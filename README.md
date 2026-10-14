# Data Warehouse de sinistros de trânsito de Belo Horizonte

Projeto de Business Intelligence — PUC Minas · Fase 3: construção do Data Warehouse.

O DW apoia a gestão de segurança viária de Belo Horizonte (BHTrans/PBH), cuja meta é **reduzir em 50% a taxa de mortos no trânsito por 100 mil habitantes até 2030, com 2014 como base**, priorizando pedestres e motociclistas. Ele integra os boletins de sinistros com vítima da PBH (2011–2024), a população do IBGE e a precipitação horária do INMET num modelo estrela no PostgreSQL 16 + PostGIS.

**Entregáveis**

| # | Entregável | Onde |
|---|---|---|
| 1 | Estrutura completa do DW num SGBD relacional, rodando localmente | PostgreSQL 16.9 + PostGIS 3.5 (Docker), banco `dw_sinistros_bh`, schemas `stg` e `dw` — ver `evidencias/01_estrutura_dw.md` |
| 2 | Script DDL único | [`sql/ddl_data_warehouse.sql`](sql/ddl_data_warehouse.sql) — prova em banco vazio: `evidencias/05_prova_ddl_banco_vazio.txt`; exportação: `evidencias/ddl_exportado_pg_dump.sql` |
| 3 | Carga inicial completa, com evidências | `python -m etl.carga_inicial` — contagens, qualidade e consultas em `evidencias/` |

**Resultado da carga inicial (13/10/2026)**

| Indicador | Valor |
|---|---|
| Anos carregados | 2011–2024 (14 anos; 2025 ainda não publicado pela PBH) |
| Boletins (fato_sinistro) | 184.728 — igual ao stg em todos os anos |
| Pessoas envolvidas (fato_envolvido) | 404.957, das quais 224.119 vítimas e 2.007 mortos |
| Veículos | 333.111 (contagens por espécie na fato_sinistro) |
| Locais (dim_local) | 22.100 locais, 22.391 versões SCD2 (286 com renomeação) |
| População (fato_populacao) | 9 regionais × 17 anos (2010–2026), somando o total do município em todos os anos |
| % geolocalizado | 88,94% (82,9% em 2015 a 94,7% em 2024) |
| % clima imputado pelo INMET | 63,29% (sobram 0,10% sem clima) |
| % UPS derivada da severidade | 59,87% (a fonte traz UPS = 0 a partir de 2016) |
| % regional não resolvida | 0,61% |
| Testes de qualidade + reconciliação | 40 de 40 aprovados (`evidencias/03_relatorio_qualidade.md`) |
| Testes locais de ponta a ponta | 23 de 23 aprovados (`evidencias/06_testes_locais.md`) |
| Tempo da carga completa | ~80 s (com a camada RAW já baixada; o primeiro download, com os ZIPs do INMET, leva ~3 min) |

---

## 1. Como executar

### Pré-requisitos
- Docker Desktop (testado com 29.3 / Compose v5.1).
- Python 3.12 ou superior. **Este ambiente usa Python 3.14.4**: a Fase 2 previa 3.12, mas a máquina só tinha 3.14 e optou-se por não instalar outra versão. O código não depende de nada específico do 3.14.
- Git (opcional).

### Subir o banco
```powershell
cd "$([Environment]::GetFolderPath('Desktop'))\Projeto_BI_BHTrans_DW"
copy .env.example .env        # e defina POSTGRES_PASSWORD (o .env real não é versionado)
docker compose up -d          # PostgreSQL 16 + PostGIS 3.5, volume nomeado, porta 127.0.0.1:5432
```
A imagem é `postgis/postgis:16-3.5`. A tag `16-3.4` existe, mas está congelada desde out/2024; a `16-3.5` continua sendo atualizada e é a mesma versão maior do PostgreSQL. Os dados ficam no volume nomeado `bi_bhtrans_dw_pgdata_bi_bhtrans`: não há bind mount da pasta do projeto, que está no OneDrive.

