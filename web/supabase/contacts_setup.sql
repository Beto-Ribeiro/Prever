begin;
-- Preserve contact exactly as recorded by previous clients. New forms use dedicated fields.
alter table public.shelter_residents add column if not exists responsible_name text not null default '' check(length(responsible_name)<=160);
alter table public.shelter_residents add column if not exists responsible_contact text not null default '' check(length(responsible_contact)<=120);
alter table public.shelter_donations add column if not exists donor_contact text not null default '' check(length(donor_contact)<=120);
alter table public."Abrigo" add column if not exists abr_coordenador_contato text not null default '' check(length(abr_coordenador_contato)<=120);
grant insert(responsible_name,responsible_contact),update(responsible_name,responsible_contact) on public.shelter_residents to authenticated;
grant insert(donor_contact) on public.shelter_donations to authenticated;
grant insert(abr_coordenador_contato),update(abr_coordenador_contato) on public."Abrigo" to authenticated;
create or replace function prever_private.update_shelter_contacts(s uuid,n text,address text,phone text,capacity integer,coordinator_name text,coordinator_contact text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not prever_private.manages(s) then raise exception 'Acesso não autorizado.' using errcode='42501'; end if;
 if coordinator_name is null or coordinator_contact is null or length(trim(coordinator_name))>160 or length(trim(coordinator_contact))>120 then raise exception 'Confira o nome e o contato do responsável.'; end if;
 perform prever_private.update_shelter(s,n,address,phone,capacity);
 update public."Abrigo" set abr_coordenador=nullif(trim(coordinator_name),''),abr_coordenador_contato=trim(coordinator_contact) where abr_id=s;
end $$;
create or replace function public.manager_update_shelter_contacts(s uuid,n text,address text,phone text,capacity integer,coordinator_name text,coordinator_contact text)
returns void language sql security invoker set search_path='' as $$select prever_private.update_shelter_contacts(s,n,address,phone,capacity,coordinator_name,coordinator_contact);$$;
revoke all on function prever_private.update_shelter_contacts(uuid,text,text,text,integer,text,text),public.manager_update_shelter_contacts(uuid,text,text,text,integer,text,text) from public,anon;
grant execute on function prever_private.update_shelter_contacts(uuid,text,text,text,integer,text,text),public.manager_update_shelter_contacts(uuid,text,text,text,integer,text,text) to authenticated;
commit;
