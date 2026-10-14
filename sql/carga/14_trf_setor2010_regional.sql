-- =============================================================================
-- 14 — TRANSFORMAR: população de 2010 nos limites atuais das regionais
-- Os subdistritos do IBGE de 2010 têm limites diferentes das regionais de 2022
-- (ex.: Noroeste 331 mil em 2010 x 234 mil em 2022). Por isso cada setor
-- censitário de 2010 é alocado à regional (limite 20220601) que contém o seu
-- ponto interior (ST_PointOnSurface); setores sem regional vão para a mais próxima.
-- =============================================================================
TRUNCATE stg.trf_setor2010_regional;

WITH regional AS (
    SELECT cod_reg::smallint AS cod, ST_GeomFromText(geometria, 31983) AS g
    FROM stg.regional_limite
    WHERE arquivo_origem LIKE '%20220601_regional%'
),
setor AS (
    SELECT m.cd_geocodi, m.cd_geocods, m.nm_subdist,
           ST_PointOnSurface(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(m.geometria_geojson), 4674), 31983)) AS p
    FROM stg.ibge_setor2010_malha m
),
pop AS (
    SELECT cod_setor, valor::int AS populacao
    FROM stg.ibge_setor2010_variavel
    WHERE planilha = 'Pessoa13' AND variavel = 'V001' AND valor ~ '^\d+$'
)
INSERT INTO stg.trf_setor2010_regional (cod_setor, cod_subdistrito, nome_subdistrito, cod_reg_limite, metodo, populacao)
SELECT s.cd_geocodi,
       s.cd_geocods,
       s.nm_subdist,
       coalesce(dentro.cod, proxima.cod),
       CASE WHEN dentro.cod IS NOT NULL THEN 'PONTO NO POLÍGONO' ELSE 'REGIONAL MAIS PRÓXIMA' END,
       coalesce(p.populacao, 0)
FROM setor s
LEFT JOIN pop p ON p.cod_setor = s.cd_geocodi
LEFT JOIN LATERAL (SELECT r.cod FROM regional r WHERE ST_Within(s.p, r.g) LIMIT 1) dentro ON true
LEFT JOIN LATERAL (SELECT r.cod FROM regional r ORDER BY ST_Distance(s.p, r.g) LIMIT 1) proxima ON true;
