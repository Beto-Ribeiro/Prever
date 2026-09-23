-- OPCIONAL - sementes para testar a tela de Relatórios com mais volume.
-- Não rode em produção. Serve apenas para demonstração/ensaios.
-- Usa um cidadão existente da base para vincular os relatos.

insert into public."Relato" (
  rel_tipo_desastre,
  rel_descricao,
  rel_data_hora,
  rel_cid_id,
  rel_localizacao
)
select
  tipos.tipo,
  severidades.severidade,
  now() - ((g % 180) || ' days')::interval,
  cid.cid_id,
  extensions.st_geogfromtext(
    'SRID=4326;POINT(' || cidades.lng || ' ' || cidades.lat || ')'
  )
from generate_series(1, 36) as g
cross join lateral (
  select cid_id from public."Cidadao" order by cid_id limit 1
) cid
cross join lateral (
  select * from (values
    ('Enchente'), ('Temporal'), ('Deslizamento'), ('Chuva Forte'), ('Desabamento')
  ) v(tipo)
  offset (g % 5)
  limit 1
) tipos
cross join lateral (
  select * from (values
    ('Crítico'), ('Grave'), ('Moderado'), ('Normal')
  ) v(severidade)
  offset (g % 4)
  limit 1
) severidades
cross join lateral (
  select * from (values
    ('São José dos Campos', -23.2237, -45.9009),
    ('Taubaté', -23.0264, -45.5553),
    ('Pindamonhangaba', -22.9239, -45.4617),
    ('Roseira', -22.8988, -45.3070),
    ('Guaratinguetá', -22.8164, -45.1927)
  ) v(cidade, lat, lng)
  offset (g % 5)
  limit 1
) cidades;
