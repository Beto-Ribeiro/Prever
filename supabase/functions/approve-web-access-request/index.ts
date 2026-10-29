import { createClient } from 'npm:@supabase/supabase-js@2.108.1'
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
const reply = (status: number, body: object) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return reply(405, { ok: false, message: 'Método não permitido.' })
  try {
    const authorization = req.headers.get('Authorization') || ''
    if (!authorization.startsWith('Bearer ')) return reply(401, { ok: false, message: 'Sua sessão expirou. Entre novamente.' })
    const url = Deno.env.get('SUPABASE_URL')!
    const client = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
    const { data: auth, error: authError } = await client.auth.getUser(authorization.slice(7))
    if (authError || !auth.user) return reply(401, { ok: false, message: 'Sua sessão expirou. Entre novamente.' })
    const { data: admin, error: roleError } = await client.rpc('is_web_admin')
    if (roleError || !admin) return reply(403, { ok: false, message: 'Acesso não autorizado.' })
    const { requestId, profileType, shelterId } = await req.json()
    if (!/^[0-9a-f-]{36}$/i.test(requestId || '') || !['funcionario', 'instituicao', 'gerente_abrigo'].includes(profileType)) return reply(400, { ok: false, message: 'Selecione uma solicitação e um perfil válidos.' })
    const { data: request, error } = await client.from('Solicitacao_Acesso_Web').select('*').eq('saw_id', requestId).single()
    if (error || !request) return reply(404, { ok: false, message: 'Solicitação não encontrada.' })
    if (request.saw_status === 'aprovado') return reply(200, { ok: true, message: 'Esta solicitação já foi aprovada.' })
    if (request.saw_status !== 'pendente') return reply(409, { ok: false, message: 'Esta solicitação já foi analisada.' })
    if (profileType === 'gerente_abrigo') {
      const { data: shelter } = await client.from('Abrigo').select('abr_id').eq('abr_id', shelterId).maybeSingle()
      if (!shelter) return reply(400, { ok: false, message: 'Selecione um abrigo válido.' })
    }
    const server = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
    const lookup = () => server.rpc('web_request_auth_user', { p_email: request.saw_email })
    const found = await lookup()
    if (found.error) throw found.error
    let targetId = found.data
    let invited = false
    if (!targetId) {
      // Uses the project's configured Site URL, never an untrusted redirect URL.
      const invitation = await server.auth.admin.inviteUserByEmail(request.saw_email, { data: { prf_nome: request.saw_nome, prf_tipo: 'pendente' } })
      if (invitation.error) {
        // A simultaneous approval may have created the account. Retry lookup, not the email.
        const retry = await lookup()
        if (!retry.error) targetId = retry.data
        if (!targetId) {
          console.error('access_invitation_failed', invitation.error.code)
          return reply(503, { ok: false, message: 'Não foi possível enviar o convite. A solicitação continua pendente. Tente novamente mais tarde.' })
        }
      } else { targetId = invitation.data.user?.id; invited = true }
    }
    if (!targetId) throw new Error('Missing target user')
    const { data: approved, error: approvalError } = await client.rpc('approve_web_access', { request_id: requestId, target_id: targetId, profile_type: profileType, shelter_id: shelterId || null })
    if (approvalError || !approved?.ok) {
      console.error('access_approval_failed', approvalError?.code)
      return reply(409, { ok: false, message: 'Não foi possível concluir a aprovação. Atualize a lista e tente novamente.' })
    }
    return reply(200, { ok: true, message: invited ? 'Acesso aprovado. Um convite foi enviado por e-mail para definir a senha.' : 'Acesso aprovado. O usuário pode entrar com sua conta; se necessário, use “Esqueci minha senha”.' })
  } catch (error) {
    console.error('access_request_error', error instanceof Error ? error.name : 'unknown')
    return reply(500, { ok: false, message: 'Erro interno no banco de dados.' })
  }
})
