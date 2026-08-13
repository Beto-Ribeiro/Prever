import { listUsersForAdmin, PERMISSION_LABELS } from '../admin/userAdminService.js'
import { getDashboardData } from '../dashboard/dashboardService.js'
import { listAuditEvents } from '../auditoria/auditService.js'
import { supabase } from '../supabase/client.js'
import {
  formatUserActivity,
  getActivityDetails,
  listUserActivities,
} from '../perfil/profileActivityService.js'

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

function compactText(value, maxLength = 500) {
  return String(value || '').trim().slice(0, maxLength)
}

function permissionSummary(permissions = {}) {
  return Object.entries(PERMISSION_LABELS).reduce((acc, [key, label]) => {
    acc[key] = {
      label,
      enabled: Boolean(permissions?.[key]),
    }
    return acc
  }, {})
}

function compactUser(user) {
  const permissions = user?.prf_permissoes || {}

  return {
    id: user?.prf_id || null,
    name: user?.prf_nome || 'Usuário sem nome',
    type: user?.prf_tipo || 'sem tipo',
    email: user?.prf_email_contato || null,
    phone: user?.prf_telefone || null,
    createdAt: user?.prf_created_at || null,
    hasAvatar: Boolean(user?.prf_avatar_url),
    permissions: permissionSummary(permissions),
    rawPermissions: permissions,
  }
}

function groupUsers(users) {
  return users.reduce((acc, user) => {
    const key = normalizeText(user.type || 'sem_tipo').replace(/\s+/g, '_') || 'sem_tipo'
    if (!acc[key]) acc[key] = []
    acc[key].push(user)
    return acc
  }, {})
}

function compactOccurrence(occurrence) {
  return {
    id: occurrence?.id || null,
    relatoId: occurrence?.relatoId || null,
    title: occurrence?.title || occurrence?.type || 'Ocorrência',
    type: occurrence?.type || null,
    severity: occurrence?.severity || null,
    riskLabel: occurrence?.riskLabel || null,
    status: occurrence?.status || null,
    city: occurrence?.city || null,
    neighborhood: occurrence?.neighborhood || null,
    citizenName: occurrence?.citizenName || null,
    reportedAt: occurrence?.reportedAt || null,
    time: occurrence?.time || null,
    description: compactText(occurrence?.description, 700),
    lat: Number.isFinite(occurrence?.lat) ? occurrence.lat : null,
    lng: Number.isFinite(occurrence?.lng) ? occurrence.lng : null,
  }
}

function compactVictim(victim) {
  return {
    id: victim?.id || null,
    name: victim?.name || 'Vítima localizada',
    assistanceStatus: victim?.assistanceStatus || 'pendente',
    source: victim?.source || null,
    updatedAt: victim?.updatedAt || null,
    lat: Number.isFinite(victim?.lat) ? victim.lat : null,
    lng: Number.isFinite(victim?.lng) ? victim.lng : null,
  }
}

function compactAuditEvent(event) {
  return {
    id: event?.id || null,
    action: event?.action || null,
    actionLabel: event?.actionLabel || null,
    type: event?.type || null,
    actor: {
      name: event?.actor?.name || null,
      email: event?.actor?.email || null,
      role: event?.actor?.role || null,
    },
    target: {
      name: event?.target?.name || null,
      email: event?.target?.email || null,
      type: event?.target?.type || event?.target?.role || null,
      id: event?.target?.id || null,
    },
    detail: compactText(event?.detail, 600),
    at: event?.at || null,
    searchText: compactText(event?.searchText, 800),
  }
}

