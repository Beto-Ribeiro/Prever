import { initializeApp, getApp, getApps } from 'firebase/app'
import { getAI, getGenerativeModel, VertexAIBackend } from 'firebase/ai'

function getEnv(name, fallback = '') {
  return String(import.meta.env[name] || fallback).trim()
}

const firebaseConfig = {
  apiKey: getEnv('VITE_FIREBASE_API_KEY'),
  authDomain: getEnv('VITE_FIREBASE_AUTH_DOMAIN'),
  projectId: getEnv('VITE_FIREBASE_PROJECT_ID'),
  storageBucket: getEnv('VITE_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: getEnv('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  appId: getEnv('VITE_FIREBASE_APP_ID'),
}

const AVAILABLE_SCREENS = [
  'dashboard',
  'reportar',
  'ocorrencias',
  'relatorios',
  'auditoria',
  'perfil',
  'admin',
  'users',
]

const ALLOWED_ACTIONS = new Set([
  'navigate',
  'open_user',
  'filter_users',
  'open_dashboard_occurrence',
  'filter_audit',
])

function validateFirebaseConfig() {
  const missing = Object.entries(firebaseConfig)
    .filter(([, value]) => !value)
    .map(([key]) => key)

  if (missing.length > 0) {
    throw new Error(`Configuração Firebase incompleta no .env: ${missing.join(', ')}`)
  }
}

function getFirebaseApp() {
  return getApps().length > 0 ? getApp() : initializeApp(firebaseConfig)
}

function sanitizeText(value, maxLength = 4000) {
  return String(value || '')
    .replaceAll(String.fromCharCode(0), '')
    .trim()
    .slice(0, maxLength)
}

function normalizeHistory(history = []) {
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

function safeStringify(value, maxLength = 36000) {
  try {
    return JSON.stringify(value || {}, null, 2).slice(0, maxLength)
  } catch {
    return '{}'
  }
}

function buildPrompt({ message, currentScreen, screenTitle, screenIntro, history, operationalContext }) {
  const historyText = normalizeHistory(history)

  return [
    'Você é Nimbo, assistente operacional da Plataforma de Resiliência e Vigilância de Eventos de Risco.',
    'Responda sempre em português do Brasil, com clareza, objetividade e tom profissional.',
    'Nimbo sempre fala de si em terceira pessoa. Use frases como: "Nimbo recomenda...", "Nimbo encontrou...", "Nimbo acha isso errado." Nunca diga "eu acho", "eu encontrei" ou "posso".',
    'Ao se apresentar, chame-se apenas de Nimbo.',
    'Use os dados reais recebidos no CONTEXTO_OPERACIONAL antes de dizer que não sabe.',
    'Se um usuário, administrador, cidadão, instituição, ocorrência, auditoria, histórico global, atividade recente, card do Dashboard ou prioridade existir no contexto, responda com base nele.',
    'Não diga que não tem acesso se o dado estiver no contexto JSON.',
    'Não invente dados fora do contexto. Se não encontrar, diga exatamente que não encontrou no contexto recebido.',
    'Em emergência real, oriente seguir protocolos oficiais da Defesa Civil, Bombeiros, SAMU ou autoridade competente.',
    'Nunca substitua a decisão técnica da autoridade responsável.',
    '',
    'FORMATO OBRIGATÓRIO DA RESPOSTA:',
    'Responda SOMENTE com JSON válido.',
    'Não use bloco markdown.',
    'Não coloque texto antes ou depois do JSON.',
    'Não use aspas soltas sem escape dentro do campo answer.',
    'Use \\n dentro da string answer quando precisar quebrar linhas.',
    'Formato exato:',
    '{',
    '  "answer": "texto em Markdown simples para exibir no chat",',
    '  "actions": []',
    '}',
    '',
    'Ações permitidas em actions:',
    '- {"type":"navigate","screen":"dashboard|reportar|ocorrencias|relatorios|auditoria|perfil|admin|users"}',
    '- {"type":"open_user","query":"nome, e-mail ou id do usuário"}',
    '- {"type":"filter_users","query":"texto para filtrar a lista de usuários"}',
    '- {"type":"open_dashboard_occurrence","id":"id ou relatoId da ocorrência","query":"texto de busca opcional","mapMode":"heat","zoom":16,"openPopup":true}',
    '- {"type":"filter_audit","query":"texto para pesquisar na auditoria","openFirst":true}',
    '',
    'REGRAS IMPORTANTES:',
    '- Se CONTEXTO_OPERACIONAL.activePopup?.isOpen for true, o foco principal da resposta deve ser o pop-up aberto, principalmente para perguntas genéricas como "explique isso", "o que faço?", "resuma", "isso está certo?" ou "o que significa?".',
    '- Quando usar activePopup, responda direto sobre o conteúdo dele. Não diga frases como "Nimbo vê o pop-up", "Nimbo está vendo o pop-up" ou "há um pop-up aberto".',
    '- Se o usuário perguntar algo fora do pop-up de forma explícita, então use a tela atual e o restante do contexto normalmente.',
    '- Para perguntas com "todos os tempos", "histórico", "tudo", "geral", "todos os usuários", "quem fez", "reports", "relatos", "alertas", "atividades do sistema" ou "não repetidas", use CONTEXTO_OPERACIONAL.globalHistory antes de currentProfile.',
    '- currentProfile mostra apenas o perfil do usuário logado. Não use currentProfile como limite quando a pergunta for global.',
    '- Se a pergunta disser explicitamente "meu perfil", "minhas atividades" ou "minha conta", use currentProfile. Caso contrário, para histórico e atividades, use globalHistory.',
    '- Para responder quem fez reports/relatos de todos os tempos, use globalHistory.allTime.occurrenceReportsByUser e globalHistory.allTime.occurrenceReports.',
    '- Para atividades mais recentes sem repetição, use globalHistory.uniqueRecent. Se o usuário pedir do próprio perfil, use currentProfile.activities.recent e remova repetidas mentalmente.',
    '- Se globalHistory.totalLoaded for maior que zero, nunca responda que Nimbo não encontrou histórico global sem antes consultar globalHistory.relatedToQuestion, globalHistory.recent, globalHistory.uniqueRecent e globalHistory.allTime.',
    '- Perguntas como "Quem é Giovanna?" ou "Quem é Ales Lino?": procure em CONTEXTO_OPERACIONAL.users.profiles e, se encontrar, responda tipo, contato, permissões e inclua action open_user.',
    '- Perguntas como "Quem são os administradores?": use CONTEXTO_OPERACIONAL.users.admins, liste os nomes e inclua action filter_users com query "administrador".',
    '- Perguntas como "Tem instituição?": use CONTEXTO_OPERACIONAL.users.institutions e diga se há ou não há perfis de instituição.',
    '- Perguntas sobre mudanças de perfil, logs ou auditoria: use CONTEXTO_OPERACIONAL.audit.recentEvents e inclua action filter_audit quando fizer sentido.',
    '- Perguntas sobre a tela Perfil, permissões ou atividades recentes: use CONTEXTO_OPERACIONAL.currentProfile.user e CONTEXTO_OPERACIONAL.currentProfile.activities.recent.',
    '- Perguntas como "O que devo conferir primeiro?" no Dashboard: escolha UMA ocorrência em CONTEXTO_OPERACIONAL.dashboard.priority.recommendedOccurrence.',
    '- Ao responder "O que devo conferir primeiro?" no Dashboard, inclua OBRIGATORIAMENTE uma action open_dashboard_occurrence usando dashboard.priority.actionSuggestion.',
    '- Nessa resposta, diga que você vai iniciar pela ocorrência recomendada, abrir o detalhe dela, aproximar o mapa e manter o mapa de calor para visualizar concentração de risco.',
    '- Se dashboard.priority.actionSuggestion existir, copie seus campos para actions. Não deixe actions vazio.',
    '- Se dashboard.recommendedOccurrence estiver vazio, mas houver dashboard.visibleCards com ocorrências ativas, severidade crítica, vítimas ou alertas, use os cards como prioridade. Não responda que não encontrou prioridade.',
    '- Se houver vítimas localizadas, severidade crítica ou ocorrências ativas, destaque isso como prioridade imediata.',
    '- Use Markdown simples dentro do campo answer: **negrito**, quebras de linha e listas com * item.',
    '',
    `Telas disponíveis: ${AVAILABLE_SCREENS.join(', ')}.`,
    `Tela atual: ${sanitizeText(screenTitle || currentScreen || 'PREVER', 120)}`,
    screenIntro ? `Contexto da tela atual: ${sanitizeText(screenIntro, 800)}` : '',
    historyText ? `Histórico recente:\n${historyText}` : '',
    `Pergunta do usuário:\n${sanitizeText(message, 2500)}`,
    '',
    `CONTEXTO_OPERACIONAL:\n${safeStringify(operationalContext)}`,
  ]
    .filter(Boolean)
    .join('\n\n')
}

function extractText(result) {
  if (typeof result?.response?.text === 'function') return result.response.text()
  if (typeof result?.text === 'function') return result.text()
  if (typeof result?.text === 'string') return result.text
  return ''
}

function createVertexBackend(location) {
  try {
    return new VertexAIBackend(location)
  } catch {
    try {
      return new VertexAIBackend({ location })
    } catch {
      return new VertexAIBackend()
    }
  }
}

function createGenerativeModel() {
  validateFirebaseConfig()

  const app = getFirebaseApp()
  const location = getEnv('VITE_FIREBASE_VERTEX_LOCATION', 'global')
  const modelName = getEnv('VITE_FIREBASE_VERTEX_MODEL', 'gemini-2.5-flash')

  const ai = getAI(app, {
    backend: createVertexBackend(location),
  })

  const model = getGenerativeModel(ai, {
    model: modelName,
    generationConfig: {
      temperature: 0.15,
      topP: 0.8,
      maxOutputTokens: 1000,
      responseMimeType: 'application/json',
    },
  })

  console.log('🔥 Nimbo — RECOMENDA OCORRÊNCIA + MAPA DE CALOR 🔥', {
    projectId: firebaseConfig.projectId,
    appId: firebaseConfig.appId,
    location,
    model: modelName,
  })

  return { model, modelName }
}

function stripMarkdownFence(text) {
  return String(text || '')
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim()
}

function findBalancedJsonObject(text) {
  const source = String(text || '')
  const start = source.indexOf('{')
  if (start < 0) return ''

  let depth = 0
  let inString = false
  let escaped = false

  for (let index = start; index < source.length; index += 1) {
    const char = source[index]

    if (escaped) {
      escaped = false
      continue
    }

    if (char === '\\') {
      escaped = true
      continue
    }

    if (char === '"') {
      inString = !inString
      continue
    }

    if (inString) continue

    if (char === '{') depth += 1
    if (char === '}') depth -= 1

    if (depth === 0) return source.slice(start, index + 1)
  }

  return ''
}

function normalizeVisibleAnswer(value) {
  let text = ''

  if (typeof value === 'string') {
    text = value
  } else if (value && typeof value === 'object') {
    text = value.answer || value.text || ''
  }

  text = String(text || '')
    .replace(/\\n/g, '\n')
    .replace(/\r\n/g, '\n')
    .replace(/\n{4,}/g, '\n\n\n')
    .replace(/^["']|["']$/g, '')
    .trim()

  if (!text || text === '[object Object]' || text === 'undefined' || text === 'null') {
    return 'Nimbo não conseguiu gerar uma resposta clara agora. Tente reformular a pergunta.'
  }

  if (text.startsWith('{') && text.includes('"answer"')) {
    return 'Nimbo retornou uma resposta fora do formato esperado. Tente enviar a pergunta novamente.'
  }

  return text.slice(0, 3500)
}

function normalizeActions(actions) {
  if (!Array.isArray(actions)) return []

  return actions
    .map((action) => {
      if (!action || typeof action !== 'object') return null

      const type = String(action.type || '').trim().toLowerCase()
      if (!ALLOWED_ACTIONS.has(type)) return null

      if (type === 'navigate') {
        const screen = String(action.screen || '').trim()
        return AVAILABLE_SCREENS.includes(screen) ? { type, screen } : null
      }

      if (type === 'open_user') {
        return { type, query: sanitizeText(action.query || action.name || action.id, 180) }
      }

      if (type === 'filter_users') {
        return { type, query: sanitizeText(action.query || action.role || action.kind || action.type, 180) }
      }

      if (type === 'open_dashboard_occurrence') {
        return {
          type,
          id: sanitizeText(action.id || action.relatoId, 120),
          relatoId: sanitizeText(action.relatoId || action.id, 120),
          query: sanitizeText(action.query || action.title, 180),
          mapMode: action.mapMode === 'points' || action.mapMode === 'victims' ? action.mapMode : 'heat',
          zoom: Number.isFinite(Number(action.zoom)) ? Number(action.zoom) : 16,
          openPopup: action.openPopup !== false,
        }
      }

      if (type === 'filter_audit') {
        return {
          type,
          query: sanitizeText(action.query, 180),
          auditType: sanitizeText(action.auditType || action.kind || action.filterType, 120),
          openFirst: action.openFirst !== false,
        }
      }

      return null
    })
    .filter(Boolean)
}

function parseJsonPayload(text) {
  const cleaned = stripMarkdownFence(text)

  try {
    return JSON.parse(cleaned)
  } catch {
    // tenta extrair objeto balanceado
  }

  const balanced = findBalancedJsonObject(cleaned)

  if (balanced) {
    try {
      return JSON.parse(balanced)
    } catch {
      // fallback abaixo
    }
  }

  return null
}

function extractLooseAnswer(text) {
  const cleaned = stripMarkdownFence(text)
  const answerMatch = cleaned.match(/["']answer["']\s*:\s*["']([\s\S]*?)["']\s*,\s*["']actions["']/i)

  if (answerMatch?.[1]) {
    return answerMatch[1]
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\')
      .trim()
  }

  if (cleaned.includes('"answer"')) return ''
  return cleaned
}

function parseAssistantPayload(rawText) {
  const parsed = parseJsonPayload(rawText)

  if (parsed && typeof parsed === 'object') {
    return {
      text: normalizeVisibleAnswer(parsed.answer || parsed.text),
      actions: normalizeActions(parsed.actions),
    }
  }

  return {
    text: normalizeVisibleAnswer(extractLooseAnswer(rawText)),
    actions: [],
  }
}

function forcePriorityActionIfMissing({ parsed, operationalContext, currentScreen, message }) {
  const question = String(message || '').toLowerCase()
  const asksPriority = currentScreen === 'dashboard' && (
    question.includes('conferir primeiro') ||
    question.includes('prioridade') ||
    question.includes('começar') ||
    question.includes('iniciar')
  )

  const suggestion = operationalContext?.dashboard?.priority?.actionSuggestion

  if (!asksPriority || !suggestion) return parsed

  const alreadyHasAction = parsed.actions.some((action) => action.type === 'open_dashboard_occurrence')

  if (alreadyHasAction) return parsed

  return {
    ...parsed,
    actions: [
      ...parsed.actions,
      {
        type: 'open_dashboard_occurrence',
        id: suggestion.id || suggestion.relatoId,
        relatoId: suggestion.relatoId || suggestion.id,
        query: suggestion.query || '',
        mapMode: 'heat',
        zoom: suggestion.zoom || 16,
        openPopup: true,
      },
    ],
  }
}

export async function askSmdnAssistant({
  message,
  currentScreen,
  screenTitle,
  screenIntro,
  history,
  operationalContext,
}) {
  console.log('🔥 NIMBO SERVICE RODANDO — OCORRÊNCIA RECOMENDADA COM MAPA 🔥')

  const cleanMessage = sanitizeText(message, 2500)

  if (!cleanMessage) {
    throw new Error('Digite uma mensagem para a IA.')
  }

  try {
    const { model, modelName } = createGenerativeModel()

    const result = await model.generateContent(
      buildPrompt({
        message: cleanMessage,
        currentScreen,
        screenTitle,
        screenIntro,
        history,
        operationalContext,
      })
    )

    const rawText = extractText(result)
    const parsed = forcePriorityActionIfMissing({
      parsed: parseAssistantPayload(rawText),
      operationalContext,
      currentScreen,
      message: cleanMessage,
    })

    return {
      text: parsed.text || 'Nimbo não conseguiu gerar uma resposta clara agora. Tente reformular a pergunta.',
      actions: parsed.actions,
      model: modelName,
    }
  } catch (error) {
    console.error('[Nimbo] Erro Vertex AI Firebase:', error)

    throw new Error(
      error?.message ||
      error?.code ||
      'Não foi possível consultar o Nimbo pelo Vertex AI.',
      { cause: error }
    )
  }
}
