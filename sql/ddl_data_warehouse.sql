/*
===============================================================================
 Projeto ....: Data Warehouse de Sinistros de Trânsito de Belo Horizonte
               (gestão de segurança viária — BHTrans / PBH)
 Disciplina .: Business Intelligence — PUC Minas (Fase 3: construção do DW)
 SGBD .......: PostgreSQL 16 + PostGIS 3.5 (imagem Docker postgis/postgis:16-3.5)
 Banco ......: dw_sinistros_bh
 Data .......: 13/10/2026
 Conteúdo ...: SOMENTE DDL — extensões, schemas stg e dw, tabelas, partições,
               constraints, índices, comentários e views materializadas.
               Nenhum INSERT: as cargas ficam em sql/carga/ e no ETL Python.

 Como executar (a partir da pasta do projeto):
   a) pelo ETL:   python -m etl.carga_inicial          (aplica este DDL e carrega tudo)
   b) só o DDL:   docker exec -i bi_bhtrans_postgis psql -U bi_bhtrans -d dw_sinistros_bh
                       -v ON_ERROR_STOP=1 < sql/ddl_data_warehouse.sql
 O script é re-executável: todos os objetos usam IF NOT EXISTS. Para recriar
 do zero, descomente o bloco de RESET abaixo (apaga os dados dos dois schemas).
===============================================================================
*/

-- ---------------------------------------------------------------------------
-- RESET (opcional) — descomente para apagar e recriar toda a estrutura
-- ---------------------------------------------------------------------------
-- DROP SCHEMA IF EXISTS dw  CASCADE;
-- DROP SCHEMA IF EXISTS stg CASCADE;

SET client_min_messages = warning;

-- ===========================================================================
-- 0. EXTENSÕES E SCHEMAS
-- ===========================================================================
CREATE EXTENSION IF NOT EXISTS postgis;   -- tipos e funções geográficas
CREATE EXTENSION IF NOT EXISTS unaccent;  -- remoção de acentos na normalização de nomes
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- similaridade de texto (trigramas)

CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;

COMMENT ON SCHEMA stg IS 'Staging: espelho das fontes (tudo como texto, sem regra de negócio), tabelas de trabalho da transformação, log de carga e resultados dos testes de qualidade.';
COMMENT ON SCHEMA dw  IS 'Data Warehouse: modelo estrela (3 fatos e 7 dimensões) e views materializadas de indicadores.';

-- ===========================================================================
-- 1. SCHEMA STG — ESPELHOS DAS FONTES
--    Colunas de dados como TEXT, exatamente como vieram (cabeçalhos
--    harmonizados pelo de-para etl/mapeamentos/de_para_cabecalhos.csv).
--    Linhagem em todas as tabelas: arquivo_origem, linha_arquivo, dt_carga.
-- ===========================================================================