### Ambiente Python (fora do OneDrive)
```powershell
python -m venv $env:USERPROFILE\.venvs\bi_bhtrans
& $env:USERPROFILE\.venvs\bi_bhtrans\Scripts\python -m pip install -r requirements.txt
```

### Carga inicial completa (refaz tudo do zero)
```powershell
& $env:USERPROFILE\.venvs\bi_bhtrans\Scripts\python -m etl.carga_inicial --recriar
```
Opções: `--anos 2019-2024` (limita os anos; útil para testes), `--forcar-download` (baixa de novo mesmo sem mudança na origem), `--sem-download` (usa só a camada RAW existente), `--recriar` (apaga e recria os schemas `stg` e `dw` antes). Sem `--recriar`, o DDL é aplicado com `IF NOT EXISTS` e as tabelas são esvaziadas e recarregadas, então a execução é idempotente.

A carga roda em 7 etapas, cada uma registrada em `stg.log_carga` e organizada para virar uma task de DAG no Airflow:

| Etapa | Módulo | O que faz |
|---|---|---|
| 1. extrair | `etl/extrair.py` | Baixa as fontes para `dados/raw/<fonte>/` sem alterar os arquivos e registra URL, SHA-256, tamanho e data de coleta em `dados/raw/manifesto.csv`. Não baixa de novo se nada mudou: compara a data de modificação do portal e o hash local. |
| 2. staging | `etl/staging.py` | Carrega os espelhos no schema `stg` via `COPY`, tudo como texto, com cabeçalhos harmonizados pelo de-para e as colunas de linhagem `ano_arquivo`, `arquivo_origem`, `linha_arquivo` e `dt_carga`. |
| 3. transformar | `etl/transformar.py` + `sql/carga/1x_*.sql` | Tipagem, deduplicação, reprojeção (pyproj), clima (INMET, UTC → local), população por regional e SCD2 de locais → `stg.trf_*`. |
| 4. testes | `etl/testes_qualidade.py` | Testes de unicidade, domínio, volume, órfãos, coerência e cobertura. Falha **CRÍTICA** interrompe a carga antes do `dw`. |
| 5. carregar | `etl/carregar.py` + `sql/carga/2x–4x_*.sql` | Carrega dimensões, depois fatos, e dá `REFRESH` nas views materializadas, tudo numa única transação. |
| 6. reconciliar | `etl/testes_qualidade.py` | Compara contagens stg × dw por ano, vítimas e mortos entre as duas fatos, soma da população das regionais = município, e vigências do SCD2. |
| 7. evidências | `etl/evidencias.py` | Gera `evidencias/*`, `docs/modelo_dimensional.md`, a prova do DDL em banco vazio e o `pg_dump --schema-only`. |

Os scripts SQL de transformação e carga (somente DML) ficam em `sql/carga/`, numerados na ordem de execução.

### Testes locais (verificar se está tudo funcionando)
```powershell
& $env:USERPROFILE\.venvs\bi_bhtrans\Scripts\python -m etl.testes_locais
```
O script roda a carga 4 vezes (~6 min) e confere:
- a carga do zero com `--recriar` e as 8 etapas no `stg.log_carga`;
- a idempotência: a 2ª execução não baixa nada, mantém os hashes da RAW e gera um dw idêntico (md5 das fatos, da dim_local e da taxa anual);
- a opção `--anos`;
- que um teste crítico reprovado interrompe a carga e que um dado corrompido é detectado;
- que o DDL não tem DML e que os scripts de carga não têm DDL;
- a prova do DDL em banco vazio, o `pg_dump`, os comentários em todas as colunas, as consultas de negócio e as evidências.

O resultado fica em `evidencias/06_testes_locais.md`. A inspeção das fontes que embasou os de-paras pode ser refeita com `python -m etl.inspecionar_fontes` (resultado em `evidencias/inspecao_fontes/`).

### Conectar no DBeaver / pgAdmin
| Campo | Valor |
|---|---|
| Host | `127.0.0.1` (prefira a `localhost`: no Windows, `localhost` tenta IPv6 primeiro e demora ~10 s) |
| Porta | `5432` |
| Banco | `dw_sinistros_bh` |
| Usuário / senha | `POSTGRES_USER` / `POSTGRES_PASSWORD` do arquivo `.env` |

