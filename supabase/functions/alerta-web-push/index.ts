import { mensagemFCM, type AlertaPublico } from './payload.ts';

interface Job { id: number; claim_token: string; payload: AlertaPublico; expira_em: string }
interface ServiceAccount { project_id: string; client_email: string; private_key: string }
let cachedToken: { token: string; expires: number } | undefined;

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Configuração ausente: ${name}`);
  return value;
}
function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
function encode(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

async function accessToken(account: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expires > Date.now() + 60000) return cachedToken.token;
  const now = Math.floor(Date.now() / 1000);
  const jwt = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(jwt));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', signal: AbortSignal.timeout(15000),
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${jwt}.${base64url(new Uint8Array(signature))}` }),
  });
  if (!response.ok) throw new Error(`OAuth HTTP ${response.status}`);
  const result = await response.json();
  if (typeof result.access_token !== 'string') throw new Error('OAuth sem token');
  cachedToken = { token: result.access_token, expires: Date.now() + Number(result.expires_in) * 1000 };
  return cachedToken.token;
}

async function rpc<T>(name: string, body: unknown): Promise<T> {
  const response = await fetch(`${env('SUPABASE_URL')}/rest/v1/rpc/${name}`, {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: { 'Content-Type': 'application/json', apikey: env('SUPABASE_SERVICE_ROLE_KEY'),
      Authorization: `Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}` },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Banco HTTP ${response.status}`);
  const text = await response.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

async function autorizado(received: string): Promise<boolean> {
  const expected = env('PUSH_DISPATCH_SECRET');
  if (expected.length < 32) throw new Error('Segredo de dispatch muito curto');
  const digest = async (value: string) => new Uint8Array(await crypto.subtle.digest(
    'SHA-256', new TextEncoder().encode(value)));
  const [a, b] = await Promise.all([digest(received), digest(expected)]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

Deno.serve(async request => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  try {
    if (!await autorizado(request.headers.get('x-dispatch-secret') ?? '')) {
      return new Response('Unauthorized', { status: 401 });
    }
    // Nunca aceitar o conteúdo do alerta do chamador: consumir somente a fila protegida.
    const account: ServiceAccount = JSON.parse(env('FIREBASE_SERVICE_ACCOUNT_JSON'));
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error('Service account inválida');
    }
    const token = await accessToken(account);
    const jobs = await rpc<Job[]>('claim_push_alertas', {});
    let enviados = 0;
    let falhas = 0;
    for (let start = 0; start < jobs.length; start += 4) {
      await Promise.all(jobs.slice(start, start + 4).map(async job => {
        let sucesso = false;
        let erro: string | null = null;
        let retry = true;
        try {
          const ttl = Math.floor((Date.parse(job.expira_em) - Date.now()) / 1000);
          if (ttl <= 0) { retry = false; throw new Error('Alerta expirado'); }
          let message;
          try { message = mensagemFCM(job.payload, ttl); }
          catch (_) { retry = false; throw new Error('Campos públicos do alerta inválidos'); }
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
              method: 'POST', signal: AbortSignal.timeout(15000),
              headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ message }),
            });
          if (!response.ok) {
            retry = response.status === 429 || response.status === 401 || response.status >= 500;
            if (response.status === 401) cachedToken = undefined;
            throw new Error(`FCM HTTP ${response.status}`);
          }
          sucesso = true;
          enviados++;
        } catch (error) {
          falhas++;
          // Não registrar payloads, tokens, dados pessoais ou credenciais.
          erro = error instanceof Error ? error.message.slice(0, 200) : 'Falha no envio';
        }
        await rpc('finalizar_push_alerta', { job_id: job.id, token: job.claim_token,
          sucesso, erro, tentar_novamente: retry });
      }));
    }
    return Response.json({ enviados, falhas });
  } catch (error) {
    console.error('Falha no processador push:', error instanceof Error ? error.message : 'erro');
    return Response.json({ error: 'Falha no processador push; consultar logs do servidor.' }, { status: 500 });
  }
});