-- 1.1 Manifesto da camada RAW ------------------------------------------------
CREATE TABLE IF NOT EXISTS stg.manifesto_raw (
    fonte                 text NOT NULL,
    conjunto              text NOT NULL,
    recurso               text,
    recurso_id            text,
    ano                   text,
    url                   text,
    arquivo               text NOT NULL,
    sha256                text,
    bytes                 text,
    dt_coleta             text,
    modificado_na_origem  text,
    sha256_pacote         text,
    bytes_pacote          text,
    observacao            text,
    arquivo_origem        text NOT NULL,
    linha_arquivo         integer NOT NULL,
    dt_carga              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_manifesto_raw PRIMARY KEY (arquivo)
);
COMMENT ON TABLE  stg.manifesto_raw IS 'Espelho de dados/raw/manifesto.csv: um registro por arquivo guardado na camada RAW (origem, hash e data de coleta).';
COMMENT ON COLUMN stg.manifesto_raw.fonte IS 'Fonte do arquivo (pbh_ckan, ibge, ibge_setores_2010, inmet).';
COMMENT ON COLUMN stg.manifesto_raw.conjunto IS 'Conjunto lógico (si_bol, si_log, si_veic, si_env, regional, estimativas, censo_2022...).';
COMMENT ON COLUMN stg.manifesto_raw.recurso IS 'Nome do recurso na origem.';
COMMENT ON COLUMN stg.manifesto_raw.recurso_id IS 'Identificador do recurso no CKAN da PBH.';
COMMENT ON COLUMN stg.manifesto_raw.ano IS 'Ano de referência do arquivo, quando houver.';
COMMENT ON COLUMN stg.manifesto_raw.url IS 'URL de download (para arquivos extraídos de ZIP, a URL do ZIP).';
COMMENT ON COLUMN stg.manifesto_raw.arquivo IS 'Caminho do arquivo dentro de dados/raw/.';
COMMENT ON COLUMN stg.manifesto_raw.sha256 IS 'Hash SHA-256 do arquivo guardado.';
COMMENT ON COLUMN stg.manifesto_raw.bytes IS 'Tamanho do arquivo em bytes.';
COMMENT ON COLUMN stg.manifesto_raw.dt_coleta IS 'Data e hora da coleta (ISO 8601).';
COMMENT ON COLUMN stg.manifesto_raw.modificado_na_origem IS 'Data de modificação informada pelo portal de origem.';
COMMENT ON COLUMN stg.manifesto_raw.sha256_pacote IS 'Hash SHA-256 do ZIP de origem (INMET e setores do IBGE), apagado após a extração.';
COMMENT ON COLUMN stg.manifesto_raw.bytes_pacote IS 'Tamanho do ZIP de origem em bytes.';
COMMENT ON COLUMN stg.manifesto_raw.observacao IS 'Observações da coleta (tipo do recurso, licença, membro do ZIP).';
COMMENT ON COLUMN stg.manifesto_raw.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.manifesto_raw.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';
COMMENT ON COLUMN stg.manifesto_raw.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- 1.2 si-bol: ocorrências (1 linha por boletim) -------------------------------
CREATE TABLE IF NOT EXISTS stg.si_bol (
    numero_boletim         text,
    data_hora_boletim      text,
    data_inclusao          text,
    tipo_acidente          text,
    desc_tipo_acidente     text,
    cod_tempo              text,
    desc_tempo             text,
    cod_pavimento          text,
    pavimento              text,
    cod_regional           text,
    desc_regional          text,
    origem_boletim         text,
    local_sinalizado       text,
    velocidade_permitida   text,
    coordenada_x           text,
    coordenada_y           text,
    hora_informada         text,
    indicador_fatalidade   text,
    valor_ups              text,
    descricao_ups          text,
    data_alteracao_smsa    text,
    valor_ups_antiga       text,
    descricao_ups_antiga   text,
    ano_arquivo            smallint NOT NULL,
    arquivo_origem         text NOT NULL,
    linha_arquivo          integer NOT NULL,
    dt_carga               timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.si_bol IS 'Espelho dos arquivos si-bol-AAAA.csv (PBH/BHTrans): dados gerais de cada boletim de ocorrência de sinistro de trânsito com vítima.';
COMMENT ON COLUMN stg.si_bol.numero_boletim IS 'Número do boletim (numérico até 2016; formato AAAA-NNNNNNNNN-NNN depois). Origem: numero_boletim / NUMERO_BOLETIM.';
COMMENT ON COLUMN stg.si_bol.data_hora_boletim IS 'Data e hora do sinistro, texto DD/MM/AAAA HH:MI. Origem: "data hora_boletim" (com espaço).';
COMMENT ON COLUMN stg.si_bol.data_inclusao IS 'Data de registro do boletim.';
COMMENT ON COLUMN stg.si_bol.tipo_acidente IS 'Código do tipo de sinistro (ex.: H01002).';
COMMENT ON COLUMN stg.si_bol.desc_tipo_acidente IS 'Descrição do tipo de sinistro.';
COMMENT ON COLUMN stg.si_bol.cod_tempo IS 'Código da condição climática declarada (0 não informado, 1 bom, 2 chuva, 3 neblina, 4 nublado).';
COMMENT ON COLUMN stg.si_bol.desc_tempo IS 'Descrição da condição climática.';
COMMENT ON COLUMN stg.si_bol.cod_pavimento IS 'Código do pavimento (0 não informado, 1 asfalto, 2 concreto, 3 terra, 4 calçamento).';
COMMENT ON COLUMN stg.si_bol.pavimento IS 'Descrição do pavimento.';
COMMENT ON COLUMN stg.si_bol.cod_regional IS 'Código da administração regional (18 a 26; 27 = Hipercentro em 2024; 0 = não informado).';
COMMENT ON COLUMN stg.si_bol.desc_regional IS 'Nome da regional.';
COMMENT ON COLUMN stg.si_bol.origem_boletim IS 'Órgão/batalhão que registrou o boletim.';
COMMENT ON COLUMN stg.si_bol.local_sinalizado IS 'Indica se o local é sinalizado (SIM, NÃO, NÃO INFORMADO).';
COMMENT ON COLUMN stg.si_bol.velocidade_permitida IS 'Velocidade máxima permitida no local (km/h; 0 = não informada).';
COMMENT ON COLUMN stg.si_bol.coordenada_x IS 'Coordenada X (UTM 23S). Até 2015: SAD 69, X multiplicado por 100; a partir de 2016: SIRGAS 2000.';
COMMENT ON COLUMN stg.si_bol.coordenada_y IS 'Coordenada Y (UTM 23S). Até 2015: SAD 69, (Y - 7.000.000) multiplicado por 100; a partir de 2016: SIRGAS 2000.';
COMMENT ON COLUMN stg.si_bol.hora_informada IS 'Indica se a hora do sinistro foi informada (SIM/NÃO).';
COMMENT ON COLUMN stg.si_bol.indicador_fatalidade IS 'Indica se houve vítima fatal (SIM/NÃO).';
COMMENT ON COLUMN stg.si_bol.valor_ups IS 'Unidade Padrão de Severidade atual (1 sem vítima, 5 com vítima não fatal, 13 com vítima fatal; 0 = não informado).';
COMMENT ON COLUMN stg.si_bol.descricao_ups IS 'Descrição da UPS atual. Origem: descricao_ups / DESCRIÇÃO_UPS.';
COMMENT ON COLUMN stg.si_bol.data_alteracao_smsa IS 'Data de alteração pela Secretaria Municipal de Saúde.';
COMMENT ON COLUMN stg.si_bol.valor_ups_antiga IS 'UPS anterior à revisão da SMSA (preservada apenas no staging).';
COMMENT ON COLUMN stg.si_bol.descricao_ups_antiga IS 'Descrição da UPS anterior (preservada apenas no staging).';
COMMENT ON COLUMN stg.si_bol.ano_arquivo IS 'Ano do arquivo de origem (si-bol-AAAA).';
COMMENT ON COLUMN stg.si_bol.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.si_bol.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem (o cabeçalho é a linha 1).';
COMMENT ON COLUMN stg.si_bol.dt_carga IS 'Linhagem: data e hora da carga no staging.';
CREATE INDEX IF NOT EXISTS ix_stg_si_bol_boletim ON stg.si_bol (numero_boletim, ano_arquivo);

-- 1.3 si-log: logradouros do local (1 ou mais linhas por boletim) -------------
CREATE TABLE IF NOT EXISTS stg.si_log (
    numero_boletim            text,
    data_boletim              text,
    numero_municipio          text,
    nome_municipio            text,
    sequencia_logradouro      text,
    numero_logradouro         text,
    tipo_logradouro           text,
    nome_logradouro           text,
    tipo_logradouro_anterior  text,
    nome_logradouro_anterior  text,
    numero_bairro             text,
    nome_bairro               text,
    tipo_bairro               text,
    descricao_tipo_bairro     text,
    numero_imovel             text,
    numero_imovel_proximo     text,
    ano_arquivo               smallint NOT NULL,
    arquivo_origem            text NOT NULL,
    linha_arquivo             integer NOT NULL,
    dt_carga                  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.si_log IS 'Espelho dos arquivos si-log-AAAA.csv: logradouros do local do sinistro (sequência 1 = logradouro principal; 2 em diante = cruzamento/referência).';
COMMENT ON COLUMN stg.si_log.numero_boletim IS 'Número do boletim. Origem: numero_boletim / Nº_boletim.';
COMMENT ON COLUMN stg.si_log.data_boletim IS 'Data e hora do sinistro.';
COMMENT ON COLUMN stg.si_log.numero_municipio IS 'Código do município do endereço. Origem: numero_municipio / Nº_municipio.';
COMMENT ON COLUMN stg.si_log.nome_municipio IS 'Nome do município do endereço.';
COMMENT ON COLUMN stg.si_log.sequencia_logradouro IS 'Sequência do logradouro no boletim. Origem: sequencia_logradouros / seq_logradouros.';
COMMENT ON COLUMN stg.si_log.numero_logradouro IS 'Código do logradouro no cadastro da PBH. Origem: numero_logradouro / Nº_logradouro.';
COMMENT ON COLUMN stg.si_log.tipo_logradouro IS 'Sigla do tipo de logradouro (RUA, AVE, ROD...).';
COMMENT ON COLUMN stg.si_log.nome_logradouro IS 'Nome do logradouro.';
COMMENT ON COLUMN stg.si_log.tipo_logradouro_anterior IS 'Sigla do tipo do logradouro em denominação anterior.';
COMMENT ON COLUMN stg.si_log.nome_logradouro_anterior IS 'Nome anterior do logradouro. Origem: nome_logradoro_anterior (erro de digitação na fonte) / nome_logradouro_anterior.';
COMMENT ON COLUMN stg.si_log.numero_bairro IS 'Código do bairro. Origem: Numero_bairro / Nº_bairro.';
COMMENT ON COLUMN stg.si_log.nome_bairro IS 'Nome do bairro.';
COMMENT ON COLUMN stg.si_log.tipo_bairro IS 'Sigla do tipo de bairro (B, V, CH...).';
COMMENT ON COLUMN stg.si_log.descricao_tipo_bairro IS 'Descrição do tipo de bairro.';
COMMENT ON COLUMN stg.si_log.numero_imovel IS 'Número do imóvel de referência.';
COMMENT ON COLUMN stg.si_log.numero_imovel_proximo IS 'Número do imóvel mais próximo.';
COMMENT ON COLUMN stg.si_log.ano_arquivo IS 'Ano do arquivo de origem.';
COMMENT ON COLUMN stg.si_log.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.si_log.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';
COMMENT ON COLUMN stg.si_log.dt_carga IS 'Linhagem: data e hora da carga no staging.';
CREATE INDEX IF NOT EXISTS ix_stg_si_log_boletim ON stg.si_log (numero_boletim, ano_arquivo);

-- 1.4 si-veic: veículos envolvidos ---------------------------------------------
CREATE TABLE IF NOT EXISTS stg.si_veic (
    numero_boletim          text,
    data_hora_boletim       text,
    sequencial_veiculo      text,
    codigo_categoria        text,
    descricao_categoria     text,
    codigo_especie          text,
    descricao_especie       text,
    codigo_situacao         text,
    descricao_situacao      text,
    tipo_socorro            text,
    descricao_tipo_socorro  text,
    ano_arquivo             smallint NOT NULL,
    arquivo_origem          text NOT NULL,
    linha_arquivo           integer NOT NULL,
    dt_carga                timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.si_veic IS 'Espelho dos arquivos si-veic-AAAA.csv: veículos envolvidos em cada boletim (o de 2023 é lido em CP850).';
COMMENT ON COLUMN stg.si_veic.numero_boletim IS 'Número do boletim. Origem: numero_boletim / Nº_boletim.';
COMMENT ON COLUMN stg.si_veic.data_hora_boletim IS 'Data e hora do sinistro.';
COMMENT ON COLUMN stg.si_veic.sequencial_veiculo IS 'Sequencial do veículo no boletim. Origem: sequencial_veiculo / seq_veic.';
COMMENT ON COLUMN stg.si_veic.codigo_categoria IS 'Código da categoria (0 n/i, 1 oficial, 2 missão diplomática, 3 particular, 4 aluguel, 5 aprendizagem). Origem: codigo_categoria / cod_categ.';
COMMENT ON COLUMN stg.si_veic.descricao_categoria IS 'Descrição da categoria do veículo.';
COMMENT ON COLUMN stg.si_veic.codigo_especie IS 'Código da espécie do veículo. Origem: codigo_especie / cod_especie.';
COMMENT ON COLUMN stg.si_veic.descricao_especie IS 'Descrição da espécie do veículo (AUTOMOVEL, MOTOCICLETA...).';
COMMENT ON COLUMN stg.si_veic.codigo_situacao IS 'Código da situação (0 n/i, 1 em movimento, 2 parado, 3 estacionado). Origem: codigo_situacao / cod_situacao.';
COMMENT ON COLUMN stg.si_veic.descricao_situacao IS 'Descrição da situação (vazia para o código 3 até 2019). Origem: descricao_situacao / desc_situacao.';
COMMENT ON COLUMN stg.si_veic.tipo_socorro IS 'Código do tipo de socorro prestado.';
COMMENT ON COLUMN stg.si_veic.descricao_tipo_socorro IS 'Descrição do tipo de socorro. Origem: descricao_tipo_socorro / desc_tipo_socorro.';
COMMENT ON COLUMN stg.si_veic.ano_arquivo IS 'Ano do arquivo de origem.';
COMMENT ON COLUMN stg.si_veic.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.si_veic.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';
COMMENT ON COLUMN stg.si_veic.dt_carga IS 'Linhagem: data e hora da carga no staging.';
CREATE INDEX IF NOT EXISTS ix_stg_si_veic_boletim ON stg.si_veic (numero_boletim, ano_arquivo);

-- 1.5 si_env: pessoas envolvidas (chamada de "si-pess" na Fase 2) --------------
CREATE TABLE IF NOT EXISTS stg.si_env (
    numero_boletim         text,
    data_hora_boletim      text,
    numero_envolvido       text,
    condutor               text,
    codigo_severidade      text,
    desc_severidade        text,
    sexo                   text,
    cinto_seguranca        text,
    embriaguez             text,
    idade                  text,
    nascimento             text,
    categoria_habilitacao  text,
    descricao_habilitacao  text,
    declaracao_obito       text,
    cod_severidade_antiga  text,
    especie_veiculo        text,
    pedestre               text,
    passageiro             text,
    usa_capacete           text,
    ano_arquivo            smallint NOT NULL,
    arquivo_origem         text NOT NULL,
    linha_arquivo          integer NOT NULL,
    dt_carga               timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.si_env IS 'Espelho dos arquivos si_env-AAAA.csv (tabela chamada "si-pess" na Fase 2): pessoas envolvidas em cada boletim.';
COMMENT ON COLUMN stg.si_env.numero_boletim IS 'Número do boletim. Origem: num_boletim / Nº_boletim.';
COMMENT ON COLUMN stg.si_env.data_hora_boletim IS 'Data e hora do sinistro.';
COMMENT ON COLUMN stg.si_env.numero_envolvido IS 'Número do envolvido no boletim. Origem: numero_envolvido / Nº_envolvido.';
COMMENT ON COLUMN stg.si_env.condutor IS 'Indica se é condutor (SIM/NÃO/NÃO INFORMADO até 2015; S/N/0 depois).';
COMMENT ON COLUMN stg.si_env.codigo_severidade IS 'Severidade atual (0 n/i, 1 não fatal, 2 fatal, 3 sem ferimentos). Origem: codigo_severidade / cod_severidade.';
COMMENT ON COLUMN stg.si_env.desc_severidade IS 'Descrição da severidade.';
COMMENT ON COLUMN stg.si_env.sexo IS 'Sexo (M, F, 0 = não informado).';
COMMENT ON COLUMN stg.si_env.cinto_seguranca IS 'Uso de cinto de segurança (SIM/NÃO/NÃO INFORMADO).';
COMMENT ON COLUMN stg.si_env.embriaguez IS 'Indício de embriaguez (SIM/NÃO/NÃO INFORMADO). Origem: Embreagues (grafia da fonte).';
COMMENT ON COLUMN stg.si_env.idade IS 'Idade em anos.';
COMMENT ON COLUMN stg.si_env.nascimento IS 'Data de nascimento (00/00/0000 = não informada).';
COMMENT ON COLUMN stg.si_env.categoria_habilitacao IS 'Categoria da habilitação do condutor.';
COMMENT ON COLUMN stg.si_env.descricao_habilitacao IS 'Descrição da categoria de habilitação.';
COMMENT ON COLUMN stg.si_env.declaracao_obito IS 'Número da declaração de óbito (preservado apenas no staging).';
COMMENT ON COLUMN stg.si_env.cod_severidade_antiga IS 'Severidade anterior à revisão (preservada apenas no staging).';
COMMENT ON COLUMN stg.si_env.especie_veiculo IS 'Espécie do veículo em que a pessoa estava (vazio para pedestres). Não traz o sequencial do veículo.';
COMMENT ON COLUMN stg.si_env.pedestre IS 'Indicador de pedestre (S/N/0). Origem: indicador_pedestre (2015) / pedestre (2016+); ausente até 2014.';
COMMENT ON COLUMN stg.si_env.passageiro IS 'Indicador de passageiro (S/N/0). Origem: indicador_passageiro (2015) / passageiro (2016+); ausente até 2014.';
COMMENT ON COLUMN stg.si_env.usa_capacete IS 'Indicador de uso de capacete. Origem: indicador_usa_capacete (somente 2015).';
COMMENT ON COLUMN stg.si_env.ano_arquivo IS 'Ano do arquivo de origem.';
COMMENT ON COLUMN stg.si_env.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.si_env.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';
COMMENT ON COLUMN stg.si_env.dt_carga IS 'Linhagem: data e hora da carga no staging.';
CREATE INDEX IF NOT EXISTS ix_stg_si_env_boletim ON stg.si_env (numero_boletim, ano_arquivo);

-- 1.6 Limites das regionais (PBH) ---------------------------------------------
CREATE TABLE IF NOT EXISTS stg.regional_limite (
    id_reg          text,
    cod_reg         text,
    sigla           text,
    nome            text,
    area_km2        text,
    perimetr_m      text,
    geometria       text,
    arquivo_origem  text NOT NULL,
    linha_arquivo   integer NOT NULL,
    dt_carga        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.regional_limite IS 'Espelho dos arquivos de limites das regionais da PBH: 20220601_regional (9 regionais, vigente até jan/2025, usado no DW) e 20250204_regional (10 regionais, apenas para referência).';
COMMENT ON COLUMN stg.regional_limite.id_reg IS 'Identificador da regional no arquivo.';
COMMENT ON COLUMN stg.regional_limite.cod_reg IS 'Código da regional (o mesmo cod_regional do si-bol).';
COMMENT ON COLUMN stg.regional_limite.sigla IS 'Sigla da regional.';
COMMENT ON COLUMN stg.regional_limite.nome IS 'Nome da regional.';
COMMENT ON COLUMN stg.regional_limite.area_km2 IS 'Área em km².';
COMMENT ON COLUMN stg.regional_limite.perimetr_m IS 'Perímetro em metros.';
COMMENT ON COLUMN stg.regional_limite.geometria IS 'Polígono em WKT, SIRGAS 2000 / UTM 23S (EPSG:31983).';
COMMENT ON COLUMN stg.regional_limite.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';
COMMENT ON COLUMN stg.regional_limite.linha_arquivo IS 'Linhagem: número do registro no arquivo de origem.';
COMMENT ON COLUMN stg.regional_limite.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- 1.7 IBGE: valores das tabelas do SIDRA ---------------------------------------
CREATE TABLE IF NOT EXISTS stg.ibge_sidra_valor (
    tabela           text,
    variavel_id      text,
    variavel_nome    text,
    nivel            text,
    localidade_id    text,
    localidade_nome  text,
    periodo          text,
    valor            text,
    arquivo_origem   text NOT NULL,
    linha_arquivo    integer NOT NULL,
    dt_carga         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.ibge_sidra_valor IS 'Valores das consultas à API de agregados do IBGE (SIDRA): estimativas (tabela 6579), Censo 2010 (202) e Censo 2022 (9923), em formato longo.';
COMMENT ON COLUMN stg.ibge_sidra_valor.tabela IS 'Número da tabela do SIDRA.';
COMMENT ON COLUMN stg.ibge_sidra_valor.variavel_id IS 'Identificador da variável (9324 estimada; 93 população residente).';
COMMENT ON COLUMN stg.ibge_sidra_valor.variavel_nome IS 'Nome da variável.';
COMMENT ON COLUMN stg.ibge_sidra_valor.nivel IS 'Nível territorial (N6 município, N10 distrito, N11 subdistrito).';
COMMENT ON COLUMN stg.ibge_sidra_valor.localidade_id IS 'Código IBGE da localidade.';
COMMENT ON COLUMN stg.ibge_sidra_valor.localidade_nome IS 'Nome da localidade.';
COMMENT ON COLUMN stg.ibge_sidra_valor.periodo IS 'Período (ano).';
COMMENT ON COLUMN stg.ibge_sidra_valor.valor IS 'Valor publicado (texto).';
COMMENT ON COLUMN stg.ibge_sidra_valor.arquivo_origem IS 'Linhagem: arquivo JSON de origem.';
COMMENT ON COLUMN stg.ibge_sidra_valor.linha_arquivo IS 'Linhagem: posição do valor no arquivo.';
COMMENT ON COLUMN stg.ibge_sidra_valor.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- 1.8 IBGE: distritos e subdistritos (API de localidades) ----------------------
CREATE TABLE IF NOT EXISTS stg.ibge_localidade (
    tipo             text,
    localidade_id    text,
    localidade_nome  text,
    distrito_id      text,
    distrito_nome    text,
    municipio_id     text,
    arquivo_origem   text NOT NULL,
    linha_arquivo    integer NOT NULL,
    dt_carga         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.ibge_localidade IS 'Distritos e subdistritos de Belo Horizonte segundo a API de localidades do IBGE (divisão territorial vigente).';
COMMENT ON COLUMN stg.ibge_localidade.tipo IS 'distrito ou subdistrito.';
COMMENT ON COLUMN stg.ibge_localidade.localidade_id IS 'Código IBGE do distrito/subdistrito.';
COMMENT ON COLUMN stg.ibge_localidade.localidade_nome IS 'Nome do distrito/subdistrito.';
COMMENT ON COLUMN stg.ibge_localidade.distrito_id IS 'Código do distrito a que o subdistrito pertence.';
COMMENT ON COLUMN stg.ibge_localidade.distrito_nome IS 'Nome do distrito a que o subdistrito pertence.';
COMMENT ON COLUMN stg.ibge_localidade.municipio_id IS 'Código IBGE do município.';
COMMENT ON COLUMN stg.ibge_localidade.arquivo_origem IS 'Linhagem: arquivo JSON de origem.';
COMMENT ON COLUMN stg.ibge_localidade.linha_arquivo IS 'Linhagem: posição do registro no arquivo.';
COMMENT ON COLUMN stg.ibge_localidade.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- 1.9 IBGE: setores censitários de 2010 (somente Belo Horizonte) ---------------
CREATE TABLE IF NOT EXISTS stg.ibge_setor2010_malha (
    cd_geocodi        text,
    tipo              text,
    cd_geocodb        text,
    nm_bairro         text,
    cd_geocods        text,
    nm_subdist        text,
    cd_geocodd        text,
    nm_distrit        text,
    cd_geocodm        text,
    nm_municip        text,
    geometria_geojson text,
    arquivo_origem    text NOT NULL,
    linha_arquivo     integer NOT NULL,
    dt_carga          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.ibge_setor2010_malha IS 'Malha de setores censitários do Censo 2010 (shapefile 31SEE250GC_SIR, SIRGAS 2000 geográfico), filtrada para Belo Horizonte.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodi IS 'Código do setor censitário (15 dígitos).';
COMMENT ON COLUMN stg.ibge_setor2010_malha.tipo IS 'Tipo do setor (URBANO/RURAL).';
COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodb IS 'Código do bairro IBGE.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_bairro IS 'Nome do bairro IBGE.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocods IS 'Código do subdistrito.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_subdist IS 'Nome do subdistrito.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodd IS 'Código do distrito.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_distrit IS 'Nome do distrito.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodm IS 'Código do município.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_municip IS 'Nome do município.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.geometria_geojson IS 'Polígono do setor em GeoJSON (EPSG:4674).';
COMMENT ON COLUMN stg.ibge_setor2010_malha.arquivo_origem IS 'Linhagem: shapefile de origem.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.linha_arquivo IS 'Linhagem: número do registro no shapefile.';
COMMENT ON COLUMN stg.ibge_setor2010_malha.dt_carga IS 'Linhagem: data e hora da carga no staging.';

CREATE TABLE IF NOT EXISTS stg.ibge_setor2010_variavel (
    cod_setor        text,
    planilha         text,
    variavel         text,
    valor            text,
    arquivo_origem   text NOT NULL,
    linha_arquivo    integer NOT NULL,
    dt_carga         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.ibge_setor2010_variavel IS 'Agregados por setor censitário do Censo 2010 (Resultados do Universo), formato longo, apenas setores de Belo Horizonte e variáveis de população.';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.cod_setor IS 'Código do setor censitário.';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.planilha IS 'Planilha de origem (Basico, Pessoa13, Domicilio02).';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.variavel IS 'Código da variável (ex.: V001 da Pessoa13 = pessoas residentes).';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.valor IS 'Valor publicado (texto; "X" = sigilo).';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.arquivo_origem IS 'Linhagem: arquivo CSV de origem.';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';
COMMENT ON COLUMN stg.ibge_setor2010_variavel.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- 1.10 INMET: dados horários das estações automáticas de BH -------------------
CREATE TABLE IF NOT EXISTS stg.inmet_horario (
    estacao_codigo             text,
    estacao_nome               text,
    data_medicao               text,
    hora_utc                   text,
    precipitacao_mm            text,
    pressao_estacao_mb         text,
    pressao_max_mb             text,
    pressao_min_mb             text,
    radiacao_global_kj_m2      text,
    temperatura_ar_c           text,
    temperatura_orvalho_c      text,
    temperatura_max_c          text,
    temperatura_min_c          text,
    temperatura_orvalho_max_c  text,
    temperatura_orvalho_min_c  text,
    umidade_max_pct            text,
    umidade_min_pct            text,
    umidade_relativa_pct       text,
    vento_direcao_graus        text,
    vento_rajada_ms            text,
    vento_velocidade_ms        text,
    ano_arquivo                smallint NOT NULL,
    arquivo_origem             text NOT NULL,
    linha_arquivo              integer NOT NULL,
    dt_carga                   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.inmet_horario IS 'Espelho dos CSVs horários do INMET das estações automáticas de BH: A521 Pampulha (principal) e F501 Cercadinho (reserva, desde 27/12/2013). Horário em UTC.';
COMMENT ON COLUMN stg.inmet_horario.estacao_codigo IS 'Código da estação (metadado "CODIGO (WMO)").';
COMMENT ON COLUMN stg.inmet_horario.estacao_nome IS 'Nome da estação (metadado "ESTACAO").';
COMMENT ON COLUMN stg.inmet_horario.data_medicao IS 'Data da medição (AAAA-MM-DD até 2018; AAAA/MM/DD depois).';
COMMENT ON COLUMN stg.inmet_horario.hora_utc IS 'Hora UTC do fim do intervalo (HH:MM até 2018; "HHMM UTC" depois).';
COMMENT ON COLUMN stg.inmet_horario.precipitacao_mm IS 'Precipitação total no intervalo horário (mm, vírgula decimal; -9999 ou vazio = ausente).';
COMMENT ON COLUMN stg.inmet_horario.pressao_estacao_mb IS 'Pressão atmosférica ao nível da estação (mB).';
COMMENT ON COLUMN stg.inmet_horario.pressao_max_mb IS 'Pressão máxima na hora anterior (mB).';
COMMENT ON COLUMN stg.inmet_horario.pressao_min_mb IS 'Pressão mínima na hora anterior (mB).';
COMMENT ON COLUMN stg.inmet_horario.radiacao_global_kj_m2 IS 'Radiação global (kJ/m²).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_ar_c IS 'Temperatura do ar, bulbo seco (°C).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_c IS 'Temperatura do ponto de orvalho (°C).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_max_c IS 'Temperatura máxima na hora anterior (°C).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_min_c IS 'Temperatura mínima na hora anterior (°C).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_max_c IS 'Temperatura de orvalho máxima na hora anterior (°C).';
COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_min_c IS 'Temperatura de orvalho mínima na hora anterior (°C).';
COMMENT ON COLUMN stg.inmet_horario.umidade_max_pct IS 'Umidade relativa máxima na hora anterior (%).';
COMMENT ON COLUMN stg.inmet_horario.umidade_min_pct IS 'Umidade relativa mínima na hora anterior (%).';
COMMENT ON COLUMN stg.inmet_horario.umidade_relativa_pct IS 'Umidade relativa do ar horária (%).';
COMMENT ON COLUMN stg.inmet_horario.vento_direcao_graus IS 'Direção horária do vento (graus).';
COMMENT ON COLUMN stg.inmet_horario.vento_rajada_ms IS 'Rajada máxima de vento (m/s).';
COMMENT ON COLUMN stg.inmet_horario.vento_velocidade_ms IS 'Velocidade horária do vento (m/s).';
COMMENT ON COLUMN stg.inmet_horario.ano_arquivo IS 'Ano do arquivo (ZIP anual do INMET).';
COMMENT ON COLUMN stg.inmet_horario.arquivo_origem IS 'Linhagem: arquivo CSV de origem.';
COMMENT ON COLUMN stg.inmet_horario.linha_arquivo IS 'Linhagem: número da linha no arquivo (metadados nas linhas 1 a 8, cabeçalho na 9).';
COMMENT ON COLUMN stg.inmet_horario.dt_carga IS 'Linhagem: data e hora da carga no staging.';

-- ===========================================================================
-- 2. SCHEMA STG — CONTROLE DA CARGA
-- ===========================================================================
CREATE TABLE IF NOT EXISTS stg.log_carga (
    id_log          bigserial PRIMARY KEY,
    id_execucao     bigint NOT NULL,
    etapa           text NOT NULL,
    status          text NOT NULL CHECK (status IN ('INICIADA', 'SUCESSO', 'FALHA', 'ALERTA')),
    dt_inicio       timestamptz NOT NULL DEFAULT now(),
    dt_fim          timestamptz,
    linhas          bigint,
    mensagem        text,
    parametros      text,
    arquivo_origem  text NOT NULL DEFAULT 'etl.carga_inicial',
    dt_carga        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.log_carga IS 'Registro de cada execução do ETL (uma linha por etapa: extrair, staging, transformar, testes, carregar, reconciliar).';
COMMENT ON COLUMN stg.log_carga.id_log IS 'Identificador da linha de log.';
COMMENT ON COLUMN stg.log_carga.id_execucao IS 'Identificador da execução (AAAAMMDDHHMISS do início).';
COMMENT ON COLUMN stg.log_carga.etapa IS 'Etapa do ETL.';
COMMENT ON COLUMN stg.log_carga.status IS 'INICIADA, SUCESSO, FALHA ou ALERTA.';
COMMENT ON COLUMN stg.log_carga.dt_inicio IS 'Início da etapa.';
COMMENT ON COLUMN stg.log_carga.dt_fim IS 'Fim da etapa.';
COMMENT ON COLUMN stg.log_carga.linhas IS 'Linhas processadas na etapa, quando aplicável.';
COMMENT ON COLUMN stg.log_carga.mensagem IS 'Mensagem de resultado ou de erro.';
COMMENT ON COLUMN stg.log_carga.parametros IS 'Parâmetros da execução (anos, forçar download...).';
COMMENT ON COLUMN stg.log_carga.arquivo_origem IS 'Linhagem: módulo que gravou o registro.';
COMMENT ON COLUMN stg.log_carga.dt_carga IS 'Linhagem: data e hora da gravação.';

CREATE TABLE IF NOT EXISTS stg.resultado_qualidade (
    id_resultado    bigserial PRIMARY KEY,
    id_execucao     bigint NOT NULL,
    teste           text NOT NULL,
    categoria       text NOT NULL,
    severidade      text NOT NULL CHECK (severidade IN ('CRITICO', 'ALERTA', 'INFO')),
    aprovado        boolean NOT NULL,
    valor_obtido    text,
    criterio        text,
    detalhe         text,
    arquivo_origem  text NOT NULL DEFAULT 'etl.testes_qualidade',
    dt_carga        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  stg.resultado_qualidade IS 'Resultado de cada teste de qualidade executado antes de promover os dados ao dw.';
COMMENT ON COLUMN stg.resultado_qualidade.id_resultado IS 'Identificador do resultado.';
COMMENT ON COLUMN stg.resultado_qualidade.id_execucao IS 'Execução do ETL a que o teste pertence.';
COMMENT ON COLUMN stg.resultado_qualidade.teste IS 'Nome do teste.';
COMMENT ON COLUMN stg.resultado_qualidade.categoria IS 'Categoria (unicidade, domínio, volume, órfãos, coerência, cobertura, reconciliação).';
COMMENT ON COLUMN stg.resultado_qualidade.severidade IS 'CRITICO interrompe a carga; ALERTA e INFO apenas registram.';
COMMENT ON COLUMN stg.resultado_qualidade.aprovado IS 'Verdadeiro se o critério foi atendido.';
COMMENT ON COLUMN stg.resultado_qualidade.valor_obtido IS 'Valor medido.';
COMMENT ON COLUMN stg.resultado_qualidade.criterio IS 'Critério de aprovação.';
COMMENT ON COLUMN stg.resultado_qualidade.detalhe IS 'Detalhamento (ex.: contagem por ano).';
COMMENT ON COLUMN stg.resultado_qualidade.arquivo_origem IS 'Linhagem: módulo que gravou o resultado.';
COMMENT ON COLUMN stg.resultado_qualidade.dt_carga IS 'Linhagem: data e hora da gravação.';

-- ===========================================================================
-- 3. SCHEMA STG — DE-PARAS DE DOMÍNIO (seeds carregados de etl/mapeamentos/)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS stg.map_dominio (
    dominio         text NOT NULL,
    codigo          text NOT NULL,
    descricao       text NOT NULL,
    grupo           text,
    ordem           smallint,
    observacao      text,
    arquivo_origem  text NOT NULL,
    linha_arquivo   integer NOT NULL,
    dt_carga        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_map_dominio PRIMARY KEY (dominio, codigo)
);
COMMENT ON TABLE  stg.map_dominio IS 'De-para dos domínios codificados (tipo de sinistro, tempo, pavimento, severidade, categoria/situação/espécie de veículo, tipo de logradouro, sexo), derivado da inspeção dos arquivos reais.';
COMMENT ON COLUMN stg.map_dominio.dominio IS 'Nome do domínio.';
COMMENT ON COLUMN stg.map_dominio.codigo IS 'Código (ou descrição) como aparece na fonte.';
COMMENT ON COLUMN stg.map_dominio.descricao IS 'Descrição padronizada.';
COMMENT ON COLUMN stg.map_dominio.grupo IS 'Agrupamento analítico (ex.: grupo do tipo de sinistro, grupo da espécie).';
COMMENT ON COLUMN stg.map_dominio.ordem IS 'Ordem de exibição.';
COMMENT ON COLUMN stg.map_dominio.observacao IS 'Observações sobre o código.';
COMMENT ON COLUMN stg.map_dominio.arquivo_origem IS 'Linhagem: arquivo de mapeamento de origem.';
COMMENT ON COLUMN stg.map_dominio.linha_arquivo IS 'Linhagem: linha no arquivo de mapeamento.';
COMMENT ON COLUMN stg.map_dominio.dt_carga IS 'Linhagem: data e hora da carga.';

CREATE TABLE IF NOT EXISTS stg.map_regional (
    cod_regional_boletim   smallint NOT NULL,
    desc_regional_boletim  text,
    cod_reg_limite         smallint,
    nome_regional          text,
    sigla                  text,
    nome_subdistrito_ibge  text,
    observacao             text,
    arquivo_origem         text NOT NULL,
    linha_arquivo          integer NOT NULL,
    dt_carga               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_map_regional PRIMARY KEY (cod_regional_boletim)
);
COMMENT ON TABLE  stg.map_regional IS 'De-para das regionais: cod_regional/desc_regional do si-bol x COD_REG/NOME do limite 20220601 x subdistritos do IBGE.';
COMMENT ON COLUMN stg.map_regional.cod_regional_boletim IS 'Código da regional no si-bol (0 = não informada; 27 = Hipercentro, usado em 2024).';
COMMENT ON COLUMN stg.map_regional.desc_regional_boletim IS 'Nome da regional no si-bol.';
COMMENT ON COLUMN stg.map_regional.cod_reg_limite IS 'COD_REG correspondente no limite de 9 regionais (vigente até jan/2025).';
COMMENT ON COLUMN stg.map_regional.nome_regional IS 'Nome da regional no limite.';
COMMENT ON COLUMN stg.map_regional.sigla IS 'Sigla da regional.';
COMMENT ON COLUMN stg.map_regional.nome_subdistrito_ibge IS 'Nome dos subdistritos do IBGE que compõem a regional (Censos 2010 e 2022).';
COMMENT ON COLUMN stg.map_regional.observacao IS 'Observações do de-para.';
COMMENT ON COLUMN stg.map_regional.arquivo_origem IS 'Linhagem: arquivo de mapeamento de origem.';
COMMENT ON COLUMN stg.map_regional.linha_arquivo IS 'Linhagem: linha no arquivo de mapeamento.';
COMMENT ON COLUMN stg.map_regional.dt_carga IS 'Linhagem: data e hora da carga.';

-- ===========================================================================
-- 4. SCHEMA STG — TABELAS DE TRABALHO DA TRANSFORMAÇÃO (prefixo trf_)
--    Dados já tipados, deduplicados e enriquecidos; base dos testes de
--    qualidade e da carga do dw. São esvaziadas e refeitas a cada carga.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS stg.trf_boletim (
    numero_boletim_dw        text NOT NULL,
    ano                      smallint NOT NULL,
    numero_boletim_origem    text NOT NULL,
    seq_ocorrencia           smallint NOT NULL,
    data_hora                timestamp NOT NULL,
    data                     date NOT NULL,
    hora                     smallint,
    fl_hora_informada        boolean NOT NULL,
    cod_tipo_sinistro        text NOT NULL,
    cod_tempo                smallint NOT NULL,
    cod_pavimento            smallint NOT NULL,
    local_sinalizado         text NOT NULL,
    cod_regional_origem      smallint NOT NULL,
    velocidade_permitida     smallint,
    valor_ups_origem         smallint,
    fl_indicador_fatalidade  boolean NOT NULL,
    coordenada_x_origem      numeric(14,2),
    coordenada_y_origem      numeric(14,2),
    qtd_linhas_origem        smallint NOT NULL,
    arquivo_origem           text NOT NULL,
    linha_arquivo            integer NOT NULL,
    dt_carga                 timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_boletim PRIMARY KEY (numero_boletim_dw, ano)
);
COMMENT ON TABLE  stg.trf_boletim IS 'Boletins tipados e deduplicados (1 linha por sinistro). Números repetidos no mesmo ano com data/hora diferentes são eventos distintos e recebem sufixo /2, /3.';
COMMENT ON COLUMN stg.trf_boletim.numero_boletim_dw IS 'Número do boletim usado no dw (original, com sufixo /n quando o número se repete no ano para outro evento).';
COMMENT ON COLUMN stg.trf_boletim.ano IS 'Ano do sinistro (igual ao ano do arquivo).';
COMMENT ON COLUMN stg.trf_boletim.numero_boletim_origem IS 'Número do boletim como veio na fonte.';
COMMENT ON COLUMN stg.trf_boletim.seq_ocorrencia IS 'Ordem do evento entre os que compartilham o mesmo número no ano (1 = único/primeiro).';
COMMENT ON COLUMN stg.trf_boletim.data_hora IS 'Data e hora do sinistro (horário local).';
COMMENT ON COLUMN stg.trf_boletim.data IS 'Data do sinistro.';
COMMENT ON COLUMN stg.trf_boletim.hora IS 'Hora do sinistro (nula quando hora_informada = NÃO).';
COMMENT ON COLUMN stg.trf_boletim.fl_hora_informada IS 'Verdadeiro se a hora foi informada no boletim.';
COMMENT ON COLUMN stg.trf_boletim.cod_tipo_sinistro IS 'Código do tipo de sinistro (sem espaços).';
COMMENT ON COLUMN stg.trf_boletim.cod_tempo IS 'Código da condição climática declarada.';
COMMENT ON COLUMN stg.trf_boletim.cod_pavimento IS 'Código do pavimento.';
COMMENT ON COLUMN stg.trf_boletim.local_sinalizado IS 'SIM, NÃO ou NÃO INFORMADO.';
COMMENT ON COLUMN stg.trf_boletim.cod_regional_origem IS 'Código da regional informado no boletim.';
COMMENT ON COLUMN stg.trf_boletim.velocidade_permitida IS 'Velocidade permitida (km/h); nula se 0 ou fora de 10–120.';
COMMENT ON COLUMN stg.trf_boletim.valor_ups_origem IS 'UPS informada na fonte (0 = não informada).';
COMMENT ON COLUMN stg.trf_boletim.fl_indicador_fatalidade IS 'Indicador de fatalidade do boletim (SIM = verdadeiro).';
COMMENT ON COLUMN stg.trf_boletim.coordenada_x_origem IS 'Coordenada X como veio na fonte (numérica).';
COMMENT ON COLUMN stg.trf_boletim.coordenada_y_origem IS 'Coordenada Y como veio na fonte (numérica).';
COMMENT ON COLUMN stg.trf_boletim.qtd_linhas_origem IS 'Linhas idênticas (mesmo número, ano e data/hora) consolidadas neste registro.';
COMMENT ON COLUMN stg.trf_boletim.arquivo_origem IS 'Linhagem: arquivo de origem.';
COMMENT ON COLUMN stg.trf_boletim.linha_arquivo IS 'Linhagem: linha do registro mantido.';
COMMENT ON COLUMN stg.trf_boletim.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_coordenada (
    numero_boletim_dw    text NOT NULL,
    ano                  smallint NOT NULL,
    srid_origem          integer,
    x_utm                numeric(12,2),
    y_utm                numeric(12,2),
    longitude            double precision,
    latitude             double precision,
    situacao             text NOT NULL,
    geom                 geometry(Point, 4326),
    fl_dentro_municipio  boolean,
    fl_geolocalizado     boolean NOT NULL DEFAULT false,
    arquivo_origem       text NOT NULL DEFAULT 'etl.transformar (pyproj)',
    dt_carga             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_coordenada PRIMARY KEY (numero_boletim_dw, ano)
);
COMMENT ON TABLE  stg.trf_coordenada IS 'Coordenadas corrigidas e reprojetadas com pyproj: 2011–2015 em SAD 69/UTM 23S (EPSG:29193, X e Y em escala x100) e 2016+ em SIRGAS 2000/UTM 23S (EPSG:31983), ambas para WGS 84 (EPSG:4326).';
COMMENT ON COLUMN stg.trf_coordenada.numero_boletim_dw IS 'Número do boletim no dw.';
COMMENT ON COLUMN stg.trf_coordenada.ano IS 'Ano do sinistro.';
COMMENT ON COLUMN stg.trf_coordenada.srid_origem IS 'Sistema de referência de origem (29193 ou 31983).';
COMMENT ON COLUMN stg.trf_coordenada.x_utm IS 'X em UTM 23S após a correção de escala (metros).';
COMMENT ON COLUMN stg.trf_coordenada.y_utm IS 'Y em UTM 23S após a correção de escala (metros).';
COMMENT ON COLUMN stg.trf_coordenada.longitude IS 'Longitude WGS 84.';
COMMENT ON COLUMN stg.trf_coordenada.latitude IS 'Latitude WGS 84.';
COMMENT ON COLUMN stg.trf_coordenada.situacao IS 'VALIDA, ZERADA (sem coordenada) ou FORA_FAIXA_BH (fora da faixa esperada para BH).';
COMMENT ON COLUMN stg.trf_coordenada.geom IS 'Ponto em WGS 84 (EPSG:4326).';
COMMENT ON COLUMN stg.trf_coordenada.fl_dentro_municipio IS 'Verdadeiro se o ponto está a até 100 m do limite do município (união das regionais).';
COMMENT ON COLUMN stg.trf_coordenada.fl_geolocalizado IS 'Verdadeiro se a coordenada é válida e está dentro do município.';
COMMENT ON COLUMN stg.trf_coordenada.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_coordenada.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_envolvido (
    numero_boletim_dw         text NOT NULL,
    ano                       smallint NOT NULL,
    numero_envolvido          smallint NOT NULL,
    tipo_envolvimento         text NOT NULL,
    origem_tipo_envolvimento  text NOT NULL,
    cod_severidade            smallint NOT NULL,
    gravidade                 text NOT NULL,
    fl_vitima                 boolean NOT NULL,
    fl_vitima_fatal           boolean NOT NULL,
    fl_condutor               boolean NOT NULL,
    fl_pedestre               boolean NOT NULL,
    fl_motociclista           boolean NOT NULL,
    sexo                      text NOT NULL,
    idade                     smallint,
    faixa_etaria              text NOT NULL,
    embriaguez                text NOT NULL,
    especie_veiculo           text,
    grupo_especie             text,
    arquivo_origem            text NOT NULL,
    linha_arquivo             integer NOT NULL,
    dt_carga                  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_envolvido PRIMARY KEY (numero_boletim_dw, ano, numero_envolvido)
);
COMMENT ON TABLE  stg.trf_envolvido IS 'Pessoas envolvidas tipadas, com tipo de envolvimento (indicador da fonte ou regra derivada), gravidade e flags.';
COMMENT ON COLUMN stg.trf_envolvido.numero_boletim_dw IS 'Número do boletim no dw.';
COMMENT ON COLUMN stg.trf_envolvido.ano IS 'Ano do sinistro.';
COMMENT ON COLUMN stg.trf_envolvido.numero_envolvido IS 'Número do envolvido no boletim.';
COMMENT ON COLUMN stg.trf_envolvido.tipo_envolvimento IS 'CONDUTOR, PASSAGEIRO, PEDESTRE ou NÃO INFORMADO.';
COMMENT ON COLUMN stg.trf_envolvido.origem_tipo_envolvimento IS 'INDICADOR DA FONTE (pedestre/passageiro/condutor informados) ou REGRA DERIVADA (2011–2015 e lacunas).';
COMMENT ON COLUMN stg.trf_envolvido.cod_severidade IS 'Severidade atual (0 n/i, 1 não fatal, 2 fatal, 3 sem ferimentos).';
COMMENT ON COLUMN stg.trf_envolvido.gravidade IS 'Descrição da severidade.';
COMMENT ON COLUMN stg.trf_envolvido.fl_vitima IS 'Vítima = severidade 1 (não fatal) ou 2 (fatal); ileso e não informado não são vítimas.';
COMMENT ON COLUMN stg.trf_envolvido.fl_vitima_fatal IS 'Severidade 2 (fatal).';
COMMENT ON COLUMN stg.trf_envolvido.fl_condutor IS 'Tipo de envolvimento = CONDUTOR.';
COMMENT ON COLUMN stg.trf_envolvido.fl_pedestre IS 'Tipo de envolvimento = PEDESTRE.';
COMMENT ON COLUMN stg.trf_envolvido.fl_motociclista IS 'Condutor ou passageiro de veículo do grupo Motocicleta.';
COMMENT ON COLUMN stg.trf_envolvido.sexo IS 'MASCULINO, FEMININO ou NÃO INFORMADO.';
COMMENT ON COLUMN stg.trf_envolvido.idade IS 'Idade em anos (nula quando 0 sem data de nascimento que a confirme, ou acima de 110).';
COMMENT ON COLUMN stg.trf_envolvido.faixa_etaria IS 'Faixa etária derivada da idade.';
COMMENT ON COLUMN stg.trf_envolvido.embriaguez IS 'SIM, NÃO ou NÃO INFORMADO.';
COMMENT ON COLUMN stg.trf_envolvido.especie_veiculo IS 'Espécie do veículo em que a pessoa estava (padronizada); nula para pedestre.';
COMMENT ON COLUMN stg.trf_envolvido.grupo_especie IS 'Grupo da espécie (Motocicleta, Automóvel/utilitário, Ônibus, Caminhão, Bicicleta, Outros).';
COMMENT ON COLUMN stg.trf_envolvido.arquivo_origem IS 'Linhagem: arquivo de origem.';
COMMENT ON COLUMN stg.trf_envolvido.linha_arquivo IS 'Linhagem: linha no arquivo de origem.';
COMMENT ON COLUMN stg.trf_envolvido.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_veiculo (
    numero_boletim_dw   text NOT NULL,
    ano                 smallint NOT NULL,
    sequencial_veiculo  smallint NOT NULL,
    cod_categoria       smallint NOT NULL,
    categoria           text NOT NULL,
    cod_especie         smallint NOT NULL,
    especie             text NOT NULL,
    grupo_especie       text NOT NULL,
    cod_situacao        smallint NOT NULL,
    situacao            text NOT NULL,
    arquivo_origem      text NOT NULL,
    linha_arquivo       integer NOT NULL,
    dt_carga            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_veiculo PRIMARY KEY (numero_boletim_dw, ano, sequencial_veiculo)
);
COMMENT ON TABLE  stg.trf_veiculo IS 'Veículos envolvidos tipados, com descrições padronizadas pelos códigos e grupo de espécie.';
COMMENT ON COLUMN stg.trf_veiculo.numero_boletim_dw IS 'Número do boletim no dw.';
COMMENT ON COLUMN stg.trf_veiculo.ano IS 'Ano do sinistro.';
COMMENT ON COLUMN stg.trf_veiculo.sequencial_veiculo IS 'Sequencial do veículo no boletim.';
COMMENT ON COLUMN stg.trf_veiculo.cod_categoria IS 'Código da categoria.';
COMMENT ON COLUMN stg.trf_veiculo.categoria IS 'Categoria padronizada.';
COMMENT ON COLUMN stg.trf_veiculo.cod_especie IS 'Código da espécie.';
COMMENT ON COLUMN stg.trf_veiculo.especie IS 'Espécie padronizada (pela descrição, pois o código 9 é usado para BONDE e TREM).';
COMMENT ON COLUMN stg.trf_veiculo.grupo_especie IS 'Grupo da espécie.';
COMMENT ON COLUMN stg.trf_veiculo.cod_situacao IS 'Código da situação.';
COMMENT ON COLUMN stg.trf_veiculo.situacao IS 'Situação padronizada pelo código (3 = ESTACIONADO).';
COMMENT ON COLUMN stg.trf_veiculo.arquivo_origem IS 'Linhagem: arquivo de origem.';
COMMENT ON COLUMN stg.trf_veiculo.linha_arquivo IS 'Linhagem: linha no arquivo de origem.';
COMMENT ON COLUMN stg.trf_veiculo.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_clima_hora (
    estacao_codigo        text NOT NULL,
    dt_hora_inicio_local  timestamp NOT NULL,
    dt_hora_fim_utc       timestamptz NOT NULL,
    precipitacao_mm       numeric(6,1),
    temperatura_ar_c      numeric(5,1),
    umidade_relativa_pct  numeric(5,1),
    arquivo_origem        text NOT NULL,
    dt_carga              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_clima_hora PRIMARY KEY (estacao_codigo, dt_hora_inicio_local)
);
COMMENT ON TABLE  stg.trf_clima_hora IS 'Leituras horárias do INMET convertidas de UTC para America/Sao_Paulo (zoneinfo, com horário de verão até 2019). Cada leitura cobre a hora que termina em dt_hora_fim_utc.';
COMMENT ON COLUMN stg.trf_clima_hora.estacao_codigo IS 'A521 (Pampulha) ou F501 (Cercadinho).';
COMMENT ON COLUMN stg.trf_clima_hora.dt_hora_inicio_local IS 'Início, em horário local, do intervalo de uma hora coberto pela leitura (chave de cruzamento com a hora do sinistro).';
COMMENT ON COLUMN stg.trf_clima_hora.dt_hora_fim_utc IS 'Fim do intervalo em UTC, como publicado pelo INMET.';
COMMENT ON COLUMN stg.trf_clima_hora.precipitacao_mm IS 'Precipitação no intervalo (mm); nula se ausente (-9999 ou vazio).';
COMMENT ON COLUMN stg.trf_clima_hora.temperatura_ar_c IS 'Temperatura do ar (°C).';
COMMENT ON COLUMN stg.trf_clima_hora.umidade_relativa_pct IS 'Umidade relativa (%).';
COMMENT ON COLUMN stg.trf_clima_hora.arquivo_origem IS 'Linhagem: arquivo CSV do INMET.';
COMMENT ON COLUMN stg.trf_clima_hora.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_logradouro_versao (
    cod_logradouro            integer NOT NULL,
    versao                    smallint NOT NULL,
    dt_inicio                 date NOT NULL,
    dt_fim                    date NOT NULL,
    tipo_logradouro           text NOT NULL,
    nome_logradouro           text NOT NULL,
    nome_anterior             text,
    fl_renomeacao_confirmada  boolean NOT NULL,
    variantes                 text,
    qtd_registros             integer NOT NULL,
    arquivo_origem            text NOT NULL DEFAULT 'etl.transformar (logradouros)',
    dt_carga                  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_logradouro_versao PRIMARY KEY (cod_logradouro, versao)
);
COMMENT ON TABLE  stg.trf_logradouro_versao IS 'Histórico de nomes por código de logradouro: variações de grafia consolidadas por similaridade; nova versão quando um nome sucede outro no tempo.';
COMMENT ON COLUMN stg.trf_logradouro_versao.cod_logradouro IS 'Código do logradouro no cadastro da PBH.';
COMMENT ON COLUMN stg.trf_logradouro_versao.versao IS 'Número da versão (1 = mais antiga).';
COMMENT ON COLUMN stg.trf_logradouro_versao.dt_inicio IS 'Início da vigência do nome (primeiro registro com o nome; 1900-01-01 na primeira versão).';
COMMENT ON COLUMN stg.trf_logradouro_versao.dt_fim IS 'Fim da vigência (exclusivo; 9999-12-31 na versão atual).';
COMMENT ON COLUMN stg.trf_logradouro_versao.tipo_logradouro IS 'Sigla do tipo de logradouro.';
COMMENT ON COLUMN stg.trf_logradouro_versao.nome_logradouro IS 'Nome normalizado (maiúsculas, sem acento, abreviaturas expandidas).';
COMMENT ON COLUMN stg.trf_logradouro_versao.nome_anterior IS 'Nome da versão anterior.';
COMMENT ON COLUMN stg.trf_logradouro_versao.fl_renomeacao_confirmada IS 'Verdadeiro se o campo nome_logradouro_anterior dos registros novos confirma o nome antigo.';
COMMENT ON COLUMN stg.trf_logradouro_versao.variantes IS 'Grafias consolidadas nesta versão.';
COMMENT ON COLUMN stg.trf_logradouro_versao.qtd_registros IS 'Registros do si-log nesta versão.';
COMMENT ON COLUMN stg.trf_logradouro_versao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_logradouro_versao.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_boletim_local (
    numero_boletim_dw          text NOT NULL,
    ano                        smallint NOT NULL,
    data                       date NOT NULL,
    chave_local                text NOT NULL,
    cod_logradouro_principal   integer NOT NULL,
    cod_logradouro_cruzamento  integer NOT NULL,
    cod_bairro                 integer NOT NULL,
    fl_cruzamento              boolean NOT NULL,
    origem_bairro              text NOT NULL,
    arquivo_origem             text NOT NULL DEFAULT 'etl.transformar (logradouros)',
    dt_carga                   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_boletim_local PRIMARY KEY (numero_boletim_dw, ano)
);
COMMENT ON TABLE  stg.trf_boletim_local IS 'Local de ocorrência de cada boletim (logradouro principal + cruzamento + bairro), com a chave natural da dim_local.';
COMMENT ON COLUMN stg.trf_boletim_local.numero_boletim_dw IS 'Número do boletim no dw.';
COMMENT ON COLUMN stg.trf_boletim_local.ano IS 'Ano do sinistro.';
COMMENT ON COLUMN stg.trf_boletim_local.data IS 'Data do sinistro (para escolher a versão vigente da dim_local).';
COMMENT ON COLUMN stg.trf_boletim_local.chave_local IS 'Chave natural do local: códigos dos logradouros (par ordenado nos cruzamentos) e do bairro.';
COMMENT ON COLUMN stg.trf_boletim_local.cod_logradouro_principal IS 'Código do logradouro principal (sequência 1).';
COMMENT ON COLUMN stg.trf_boletim_local.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (sequência 2); 0 se não houver.';
COMMENT ON COLUMN stg.trf_boletim_local.cod_bairro IS 'Código do bairro (imputado quando 0, ver origem_bairro).';
COMMENT ON COLUMN stg.trf_boletim_local.fl_cruzamento IS 'Verdadeiro se há logradouro de cruzamento.';
COMMENT ON COLUMN stg.trf_boletim_local.origem_bairro IS 'INFORMADO, IMPUTADO (moda do mesmo cruzamento/endereço/logradouro) ou NÃO INFORMADO.';
COMMENT ON COLUMN stg.trf_boletim_local.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_boletim_local.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_local_versao (
    chave_local                 text NOT NULL,
    versao                      smallint NOT NULL,
    dt_inicio                   date NOT NULL,
    dt_fim                      date NOT NULL,
    fl_versao_atual             boolean NOT NULL,
    cod_logradouro_principal    integer NOT NULL,
    tipo_logradouro_principal   text NOT NULL,
    nome_logradouro_principal   text NOT NULL,
    nome_anterior_principal     text,
    cod_logradouro_cruzamento   integer NOT NULL,
    tipo_logradouro_cruzamento  text,
    nome_logradouro_cruzamento  text,
    nome_anterior_cruzamento    text,
    cod_bairro                  integer NOT NULL,
    nome_bairro                 text NOT NULL,
    fl_cruzamento               boolean NOT NULL,
    descricao_local             text NOT NULL,
    descricao_local_atual       text NOT NULL,
    motivo_versao               text NOT NULL,
    arquivo_origem              text NOT NULL DEFAULT 'etl.transformar (logradouros)',
    dt_carga                    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_local_versao PRIMARY KEY (chave_local, versao)
);
COMMENT ON TABLE  stg.trf_local_versao IS 'Versões (SCD Tipo 2) de cada local: uma nova versão a cada mudança de nome do logradouro principal ou do cruzamento.';
COMMENT ON COLUMN stg.trf_local_versao.chave_local IS 'Chave natural do local.';
COMMENT ON COLUMN stg.trf_local_versao.versao IS 'Número da versão.';
COMMENT ON COLUMN stg.trf_local_versao.dt_inicio IS 'Início da vigência.';
COMMENT ON COLUMN stg.trf_local_versao.dt_fim IS 'Fim da vigência (exclusivo).';
COMMENT ON COLUMN stg.trf_local_versao.fl_versao_atual IS 'Verdadeiro na versão vigente.';
COMMENT ON COLUMN stg.trf_local_versao.cod_logradouro_principal IS 'Código do logradouro principal.';
COMMENT ON COLUMN stg.trf_local_versao.tipo_logradouro_principal IS 'Sigla do tipo do logradouro principal.';
COMMENT ON COLUMN stg.trf_local_versao.nome_logradouro_principal IS 'Nome do logradouro principal na versão.';
COMMENT ON COLUMN stg.trf_local_versao.nome_anterior_principal IS 'Nome anterior do logradouro principal.';
COMMENT ON COLUMN stg.trf_local_versao.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (0 = sem cruzamento).';
COMMENT ON COLUMN stg.trf_local_versao.tipo_logradouro_cruzamento IS 'Sigla do tipo do logradouro de cruzamento.';
COMMENT ON COLUMN stg.trf_local_versao.nome_logradouro_cruzamento IS 'Nome do logradouro de cruzamento na versão.';
COMMENT ON COLUMN stg.trf_local_versao.nome_anterior_cruzamento IS 'Nome anterior do logradouro de cruzamento.';
COMMENT ON COLUMN stg.trf_local_versao.cod_bairro IS 'Código do bairro.';
COMMENT ON COLUMN stg.trf_local_versao.nome_bairro IS 'Nome do bairro (mais recente, normalizado).';
COMMENT ON COLUMN stg.trf_local_versao.fl_cruzamento IS 'Verdadeiro se é cruzamento.';
COMMENT ON COLUMN stg.trf_local_versao.descricao_local IS 'Descrição legível na versão (ex.: AVE X x RUA Y).';
COMMENT ON COLUMN stg.trf_local_versao.descricao_local_atual IS 'Descrição com os nomes atuais (igual em todas as versões).';
COMMENT ON COLUMN stg.trf_local_versao.motivo_versao IS 'Motivo da abertura da versão.';
COMMENT ON COLUMN stg.trf_local_versao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_local_versao.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_setor2010_regional (
    cod_setor          text NOT NULL,
    cod_subdistrito    text,
    nome_subdistrito   text,
    cod_reg_limite     smallint NOT NULL,
    metodo             text NOT NULL,
    populacao          integer NOT NULL,
    arquivo_origem     text NOT NULL DEFAULT 'sql/carga (PostGIS)',
    dt_carga           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_setor2010_regional PRIMARY KEY (cod_setor)
);
COMMENT ON TABLE  stg.trf_setor2010_regional IS 'Setores censitários de 2010 alocados às 9 regionais do limite 20220601 (ponto interior do setor dentro do polígono), para obter a população de 2010 nos limites atuais.';
COMMENT ON COLUMN stg.trf_setor2010_regional.cod_setor IS 'Código do setor censitário 2010.';
COMMENT ON COLUMN stg.trf_setor2010_regional.cod_subdistrito IS 'Subdistrito IBGE do setor em 2010.';
COMMENT ON COLUMN stg.trf_setor2010_regional.nome_subdistrito IS 'Nome do subdistrito IBGE em 2010.';
COMMENT ON COLUMN stg.trf_setor2010_regional.cod_reg_limite IS 'Regional (COD_REG) em que o setor foi alocado.';
COMMENT ON COLUMN stg.trf_setor2010_regional.metodo IS 'PONTO NO POLÍGONO ou REGIONAL MAIS PRÓXIMA.';
COMMENT ON COLUMN stg.trf_setor2010_regional.populacao IS 'Pessoas residentes no setor (Pessoa13, V001).';
COMMENT ON COLUMN stg.trf_setor2010_regional.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_setor2010_regional.dt_carga IS 'Linhagem: data e hora da transformação.';

CREATE TABLE IF NOT EXISTS stg.trf_populacao (
    ano                     smallint NOT NULL,
    cod_reg_limite          smallint NOT NULL,
    populacao_residente     integer NOT NULL,
    participacao            numeric(12,10) NOT NULL,
    populacao_municipio     integer NOT NULL,
    origem_dado             text NOT NULL,
    origem_total_municipio  text NOT NULL,
    metodo_regional         text NOT NULL,
    arquivo_origem          text NOT NULL DEFAULT 'etl.transformar (populacao)',
    dt_carga                timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_trf_populacao PRIMARY KEY (ano, cod_reg_limite)
);
COMMENT ON TABLE  stg.trf_populacao IS 'População residente por regional e ano: participação da regional x população do município, com arredondamento pelo maior resto para fechar exatamente no total.';
COMMENT ON COLUMN stg.trf_populacao.ano IS 'Ano de referência (1º de julho).';
COMMENT ON COLUMN stg.trf_populacao.cod_reg_limite IS 'Código da regional (COD_REG).';
COMMENT ON COLUMN stg.trf_populacao.populacao_residente IS 'População residente estimada da regional.';
COMMENT ON COLUMN stg.trf_populacao.participacao IS 'Participação da regional na população do município.';
COMMENT ON COLUMN stg.trf_populacao.populacao_municipio IS 'População do município no ano.';
COMMENT ON COLUMN stg.trf_populacao.origem_dado IS 'CENSO, ESTIMATIVA IBGE x PROPORÇÃO, INTERPOLADO x PROPORÇÃO.';
COMMENT ON COLUMN stg.trf_populacao.origem_total_municipio IS 'Origem do total municipal (tabela SIDRA ou interpolação geométrica).';
COMMENT ON COLUMN stg.trf_populacao.metodo_regional IS 'Como a participação da regional foi obtida.';
COMMENT ON COLUMN stg.trf_populacao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';
COMMENT ON COLUMN stg.trf_populacao.dt_carga IS 'Linhagem: data e hora da transformação.';

-- ===========================================================================
-- 5. SCHEMA DW — DIMENSÕES
--    Chaves substitutas inteiras; membros especiais em todas as dimensões:
--    -1 = "Não informado" e -2 = "Não se aplica" (nenhuma FK fica nula).
-- ===========================================================================

-- 5.1 DIM_TEMPO (grão: data + hora; sk = AAAAMMDDHH; AAAAMMDD99 = sem hora) --
CREATE TABLE IF NOT EXISTS dw.dim_tempo (
    sk_tempo           integer PRIMARY KEY,
    data               date,
    ano                smallint,
    semestre           smallint,
    trimestre          smallint,
    mes                smallint,
    nome_mes           text NOT NULL,
    ano_mes            text,
    dia                smallint,
    dia_semana         smallint,
    nome_dia_semana    text NOT NULL,
    fl_fim_de_semana   boolean,
    hora               smallint,
    fl_hora_informada  boolean NOT NULL,
    faixa_horaria      text NOT NULL,
    periodo_dia        text NOT NULL,
    dt_carga           timestamptz NOT NULL DEFAULT now(),
    arquivo_origem     text NOT NULL,
    CONSTRAINT ck_dim_tempo_hora CHECK (hora IS NULL OR hora BETWEEN 0 AND 23)
);
COMMENT ON TABLE  dw.dim_tempo IS 'Dimensão tempo no grão data + hora (2010–2030). Membro "Sem hora" por dia (sk AAAAMMDD99) para boletins sem hora informada e para a fato_populacao; -1 e -2 são membros especiais.';
COMMENT ON COLUMN dw.dim_tempo.sk_tempo IS 'Chave substituta inteligente AAAAMMDDHH (HH = 99 para "Sem hora").';
COMMENT ON COLUMN dw.dim_tempo.data IS 'Data.';
COMMENT ON COLUMN dw.dim_tempo.ano IS 'Ano.';
COMMENT ON COLUMN dw.dim_tempo.semestre IS 'Semestre (1–2).';
COMMENT ON COLUMN dw.dim_tempo.trimestre IS 'Trimestre (1–4).';
COMMENT ON COLUMN dw.dim_tempo.mes IS 'Mês (1–12).';
COMMENT ON COLUMN dw.dim_tempo.nome_mes IS 'Nome do mês em português.';
COMMENT ON COLUMN dw.dim_tempo.ano_mes IS 'Ano e mês (AAAA-MM).';
COMMENT ON COLUMN dw.dim_tempo.dia IS 'Dia do mês.';
COMMENT ON COLUMN dw.dim_tempo.dia_semana IS 'Dia da semana ISO (1 = segunda ... 7 = domingo).';
COMMENT ON COLUMN dw.dim_tempo.nome_dia_semana IS 'Nome do dia da semana.';
COMMENT ON COLUMN dw.dim_tempo.fl_fim_de_semana IS 'Sábado ou domingo.';
COMMENT ON COLUMN dw.dim_tempo.hora IS 'Hora (0–23); nula no membro "Sem hora".';
COMMENT ON COLUMN dw.dim_tempo.fl_hora_informada IS 'Falso no membro "Sem hora" e nos membros especiais.';
COMMENT ON COLUMN dw.dim_tempo.faixa_horaria IS 'Faixa de 3 horas (00h–02h ... 21h–23h) ou "Hora não informada".';
COMMENT ON COLUMN dw.dim_tempo.periodo_dia IS 'Madrugada (0–5h), Manhã (6–11h), Tarde (12–17h), Noite (18–23h) ou "Hora não informada".';
COMMENT ON COLUMN dw.dim_tempo.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_tempo.arquivo_origem IS 'Linhagem: script que gerou a linha.';
CREATE INDEX IF NOT EXISTS ix_dim_tempo_data ON dw.dim_tempo (data);
CREATE INDEX IF NOT EXISTS ix_dim_tempo_ano_mes ON dw.dim_tempo (ano, mes);

-- 5.2 DIM_REGIONAL -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw.dim_regional (
    sk_regional            smallint PRIMARY KEY,
    cod_regional           smallint,
    nome_regional          text NOT NULL,
    sigla                  text,
    area_km2               numeric(10,3),
    perimetro_m            numeric(12,3),
    subdistritos_ibge      text,
    versao_limite          text,
    geom                   geometry(MultiPolygon, 4326),
    dt_carga               timestamptz NOT NULL DEFAULT now(),
    arquivo_origem         text NOT NULL,
    CONSTRAINT uq_dim_regional_cod UNIQUE (cod_regional)
);
COMMENT ON TABLE  dw.dim_regional IS 'Dimensão regional administrativa: as 9 regionais vigentes até jan/2025 (compatíveis com a série de sinistros e com o Censo 2022).';
COMMENT ON COLUMN dw.dim_regional.sk_regional IS 'Chave substituta (-1 = não informada, -2 = não se aplica).';
COMMENT ON COLUMN dw.dim_regional.cod_regional IS 'Código da regional na PBH (COD_REG = cod_regional do si-bol, 18 a 26).';
COMMENT ON COLUMN dw.dim_regional.nome_regional IS 'Nome da regional.';
COMMENT ON COLUMN dw.dim_regional.sigla IS 'Sigla da regional.';
COMMENT ON COLUMN dw.dim_regional.area_km2 IS 'Área em km² (do arquivo da PBH).';
COMMENT ON COLUMN dw.dim_regional.perimetro_m IS 'Perímetro em metros (do arquivo da PBH).';
COMMENT ON COLUMN dw.dim_regional.subdistritos_ibge IS 'Códigos dos subdistritos do IBGE que compõem a regional.';
COMMENT ON COLUMN dw.dim_regional.versao_limite IS 'Arquivo de limite de origem.';
COMMENT ON COLUMN dw.dim_regional.geom IS 'Polígono da regional (MultiPolygon, EPSG:4326).';
COMMENT ON COLUMN dw.dim_regional.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_regional.arquivo_origem IS 'Linhagem: arquivo de origem.';
CREATE INDEX IF NOT EXISTS gix_dim_regional_geom ON dw.dim_regional USING gist (geom);

-- 5.3 DIM_LOCAL (SCD Tipo 2) ---------------------------------------------------
CREATE TABLE IF NOT EXISTS dw.dim_local (
    sk_local                         integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    chave_natural                    text NOT NULL,
    versao                           smallint NOT NULL,
    cod_logradouro_principal         integer,
    tipo_logradouro_principal        text,
    nome_logradouro_principal        text NOT NULL,
    nome_anterior_principal          text,
    nome_logradouro_principal_atual  text NOT NULL,
    cod_logradouro_cruzamento        integer,
    tipo_logradouro_cruzamento       text,
    nome_logradouro_cruzamento       text,
    nome_anterior_cruzamento         text,
    nome_logradouro_cruzamento_atual text,
    cod_bairro                       integer,
    nome_bairro                      text NOT NULL,
    fl_cruzamento                    boolean NOT NULL,
    descricao_local                  text NOT NULL,
    descricao_local_atual            text NOT NULL,
    latitude                         double precision,
    longitude                        double precision,
    geom                             geometry(Point, 4326),
    qtd_pontos_geom                  integer,
    dt_inicio_vigencia               date NOT NULL,
    dt_fim_vigencia                  date NOT NULL,
    fl_versao_atual                  boolean NOT NULL,
    motivo_versao                    text,
    dt_carga                         timestamptz NOT NULL DEFAULT now(),
    arquivo_origem                   text NOT NULL,
    CONSTRAINT uq_dim_local_versao UNIQUE (chave_natural, versao),
    CONSTRAINT ck_dim_local_vigencia CHECK (dt_inicio_vigencia < dt_fim_vigencia)
);
COMMENT ON TABLE  dw.dim_local IS 'Dimensão local de ocorrência (SCD Tipo 2): logradouro principal + logradouro de cruzamento (quando houver) + bairro. Nova versão quando o nome de um logradouro muda; o nome atual fica em todas as versões.';
COMMENT ON COLUMN dw.dim_local.sk_local IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';
COMMENT ON COLUMN dw.dim_local.chave_natural IS 'Chave natural pelos códigos: logradouro(s) e bairro (par de logradouros ordenado nos cruzamentos).';
COMMENT ON COLUMN dw.dim_local.versao IS 'Número da versão do local.';
COMMENT ON COLUMN dw.dim_local.cod_logradouro_principal IS 'Código do logradouro principal (cadastro da PBH).';
COMMENT ON COLUMN dw.dim_local.tipo_logradouro_principal IS 'Tipo do logradouro principal (RUA, AVENIDA...).';
COMMENT ON COLUMN dw.dim_local.nome_logradouro_principal IS 'Nome do logradouro principal vigente na versão.';
COMMENT ON COLUMN dw.dim_local.nome_anterior_principal IS 'Nome anterior do logradouro principal (versão anterior).';
COMMENT ON COLUMN dw.dim_local.nome_logradouro_principal_atual IS 'Nome atual do logradouro principal (igual em todas as versões).';
COMMENT ON COLUMN dw.dim_local.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (nulo se não houver).';
COMMENT ON COLUMN dw.dim_local.tipo_logradouro_cruzamento IS 'Tipo do logradouro de cruzamento.';
COMMENT ON COLUMN dw.dim_local.nome_logradouro_cruzamento IS 'Nome do logradouro de cruzamento vigente na versão.';
COMMENT ON COLUMN dw.dim_local.nome_anterior_cruzamento IS 'Nome anterior do logradouro de cruzamento.';
COMMENT ON COLUMN dw.dim_local.nome_logradouro_cruzamento_atual IS 'Nome atual do logradouro de cruzamento.';
COMMENT ON COLUMN dw.dim_local.cod_bairro IS 'Código do bairro (0 = não informado).';
COMMENT ON COLUMN dw.dim_local.nome_bairro IS 'Nome do bairro (mais recente, normalizado).';
COMMENT ON COLUMN dw.dim_local.fl_cruzamento IS 'Verdadeiro se o local é um cruzamento.';
COMMENT ON COLUMN dw.dim_local.descricao_local IS 'Descrição legível na versão (ex.: "AVE AMAZONAS x RUA DOS TUPIS").';
COMMENT ON COLUMN dw.dim_local.descricao_local_atual IS 'Descrição com os nomes atuais, para rankings históricos estáveis.';
COMMENT ON COLUMN dw.dim_local.latitude IS 'Latitude do ponto representativo.';
COMMENT ON COLUMN dw.dim_local.longitude IS 'Longitude do ponto representativo.';
COMMENT ON COLUMN dw.dim_local.geom IS 'Ponto representativo dos sinistros do local (o sinistro geolocalizado mais próximo do centroide), EPSG:4326.';
COMMENT ON COLUMN dw.dim_local.qtd_pontos_geom IS 'Quantidade de sinistros geolocalizados usados no ponto representativo.';
COMMENT ON COLUMN dw.dim_local.dt_inicio_vigencia IS 'Início da vigência da versão.';
COMMENT ON COLUMN dw.dim_local.dt_fim_vigencia IS 'Fim da vigência (exclusivo; 9999-12-31 na versão atual).';
COMMENT ON COLUMN dw.dim_local.fl_versao_atual IS 'Verdadeiro na versão vigente.';
COMMENT ON COLUMN dw.dim_local.motivo_versao IS 'Motivo da abertura da versão.';
COMMENT ON COLUMN dw.dim_local.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_local.arquivo_origem IS 'Linhagem: arquivo(s) de origem.';
CREATE INDEX IF NOT EXISTS ix_dim_local_chave_vigencia ON dw.dim_local (chave_natural, dt_inicio_vigencia, dt_fim_vigencia);
CREATE INDEX IF NOT EXISTS gix_dim_local_geom ON dw.dim_local USING gist (geom);
CREATE INDEX IF NOT EXISTS ix_dim_local_descricao_trgm ON dw.dim_local USING gin (descricao_local_atual gin_trgm_ops);

-- 5.4 DIM_TIPO_SINISTRO --------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw.dim_tipo_sinistro (
    sk_tipo_sinistro     smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    cod_tipo_sinistro    text NOT NULL,
    descricao            text NOT NULL,
    descricao_origem     text,
    grupo_tipo_sinistro  text NOT NULL,
    ordem                smallint,
    dt_carga             timestamptz NOT NULL DEFAULT now(),
    arquivo_origem       text NOT NULL,
    CONSTRAINT uq_dim_tipo_sinistro_cod UNIQUE (cod_tipo_sinistro)
);
COMMENT ON TABLE  dw.dim_tipo_sinistro IS 'Dimensão tipo de sinistro, com agrupamento derivado do domínio real (colisão/abalroamento, atropelamento, choque, capotamento/tombamento, queda, outros).';
COMMENT ON COLUMN dw.dim_tipo_sinistro.sk_tipo_sinistro IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';
COMMENT ON COLUMN dw.dim_tipo_sinistro.cod_tipo_sinistro IS 'Código do tipo de sinistro (ex.: H06002).';
COMMENT ON COLUMN dw.dim_tipo_sinistro.descricao IS 'Descrição padronizada.';
COMMENT ON COLUMN dw.dim_tipo_sinistro.descricao_origem IS 'Descrição como veio na fonte.';
COMMENT ON COLUMN dw.dim_tipo_sinistro.grupo_tipo_sinistro IS 'Agrupamento analítico.';
COMMENT ON COLUMN dw.dim_tipo_sinistro.ordem IS 'Ordem de exibição.';
COMMENT ON COLUMN dw.dim_tipo_sinistro.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_tipo_sinistro.arquivo_origem IS 'Linhagem: arquivo de origem.';

-- 5.5 DIM_CONDICAO_VIA (junk) --------------------------------------------------
CREATE TABLE IF NOT EXISTS dw.dim_condicao_via (
    sk_condicao_via      smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    cod_tempo            smallint,
    condicao_climatica   text NOT NULL,
    origem_clima         text NOT NULL,
    grupo_chuva          text NOT NULL,
    cod_pavimento        smallint,
    pavimento            text NOT NULL,
    local_sinalizado     text NOT NULL,
    dt_carga             timestamptz NOT NULL DEFAULT now(),
    arquivo_origem       text NOT NULL,
    CONSTRAINT uq_dim_condicao_via UNIQUE (cod_tempo, condicao_climatica, origem_clima, cod_pavimento, local_sinalizado),
    CONSTRAINT ck_dim_condicao_via_origem CHECK (origem_clima IN ('DECLARADO NO BOLETIM', 'IMPUTADO PELO INMET', 'NÃO INFORMADO', 'NÃO SE APLICA')),
    CONSTRAINT ck_dim_condicao_via_grupo CHECK (grupo_chuva IN ('COM CHUVA', 'SEM CHUVA', 'NÃO INFORMADO', 'NÃO SE APLICA'))
);
COMMENT ON TABLE  dw.dim_condicao_via IS 'Dimensão lixo (junk) com as condições do local: clima (declarado no boletim ou imputado pelo INMET), pavimento e sinalização.';
COMMENT ON COLUMN dw.dim_condicao_via.sk_condicao_via IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';
COMMENT ON COLUMN dw.dim_condicao_via.cod_tempo IS 'Código do tempo declarado no boletim.';
COMMENT ON COLUMN dw.dim_condicao_via.condicao_climatica IS 'BOM, CHUVA, NEBLINA, NUBLADO (declarados), CHUVA (INMET), SEM CHUVA (INMET) ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_condicao_via.origem_clima IS 'DECLARADO NO BOLETIM, IMPUTADO PELO INMET ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_condicao_via.grupo_chuva IS 'Agrupamento comparável entre declarado e imputado: COM CHUVA, SEM CHUVA ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_condicao_via.cod_pavimento IS 'Código do pavimento.';
COMMENT ON COLUMN dw.dim_condicao_via.pavimento IS 'Pavimento.';
COMMENT ON COLUMN dw.dim_condicao_via.local_sinalizado IS 'SIM, NÃO ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_condicao_via.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_condicao_via.arquivo_origem IS 'Linhagem: arquivo de origem.';

-- 5.6 DIM_VEICULO (perfil) -----------------------------------------------------
CREATE TABLE IF NOT EXISTS dw.dim_veiculo (
    sk_veiculo        smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    especie           text NOT NULL,
    grupo_especie     text NOT NULL,
    categoria         text NOT NULL,
    situacao          text NOT NULL,
    fl_identificado   boolean NOT NULL,
    dt_carga          timestamptz NOT NULL DEFAULT now(),
    arquivo_origem    text NOT NULL,
    CONSTRAINT uq_dim_veiculo UNIQUE (especie, categoria, situacao)
);
COMMENT ON TABLE  dw.dim_veiculo IS 'Dimensão perfil de veículo (espécie x categoria x situação). Ligada à fato_envolvido: a pessoa herda o perfil do veículo quando o boletim tem exatamente um veículo da espécie dela.';
COMMENT ON COLUMN dw.dim_veiculo.sk_veiculo IS 'Chave substituta (-1 = não identificado, -2 = não se aplica (pedestre)).';
COMMENT ON COLUMN dw.dim_veiculo.especie IS 'Espécie do veículo.';
COMMENT ON COLUMN dw.dim_veiculo.grupo_especie IS 'Grupo da espécie (Motocicleta, Automóvel/utilitário, Ônibus, Caminhão, Bicicleta, Outros).';
COMMENT ON COLUMN dw.dim_veiculo.categoria IS 'Categoria (PARTICULAR, ALUGUEL...) ou NÃO IDENTIFICADA quando o veículo exato não pôde ser determinado.';
COMMENT ON COLUMN dw.dim_veiculo.situacao IS 'Situação (EM MOVIMENTO, PARADO...) ou NÃO IDENTIFICADA.';
COMMENT ON COLUMN dw.dim_veiculo.fl_identificado IS 'Verdadeiro se categoria e situação vêm do veículo identificado.';
COMMENT ON COLUMN dw.dim_veiculo.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_veiculo.arquivo_origem IS 'Linhagem: arquivo de origem.';

-- 5.7 DIM_PESSOA (perfil, não uma linha por pessoa) ----------------------------
CREATE TABLE IF NOT EXISTS dw.dim_pessoa (
    sk_pessoa            smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    tipo_envolvimento    text NOT NULL,
    sexo                 text NOT NULL,
    faixa_etaria         text NOT NULL,
    ordem_faixa_etaria   smallint NOT NULL,
    embriaguez           text NOT NULL,
    dt_carga             timestamptz NOT NULL DEFAULT now(),
    arquivo_origem       text NOT NULL,
    CONSTRAINT uq_dim_pessoa UNIQUE (tipo_envolvimento, sexo, faixa_etaria, embriaguez)
);
COMMENT ON TABLE  dw.dim_pessoa IS 'Dimensão perfil de pessoa envolvida (tipo de envolvimento x sexo x faixa etária x embriaguez). O cinto de segurança ficou de fora: o domínio alterna entre anos (valor padrão do sistema), ver README.';
COMMENT ON COLUMN dw.dim_pessoa.sk_pessoa IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';
COMMENT ON COLUMN dw.dim_pessoa.tipo_envolvimento IS 'CONDUTOR, PASSAGEIRO, PEDESTRE ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_pessoa.sexo IS 'MASCULINO, FEMININO ou NÃO INFORMADO.';
COMMENT ON COLUMN dw.dim_pessoa.faixa_etaria IS 'Faixa etária (0 a 9 ... 70 ou mais, Não informada).';
COMMENT ON COLUMN dw.dim_pessoa.ordem_faixa_etaria IS 'Ordem de exibição da faixa etária.';
COMMENT ON COLUMN dw.dim_pessoa.embriaguez IS 'Indício de embriaguez: SIM, NÃO ou NÃO INFORMADO (consistente a partir de 2016).';
COMMENT ON COLUMN dw.dim_pessoa.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.dim_pessoa.arquivo_origem IS 'Linhagem: origem da linha.';

-- ===========================================================================
-- 6. SCHEMA DW — FATOS
-- ===========================================================================

-- 6.1 FATO_SINISTRO (grão: um boletim; particionada por ano) -------------------
CREATE TABLE IF NOT EXISTS dw.fato_sinistro (
    numero_boletim           text NOT NULL,
    ano                      smallint NOT NULL,
    sk_tempo                 integer NOT NULL REFERENCES dw.dim_tempo (sk_tempo),
    sk_local                 integer NOT NULL REFERENCES dw.dim_local (sk_local),
    sk_tipo_sinistro         smallint NOT NULL REFERENCES dw.dim_tipo_sinistro (sk_tipo_sinistro),
    sk_condicao_via          smallint NOT NULL REFERENCES dw.dim_condicao_via (sk_condicao_via),
    sk_regional              smallint NOT NULL REFERENCES dw.dim_regional (sk_regional),
    qtd_envolvidos           smallint NOT NULL,
    qtd_vitimas              smallint NOT NULL,
    qtd_vitimas_fatais       smallint NOT NULL,
    qtd_veiculos             smallint NOT NULL,
    qtd_motocicletas         smallint NOT NULL,
    qtd_automoveis           smallint NOT NULL,
    qtd_onibus               smallint NOT NULL,
    qtd_caminhoes            smallint NOT NULL,
    qtd_bicicletas           smallint NOT NULL,
    qtd_outros_veiculos      smallint NOT NULL,
    valor_ups                smallint NOT NULL,
    fl_ups_imputada          boolean NOT NULL,
    velocidade_permitida     smallint,
    precipitacao_mm          numeric(6,1),
    estacao_inmet            text,
    fl_fatal                 boolean NOT NULL,
    fl_envolve_pedestre      boolean NOT NULL,
    fl_envolve_motociclista  boolean NOT NULL,
    fl_geolocalizado         boolean NOT NULL,
    latitude                 double precision,
    longitude                double precision,
    geom                     geometry(Point, 4326),
    origem_regional          text NOT NULL,
    dt_carga                 timestamptz NOT NULL DEFAULT now(),
    arquivo_origem           text NOT NULL,
    CONSTRAINT pk_fato_sinistro PRIMARY KEY (numero_boletim, ano),
    CONSTRAINT ck_fato_sinistro_ups CHECK (valor_ups IN (1, 5, 13)),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (qtd_vitimas_fatais <= qtd_vitimas AND qtd_vitimas <= qtd_envolvidos)
) PARTITION BY RANGE (ano);
COMMENT ON TABLE  dw.fato_sinistro IS 'Fato sinistro: uma linha por boletim de ocorrência (numero_boletim + ano), particionada por ano. Contagens de veículos por espécie respondem ao perfil da frota por local sem quebrar o grão.';
COMMENT ON COLUMN dw.fato_sinistro.numero_boletim IS 'Dimensão degenerada: número do boletim (sufixo /n para eventos distintos com o mesmo número no ano).';
COMMENT ON COLUMN dw.fato_sinistro.ano IS 'Ano do sinistro (chave de partição).';
COMMENT ON COLUMN dw.fato_sinistro.sk_tempo IS 'FK dim_tempo (data + hora; AAAAMMDD99 quando a hora não foi informada).';
COMMENT ON COLUMN dw.fato_sinistro.sk_local IS 'FK dim_local (versão vigente na data do sinistro).';
COMMENT ON COLUMN dw.fato_sinistro.sk_tipo_sinistro IS 'FK dim_tipo_sinistro.';
COMMENT ON COLUMN dw.fato_sinistro.sk_condicao_via IS 'FK dim_condicao_via.';
COMMENT ON COLUMN dw.fato_sinistro.sk_regional IS 'FK dim_regional (código do boletim; nulo/0 resolvido por ST_Within; 27 Hipercentro -> Centro-Sul).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_envolvidos IS 'Pessoas envolvidas (si_env).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_vitimas IS 'Vítimas: envolvidos com severidade não fatal ou fatal.';
COMMENT ON COLUMN dw.fato_sinistro.qtd_vitimas_fatais IS 'Vítimas fatais (severidade fatal no si_env).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_veiculos IS 'Veículos envolvidos (si-veic).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_motocicletas IS 'Veículos do grupo Motocicleta (motocicleta, motoneta, ciclomotor, triciclo).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_automoveis IS 'Veículos do grupo Automóvel/utilitário.';
COMMENT ON COLUMN dw.fato_sinistro.qtd_onibus IS 'Veículos do grupo Ônibus (ônibus e micro-ônibus).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_caminhoes IS 'Veículos do grupo Caminhão (caminhão, caminhão-trator, reboque).';
COMMENT ON COLUMN dw.fato_sinistro.qtd_bicicletas IS 'Bicicletas.';
COMMENT ON COLUMN dw.fato_sinistro.qtd_outros_veiculos IS 'Demais espécies e não informadas.';
COMMENT ON COLUMN dw.fato_sinistro.valor_ups IS 'Unidade Padrão de Severidade (1, 5 ou 13): a da fonte quando informada; senão 13 se houve morte e 5 caso contrário.';
COMMENT ON COLUMN dw.fato_sinistro.fl_ups_imputada IS 'Verdadeiro quando a UPS não veio na fonte (0 a partir de 2016) e foi derivada da severidade.';
COMMENT ON COLUMN dw.fato_sinistro.velocidade_permitida IS 'Velocidade máxima permitida (km/h) — medida NÃO aditiva; nula se não informada.';
COMMENT ON COLUMN dw.fato_sinistro.precipitacao_mm IS 'Precipitação do INMET na hora do sinistro (mm) — medida não aditiva entre sinistros.';
COMMENT ON COLUMN dw.fato_sinistro.estacao_inmet IS 'Estação usada para a precipitação (A521 Pampulha ou F501 Cercadinho).';
COMMENT ON COLUMN dw.fato_sinistro.fl_fatal IS 'Verdadeiro se houve ao menos uma vítima fatal.';
COMMENT ON COLUMN dw.fato_sinistro.fl_envolve_pedestre IS 'Verdadeiro se há pedestre envolvido ou o tipo é atropelamento de pessoa.';
COMMENT ON COLUMN dw.fato_sinistro.fl_envolve_motociclista IS 'Verdadeiro se há motocicleta (grupo) entre os veículos ou envolvidos.';
COMMENT ON COLUMN dw.fato_sinistro.fl_geolocalizado IS 'Verdadeiro se a coordenada é válida e está dentro do município.';
COMMENT ON COLUMN dw.fato_sinistro.latitude IS 'Latitude do ponto exato (WGS 84).';
COMMENT ON COLUMN dw.fato_sinistro.longitude IS 'Longitude do ponto exato (WGS 84).';
COMMENT ON COLUMN dw.fato_sinistro.geom IS 'Ponto exato do sinistro (EPSG:4326), para o mapa de calor.';
COMMENT ON COLUMN dw.fato_sinistro.origem_regional IS 'BOLETIM, ESPACIAL (ST_Within), HIPERCENTRO -> CENTRO-SUL ou NÃO RESOLVIDA.';
COMMENT ON COLUMN dw.fato_sinistro.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.fato_sinistro.arquivo_origem IS 'Linhagem: arquivo si-bol de origem.';

CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2011 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2011) TO (2012);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2012 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2012) TO (2013);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2013 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2013) TO (2014);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2014 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2014) TO (2015);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2015 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2015) TO (2016);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2016 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2016) TO (2017);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2017 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2017) TO (2018);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2018 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2018) TO (2019);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2019 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2019) TO (2020);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2020 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2020) TO (2021);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2021 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2021) TO (2022);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2022 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2022) TO (2023);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2023 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2023) TO (2024);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2024 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2024) TO (2025);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2025 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2025) TO (2026);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_2026 PARTITION OF dw.fato_sinistro FOR VALUES FROM (2026) TO (2027);
CREATE TABLE IF NOT EXISTS dw.fato_sinistro_default PARTITION OF dw.fato_sinistro DEFAULT;
COMMENT ON TABLE dw.fato_sinistro_default IS 'Partição padrão da fato_sinistro (anos fora de 2011–2026).';

