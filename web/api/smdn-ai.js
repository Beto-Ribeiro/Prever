import { assistantError } from '../src/backend/ai/assistantPolicy.js'
import { GoogleGenAI } from '@google/genai'

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.5-flash'

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  res.end(JSON.stringify(payload))
}

function sanitizeText(value, maxLength = 4000) {
  return String(value || '').trim().slice(0, maxLength)
}

async function readBody(req) {
  const chunks = []

  for await (const chunk of req) {
    chunks.push(chunk)
  }

  if (chunks.length === 0) return {}

  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    return {}
  }
}

async function validateSupabaseSession(req) {
  const supabaseUrl = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY
  const authorization = req.headers.authorization || ''

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('Erro interno no banco de dados.')
  }

  if (!authorization.startsWith('Bearer ')) {
    throw new Error('Faça login para usar o Nimbo.')
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: supabaseAnonKey,
      authorization,
    },
  })

  if (!response.ok) {
    throw new Error('Sessão inválida ou expirada. Entre novamente.')
  }

  return response.json()
}

function buildPrompt({ message, currentScreen, screenTitle, screenIntro, history }) {
  const recentHistory = Array.isArray(history)
    ? history
        .slice(-8)
        .map((item) => {
          const role = item?.role === 'assistant' ? 'Nimbo' : 'Usuário'
          return `${role}: ${sanitizeText(item?.text, 1200)}`
        })
        .join('\n')
    : ''

  return [
    `Tela atual: ${sanitizeText(screenTitle || currentScreen || 'PREVER', 120)}`,
    screenIntro ? `Contexto da tela: ${sanitizeText(screenIntro, 500)}` : '',
    recentHistory ? `Histórico recente:\n${recentHistory}` : '',
    `Pergunta do usuário:\n${sanitizeText(message, 2000)}`,
  ]
    .filter(Boolean)
    .join('\n\n')
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return sendJson(res, 405, { error: 'Método não permitido.' })
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY

    if (!apiKey) {
      return sendJson(res, 500, {
        error: 'O Nimbo está indisponível no momento. Tente novamente em instantes.',
      })
    }

    await validateSupabaseSession(req)

    const body = await readBody(req)
    const message = sanitizeText(body.message, 2000)

    if (!message) {
      return sendJson(res, 400, { error: 'Digite uma mensagem para o Nimbo.' })
    }

    const ai = new GoogleGenAI({ apiKey })

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: buildPrompt({
        message,
        currentScreen: body.currentScreen,
        screenTitle: body.screenTitle,
        screenIntro: body.screenIntro,
        history: body.history,
      }),
      config: {
        systemInstruction: [
          'Você é Nimbo, assistente operacional do Sistema de Monitoramento de Desastres Naturais.',
          'Responda sempre em português do Brasil.',
          'Nimbo sempre fala de si em terceira pessoa. Use frases como: Nimbo recomenda, Nimbo encontrou, Nimbo acha isso errado.',
          'Ao se apresentar, chame-se apenas de Nimbo.',
          'Ajude agentes públicos a entender telas, priorizar ocorrências, revisar alertas, interpretar relatórios e consultar auditoria.',
          'Não invente dados do sistema.',
          'Use apenas o contexto recebido na pergunta.',
          'Em emergência real, oriente seguir protocolos oficiais da Defesa Civil, Bombeiros, SAMU ou autoridade competente.',
          'Nunca substitua a decisão técnica da autoridade responsável.',
        ].join(' '),
        temperature: 0.3,
        topP: 0.9,
        maxOutputTokens: 1600,
      },
    })

    return sendJson(res, 200, {
      text: response.text || 'Nimbo não conseguiu gerar uma resposta agora.',
      model: GEMINI_MODEL,
    })
  } catch (error) {
    return sendJson(res, 500, {
      error: assistantError(error),
    })
  }
}
