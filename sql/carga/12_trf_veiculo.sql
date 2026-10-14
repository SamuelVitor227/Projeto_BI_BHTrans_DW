-- =============================================================================
-- 12 — TRANSFORMAR: veículos (stg.si_veic -> stg.trf_veiculo)
-- Categoria e situação padronizadas pelo código (a descrição do código 3 de
-- situação vem vazia até 2019); espécie pela descrição (o código 9 é usado
-- para BONDE e TREM). Grupo de espécie pelo de-para etl/mapeamentos/dominios.csv.
-- =============================================================================
TRUNCATE stg.trf_veiculo;

WITH vei AS (
    SELECT v.*,
           btrim(v.numero_boletim) AS nb,
           CASE WHEN btrim(v.data_hora_boletim) ~ '^\d{2}/\d{2}/\d{4} \d{2}:\d{2}'
                THEN to_date(substr(btrim(v.data_hora_boletim), 1, 10), 'DD/MM/YYYY')
                     + substr(btrim(v.data_hora_boletim), 12, 5)::time
           END AS data_hora_vei,
           CASE WHEN btrim(v.codigo_categoria) ~ '^\d+$' THEN btrim(v.codigo_categoria)::smallint ELSE 0 END AS cod_categoria,
           CASE WHEN btrim(v.codigo_especie)   ~ '^\d+$' THEN btrim(v.codigo_especie)::smallint   ELSE 0 END AS cod_especie,
           CASE WHEN btrim(v.codigo_situacao)  ~ '^\d+$' THEN btrim(v.codigo_situacao)::smallint  ELSE 0 END AS cod_situacao,
           coalesce(nullif(upper(btrim(v.descricao_especie)), ''), 'NAO INFORMADO') AS especie_origem
    FROM stg.si_veic v
),
ligado AS (
    SELECT vei.*, b.numero_boletim_dw, b.ano,
           row_number() OVER (PARTITION BY b.numero_boletim_dw, b.ano, btrim(vei.sequencial_veiculo)
                              ORDER BY vei.linha_arquivo DESC) AS rn
    FROM vei
    JOIN stg.trf_boletim b
      ON b.numero_boletim_origem = vei.nb
     AND b.ano = vei.ano_arquivo
     AND (b.qtd_eventos_numero = 1 OR b.data_hora = vei.data_hora_vei)
    WHERE btrim(vei.sequencial_veiculo) ~ '^\d+$'
)
INSERT INTO stg.trf_veiculo (
    numero_boletim_dw, ano, sequencial_veiculo, cod_categoria, categoria, cod_especie, especie,
    grupo_especie, cod_situacao, situacao, arquivo_origem, linha_arquivo)
SELECT l.numero_boletim_dw,
       l.ano,
       btrim(l.sequencial_veiculo)::smallint,
       l.cod_categoria,
       coalesce(mc.descricao, 'NÃO INFORMADA'),
       l.cod_especie,
       coalesce(me.descricao, l.especie_origem),
       coalesce(me.grupo, 'Outros'),
       l.cod_situacao,
       coalesce(ms.descricao, 'NÃO INFORMADA'),
       l.arquivo_origem,
       l.linha_arquivo
FROM ligado l
LEFT JOIN stg.map_dominio mc ON mc.dominio = 'categoria_veiculo' AND mc.codigo = l.cod_categoria::text
LEFT JOIN stg.map_dominio me ON me.dominio = 'especie_veiculo'   AND me.codigo = l.especie_origem
LEFT JOIN stg.map_dominio ms ON ms.dominio = 'situacao_veiculo'  AND ms.codigo = l.cod_situacao::text
WHERE l.rn = 1;

ANALYZE stg.trf_veiculo;
