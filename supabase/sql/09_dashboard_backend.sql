-- SMDN - Backend real do Dashboard
-- Rode no Supabase Dashboard > SQL Editor.
-- Este SQL cria uma RPC para o Dashboard consumir Relato/Foto/Cidadao/Alerta_Web
-- sem depender de mocks no front-end.

create or replace function public.dashboard_severity_from_relato(nivel text)
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

create or replace function public.get_dashboard_data()
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  with relato_base as (
    select
      r.rel_id,
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
      foto.fto_url
    from public."Relato" r
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
  ordered_relato as (
    select *
    from relato_base
    order by rel_data_hora desc nulls last, rel_id desc
    limit 30
  )
  select jsonb_build_object(
    'stats', jsonb_build_object(
      'activeOccurrences', (select count(*) from relato_base),
      'activeAlerts', (
        select count(*)
        from public."Alerta_Web" a
        where coalesce(a.alw_status, 'disparado') = 'disparado'
      ),
      'criticalSeverity', (
        select count(*)
        from relato_base rb
        where public.dashboard_severity_from_relato(rb.rel_descricao) = 'critical'
      ),
      'resolvedToday', (
        select count(*)
        from public."Alerta_Web" a
        where a.alw_status = 'resolvido'
          and a.alw_created_at::date = current_date
      )
    ),
    'recentOccurrences', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', rel_id,
          'type', coalesce(rel_tipo_desastre, 'Relato'),
          'title', concat(coalesce(rel_tipo_desastre, 'Relato'), ' reportado'),
          'severity', public.dashboard_severity_from_relato(rel_descricao),
          'riskLabel', coalesce(rel_descricao, 'Não informado'),
          'city', case
            when lat is not null and lng is not null then 'Local informado'
            else 'Local não informado'
          end,
          'lat', lat,
          'lng', lng,
          'reportedAt', rel_data_hora,
          'citizenId', rel_cid_id,
          'citizenName', coalesce(cidadao_nome, 'Cidadão não identificado'),
          'photoPath', fto_url
        )
        order by rel_data_hora desc nulls last, rel_id desc
      )
      from ordered_relato
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_dashboard_data() from public;
grant execute on function public.get_dashboard_data() to authenticated;

-- Permite que usuários autenticados gerem signed URLs das fotos dos relatos.
-- O bucket atual encontrado no projeto é Fotos_Storage.
drop policy if exists "Fotos_Storage authenticated read" on storage.objects;
create policy "Fotos_Storage authenticated read"
on storage.objects
for select
to authenticated
using (bucket_id = 'Fotos_Storage');

-- Habilita eventos realtime para o Dashboard quando possível.
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
      and tablename = 'Alerta_Web'
  ) then
    alter publication supabase_realtime add table public."Alerta_Web";
  end if;
exception
  when duplicate_object then
    null;
end $$;

notify pgrst, 'reload schema';