function compactProfileActivity(activity, currentUser) {
  const details = getActivityDetails(activity, currentUser)
  const metadata = activity?.atu_metadata || {}

  return {
    id: activity?.atu_id || null,
    action: activity?.atu_action || null,
    summary: formatUserActivity(activity, currentUser),
    detail: compactText(activity?.atu_detail, 700),
    kind: metadata.kind || null,
    createdAt: activity?.atu_created_at || null,
    actor: {
      id: activity?.atu_actor_id || null,
      name:
        activity?.actorProfile?.prf_nome ||
        metadata?.actor?.name ||
        metadata?.actorName ||
        null,
      email:
        activity?.actorProfile?.prf_email_contato ||
        metadata?.actor?.email ||
        null,
    },
    sections: (details?.sections || []).map((section) => ({
      title: section.title,
      rows: (section.rows || []).map((row) => ({
        label: row.label,
        value: compactText(row.value, 500),
      })),
    })),
  }
}


function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

function profileSummary(profile, fallbackId = null) {
  if (!profile && !fallbackId) return null

  return {
    id: profile?.prf_id || fallbackId || null,
    name: profile?.prf_nome || 'Usuário sem nome',
    type: profile?.prf_tipo || null,
    email: profile?.prf_email_contato || null,
    hasAvatar: Boolean(profile?.prf_avatar_url),
  }
}

async function enrichGlobalActivitiesWithProfiles(activities) {
  const profileIds = [...new Set(
    (activities || [])
      .flatMap((activity) => [activity?.atu_actor_id, activity?.atu_user_id])
      .filter(Boolean)
  )]

  if (profileIds.length === 0) return activities || []

  const { data, error } = await supabase
    .from('Perfis')
    .select('prf_id, prf_nome, prf_email_contato, prf_avatar_url, prf_tipo')
    .in('prf_id', profileIds)

  if (error) {
    console.warn('[Nimbo] Não foi possível enriquecer histórico global com perfis:', error.message)
    return activities || []
  }

  const profileMap = new Map((data || []).map((profile) => [profile.prf_id, profile]))

  return (activities || []).map((activity) => ({
    ...activity,
    actorProfile: profileMap.get(activity.atu_actor_id) || null,
    targetProfile: profileMap.get(activity.atu_user_id) || null,
  }))
}

async function listAllActivitiesForNimbo(limit = 1000) {
  const { data, error } = await supabase
    .from('Atividade_Usuario')
    .select('atu_id, atu_user_id, atu_actor_id, atu_action, atu_detail, atu_metadata, atu_created_at')
    .order('atu_created_at', { ascending: false })
    .limit(limit)

  if (error) {
    if (isMissingRelationError(error)) return []
    throw error
  }

  return enrichGlobalActivitiesWithProfiles(data || [])
}

function getGlobalActivityKind(activity) {
  const metadata = activity?.atu_metadata || {}
  return metadata.kind || normalizeText(activity?.atu_action || 'atividade').replace(/\s+/g, '_') || 'atividade'
}

function buildGlobalCurrentUser(activity) {
  const target = activity?.targetProfile || {}

  return {
    id: activity?.atu_user_id,
    email: target?.prf_email_contato || null,
    name: target?.prf_nome || 'Usuário',
    perfil: target,
  }
}

function getGlobalActivitySummary(activity) {
  try {
    return formatUserActivity(activity, buildGlobalCurrentUser(activity))
  } catch {
    return compactText(activity?.atu_detail || activity?.atu_action || 'Atividade registrada.', 500)
  }
}

function getGlobalActivityDetails(activity) {
  try {
    const details = getActivityDetails(activity, buildGlobalCurrentUser(activity))
    return {
      title: compactText(details?.title, 200),
      sections: (details?.sections || []).map((section) => ({
        title: section.title,
        rows: (section.rows || []).map((row) => ({
          label: row.label,
          value: compactText(row.value, 500),
        })),
      })),
    }
  } catch {
    return null
  }
}

