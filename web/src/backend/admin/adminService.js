import { supabase } from '../supabase/client.js'

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

function emptyBecauseMissingSchema() {
  return {
    data: [],
    missingSchema: true,
    message: 'Esta área administrativa ainda não está disponível. Avise o responsável pelo painel.',
  }
}

async function getCurrentUserId() {
  const { data } = await supabase.auth.getUser()
  return data?.user?.id || null
}

async function getProfileName(userId) {
  if (!userId) return 'Administrador'

  const { data } = await supabase
    .from('Perfis')
    .select('prf_nome')
    .eq('prf_id', userId)
    .maybeSingle()

  return data?.prf_nome || 'Administrador'
}

function changesToActivityList(changes = {}) {
  return Object.entries(changes).map(([key, change]) => ({
    key,
    label: change.label,
    oldValue: change.old,
    newValue: change.value ?? change.new,
  }))
}

async function safeAuditLog(payload) {
  const { error } = await supabase.from('Audit_Log').insert(payload)
  if (error && !isMissingRelationError(error)) {
    console.warn('Não foi possível registrar auditoria:', error.message)
  }
}

async function safeUserActivity(payload) {
  const { error } = await supabase.from('Atividade_Usuario').insert(payload)
  if (error && !isMissingRelationError(error)) {
    console.warn('Não foi possível registrar atividade do usuário:', error.message)
  }
}

async function syncAuthEmailByAdmin(userId, email) {
  const cleanEmail = String(email || '').trim().toLowerCase()
  if (!userId || !cleanEmail) return null

  const { data, error } = await supabase.rpc('admin_update_auth_email', {
    p_user_id: userId,
    p_new_email: cleanEmail,
  })

  if (error) {
    throw new Error('Não foi possível atualizar o e-mail de entrada. Tente novamente ou avise o responsável pelo painel.')
  }

  return data
}

async function sendPasswordResetEmail(email) {
  const cleanEmail = String(email || '').trim().toLowerCase()
  if (!cleanEmail) return null

  const { data, error } = await supabase.auth.resetPasswordForEmail(cleanEmail, {
    redirectTo: window.location.origin,
  })

  if (error) {
    throw new Error('A solicitação foi aprovada, mas não foi possível enviar o e-mail de redefinição de senha. Tente novamente ou avise o responsável pelo painel.')
  }

  return data
}

async function setUserPasswordByAdmin(userId, password) {
  const cleanPassword = String(password || '')

  if (!userId) {
    throw new Error('Usuário não encontrado para trocar a senha.')
  }

  if (cleanPassword.length < 6) {
    throw new Error('A senha precisa ter pelo menos 6 caracteres.')
  }

  const { data, error } = await supabase.rpc('admin_set_user_password', {
    p_user_id: userId,
    p_new_password: cleanPassword,
  })

  if (error) {
    throw new Error('Não foi possível trocar a senha pelo painel. Avise o responsável para aplicar a configuração de senha administrativa.')
  }

  return data
}

export async function listAccessRequests() {
  const { data, error } = await supabase
    .from('Solicitacao_Acesso_Web')
    .select('saw_id, saw_nome, saw_email, saw_instituicao, saw_cargo, saw_tipo_agente, saw_status, saw_observacao, saw_created_at, saw_reviewed_at, saw_reviewed_by')
    .order('saw_created_at', { ascending: false })

  if (error) {
    if (isMissingRelationError(error)) return emptyBecauseMissingSchema(error)
    throw error
  }

  return { data: data || [], missingSchema: false }
}

export async function listProfileChangeRequests() {
  const { data, error } = await supabase
    .from('Solicitacao_Alteracao_Perfil')
    .select('sap_id, sap_user_id, sap_nome_solicitante, sap_email_solicitante, sap_alteracoes, sap_status, sap_observacao, sap_created_at, sap_reviewed_by, sap_reviewed_at')
    .order('sap_created_at', { ascending: false })

  if (error) {
    if (isMissingRelationError(error)) return emptyBecauseMissingSchema(error)
    throw error
  }

  return { data: data || [], missingSchema: false }
}

export async function listWebProfiles() {
  const { data, error } = await supabase
    .from('Perfis')
    .select('prf_id, prf_nome, prf_tipo, prf_telefone, prf_email_contato, prf_avatar_url, prf_permissoes, prf_created_at')
    .order('prf_created_at', { ascending: false })

  if (error) {
    if (isMissingRelationError(error)) return emptyBecauseMissingSchema(error)
    throw error
  }

  return { data: data || [], missingSchema: false }
}

export async function listAuditLogs() {
  const { data, error } = await supabase
    .from('Audit_Log')
    .select('log_id, actor_user_id, action, entity_type, entity_id, detail, metadata, created_at')
    .order('created_at', { ascending: false })
    .limit(100)

  if (error) {
    if (isMissingRelationError(error)) return emptyBecauseMissingSchema(error)
    throw error
  }

  return { data: data || [], missingSchema: false }
}

