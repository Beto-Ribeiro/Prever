-- SMDN - Auditoria real + permissões por usuário + reset de perfil
-- Rode no Supabase Dashboard > SQL Editor.

alter table public."Perfis"
  add column if not exists prf_permissoes jsonb not null default '{
    "dashboard": true,
    "reportar": true,
    "ocorrencias": true,
    "relatorios": true,
    "auditoria": false,
    "admin": false
  }'::jsonb,
  add column if not exists prf_avatar_url text,
  add column if not exists prf_telefone text,
  add column if not exists prf_email_contato text;

create or replace function public.is_web_admin()
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
      and lower(coalesce(p.prf_tipo, '')) in ('admin', 'adm', 'administrador', 'administradora')
  );
$$;

create table if not exists public."Atividade_Usuario" (
  atu_id uuid primary key default gen_random_uuid(),
  atu_user_id uuid not null references auth.users(id) on delete cascade,
  atu_actor_id uuid references auth.users(id),
  atu_action text not null,
  atu_detail text,
  atu_metadata jsonb not null default '{}'::jsonb,
  atu_created_at timestamptz not null default now()
);

alter table public."Atividade_Usuario" enable row level security;

drop policy if exists "Atividade_Usuario select own or admin" on public."Atividade_Usuario";
create policy "Atividade_Usuario select own or admin"
on public."Atividade_Usuario"
for select
to authenticated
using (atu_user_id = auth.uid() or public.is_web_admin());

drop policy if exists "Atividade_Usuario admin insert" on public."Atividade_Usuario";
create policy "Atividade_Usuario admin insert"
on public."Atividade_Usuario"
for insert
to authenticated
with check (public.is_web_admin());

drop policy if exists "Atividade_Usuario admin update" on public."Atividade_Usuario";
create policy "Atividade_Usuario admin update"
on public."Atividade_Usuario"
for update
to authenticated
using (public.is_web_admin())
with check (public.is_web_admin());

create or replace function public.admin_reset_user_profile(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor_id uuid;
  actor_name text;
  target_name text;
begin
  actor_id := auth.uid();

  if actor_id is null or not public.is_web_admin() then
    raise exception 'Apenas administradores podem zerar perfil.';
  end if;

  select coalesce(prf_nome, 'Administrador') into actor_name
  from public."Perfis"
  where prf_id = actor_id;

  select coalesce(prf_nome, 'Usuário') into target_name
  from public."Perfis"
  where prf_id = target_user_id;

  delete from public."Administrador" where adm_id = target_user_id;
  delete from public."Funcionario" where fun_id = target_user_id;
  delete from public."Instituicao" where ins_id = target_user_id;

  update public."Perfis"
  set
    prf_tipo = 'pendente',
    prf_telefone = null,
    prf_email_contato = null,
    prf_avatar_url = null,
    prf_permissoes = '{}'::jsonb
  where prf_id = target_user_id;

  insert into public."Atividade_Usuario" (
    atu_user_id,
    atu_actor_id,
    atu_action,
    atu_detail,
    atu_metadata
  ) values (
    target_user_id,
    actor_id,
    'Perfil zerado pelo administrador',
    'Perfil de acesso zerado por administrador.',
    jsonb_build_object(
      'actorName', actor_name,
      'targetName', target_name,
      'kind', 'reset_profile'
    )
  );

  insert into public."Audit_Log" (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    detail,
    metadata
  ) values (
    actor_id,
    'admin_reset_user_profile',
    'Perfis',
    target_user_id,
    concat('Perfil de ', coalesce(target_name, target_user_id::text), ' zerado por ', coalesce(actor_name, actor_id::text), '.'),
    jsonb_build_object('actorName', actor_name, 'targetName', target_name)
  );
end;
$$;

-- Realtime para auditoria e atividades.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'Audit_Log'
  ) then
    alter publication supabase_realtime add table public."Audit_Log";
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'Atividade_Usuario'
  ) then
    alter publication supabase_realtime add table public."Atividade_Usuario";
  end if;
end $$;

notify pgrst, 'reload schema';
