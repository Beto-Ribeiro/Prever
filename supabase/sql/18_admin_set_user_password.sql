-- SMDN - Admin pode definir senha temporária pelo painel
-- Rode no Supabase SQL Editor antes de usar o botão "Aprovar e trocar senha".
-- A senha NÃO fica salva em texto puro: ela é convertida em hash antes de gravar.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.admin_set_user_password(
  p_user_id uuid,
  p_new_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  if not public.is_web_admin() then
    raise exception 'Acesso não autorizado.';
  end if;

  if p_user_id is null then
    raise exception 'Usuário não informado.';
  end if;

  if length(coalesce(p_new_password, '')) < 6 then
    raise exception 'A senha precisa ter pelo menos 6 caracteres.';
  end if;

  update auth.users
  set
    encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
    updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'Usuário não encontrado.';
  end if;

  return jsonb_build_object('ok', true, 'userId', p_user_id);
end;
$$;

revoke all on function public.admin_set_user_password(uuid, text) from public;
grant execute on function public.admin_set_user_password(uuid, text) to authenticated;

notify pgrst, 'reload schema';
