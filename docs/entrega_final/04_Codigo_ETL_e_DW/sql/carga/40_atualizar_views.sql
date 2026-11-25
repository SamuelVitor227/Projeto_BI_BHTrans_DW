-- =============================================================================
-- 40 — CARREGAR: atualiza as views materializadas (criadas WITH NO DATA no DDL)
-- =============================================================================
REFRESH MATERIALIZED VIEW dw.mv_taxa_mortalidade_anual;
REFRESH MATERIALIZED VIEW dw.mv_indicadores_regional_ano;
REFRESH MATERIALIZED VIEW dw.mv_ranking_locais;
REFRESH MATERIALIZED VIEW dw.mv_participacao_vitimas_ano;

ANALYZE dw.dim_tempo;
ANALYZE dw.dim_local;
ANALYZE dw.fato_populacao;