function compactGlobalActivity(activity) {
  const metadata = activity?.atu_metadata || {}
  const kind = getGlobalActivityKind(activity)
  const actor = profileSummary(activity?.actorProfile, activity?.atu_actor_id)
  const target = profileSummary(activity?.targetProfile, activity?.atu_user_id)
  const summary = getGlobalActivitySummary(activity)
  const details = getGlobalActivityDetails(activity)

  const occurrence = metadata.occurrence
    ? {
        relatoId: metadata.occurrence.relatoId || null,
        tipo: metadata.occurrence.tipo || null,
        risco: metadata.occurrence.risco || null,
        status: metadata.occurrence.status || null,
        cidadaoNome: metadata.occurrence.cidadaoNome || target?.name || null,
        dataHora: metadata.occurrence.dataHora || null,
        lat: metadata.occurrence.lat || null,
        lng: metadata.occurrence.lng || null,
      }
    : null

  const alert = metadata.alert
    ? {
        alertId: metadata.alert.alertId || null,
        tipo: metadata.alert.tipo || null,
        severidade: metadata.alert.severidade || null,
        cidade: metadata.alert.cidade || null,
        bairro: metadata.alert.bairro || null,
        status: metadata.alert.status || null,
        criadoEm: metadata.alert.criadoEm || null,
      }
    : null

  const changes = Array.isArray(metadata.changes)
    ? metadata.changes.map((change) => ({
        key: change.key || null,
        label: change.label || change.key || 'Campo',
        oldValue: compactText(change.oldValue, 250),
        newValue: compactText(change.newValue, 250),
      }))
    : []

  const searchableText = [
    activity?.atu_id,
    activity?.atu_action,
    activity?.atu_detail,
    kind,
    summary,
    actor?.name,
    actor?.email,
    actor?.type,
    target?.name,
    target?.email,
    target?.type,
    occurrence?.relatoId,
    occurrence?.tipo,
    occurrence?.risco,
    occurrence?.status,
    occurrence?.cidadaoNome,
    alert?.alertId,
    alert?.tipo,
    alert?.severidade,
    alert?.cidade,
    alert?.bairro,
    ...changes.flatMap((change) => [change.label, change.oldValue, change.newValue]),
  ]
    .filter(Boolean)
    .join(' ')

  return {
    id: activity?.atu_id || null,
    kind,
    action: activity?.atu_action || null,
    summary,
    detail: compactText(activity?.atu_detail, 900),
    createdAt: activity?.atu_created_at || null,
    target,
    actor,
    occurrence,
    alert,
    changes,
    details,
    searchText: compactText(searchableText, 1800),
  }
}

function activityMatchesQuestion(activity, question) {
  const normalizedQuestion = normalizeText(question)
  if (!normalizedQuestion) return false

  const words = normalizedQuestion
    .split(/\s+/)
    .map((word) => word.trim())
    .filter((word) => word.length >= 3)

  if (words.length === 0) return false

  const content = normalizeText(activity.searchText)
  return words.some((word) => content.includes(word))
}

function uniqueActivitiesByMeaning(activities, limit = 60) {
  const seen = new Set()
  const unique = []

  for (const activity of activities || []) {
    const key = [
      activity.kind,
      normalizeText(activity.summary),
      activity.target?.id || activity.target?.name,
      activity.occurrence?.relatoId,
      activity.alert?.alertId,
    ].filter(Boolean).join('|')

    if (seen.has(key)) continue

    seen.add(key)
    unique.push(activity)

    if (unique.length >= limit) break
  }

  return unique
}

function summarizeActivitiesByUser(activities) {
  const map = new Map()

  for (const activity of activities || []) {
    const user = activity.target || activity.actor || { id: 'sem-id', name: 'Usuário sem nome' }
    const key = user.id || user.name || 'sem-id'
    const current = map.get(key) || {
      user,
      total: 0,
      latestAt: null,
      examples: [],
    }

    current.total += 1
    current.latestAt = current.latestAt || activity.createdAt

    if (current.examples.length < 5) {
      current.examples.push({
        id: activity.id,
        summary: activity.summary,
        createdAt: activity.createdAt,
        occurrence: activity.occurrence,
        alert: activity.alert,
      })
    }

    map.set(key, current)
  }

  return [...map.values()]
    .sort((a, b) => b.total - a.total)
    .slice(0, 80)
}

