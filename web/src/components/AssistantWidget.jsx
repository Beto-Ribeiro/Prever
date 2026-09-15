import { captureScreenContext } from '../backend/ai/screenContextService.js'
import { assistantError, allowedScreens, chatKey, LEGACY_CHAT_KEY, permittedActions } from '../backend/ai/assistantPolicy.js'
import { Fragment, useEffect, useMemo, useRef, useState } from 'react'
import assistantIcon from '../assets/assistant/assistant-icon.svg'
import { askSmdnAssistant } from '../backend/ai/assistantService.js'
import { buildSmdnOperationalContext } from '../backend/ai/smdnContextService.js'
import { useAuth } from '../hooks/useAuth.js'
import { useSmdnSettings } from '../hooks/useSmdnSettings.js'

const SCREEN_CONTEXT = {
  dashboard: {
    title: 'Dashboard',
    intro: 'Ajude a entender mapa, ocorrências críticas, alertas ativos, vítimas e status operacional.',
    suggestions: ['Resuma esta tela', 'O que devo conferir primeiro?'],
  },
  reportar: {
    title: 'Reportar',
    intro: 'Ajude a revisar mensagens antes do disparo de alertas públicos.',
    suggestions: ['Revise um alerta antes de disparar', 'Como escrever uma boa mensagem de alerta?'],
  },
  ocorrencias: {
    title: 'Ocorrências',
    intro: 'Ajude a priorizar relatos, status e ocorrências críticas.',
    suggestions: ['Como priorizar ocorrências?', 'Explique os status de ocorrência'],
  },
  relatorios: {
    title: 'Relatórios',
    intro: 'Ajude a interpretar KPIs, gráficos, municípios, tipos e severidades.',
    suggestions: ['Gere um resumo executivo', 'O que destacar em uma apresentação?'],
  },
  auditoria: {
    title: 'Auditoria',
    intro: 'Ajude a interpretar logs, responsáveis, ações e impacto das alterações.',
    suggestions: ['Como ler os logs?', 'O que procurar em uma auditoria?'],
  },
  perfil: {
    title: 'Perfil',
    intro: 'Ajude a entender permissões, perfil de usuário e atividades recentes.',
    suggestions: ['Explique minhas permissões', 'Como interpretar atividades recentes?'],
  },
  admin: {
    title: 'Painel do Admin',
    intro: 'Ajude a revisar solicitações de acesso e alterações administrativas.',
    suggestions: ['Checklist para aprovar acesso', 'Como avaliar solicitação suspeita?'],
  },
  users: {
    title: 'Lista de Usuários',
    intro: 'Ajude a revisar vínculos, perfis e permissões de usuários.',
    suggestions: ['Como revisar permissões?', 'Como identificar inconsistências de usuário?'],
  },
}

const MANAGER_CONTEXT = {
  dashboard: { title: 'Visão geral do abrigo', intro: 'Resumo do abrigo vinculado: vagas, estoque, pedidos e doações.', suggestions: ['Quantas vagas temos?', 'O que está acabando no estoque?'] },
  ocupantes: { title: 'Ocupantes', intro: 'Nomes, idades, categorias, responsáveis e contatos dos ocupantes, conforme a tela e o abrigo vinculado.', suggestions: ['Quem é o ocupante mais novo?', 'Resuma os ocupantes desta tela'] },
  estoque: { title: 'Estoque', intro: 'Quantidades, unidades e metas do estoque do abrigo.', suggestions: ['Quais itens estão em nível crítico?', 'Resuma o estoque do abrigo'] },
  pedidos: { title: 'Pedidos de ajuda', intro: 'Pedidos, prioridades, quantidades recebidas e pendências do abrigo.', suggestions: ['Quais pedidos estão pendentes?', 'Quais pedidos são urgentes?'] },
  relatorios: { title: 'Relatórios do abrigo', intro: 'Resumo atual; relatórios por período são gerados na tela Relatórios.', suggestions: ['Resuma os indicadores atuais do abrigo', 'Como exportar um relatório?'] },
  perfil: SCREEN_CONTEXT.perfil,
}

function SparkIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 2l1.5 5.2L19 9l-5.5 1.8L12 16l-1.5-5.2L5 9l5.5-1.8L12 2Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M18 14l.8 2.6 2.7.9-2.7.9L18 21l-.8-2.6-2.7-.9 2.7-.9L18 14Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M5.5 14l.6 1.9 1.9.6-1.9.6-.6 1.9-.6-1.9-1.9-.6 1.9-.6.6-1.9Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  )
}

function buildInitialMessages() {
  return [
    {
      role: 'assistant',
      text: 'Olá! Sou o Nimbo. Como posso ajudar?',
    },
    {
      role: 'assistant',
      text: 'Consulto os dados e o conteúdo da tela do PREVER, incluindo formulários abertos, conforme suas permissões. Essas informações são processadas pela IA do Google para ajudar você.',
    },
  ]
}

function readStoredMessages(key) {
  if (!key) return buildInitialMessages()
  try {
    localStorage.removeItem(LEGACY_CHAT_KEY)
    const saved = JSON.parse(sessionStorage.getItem(key) || '[]')
    if (Array.isArray(saved) && saved.length > 0) {
      return saved
        .filter((item) => item?.role && typeof item?.text === 'string')
        .slice(-24)
    }
  } catch {
    // ignora histórico corrompido
  }

  return buildInitialMessages()
}

function writeStoredMessages(key, messages) {
  if (!key) return
  try {
    const safeMessages = (messages || [])
      .filter((item) => item?.role && typeof item?.text === 'string')
      .slice(-40)

    sessionStorage.setItem(key, JSON.stringify(safeMessages))
  } catch {
    // ignora storage indisponível
  }
}

function getAccountProfile(user, session) {
  const authUser = user || session?.user || {}
  const perfil = authUser?.perfil || {}

  const name =
    authUser?.name ||
    authUser?.nome ||
    perfil?.prf_nome ||
    authUser?.user_metadata?.name ||
    authUser?.email?.split('@')[0] ||
    'Usuário'


  return {
    id: authUser?.id || session?.user?.id || 'sem-conta',
    name,
    avatar:
      authUser?.avatar ||
      authUser?.avatarUrl ||
      perfil?.prf_avatar_url ||
      authUser?.user_metadata?.avatar_url ||
      '',
    role:
      authUser?.roleLabel ||
      authUser?.role ||
      perfil?.prf_tipo ||
      'Conta PREVER',
  }
}

function initialsFromName(name) {
  return String(name || 'U')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function UserAvatar({ account }) {
  if (!account) return null

  if (account.avatar) {
    return (
      <img
        src={account.avatar}
        alt=""
        className="mt-0.5 h-8 w-8 rounded-xl border border-border-soft object-cover flex-shrink-0"
        aria-hidden="true"
      />
    )
  }

  return (
    <span
      className="mt-0.5 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-xl border border-border-soft bg-slate-100 text-[10px] font-black text-slate-700"
      aria-hidden="true"
    >
      {initialsFromName(account.name)}
    </span>
  )
}

function clearPendingAiActions() {
  window.__SMDN_AI_PENDING_USER_ACTION = null
  window.__SMDN_AI_PENDING_DASHBOARD_ACTION = null
  window.__SMDN_AI_PENDING_AUDIT_ACTION = null
}

function renderInlineMarkdown(text) {
  const parts = String(text || '').split(/(\*\*[^*]+\*\*)/g)

  return parts.map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return (
        <strong key={index} className="font-extrabold text-inherit">
          {part.slice(2, -2)}
        </strong>
      )
    }

    return <Fragment key={index}>{part}</Fragment>
  })
}

