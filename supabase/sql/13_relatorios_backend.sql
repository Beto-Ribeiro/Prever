-- SMDN - Backend real da tela de Relatórios
-- Rode no Supabase Dashboard > SQL Editor.
-- Cria uma RPC para calcular os gráficos a partir de Relato + Ocorrencia_Status.

create or replace function public.relatorio_period_start(p_period text)
returns timestamptz
language sql
stable
as $$
  select case lower(coalesce(p_period, '6m'))
    when '7d' then now() - interval '7 days'
    when '30d' then now() - interval '30 days'
    when '6m' then now() - interval '6 months'
    when '1y' then now() - interval '1 year'
    else now() - interval '6 months'
  end;
$$;

create or replace function public.relatorio_severity_key(nivel text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(nivel, '')) in ('crítico', 'critico', 'critical', 'muito alto', 'muito-alto') then 'critical'
    when lower(coalesce(nivel, '')) in ('alto', 'grave', 'severe') then 'severe'
    when lower(coalesce(nivel, '')) in ('moderado', 'medio', 'médio', 'moderate') then 'moderate'
    else 'normal'
  end;
$$;

create or replace function public.relatorio_city_from_coords(p_lat double precision, p_lng double precision)
returns text
language sql
immutable
as $$
  with cidades(nome, lat, lng) as (
    values
      ('Pindamonhangaba'::text, -22.9239::double precision, -45.4617::double precision),
      ('Roseira'::text, -22.8988::double precision, -45.3070::double precision),
      ('Taubaté'::text, -23.0264::double precision, -45.5553::double precision),
      ('São José dos Campos'::text, -23.2237::double precision, -45.9009::double precision),
      ('Jacareí'::text, -23.3053::double precision, -45.9658::double precision),
      ('Guaratinguetá'::text, -22.8164::double precision, -45.1927::double precision),
      ('Caraguatatuba'::text, -23.6203::double precision, -45.4131::double precision)
  )
  select case
    when p_lat is null or p_lng is null then 'Local não informado'
    else (
      select nome
      from cidades
      order by ((lat - p_lat) * (lat - p_lat)) + ((lng - p_lng) * (lng - p_lng))
      limit 1
    )
  end;
$$;

create or replace function public.relatorio_month_label(p_date date)
returns text
language sql
immutable
as $$
  select case extract(month from p_date)::int
    when 1 then 'Jan'
    when 2 then 'Fev'
    when 3 then 'Mar'
    when 4 then 'Abr'
    when 5 then 'Mai'
    when 6 then 'Jun'
    when 7 then 'Jul'
    when 8 then 'Ago'
    when 9 then 'Set'
    when 10 then 'Out'
    when 11 then 'Nov'
    when 12 then 'Dez'
  end;
$$;

create or replace function public.relatorio_pct(p_part numeric, p_total numeric)
returns integer
language sql
immutable
as $$
  select case
    when coalesce(p_total, 0) <= 0 then 0
    else least(100, greatest(0, round((coalesce(p_part, 0) / p_total) * 100)::integer))
  end;
$$;

create or replace function public.relatorio_delta_text(p_current numeric, p_previous numeric)
returns text
language sql
immutable
as $$
  select case
    when coalesce(p_previous, 0) = 0 and coalesce(p_current, 0) = 0 then '0%'
    when coalesce(p_previous, 0) = 0 then '+100%'
    else (
      case when ((p_current - p_previous) / p_previous) >= 0 then '+' else '' end
      || round(((p_current - p_previous) / p_previous) * 100)::int::text
      || '%'
    )
  end;
$$;

