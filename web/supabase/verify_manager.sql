-- Executar em transação: fixtures não persistem nem enviam e-mails.
begin;
do $$
declare a uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); s2 uuid:=gen_random_uuid(); inv uuid; req uuid; request_access uuid:=gen_random_uuid(); resident uuid; uid uuid; c integer;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(a,a||'@example.invalid','{}'),(m,m||'@example.invalid','{}'),(other_user,other_user||'@example.invalid','{}');
 insert into public."Perfis"(prf_id,prf_nome,prf_tipo,prf_permissoes) values(a,'Teste administrador','administrador','{}'),(m,'Teste gerente','pendente','{}'),(other_user,'Outro gerente','gerente_abrigo','{}');
 insert into public."Abrigo"(abr_id,abr_nome,abr_tipo,abr_capacidade) values(s,'Teste A','Teste',2),(s2,'Teste B','Teste',2);
 insert into public."Solicitacao_Acesso_Web"(saw_id,saw_nome,saw_email,saw_status) values(request_access,'Teste gerente',m||'@example.invalid','pendente');
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 perform public.approve_web_access(request_access,m,'gerente_abrigo',s);
 perform public.approve_web_access(request_access,m,'gerente_abrigo',s);
 if not exists(select 1 from public."Solicitacao_Acesso_Web" where saw_id=request_access and saw_status='aprovado') then raise exception 'Approval failed';end if;
 execute 'reset role';
 insert into public.shelter_managers(user_id,shelter_id) values(other_user,s2);
 perform set_config('request.jwt.claim.sub',m::text,true);
 execute 'set local role authenticated';
 if (public.get_my_web_access()->>'role')<>'shelter_manager' then raise exception 'Manager role failed';end if;
 if public.can_manage_occurrences() then raise exception 'Manager has global privileges';end if;
 begin
  perform public.get_dashboard_data();
  raise exception 'Manager accessed global dashboard';
 exception when insufficient_privilege then null;end;
 begin
  perform public.get_ocorrencias_data();
  raise exception 'Manager accessed global occurrences';
 exception when insufficient_privilege then null;end;
 begin
  perform public.get_relatorios_data('30d');
  raise exception 'Manager accessed global reports';
 exception when insufficient_privilege then null;end;
 if exists(select 1 from public."Abrigo" where abr_id=s2) then raise exception 'Other shelter exposed';end if;
 begin
  update public."Perfis" set prf_tipo='administrador' where prf_id=m;
  raise exception 'Self promotion accepted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.approve_web_access(request_access,m,'gerente_abrigo',s);
  raise exception 'Manager approved access';
 exception when insufficient_privilege then null; end;
 insert into public.shelter_residents(shelter_id,name,age,category) values(s,'Ocupante de teste',34,'Adulto') returning id into resident;
 if (select abr_ocupacao from public."Abrigo" where abr_id=s)<>1 then raise exception 'Occupancy failed';end if;
 update public.shelter_residents set active=false where id=resident;
 if (select abr_ocupacao from public."Abrigo" where abr_id=s)<>0 then raise exception 'Departure failed';end if;
 insert into public.shelter_inventory(shelter_id,name,category,quantity,target,unit) values(s,'Água','Suprimentos básicos',0,10,'L') returning id into inv;
 insert into public.shelter_requests(shelter_id,inventory_id,target,priority) values(s,inv,10,'Urgente') returning id into req;
 insert into public.shelter_donations(shelter_id,request_id,donor,quantity) values(s,req,'Doador de teste',4);
 if (select quantity from public.shelter_inventory where id=inv)<>4 or (select received from public.shelter_requests where id=req)<>4 then raise exception 'Donation totals failed';end if;
 begin
  insert into public.shelter_donations(shelter_id,request_id,donor,quantity) values(s,req,'Teste excesso',7);
  raise exception 'Excess donation accepted';
 exception when raise_exception then if sqlerrm<>'A quantidade ultrapassa o que falta para concluir o pedido.' then raise;end if;end;
 begin
  update public.shelter_requests set received=10 where id=req;
  raise exception 'Forged totals accepted';
 exception when insufficient_privilege then null;end;
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',other_user::text,true);
 execute 'set local role authenticated';
 if exists(select 1 from public.shelter_residents where shelter_id=s) then raise exception 'Resident data exposed';end if;
 begin
  insert into public.shelter_inventory(shelter_id,name,category,target) values(s,'Intruso','Estrutura',5);
  raise exception 'Cross shelter insert accepted';
 exception when insufficient_privilege then null;end;
 execute 'reset role';
end $$;
rollback;
select 'passed: approval + idempotency + manager login + RLS isolation + role protection + occupancy + donation transaction + overdelivery + forged totals' as verification;
