# Contagens da carga — gerado em 13/10/2026 22:07

## Linhas por tabela

| schema | tabela | linhas |
|---|---|---|
| stg | ibge_localidade | 18 |
| stg | ibge_setor2010_malha | 3936 |
| stg | ibge_setor2010_variavel | 15.580 |
| stg | ibge_sidra_valor | 54 |
| stg | inmet_horario | 219.288 |
| stg | log_carga | 31 |
| stg | manifesto_raw | 116 |
| stg | map_dominio | 91 |
| stg | map_regional | 11 |
| stg | regional_limite | 19 |
| stg | resultado_qualidade | 160 |
| stg | si_bol | 184.728 |
| stg | si_env | 404.957 |
| stg | si_log | 243.588 |
| stg | si_veic | 333.111 |
| stg | trf_boletim | 184.728 |
| stg | trf_boletim_local | 184.570 |
| stg | trf_clima_hora | 219.273 |
| stg | trf_coordenada | 184.728 |
| stg | trf_envolvido | 404.957 |
| stg | trf_local_versao | 22.391 |
| stg | trf_logradouro_versao | 8848 |
| stg | trf_populacao | 153 |
| stg | trf_setor2010_regional | 3936 |
| stg | trf_veiculo | 333.111 |
| dw | dim_condicao_via | 61 |
| dw | dim_local | 22.393 |
| dw | dim_pessoa | 361 |
| dw | dim_regional | 11 |
| dw | dim_tempo | 191.727 |
| dw | dim_tipo_sinistro | 14 |
| dw | dim_veiculo | 303 |
| dw | fato_envolvido | 404.957 |
| dw | fato_populacao | 153 |
| dw | fato_sinistro | 184.728 |
| dw | mv_indicadores_regional_ano | 140 |
| dw | mv_participacao_vitimas_ano | 14 |
| dw | mv_ranking_locais | 69.744 |
| dw | mv_taxa_mortalidade_anual | 14 |

## Por ano: staging x dw, vítimas, mortos, geolocalização, clima imputado e população

| ano | stg_si_bol | fato_sinistro | stg_si_env | fato_envolvido | stg_si_veic | stg_si_log | vitimas | mortos | pct_geolocalizado | pct_clima_imputado | populacao | origem_populacao |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2010 |  |  |  |  |  |  |  |  |  |  | 2.375.151 | CENSO |
| 2011 | 16.294 | 16.294 | 36.084 | 36.084 | 28.301 | 20.540 | 20.327 | 217 | 86,6 | 33,1 | 2.385.640 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2012 | 15.261 | 15.261 | 33.745 | 33.745 | 26.660 | 19.909 | 18.900 | 181 | 86,8 | 72,9 | 2.395.785 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2013 | 14.145 | 14.145 | 32.152 | 32.152 | 25.367 | 19.446 | 17.689 | 170 | 87,2 | 95,5 | 2.479.165 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2014 | 14.965 | 14.965 | 33.588 | 33.588 | 26.840 | 20.600 | 18.477 | 177 | 84,1 | 98,5 | 2.491.109 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2015 | 13.299 | 13.299 | 29.131 | 29.131 | 23.398 | 17.644 | 16.140 | 150 | 82,9 | 99,9 | 2.502.557 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2016 | 12.477 | 12.477 | 27.216 | 27.216 | 22.212 | 16.392 | 15.062 | 135 | 89,6 | 56,8 | 2.513.451 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2017 | 12.243 | 12.243 | 26.622 | 26.622 | 22.012 | 16.072 | 14.611 | 121 | 90,6 | 56,3 | 2.523.794 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2018 | 11.656 | 11.656 | 25.524 | 25.524 | 21.133 | 15.253 | 13.987 | 113 | 89,4 | 55,4 | 2.501.576 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2019 | 13.342 | 13.342 | 28.972 | 28.972 | 24.469 | 17.576 | 15.870 | 105 | 89,1 | 53,0 | 2.512.070 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2020 | 10.624 | 10.624 | 22.643 | 22.643 | 19.494 | 14.181 | 12.657 | 113 | 90,9 | 44,2 | 2.521.564 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2021 | 11.122 | 11.122 | 23.736 | 23.736 | 20.506 | 14.437 | 13.175 | 113 | 91,4 | 53,5 | 2.530.701 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2022 | 12.148 | 12.148 | 26.094 | 26.094 | 22.310 | 15.550 | 14.495 | 131 | 92,2 | 55,8 | 2.315.560 | CENSO |
| 2023 | 13.886 | 13.886 | 30.170 | 30.170 | 25.569 | 17.418 | 16.802 | 122 | 92,3 | 49,8 | 2.365.413 | INTERPOLADO x PROPORÇÃO |
| 2024 | 13.266 | 13.266 | 29.280 | 29.280 | 24.840 | 18.570 | 15.927 | 159 | 94,7 | 53,0 | 2.416.339 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2025 |  |  |  |  |  |  |  |  |  |  | 2.415.872 | ESTIMATIVA IBGE x PROPORÇÃO |
| 2026 |  |  |  |  |  |  |  |  |  |  | 2.415.451 | ESTIMATIVA IBGE x PROPORÇÃO |

## Linhas por partição (estatística do PostgreSQL após ANALYZE)

| particao | linhas_estimadas |
|---|---|
| fato_envolvido_2011 | 36.084 |
| fato_envolvido_2012 | 33.745 |
| fato_envolvido_2013 | 32.152 |
| fato_envolvido_2014 | 33.588 |
| fato_envolvido_2015 | 29.131 |
| fato_envolvido_2016 | 27.216 |
| fato_envolvido_2017 | 26.622 |
| fato_envolvido_2018 | 25.524 |
| fato_envolvido_2019 | 28.972 |
| fato_envolvido_2020 | 22.643 |
| fato_envolvido_2021 | 23.736 |
| fato_envolvido_2022 | 26.094 |
| fato_envolvido_2023 | 30.170 |
| fato_envolvido_2024 | 29.280 |
| fato_envolvido_2025 | 0 |
| fato_envolvido_2026 | 0 |
| fato_envolvido_default | 0 |
| fato_sinistro_2011 | 16.294 |
| fato_sinistro_2012 | 15.261 |
| fato_sinistro_2013 | 14.145 |
| fato_sinistro_2014 | 14.965 |
| fato_sinistro_2015 | 13.299 |
| fato_sinistro_2016 | 12.477 |
| fato_sinistro_2017 | 12.243 |
| fato_sinistro_2018 | 11.656 |
| fato_sinistro_2019 | 13.342 |
| fato_sinistro_2020 | 10.624 |
| fato_sinistro_2021 | 11.122 |
| fato_sinistro_2022 | 12.148 |
| fato_sinistro_2023 | 13.886 |
| fato_sinistro_2024 | 13.266 |
| fato_sinistro_2025 | 0 |
| fato_sinistro_2026 | 0 |
| fato_sinistro_default | 0 |
