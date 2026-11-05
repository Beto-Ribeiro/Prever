-- Push geográfico: apenas INSERTs futuros de Alerta_Web com status disparado.
-- As coordenadas do celular ficam privadas; clientes usam somente os RPCs.
begin;

create schema if not exists alertas_privado;
revoke all on schema alertas_privado from public, anon, authenticated;

create table if not exists alertas_privado.dispositivos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique check (length(token) between 20 and 4096),
  plataforma text not null check (plataforma in ('android', 'ios')),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  localizado_em timestamptz not null default now(),
  ativo boolean not null default true
);
create index if not exists dispositivos_alerta_localizados_idx
  on alertas_privado.dispositivos(localizado_em) where ativo;

create table if not exists alertas_privado.alertas (
  id uuid primary key references public."Alerta_Web"(alw_id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  titulo text not null,
  descricao text not null,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default (now() + interval '15 minutes')
);

create table if not exists alertas_privado.entregas (
  id uuid primary key default gen_random_uuid(),
  alerta_id uuid not null references alertas_privado.alertas(id) on delete cascade,
  dispositivo_id uuid not null references alertas_privado.dispositivos(id) on delete cascade,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  estado text not null default 'pendente'
    check (estado in ('pendente', 'processando', 'enviado', 'ignorado', 'falhou', 'expirado')),
  tentativas integer not null default 0,
  proxima_tentativa timestamptz not null default now(),
  lease_id uuid,
  lease_ate timestamptz,
  enviado_em timestamptz,
  ultimo_codigo text,
  unique (alerta_id, dispositivo_id)
);
create index if not exists entregas_alerta_pendentes_idx
  on alertas_privado.entregas(proxima_tentativa)
  where estado in ('pendente', 'processando');

alter table alertas_privado.dispositivos enable row level security;
alter table alertas_privado.alertas enable row level security;
alter table alertas_privado.entregas enable row level security;
revoke all on all tables in schema alertas_privado from public, anon, authenticated;

create or replace function alertas_privado.distancia_metros(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns double precision
language sql immutable strict set search_path = '' as $$
  select 6371008.8 * 2 * asin(sqrt(least(1.0, greatest(0.0,
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * power(sin(radians(lng2 - lng1) / 2), 2)
  ))));
$$;
revoke all on function alertas_privado.distancia_metros(double precision,double precision,double precision,double precision) from public;

create or replace function public.registrar_dispositivo_alerta(
  p_token text, p_latitude double precision, p_longitude double precision,
  p_plataforma text
) returns void
language plpgsql security definer set search_path = '' as $$
declare v_usuario uuid := auth.uid();
begin
  if v_usuario is null then raise exception 'Autenticação necessária.' using errcode = '42501'; end if;
  if p_token is null or length(p_token) not between 20 and 4096
    or p_latitude is null or not (p_latitude between -90 and 90)
    or p_longitude is null or not (p_longitude between -180 and 180)
    or p_plataforma is null or p_plataforma not in ('android', 'ios') then
    raise exception 'Dispositivo ou coordenadas inválidos.' using errcode = '22023';
  end if;
  -- Não permite que um usuário assuma um token já vinculado a outro usuário.
  -- Ao trocar de conta, o app deve excluir o token FCM e registrar um novo.
  insert into alertas_privado.dispositivos as d
    (usuario_id, token, plataforma, latitude, longitude, localizado_em, ativo)
  values (v_usuario, p_token, p_plataforma, p_latitude, p_longitude, now(), true)
  on conflict (token) do update set
    plataforma = excluded.plataforma, latitude = excluded.latitude,
    longitude = excluded.longitude, localizado_em = now(), ativo = true
  where d.usuario_id = v_usuario;
  if not found then raise exception 'Token vinculado a outra sessão.' using errcode = '42501'; end if;
end;
$$;
revoke all on function public.registrar_dispositivo_alerta(text,double precision,double precision,text) from public, anon;
grant execute on function public.registrar_dispositivo_alerta(text,double precision,double precision,text) to authenticated;

create or replace function public.desativar_dispositivo_alerta(p_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Autenticação necessária.' using errcode = '42501'; end if;
  update alertas_privado.dispositivos set ativo = false
  where token = p_token and usuario_id = auth.uid();
end;
$$;
revoke all on function public.desativar_dispositivo_alerta(text) from public, anon;
grant execute on function public.desativar_dispositivo_alerta(text) to authenticated;

create or replace function alertas_privado.enfileirar_alerta_web()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.alw_status is distinct from 'disparado' then return new; end if;
  if new.alw_lat is null or not (new.alw_lat between -90 and 90)
    or new.alw_lng is null or not (new.alw_lng between -180 and 180) then
    raise warning 'Push de Alerta_Web ignorado: coordenadas ausentes ou inválidas.';
    return new;
  end if;
  insert into alertas_privado.alertas(id, latitude, longitude, titulo, descricao)
  values (new.alw_id, new.alw_lat, new.alw_lng,
    left(concat(new.alw_tipo, ' — ', new.alw_cidade), 120),
    left(coalesce(new.alw_descricao, ''), 500))
  on conflict (id) do nothing;
  -- Seleção no momento da emissão: não inclui depois usuários que entraram na região.
  insert into alertas_privado.entregas(alerta_id, dispositivo_id, usuario_id)
  select new.alw_id, d.id, d.usuario_id from alertas_privado.dispositivos d
  where d.ativo and d.localizado_em >= now() - interval '30 minutes'
    and alertas_privado.distancia_metros(d.latitude, d.longitude, new.alw_lat, new.alw_lng) <= 20000.0 + 1e-6
  on conflict (alerta_id, dispositivo_id) do nothing;
  return new;
end;
$$;
revoke all on function alertas_privado.enfileirar_alerta_web() from public;
drop trigger if exists trg_enfileirar_push_alerta_web on public."Alerta_Web";
create trigger trg_enfileirar_push_alerta_web after insert on public."Alerta_Web"
for each row execute function alertas_privado.enfileirar_alerta_web();
-- O trigger preexistente trg_record_alerta_web_activity não é alterado.

create or replace function public.reservar_entregas_alerta(p_limite integer default 50)
returns table (
  entrega_id uuid, lease_id uuid, token text, alerta_id uuid,
  latitude double precision, longitude double precision,
  titulo text, descricao text, expira_em timestamptz
) language plpgsql security definer set search_path = '' as $$
begin
  -- Descarta filas que perderam validade sem voltar a tentar enviá-las.
  update alertas_privado.entregas e set estado = 'expirado', ultimo_codigo = 'TTL_EXPIRED'
  from alertas_privado.alertas a where a.id = e.alerta_id and a.expira_em <= now()
    and e.estado in ('pendente', 'processando');
  update alertas_privado.entregas e set estado = 'ignorado', ultimo_codigo = 'NO_LONGER_ELIGIBLE'
  from alertas_privado.alertas a, alertas_privado.dispositivos d, public."Alerta_Web" w
  where e.alerta_id = a.id and e.dispositivo_id = d.id and w.alw_id = a.id
    and e.estado in ('pendente', 'processando')
    and (w.alw_status is distinct from 'disparado' or not d.ativo or d.usuario_id <> e.usuario_id
      or d.localizado_em < now() - interval '30 minutes'
      or alertas_privado.distancia_metros(d.latitude, d.longitude, a.latitude, a.longitude) > 20000.0 + 1e-6);
  return query
  with candidatos as (
    select e.id from alertas_privado.entregas e
    where ((e.estado = 'pendente' and e.proxima_tentativa <= now())
      or (e.estado = 'processando' and e.lease_ate < now()))
      and e.tentativas < 8
    order by e.proxima_tentativa, e.id
    limit greatest(1, least(coalesce(p_limite, 50), 100))
    for update skip locked
  ), reservadas as (
    update alertas_privado.entregas e set estado = 'processando',
      lease_id = gen_random_uuid(), lease_ate = now() + interval '3 minutes',
      tentativas = e.tentativas + 1
    from candidatos c where e.id = c.id
    returning e.*
  )
  select e.id, e.lease_id, d.token, a.id, a.latitude, a.longitude,
    a.titulo, a.descricao, a.expira_em
  from reservadas e join alertas_privado.dispositivos d on d.id = e.dispositivo_id
  join alertas_privado.alertas a on a.id = e.alerta_id;
end;
$$;
revoke all on function public.reservar_entregas_alerta(integer) from public, anon, authenticated;
grant execute on function public.reservar_entregas_alerta(integer) to service_role;

create or replace function public.validar_entrega_alerta(p_entrega_id uuid, p_lease_id uuid)
returns boolean language sql security definer set search_path = '' as $$
  select exists (
    select 1 from alertas_privado.entregas e
    join alertas_privado.alertas a on a.id = e.alerta_id
    join public."Alerta_Web" w on w.alw_id = a.id
    join alertas_privado.dispositivos d on d.id = e.dispositivo_id
    where e.id = p_entrega_id and e.lease_id = p_lease_id
      and e.estado = 'processando' and e.lease_ate > now() and a.expira_em > now()
      and w.alw_status = 'disparado' and d.ativo and d.usuario_id = e.usuario_id
      and d.localizado_em >= now() - interval '30 minutes'
      and alertas_privado.distancia_metros(d.latitude, d.longitude, a.latitude, a.longitude) <= 20000.0 + 1e-6
  );
$$;
revoke all on function public.validar_entrega_alerta(uuid,uuid) from public, anon, authenticated;
grant execute on function public.validar_entrega_alerta(uuid,uuid) to service_role;

create or replace function public.concluir_entrega_alerta(
  p_entrega_id uuid, p_lease_id uuid, p_resultado text, p_codigo text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare v_dispositivo uuid;
begin
  if p_resultado is null or p_resultado not in ('enviado', 'repetir', 'invalido', 'falhou', 'ignorado') then
    raise exception 'Resultado inválido.' using errcode = '22023';
  end if;
  update alertas_privado.entregas e set
    estado = case when p_resultado = 'repetir' and e.tentativas < 8 then 'pendente'
      when p_resultado in ('invalido', 'repetir') then 'falhou' else p_resultado end,
    proxima_tentativa = now() + make_interval(secs => least(300, (30 * power(2, least(e.tentativas, 4)))::integer)),
    enviado_em = case when p_resultado = 'enviado' then now() else e.enviado_em end,
    ultimo_codigo = left(p_codigo, 80), lease_ate = null, lease_id = null
  where e.id = p_entrega_id and e.lease_id = p_lease_id and e.estado = 'processando'
  returning e.dispositivo_id into v_dispositivo;
  if p_resultado = 'invalido' and v_dispositivo is not null then
    update alertas_privado.dispositivos set ativo = false where id = v_dispositivo;
  end if;
end;
$$;
revoke all on function public.concluir_entrega_alerta(uuid,uuid,text,text) from public, anon, authenticated;
grant execute on function public.concluir_entrega_alerta(uuid,uuid,text,text) to service_role;

commit;
