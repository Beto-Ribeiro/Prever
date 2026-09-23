import { supabase } from '../supabase/client.js'
import { formatUserActivity } from '../perfil/profileActivityService.js'

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
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

function mapAuditType(action = '') {
  const normalized = String(action || '').toLowerCase()
  if (normalized.includes('profile') || normalized.includes('perfil')) return 'profile'
  if (normalized.includes('access') || normalized.includes('login') || normalized.includes('auth')) return 'auth'
  if (normalized.includes('alert') || normalized.includes('alerta')) return 'alert'
  return 'record'
}

function actionLabel(action = '') {
  const labels = {
    admin_updated_user_profile: 'Perfil Editado',
    admin_reset_user_profile: 'Perfil Removido',
    profile_change_approved: 'Perfil Aprovado',
    profile_change_rejected: 'Perfil Recusado',
    access_request_rejected: 'Acesso recusado',
    access_request_approved: 'Acesso aprovado',
    occurrence_status_updated: 'Ocorrência Atualizada',
    ALERTA_DISPARADO: 'Alerta Disparado',
  }

  return labels[action] || action || 'Registro'
}

function roleLabel(value) {
  const role = String(value || '').toLowerCase()
  const labels = {
    administrador: 'Administrador',
    funcionario: 'Funcionário',
    instituicao: 'Instituição',
    cidadao: 'Cidadão',
    pendente: 'Sem perfil',
    gerente_abrigo: 'Gerente de Abrigo',
    shelter_manager: 'Gerente de Abrigo',
  }
  return labels[role] || value || 'Sistema'
}

function row(label, value) {
  return { label, value: clean(value) }
}

function profileToPerson(profile, fallback = {}) {
  return {
    id: profile?.prf_id || fallback.id || null,
    name: profile?.prf_nome || fallback.name || fallback.email || 'Sistema',
    email: profile?.prf_email_contato || fallback.email || null,
    avatar: profile?.prf_avatar_url || fallback.avatar || null,
    role: roleLabel(profile?.prf_tipo || fallback.role),
  }
}

function normalizeChanges(changes) {
  if (!changes) return []

  if (Array.isArray(changes)) {
    return changes.map((change, index) => {
      if (typeof change === 'string') {
        return { label: `Alteração ${index + 1}`, oldValue: '—', newValue: change }
      }
      return {
        label: change?.label || change?.key || `Alteração ${index + 1}`,
        oldValue: change?.oldValue ?? change?.old ?? '—',
        newValue: change?.newValue ?? change?.new ?? change?.value ?? '—',
      }
    })
  }

  if (typeof changes === 'object') {
    return Object.entries(changes).map(([key, change]) => ({
      label: change?.label || key,
      oldValue: change?.oldValue ?? change?.old ?? '—',
      newValue: change?.newValue ?? change?.new ?? change?.value ?? '—',
    }))
  }

  return []
}

function changesSection(changes) {
  const rows = normalizeChanges(changes).map((change) => row(change.label, `${clean(change.oldValue)} → ${clean(change.newValue)}`))
  if (rows.length === 0) return null
  return { title: 'Alterações', rows }
}

async function safeSelect(promise, fallback = []) {
  const { data, error } = await promise
  if (error) {
    if (isMissingRelationError(error)) return fallback
    throw error
  }
  return data || fallback
}

function makeDetails({ actor, target, registerRows = [], extraSections = [] }) {
  const sections = [
    {
      title: 'Responsável pela ação',
      rows: [
        row('Nome', actor?.name),
        row('E-mail', actor?.email),
        row('Perfil', actor?.role),
      ],
    },
  ]

  if (target?.name || target?.email || target?.type) {
    sections.push({
      title: 'Afetado / alvo',
      rows: [
        row('Nome', target?.name),
        row('E-mail', target?.email),
        row('Tipo', target?.type || target?.role),
        row('ID', target?.id),
      ],
    })
  }

  if (registerRows.length > 0) {
    sections.push({ title: 'Registro', rows: registerRows })
  }

  for (const section of extraSections) {
    if (section?.rows?.length) sections.push(section)
  }

  return sections
}

