-- =============================================================================
-- 30 — CARREGAR: fato_sinistro (1 linha por boletim)
-- * sk_tempo: AAAAMMDDHH, ou AAAAMMDD99 quando a hora não foi informada;
-- * sk_local: versão da dim_local vigente na data do sinistro;
-- * sk_regional: código do boletim (27 Hipercentro -> Centro-Sul); se 0/nulo,
--   ST_Within do ponto do boletim contra a dim_regional (ou a regional mais
--   próxima, para pontos a até 100 m do limite); se o boletim não tem ponto,
--   ST_Within do ponto representativo do local (dim_local.geom); senão -1;
-- * valor_ups: a da fonte quando 1/5/13; senão derivada (13 se houve morte, 5 se não).
-- =============================================================================
WITH env AS (
    SELECT numero_boletim_dw, ano,
           count(*)                                 AS qtd_envolvidos,
           count(*) FILTER (WHERE fl_vitima)        AS qtd_vitimas,
           count(*) FILTER (WHERE fl_vitima_fatal)  AS qtd_vitimas_fatais,
           bool_or(fl_pedestre)                     AS tem_pedestre,
           bool_or(fl_motociclista)                 AS tem_motociclista
    FROM stg.trf_envolvido
    GROUP BY numero_boletim_dw, ano
),
vei AS (
    SELECT numero_boletim_dw, ano,
           count(*)                                                    AS qtd_veiculos,
           count(*) FILTER (WHERE grupo_especie = 'Motocicleta')          AS qtd_motocicletas,
           count(*) FILTER (WHERE grupo_especie = 'Automóvel/utilitário') AS qtd_automoveis,
           count(*) FILTER (WHERE grupo_especie = 'Ônibus')               AS qtd_onibus,
           count(*) FILTER (WHERE grupo_especie = 'Caminhão')             AS qtd_caminhoes,
           count(*) FILTER (WHERE grupo_especie = 'Bicicleta')            AS qtd_bicicletas,
           count(*) FILTER (WHERE grupo_especie = 'Outros')               AS qtd_outros
    FROM stg.trf_veiculo
    GROUP BY numero_boletim_dw, ano
),
regional_boletim AS (
    SELECT m.cod_regional_boletim, r.sk_regional
    FROM stg.map_regional m
    JOIN dw.dim_regional r ON r.cod_regional = m.cod_reg_limite
)
INSERT INTO dw.fato_sinistro (
    numero_boletim, ano, sk_tempo, sk_local, sk_tipo_sinistro, sk_condicao_via, sk_regional,
    qtd_envolvidos, qtd_vitimas, qtd_vitimas_fatais, qtd_veiculos, qtd_motocicletas, qtd_automoveis,
    qtd_onibus, qtd_caminhoes, qtd_bicicletas, qtd_outros_veiculos, valor_ups, fl_ups_imputada,
    velocidade_permitida, precipitacao_mm, estacao_inmet, fl_fatal, fl_envolve_pedestre,
    fl_envolve_motociclista, fl_geolocalizado, latitude, longitude, geom, origem_regional, arquivo_origem)