No DBeaver: *Nova conexão → PostgreSQL*, preencha os campos acima e, em *PostgreSQL*, marque "Show all databases" se quiser. As geometrias (`geom`) aparecem na aba *Spatial*. No pgAdmin: *Register → Server*, aba *Connection*, com os mesmos dados.

---

## 2. Estrutura do projeto
```
Projeto_BI_BHTrans_DW/
  README.md · PROGRESSO.md · docker-compose.yml · requirements.txt · .env.example · .gitignore
  sql/ddl_data_warehouse.sql      entregável 2 (somente DDL)
  sql/carga/                      DML de transformação e carga, numerado (10–15 transformar, 20–40 carregar)
  sql/consultas_validacao.sql     consultas de negócio da Fase 1
  etl/                            config, banco, leitura, extrair, staging, transformar, testes_qualidade,
                                  carregar, evidencias, carga_inicial, inspecionar_fontes, testes_locais
  etl/mapeamentos/                de-paras versionados (cabeçalhos, domínios, regionais, abreviaturas)
  dados/raw/<fonte>/              camada RAW (fora do Git) + dados/raw/manifesto.csv (versionado)
  evidencias/                     estrutura, contagens, qualidade, consultas, prova do DDL, pg_dump, log
  docs/modelo_dimensional.md      diagrama Mermaid e dicionário de dados do dw
```

---

## 3. Fontes de dados e licenças

| Fonte | Conjunto | Uso | Licença |
|---|---|---|---|
| PBH/BHTrans — CKAN (`ckan.pbh.gov.br`, mesmo backend de `dados.pbh.gov.br`) | `relacao-de-ocorrencias-de-acidentes-de-transito-com-vitima` (si-bol), `...-logradouros-...` (si-log), `...-veiculos-...` (si-veic), `...-pessoas-envolvidas-...` (si_env) | sinistros 2011–2024 (2025 ainda não publicado em 13/10/2026) + dicionários de dados | Open Data Commons Open Database License (ODbL) |
| PBH — CKAN | `regiao-administrativa`: recurso `20220601_regional` ("Limite de Regional vigente até janeiro de 2025"); `20250204_regional` guardado só para referência | dim_regional | Creative Commons Atribuição |
| IBGE — API de agregados (SIDRA) | tabela 6579 (estimativas, var. 9324), 202 (Censo 2010, var. 93), 9923 (Censo 2022, var. 93) | população | dados públicos do IBGE (uso livre com citação da fonte) |
| IBGE — API de localidades | distritos e subdistritos de 3106200 | de-para regional × IBGE | idem |
| IBGE — FTP/geoftp | setores censitários 2010 de MG: malha `31SEE250GC_SIR` e agregados (`Pessoa13`, `Basico`, `Domicilio02`) | população de 2010 nos limites atuais | idem |
| INMET — dados históricos | ZIP anual `portal.inmet.gov.br/uploads/dadoshistoricos/<ano>.zip`; guardados só os CSVs de A521 Pampulha e F501 Cercadinho | precipitação horária | dados públicos do INMET (citar a fonte) |

O manifesto da camada RAW (`dados/raw/manifesto.csv`) registra, para cada arquivo: fonte, conjunto, recurso, ano, URL, caminho, SHA-256, bytes, data/hora da coleta, data de modificação na origem e, nos arquivos extraídos de ZIP, o SHA-256 e o tamanho do ZIP (que é apagado).

---

## 4. Decisões de modelagem e divergências em relação à Fase 2

### 4.1 Modelo
O modelo estrela tem 3 fatos e 7 dimensões, com os nomes da Fase 2 (diagrama e dicionário em [`docs/modelo_dimensional.md`](docs/modelo_dimensional.md)):

