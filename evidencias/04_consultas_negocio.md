# Consultas de negócio (requisitos da Fase 1) — gerado em 13/10/2026 22:48

Fonte das consultas: `sql/consultas_validacao.sql`.

## 1. Taxa de mortos por 100 mil habitantes x meta municipal para 2030

**Pergunta:** Como evolui a taxa de mortos no trânsito por 100 mil habitantes e qual a distância para a meta (50% da taxa de 2014 até 2030)?

```sql
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
ORDER BY ano
```

**Resultado** (14 linhas):

| ano | populacao | mortos | taxa_mortos_100mil | taxa_base_2014 | meta_2030 | distancia_meta | pct_reducao_vs_2014 | origem_populacao |
|---|---|---|---|---|---|---|---|---|
| 2011 | 2.385.640 | 217 | 9,096 | 7,105 | 3,553 | 5,543 | -28,0 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2012 | 2.395.785 | 181 | 7,555 | 7,105 | 3,553 | 4,002 | -6,3 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2013 | 2.479.165 | 170 | 6,857 | 7,105 | 3,553 | 3,305 | 3,5 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2014 | 2.491.109 | 177 | 7,105 | 7,105 | 3,553 | 3,553 | 0,0 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2015 | 2.502.557 | 150 | 5,994 | 7,105 | 3,553 | 2,441 | 15,6 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2016 | 2.513.451 | 135 | 5,371 | 7,105 | 3,553 | 1,818 | 24,4 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2017 | 2.523.794 | 121 | 4,794 | 7,105 | 3,553 | 1,242 | 32,5 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2018 | 2.501.576 | 113 | 4,517 | 7,105 | 3,553 | 0,965 | 36,4 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2019 | 2.512.070 | 105 | 4,180 | 7,105 | 3,553 | 0,627 | 41,2 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2020 | 2.521.564 | 113 | 4,481 | 7,105 | 3,553 | 0,929 | 36,9 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2021 | 2.530.701 | 113 | 4,465 | 7,105 | 3,553 | 0,913 | 37,2 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |
| 2022 | 2.315.560 | 131 | 5,657 | 7,105 | 3,553 | 2,105 | 20,4 | CENSO 2022 (SIDRA 9923) |
| 2023 | 2.365.413 | 122 | 5,158 | 7,105 | 3,553 | 1,605 | 27,4 | INTERPOLAÇÃO GEOMÉTRICA 2022–2024 |
| 2024 | 2.416.339 | 159 | 6,580 | 7,105 | 3,553 | 3,028 | 7,4 | ESTIMATIVA IBGE 1º/JUL (SIDRA 6579) |

## 2. Regionais de maior risco ajustado pela população (2022–2024)

**Pergunta:** Quais regionais têm mais vítimas e mortos por 100 mil habitantes nos três anos mais recentes?

```sql
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
ORDER BY vitimas_100mil_ano DESC
```

**Resultado** (9 linhas):

| nome_regional | sinistros | vitimas | mortos | populacao_media | vitimas_100mil_ano | mortos_100mil_ano | rank_vitimas | rank_mortos |
|---|---|---|---|---|---|---|---|---|
| CENTRO-SUL | 6446 | 7692 | 35 | 277.914 | 922,6 | 4,20 | 1 | 7 |
| PAMPULHA | 5786 | 6905 | 81 | 252.946 | 909,9 | 10,67 | 2 | 1 |
| NOROESTE | 4624 | 5589 | 43 | 238.723 | 780,4 | 6,00 | 3 | 4 |
| OESTE | 4758 | 5665 | 64 | 315.821 | 597,9 | 6,75 | 4 | 2 |
| NORTE | 3113 | 3779 | 33 | 218.055 | 577,7 | 5,04 | 5 | 5 |
| LESTE | 3213 | 3887 | 28 | 225.480 | 574,6 | 4,14 | 6 | 8 |
| NORDESTE | 4077 | 4921 | 58 | 299.979 | 546,8 | 6,44 | 7 | 3 |
| VENDA NOVA | 3320 | 4029 | 28 | 252.678 | 531,5 | 3,69 | 8 | 9 |
| BARREIRO | 3619 | 4354 | 37 | 284.175 | 510,7 | 4,34 | 9 | 6 |

## 3a. Top 10 locais (trechos e cruzamentos) por severidade (UPS), 2011–2024

**Pergunta:** Quais locais concentram a maior severidade de sinistros na série histórica (nome atual do local)?

```sql
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
LIMIT 10
```

**Resultado** (10 linhas):

