-- Applied to SMDN for the report history card. No report contents are stored.
begin;
create table if not exists public.shelter_report_history (
 id uuid primary key default gen_random_uuid(),
 shelter_id uuid not null references public."Abrigo"(abr_id),
 actor_id uuid not null default auth.uid() references auth.users(id),
 report_type text not null check (report_type in ('Completo','Ocupantes','Estoque','Pedidos','Doações','Atividades')),
 format text not null check (format in ('pdf','xlsx')),
 start_date date not null,
 end_date date not null check (end_date >= start_date),
 created_at timestamptz not null default now()
);
create index if not exists shelter_report_history_shelter_date_idx on public.shelter_report_history(shelter_id,created_at desc);
alter table public.shelter_report_history enable row level security;
revoke all on public.shelter_report_history from anon,authenticated;
grant select on public.shelter_report_history to authenticated;
grant insert (shelter_id,actor_id,report_type,format,start_date,end_date) on public.shelter_report_history to authenticated;
drop policy if exists "manager report history read" on public.shelter_report_history;
create policy "manager report history read" on public.shelter_report_history for select to authenticated using (prever_private.manages(shelter_id));
drop policy if exists "manager report history insert" on public.shelter_report_history;
create policy "manager report history insert" on public.shelter_report_history for insert to authenticated with check (actor_id = (select auth.uid()) and prever_private.manages(shelter_id));
commit;