CREATE INDEX IF NOT EXISTS ix_fato_sinistro_sk_tempo ON dw.fato_sinistro (sk_tempo);
CREATE INDEX IF NOT EXISTS ix_fato_sinistro_sk_local ON dw.fato_sinistro (sk_local);
CREATE INDEX IF NOT EXISTS ix_fato_sinistro_sk_tipo_sinistro ON dw.fato_sinistro (sk_tipo_sinistro);
CREATE INDEX IF NOT EXISTS ix_fato_sinistro_sk_condicao_via ON dw.fato_sinistro (sk_condicao_via);
CREATE INDEX IF NOT EXISTS ix_fato_sinistro_sk_regional ON dw.fato_sinistro (sk_regional);
CREATE INDEX IF NOT EXISTS gix_fato_sinistro_geom ON dw.fato_sinistro USING gist (geom);

-- 6.2 FATO_ENVOLVIDO (grão: uma pessoa envolvida; particionada por ano) ---------
CREATE TABLE IF NOT EXISTS dw.fato_envolvido (
    numero_boletim            text NOT NULL,
    ano                       smallint NOT NULL,
    numero_envolvido          smallint NOT NULL,
    sk_tempo                  integer NOT NULL REFERENCES dw.dim_tempo (sk_tempo),
    sk_local                  integer NOT NULL REFERENCES dw.dim_local (sk_local),
    sk_pessoa                 smallint NOT NULL REFERENCES dw.dim_pessoa (sk_pessoa),
    sk_veiculo                smallint NOT NULL REFERENCES dw.dim_veiculo (sk_veiculo),
    sk_regional               smallint NOT NULL REFERENCES dw.dim_regional (sk_regional),
    idade                     smallint,
    gravidade                 text NOT NULL,
    qtd_envolvido             smallint NOT NULL DEFAULT 1,
    fl_vitima                 boolean NOT NULL,
    fl_vitima_fatal           boolean NOT NULL,
    fl_pedestre               boolean NOT NULL,
    fl_motociclista           boolean NOT NULL,
    fl_condutor               boolean NOT NULL,
    origem_tipo_envolvimento  text NOT NULL,
    dt_carga                  timestamptz NOT NULL DEFAULT now(),
    arquivo_origem            text NOT NULL,
    CONSTRAINT pk_fato_envolvido PRIMARY KEY (numero_boletim, ano, numero_envolvido),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (NOT fl_vitima_fatal OR fl_vitima),
    CONSTRAINT ck_fato_envolvido_gravidade CHECK (gravidade IN ('FATAL', 'NÃO FATAL', 'SEM FERIMENTOS', 'NÃO INFORMADA'))
) PARTITION BY RANGE (ano);
COMMENT ON TABLE  dw.fato_envolvido IS 'Fato envolvido: uma linha por pessoa envolvida (numero_boletim + ano + número do envolvido), particionada por ano. Recebe dim_pessoa e dim_veiculo, que não cabem no grão de boletim.';
COMMENT ON COLUMN dw.fato_envolvido.numero_boletim IS 'Dimensão degenerada: número do boletim (o mesmo da fato_sinistro).';
COMMENT ON COLUMN dw.fato_envolvido.ano IS 'Ano do sinistro (chave de partição).';
COMMENT ON COLUMN dw.fato_envolvido.numero_envolvido IS 'Dimensão degenerada: número do envolvido no boletim.';
COMMENT ON COLUMN dw.fato_envolvido.sk_tempo IS 'FK dim_tempo.';
COMMENT ON COLUMN dw.fato_envolvido.sk_local IS 'FK dim_local (versão vigente na data).';
COMMENT ON COLUMN dw.fato_envolvido.sk_pessoa IS 'FK dim_pessoa (perfil).';
COMMENT ON COLUMN dw.fato_envolvido.sk_veiculo IS 'FK dim_veiculo (perfil herdado quando há exatamente um veículo da espécie da pessoa no boletim).';
COMMENT ON COLUMN dw.fato_envolvido.sk_regional IS 'FK dim_regional (dimensão conformada com a fato_sinistro; acréscimo à Fase 2).';
COMMENT ON COLUMN dw.fato_envolvido.idade IS 'Idade em anos (atributo; nula se não informada).';
COMMENT ON COLUMN dw.fato_envolvido.gravidade IS 'Dimensão degenerada: FATAL, NÃO FATAL, SEM FERIMENTOS ou NÃO INFORMADA.';
COMMENT ON COLUMN dw.fato_envolvido.qtd_envolvido IS 'Contador (sempre 1) para somas.';
COMMENT ON COLUMN dw.fato_envolvido.fl_vitima IS 'Vítima (gravidade NÃO FATAL ou FATAL); envolvido ileso não é vítima.';
COMMENT ON COLUMN dw.fato_envolvido.fl_vitima_fatal IS 'Vítima fatal.';
COMMENT ON COLUMN dw.fato_envolvido.fl_pedestre IS 'Pedestre.';
COMMENT ON COLUMN dw.fato_envolvido.fl_motociclista IS 'Condutor ou passageiro de motocicleta (grupo).';
COMMENT ON COLUMN dw.fato_envolvido.fl_condutor IS 'Condutor.';
COMMENT ON COLUMN dw.fato_envolvido.origem_tipo_envolvimento IS 'INDICADOR DA FONTE ou REGRA DERIVADA (ver README).';
COMMENT ON COLUMN dw.fato_envolvido.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.fato_envolvido.arquivo_origem IS 'Linhagem: arquivo si_env de origem.';

CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2011 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2011) TO (2012);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2012 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2012) TO (2013);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2013 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2013) TO (2014);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2014 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2014) TO (2015);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2015 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2015) TO (2016);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2016 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2016) TO (2017);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2017 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2017) TO (2018);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2018 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2018) TO (2019);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2019 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2019) TO (2020);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2020 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2020) TO (2021);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2021 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2021) TO (2022);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2022 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2022) TO (2023);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2023 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2023) TO (2024);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2024 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2024) TO (2025);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2025 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2025) TO (2026);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_2026 PARTITION OF dw.fato_envolvido FOR VALUES FROM (2026) TO (2027);
CREATE TABLE IF NOT EXISTS dw.fato_envolvido_default PARTITION OF dw.fato_envolvido DEFAULT;
COMMENT ON TABLE dw.fato_envolvido_default IS 'Partição padrão da fato_envolvido (anos fora de 2011–2026).';

CREATE INDEX IF NOT EXISTS ix_fato_envolvido_sk_tempo ON dw.fato_envolvido (sk_tempo);
CREATE INDEX IF NOT EXISTS ix_fato_envolvido_sk_local ON dw.fato_envolvido (sk_local);
CREATE INDEX IF NOT EXISTS ix_fato_envolvido_sk_pessoa ON dw.fato_envolvido (sk_pessoa);
CREATE INDEX IF NOT EXISTS ix_fato_envolvido_sk_veiculo ON dw.fato_envolvido (sk_veiculo);
CREATE INDEX IF NOT EXISTS ix_fato_envolvido_sk_regional ON dw.fato_envolvido (sk_regional);

