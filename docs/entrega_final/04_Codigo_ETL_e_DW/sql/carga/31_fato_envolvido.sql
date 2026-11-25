-- =============================================================================
-- 31 — CARREGAR: fato_envolvido (1 linha por pessoa envolvida)
-- Tempo, local e regional vêm da fato_sinistro do mesmo boletim (dimensões
-- conformadas). Ligação com a dim_veiculo: o si_env não traz o sequencial do
-- veículo, só a espécie; se o boletim tem exatamente um veículo dessa espécie,
-- a pessoa herda a categoria e a situação dele; senão, o perfil da espécie com
-- categoria/situação "NÃO IDENTIFICADA". Pedestre -> -2; sem espécie -> -1.
-- =============================================================================
WITH veiculo_especie AS (
    SELECT numero_boletim_dw, ano, especie,
           count(*)       AS qtd,
           min(categoria) AS categoria,
           min(situacao)  AS situacao
    FROM stg.trf_veiculo
    GROUP BY numero_boletim_dw, ano, especie
)
INSERT INTO dw.fato_envolvido (
    numero_boletim, ano, numero_envolvido, sk_tempo, sk_local, sk_pessoa, sk_veiculo, sk_regional,
    idade, gravidade, fl_vitima, fl_vitima_fatal, fl_pedestre, fl_motociclista, fl_condutor,
    origem_tipo_envolvimento, origem_especie_veiculo, arquivo_origem)
SELECT e.numero_boletim_dw,
       e.ano,
       e.numero_envolvido,
       f.sk_tempo,
       f.sk_local,
       coalesce(dp.sk_pessoa, -1),
       CASE WHEN e.fl_pedestre THEN -2
            WHEN e.especie_veiculo IS NULL THEN -1
            ELSE coalesce(dv.sk_veiculo, -1) END,
       f.sk_regional,
       e.idade,
       e.gravidade,
       e.fl_vitima,
       e.fl_vitima_fatal,
       e.fl_pedestre,
       e.fl_motociclista,
       e.fl_condutor,
       e.origem_tipo_envolvimento,
       e.origem_especie,
       e.arquivo_origem
FROM stg.trf_envolvido e
JOIN dw.fato_sinistro f ON f.numero_boletim = e.numero_boletim_dw AND f.ano = e.ano
LEFT JOIN dw.dim_pessoa dp
       ON dp.tipo_envolvimento = e.tipo_envolvimento
      AND dp.sexo = e.sexo
      AND dp.faixa_etaria = e.faixa_etaria
      AND dp.embriaguez = e.embriaguez
LEFT JOIN veiculo_especie ve
       ON ve.numero_boletim_dw = e.numero_boletim_dw AND ve.ano = e.ano AND ve.especie = e.especie_veiculo
LEFT JOIN dw.dim_veiculo dv
       ON dv.especie = e.especie_veiculo
      AND dv.categoria = CASE WHEN ve.qtd = 1 THEN ve.categoria ELSE 'NÃO IDENTIFICADA' END
      AND dv.situacao  = CASE WHEN ve.qtd = 1 THEN ve.situacao  ELSE 'NÃO IDENTIFICADA' END;

ANALYZE dw.fato_envolvido;
