-- Executar SOMENTE depois da migração, deploy da Edge Function e configuração
-- dos segredos. Este arquivo não contém chaves nem envia alertas de teste.
-- Vault esperado:
--   alertas_push_url: https://<project-ref>.supabase.co/functions/v1/enviar-alertas-web
--   alertas_webhook_secret: o mesmo valor de ALERTAS_WEBHOOK_SECRET da função.
-- Gere um segredo aleatório de pelo menos 32 caracteres; não use a anon key.

begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

do $$
declare v_url text; v_segredo text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'alertas_push_url';
  select decrypted_secret into v_segredo from vault.decrypted_secrets where name = 'alertas_webhook_secret';
  if v_url is null or v_url !~ '^https://[a-z0-9]+[.]supabase[.]co/functions/v1/enviar-alertas-web$'
    or v_segredo is null or length(v_segredo) < 32 then
    raise exception 'Configure os dois segredos do push no Vault antes de ativar.';
  end if;
end;
$$;

create or replace function alertas_privado.solicitar_processamento_alertas()
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_url text; v_segredo text; v_request_id bigint;
begin
  if not exists (
    select 1 from alertas_privado.entregas e
    join alertas_privado.alertas a on a.id = e.alerta_id
    where (
      (e.estado = 'pendente' and e.proxima_tentativa <= now()) or
      (e.estado = 'processando' and e.lease_ate < now())
    )
  ) then return null; end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'alertas_push_url';
  select decrypted_secret into v_segredo from vault.decrypted_secrets where name = 'alertas_webhook_secret';
  if v_url is null or v_url !~ '^https://[a-z0-9]+[.]supabase[.]co/functions/v1/enviar-alertas-web$'
    or v_segredo is null or length(v_segredo) < 32 then
    raise warning 'Push não acionado: configuração do Vault ausente ou inválida.';
    return null;
  end if;
  select net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_segredo),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  ) into v_request_id;
  return v_request_id;
exception when others then
  -- Falha transitória de pg_net não impede a emissão web; cron tenta novamente.
  raise warning 'Push será retomado pelo cron.';
  return null;
end;
$$;
revoke all on function alertas_privado.solicitar_processamento_alertas() from public, anon, authenticated;

create or replace function alertas_privado.acordar_worker_alertas()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform alertas_privado.solicitar_processamento_alertas();
  return null;
end;
$$;
revoke all on function alertas_privado.acordar_worker_alertas() from public, anon, authenticated;
drop trigger if exists trg_acordar_worker_alertas on alertas_privado.entregas;
create trigger trg_acordar_worker_alertas after insert on alertas_privado.entregas
for each statement execute function alertas_privado.acordar_worker_alertas();

-- Mesmo nome atualiza a configuração deste job, sem duplicar o agendamento.
select cron.schedule('prever-enviar-alertas-web', '* * * * *',
  'select alertas_privado.solicitar_processamento_alertas();');
commit;
