import assert from 'node:assert/strict'
import test, { mock } from 'node:test'

let mockRpcImpl = async () => ({ data: null, error: null })
let mockUpdatePayload = null
let mockCreateSignedUrlsCalls = 0

mock.module('../src/backend/supabase/client.js', {
  namedExports: {
    supabase: {
      auth: {
        getUser: async () => ({ data: { user: { id: 'admin-uuid-1' } }, error: null }),
      },
      storage: {
        from: () => ({
          createSignedUrls: async (paths) => {
            mockCreateSignedUrlsCalls += 1
            return {
              data: paths.map((path) => ({ path, signedUrl: `https://signed.local/${path}` })),
              error: null,
            }
          },
          createSignedUrl: async (path) => ({
            data: { signedUrl: `https://signed.local/${path}` },
            error: null,
          }),
        }),
      },
      rpc: async (name, args) => mockRpcImpl(name, args),
      from: () => ({
        select: () => ({
          eq: () => ({
            order: async () => ({
              data: [
                {
                  rel_id: 'rel-1',
                  rel_tipo_desastre: 'Enchente',
                  rel_descricao: 'Água subindo',
                  rel_gravidade: 'Severa',
                  rel_data_hora: '2026-11-24T12:00:00Z',
                  rel_fraud_score: 0.32,
                  rel_fraud_reason: 'Foto escura',
                  Foto: [{ fto_url: 'relatos/foto1.jpg' }],
                },
                {
                  rel_id: 'rel-2',
                  rel_tipo_desastre: 'Deslizamento',
                  rel_descricao: 'Encosta cedendo',
                  rel_gravidade: 'Moderada',
                  rel_data_hora: '2026-11-24T11:00:00Z',
                  rel_fraud_score: 0.41,
                  rel_fraud_reason: 'Descrição curta',
                  Foto: [{ fto_url: 'relatos/foto2.jpg' }],
                },
              ],
              error: null,
            }),
          }),
        }),
        update: (payload) => {
          mockUpdatePayload = payload
          return {
            eq: async () => ({ data: [{ rel_id: 'rel-1', ...payload }], error: null }),
          }
        },
      }),
    },
  },
})

const { getRelatosPendentes, validarRelatoStatus } = await import(
  '../src/backend/validacao/validacaoService.js'
)

test('getRelatosPendentes assina múltiplas fotos em lote único (sem N+1)', async () => {
  mockCreateSignedUrlsCalls = 0
  const items = await getRelatosPendentes()
  assert.equal(items.length, 2)
  assert.equal(mockCreateSignedUrlsCalls, 1)
  assert.equal(items[0].photoUrl, 'https://signed.local/relatos/foto1.jpg')
  assert.equal(items[1].photoUrl, 'https://signed.local/relatos/foto2.jpg')
})

test('validarRelatoStatus aciona RPC aprovar_relato / rejeitar_relato e usa fallback aprovado/rejeitado compatível com CHECK do banco', async () => {
  const calls = []
  mockRpcImpl = async (name, args) => {
    calls.push({ name, args })
    return { data: null, error: null }
  }

  const approved = await validarRelatoStatus({ relatoId: 'rel-1', isValid: true })
  assert.equal(approved.status, 'aprovado')
  assert.equal(calls[0].name, 'aprovar_relato')
  assert.equal(calls[0].args.p_rel_id, 'rel-1')

  mockRpcImpl = async () => ({
    data: null,
    error: { message: 'Could not find the function public.rejeitar_relato in the schema cache' },
  })
  mockUpdatePayload = null

  await validarRelatoStatus({ relatoId: 'rel-2', isValid: false, reason: 'Trote confirmado' })
  assert.equal(mockUpdatePayload.rel_fraud_status, 'rejeitado')
  assert.equal(mockUpdatePayload.rel_needs_admin_review, false)
  assert.equal(mockUpdatePayload.rel_prioridade, 'baixa')
  assert.equal(mockUpdatePayload.rel_fraud_reason, 'Trote confirmado')
})
