import { supabase } from '../supabase/client.js'

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

const FIELD_MESSAGES = {
  name: { noun: 'nome', self: 'seu nome' },
  phone: { noun: 'telefone', self: 'seu telefone' },
  email: { noun: 'e-mail de contato', self: 'seu e-mail de contato' },
  avatar: { noun: 'avatar', self: 'seu avatar' },
  type: { noun: 'tipo de perfil', self: 'seu tipo de perfil' },
  permissions: { noun: 'permissões', self: 'suas permissões' },
}

const STATUS_LABELS = {
  active: 'Ativa',
  monitoring: 'Em monitoramento',
  resolved: 'Resolvida',
}

const ALERT_SEVERITY_LABELS = {
  critical: 'Crítico',
  severe: 'Grave',
  regular: 'Moderado',
}

function clean(value, fallback = '—') {
  const text = String(value ?? '').trim()
  return text || fallback
}

function formatDateTime(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'

  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

function shortUserAgent(userAgent = '') {
  const text = String(userAgent || '')
  if (!text) return 'Navegador não informado'
  if (text.includes('Firefox')) return 'Firefox'
  if (text.includes('Edg/')) return 'Microsoft Edge'
  if (text.includes('OPR/') || text.includes('Opera')) return 'Opera'
  if (text.includes('Chrome')) return 'Google Chrome'
  if (text.includes('Safari')) return 'Safari'
  return text.slice(0, 80)
}

function simpleHash(input) {
  let hash = 0
  const text = String(input || '')

  for (let index = 0; index < text.length; index += 1) {
    hash = ((hash << 5) - hash) + text.charCodeAt(index)
    hash |= 0
  }

  return Math.abs(hash).toString(36)
}

function buildLoginContext(userId) {
  if (typeof window === 'undefined') return {}

  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || ''
  const screenInfo = window.screen
    ? {
        width: window.screen.width,
        height: window.screen.height,
        colorDepth: window.screen.colorDepth,
      }
    : null

  const fingerprintSource = [
    navigator.userAgent,
    navigator.language,
    navigator.platform,
    timezone,
    screenInfo?.width,
    screenInfo?.height,
    screenInfo?.colorDepth,
  ].join('|')

  const fingerprint = simpleHash(fingerprintSource)
  const storageKey = `smdn-login-known:${userId}:${fingerprint}`
  const browserSeenBefore = window.localStorage?.getItem(storageKey) === '1'

  try {
    window.localStorage?.setItem(storageKey, '1')
  } catch {
    // LocalStorage pode estar bloqueado em alguns navegadores.
  }

  return {
    fingerprint,
    browserSeenBefore,
    userAgent: navigator.userAgent,
    language: navigator.language,
    platform: navigator.platform,
    timezone,
    screen: screenInfo,
  }
}

async function enrichActivitiesWithActorProfiles(activities) {
  const actorIds = [...new Set(
    (activities || [])
      .map((activity) => activity.atu_actor_id)
      .filter(Boolean)
  )]

  if (actorIds.length === 0) return activities || []

  const { data, error } = await supabase
    .from('Perfis')
    .select('prf_id, prf_nome, prf_email_contato, prf_avatar_url, prf_tipo')
    .in('prf_id', actorIds)

  if (error) {
    console.warn('Não foi possível enriquecer atividades com perfis dos atores:', error.message)
    return activities || []
  }

  const profileMap = new Map((data || []).map((profile) => [profile.prf_id, profile]))

  return (activities || []).map((activity) => ({
    ...activity,
    actorProfile: profileMap.get(activity.atu_actor_id) || null,
  }))
}

export async function listUserActivities(userId, limit = 20) {
  if (!userId) return []

  const { data, error } = await supabase
    .from('Atividade_Usuario')
    .select('atu_id, atu_user_id, atu_actor_id, atu_action, atu_detail, atu_metadata, atu_created_at')
    .eq('atu_user_id', userId)
    .order('atu_created_at', { ascending: false })
    .limit(limit)

  if (error) {
    if (isMissingRelationError(error)) return []
    throw error
  }

  return enrichActivitiesWithActorProfiles(data || [])
}

export async function recordLoginActivity(userId) {
  if (!userId) return null

  const clientContext = buildLoginContext(userId)

  const { data, error } = await supabase.rpc('record_user_login_activity', {
    client_context: clientContext,
  })

  if (error) {
    console.warn('[PREVER Auth] Não foi possível registrar login:', error.message)
    return null
  }

  return data
}

export function formatActivityDate(value) {
  if (!value) return '—'

  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

function describeSingleChange(change, viewerIsTarget, actorIsTarget, actorName) {
  const field = FIELD_MESSAGES[change?.key] || { noun: change?.label || 'perfil', self: 'seu perfil' }
  const newValue = String(change?.newValue ?? '').trim()
  const removed = !newValue || newValue === '—' || newValue === 'null'

  if (actorIsTarget) {
    if (change?.key === 'avatar' && removed) return 'Você removeu seu avatar.'
    return `Você alterou ${field.self}.`
  }

  if (viewerIsTarget) {
    if (change?.key === 'avatar' && removed) return 'Seu avatar foi retirado por um administrador.'
    return `${field.self.charAt(0).toUpperCase()}${field.self.slice(1)} foi alterado por um administrador.`
  }

  if (change?.key === 'avatar' && removed) return `${actorName} removeu o avatar deste usuário.`
  return `${actorName} alterou ${field.self}.`
}

function getActorName(activity) {
  const metadata = activity?.atu_metadata || {}
  return activity?.actorProfile?.prf_nome || metadata.actor?.name || metadata.actorName || 'Administrador'
}

export function formatUserActivity(activity, currentUser) {
  const metadata = activity?.atu_metadata || {}
  const changes = Array.isArray(metadata.changes) ? metadata.changes : []
  const actorName = getActorName(activity)
  const viewerIsTarget = currentUser?.id === activity?.atu_user_id
  const actorIsTarget = activity?.atu_actor_id && activity?.atu_actor_id === activity?.atu_user_id

  if (metadata.kind === 'login') {
    return metadata.isNewLocation ? 'Login realizado em local novo.' : 'Login realizado.'
  }

  if (metadata.kind === 'occurrence_reported') {
    const occurrence = metadata.occurrence || {}
    return `Ocorrência enviada${occurrence.tipo ? `: ${occurrence.tipo}` : ''}.`
  }

  if (metadata.kind === 'web_alert') {
    const alert = metadata.alert || {}
    const location = [alert.cidade, alert.bairro].filter(Boolean).join(' · ')
    return `Alerta disparado${alert.tipo ? `: ${alert.tipo}` : ''}${location ? ` em ${location}` : ''}.`
  }

  if (metadata.kind === 'occurrence_status') {
    const occurrence = metadata.occurrence || {}
    const status = STATUS_LABELS[occurrence.status] || occurrence.status || 'atualizado'
    return `Ocorrência atualizada para ${status}.`
  }

  if (metadata.kind === 'reset_profile') {
    if (viewerIsTarget) return 'Seu perfil de acesso foi removido por um administrador.'
    return `${actorName} removeu o perfil de acesso deste usuário.`
  }

  if (changes.length === 1) {
    return describeSingleChange(changes[0], viewerIsTarget, actorIsTarget, actorName)
  }

  if (actorIsTarget) return 'Você alterou seu perfil.'
  if (viewerIsTarget) return 'Seu perfil foi alterado por um administrador.'
  return `${actorName} alterou o perfil deste usuário.`
}

function makeRow(label, value) {
  return { label, value: clean(value) }
}

function removeReasonFromDetail(detail, reason) {
  if (!detail || !reason) return detail
  return String(detail)
    .replace(` Motivo: ${reason}`, '')
    .replace(`Motivo: ${reason}`, '')
    .trim()
}

function buildChangesRows(changes = []) {
  return changes.map((change) => ({
    label: clean(change.label || change.key, 'Campo'),
    value: `${clean(change.oldValue, '—')} → ${clean(change.newValue, '—')}`,
  }))
}

export function getActivityDetails(activity, currentUser) {
  const metadata = activity?.atu_metadata || {}
  const changes = Array.isArray(metadata.changes) ? metadata.changes : []
  const actorProfile = activity?.actorProfile || {}
  const actor = metadata.actor || {}
  const actorInfo = {
    id: activity?.atu_actor_id,
    name: actorProfile.prf_nome || actor.name || metadata.actorName || null,
    email: actorProfile.prf_email_contato || actor.email || null,
    avatar: actorProfile.prf_avatar_url || actor.avatar || null,
  }

  const detailSummary = removeReasonFromDetail(activity?.atu_detail, metadata.reason) || formatUserActivity(activity, currentUser)

  const sections = [
    {
      title: 'Registro',
      rows: [
        makeRow('Ação', activity?.atu_action),
        makeRow('Resumo', detailSummary),
        makeRow('Data', formatDateTime(activity?.atu_created_at)),
      ],
    },
  ]

  if (metadata.reason) {
    sections.push({
      title: 'Motivo da recusa',
      rows: [makeRow('Motivo', metadata.reason)],
    })
  }

  if (metadata.kind === 'login') {
    sections.push({
      title: 'Login',
      rows: [
        makeRow('IP', metadata.ip),
        makeRow('Local novo', metadata.isNewLocation ? 'Sim' : 'Não'),
        makeRow('Navegador', shortUserAgent(metadata.userAgent)),
        makeRow('Sistema/plataforma', metadata.platform),
        makeRow('Fuso horário', metadata.timezone),
        makeRow('Idioma', metadata.language),
      ],
    })
  }

  if (metadata.kind === 'occurrence_reported' || metadata.kind === 'occurrence_status') {
    const occurrence = metadata.occurrence || {}
    sections.push({
      title: 'Ocorrência',
      rows: [
        makeRow('ID do relato', occurrence.relatoId),
        makeRow('Tipo', occurrence.tipo),
        makeRow('Risco/descrição', occurrence.risco),
        makeRow('Status', STATUS_LABELS[occurrence.status] || occurrence.status),
        makeRow('Cidadão', occurrence.cidadaoNome),
        makeRow('Data do relato', formatDateTime(occurrence.dataHora)),
        makeRow('Latitude', occurrence.lat),
        makeRow('Longitude', occurrence.lng),
      ],
    })
  }

  if (metadata.kind === 'web_alert') {
    const alert = metadata.alert || {}
    sections.push({
      title: 'Alerta disparado',
      rows: [
        makeRow('ID do alerta', alert.alertId),
        makeRow('Tipo', alert.tipo),
        makeRow('Severidade', ALERT_SEVERITY_LABELS[alert.severidade] || alert.severidade),
        makeRow('Cidade', alert.cidade),
        makeRow('Bairro/área', alert.bairro),
        makeRow('Descrição', alert.descricao),
        makeRow('Destinatários', alert.destinatarios),
        makeRow('Status', alert.status),
        makeRow('Data do disparo', formatDateTime(alert.criadoEm)),
        makeRow('Latitude', alert.lat),
        makeRow('Longitude', alert.lng),
      ],
    })
  }

  if (changes.length > 0) {
    sections.push({
      title: 'Alterações',
      rows: buildChangesRows(changes),
    })
  }

  if (actorInfo.name || actorInfo.email || actorInfo.avatar) {
    sections.push({
      title: 'Responsável',
      rows: [
        makeRow('Nome', actorInfo.name),
        makeRow('E-mail', actorInfo.email),
      ],
    })
  }

  return {
    title: formatUserActivity(activity, currentUser),
    actor: actorInfo,
    sections,
  }
}
