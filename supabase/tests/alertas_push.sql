-- Executar depois da migração em um banco de desenvolvimento.
-- Não emite nem insere alertas; todas as verificações são somente leitura.
begin;
do $$
declare v_limite double precision := degrees(20000.0 / 6371008.8);
begin
  assert alertas_privado.distancia_metros(0, 0, 0, 0) = 0, 'Distância na origem';
  assert abs(alertas_privado.distancia_metros(0, 0, v_limite, 0) - 20000) < 1e-6, 'Fronteira 20 km';
  assert alertas_privado.distancia_metros(0, 0, v_limite, 0) <= 20000 + 1e-6, 'Borda inclusiva';
  assert alertas_privado.distancia_metros(0, 0, degrees(19999.0 / 6371008.8), 0) <= 20000, 'Dentro do raio';
  assert alertas_privado.distancia_metros(0, 0, degrees(20001.0 / 6371008.8), 0) > 20000 + 1e-6, 'Fora do raio';
  assert alertas_privado.distancia_metros(0, 179.99, 0, -179.99) < 3000, 'Linha de mudança de data';
  assert abs(alertas_privado.distancia_metros(0, 0, 0, 180) - pi() * 6371008.8) < 1e-6, 'Antípodas sem NaN';
  assert not has_schema_privilege('anon', 'alertas_privado', 'USAGE'), 'Schema privado para anon';
  assert not has_schema_privilege('authenticated', 'alertas_privado', 'USAGE'), 'Schema privado para clientes';
  assert not has_function_privilege('anon', 'public.registrar_dispositivo_alerta(text,double precision,double precision,text)', 'EXECUTE'), 'Registro exige login';
  assert has_function_privilege('authenticated', 'public.registrar_dispositivo_alerta(text,double precision,double precision,text)', 'EXECUTE'), 'Usuário registra próprio aparelho';
  assert not has_function_privilege('authenticated', 'public.reservar_entregas_alerta(integer)', 'EXECUTE'), 'Clientes não podem enviar push';
  assert has_function_privilege('service_role', 'public.reservar_entregas_alerta(integer)', 'EXECUTE'), 'Worker pode reservar';
end;
$$;
rollback;