SELECT b.numero_boletim_dw,
       b.ano,
       to_char(b.data, 'YYYYMMDD')::int * 100 + coalesce(b.hora, 99),
       coalesce(dl.sk_local, -1),
       coalesce(dts.sk_tipo_sinistro, -1),
       coalesce(dcv.sk_condicao_via, -1),
       coalesce(rb.sk_regional, dentro.sk_regional, proxima.sk_regional, pelo_local.sk_regional, -1),
       coalesce(env.qtd_envolvidos, 0),
       coalesce(env.qtd_vitimas, 0),
       coalesce(env.qtd_vitimas_fatais, 0),
       coalesce(vei.qtd_veiculos, 0),
       coalesce(vei.qtd_motocicletas, 0),
       coalesce(vei.qtd_automoveis, 0),
       coalesce(vei.qtd_onibus, 0),
       coalesce(vei.qtd_caminhoes, 0),
       coalesce(vei.qtd_bicicletas, 0),
       coalesce(vei.qtd_outros, 0),
       CASE WHEN b.valor_ups_origem IN (1, 5, 13) THEN b.valor_ups_origem
            WHEN coalesce(env.qtd_vitimas_fatais, 0) > 0 THEN 13
            ELSE 5 END,
       b.valor_ups_origem IS NULL OR b.valor_ups_origem NOT IN (1, 5, 13),
       b.velocidade_permitida,
       b.precipitacao_mm,
       b.estacao_inmet,
       coalesce(env.qtd_vitimas_fatais, 0) > 0,
       coalesce(env.tem_pedestre, false) OR b.cod_tipo_sinistro IN ('H06001', 'H06002'),
       coalesce(vei.qtd_motocicletas, 0) > 0 OR coalesce(env.tem_motociclista, false),
       coalesce(c.fl_geolocalizado, false),
       c.latitude,
       c.longitude,
       c.geom,
       CASE WHEN rb.sk_regional IS NOT NULL AND b.cod_regional_origem = 27 THEN 'HIPERCENTRO -> CENTRO-SUL'
            WHEN rb.sk_regional IS NOT NULL      THEN 'BOLETIM'
            WHEN dentro.sk_regional IS NOT NULL  THEN 'ESPACIAL (ST_Within)'
            WHEN proxima.sk_regional IS NOT NULL THEN 'ESPACIAL (regional mais próxima)'
            WHEN pelo_local.sk_regional IS NOT NULL THEN 'ESPACIAL (ponto do local)'
            ELSE 'NÃO RESOLVIDA' END,
       b.arquivo_origem
FROM stg.trf_boletim b
LEFT JOIN env  ON env.numero_boletim_dw = b.numero_boletim_dw AND env.ano = b.ano
LEFT JOIN vei  ON vei.numero_boletim_dw = b.numero_boletim_dw AND vei.ano = b.ano
LEFT JOIN stg.trf_coordenada c    ON c.numero_boletim_dw = b.numero_boletim_dw AND c.ano = b.ano
LEFT JOIN stg.trf_boletim_local bl ON bl.numero_boletim_dw = b.numero_boletim_dw AND bl.ano = b.ano
LEFT JOIN dw.dim_local dl
       ON dl.chave_natural = bl.chave_local
      AND b.data >= dl.dt_inicio_vigencia AND b.data < dl.dt_fim_vigencia
LEFT JOIN dw.dim_tipo_sinistro dts ON dts.cod_tipo_sinistro = b.cod_tipo_sinistro
LEFT JOIN dw.dim_condicao_via dcv
       ON dcv.cod_tempo = b.cod_tempo
      AND dcv.condicao_climatica = b.condicao_climatica
      AND dcv.origem_clima = b.origem_clima
      AND dcv.cod_pavimento = b.cod_pavimento
      AND dcv.local_sinalizado = b.local_sinalizado
LEFT JOIN regional_boletim rb ON rb.cod_regional_boletim = b.cod_regional_origem
LEFT JOIN LATERAL (
    SELECT r.sk_regional FROM dw.dim_regional r
    WHERE rb.sk_regional IS NULL AND c.fl_geolocalizado AND r.sk_regional > 0 AND ST_Within(c.geom, r.geom)
    LIMIT 1
) dentro ON true
LEFT JOIN LATERAL (
    SELECT r.sk_regional FROM dw.dim_regional r
    WHERE rb.sk_regional IS NULL AND dentro.sk_regional IS NULL AND c.fl_geolocalizado AND r.sk_regional > 0
    ORDER BY ST_Distance(c.geom::geography, r.geom::geography)
    LIMIT 1
) proxima ON true
LEFT JOIN LATERAL (
    SELECT r.sk_regional FROM dw.dim_regional r
    WHERE rb.sk_regional IS NULL AND NOT coalesce(c.fl_geolocalizado, false) AND dl.geom IS NOT NULL
      AND r.sk_regional > 0 AND ST_Within(dl.geom, r.geom)
    LIMIT 1
) pelo_local ON true;

ANALYZE dw.fato_sinistro;
