-- SMDN - Admin panel + solicitações de alteração de perfil
-- Rode no Supabase Dashboard > SQL Editor.
-- Este SQL cria as tabelas que o Painel do Administrador espera e adiciona o fluxo
-- de solicitação de alteração de perfil para usuários não-admin.

-- Campos extras seguros no perfil público do usuário.
alter table public."Perfis"
  add column if not exists prf_telefone text,
  add column if not exists prf_email_contato text;

-- Helper para policies: considera admin quem tem Perfis.prf_tipo administrativo.
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

-- Solicitações de acesso web.
create table if not exists public."Solicitacao_Acesso_Web" (
  saw_id uuid primary key default gen_random_uuid(),
  saw_nome text not null,
  saw_email text not null,
  saw_documento text,
  saw_instituicao text,
  saw_cargo text,
  saw_tipo_agente text,
  saw_status text not null default 'pendente' check (saw_status in ('pendente', 'aprovado', 'recusado', 'banido')),
  saw_observacao text,
  saw_created_at timestamptz not null default now(),
  saw_reviewed_by uuid references auth.users(id),
  saw_reviewed_at timestamptz
);

alter table public."Solicitacao_Acesso_Web" enable row level security;

drop policy if exists "Solicitacao_Acesso_Web insert public" on public."Solicitacao_Acesso_Web";
create policy "Solicitacao_Acesso_Web insert public"
on public."Solicitacao_Acesso_Web"
for insert
to anon, authenticated
with check (true);

drop policy if exists "Solicitacao_Acesso_Web admin select" on public."Solicitacao_Acesso_Web";
create policy "Solicitacao_Acesso_Web admin select"
on public."Solicitacao_Acesso_Web"
for select
to authenticated
using (public.is_web_admin());

drop policy if exists "Solicitacao_Acesso_Web admin update" on public."Solicitacao_Acesso_Web";
create policy "Solicitacao_Acesso_Web admin update"
on public."Solicitacao_Acesso_Web"
for update
to authenticated
using (public.is_web_admin())
with check (public.is_web_admin());

-- Solicitações de alteração de perfil.
-- Importante: senha nova não é armazenada aqui. Para senha, guardamos apenas pedido de redefinição.
create table if not exists public."Solicitacao_Alteracao_Perfil" (
  sap_id uuid primary key default gen_random_uuid(),
  sap_user_id uuid not null references auth.users(id) on delete cascade,
  sap_nome_solicitante text,
  sap_email_solicitante text,
  sap_alteracoes jsonb not null default '{}'::jsonb,
  sap_status text not null default 'pendente' check (sap_status in ('pendente', 'aprovado', 'recusado')),
  sap_observacao text,
  sap_created_at timestamptz not null default now(),
  sap_reviewed_by uuid references auth.users(id),
  sap_reviewed_at timestamptz
);

alter table public."Solicitacao_Alteracao_Perfil" enable row level security;

drop policy if exists "Solicitacao_Alteracao_Perfil insert own" on public."Solicitacao_Alteracao_Perfil";
create policy "Solicitacao_Alteracao_Perfil insert own"
on public."Solicitacao_Alteracao_Perfil"
for insert
to authenticated
with check (sap_user_id = auth.uid());

drop policy if exists "Solicitacao_Alteracao_Perfil select own or admin" on public."Solicitacao_Alteracao_Perfil";
create policy "Solicitacao_Alteracao_Perfil select own or admin"
on public."Solicitacao_Alteracao_Perfil"
for select
to authenticated
using (sap_user_id = auth.uid() or public.is_web_admin());

drop policy if exists "Solicitacao_Alteracao_Perfil admin update" on public."Solicitacao_Alteracao_Perfil";
create policy "Solicitacao_Alteracao_Perfil admin update"
on public."Solicitacao_Alteracao_Perfil"
for update
to authenticated
using (public.is_web_admin())
with check (public.is_web_admin());

-- Auditoria básica do painel.
create table if not exists public."Audit_Log" (
  log_id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  detail text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public."Audit_Log" enable row level security;

drop policy if exists "Audit_Log admin select" on public."Audit_Log";
create policy "Audit_Log admin select"
on public."Audit_Log"
for select
to authenticated
using (public.is_web_admin());

drop policy if exists "Audit_Log admin insert" on public."Audit_Log";
create policy "Audit_Log admin insert"
on public."Audit_Log"
for insert
to authenticated
with check (public.is_web_admin());

-- Atualiza o cache do PostgREST para remover erro de schema cache.
notify pgrst, 'reload schema';