function countByKind(activities) {
  return (activities || []).reduce((acc, activity) => {
    acc[activity.kind] = (acc[activity.kind] || 0) + 1
    return acc
  }, {})
}

function buildGlobalActivityHistory(activities, question) {
  const compactActivities = (activities || []).map(compactGlobalActivity)
  const occurrenceReports = compactActivities.filter((activity) => activity.kind === 'occurrence_reported')
  const webAlerts = compactActivities.filter((activity) => activity.kind === 'web_alert')
  const occurrenceUpdates = compactActivities.filter((activity) => activity.kind === 'occurrence_status')
  const logins = compactActivities.filter((activity) => activity.kind === 'login')
  const profileChanges = compactActivities.filter((activity) => {
    return !['occurrence_reported', 'web_alert', 'occurrence_status', 'login'].includes(activity.kind)
  })

  const relatedToQuestion = compactActivities
    .filter((activity) => activityMatchesQuestion(activity, question))
    .slice(0, 90)

  return {
    scope: 'global_all_accessible_history',
    note:
      'Histórico global de tudo que a sessão atual consegue consultar no Supabase. Use este bloco para perguntas sobre todos os tempos, todos os usuários, reports, relatos, alertas, auditoria e atividades gerais. Não limite ao usuário logado, exceto quando a pergunta disser claramente "meu" ou "minhas".',
    limitLoaded: 1000,
    totalLoaded: compactActivities.length,
    oldestLoadedAt: compactActivities.at(-1)?.createdAt || null,
    newestLoadedAt: compactActivities[0]?.createdAt || null,
    byKind: countByKind(compactActivities),
    recent: compactActivities.slice(0, 160),
    uniqueRecent: uniqueActivitiesByMeaning(compactActivities, 80),
    relatedToQuestion,
    allTime: {
      occurrenceReportsTotal: occurrenceReports.length,
      occurrenceReports: occurrenceReports.slice(0, 180),
      occurrenceReportsByUser: summarizeActivitiesByUser(occurrenceReports),
      webAlertsTotal: webAlerts.length,
      webAlerts: webAlerts.slice(0, 120),
      webAlertsByUser: summarizeActivitiesByUser(webAlerts),
      occurrenceUpdatesTotal: occurrenceUpdates.length,
      occurrenceUpdates: occurrenceUpdates.slice(0, 120),
      loginsTotal: logins.length,
      logins: logins.slice(0, 80),
      profileChangesTotal: profileChanges.length,
      profileChanges: profileChanges.slice(0, 120),
    },
  }
}

async function safeLoad(label, loader, fallback) {
  try {
    return await loader()
  } catch (error) {
    console.warn(`[Nimbo] Não foi possível carregar contexto de ${label}:`, error?.message || error)
    return fallback
  }
}

async function getCurrentAuthUser() {
  const { data, error } = await supabase.auth.getUser()
  if (error) throw error
  return data?.user || null
}

function findRelatedUsers(users, question) {
  const normalizedQuestion = normalizeText(question)
  if (!normalizedQuestion) return []

  return users.filter((user) => {
    const content = normalizeText([
      user.name,
      user.type,
      user.email,
      user.phone,
      user.id,
    ].filter(Boolean).join(' '))

    return content && normalizedQuestion.split(/\s+/).some((token) => token.length >= 3 && content.includes(token))
  }).slice(0, 8)
}

