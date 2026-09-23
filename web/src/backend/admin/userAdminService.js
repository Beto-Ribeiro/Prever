import { supabase } from '../supabase/client.js'
import { formatBrazilPhone } from '../../utils/phone.js'

export const DEFAULT_PERMISSIONS = {
  ocupantes: false,
  estoque: false,
  pedidos: false,
  dashboard: true,
  reportar: true,
  ocorrencias: true,
  relatorios: true,
  auditoria: false,
  admin: false,
}

export const PERMISSION_LABELS = {
  ocupantes: 'Ocupantes do abrigo',
  estoque: 'Estoque do abrigo',
  pedidos: 'Pedidos de ajuda do abrigo',
  dashboard: 'Dashboard',
  reportar: 'Reportar / Disparar Alertas',
  ocorrencias: 'Gerenciar Ocorrências',
  relatorios: 'Relatórios Analíticos',
  auditoria: 'Auditoria',
  admin: 'Administração de Usuários',
}

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

function normalize(value) {
  return String(value ?? '').trim()
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

function getActorInfo(actorUser, actorUserId, actorName) {
  return {
    id: actorUserId || null,
    name: actorName || actorUser?.name || actorUser?.email || 'Administrador',
    email: actorUser?.contactEmail || actorUser?.perfil?.prf_email_contato || actorUser?.email || null,
    avatar: actorUser?.avatar || actorUser?.perfil?.prf_avatar_url || null,
    role: actorUser?.roleLabel || actorUser?.role || null,
  }
}

function normalizeProfileType(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

function isAdminType(value) {
  const normalizedType = normalizeProfileType(value)
  return normalizedType === 'administrador' || normalizedType === 'admin'
}

function isBlockedWebType(value) {
  const normalizedType = normalizeProfileType(value)
  return ['pendente', 'sem perfil', 'semperfil', 'cidadao', 'cidada', 'citizen', 'unknown'].includes(normalizedType)
}

function permissionsWithDefaults(value) {
  return { ...DEFAULT_PERMISSIONS, ...(value || {}) }
}

function permissionsForRole(value, profileType) {
  if (['gerente_abrigo', 'shelter_manager'].includes(normalizeProfileType(profileType))) return { dashboard: true, ocupantes: true, estoque: true, pedidos: true, relatorios: true, reportar: false, ocorrencias: false, auditoria: false, admin: false }
  const permissions = permissionsWithDefaults(value)

  if (isBlockedWebType(profileType)) {
    return Object.keys(DEFAULT_PERMISSIONS).reduce((acc, key) => ({ ...acc, [key]: false }), {})
  }

  if (isAdminType(profileType)) {
    return Object.keys(DEFAULT_PERMISSIONS).reduce((acc, key) => ({ ...acc, [key]: true }), {})
  }

  return {
    ...permissions,
    admin: false,
  }
}

function makeAdminAlias(name, fallbackId) {
  const base = normalize(name)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')

  return `${base || String(fallbackId || 'admin').slice(0, 8)}-admin`
}

async function syncAuthEmailByAdmin({ userId, email }) {
  const cleanEmail = normalize(email).toLowerCase()
  if (!userId || !cleanEmail) return null

  const { data, error } = await supabase.rpc('admin_update_auth_email', {
    p_user_id: userId,
    p_new_email: cleanEmail,
  })

  if (error) {
    throw new Error('Perfil salvo, mas não foi possível alterar o e-mail de entrada. Tente novamente ou avise o responsável pelo painel.')
  }

  return data
}

async function syncAdministratorBinding({ userId, profileType, name }) {
  const normalizedType = normalizeProfileType(profileType)

  if (normalizedType === 'administrador' || normalizedType === 'admin') {
    const { error } = await supabase
      .from('Administrador')
      .upsert(
        {
          adm_id: userId,
          adm_apelido: makeAdminAlias(name, userId),
        },
        { onConflict: 'adm_id' }
      )

    if (error && !isMissingRelationError(error)) {
      throw error
    }

    return
  }

  const { error } = await supabase
    .from('Administrador')
    .delete()
    .eq('adm_id', userId)

  if (error && !isMissingRelationError(error)) {
    throw error
  }
}

function makeChange(key, label, oldValue, newValue) {
  return {
    key,
    label,
    oldValue: oldValue ?? null,
    newValue: newValue ?? null,
  }
}

function buildChanges(before, after) {
  const changes = []

  if (normalize(before.prf_nome) !== normalize(after.prf_nome)) {
    changes.push(makeChange('name', 'Nome', before.prf_nome || '—', after.prf_nome || '—'))
  }

  if (normalize(before.prf_tipo) !== normalize(after.prf_tipo)) {
    changes.push(makeChange('type', 'Tipo de perfil', before.prf_tipo || '—', after.prf_tipo || '—'))
  }

  if (normalize(before.prf_email_contato) !== normalize(after.prf_email_contato)) {
    changes.push(makeChange('email', 'E-mail de contato', before.prf_email_contato || '—', after.prf_email_contato || '—'))
  }

  if (normalize(before.prf_telefone) !== normalize(after.prf_telefone)) {
    changes.push(makeChange('phone', 'Telefone', before.prf_telefone || '—', after.prf_telefone || '—'))
  }

  if (normalize(before.prf_avatar_url) !== normalize(after.prf_avatar_url)) {
    changes.push(makeChange('avatar', 'Avatar', before.prf_avatar_url ? 'Foto anterior' : '—', after.prf_avatar_url ? 'Nova foto' : '—'))
  }

  const beforePermissions = JSON.stringify(permissionsWithDefaults(before.prf_permissoes))
  const afterPermissions = JSON.stringify(permissionsWithDefaults(after.prf_permissoes))
  if (beforePermissions !== afterPermissions) {
    changes.push(makeChange('permissions', 'Permissões', 'Permissões anteriores', 'Permissões atualizadas'))
  }

  return changes
}

export async function listUsersForAdmin() {
  const { data, error } = await supabase
    .from('Perfis')
    .select('prf_id, prf_nome, prf_tipo, prf_telefone, prf_email_contato, prf_avatar_url, prf_permissoes, prf_created_at')
    .order('prf_nome', { ascending: true })

  if (error) {
    if (isMissingRelationError(error)) {
      return { data: [], missingSchema: true }
    }
    throw error
  }

  return { data: data || [], missingSchema: false }
}

export async function updateUserProfileByAdmin({ user, form, actorUser }) {
  if (!user?.prf_id) throw new Error('Usuário inválido para edição.')

  const actorUserId = await getCurrentUserId()
  const actorName = actorUser?.name || await getProfileName(actorUserId)
  const payload = {
    prf_nome: normalize(form.name),
    prf_tipo: normalize(form.type) || null,
    prf_email_contato: normalize(form.email).toLowerCase() || null,
    prf_telefone: formatBrazilPhone(form.phone) || null,
    prf_avatar_url: normalize(form.avatarUrl) || null,
    prf_permissoes: permissionsForRole(form.permissions, form.type),
  }

  const before = {
    prf_nome: user.prf_nome,
    prf_tipo: user.prf_tipo,
    prf_email_contato: user.prf_email_contato,
    prf_telefone: user.prf_telefone,
    prf_avatar_url: user.prf_avatar_url,
    prf_permissoes: permissionsWithDefaults(user.prf_permissoes),
  }

  const { data, error } = await supabase
    .from('Perfis')
    .update(payload)
    .eq('prf_id', user.prf_id)
    .select('prf_id, prf_nome, prf_tipo, prf_telefone, prf_email_contato, prf_avatar_url, prf_permissoes, prf_created_at')
    .single()

  if (error) throw error

  await syncAdministratorBinding({
    userId: user.prf_id,
    profileType: data.prf_tipo,
    name: data.prf_nome,
  })

  if (normalize(before.prf_email_contato).toLowerCase() !== normalize(data.prf_email_contato).toLowerCase() && data.prf_email_contato) {
    await syncAuthEmailByAdmin({ userId: user.prf_id, email: data.prf_email_contato })
  }

  const changes = buildChanges(before, data)
  const detail = actorUserId === user.prf_id
    ? 'Usuário alterou o próprio perfil.'
    : `${actorName} alterou o perfil de ${data.prf_nome || user.prf_id}.`

  const activityPayload = {
    atu_user_id: user.prf_id,
    atu_actor_id: actorUserId,
    atu_action: actorUserId === user.prf_id ? 'Perfil alterado pelo próprio usuário' : 'Perfil alterado pelo administrador',
    atu_detail: detail,
    atu_metadata: {
      actorName,
      actor: getActorInfo(actorUser, actorUserId, actorName),
      actorIsTarget: actorUserId === user.prf_id,
      targetName: data.prf_nome,
      changes,
    },
  }

  const { error: activityError } = await supabase
    .from('Atividade_Usuario')
    .insert(activityPayload)

  if (activityError && !isMissingRelationError(activityError)) {
    console.warn('Não foi possível registrar atividade do usuário:', activityError.message)
  }

  const { error: auditError } = await supabase
    .from('Audit_Log')
    .insert({
      actor_user_id: actorUserId,
      action: 'admin_updated_user_profile',
      entity_type: 'Perfis',
      entity_id: user.prf_id,
      detail,
      metadata: { actorName, actor: getActorInfo(actorUser, actorUserId, actorName), before, after: data, changes },
    })

  if (auditError && !isMissingRelationError(auditError)) {
    console.warn('Não foi possível registrar auditoria:', auditError.message)
  }

  return data
}

export async function resetUserProfileByAdmin(user) {
  if (!user?.prf_id) throw new Error('Usuário inválido para zerar perfil.')

  const { error } = await supabase.rpc('admin_reset_user_profile', {
    target_user_id: user.prf_id,
  })

  if (error) throw error

  return true
}