-- 6.3 FATO_POPULACAO (grão: regional x ano) ------------------------------------
CREATE TABLE IF NOT EXISTS dw.fato_populacao (
    sk_regional             smallint NOT NULL REFERENCES dw.dim_regional (sk_regional),
    sk_tempo                integer NOT NULL REFERENCES dw.dim_tempo (sk_tempo),
    ano                     smallint NOT NULL,
    populacao_residente     integer NOT NULL CHECK (populacao_residente > 0),
    participacao_regional   numeric(12,10) NOT NULL,
    populacao_municipio     integer NOT NULL,
    origem_dado             text NOT NULL,
    origem_total_municipio  text NOT NULL,
    metodo_regional         text NOT NULL,
    dt_carga                timestamptz NOT NULL DEFAULT now(),
    arquivo_origem          text NOT NULL,
    CONSTRAINT pk_fato_populacao PRIMARY KEY (sk_regional, ano)
);
COMMENT ON TABLE  dw.fato_populacao IS 'Fato população residente por regional e ano (referência 1º de julho, membro "Sem hora" da dim_tempo). Denominador das taxas por 100 mil habitantes.';
COMMENT ON COLUMN dw.fato_populacao.sk_regional IS 'FK dim_regional.';
COMMENT ON COLUMN dw.fato_populacao.sk_tempo IS 'FK dim_tempo: 1º de julho do ano, membro "Sem hora" (AAAA070199).';
COMMENT ON COLUMN dw.fato_populacao.ano IS 'Ano de referência.';
COMMENT ON COLUMN dw.fato_populacao.populacao_residente IS 'População residente da regional (medida semiaditiva: soma entre regionais, não entre anos).';
COMMENT ON COLUMN dw.fato_populacao.participacao_regional IS 'Participação da regional na população do município.';
COMMENT ON COLUMN dw.fato_populacao.populacao_municipio IS 'População do município no ano (as regionais somam exatamente este total).';
COMMENT ON COLUMN dw.fato_populacao.origem_dado IS 'CENSO, ESTIMATIVA IBGE x PROPORÇÃO ou INTERPOLADO x PROPORÇÃO.';
COMMENT ON COLUMN dw.fato_populacao.origem_total_municipio IS 'Origem do total municipal (tabela SIDRA ou interpolação).';
COMMENT ON COLUMN dw.fato_populacao.metodo_regional IS 'Método da participação da regional (Censo 2022, Censo 2010 por setores ou interpolação linear 2010–2022).';
COMMENT ON COLUMN dw.fato_populacao.dt_carga IS 'Linhagem: data e hora da carga.';
COMMENT ON COLUMN dw.fato_populacao.arquivo_origem IS 'Linhagem: arquivos de origem.';
CREATE INDEX IF NOT EXISTS ix_fato_populacao_sk_tempo ON dw.fato_populacao (sk_tempo);

