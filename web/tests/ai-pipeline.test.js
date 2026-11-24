import test, { mock } from 'node:test'
import assert from 'node:assert/strict'

mock.module('../src/backend/supabase/client.js', {
  namedExports: {
    supabase: {
      auth: {
        getSession: async () => ({
          data: { session: { access_token: 'mock-jwt' } },
          error: null,
        }),
      },
      functions: {
        invoke: async () => ({
          data: { text: 'Resposta da Edge Function', actions: [], model: 'gemini-2.5-flash' },
          error: null,
        }),
      },
    },
  },
})

const { askSmdnAssistant, parseAssistantPayload } = await import('../src/backend/ai/assistantService.js')

test('pipeline IA Web faz retry em 429 e fallback automático entre provedores quando o primário falha', async () => {
  const calls = []

  const tier1FailAppCheck = async () => {
    calls.push('firebase-vertex')
    throw new Error('Firebase App Check token is invalid')
  }

  let tier2Attempts = 0
  const tier2RetryThenSuccess = async () => {
    tier2Attempts += 1
    calls.push(`vercel-api-${tier2Attempts}`)
    if (tier2Attempts === 1) {
      const err = new Error('429 RESOURCE_EXHAUSTED')
      err.status = 429
      throw err
    }
    return {
      text: 'Há **3 ocorrências críticas** ativas no painel.',
      actions: [{ type: 'navigate', screen: 'ocorrencias' }],
      model: 'gemini-2.5-flash',
    }
  }

  const result = await askSmdnAssistant({
    message: 'Quais ocorrências críticas estão ativas?',
    currentScreen: 'dashboard',
    screenTitle: 'Dashboard',
    options: {
      retries: 1,
      retryDelayMs: 5,
      timeoutMs: 500,
      transports: [tier1FailAppCheck, tier2RetryThenSuccess],
    },
  })

  assert.deepEqual(calls, ['firebase-vertex', 'vercel-api-1', 'vercel-api-2'])
  assert.equal(result.model, 'gemini-2.5-flash')
  assert.match(result.text, /3 ocorrências críticas/)
  assert.deepEqual(result.actions, [{ type: 'navigate', screen: 'ocorrencias' }])
})

test('pipeline IA Web interrompe fallback imediatamente quando a sessão expira (401)', async () => {
  let secondCalled = false

  await assert.rejects(
    () =>
      askSmdnAssistant({
        message: 'Resuma o abrigo',
        options: {
          retries: 0,
          transports: [
            async () => {
              const err = new Error('Sessão inválida ou expirada. Entre novamente.')
              err.status = 401
              throw err
            },
            async () => {
              secondCalled = true
              return { text: 'Não deveria chegar aqui', actions: [] }
            },
          ],
        },
      }),
    /sessão expirou/i
  )

  assert.equal(secondCalled, false)
})

test('parseAssistantPayload recupera resposta útil mesmo quando JSON do Gemini é truncado antes do fechamento', () => {
  const truncated = '{"answer":"Os itens críticos do abrigo são:\\n* Água potável (2 L)\\n* Colchões'
  const parsed = parseAssistantPayload(truncated)

  assert.match(parsed.text, /Água potável/)
  assert.doesNotMatch(parsed.text, /fora do formato esperado/)
  assert.deepEqual(parsed.actions, [])

  const valid = parseAssistantPayload('```json\n{"answer":"Tudo certo","actions":[{"type":"navigate","screen":"estoque"},{"type":"hack"}]}\n```')
  assert.equal(valid.text, 'Tudo certo')
  assert.deepEqual(valid.actions, [{ type: 'navigate', screen: 'estoque' }])
})
