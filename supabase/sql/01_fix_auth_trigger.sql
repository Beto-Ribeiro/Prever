-- SMDN - Correção da trigger de criação de usuário Auth
-- Objetivo: permitir criação de usuários pelo Supabase Dashboard sem quebrar o mobile.
-- A função continua usando os metadados enviados pelo mobile quando eles existem.
-- Quando os metadados não existem, cria Perfil como pendente com nome derivado do email.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_tipo text;
  v_nome text;
begin
  v_tipo := coalesce(
    nullif(new.raw_user_meta_data->>'prf_tipo', ''),
    'pendente'
  );

  v_nome := coalesce(
    nullif(new.raw_user_meta_data->>'prf_nome', ''),
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1),
    'Usuário SMDN'
  );

  if new.email_confirmed_at is not null then

    if not exists (
      select 1
      from public."Perfis"
      where prf_id = new.id
    ) then

      insert into public."Perfis" (
        prf_id,
        prf_nome,
        prf_tipo
      )
      values (
        new.id,
        v_nome,
        v_tipo
      );

      if v_tipo = 'cidadao' then

        insert into public."Cidadao" (
          cid_id,
          cid_cpf,
          cid_rg,
          cid_data_nascimento
        )
        values (
          new.id,
          new.raw_user_meta_data->>'cpf',
          new.raw_user_meta_data->>'rg',
          nullif(new.raw_user_meta_data->>'data_nascimento', '')::date
        );

      elsif v_tipo = 'funcionario' then

        insert into public."Funcionario" (
          fun_id,
          fun_cpf,
          fun_cargo,
          fun_ins_id
        )
        values (
          new.id,
          new.raw_user_meta_data->>'cpf',
          new.raw_user_meta_data->>'cargo',
          nullif(new.raw_user_meta_data->>'id_instituicao', '')::uuid
        );

      elsif v_tipo = 'instituicao' then

        insert into public."Instituicao" (
          ins_id,
          ins_numero,
          ins_localizacao
        )
        values (
          new.id,
          new.raw_user_meta_data->>'numero',
          case
            when new.raw_user_meta_data->>'lat' is not null
             and new.raw_user_meta_data->>'lng' is not null
            then
              ST_SetSRID(
                ST_MakePoint(
                  (new.raw_user_meta_data->>'lng')::float,
                  (new.raw_user_meta_data->>'lat')::float
                ),
                4326
              )::geography
            else null
          end
        );

      end if;

    end if;
  end if;

  return new;
end;
$$;

-- Havia duas triggers chamando a mesma função.
-- Mantemos a on_auth_user_created, que já cobre INSERT OR UPDATE.
drop trigger if exists add_users_specific_tables on auth.users;
