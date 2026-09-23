-- Já aplicado no Supabase em robfgvtnoooivihlnomr.
-- Mantido aqui para versionamento/reaplicação se necessário.

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
  ),
  victims_from_tokens as (
    select
      coalesce(nullif(t.user_id, ''), t.id::text) as victim_id,
      t.lat,
      t.lng,
      coalesce(p.prf_nome, 'Vítima localizada') as victim_name,
      'localizacao_dispositivo'::text as source,
      1 as priority,
      t.updated_at as updated_at
    from public.user_tokens t
    left join public."Perfis" p
      on p.prf_id = case
        when t.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then t.user_id::uuid
        else null
      end
    where t.lat is not null
      and t.lng is not null
  ),
  victims_from_relatos as (
    select distinct on (rb.rel_cid_id)
      rb.rel_cid_id::text as victim_id,
      rb.lat,
      rb.lng,
      coalesce(rb.cidadao_nome, 'Vítima vinculada ao relato') as victim_name,
      'relato'::text as source,
      2 as priority,
      rb.rel_data_hora::timestamptz as updated_at
    from relato_base rb
    where rb.rel_cid_id is not null
      and rb.lat is not null
      and rb.lng is not null
    order by rb.rel_cid_id, rb.rel_data_hora desc nulls last, rb.rel_id desc
  ),
  victim_source as (
    select * from victims_from_tokens
    union all
    select * from victims_from_relatos
  ),
  victim_base as (
    select distinct on (victim_id)
      victim_id,
      lat,
      lng,
      victim_name,
      source,
      updated_at
    from victim_source
    where lat is not null
      and lng is not null
    order by victim_id, priority, updated_at desc nulls last
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
      ),
      'locatedVictims', (select count(*) from victim_base)
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
    ), '[]'::jsonb),
    'victims', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', victim_id,
          'name', victim_name,
          'lat', lat,
          'lng', lng,
          'source', source,
          'updatedAt', updated_at
        )
        order by updated_at desc nulls last, victim_id
      )
      from victim_base
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_dashboard_data() from public;
grant execute on function public.get_dashboard_data() to authenticated;
notify pgrst, 'reload schema';