| descricao_local_atual | cruzamento | bairro | sinistros | vitimas | mortos | ups |
|---|---|---|---|---|---|---|
| AVE PRESIDENTE ANTONIO CARLOS (CACHOEIRINHA) | não | CACHOEIRINHA | 979 | 1256 | 14 | 5015 |
| ROD ANEL RODOVIARIO CELSO MELLO AZEVEDO (SAO FRANCISCO) | não | SAO FRANCISCO | 922 | 1179 | 42 | 4938 |
| AVE PRESIDENTE ANTONIO CARLOS (SAO LUIZ) | não | SAO LUIZ | 920 | 1145 | 21 | 4752 |
| AVE AFONSO PENA (CENTRO) | não | CENTRO | 906 | 1143 | 5 | 4570 |
| AVE PRESIDENTE ANTONIO CARLOS (LAGOINHA) | não | LAGOINHA | 829 | 994 | 13 | 4249 |
| AVE PRESIDENTE ANTONIO CARLOS (SAO FRANCISCO) | não | SAO FRANCISCO | 795 | 1020 | 8 | 4039 |
| RUA PADRE PEDRO PINTO (VENDA NOVA) | não | VENDA NOVA | 775 | 912 | 7 | 3931 |
| AVE CRISTIANO MACHADO (VILA CLORIS) | não | VILA CLORIS | 712 | 935 | 9 | 3632 |
| AVE CRISTIANO MACHADO (UNIAO) | não | UNIAO | 700 | 875 | 12 | 3596 |
| AVE DO CONTORNO (CENTRO) | não | CENTRO | 669 | 817 | 9 | 3417 |

## 3b. Top 10 cruzamentos por número de sinistros, 2011–2024

**Pergunta:** Quais cruzamentos são os pontos críticos da cidade?

```sql
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
LIMIT 10
```

**Resultado** (10 linhas):

| descricao_local_atual | bairro | sinistros | vitimas | mortos | ups | latitude | longitude |
|---|---|---|---|---|---|---|---|
| AVE CRISTIANO MACHADO x RUA WALDOMIRO LOBO | GUARANI | 266 | 329 | 1 | 1338 | -19,84674 | -43,93263 |
| AVE CRISTIANO MACHADO x RUA JACUI | IPIRANGA | 165 | 217 | 0 | 825 | -19,89080 | -43,93078 |
| AVE AMAZONAS x AVE DO CONTORNO | GUTIERREZ | 156 | 193 | 0 | 780 | -19,92944 | -43,95719 |
| AVE AFONSO PENA x RUA DA BAHIA | CENTRO | 152 | 171 | 1 | 768 | -19,92230 | -43,93667 |
| AVE CRISTIANO MACHADO x AVE SARAMENHA | GUARANI | 129 | 169 | 1 | 653 | -19,84385 | -43,93339 |
| AVE DOS ANDRADAS x AVE DO CONTORNO | SANTA EFIGENIA | 122 | 166 | 1 | 618 | -19,92109 | -43,92424 |
| AVE AFONSO PENA x RUA RIO DE JANEIRO | CENTRO | 117 | 143 | 1 | 593 | -19,91912 | -43,93863 |
| AVE DOS ANDRADAS x VDT JORNALISTA OSWALDO FARIA | CENTRO | 115 | 162 | 0 | 575 | -19,91503 | -43,93407 |
| AVE SARAMENHA x AVE RISOLETA NEVES | GUARANI | 110 | 134 | 1 | 558 |  |  |
| AVE AMAZONAS x AVE FRANCISCO SA | GUTIERREZ | 109 | 134 | 1 | 553 | -19,93002 | -43,95990 |

## 4. Participação de pedestres e motociclistas nas vítimas e nos mortos

**Pergunta:** Qual a participação dos grupos prioritários (pedestres e motociclistas) nas vítimas e nos mortos ao longo do tempo?

```sql
SELECT ano,
       vitimas,
       pct_vitimas_pedestres,
       pct_vitimas_motociclistas,
       mortos,
       pct_mortos_pedestres,
       pct_mortos_motociclistas
FROM dw.mv_participacao_vitimas_ano
ORDER BY ano
```

**Resultado** (14 linhas):

