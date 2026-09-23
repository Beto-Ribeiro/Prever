-- SMDN - Backend real da tela Ocorrências
-- Rode no Supabase Dashboard > SQL Editor.
-- Esta etapa NÃO altera o schema mobile de Relato/Foto.
-- Ela cria uma tabela auxiliar para status web da ocorrência.

create or replace function public.ocorrencia_severity_from_relato(nivel text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(nivel, '')) in ('crítico', 'critico', 'muito alto') then 'critical'
    when lower(coalesce(nivel, '')) in ('alto', 'grave') then 'severe'
    else 'regular'
  end;
$$;

create or replace function public.can_manage_occurrences()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public."Perfis" p
    where p.prf_id = auth.uid()
      and (
        lower(coalesce(p.prf_tipo, '')) in ('admin', 'adm', 'administrador', 'administradora', 'funcionario', 'funcionário', 'instituicao', 'instituição')
        or coalesce((p.prf_permissoes ->> 'ocorrencias')::boolean, false) = true
      )
  );
$$;

create table if not exists public."Ocorrencia_Status" (
  ocs_rel_id uuid primary key references public."Relato"(rel_id) on delete cascade,
  ocs_status text not null default 'active' check (ocs_status in ('active', 'monitoring', 'resolved')),
  ocs_updated_by uuid references auth.users(id),
  ocs_updated_at timestamptz not null default now()
);

alter table public."Ocorrencia_Status" enable row level security;

drop policy if exists "Ocorrencia_Status select web" on public."Ocorrencia_Status";
create policy "Ocorrencia_Status select web"
on public."Ocorrencia_Status"
for select
to authenticated
using (public.can_manage_occurrences());

drop policy if exists "Ocorrencia_Status upsert web" on public."Ocorrencia_Status";
create policy "Ocorrencia_Status upsert web"
on public."Ocorrencia_Status"
for insert
to authenticated
with check (public.can_manage_occurrences());

drop policy if exists "Ocorrencia_Status update web" on public."Ocorrencia_Status";
create policy "Ocorrencia_Status update web"
on public."Ocorrencia_Status"
for update
to authenticated
using (public.can_manage_occurrences())
with check (public.can_manage_occurrences());

create or replace function public.get_ocorrencias_data()
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  with relato_base as (
    select
      r.rel_id,
      'OC-' || upper(substr(replace(r.rel_id::text, '-', ''), 1, 6)) as codigo,
      r.rel_tipo_desastre,
      r.rel_descricao,
      r.rel_data_hora,
      r.rel_cid_id,
      case
        when r.rel_localizacao is not null then extensions.st_y(r.rel_localizacao::extensions.geometry)
        else null
      end as lat,
      case
        when r.rel_localizacao is not null then extensions.st_x(r.rel_localizacao::extensions.geometry)
        else null
      end as lng,
      p.prf_nome as cidadao_nome,
      foto.fto_url,
      coalesce(ocs.ocs_status, 'active') as status,
      ocs.ocs_updated_at
    from public."Relato" r
    left join public."Ocorrencia_Status" ocs
      on ocs.ocs_rel_id = r.rel_id
    left join public."Cidadao" c
      on c.cid_id = r.rel_cid_id
    left join public."Perfis" p
      on p.prf_id = c.cid_id
    left join lateral (
      select f.fto_url
      from public."Foto" f
      where f.fto_rel_id = r.rel_id
      order by f.fto_id
      limit 1
    ) foto on true
  ),
  rows_json as (
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'id', codigo,
        'relatoId', rel_id,
        'type', coalesce(rel_tipo_desastre, 'Relato'),
        'city', case
          when lat is not null and lng is not null then 'Local informado'
          else 'Local não informado'
        end,
        'neighborhood', case
          when lat is not null and lng is not null then 'Coordenadas disponíveis'
          else 'Sem bairro informado'
        end,
        'severity', public.ocorrencia_severity_from_relato(rel_descricao),
        'riskLabel', coalesce(rel_descricao, 'Não informado'),
        'status', status,
        'reportedAt', rel_data_hora,
        'description', concat('Nível reportado pelo cidadão: ', coalesce(rel_descricao, 'Não informado')),
        'citizenId', rel_cid_id,
        'citizenName', coalesce(cidadao_nome, 'Cidadão não identificado'),
        'lat', lat,
        'lng', lng,
        'photoPath', fto_url,
        'updatedAt', ocs_updated_at
      )
      order by rel_data_hora desc nulls last, rel_id desc
    ), '[]'::jsonb) as items
    from relato_base
  )
  select jsonb_build_object(
    'stats', jsonb_build_object(
      'active', (select count(*) from relato_base where status = 'active'),
      'monitoring', (select count(*) from relato_base where status = 'monitoring'),
      'resolved', (select count(*) from relato_base where status = 'resolved')
    ),
    'items', (select items from rows_json)
  );
$$;

create or replace function public.update_ocorrencia_status(
  p_rel_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_manage_occurrences() then
    raise exception 'Usuário sem permissão para atualizar ocorrências.';
  end if;

  if p_status not in ('active', 'monitoring', 'resolved') then
    raise exception 'Status inválido: %', p_status;
  end if;

  insert into public."Ocorrencia_Status" (
    ocs_rel_id,
    ocs_status,
    ocs_updated_by,
    ocs_updated_at
  )
  values (
    p_rel_id,
    p_status,
    auth.uid(),
    now()
  )
  on conflict (ocs_rel_id) do update
  set
    ocs_status = excluded.ocs_status,
    ocs_updated_by = excluded.ocs_updated_by,
    ocs_updated_at = excluded.ocs_updated_at;

  insert into public."Audit_Log" (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    detail,
    metadata
  )
  values (
    auth.uid(),
    'occurrence_status_updated',
    'Relato',
    p_rel_id,
    'Status da ocorrência atualizado para ' || p_status || '.',
    jsonb_build_object('status', p_status)
  );

  return jsonb_build_object('ok', true, 'relatoId', p_rel_id, 'status', p_status);
end;
$$;

revoke all on function public.get_ocorrencias_data() from public;
revoke all on function public.update_ocorrencia_status(uuid, text) from public;
grant execute on function public.get_ocorrencias_data() to authenticated;
grant execute on function public.update_ocorrencia_status(uuid, text) to authenticated;

-- Permite signed URL de fotos dos relatos para usuários autenticados.
drop policy if exists "Fotos_Storage authenticated read" on storage.objects;
create policy "Fotos_Storage authenticated read"
on storage.objects
for select
to authenticated
using (bucket_id = 'Fotos_Storage');

-- Realtime para atualizar a tela quando chegar relato/foto/status.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'Relato'
  ) then
    alter publication supabase_realtime add table public."Relato";
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'Foto'
  ) then
    alter publication supabase_realtime add table public."Foto";
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'Ocorrencia_Status'
  ) then
    alter publication supabase_realtime add table public."Ocorrencia_Status";
  end if;
exception
  when duplicate_object then
    null;
end $$;

notify pgrst, 'reload schema';