function buildUserSummary(users, question) {
  const compactUsers = users.map(compactUser)
  const byRole = groupUsers(compactUsers)
  const admins = compactUsers.filter((user) => ['administrador', 'admin'].includes(normalizeText(user.type)))
  const citizens = compactUsers.filter((user) => ['cidadao', 'cidada', 'citizen'].includes(normalizeText(user.type)))
  const institutions = compactUsers.filter((user) => normalizeText(user.type).includes('instituicao'))

  return {
    total: compactUsers.length,
    profiles: compactUsers,
    relatedToQuestion: findRelatedUsers(compactUsers, question),
    byRole,
    admins,
    citizens,
    institutions,
  }
}

function getOccurrencePriorityScore(occurrence) {
  const severityText = normalizeText([
    occurrence?.severity,
    occurrence?.riskLabel,
    occurrence?.description,
    occurrence?.title,
    occurrence?.type,
  ].filter(Boolean).join(' '))

  let score = 0

  if (severityText.includes('critico') || severityText.includes('crítico')) score += 50
  if (severityText.includes('grave') || severityText.includes('severo') || severityText.includes('severe')) score += 35
  if (severityText.includes('moderado') || severityText.includes('regular')) score += 15
  if (normalizeText(occurrence?.status).includes('active') || normalizeText(occurrence?.status).includes('ativo')) score += 15
  if (Number.isFinite(occurrence?.lat) && Number.isFinite(occurrence?.lng)) score += 10
  if (occurrence?.reportedAt) score += 6
  if (occurrence?.photoUrl) score += 4

  return score
}

function pickRecommendedOccurrence(recentOccurrences = []) {
  const withCoords = recentOccurrences.filter((occurrence) => Number.isFinite(occurrence?.lat) && Number.isFinite(occurrence?.lng))
  const source = withCoords.length > 0 ? withCoords : recentOccurrences

  return [...source]
    .sort((a, b) => {
      const scoreDiff = getOccurrencePriorityScore(b) - getOccurrencePriorityScore(a)
      if (scoreDiff !== 0) return scoreDiff
      return new Date(b.reportedAt || 0) - new Date(a.reportedAt || 0)
    })[0] || null
}

function buildDashboardPriority({ stats = {}, recentOccurrences = [], victims = [] }) {
  const recommendedOccurrence = pickRecommendedOccurrence(recentOccurrences)
  const checklist = []

  if (recommendedOccurrence) {
    checklist.push({
      level: 'crítica',
      label: 'Ocorrência para iniciar',
      reason: `Inicie por ${recommendedOccurrence.title || recommendedOccurrence.id}, porque ela combina maior prioridade operacional, recência, status e localização no mapa.`,
      occurrenceId: recommendedOccurrence.id,
      relatoId: recommendedOccurrence.relatoId,
      lat: recommendedOccurrence.lat,
      lng: recommendedOccurrence.lng,
    })
  }

  if (stats.criticalSeverity > 0) {
    checklist.push({
      level: 'crítica',
      label: 'Severidade crítica',
      reason: `Há ${stats.criticalSeverity} ponto(s) de severidade crítica no painel.`,
    })
  }

  if (stats.locatedVictims > 0 || victims.length > 0) {
    checklist.push({
      level: 'crítica',
      label: 'Vítimas localizadas',
      reason: `Há ${stats.locatedVictims || victims.length} vítima(s) localizada(s). Priorize confirmação e atendimento.`,
    })
  }

  if (stats.activeOccurrences > 0) {
    checklist.push({
      level: 'alta',
      label: 'Ocorrências ativas',
      reason: `Há ${stats.activeOccurrences} ocorrência(s) ativa(s). Verifique as mais recentes e críticas primeiro.`,
    })
  }

  if (stats.activeAlerts > 0) {
    checklist.push({
      level: 'atenção',
      label: 'Alertas ativos',
      reason: `Há ${stats.activeAlerts} alerta(s) ativo(s). Confira se precisam de atualização ou encerramento.`,
    })
  }

  return {
    recommendedOccurrence,
    actionSuggestion: recommendedOccurrence
      ? {
          type: 'open_dashboard_occurrence',
          id: recommendedOccurrence.id,
          relatoId: recommendedOccurrence.relatoId,
          query: recommendedOccurrence.title || recommendedOccurrence.description || recommendedOccurrence.type || '',
          mapMode: 'heat',
          zoom: 16,
          openPopup: true,
        }
      : null,
    checklist,
    answerHint:
      recommendedOccurrence
        ? 'Para responder "O que devo conferir primeiro?", recomende a ocorrência em dashboard.priority.recommendedOccurrence e inclua obrigatoriamente a action dashboard.priority.actionSuggestion.'
        : 'Se não houver ocorrência recomendada, use os cards stats.activeOccurrences, stats.criticalSeverity, stats.locatedVictims e stats.activeAlerts. Não diga que não encontrou prioridade se algum card tiver valor maior que zero.',
  }
}