-- ===========================================================================
-- 7. SCHEMA DW — VIEWS MATERIALIZADAS (criadas sem dados; REFRESH na carga)
-- ===========================================================================

-- 7.1 Taxa de mortos por 100 mil hab. x meta 2030 ------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.mv_taxa_mortalidade_anual AS
WITH pop AS (
    SELECT p.ano, sum(p.populacao_residente) AS populacao,
           string_agg(DISTINCT p.origem_total_municipio, '; ') AS origem_populacao
    FROM dw.fato_populacao p
    GROUP BY p.ano
), sin AS (
    SELECT f.ano, count(*) AS sinistros, sum(f.qtd_vitimas) AS vitimas,
           sum(f.qtd_vitimas_fatais) AS mortos
    FROM dw.fato_sinistro f
    GROUP BY f.ano
), base AS (
    SELECT s.mortos * 100000.0 / p.populacao AS taxa_2014
    FROM sin s JOIN pop p ON p.ano = s.ano
    WHERE s.ano = 2014
)
SELECT s.ano,
       p.populacao,
       p.origem_populacao,
       s.sinistros,
       s.vitimas,
       s.mortos,
       round(s.mortos * 100000.0 / p.populacao, 3)                         AS taxa_mortos_100mil,
       round(s.vitimas * 100000.0 / p.populacao, 2)                        AS taxa_vitimas_100mil,
       round(b.taxa_2014, 3)                                               AS taxa_base_2014,
       round(b.taxa_2014 * 0.5, 3)                                         AS meta_2030,
       round(s.mortos * 100000.0 / p.populacao - b.taxa_2014 * 0.5, 3)     AS distancia_meta,
       round(100 * (1 - (s.mortos * 100000.0 / p.populacao) / b.taxa_2014), 1) AS pct_reducao_vs_2014
