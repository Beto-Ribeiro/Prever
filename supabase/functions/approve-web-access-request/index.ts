// @ts-nocheck
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') || 'gemini-3.5-flash'
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GOOGLE_API_KEY')
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

function json(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}

function sanitizeText(value: unknown, maxLength = 4000) {
  return String(value || '').trim().slice(0, maxLength)
}

function normalizeHistory(history: unknown) {
  if (!Array.isArray(history)) return ''

  return history
    .slice(-8)
    .map((item) => {
      const role = item?.role === 'assistant' ? 'IA PREVER' : 'Usuário'
      const text = sanitizeText(item?.text, 1200)
      return text ? `${role}: ${text}` : ''
    })
    .filter(Boolean)
    .join('\n')
}

function buildPrompt(body: Record<string, unknown>) {
  const screenTitle = sanitizeText(body.screenTitle || body.currentScreen || 'PREVER', 120)
  const screenIntro = sanitizeText(body.screenIntro, 500)
  const history = normalizeHistory(body.history)
  const message = sanitizeText(body.message, 2000)

  return [
    `Tela atual: ${screenTitle}`,
    screenIntro ? `Contexto da tela: ${screenIntro}` : '',
    history ? `Histórico recente:\n${history}` : '',
    `Pergunta do usuário:\n${message}`,
  ]
    .filter(Boolean)
    .join('\n\n')
}

function extractGeminiText(payload: Record<string, unknown>) {
  const candidates = Array.isArray(payload?.candidates) ? payload.candidates : []
  const parts = candidates[0]?.content?.parts

  if (!Array.isArray(parts)) return ''

  return parts
    .map((part) => typeof part?.text === 'string' ? part.text : '')
    .filter(Boolean)
    .join('\n')
    .trim()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Método não permitido.' }, 405)
  }

  try {
    if (!GEMINI_API_KEY) {
      return json({
        error: 'A IA ainda não está configurada. Defina GEMINI_API_KEY nos secrets do Supabase.',
      }, 500)
    }

    const body = await req.json().catch(() => ({}))
    const message = sanitizeText(body.message, 2000)

    if (!message) {
      return json({ error: 'Digite uma mensagem para a IA.' }, 400)
    }

    const prompt = buildPrompt(body)

    const response = await fetch(`${GEMINI_ENDPOINT}?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [
              {
                text: prompt,
              },
            ],
          },
        ],
        systemInstruction: {
          parts: [
            {
              text: [
                'Você é a IA PREVER, assistente operacional da Plataforma de Resiliência e Vigilância de Eventos de Risco.',
                'Responda sempre em português do Brasil.',
                'Ajude agentes públicos a entender telas, priorizar ocorrências, revisar alertas, interpretar relatórios e consultar auditoria.',
                'Não invente dados do sistema.',
                'Use apenas o contexto recebido na pergunta.',
                'Em emergência real, oriente seguir protocolos oficiais da Defesa Civil, Bombeiros, SAMU ou autoridade competente.',
                'Nunca substitua a decisão técnica da autoridade responsável.',
              ].join(' '),
            },
          ],
        },
        generationConfig: {
          temperature: 0.4,
          topP: 0.9,
          maxOutputTokens: 1600,
        },
      }),
    })

    const payload = await response.json().catch(() => ({}))

    if (!response.ok) {
      return json({
        error: payload?.error?.message || 'Não foi possível consultar a IA agora.',
      }, response.status)
    }

    const text = extractGeminiText(payload) || 'Não consegui gerar uma resposta agora.'

    return json({
      text,
      model: GEMINI_MODEL,
    })
  } catch (error) {
    return json({
      error: error?.message || 'Erro inesperado ao consultar a IA.',
    }, 500)
  }
})
