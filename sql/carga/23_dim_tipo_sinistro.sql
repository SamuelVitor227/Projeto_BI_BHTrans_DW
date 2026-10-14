-- =============================================================================
-- 23 — CARREGAR: dim_tipo_sinistro (domínio real + agrupamento do de-para)
-- Códigos que aparecerem na fonte sem de-para entram no grupo "Outros"
-- (e o teste de domínio acusa a lacuna).
-- =============================================================================
INSERT INTO dw.dim_tipo_sinistro (sk_tipo_sinistro, cod_tipo_sinistro, descricao, grupo_tipo_sinistro, ordem, arquivo_origem)
OVERRIDING SYSTEM VALUE
VALUES (-1, '(n/i)', 'Não informado', 'Não informado', 98, 'sql/carga/23_dim_tipo_sinistro.sql'),
       (-2, '(n/a)', 'Não se aplica', 'Não se aplica', 99, 'sql/carga/23_dim_tipo_sinistro.sql');

WITH fonte AS (
    SELECT btrim(tipo_acidente) AS cod, max(btrim(desc_tipo_acidente)) AS descricao_origem,
           min(arquivo_origem) AS arquivo_origem
    FROM stg.si_bol
    GROUP BY 1
)
INSERT INTO dw.dim_tipo_sinistro (cod_tipo_sinistro, descricao, descricao_origem, grupo_tipo_sinistro, ordem, arquivo_origem)
SELECT m.codigo, m.descricao, f.descricao_origem, m.grupo, m.ordem,
       'etl/mapeamentos/dominios.csv; ' || coalesce(f.arquivo_origem, '(sem ocorrência)')
FROM stg.map_dominio m
LEFT JOIN fonte f ON f.cod = m.codigo
WHERE m.dominio = 'tipo_sinistro'
UNION ALL
SELECT f.cod, initcap(f.descricao_origem), f.descricao_origem, 'Outros', 90, f.arquivo_origem
FROM fonte f
WHERE NOT EXISTS (SELECT 1 FROM stg.map_dominio m WHERE m.dominio = 'tipo_sinistro' AND m.codigo = f.cod)
ORDER BY 5;