FROM sin s
JOIN pop p ON p.ano = s.ano
CROSS JOIN base b
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW dw.mv_taxa_mortalidade_anual IS 'Taxa anual de mortos no trânsito por 100 mil habitantes, meta municipal (50% da taxa de 2014 até 2030) e distância até a meta.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.ano IS 'Ano.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.populacao IS 'População do município (soma das regionais).';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.origem_populacao IS 'Origem do total populacional.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.sinistros IS 'Sinistros com vítima.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.vitimas IS 'Vítimas (feridos + mortos).';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.mortos IS 'Vítimas fatais registradas nos boletins.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_mortos_100mil IS 'Mortos por 100 mil habitantes.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_vitimas_100mil IS 'Vítimas por 100 mil habitantes.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_base_2014 IS 'Taxa de mortos de 2014 (ano-base da meta).';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.meta_2030 IS 'Meta para 2030: 50% da taxa de 2014.';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.distancia_meta IS 'Taxa do ano menos a meta (positivo = acima da meta).';
COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.pct_reducao_vs_2014 IS 'Redução percentual da taxa em relação a 2014.';
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_taxa_mortalidade_anual ON dw.mv_taxa_mortalidade_anual (ano);

-- 7.2 Sinistros, vítimas, mortos e taxas por regional e ano --------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.mv_indicadores_regional_ano AS
SELECT f.ano,
       r.sk_regional,
       r.cod_regional,
       r.nome_regional,
       r.sigla,
       count(*)                                  AS sinistros,
       count(*) FILTER (WHERE f.fl_fatal)        AS sinistros_fatais,
       sum(f.qtd_vitimas)                        AS vitimas,
       sum(f.qtd_vitimas_fatais)                 AS mortos,
       sum(f.valor_ups)                          AS ups,
       max(p.populacao_residente)                AS populacao,
       round(count(*) * 100000.0 / nullif(max(p.populacao_residente), 0), 2)                 AS taxa_sinistros_100mil,
       round(sum(f.qtd_vitimas) * 100000.0 / nullif(max(p.populacao_residente), 0), 2)       AS taxa_vitimas_100mil,
       round(sum(f.qtd_vitimas_fatais) * 100000.0 / nullif(max(p.populacao_residente), 0), 3) AS taxa_mortos_100mil
