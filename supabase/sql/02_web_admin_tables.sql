-- SMDN - Backend de acesso web/admin
-- NÃO EXECUTAR AINDA sem revisar. Este arquivo foi criado para a branch supabase-migration.
-- Objetivo: separar cidadãos do mobile de usuários autorizados do painel web.

-- 1) Solicitações de acesso ao painel web
create table if not exists public."Solicitacao_Acesso_Web" (
  saw_id uuid primary key default gen_random_uuid(),
  saw_nome text not null,
  saw_email text not null,
  saw_instituicao text,
  saw_cargo text,
  saw_tipo_agente text,
  saw_status text not null default 'pendente'
    check (saw_status in ('pendente', 'aprovado', 'recusado', 'banido')),
  saw_observacao text,
  saw_created_at timestamptz not null default now(),
  saw_reviewed_by uuid references auth.users(id),
  saw_reviewed_at timestamptz
);

create index if not exists saw_status_idx
  on public."Solicitacao_Acesso_Web" (saw_status);

create index if not exists saw_email_idx
  on public."Solicitacao_Acesso_Web" (lower(saw_email));

-- 2) Registros administrativos / auditoria
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

create index if not exists audit_log_created_at_idx
  on public."Audit_Log" (created_at desc);

create index if not exists audit_log_actor_idx
  on public."Audit_Log" (actor_user_id);

-- 3) RLS das novas tabelas
alter table public."Solicitacao_Acesso_Web" enable row level security;
alter table public."Audit_Log" enable row level security;

-- Atenção: estas policies dependem de existir administrador em public."Administrador"
-- ou perfil com prf_tipo = administrador/admin.

-- Qualquer visitante pode solicitar acesso, mas somente como pendente.
drop policy if exists "visitantes podem solicitar acesso web" on public."Solicitacao_Acesso_Web";
create policy "visitantes podem solicitar acesso web"
  on public."Solicitacao_Acesso_Web"
  for insert
  to anon, authenticated
  with check (saw_status = 'pendente');

-- Administradores podem ler solicitações.
drop policy if exists "admins podem ler solicitacoes web" on public."Solicitacao_Acesso_Web";
create policy "admins podem ler solicitacoes web"
  on public."Solicitacao_Acesso_Web"
  for select
  to authenticated
  using (
    exists (
      select 1 from public."Administrador" adm
      where adm.adm_id = auth.uid()
    )
    or exists (
      select 1 from public."Perfis" p
      where p.prf_id = auth.uid()
        and lower(p.prf_tipo) in ('admin', 'administrador', 'administradora')
    )
  );

-- Administradores podem atualizar status das solicitações.
drop policy if exists "admins podem atualizar solicitacoes web" on public."Solicitacao_Acesso_Web";
create policy "admins podem atualizar solicitacoes web"
  on public."Solicitacao_Acesso_Web"
  for update
  to authenticated
  using (
    exists (
      select 1 from public."Administrador" adm
      where adm.adm_id = auth.uid()
    )
    or exists (
      select 1 from public."Perfis" p
      where p.prf_id = auth.uid()
        and lower(p.prf_tipo) in ('admin', 'administrador', 'administradora')
    )
  )
  with check (
    exists (
      select 1 from public."Administrador" adm
      where adm.adm_id = auth.uid()
    )
    or exists (
      select 1 from public."Perfis" p
      where p.prf_id = auth.uid()
        and lower(p.prf_tipo) in ('admin', 'administrador', 'administradora')
    )
  );

-- Auditoria: somente administradores leem.
drop policy if exists "admins podem ler audit log" on public."Audit_Log";
create policy "admins podem ler audit log"
  on public."Audit_Log"
  for select
  to authenticated
  using (
    exists (
      select 1 from public."Administrador" adm
      where adm.adm_id = auth.uid()
    )
    or exists (
      select 1 from public."Perfis" p
      where p.prf_id = auth.uid()
        and lower(p.prf_tipo) in ('admin', 'administrador', 'administradora')
    )
  );

-- Inserção de logs deve ser feita por backend seguro / Edge Function.
-- Não crie policy pública de insert em Audit_Log sem necessidade.

-- 4) Criar o primeiro administrador manualmente, quando você liberar mexer no banco:
-- 4.1 Crie o usuário em Authentication > Users > Add user.
-- 4.2 Copie o UUID do usuário criado.
-- 4.3 Rode algo assim, trocando os valores:
--
-- insert into public."Perfis" (prf_id, prf_nome, prf_tipo)
-- values ('UUID_DO_AUTH_USER', 'Nome do Administrador', 'administrador')
-- on conflict (prf_id) do update
-- set prf_nome = excluded.prf_nome,
--     prf_tipo = excluded.prf_tipo;
--
-- insert into public."Administrador" (adm_id, adm_apelido)
-- values ('UUID_DO_AUTH_USER', 'admin-smdn')
-- on conflict (adm_id) do update
-- set adm_apelido = excluded.adm_apelido;

-- 5) Observação importante sobre RLS atual
-- O Supabase apontou RLS desativado em algumas tabelas antigas:
-- public."Cidadao", public."Historico_Medicacao_Cidadao", public."Relato", public."Foto", public."Perfis".
-- Não ative RLS nelas sem criar policies antes, porque pode bloquear o app inteiro.
