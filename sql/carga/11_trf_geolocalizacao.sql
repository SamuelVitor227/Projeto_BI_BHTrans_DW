-- =============================================================================
-- 11 — TRANSFORMAR: geolocalização (depois da reprojeção feita em Python/pyproj)
-- Monta o ponto e marca como não geolocalizado o que estiver zerado, fora da
-- faixa de BH ou a mais de 100 m do limite do município (união das 9 regionais).
-- Nenhum boletim é descartado.
-- =============================================================================
WITH municipio AS (
    SELECT ST_Buffer(ST_Union(ST_GeomFromText(geometria, 31983)), 100) AS g
    FROM stg.regional_limite
    WHERE arquivo_origem LIKE '%20220601_regional%'
)
UPDATE stg.trf_coordenada c
SET geom                = ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326),
    fl_dentro_municipio = ST_Intersects(m.g, ST_Transform(ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326), 31983))
FROM municipio m
WHERE c.situacao = 'VALIDA';

UPDATE stg.trf_coordenada
SET situacao = 'FORA_DO_MUNICIPIO'
WHERE situacao = 'VALIDA' AND NOT fl_dentro_municipio;

UPDATE stg.trf_coordenada
SET fl_geolocalizado = (situacao = 'VALIDA');

ANALYZE stg.trf_coordenada;
