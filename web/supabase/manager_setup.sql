-- PREVER: perfil de gerente e operações do abrigo.
-- Aplicado pelo plugin Supabase; não contém credenciais nem dados de usuários.
create schema if not exists prever_private;
revoke all on schema prever_private from public;
grant usage on schema prever_private to authenticated, service_role;

create or replace function public.is_admin() returns boolean language sql stable security invoker set search_path='' as $$ select public.is_web_admin(); $$;
create or replace function public.is_func() returns boolean language sql stable security invoker set search_path='' as $$ select exists(select 1 from public."Perfis" where prf_id=auth.uid() and lower(prf_tipo) in ('funcionario','funcionário','employee')); $$;

-- Perfis controla autorização: cada pessoa lê seu perfil; só administradores alteram papéis.
alter table public."Perfis" enable row level security;
drop policy if exists "Alterar Perfis Somente Admins" on public."Perfis";
create policy "Perfis admin" on public."Perfis" for all to authenticated using(public.is_web_admin()) with check(public.is_web_admin());
create policy "Perfis own personal update" on public."Perfis" for update to authenticated using(prf_id=auth.uid()) with check(prf_id=auth.uid());
create policy "Perfis own citizen insert" on public."Perfis" for insert to authenticated with check(prf_id=auth.uid() and prf_tipo='cidadao' and prf_permissoes='{}'::jsonb);
create or replace function prever_private.protect_profile_role() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('anon','authenticated') and not public.is_web_admin() and
 (new.prf_id is distinct from old.prf_id or new.prf_tipo is distinct from old.prf_tipo or new.prf_permissoes is distinct from old.prf_permissoes) then
 raise exception 'Acesso não autorizado.' using errcode='42501'; end if;
 return new;
end $$;
create trigger protect_profile_role before update on public."Perfis" for each row execute function prever_private.protect_profile_role();

-- Metadados editáveis pelo usuário não concedem acesso institucional/admin.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
declare v_type text;
begin
 if new.email_confirmed_at is not null then
  v_type := case when new.raw_user_meta_data->>'prf_tipo' in ('cidadao','cidadão') then 'cidadao' else 'pendente' end;
  insert into public."Perfis"(prf_id,prf_nome,prf_tipo,prf_email_contato,prf_permissoes)
  values(new.id,coalesce(nullif(new.raw_user_meta_data->>'prf_nome',''),split_part(new.email,'@',1),'Usuário'),v_type,new.email,'{}') on conflict(prf_id) do nothing;
  if not found then return new; end if;
  if v_type='cidadao' then
   insert into public."Cidadao"(cid_id,cid_cpf,cid_rg,cid_data_nascimento)
   values(new.id,new.raw_user_meta_data->>'cpf',new.raw_user_meta_data->>'rg',nullif(new.raw_user_meta_data->>'data_nascimento','')::date) on conflict(cid_id) do nothing;
  end if;
 end if;
 return new;
end $$;

create or replace function public.get_my_web_access() returns jsonb language plpgsql security invoker set search_path='' as $$
declare p jsonb; r text; t text;
begin
 select to_jsonb(x) into p from public."Perfis" x where prf_id=auth.uid();
 t:=lower(trim(coalesce(p->>'prf_tipo','')));
 r:=case when t in ('admin','adm','administrador','administradora') then 'admin'
 when t in ('funcionario','funcionário','funcionaria','funcionária','employee','agente','operador','operadora') then 'employee'
 when t in ('instituicao','instituição','institution','orgao','órgão') then 'institution'
 when t in ('gerente_abrigo','gerente de abrigo','shelter_manager') then 'shelter_manager'
 when t in ('cidadao','cidadão','citizen','mobile') then 'citizen' else 'unknown' end;
 return jsonb_build_object('allowed',r in ('admin','employee','institution','shelter_manager'),'isAdmin',r='admin','role',r,'profile',p,'reason','Seu acesso ao painel ainda não foi autorizado.');
end $$;
revoke all on function public.get_my_web_access() from public,anon;
grant execute on function public.get_my_web_access() to authenticated;
create or replace function public.can_manage_occurrences() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public."Perfis" where prf_id=auth.uid() and lower(prf_tipo) in ('admin','adm','administrador','administradora','funcionario','funcionário','employee','instituicao','instituição','institution'));
$$;

