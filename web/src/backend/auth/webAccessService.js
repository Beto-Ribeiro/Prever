import { supabase } from '../supabase/client.js'
import { canAccessAdmin, canAccessWeb, getRoleLabel, normalizeRole } from '../../utils/webRoles.js'

function isMissingRelationError(error) {
  return error?.code === '42P01' || String(error?.message || '').toLowerCase().includes('does not exist')
}

async function maybeGetSingle(table, idColumn, userId) {
  const { data, error } = await supabase
    .from(table)
    .select('*')
    .eq(idColumn, userId)
    .maybeSingle()

  if (error) {
    // Em implantação, algumas leituras podem ser bloqueadas temporariamente.
    // A gente ignora aqui para não derrubar a sessão por uma configuração incompleta.
    console.warn(`Não foi possível consultar ${table}:`, error.message)
    return null
  }

  return data
}

function buildAccessResult({ authUser, perfil, role, allowed, admin, reason }) {
  const permissions = {
    ...(perfil?.prf_permissoes || {}),
    admin,
  }
  const name = perfil?.prf_nome || authUser.email?.split('@')[0] || 'Usuário PREVER'

  if (!allowed) {
    return {
      allowed: false,
      isAdmin: false,
      profile: perfil,
      role,
      reason,
    }
  }

  return {
    allowed: true,
    isAdmin: admin,
    profile: perfil,
    role,
    user: {
      id: authUser.id,
      email: authUser.email,
      name,
      role,
      roleLabel: getRoleLabel(role),
      isAdmin: admin,
      avatar: perfil?.prf_avatar_url || null,
      permissions,
      perfil,
      funcionario: null,
      administrador: null,
      instituicao: null,
      raw: authUser,
    },
  }
}

async function getWebAccessByRpc(authUser) {
  const { data, error } = await supabase.rpc('get_my_web_access')

  if (error) {
    console.warn('[PREVER Acesso] Validação principal indisponível, usando alternativa:', error.message)
    return null
  }

  if (!data) return null

  return buildAccessResult({
    authUser,
    perfil: data.profile || null,
    role: data.role || 'unknown',
    allowed: Boolean(data.allowed),
    admin: Boolean(data.isAdmin),
    reason: data.reason || 'Seu usuário ainda não foi autorizado para acessar o painel web.',
  })
}

export async function getWebAccessForUser(authUser) {
  if (!authUser?.id) {
    return {
      allowed: false,
      isAdmin: false,
      user: null,
      reason: 'Sessão inválida.',
    }
  }

  const rpcAccess = await getWebAccessByRpc(authUser)
  if (rpcAccess) return rpcAccess

  const { data: perfil, error: perfilError } = await supabase
    .from('Perfis')
    .select('prf_id, prf_nome, prf_tipo, prf_telefone, prf_email_contato, prf_avatar_url, prf_permissoes, prf_created_at')
    .eq('prf_id', authUser.id)
    .maybeSingle()

  if (perfilError && !isMissingRelationError(perfilError)) {
    throw perfilError
  }

  const [funcionario, administrador, instituicao, cidadao] = await Promise.all([
    maybeGetSingle('Funcionario', 'fun_id', authUser.id),
    maybeGetSingle('Administrador', 'adm_id', authUser.id),
    maybeGetSingle('Instituicao', 'ins_id', authUser.id),
    maybeGetSingle('Cidadao', 'cid_id', authUser.id),
  ])

  // O tipo salvo em Perfis é a fonte principal de autorização do painel web.
  // As tabelas específicas antigas (Funcionario/Administrador/Instituicao) ficam como fallback.
  // Isso evita o bug em que um usuário alterado para administrador continuava aparecendo
  // como funcionário/sem perfil por causa de vínculo antigo em outra tabela.
  const hasProfileRole = Boolean(perfil?.prf_tipo)
  const profileRole = hasProfileRole ? normalizeRole(perfil.prf_tipo) : null

  const fallbackRole = administrador
    ? 'admin'
    : funcionario
      ? 'employee'
      : instituicao
        ? 'institution'
        : cidadao
          ? 'citizen'
          : 'unknown'

  const inferredRole = hasProfileRole ? profileRole : fallbackRole
  const allowed = canAccessWeb(inferredRole) || (!hasProfileRole && Boolean(funcionario || administrador || instituicao))
  const admin = canAccessAdmin(inferredRole) || (!hasProfileRole && Boolean(administrador))

  if (!allowed) {
    return {
      allowed: false,
      isAdmin: false,
      profile: perfil,
      reason:
        cidadao || inferredRole === 'citizen'
          ? 'Seu cadastro é de cidadão/mobile. O painel web é restrito a agentes, instituições e administradores autorizados.'
          : 'Seu usuário ainda não foi autorizado para acessar o painel web.',
    }
  }

  const name = perfil?.prf_nome || authUser.email?.split('@')[0] || 'Usuário PREVER'
  const role = inferredRole
  const permissions = {
    ...(perfil?.prf_permissoes || {}),
    admin,
  }

  return {
    allowed: true,
    isAdmin: admin,
    profile: perfil,
    role,
    user: {
      id: authUser.id,
      email: authUser.email,
      name,
      role,
      roleLabel: getRoleLabel(role),
      isAdmin: admin,
      avatar: perfil?.prf_avatar_url || null,
      permissions,
      perfil,
      funcionario,
      administrador,
      instituicao,
      raw: authUser,
    },
  }
}

