# Estrutura do Data Warehouse — gerado em 13/10/2026 22:48

- SGBD: `PostgreSQL 16.9 (Debian 16.9-1.pgdg110+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 10.2.1-6) 10.2.1 20210110, 64-bit`
- PostGIS: `POSTGIS="3.5.2 dea6d0a" [EXTENSION] PGSQL="160" GEOS="3.9.0-CAPI-1.16.2" PROJ="7.2.1 NETWORK_ENABLED=OFF URL_ENDPOINT=ht...`
- dw: **10** tabelas (7 dimensões + 3 fatos), **255** partições, **4** views materializadas
- stg: **25** tabelas (espelhos, de-paras, trabalho, log e qualidade)
- bi: **15** views de consumo do Power BI (sem geometria e sem partições)
- Colunas: **767** em stg, dw e bi; sem COMMENT: **0**
- Dicionário completo das colunas (tipo, nulidade, comentário): `01f_colunas.csv`
## Schemas

Arquivo completo: `01a_schemas.csv` (3 linhas)

| schema | comentario |
|---|---|
| bi | Camada de consumo do Power BI: views sobre o dw sem geometria, sem partições e sem colunas de linhagem, com calendário diário e dimensão de hora. |
| dw | Data Warehouse: modelo estrela (3 fatos e 7 dimensões) e views materializadas de indicadores. |
| stg | Staging: espelho das fontes (tudo como texto, sem regra de negócio), tabelas de trabalho da transformação, log de carga e resultados dos testes de qualidade. |

## Tabelas (sem partições), views materializadas e views do Power BI

Arquivo completo: `01b_tabelas.csv` (54 linhas)

