-- =============================================================================
-- 27 — CARREGAR: dim_local (SCD Tipo 2)
-- Uma linha por versão do local (stg.trf_local_versao). Todas as versões
-- guardam também os nomes atuais. O ponto representativo é o sinistro
-- geolocalizado mais próximo do centroide dos sinistros do local.
-- =============================================================================
INSERT INTO dw.dim_local (sk_local, chave_natural, versao, nome_logradouro_principal, nome_logradouro_principal_atual,
                          nome_bairro, fl_cruzamento, descricao_local, descricao_local_atual,
                          dt_inicio_vigencia, dt_fim_vigencia, fl_versao_atual, motivo_versao, arquivo_origem)
OVERRIDING SYSTEM VALUE
VALUES (-1, '(n/i)', 1, 'NÃO INFORMADO', 'NÃO INFORMADO', 'NÃO INFORMADO', false, 'Local não informado',
        'Local não informado', DATE '1900-01-01', DATE '9999-12-31', true, 'Membro especial', 'sql/carga/27_dim_local.sql'),
       (-2, '(n/a)', 1, 'NÃO SE APLICA', 'NÃO SE APLICA', 'NÃO SE APLICA', false, 'Não se aplica',
        'Não se aplica', DATE '1900-01-01', DATE '9999-12-31', true, 'Membro especial', 'sql/carga/27_dim_local.sql');

WITH pontos AS (
    SELECT bl.chave_local, c.geom
    FROM stg.trf_boletim_local bl
    JOIN stg.trf_coordenada c ON c.numero_boletim_dw = bl.numero_boletim_dw AND c.ano = bl.ano
    WHERE c.fl_geolocalizado
),
representativo AS (
    SELECT chave_local, count(*) AS qtd,
           ST_ClosestPoint(ST_Collect(geom), ST_Centroid(ST_Collect(geom))) AS geom
    FROM pontos
    GROUP BY chave_local
),
atual AS (
    SELECT chave_local, nome_logradouro_principal AS principal_atual, nome_logradouro_cruzamento AS cruzamento_atual
    FROM stg.trf_local_versao
    WHERE fl_versao_atual
)
INSERT INTO dw.dim_local (chave_natural, versao, cod_logradouro_principal, tipo_logradouro_principal,
                          nome_logradouro_principal, nome_anterior_principal, nome_logradouro_principal_atual,
                          cod_logradouro_cruzamento, tipo_logradouro_cruzamento, nome_logradouro_cruzamento,
                          nome_anterior_cruzamento, nome_logradouro_cruzamento_atual, cod_bairro, nome_bairro,
                          fl_cruzamento, descricao_local, descricao_local_atual, latitude, longitude, geom,
                          qtd_pontos_geom, dt_inicio_vigencia, dt_fim_vigencia, fl_versao_atual, motivo_versao,
                          arquivo_origem)
SELECT v.chave_local, v.versao, v.cod_logradouro_principal,
       coalesce(tp.descricao, v.tipo_logradouro_principal),
       v.nome_logradouro_principal, v.nome_anterior_principal, a.principal_atual,
       nullif(v.cod_logradouro_cruzamento, 0),
       coalesce(tc.descricao, v.tipo_logradouro_cruzamento),
       v.nome_logradouro_cruzamento, v.nome_anterior_cruzamento, a.cruzamento_atual,
       v.cod_bairro, v.nome_bairro, v.fl_cruzamento, v.descricao_local, v.descricao_local_atual,
       ST_Y(r.geom), ST_X(r.geom), r.geom, coalesce(r.qtd, 0),
       v.dt_inicio, v.dt_fim, v.fl_versao_atual, v.motivo_versao,
       'si-log (stg.trf_local_versao)'
FROM stg.trf_local_versao v
JOIN atual a ON a.chave_local = v.chave_local
LEFT JOIN representativo r ON r.chave_local = v.chave_local
LEFT JOIN stg.map_dominio tp ON tp.dominio = 'tipo_logradouro' AND tp.codigo = v.tipo_logradouro_principal
LEFT JOIN stg.map_dominio tc ON tc.dominio = 'tipo_logradouro' AND tc.codigo = v.tipo_logradouro_cruzamento
ORDER BY v.chave_local, v.versao;
