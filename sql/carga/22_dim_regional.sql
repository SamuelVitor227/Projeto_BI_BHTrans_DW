-- =============================================================================
-- 22 — CARREGAR: dim_regional (9 regionais do limite 20220601, vigente até jan/2025)
-- Geometria reprojetada de SIRGAS 2000/UTM 23S (31983) para WGS 84 (4326).
-- =============================================================================
INSERT INTO dw.dim_regional (sk_regional, cod_regional, nome_regional, sigla, versao_limite, arquivo_origem)
VALUES (-1, NULL, 'NÃO INFORMADA', NULL, NULL, 'sql/carga/22_dim_regional.sql'),
       (-2, NULL, 'NÃO SE APLICA', NULL, NULL, 'sql/carga/22_dim_regional.sql');

INSERT INTO dw.dim_regional (sk_regional, cod_regional, nome_regional, sigla, area_km2, perimetro_m,
                             subdistritos_ibge, versao_limite, geom, arquivo_origem)
SELECT row_number() OVER (ORDER BY r.cod_reg::int)::smallint,
       r.cod_reg::smallint,
       r.nome,
       r.sigla,
       replace(r.area_km2, ',', '.')::numeric,
       replace(r.perimetr_m, ',', '.')::numeric,
       (SELECT string_agg(l.localidade_id, ', ' ORDER BY l.localidade_id)
          FROM stg.ibge_localidade l
         WHERE l.tipo = 'subdistrito'
           AND upper(unaccent(l.localidade_nome)) = upper(unaccent(r.nome))),
       '20220601_regional (9 regionais, vigente até jan/2025)',
       ST_Multi(ST_Transform(ST_GeomFromText(r.geometria, 31983), 4326)),
       r.arquivo_origem
FROM stg.regional_limite r
WHERE r.arquivo_origem LIKE '%20220601_regional%';
