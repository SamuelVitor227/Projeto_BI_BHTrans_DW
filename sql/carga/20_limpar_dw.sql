-- =============================================================================
-- 20 — CARREGAR: esvazia o dw para a carga inicial completa (idempotente).
-- RESTART IDENTITY faz as chaves substitutas recomeçarem, então a mesma
-- entrada gera as mesmas chaves a cada execução.
-- =============================================================================
TRUNCATE dw.fato_envolvido, dw.fato_sinistro, dw.fato_populacao,
         dw.dim_local, dw.dim_tipo_sinistro, dw.dim_condicao_via, dw.dim_veiculo,
         dw.dim_pessoa, dw.dim_regional, dw.dim_tempo
RESTART IDENTITY;