function buildDashboardSummary(dashboard) {
  const stats = dashboard?.stats || {}
  const recentOccurrences = (dashboard?.recentOccurrences || []).map(compactOccurrence)
  const victims = (dashboard?.victims || []).map(compactVictim)
  const priority = buildDashboardPriority({ stats, recentOccurrences, victims })

  return {
    stats,
    visibleCards: {
      activeOccurrences: {
        label: 'Ocorrências ativas',
        value: Number(stats.activeOccurrences || 0),
      },
      activeAlerts: {
        label: 'Alertas ativos',
        value: Number(stats.activeAlerts || 0),
      },
      criticalSeverity: {
        label: 'Severidade crítica',
        value: Number(stats.criticalSeverity || 0),
      },
      resolvedToday: {
        label: 'Resolvidas hoje',
        value: Number(stats.resolvedToday || 0),
      },
      locatedVictims: {
        label: 'Vítimas localizadas',
        value: Number(stats.locatedVictims || 0),
      },
      assistedVictims: {
        label: 'Vítimas atendidas',
        value: Number(stats.assistedVictims || 0),
      },
    },
    recentOccurrences,
    victims,
    recommendedOccurrence: priority.recommendedOccurrence,
    priority,
  }
}

function buildCurrentProfileSummary({ authUser, users, activities }) {
  if (!authUser?.id) {
    return {
      user: null,
      activities: {
        total: 0,
        recent: [],
      },
    }
  }

  const currentProfile = users.find((user) => user?.prf_id === authUser.id)
  const compactProfile = currentProfile
    ? compactUser(currentProfile)
    : {
        id: authUser.id,
        name: authUser.email?.split('@')[0] || 'Usuário PREVER',
        type: 'perfil autenticado',
        email: authUser.email || null,
        phone: null,
        createdAt: authUser.created_at || null,
        hasAvatar: false,
        permissions: {},
        rawPermissions: {},
      }

  const currentUserForFormat = {
    id: authUser.id,
    email: authUser.email,
    name: compactProfile.name,
    perfil: currentProfile || null,
  }

  const compactActivities = (activities || [])
    .slice(0, 30)
    .map((activity) => compactProfileActivity(activity, currentUserForFormat))

  return {
    user: compactProfile,
    activities: {
      total: activities?.length || 0,
      recent: compactActivities,
      howToRead:
        'A lista de Atividade Recente mostra ações ligadas ao perfil atual, como login, alterações feitas por administrador, mudanças de permissões, e-mail, nome, ocorrências e alertas. Leia de cima para baixo: os primeiros itens são os mais recentes.',
    },
  }
}


function getVisibleTextFromElement(element, maxLength = 3500) {
  if (!element) return ''

  return String(element.innerText || element.textContent || '')
    .replace(/\s+\n/g, '\n')
    .replace(/\n\s+/g, '\n')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, maxLength)
}

