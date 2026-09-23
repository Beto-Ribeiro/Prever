-- SMDN - Sincroniza e-mail real do Auth pelo painel admin

create or replace function public.admin_update_auth_email(
  p_user_id uuid,
  p_new_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(trim(coalesce(p_new_email, '')));
  v_old_email text;
begin
  if not public.is_web_admin() then
    raise exception 'Usuário sem permissão para alterar e-mail de login.';
  end if;

  if p_user_id is null then
    raise exception 'Usuário alvo não informado.';
  end if;

  if v_email = '' or v_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then
    raise exception 'E-mail inválido: %', p_new_email;
  end if;

  select email
  into v_old_email
  from auth.users
  where id = p_user_id
  limit 1;

  if v_old_email is null then
    raise exception 'Usuário Auth não encontrado: %', p_user_id;
  end if;

  if exists (
    select 1
    from auth.users
    where lower(email) = v_email
      and id <> p_user_id
  ) then
    raise exception 'Já existe outro usuário Auth com este e-mail: %', v_email;
  end if;

  update auth.users
  set
    email = v_email,
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    confirmation_sent_at = null,
    email_change = '',
    email_change_token_new = '',
    email_change_token_current = '',
    email_change_confirm_status = 0,
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('email', v_email),
    updated_at = now()
  where id = p_user_id;

  return jsonb_build_object(
    'ok', true,
    'userId', p_user_id,
    'oldEmail', v_old_email,
    'newEmail', v_email
  );
end;
$$;

revoke all on function public.admin_update_auth_email(uuid, text) from public;
grant execute on function public.admin_update_auth_email(uuid, text) to authenticated;

notify pgrst, 'reload schema';
