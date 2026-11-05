// Funções puras: também executadas pelos testes Node, sem credenciais.
export function ttlSeconds(expiresAt, now = Date.now()) {
  const remaining = Math.floor((Date.parse(expiresAt) - now) / 1000);
  return Number.isFinite(remaining) ? Math.max(0, Math.min(900, remaining)) : 0;
}

export function truncateUtf8(value, maxBytes) {
  const encoder = new TextEncoder();
  let result = '';
  let bytes = 0;
  for (const character of String(value ?? '')) {
    const length = encoder.encode(character).length;
    if (bytes + length > maxBytes) break;
    result += character;
    bytes += length;
  }
  return result;
}

export function buildMessage(delivery, now = Date.now()) {
  const ttl = ttlSeconds(delivery.expira_em, now);
  if (ttl === 0) return null;
  if (!Number.isFinite(delivery.latitude) || Math.abs(delivery.latitude) > 90 ||
      !Number.isFinite(delivery.longitude) || Math.abs(delivery.longitude) > 180) {
    throw new Error('INVALID_COORDINATES');
  }
  // Notification + data compartilham o limite FCM de 4 KiB. Limita bytes UTF-8,
  // não somente caracteres, preservando emoji e caracteres multibyte inteiros.
  const title = truncateUtf8(delivery.titulo, 160);
  const description = truncateUtf8(delivery.descricao, 900);
  return {
    message: {
      token: delivery.token,
      notification: { title, body: description },
      data: {
        tipo: 'alerta_web',
        alerta_id: delivery.alerta_id,
        latitude: String(delivery.latitude),
        longitude: String(delivery.longitude),
        titulo: title,
        descricao: description,
        expira_em: delivery.expira_em,
      },
      android: {
        priority: 'HIGH',
        ttl: `${ttl}s`,
        notification: {
          channel_id: 'alertas_web_v2',
          sound: 'default',
          icon: 'ic_stat_alerta',
          tag: delivery.alerta_id,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
          'apns-expiration': String(Math.floor(now / 1000) + ttl),
          'apns-collapse-id': delivery.alerta_id,
        },
        payload: { aps: { sound: 'default' } },
      },
    },
  };
}

export function classifyFcmResponse(status, response) {
  if (status >= 200 && status < 300) return { result: 'enviado', code: 'OK' };
  const details = response?.error?.details;
  const fcm = Array.isArray(details)
    ? details.find((detail) => detail?.['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError')
    : undefined;
  const code = typeof fcm?.errorCode === 'string' ? fcm.errorCode : `HTTP_${status}`;
  // INVALID_ARGUMENT pode indicar payload malformado: não invalide o token por ele.
  if (code === 'UNREGISTERED') return { result: 'invalido', code };
  if (status === 401 || status === 403 || status === 408 || status === 429 || status >= 500) {
    return { result: 'repetir', code };
  }
  return { result: 'falhou', code };
}

export async function withConcurrency(items, concurrency, action) {
  let next = 0;
  const results = new Array(items.length);
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      results[index] = await action(items[index]);
    }
  }));
  return results;
}
