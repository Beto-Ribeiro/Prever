// Banco PostgreSQL local em memória; não usa credenciais ou dados do Supabase.
// npm install --prefix build/push-validation --no-save --package-lock=false @electric-sql/pglite
import { PGlite } from '../../build/push-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

test('Migration: publicação, deduplicação, retry, cancelamento, expiração e permissões', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role;
      create schema vault; create schema net; create schema cron;
      create table vault.decrypted_secrets(name text, decrypted_secret text);
      create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds integer)
        returns bigint language sql as 'select 1::bigint';
      create function cron.schedule(jobname text, schedule text, command text)
        returns bigint language sql as 'select 1::bigint';
      create table public."Alerta_Web" (alw_id text primary key, alw_tipo text,
        alw_cidade text, alw_bairro text, alw_severidade text, alw_descricao text, alw_status text);
    `);
    const migration = await readFile(new URL('../migrations/20261020_alerta_web_push.sql', import.meta.url), 'utf8');
    await db.exec(migration.replace(/^create extension[^;]+;\r?\n/gm, ''));
    await db.exec(`insert into public."Alerta_Web" values
      ('1', 'Alagamento', 'Jacareí', 'Centro', 'Extrema', 'Evite a região', 'rascunho');`);
    assert.equal((await db.query('select * from public.push_alerta_fila')).rows.length, 0);
    await db.exec(`update public."Alerta_Web" set alw_status = 'disparado' where alw_id = '1';
      update public."Alerta_Web" set alw_status = 'disparado' where alw_id = '1';`);
    const rows = (await db.query('select * from public.push_alerta_fila')).rows;
    assert.equal(rows.length, 1);
    assert.equal(rows[0].payload.cidade, 'Jacareí');
    assert.equal(rows[0].payload.alerta_id, '1');
    const first = (await db.query('select * from public.claim_push_alertas()')).rows[0];
    assert.equal(first.tentativas, 1);
    assert.equal((await db.query('select * from public.claim_push_alertas()')).rows.length, 0);
    await db.query('select public.finalizar_push_alerta($1, $2, false, $3, true)',
      [first.id, first.claim_token, 'FCM HTTP 429']);
    assert.equal((await db.query('select status from public.push_alerta_fila')).rows[0].status, 'pendente');
    assert.equal((await db.query('select * from public.claim_push_alertas()')).rows.length, 0);
    await db.exec("update public.push_alerta_fila set proxima_tentativa = now() - interval '1 second'");
    const second = (await db.query('select * from public.claim_push_alertas()')).rows[0];
    assert.equal(second.tentativas, 2);
    await db.query('select public.finalizar_push_alerta($1, $2, true)', [first.id, first.claim_token]);
    assert.equal((await db.query('select status from public.push_alerta_fila')).rows[0].status, 'processando');
    await db.query('select public.finalizar_push_alerta($1, $2, true)', [second.id, second.claim_token]);
    assert.equal((await db.query('select status from public.push_alerta_fila')).rows[0].status, 'enviado');

    await db.exec(`insert into public."Alerta_Web" values
      ('2', 'Chuva', '', null, 'Severa', 'Risco', 'disparado'),
      ('3', 'Chuva', 'Taubaté', null, 'Severa', 'Risco', 'disparado'),
      ('4', 'Chuva', 'Taubaté', null, 'Severa', 'Risco', 'disparado');
      update public."Alerta_Web" set alw_status = 'cancelado' where alw_id = '3';
      update public.push_alerta_fila set expira_em = now() - interval '1 second' where alerta_id = '4';`);
    assert.equal((await db.query('select * from public.claim_push_alertas()')).rows.length, 0);
    const states = (await db.query('select alerta_id, status from public.push_alerta_fila order by alerta_id')).rows;
    assert.deepEqual(states.map(row => row.status), ['enviado', 'falhou', 'falhou', 'expirado']);
    await db.exec('set role authenticated');
    await assert.rejects(db.query('select * from public.push_alerta_fila'), /permission denied/);
    await assert.rejects(db.query('select * from public.claim_push_alertas()'), /permission denied/);
    await db.exec('reset role');
  } finally { await db.close(); }
});