| schema | tabela | tipo | colunas | comentario |
|---|---|---|---|---|
| stg | ibge_localidade | tabela | 9 | Distritos e subdistritos de Belo Horizonte segundo a API de localidades do IBGE (divisão territorial vigente). |
| stg | ibge_setor2010_malha | tabela | 14 | Malha de setores censitários do Censo 2010 (shapefile 31SEE250GC_SIR, SIRGAS 2000 geográfico), filtrada para Belo Horizonte. |
| stg | ibge_setor2010_variavel | tabela | 7 | Agregados por setor censitário do Censo 2010 (Resultados do Universo), formato longo, apenas setores de Belo Horizonte e variáveis de população. |
| stg | ibge_sidra_valor | tabela | 11 | Valores das consultas à API de agregados do IBGE (SIDRA): estimativas (tabela 6579), Censo 2010 (202) e Censo 2022 (9923), em formato longo. |
| stg | inmet_horario | tabela | 25 | Espelho dos CSVs horários do INMET das estações automáticas de BH: A521 Pampulha (principal) e F501 Cercadinho (reserva, desde 27/12/2013). Horário em UTC. |
| stg | log_carga | tabela | 11 | Registro de cada execução do ETL (uma linha por etapa: extrair, staging, transformar, testes, carregar, reconciliar). |
| stg | manifesto_raw | tabela | 17 | Espelho de dados/raw/manifesto.csv: um registro por arquivo guardado na camada RAW (origem, hash e data de coleta). |
| stg | map_dominio | tabela | 9 | De-para dos domínios codificados (tipo de sinistro, tempo, pavimento, severidade, categoria/situação/espécie de veículo, tipo de logradouro, sexo), derivado da inspeção dos arquivos reais. |
| stg | map_regional | tabela | 10 | De-para das regionais: cod_regional/desc_regional do si-bol x COD_REG/NOME do limite 20220601 x subdistritos do IBGE. |
| stg | regional_limite | tabela | 10 | Espelho dos arquivos de limites das regionais da PBH: 20220601_regional (9 regionais, vigente até jan/2025, usado no DW) e 20250204_regional (10 regionais, apenas para referência). |
| stg | resultado_qualidade | tabela | 11 | Resultado de cada teste de qualidade executado antes de promover os dados ao dw. |
| stg | si_bol | tabela | 27 | Espelho dos arquivos si-bol-AAAA.csv (PBH/BHTrans): dados gerais de cada boletim de ocorrência de sinistro de trânsito com vítima. |
| stg | si_env | tabela | 23 | Espelho dos arquivos si_env-AAAA.csv (tabela chamada "si-pess" na Fase 2): pessoas envolvidas em cada boletim. |
| stg | si_log | tabela | 20 | Espelho dos arquivos si-log-AAAA.csv: logradouros do local do sinistro (sequência 1 = logradouro principal; 2 em diante = cruzamento/referência). |
| stg | si_veic | tabela | 15 | Espelho dos arquivos si-veic-AAAA.csv: veículos envolvidos em cada boletim (o de 2023 é lido em CP850). |
| stg | trf_boletim | tabela | 28 | Boletins tipados e deduplicados (1 linha por sinistro). Números repetidos no mesmo ano com data/hora diferentes são eventos distintos e recebem sufixo /2, /3. |
| stg | trf_boletim_local | tabela | 12 | Local de ocorrência de cada boletim (logradouro principal + cruzamento + bairro), com a chave natural da dim_local. |
| stg | trf_clima_hora | tabela | 8 | Leituras horárias do INMET convertidas de UTC para America/Sao_Paulo (zoneinfo, com horário de verão até 2019). Cada leitura cobre a hora que termina em dt_hora_fim_utc. |
| stg | trf_coordenada | tabela | 13 | Coordenadas corrigidas e reprojetadas com pyproj: 2011–2015 em SAD 69/UTM 23S (EPSG:29193, X e Y em escala x100) e 2016+ em SIRGAS 2000/UTM 23S (EPSG:31983), ambas para WGS 84 (EPSG:4326). |
| stg | trf_envolvido | tabela | 22 | Pessoas envolvidas tipadas, com tipo de envolvimento (indicador da fonte ou regra derivada), gravidade e flags. |
| stg | trf_local_versao | tabela | 21 | Versões (SCD Tipo 2) de cada local: uma nova versão a cada mudança de nome do logradouro principal ou do cruzamento. |
| stg | trf_logradouro_versao | tabela | 12 | Histórico de nomes por código de logradouro: variações de grafia consolidadas por similaridade; nova versão quando um nome sucede outro no tempo. |
| stg | trf_populacao | tabela | 10 | População residente por regional e ano: participação da regional x população do município, com arredondamento pelo maior resto para fechar exatamente no total. |
| stg | trf_setor2010_regional | tabela | 8 | Setores censitários de 2010 alocados às 9 regionais do limite 20220601 (ponto interior do setor dentro do polígono), para obter a população de 2010 nos limites atuais. |
| stg | trf_veiculo | tabela | 13 | Veículos envolvidos tipados, com descrições padronizadas pelos códigos e grupo de espécie. |
| dw | dim_condicao_via | tabela | 10 | Dimensão lixo (junk) com as condições do local: clima (declarado no boletim ou imputado pelo INMET), pavimento e sinalização. |
| dw | dim_local | tabela | 28 | Dimensão local de ocorrência (SCD Tipo 2): logradouro principal + logradouro de cruzamento (quando houver) + bairro. Nova versão quando o nome de um logradouro muda; o nome atual fica em todas as versões. |
| dw | dim_pessoa | tabela | 8 | Dimensão perfil de pessoa envolvida (tipo de envolvimento x sexo x faixa etária x embriaguez). O cinto de segurança ficou de fora: o domínio alterna entre anos (valor padrão do sistema), ver README. |
| dw | dim_regional | tabela | 11 | Dimensão regional administrativa: as 9 regionais vigentes até jan/2025 (compatíveis com a série de sinistros e com o Censo 2022). |
| dw | dim_tempo | tabela | 18 | Dimensão tempo no grão data + hora (2010–2030). Membro "Sem hora" por dia (sk AAAAMMDD99) para boletins sem hora informada e para a fato_populacao; -1 e -2 são membros especiais. |
| dw | dim_tipo_sinistro | tabela | 8 | Dimensão tipo de sinistro, com agrupamento derivado do domínio real (colisão/abalroamento, atropelamento, choque, capotamento/tombamento, queda, outros). |
| dw | dim_veiculo | tabela | 8 | Dimensão perfil de veículo (espécie x categoria x situação). Ligada à fato_envolvido: a pessoa herda o perfil do veículo quando o boletim tem exatamente um veículo da espécie dela. |
| dw | fato_populacao | tabela | 11 | Fato população residente por regional e ano (referência 1º de julho, membro "Sem hora" da dim_tempo). Denominador das taxas por 100 mil habitantes. |
| dw | fato_envolvido | tabela particionada | 20 | Fato envolvido: uma linha por pessoa envolvida (numero_boletim + ano + número do envolvido), particionada por ano. Recebe dim_pessoa e dim_veiculo, que não cabem no grão de boletim. |
| dw | fato_sinistro | tabela particionada | 32 | Fato sinistro: uma linha por boletim de ocorrência (numero_boletim + ano), particionada por ano. Contagens de veículos por espécie respondem ao perfil da frota por local sem quebrar o grão. |
| dw | mv_indicadores_regional_ano | view materializada | 14 | Sinistros, vítimas, mortos, UPS e taxas por 100 mil habitantes por regional e ano (risco ajustado pela população). |
| dw | mv_participacao_vitimas_ano | view materializada | 11 | Participação de pedestres e motociclistas (grupos prioritários) nas vítimas e nos mortos, por ano. |
| dw | mv_ranking_locais | view materializada | 15 | Ranking de locais e cruzamentos por ano (sinistros, vítimas, mortos, UPS), agregando todas as versões do local pela chave natural e exibindo o nome atual. |
| dw | mv_taxa_mortalidade_anual | view materializada | 12 | Taxa anual de mortos no trânsito por 100 mil habitantes, meta municipal (50% da taxa de 2014 até 2030) e distância até a meta (nulas se 2014 não estiver carregado). |
| bi | dim_calendario | view (Power BI) | 16 | Calendário diário de 2010 a 2030 (1 linha por data) para "Marcar como tabela de datas" no Power BI. Relaciona-se com as fatos pela coluna data. |
| bi | dim_condicao_via | view (Power BI) | 8 | dw.dim_condicao_via sem as colunas de linhagem. |
| bi | dim_hora | view (Power BI) | 6 | Horas do dia (0–23) e o membro 99 "Não informada". Relaciona-se com fato_sinistro e fato_envolvido pela coluna hora. |
| bi | dim_local | view (Power BI) | 25 | dw.dim_local (SCD Tipo 2) sem a geometria; o ponto representativo está em latitude/longitude. |
| bi | dim_pessoa | view (Power BI) | 6 | dw.dim_pessoa sem as colunas de linhagem. |
| bi | dim_regional | view (Power BI) | 10 | dw.dim_regional sem a geometria; latitude/longitude de um ponto interno ao polígono (rótulos e bolhas). Os polígonos estão em powerbi/regionais_bh.*. |
| bi | dim_tipo_sinistro | view (Power BI) | 6 | dw.dim_tipo_sinistro sem as colunas de linhagem. |
| bi | dim_veiculo | view (Power BI) | 6 | dw.dim_veiculo sem as colunas de linhagem. |
| bi | fato_envolvido | view (Power BI) | 21 | dw.fato_envolvido (1 linha por pessoa) com data e hora no lugar de sk_tempo e com o tipo de sinistro e a condição da via herdados do boletim. |
| bi | fato_populacao | view (Power BI) | 9 | dw.fato_populacao (regional x ano) com a data de referência (1º de julho) no lugar de sk_tempo. |
| bi | fato_sinistro | view (Power BI) | 30 | dw.fato_sinistro (1 linha por boletim) com data e hora no lugar de sk_tempo e sem a geometria; o ponto exato está em latitude/longitude (nulas quando não geolocalizado). |
| bi | ind_participacao_vitimas_ano | view (Power BI) | 11 | Exposição de dw.mv_participacao_vitimas_ano: participação de pedestres e motociclistas nas vítimas e nos mortos. |
| bi | ind_ranking_locais | view (Power BI) | 15 | Exposição de dw.mv_ranking_locais: ranking anual de locais e cruzamentos. |
| bi | ind_regional_ano | view (Power BI) | 14 | Exposição de dw.mv_indicadores_regional_ano: sinistros, vítimas, mortos e taxas por regional e ano. |
| bi | ind_taxa_mortalidade_anual | view (Power BI) | 12 | Exposição de dw.mv_taxa_mortalidade_anual: taxa anual de mortos por 100 mil hab., meta 2030 e distância até a meta. |

