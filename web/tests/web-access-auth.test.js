import test, { mock } from 'node:test'
import assert from 'node:assert/strict'

let signUpHandler = async () => ({ data: { user: { id: 'u1' }, session: null }, error: null })
let signOutCalls = 0
let insertedPayloads = []
let rpcCalls = []

mock.module('../src/backend/supabase/client.js', {
  namedExports: {
    supabase: {
      auth: {
        signUp: (...args) => signUpHandler(...args),
        signOut: async () => {
          signOutCalls += 1
          return { error: null }
        },
        getUser: async () => ({ data: { user: { id: 'admin-1' } }, error: null }),
      },
      rpc: async (fn, params) => {
        rpcCalls.push({ fn, params })
        return { data: { ok: true }, error: null }
      },
      from: (table) => ({
        insert: async (payload) => {
          insertedPayloads.push({ table, payload })
          return { error: null }
        },
      }),
    },
  },
})

const { createWebAccessRequest } = await import('../src/backend/auth/webAccessService.js')
const { setUserPasswordByAdmin } = await import('../src/backend/admin/userAdminService.js')

test('solicitação de acesso web envia emailRedirectTo, não salva senha em texto puro e encerra sessão temporária', async () => {
  signOutCalls = 0
  insertedPayloads = []
  let capturedSignUpArgs = null

  globalThis.window = { location: { origin: 'https://prever.app' } }

  signUpHandler = async (args) => {
    capturedSignUpArgs = args
    return {
      data: {
        user: { id: 'novo-agente' },
        session: { access_token: 'temp-session' },
      },
      error: null,
    }
  }

  const result = await createWebAccessRequest({
    institution: 'Defesa Civil',
    name: ' Maria Silva ',
    email: 'MARIA@DefesaCivil.gov.br ',
    role: 'Agente Operacional',
    password: 'senhaSegura123',
  })

  assert.equal(result.created, true)
  assert.equal(capturedSignUpArgs.email, 'maria@defesacivil.gov.br')
  assert.equal(capturedSignUpArgs.options.emailRedirectTo, 'https://prever.app')
  assert.equal(capturedSignUpArgs.options.data.prf_tipo, 'pendente')
  assert.equal(signOutCalls, 1)
  assert.equal(insertedPayloads.length, 1)
  assert.equal(insertedPayloads[0].table, 'Solicitacao_Acesso_Web')
  assert.equal('password' in insertedPayloads[0].payload, false)
  assert.equal(insertedPayloads[0].payload.saw_status, 'pendente')

  delete globalThis.window
})

test('solicitação de acesso web permite conta já existente no Auth e trata rate-limit de e-mail', async () => {
  insertedPayloads = []
  signUpHandler = async () => ({
    data: { user: null, session: null },
    error: { message: 'User already registered', status: 400 },
  })

  const existing = await createWebAccessRequest({
    institution: 'Corpo de Bombeiros',
    name: 'Carlos Souza',
    email: 'carlos@bombeiros.gov.br',
    role: 'Tenente',
    password: 'senhaSegura123',
  })

  assert.equal(existing.created, true)
  assert.equal(insertedPayloads.length, 1)

  signUpHandler = async () => ({
    data: { user: null, session: null },
    error: { message: 'Email rate limit exceeded', status: 429 },
  })

  await assert.rejects(
    () =>
      createWebAccessRequest({
        institution: 'Corpo de Bombeiros',
        name: 'Carlos Souza',
        email: 'outro@bombeiros.gov.br',
        role: 'Tenente',
        password: 'senhaSegura123',
      }),
    /Muitas solicitações seguidas/
  )
})

test('troca administrativa de senha exige mínimo de 6 caracteres e registra auditoria', async () => {
  rpcCalls = []
  insertedPayloads = []

  await assert.rejects(() => setUserPasswordByAdmin('user-1', '12345'), /6 caracteres/)
  await assert.rejects(() => setUserPasswordByAdmin('', '123456'), /Usuário não encontrado/)

  const ok = await setUserPasswordByAdmin('user-1', 'novaSenha123')
  assert.equal(ok, true)
  assert.equal(rpcCalls.length, 1)
  assert.equal(rpcCalls[0].fn, 'admin_set_user_password')
  assert.equal(insertedPayloads.some((item) => item.table === 'Audit_Log'), true)
})
