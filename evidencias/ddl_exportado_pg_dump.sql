--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg110+1)
-- Dumped by pg_dump version 16.9 (Debian 16.9-1.pgdg110+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: dw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA dw;


--
-- Name: SCHEMA dw; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA dw IS 'Data Warehouse: modelo estrela (3 fatos e 7 dimensões) e views materializadas de indicadores.';


--
-- Name: stg; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA stg;


--
-- Name: SCHEMA stg; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA stg IS 'Staging: espelho das fontes (tudo como texto, sem regra de negócio), tabelas de trabalho da transformação, log de carga e resultados dos testes de qualidade.';


--
-- Name: tiger; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tiger;


--
-- Name: tiger_data; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tiger_data;


--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_tiger_geocoder; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;


--
-- Name: EXTENSION postgis_tiger_geocoder; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_tiger_geocoder IS 'PostGIS tiger geocoder and reverse geocoder';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dim_condicao_via; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_condicao_via (
    sk_condicao_via smallint NOT NULL,
    cod_tempo smallint,
    condicao_climatica text NOT NULL,
    origem_clima text NOT NULL,
    grupo_chuva text NOT NULL,
    cod_pavimento smallint,
    pavimento text NOT NULL,
    local_sinalizado text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_dim_condicao_via_grupo CHECK ((grupo_chuva = ANY (ARRAY['COM CHUVA'::text, 'SEM CHUVA'::text, 'NÃO INFORMADO'::text, 'NÃO SE APLICA'::text]))),
    CONSTRAINT ck_dim_condicao_via_origem CHECK ((origem_clima = ANY (ARRAY['DECLARADO NO BOLETIM'::text, 'IMPUTADO PELO INMET'::text, 'NÃO INFORMADO'::text, 'NÃO SE APLICA'::text])))
);


--
-- Name: TABLE dim_condicao_via; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_condicao_via IS 'Dimensão lixo (junk) com as condições do local: clima (declarado no boletim ou imputado pelo INMET), pavimento e sinalização.';


--
-- Name: COLUMN dim_condicao_via.sk_condicao_via; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.sk_condicao_via IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';


--
-- Name: COLUMN dim_condicao_via.cod_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.cod_tempo IS 'Código do tempo declarado no boletim.';


--
-- Name: COLUMN dim_condicao_via.condicao_climatica; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.condicao_climatica IS 'BOM, CHUVA, NEBLINA, NUBLADO (declarados), CHUVA (INMET), SEM CHUVA (INMET) ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_condicao_via.origem_clima; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.origem_clima IS 'DECLARADO NO BOLETIM, IMPUTADO PELO INMET ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_condicao_via.grupo_chuva; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.grupo_chuva IS 'Agrupamento comparável entre declarado e imputado: COM CHUVA, SEM CHUVA ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_condicao_via.cod_pavimento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.cod_pavimento IS 'Código do pavimento.';


--
-- Name: COLUMN dim_condicao_via.pavimento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.pavimento IS 'Pavimento.';


--
-- Name: COLUMN dim_condicao_via.local_sinalizado; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.local_sinalizado IS 'SIM, NÃO ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_condicao_via.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_condicao_via.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_condicao_via.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: dim_condicao_via_sk_condicao_via_seq; Type: SEQUENCE; Schema: dw; Owner: -
--

ALTER TABLE dw.dim_condicao_via ALTER COLUMN sk_condicao_via ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dw.dim_condicao_via_sk_condicao_via_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_local; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_local (
    sk_local integer NOT NULL,
    chave_natural text NOT NULL,
    versao smallint NOT NULL,
    cod_logradouro_principal integer,
    tipo_logradouro_principal text,
    nome_logradouro_principal text NOT NULL,
    nome_anterior_principal text,
    nome_logradouro_principal_atual text NOT NULL,
    cod_logradouro_cruzamento integer,
    tipo_logradouro_cruzamento text,
    nome_logradouro_cruzamento text,
    nome_anterior_cruzamento text,
    nome_logradouro_cruzamento_atual text,
    cod_bairro integer,
    nome_bairro text NOT NULL,
    fl_cruzamento boolean NOT NULL,
    descricao_local text NOT NULL,
    descricao_local_atual text NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    qtd_pontos_geom integer,
    dt_inicio_vigencia date NOT NULL,
    dt_fim_vigencia date NOT NULL,
    fl_versao_atual boolean NOT NULL,
    motivo_versao text,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_dim_local_vigencia CHECK ((dt_inicio_vigencia < dt_fim_vigencia))
);


--
-- Name: TABLE dim_local; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_local IS 'Dimensão local de ocorrência (SCD Tipo 2): logradouro principal + logradouro de cruzamento (quando houver) + bairro. Nova versão quando o nome de um logradouro muda; o nome atual fica em todas as versões.';


--
-- Name: COLUMN dim_local.sk_local; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.sk_local IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';


--
-- Name: COLUMN dim_local.chave_natural; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.chave_natural IS 'Chave natural pelos códigos: logradouro(s) e bairro (par de logradouros ordenado nos cruzamentos).';


--
-- Name: COLUMN dim_local.versao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.versao IS 'Número da versão do local.';


--
-- Name: COLUMN dim_local.cod_logradouro_principal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.cod_logradouro_principal IS 'Código do logradouro principal (cadastro da PBH).';


--
-- Name: COLUMN dim_local.tipo_logradouro_principal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.tipo_logradouro_principal IS 'Tipo do logradouro principal (RUA, AVENIDA...).';


--
-- Name: COLUMN dim_local.nome_logradouro_principal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_logradouro_principal IS 'Nome do logradouro principal vigente na versão.';


--
-- Name: COLUMN dim_local.nome_anterior_principal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_anterior_principal IS 'Nome anterior do logradouro principal (versão anterior).';


--
-- Name: COLUMN dim_local.nome_logradouro_principal_atual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_logradouro_principal_atual IS 'Nome atual do logradouro principal (igual em todas as versões).';


--
-- Name: COLUMN dim_local.cod_logradouro_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (nulo se não houver).';


--
-- Name: COLUMN dim_local.tipo_logradouro_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.tipo_logradouro_cruzamento IS 'Tipo do logradouro de cruzamento.';


--
-- Name: COLUMN dim_local.nome_logradouro_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_logradouro_cruzamento IS 'Nome do logradouro de cruzamento vigente na versão.';


--
-- Name: COLUMN dim_local.nome_anterior_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_anterior_cruzamento IS 'Nome anterior do logradouro de cruzamento.';


--
-- Name: COLUMN dim_local.nome_logradouro_cruzamento_atual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_logradouro_cruzamento_atual IS 'Nome atual do logradouro de cruzamento.';


--
-- Name: COLUMN dim_local.cod_bairro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.cod_bairro IS 'Código do bairro (0 = não informado).';


--
-- Name: COLUMN dim_local.nome_bairro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.nome_bairro IS 'Nome do bairro (mais recente, normalizado).';


--
-- Name: COLUMN dim_local.fl_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.fl_cruzamento IS 'Verdadeiro se o local é um cruzamento.';


--
-- Name: COLUMN dim_local.descricao_local; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.descricao_local IS 'Descrição legível na versão (ex.: "AVE AMAZONAS x RUA DOS TUPIS").';


--
-- Name: COLUMN dim_local.descricao_local_atual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.descricao_local_atual IS 'Descrição com os nomes atuais, para rankings históricos estáveis.';


--
-- Name: COLUMN dim_local.latitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.latitude IS 'Latitude do ponto representativo.';


--
-- Name: COLUMN dim_local.longitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.longitude IS 'Longitude do ponto representativo.';


--
-- Name: COLUMN dim_local.geom; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.geom IS 'Ponto representativo dos sinistros do local (o sinistro geolocalizado mais próximo do centroide), EPSG:4326.';


--
-- Name: COLUMN dim_local.qtd_pontos_geom; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.qtd_pontos_geom IS 'Quantidade de sinistros geolocalizados usados no ponto representativo.';


--
-- Name: COLUMN dim_local.dt_inicio_vigencia; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.dt_inicio_vigencia IS 'Início da vigência da versão.';


--
-- Name: COLUMN dim_local.dt_fim_vigencia; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.dt_fim_vigencia IS 'Fim da vigência (exclusivo; 9999-12-31 na versão atual).';


--
-- Name: COLUMN dim_local.fl_versao_atual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.fl_versao_atual IS 'Verdadeiro na versão vigente.';


--
-- Name: COLUMN dim_local.motivo_versao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.motivo_versao IS 'Motivo da abertura da versão.';


--
-- Name: COLUMN dim_local.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_local.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_local.arquivo_origem IS 'Linhagem: arquivo(s) de origem.';


--
-- Name: dim_local_sk_local_seq; Type: SEQUENCE; Schema: dw; Owner: -
--

ALTER TABLE dw.dim_local ALTER COLUMN sk_local ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dw.dim_local_sk_local_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_pessoa; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_pessoa (
    sk_pessoa smallint NOT NULL,
    tipo_envolvimento text NOT NULL,
    sexo text NOT NULL,
    faixa_etaria text NOT NULL,
    ordem_faixa_etaria smallint NOT NULL,
    embriaguez text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL
);


--
-- Name: TABLE dim_pessoa; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_pessoa IS 'Dimensão perfil de pessoa envolvida (tipo de envolvimento x sexo x faixa etária x embriaguez). O cinto de segurança ficou de fora: o domínio alterna entre anos (valor padrão do sistema), ver README.';


--
-- Name: COLUMN dim_pessoa.sk_pessoa; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.sk_pessoa IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';


--
-- Name: COLUMN dim_pessoa.tipo_envolvimento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.tipo_envolvimento IS 'CONDUTOR, PASSAGEIRO, PEDESTRE ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_pessoa.sexo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.sexo IS 'MASCULINO, FEMININO ou NÃO INFORMADO.';


--
-- Name: COLUMN dim_pessoa.faixa_etaria; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.faixa_etaria IS 'Faixa etária (0 a 9 ... 70 ou mais, Não informada).';


--
-- Name: COLUMN dim_pessoa.ordem_faixa_etaria; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.ordem_faixa_etaria IS 'Ordem de exibição da faixa etária.';


--
-- Name: COLUMN dim_pessoa.embriaguez; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.embriaguez IS 'Indício de embriaguez: SIM, NÃO ou NÃO INFORMADO (consistente a partir de 2016).';


--
-- Name: COLUMN dim_pessoa.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_pessoa.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_pessoa.arquivo_origem IS 'Linhagem: origem da linha.';


--
-- Name: dim_pessoa_sk_pessoa_seq; Type: SEQUENCE; Schema: dw; Owner: -
--

ALTER TABLE dw.dim_pessoa ALTER COLUMN sk_pessoa ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dw.dim_pessoa_sk_pessoa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_regional; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_regional (
    sk_regional smallint NOT NULL,
    cod_regional smallint,
    nome_regional text NOT NULL,
    sigla text,
    area_km2 numeric(10,3),
    perimetro_m numeric(12,3),
    subdistritos_ibge text,
    versao_limite text,
    geom public.geometry(MultiPolygon,4326),
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL
);


--
-- Name: TABLE dim_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_regional IS 'Dimensão regional administrativa: as 9 regionais vigentes até jan/2025 (compatíveis com a série de sinistros e com o Censo 2022).';


--
-- Name: COLUMN dim_regional.sk_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.sk_regional IS 'Chave substituta (-1 = não informada, -2 = não se aplica).';


--
-- Name: COLUMN dim_regional.cod_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.cod_regional IS 'Código da regional na PBH (COD_REG = cod_regional do si-bol, 18 a 26).';


--
-- Name: COLUMN dim_regional.nome_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.nome_regional IS 'Nome da regional.';


--
-- Name: COLUMN dim_regional.sigla; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.sigla IS 'Sigla da regional.';


--
-- Name: COLUMN dim_regional.area_km2; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.area_km2 IS 'Área em km² (do arquivo da PBH).';


--
-- Name: COLUMN dim_regional.perimetro_m; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.perimetro_m IS 'Perímetro em metros (do arquivo da PBH).';


--
-- Name: COLUMN dim_regional.subdistritos_ibge; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.subdistritos_ibge IS 'Códigos dos subdistritos do IBGE que compõem a regional.';


--
-- Name: COLUMN dim_regional.versao_limite; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.versao_limite IS 'Arquivo de limite de origem.';


--
-- Name: COLUMN dim_regional.geom; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.geom IS 'Polígono da regional (MultiPolygon, EPSG:4326).';


--
-- Name: COLUMN dim_regional.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_regional.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_regional.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: dim_tempo; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_tempo (
    sk_tempo integer NOT NULL,
    data date,
    ano smallint,
    semestre smallint,
    trimestre smallint,
    mes smallint,
    nome_mes text NOT NULL,
    ano_mes text,
    dia smallint,
    dia_semana smallint,
    nome_dia_semana text NOT NULL,
    fl_fim_de_semana boolean,
    hora smallint,
    fl_hora_informada boolean NOT NULL,
    faixa_horaria text NOT NULL,
    periodo_dia text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_dim_tempo_hora CHECK (((hora IS NULL) OR ((hora >= 0) AND (hora <= 23))))
);


--
-- Name: TABLE dim_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_tempo IS 'Dimensão tempo no grão data + hora (2010–2030). Membro "Sem hora" por dia (sk AAAAMMDD99) para boletins sem hora informada e para a fato_populacao; -1 e -2 são membros especiais.';


--
-- Name: COLUMN dim_tempo.sk_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.sk_tempo IS 'Chave substituta inteligente AAAAMMDDHH (HH = 99 para "Sem hora").';


--
-- Name: COLUMN dim_tempo.data; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.data IS 'Data.';


--
-- Name: COLUMN dim_tempo.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.ano IS 'Ano.';


--
-- Name: COLUMN dim_tempo.semestre; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.semestre IS 'Semestre (1–2).';


--
-- Name: COLUMN dim_tempo.trimestre; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.trimestre IS 'Trimestre (1–4).';


--
-- Name: COLUMN dim_tempo.mes; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.mes IS 'Mês (1–12).';


--
-- Name: COLUMN dim_tempo.nome_mes; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.nome_mes IS 'Nome do mês em português.';


--
-- Name: COLUMN dim_tempo.ano_mes; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.ano_mes IS 'Ano e mês (AAAA-MM).';


--
-- Name: COLUMN dim_tempo.dia; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.dia IS 'Dia do mês.';


--
-- Name: COLUMN dim_tempo.dia_semana; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.dia_semana IS 'Dia da semana ISO (1 = segunda ... 7 = domingo).';


--
-- Name: COLUMN dim_tempo.nome_dia_semana; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.nome_dia_semana IS 'Nome do dia da semana.';


--
-- Name: COLUMN dim_tempo.fl_fim_de_semana; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.fl_fim_de_semana IS 'Sábado ou domingo.';


--
-- Name: COLUMN dim_tempo.hora; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.hora IS 'Hora (0–23); nula no membro "Sem hora".';


--
-- Name: COLUMN dim_tempo.fl_hora_informada; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.fl_hora_informada IS 'Falso no membro "Sem hora" e nos membros especiais.';


--
-- Name: COLUMN dim_tempo.faixa_horaria; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.faixa_horaria IS 'Faixa de 3 horas (00h–02h ... 21h–23h) ou "Hora não informada".';


--
-- Name: COLUMN dim_tempo.periodo_dia; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.periodo_dia IS 'Madrugada (0–5h), Manhã (6–11h), Tarde (12–17h), Noite (18–23h) ou "Hora não informada".';


--
-- Name: COLUMN dim_tempo.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_tempo.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tempo.arquivo_origem IS 'Linhagem: script que gerou a linha.';


--
-- Name: dim_tipo_sinistro; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_tipo_sinistro (
    sk_tipo_sinistro smallint NOT NULL,
    cod_tipo_sinistro text NOT NULL,
    descricao text NOT NULL,
    descricao_origem text,
    grupo_tipo_sinistro text NOT NULL,
    ordem smallint,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL
);


--
-- Name: TABLE dim_tipo_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_tipo_sinistro IS 'Dimensão tipo de sinistro, com agrupamento derivado do domínio real (colisão/abalroamento, atropelamento, choque, capotamento/tombamento, queda, outros).';


--
-- Name: COLUMN dim_tipo_sinistro.sk_tipo_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.sk_tipo_sinistro IS 'Chave substituta (-1 = não informado, -2 = não se aplica).';


--
-- Name: COLUMN dim_tipo_sinistro.cod_tipo_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.cod_tipo_sinistro IS 'Código do tipo de sinistro (ex.: H06002).';


--
-- Name: COLUMN dim_tipo_sinistro.descricao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.descricao IS 'Descrição padronizada.';


--
-- Name: COLUMN dim_tipo_sinistro.descricao_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.descricao_origem IS 'Descrição como veio na fonte.';


--
-- Name: COLUMN dim_tipo_sinistro.grupo_tipo_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.grupo_tipo_sinistro IS 'Agrupamento analítico.';


--
-- Name: COLUMN dim_tipo_sinistro.ordem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.ordem IS 'Ordem de exibição.';


--
-- Name: COLUMN dim_tipo_sinistro.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_tipo_sinistro.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_tipo_sinistro.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: dim_tipo_sinistro_sk_tipo_sinistro_seq; Type: SEQUENCE; Schema: dw; Owner: -
--

ALTER TABLE dw.dim_tipo_sinistro ALTER COLUMN sk_tipo_sinistro ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dw.dim_tipo_sinistro_sk_tipo_sinistro_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_veiculo; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.dim_veiculo (
    sk_veiculo smallint NOT NULL,
    especie text NOT NULL,
    grupo_especie text NOT NULL,
    categoria text NOT NULL,
    situacao text NOT NULL,
    fl_identificado boolean NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL
);


--
-- Name: TABLE dim_veiculo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.dim_veiculo IS 'Dimensão perfil de veículo (espécie x categoria x situação). Ligada à fato_envolvido: a pessoa herda o perfil do veículo quando o boletim tem exatamente um veículo da espécie dela.';


--
-- Name: COLUMN dim_veiculo.sk_veiculo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.sk_veiculo IS 'Chave substituta (-1 = não identificado, -2 = não se aplica (pedestre)).';


--
-- Name: COLUMN dim_veiculo.especie; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.especie IS 'Espécie do veículo.';


--
-- Name: COLUMN dim_veiculo.grupo_especie; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.grupo_especie IS 'Grupo da espécie (Motocicleta, Automóvel/utilitário, Ônibus, Caminhão, Bicicleta, Outros).';


--
-- Name: COLUMN dim_veiculo.categoria; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.categoria IS 'Categoria (PARTICULAR, ALUGUEL...) ou NÃO IDENTIFICADA quando o veículo exato não pôde ser determinado.';


--
-- Name: COLUMN dim_veiculo.situacao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.situacao IS 'Situação (EM MOVIMENTO, PARADO...) ou NÃO IDENTIFICADA.';


--
-- Name: COLUMN dim_veiculo.fl_identificado; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.fl_identificado IS 'Verdadeiro se categoria e situação vêm do veículo identificado.';


--
-- Name: COLUMN dim_veiculo.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN dim_veiculo.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.dim_veiculo.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: dim_veiculo_sk_veiculo_seq; Type: SEQUENCE; Schema: dw; Owner: -
--

ALTER TABLE dw.dim_veiculo ALTER COLUMN sk_veiculo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dw.dim_veiculo_sk_veiculo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: fato_envolvido; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
)
PARTITION BY RANGE (ano);


--
-- Name: TABLE fato_envolvido; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.fato_envolvido IS 'Fato envolvido: uma linha por pessoa envolvida (numero_boletim + ano + número do envolvido), particionada por ano. Recebe dim_pessoa e dim_veiculo, que não cabem no grão de boletim.';


--
-- Name: COLUMN fato_envolvido.numero_boletim; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.numero_boletim IS 'Dimensão degenerada: número do boletim (o mesmo da fato_sinistro).';


--
-- Name: COLUMN fato_envolvido.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.ano IS 'Ano do sinistro (chave de partição).';


--
-- Name: COLUMN fato_envolvido.numero_envolvido; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.numero_envolvido IS 'Dimensão degenerada: número do envolvido no boletim.';


--
-- Name: COLUMN fato_envolvido.sk_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.sk_tempo IS 'FK dim_tempo.';


--
-- Name: COLUMN fato_envolvido.sk_local; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.sk_local IS 'FK dim_local (versão vigente na data).';


--
-- Name: COLUMN fato_envolvido.sk_pessoa; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.sk_pessoa IS 'FK dim_pessoa (perfil).';


--
-- Name: COLUMN fato_envolvido.sk_veiculo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.sk_veiculo IS 'FK dim_veiculo (perfil herdado quando há exatamente um veículo da espécie da pessoa no boletim).';


--
-- Name: COLUMN fato_envolvido.sk_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.sk_regional IS 'FK dim_regional (dimensão conformada com a fato_sinistro; acréscimo à Fase 2).';


--
-- Name: COLUMN fato_envolvido.idade; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.idade IS 'Idade em anos (atributo; nula se não informada).';


--
-- Name: COLUMN fato_envolvido.gravidade; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.gravidade IS 'Dimensão degenerada: FATAL, NÃO FATAL, SEM FERIMENTOS ou NÃO INFORMADA.';


--
-- Name: COLUMN fato_envolvido.qtd_envolvido; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.qtd_envolvido IS 'Contador (sempre 1) para somas.';


--
-- Name: COLUMN fato_envolvido.fl_vitima; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.fl_vitima IS 'Vítima (gravidade NÃO FATAL ou FATAL); envolvido ileso não é vítima.';


--
-- Name: COLUMN fato_envolvido.fl_vitima_fatal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.fl_vitima_fatal IS 'Vítima fatal.';


--
-- Name: COLUMN fato_envolvido.fl_pedestre; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.fl_pedestre IS 'Pedestre.';


