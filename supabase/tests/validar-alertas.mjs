import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = new PGlite();
const migration = await readFile(new URL('../migrations/202611040001_alertas_push.sql', import.meta.url), 'utf8');
const u1 = '00000000-0000-0000-0000-000000000001';
const u2 = '00000000-0000-0000-0000-000000000002';
let successes = 0;
let failures = 0;
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;
const one = async (sql, params = []) => (await rows(sql, params))[0];
async function asRole(role, uid, action) {
  await db.exec(`set role ${role}`);
  try {
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid ?? '']);
    return await action();
  } finally { await db.exec('reset role'); }
}
async function rejects(action, code) {
  await assert.rejects(action, e => e.code === code);
}
async function register(token, meters = 0, uid = u1) {
  return asRole('authenticated', uid, () => db.query(
    'select public.registrar_dispositivo_alerta($1,$2,0,$3)',
    [token.padEnd(24, '_'), meters / 6371008.8 * 180 / Math.PI, 'android'],
  ));
}
async function alert({ status = 'disparado', lat = 0, lon = 0, description = 'Teste sintético' } = {}) {
  return (await one(`insert into public."Alerta_Web"(alw_status,alw_lat,alw_lng,alw_descricao)
    values ($1,$2,$3,$4) returning alw_id`, [status, lat, lon, description])).alw_id;
}
async function claim() {
  return asRole('service_role', null, () => rows('select * from public.reservar_entregas_alerta(50)'));
}
async function validate(delivery) {
  return asRole('service_role', null, async () => (await one(
    'select public.validar_entrega_alerta($1,$2) as ok', [delivery.entrega_id, delivery.lease_id],
  )).ok);
}
async function finish(delivery, result, code = 'TEST') {
  return asRole('service_role', null, () => db.query(
    'select public.concluir_entrega_alerta($1,$2,$3,$4)',
    [delivery.entrega_id, delivery.lease_id, result, code],
  ));
}
async function test(name, action) {
  await db.exec('reset role; truncate alertas_privado.entregas, alertas_privado.alertas, alertas_privado.dispositivos; truncate public."Alerta_Web" cascade; truncate public.activity_test;');
  try { await action(); successes++; console.log(`PASS ${name}`); }
  catch (e) { failures++; console.error(`FAIL ${name}: ${e.stack ?? e}`); }
}

await db.exec(`
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
insert into auth.users values ('${u1}'), ('${u2}');
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create table public."Alerta_Web" (
  alw_id uuid primary key default gen_random_uuid(),
  alw_tipo text default 'chuva', alw_cidade text default 'Cidade sintética',
  alw_descricao text, alw_status text, alw_lat double precision, alw_lng double precision
);
create table public.activity_test(id uuid);
create function public.activity_test_fn() returns trigger language plpgsql as
$$ begin insert into public.activity_test values(new.alw_id); return new; end $$;
create trigger trg_record_alerta_web_activity after insert on public."Alerta_Web"
for each row execute function public.activity_test_fn();
`);
await db.exec(migration);
console.log('PASS migration compiles');
await db.exec(migration);
console.log('PASS migration reapplies');

