// @ts-nocheck
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') || 'gemini-2.5-flash'
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || ''
const ALLOWED_ORIGINS = (Deno.env.get('ALLOWED_ORIGINS') || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean)

const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

function resolveCorsHeaders(req: Request) {
  const origin = req.headers.get('Origin') || ''
  const allowOrigin =
    ALLOWED_ORIGINS.length === 0
      ? '*'
      : ALLOWED_ORIGINS.includes(origin)
        ? origin
        : ALLOWED_ORIGINS[0]

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  }
}

function json(req: Request, payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...resolveCorsHeaders(req),
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  })
}

function sanitizeText(value: unknown, maxLength = 4000) {
  return String(value || '')
    .replaceAll('\u0000', '')
    .trim()
    .slice(0, maxLength)
}

function normalizeHistory(history: unknown) {
  if (!Array.isArray(history)) return ''

  return history
    .slice(-8)
    .map((item) => {
      const role = item?.role === 'assistant' ? 'Nimbo' : 'Usuário'
      const text = sanitizeText(item?.text, 1200)
      return text ? `${role}: ${text}` : ''
    })
    .filter(Boolean)
    .join('\n')
}

function serializeOperationalContext(context: unknown, budget = 60000) {
  if (!context || typeof context !== 'object') return ''
  try {
    const raw = JSON.stringify(context)
    return raw.length <= budget ? raw : raw.slice(0, budget)
  } catch {
    return ''
  }
}

function buildPrompt(body: Record<string, unknown>) {
  const screenTitle = sanitizeText(body.screenTitle || body.currentScreen || 'PREVER', 120)
  const screenIntro = sanitizeText(body.screenIntro, 500)
  const history = normalizeHistory(body.history)
  const message = sanitizeText(body.message, 2500)
  const operational = serializeOperationalContext(body.operationalContext)

  return [
    `Tela atual: ${screenTitle}`,
    screenIntro ? `Contexto da tela: ${screenIntro}` : '',
    history ? `Histórico recente:\n${history}` : '',
    `Pergunta do usuário:\n${message}`,
    operational ? `CONTEXTO_OPERACIONAL:\n${operational}` : '',
  ]
    .filter(Boolean)
    .join('\n\n')
}

function extractGeminiText(payload: Record<string, unknown>) {
  const candidates = Array.isArray(payload?.candidates) ? payload.candidates : []
  const parts = candidates[0]?.content?.parts

  if (!Array.isArray(parts)) return ''

  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .filter(Boolean)
    .join('\n')
    .trim()
}

function parseStructuredAnswer(rawText: string) {
  const cleaned = String(rawText || '')
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim()

  try {
    const parsed = JSON.parse(cleaned)
    if (parsed && typeof parsed === 'object') {
      return {
        text: String(parsed.answer || parsed.text || '').trim(),
        actions: Array.isArray(parsed.actions) ? parsed.actions : [],
      }
    }
  } catch {
    // Fallback textual caso o modelo retorne Markdown simples.
  }

  return {
    text: cleaned,
    actions: [],
  }
}

async function verifyAuthenticatedUser(req: Request) {
  const authorization = req.headers.get('Authorization') || ''
  if (!authorization.startsWith('Bearer ')) {
    return false
  }
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return false
  }

  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: authorization,
    },
    signal: AbortSignal.timeout(10000),
  })

  return res.ok
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: resolveCorsHeaders(req) })
  }

  if (req.method !== 'POST') {
    return json(req, { error: 'Método não permitido.' }, 405)
  }

  try {
    const authenticated = await verifyAuthenticatedUser(req)
    if (!authenticated) {
      return json(req, { error: 'Sessão inválida ou expirada. Entre novamente.' }, 401)
    }

    if (!GEMINI_API_KEY) {
      return json(
        req,
        { error: 'O Nimbo está indisponível no momento. Tente novamente em instantes.' },
        503
      )
    }

    const body = await req.json().catch(() => ({}))
    const message = sanitizeText(body.message, 2500)

    if (!message) {
      return json(req, { error: 'Digite uma mensagem para o Nimbo.' }, 400)
    }

    const prompt = buildPrompt(body)

    const response = await fetch(GEMINI_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      signal: AbortSignal.timeout(25000),
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }],
          },
        ],
        systemInstruction: {
          parts: [
            {
              text: [
                'Você é Nimbo, assistente operacional do PREVER — Plataforma de Resiliência e Vigilância de Eventos de Risco.',
                'Responda sempre em português do Brasil.',
                'Responda SOMENTE JSON válido no formato {"answer":"texto em Markdown simples","actions":[]}.',
                'Ajude agentes públicos a entender telas, priorizar ocorrências, revisar alertas, interpretar relatórios e consultar auditoria.',
                'Não invente dados do sistema. Use apenas o contexto recebido na pergunta.',
                'Em emergência real, oriente seguir protocolos oficiais da Defesa Civil, Bombeiros, SAMU ou autoridade competente.',
                'Nunca substitua a decisão técnica da autoridade responsável.',
              ].join(' '),
            },
          ],
        },
        generationConfig: {
          temperature: 0.2,
          topP: 0.9,
          maxOutputTokens: 4096,
          responseMimeType: 'application/json',
        },
      }),
    })

    const payload = await response.json().catch(() => ({}))

    if (!response.ok) {
      const status = response.status === 429 ? 429 : 502
      return json(
        req,
        {
          error:
            response.status === 429
              ? 'O Nimbo está recebendo muitas solicitações. Tente novamente em instantes.'
              : 'Não foi possível consultar o Nimbo agora.',
        },
        status
      )
    }

    const rawText = extractGeminiText(payload)
    const parsed = parseStructuredAnswer(rawText)

    return json(req, {
      text: parsed.text || 'Nimbo não conseguiu gerar uma resposta agora.',
      actions: parsed.actions,
      model: GEMINI_MODEL,
    })
  } catch {
    return json(
      req,
      { error: 'O Nimbo está indisponível no momento. Tente novamente em instantes.' },
      500
    )
  }
})