async function fetchProfileMap(ids) {
  const uniqueIds = [...new Set(ids.filter(Boolean))]
  if (uniqueIds.length === 0) return new Map()

  const profiles = await safeSelect(
    supabase
      .from('Perfis')
      .select('prf_id, prf_nome, prf_tipo, prf_email_contato, prf_avatar_url')
      .in('prf_id', uniqueIds)
  )

  return new Map(profiles.map((profile) => [profile.prf_id, profile]))
}

async function fetchAccessRequestMap(ids) {
  const uniqueIds = [...new Set(ids.filter(Boolean))]
  if (uniqueIds.length === 0) return new Map()

  const rows = await safeSelect(
    supabase
      .from('Solicitacao_Acesso_Web')
      .select('saw_id, saw_nome, saw_email, saw_instituicao, saw_cargo, saw_tipo_agente, saw_status, saw_observacao, saw_created_at, saw_reviewed_at, saw_reviewed_by')
      .in('saw_id', uniqueIds)
  )

  return new Map(rows.map((item) => [item.saw_id, item]))
}

async function fetchProfileChangeRequestMap(ids) {
  const uniqueIds = [...new Set(ids.filter(Boolean))]
  if (uniqueIds.length === 0) return new Map()

  const rows = await safeSelect(
    supabase
      .from('Solicitacao_Alteracao_Perfil')
      .select('sap_id, sap_user_id, sap_nome_solicitante, sap_email_solicitante, sap_alteracoes, sap_status, sap_observacao, sap_created_at, sap_reviewed_at, sap_reviewed_by')
      .in('sap_id', uniqueIds)
  )

  return new Map(rows.map((item) => [item.sap_id, item]))
}

function makeSearchText(entry) {
  return [
    entry.action,
    entry.actionLabel,
    entry.actor?.name,
    entry.actor?.email,
    entry.target?.name,
    entry.target?.email,
    entry.detail,
    entry.role,
  ].filter(Boolean).join(' ').toLowerCase()
}

