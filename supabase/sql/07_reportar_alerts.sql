-- SMDN - Alertas reais da tela Reportar
-- Rode no Supabase Dashboard > SQL Editor.
-- Cria um histórico independente para a tela Reportar, sem depender de mocks.

create table if not exists public."Alerta_Web" (
  alw_id uuid primary key default gen_random_uuid(),
  alw_tipo text not null,
  alw_cidade text not null,
  alw_bairro text,
  alw_severidade text not null check (alw_severidade in ('critical', 'severe', 'regular')),
  alw_descricao text not null,
  alw_destinatarios integer not null default 0,
  alw_operador_id uuid references auth.users(id) on delete set null,
  alw_operador_nome text,
  alw_status text not null default 'disparado' check (alw_status in ('disparado', 'resolvido', 'cancelado')),
  alw_lat double precision,
  alw_lng double precision,
  alw_metadata jsonb not null default '{}'::jsonb,
  alw_created_at timestamptz not null default now()
);

alter table public."Alerta_Web" enable row level security;

create index if not exists idx_alerta_web_created_at on public."Alerta_Web" (alw_created_at desc);
create index if not exists idx_alerta_web_cidade on public."Alerta_Web" (alw_cidade);
create index if not exists idx_alerta_web_severidade on public."Alerta_Web" (alw_severidade);

drop policy if exists "Alerta_Web select authenticated" on public."Alerta_Web";
create policy "Alerta_Web select authenticated"
on public."Alerta_Web"
for select
to authenticated
using (true);

drop policy if exists "Alerta_Web insert authenticated" on public."Alerta_Web";
create policy "Alerta_Web insert authenticated"
on public."Alerta_Web"
for insert
to authenticated
with check (alw_operador_id = auth.uid());

drop policy if exists "Alerta_Web admin update" on public."Alerta_Web";
create policy "Alerta_Web admin update"
on public."Alerta_Web"
for update
to authenticated
using (public.is_web_admin())
with check (public.is_web_admin());

-- Realtime para histórico de alertas.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'Alerta_Web'
  ) then
    alter publication supabase_realtime add table public."Alerta_Web";
  end if;
end $$;

-- Realtime para atualizar total de destinatários quando cidadãos mudarem.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'Cidadao'
  ) then
    alter publication supabase_realtime add table public."Cidadao";
  end if;
end $$;

notify pgrst, 'reload schema';