await test('anonymous cannot register; authenticated needs a real uid', async () => {
  await rejects(() => asRole('anon', null, () => db.query("select public.registrar_dispositivo_alerta('token_sintetico_000000000',0,0,'android')")), '42501');
  await rejects(() => asRole('authenticated', null, () => db.query("select public.registrar_dispositivo_alerta('token_sintetico_000000000',0,0,'android')")), '42501');
});
await test('rejects invalid, null and non-finite coordinates', async () => {
  for (const lat of [null, 91, -91, NaN, Infinity, -Infinity]) {
    await rejects(() => asRole('authenticated', u1, () => db.query("select public.registrar_dispositivo_alerta('token_sintetico_000000000',$1,0,'android')", [lat])), '22023');
  }
  for (const lon of [null, 181, -181, NaN, Infinity]) {
    await rejects(() => asRole('authenticated', u1, () => db.query("select public.registrar_dispositivo_alerta('token_sintetico_000000000',0,$1,'android')", [lon])), '22023');
  }
});
await test('private data and worker RPCs inaccessible to client roles', async () => {
  for (const role of ['anon', 'authenticated']) {
    for (const table of ['dispositivos', 'alertas', 'entregas']) {
      await rejects(() => asRole(role, u1, () => db.query(`select * from alertas_privado.${table}`)), '42501');
    }
    await rejects(() => asRole(role, u1, () => db.query('select * from public.reservar_entregas_alerta(50)')), '42501');
    await rejects(() => asRole(role, u1, () => db.query("select public.validar_entrega_alerta(gen_random_uuid(),gen_random_uuid())")), '42501');
    await rejects(() => asRole(role, u1, () => db.query("select public.concluir_entrega_alerta(gen_random_uuid(),gen_random_uuid(),'enviado')")), '42501');
  }
});
await test('token ownership protected and same-user registration idempotent', async () => {
  await register('same'); await register('same', 100);
  await rejects(() => register('same', 0, u2), '42501');
  assert.equal((await one('select count(*)::int as n from alertas_privado.dispositivos')).n, 1);
});
await test('20km boundary inclusive with shared Earth radius', async () => {
  await register('inside', 19999); await register('boundary', 20000); await register('outside', 20001);
  await alert();
  const deliveries = await claim();
  assert.deepEqual(deliveries.map(d => d.token.trimEnd().split('_')[0]).sort(), ['boundary', 'inside']);
  const d = await one('select alertas_privado.distancia_metros(0,0,$1,0) as metros', [20000 / 6371008.8 * 180 / Math.PI]);
  assert.ok(Math.abs(d.metros - 20000) < 0.000001);
});
await test('ignores location older than 30min', async () => {
  await register('stale');
  await db.exec("update alertas_privado.dispositivos set localizado_em=now()-interval '31 minutes'");
  await alert(); assert.equal((await claim()).length, 0);
});
await test('invalid/null alert coordinates and non-issued statuses do not queue', async () => {
  await register('near');
  for (const status of ['cancelado', 'resolvido', null]) await alert({status});
  for (const lat of [null, 91, NaN, Infinity]) await alert({lat});
  for (const lon of [null, 181, NaN]) await alert({lon});
  assert.equal((await claim()).length, 0);
});
await test('nullable description does not break website insert', async () => {
  await register('near'); await alert({description: null});
  assert.equal((await claim()).length, 1);
});
await test('preserves existing activity trigger and does not enqueue UPDATE', async () => {
  await register('near'); const id = await alert();
  await db.query('update public."Alerta_Web" set alw_descricao=$1 where alw_id=$2', ['Alteração sintética', id]);
  assert.equal((await one('select count(*)::int as n from public.activity_test')).n, 1);
  assert.equal((await one('select count(*)::int as n from alertas_privado.entregas')).n, 1);
});
await test('claim idempotency and successful completion never retries', async () => {
  await register('near'); await alert(); const [d] = await claim();
  assert.ok(await validate(d)); assert.equal((await claim()).length, 0);
  await finish(d, 'enviado'); await finish(d, 'repetir');
  assert.equal((await claim()).length, 0);
  assert.equal((await one('select estado from alertas_privado.entregas')).estado, 'enviado');
});
await test('revalidates device revoked, moved away, stale or cancelled', async () => {
  await register('near'); const id = await alert(); const [d] = await claim();
  await db.exec('update alertas_privado.dispositivos set ativo=false'); assert.equal(await validate(d), false);
  await register('near', 30000); assert.equal(await validate(d), false);
  await register('near', 0); assert.equal(await validate(d), true);
  await db.exec("update alertas_privado.dispositivos set localizado_em=now()-interval '31 minutes'"); assert.equal(await validate(d), false);
  await register('near', 0);
  await db.query('update public."Alerta_Web" set alw_status=$1 where alw_id=$2', ['cancelado', id]); assert.equal(await validate(d), false);
});
await test('other user cannot deactivate device', async () => {
  await register('near');
  await asRole('authenticated', u2, () => db.query('select public.desativar_dispositivo_alerta($1)', ['near'.padEnd(24, '_')]));
  assert.equal((await one('select ativo from alertas_privado.dispositivos')).ativo, true);
});
await test('retry delayed, expired lease reclaimable and stale ack ignored', async () => {
  await register('near'); await alert(); const [d] = await claim();
  await finish(d, 'repetir'); assert.equal((await claim()).length, 0);
  await db.exec("update alertas_privado.entregas set proxima_tentativa=now()-interval '1 second'");
  const [d2] = await claim(); assert.notEqual(d.lease_id, d2.lease_id);
  await db.exec("update alertas_privado.entregas set lease_ate=now()-interval '1 second'");
  const [d3] = await claim(); assert.notEqual(d2.lease_id, d3.lease_id);
  await finish(d2, 'enviado'); assert.equal((await one('select estado from alertas_privado.entregas')).estado, 'processando');
  await finish(d3, 'enviado'); assert.equal((await one('select estado from alertas_privado.entregas')).estado, 'enviado');
});
await test('expired alert never sends and invalid token deactivates device', async () => {
  await register('near'); await alert();
  await db.exec("update alertas_privado.alertas set expira_em=now()-interval '1 second'");
  assert.equal((await claim()).length, 0);
  await alert(); const [d] = await claim(); await finish(d, 'invalido');
  assert.equal((await one('select ativo from alertas_privado.dispositivos')).ativo, false);
});

console.log(JSON.stringify({ passed: successes, failed: failures, database: 'PGlite in-memory', liveDataTouched: false }));
await db.close();
process.exitCode = failures ? 1 : 0;