export async function createWebAccessRequest({ institution, name, email, role, agentType, documentNumber, password }) {
  const payload = {
    saw_nome: name?.trim(),
    saw_email: email?.trim().toLowerCase(),
    saw_documento: documentNumber?.trim() || null,
    saw_instituicao: institution?.trim(),
    saw_cargo: role?.trim(),
    saw_tipo_agente: agentType?.trim() || role?.trim(),
    saw_status: 'pendente',
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (
    !payload.saw_nome ||
    !payload.saw_email ||
    !emailRegex.test(payload.saw_email) ||
    !payload.saw_instituicao ||
    !payload.saw_cargo ||
    String(password || '').length < 6
  ) {
    throw new Error('Preencha todos os campos obrigatórios com um e-mail válido e senha de no mínimo 6 caracteres.')
  }

  const emailRedirectTo =
    typeof window !== 'undefined' && window.location?.origin
      ? window.location.origin
      : undefined

  // A senha é cadastrada pelo Supabase Auth (hash gerenciado pelo próprio serviço),
  // nunca é gravada na tabela pública de solicitações.
  const { data: signup, error: signupError } = await supabase.auth.signUp({
    email: payload.saw_email,
    password: String(password),
    options: {
      ...(emailRedirectTo ? { emailRedirectTo } : {}),
      data: { prf_nome: payload.saw_nome, prf_tipo: 'pendente' },
    },
  })

  if (signupError) {
    const errMsg = String(signupError.message || '').toLowerCase()
    if (errMsg.includes('rate limit') || signupError.status === 429) {
      throw new Error('Muitas solicitações seguidas para envio de e-mail. Aguarde alguns instantes e tente novamente.')
    }
    const alreadyExists =
      errMsg.includes('already registered') || errMsg.includes('already been registered')
    if (!alreadyExists) {
      throw new Error('Não foi possível criar a conta com esse e-mail. Verifique o endereço informado e tente novamente.')
    }
  } else if (!signup?.user) {
    throw new Error('Não foi possível criar a conta com esse e-mail. Tente novamente.')
  }

  // Quando a confirmação de e-mail está desativada, signUp pode criar uma sessão.
  // A conta continua sem permissão web até a aprovação administrativa.
  if (signup?.session) {
    await supabase.auth.signOut()
  }

  const { error } = await supabase
    .from('Solicitacao_Acesso_Web')
    .insert(payload, { returning: 'minimal' })

  if (error) {
    if (isMissingRelationError(error)) {
      throw new Error('A solicitação de acesso ainda não está disponível. Avise o responsável pelo painel.')
    }
    const message = String(error.message || '').toLowerCase()
    if (message.includes('row level security') || message.includes('policy')) {
      throw new Error('Erro interno no banco de dados.')
    }
    throw error
  }

  return {
    created: true,
    emailConfirmationPending: Boolean(signup?.user && !signup?.session),
  }
}
