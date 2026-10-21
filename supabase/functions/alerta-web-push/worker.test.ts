import { test } from 'node:test';
import assert from 'node:assert/strict';

const key = await crypto.subtle.generateKey(
  { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true, ['sign', 'verify']);
const pem = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey('pkcs8', key.privateKey))));
const settings = new Map([
  ['PUSH_DISPATCH_SECRET', 'segredo-apenas-de-teste-01234567890123456789'],
  ['FIREBASE_SERVICE_ACCOUNT_JSON', JSON.stringify({ project_id: 'teste', client_email: 'teste@example.com',
    private_key: `-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----` })],
  ['SUPABASE_URL', 'https://test.supabase.co'], ['SUPABASE_SERVICE_ROLE_KEY', 'test-key'],
]);
let handler: (request: Request) => Promise<Response>;
Object.assign(globalThis, { Deno: { env: { get: (name: string) => settings.get(name) },
  serve: (callback: typeof handler) => { handler = callback; } } });
await import('./index.ts');

test('Requisição sem segredo não acessa fila nem envia mensagens', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error('Não deveria fazer chamadas'); };
  try {
    const result = await handler(new Request('https://worker', { method: 'POST' }));
    assert.equal(result.status, 401);
  } finally { globalThis.fetch = original; }
});

test('Worker marca sucesso e reprograma erros temporários do Firebase', async () => {
  const original = globalThis.fetch;
  const finalizados: any[] = [];
  let enviados = 0;
  globalThis.fetch = async (input, options) => {
    const url = String(input);
    if (url.includes('oauth2.googleapis.com')) return Response.json({ access_token: 'test-token', expires_in: 3600 });
    if (url.endsWith('/claim_push_alertas')) return Response.json([1, 2, 3].map(id => ({
      id, claim_token: `claim-${id}`, expira_em: new Date(Date.now() + 300000).toISOString(),
      payload: { alerta_id: String(id), cidade: id === 3 ? '' : 'Jacareí', tipo: 'Alagamento', descricao: 'Atenção.' },
    })));
    if (url.includes('fcm.googleapis.com')) {
      enviados++;
      const message = JSON.parse(String(options?.body)).message;
      assert.equal(message.topic, 'prever_cidade_jacarei');
      return new Response('{}', { status: message.data.alerta_id === '1' ? 200 : 429 });
    }
    if (url.endsWith('/finalizar_push_alerta')) {
      finalizados.push(JSON.parse(String(options?.body)));
      return new Response('');
    }
    throw new Error(`Chamada inesperada: ${url}`);
  };
  try {
    const response = await handler(new Request('https://worker', { method: 'POST',
      headers: { 'x-dispatch-secret': settings.get('PUSH_DISPATCH_SECRET')! } }));
    assert.equal(response.status, 200);
    assert.equal(enviados, 2);
    assert.equal(finalizados.find(j => j.job_id === 1).sucesso, true);
    assert.equal(finalizados.find(j => j.job_id === 2).tentar_novamente, true);
    assert.equal(finalizados.find(j => j.job_id === 3).tentar_novamente, false);
    assert.equal(finalizados.find(j => j.job_id === 1).token, 'claim-1');
  } finally { globalThis.fetch = original; }
});