export async function rejectAccessRequest(requestId, observation = '') {
  const actorUserId = await getCurrentUserId()

  const { data, error } = await supabase
    .from('Solicitacao_Acesso_Web')
    .update({
      saw_status: 'recusado',
      saw_observacao: observation || null,
      saw_reviewed_by: actorUserId,
      saw_reviewed_at: new Date().toISOString(),
    })
    .eq('saw_id', requestId)
    .select('*')
    .single()

  if (error) throw error

  await safeAuditLog({
    actor_user_id: actorUserId,
    action: 'access_request_rejected',
    entity_type: 'Solicitacao_Acesso_Web',
    entity_id: requestId,
    detail: observation || 'Solicitação de acesso recusada.',
    metadata: { reason: observation || 'Solicitação de acesso recusada.' },
  })

  return data
}

export async function approveAccessRequest(requestId) {
  const { data, error } = await supabase.functions.invoke('approve-web-access-request', {
    body: { requestId },
  })

  if (error) {
    throw new Error('A aprovação automática ainda não está disponível. Avise o responsável pelo painel.')
  }

  return data
}

function buildProfileUpdateFromChanges(changes = {}) {
  const payload = {}

  if (changes.name?.new) payload.prf_nome = changes.name.new
  if (changes.phone) payload.prf_telefone = changes.phone.new === '—' ? null : changes.phone.new
  if (changes.email?.new) payload.prf_email_contato = changes.email.new
  if (changes.avatar) payload.prf_avatar_url = changes.avatar.value || null

  return payload
}

export async function approveProfileChangeRequest(request, options = {}) {
  const actorUserId = await getCurrentUserId()
  const actorName = await getProfileName(actorUserId)
  const changes = request.sap_alteracoes || {}
  const profileUpdate = buildProfileUpdateFromChanges(changes)

  if (Object.keys(profileUpdate).length > 0) {
    const { error: profileError } = await supabase
      .from('Perfis')
      .update(profileUpdate)
      .eq('prf_id', request.sap_user_id)

    if (profileError) throw profileError
  }

  let authEmailResult = null
  if (changes.email?.new) {
    authEmailResult = await syncAuthEmailByAdmin(request.sap_user_id, changes.email.new)
  }

  let passwordUpdatedByAdmin = false
  if (changes.password) {
    if (options?.password) {
      await setUserPasswordByAdmin(request.sap_user_id, options.password)
      passwordUpdatedByAdmin = true
    } else {
      const resetTargetEmail = authEmailResult?.newEmail || changes.email?.new || request.sap_email_solicitante
      await sendPasswordResetEmail(resetTargetEmail)
    }
  }

  const passwordMessage = changes.password
    ? passwordUpdatedByAdmin
      ? ' Senha atualizada pelo painel administrativo.'
      : ' E-mail de redefinição de senha enviado para o usuário.'
    : ''

  const { data, error } = await supabase
    .from('Solicitacao_Alteracao_Perfil')
    .update({
      sap_status: 'aprovado',
      sap_observacao: `Aprovado pelo painel administrativo.${passwordMessage}`,
      sap_reviewed_by: actorUserId,
      sap_reviewed_at: new Date().toISOString(),
    })
    .eq('sap_id', request.sap_id)
    .select('*')
    .single()

  if (error) throw error

  await safeUserActivity({
    atu_user_id: request.sap_user_id,
    atu_actor_id: actorUserId,
    atu_action: 'Perfil alterado pelo administrador',
    atu_detail: `Alteração de perfil aprovada por ${actorName}.`,
    atu_metadata: {
      actorName,
      actorIsTarget: actorUserId === request.sap_user_id,
      targetName: request.sap_nome_solicitante,
      changes: changesToActivityList(changes),
    },
  })

  await safeAuditLog({
    actor_user_id: actorUserId,
    action: 'profile_change_approved',
    entity_type: 'Solicitacao_Alteracao_Perfil',
    entity_id: request.sap_id,
    detail: `Alteração de perfil aprovada para ${request.sap_nome_solicitante || request.sap_email_solicitante || request.sap_user_id}.${passwordMessage}`,
    metadata: { actorName, changes, authEmailUpdated: authEmailResult, passwordUpdatedByAdmin },
  })

  return data
}

export async function rejectProfileChangeRequest(request, observation = '') {
  const actorUserId = await getCurrentUserId()

  const { data, error } = await supabase
    .from('Solicitacao_Alteracao_Perfil')
    .update({
      sap_status: 'recusado',
      sap_observacao: observation || 'Recusado pelo painel administrativo.',
      sap_reviewed_by: actorUserId,
      sap_reviewed_at: new Date().toISOString(),
    })
    .eq('sap_id', request.sap_id)
    .select('*')
    .single()

  if (error) throw error

  const actorName = await getProfileName(actorUserId)
  const reason = observation || 'Alteração de perfil recusada.'

  await safeUserActivity({
    atu_user_id: request.sap_user_id,
    atu_actor_id: actorUserId,
    atu_action: 'Alteração recusada pelo administrador',
    atu_detail: `Solicitação de alteração recusada por ${actorName}. Motivo: ${reason}`,
    atu_metadata: {
      actorName,
      actorIsTarget: actorUserId === request.sap_user_id,
      targetName: request.sap_nome_solicitante,
      reason,
      changes: changesToActivityList(request.sap_alteracoes || {}),
    },
  })

  await safeAuditLog({
    actor_user_id: actorUserId,
    action: 'profile_change_rejected',
    entity_type: 'Solicitacao_Alteracao_Perfil',
    entity_id: request.sap_id,
    detail: reason,
    metadata: { actorName, reason, changes: request.sap_alteracoes || {} },
  })

  return data
}
