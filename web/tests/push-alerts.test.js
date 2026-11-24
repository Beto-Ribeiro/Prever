import test from 'node:test'
import assert from 'node:assert/strict'
import {
  buildMessage,
  classifyFcmResponse,
  ttlSeconds,
  truncateUtf8,
  withConcurrency,
} from '../../supabase/functions/enviar-alertas-web/push.mjs'

const now = Date.parse('2026-11-04T12:00:00Z')
const delivery = {
  token: 'token-ficticio-apenas-para-teste',
  alerta_id: '00000000-0000-4000-8000-000000000001',
  latitude: -23.55,
  longitude: -46.63,
  titulo: 'Alagamento — Teste',
  descricao: 'Mensagem fictícia, não enviada.',
  expira_em: '2026-11-04T12:15:00Z',
}

test('push worker: payload contém apenas um alerta com coordenadas e identidade estável', () => {
  const payload = buildMessage(delivery, now).message
  assert.equal(payload.data.tipo, 'alerta_web')
  assert.equal(payload.data.alerta_id, delivery.alerta_id)
  assert.equal(payload.data.latitude, '-23.55')
  assert.equal(payload.android.notification.channel_id, 'alertas_web_v2')
  assert.equal(payload.android.notification.tag, delivery.alerta_id)
  assert.equal(payload.apns.headers['apns-collapse-id'], delivery.alerta_id)
  assert.equal(payload.android.ttl, '900s')
})

test('push worker: não estende validade em retries e rejeita alerta expirado', () => {
  assert.equal(ttlSeconds(delivery.expira_em, now + 5 * 60_000), 600)
  assert.equal(buildMessage(delivery, now + 15 * 60_000), null)
  assert.equal(ttlSeconds('inválido', now), 0)
  assert.equal(ttlSeconds('2026-12-04T12:00:00Z', now), 900)
})

test('push worker: emoji e texto multibyte respeitam 4 KiB sem cortar codepoints', () => {
  const payload = buildMessage(
    { ...delivery, titulo: '🚨'.repeat(120), descricao: '🌊'.repeat(500) },
    now
  )
  const encoder = new TextEncoder()
  assert.ok(encoder.encode(JSON.stringify(payload)).length < 4096)
  assert.equal(encoder.encode(payload.message.notification.title).length, 160)
  assert.equal(encoder.encode(payload.message.notification.body).length, 900)
  assert.equal(truncateUtf8('á🌊x', 5), 'á')
  assert.equal(payload.message.notification.body, payload.message.data.descricao)
  assert.ok(!payload.message.data.descricao.includes('\ufffd'))
})

test('push worker: coordenadas não finitas e fora do domínio jamais viram notificação', () => {
  for (const latitude of [NaN, Infinity, -Infinity, 91, -91, null, '']) {
    assert.throws(() => buildMessage({ ...delivery, latitude }, now), /INVALID_COORDINATES/)
  }
  assert.throws(() => buildMessage({ ...delivery, longitude: 181 }, now), /INVALID_COORDINATES/)
})

test('push worker: somente UNREGISTERED revoga token; erros transitórios preservam', () => {
  const err = (code) => ({
    error: {
      details: [
        {
          '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
          errorCode: code,
        },
      ],
    },
  })
  assert.equal(classifyFcmResponse(404, err('UNREGISTERED')).result, 'invalido')
  assert.equal(classifyFcmResponse(400, err('INVALID_ARGUMENT')).result, 'falhou')
  assert.equal(classifyFcmResponse(403, err('SENDER_ID_MISMATCH')).result, 'repetir')
  for (const status of [401, 408, 429, 500, 503]) {
    assert.equal(classifyFcmResponse(status, {}).result, 'repetir')
  }
  assert.equal(classifyFcmResponse(200, {}).result, 'enviado')
})

test('push worker: limite de concorrência processa cada destinatário uma vez', async () => {
  let active = 0
  let peak = 0
  const seen = []
  const results = await withConcurrency([1, 2, 3, 4, 5, 6, 7], 3, async (value) => {
    active++
    peak = Math.max(peak, active)
    await new Promise((resolve) => setTimeout(resolve, 2))
    seen.push(value)
    active--
    return value * 2
  })
  assert.ok(peak <= 3)
  assert.deepEqual(
    seen.sort((a, b) => a - b),
    [1, 2, 3, 4, 5, 6, 7]
  )
  assert.deepEqual(results, [2, 4, 6, 8, 10, 12, 14])
})