## Partições das fatos

Arquivo completo: `01c_particoes.csv` (255 linhas)

| tabela_pai | particao | limites |
|---|---|---|
| fato_envolvido | fato_envolvido_2011 | FOR VALUES FROM ('2011') TO ('2012') |
| fato_envolvido | fato_envolvido_2012 | FOR VALUES FROM ('2012') TO ('2013') |
| fato_envolvido | fato_envolvido_2013 | FOR VALUES FROM ('2013') TO ('2014') |
| fato_envolvido | fato_envolvido_2014 | FOR VALUES FROM ('2014') TO ('2015') |
| fato_envolvido | fato_envolvido_2015 | FOR VALUES FROM ('2015') TO ('2016') |
| fato_envolvido | fato_envolvido_2016 | FOR VALUES FROM ('2016') TO ('2017') |
| fato_envolvido | fato_envolvido_2017 | FOR VALUES FROM ('2017') TO ('2018') |
| fato_envolvido | fato_envolvido_2018 | FOR VALUES FROM ('2018') TO ('2019') |
| fato_envolvido | fato_envolvido_2019 | FOR VALUES FROM ('2019') TO ('2020') |
| fato_envolvido | fato_envolvido_2020 | FOR VALUES FROM ('2020') TO ('2021') |
| fato_envolvido | fato_envolvido_2021 | FOR VALUES FROM ('2021') TO ('2022') |
| fato_envolvido | fato_envolvido_2022 | FOR VALUES FROM ('2022') TO ('2023') |
| fato_envolvido | fato_envolvido_2023 | FOR VALUES FROM ('2023') TO ('2024') |
| fato_envolvido | fato_envolvido_2024 | FOR VALUES FROM ('2024') TO ('2025') |
| fato_envolvido | fato_envolvido_2025 | FOR VALUES FROM ('2025') TO ('2026') |
| fato_envolvido | fato_envolvido_2026 | FOR VALUES FROM ('2026') TO ('2027') |
| fato_envolvido | fato_envolvido_default | DEFAULT |
| fato_sinistro | fato_sinistro_2011 | FOR VALUES FROM ('2011') TO ('2012') |
| fato_sinistro | fato_sinistro_2012 | FOR VALUES FROM ('2012') TO ('2013') |
| fato_sinistro | fato_sinistro_2013 | FOR VALUES FROM ('2013') TO ('2014') |
| fato_sinistro | fato_sinistro_2014 | FOR VALUES FROM ('2014') TO ('2015') |
| fato_sinistro | fato_sinistro_2015 | FOR VALUES FROM ('2015') TO ('2016') |
| fato_sinistro | fato_sinistro_2016 | FOR VALUES FROM ('2016') TO ('2017') |
| fato_sinistro | fato_sinistro_2017 | FOR VALUES FROM ('2017') TO ('2018') |
| fato_sinistro | fato_sinistro_2018 | FOR VALUES FROM ('2018') TO ('2019') |
| fato_sinistro | fato_sinistro_2019 | FOR VALUES FROM ('2019') TO ('2020') |
| fato_sinistro | fato_sinistro_2020 | FOR VALUES FROM ('2020') TO ('2021') |
| fato_sinistro | fato_sinistro_2021 | FOR VALUES FROM ('2021') TO ('2022') |
| fato_sinistro | fato_sinistro_2022 | FOR VALUES FROM ('2022') TO ('2023') |
| fato_sinistro | fato_sinistro_2023 | FOR VALUES FROM ('2023') TO ('2024') |
| fato_sinistro | fato_sinistro_2024 | FOR VALUES FROM ('2024') TO ('2025') |
| fato_sinistro | fato_sinistro_2025 | FOR VALUES FROM ('2025') TO ('2026') |
| fato_sinistro | fato_sinistro_2026 | FOR VALUES FROM ('2026') TO ('2027') |
| fato_sinistro | fato_sinistro_default | DEFAULT |
| gix_fato_sinistro_geom | fato_sinistro_2011_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2012_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2013_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2014_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2015_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2016_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2017_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2018_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2019_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2020_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2021_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2022_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2023_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2024_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2025_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_2026_geom_idx |  |
| gix_fato_sinistro_geom | fato_sinistro_default_geom_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2011_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2012_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2013_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2014_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2015_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2016_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2017_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2018_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2019_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2020_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2021_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2022_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2023_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2024_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2025_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_2026_sk_local_idx |  |
| ix_fato_envolvido_sk_local | fato_envolvido_default_sk_local_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2011_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2012_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2013_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2014_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2015_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2016_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2017_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2018_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2019_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2020_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2021_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2022_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2023_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2024_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2025_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_2026_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_pessoa | fato_envolvido_default_sk_pessoa_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2011_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2012_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2013_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2014_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2015_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2016_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2017_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2018_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2019_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2020_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2021_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2022_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2023_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2024_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2025_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_2026_sk_regional_idx |  |
| ix_fato_envolvido_sk_regional | fato_envolvido_default_sk_regional_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2011_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2012_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2013_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2014_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2015_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2016_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2017_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2018_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2019_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2020_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2021_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2022_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2023_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2024_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2025_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_2026_sk_tempo_idx |  |
| ix_fato_envolvido_sk_tempo | fato_envolvido_default_sk_tempo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2011_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2012_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2013_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2014_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2015_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2016_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2017_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2018_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2019_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2020_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2021_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2022_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2023_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2024_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2025_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_2026_sk_veiculo_idx |  |
| ix_fato_envolvido_sk_veiculo | fato_envolvido_default_sk_veiculo_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2011_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2012_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2013_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2014_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2015_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2016_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2017_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2018_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2019_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2020_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2021_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2022_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2023_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2024_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2025_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_2026_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_condicao_via | fato_sinistro_default_sk_condicao_via_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2011_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2012_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2013_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2014_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2015_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2016_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2017_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2018_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2019_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2020_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2021_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2022_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2023_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2024_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2025_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_2026_sk_local_idx |  |
| ix_fato_sinistro_sk_local | fato_sinistro_default_sk_local_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2011_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2012_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2013_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2014_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2015_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2016_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2017_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2018_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2019_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2020_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2021_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2022_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2023_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2024_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2025_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_2026_sk_regional_idx |  |
| ix_fato_sinistro_sk_regional | fato_sinistro_default_sk_regional_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2011_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2012_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2013_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2014_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2015_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2016_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2017_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2018_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2019_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2020_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2021_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2022_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2023_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2024_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2025_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_2026_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tempo | fato_sinistro_default_sk_tempo_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2011_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2012_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2013_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2014_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2015_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2016_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2017_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2018_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2019_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2020_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2021_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2022_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2023_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2024_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2025_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_2026_sk_tipo_sinistro_idx |  |
| ix_fato_sinistro_sk_tipo_sinistro | fato_sinistro_default_sk_tipo_sinistro_idx |  |
| pk_fato_envolvido | fato_envolvido_2011_pkey |  |
| pk_fato_envolvido | fato_envolvido_2012_pkey |  |
| pk_fato_envolvido | fato_envolvido_2013_pkey |  |
| pk_fato_envolvido | fato_envolvido_2014_pkey |  |
| pk_fato_envolvido | fato_envolvido_2015_pkey |  |
| pk_fato_envolvido | fato_envolvido_2016_pkey |  |
| pk_fato_envolvido | fato_envolvido_2017_pkey |  |
| pk_fato_envolvido | fato_envolvido_2018_pkey |  |
| pk_fato_envolvido | fato_envolvido_2019_pkey |  |
| pk_fato_envolvido | fato_envolvido_2020_pkey |  |
| pk_fato_envolvido | fato_envolvido_2021_pkey |  |
| pk_fato_envolvido | fato_envolvido_2022_pkey |  |
| pk_fato_envolvido | fato_envolvido_2023_pkey |  |
| pk_fato_envolvido | fato_envolvido_2024_pkey |  |
| pk_fato_envolvido | fato_envolvido_2025_pkey |  |
| pk_fato_envolvido | fato_envolvido_2026_pkey |  |
| pk_fato_envolvido | fato_envolvido_default_pkey |  |
| pk_fato_sinistro | fato_sinistro_2011_pkey |  |
| pk_fato_sinistro | fato_sinistro_2012_pkey |  |
| pk_fato_sinistro | fato_sinistro_2013_pkey |  |
| pk_fato_sinistro | fato_sinistro_2014_pkey |  |
| pk_fato_sinistro | fato_sinistro_2015_pkey |  |
| pk_fato_sinistro | fato_sinistro_2016_pkey |  |
| pk_fato_sinistro | fato_sinistro_2017_pkey |  |
| pk_fato_sinistro | fato_sinistro_2018_pkey |  |
| pk_fato_sinistro | fato_sinistro_2019_pkey |  |
| pk_fato_sinistro | fato_sinistro_2020_pkey |  |
| pk_fato_sinistro | fato_sinistro_2021_pkey |  |
| pk_fato_sinistro | fato_sinistro_2022_pkey |  |
| pk_fato_sinistro | fato_sinistro_2023_pkey |  |
| pk_fato_sinistro | fato_sinistro_2024_pkey |  |
| pk_fato_sinistro | fato_sinistro_2025_pkey |  |
| pk_fato_sinistro | fato_sinistro_2026_pkey |  |
| pk_fato_sinistro | fato_sinistro_default_pkey |  |