- **fato_sinistro** — grão: um boletim (`numero_boletim` + `ano`). Tem as contagens de envolvidos, vítimas, mortos e veículos (inclusive por espécie), UPS, velocidade (não aditiva), precipitação do INMET, flags e o **ponto exato** (lat/long/geom) para o mapa de calor.
- **fato_envolvido** — grão: uma pessoa envolvida (`numero_boletim` + `ano` + número do envolvido).
- **fato_populacao** — grão: regional × ano (1º de julho, membro "Sem hora" da dim_tempo).
- **Dimensões:** dim_tempo (data + hora, `AAAAMMDDHH`, com um membro "Sem hora" `AAAAMMDD99` por dia), dim_local (SCD Tipo 2), dim_tipo_sinistro, dim_condicao_via (junk), dim_veiculo (perfil), dim_pessoa (perfil) e dim_regional. Todas têm chaves substitutas inteiras e os membros `-1` "Não informado" e `-2` "Não se aplica"; nenhuma FK fica nula.
- **Física:** as fatos são particionadas por ano (2011–2026 + `DEFAULT`, com a PK incluindo `ano`). Há FKs declaradas, B-tree em todas as FKs, GiST nas geometrias, `COMMENT ON` em todas as tabelas e colunas, e 4 views materializadas criadas `WITH NO DATA` e atualizadas na carga.

### 4.2 Divergências e correções em relação à Fase 2

| Tema | Fase 2 | O que foi feito e por quê |
|---|---|---|
| **si-pess × si_env** | A tabela de pessoas foi chamada de "si-pess". | No portal, os arquivos se chamam `si_env-AAAA.csv` (conjunto "pessoas envolvidas"). O DW usa o nome real (`stg.si_env`); a equivalência fica registrada aqui e no `COMMENT` da tabela. |
| **Grão de veículo e pessoa** | O diagrama desenha as 7 dimensões em volta da FATO_SINISTRO. | Corrigido: dim_pessoa e dim_veiculo têm grão de pessoa/veículo e não cabem num fato com grão de boletim (ligá-las ali duplicaria os sinistros). Elas se ligam à **fato_envolvido**. O perfil da frota por local é respondido na fato_sinistro por **contagens por espécie** (motocicletas, automóveis, ônibus, caminhões, bicicletas, outros), sem quebrar o grão. |
| **Regional na fato_envolvido** | Não prevista. | Acrescentada como **dimensão conformada**, para calcular vítimas por regional e por 100 mil habitantes direto na fato de pessoas. |
| **Ponto exato na fato_sinistro** | A geometria ficaria só na dim_local. | A fato_sinistro guarda latitude, longitude e `geom` do ponto do boletim (mapa de calor). A dim_local tem um ponto **representativo** do local: o sinistro mais próximo do centroide. |
| **9 × 10 regionais** | 9 regionais. | Desde fev/2025 a PBH tem 10 regionais (com Hipercentro). O DW usa as **9 vigentes até jan/2025**, compatíveis com a série e com o Censo 2022. O si-bol de 2024 já traz o código 27 (HIPERCENTRO) em 655 boletins; como o polígono do Hipercentro está **100% contido na Centro-Sul de 2022** (2,206 km²), o código 27 vira Centro-Sul. |
| **Ligação pessoa → veículo** | — | O si_env não traz o sequencial do veículo, só a espécie. Se o boletim tem exatamente um veículo da espécie da pessoa, ela herda categoria e situação dele; senão, usa-se o perfil da espécie com categoria/situação "NÃO IDENTIFICADA". Pedestre usa `-2` "Não se aplica (pedestre)". |
| **Distritos do IBGE** | "As regionais aparecem como distritos". | Na API de localidades, BH tem **3 distritos** (Belo Horizonte, Barreiro, Venda Nova). As regionais aparecem como **subdistritos** (nível N11), algumas repartidas entre distritos (ex.: Oeste tem 712 moradores no distrito Barreiro). Usou-se o N11. |
| **Python** | 3.12 | 3.14.4, por decisão do usuário (não instalar outra versão). |

### 4.3 Achados nos dados reais e como foram tratados
Os de-paras foram construídos a partir da inspeção de **todos** os arquivos (cabeçalhos e valores distintos por ano) e estão em `evidencias/inspecao_fontes/`:

