-- =============================================================================
-- 15 — TRANSFORMAR: clima do sinistro (depois da conversão UTC -> local do INMET)
-- Precipitação da hora do sinistro: estação Pampulha (A521); Cercadinho (F501)
-- quando a Pampulha não tiver leitura. Boletim sem hora informada não recebe
-- precipitação. Clima final:
--   cod_tempo 1–4 -> DECLARADO NO BOLETIM;
--   cod_tempo 0 com leitura do INMET -> IMPUTADO PELO INMET (chuva se > 0 mm);
--   caso contrário -> NÃO INFORMADO.
-- =============================================================================
UPDATE stg.trf_boletim
SET precipitacao_mm = NULL, estacao_inmet = NULL,
    condicao_climatica = NULL, origem_clima = NULL, grupo_chuva = NULL;

WITH leitura AS (
    SELECT b.numero_boletim_dw, b.ano,
           pa.precipitacao_mm AS precip_pampulha,
           ce.precipitacao_mm AS precip_cercadinho
    FROM stg.trf_boletim b
    LEFT JOIN stg.trf_clima_hora pa
           ON pa.estacao_codigo = 'A521' AND pa.dt_hora_inicio_local = date_trunc('hour', b.data_hora)
    LEFT JOIN stg.trf_clima_hora ce
           ON ce.estacao_codigo = 'F501' AND ce.dt_hora_inicio_local = date_trunc('hour', b.data_hora)
    WHERE b.fl_hora_informada
)
UPDATE stg.trf_boletim b
SET precipitacao_mm = coalesce(l.precip_pampulha, l.precip_cercadinho),
    estacao_inmet   = CASE WHEN l.precip_pampulha   IS NOT NULL THEN 'A521'
                           WHEN l.precip_cercadinho IS NOT NULL THEN 'F501' END
FROM leitura l
WHERE l.numero_boletim_dw = b.numero_boletim_dw AND l.ano = b.ano;

UPDATE stg.trf_boletim b
SET condicao_climatica = CASE
        WHEN b.cod_tempo BETWEEN 1 AND 4 THEN m.descricao
        WHEN b.precipitacao_mm IS NOT NULL THEN
             CASE WHEN b.precipitacao_mm > 0 THEN 'CHUVA (INMET)' ELSE 'SEM CHUVA (INMET)' END
        ELSE 'NÃO INFORMADO' END,
    origem_clima = CASE
        WHEN b.cod_tempo BETWEEN 1 AND 4 THEN 'DECLARADO NO BOLETIM'
        WHEN b.precipitacao_mm IS NOT NULL THEN 'IMPUTADO PELO INMET'
        ELSE 'NÃO INFORMADO' END,
    grupo_chuva = CASE
        WHEN b.cod_tempo BETWEEN 1 AND 4 THEN m.grupo
        WHEN b.precipitacao_mm IS NOT NULL THEN
             CASE WHEN b.precipitacao_mm > 0 THEN 'COM CHUVA' ELSE 'SEM CHUVA' END
        ELSE 'NÃO INFORMADO' END
FROM stg.map_dominio m
WHERE m.dominio = 'tempo' AND m.codigo = b.cod_tempo::text;

ANALYZE stg.trf_boletim;
