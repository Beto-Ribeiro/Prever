-- SMDN - Mostra alertas disparados na Atividade Recente do Perfil
-- Este SQL já foi aplicado no Supabase deste projeto, mas fica aqui para versionar.

create or replace function public.record_alerta_web_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.alw_operador_id is not null then
    insert into public."Atividade_Usuario" (
      atu_user_id,
      atu_actor_id,
      atu_action,
      atu_detail,
      atu_metadata
    )
    values (
      new.alw_operador_id,
      new.alw_operador_id,
      'Alerta disparado',
      'Alerta web disparado para ' || coalesce(new.alw_destinatarios, 0)::text || ' destinatário(s).',
      jsonb_build_object(
        'kind', 'web_alert',
        'alert', jsonb_build_object(
          'alertId', new.alw_id,
          'tipo', new.alw_tipo,
          'cidade', new.alw_cidade,
          'bairro', new.alw_bairro,
          'severidade', new.alw_severidade,
          'descricao', new.alw_descricao,
          'destinatarios', new.alw_destinatarios,
          'status', new.alw_status,
          'lat', new.alw_lat,
          'lng', new.alw_lng,
          'criadoEm', new.alw_created_at
        )
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_record_alerta_web_activity on public."Alerta_Web";
create trigger trg_record_alerta_web_activity
after insert on public."Alerta_Web"
for each row
execute function public.record_alerta_web_activity();

-- Backfill: adiciona no histórico os alertas que já tinham sido disparados.
insert into public."Atividade_Usuario" (
  atu_user_id,
  atu_actor_id,
  atu_action,
  atu_detail,
  atu_metadata,
  atu_created_at
)
select
  a.alw_operador_id,
  a.alw_operador_id,
  'Alerta disparado',
  'Alerta web disparado para ' || coalesce(a.alw_destinatarios, 0)::text || ' destinatário(s).',
  jsonb_build_object(
    'kind', 'web_alert',
    'alert', jsonb_build_object(
      'alertId', a.alw_id,
      'tipo', a.alw_tipo,
      'cidade', a.alw_cidade,
      'bairro', a.alw_bairro,
      'severidade', a.alw_severidade,
      'descricao', a.alw_descricao,
      'destinatarios', a.alw_destinatarios,
      'status', a.alw_status,
      'lat', a.alw_lat,
      'lng', a.alw_lng,
      'criadoEm', a.alw_created_at
    )
  ),
  a.alw_created_at
from public."Alerta_Web" a
where a.alw_operador_id is not null
  and not exists (
    select 1
    from public."Atividade_Usuario" au
    where au.atu_user_id = a.alw_operador_id
      and au.atu_metadata->>'kind' = 'web_alert'
      and au.atu_metadata->'alert'->>'alertId' = a.alw_id::text
  );