## Chaves primárias, únicas, checks e estrangeiras (dw)

Arquivo completo: `01d_constraints.csv` (37 linhas)

| tabela | restricao | tipo | definicao |
|---|---|---|---|
| dim_condicao_via | ck_dim_condicao_via_grupo | CHECK | CHECK ((grupo_chuva = ANY (ARRAY['COM CHUVA'::text, 'SEM CHUVA'::text, 'NÃO INFORMADO'::text, 'NÃO SE APLICA'::text]))) |
| dim_condicao_via | ck_dim_condicao_via_origem | CHECK | CHECK ((origem_clima = ANY (ARRAY['DECLARADO NO BOLETIM'::text, 'IMPUTADO PELO INMET'::text, 'NÃO INFORMADO'::text, 'NÃO SE APLICA'::text]))) |
| dim_condicao_via | dim_condicao_via_pkey | PK | PRIMARY KEY (sk_condicao_via) |
| dim_condicao_via | uq_dim_condicao_via | UNIQUE | UNIQUE (cod_tempo, condicao_climatica, origem_clima, cod_pavimento, local_sinalizado) |
| dim_local | ck_dim_local_vigencia | CHECK | CHECK ((dt_inicio_vigencia < dt_fim_vigencia)) |
| dim_local | dim_local_pkey | PK | PRIMARY KEY (sk_local) |
| dim_local | uq_dim_local_versao | UNIQUE | UNIQUE (chave_natural, versao) |
| dim_pessoa | dim_pessoa_pkey | PK | PRIMARY KEY (sk_pessoa) |
| dim_pessoa | uq_dim_pessoa | UNIQUE | UNIQUE (tipo_envolvimento, sexo, faixa_etaria, embriaguez) |
| dim_regional | dim_regional_pkey | PK | PRIMARY KEY (sk_regional) |
| dim_regional | uq_dim_regional_cod | UNIQUE | UNIQUE (cod_regional) |
| dim_tempo | ck_dim_tempo_hora | CHECK | CHECK (((hora IS NULL) OR ((hora >= 0) AND (hora <= 23)))) |
| dim_tempo | dim_tempo_pkey | PK | PRIMARY KEY (sk_tempo) |
| dim_tipo_sinistro | dim_tipo_sinistro_pkey | PK | PRIMARY KEY (sk_tipo_sinistro) |
| dim_tipo_sinistro | uq_dim_tipo_sinistro_cod | UNIQUE | UNIQUE (cod_tipo_sinistro) |
| dim_veiculo | dim_veiculo_pkey | PK | PRIMARY KEY (sk_veiculo) |
| dim_veiculo | uq_dim_veiculo | UNIQUE | UNIQUE (especie, categoria, situacao) |
| fato_envolvido | ck_fato_envolvido_gravidade | CHECK | CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))) |
| fato_envolvido | ck_fato_envolvido_vitima | CHECK | CHECK (((NOT fl_vitima_fatal) OR fl_vitima)) |
| fato_envolvido | fato_envolvido_sk_local_fkey | FK | FOREIGN KEY (sk_local) REFERENCES dw.dim_local(sk_local) |
| fato_envolvido | fato_envolvido_sk_pessoa_fkey | FK | FOREIGN KEY (sk_pessoa) REFERENCES dw.dim_pessoa(sk_pessoa) |
| fato_envolvido | fato_envolvido_sk_regional_fkey | FK | FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional) |
| fato_envolvido | fato_envolvido_sk_tempo_fkey | FK | FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo) |
| fato_envolvido | fato_envolvido_sk_veiculo_fkey | FK | FOREIGN KEY (sk_veiculo) REFERENCES dw.dim_veiculo(sk_veiculo) |
| fato_envolvido | pk_fato_envolvido | PK | PRIMARY KEY (numero_boletim, ano, numero_envolvido) |
| fato_populacao | fato_populacao_populacao_residente_check | CHECK | CHECK ((populacao_residente > 0)) |
| fato_populacao | fato_populacao_sk_regional_fkey | FK | FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional) |
| fato_populacao | fato_populacao_sk_tempo_fkey | FK | FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo) |
| fato_populacao | pk_fato_populacao | PK | PRIMARY KEY (sk_regional, ano) |
| fato_sinistro | ck_fato_sinistro_ups | CHECK | CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))) |
| fato_sinistro | ck_fato_sinistro_vitimas | CHECK | CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos))) |
| fato_sinistro | fato_sinistro_sk_condicao_via_fkey | FK | FOREIGN KEY (sk_condicao_via) REFERENCES dw.dim_condicao_via(sk_condicao_via) |
| fato_sinistro | fato_sinistro_sk_local_fkey | FK | FOREIGN KEY (sk_local) REFERENCES dw.dim_local(sk_local) |
| fato_sinistro | fato_sinistro_sk_regional_fkey | FK | FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional) |
| fato_sinistro | fato_sinistro_sk_tempo_fkey | FK | FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo) |
| fato_sinistro | fato_sinistro_sk_tipo_sinistro_fkey | FK | FOREIGN KEY (sk_tipo_sinistro) REFERENCES dw.dim_tipo_sinistro(sk_tipo_sinistro) |
| fato_sinistro | pk_fato_sinistro | PK | PRIMARY KEY (numero_boletim, ano) |

