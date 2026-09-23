-- As consultas globais permanecem disponíveis aos agentes/instituições/admins.
alter function public.get_dashboard_data() set schema prever_private;
alter function public.get_ocorrencias_data() set schema prever_private;
alter function public.get_relatorios_data(text) set schema prever_private;
create function public.get_dashboard_data() returns jsonb language plpgsql security invoker set search_path='' as $$begin if auth.uid() is null or not public.can_manage_occurrences() then raise exception 'Acesso não autorizado.' using errcode='42501';end if;return prever_private.get_dashboard_data();end$$;
create function public.get_ocorrencias_data() returns jsonb language plpgsql security invoker set search_path='' as $$begin if auth.uid() is null or not public.can_manage_occurrences() then raise exception 'Acesso não autorizado.' using errcode='42501';end if;return prever_private.get_ocorrencias_data();end$$;
create function public.get_relatorios_data(p_period text default '30d') returns jsonb language plpgsql security invoker set search_path='' as $$begin if auth.uid() is null or not public.can_manage_occurrences() then raise exception 'Acesso não autorizado.' using errcode='42501';end if;return prever_private.get_relatorios_data(p_period);end$$;
revoke all on function public.get_dashboard_data(),public.get_ocorrencias_data(),public.get_relatorios_data(text),prever_private.get_dashboard_data(),prever_private.get_ocorrencias_data(),prever_private.get_relatorios_data(text) from public,anon;
grant execute on function public.get_dashboard_data(),public.get_ocorrencias_data(),public.get_relatorios_data(text),prever_private.get_dashboard_data(),prever_private.get_ocorrencias_data(),prever_private.get_relatorios_data(text) to authenticated;