1. **Cabeçalhos:** cada coluna tem até duas grafias (layouts 2011–2015 × 2016+), mais exceções: `nome_logradoro_anterior` (erro de digitação) aparece em 2011–2018 e 2021–2024, e a grafia correta só em 2019–2020; `num_boletim`/`Nº_boletim` se alternam no si_env (2018 e 2021+ usam `Nº_`); o si_env de 2015 tem `indicador_pedestre`, `indicador_passageiro`, `indicador_usa_capacete` e uma coluna vazia no fim. De-para em `etl/mapeamentos/de_para_cabecalhos.csv`. Um cabeçalho novo sem de-para interrompe o staging com mensagem clara.
2. **Codificação:** todos os CSVs estão em Latin-1, **exceto `si-veic-2023.csv`, que está em CP850** (lido em Latin-1 apareceria `N§_boletim` e `NÇO SE APLICA`). A codificação é detectada arquivo a arquivo. Os limites das regionais estão em UTF-8 (o de 2022 com separador `,` e o de 2025 com `;`).
3. **Coordenadas de 2011–2015 em outro formato e outro datum.** Os valores vêm como `0060643717.00` / `0081070137.00`, ou seja, **X × 100 e (Y − 7.000.000) × 100**. Além disso, o dicionário 2011–2015 informa **SAD 69 / UTM 23S**, e o de 2016, SIRGAS 2000. Comparando os mesmos endereços (logradouro + número) entre 2011–2015 e 2016+, o deslocamento mediano é **dx = −44,6 m, dy = −44,3 m** (zero pares idênticos), contra 0,0 m no controle 2016–19 × 2020–24. O pyproj reproduz o deslocamento com EPSG:29193 → 31983 (−44,7 / −45,1 m). Por isso: 2011–2015 = escala corrigida + EPSG:29193; 2016+ = EPSG:31983; ambos vão para EPSG:4326. Um teste de qualidade confere que, depois da correção, o deslocamento mediano fica abaixo de 5 m. Não há X/Y trocados nem vírgula decimal mal lida (o código detecta os dois casos).
4. **Números de boletim repetidos:** 13 números se repetem no mesmo ano (2011–2013) com data/hora e tipo diferentes, ou seja, são **eventos distintos** e não duplicatas, e os filhos (si_env, si-veic, si-log) também se repetem. Ficaram os dois eventos: o segundo recebe o sufixo `/2`, e os filhos são ligados também pela data/hora. A deduplicação por (`numero_boletim`, `ano`) continua valendo para duplicatas exatas (mesmo número, ano e data/hora), que não ocorreram. A numeração mudou durante 2016 (`596171` → `2016-000009920-001`); 365 números antigos se repetem entre anos, o que confirma a chave composta.
5. **UPS:** o domínio documentado é 1/5/13, mas a partir de 2016 a fonte traz `0 = NÃO INFORMADO` (o valor 1, "sem vítima", nunca aparece, porque todos os boletins são com vítima). A `valor_ups` da fato usa a UPS da fonte quando informada; caso contrário, é **derivada da severidade** (13 se houve morte no si_env, 5 se não), com `fl_ups_imputada = true`. `valor_ups_antiga`, `descricao_ups_antiga` e `data_alteracao_smsa` ficam preservadas no stg.
6. **Tipo de envolvimento (pedestre/passageiro):** os indicadores só existem de 2016 em diante (2015 vem todo "NÃO INFORMADO"). Para 2011–2015 e para as lacunas, aplica-se a regra **"não condutor, sem espécie de veículo e boletim de atropelamento de pessoa (H06001/H06002) = pedestre; demais não condutores = passageiro"**. Validada nos dados de 2016+ contra os indicadores: **precisão 99,2% e recall 92,7%** para pedestres. A regra simples "não condutor sem veículo = pedestre" classificaria 4.396 passageiros como pedestres. A origem fica em `origem_tipo_envolvimento` na fato_envolvido.
7. **Vítima:** severidade 1 (não fatal) ou 2 (fatal). O envolvido ileso (3) e o não informado (0) não são vítimas.
8. **Clima declarado:** `cod_tempo = 0` (não informado) em 63% dos boletins, e em quase 100% de 2013–2015. Nesses casos o clima é imputado pela precipitação do INMET na hora do sinistro.
9. **`local_sinalizado`:** vem 100% "NÃO" a partir de 2016, o que parece valor padrão do sistema. Foi mantido, mas não deve ser usado em análise.
10. **Cinto de segurança:** o domínio é estável (SIM/NÃO/NÃO INFORMADO), mas o padrão se inverte entre anos (2016: 78% "NÃO"; 2017–2021: ~82% "SIM"; 2022+: ~75% "NÃO"), sinal de valor padrão do sistema. Por isso **ficou fora da dim_pessoa** e está preservado no stg. A **embriaguez** é coerente a partir de 2016 e entrou (2011–2015 ficam "NÃO INFORMADO").
11. **Idade:** a idade 0 aparece em 7,4% dos envolvidos, quase sempre junto com sexo e severidade não informados, e foi tratada como "Não informada". Idades acima de 110 também. Faixas: 0–9, 10–17, 18–24, 25–29, 30–39, 40–49, 50–59, 60–69, 70+.
12. **Municípios no si-log:** 100% dos registros têm `nome_municipio = BELO HORIZONTE` (código 1). Não há boletins de fora de BH para tratar.
13. **Sequência de logradouros:** a seq 1 é o principal (66% têm número de imóvel; nas demais, 2%), a seq 2 é o cruzamento, e as seq 3+ (5.949 registros, quase todos de 2011–2015) são referências extras não usadas no local. Em 21 boletins sem seq 1, usa-se a menor sequência disponível.
14. **Velocidade permitida:** 0 = não informada (97% dos boletins). Valores fora de 10–120 km/h (ex.: 6 e 700) viram nulos.
15. **Regional do boletim × posição do ponto:** concordam em 87,9% dos boletins geolocalizados (~90% de 2016 em diante). Das divergências, 69% estão a menos de 50 m da regional informada: são sinistros em avenidas que servem de divisa entre regionais. Por isso usa-se o `cod_regional` do boletim. O ST_Within contra a dim_regional só resolve os 4.533 boletins com regional 0: primeiro pelo ponto do boletim e, quando ele não tem coordenada, pelo ponto representativo do local. A origem fica em `fato_sinistro.origem_regional`.
16. **Espécie do veículo da pessoa:** até 2016 os passageiros vêm sem espécie (~4–5 mil por ano), o que subestimaria os motociclistas nesses anos. Quando o boletim tem **uma única espécie de veículo**, ela é atribuída à pessoa. A regra foi validada em 2017+ com 100% de acerto (11.605 passageiros com espécie informada). A origem fica em `fato_envolvido.origem_especie_veiculo`. Em boletins com várias espécies, a espécie continua desconhecida.

