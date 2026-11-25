-- =============================================================================
-- 32 — CARREGAR: fato_populacao (regional x ano)
-- sk_tempo = 1º de julho do ano, membro "Sem hora" (AAAA070199): data de
-- referência das estimativas do IBGE.
-- =============================================================================
INSERT INTO dw.fato_populacao (sk_regional, sk_tempo, ano, populacao_residente, participacao_regional,
                               populacao_municipio, origem_dado, origem_total_municipio, metodo_regional,
                               arquivo_origem)
SELECT r.sk_regional,
       (p.ano * 10000 + 701) * 100 + 99,
       p.ano,
       p.populacao_residente,
       p.participacao,
       p.populacao_municipio,
       p.origem_dado,
       p.origem_total_municipio,
       p.metodo_regional,
       'IBGE: SIDRA 6579/202/9923 e setores censitários 2010'
FROM stg.trf_populacao p
JOIN dw.dim_regional r ON r.cod_regional = p.cod_reg_limite
ORDER BY p.ano, r.sk_regional;
