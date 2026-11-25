-- =============================================================================
-- 25 — CARREGAR: dim_veiculo (perfil espécie x categoria x situação)
-- Para cada espécie também existe o perfil com categoria/situação
-- "NÃO IDENTIFICADA", usado quando a pessoa está numa espécie da qual o
-- boletim tem 0 ou mais de 1 veículo (o si_env não traz o sequencial do veículo).
-- =============================================================================
INSERT INTO dw.dim_veiculo (sk_veiculo, especie, grupo_especie, categoria, situacao, fl_identificado, arquivo_origem)
OVERRIDING SYSTEM VALUE
VALUES (-1, 'NÃO IDENTIFICADO', 'Não identificado', 'NÃO IDENTIFICADA', 'NÃO IDENTIFICADA', false, 'sql/carga/25_dim_veiculo.sql'),
       (-2, 'NÃO SE APLICA (PEDESTRE)', 'Não se aplica', 'NÃO SE APLICA', 'NÃO SE APLICA', false, 'sql/carga/25_dim_veiculo.sql');

INSERT INTO dw.dim_veiculo (especie, grupo_especie, categoria, situacao, fl_identificado, arquivo_origem)
SELECT especie, grupo_especie, categoria, situacao, fl_identificado, arquivo_origem
FROM (
    SELECT DISTINCT especie, grupo_especie, categoria, situacao, true AS fl_identificado,
           'stg.trf_veiculo (si-veic)' AS arquivo_origem
    FROM stg.trf_veiculo
    UNION
    SELECT DISTINCT especie, grupo_especie, 'NÃO IDENTIFICADA', 'NÃO IDENTIFICADA', false,
           'stg.trf_veiculo / stg.trf_envolvido'
    FROM (SELECT especie, grupo_especie FROM stg.trf_veiculo
          UNION
          SELECT especie_veiculo, grupo_especie FROM stg.trf_envolvido WHERE especie_veiculo IS NOT NULL) e
) x
ORDER BY grupo_especie, especie, fl_identificado DESC, categoria, situacao;