### 4.4 dim_local (SCD Tipo 2)
- **Grão:** logradouro principal + logradouro de cruzamento (quando houver) + bairro. **Chave natural pelos códigos** (`numero_logradouro` é o código do logradouro no cadastro da PBH: o mesmo código mantém o endereço mesmo quando o nome muda). Nos cruzamentos, o par de códigos é ordenado, para que "A x B" e "B x A" sejam o mesmo local; a descrição usa a orientação mais frequente.
- **Bairro:** quando vem 0 (frequente em 2012–2015), é imputado pela moda do mesmo cruzamento, do mesmo endereço ou do logradouro (se ele tem um único bairro). A origem fica em `stg.trf_boletim_local.origem_bairro`. O nome do bairro é o mais recente normalizado (tipo 1): as mudanças de nome de bairro observadas são de padronização cadastral ("PRIMEIRA SECAO" → "I").
- **Normalização dos nomes:** maiúsculas, sem acento, sem pontuação, abreviaturas com ponto expandidas (`etl/mapeamentos/abreviaturas_logradouro.csv`). O cadastro da PBH já usa nomes por extenso, então a expansão quase não age. Variações de grafia do mesmo código são consolidadas por similaridade (rapidfuzz ≥ 90 sem artigo inicial, ou um nome que contém todas as palavras do outro), como CONTORNO / DO CONTORNO, DONA CARMEM / DONA CARMEN e CASTELO BRANCO / PRESIDENTE CASTELO BRANCO.
- **Versões:** uma nova versão começa quando o **nome dominante do ano** muda para um nome ainda não usado (a volta a um nome antigo é tratada como ruído). A vigência começa no primeiro registro do novo nome. O campo `nome_logradouro_anterior` é usado para **confirmar** a renomeação (`fl_renomeacao_confirmada`), mas não para abri-la: ele vem vazio em 2012–2014 e em 2024 e, nos demais anos, muitas vezes aponta denominações de décadas atrás. Exemplos: PRESIDENTE CASTELO BRANCO → DONA HELENA GRECO (2013, confirmada); MG VINTE → CAMILO TEIXEIRA DA COSTA (2015); PIO DOZE → PIO XII (2021, confirmada).
- Cada versão guarda `dt_inicio_vigencia`, `dt_fim_vigencia` (exclusivo; 9999-12-31 na atual), `fl_versao_atual`, os nomes da versão, o nome anterior e também os **nomes atuais** (`descricao_local_atual`), para que o ranking histórico não se quebre. A fato aponta para a versão vigente na data do sinistro, e um teste confere isso em todos os sinistros.

