import { buildMessage, classifyFcmResponse, withConcurrency } from './push.mjs';

type Delivery = {
  entrega_id: string;
  lease_id: string;
  token: string;
  alerta_id: string;
  latitude: number;
  longitude: number;
  titulo: string;
  descricao: string;
  expira_em: string;
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});

function requiredSecret(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`MISSING_${name}`);
  return value;
}

async function authorized(request: Request): Promise<boolean> {
  const expected = requiredSecret('ALERTAS_WEBHOOK_SECRET');
  if (expected.length < 32) throw new Error('WEBHOOK_SECRET_TOO_SHORT');
  const received = request.headers.get('x-webhook-secret') ?? '';
  if (received.length > 512) return false;
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
    crypto.subtle.digest('SHA-256', encoder.encode(received)),
  ]);
  let difference = 0;
  const a = new Uint8Array(left);
  const b = new Uint8Array(right);
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

let cachedAccess: { token: string; expiresAt: number; projectId: string } | undefined;

async function firebaseAccess() {
  if (cachedAccess && cachedAccess.expiresAt > Date.now() + 60_000) return cachedAccess;
  const account = JSON.parse(requiredSecret('FIREBASE_SERVICE_ACCOUNT'));
  if (account.type !== 'service_account' ||
    typeof account.project_id !== 'string' || !/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(account.project_id) ||
    typeof account.client_email !== 'string' || !account.client_email.endsWith('.iam.gserviceaccount.com') ||
    typeof account.private_key !== 'string' || !account.private_key.includes('BEGIN PRIVATE KEY')) {
    throw new Error('INVALID_FIREBASE_SERVICE_ACCOUNT');
  }
  const configuredProject = Deno.env.get('FIREBASE_PROJECT_ID');
  if (configuredProject && configuredProject !== account.project_id) throw new Error('FIREBASE_PROJECT_MISMATCH');
  const pem = account.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const bytes = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', bytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(encoder.encode(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })));
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(input));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${input}.${base64url(new Uint8Array(signature))}`,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== 'string') throw new Error('FIREBASE_AUTH_FAILED');
  cachedAccess = {
    token: result.access_token,
    projectId: account.project_id,
    expiresAt: Date.now() + Math.min(Number(result.expires_in) || 3600, 3600) * 1000,
  };
  return cachedAccess;
}

async function rpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  const url = requiredSecret('SUPABASE_URL');
  const serviceKey = requiredSecret('SUPABASE_SERVICE_ROLE_KEY');
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: serviceKey, Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) throw new Error(`RPC_${name}_${response.status}`);
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  try {
    if (!await authorized(request)) return json({ error: 'UNAUTHORIZED' }, 401);
    // Valida credenciais antes de reservar entregas, sem consumir tentativas da fila.
    const access = await firebaseAccess();
    const deliveries = await rpc<Delivery[]>('reservar_entregas_alerta', { p_limite: 50 });
    const results = await withConcurrency(deliveries, 10, async (delivery: Delivery) => {
      let outcome = { result: 'repetir', code: 'NETWORK_ERROR' };
      try {
        const eligible = await rpc<boolean>('validar_entrega_alerta', {
          p_entrega_id: delivery.entrega_id, p_lease_id: delivery.lease_id,
        });
        const body = buildMessage(delivery);
        if (!eligible || !body) {
          outcome = { result: 'ignorado', code: 'NO_LONGER_ELIGIBLE' };
        } else {
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${access.projectId}/messages:send`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${access.token}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
            signal: AbortSignal.timeout(10_000),
          });
          const result = await response.json().catch(() => ({}));
          outcome = classifyFcmResponse(response.status, result);
          if (response.status === 401) cachedAccess = undefined;
        }
      } catch {
        // Nunca escreve token, conteúdo, localização ou credenciais nos logs.
        // Timeout após aceite pelo FCM pode causar repetição; tag/collapse-id são estáveis.
      }
      try {
        await rpc('concluir_entrega_alerta', {
          p_entrega_id: delivery.entrega_id, p_lease_id: delivery.lease_id,
          p_resultado: outcome.result, p_codigo: outcome.code,
        });
        return outcome.result;
      } catch {
        return 'lease_pendente'; // Recuperada após três minutos por outra execução.
      }
    });
    const counts: Record<string, number> = {};
    for (const result of results) counts[result] = (counts[result] ?? 0) + 1;
    return json({ processadas: deliveries.length, resultados: counts });
  } catch (error) {
    // Apenas códigos definidos pelo servidor; não serialize erros de bibliotecas ou respostas.
    const safeCode = error instanceof Error && /^(MISSING_[A-Z_]+|WEBHOOK_SECRET_TOO_SHORT|INVALID_FIREBASE_SERVICE_ACCOUNT|FIREBASE_PROJECT_MISMATCH|FIREBASE_AUTH_FAILED|RPC_[a-z_]+_\d+)$/.test(error.message)
      ? error.message : 'PUSH_WORKER_FAILED';
    console.error(safeCode);
    return json({ error: safeCode }, 503);
  }
});
