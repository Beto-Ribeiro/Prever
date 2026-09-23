// Esqueleto opcional para uma Edge Function futura: approve-web-access-request
// NÃO está deployado. NÃO colocar service_role no frontend.
// Esta função deve rodar no Supabase Edge Functions, com SUPABASE_SERVICE_ROLE_KEY no ambiente seguro.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 })
  }

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const {
    data: { user: caller },
    error: callerError,
  } = await supabaseUser.auth.getUser()

  if (callerError || !caller) {
    return new Response(JSON.stringify({ error: 'Invalid caller' }), { status: 401 })
  }

  const { data: adminProfile } = await supabaseAdmin
    .from('Administrador')
    .select('adm_id')
    .eq('adm_id', caller.id)
    .maybeSingle()

  if (!adminProfile) {
    return new Response(JSON.stringify({ error: 'Only administrators can approve requests' }), { status: 403 })
  }

  const { requestId } = await req.json()

  const { data: request, error: requestError } = await supabaseAdmin
    .from('Solicitacao_Acesso_Web')
    .select('*')
    .eq('saw_id', requestId)
    .eq('saw_status', 'pendente')
    .single()

  if (requestError || !request) {
    return new Response(JSON.stringify({ error: 'Request not found or already reviewed' }), { status: 404 })
  }

  // Estratégia recomendada:
  // 1. Convide o usuário por email OU crie o usuário com senha temporária.
  // 2. Insira em Perfis com prf_tipo = funcionario/instituicao/admin conforme regra.
  // 3. Insira em Funcionario ou Instituicao conforme o tipo aprovado.
  // 4. Marque a solicitação como aprovada.
  // 5. Grave Audit_Log.

  const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
    request.saw_email
  )

  if (inviteError) {
    return new Response(JSON.stringify({ error: inviteError.message }), { status: 400 })
  }

  const newUserId = inviteData.user?.id

  if (!newUserId) {
    return new Response(JSON.stringify({ error: 'Could not create auth user' }), { status: 400 })
  }

  await supabaseAdmin.from('Perfis').upsert({
    prf_id: newUserId,
    prf_nome: request.saw_nome,
    prf_tipo: 'funcionario',
  })

  await supabaseAdmin.from('Funcionario').upsert({
    fun_id: newUserId,
    fun_cargo: request.saw_cargo || request.saw_tipo_agente || 'Agente autorizado',
  })

  await supabaseAdmin
    .from('Solicitacao_Acesso_Web')
    .update({
      saw_status: 'aprovado',
      saw_reviewed_by: caller.id,
      saw_reviewed_at: new Date().toISOString(),
    })
    .eq('saw_id', requestId)

  await supabaseAdmin.from('Audit_Log').insert({
    actor_user_id: caller.id,
    action: 'approve_web_access_request',
    entity_type: 'Solicitacao_Acesso_Web',
    entity_id: requestId,
    detail: `Solicitação aprovada para ${request.saw_email}`,
  })

  return new Response(JSON.stringify({ success: true, userId: newUserId }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
