-- SMDN - Dashboard: atendimento de vítimas e estatísticas
-- OBS: já aplicado no Supabase do projeto robfgvtnoooivihlnomr.
-- Este arquivo fica no patch para versionamento/backup.

create table if not exists public."Vitima_Atendimento" (
  vat_victim_id text primary key,
  vat_status text not null default 'pendente' check (vat_status in ('pendente', 'atendida')),
  vat_name text,
  vat_lat double precision,
  vat_llng double precision,
  vat_source text,
  vat_updated_by uuid references auth.users(id),
  vat_updated_at timestamptz not null default now(),
  vat_metadata jsonb not null default '{}'::jsonb
);

alter table public."Vitima_Atendimento" enable row level security;

drop policy if exists "Vitima_Atendimento select web" on public."Vitima_Atendimento";
create policy "Vitima_Atendimento select web"
on public."Vitima_Atendimento"
for select
to authenticated
using (public.can_manage_occurrences());

drop policy if exists "Vitima_Atendimento write web" on public."Vitima_Atendimento";
create policy "Vitima_Atendimento write web"
on public."Vitima_Atendimento"
for all
to authenticated
using (public.can_manage_occurrences())
with check (public.can_manage_occurrences());

create or replace function public.update_victim_assistance(
  p_victim_id text,
  p_status text default 'atendida',
  p_name text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_source text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_actor_name text;
begin
  if not public.can_manage_occurrences() then
    raise exception 'Usuário sem permissão para atualizar atendimento de vítimas.';
  end if;

  if nullif(trim(p_victim_id), '') is null then
    raise exception 'Identificador da vítima não informado.';
  end if;

  if p_status not in ('pendente', 'atendida') then
    raise exception 'Status de vítima inválido: %', p_status;
  end if;

  select prf_nome into v_actor_name
  from public."Perfis"
  where prf_id = auth.uid()
  limit 1;

  insert into public."Vitima_Atendimento" (
    vat_victim_id, vat_status, vat_name, vat_lat, vat_llng, vat_source,
    vat_updated_by, vat_updated_at, vat_metadata
  )
  values (
    p_victim_id, p_status, p_name, p_lat, p_lng, p_source,
    auth.uid(), now(),
    jsonb_build_object('actorName', coalesce(v_actor_name, 'Usuário SMDN'), 'updatedBy', auth.uid(), 'updatedAt', now())
  )
  on conflict (vat_victim_id) do update
  set
    vat_status = excluded.vat_status,
    vat_name = coalesce(excluded.vat_name, public."Vitima_Atendimento".vat_name),
    vat_lat = coalesce(excluded.vat_lat, public."Vitima_Atendimento".vat_lat),
    vat_llng = coalesce(excluded.vat_llng, public."Vitima_Atendimento".vat_llng),
    vat_source = coalesce(excluded.vat_source, public."Vitima_Atendimento".vat_source),
    vat_updated_by = excluded.vat_updated_by,
    vat_updated_at = excluded.vat_updated_at,
    vat_metadata = excluded.vat_metadata;

  insert into public."Audit_Log" (actor_user_id, action, entity_type, detail, metadata)
  values (
    auth.uid(),
    'victim_assistance_updated',
    'Vitima_Atendimento',
    'Status da vítima atualizado para ' || p_status || '.',
    jsonb_build_object('victimId', p_victim_id, 'victimName', p_name, 'status', p_status, 'lat', p_lat, 'lng', p_lng, 'source', p_source, 'actorName', coalesce(v_actor_name, 'Usuário SMDN'))
  );

  return jsonb_build_object('ok', true, 'victimId', p_victim_id, 'status', p_status);
end;
$$;

grant execute on function public.update_victim_assistance(text, text, text, double precision, double precision, text) to authenticated;

-- A função public.get_dashboard_data() também foi atualizada no Supabase para retornar:
-- stats.assistedVictims e victims[].assistanceStatus / assistedAt / assistedBy.
notify pgrst, 'reload schema';