FROM dw.fato_sinistro f
JOIN dw.dim_regional r ON r.sk_regional = f.sk_regional
LEFT JOIN dw.fato_populacao p ON p.sk_regional = f.sk_regional AND p.ano = f.ano
GROUP BY f.ano, r.sk_regional, r.cod_regional, r.nome_regional, r.sigla
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW dw.mv_indicadores_regional_ano IS 'Sinistros, vítimas, mortos, UPS e taxas por 100 mil habitantes por regional e ano (risco ajustado pela população).';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.ano IS 'Ano.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sk_regional IS 'Chave da regional.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.cod_regional IS 'Código da regional.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.nome_regional IS 'Nome da regional.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sigla IS 'Sigla da regional.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sinistros IS 'Sinistros com vítima.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sinistros_fatais IS 'Sinistros com ao menos uma morte.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.vitimas IS 'Vítimas.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.mortos IS 'Vítimas fatais.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.ups IS 'Soma da Unidade Padrão de Severidade.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.populacao IS 'População residente da regional no ano.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_sinistros_100mil IS 'Sinistros por 100 mil habitantes.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_vitimas_100mil IS 'Vítimas por 100 mil habitantes.';
COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_mortos_100mil IS 'Mortos por 100 mil habitantes.';
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_indicadores_regional_ano ON dw.mv_indicadores_regional_ano (ano, sk_regional);

-- 7.3 Ranking de locais e cruzamentos ------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.mv_ranking_locais AS
SELECT l.chave_natural,
       f.ano,
       max(l.descricao_local_atual)               AS descricao_local_atual,
       bool_or(l.fl_cruzamento)                   AS fl_cruzamento,
       max(l.nome_bairro)                         AS nome_bairro,
       count(*)                                   AS sinistros,
       sum(f.qtd_vitimas)                         AS vitimas,
       sum(f.qtd_vitimas_fatais)                  AS mortos,
       sum(f.valor_ups)                           AS ups,
       count(*) FILTER (WHERE f.fl_envolve_pedestre)      AS sinistros_com_pedestre,
       count(*) FILTER (WHERE f.fl_envolve_motociclista)  AS sinistros_com_motocicleta,
       rank() OVER (PARTITION BY f.ano ORDER BY sum(f.valor_ups) DESC)  AS rank_ups_ano,
       rank() OVER (PARTITION BY f.ano ORDER BY count(*) DESC)          AS rank_sinistros_ano,
       max(l.latitude)                            AS latitude,
       max(l.longitude)                           AS longitude
FROM dw.fato_sinistro f
JOIN dw.dim_local l ON l.sk_local = f.sk_local
WHERE f.sk_local > 0
GROUP BY l.chave_natural, f.ano
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW dw.mv_ranking_locais IS 'Ranking de locais e cruzamentos por ano (sinistros, vítimas, mortos, UPS), agregando todas as versões do local pela chave natural e exibindo o nome atual.';
COMMENT ON COLUMN dw.mv_ranking_locais.chave_natural IS 'Chave natural do local.';
COMMENT ON COLUMN dw.mv_ranking_locais.ano IS 'Ano.';
COMMENT ON COLUMN dw.mv_ranking_locais.descricao_local_atual IS 'Descrição do local com os nomes atuais.';
COMMENT ON COLUMN dw.mv_ranking_locais.fl_cruzamento IS 'Verdadeiro se é cruzamento.';
COMMENT ON COLUMN dw.mv_ranking_locais.nome_bairro IS 'Bairro.';
COMMENT ON COLUMN dw.mv_ranking_locais.sinistros IS 'Sinistros com vítima.';
COMMENT ON COLUMN dw.mv_ranking_locais.vitimas IS 'Vítimas.';
COMMENT ON COLUMN dw.mv_ranking_locais.mortos IS 'Vítimas fatais.';
COMMENT ON COLUMN dw.mv_ranking_locais.ups IS 'Soma da UPS (severidade ponderada).';
COMMENT ON COLUMN dw.mv_ranking_locais.sinistros_com_pedestre IS 'Sinistros com pedestre envolvido.';
COMMENT ON COLUMN dw.mv_ranking_locais.sinistros_com_motocicleta IS 'Sinistros com motocicleta envolvida.';
COMMENT ON COLUMN dw.mv_ranking_locais.rank_ups_ano IS 'Posição no ano pela UPS.';
COMMENT ON COLUMN dw.mv_ranking_locais.rank_sinistros_ano IS 'Posição no ano pelo número de sinistros.';
COMMENT ON COLUMN dw.mv_ranking_locais.latitude IS 'Latitude do ponto representativo do local.';
COMMENT ON COLUMN dw.mv_ranking_locais.longitude IS 'Longitude do ponto representativo do local.';
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_ranking_locais ON dw.mv_ranking_locais (chave_natural, ano);

-- 7.4 Participação de pedestres e motociclistas nas vítimas ---------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.mv_participacao_vitimas_ano AS
SELECT e.ano,
       count(*) FILTER (WHERE e.fl_vitima)                           AS vitimas,
       count(*) FILTER (WHERE e.fl_vitima AND e.fl_pedestre)         AS vitimas_pedestres,
       count(*) FILTER (WHERE e.fl_vitima AND e.fl_motociclista)     AS vitimas_motociclistas,
       round(100.0 * count(*) FILTER (WHERE e.fl_vitima AND e.fl_pedestre)
             / nullif(count(*) FILTER (WHERE e.fl_vitima), 0), 2)    AS pct_vitimas_pedestres,
       round(100.0 * count(*) FILTER (WHERE e.fl_vitima AND e.fl_motociclista)
             / nullif(count(*) FILTER (WHERE e.fl_vitima), 0), 2)    AS pct_vitimas_motociclistas,
       count(*) FILTER (WHERE e.fl_vitima_fatal)                     AS mortos,
       count(*) FILTER (WHERE e.fl_vitima_fatal AND e.fl_pedestre)   AS mortos_pedestres,
       count(*) FILTER (WHERE e.fl_vitima_fatal AND e.fl_motociclista) AS mortos_motociclistas,
       round(100.0 * count(*) FILTER (WHERE e.fl_vitima_fatal AND e.fl_pedestre)
             / nullif(count(*) FILTER (WHERE e.fl_vitima_fatal), 0), 2) AS pct_mortos_pedestres,
       round(100.0 * count(*) FILTER (WHERE e.fl_vitima_fatal AND e.fl_motociclista)
             / nullif(count(*) FILTER (WHERE e.fl_vitima_fatal), 0), 2) AS pct_mortos_motociclistas
FROM dw.fato_envolvido e
GROUP BY e.ano
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW dw.mv_participacao_vitimas_ano IS 'Participação de pedestres e motociclistas (grupos prioritários) nas vítimas e nos mortos, por ano.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.ano IS 'Ano.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas IS 'Total de vítimas.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas_pedestres IS 'Vítimas pedestres.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas_motociclistas IS 'Vítimas motociclistas (condutores e passageiros).';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_vitimas_pedestres IS 'Percentual de pedestres nas vítimas.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_vitimas_motociclistas IS 'Percentual de motociclistas nas vítimas.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos IS 'Total de mortos.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos_pedestres IS 'Mortos pedestres.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos_motociclistas IS 'Mortos motociclistas.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_mortos_pedestres IS 'Percentual de pedestres nos mortos.';
COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_mortos_motociclistas IS 'Percentual de motociclistas nos mortos.';
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_participacao_vitimas_ano ON dw.mv_participacao_vitimas_ano (ano);

-- Fim do DDL
