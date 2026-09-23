-- SMDN - Atividade recente detalhada no Perfil
-- Rode no Supabase Dashboard > SQL Editor.
-- Este SQL cria logs detalhados de login e ocorrência.

create or replace function public.record_user_login_activity(client_context jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_headers jsonb := '{}'::jsonb;
  v_headers_raw text;
  v_ip text;
  v_user_agent text;
  v_fingerprint text;
  v_browser_seen_before boolean := false;
  v_known_location boolean := false;
  v_is_new_location boolean := true;
  v_activity_id uuid;
begin
  if v_uid is null then
    raise exception 'Sessão inválida para registrar login.';
  end if;

  v_headers_raw := current_setting('request.headers', true);

  if v_headers_raw is not null and length(trim(v_headers_raw)) > 0 then
    begin
      v_headers := v_headers_raw::jsonb;
    exception when others then
      v_headers := '{}'::jsonb;
    end;
  end if;

  v_ip := coalesce(
    nullif(split_part(coalesce(v_headers->>'x-forwarded-for', ''), ',', 1), ''),
    nullif(v_headers->>'cf-connecting-ip', ''),
    nullif(v_headers->>'x-real-ip', ''),
    'IP não disponível'
  );

  v_user_agent := coalesce(
    nullif(client_context->>'userAgent', ''),
    nullif(v_headers->>'user-agent', ''),
    'Navegador não informado'
  );

  v_fingerprint := md5(coalesce(client_context->>'fingerprint', v_user_agent));
  v_browser_seen_before := coalesce((client_context->>'browserSeenBefore')::boolean, false);

  select exists (
    select 1
    from public."Atividade_Usuario" a
    where a.atu_user_id = v_uid
      and a.atu_metadata->>'kind' = 'login'
      and (
        nullif(a.atu_metadata->>'ip', '') = v_ip
        or nullif(a.atu_metadata->>'fingerprint', '') = v_fingerprint
      )
  ) into v_known_location;

  v_is_new_location := not v_known_location;

  insert into public."Atividade_Usuario" (
    atu_user_id,
    atu_actor_id,
    atu_action,
    atu_detail,
    atu_metadata
  )
  values (
    v_uid,
    v_uid,
    'Login realizado',
    case when v_is_new_location then 'Login realizado em um local novo.' else 'Login realizado.' end,
    jsonb_build_object(
      'kind', 'login',
      'ip', v_ip,
      'isNewLocation', v_is_new_location,
      'knownLocation', v_known_location,
      'browserSeenBefore', v_browser_seen_before,
      'fingerprint', v_fingerprint,
      'userAgent', v_user_agent,
      'timezone', client_context->>'timezone',
      'language', client_context->>'language',
      'platform', client_context->>'platform',
      'screen', client_context->'screen',
      'recordedAt', now()
    )
  )
  returning atu_id into v_activity_id;

  return jsonb_build_object(
    'ok', true,
    'activityId', v_activity_id,
    'ip', v_ip,
    'isNewLocation', v_is_new_location
  );
end;
$$;

grant execute on function public.record_user_login_activity(jsonb) to authenticated;

create or replace function public.record_relato_activity()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_lat double precision;
  v_lng double precision;
begin
  if new.rel_localizacao is not null then
    v_lat := extensions.st_y(new.rel_localizacao::extensions.geometry);
    v_lng := extensions.st_x(new.rel_localizacao::extensions.geometry);
  end if;

  if new.rel_cid_id is not null then
    insert into public."Atividade_Usuario" (
      atu_user_id,
      atu_actor_id,
      atu_action,
      atu_detail,
      atu_metadata
    )
    values (
      new.rel_cid_id,
      new.rel_cid_id,
      'Ocorrência enviada',
      'Relato enviado pelo cidadão.',
      jsonb_build_object(
        'kind', 'occurrence_reported',
        'occurrence', jsonb_build_object(
          'relatoId', new.rel_id,
          'tipo', new.rel_tipo_desastre,
          'risco', new.rel_descricao,
          'dataHora', new.rel_data_hora,
          'status', 'active',
          'lat', v_lat,
          'lng', v_lng
        )
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_record_relato_activity on public."Relato";
create trigger trg_record_relato_activity
after insert on public."Relato"
for each row
execute function public.record_relato_activity();

create or replace function public.update_ocorrencia_status(
  p_rel_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_relato record;
  v_actor_name text;
begin
  if not public.can_manage_occurrences() then
    raise exception 'Usuário sem permissão para atualizar ocorrências.';
  end if;

  if p_status not in ('active', 'monitoring', 'resolved') then
    raise exception 'Status inválido: %', p_status;
  end if;

  select
    r.rel_id,
    r.rel_tipo_desastre,
    r.rel_descricao,
    r.rel_data_hora,
    r.rel_cid_id,
    case when r.rel_localizacao is not null then extensions.st_y(r.rel_localizacao::extensions.geometry) else null end as lat,
    case when r.rel_localizacao is not null then extensions.st_x(r.rel_localizacao::extensions.geometry) else null end as lng,
    p.prf_nome as cidadao_nome
  into v_relato
  from public."Relato" r
  left join public."Cidadao" c on c.cid_id = r.rel_cid_id
  left join public."Perfis" p on p.prf_id = c.cid_id
  where r.rel_id = p_rel_id
  limit 1;

  if v_relato.rel_id is null then
    raise exception 'Ocorrência não encontrada: %', p_rel_id;
  end if;

  select prf_nome
  into v_actor_name
  from public."Perfis"
  where prf_id = auth.uid()
  limit 1;

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

  insert into public."Atividade_Usuario" (
    atu_user_id,
    atu_actor_id,
    atu_action,
    atu_detail,
    atu_metadata
  )
  values (
    auth.uid(),
    auth.uid(),
    'Ocorrência atualizada',
    'Status da ocorrência atualizado para ' || p_status || '.',
    jsonb_build_object(
      'kind', 'occurrence_status',
      'actorName', coalesce(v_actor_name, 'Usuário SMDN'),
      'occurrence', jsonb_build_object(
        'relatoId', v_relato.rel_id,
        'tipo', v_relato.rel_tipo_desastre,
        'risco', v_relato.rel_descricao,
        'status', p_status,
        'dataHora', v_relato.rel_data_hora,
        'cidadaoId', v_relato.rel_cid_id,
        'cidadaoNome', v_relato.cidadao_nome,
        'lat', v_relato.lat,
        'lng', v_relato.lng
      )
    )
  );

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
    jsonb_build_object(
      'status', p_status,
      'occurrence', jsonb_build_object(
        'relatoId', v_relato.rel_id,
        'tipo', v_relato.rel_tipo_desastre,
        'risco', v_relato.rel_descricao,
        'lat', v_relato.lat,
        'lng', v_relato.lng
      )
    )
  );

  return jsonb_build_object('ok', true, 'relatoId', p_rel_id, 'status', p_status);
end;
$$;

grant execute on function public.update_ocorrencia_status(uuid, text) to authenticated;

notify pgrst, 'reload schema';