function getActivePopupContext() {
  if (typeof document === 'undefined') return null

  const candidates = [
    { type: 'profile_activity', selector: '.profile-activity-details-panel' },
    { type: 'occurrence_modal', selector: '.modal-panel' },
    { type: 'map_popup', selector: '.maplibregl-popup-content, .leaflet-popup-content' },
  ]

  for (const candidate of candidates) {
    const elements = Array.from(document.querySelectorAll(candidate.selector))
      .filter((element) => {
        const style = window.getComputedStyle(element)
        const rect = element.getBoundingClientRect()

        return (
          style.display !== 'none' &&
          style.visibility !== 'hidden' &&
          rect.width > 20 &&
          rect.height > 20
        )
      })

    const element = elements.at(-1)
    if (!element) continue

    const text = getVisibleTextFromElement(element)
    if (!text) continue

    const titleElement = element.querySelector('h1, h2, h3, [data-ai-title], [aria-label]')
    const title =
      titleElement?.getAttribute?.('data-ai-title') ||
      titleElement?.getAttribute?.('aria-label') ||
      titleElement?.textContent ||
      text.split('\n').find(Boolean) ||
      'Pop-up aberto'

    return {
      isOpen: true,
      type: candidate.type,
      title: compactText(title, 160),
      text,
      instruction:
        'Existe um pop-up aberto na interface. Para perguntas genéricas, use este pop-up como foco principal. Não anuncie que está lendo o pop-up; responda direto ao pedido do usuário.',
    }
  }

  return null
}

function buildVisibleScreen(currentScreen) {
  if (currentScreen === 'dashboard') {
    return {
      title: 'Dashboard',
      visibleSections: [
        'Mapa de calor',
        'Pontos de ocorrência',
        'Ocorrências recentes',
        'Cards de métricas',
        'Vítimas localizadas e atendidas',
      ],
      importantInstruction:
        'Quando a pergunta for sobre o que conferir primeiro, use dashboard.priority.recommendedOccurrence, inclua action open_dashboard_occurrence e oriente que o mapa será aproximado em modo mapa de calor.',
    }
  }

  if (currentScreen === 'perfil') {
    return {
      title: 'Perfil',
      visibleSections: [
        'Cartão do usuário',
        'Permissões de acesso',
        'Atividade Recente',
        'Botões de acessibilidade e sair',
      ],
      importantInstruction:
        'Quando a pergunta for sobre atividades recentes do Perfil, use currentProfile.activities.recent antes de dizer que não encontrou informação.',
    }
  }

  return null
}

export async function buildSmdnOperationalContext({ question = '', currentScreen = '' } = {}) {
  const [dashboard, usersResult, auditEvents, authUser, allUserActivities] = await Promise.all([
    safeLoad('dashboard', () => getDashboardData(), null),
    safeLoad('usuários', () => listUsersForAdmin(), { data: [] }),
    safeLoad('auditoria', () => listAuditEvents(), []),
    safeLoad('usuário autenticado', () => getCurrentAuthUser(), null),
    safeLoad('histórico global do Nimbo', () => listAllActivitiesForNimbo(1000), []),
  ])

  const users = usersResult?.data || []
  const profileActivities = authUser?.id
    ? await safeLoad('atividades recentes do perfil', () => listUserActivities(authUser.id, 30), [])
    : []

  return {
    generatedAt: new Date().toISOString(),
    currentScreen,
    question: compactText(question, 500),
    visibleScreen: buildVisibleScreen(currentScreen),
    activePopup: getActivePopupContext(),
    globalHistory: buildGlobalActivityHistory(allUserActivities, question),
    currentProfile: buildCurrentProfileSummary({
      authUser,
      users,
      activities: profileActivities,
    }),
    dashboard: dashboard ? buildDashboardSummary(dashboard) : null,
    users: buildUserSummary(users, question),
    audit: {
      total: auditEvents.length,
      recentEvents: auditEvents.slice(0, 200).map(compactAuditEvent),
      relatedToQuestion: auditEvents
        .filter((event) => normalizeText(event.searchText || '').includes(normalizeText(question)))
        .slice(0, 50)
        .map(compactAuditEvent),
    },
  }
}