create table public.shelter_managers (
 user_id uuid primary key references public."Perfis"(prf_id) on delete cascade,
 shelter_id uuid not null references public."Abrigo"(abr_id), assigned_at timestamptz not null default now()
);
create index on public.shelter_managers(shelter_id);
alter table public.shelter_managers enable row level security;
create policy "manager own assignment" on public.shelter_managers for select to authenticated using(user_id=auth.uid() or public.is_web_admin());
create policy "admin assignments" on public.shelter_managers for all to authenticated using(public.is_web_admin()) with check(public.is_web_admin());
grant select,insert,update,delete on public.shelter_managers to authenticated;

create or replace function prever_private.manages(s uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_web_admin() or exists(select 1 from public.shelter_managers m join public."Perfis" p on p.prf_id=m.user_id where m.user_id=auth.uid() and m.shelter_id=s and lower(p.prf_tipo) in ('gerente_abrigo','gerente de abrigo','shelter_manager')));
$$;
revoke all on function prever_private.manages(uuid) from public;
grant execute on function prever_private.manages(uuid) to authenticated;
create policy "manager reads shelter" on public."Abrigo" for select to authenticated using(prever_private.manages(abr_id));

create table public.shelter_residents (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public."Abrigo"(abr_id),
 name text not null check(length(trim(name)) between 2 and 160), age integer not null check(age between 0 and 130),
 category text not null check(category in ('Adulto','Criança','Idoso','PCD')), contact text not null default '',
 entered_on date not null default current_date, active boolean not null default true, created_at timestamptz not null default now()
);
create table public.shelter_inventory (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public."Abrigo"(abr_id),
 name text not null check(length(trim(name)) between 2 and 160), category text not null check(category in ('Suprimentos básicos','Higiene e saúde','Estrutura')),
 quantity numeric not null default 0 check(quantity>=0), target numeric not null check(target>0), unit text not null default 'un.', created_at timestamptz not null default now()
);
create table public.shelter_requests (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public."Abrigo"(abr_id),
 inventory_id uuid not null references public.shelter_inventory(id), target numeric not null check(target>0), received numeric not null default 0 check(received>=0 and received<=target),
 priority text not null check(priority in ('Urgente','Moderado','Leve')), created_at timestamptz not null default now()
);
create table public.shelter_donations (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public."Abrigo"(abr_id),
 request_id uuid not null references public.shelter_requests(id), donor text not null check(length(trim(donor)) between 2 and 160), quantity numeric not null check(quantity>0), created_at timestamptz not null default now()
);
create table public.shelter_activity (
 id uuid primary key default gen_random_uuid(), shelter_id uuid not null references public."Abrigo"(abr_id), actor_id uuid references auth.users(id), detail text not null, created_at timestamptz not null default now()
);
do $$ declare t text; begin
 foreach t in array array['shelter_residents','shelter_inventory','shelter_requests','shelter_donations','shelter_activity'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create index on public.%I(shelter_id,created_at)',t);
 execute format('create policy "manager read" on public.%I for select to authenticated using(prever_private.manages(shelter_id))',t);
 execute format('grant select on public.%I to authenticated',t);
 if t<>'shelter_activity' then
 execute format('create policy "manager insert" on public.%I for insert to authenticated with check(prever_private.manages(shelter_id))',t);
 end if;
 if t in ('shelter_residents','shelter_inventory') then
 execute format('create policy "manager update" on public.%I for update to authenticated using(prever_private.manages(shelter_id)) with check(prever_private.manages(shelter_id))',t);
 end if;
 end loop;
end $$;
-- Remove any default table-wide write grants; restore only allowed columns above afterwards.
revoke insert,update,delete on public.shelter_activity from anon,authenticated;
revoke all on public.shelter_managers,public.shelter_residents,public.shelter_inventory,public.shelter_requests,public.shelter_donations,public.shelter_activity from anon;
revoke insert,update,delete on public.shelter_residents,public.shelter_inventory,public.shelter_requests,public.shelter_donations from authenticated;
grant insert(shelter_id,name,age,category,contact,entered_on,active),update(name,age,category,contact,entered_on,active) on public.shelter_residents to authenticated;
grant insert(shelter_id,name,category,quantity,target,unit),update(name,category,quantity,target,unit) on public.shelter_inventory to authenticated;
grant insert(shelter_id,inventory_id,target,priority) on public.shelter_requests to authenticated;
grant insert(shelter_id,request_id,donor,quantity) on public.shelter_donations to authenticated;


create or replace function prever_private.resident_change() returns trigger language plpgsql security definer set search_path='' as $$
declare delta integer; cap integer; occupied integer;
begin
 if auth.uid() is null or not prever_private.manages(new.shelter_id) then raise exception 'Acesso não autorizado.' using errcode='42501'; end if;
 delta:=case when new.active then 1 else 0 end;
 if tg_op='UPDATE' then delta:=delta-case when old.active then 1 else 0 end; end if;
 select abr_capacidade,abr_ocupacao into cap,occupied from public."Abrigo" where abr_id=new.shelter_id for update;
 if occupied+delta>cap or occupied+delta<0 then raise exception 'A capacidade do abrigo não permite esta alteração.'; end if;
 if new.entered_on>current_date then raise exception 'A data de entrada não pode estar no futuro.'; end if;
 update public."Abrigo" set abr_ocupacao=occupied+delta,abr_updated_at=now(),abr_status=case when abr_status='inativo' then 'inativo' when occupied+delta>=cap then 'lotado' when occupied+delta>=cap*0.85 then 'quase_lotado' else 'disponivel' end where abr_id=new.shelter_id;
 return new;
end $$;
create trigger resident_change before insert or update on public.shelter_residents for each row execute function prever_private.resident_change();
create or replace function prever_private.request_check() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.shelter_inventory where id=new.inventory_id and shelter_id=new.shelter_id) then raise exception 'Recurso não encontrado neste abrigo.';end if; return new;
end $$;
create trigger request_check before insert on public.shelter_requests for each row execute function prever_private.request_check();
create or replace function prever_private.receive_donation() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.shelter_requests;
begin
 if auth.uid() is null or not prever_private.manages(new.shelter_id) then raise exception 'Acesso não autorizado.' using errcode='42501';end if;
 select * into r from public.shelter_requests where id=new.request_id and shelter_id=new.shelter_id for update;
 if not found then raise exception 'Pedido não encontrado neste abrigo.';end if;
 if r.received+new.quantity>r.target then raise exception 'A quantidade ultrapassa o que falta para concluir o pedido.';end if;
 update public.shelter_requests set received=received+new.quantity where id=r.id;
 update public.shelter_inventory set quantity=quantity+new.quantity where id=r.inventory_id and shelter_id=new.shelter_id;
 return new;