export async function listAuditEvents() {
  const [alerts, auditLogs, activities] = await Promise.all([
    safeSelect(
      supabase
        .from('Alerta_Web')
        .select('alw_id, alw_tipo, alw_cidade, alw_bairro, alw_severidade, alw_descricao, alw_destinatarios, alw_operador_id, alw_operador_nome, alw_status, alw_lat, alw_lng, alw_created_at')
        .order('alw_created_at', { ascending: false })
        .limit(200)
    ),
    safeSelect(
      supabase
        .from('Audit_Log')
        .select('log_id, actor_user_id, action, entity_type, entity_id, detail, metadata, created_at')
        .order('created_at', { ascending: false })
        .limit(200)
    ),
    safeSelect(
      supabase
        .from('Atividade_Usuario')
        .select('atu_id, atu_user_id, atu_actor_id, atu_action, atu_detail, atu_metadata, atu_created_at')
        .order('atu_created_at', { ascending: false })
        .limit(200)
    ),
  ])

  const profileIds = [
    ...alerts.map((alert) => alert.alw_operador_id),
    ...auditLogs.map((log) => log.actor_user_id),
    ...auditLogs.filter((log) => log.entity_type === 'Perfis').map((log) => log.entity_id),
    ...activities.map((activity) => activity.atu_actor_id),
    ...activities.map((activity) => activity.atu_user_id),
  ]

  const accessRequestIds = auditLogs
    .filter((log) => log.entity_type === 'Solicitacao_Acesso_Web')
    .map((log) => log.entity_id)

  const profileChangeRequestIds = auditLogs
    .filter((log) => log.entity_type === 'Solicitacao_Alteracao_Perfil')
    .map((log) => log.entity_id)

  const [profileMap, accessRequestMap, profileChangeRequestMap] = await Promise.all([
    fetchProfileMap(profileIds),
    fetchAccessRequestMap(accessRequestIds),
    fetchProfileChangeRequestMap(profileChangeRequestIds),
  ])

  const alertEvents = alerts.map((alert) => {
    const actor = profileToPerson(profileMap.get(alert.alw_operador_id), {
      id: alert.alw_operador_id,
      name: alert.alw_operador_nome,
      role: 'Painel Web',
    })
    const target = {
      id: alert.alw_id,
      name: `${alert.alw_tipo} em ${alert.alw_cidade}`,
      email: null,
      type: 'Alerta Web',
    }

    const entry = {
      id: `alert-${alert.alw_id}`,
      action: 'ALERTA_DISPARADO',
      actionLabel: 'Alerta Disparado',
      actor,
      target,
      user: actor.name,
      role: 'Painel Web',
      detail: `Disparou alerta de ${alert.alw_tipo} para ${alert.alw_cidade}${alert.alw_bairro ? ` / ${alert.alw_bairro}` : ''}.`,
      at: alert.alw_created_at,
      ip: 'web',
      type: 'alert',
      details: makeDetails({
        actor,
        target,
        registerRows: [
          row('Data', formatDateTime(alert.alw_created_at)),
          row('Destinatários', (alert.alw_destinatarios || 0).toLocaleString('pt-BR')),
          row('Status', alert.alw_status),
        ],
        extraSections: [{
          title: 'Alerta',
          rows: [
            row('Tipo', alert.alw_tipo),
            row('Cidade', alert.alw_cidade),
            row('Bairro/área', alert.alw_bairro),
            row('Severidade', alert.alw_severidade),
            row('Descrição', alert.alw_descricao),
            row('Latitude', alert.alw_lat),
            row('Longitude', alert.alw_lng),
          ],
        }],
      }),
    }
    return { ...entry, searchText: makeSearchText(entry) }
  })

  const auditEvents = auditLogs.map((log) => {
    const metadata = log.metadata || {}
    const actor = profileToPerson(profileMap.get(log.actor_user_id), {
      id: log.actor_user_id,
      name: metadata.actor?.name || metadata.actorName || 'Administrador',
      email: metadata.actor?.email,
      avatar: metadata.actor?.avatar,
      role: metadata.actor?.role || 'Administrador',
    })

    let target = {
      id: log.entity_id,
      name: metadata.targetName || metadata.after?.prf_nome || profileMap.get(log.entity_id)?.prf_nome || log.entity_id,
      email: metadata.after?.prf_email_contato || profileMap.get(log.entity_id)?.prf_email_contato || null,
      avatar: metadata.after?.prf_avatar_url || profileMap.get(log.entity_id)?.prf_avatar_url || null,
      type: log.entity_type || 'Sistema',
    }

    const extraSections = []
    let detail = log.detail || 'Registro administrativo.'

    if (log.entity_type === 'Solicitacao_Acesso_Web') {
      const request = accessRequestMap.get(log.entity_id)
      if (request) {
        target = {
          id: request.saw_id,
          name: request.saw_nome || request.saw_email,
          email: request.saw_email,
          type: 'Solicitação de acesso web',
        }
        detail = log.action === 'access_request_approved'
          ? `A solicitação de ${target.name} foi aprovada. O acesso ao painel foi liberado.`
          : log.action === 'access_request_rejected'
            ? `A solicitação de acesso de ${target.name} foi recusada.`
            : `${actionLabel(log.action)}: ${target.name}.`
        extraSections.push({
          title: 'Solicitação de acesso',
          rows: [
            row('Nome', request.saw_nome),
            row('E-mail', request.saw_email),
            row('Instituição', request.saw_instituicao),
            row('Cargo/tipo', request.saw_tipo_agente || request.saw_cargo),
            row('Status', request.saw_status),
            row('Observação', request.saw_observacao),
            row('Solicitado em', formatDateTime(request.saw_created_at)),
            row('Revisado em', formatDateTime(request.saw_reviewed_at)),
          ],
        })
      }
    }

    if (log.entity_type === 'Solicitacao_Alteracao_Perfil') {
      const request = profileChangeRequestMap.get(log.entity_id)
      if (request) {
        target = {
          id: request.sap_user_id || request.sap_id,
          name: request.sap_nome_solicitante || request.sap_email_solicitante,
          email: request.sap_email_solicitante,
          type: 'Solicitação de alteração de perfil',
        }
        extraSections.push({
          title: 'Solicitação de perfil',
          rows: [
            row('Nome', request.sap_nome_solicitante),
            row('E-mail', request.sap_email_solicitante),
            row('Status', request.sap_status),
            row('Observação', request.sap_observacao),
            row('Solicitado em', formatDateTime(request.sap_created_at)),
            row('Revisado em', formatDateTime(request.sap_reviewed_at)),
          ],
        })
      }
    }

    const changes = changesSection(metadata.changes)
    if (changes) extraSections.push(changes)

    const entry = {
      id: `audit-${log.log_id}`,
      action: log.action,
      actionLabel: actionLabel(log.action),
      actor,
      target,
      user: actor.name,
      role: ({ Solicitacao_Acesso_Web: 'Solicitação de acesso', Solicitacao_Alteracao_Perfil: 'Alteração de perfil', Perfis: 'Perfil', Abrigo: 'Abrigo' })[log.entity_type] || 'Registro do sistema',
      detail,
      at: log.created_at,
      ip: 'web',
      type: mapAuditType(log.action),
      details: makeDetails({
        actor,
        target,
        registerRows: [
          row('Ação técnica', log.action),
          row('Entidade', log.entity_type),
          row('Data', formatDateTime(log.created_at)),
          row('Detalhe', detail),
        ],
        extraSections,
      }),
    }

    return { ...entry, searchText: makeSearchText(entry) }
  })

  const activityEvents = activities.map((activity) => {
    const metadata = activity.atu_metadata || {}
    const actor = profileToPerson(profileMap.get(activity.atu_actor_id), {
      id: activity.atu_actor_id,
      name: metadata.actor?.name || metadata.actorName || 'Sistema',
      email: metadata.actor?.email,
      avatar: metadata.actor?.avatar,
      role: metadata.actor?.role,
    })
    const target = profileToPerson(profileMap.get(activity.atu_user_id), {
      id: activity.atu_user_id,
      name: metadata.targetName,
      role: 'Perfil',
    })

    const changes = changesSection(metadata.changes)
    const entry = {
      id: `activity-${activity.atu_id}`,
      action: activity.atu_action,
      actionLabel: activity.atu_action || 'Atividade de Perfil',
      actor,
      target: { ...target, type: 'Perfil de usuário' },
      user: actor.name,
      role: 'Perfil',
      detail: formatUserActivity(activity, { id: activity.atu_actor_id }),
      at: activity.atu_created_at,
      ip: metadata.ip || 'web',
      type: metadata.kind === 'login' ? 'auth' : 'profile',
      details: makeDetails({
        actor,
        target: { ...target, type: 'Perfil de usuário' },
        registerRows: [
          row('Ação', activity.atu_action),
          row('Data', formatDateTime(activity.atu_created_at)),
          row('Detalhe', activity.atu_detail || formatUserActivity(activity, { id: activity.atu_actor_id })),
          row('IP', metadata.ip),
          row('Local novo', metadata.isNewLocation === true ? 'Sim' : metadata.isNewLocation === false ? 'Não' : null),
        ],
        extraSections: changes ? [changes] : [],
      }),
    }

    return { ...entry, searchText: makeSearchText(entry) }
  })

  return [...alertEvents, ...auditEvents, ...activityEvents]
    .sort((a, b) => new Date(b.at || 0) - new Date(a.at || 0))
}