| ano | vitimas | pct_vitimas_pedestres | pct_vitimas_motociclistas | mortos | pct_mortos_pedestres | pct_mortos_motociclistas |
|---|---|---|---|---|---|---|
| 2011 | 20.327 | 14,45 | 46,00 | 217 | 35,02 | 31,80 |
| 2012 | 18.900 | 14,07 | 47,43 | 181 | 42,54 | 28,18 |
| 2013 | 17.689 | 13,54 | 47,08 | 170 | 35,29 | 34,12 |
| 2014 | 18.477 | 12,88 | 48,37 | 177 | 35,03 | 36,16 |
| 2015 | 16.140 | 12,52 | 49,45 | 150 | 26,00 | 47,33 |
| 2016 | 15.062 | 12,51 | 50,82 | 135 | 31,11 | 38,52 |
| 2017 | 14.611 | 11,98 | 58,98 | 121 | 33,88 | 39,67 |
| 2018 | 13.987 | 11,55 | 61,20 | 113 | 40,71 | 40,71 |
| 2019 | 15.870 | 10,91 | 63,82 | 105 | 34,29 | 47,62 |
| 2020 | 12.657 | 9,42 | 66,58 | 113 | 36,28 | 48,67 |
| 2021 | 13.175 | 8,94 | 66,19 | 113 | 32,74 | 38,94 |
| 2022 | 14.495 | 9,65 | 67,80 | 131 | 31,30 | 44,27 |
| 2023 | 16.802 | 8,84 | 71,89 | 122 | 29,51 | 54,10 |
| 2024 | 15.927 | 8,55 | 73,27 | 159 | 31,45 | 52,83 |

## 5. Tipos de sinistro mais letais e os que mais crescem

**Pergunta:** Quais tipos de sinistro matam mais por ocorrência e quais cresceram entre 2011–2013 e 2022–2024?

```sql
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
ORDER BY mortos_por_mil_sinistros DESC
```

**Resultado** (7 linhas):

| grupo_tipo_sinistro | sinistros | mortos | mortos_por_mil_sinistros | pct_sinistros_fatais | media_anual_2011_2013 | media_anual_2022_2024 | variacao_pct |
|---|---|---|---|---|---|---|---|
| Atropelamento de pessoa | 24.328 | 690 | 28,4 | 2,79 | 2559 | 1294 | -49,4 |
| Outros | 3793 | 87 | 22,9 | 2,16 | 484 | 188 | -61,1 |
| Choque | 27.649 | 510 | 18,4 | 1,68 | 2232 | 2139 | -4,2 |
| Capotamento/tombamento | 12.524 | 104 | 8,3 | 0,78 | 626 | 1109 | 77,1 |
| Queda | 7706 | 57 | 7,4 | 0,67 | 1010 | 211 | -79,1 |
| Colisão/abalroamento | 108.086 | 557 | 5,2 | 0,49 | 8284 | 8110 | -2,1 |
| Atropelamento de animal | 642 | 2 | 3,1 | 0,31 | 37 | 48 | 30,9 |

## 6. Clima x severidade dos sinistros

**Pergunta:** Sinistros com chuva (declarada ou registrada pelo INMET) são mais graves?

```sql
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
ORDER BY c.grupo_chuva, c.origem_clima
```

**Resultado** (5 linhas):

| grupo_chuva | origem_clima | sinistros | vitimas_por_sinistro | mortos_por_mil_sinistros | pct_fatais | ups_media |
|---|---|---|---|---|---|---|
| COM CHUVA | DECLARADO NO BOLETIM | 5162 | 1,257 | 19,8 | 1,86 | 5,15 |
| COM CHUVA | IMPUTADO PELO INMET | 7863 | 1,172 | 5,9 | 0,53 | 5,04 |
| NÃO INFORMADO | NÃO INFORMADO | 188 | 1,176 | 5,3 | 0,53 | 5,04 |
| SEM CHUVA | DECLARADO NO BOLETIM | 62.455 | 1,273 | 18,2 | 1,71 | 5,14 |
| SEM CHUVA | IMPUTADO PELO INMET | 109.060 | 1,180 | 6,6 | 0,64 | 5,05 |

## 7. Distribuição por dia da semana e período do dia (2022–2024)

**Pergunta:** Em que dias e períodos se concentram os sinistros e as mortes?

```sql
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
ORDER BY t.dia_semana
```

**Resultado** (7 linhas):

| dia_semana | nome_dia_semana | madrugada | manha | tarde | noite | total | mortos |
|---|---|---|---|---|---|---|---|
| 1 | Segunda-feira | 307 | 1985 | 2130 | 1396 | 5818 | 62 |
| 2 | Terça-feira | 171 | 2006 | 2094 | 1547 | 5818 | 51 |
| 3 | Quarta-feira | 201 | 1877 | 2108 | 1646 | 5832 | 57 |
| 4 | Quinta-feira | 234 | 1896 | 2091 | 1647 | 5868 | 46 |
| 5 | Sexta-feira | 280 | 1881 | 2360 | 1844 | 6365 | 65 |
| 6 | Sábado | 499 | 1385 | 2054 | 1528 | 5466 | 65 |
| 7 | Domingo | 561 | 772 | 1439 | 1361 | 4133 | 66 |