function renderMessageText(text) {
  const lines = String(text || '').split('\n')

  return lines.map((line, index) => {
    const bullet = line.match(/^\s*\*\s+(.*)$/)
    const content = bullet ? bullet[1] : line

    return (
      <Fragment key={`${line}-${index}`}>
        {bullet ? (
          <span className="block pl-4 -indent-4">
            <span aria-hidden="true">• </span>
            {renderInlineMarkdown(content)}
          </span>
        ) : (
          <span>{renderInlineMarkdown(content)}</span>
        )}
        {index < lines.length - 1 && !bullet && <br />}
      </Fragment>
    )
  })
}

function normalizeAction(action) {
  if (!action || typeof action !== 'object') return null
  return {
    ...action,
    type: String(action.type || '').trim().toLowerCase(),
  }
}

function normalizeDashboardAction(action) {
  return {
    id: action.id || action.relatoId || '',
    relatoId: action.relatoId || action.id || '',
    query: action.query || action.title || '',
    mapMode: action.mapMode === 'points' || action.mapMode === 'victims' ? action.mapMode : 'heat',
    zoom: Number.isFinite(Number(action.zoom)) ? Number(action.zoom) : 16,
    openPopup: action.openPopup !== false,
  }
}

export default function AssistantWidget(props) {
  const { user } = useAuth()
  return <AssistantWidgetSession key={chatKey(user) || 'no-session'} {...props} />
}
function AssistantWidgetSession({ currentScreen, setCurrentScreen, compact = false, dense = false }) {
  const { user, session } = useAuth()
  const { settings } = useSmdnSettings()
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState(() => readStoredMessages(chatKey(user)))
  const requestRef = useRef(0)
  const timersRef = useRef(new Set())
  const [draft, setDraft] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState('')

  const panelRef = useRef(null)
  const buttonRef = useRef(null)
  const messagesEndRef = useRef(null)
  const dragStateRef = useRef(null)
  const [panelPosition, setPanelPosition] = useState(null)

  const accountProfile = useMemo(() => getAccountProfile(user, session), [user, session])
  const accountId = accountProfile.id

  const context = useMemo(
    () => user?.role === 'shelter_manager' ? (MANAGER_CONTEXT[currentScreen] || MANAGER_CONTEXT.dashboard) : (SCREEN_CONTEXT[currentScreen] || SCREEN_CONTEXT.dashboard),
    [currentScreen, user?.role]
  )

  const chatStorageKey = chatKey(user)

  function getDefaultPanelPosition() {
    if (typeof window === 'undefined') {
      return { x: compact ? 70 : 210, y: 96 }
    }

    const panelHeight = Math.min(760, window.innerHeight - 80)
    return {
      x: compact ? 70 : 210,
      y: Math.max(16, window.innerHeight - panelHeight - 64),
    }
  }

  function clampPanelPosition(x, y) {
    if (typeof window === 'undefined') return { x, y }

    const panelWidth = panelRef.current?.offsetWidth || 420
    const panelHeight = panelRef.current?.offsetHeight || Math.min(760, window.innerHeight - 80)

    return {
      x: Math.min(Math.max(8, x), Math.max(8, window.innerWidth - panelWidth - 8)),
      y: Math.min(Math.max(8, y), Math.max(8, window.innerHeight - panelHeight - 8)),
    }
  }

  function startPanelDrag(event) {
    if (event.button !== 0) return
    if (event.target.closest('button, textarea, input, select, a')) return

    const currentPosition = panelPosition || getDefaultPanelPosition()

    dragStateRef.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      originX: currentPosition.x,
      originY: currentPosition.y,
    }

    event.currentTarget.setPointerCapture?.(event.pointerId)
  }

  function movePanelDrag(event) {
    const drag = dragStateRef.current
    if (!drag || drag.pointerId !== event.pointerId) return

    const next = clampPanelPosition(
      drag.originX + event.clientX - drag.startX,
      drag.originY + event.clientY - drag.startY
    )

    setPanelPosition(next)
  }

  function endPanelDrag(event) {
    if (dragStateRef.current?.pointerId === event.pointerId) {
      dragStateRef.current = null
    }
  }

  useEffect(() => {
    if (open && !panelPosition) {
      setPanelPosition(getDefaultPanelPosition())
    }
  }, [open, panelPosition])

  useEffect(() => {
    const timers = timersRef.current
    return () => {
      requestRef.current += 1
      timers.forEach(clearTimeout)
      clearPendingAiActions()
    }
  }, [])
  function scheduleUiEvent(name, detail, requestId) {
    const timer = window.setTimeout(() => {
      timersRef.current.delete(timer)
      if (requestRef.current === requestId) window.dispatchEvent(new CustomEvent(name, { detail }))
    }, 180)
    timersRef.current.add(timer)
  }

  useEffect(() => {
    if (messages.length > 0) {
      writeStoredMessages(chatStorageKey, messages)
    }
  }, [chatStorageKey, messages])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [messages, sending])

  useEffect(() => {
    function handleEscape(event) {
      if (event.key === 'Escape') {
        setOpen(false)
      }
    }

    document.addEventListener('keydown', handleEscape)

    return () => {
      document.removeEventListener('keydown', handleEscape)
    }
  }, [])

  function restartChat() {
    requestRef.current += 1
    setSending(false)
    timersRef.current.forEach(clearTimeout)
    timersRef.current.clear()
    const initialMessages = buildInitialMessages()
    setMessages(initialMessages)
    writeStoredMessages(chatStorageKey, initialMessages)
    setDraft('')
    setError('')
    clearPendingAiActions()
  }

  function applyAssistantActions(actions = [], requestId) {
    const normalizedActions = actions.map(normalizeAction).filter(Boolean)

    for (const action of normalizedActions) {
      if (action.type === 'navigate') {
        setCurrentScreen(action.screen)
      }

      if (action.type === 'open_user') {
        const detail = {
          mode: 'open',
          query: action.query || action.name || action.id || '',
        }
        window.__SMDN_AI_PENDING_USER_ACTION = detail
        setCurrentScreen('users')
        scheduleUiEvent('smdn-ai-users-action', detail, requestId)
      }

      if (action.type === 'filter_users') {
        const detail = {
          mode: 'filter',
          query: action.query || action.role || action.type || '',
        }
        window.__SMDN_AI_PENDING_USER_ACTION = detail
        setCurrentScreen('users')
        scheduleUiEvent('smdn-ai-users-action', detail, requestId)
      }

      if (action.type === 'open_dashboard_occurrence') {
        const detail = normalizeDashboardAction(action)
        window.__SMDN_AI_PENDING_DASHBOARD_ACTION = detail
        setCurrentScreen('dashboard')
        scheduleUiEvent('smdn-ai-dashboard-open-occurrence', detail, requestId)
      }

      if (action.type === 'filter_audit') {
        const detail = {
          query: action.query || '',
          type: action.auditType || action.kind || action.filterType || '',
          openFirst: action.openFirst !== false,
        }
        window.__SMDN_AI_PENDING_AUDIT_ACTION = detail
        setCurrentScreen('auditoria')
        scheduleUiEvent('smdn-ai-audit-action', detail, requestId)
      }
    }
  }

  async function sendToGemini(text) {
    const cleanText = String(text || '').trim()

    if (!cleanText || sending || !user?.id) return
    const requestId = ++requestRef.current

    setError('')
    setSending(true)
    setDraft('')

    const userMessage = {
      role: 'user',
      text: cleanText,
      accountId,
      account: accountProfile,
      screen: currentScreen,
      screenTitle: context.title,
      sentAt: new Date().toISOString(),
    }
    const historyBeforeSend = messages

    setMessages((current) => [...current, userMessage])

    try {
      const operationalContext = await buildSmdnOperationalContext({
        question: cleanText,
        currentScreen,
        accountId,
        screenContext: captureScreenContext({ currentScreen, accountId }),
      })

      if (requestId !== requestRef.current) return
      if (operationalContext.currentAskingAccount.role !== user.role || operationalContext.allowedScreens.join(',') !== allowedScreens(user).join(',')) {
        restartChat()
        setError('Suas permissões mudaram. Recarregue a página para continuar com o acesso atualizado.')
        return
      }

      const result = await askSmdnAssistant({
        message: cleanText,
        currentScreen,
        screenTitle: context.title,
        screenIntro: context.intro,
        history: historyBeforeSend,
        operationalContext,
      })

      if (requestId !== requestRef.current) return
      const freshUser = { ...user, role: operationalContext.currentAskingAccount.role }
      const requestedNavigation = /\b(abr[aei]|abrir|naveg\w*|filtr\w*|v[aá] para|ir para|mostr\w* no mapa)\b/i.test(cleanText)
      const actions = permittedActions(requestedNavigation ? result.actions : [], freshUser).filter(action => {
        const target = action.type === 'navigate' ? action.screen : ({ open_user: 'users', filter_users: 'users', filter_audit: 'auditoria', open_dashboard_occurrence: 'dashboard' })[action.type]
        return operationalContext.allowedScreens.includes(target)
      })
      applyAssistantActions(actions, requestId)
      const failed = Object.values(operationalContext.sources).filter(source => source.status === 'error').map(source => source.label)
      const sourceNote = failed.length ? `Não foi possível consultar: ${failed.join(', ')}. Erro interno no banco de dados.` : ''

      setMessages((current) => [
        ...current,
        {
          role: 'assistant',
          text: result.text || 'Nimbo não conseguiu gerar uma resposta agora.',
          sourceNote,
          accountId,
          replyToAccount: accountProfile,
          screen: currentScreen,
          screenTitle: context.title,
          sentAt: new Date().toISOString(),
        },
      ])
    } catch (err) {
      if (requestId === requestRef.current) setError(assistantError(err))
    } finally {
      if (requestId === requestRef.current) setSending(false)
    }
  }

  function handleSubmit(event) {
    event.preventDefault()
    sendToGemini(draft)
  }

  return (
    <div className="relative" data-nimbo-widget>
      <button
        ref={buttonRef}
        type="button"
        onClick={() => setOpen((value) => !value)}
        className={`w-full flex items-center gap-3 px-3 ${dense ? 'py-2' : 'py-2.5'} rounded-lg text-sm font-medium text-text-on-dark hover:bg-white/5 hover:text-white transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-white ${compact ? 'justify-center' : ''}`}
        aria-expanded={open}
        aria-label="Abrir Nimbo"
      >
        <SparkIcon />
        <span className={compact ? 'sr-only' : undefined}>Nimbo: AI</span>
      </button>

      {open && (
        <div
          ref={panelRef}
          className="fixed z-[100050] overflow-hidden rounded-3xl border border-border-soft bg-bg-surface shadow-2xl animate-slide-up flex flex-col"
          style={{
            resize: 'both',
            width: '420px',
            height: 'min(760px, calc(100vh - 5rem))',
            minWidth: '340px',
            minHeight: '430px',
            maxWidth: 'min(90vw, 760px)',
            maxHeight: 'calc(100vh - 5rem)',
            left: `${(panelPosition || getDefaultPanelPosition()).x}px`,
            top: `${(panelPosition || getDefaultPanelPosition()).y}px`,
          }}
          role="dialog"
          aria-label="Assistente Nimbo"
        >
          <div
            className="flex cursor-grab active:cursor-grabbing items-center justify-between gap-3 border-b border-border-soft px-4 py-3 bg-text-main/5 select-none"
            onPointerDown={startPanelDrag}
            onPointerMove={movePanelDrag}
            onPointerUp={endPanelDrag}
            onPointerCancel={endPanelDrag}
          >
            <button
              type="button"
              onClick={restartChat}
              className="rounded-xl border border-border-soft bg-bg-surface px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
            >
              Reiniciar chat
            </button>

            <div className="min-w-0 text-center">
              <span className="block text-[10px] font-black uppercase tracking-[0.22em] text-slate-400">
                Arraste para mover
              </span>
            </div>

            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded-lg p-2 text-slate-400 hover:bg-white/60 hover:text-slate-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main"
              aria-label="Fechar Nimbo"
            >
              ×
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-4 space-y-3" aria-live="polite">
            {messages.map((message, index) => {
              const isAssistant = message.role === 'assistant'

              return (
                <div
                  key={`${message.role}-${index}-${message.text}`}
                  className={`flex items-start gap-2 ${isAssistant ? 'justify-start' : 'justify-end'}`}
                >
                  {isAssistant && (
                    <img
                      src={assistantIcon}
                      alt=""
                      className="mt-0.5 h-8 w-8 rounded-xl border border-border-soft object-cover flex-shrink-0"
                      aria-hidden="true"
                    />
                  )}

                  <div
                    className={`max-w-[78%] rounded-2xl px-3 py-2 text-sm leading-relaxed whitespace-pre-wrap ${
                      isAssistant
                        ? 'bg-slate-100 text-slate-700 mr-3'
                        : 'bg-text-main text-white'
                    }`}
                  >
                    {renderMessageText(message.text)}
                    {message.sourceNote && <small className="block mt-2 font-semibold">{message.sourceNote}</small>}
                  </div>

                  {!isAssistant && <UserAvatar account={message.account} />}
                </div>
              )
            })}

            {sending && (
              <div className="flex items-start gap-2 justify-start">
                <img
                  src={assistantIcon}
                  alt=""
                  className="mt-0.5 h-8 w-8 rounded-xl border border-border-soft object-cover flex-shrink-0"
                  aria-hidden="true"
                />
                <div className="rounded-2xl bg-slate-100 px-3 py-2 text-sm text-slate-700 mr-3">
                  Consultando os dados disponíveis para sua conta…
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          <div className="border-t border-border-soft p-4 space-y-2">
            {!settings.promptRecommendationsDisabled && (
              <div className="grid gap-2">
                {context.suggestions.map((label) => (
                  <button
                    key={label}
                    type="button"
                    onClick={() => sendToGemini(label)}
                    disabled={sending}
                    className="w-full rounded-xl border border-border-soft bg-bg-surface px-3 py-2 text-left text-sm font-bold text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-60"
                  >
                    {label}
                  </button>
                ))}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-2 pt-2">
              <label htmlFor="smdn-ai-message" className="sr-only">
                Mensagem para Nimbo
              </label>

              <textarea
                id="smdn-ai-message"
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                placeholder="Pergunte algo sobre esta tela..."
                rows={3}
                maxLength={2500}
                disabled={sending}
                className="w-full resize-none rounded-xl border border-border-soft bg-bg-surface px-3 py-2 text-sm text-slate-700 placeholder:text-slate-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-text-main disabled:opacity-60"
              />

              {error && (
                <p
                  role="alert"
                  className="rounded-lg border border-red-100 bg-red-50 px-3 py-2 text-xs font-semibold text-red-700"
                >
                  {error}
                </p>
              )}

              <button
                type="submit"
                disabled={sending || !draft.trim()}
                className="w-full rounded-xl bg-text-main px-3 py-2 text-sm font-bold text-white hover:bg-action-hover disabled:cursor-not-allowed disabled:opacity-60"
              >
                {sending ? 'Consultando Nimbo...' : 'Enviar para Nimbo'}
              </button>
            </form>


          </div>
        </div>
      )}
    </div>
  )
}