--
-- Name: COLUMN fato_envolvido.fl_motociclista; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.fl_motociclista IS 'Condutor ou passageiro de motocicleta (grupo).';


--
-- Name: COLUMN fato_envolvido.fl_condutor; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.fl_condutor IS 'Condutor.';


--
-- Name: COLUMN fato_envolvido.origem_tipo_envolvimento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.origem_tipo_envolvimento IS 'INDICADOR DA FONTE ou REGRA DERIVADA (ver README).';


--
-- Name: COLUMN fato_envolvido.origem_especie_veiculo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.origem_especie_veiculo IS 'Origem da espécie do veículo da pessoa: INFORMADA NO BOLETIM, IMPUTADA (ESPÉCIE ÚNICA NO BOLETIM), NÃO INFORMADA ou NÃO SE APLICA (PEDESTRE).';


--
-- Name: COLUMN fato_envolvido.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN fato_envolvido.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_envolvido.arquivo_origem IS 'Linhagem: arquivo si_env de origem.';


--
-- Name: fato_envolvido_2011; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2011 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2012; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2012 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2013; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2013 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2014; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2014 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2015; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2015 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2016; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2016 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2017; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2017 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2018; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2018 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2019; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2019 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2020; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2020 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2021; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2021 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2022; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2022 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2023; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2023 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2024; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2024 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2025; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2025 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_2026; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_2026 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: fato_envolvido_default; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_envolvido_default (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_pessoa smallint NOT NULL,
    sk_veiculo smallint NOT NULL,
    sk_regional smallint NOT NULL,
    idade smallint,
    gravidade text NOT NULL,
    qtd_envolvido smallint DEFAULT 1 NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    origem_especie_veiculo text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_envolvido_gravidade CHECK ((gravidade = ANY (ARRAY['FATAL'::text, 'NÃO FATAL'::text, 'SEM FERIMENTOS'::text, 'NÃO INFORMADA'::text]))),
    CONSTRAINT ck_fato_envolvido_vitima CHECK (((NOT fl_vitima_fatal) OR fl_vitima))
);


--
-- Name: TABLE fato_envolvido_default; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.fato_envolvido_default IS 'Partição padrão da fato_envolvido (anos fora de 2011–2026).';


--
-- Name: fato_populacao; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_populacao (
    sk_regional smallint NOT NULL,
    sk_tempo integer NOT NULL,
    ano smallint NOT NULL,
    populacao_residente integer NOT NULL,
    participacao_regional numeric(12,10) NOT NULL,
    populacao_municipio integer NOT NULL,
    origem_dado text NOT NULL,
    origem_total_municipio text NOT NULL,
    metodo_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT fato_populacao_populacao_residente_check CHECK ((populacao_residente > 0))
);


--
-- Name: TABLE fato_populacao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.fato_populacao IS 'Fato população residente por regional e ano (referência 1º de julho, membro "Sem hora" da dim_tempo). Denominador das taxas por 100 mil habitantes.';


--
-- Name: COLUMN fato_populacao.sk_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.sk_regional IS 'FK dim_regional.';


--
-- Name: COLUMN fato_populacao.sk_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.sk_tempo IS 'FK dim_tempo: 1º de julho do ano, membro "Sem hora" (AAAA070199).';


--
-- Name: COLUMN fato_populacao.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.ano IS 'Ano de referência.';


--
-- Name: COLUMN fato_populacao.populacao_residente; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.populacao_residente IS 'População residente da regional (medida semiaditiva: soma entre regionais, não entre anos).';


--
-- Name: COLUMN fato_populacao.participacao_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.participacao_regional IS 'Participação da regional na população do município.';


--
-- Name: COLUMN fato_populacao.populacao_municipio; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.populacao_municipio IS 'População do município no ano (as regionais somam exatamente este total).';


--
-- Name: COLUMN fato_populacao.origem_dado; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.origem_dado IS 'CENSO, ESTIMATIVA IBGE x PROPORÇÃO ou INTERPOLADO x PROPORÇÃO.';


--
-- Name: COLUMN fato_populacao.origem_total_municipio; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.origem_total_municipio IS 'Origem do total municipal (tabela SIDRA ou interpolação).';


--
-- Name: COLUMN fato_populacao.metodo_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.metodo_regional IS 'Método da participação da regional (Censo 2022, Censo 2010 por setores ou interpolação linear 2010–2022).';


--
-- Name: COLUMN fato_populacao.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN fato_populacao.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_populacao.arquivo_origem IS 'Linhagem: arquivos de origem.';


--
-- Name: fato_sinistro; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
)
PARTITION BY RANGE (ano);


--
-- Name: TABLE fato_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.fato_sinistro IS 'Fato sinistro: uma linha por boletim de ocorrência (numero_boletim + ano), particionada por ano. Contagens de veículos por espécie respondem ao perfil da frota por local sem quebrar o grão.';


--
-- Name: COLUMN fato_sinistro.numero_boletim; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.numero_boletim IS 'Dimensão degenerada: número do boletim (sufixo /n para eventos distintos com o mesmo número no ano).';


--
-- Name: COLUMN fato_sinistro.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.ano IS 'Ano do sinistro (chave de partição).';


--
-- Name: COLUMN fato_sinistro.sk_tempo; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.sk_tempo IS 'FK dim_tempo (data + hora; AAAAMMDD99 quando a hora não foi informada).';


--
-- Name: COLUMN fato_sinistro.sk_local; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.sk_local IS 'FK dim_local (versão vigente na data do sinistro).';


--
-- Name: COLUMN fato_sinistro.sk_tipo_sinistro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.sk_tipo_sinistro IS 'FK dim_tipo_sinistro.';


--
-- Name: COLUMN fato_sinistro.sk_condicao_via; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.sk_condicao_via IS 'FK dim_condicao_via.';


--
-- Name: COLUMN fato_sinistro.sk_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.sk_regional IS 'FK dim_regional (código do boletim; 27 Hipercentro -> Centro-Sul; nulo/0 resolvido por ST_Within do ponto do boletim ou, sem ponto, do ponto representativo do local).';


--
-- Name: COLUMN fato_sinistro.qtd_envolvidos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_envolvidos IS 'Pessoas envolvidas (si_env).';


--
-- Name: COLUMN fato_sinistro.qtd_vitimas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_vitimas IS 'Vítimas: envolvidos com severidade não fatal ou fatal.';


--
-- Name: COLUMN fato_sinistro.qtd_vitimas_fatais; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_vitimas_fatais IS 'Vítimas fatais (severidade fatal no si_env).';


--
-- Name: COLUMN fato_sinistro.qtd_veiculos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_veiculos IS 'Veículos envolvidos (si-veic).';


--
-- Name: COLUMN fato_sinistro.qtd_motocicletas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_motocicletas IS 'Veículos do grupo Motocicleta (motocicleta, motoneta, ciclomotor, triciclo).';


--
-- Name: COLUMN fato_sinistro.qtd_automoveis; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_automoveis IS 'Veículos do grupo Automóvel/utilitário.';


--
-- Name: COLUMN fato_sinistro.qtd_onibus; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_onibus IS 'Veículos do grupo Ônibus (ônibus e micro-ônibus).';


--
-- Name: COLUMN fato_sinistro.qtd_caminhoes; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_caminhoes IS 'Veículos do grupo Caminhão (caminhão, caminhão-trator, reboque).';


--
-- Name: COLUMN fato_sinistro.qtd_bicicletas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_bicicletas IS 'Bicicletas.';


--
-- Name: COLUMN fato_sinistro.qtd_outros_veiculos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.qtd_outros_veiculos IS 'Demais espécies e não informadas.';


--
-- Name: COLUMN fato_sinistro.valor_ups; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.valor_ups IS 'Unidade Padrão de Severidade (1, 5 ou 13): a da fonte quando informada; senão 13 se houve morte e 5 caso contrário.';


--
-- Name: COLUMN fato_sinistro.fl_ups_imputada; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.fl_ups_imputada IS 'Verdadeiro quando a UPS não veio na fonte (0 a partir de 2016) e foi derivada da severidade.';


--
-- Name: COLUMN fato_sinistro.velocidade_permitida; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.velocidade_permitida IS 'Velocidade máxima permitida (km/h) — medida NÃO aditiva; nula se não informada.';


--
-- Name: COLUMN fato_sinistro.precipitacao_mm; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.precipitacao_mm IS 'Precipitação do INMET na hora do sinistro (mm) — medida não aditiva entre sinistros.';


--
-- Name: COLUMN fato_sinistro.estacao_inmet; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.estacao_inmet IS 'Estação usada para a precipitação (A521 Pampulha ou F501 Cercadinho).';


--
-- Name: COLUMN fato_sinistro.fl_fatal; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.fl_fatal IS 'Verdadeiro se houve ao menos uma vítima fatal.';


--
-- Name: COLUMN fato_sinistro.fl_envolve_pedestre; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.fl_envolve_pedestre IS 'Verdadeiro se há pedestre envolvido ou o tipo é atropelamento de pessoa.';


--
-- Name: COLUMN fato_sinistro.fl_envolve_motociclista; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.fl_envolve_motociclista IS 'Verdadeiro se há motocicleta (grupo) entre os veículos ou envolvidos.';


--
-- Name: COLUMN fato_sinistro.fl_geolocalizado; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.fl_geolocalizado IS 'Verdadeiro se a coordenada é válida e está dentro do município.';


--
-- Name: COLUMN fato_sinistro.latitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.latitude IS 'Latitude do ponto exato (WGS 84).';


--
-- Name: COLUMN fato_sinistro.longitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.longitude IS 'Longitude do ponto exato (WGS 84).';


--
-- Name: COLUMN fato_sinistro.geom; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.geom IS 'Ponto exato do sinistro (EPSG:4326), para o mapa de calor.';


--
-- Name: COLUMN fato_sinistro.origem_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.origem_regional IS 'BOLETIM, HIPERCENTRO -> CENTRO-SUL, ESPACIAL (ST_Within), ESPACIAL (regional mais próxima), ESPACIAL (ponto do local) ou NÃO RESOLVIDA.';


--
-- Name: COLUMN fato_sinistro.dt_carga; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: COLUMN fato_sinistro.arquivo_origem; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.fato_sinistro.arquivo_origem IS 'Linhagem: arquivo si-bol de origem.';