create or replace function public.get_relatorios_data(p_period text default '6m')
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  with params as (
    select
      public.relatorio_period_start(p_period) as start_at,
      now() as end_at
  ),
  ranges as (
    select
      start_at,
      end_at,
      start_at - (end_at - start_at) as previous_start_at
    from params
  ),
  base as (
    select
      r.rel_id,
      coalesce(nullif(r.rel_tipo_desastre, ''), 'Não informado') as tipo,
      coalesce(nullif(r.rel_descricao, ''), 'Normal') as descricao,
      public.relatorio_severity_key(r.rel_descricao) as severity_key,
      coalesce(r.rel_data_hora::timestamptz, now()) as event_at,
      coalesce(os.ocs_status, 'active') as status_key,
      case when r.rel_localizacao is not null then extensions.st_y(r.rel_localizacao::extensions.geometry) else null end as lat,
      case when r.rel_localizacao is not null then extensions.st_x(r.rel_localizacao::extensions.geometry) else null end as lng,
      p.prf_nome as cidadao_nome,
      r.rel_cid_id
    from public."Relato" r
    left join public."Ocorrencia_Status" os on os.ocs_rel_id = r.rel_id
    left join public."Cidadao" c on c.cid_id = r.rel_cid_id
    left join public."Perfis" p on p.prf_id = c.cid_id
  ),
  current_base as (
    select *
    from base, ranges
    where event_at >= ranges.start_at
      and event_at <= ranges.end_at
  ),
  previous_base as (
    select *
    from base, ranges
    where event_at >= ranges.previous_start_at
      and event_at < ranges.start_at
  ),
  totals as (
    select
      (select count(*) from current_base)::numeric as total_current,
      (select count(*) from previous_base)::numeric as total_previous,
      (select count(*) from current_base where status_key = 'resolved')::numeric as resolved_current,
      (select count(*) from previous_base where status_key = 'resolved')::numeric as resolved_previous
  ),
  month_series as (
    select generate_series(
      date_trunc('month', now())::date - interval '6 months',
      date_trunc('month', now())::date,
      interval '1 month'
    )::date as month_start
  ),
  monthly as (
    select
      ms.month_start,
      public.relatorio_month_label(ms.month_start) as month,
      count(cb.rel_id)::int as total,
      count(cb.rel_id) filter (where cb.severity_key = 'critical')::int as critical
    from month_series ms
    left join current_base cb
      on date_trunc('month', cb.event_at)::date = ms.month_start
    group by ms.month_start
    order by ms.month_start
  ),
  type_rows as (
    select
      tipo as type,
      count(*)::int as count,
      public.relatorio_pct(count(*)::numeric, nullif((select total_current from totals), 0)) as pct
    from current_base
    group by tipo
    order by count(*) desc, tipo
    limit 6
  ),
  city_rows as (
    select
      public.relatorio_city_from_coords(lat, lng) as city,
      count(*)::int as count
    from current_base
    group by public.relatorio_city_from_coords(lat, lng)
    order by count(*) desc, city
    limit 6
  ),
  severity_labels(key, label, ord) as (
    values
      ('critical'::text, 'Crítico'::text, 1),
      ('severe'::text, 'Grave'::text, 2),
      ('moderate'::text, 'Moderado'::text, 3),
      ('normal'::text, 'Normal'::text, 4)
  ),
  severity_rows as (
    select
      sl.label,
      count(cb.rel_id)::int as count,
      public.relatorio_pct(count(cb.rel_id)::numeric, nullif((select total_current from totals), 0)) as pct,
      case sl.key
        when 'critical' then 'bg-status-critical'
        when 'severe' then 'bg-status-severe'
        when 'moderate' then 'bg-status-regular'
        else 'bg-status-success'
      end as color,
      case sl.key
        when 'critical' then 'text-status-critical'
        when 'severe' then 'text-status-severe'
        when 'moderate' then 'text-status-regular'
        else 'text-status-success'
      end as text
    from severity_labels sl
    left join current_base cb on cb.severity_key = sl.key
    group by sl.key, sl.label, sl.ord
    order by sl.ord
  ),
  status_labels(key, label, color, ord) as (
    values
      ('resolved'::text, 'Resolvidas'::text, '#02c602'::text, 1),
      ('monitoring'::text, 'Em andamento'::text, '#ff6a00'::text, 2),
      ('active'::text, 'Pendentes'::text, '#c60202'::text, 3)
  ),
  status_rows as (
    select
      sl.label,
      count(cb.rel_id)::int as count,
      public.relatorio_pct(count(cb.rel_id)::numeric, nullif((select total_current from totals), 0)) as pct,
      sl.color
    from status_labels sl
    left join current_base cb on cb.status_key = sl.key
    group by sl.key, sl.label, sl.color, sl.ord
    order by sl.ord
  ),
  occurrence_rows as (
    select
      rel_id,
      tipo,
      descricao,
      case severity_key
        when 'critical' then 'Crítico'
        when 'severe' then 'Grave'
        when 'moderate' then 'Moderado'
        else 'Normal'
      end as severidade,
      case status_key
        when 'resolved' then 'Resolvida'
        when 'monitoring' then 'Em andamento'
        else 'Pendente'
      end as status,
      public.relatorio_city_from_coords(lat, lng) as municipio,
      cidadao_nome,
      lat,
      lng,
      event_at
    from current_base
    order by event_at desc
    limit 500
  )
  select jsonb_build_object(
    'periodKey', p_period,
    'generatedAt', now(),
    'kpis', jsonb_build_object(
      'total', (select total_current::int from totals),
      'totalDelta', public.relatorio_delta_text((select total_current from totals), (select total_previous from totals)),
      'totalPositive', (select total_current >= total_previous from totals),
      'resolutionRate', (
        public.relatorio_pct((select resolved_current from totals), nullif((select total_current from totals), 0))::text || '%'
      ),
      'resolutionDelta', public.relatorio_delta_text(
        public.relatorio_pct((select resolved_current from totals), nullif((select total_current from totals), 0))::numeric,
        public.relatorio_pct((select resolved_previous from totals), nullif((select total_previous from totals), 0))::numeric
      ),
      'resolutionPositive', (
        public.relatorio_pct((select resolved_current from totals), nullif((select total_current from totals), 0))
        >= public.relatorio_pct((select resolved_previous from totals), nullif((select total_previous from totals), 0))
      )
    ),
    'monthly', coalesce((select jsonb_agg(to_jsonb(monthly) order by month_start) from monthly), '[]'::jsonb),
    'byType', coalesce((select jsonb_agg(to_jsonb(type_rows)) from type_rows), '[]'::jsonb),
    'byCity', coalesce((select jsonb_agg(to_jsonb(city_rows)) from city_rows), '[]'::jsonb),
    'bySeverity', coalesce((select jsonb_agg(to_jsonb(severity_rows)) from severity_rows), '[]'::jsonb),
    'byStatus', coalesce((select jsonb_agg(to_jsonb(status_rows)) from status_rows), '[]'::jsonb),
    'occurrences', coalesce((select jsonb_agg(to_jsonb(occurrence_rows)) from occurrence_rows), '[]'::jsonb)
  );
$$;

revoke all on function public.get_relatorios_data(text) from public;
grant execute on function public.get_relatorios_data(text) to authenticated;

notify pgrst, 'reload schema';