end $$;
create trigger receive_donation before insert on public.shelter_donations for each row execute function prever_private.receive_donation();
create or replace function prever_private.log_shelter_change() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.shelter_activity(shelter_id,actor_id,detail) values(new.shelter_id,auth.uid(),
 case tg_table_name when 'shelter_residents' then 'Cadastro de ocupante atualizado' when 'shelter_inventory' then 'Estoque atualizado' when 'shelter_requests' then 'Pedido de ajuda criado' else 'Doação recebida' end);
 return new;
end $$;
do $$ declare t text;begin foreach t in array array['shelter_residents','shelter_inventory','shelter_requests','shelter_donations'] loop
 execute format('create trigger log_shelter_change after insert or update on public.%I for each row execute function prever_private.log_shelter_change()',t);
end loop;end $$;

create or replace function prever_private.update_shelter(s uuid,n text,address text,phone text,capacity integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not prever_private.manages(s) then raise exception 'Acesso não autorizado.' using errcode='42501';end if;
 if length(trim(n))<2 or capacity<1 then raise exception 'Informe nome e capacidade válidos.';end if;
 update public."Abrigo" set abr_nome=trim(n),abr_bairro=address,abr_telefone_principal=phone,abr_capacidade=capacity,abr_updated_at=now() where abr_id=s;
 insert into public.shelter_activity(shelter_id,actor_id,detail) values(s,auth.uid(),'Dados do abrigo atualizados');
end $$;
create or replace function public.manager_update_shelter(s uuid,n text,address text,phone text,capacity integer) returns void language sql security invoker set search_path='' as $$select prever_private.update_shelter(s,n,address,phone,capacity);$$;
revoke all on function prever_private.update_shelter(uuid,text,text,text,integer),public.manager_update_shelter(uuid,text,text,text,integer) from public,anon;
grant execute on function prever_private.update_shelter(uuid,text,text,text,integer),public.manager_update_shelter(uuid,text,text,text,integer) to authenticated;

-- Server-only email lookup; no user enumeration from browser clients.
create or replace function public.web_request_auth_user(p_email text) returns uuid language sql security definer set search_path='' as $$ select id from auth.users where lower(email)=lower(trim(p_email)) limit 1; $$;
revoke all on function public.web_request_auth_user(text) from public,anon,authenticated;
grant execute on function public.web_request_auth_user(text) to service_role;

create or replace function prever_private.approve_access(request_id uuid,target_id uuid,profile_type text,shelter_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public."Solicitacao_Acesso_Web"; perms jsonb;
begin
 if auth.uid() is null or not public.is_web_admin() then raise exception 'Acesso não autorizado.' using errcode='42501';end if;
 select * into r from public."Solicitacao_Acesso_Web" where saw_id=request_id for update;
 if not found then raise exception 'Solicitação não encontrada.';end if;
 if r.saw_status='aprovado' then return jsonb_build_object('ok',true,'alreadyApproved',true);end if;
 if r.saw_status<>'pendente' then raise exception 'Esta solicitação já foi analisada.';end if;
 if profile_type not in ('funcionario','instituicao','gerente_abrigo') then raise exception 'Selecione um perfil válido.';end if;
 if not exists(select 1 from auth.users where id=target_id and lower(email)=lower(r.saw_email)) then raise exception 'A conta não corresponde à solicitação.';end if;
 if exists(select 1 from public."Perfis" where prf_id=target_id and lower(prf_tipo) in ('admin','adm','administrador','administradora')) then raise exception 'Esta conta já possui acesso administrativo.';end if;
 if profile_type='gerente_abrigo' and not exists(select 1 from public."Abrigo" where abr_id=shelter_id) then raise exception 'Selecione o abrigo responsável.';end if;
 perms:=case when profile_type='gerente_abrigo' then '{"dashboard":true,"ocupantes":true,"estoque":true,"pedidos":true,"relatorios":true,"reportar":false,"ocorrencias":false,"auditoria":false,"admin":false}'::jsonb else '{"dashboard":true,"reportar":true,"ocorrencias":true,"relatorios":true,"auditoria":false,"admin":false}'::jsonb end;
 insert into public."Perfis"(prf_id,prf_nome,prf_tipo,prf_email_contato,prf_permissoes) values(target_id,r.saw_nome,profile_type,r.saw_email,perms)
 on conflict(prf_id) do update set prf_tipo=excluded.prf_tipo,prf_permissoes=excluded.prf_permissoes;
 if profile_type='gerente_abrigo' then insert into public.shelter_managers(user_id,shelter_id) values(target_id,shelter_id) on conflict(user_id) do update set shelter_id=excluded.shelter_id;
 else delete from public.shelter_managers where user_id=target_id;end if;
 update public."Solicitacao_Acesso_Web" set saw_status='aprovado',saw_reviewed_by=auth.uid(),saw_reviewed_at=now(),saw_observacao='Acesso autorizado pelo administrador.' where saw_id=request_id;
 insert into public."Audit_Log"(actor_user_id,action,entity_type,entity_id,detail) values(auth.uid(),'access_request_approved','Solicitacao_Acesso_Web',request_id,'Solicitação aprovada como '||profile_type);
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.approve_web_access(request_id uuid,target_id uuid,profile_type text,shelter_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$select prever_private.approve_access(request_id,target_id,profile_type,shelter_id);$$;
revoke all on function prever_private.approve_access(uuid,uuid,text,uuid),public.approve_web_access(uuid,uuid,text,uuid) from public,anon;
grant execute on function prever_private.approve_access(uuid,uuid,text,uuid),public.approve_web_access(uuid,uuid,text,uuid) to authenticated;

-- Public requests must start pending, with no forged review data.
drop policy "Solicitacao_Acesso_Web insert public" on public."Solicitacao_Acesso_Web";
create policy "Solicitacao_Acesso_Web insert public" on public."Solicitacao_Acesso_Web" for insert to anon,authenticated with check(saw_status='pendente' and saw_reviewed_by is null and saw_reviewed_at is null and saw_observacao is null and length(trim(saw_nome)) between 2 and 160 and saw_email ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$');
