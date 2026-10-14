-- =============================================================================
-- 24 — CARREGAR: dim_condicao_via (junk): combinações que ocorrem nos boletins
-- =============================================================================
INSERT INTO dw.dim_condicao_via (sk_condicao_via, cod_tempo, condicao_climatica, origem_clima, grupo_chuva,
                                 cod_pavimento, pavimento, local_sinalizado, arquivo_origem)
OVERRIDING SYSTEM VALUE
VALUES (-1, NULL, 'NÃO INFORMADO', 'NÃO INFORMADO', 'NÃO INFORMADO', NULL, 'NÃO INFORMADO', 'NÃO INFORMADO', 'sql/carga/24_dim_condicao_via.sql'),
       (-2, NULL, 'NÃO SE APLICA', 'NÃO SE APLICA', 'NÃO SE APLICA', NULL, 'NÃO SE APLICA', 'NÃO SE APLICA', 'sql/carga/24_dim_condicao_via.sql');

INSERT INTO dw.dim_condicao_via (cod_tempo, condicao_climatica, origem_clima, grupo_chuva,
                                 cod_pavimento, pavimento, local_sinalizado, arquivo_origem)
SELECT DISTINCT b.cod_tempo, b.condicao_climatica, b.origem_clima, b.grupo_chuva,
       b.cod_pavimento, coalesce(mp.descricao, 'NÃO INFORMADO'), b.local_sinalizado,
       'stg.trf_boletim (si-bol + INMET)'
FROM stg.trf_boletim b
LEFT JOIN stg.map_dominio mp ON mp.dominio = 'pavimento' AND mp.codigo = b.cod_pavimento::text
ORDER BY 1, 2, 5, 7;
