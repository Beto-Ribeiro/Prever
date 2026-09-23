-- SMDN - Template para transformar um usuário Auth em primeiro administrador web
-- 1. Crie o usuário em Authentication > Users > Add user, com Auto Confirm marcado.
-- 2. Copie o UUID do usuário criado.
-- 3. Substitua UUID_DO_AUTH_USER, NOME_DO_ADMIN e APELIDO_DO_ADMIN abaixo.
-- 4. Rode este SQL.

begin;

insert into public."Perfis" (
  prf_id,
  prf_nome,
  prf_tipo
)
values (
  'UUID_DO_AUTH_USER',
  'NOME_DO_ADMIN',
  'administrador'
)
on conflict (prf_id) do update
set
  prf_nome = excluded.prf_nome,
  prf_tipo = excluded.prf_tipo;

insert into public."Administrador" (
  adm_id,
  adm_apelido
)
values (
  'UUID_DO_AUTH_USER',
  'APELIDO_DO_ADMIN'
)
on conflict (adm_id) do update
set
  adm_apelido = excluded.adm_apelido;

commit;

-- Conferência:
select
  p.prf_id,
  p.prf_nome,
  p.prf_tipo,
  a.adm_apelido
from public."Perfis" p
left join public."Administrador" a
  on a.adm_id = p.prf_id
where p.prf_id = 'UUID_DO_AUTH_USER';
