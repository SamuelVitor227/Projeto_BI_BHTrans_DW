# PROGRESSO — Construção do DW de sinistros de trânsito de BH

Checklist das etapas, para retomar o trabalho se a sessão for interrompida.
Legenda: `[x]` concluído e validado · `[~]` em andamento · `[ ]` pendente.

## 0. Ambiente
- [x] Diagnóstico: Docker 29.3 + Compose v5.1, Git 2.53, portas 5432/5433 livres, sem psql local
- [x] Python: 3.12 ausente; por decisão do usuário, usar o Python 3.14 existente (divergência registrada no README)
- [x] Pasta do projeto criada na Área de Trabalho
- [x] `.env` (senha aleatória), `.env.example`, `.gitignore`, `docker-compose.yml` (postgis/postgis:16-3.5)
- [x] `git init`
- [x] Container PostGIS no ar e testado (PostgreSQL 16.9, PostGIS 3.5.2; usar host 127.0.0.1 — `localhost` atrasa 10 s por tentar IPv6)
- [x] venv em `%USERPROFILE%\.venvs\bi_bhtrans` (Python 3.14.4 via uv)
- [x] `requirements.txt` com versões fixadas

## 1. Fontes (descoberta e download para RAW)
- [x] CKAN PBH: 2011–2024 em todos os conjuntos (2025 ainda não publicado); dicionários 2011–2015 e 2016
- [x] IBGE: regionais são SUBDISTRITOS (N11), não distritos; Censo 2022 tabela 9923 (N11), Censo 2010 tabela 202 (N11, limites diferentes de 2022), estimativas 6579 (sem 2010, 2022, 2023)
- [x] INMET: ZIP anual ~100 MB por ano
- [x] `python -m etl.extrair` (baixa PBH, IBGE, setores 2010 e INMET) → `dados/raw/manifesto.csv` (116 arquivos)

## 2. Inspeção dos arquivos reais
- [x] Cabeçalhos de todos os anos → `etl/mapeamentos/de_para_cabecalhos.csv` (evidência: `evidencias/inspecao_fontes/`)
- [x] Domínios → `etl/mapeamentos/dominios.csv`, `regionais.csv`, `abreviaturas_logradouro.csv`
- [x] Achados (todos vão para o README):
  - si-veic-2023 em CP850; demais Latin-1; regionais em UTF-8
  - coordenadas 2011–2015: X/100 e 7.000.000 + Y/100, datum SAD69 (EPSG:29193, desvio medido −44,6/−44,3 m ≈ pyproj −44,7/−45,1 m)
  - 13 números de boletim repetidos (2011–2013) = eventos distintos → sufixo /2
  - valor_ups = 0 a partir de 2016 → UPS derivada da severidade
  - cod_regional 27 (Hipercentro) em 2024 → Centro-Sul (polígono 100% contido); concordância boletim × espacial ≈ 90% (69% das divergências a < 50 m da divisa)
  - pedestre/passageiro só de 2016: regra derivada para 2011–2015 validada em 2016+ (precisão 99,2%, recall 92,7%)
  - cinto de segurança inconsistente entre anos → fora da dim_pessoa; embriaguez consistente desde 2016
  - regionais no IBGE são SUBDISTRITOS; limites de 2010 ≠ 2022 → população 2010 por setores agregados aos polígonos

## 3. DDL (entregável 2)
- [x] `sql/ddl_data_warehouse.sql` (stg + dw, partições, índices, comentários, MVs) — roda do zero e é re-executável
- [x] Aplicado no banco principal

## 4. ETL / carga inicial (entregável 3)
- [x] `etl/` (config, banco, leitura, extrair, staging, transformar, testes_qualidade, carregar, evidencias, carga_inicial)
- [x] `sql/carga/` numerado (10–15 transformar; 20–27 dimensões; 30–32 fatos; 40 views)
- [x] Transformação validada isoladamente (stg = trf: 184.728 boletins, 404.957 envolvidos, 333.111 veículos)
- [x] Carga completa `python -m etl.carga_inicial --recriar` em ~80 s: 184.728 sinistros, 404.957 envolvidos, 153 linhas de população; 38/39 testes (1 ALERTA de regional não resolvida)
- [x] Ajustes após revisão dos resultados: regional pelo ponto do local quando o boletim não tem coordenada; espécie do passageiro imputada quando o boletim tem espécie única (validada 100% em 2017+); formatação pt-BR nas evidências; scripts 12/13 reordenados (veículo antes de envolvido)

## 5. Evidências e documentação
- [x] Prova do DDL em banco vazio + `pg_dump --schema-only` (`evidencias/05_*`, `ddl_exportado_pg_dump.sql`)
- [x] Evidências de estrutura, contagens, qualidade (42/42) e consultas de negócio (8)
- [x] `docs/modelo_dimensional.md` (Mermaid + dicionário gerado dos COMMENT ON)
- [x] `README.md`

## 6. Testes locais finais (pedido do usuário) — `python -m etl.testes_locais`
- [x] 1ª bateria: 22/23 — a view da taxa anual ficava vazia em carga parcial sem 2014 (CROSS JOIN) → corrigido com LEFT JOIN
- [x] 2ª bateria: **23/23 aprovados** → `evidencias/06_testes_locais.md`

## 7. Auditoria contra os requisitos (13/10/2026)
- [x] Publicado no GitHub (público, a pedido do usuário): https://github.com/SamuelVitor227/Projeto_BI_BHTrans_DW
- [x] Conferência item a item no banco, no DDL e nos arquivos: tudo atendido, exceto 1 defeito
- [x] Defeito: `dim_tempo` terminava em 30/12/2030 (generate_series com DATE vira timestamptz e o horário de verão deslocava a série) → corrigido com TIMESTAMP em `sql/carga/21_dim_tempo.sql` + novo teste de cobertura (41/41 aprovados)
- [x] Portal da PBH reconferido: 2025 ainda não publicado (2011–2024)

## Situação: CONCLUÍDO (13/10/2026). Para reprocessar tudo: `python -m etl.carga_inicial --recriar`

## Notas para retomada
- Banco: `docker compose up -d` na pasta do projeto; credenciais no `.env`.

## 8. Preparação para o Power BI (13/10/2026)
- [x] Schema `bi` no DDL (seção 8): 15 views sem geometria, sem partições e sem linhagem; `dim_calendario` diária + `dim_hora`; MVs expostas como views `ind_*`; `fato_envolvido` com tipo de sinistro e condição da via do boletim
- [x] `etl/powerbi.py` (etapa 7): polígonos das regionais em `powerbi/regionais_bh.geojson` (Azure Maps) e `powerbi/regionais_bh_topojson.json` (Mapa de formas)
- [x] `powerbi/medidas.dax` (34 medidas) e `powerbi/GUIA_POWER_BI.md` (conexão, relacionamentos, ordenações, mapas, valores de conferência)
- [x] Novo teste de qualidade da camada bi (42/42) e testes locais 24/24