### 4.5 Clima (INMET)
- A hora do INMET vem em UTC e marca o **fim** do intervalo de uma hora. Ela é convertida para `America/Sao_Paulo` com `zoneinfo`, que trata o horário de verão vigente até 2019, e o sinistro das 21h35 recebe a leitura que cobre 21h00–22h00 local.
- A estação principal é a A521 (Pampulha). A F501 (Cercadinho, desde 27/12/2013) é a reserva quando falta leitura; a estação usada fica em `fato_sinistro.estacao_inmet`.
- Na `dim_condicao_via`, `origem_clima` vale DECLARADO NO BOLETIM, IMPUTADO PELO INMET ou NÃO INFORMADO, e `grupo_chuva` (COM CHUVA / SEM CHUVA / NÃO INFORMADO) torna declarado e imputado comparáveis. Chuva imputada = precipitação > 0 mm na hora (resolução do pluviômetro: 0,2 mm).

### 4.6 População
- **Município:** Censo 2010 (2.375.151), estimativas IBGE de 1º/jul 2011–2021 (tabela 6579, confirmada pelos metadados), Censo 2022 (2.315.560), estimativas 2024–2026. **2023 não tem estimativa** e foi interpolado geometricamente entre 2022 e 2024 (2.365.413). A origem de cada valor fica em `fato_populacao.origem_total_municipio` e `origem_dado`.
- **Regionais:** população da regional no ano = participação da regional × população do município, com **arredondamento pelo maior resto** para fechar exatamente no total (um teste confere todos os anos).
  - 2022: Censo, subdistritos do IBGE (SIDRA 9923, N11) agregados por regional.
  - 2020 em diante: participação do Censo 2022 (mesma lógica da Nota Técnica SUPTEC/SMSA nº 1/2026).
  - 2010: os **subdistritos do IBGE de 2010 têm limites diferentes** dos de 2022 (Noroeste: 331 mil em 2010 × 234 mil em 2022; Pampulha: 187 mil × 248 mil). Por isso os **3.936 setores censitários de 2010** foram alocados aos polígonos das regionais no PostGIS (ponto interior do setor), o que dá a população de 2010 nos limites atuais (soma exata de 2.375.151; Noroeste 267 mil, Pampulha 226 mil).
  - 2011–2019: participações interpoladas linearmente entre 2010 (setores) e 2022.
- **Conferência com a imprensa (Censo 2022):** 6 das 9 regionais batem exatamente. A Oeste tem +712 (o subdistrito Oeste dentro do distrito Barreiro, que a imprensa não somou), e Centro-Sul e Leste trocam 247 pessoas entre si. A soma do IBGE fecha em 2.315.560; a da imprensa, em 2.314.848.

---

