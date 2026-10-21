-- Alertas públicos por cidade. Nenhuma credencial fica no aplicativo.
-- Não altera alw_destinatarios: FCM não informa número de pessoas que leram.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create table if not exists public.push_alerta_fila (
  id bigint generated always as identity primary key,
  alerta_id text not null unique,
  payload jsonb not null,
  status text not null default 'pendente'
    check (status in ('pendente', 'processando', 'enviado', 'falhou', 'expirado')),
  tentativas integer not null default 0,
  proxima_tentativa timestamptz not null default now(),
  lease_ate timestamptz,
  claim_token uuid,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default (now() + interval '1 hour'),
  enviado_em timestamptz,
  ultimo_erro text
);
alter table public.push_alerta_fila enable row level security;
revoke all on public.push_alerta_fila from anon, authenticated;
grant all on public.push_alerta_fila to service_role;
create index if not exists push_alerta_fila_pendentes
  on public.push_alerta_fila (status, proxima_tentativa);

-- O URL e o segredo são criados no Vault depois do deploy da Edge Function.
create or replace function public.acordar_push_alertas()
returns void language plpgsql security definer set search_path = '' as $$
declare url text; segredo text;
begin
  if not exists (select 1 from public.push_alerta_fila
    where status = 'pendente' and proxima_tentativa <= now()
       or status = 'processando' and lease_ate < now()) then return; end if;
  select decrypted_secret into url from vault.decrypted_secrets
    where name = 'push_dispatch_url' limit 1;
  select decrypted_secret into segredo from vault.decrypted_secrets
    where name = 'push_dispatch_secret' limit 1;
  if url is null or segredo is null then return; end if;
  perform net.http_post(url := url,
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-dispatch-secret', segredo), body := '{}'::jsonb, timeout_milliseconds := 120000);
exception when others then
  -- Uma falha no envio não pode desfazer a publicação do alerta.
  raise warning 'Push indisponível; a fila será retomada pelo agendamento.';
end;
$$;

create or replace function public.enfileirar_alerta_web_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare registro jsonb := to_jsonb(new); cidade text;
begin
  if lower(trim(coalesce(registro->>'alw_status', ''))) <> 'disparado' then
    return new;
  end if;
  if TG_OP = 'UPDATE' then
    if lower(trim(coalesce(to_jsonb(old)->>'alw_status', ''))) = 'disparado' then
      return new;
    end if;
  end if;
  cidade := trim(coalesce(registro->>'alw_cidade', ''));
  -- Sem cidade não existe destino seguro: falha visível na fila, nunca broadcast.
  insert into public.push_alerta_fila(alerta_id, payload, status, ultimo_erro)
  values (registro->>'alw_id', jsonb_build_object(
    'alerta_id', registro->>'alw_id', 'tipo', registro->>'alw_tipo',
    'cidade', cidade, 'bairro', registro->>'alw_bairro',
    'severidade', registro->>'alw_severidade', 'descricao', registro->>'alw_descricao'),
    case when cidade = '' then 'falhou' else 'pendente' end,
    case when cidade = '' then 'Alerta sem cidade; envio bloqueado.' end)
  on conflict (alerta_id) do nothing;
  perform public.acordar_push_alertas();
  return new;
end;
$$;

drop trigger if exists alerta_web_push on public."Alerta_Web";
create trigger alerta_web_push after insert or update of alw_status
  on public."Alerta_Web" for each row execute function public.enfileirar_alerta_web_push();

create or replace function public.claim_push_alertas()
returns setof public.push_alerta_fila language plpgsql security definer set search_path = '' as $$
begin
  update public.push_alerta_fila f set status = 'falhou', claim_token = null,
    ultimo_erro = 'Alerta removido ou não está mais disparado.'
    where (f.status = 'pendente' or (f.status = 'processando' and f.lease_ate < now()))
    and not exists (select 1 from public."Alerta_Web" a
      where a.alw_id::text = f.alerta_id and lower(trim(a.alw_status::text)) = 'disparado');
  update public.push_alerta_fila set status = 'expirado', claim_token = null
    where expira_em <= now() and status in ('pendente', 'processando');
  update public.push_alerta_fila set status = 'falhou', claim_token = null,
    ultimo_erro = 'Limite de tentativas atingido.'
    where tentativas >= 6 and status = 'processando' and lease_ate < now();
  return query
    with proximos as (
      select id from public.push_alerta_fila
      where expira_em > now() and tentativas < 6 and
        ((status = 'pendente' and proxima_tentativa <= now()) or
         (status = 'processando' and lease_ate < now()))
      order by id for update skip locked limit 8
    )
    update public.push_alerta_fila f set status = 'processando',
      tentativas = tentativas + 1, lease_ate = now() + interval '3 minutes',
      claim_token = gen_random_uuid()
    from proximos p where f.id = p.id returning f.*;
end;
$$;

create or replace function public.finalizar_push_alerta(
  job_id bigint, token uuid, sucesso boolean, erro text default null,
  tentar_novamente boolean default true)
returns void language sql security definer set search_path = '' as $$
  update public.push_alerta_fila set
    status = case when sucesso then 'enviado'
      when not tentar_novamente or tentativas >= 6 then 'falhou' else 'pendente' end,
    enviado_em = case when sucesso then now() else null end,
    ultimo_erro = left(erro, 300), lease_ate = null, claim_token = null,
    proxima_tentativa = now() + make_interval(secs => least(900, 30 * (2 ^ tentativas)::int))
  where id = job_id and claim_token = token and status = 'processando';
$$;

revoke all on function public.acordar_push_alertas() from public, anon, authenticated;
revoke all on function public.enfileirar_alerta_web_push() from public, anon, authenticated;
revoke all on function public.claim_push_alertas() from public, anon, authenticated;
revoke all on function public.finalizar_push_alerta(bigint, uuid, boolean, text, boolean)
  from public, anon, authenticated;
grant execute on function public.claim_push_alertas() to service_role;
grant execute on function public.finalizar_push_alerta(bigint, uuid, boolean, text, boolean)
  to service_role;

-- Retoma falhas e alertas restantes sem depender de o app estar aberto.
select cron.schedule('prever-push-alertas', '* * * * *',
  'select public.acordar_push_alertas();');