## Índices (dw, sem os herdados pelas partições)

Arquivo completo: `01e_indices.csv` (38 linhas)

| tabela | indice | metodo | definicao |
|---|---|---|---|
| dim_condicao_via | dim_condicao_via_pkey | btree | CREATE UNIQUE INDEX dim_condicao_via_pkey ON dw.dim_condicao_via USING btree (sk_condicao_via) |
| dim_condicao_via | uq_dim_condicao_via | btree | CREATE UNIQUE INDEX uq_dim_condicao_via ON dw.dim_condicao_via USING btree (cod_tempo, condicao_climatica, origem_clima, cod_pavimento, local_sinalizado) |
| dim_local | dim_local_pkey | btree | CREATE UNIQUE INDEX dim_local_pkey ON dw.dim_local USING btree (sk_local) |
| dim_local | gix_dim_local_geom | gist | CREATE INDEX gix_dim_local_geom ON dw.dim_local USING gist (geom) |
| dim_local | ix_dim_local_chave_vigencia | btree | CREATE INDEX ix_dim_local_chave_vigencia ON dw.dim_local USING btree (chave_natural, dt_inicio_vigencia, dt_fim_vigencia) |
| dim_local | ix_dim_local_descricao_trgm | gin | CREATE INDEX ix_dim_local_descricao_trgm ON dw.dim_local USING gin (descricao_local_atual gin_trgm_ops) |
| dim_local | uq_dim_local_versao | btree | CREATE UNIQUE INDEX uq_dim_local_versao ON dw.dim_local USING btree (chave_natural, versao) |
| dim_pessoa | dim_pessoa_pkey | btree | CREATE UNIQUE INDEX dim_pessoa_pkey ON dw.dim_pessoa USING btree (sk_pessoa) |
| dim_pessoa | uq_dim_pessoa | btree | CREATE UNIQUE INDEX uq_dim_pessoa ON dw.dim_pessoa USING btree (tipo_envolvimento, sexo, faixa_etaria, embriaguez) |
| dim_regional | dim_regional_pkey | btree | CREATE UNIQUE INDEX dim_regional_pkey ON dw.dim_regional USING btree (sk_regional) |
| dim_regional | gix_dim_regional_geom | gist | CREATE INDEX gix_dim_regional_geom ON dw.dim_regional USING gist (geom) |
| dim_regional | uq_dim_regional_cod | btree | CREATE UNIQUE INDEX uq_dim_regional_cod ON dw.dim_regional USING btree (cod_regional) |
| dim_tempo | dim_tempo_pkey | btree | CREATE UNIQUE INDEX dim_tempo_pkey ON dw.dim_tempo USING btree (sk_tempo) |
| dim_tempo | ix_dim_tempo_ano_mes | btree | CREATE INDEX ix_dim_tempo_ano_mes ON dw.dim_tempo USING btree (ano, mes) |
| dim_tempo | ix_dim_tempo_data | btree | CREATE INDEX ix_dim_tempo_data ON dw.dim_tempo USING btree (data) |
| dim_tipo_sinistro | dim_tipo_sinistro_pkey | btree | CREATE UNIQUE INDEX dim_tipo_sinistro_pkey ON dw.dim_tipo_sinistro USING btree (sk_tipo_sinistro) |
| dim_tipo_sinistro | uq_dim_tipo_sinistro_cod | btree | CREATE UNIQUE INDEX uq_dim_tipo_sinistro_cod ON dw.dim_tipo_sinistro USING btree (cod_tipo_sinistro) |
| dim_veiculo | dim_veiculo_pkey | btree | CREATE UNIQUE INDEX dim_veiculo_pkey ON dw.dim_veiculo USING btree (sk_veiculo) |
| dim_veiculo | uq_dim_veiculo | btree | CREATE UNIQUE INDEX uq_dim_veiculo ON dw.dim_veiculo USING btree (especie, categoria, situacao) |
| fato_envolvido | ix_fato_envolvido_sk_local | btree | CREATE INDEX ix_fato_envolvido_sk_local ON ONLY dw.fato_envolvido USING btree (sk_local) |
| fato_envolvido | ix_fato_envolvido_sk_pessoa | btree | CREATE INDEX ix_fato_envolvido_sk_pessoa ON ONLY dw.fato_envolvido USING btree (sk_pessoa) |
| fato_envolvido | ix_fato_envolvido_sk_regional | btree | CREATE INDEX ix_fato_envolvido_sk_regional ON ONLY dw.fato_envolvido USING btree (sk_regional) |
| fato_envolvido | ix_fato_envolvido_sk_tempo | btree | CREATE INDEX ix_fato_envolvido_sk_tempo ON ONLY dw.fato_envolvido USING btree (sk_tempo) |
| fato_envolvido | ix_fato_envolvido_sk_veiculo | btree | CREATE INDEX ix_fato_envolvido_sk_veiculo ON ONLY dw.fato_envolvido USING btree (sk_veiculo) |
| fato_envolvido | pk_fato_envolvido | btree | CREATE UNIQUE INDEX pk_fato_envolvido ON ONLY dw.fato_envolvido USING btree (numero_boletim, ano, numero_envolvido) |
| fato_populacao | ix_fato_populacao_sk_tempo | btree | CREATE INDEX ix_fato_populacao_sk_tempo ON dw.fato_populacao USING btree (sk_tempo) |
| fato_populacao | pk_fato_populacao | btree | CREATE UNIQUE INDEX pk_fato_populacao ON dw.fato_populacao USING btree (sk_regional, ano) |
| fato_sinistro | gix_fato_sinistro_geom | gist | CREATE INDEX gix_fato_sinistro_geom ON ONLY dw.fato_sinistro USING gist (geom) |
| fato_sinistro | ix_fato_sinistro_sk_condicao_via | btree | CREATE INDEX ix_fato_sinistro_sk_condicao_via ON ONLY dw.fato_sinistro USING btree (sk_condicao_via) |
| fato_sinistro | ix_fato_sinistro_sk_local | btree | CREATE INDEX ix_fato_sinistro_sk_local ON ONLY dw.fato_sinistro USING btree (sk_local) |
| fato_sinistro | ix_fato_sinistro_sk_regional | btree | CREATE INDEX ix_fato_sinistro_sk_regional ON ONLY dw.fato_sinistro USING btree (sk_regional) |
| fato_sinistro | ix_fato_sinistro_sk_tempo | btree | CREATE INDEX ix_fato_sinistro_sk_tempo ON ONLY dw.fato_sinistro USING btree (sk_tempo) |
| fato_sinistro | ix_fato_sinistro_sk_tipo_sinistro | btree | CREATE INDEX ix_fato_sinistro_sk_tipo_sinistro ON ONLY dw.fato_sinistro USING btree (sk_tipo_sinistro) |
| fato_sinistro | pk_fato_sinistro | btree | CREATE UNIQUE INDEX pk_fato_sinistro ON ONLY dw.fato_sinistro USING btree (numero_boletim, ano) |
| mv_indicadores_regional_ano | ux_mv_indicadores_regional_ano | btree | CREATE UNIQUE INDEX ux_mv_indicadores_regional_ano ON dw.mv_indicadores_regional_ano USING btree (ano, sk_regional) |
| mv_participacao_vitimas_ano | ux_mv_participacao_vitimas_ano | btree | CREATE UNIQUE INDEX ux_mv_participacao_vitimas_ano ON dw.mv_participacao_vitimas_ano USING btree (ano) |
| mv_ranking_locais | ux_mv_ranking_locais | btree | CREATE UNIQUE INDEX ux_mv_ranking_locais ON dw.mv_ranking_locais USING btree (chave_natural, ano) |
| mv_taxa_mortalidade_anual | ux_mv_taxa_mortalidade_anual | btree | CREATE UNIQUE INDEX ux_mv_taxa_mortalidade_anual ON dw.mv_taxa_mortalidade_anual USING btree (ano) |
