-- Estrutura para a tela Web > Abrigos.
-- Mantém os dados no Supabase; não há persistência em localStorage no front-end.

create table if not exists public."Abrigo" (
  abr_id uuid primary key default gen_random_uuid(),
  abr_nome text not null,
  abr_tipo text not null,
  abr_capacidade integer not null check (abr_capacidade > 0),
  abr_ocupacao integer not null default 0 check (abr_ocupacao >= 0),
  abr_acessibilidade text,
  abr_aceita_pets text,
  abr_coordenador text,
  abr_telefone_principal text,
  abr_telefone_secundario text,
  abr_cidade text,
  abr_bairro text,
  abr_lat double precision,
  abr_lng double precision,
  abr_status text not null default 'disponivel' check (abr_status in ('disponivel','quase_lotado','lotado','inativo')),
  abr_created_by uuid references auth.users(id) on delete set null,
  abr_created_at timestamp with time zone not null default now(),
  abr_updated_at timestamp with time zone not null default now(),
  constraint Abrigo_ocupacao_capacidade_check check (abr_ocupacao <= abr_capacidade)
);

alter table public."Abrigo" enable row level security;

drop policy if exists "Abrigo select web" on public."Abrigo";
drop policy if exists "Abrigo write web" on public."Abrigo";
drop policy if exists "Abrigo insert web" on public."Abrigo";
drop policy if exists "Abrigo update web" on public."Abrigo";
drop policy if exists "Abrigo delete web" on public."Abrigo";

create policy "Abrigo select web" on public."Abrigo"
  for select to authenticated
  using (can_manage_occurrences());

create policy "Abrigo insert web" on public."Abrigo"
  for insert to authenticated
  with check (can_manage_occurrences());

create policy "Abrigo update web" on public."Abrigo"
  for update to authenticated
  using (can_manage_occurrences())
  with check (can_manage_occurrences());

create policy "Abrigo delete web" on public."Abrigo"
  for delete to authenticated
  using (can_manage_occurrences());

grant select, insert, update, delete on table public."Abrigo" to authenticated;

create index if not exists idx_abrigo_status on public."Abrigo" (abr_status);
create index if not exists idx_abrigo_cidade on public."Abrigo" (abr_cidade);
create index if not exists idx_abrigo_localizacao on public."Abrigo" (abr_lat, abr_lng);

insert into public."Abrigo" (
  abr_id,
  abr_nome,
  abr_tipo,
  abr_capacidade,
  abr_ocupacao,
  abr_acessibilidade,
  abr_aceita_pets,
  abr_coordenador,
  abr_telefone_principal,
  abr_telefone_secundario,
  abr_cidade,
  abr_bairro,
  abr_lat,
  abr_lng,
  abr_status
) values
  ('11111111-1111-4111-8111-111111111111', 'Etec Taubaté', 'Escola pública', 40, 2, 'Sim', 'Não', 'Defesa Civil Taubaté', '(12) 3625-0000', null, 'Taubaté', 'Centro', -23.0264, -45.5553, 'disponivel'),
  ('22222222-2222-4222-8222-222222222222', 'Etec JQA', 'Escola pública', 40, 20, 'Parcial', 'Sim', 'Operação Vale', '(12) 3642-0000', null, 'Pindamonhangaba', 'Moreira César', -22.9246, -45.4619, 'disponivel'),
  ('33333333-3333-4333-8333-333333333333', 'Etec Lorena', 'Ginásio', 40, 39, 'Sim', 'Não', 'Defesa Civil Lorena', '(12) 3153-0000', null, 'Lorena', 'Vila Geny', -22.7309, -45.1247, 'quase_lotado')
on conflict (abr_id) do nothing;