--
-- Name: fato_sinistro_2011; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2011 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2012; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2012 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2013; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2013 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2014; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2014 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2015; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2015 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2016; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2016 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2017; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2017 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2018; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2018 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2019; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2019 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2020; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2020 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2021; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2021 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2022; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2022 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2023; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2023 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2024; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2024 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2025; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2025 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_2026; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_2026 (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: fato_sinistro_default; Type: TABLE; Schema: dw; Owner: -
--

CREATE TABLE dw.fato_sinistro_default (
    numero_boletim text NOT NULL,
    ano smallint NOT NULL,
    sk_tempo integer NOT NULL,
    sk_local integer NOT NULL,
    sk_tipo_sinistro smallint NOT NULL,
    sk_condicao_via smallint NOT NULL,
    sk_regional smallint NOT NULL,
    qtd_envolvidos smallint NOT NULL,
    qtd_vitimas smallint NOT NULL,
    qtd_vitimas_fatais smallint NOT NULL,
    qtd_veiculos smallint NOT NULL,
    qtd_motocicletas smallint NOT NULL,
    qtd_automoveis smallint NOT NULL,
    qtd_onibus smallint NOT NULL,
    qtd_caminhoes smallint NOT NULL,
    qtd_bicicletas smallint NOT NULL,
    qtd_outros_veiculos smallint NOT NULL,
    valor_ups smallint NOT NULL,
    fl_ups_imputada boolean NOT NULL,
    velocidade_permitida smallint,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    fl_fatal boolean NOT NULL,
    fl_envolve_pedestre boolean NOT NULL,
    fl_envolve_motociclista boolean NOT NULL,
    fl_geolocalizado boolean NOT NULL,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    origem_regional text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    arquivo_origem text NOT NULL,
    CONSTRAINT ck_fato_sinistro_ups CHECK ((valor_ups = ANY (ARRAY[1, 5, 13]))),
    CONSTRAINT ck_fato_sinistro_vitimas CHECK (((qtd_vitimas_fatais <= qtd_vitimas) AND (qtd_vitimas <= qtd_envolvidos)))
);


--
-- Name: TABLE fato_sinistro_default; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON TABLE dw.fato_sinistro_default IS 'Partição padrão da fato_sinistro (anos fora de 2011–2026).';


--
-- Name: mv_indicadores_regional_ano; Type: MATERIALIZED VIEW; Schema: dw; Owner: -
--

CREATE MATERIALIZED VIEW dw.mv_indicadores_regional_ano AS
 SELECT f.ano,
    r.sk_regional,
    r.cod_regional,
    r.nome_regional,
    r.sigla,
    count(*) AS sinistros,
    count(*) FILTER (WHERE f.fl_fatal) AS sinistros_fatais,
    sum(f.qtd_vitimas) AS vitimas,
    sum(f.qtd_vitimas_fatais) AS mortos,
    sum(f.valor_ups) AS ups,
    max(p.populacao_residente) AS populacao,
    round((((count(*))::numeric * 100000.0) / (NULLIF(max(p.populacao_residente), 0))::numeric), 2) AS taxa_sinistros_100mil,
    round((((sum(f.qtd_vitimas))::numeric * 100000.0) / (NULLIF(max(p.populacao_residente), 0))::numeric), 2) AS taxa_vitimas_100mil,
    round((((sum(f.qtd_vitimas_fatais))::numeric * 100000.0) / (NULLIF(max(p.populacao_residente), 0))::numeric), 3) AS taxa_mortos_100mil
   FROM ((dw.fato_sinistro f
     JOIN dw.dim_regional r ON ((r.sk_regional = f.sk_regional)))
     LEFT JOIN dw.fato_populacao p ON (((p.sk_regional = f.sk_regional) AND (p.ano = f.ano))))
  GROUP BY f.ano, r.sk_regional, r.cod_regional, r.nome_regional, r.sigla
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_indicadores_regional_ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON MATERIALIZED VIEW dw.mv_indicadores_regional_ano IS 'Sinistros, vítimas, mortos, UPS e taxas por 100 mil habitantes por regional e ano (risco ajustado pela população).';


--
-- Name: COLUMN mv_indicadores_regional_ano.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.ano IS 'Ano.';


--
-- Name: COLUMN mv_indicadores_regional_ano.sk_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sk_regional IS 'Chave da regional.';


--
-- Name: COLUMN mv_indicadores_regional_ano.cod_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.cod_regional IS 'Código da regional.';


--
-- Name: COLUMN mv_indicadores_regional_ano.nome_regional; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.nome_regional IS 'Nome da regional.';


--
-- Name: COLUMN mv_indicadores_regional_ano.sigla; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sigla IS 'Sigla da regional.';


--
-- Name: COLUMN mv_indicadores_regional_ano.sinistros; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sinistros IS 'Sinistros com vítima.';


--
-- Name: COLUMN mv_indicadores_regional_ano.sinistros_fatais; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.sinistros_fatais IS 'Sinistros com ao menos uma morte.';


--
-- Name: COLUMN mv_indicadores_regional_ano.vitimas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.vitimas IS 'Vítimas.';


--
-- Name: COLUMN mv_indicadores_regional_ano.mortos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.mortos IS 'Vítimas fatais.';


--
-- Name: COLUMN mv_indicadores_regional_ano.ups; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.ups IS 'Soma da Unidade Padrão de Severidade.';


--
-- Name: COLUMN mv_indicadores_regional_ano.populacao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.populacao IS 'População residente da regional no ano.';


--
-- Name: COLUMN mv_indicadores_regional_ano.taxa_sinistros_100mil; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_sinistros_100mil IS 'Sinistros por 100 mil habitantes.';


--
-- Name: COLUMN mv_indicadores_regional_ano.taxa_vitimas_100mil; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_vitimas_100mil IS 'Vítimas por 100 mil habitantes.';


--
-- Name: COLUMN mv_indicadores_regional_ano.taxa_mortos_100mil; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_indicadores_regional_ano.taxa_mortos_100mil IS 'Mortos por 100 mil habitantes.';


--
-- Name: mv_participacao_vitimas_ano; Type: MATERIALIZED VIEW; Schema: dw; Owner: -
--

CREATE MATERIALIZED VIEW dw.mv_participacao_vitimas_ano AS
 SELECT ano,
    count(*) FILTER (WHERE fl_vitima) AS vitimas,
    count(*) FILTER (WHERE (fl_vitima AND fl_pedestre)) AS vitimas_pedestres,
    count(*) FILTER (WHERE (fl_vitima AND fl_motociclista)) AS vitimas_motociclistas,
    round(((100.0 * (count(*) FILTER (WHERE (fl_vitima AND fl_pedestre)))::numeric) / (NULLIF(count(*) FILTER (WHERE fl_vitima), 0))::numeric), 2) AS pct_vitimas_pedestres,
    round(((100.0 * (count(*) FILTER (WHERE (fl_vitima AND fl_motociclista)))::numeric) / (NULLIF(count(*) FILTER (WHERE fl_vitima), 0))::numeric), 2) AS pct_vitimas_motociclistas,
    count(*) FILTER (WHERE fl_vitima_fatal) AS mortos,
    count(*) FILTER (WHERE (fl_vitima_fatal AND fl_pedestre)) AS mortos_pedestres,
    count(*) FILTER (WHERE (fl_vitima_fatal AND fl_motociclista)) AS mortos_motociclistas,
    round(((100.0 * (count(*) FILTER (WHERE (fl_vitima_fatal AND fl_pedestre)))::numeric) / (NULLIF(count(*) FILTER (WHERE fl_vitima_fatal), 0))::numeric), 2) AS pct_mortos_pedestres,
    round(((100.0 * (count(*) FILTER (WHERE (fl_vitima_fatal AND fl_motociclista)))::numeric) / (NULLIF(count(*) FILTER (WHERE fl_vitima_fatal), 0))::numeric), 2) AS pct_mortos_motociclistas
   FROM dw.fato_envolvido e
  GROUP BY ano
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_participacao_vitimas_ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON MATERIALIZED VIEW dw.mv_participacao_vitimas_ano IS 'Participação de pedestres e motociclistas (grupos prioritários) nas vítimas e nos mortos, por ano.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.ano IS 'Ano.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.vitimas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas IS 'Total de vítimas.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.vitimas_pedestres; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas_pedestres IS 'Vítimas pedestres.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.vitimas_motociclistas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.vitimas_motociclistas IS 'Vítimas motociclistas (condutores e passageiros).';


--
-- Name: COLUMN mv_participacao_vitimas_ano.pct_vitimas_pedestres; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_vitimas_pedestres IS 'Percentual de pedestres nas vítimas.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.pct_vitimas_motociclistas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_vitimas_motociclistas IS 'Percentual de motociclistas nas vítimas.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.mortos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos IS 'Total de mortos.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.mortos_pedestres; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos_pedestres IS 'Mortos pedestres.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.mortos_motociclistas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.mortos_motociclistas IS 'Mortos motociclistas.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.pct_mortos_pedestres; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_mortos_pedestres IS 'Percentual de pedestres nos mortos.';


--
-- Name: COLUMN mv_participacao_vitimas_ano.pct_mortos_motociclistas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_participacao_vitimas_ano.pct_mortos_motociclistas IS 'Percentual de motociclistas nos mortos.';


--
-- Name: mv_ranking_locais; Type: MATERIALIZED VIEW; Schema: dw; Owner: -
--

CREATE MATERIALIZED VIEW dw.mv_ranking_locais AS
 SELECT l.chave_natural,
    f.ano,
    max(l.descricao_local_atual) AS descricao_local_atual,
    bool_or(l.fl_cruzamento) AS fl_cruzamento,
    max(l.nome_bairro) AS nome_bairro,
    count(*) AS sinistros,
    sum(f.qtd_vitimas) AS vitimas,
    sum(f.qtd_vitimas_fatais) AS mortos,
    sum(f.valor_ups) AS ups,
    count(*) FILTER (WHERE f.fl_envolve_pedestre) AS sinistros_com_pedestre,
    count(*) FILTER (WHERE f.fl_envolve_motociclista) AS sinistros_com_motocicleta,
    rank() OVER (PARTITION BY f.ano ORDER BY (sum(f.valor_ups)) DESC) AS rank_ups_ano,
    rank() OVER (PARTITION BY f.ano ORDER BY (count(*)) DESC) AS rank_sinistros_ano,
    max(l.latitude) AS latitude,
    max(l.longitude) AS longitude
   FROM (dw.fato_sinistro f
     JOIN dw.dim_local l ON ((l.sk_local = f.sk_local)))
  WHERE (f.sk_local > 0)
  GROUP BY l.chave_natural, f.ano
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_ranking_locais; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON MATERIALIZED VIEW dw.mv_ranking_locais IS 'Ranking de locais e cruzamentos por ano (sinistros, vítimas, mortos, UPS), agregando todas as versões do local pela chave natural e exibindo o nome atual.';


--
-- Name: COLUMN mv_ranking_locais.chave_natural; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.chave_natural IS 'Chave natural do local.';


--
-- Name: COLUMN mv_ranking_locais.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.ano IS 'Ano.';


--
-- Name: COLUMN mv_ranking_locais.descricao_local_atual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.descricao_local_atual IS 'Descrição do local com os nomes atuais.';


--
-- Name: COLUMN mv_ranking_locais.fl_cruzamento; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.fl_cruzamento IS 'Verdadeiro se é cruzamento.';


--
-- Name: COLUMN mv_ranking_locais.nome_bairro; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.nome_bairro IS 'Bairro.';


--
-- Name: COLUMN mv_ranking_locais.sinistros; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.sinistros IS 'Sinistros com vítima.';


--
-- Name: COLUMN mv_ranking_locais.vitimas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.vitimas IS 'Vítimas.';


--
-- Name: COLUMN mv_ranking_locais.mortos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.mortos IS 'Vítimas fatais.';


--
-- Name: COLUMN mv_ranking_locais.ups; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.ups IS 'Soma da UPS (severidade ponderada).';


--
-- Name: COLUMN mv_ranking_locais.sinistros_com_pedestre; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.sinistros_com_pedestre IS 'Sinistros com pedestre envolvido.';


--
-- Name: COLUMN mv_ranking_locais.sinistros_com_motocicleta; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.sinistros_com_motocicleta IS 'Sinistros com motocicleta envolvida.';


--
-- Name: COLUMN mv_ranking_locais.rank_ups_ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.rank_ups_ano IS 'Posição no ano pela UPS.';


--
-- Name: COLUMN mv_ranking_locais.rank_sinistros_ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.rank_sinistros_ano IS 'Posição no ano pelo número de sinistros.';


--
-- Name: COLUMN mv_ranking_locais.latitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.latitude IS 'Latitude do ponto representativo do local.';


--
-- Name: COLUMN mv_ranking_locais.longitude; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_ranking_locais.longitude IS 'Longitude do ponto representativo do local.';


--
-- Name: mv_taxa_mortalidade_anual; Type: MATERIALIZED VIEW; Schema: dw; Owner: -
--

CREATE MATERIALIZED VIEW dw.mv_taxa_mortalidade_anual AS
 WITH pop AS (
         SELECT p_1.ano,
            sum(p_1.populacao_residente) AS populacao,
            string_agg(DISTINCT p_1.origem_total_municipio, '; '::text) AS origem_populacao
           FROM dw.fato_populacao p_1
          GROUP BY p_1.ano
        ), sin AS (
         SELECT f.ano,
            count(*) AS sinistros,
            sum(f.qtd_vitimas) AS vitimas,
            sum(f.qtd_vitimas_fatais) AS mortos
           FROM dw.fato_sinistro f
          GROUP BY f.ano
        ), base AS (
         SELECT (((s_1.mortos)::numeric * 100000.0) / (p_1.populacao)::numeric) AS taxa_2014
           FROM (sin s_1
             JOIN pop p_1 ON ((p_1.ano = s_1.ano)))
          WHERE (s_1.ano = 2014)
        )
 SELECT s.ano,
    p.populacao,
    p.origem_populacao,
    s.sinistros,
    s.vitimas,
    s.mortos,
    round((((s.mortos)::numeric * 100000.0) / (p.populacao)::numeric), 3) AS taxa_mortos_100mil,
    round((((s.vitimas)::numeric * 100000.0) / (p.populacao)::numeric), 2) AS taxa_vitimas_100mil,
    round(b.taxa_2014, 3) AS taxa_base_2014,
    round((b.taxa_2014 * 0.5), 3) AS meta_2030,
    round(((((s.mortos)::numeric * 100000.0) / (p.populacao)::numeric) - (b.taxa_2014 * 0.5)), 3) AS distancia_meta,
    round(((100)::numeric * ((1)::numeric - ((((s.mortos)::numeric * 100000.0) / (p.populacao)::numeric) / b.taxa_2014))), 1) AS pct_reducao_vs_2014
   FROM ((sin s
     JOIN pop p ON ((p.ano = s.ano)))
     LEFT JOIN base b ON (true))
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_taxa_mortalidade_anual; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON MATERIALIZED VIEW dw.mv_taxa_mortalidade_anual IS 'Taxa anual de mortos no trânsito por 100 mil habitantes, meta municipal (50% da taxa de 2014 até 2030) e distância até a meta (nulas se 2014 não estiver carregado).';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.ano; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.ano IS 'Ano.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.populacao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.populacao IS 'População do município (soma das regionais).';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.origem_populacao; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.origem_populacao IS 'Origem do total populacional.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.sinistros; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.sinistros IS 'Sinistros com vítima.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.vitimas; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.vitimas IS 'Vítimas (feridos + mortos).';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.mortos; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.mortos IS 'Vítimas fatais registradas nos boletins.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.taxa_mortos_100mil; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_mortos_100mil IS 'Mortos por 100 mil habitantes.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.taxa_vitimas_100mil; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_vitimas_100mil IS 'Vítimas por 100 mil habitantes.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.taxa_base_2014; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.taxa_base_2014 IS 'Taxa de mortos de 2014 (ano-base da meta).';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.meta_2030; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.meta_2030 IS 'Meta para 2030: 50% da taxa de 2014.';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.distancia_meta; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.distancia_meta IS 'Taxa do ano menos a meta (positivo = acima da meta).';


--
-- Name: COLUMN mv_taxa_mortalidade_anual.pct_reducao_vs_2014; Type: COMMENT; Schema: dw; Owner: -
--

COMMENT ON COLUMN dw.mv_taxa_mortalidade_anual.pct_reducao_vs_2014 IS 'Redução percentual da taxa em relação a 2014.';


--
-- Name: ibge_localidade; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.ibge_localidade (
    tipo text,
    localidade_id text,
    localidade_nome text,
    distrito_id text,
    distrito_nome text,
    municipio_id text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ibge_localidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.ibge_localidade IS 'Distritos e subdistritos de Belo Horizonte segundo a API de localidades do IBGE (divisão territorial vigente).';


--
-- Name: COLUMN ibge_localidade.tipo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.tipo IS 'distrito ou subdistrito.';


--
-- Name: COLUMN ibge_localidade.localidade_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.localidade_id IS 'Código IBGE do distrito/subdistrito.';


--
-- Name: COLUMN ibge_localidade.localidade_nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.localidade_nome IS 'Nome do distrito/subdistrito.';


--
-- Name: COLUMN ibge_localidade.distrito_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.distrito_id IS 'Código do distrito a que o subdistrito pertence.';


--
-- Name: COLUMN ibge_localidade.distrito_nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.distrito_nome IS 'Nome do distrito a que o subdistrito pertence.';


--
-- Name: COLUMN ibge_localidade.municipio_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.municipio_id IS 'Código IBGE do município.';


--
-- Name: COLUMN ibge_localidade.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.arquivo_origem IS 'Linhagem: arquivo JSON de origem.';


--
-- Name: COLUMN ibge_localidade.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.linha_arquivo IS 'Linhagem: posição do registro no arquivo.';


--
-- Name: COLUMN ibge_localidade.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_localidade.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: ibge_setor2010_malha; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.ibge_setor2010_malha (
    cd_geocodi text,
    tipo text,
    cd_geocodb text,
    nm_bairro text,
    cd_geocods text,
    nm_subdist text,
    cd_geocodd text,
    nm_distrit text,
    cd_geocodm text,
    nm_municip text,
    geometria_geojson text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ibge_setor2010_malha; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.ibge_setor2010_malha IS 'Malha de setores censitários do Censo 2010 (shapefile 31SEE250GC_SIR, SIRGAS 2000 geográfico), filtrada para Belo Horizonte.';


--
-- Name: COLUMN ibge_setor2010_malha.cd_geocodi; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodi IS 'Código do setor censitário (15 dígitos).';


--
-- Name: COLUMN ibge_setor2010_malha.tipo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.tipo IS 'Tipo do setor (URBANO/RURAL).';


--
-- Name: COLUMN ibge_setor2010_malha.cd_geocodb; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodb IS 'Código do bairro IBGE.';


--
-- Name: COLUMN ibge_setor2010_malha.nm_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_bairro IS 'Nome do bairro IBGE.';


--
-- Name: COLUMN ibge_setor2010_malha.cd_geocods; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocods IS 'Código do subdistrito.';


--
-- Name: COLUMN ibge_setor2010_malha.nm_subdist; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_subdist IS 'Nome do subdistrito.';


--
-- Name: COLUMN ibge_setor2010_malha.cd_geocodd; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodd IS 'Código do distrito.';


--
-- Name: COLUMN ibge_setor2010_malha.nm_distrit; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_distrit IS 'Nome do distrito.';


--
-- Name: COLUMN ibge_setor2010_malha.cd_geocodm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.cd_geocodm IS 'Código do município.';


--
-- Name: COLUMN ibge_setor2010_malha.nm_municip; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.nm_municip IS 'Nome do município.';


--
-- Name: COLUMN ibge_setor2010_malha.geometria_geojson; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.geometria_geojson IS 'Polígono do setor em GeoJSON (EPSG:4674).';


--
-- Name: COLUMN ibge_setor2010_malha.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.arquivo_origem IS 'Linhagem: shapefile de origem.';


--
-- Name: COLUMN ibge_setor2010_malha.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.linha_arquivo IS 'Linhagem: número do registro no shapefile.';


--
-- Name: COLUMN ibge_setor2010_malha.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_malha.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: ibge_setor2010_variavel; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.ibge_setor2010_variavel (
    cod_setor text,
    planilha text,
    variavel text,
    valor text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ibge_setor2010_variavel; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.ibge_setor2010_variavel IS 'Agregados por setor censitário do Censo 2010 (Resultados do Universo), formato longo, apenas setores de Belo Horizonte e variáveis de população.';


--
-- Name: COLUMN ibge_setor2010_variavel.cod_setor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.cod_setor IS 'Código do setor censitário.';


--
-- Name: COLUMN ibge_setor2010_variavel.planilha; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.planilha IS 'Planilha de origem (Basico, Pessoa13, Domicilio02).';


--
-- Name: COLUMN ibge_setor2010_variavel.variavel; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.variavel IS 'Código da variável (ex.: V001 da Pessoa13 = pessoas residentes).';


--
-- Name: COLUMN ibge_setor2010_variavel.valor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.valor IS 'Valor publicado (texto; "X" = sigilo).';


--
-- Name: COLUMN ibge_setor2010_variavel.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.arquivo_origem IS 'Linhagem: arquivo CSV de origem.';


--
-- Name: COLUMN ibge_setor2010_variavel.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';


--
-- Name: COLUMN ibge_setor2010_variavel.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_setor2010_variavel.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: ibge_sidra_valor; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.ibge_sidra_valor (
    tabela text,
    variavel_id text,
    variavel_nome text,
    nivel text,
    localidade_id text,
    localidade_nome text,
    periodo text,
    valor text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ibge_sidra_valor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.ibge_sidra_valor IS 'Valores das consultas à API de agregados do IBGE (SIDRA): estimativas (tabela 6579), Censo 2010 (202) e Censo 2022 (9923), em formato longo.';


--
-- Name: COLUMN ibge_sidra_valor.tabela; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.tabela IS 'Número da tabela do SIDRA.';


--
-- Name: COLUMN ibge_sidra_valor.variavel_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.variavel_id IS 'Identificador da variável (9324 estimada; 93 população residente).';


--
-- Name: COLUMN ibge_sidra_valor.variavel_nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.variavel_nome IS 'Nome da variável.';


--
-- Name: COLUMN ibge_sidra_valor.nivel; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.nivel IS 'Nível territorial (N6 município, N10 distrito, N11 subdistrito).';


--
-- Name: COLUMN ibge_sidra_valor.localidade_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.localidade_id IS 'Código IBGE da localidade.';


--
-- Name: COLUMN ibge_sidra_valor.localidade_nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.localidade_nome IS 'Nome da localidade.';


--
-- Name: COLUMN ibge_sidra_valor.periodo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.periodo IS 'Período (ano).';


--
-- Name: COLUMN ibge_sidra_valor.valor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.valor IS 'Valor publicado (texto).';


--
-- Name: COLUMN ibge_sidra_valor.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.arquivo_origem IS 'Linhagem: arquivo JSON de origem.';


--
-- Name: COLUMN ibge_sidra_valor.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.linha_arquivo IS 'Linhagem: posição do valor no arquivo.';


--
-- Name: COLUMN ibge_sidra_valor.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.ibge_sidra_valor.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: inmet_horario; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.inmet_horario (
    estacao_codigo text,
    estacao_nome text,
    data_medicao text,
    hora_utc text,
    precipitacao_mm text,
    pressao_estacao_mb text,
    pressao_max_mb text,
    pressao_min_mb text,
    radiacao_global_kj_m2 text,
    temperatura_ar_c text,
    temperatura_orvalho_c text,
    temperatura_max_c text,
    temperatura_min_c text,
    temperatura_orvalho_max_c text,
    temperatura_orvalho_min_c text,
    umidade_max_pct text,
    umidade_min_pct text,
    umidade_relativa_pct text,
    vento_direcao_graus text,
    vento_rajada_ms text,
    vento_velocidade_ms text,
    ano_arquivo smallint NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE inmet_horario; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.inmet_horario IS 'Espelho dos CSVs horários do INMET das estações automáticas de BH: A521 Pampulha (principal) e F501 Cercadinho (reserva, desde 27/12/2013). Horário em UTC.';


--
-- Name: COLUMN inmet_horario.estacao_codigo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.estacao_codigo IS 'Código da estação (metadado "CODIGO (WMO)").';


--
-- Name: COLUMN inmet_horario.estacao_nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.estacao_nome IS 'Nome da estação (metadado "ESTACAO").';


--
-- Name: COLUMN inmet_horario.data_medicao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.data_medicao IS 'Data da medição (AAAA-MM-DD até 2018; AAAA/MM/DD depois).';


--
-- Name: COLUMN inmet_horario.hora_utc; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.hora_utc IS 'Hora UTC do fim do intervalo (HH:MM até 2018; "HHMM UTC" depois).';


--
-- Name: COLUMN inmet_horario.precipitacao_mm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.precipitacao_mm IS 'Precipitação total no intervalo horário (mm, vírgula decimal; -9999 ou vazio = ausente).';


--
-- Name: COLUMN inmet_horario.pressao_estacao_mb; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.pressao_estacao_mb IS 'Pressão atmosférica ao nível da estação (mB).';


--
-- Name: COLUMN inmet_horario.pressao_max_mb; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.pressao_max_mb IS 'Pressão máxima na hora anterior (mB).';


--
-- Name: COLUMN inmet_horario.pressao_min_mb; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.pressao_min_mb IS 'Pressão mínima na hora anterior (mB).';


--
-- Name: COLUMN inmet_horario.radiacao_global_kj_m2; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.radiacao_global_kj_m2 IS 'Radiação global (kJ/m²).';


--
-- Name: COLUMN inmet_horario.temperatura_ar_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_ar_c IS 'Temperatura do ar, bulbo seco (°C).';


--
-- Name: COLUMN inmet_horario.temperatura_orvalho_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_c IS 'Temperatura do ponto de orvalho (°C).';


--
-- Name: COLUMN inmet_horario.temperatura_max_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_max_c IS 'Temperatura máxima na hora anterior (°C).';


--
-- Name: COLUMN inmet_horario.temperatura_min_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_min_c IS 'Temperatura mínima na hora anterior (°C).';


--
-- Name: COLUMN inmet_horario.temperatura_orvalho_max_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_max_c IS 'Temperatura de orvalho máxima na hora anterior (°C).';


--
-- Name: COLUMN inmet_horario.temperatura_orvalho_min_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.temperatura_orvalho_min_c IS 'Temperatura de orvalho mínima na hora anterior (°C).';


--
-- Name: COLUMN inmet_horario.umidade_max_pct; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.umidade_max_pct IS 'Umidade relativa máxima na hora anterior (%).';


--
-- Name: COLUMN inmet_horario.umidade_min_pct; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.umidade_min_pct IS 'Umidade relativa mínima na hora anterior (%).';


--
-- Name: COLUMN inmet_horario.umidade_relativa_pct; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.umidade_relativa_pct IS 'Umidade relativa do ar horária (%).';


--
-- Name: COLUMN inmet_horario.vento_direcao_graus; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.vento_direcao_graus IS 'Direção horária do vento (graus).';


--
-- Name: COLUMN inmet_horario.vento_rajada_ms; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.vento_rajada_ms IS 'Rajada máxima de vento (m/s).';


--
-- Name: COLUMN inmet_horario.vento_velocidade_ms; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.vento_velocidade_ms IS 'Velocidade horária do vento (m/s).';


--
-- Name: COLUMN inmet_horario.ano_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.ano_arquivo IS 'Ano do arquivo (ZIP anual do INMET).';


--
-- Name: COLUMN inmet_horario.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.arquivo_origem IS 'Linhagem: arquivo CSV de origem.';


--
-- Name: COLUMN inmet_horario.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.linha_arquivo IS 'Linhagem: número da linha no arquivo (metadados nas linhas 1 a 8, cabeçalho na 9).';


--
-- Name: COLUMN inmet_horario.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.inmet_horario.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: log_carga; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.log_carga (
    id_log bigint NOT NULL,
    id_execucao bigint NOT NULL,
    etapa text NOT NULL,
    status text NOT NULL,
    dt_inicio timestamp with time zone DEFAULT now() NOT NULL,
    dt_fim timestamp with time zone,
    linhas bigint,
    mensagem text,
    parametros text,
    arquivo_origem text DEFAULT 'etl.carga_inicial'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT log_carga_status_check CHECK ((status = ANY (ARRAY['INICIADA'::text, 'SUCESSO'::text, 'FALHA'::text, 'ALERTA'::text])))
);


--
-- Name: TABLE log_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.log_carga IS 'Registro de cada execução do ETL (uma linha por etapa: extrair, staging, transformar, testes, carregar, reconciliar).';


--
-- Name: COLUMN log_carga.id_log; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.id_log IS 'Identificador da linha de log.';


--
-- Name: COLUMN log_carga.id_execucao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.id_execucao IS 'Identificador da execução (AAAAMMDDHHMISS do início).';


--
-- Name: COLUMN log_carga.etapa; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.etapa IS 'Etapa do ETL.';


--
-- Name: COLUMN log_carga.status; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.status IS 'INICIADA, SUCESSO, FALHA ou ALERTA.';


--
-- Name: COLUMN log_carga.dt_inicio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.dt_inicio IS 'Início da etapa.';


--
-- Name: COLUMN log_carga.dt_fim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.dt_fim IS 'Fim da etapa.';


--
-- Name: COLUMN log_carga.linhas; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.linhas IS 'Linhas processadas na etapa, quando aplicável.';


--
-- Name: COLUMN log_carga.mensagem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.mensagem IS 'Mensagem de resultado ou de erro.';


--
-- Name: COLUMN log_carga.parametros; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.parametros IS 'Parâmetros da execução (anos, forçar download...).';


--
-- Name: COLUMN log_carga.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.arquivo_origem IS 'Linhagem: módulo que gravou o registro.';


--
-- Name: COLUMN log_carga.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.log_carga.dt_carga IS 'Linhagem: data e hora da gravação.';


--
-- Name: log_carga_id_log_seq; Type: SEQUENCE; Schema: stg; Owner: -
--

CREATE SEQUENCE stg.log_carga_id_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_carga_id_log_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: -
--

ALTER SEQUENCE stg.log_carga_id_log_seq OWNED BY stg.log_carga.id_log;


--
-- Name: manifesto_raw; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.manifesto_raw (
    fonte text NOT NULL,
    conjunto text NOT NULL,
    recurso text,
    recurso_id text,
    ano text,
    url text,
    arquivo text NOT NULL,
    sha256 text,
    bytes text,
    dt_coleta text,
    modificado_na_origem text,
    sha256_pacote text,
    bytes_pacote text,
    observacao text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE manifesto_raw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.manifesto_raw IS 'Espelho de dados/raw/manifesto.csv: um registro por arquivo guardado na camada RAW (origem, hash e data de coleta).';


--
-- Name: COLUMN manifesto_raw.fonte; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.fonte IS 'Fonte do arquivo (pbh_ckan, ibge, ibge_setores_2010, inmet).';


--
-- Name: COLUMN manifesto_raw.conjunto; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.conjunto IS 'Conjunto lógico (si_bol, si_log, si_veic, si_env, regional, estimativas, censo_2022...).';


--
-- Name: COLUMN manifesto_raw.recurso; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.recurso IS 'Nome do recurso na origem.';


--
-- Name: COLUMN manifesto_raw.recurso_id; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.recurso_id IS 'Identificador do recurso no CKAN da PBH.';


--
-- Name: COLUMN manifesto_raw.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.ano IS 'Ano de referência do arquivo, quando houver.';


--
-- Name: COLUMN manifesto_raw.url; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.url IS 'URL de download (para arquivos extraídos de ZIP, a URL do ZIP).';


--
-- Name: COLUMN manifesto_raw.arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.arquivo IS 'Caminho do arquivo dentro de dados/raw/.';


--
-- Name: COLUMN manifesto_raw.sha256; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.sha256 IS 'Hash SHA-256 do arquivo guardado.';


--
-- Name: COLUMN manifesto_raw.bytes; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.bytes IS 'Tamanho do arquivo em bytes.';


--
-- Name: COLUMN manifesto_raw.dt_coleta; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.dt_coleta IS 'Data e hora da coleta (ISO 8601).';


--
-- Name: COLUMN manifesto_raw.modificado_na_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.modificado_na_origem IS 'Data de modificação informada pelo portal de origem.';


--
-- Name: COLUMN manifesto_raw.sha256_pacote; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.sha256_pacote IS 'Hash SHA-256 do ZIP de origem (INMET e setores do IBGE), apagado após a extração.';


--
-- Name: COLUMN manifesto_raw.bytes_pacote; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.bytes_pacote IS 'Tamanho do ZIP de origem em bytes.';


--
-- Name: COLUMN manifesto_raw.observacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.observacao IS 'Observações da coleta (tipo do recurso, licença, membro do ZIP).';


--
-- Name: COLUMN manifesto_raw.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN manifesto_raw.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';


--
-- Name: COLUMN manifesto_raw.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.manifesto_raw.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: map_dominio; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.map_dominio (
    dominio text NOT NULL,
    codigo text NOT NULL,
    descricao text NOT NULL,
    grupo text,
    ordem smallint,
    observacao text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE map_dominio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.map_dominio IS 'De-para dos domínios codificados (tipo de sinistro, tempo, pavimento, severidade, categoria/situação/espécie de veículo, tipo de logradouro, sexo), derivado da inspeção dos arquivos reais.';


--
-- Name: COLUMN map_dominio.dominio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.dominio IS 'Nome do domínio.';


--
-- Name: COLUMN map_dominio.codigo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.codigo IS 'Código (ou descrição) como aparece na fonte.';


--
-- Name: COLUMN map_dominio.descricao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.descricao IS 'Descrição padronizada.';


--
-- Name: COLUMN map_dominio.grupo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.grupo IS 'Agrupamento analítico (ex.: grupo do tipo de sinistro, grupo da espécie).';


--
-- Name: COLUMN map_dominio.ordem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.ordem IS 'Ordem de exibição.';


--
-- Name: COLUMN map_dominio.observacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.observacao IS 'Observações sobre o código.';


--
-- Name: COLUMN map_dominio.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.arquivo_origem IS 'Linhagem: arquivo de mapeamento de origem.';


--
-- Name: COLUMN map_dominio.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.linha_arquivo IS 'Linhagem: linha no arquivo de mapeamento.';


--
-- Name: COLUMN map_dominio.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_dominio.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: map_regional; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.map_regional (
    cod_regional_boletim smallint NOT NULL,
    desc_regional_boletim text,
    cod_reg_limite smallint,
    nome_regional text,
    sigla text,
    nome_subdistrito_ibge text,
    observacao text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE map_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.map_regional IS 'De-para das regionais: cod_regional/desc_regional do si-bol x COD_REG/NOME do limite 20220601 x subdistritos do IBGE.';


--
-- Name: COLUMN map_regional.cod_regional_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.cod_regional_boletim IS 'Código da regional no si-bol (0 = não informada; 27 = Hipercentro, usado em 2024).';


--
-- Name: COLUMN map_regional.desc_regional_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.desc_regional_boletim IS 'Nome da regional no si-bol.';


--
-- Name: COLUMN map_regional.cod_reg_limite; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.cod_reg_limite IS 'COD_REG correspondente no limite de 9 regionais (vigente até jan/2025).';


--
-- Name: COLUMN map_regional.nome_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.nome_regional IS 'Nome da regional no limite.';


--
-- Name: COLUMN map_regional.sigla; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.sigla IS 'Sigla da regional.';


--
-- Name: COLUMN map_regional.nome_subdistrito_ibge; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.nome_subdistrito_ibge IS 'Nome dos subdistritos do IBGE que compõem a regional (Censos 2010 e 2022).';


--
-- Name: COLUMN map_regional.observacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.observacao IS 'Observações do de-para.';


--
-- Name: COLUMN map_regional.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.arquivo_origem IS 'Linhagem: arquivo de mapeamento de origem.';


--
-- Name: COLUMN map_regional.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.linha_arquivo IS 'Linhagem: linha no arquivo de mapeamento.';


--
-- Name: COLUMN map_regional.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.map_regional.dt_carga IS 'Linhagem: data e hora da carga.';


--
-- Name: regional_limite; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.regional_limite (
    id_reg text,
    cod_reg text,
    sigla text,
    nome text,
    area_km2 text,
    perimetr_m text,
    geometria text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE regional_limite; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.regional_limite IS 'Espelho dos arquivos de limites das regionais da PBH: 20220601_regional (9 regionais, vigente até jan/2025, usado no DW) e 20250204_regional (10 regionais, apenas para referência).';


--
-- Name: COLUMN regional_limite.id_reg; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.id_reg IS 'Identificador da regional no arquivo.';


--
-- Name: COLUMN regional_limite.cod_reg; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.cod_reg IS 'Código da regional (o mesmo cod_regional do si-bol).';


--
-- Name: COLUMN regional_limite.sigla; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.sigla IS 'Sigla da regional.';


--
-- Name: COLUMN regional_limite.nome; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.nome IS 'Nome da regional.';


--
-- Name: COLUMN regional_limite.area_km2; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.area_km2 IS 'Área em km².';


--
-- Name: COLUMN regional_limite.perimetr_m; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.perimetr_m IS 'Perímetro em metros.';


--
-- Name: COLUMN regional_limite.geometria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.geometria IS 'Polígono em WKT, SIRGAS 2000 / UTM 23S (EPSG:31983).';


--
-- Name: COLUMN regional_limite.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN regional_limite.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.linha_arquivo IS 'Linhagem: número do registro no arquivo de origem.';


--
-- Name: COLUMN regional_limite.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.regional_limite.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: resultado_qualidade; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.resultado_qualidade (
    id_resultado bigint NOT NULL,
    id_execucao bigint NOT NULL,
    teste text NOT NULL,
    categoria text NOT NULL,
    severidade text NOT NULL,
    aprovado boolean NOT NULL,
    valor_obtido text,
    criterio text,
    detalhe text,
    arquivo_origem text DEFAULT 'etl.testes_qualidade'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resultado_qualidade_severidade_check CHECK ((severidade = ANY (ARRAY['CRITICO'::text, 'ALERTA'::text, 'INFO'::text])))
);


--
-- Name: TABLE resultado_qualidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.resultado_qualidade IS 'Resultado de cada teste de qualidade executado antes de promover os dados ao dw.';


--
-- Name: COLUMN resultado_qualidade.id_resultado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.id_resultado IS 'Identificador do resultado.';


--
-- Name: COLUMN resultado_qualidade.id_execucao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.id_execucao IS 'Execução do ETL a que o teste pertence.';


--
-- Name: COLUMN resultado_qualidade.teste; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.teste IS 'Nome do teste.';


--
-- Name: COLUMN resultado_qualidade.categoria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.categoria IS 'Categoria (unicidade, domínio, volume, órfãos, coerência, cobertura, reconciliação).';


--
-- Name: COLUMN resultado_qualidade.severidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.severidade IS 'CRITICO interrompe a carga; ALERTA e INFO apenas registram.';


--
-- Name: COLUMN resultado_qualidade.aprovado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.aprovado IS 'Verdadeiro se o critério foi atendido.';


--
-- Name: COLUMN resultado_qualidade.valor_obtido; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.valor_obtido IS 'Valor medido.';


--
-- Name: COLUMN resultado_qualidade.criterio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.criterio IS 'Critério de aprovação.';


--
-- Name: COLUMN resultado_qualidade.detalhe; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.detalhe IS 'Detalhamento (ex.: contagem por ano).';


--
-- Name: COLUMN resultado_qualidade.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.arquivo_origem IS 'Linhagem: módulo que gravou o resultado.';


--
-- Name: COLUMN resultado_qualidade.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.resultado_qualidade.dt_carga IS 'Linhagem: data e hora da gravação.';


--
-- Name: resultado_qualidade_id_resultado_seq; Type: SEQUENCE; Schema: stg; Owner: -
--

CREATE SEQUENCE stg.resultado_qualidade_id_resultado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resultado_qualidade_id_resultado_seq; Type: SEQUENCE OWNED BY; Schema: stg; Owner: -
--

ALTER SEQUENCE stg.resultado_qualidade_id_resultado_seq OWNED BY stg.resultado_qualidade.id_resultado;


--
-- Name: si_bol; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.si_bol (
    numero_boletim text,
    data_hora_boletim text,
    data_inclusao text,
    tipo_acidente text,
    desc_tipo_acidente text,
    cod_tempo text,
    desc_tempo text,
    cod_pavimento text,
    pavimento text,
    cod_regional text,
    desc_regional text,
    origem_boletim text,
    local_sinalizado text,
    velocidade_permitida text,
    coordenada_x text,
    coordenada_y text,
    hora_informada text,
    indicador_fatalidade text,
    valor_ups text,
    descricao_ups text,
    data_alteracao_smsa text,
    valor_ups_antiga text,
    descricao_ups_antiga text,
    ano_arquivo smallint NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE si_bol; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.si_bol IS 'Espelho dos arquivos si-bol-AAAA.csv (PBH/BHTrans): dados gerais de cada boletim de ocorrência de sinistro de trânsito com vítima.';


--
-- Name: COLUMN si_bol.numero_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.numero_boletim IS 'Número do boletim (numérico até 2016; formato AAAA-NNNNNNNNN-NNN depois). Origem: numero_boletim / NUMERO_BOLETIM.';


--
-- Name: COLUMN si_bol.data_hora_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.data_hora_boletim IS 'Data e hora do sinistro, texto DD/MM/AAAA HH:MI. Origem: "data hora_boletim" (com espaço).';


--
-- Name: COLUMN si_bol.data_inclusao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.data_inclusao IS 'Data de registro do boletim.';


--
-- Name: COLUMN si_bol.tipo_acidente; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.tipo_acidente IS 'Código do tipo de sinistro (ex.: H01002).';


--
-- Name: COLUMN si_bol.desc_tipo_acidente; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.desc_tipo_acidente IS 'Descrição do tipo de sinistro.';


--
-- Name: COLUMN si_bol.cod_tempo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.cod_tempo IS 'Código da condição climática declarada (0 não informado, 1 bom, 2 chuva, 3 neblina, 4 nublado).';


--
-- Name: COLUMN si_bol.desc_tempo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.desc_tempo IS 'Descrição da condição climática.';


--
-- Name: COLUMN si_bol.cod_pavimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.cod_pavimento IS 'Código do pavimento (0 não informado, 1 asfalto, 2 concreto, 3 terra, 4 calçamento).';


--
-- Name: COLUMN si_bol.pavimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.pavimento IS 'Descrição do pavimento.';


--
-- Name: COLUMN si_bol.cod_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.cod_regional IS 'Código da administração regional (18 a 26; 27 = Hipercentro em 2024; 0 = não informado).';


--
-- Name: COLUMN si_bol.desc_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.desc_regional IS 'Nome da regional.';


--
-- Name: COLUMN si_bol.origem_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.origem_boletim IS 'Órgão/batalhão que registrou o boletim.';


--
-- Name: COLUMN si_bol.local_sinalizado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.local_sinalizado IS 'Indica se o local é sinalizado (SIM, NÃO, NÃO INFORMADO).';


--
-- Name: COLUMN si_bol.velocidade_permitida; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.velocidade_permitida IS 'Velocidade máxima permitida no local (km/h; 0 = não informada).';


--
-- Name: COLUMN si_bol.coordenada_x; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.coordenada_x IS 'Coordenada X (UTM 23S). Até 2015: SAD 69, X multiplicado por 100; a partir de 2016: SIRGAS 2000.';


--
-- Name: COLUMN si_bol.coordenada_y; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.coordenada_y IS 'Coordenada Y (UTM 23S). Até 2015: SAD 69, (Y - 7.000.000) multiplicado por 100; a partir de 2016: SIRGAS 2000.';


--
-- Name: COLUMN si_bol.hora_informada; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.hora_informada IS 'Indica se a hora do sinistro foi informada (SIM/NÃO).';


--
-- Name: COLUMN si_bol.indicador_fatalidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.indicador_fatalidade IS 'Indica se houve vítima fatal (SIM/NÃO).';


--
-- Name: COLUMN si_bol.valor_ups; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.valor_ups IS 'Unidade Padrão de Severidade atual (1 sem vítima, 5 com vítima não fatal, 13 com vítima fatal; 0 = não informado).';


--
-- Name: COLUMN si_bol.descricao_ups; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.descricao_ups IS 'Descrição da UPS atual. Origem: descricao_ups / DESCRIÇÃO_UPS.';


--
-- Name: COLUMN si_bol.data_alteracao_smsa; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.data_alteracao_smsa IS 'Data de alteração pela Secretaria Municipal de Saúde.';


--
-- Name: COLUMN si_bol.valor_ups_antiga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.valor_ups_antiga IS 'UPS anterior à revisão da SMSA (preservada apenas no staging).';


--
-- Name: COLUMN si_bol.descricao_ups_antiga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.descricao_ups_antiga IS 'Descrição da UPS anterior (preservada apenas no staging).';


--
-- Name: COLUMN si_bol.ano_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.ano_arquivo IS 'Ano do arquivo de origem (si-bol-AAAA).';


--
-- Name: COLUMN si_bol.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN si_bol.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem (o cabeçalho é a linha 1).';


--
-- Name: COLUMN si_bol.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_bol.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: si_env; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.si_env (
    numero_boletim text,
    data_hora_boletim text,
    numero_envolvido text,
    condutor text,
    codigo_severidade text,
    desc_severidade text,
    sexo text,
    cinto_seguranca text,
    embriaguez text,
    idade text,
    nascimento text,
    categoria_habilitacao text,
    descricao_habilitacao text,
    declaracao_obito text,
    cod_severidade_antiga text,
    especie_veiculo text,
    pedestre text,
    passageiro text,
    usa_capacete text,
    ano_arquivo smallint NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE si_env; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.si_env IS 'Espelho dos arquivos si_env-AAAA.csv (tabela chamada "si-pess" na Fase 2): pessoas envolvidas em cada boletim.';


--
-- Name: COLUMN si_env.numero_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.numero_boletim IS 'Número do boletim. Origem: num_boletim / Nº_boletim.';


--
-- Name: COLUMN si_env.data_hora_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.data_hora_boletim IS 'Data e hora do sinistro.';


--
-- Name: COLUMN si_env.numero_envolvido; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.numero_envolvido IS 'Número do envolvido no boletim. Origem: numero_envolvido / Nº_envolvido.';


--
-- Name: COLUMN si_env.condutor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.condutor IS 'Indica se é condutor (SIM/NÃO/NÃO INFORMADO até 2015; S/N/0 depois).';


--
-- Name: COLUMN si_env.codigo_severidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.codigo_severidade IS 'Severidade atual (0 n/i, 1 não fatal, 2 fatal, 3 sem ferimentos). Origem: codigo_severidade / cod_severidade.';


--
-- Name: COLUMN si_env.desc_severidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.desc_severidade IS 'Descrição da severidade.';


--
-- Name: COLUMN si_env.sexo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.sexo IS 'Sexo (M, F, 0 = não informado).';


--
-- Name: COLUMN si_env.cinto_seguranca; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.cinto_seguranca IS 'Uso de cinto de segurança (SIM/NÃO/NÃO INFORMADO).';


--
-- Name: COLUMN si_env.embriaguez; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.embriaguez IS 'Indício de embriaguez (SIM/NÃO/NÃO INFORMADO). Origem: Embreagues (grafia da fonte).';


--
-- Name: COLUMN si_env.idade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.idade IS 'Idade em anos.';


--
-- Name: COLUMN si_env.nascimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.nascimento IS 'Data de nascimento (00/00/0000 = não informada).';


--
-- Name: COLUMN si_env.categoria_habilitacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.categoria_habilitacao IS 'Categoria da habilitação do condutor.';


--
-- Name: COLUMN si_env.descricao_habilitacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.descricao_habilitacao IS 'Descrição da categoria de habilitação.';


--
-- Name: COLUMN si_env.declaracao_obito; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.declaracao_obito IS 'Número da declaração de óbito (preservado apenas no staging).';


--
-- Name: COLUMN si_env.cod_severidade_antiga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.cod_severidade_antiga IS 'Severidade anterior à revisão (preservada apenas no staging).';


--
-- Name: COLUMN si_env.especie_veiculo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.especie_veiculo IS 'Espécie do veículo em que a pessoa estava (vazio para pedestres). Não traz o sequencial do veículo.';


--
-- Name: COLUMN si_env.pedestre; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.pedestre IS 'Indicador de pedestre (S/N/0). Origem: indicador_pedestre (2015) / pedestre (2016+); ausente até 2014.';


--
-- Name: COLUMN si_env.passageiro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.passageiro IS 'Indicador de passageiro (S/N/0). Origem: indicador_passageiro (2015) / passageiro (2016+); ausente até 2014.';


--
-- Name: COLUMN si_env.usa_capacete; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.usa_capacete IS 'Indicador de uso de capacete. Origem: indicador_usa_capacete (somente 2015).';


--
-- Name: COLUMN si_env.ano_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.ano_arquivo IS 'Ano do arquivo de origem.';


--
-- Name: COLUMN si_env.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN si_env.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';


--
-- Name: COLUMN si_env.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_env.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: si_log; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.si_log (
    numero_boletim text,
    data_boletim text,
    numero_municipio text,
    nome_municipio text,
    sequencia_logradouro text,
    numero_logradouro text,
    tipo_logradouro text,
    nome_logradouro text,
    tipo_logradouro_anterior text,
    nome_logradouro_anterior text,
    numero_bairro text,
    nome_bairro text,
    tipo_bairro text,
    descricao_tipo_bairro text,
    numero_imovel text,
    numero_imovel_proximo text,
    ano_arquivo smallint NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE si_log; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.si_log IS 'Espelho dos arquivos si-log-AAAA.csv: logradouros do local do sinistro (sequência 1 = logradouro principal; 2 em diante = cruzamento/referência).';


--
-- Name: COLUMN si_log.numero_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_boletim IS 'Número do boletim. Origem: numero_boletim / Nº_boletim.';


--
-- Name: COLUMN si_log.data_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.data_boletim IS 'Data e hora do sinistro.';


--
-- Name: COLUMN si_log.numero_municipio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_municipio IS 'Código do município do endereço. Origem: numero_municipio / Nº_municipio.';


--
-- Name: COLUMN si_log.nome_municipio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.nome_municipio IS 'Nome do município do endereço.';


--
-- Name: COLUMN si_log.sequencia_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.sequencia_logradouro IS 'Sequência do logradouro no boletim. Origem: sequencia_logradouros / seq_logradouros.';


--
-- Name: COLUMN si_log.numero_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_logradouro IS 'Código do logradouro no cadastro da PBH. Origem: numero_logradouro / Nº_logradouro.';


--
-- Name: COLUMN si_log.tipo_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.tipo_logradouro IS 'Sigla do tipo de logradouro (RUA, AVE, ROD...).';


--
-- Name: COLUMN si_log.nome_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.nome_logradouro IS 'Nome do logradouro.';


--
-- Name: COLUMN si_log.tipo_logradouro_anterior; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.tipo_logradouro_anterior IS 'Sigla do tipo do logradouro em denominação anterior.';


--
-- Name: COLUMN si_log.nome_logradouro_anterior; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.nome_logradouro_anterior IS 'Nome anterior do logradouro. Origem: nome_logradoro_anterior (erro de digitação na fonte) / nome_logradouro_anterior.';


--
-- Name: COLUMN si_log.numero_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_bairro IS 'Código do bairro. Origem: Numero_bairro / Nº_bairro.';


--
-- Name: COLUMN si_log.nome_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.nome_bairro IS 'Nome do bairro.';


--
-- Name: COLUMN si_log.tipo_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.tipo_bairro IS 'Sigla do tipo de bairro (B, V, CH...).';


--
-- Name: COLUMN si_log.descricao_tipo_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.descricao_tipo_bairro IS 'Descrição do tipo de bairro.';


--
-- Name: COLUMN si_log.numero_imovel; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_imovel IS 'Número do imóvel de referência.';


--
-- Name: COLUMN si_log.numero_imovel_proximo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.numero_imovel_proximo IS 'Número do imóvel mais próximo.';


--
-- Name: COLUMN si_log.ano_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.ano_arquivo IS 'Ano do arquivo de origem.';


--
-- Name: COLUMN si_log.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN si_log.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';


--
-- Name: COLUMN si_log.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_log.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: si_veic; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.si_veic (
    numero_boletim text,
    data_hora_boletim text,
    sequencial_veiculo text,
    codigo_categoria text,
    descricao_categoria text,
    codigo_especie text,
    descricao_especie text,
    codigo_situacao text,
    descricao_situacao text,
    tipo_socorro text,
    descricao_tipo_socorro text,
    ano_arquivo smallint NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE si_veic; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.si_veic IS 'Espelho dos arquivos si-veic-AAAA.csv: veículos envolvidos em cada boletim (o de 2023 é lido em CP850).';


--
-- Name: COLUMN si_veic.numero_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.numero_boletim IS 'Número do boletim. Origem: numero_boletim / Nº_boletim.';


--
-- Name: COLUMN si_veic.data_hora_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.data_hora_boletim IS 'Data e hora do sinistro.';


--
-- Name: COLUMN si_veic.sequencial_veiculo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.sequencial_veiculo IS 'Sequencial do veículo no boletim. Origem: sequencial_veiculo / seq_veic.';


--
-- Name: COLUMN si_veic.codigo_categoria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.codigo_categoria IS 'Código da categoria (0 n/i, 1 oficial, 2 missão diplomática, 3 particular, 4 aluguel, 5 aprendizagem). Origem: codigo_categoria / cod_categ.';


--
-- Name: COLUMN si_veic.descricao_categoria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.descricao_categoria IS 'Descrição da categoria do veículo.';


--
-- Name: COLUMN si_veic.codigo_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.codigo_especie IS 'Código da espécie do veículo. Origem: codigo_especie / cod_especie.';


--
-- Name: COLUMN si_veic.descricao_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.descricao_especie IS 'Descrição da espécie do veículo (AUTOMOVEL, MOTOCICLETA...).';


--
-- Name: COLUMN si_veic.codigo_situacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.codigo_situacao IS 'Código da situação (0 n/i, 1 em movimento, 2 parado, 3 estacionado). Origem: codigo_situacao / cod_situacao.';


--
-- Name: COLUMN si_veic.descricao_situacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.descricao_situacao IS 'Descrição da situação (vazia para o código 3 até 2019). Origem: descricao_situacao / desc_situacao.';


--
-- Name: COLUMN si_veic.tipo_socorro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.tipo_socorro IS 'Código do tipo de socorro prestado.';


--
-- Name: COLUMN si_veic.descricao_tipo_socorro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.descricao_tipo_socorro IS 'Descrição do tipo de socorro. Origem: descricao_tipo_socorro / desc_tipo_socorro.';


--
-- Name: COLUMN si_veic.ano_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.ano_arquivo IS 'Ano do arquivo de origem.';


--
-- Name: COLUMN si_veic.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.arquivo_origem IS 'Linhagem: arquivo de onde a linha foi carregada.';


--
-- Name: COLUMN si_veic.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.linha_arquivo IS 'Linhagem: número da linha no arquivo de origem.';


--
-- Name: COLUMN si_veic.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.si_veic.dt_carga IS 'Linhagem: data e hora da carga no staging.';


--
-- Name: trf_boletim; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_boletim (
    numero_boletim_dw text NOT NULL,
    ano smallint NOT NULL,
    numero_boletim_origem text NOT NULL,
    seq_ocorrencia smallint NOT NULL,
    data_hora timestamp without time zone NOT NULL,
    data date NOT NULL,
    hora smallint,
    fl_hora_informada boolean NOT NULL,
    cod_tipo_sinistro text NOT NULL,
    cod_tempo smallint NOT NULL,
    cod_pavimento smallint NOT NULL,
    local_sinalizado text NOT NULL,
    cod_regional_origem smallint NOT NULL,
    velocidade_permitida smallint,
    valor_ups_origem smallint,
    fl_indicador_fatalidade boolean NOT NULL,
    coordenada_x_origem numeric(14,2),
    coordenada_y_origem numeric(14,2),
    qtd_linhas_origem smallint NOT NULL,
    qtd_eventos_numero smallint NOT NULL,
    precipitacao_mm numeric(6,1),
    estacao_inmet text,
    condicao_climatica text,
    origem_clima text,
    grupo_chuva text,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_boletim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_boletim IS 'Boletins tipados e deduplicados (1 linha por sinistro). Números repetidos no mesmo ano com data/hora diferentes são eventos distintos e recebem sufixo /2, /3.';


--
-- Name: COLUMN trf_boletim.numero_boletim_dw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.numero_boletim_dw IS 'Número do boletim usado no dw (original, com sufixo /n quando o número se repete no ano para outro evento).';


--
-- Name: COLUMN trf_boletim.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.ano IS 'Ano do sinistro (igual ao ano do arquivo).';


--
-- Name: COLUMN trf_boletim.numero_boletim_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.numero_boletim_origem IS 'Número do boletim como veio na fonte.';


--
-- Name: COLUMN trf_boletim.seq_ocorrencia; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.seq_ocorrencia IS 'Ordem do evento entre os que compartilham o mesmo número no ano (1 = único/primeiro).';


--
-- Name: COLUMN trf_boletim.data_hora; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.data_hora IS 'Data e hora do sinistro (horário local).';


--
-- Name: COLUMN trf_boletim.data; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.data IS 'Data do sinistro.';


--
-- Name: COLUMN trf_boletim.hora; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.hora IS 'Hora do sinistro (nula quando hora_informada = NÃO).';


--
-- Name: COLUMN trf_boletim.fl_hora_informada; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.fl_hora_informada IS 'Verdadeiro se a hora foi informada no boletim.';


--
-- Name: COLUMN trf_boletim.cod_tipo_sinistro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.cod_tipo_sinistro IS 'Código do tipo de sinistro (sem espaços).';


--
-- Name: COLUMN trf_boletim.cod_tempo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.cod_tempo IS 'Código da condição climática declarada.';


--
-- Name: COLUMN trf_boletim.cod_pavimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.cod_pavimento IS 'Código do pavimento.';


--
-- Name: COLUMN trf_boletim.local_sinalizado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.local_sinalizado IS 'SIM, NÃO ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_boletim.cod_regional_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.cod_regional_origem IS 'Código da regional informado no boletim.';


--
-- Name: COLUMN trf_boletim.velocidade_permitida; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.velocidade_permitida IS 'Velocidade permitida (km/h); nula se 0 ou fora de 10–120.';


--
-- Name: COLUMN trf_boletim.valor_ups_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.valor_ups_origem IS 'UPS informada na fonte (0 = não informada).';


--
-- Name: COLUMN trf_boletim.fl_indicador_fatalidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.fl_indicador_fatalidade IS 'Indicador de fatalidade do boletim (SIM = verdadeiro).';


--
-- Name: COLUMN trf_boletim.coordenada_x_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.coordenada_x_origem IS 'Coordenada X como veio na fonte (numérica).';


--
-- Name: COLUMN trf_boletim.coordenada_y_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.coordenada_y_origem IS 'Coordenada Y como veio na fonte (numérica).';


--
-- Name: COLUMN trf_boletim.qtd_linhas_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.qtd_linhas_origem IS 'Linhas idênticas (mesmo número, ano e data/hora) consolidadas neste registro.';


--
-- Name: COLUMN trf_boletim.qtd_eventos_numero; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.qtd_eventos_numero IS 'Quantidade de eventos distintos que compartilham o número do boletim no ano (1 = número único).';


--
-- Name: COLUMN trf_boletim.precipitacao_mm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.precipitacao_mm IS 'Precipitação do INMET na hora do sinistro (Pampulha; Cercadinho se faltar).';


--
-- Name: COLUMN trf_boletim.estacao_inmet; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.estacao_inmet IS 'Estação do INMET usada (A521 ou F501).';


--
-- Name: COLUMN trf_boletim.condicao_climatica; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.condicao_climatica IS 'Condição climática final (declarada ou imputada pelo INMET).';


--
-- Name: COLUMN trf_boletim.origem_clima; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.origem_clima IS 'DECLARADO NO BOLETIM, IMPUTADO PELO INMET ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_boletim.grupo_chuva; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.grupo_chuva IS 'COM CHUVA, SEM CHUVA ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_boletim.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: COLUMN trf_boletim.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.linha_arquivo IS 'Linhagem: linha do registro mantido.';


--
-- Name: COLUMN trf_boletim.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_boletim_local; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_boletim_local (
    numero_boletim_dw text NOT NULL,
    ano smallint NOT NULL,
    data date NOT NULL,
    chave_local text NOT NULL,
    cod_logradouro_principal integer NOT NULL,
    cod_logradouro_cruzamento integer NOT NULL,
    cod_bairro integer NOT NULL,
    fl_cruzamento boolean NOT NULL,
    origem_bairro text NOT NULL,
    numero_imovel text,
    arquivo_origem text DEFAULT 'etl.transformar (logradouros)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_boletim_local; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_boletim_local IS 'Local de ocorrência de cada boletim (logradouro principal + cruzamento + bairro), com a chave natural da dim_local.';


--
-- Name: COLUMN trf_boletim_local.numero_boletim_dw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.numero_boletim_dw IS 'Número do boletim no dw.';


--
-- Name: COLUMN trf_boletim_local.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.ano IS 'Ano do sinistro.';


--
-- Name: COLUMN trf_boletim_local.data; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.data IS 'Data do sinistro (para escolher a versão vigente da dim_local).';


--
-- Name: COLUMN trf_boletim_local.chave_local; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.chave_local IS 'Chave natural do local: códigos dos logradouros (par ordenado nos cruzamentos) e do bairro.';


--
-- Name: COLUMN trf_boletim_local.cod_logradouro_principal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.cod_logradouro_principal IS 'Código do logradouro principal (sequência 1).';


--
-- Name: COLUMN trf_boletim_local.cod_logradouro_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (sequência 2); 0 se não houver.';


--
-- Name: COLUMN trf_boletim_local.cod_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.cod_bairro IS 'Código do bairro (imputado quando 0, ver origem_bairro).';


--
-- Name: COLUMN trf_boletim_local.fl_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.fl_cruzamento IS 'Verdadeiro se há logradouro de cruzamento.';


--
-- Name: COLUMN trf_boletim_local.origem_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.origem_bairro IS 'INFORMADO, IMPUTADO (moda do mesmo cruzamento/endereço/logradouro) ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_boletim_local.numero_imovel; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.numero_imovel IS 'Número do imóvel de referência no logradouro principal (como veio na fonte).';


--
-- Name: COLUMN trf_boletim_local.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_boletim_local.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_boletim_local.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_clima_hora; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_clima_hora (
    estacao_codigo text NOT NULL,
    dt_hora_inicio_local timestamp without time zone NOT NULL,
    dt_hora_fim_utc timestamp with time zone NOT NULL,
    precipitacao_mm numeric(6,1),
    temperatura_ar_c numeric(5,1),
    umidade_relativa_pct numeric(5,1),
    arquivo_origem text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_clima_hora; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_clima_hora IS 'Leituras horárias do INMET convertidas de UTC para America/Sao_Paulo (zoneinfo, com horário de verão até 2019). Cada leitura cobre a hora que termina em dt_hora_fim_utc.';


--
-- Name: COLUMN trf_clima_hora.estacao_codigo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.estacao_codigo IS 'A521 (Pampulha) ou F501 (Cercadinho).';


--
-- Name: COLUMN trf_clima_hora.dt_hora_inicio_local; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.dt_hora_inicio_local IS 'Início, em horário local, do intervalo de uma hora coberto pela leitura (chave de cruzamento com a hora do sinistro).';


--
-- Name: COLUMN trf_clima_hora.dt_hora_fim_utc; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.dt_hora_fim_utc IS 'Fim do intervalo em UTC, como publicado pelo INMET.';


--
-- Name: COLUMN trf_clima_hora.precipitacao_mm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.precipitacao_mm IS 'Precipitação no intervalo (mm); nula se ausente (-9999 ou vazio).';


--
-- Name: COLUMN trf_clima_hora.temperatura_ar_c; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.temperatura_ar_c IS 'Temperatura do ar (°C).';


--
-- Name: COLUMN trf_clima_hora.umidade_relativa_pct; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.umidade_relativa_pct IS 'Umidade relativa (%).';


--
-- Name: COLUMN trf_clima_hora.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.arquivo_origem IS 'Linhagem: arquivo CSV do INMET.';


--
-- Name: COLUMN trf_clima_hora.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_clima_hora.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_coordenada; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_coordenada (
    numero_boletim_dw text NOT NULL,
    ano smallint NOT NULL,
    srid_origem integer,
    x_utm numeric(12,2),
    y_utm numeric(12,2),
    longitude double precision,
    latitude double precision,
    situacao text NOT NULL,
    geom public.geometry(Point,4326),
    fl_dentro_municipio boolean,
    fl_geolocalizado boolean DEFAULT false NOT NULL,
    arquivo_origem text DEFAULT 'etl.transformar (pyproj)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_coordenada; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_coordenada IS 'Coordenadas corrigidas e reprojetadas com pyproj: 2011–2015 em SAD 69/UTM 23S (EPSG:29193, X e Y em escala x100) e 2016+ em SIRGAS 2000/UTM 23S (EPSG:31983), ambas para WGS 84 (EPSG:4326).';


--
-- Name: COLUMN trf_coordenada.numero_boletim_dw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.numero_boletim_dw IS 'Número do boletim no dw.';


--
-- Name: COLUMN trf_coordenada.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.ano IS 'Ano do sinistro.';


--
-- Name: COLUMN trf_coordenada.srid_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.srid_origem IS 'Sistema de referência de origem (29193 ou 31983).';


--
-- Name: COLUMN trf_coordenada.x_utm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.x_utm IS 'X em UTM 23S após a correção de escala (metros).';


--
-- Name: COLUMN trf_coordenada.y_utm; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.y_utm IS 'Y em UTM 23S após a correção de escala (metros).';


--
-- Name: COLUMN trf_coordenada.longitude; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.longitude IS 'Longitude WGS 84.';


--
-- Name: COLUMN trf_coordenada.latitude; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.latitude IS 'Latitude WGS 84.';


--
-- Name: COLUMN trf_coordenada.situacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.situacao IS 'VALIDA, ZERADA (sem coordenada) ou FORA_FAIXA_BH (fora da faixa esperada para BH).';


--
-- Name: COLUMN trf_coordenada.geom; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.geom IS 'Ponto em WGS 84 (EPSG:4326).';


--
-- Name: COLUMN trf_coordenada.fl_dentro_municipio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.fl_dentro_municipio IS 'Verdadeiro se o ponto está a até 100 m do limite do município (união das regionais).';


--
-- Name: COLUMN trf_coordenada.fl_geolocalizado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.fl_geolocalizado IS 'Verdadeiro se a coordenada é válida e está dentro do município.';


--
-- Name: COLUMN trf_coordenada.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_coordenada.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_coordenada.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_envolvido; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_envolvido (
    numero_boletim_dw text NOT NULL,
    ano smallint NOT NULL,
    numero_envolvido smallint NOT NULL,
    tipo_envolvimento text NOT NULL,
    origem_tipo_envolvimento text NOT NULL,
    cod_severidade smallint NOT NULL,
    gravidade text NOT NULL,
    fl_vitima boolean NOT NULL,
    fl_vitima_fatal boolean NOT NULL,
    fl_condutor boolean NOT NULL,
    fl_pedestre boolean NOT NULL,
    fl_motociclista boolean NOT NULL,
    sexo text NOT NULL,
    idade smallint,
    faixa_etaria text NOT NULL,
    embriaguez text NOT NULL,
    especie_veiculo text,
    grupo_especie text,
    origem_especie text NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_envolvido; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_envolvido IS 'Pessoas envolvidas tipadas, com tipo de envolvimento (indicador da fonte ou regra derivada), gravidade e flags.';


--
-- Name: COLUMN trf_envolvido.numero_boletim_dw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.numero_boletim_dw IS 'Número do boletim no dw.';


--
-- Name: COLUMN trf_envolvido.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.ano IS 'Ano do sinistro.';


--
-- Name: COLUMN trf_envolvido.numero_envolvido; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.numero_envolvido IS 'Número do envolvido no boletim.';


--
-- Name: COLUMN trf_envolvido.tipo_envolvimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.tipo_envolvimento IS 'CONDUTOR, PASSAGEIRO, PEDESTRE ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_envolvido.origem_tipo_envolvimento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.origem_tipo_envolvimento IS 'INDICADOR DA FONTE (pedestre/passageiro/condutor informados) ou REGRA DERIVADA (2011–2015 e lacunas).';


--
-- Name: COLUMN trf_envolvido.cod_severidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.cod_severidade IS 'Severidade atual (0 n/i, 1 não fatal, 2 fatal, 3 sem ferimentos).';


--
-- Name: COLUMN trf_envolvido.gravidade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.gravidade IS 'Descrição da severidade.';


--
-- Name: COLUMN trf_envolvido.fl_vitima; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.fl_vitima IS 'Vítima = severidade 1 (não fatal) ou 2 (fatal); ileso e não informado não são vítimas.';


--
-- Name: COLUMN trf_envolvido.fl_vitima_fatal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.fl_vitima_fatal IS 'Severidade 2 (fatal).';


--
-- Name: COLUMN trf_envolvido.fl_condutor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.fl_condutor IS 'Tipo de envolvimento = CONDUTOR.';


--
-- Name: COLUMN trf_envolvido.fl_pedestre; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.fl_pedestre IS 'Tipo de envolvimento = PEDESTRE.';


--
-- Name: COLUMN trf_envolvido.fl_motociclista; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.fl_motociclista IS 'Condutor ou passageiro de veículo do grupo Motocicleta.';


--
-- Name: COLUMN trf_envolvido.sexo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.sexo IS 'MASCULINO, FEMININO ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_envolvido.idade; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.idade IS 'Idade em anos (nula quando 0 sem data de nascimento que a confirme, ou acima de 110).';


--
-- Name: COLUMN trf_envolvido.faixa_etaria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.faixa_etaria IS 'Faixa etária derivada da idade.';


--
-- Name: COLUMN trf_envolvido.embriaguez; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.embriaguez IS 'SIM, NÃO ou NÃO INFORMADO.';


--
-- Name: COLUMN trf_envolvido.especie_veiculo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.especie_veiculo IS 'Espécie do veículo em que a pessoa estava (padronizada); nula para pedestre.';


--
-- Name: COLUMN trf_envolvido.grupo_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.grupo_especie IS 'Grupo da espécie (Motocicleta, Automóvel/utilitário, Ônibus, Caminhão, Bicicleta, Outros).';


--
-- Name: COLUMN trf_envolvido.origem_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.origem_especie IS 'INFORMADA NO BOLETIM, IMPUTADA (ESPÉCIE ÚNICA NO BOLETIM), NÃO INFORMADA ou NÃO SE APLICA (PEDESTRE).';


--
-- Name: COLUMN trf_envolvido.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: COLUMN trf_envolvido.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.linha_arquivo IS 'Linhagem: linha no arquivo de origem.';


--
-- Name: COLUMN trf_envolvido.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_envolvido.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_local_versao; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_local_versao (
    chave_local text NOT NULL,
    versao smallint NOT NULL,
    dt_inicio date NOT NULL,
    dt_fim date NOT NULL,
    fl_versao_atual boolean NOT NULL,
    cod_logradouro_principal integer NOT NULL,
    tipo_logradouro_principal text NOT NULL,
    nome_logradouro_principal text NOT NULL,
    nome_anterior_principal text,
    cod_logradouro_cruzamento integer NOT NULL,
    tipo_logradouro_cruzamento text,
    nome_logradouro_cruzamento text,
    nome_anterior_cruzamento text,
    cod_bairro integer NOT NULL,
    nome_bairro text NOT NULL,
    fl_cruzamento boolean NOT NULL,
    descricao_local text NOT NULL,
    descricao_local_atual text NOT NULL,
    motivo_versao text NOT NULL,
    arquivo_origem text DEFAULT 'etl.transformar (logradouros)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_local_versao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_local_versao IS 'Versões (SCD Tipo 2) de cada local: uma nova versão a cada mudança de nome do logradouro principal ou do cruzamento.';


--
-- Name: COLUMN trf_local_versao.chave_local; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.chave_local IS 'Chave natural do local.';


--
-- Name: COLUMN trf_local_versao.versao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.versao IS 'Número da versão.';


--
-- Name: COLUMN trf_local_versao.dt_inicio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.dt_inicio IS 'Início da vigência.';


--
-- Name: COLUMN trf_local_versao.dt_fim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.dt_fim IS 'Fim da vigência (exclusivo).';


--
-- Name: COLUMN trf_local_versao.fl_versao_atual; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.fl_versao_atual IS 'Verdadeiro na versão vigente.';


--
-- Name: COLUMN trf_local_versao.cod_logradouro_principal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.cod_logradouro_principal IS 'Código do logradouro principal.';


--
-- Name: COLUMN trf_local_versao.tipo_logradouro_principal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.tipo_logradouro_principal IS 'Sigla do tipo do logradouro principal.';


--
-- Name: COLUMN trf_local_versao.nome_logradouro_principal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.nome_logradouro_principal IS 'Nome do logradouro principal na versão.';


--
-- Name: COLUMN trf_local_versao.nome_anterior_principal; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.nome_anterior_principal IS 'Nome anterior do logradouro principal.';


--
-- Name: COLUMN trf_local_versao.cod_logradouro_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.cod_logradouro_cruzamento IS 'Código do logradouro de cruzamento (0 = sem cruzamento).';


--
-- Name: COLUMN trf_local_versao.tipo_logradouro_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.tipo_logradouro_cruzamento IS 'Sigla do tipo do logradouro de cruzamento.';


--
-- Name: COLUMN trf_local_versao.nome_logradouro_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.nome_logradouro_cruzamento IS 'Nome do logradouro de cruzamento na versão.';


--
-- Name: COLUMN trf_local_versao.nome_anterior_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.nome_anterior_cruzamento IS 'Nome anterior do logradouro de cruzamento.';


--
-- Name: COLUMN trf_local_versao.cod_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.cod_bairro IS 'Código do bairro.';


--
-- Name: COLUMN trf_local_versao.nome_bairro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.nome_bairro IS 'Nome do bairro (mais recente, normalizado).';


--
-- Name: COLUMN trf_local_versao.fl_cruzamento; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.fl_cruzamento IS 'Verdadeiro se é cruzamento.';


--
-- Name: COLUMN trf_local_versao.descricao_local; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.descricao_local IS 'Descrição legível na versão (ex.: AVE X x RUA Y).';


--
-- Name: COLUMN trf_local_versao.descricao_local_atual; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.descricao_local_atual IS 'Descrição com os nomes atuais (igual em todas as versões).';


--
-- Name: COLUMN trf_local_versao.motivo_versao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.motivo_versao IS 'Motivo da abertura da versão.';


--
-- Name: COLUMN trf_local_versao.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_local_versao.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_local_versao.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_logradouro_versao; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_logradouro_versao (
    cod_logradouro integer NOT NULL,
    versao smallint NOT NULL,
    dt_inicio date NOT NULL,
    dt_fim date NOT NULL,
    tipo_logradouro text NOT NULL,
    nome_logradouro text NOT NULL,
    nome_anterior text,
    fl_renomeacao_confirmada boolean NOT NULL,
    variantes text,
    qtd_registros integer NOT NULL,
    arquivo_origem text DEFAULT 'etl.transformar (logradouros)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_logradouro_versao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_logradouro_versao IS 'Histórico de nomes por código de logradouro: variações de grafia consolidadas por similaridade; nova versão quando um nome sucede outro no tempo.';


--
-- Name: COLUMN trf_logradouro_versao.cod_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.cod_logradouro IS 'Código do logradouro no cadastro da PBH.';


--
-- Name: COLUMN trf_logradouro_versao.versao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.versao IS 'Número da versão (1 = mais antiga).';


--
-- Name: COLUMN trf_logradouro_versao.dt_inicio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.dt_inicio IS 'Início da vigência do nome (primeiro registro com o nome; 1900-01-01 na primeira versão).';


--
-- Name: COLUMN trf_logradouro_versao.dt_fim; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.dt_fim IS 'Fim da vigência (exclusivo; 9999-12-31 na versão atual).';


--
-- Name: COLUMN trf_logradouro_versao.tipo_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.tipo_logradouro IS 'Sigla do tipo de logradouro.';


--
-- Name: COLUMN trf_logradouro_versao.nome_logradouro; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.nome_logradouro IS 'Nome normalizado (maiúsculas, sem acento, abreviaturas expandidas).';


--
-- Name: COLUMN trf_logradouro_versao.nome_anterior; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.nome_anterior IS 'Nome da versão anterior.';


--
-- Name: COLUMN trf_logradouro_versao.fl_renomeacao_confirmada; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.fl_renomeacao_confirmada IS 'Verdadeiro se o campo nome_logradouro_anterior dos registros novos confirma o nome antigo.';


--
-- Name: COLUMN trf_logradouro_versao.variantes; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.variantes IS 'Grafias consolidadas nesta versão.';


--
-- Name: COLUMN trf_logradouro_versao.qtd_registros; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.qtd_registros IS 'Registros do si-log nesta versão.';


--
-- Name: COLUMN trf_logradouro_versao.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_logradouro_versao.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_logradouro_versao.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_populacao; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_populacao (
    ano smallint NOT NULL,
    cod_reg_limite smallint NOT NULL,
    populacao_residente integer NOT NULL,
    participacao numeric(12,10) NOT NULL,
    populacao_municipio integer NOT NULL,
    origem_dado text NOT NULL,
    origem_total_municipio text NOT NULL,
    metodo_regional text NOT NULL,
    arquivo_origem text DEFAULT 'etl.transformar (populacao)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_populacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_populacao IS 'População residente por regional e ano: participação da regional x população do município, com arredondamento pelo maior resto para fechar exatamente no total.';


--
-- Name: COLUMN trf_populacao.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.ano IS 'Ano de referência (1º de julho).';


--
-- Name: COLUMN trf_populacao.cod_reg_limite; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.cod_reg_limite IS 'Código da regional (COD_REG).';


--
-- Name: COLUMN trf_populacao.populacao_residente; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.populacao_residente IS 'População residente estimada da regional.';


--
-- Name: COLUMN trf_populacao.participacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.participacao IS 'Participação da regional na população do município.';


--
-- Name: COLUMN trf_populacao.populacao_municipio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.populacao_municipio IS 'População do município no ano.';


--
-- Name: COLUMN trf_populacao.origem_dado; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.origem_dado IS 'CENSO, ESTIMATIVA IBGE x PROPORÇÃO, INTERPOLADO x PROPORÇÃO.';


--
-- Name: COLUMN trf_populacao.origem_total_municipio; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.origem_total_municipio IS 'Origem do total municipal (tabela SIDRA ou interpolação geométrica).';


--
-- Name: COLUMN trf_populacao.metodo_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.metodo_regional IS 'Como a participação da regional foi obtida.';


--
-- Name: COLUMN trf_populacao.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_populacao.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_populacao.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_setor2010_regional; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_setor2010_regional (
    cod_setor text NOT NULL,
    cod_subdistrito text,
    nome_subdistrito text,
    cod_reg_limite smallint NOT NULL,
    metodo text NOT NULL,
    populacao integer NOT NULL,
    arquivo_origem text DEFAULT 'sql/carga (PostGIS)'::text NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_setor2010_regional; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_setor2010_regional IS 'Setores censitários de 2010 alocados às 9 regionais do limite 20220601 (ponto interior do setor dentro do polígono), para obter a população de 2010 nos limites atuais.';


--
-- Name: COLUMN trf_setor2010_regional.cod_setor; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.cod_setor IS 'Código do setor censitário 2010.';


--
-- Name: COLUMN trf_setor2010_regional.cod_subdistrito; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.cod_subdistrito IS 'Subdistrito IBGE do setor em 2010.';


--
-- Name: COLUMN trf_setor2010_regional.nome_subdistrito; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.nome_subdistrito IS 'Nome do subdistrito IBGE em 2010.';


--
-- Name: COLUMN trf_setor2010_regional.cod_reg_limite; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.cod_reg_limite IS 'Regional (COD_REG) em que o setor foi alocado.';


--
-- Name: COLUMN trf_setor2010_regional.metodo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.metodo IS 'PONTO NO POLÍGONO ou REGIONAL MAIS PRÓXIMA.';


--
-- Name: COLUMN trf_setor2010_regional.populacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.populacao IS 'Pessoas residentes no setor (Pessoa13, V001).';


--
-- Name: COLUMN trf_setor2010_regional.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.arquivo_origem IS 'Linhagem: processo que gerou o registro.';


--
-- Name: COLUMN trf_setor2010_regional.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_setor2010_regional.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: trf_veiculo; Type: TABLE; Schema: stg; Owner: -
--

CREATE TABLE stg.trf_veiculo (
    numero_boletim_dw text NOT NULL,
    ano smallint NOT NULL,
    sequencial_veiculo smallint NOT NULL,
    cod_categoria smallint NOT NULL,
    categoria text NOT NULL,
    cod_especie smallint NOT NULL,
    especie text NOT NULL,
    grupo_especie text NOT NULL,
    cod_situacao smallint NOT NULL,
    situacao text NOT NULL,
    arquivo_origem text NOT NULL,
    linha_arquivo integer NOT NULL,
    dt_carga timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE trf_veiculo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON TABLE stg.trf_veiculo IS 'Veículos envolvidos tipados, com descrições padronizadas pelos códigos e grupo de espécie.';


--
-- Name: COLUMN trf_veiculo.numero_boletim_dw; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.numero_boletim_dw IS 'Número do boletim no dw.';


--
-- Name: COLUMN trf_veiculo.ano; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.ano IS 'Ano do sinistro.';


--
-- Name: COLUMN trf_veiculo.sequencial_veiculo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.sequencial_veiculo IS 'Sequencial do veículo no boletim.';


--
-- Name: COLUMN trf_veiculo.cod_categoria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.cod_categoria IS 'Código da categoria.';


--
-- Name: COLUMN trf_veiculo.categoria; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.categoria IS 'Categoria padronizada.';


--
-- Name: COLUMN trf_veiculo.cod_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.cod_especie IS 'Código da espécie.';


--
-- Name: COLUMN trf_veiculo.especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.especie IS 'Espécie padronizada (pela descrição, pois o código 9 é usado para BONDE e TREM).';


--
-- Name: COLUMN trf_veiculo.grupo_especie; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.grupo_especie IS 'Grupo da espécie.';


--
-- Name: COLUMN trf_veiculo.cod_situacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.cod_situacao IS 'Código da situação.';


--
-- Name: COLUMN trf_veiculo.situacao; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.situacao IS 'Situação padronizada pelo código (3 = ESTACIONADO).';


--
-- Name: COLUMN trf_veiculo.arquivo_origem; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.arquivo_origem IS 'Linhagem: arquivo de origem.';


--
-- Name: COLUMN trf_veiculo.linha_arquivo; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.linha_arquivo IS 'Linhagem: linha no arquivo de origem.';


--
-- Name: COLUMN trf_veiculo.dt_carga; Type: COMMENT; Schema: stg; Owner: -
--

COMMENT ON COLUMN stg.trf_veiculo.dt_carga IS 'Linhagem: data e hora da transformação.';


--
-- Name: fato_envolvido_2011; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2011 FOR VALUES FROM ('2011') TO ('2012');


--
-- Name: fato_envolvido_2012; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2012 FOR VALUES FROM ('2012') TO ('2013');


--
-- Name: fato_envolvido_2013; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2013 FOR VALUES FROM ('2013') TO ('2014');


--
-- Name: fato_envolvido_2014; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2014 FOR VALUES FROM ('2014') TO ('2015');


--
-- Name: fato_envolvido_2015; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2015 FOR VALUES FROM ('2015') TO ('2016');


--
-- Name: fato_envolvido_2016; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2016 FOR VALUES FROM ('2016') TO ('2017');


--
-- Name: fato_envolvido_2017; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2017 FOR VALUES FROM ('2017') TO ('2018');


--
-- Name: fato_envolvido_2018; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2018 FOR VALUES FROM ('2018') TO ('2019');


--
-- Name: fato_envolvido_2019; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2019 FOR VALUES FROM ('2019') TO ('2020');


--
-- Name: fato_envolvido_2020; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2020 FOR VALUES FROM ('2020') TO ('2021');


--
-- Name: fato_envolvido_2021; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2021 FOR VALUES FROM ('2021') TO ('2022');


--
-- Name: fato_envolvido_2022; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2022 FOR VALUES FROM ('2022') TO ('2023');


--
-- Name: fato_envolvido_2023; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2023 FOR VALUES FROM ('2023') TO ('2024');


--
-- Name: fato_envolvido_2024; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2024 FOR VALUES FROM ('2024') TO ('2025');


--
-- Name: fato_envolvido_2025; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2025 FOR VALUES FROM ('2025') TO ('2026');


--
-- Name: fato_envolvido_2026; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_2026 FOR VALUES FROM ('2026') TO ('2027');


--
-- Name: fato_envolvido_default; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido ATTACH PARTITION dw.fato_envolvido_default DEFAULT;


--
-- Name: fato_sinistro_2011; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2011 FOR VALUES FROM ('2011') TO ('2012');


--
-- Name: fato_sinistro_2012; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2012 FOR VALUES FROM ('2012') TO ('2013');


--
-- Name: fato_sinistro_2013; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2013 FOR VALUES FROM ('2013') TO ('2014');


--
-- Name: fato_sinistro_2014; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2014 FOR VALUES FROM ('2014') TO ('2015');


--
-- Name: fato_sinistro_2015; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2015 FOR VALUES FROM ('2015') TO ('2016');


--
-- Name: fato_sinistro_2016; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2016 FOR VALUES FROM ('2016') TO ('2017');


--
-- Name: fato_sinistro_2017; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2017 FOR VALUES FROM ('2017') TO ('2018');


--
-- Name: fato_sinistro_2018; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2018 FOR VALUES FROM ('2018') TO ('2019');


--
-- Name: fato_sinistro_2019; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2019 FOR VALUES FROM ('2019') TO ('2020');


--
-- Name: fato_sinistro_2020; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2020 FOR VALUES FROM ('2020') TO ('2021');


--
-- Name: fato_sinistro_2021; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2021 FOR VALUES FROM ('2021') TO ('2022');


--
-- Name: fato_sinistro_2022; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2022 FOR VALUES FROM ('2022') TO ('2023');


--
-- Name: fato_sinistro_2023; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2023 FOR VALUES FROM ('2023') TO ('2024');


--
-- Name: fato_sinistro_2024; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2024 FOR VALUES FROM ('2024') TO ('2025');


--
-- Name: fato_sinistro_2025; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2025 FOR VALUES FROM ('2025') TO ('2026');


--
-- Name: fato_sinistro_2026; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_2026 FOR VALUES FROM ('2026') TO ('2027');


--
-- Name: fato_sinistro_default; Type: TABLE ATTACH; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro ATTACH PARTITION dw.fato_sinistro_default DEFAULT;


--
-- Name: log_carga id_log; Type: DEFAULT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.log_carga ALTER COLUMN id_log SET DEFAULT nextval('stg.log_carga_id_log_seq'::regclass);


--
-- Name: resultado_qualidade id_resultado; Type: DEFAULT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.resultado_qualidade ALTER COLUMN id_resultado SET DEFAULT nextval('stg.resultado_qualidade_id_resultado_seq'::regclass);


--
-- Name: dim_condicao_via dim_condicao_via_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_condicao_via
    ADD CONSTRAINT dim_condicao_via_pkey PRIMARY KEY (sk_condicao_via);


--
-- Name: dim_local dim_local_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_local
    ADD CONSTRAINT dim_local_pkey PRIMARY KEY (sk_local);


--
-- Name: dim_pessoa dim_pessoa_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_pessoa
    ADD CONSTRAINT dim_pessoa_pkey PRIMARY KEY (sk_pessoa);


--
-- Name: dim_regional dim_regional_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_regional
    ADD CONSTRAINT dim_regional_pkey PRIMARY KEY (sk_regional);


--
-- Name: dim_tempo dim_tempo_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_tempo
    ADD CONSTRAINT dim_tempo_pkey PRIMARY KEY (sk_tempo);


--
-- Name: dim_tipo_sinistro dim_tipo_sinistro_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_tipo_sinistro
    ADD CONSTRAINT dim_tipo_sinistro_pkey PRIMARY KEY (sk_tipo_sinistro);


--
-- Name: dim_veiculo dim_veiculo_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_veiculo
    ADD CONSTRAINT dim_veiculo_pkey PRIMARY KEY (sk_veiculo);


--
-- Name: fato_envolvido pk_fato_envolvido; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido
    ADD CONSTRAINT pk_fato_envolvido PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2011 fato_envolvido_2011_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2011
    ADD CONSTRAINT fato_envolvido_2011_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2012 fato_envolvido_2012_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2012
    ADD CONSTRAINT fato_envolvido_2012_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2013 fato_envolvido_2013_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2013
    ADD CONSTRAINT fato_envolvido_2013_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2014 fato_envolvido_2014_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2014
    ADD CONSTRAINT fato_envolvido_2014_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2015 fato_envolvido_2015_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2015
    ADD CONSTRAINT fato_envolvido_2015_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2016 fato_envolvido_2016_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2016
    ADD CONSTRAINT fato_envolvido_2016_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2017 fato_envolvido_2017_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2017
    ADD CONSTRAINT fato_envolvido_2017_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2018 fato_envolvido_2018_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2018
    ADD CONSTRAINT fato_envolvido_2018_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2019 fato_envolvido_2019_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2019
    ADD CONSTRAINT fato_envolvido_2019_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2020 fato_envolvido_2020_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2020
    ADD CONSTRAINT fato_envolvido_2020_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2021 fato_envolvido_2021_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2021
    ADD CONSTRAINT fato_envolvido_2021_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2022 fato_envolvido_2022_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2022
    ADD CONSTRAINT fato_envolvido_2022_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2023 fato_envolvido_2023_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2023
    ADD CONSTRAINT fato_envolvido_2023_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2024 fato_envolvido_2024_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2024
    ADD CONSTRAINT fato_envolvido_2024_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2025 fato_envolvido_2025_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2025
    ADD CONSTRAINT fato_envolvido_2025_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_2026 fato_envolvido_2026_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_2026
    ADD CONSTRAINT fato_envolvido_2026_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_envolvido_default fato_envolvido_default_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_envolvido_default
    ADD CONSTRAINT fato_envolvido_default_pkey PRIMARY KEY (numero_boletim, ano, numero_envolvido);


--
-- Name: fato_sinistro pk_fato_sinistro; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro
    ADD CONSTRAINT pk_fato_sinistro PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2011 fato_sinistro_2011_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2011
    ADD CONSTRAINT fato_sinistro_2011_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2012 fato_sinistro_2012_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2012
    ADD CONSTRAINT fato_sinistro_2012_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2013 fato_sinistro_2013_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2013
    ADD CONSTRAINT fato_sinistro_2013_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2014 fato_sinistro_2014_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2014
    ADD CONSTRAINT fato_sinistro_2014_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2015 fato_sinistro_2015_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2015
    ADD CONSTRAINT fato_sinistro_2015_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2016 fato_sinistro_2016_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2016
    ADD CONSTRAINT fato_sinistro_2016_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2017 fato_sinistro_2017_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2017
    ADD CONSTRAINT fato_sinistro_2017_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2018 fato_sinistro_2018_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2018
    ADD CONSTRAINT fato_sinistro_2018_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2019 fato_sinistro_2019_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2019
    ADD CONSTRAINT fato_sinistro_2019_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2020 fato_sinistro_2020_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2020
    ADD CONSTRAINT fato_sinistro_2020_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2021 fato_sinistro_2021_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2021
    ADD CONSTRAINT fato_sinistro_2021_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2022 fato_sinistro_2022_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2022
    ADD CONSTRAINT fato_sinistro_2022_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2023 fato_sinistro_2023_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2023
    ADD CONSTRAINT fato_sinistro_2023_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2024 fato_sinistro_2024_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2024
    ADD CONSTRAINT fato_sinistro_2024_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2025 fato_sinistro_2025_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2025
    ADD CONSTRAINT fato_sinistro_2025_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_2026 fato_sinistro_2026_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_2026
    ADD CONSTRAINT fato_sinistro_2026_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_sinistro_default fato_sinistro_default_pkey; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_sinistro_default
    ADD CONSTRAINT fato_sinistro_default_pkey PRIMARY KEY (numero_boletim, ano);


--
-- Name: fato_populacao pk_fato_populacao; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_populacao
    ADD CONSTRAINT pk_fato_populacao PRIMARY KEY (sk_regional, ano);


--
-- Name: dim_condicao_via uq_dim_condicao_via; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_condicao_via
    ADD CONSTRAINT uq_dim_condicao_via UNIQUE (cod_tempo, condicao_climatica, origem_clima, cod_pavimento, local_sinalizado);


--
-- Name: dim_local uq_dim_local_versao; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_local
    ADD CONSTRAINT uq_dim_local_versao UNIQUE (chave_natural, versao);


--
-- Name: dim_pessoa uq_dim_pessoa; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_pessoa
    ADD CONSTRAINT uq_dim_pessoa UNIQUE (tipo_envolvimento, sexo, faixa_etaria, embriaguez);


--
-- Name: dim_regional uq_dim_regional_cod; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_regional
    ADD CONSTRAINT uq_dim_regional_cod UNIQUE (cod_regional);


--
-- Name: dim_tipo_sinistro uq_dim_tipo_sinistro_cod; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_tipo_sinistro
    ADD CONSTRAINT uq_dim_tipo_sinistro_cod UNIQUE (cod_tipo_sinistro);


--
-- Name: dim_veiculo uq_dim_veiculo; Type: CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.dim_veiculo
    ADD CONSTRAINT uq_dim_veiculo UNIQUE (especie, categoria, situacao);


--
-- Name: log_carga log_carga_pkey; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.log_carga
    ADD CONSTRAINT log_carga_pkey PRIMARY KEY (id_log);


--
-- Name: manifesto_raw pk_manifesto_raw; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.manifesto_raw
    ADD CONSTRAINT pk_manifesto_raw PRIMARY KEY (arquivo);


--
-- Name: map_dominio pk_map_dominio; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.map_dominio
    ADD CONSTRAINT pk_map_dominio PRIMARY KEY (dominio, codigo);


--
-- Name: map_regional pk_map_regional; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.map_regional
    ADD CONSTRAINT pk_map_regional PRIMARY KEY (cod_regional_boletim);


--
-- Name: trf_boletim pk_trf_boletim; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_boletim
    ADD CONSTRAINT pk_trf_boletim PRIMARY KEY (numero_boletim_dw, ano);


--
-- Name: trf_boletim_local pk_trf_boletim_local; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_boletim_local
    ADD CONSTRAINT pk_trf_boletim_local PRIMARY KEY (numero_boletim_dw, ano);


--
-- Name: trf_clima_hora pk_trf_clima_hora; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_clima_hora
    ADD CONSTRAINT pk_trf_clima_hora PRIMARY KEY (estacao_codigo, dt_hora_inicio_local);


--
-- Name: trf_coordenada pk_trf_coordenada; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_coordenada
    ADD CONSTRAINT pk_trf_coordenada PRIMARY KEY (numero_boletim_dw, ano);


--
-- Name: trf_envolvido pk_trf_envolvido; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_envolvido
    ADD CONSTRAINT pk_trf_envolvido PRIMARY KEY (numero_boletim_dw, ano, numero_envolvido);


--
-- Name: trf_local_versao pk_trf_local_versao; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_local_versao
    ADD CONSTRAINT pk_trf_local_versao PRIMARY KEY (chave_local, versao);


--
-- Name: trf_logradouro_versao pk_trf_logradouro_versao; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_logradouro_versao
    ADD CONSTRAINT pk_trf_logradouro_versao PRIMARY KEY (cod_logradouro, versao);


--
-- Name: trf_populacao pk_trf_populacao; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_populacao
    ADD CONSTRAINT pk_trf_populacao PRIMARY KEY (ano, cod_reg_limite);


--
-- Name: trf_setor2010_regional pk_trf_setor2010_regional; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_setor2010_regional
    ADD CONSTRAINT pk_trf_setor2010_regional PRIMARY KEY (cod_setor);


--
-- Name: trf_veiculo pk_trf_veiculo; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.trf_veiculo
    ADD CONSTRAINT pk_trf_veiculo PRIMARY KEY (numero_boletim_dw, ano, sequencial_veiculo);


--
-- Name: resultado_qualidade resultado_qualidade_pkey; Type: CONSTRAINT; Schema: stg; Owner: -
--

ALTER TABLE ONLY stg.resultado_qualidade
    ADD CONSTRAINT resultado_qualidade_pkey PRIMARY KEY (id_resultado);


--
-- Name: ix_fato_envolvido_sk_local; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_envolvido_sk_local ON ONLY dw.fato_envolvido USING btree (sk_local);


--
-- Name: fato_envolvido_2011_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2011_sk_local_idx ON dw.fato_envolvido_2011 USING btree (sk_local);


--
-- Name: ix_fato_envolvido_sk_pessoa; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_envolvido_sk_pessoa ON ONLY dw.fato_envolvido USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2011_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2011_sk_pessoa_idx ON dw.fato_envolvido_2011 USING btree (sk_pessoa);


--
-- Name: ix_fato_envolvido_sk_regional; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_envolvido_sk_regional ON ONLY dw.fato_envolvido USING btree (sk_regional);


--
-- Name: fato_envolvido_2011_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2011_sk_regional_idx ON dw.fato_envolvido_2011 USING btree (sk_regional);


--
-- Name: ix_fato_envolvido_sk_tempo; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_envolvido_sk_tempo ON ONLY dw.fato_envolvido USING btree (sk_tempo);


--
-- Name: fato_envolvido_2011_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2011_sk_tempo_idx ON dw.fato_envolvido_2011 USING btree (sk_tempo);


--
-- Name: ix_fato_envolvido_sk_veiculo; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_envolvido_sk_veiculo ON ONLY dw.fato_envolvido USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2011_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2011_sk_veiculo_idx ON dw.fato_envolvido_2011 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2012_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2012_sk_local_idx ON dw.fato_envolvido_2012 USING btree (sk_local);


--
-- Name: fato_envolvido_2012_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2012_sk_pessoa_idx ON dw.fato_envolvido_2012 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2012_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2012_sk_regional_idx ON dw.fato_envolvido_2012 USING btree (sk_regional);


--
-- Name: fato_envolvido_2012_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2012_sk_tempo_idx ON dw.fato_envolvido_2012 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2012_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2012_sk_veiculo_idx ON dw.fato_envolvido_2012 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2013_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2013_sk_local_idx ON dw.fato_envolvido_2013 USING btree (sk_local);


--
-- Name: fato_envolvido_2013_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2013_sk_pessoa_idx ON dw.fato_envolvido_2013 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2013_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2013_sk_regional_idx ON dw.fato_envolvido_2013 USING btree (sk_regional);


--
-- Name: fato_envolvido_2013_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2013_sk_tempo_idx ON dw.fato_envolvido_2013 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2013_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2013_sk_veiculo_idx ON dw.fato_envolvido_2013 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2014_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2014_sk_local_idx ON dw.fato_envolvido_2014 USING btree (sk_local);


--
-- Name: fato_envolvido_2014_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2014_sk_pessoa_idx ON dw.fato_envolvido_2014 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2014_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2014_sk_regional_idx ON dw.fato_envolvido_2014 USING btree (sk_regional);


--
-- Name: fato_envolvido_2014_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2014_sk_tempo_idx ON dw.fato_envolvido_2014 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2014_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2014_sk_veiculo_idx ON dw.fato_envolvido_2014 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2015_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2015_sk_local_idx ON dw.fato_envolvido_2015 USING btree (sk_local);


--
-- Name: fato_envolvido_2015_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2015_sk_pessoa_idx ON dw.fato_envolvido_2015 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2015_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2015_sk_regional_idx ON dw.fato_envolvido_2015 USING btree (sk_regional);


--
-- Name: fato_envolvido_2015_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2015_sk_tempo_idx ON dw.fato_envolvido_2015 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2015_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2015_sk_veiculo_idx ON dw.fato_envolvido_2015 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2016_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2016_sk_local_idx ON dw.fato_envolvido_2016 USING btree (sk_local);


--
-- Name: fato_envolvido_2016_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2016_sk_pessoa_idx ON dw.fato_envolvido_2016 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2016_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2016_sk_regional_idx ON dw.fato_envolvido_2016 USING btree (sk_regional);


--
-- Name: fato_envolvido_2016_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2016_sk_tempo_idx ON dw.fato_envolvido_2016 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2016_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2016_sk_veiculo_idx ON dw.fato_envolvido_2016 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2017_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2017_sk_local_idx ON dw.fato_envolvido_2017 USING btree (sk_local);


--
-- Name: fato_envolvido_2017_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2017_sk_pessoa_idx ON dw.fato_envolvido_2017 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2017_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2017_sk_regional_idx ON dw.fato_envolvido_2017 USING btree (sk_regional);


--
-- Name: fato_envolvido_2017_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2017_sk_tempo_idx ON dw.fato_envolvido_2017 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2017_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2017_sk_veiculo_idx ON dw.fato_envolvido_2017 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2018_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2018_sk_local_idx ON dw.fato_envolvido_2018 USING btree (sk_local);


--
-- Name: fato_envolvido_2018_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2018_sk_pessoa_idx ON dw.fato_envolvido_2018 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2018_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2018_sk_regional_idx ON dw.fato_envolvido_2018 USING btree (sk_regional);


--
-- Name: fato_envolvido_2018_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2018_sk_tempo_idx ON dw.fato_envolvido_2018 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2018_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2018_sk_veiculo_idx ON dw.fato_envolvido_2018 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2019_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2019_sk_local_idx ON dw.fato_envolvido_2019 USING btree (sk_local);


--
-- Name: fato_envolvido_2019_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2019_sk_pessoa_idx ON dw.fato_envolvido_2019 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2019_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2019_sk_regional_idx ON dw.fato_envolvido_2019 USING btree (sk_regional);


--
-- Name: fato_envolvido_2019_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2019_sk_tempo_idx ON dw.fato_envolvido_2019 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2019_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2019_sk_veiculo_idx ON dw.fato_envolvido_2019 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2020_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2020_sk_local_idx ON dw.fato_envolvido_2020 USING btree (sk_local);


--
-- Name: fato_envolvido_2020_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2020_sk_pessoa_idx ON dw.fato_envolvido_2020 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2020_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2020_sk_regional_idx ON dw.fato_envolvido_2020 USING btree (sk_regional);


--
-- Name: fato_envolvido_2020_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2020_sk_tempo_idx ON dw.fato_envolvido_2020 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2020_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2020_sk_veiculo_idx ON dw.fato_envolvido_2020 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2021_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2021_sk_local_idx ON dw.fato_envolvido_2021 USING btree (sk_local);


--
-- Name: fato_envolvido_2021_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2021_sk_pessoa_idx ON dw.fato_envolvido_2021 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2021_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2021_sk_regional_idx ON dw.fato_envolvido_2021 USING btree (sk_regional);


--
-- Name: fato_envolvido_2021_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2021_sk_tempo_idx ON dw.fato_envolvido_2021 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2021_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2021_sk_veiculo_idx ON dw.fato_envolvido_2021 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2022_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2022_sk_local_idx ON dw.fato_envolvido_2022 USING btree (sk_local);


--
-- Name: fato_envolvido_2022_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2022_sk_pessoa_idx ON dw.fato_envolvido_2022 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2022_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2022_sk_regional_idx ON dw.fato_envolvido_2022 USING btree (sk_regional);


--
-- Name: fato_envolvido_2022_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2022_sk_tempo_idx ON dw.fato_envolvido_2022 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2022_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2022_sk_veiculo_idx ON dw.fato_envolvido_2022 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2023_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2023_sk_local_idx ON dw.fato_envolvido_2023 USING btree (sk_local);


--
-- Name: fato_envolvido_2023_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2023_sk_pessoa_idx ON dw.fato_envolvido_2023 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2023_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2023_sk_regional_idx ON dw.fato_envolvido_2023 USING btree (sk_regional);


--
-- Name: fato_envolvido_2023_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2023_sk_tempo_idx ON dw.fato_envolvido_2023 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2023_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2023_sk_veiculo_idx ON dw.fato_envolvido_2023 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2024_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2024_sk_local_idx ON dw.fato_envolvido_2024 USING btree (sk_local);


--
-- Name: fato_envolvido_2024_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2024_sk_pessoa_idx ON dw.fato_envolvido_2024 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2024_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2024_sk_regional_idx ON dw.fato_envolvido_2024 USING btree (sk_regional);


--
-- Name: fato_envolvido_2024_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2024_sk_tempo_idx ON dw.fato_envolvido_2024 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2024_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2024_sk_veiculo_idx ON dw.fato_envolvido_2024 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2025_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2025_sk_local_idx ON dw.fato_envolvido_2025 USING btree (sk_local);


--
-- Name: fato_envolvido_2025_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2025_sk_pessoa_idx ON dw.fato_envolvido_2025 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2025_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2025_sk_regional_idx ON dw.fato_envolvido_2025 USING btree (sk_regional);


--
-- Name: fato_envolvido_2025_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2025_sk_tempo_idx ON dw.fato_envolvido_2025 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2025_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2025_sk_veiculo_idx ON dw.fato_envolvido_2025 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_2026_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2026_sk_local_idx ON dw.fato_envolvido_2026 USING btree (sk_local);


--
-- Name: fato_envolvido_2026_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2026_sk_pessoa_idx ON dw.fato_envolvido_2026 USING btree (sk_pessoa);


--
-- Name: fato_envolvido_2026_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2026_sk_regional_idx ON dw.fato_envolvido_2026 USING btree (sk_regional);


--
-- Name: fato_envolvido_2026_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2026_sk_tempo_idx ON dw.fato_envolvido_2026 USING btree (sk_tempo);


--
-- Name: fato_envolvido_2026_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_2026_sk_veiculo_idx ON dw.fato_envolvido_2026 USING btree (sk_veiculo);


--
-- Name: fato_envolvido_default_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_default_sk_local_idx ON dw.fato_envolvido_default USING btree (sk_local);


--
-- Name: fato_envolvido_default_sk_pessoa_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_default_sk_pessoa_idx ON dw.fato_envolvido_default USING btree (sk_pessoa);


--
-- Name: fato_envolvido_default_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_default_sk_regional_idx ON dw.fato_envolvido_default USING btree (sk_regional);


--
-- Name: fato_envolvido_default_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_default_sk_tempo_idx ON dw.fato_envolvido_default USING btree (sk_tempo);


--
-- Name: fato_envolvido_default_sk_veiculo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_envolvido_default_sk_veiculo_idx ON dw.fato_envolvido_default USING btree (sk_veiculo);


--
-- Name: gix_fato_sinistro_geom; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX gix_fato_sinistro_geom ON ONLY dw.fato_sinistro USING gist (geom);


--
-- Name: fato_sinistro_2011_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_geom_idx ON dw.fato_sinistro_2011 USING gist (geom);


--
-- Name: ix_fato_sinistro_sk_condicao_via; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_sinistro_sk_condicao_via ON ONLY dw.fato_sinistro USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2011_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_sk_condicao_via_idx ON dw.fato_sinistro_2011 USING btree (sk_condicao_via);


--
-- Name: ix_fato_sinistro_sk_local; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_sinistro_sk_local ON ONLY dw.fato_sinistro USING btree (sk_local);


--
-- Name: fato_sinistro_2011_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_sk_local_idx ON dw.fato_sinistro_2011 USING btree (sk_local);


--
-- Name: ix_fato_sinistro_sk_regional; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_sinistro_sk_regional ON ONLY dw.fato_sinistro USING btree (sk_regional);


--
-- Name: fato_sinistro_2011_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_sk_regional_idx ON dw.fato_sinistro_2011 USING btree (sk_regional);


--
-- Name: ix_fato_sinistro_sk_tempo; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_sinistro_sk_tempo ON ONLY dw.fato_sinistro USING btree (sk_tempo);


--
-- Name: fato_sinistro_2011_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_sk_tempo_idx ON dw.fato_sinistro_2011 USING btree (sk_tempo);


--
-- Name: ix_fato_sinistro_sk_tipo_sinistro; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_sinistro_sk_tipo_sinistro ON ONLY dw.fato_sinistro USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2011_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2011_sk_tipo_sinistro_idx ON dw.fato_sinistro_2011 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2012_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_geom_idx ON dw.fato_sinistro_2012 USING gist (geom);


--
-- Name: fato_sinistro_2012_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_sk_condicao_via_idx ON dw.fato_sinistro_2012 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2012_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_sk_local_idx ON dw.fato_sinistro_2012 USING btree (sk_local);


--
-- Name: fato_sinistro_2012_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_sk_regional_idx ON dw.fato_sinistro_2012 USING btree (sk_regional);


--
-- Name: fato_sinistro_2012_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_sk_tempo_idx ON dw.fato_sinistro_2012 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2012_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2012_sk_tipo_sinistro_idx ON dw.fato_sinistro_2012 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2013_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_geom_idx ON dw.fato_sinistro_2013 USING gist (geom);


--
-- Name: fato_sinistro_2013_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_sk_condicao_via_idx ON dw.fato_sinistro_2013 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2013_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_sk_local_idx ON dw.fato_sinistro_2013 USING btree (sk_local);


--
-- Name: fato_sinistro_2013_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_sk_regional_idx ON dw.fato_sinistro_2013 USING btree (sk_regional);


--
-- Name: fato_sinistro_2013_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_sk_tempo_idx ON dw.fato_sinistro_2013 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2013_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2013_sk_tipo_sinistro_idx ON dw.fato_sinistro_2013 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2014_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_geom_idx ON dw.fato_sinistro_2014 USING gist (geom);


--
-- Name: fato_sinistro_2014_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_sk_condicao_via_idx ON dw.fato_sinistro_2014 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2014_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_sk_local_idx ON dw.fato_sinistro_2014 USING btree (sk_local);


--
-- Name: fato_sinistro_2014_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_sk_regional_idx ON dw.fato_sinistro_2014 USING btree (sk_regional);


--
-- Name: fato_sinistro_2014_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_sk_tempo_idx ON dw.fato_sinistro_2014 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2014_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2014_sk_tipo_sinistro_idx ON dw.fato_sinistro_2014 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2015_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_geom_idx ON dw.fato_sinistro_2015 USING gist (geom);


--
-- Name: fato_sinistro_2015_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_sk_condicao_via_idx ON dw.fato_sinistro_2015 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2015_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_sk_local_idx ON dw.fato_sinistro_2015 USING btree (sk_local);


--
-- Name: fato_sinistro_2015_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_sk_regional_idx ON dw.fato_sinistro_2015 USING btree (sk_regional);


--
-- Name: fato_sinistro_2015_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_sk_tempo_idx ON dw.fato_sinistro_2015 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2015_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2015_sk_tipo_sinistro_idx ON dw.fato_sinistro_2015 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2016_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_geom_idx ON dw.fato_sinistro_2016 USING gist (geom);


--
-- Name: fato_sinistro_2016_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_sk_condicao_via_idx ON dw.fato_sinistro_2016 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2016_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_sk_local_idx ON dw.fato_sinistro_2016 USING btree (sk_local);


--
-- Name: fato_sinistro_2016_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_sk_regional_idx ON dw.fato_sinistro_2016 USING btree (sk_regional);


--
-- Name: fato_sinistro_2016_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_sk_tempo_idx ON dw.fato_sinistro_2016 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2016_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2016_sk_tipo_sinistro_idx ON dw.fato_sinistro_2016 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2017_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_geom_idx ON dw.fato_sinistro_2017 USING gist (geom);


--
-- Name: fato_sinistro_2017_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_sk_condicao_via_idx ON dw.fato_sinistro_2017 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2017_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_sk_local_idx ON dw.fato_sinistro_2017 USING btree (sk_local);


--
-- Name: fato_sinistro_2017_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_sk_regional_idx ON dw.fato_sinistro_2017 USING btree (sk_regional);


--
-- Name: fato_sinistro_2017_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_sk_tempo_idx ON dw.fato_sinistro_2017 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2017_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2017_sk_tipo_sinistro_idx ON dw.fato_sinistro_2017 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2018_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_geom_idx ON dw.fato_sinistro_2018 USING gist (geom);


--
-- Name: fato_sinistro_2018_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_sk_condicao_via_idx ON dw.fato_sinistro_2018 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2018_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_sk_local_idx ON dw.fato_sinistro_2018 USING btree (sk_local);


--
-- Name: fato_sinistro_2018_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_sk_regional_idx ON dw.fato_sinistro_2018 USING btree (sk_regional);


--
-- Name: fato_sinistro_2018_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_sk_tempo_idx ON dw.fato_sinistro_2018 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2018_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2018_sk_tipo_sinistro_idx ON dw.fato_sinistro_2018 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2019_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_geom_idx ON dw.fato_sinistro_2019 USING gist (geom);


--
-- Name: fato_sinistro_2019_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_sk_condicao_via_idx ON dw.fato_sinistro_2019 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2019_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_sk_local_idx ON dw.fato_sinistro_2019 USING btree (sk_local);


--
-- Name: fato_sinistro_2019_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_sk_regional_idx ON dw.fato_sinistro_2019 USING btree (sk_regional);


--
-- Name: fato_sinistro_2019_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_sk_tempo_idx ON dw.fato_sinistro_2019 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2019_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2019_sk_tipo_sinistro_idx ON dw.fato_sinistro_2019 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2020_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_geom_idx ON dw.fato_sinistro_2020 USING gist (geom);


--
-- Name: fato_sinistro_2020_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_sk_condicao_via_idx ON dw.fato_sinistro_2020 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2020_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_sk_local_idx ON dw.fato_sinistro_2020 USING btree (sk_local);


--
-- Name: fato_sinistro_2020_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_sk_regional_idx ON dw.fato_sinistro_2020 USING btree (sk_regional);


--
-- Name: fato_sinistro_2020_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_sk_tempo_idx ON dw.fato_sinistro_2020 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2020_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2020_sk_tipo_sinistro_idx ON dw.fato_sinistro_2020 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2021_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_geom_idx ON dw.fato_sinistro_2021 USING gist (geom);


--
-- Name: fato_sinistro_2021_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_sk_condicao_via_idx ON dw.fato_sinistro_2021 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2021_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_sk_local_idx ON dw.fato_sinistro_2021 USING btree (sk_local);


--
-- Name: fato_sinistro_2021_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_sk_regional_idx ON dw.fato_sinistro_2021 USING btree (sk_regional);


--
-- Name: fato_sinistro_2021_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_sk_tempo_idx ON dw.fato_sinistro_2021 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2021_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2021_sk_tipo_sinistro_idx ON dw.fato_sinistro_2021 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2022_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_geom_idx ON dw.fato_sinistro_2022 USING gist (geom);


--
-- Name: fato_sinistro_2022_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_sk_condicao_via_idx ON dw.fato_sinistro_2022 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2022_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_sk_local_idx ON dw.fato_sinistro_2022 USING btree (sk_local);


--
-- Name: fato_sinistro_2022_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_sk_regional_idx ON dw.fato_sinistro_2022 USING btree (sk_regional);


--
-- Name: fato_sinistro_2022_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_sk_tempo_idx ON dw.fato_sinistro_2022 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2022_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2022_sk_tipo_sinistro_idx ON dw.fato_sinistro_2022 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2023_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_geom_idx ON dw.fato_sinistro_2023 USING gist (geom);


--
-- Name: fato_sinistro_2023_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_sk_condicao_via_idx ON dw.fato_sinistro_2023 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2023_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_sk_local_idx ON dw.fato_sinistro_2023 USING btree (sk_local);


--
-- Name: fato_sinistro_2023_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_sk_regional_idx ON dw.fato_sinistro_2023 USING btree (sk_regional);


--
-- Name: fato_sinistro_2023_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_sk_tempo_idx ON dw.fato_sinistro_2023 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2023_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2023_sk_tipo_sinistro_idx ON dw.fato_sinistro_2023 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2024_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_geom_idx ON dw.fato_sinistro_2024 USING gist (geom);


--
-- Name: fato_sinistro_2024_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_sk_condicao_via_idx ON dw.fato_sinistro_2024 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2024_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_sk_local_idx ON dw.fato_sinistro_2024 USING btree (sk_local);


--
-- Name: fato_sinistro_2024_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_sk_regional_idx ON dw.fato_sinistro_2024 USING btree (sk_regional);


--
-- Name: fato_sinistro_2024_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_sk_tempo_idx ON dw.fato_sinistro_2024 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2024_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2024_sk_tipo_sinistro_idx ON dw.fato_sinistro_2024 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2025_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_geom_idx ON dw.fato_sinistro_2025 USING gist (geom);


--
-- Name: fato_sinistro_2025_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_sk_condicao_via_idx ON dw.fato_sinistro_2025 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2025_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_sk_local_idx ON dw.fato_sinistro_2025 USING btree (sk_local);


--
-- Name: fato_sinistro_2025_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_sk_regional_idx ON dw.fato_sinistro_2025 USING btree (sk_regional);


--
-- Name: fato_sinistro_2025_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_sk_tempo_idx ON dw.fato_sinistro_2025 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2025_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2025_sk_tipo_sinistro_idx ON dw.fato_sinistro_2025 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_2026_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_geom_idx ON dw.fato_sinistro_2026 USING gist (geom);


--
-- Name: fato_sinistro_2026_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_sk_condicao_via_idx ON dw.fato_sinistro_2026 USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_2026_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_sk_local_idx ON dw.fato_sinistro_2026 USING btree (sk_local);


--
-- Name: fato_sinistro_2026_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_sk_regional_idx ON dw.fato_sinistro_2026 USING btree (sk_regional);


--
-- Name: fato_sinistro_2026_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_sk_tempo_idx ON dw.fato_sinistro_2026 USING btree (sk_tempo);


--
-- Name: fato_sinistro_2026_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_2026_sk_tipo_sinistro_idx ON dw.fato_sinistro_2026 USING btree (sk_tipo_sinistro);


--
-- Name: fato_sinistro_default_geom_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_geom_idx ON dw.fato_sinistro_default USING gist (geom);


--
-- Name: fato_sinistro_default_sk_condicao_via_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_sk_condicao_via_idx ON dw.fato_sinistro_default USING btree (sk_condicao_via);


--
-- Name: fato_sinistro_default_sk_local_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_sk_local_idx ON dw.fato_sinistro_default USING btree (sk_local);


--
-- Name: fato_sinistro_default_sk_regional_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_sk_regional_idx ON dw.fato_sinistro_default USING btree (sk_regional);


--
-- Name: fato_sinistro_default_sk_tempo_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_sk_tempo_idx ON dw.fato_sinistro_default USING btree (sk_tempo);


--
-- Name: fato_sinistro_default_sk_tipo_sinistro_idx; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX fato_sinistro_default_sk_tipo_sinistro_idx ON dw.fato_sinistro_default USING btree (sk_tipo_sinistro);


--
-- Name: gix_dim_local_geom; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX gix_dim_local_geom ON dw.dim_local USING gist (geom);


--
-- Name: gix_dim_regional_geom; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX gix_dim_regional_geom ON dw.dim_regional USING gist (geom);


--
-- Name: ix_dim_local_chave_vigencia; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_dim_local_chave_vigencia ON dw.dim_local USING btree (chave_natural, dt_inicio_vigencia, dt_fim_vigencia);


--
-- Name: ix_dim_local_descricao_trgm; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_dim_local_descricao_trgm ON dw.dim_local USING gin (descricao_local_atual public.gin_trgm_ops);


--
-- Name: ix_dim_tempo_ano_mes; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_dim_tempo_ano_mes ON dw.dim_tempo USING btree (ano, mes);


--
-- Name: ix_dim_tempo_data; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_dim_tempo_data ON dw.dim_tempo USING btree (data);


--
-- Name: ix_fato_populacao_sk_tempo; Type: INDEX; Schema: dw; Owner: -
--

CREATE INDEX ix_fato_populacao_sk_tempo ON dw.fato_populacao USING btree (sk_tempo);


--
-- Name: ux_mv_indicadores_regional_ano; Type: INDEX; Schema: dw; Owner: -
--

CREATE UNIQUE INDEX ux_mv_indicadores_regional_ano ON dw.mv_indicadores_regional_ano USING btree (ano, sk_regional);


--
-- Name: ux_mv_participacao_vitimas_ano; Type: INDEX; Schema: dw; Owner: -
--

CREATE UNIQUE INDEX ux_mv_participacao_vitimas_ano ON dw.mv_participacao_vitimas_ano USING btree (ano);


--
-- Name: ux_mv_ranking_locais; Type: INDEX; Schema: dw; Owner: -
--

CREATE UNIQUE INDEX ux_mv_ranking_locais ON dw.mv_ranking_locais USING btree (chave_natural, ano);


--
-- Name: ux_mv_taxa_mortalidade_anual; Type: INDEX; Schema: dw; Owner: -
--

CREATE UNIQUE INDEX ux_mv_taxa_mortalidade_anual ON dw.mv_taxa_mortalidade_anual USING btree (ano);


--
-- Name: gix_trf_coordenada_geom; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX gix_trf_coordenada_geom ON stg.trf_coordenada USING gist (geom);


--
-- Name: ix_stg_si_bol_boletim; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX ix_stg_si_bol_boletim ON stg.si_bol USING btree (numero_boletim, ano_arquivo);


--
-- Name: ix_stg_si_env_boletim; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX ix_stg_si_env_boletim ON stg.si_env USING btree (numero_boletim, ano_arquivo);


--
-- Name: ix_stg_si_log_boletim; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX ix_stg_si_log_boletim ON stg.si_log USING btree (numero_boletim, ano_arquivo);


--
-- Name: ix_stg_si_veic_boletim; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX ix_stg_si_veic_boletim ON stg.si_veic USING btree (numero_boletim, ano_arquivo);


--
-- Name: ix_trf_boletim_origem; Type: INDEX; Schema: stg; Owner: -
--

CREATE INDEX ix_trf_boletim_origem ON stg.trf_boletim USING btree (numero_boletim_origem, ano);


--
-- Name: fato_envolvido_2011_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2011_pkey;


--
-- Name: fato_envolvido_2011_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2011_sk_local_idx;


--
-- Name: fato_envolvido_2011_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2011_sk_pessoa_idx;


--
-- Name: fato_envolvido_2011_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2011_sk_regional_idx;


--
-- Name: fato_envolvido_2011_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2011_sk_tempo_idx;


--
-- Name: fato_envolvido_2011_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2011_sk_veiculo_idx;


--
-- Name: fato_envolvido_2012_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2012_pkey;


--
-- Name: fato_envolvido_2012_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2012_sk_local_idx;


--
-- Name: fato_envolvido_2012_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2012_sk_pessoa_idx;


--
-- Name: fato_envolvido_2012_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2012_sk_regional_idx;


--
-- Name: fato_envolvido_2012_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2012_sk_tempo_idx;


--
-- Name: fato_envolvido_2012_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2012_sk_veiculo_idx;


--
-- Name: fato_envolvido_2013_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2013_pkey;


--
-- Name: fato_envolvido_2013_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2013_sk_local_idx;


--
-- Name: fato_envolvido_2013_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2013_sk_pessoa_idx;


--
-- Name: fato_envolvido_2013_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2013_sk_regional_idx;


--
-- Name: fato_envolvido_2013_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2013_sk_tempo_idx;


--
-- Name: fato_envolvido_2013_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2013_sk_veiculo_idx;


--
-- Name: fato_envolvido_2014_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2014_pkey;


--
-- Name: fato_envolvido_2014_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2014_sk_local_idx;


--
-- Name: fato_envolvido_2014_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2014_sk_pessoa_idx;


--
-- Name: fato_envolvido_2014_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2014_sk_regional_idx;


--
-- Name: fato_envolvido_2014_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2014_sk_tempo_idx;


--
-- Name: fato_envolvido_2014_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2014_sk_veiculo_idx;


--
-- Name: fato_envolvido_2015_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2015_pkey;


--
-- Name: fato_envolvido_2015_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2015_sk_local_idx;


--
-- Name: fato_envolvido_2015_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2015_sk_pessoa_idx;


--
-- Name: fato_envolvido_2015_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2015_sk_regional_idx;


--
-- Name: fato_envolvido_2015_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2015_sk_tempo_idx;


--
-- Name: fato_envolvido_2015_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2015_sk_veiculo_idx;


--
-- Name: fato_envolvido_2016_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2016_pkey;


--
-- Name: fato_envolvido_2016_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2016_sk_local_idx;


--
-- Name: fato_envolvido_2016_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2016_sk_pessoa_idx;


--
-- Name: fato_envolvido_2016_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2016_sk_regional_idx;


--
-- Name: fato_envolvido_2016_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2016_sk_tempo_idx;


--
-- Name: fato_envolvido_2016_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2016_sk_veiculo_idx;


--
-- Name: fato_envolvido_2017_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2017_pkey;


--
-- Name: fato_envolvido_2017_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2017_sk_local_idx;


--
-- Name: fato_envolvido_2017_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2017_sk_pessoa_idx;


--
-- Name: fato_envolvido_2017_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2017_sk_regional_idx;


--
-- Name: fato_envolvido_2017_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2017_sk_tempo_idx;


--
-- Name: fato_envolvido_2017_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2017_sk_veiculo_idx;


--
-- Name: fato_envolvido_2018_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2018_pkey;


--
-- Name: fato_envolvido_2018_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2018_sk_local_idx;


--
-- Name: fato_envolvido_2018_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2018_sk_pessoa_idx;


--
-- Name: fato_envolvido_2018_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2018_sk_regional_idx;


--
-- Name: fato_envolvido_2018_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2018_sk_tempo_idx;


--
-- Name: fato_envolvido_2018_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2018_sk_veiculo_idx;


--
-- Name: fato_envolvido_2019_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2019_pkey;


--
-- Name: fato_envolvido_2019_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2019_sk_local_idx;


--
-- Name: fato_envolvido_2019_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2019_sk_pessoa_idx;


--
-- Name: fato_envolvido_2019_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2019_sk_regional_idx;


--
-- Name: fato_envolvido_2019_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2019_sk_tempo_idx;


--
-- Name: fato_envolvido_2019_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2019_sk_veiculo_idx;


--
-- Name: fato_envolvido_2020_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2020_pkey;


--
-- Name: fato_envolvido_2020_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2020_sk_local_idx;


--
-- Name: fato_envolvido_2020_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2020_sk_pessoa_idx;


--
-- Name: fato_envolvido_2020_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2020_sk_regional_idx;


--
-- Name: fato_envolvido_2020_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2020_sk_tempo_idx;


--
-- Name: fato_envolvido_2020_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2020_sk_veiculo_idx;


--
-- Name: fato_envolvido_2021_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2021_pkey;


--
-- Name: fato_envolvido_2021_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2021_sk_local_idx;


--
-- Name: fato_envolvido_2021_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2021_sk_pessoa_idx;


--
-- Name: fato_envolvido_2021_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2021_sk_regional_idx;


--
-- Name: fato_envolvido_2021_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2021_sk_tempo_idx;


--
-- Name: fato_envolvido_2021_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2021_sk_veiculo_idx;


--
-- Name: fato_envolvido_2022_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2022_pkey;


--
-- Name: fato_envolvido_2022_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2022_sk_local_idx;


--
-- Name: fato_envolvido_2022_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2022_sk_pessoa_idx;


--
-- Name: fato_envolvido_2022_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2022_sk_regional_idx;


--
-- Name: fato_envolvido_2022_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2022_sk_tempo_idx;


--
-- Name: fato_envolvido_2022_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2022_sk_veiculo_idx;


--
-- Name: fato_envolvido_2023_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2023_pkey;


--
-- Name: fato_envolvido_2023_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2023_sk_local_idx;


--
-- Name: fato_envolvido_2023_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2023_sk_pessoa_idx;


--
-- Name: fato_envolvido_2023_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2023_sk_regional_idx;


--
-- Name: fato_envolvido_2023_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2023_sk_tempo_idx;


--
-- Name: fato_envolvido_2023_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2023_sk_veiculo_idx;


--
-- Name: fato_envolvido_2024_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2024_pkey;


--
-- Name: fato_envolvido_2024_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2024_sk_local_idx;


--
-- Name: fato_envolvido_2024_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2024_sk_pessoa_idx;


--
-- Name: fato_envolvido_2024_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2024_sk_regional_idx;


--
-- Name: fato_envolvido_2024_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2024_sk_tempo_idx;


--
-- Name: fato_envolvido_2024_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2024_sk_veiculo_idx;


--
-- Name: fato_envolvido_2025_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2025_pkey;


--
-- Name: fato_envolvido_2025_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2025_sk_local_idx;


--
-- Name: fato_envolvido_2025_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2025_sk_pessoa_idx;


--
-- Name: fato_envolvido_2025_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2025_sk_regional_idx;


--
-- Name: fato_envolvido_2025_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2025_sk_tempo_idx;


--
-- Name: fato_envolvido_2025_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2025_sk_veiculo_idx;


--
-- Name: fato_envolvido_2026_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_2026_pkey;


--
-- Name: fato_envolvido_2026_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_2026_sk_local_idx;


--
-- Name: fato_envolvido_2026_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_2026_sk_pessoa_idx;


--
-- Name: fato_envolvido_2026_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_2026_sk_regional_idx;


--
-- Name: fato_envolvido_2026_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_2026_sk_tempo_idx;


--
-- Name: fato_envolvido_2026_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_2026_sk_veiculo_idx;


--
-- Name: fato_envolvido_default_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_envolvido ATTACH PARTITION dw.fato_envolvido_default_pkey;


--
-- Name: fato_envolvido_default_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_local ATTACH PARTITION dw.fato_envolvido_default_sk_local_idx;


--
-- Name: fato_envolvido_default_sk_pessoa_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_pessoa ATTACH PARTITION dw.fato_envolvido_default_sk_pessoa_idx;


--
-- Name: fato_envolvido_default_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_regional ATTACH PARTITION dw.fato_envolvido_default_sk_regional_idx;


--
-- Name: fato_envolvido_default_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_tempo ATTACH PARTITION dw.fato_envolvido_default_sk_tempo_idx;


--
-- Name: fato_envolvido_default_sk_veiculo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_envolvido_sk_veiculo ATTACH PARTITION dw.fato_envolvido_default_sk_veiculo_idx;


--
-- Name: fato_sinistro_2011_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2011_geom_idx;


--
-- Name: fato_sinistro_2011_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2011_pkey;


--
-- Name: fato_sinistro_2011_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2011_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2011_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2011_sk_local_idx;


--
-- Name: fato_sinistro_2011_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2011_sk_regional_idx;


--
-- Name: fato_sinistro_2011_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2011_sk_tempo_idx;


--
-- Name: fato_sinistro_2011_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2011_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2012_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2012_geom_idx;


--
-- Name: fato_sinistro_2012_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2012_pkey;


--
-- Name: fato_sinistro_2012_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2012_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2012_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2012_sk_local_idx;


--
-- Name: fato_sinistro_2012_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2012_sk_regional_idx;


--
-- Name: fato_sinistro_2012_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2012_sk_tempo_idx;


--
-- Name: fato_sinistro_2012_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2012_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2013_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2013_geom_idx;


--
-- Name: fato_sinistro_2013_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2013_pkey;


--
-- Name: fato_sinistro_2013_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2013_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2013_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2013_sk_local_idx;


--
-- Name: fato_sinistro_2013_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2013_sk_regional_idx;


--
-- Name: fato_sinistro_2013_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2013_sk_tempo_idx;


--
-- Name: fato_sinistro_2013_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2013_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2014_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2014_geom_idx;


--
-- Name: fato_sinistro_2014_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2014_pkey;


--
-- Name: fato_sinistro_2014_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2014_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2014_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2014_sk_local_idx;


--
-- Name: fato_sinistro_2014_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2014_sk_regional_idx;


--
-- Name: fato_sinistro_2014_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2014_sk_tempo_idx;


--
-- Name: fato_sinistro_2014_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2014_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2015_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2015_geom_idx;


--
-- Name: fato_sinistro_2015_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2015_pkey;


--
-- Name: fato_sinistro_2015_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2015_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2015_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2015_sk_local_idx;


--
-- Name: fato_sinistro_2015_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2015_sk_regional_idx;


--
-- Name: fato_sinistro_2015_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2015_sk_tempo_idx;


--
-- Name: fato_sinistro_2015_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2015_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2016_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2016_geom_idx;


--
-- Name: fato_sinistro_2016_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2016_pkey;


--
-- Name: fato_sinistro_2016_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2016_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2016_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2016_sk_local_idx;


--
-- Name: fato_sinistro_2016_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2016_sk_regional_idx;


--
-- Name: fato_sinistro_2016_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2016_sk_tempo_idx;


--
-- Name: fato_sinistro_2016_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2016_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2017_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2017_geom_idx;


--
-- Name: fato_sinistro_2017_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2017_pkey;


--
-- Name: fato_sinistro_2017_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2017_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2017_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2017_sk_local_idx;


--
-- Name: fato_sinistro_2017_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2017_sk_regional_idx;


--
-- Name: fato_sinistro_2017_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2017_sk_tempo_idx;


--
-- Name: fato_sinistro_2017_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2017_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2018_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2018_geom_idx;


--
-- Name: fato_sinistro_2018_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2018_pkey;


--
-- Name: fato_sinistro_2018_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2018_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2018_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2018_sk_local_idx;


--
-- Name: fato_sinistro_2018_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2018_sk_regional_idx;


--
-- Name: fato_sinistro_2018_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2018_sk_tempo_idx;


--
-- Name: fato_sinistro_2018_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2018_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2019_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2019_geom_idx;


--
-- Name: fato_sinistro_2019_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2019_pkey;


--
-- Name: fato_sinistro_2019_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2019_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2019_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2019_sk_local_idx;


--
-- Name: fato_sinistro_2019_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2019_sk_regional_idx;


--
-- Name: fato_sinistro_2019_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2019_sk_tempo_idx;


--
-- Name: fato_sinistro_2019_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2019_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2020_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2020_geom_idx;


--
-- Name: fato_sinistro_2020_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2020_pkey;


--
-- Name: fato_sinistro_2020_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2020_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2020_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2020_sk_local_idx;


--
-- Name: fato_sinistro_2020_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2020_sk_regional_idx;


--
-- Name: fato_sinistro_2020_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2020_sk_tempo_idx;


--
-- Name: fato_sinistro_2020_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2020_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2021_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2021_geom_idx;


--
-- Name: fato_sinistro_2021_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2021_pkey;


--
-- Name: fato_sinistro_2021_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2021_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2021_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2021_sk_local_idx;


--
-- Name: fato_sinistro_2021_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2021_sk_regional_idx;


--
-- Name: fato_sinistro_2021_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2021_sk_tempo_idx;


--
-- Name: fato_sinistro_2021_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2021_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2022_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2022_geom_idx;


--
-- Name: fato_sinistro_2022_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2022_pkey;


--
-- Name: fato_sinistro_2022_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2022_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2022_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2022_sk_local_idx;


--
-- Name: fato_sinistro_2022_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2022_sk_regional_idx;


--
-- Name: fato_sinistro_2022_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2022_sk_tempo_idx;


--
-- Name: fato_sinistro_2022_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2022_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2023_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2023_geom_idx;


--
-- Name: fato_sinistro_2023_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2023_pkey;


--
-- Name: fato_sinistro_2023_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2023_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2023_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2023_sk_local_idx;


--
-- Name: fato_sinistro_2023_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2023_sk_regional_idx;


--
-- Name: fato_sinistro_2023_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2023_sk_tempo_idx;


--
-- Name: fato_sinistro_2023_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2023_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2024_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2024_geom_idx;


--
-- Name: fato_sinistro_2024_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2024_pkey;


--
-- Name: fato_sinistro_2024_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2024_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2024_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2024_sk_local_idx;


--
-- Name: fato_sinistro_2024_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2024_sk_regional_idx;


--
-- Name: fato_sinistro_2024_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2024_sk_tempo_idx;


--
-- Name: fato_sinistro_2024_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2024_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2025_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2025_geom_idx;


--
-- Name: fato_sinistro_2025_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2025_pkey;


--
-- Name: fato_sinistro_2025_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2025_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2025_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2025_sk_local_idx;


--
-- Name: fato_sinistro_2025_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2025_sk_regional_idx;


--
-- Name: fato_sinistro_2025_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2025_sk_tempo_idx;


--
-- Name: fato_sinistro_2025_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2025_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_2026_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_2026_geom_idx;


--
-- Name: fato_sinistro_2026_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_2026_pkey;


--
-- Name: fato_sinistro_2026_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_2026_sk_condicao_via_idx;


--
-- Name: fato_sinistro_2026_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_2026_sk_local_idx;


--
-- Name: fato_sinistro_2026_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_2026_sk_regional_idx;


--
-- Name: fato_sinistro_2026_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_2026_sk_tempo_idx;


--
-- Name: fato_sinistro_2026_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_2026_sk_tipo_sinistro_idx;


--
-- Name: fato_sinistro_default_geom_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.gix_fato_sinistro_geom ATTACH PARTITION dw.fato_sinistro_default_geom_idx;


--
-- Name: fato_sinistro_default_pkey; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.pk_fato_sinistro ATTACH PARTITION dw.fato_sinistro_default_pkey;


--
-- Name: fato_sinistro_default_sk_condicao_via_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_condicao_via ATTACH PARTITION dw.fato_sinistro_default_sk_condicao_via_idx;


--
-- Name: fato_sinistro_default_sk_local_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_local ATTACH PARTITION dw.fato_sinistro_default_sk_local_idx;


--
-- Name: fato_sinistro_default_sk_regional_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_regional ATTACH PARTITION dw.fato_sinistro_default_sk_regional_idx;


--
-- Name: fato_sinistro_default_sk_tempo_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tempo ATTACH PARTITION dw.fato_sinistro_default_sk_tempo_idx;


--
-- Name: fato_sinistro_default_sk_tipo_sinistro_idx; Type: INDEX ATTACH; Schema: dw; Owner: -
--

ALTER INDEX dw.ix_fato_sinistro_sk_tipo_sinistro ATTACH PARTITION dw.fato_sinistro_default_sk_tipo_sinistro_idx;


--
-- Name: fato_envolvido fato_envolvido_sk_local_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_envolvido
    ADD CONSTRAINT fato_envolvido_sk_local_fkey FOREIGN KEY (sk_local) REFERENCES dw.dim_local(sk_local);


--
-- Name: fato_envolvido fato_envolvido_sk_pessoa_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_envolvido
    ADD CONSTRAINT fato_envolvido_sk_pessoa_fkey FOREIGN KEY (sk_pessoa) REFERENCES dw.dim_pessoa(sk_pessoa);


--
-- Name: fato_envolvido fato_envolvido_sk_regional_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_envolvido
    ADD CONSTRAINT fato_envolvido_sk_regional_fkey FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional);


--
-- Name: fato_envolvido fato_envolvido_sk_tempo_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_envolvido
    ADD CONSTRAINT fato_envolvido_sk_tempo_fkey FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo);


--
-- Name: fato_envolvido fato_envolvido_sk_veiculo_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_envolvido
    ADD CONSTRAINT fato_envolvido_sk_veiculo_fkey FOREIGN KEY (sk_veiculo) REFERENCES dw.dim_veiculo(sk_veiculo);


--
-- Name: fato_populacao fato_populacao_sk_regional_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_populacao
    ADD CONSTRAINT fato_populacao_sk_regional_fkey FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional);


--
-- Name: fato_populacao fato_populacao_sk_tempo_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE ONLY dw.fato_populacao
    ADD CONSTRAINT fato_populacao_sk_tempo_fkey FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo);


--
-- Name: fato_sinistro fato_sinistro_sk_condicao_via_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_sinistro
    ADD CONSTRAINT fato_sinistro_sk_condicao_via_fkey FOREIGN KEY (sk_condicao_via) REFERENCES dw.dim_condicao_via(sk_condicao_via);


--
-- Name: fato_sinistro fato_sinistro_sk_local_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_sinistro
    ADD CONSTRAINT fato_sinistro_sk_local_fkey FOREIGN KEY (sk_local) REFERENCES dw.dim_local(sk_local);


--
-- Name: fato_sinistro fato_sinistro_sk_regional_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_sinistro
    ADD CONSTRAINT fato_sinistro_sk_regional_fkey FOREIGN KEY (sk_regional) REFERENCES dw.dim_regional(sk_regional);


--
-- Name: fato_sinistro fato_sinistro_sk_tempo_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_sinistro
    ADD CONSTRAINT fato_sinistro_sk_tempo_fkey FOREIGN KEY (sk_tempo) REFERENCES dw.dim_tempo(sk_tempo);


--
-- Name: fato_sinistro fato_sinistro_sk_tipo_sinistro_fkey; Type: FK CONSTRAINT; Schema: dw; Owner: -
--

ALTER TABLE dw.fato_sinistro
    ADD CONSTRAINT fato_sinistro_sk_tipo_sinistro_fkey FOREIGN KEY (sk_tipo_sinistro) REFERENCES dw.dim_tipo_sinistro(sk_tipo_sinistro);


--
-- PostgreSQL database dump complete
--

