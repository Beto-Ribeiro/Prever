const DEFAULT_MESSAGE = 'Não foi possível concluir a ação agora. Tente novamente em instantes.'

function normalizeMessage(input) {
  if (!input) return ''
  if (typeof input === 'string') return input
  if (input.message) return String(input.message)
  return String(input)
}

export function toFriendlyMessage(error, fallback = DEFAULT_MESSAGE) {
  const raw = normalizeMessage(error)
  const text = raw.toLowerCase()

  if (!raw.trim()) return fallback
  if (/^(42(?!501)|XX|PGRST)/i.test(String(error?.code || '')) || /supabase|schema|postgres|database|banco de dados|não está disponível|nao esta disponivel|configuração|política pública/i.test(raw)) return 'Erro interno no banco de dados.'

  if (
    text.includes('invalid login credentials') ||
    text.includes('invalid_grant') ||
    text.includes('email or password') ||
    text.includes('credenciais inválidas')
  ) {
    return 'E-mail ou senha incorretos. Confira os dados e tente novamente.'
  }

  if (text.includes('email not confirmed') || text.includes('not confirmed')) {
    return 'Confirme seu e-mail antes de entrar no painel.'
  }

  if (
    text.includes('jwt') ||
    text.includes('refresh_token') ||
    text.includes('access_token') ||
    text.includes('token') ||
    text.includes('session') ||
    text.includes('sessão expirada') ||
    text.includes('invalid session')
  ) {
    return 'Sua sessão expirou. Entre novamente para continuar.'
  }

  if (
    text.includes('permission denied') ||
    text.includes('not authorized') ||
    text.includes('unauthorized') ||
    text.includes('forbidden') ||
    text.includes('row level security') ||
    text.includes('rls') ||
    text.includes('policy') ||
    text.includes('policies') ||
    text.includes('sem permissão') ||
    text.includes('não autorizado') ||
    text.includes('nao autorizado')
  ) {
    return 'Acesso não autorizado. Esse usuário não tem permissão para fazer essa ação.'
  }

  if (
    text.includes('duplicate') ||
    text.includes('unique') ||
    text.includes('already exists') ||
    text.includes('already registered') ||
    text.includes('já existe') ||
    text.includes('ja existe')
  ) {
    return 'Já existe um cadastro com essas informações. Confira os dados e tente novamente.'
  }

  if (
    text.includes('failed to fetch') ||
    text.includes('network') ||
    text.includes('timeout') ||
    text.includes('load failed') ||
    text.includes('fetch failed')
  ) {
    return 'Falha de conexão. Verifique sua internet e tente novamente.'
  }

  if (
    text.includes('bucket') ||
    text.includes('storage') ||
    text.includes('object not found')
  ) {
    return 'Não foi possível salvar ou carregar a imagem. Tente novamente.'
  }

  if (
    text.includes('supabase') ||
    text.includes('edge function') ||
    text.includes('rpc') ||
    text.includes('schema') ||
    text.includes('sql') ||
    text.includes('backend') ||
    text.includes('postgres') ||
    text.includes('42p01') ||
    text.includes('does not exist') ||
    text.includes('vite_') ||
    text.includes('env') ||
    text.includes('database') ||
    text.includes('function')
  ) {
    return 'Erro interno no banco de dados.'
  }

  if (text.includes('invalid') || text.includes('inválid') || text.includes('invalido')) {
    return 'Alguma informação parece inválida. Confira os campos e tente novamente.'
  }

  if (raw.length > 180 || /[{}[\]_;]/.test(raw)) return fallback

  return /^[A-ZÀ-Ú]/.test(raw) && /[ãõáéíóúçêôà]|^(Informe|Selecione|Preencha|Esta |Este |Seu |Sua |Nenhum|Nenhuma|A |O )/.test(raw) ? raw : fallback
}

export function supportMessage(context = 'esta ação') {
  return `Não foi possível concluir ${context}. Tente novamente ou avise o responsável pelo painel.`
}