## 5. Limitações
1. **Quebras de nível na população.** As estimativas 2011–2021 foram feitas antes do Censo 2022 (2021: 2.530.701 × Censo 2022: 2.315.560, −8,5%), e as estimativas de 2024+ incorporam ajustes do IBGE (2024: 2.416.339, +4,4% sobre o Censo). Por isso a taxa por 100 mil tem degraus metodológicos em 2022 e em 2024 que não são variação real. Mantido o IBGE como série principal (Fase 2), com a origem de cada valor registrada.
2. **População por regional** é estimada (participação × total), exceto em 2010 e 2022. Os setores de 2010 foram alocados pelo ponto interior, sem ponderação por área.
3. **Clima imputado:** a precipitação de uma estação (Pampulha) representa a cidade toda; chuva localizada pode não ser captada. Em 2013–2015 quase todo o clima é imputado. Há também um **viés de preenchimento**: boletins com clima *declarado* têm ~3× mais mortos por mil sinistros do que os de clima *imputado*, chovendo ou não (o tempo é registrado com mais frequência em sinistros graves). Por isso, compare "com chuva × sem chuva" **dentro da mesma `origem_clima`**, nunca misturando as duas.
4. **Mortos** são as vítimas fatais registradas nos boletins (si_env), já com as revisões da SMSA. Podem diferir das estatísticas de mortalidade do SIM/DATASUS, que contam óbitos até 30 dias.
5. **Tipo de envolvimento em 2011–2015** é derivado (recall de 92,7% para pedestres). Há uma pequena descontinuidade metodológica em 2016 na participação de pedestres. Também a **participação de motociclistas em 2011–2016 está subestimada**: passageiros sem espécie em boletins com mais de uma espécie de veículo não podem ser classificados (ver item 16 da seção 4.3).
6. **UPS a partir de 2016** é derivada da severidade, e não informada pela fonte.
7. **Regional:** usa-se a do boletim, que concorda com a posição do ponto em 87,9% dos casos (as divergências são majoritariamente em vias-divisa). Uma pequena parcela de boletins sem regional, sem coordenada e sem ponto de local fica como "NÃO INFORMADA" (`sk_regional = -1`).
8. **dim_local:** bairros não informados foram imputados (moda), e ~1% dos boletins ficam com bairro "NÃO INFORMADO". Locais sem cruzamento são trechos de logradouro dentro de um bairro, e avenidas longas aparecem em vários trechos.
9. **`local_sinalizado` e cinto de segurança** não são confiáveis (valores padrão do sistema) e não devem ser analisados.
10. **Coordenadas:** 5% a 13% dos boletins por ano não têm coordenada (zeradas). Ficam com `fl_geolocalizado = false` e não são descartados.
11. A carga é **inicial e completa** (truncate + reload, com chaves reprodutíveis). A manutenção incremental do SCD2 fica para a fase com Airflow.

---

## 6. Evidências (pasta `evidencias/`)
| Arquivo | Conteúdo |
|---|---|
| `01_estrutura_dw.md` + `01a`–`01f_*.csv` | schemas, tabelas, partições, constraints (PK/FK/UNIQUE/CHECK), índices e dicionário de todas as colunas com comentários |
| `02_contagens.md` + CSVs | linhas por tabela, por partição e por ano (stg × dw), vítimas, mortos, % geolocalizado, % clima imputado e população |
| `03_relatorio_qualidade.md` | resultado de todos os testes de qualidade e da reconciliação |
| `04_consultas_negocio.md` | consultas de `sql/consultas_validacao.sql` (taxa × meta 2030, regionais por risco, top 10 locais e cruzamentos, pedestres e motociclistas, tipos mais letais, clima × severidade, dia × período) com resultados |
| `05_prova_ddl_banco_vazio.txt` | o DDL rodado com `psql -v ON_ERROR_STOP=1` num banco temporário vazio, duas vezes (re-execução), comparado com o banco principal e apagado em seguida |
| `06_testes_locais.md` | os 23 testes locais de ponta a ponta (`python -m etl.testes_locais`) |
| `ddl_exportado_pg_dump.sql` | `pg_dump --schema-only` do banco principal |
| `log_carga_inicial.txt` | log completo da última execução |
| `inspecao_fontes/` | codificação, cabeçalhos por ano e domínios de todos os arquivos (base dos de-paras) |
