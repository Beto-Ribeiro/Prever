-- SMDN - Lista de usuário separada + atividades de perfil
-- Rode no Supabase Dashboard > SQL Editor.
-- Cria suporte para foto/avatar do perfil e registra atividades quando admin edita outro usuário.

alter table public."Perfis"
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

notify pgrst, 'reload schema';
