/*
===============================================================================
 Consultas de validação — requisitos de negócio da Fase 1 respondidos pelo DW
 Banco: dw_sinistros_bh (schema dw). Os resultados são gravados em
 evidencias/04_consultas_negocio.md por "python -m etl.evidencias".
 Cada consulta começa com "-- @consulta:" e termina com ";".
===============================================================================
*/

-- @consulta: 1. Taxa de mortos por 100 mil habitantes x meta municipal para 2030
-- @pergunta: Como evolui a taxa de mortos no trânsito por 100 mil habitantes e qual a distância para a meta (50% da taxa de 2014 até 2030)?
SELECT ano,
       populacao,
       mortos,
       taxa_mortos_100mil,
       taxa_base_2014,
       meta_2030,
       distancia_meta,
       pct_reducao_vs_2014,
       origem_populacao
FROM dw.mv_taxa_mortalidade_anual
ORDER BY ano;

-- @consulta: 2. Regionais de maior risco ajustado pela população (2022–2024)
-- @pergunta: Quais regionais têm mais vítimas e mortos por 100 mil habitantes nos três anos mais recentes?
SELECT r.nome_regional,
       sum(m.sinistros)                                                     AS sinistros,
       sum(m.vitimas)                                                       AS vitimas,
       sum(m.mortos)                                                        AS mortos,
       round(avg(m.populacao))                                              AS populacao_media,
       round(sum(m.vitimas) * 100000.0 / sum(m.populacao) , 1)              AS vitimas_100mil_ano,
       round(sum(m.mortos)  * 100000.0 / sum(m.populacao) , 2)              AS mortos_100mil_ano,
       rank() OVER (ORDER BY sum(m.vitimas) * 1.0 / sum(m.populacao) DESC)  AS rank_vitimas,
       rank() OVER (ORDER BY sum(m.mortos)  * 1.0 / sum(m.populacao) DESC)  AS rank_mortos
FROM dw.mv_indicadores_regional_ano m
JOIN dw.dim_regional r USING (sk_regional)
WHERE m.ano BETWEEN 2022 AND 2024 AND m.sk_regional > 0
GROUP BY r.nome_regional
ORDER BY vitimas_100mil_ano DESC;

-- @consulta: 3a. Top 10 locais (trechos e cruzamentos) por severidade (UPS), 2011–2024
-- @pergunta: Quais locais concentram a maior severidade de sinistros na série histórica (nome atual do local)?
SELECT descricao_local_atual,
       bool_or(fl_cruzamento)   AS cruzamento,
       max(nome_bairro)         AS bairro,
       sum(sinistros)           AS sinistros,
       sum(vitimas)             AS vitimas,
       sum(mortos)              AS mortos,
       sum(ups)                 AS ups
FROM dw.mv_ranking_locais
GROUP BY chave_natural, descricao_local_atual
ORDER BY ups DESC, sinistros DESC
LIMIT 10;

-- @consulta: 3b. Top 10 cruzamentos por número de sinistros, 2011–2024
-- @pergunta: Quais cruzamentos são os pontos críticos da cidade?
SELECT descricao_local_atual,
       max(nome_bairro)         AS bairro,
       sum(sinistros)           AS sinistros,
       sum(vitimas)             AS vitimas,
       sum(mortos)              AS mortos,
       sum(ups)                 AS ups,
       round(max(latitude)::numeric, 5)  AS latitude,
       round(max(longitude)::numeric, 5) AS longitude
FROM dw.mv_ranking_locais
WHERE fl_cruzamento
GROUP BY chave_natural, descricao_local_atual
ORDER BY sinistros DESC, ups DESC
LIMIT 10;

-- @consulta: 4. Participação de pedestres e motociclistas nas vítimas e nos mortos
-- @pergunta: Qual a participação dos grupos prioritários (pedestres e motociclistas) nas vítimas e nos mortos ao longo do tempo?
SELECT ano,
       vitimas,
       pct_vitimas_pedestres,
       pct_vitimas_motociclistas,
       mortos,
       pct_mortos_pedestres,
       pct_mortos_motociclistas
FROM dw.mv_participacao_vitimas_ano
ORDER BY ano;

-- @consulta: 5. Tipos de sinistro mais letais e os que mais crescem
-- @pergunta: Quais tipos de sinistro matam mais por ocorrência e quais cresceram entre 2011–2013 e 2022–2024?
SELECT t.grupo_tipo_sinistro,
       count(*)                                                              AS sinistros,
       sum(f.qtd_vitimas_fatais)                                             AS mortos,
       round(1000.0 * sum(f.qtd_vitimas_fatais) / count(*), 1)               AS mortos_por_mil_sinistros,
       round(100.0 * count(*) FILTER (WHERE f.fl_fatal) / count(*), 2)       AS pct_sinistros_fatais,
       round(count(*) FILTER (WHERE f.ano BETWEEN 2011 AND 2013) / 3.0)      AS media_anual_2011_2013,
       round(count(*) FILTER (WHERE f.ano BETWEEN 2022 AND 2024) / 3.0)      AS media_anual_2022_2024,
       round(100.0 * (count(*) FILTER (WHERE f.ano BETWEEN 2022 AND 2024)
              - count(*) FILTER (WHERE f.ano BETWEEN 2011 AND 2013))
             / nullif(count(*) FILTER (WHERE f.ano BETWEEN 2011 AND 2013), 0), 1) AS variacao_pct
FROM dw.fato_sinistro f
JOIN dw.dim_tipo_sinistro t USING (sk_tipo_sinistro)
GROUP BY t.grupo_tipo_sinistro
ORDER BY mortos_por_mil_sinistros DESC;

-- @consulta: 6. Clima x severidade dos sinistros
-- @pergunta: Sinistros com chuva (declarada ou registrada pelo INMET) são mais graves?
SELECT c.grupo_chuva,
       c.origem_clima,
       count(*)                                                        AS sinistros,
       round(avg(f.qtd_vitimas), 3)                                    AS vitimas_por_sinistro,
       round(1000.0 * sum(f.qtd_vitimas_fatais) / count(*), 1)         AS mortos_por_mil_sinistros,
       round(100.0 * count(*) FILTER (WHERE f.fl_fatal) / count(*), 2) AS pct_fatais,
       round(avg(f.valor_ups), 2)                                      AS ups_media
FROM dw.fato_sinistro f
JOIN dw.dim_condicao_via c USING (sk_condicao_via)
GROUP BY c.grupo_chuva, c.origem_clima
ORDER BY c.grupo_chuva, c.origem_clima;

-- @consulta: 7. Distribuição por dia da semana e período do dia (2022–2024)
-- @pergunta: Em que dias e períodos se concentram os sinistros e as mortes?
SELECT t.dia_semana,
       t.nome_dia_semana,
       count(*) FILTER (WHERE t.periodo_dia = 'Madrugada') AS madrugada,
       count(*) FILTER (WHERE t.periodo_dia = 'Manhã')     AS manha,
       count(*) FILTER (WHERE t.periodo_dia = 'Tarde')     AS tarde,
       count(*) FILTER (WHERE t.periodo_dia = 'Noite')     AS noite,
       count(*)                                            AS total,
       sum(f.qtd_vitimas_fatais)                           AS mortos
FROM dw.fato_sinistro f
JOIN dw.dim_tempo t USING (sk_tempo)
WHERE f.ano BETWEEN 2022 AND 2024
GROUP BY t.dia_semana, t.nome_dia_semana
ORDER BY t.dia_semana;
