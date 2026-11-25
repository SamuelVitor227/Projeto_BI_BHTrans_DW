"""
Configuração central do ETL do Data Warehouse de sinistros de trânsito de BH.

Reúne num só lugar: caminhos do projeto, parâmetros de conexão (lidos do .env)
e o catálogo das fontes de dados (PBH/CKAN, IBGE e INMET).
"""
from __future__ import annotations

from pathlib import Path

from dotenv import dotenv_values

# ---------------------------------------------------------------------------
# Caminhos (o projeto fica no OneDrive, com espaço e acento: sempre Path)
# ---------------------------------------------------------------------------
RAIZ = Path(__file__).resolve().parents[1]
DIR_RAW = RAIZ / "dados" / "raw"
ARQ_MANIFESTO = DIR_RAW / "manifesto.csv"
DIR_SQL = RAIZ / "sql"
ARQ_DDL = DIR_SQL / "ddl_data_warehouse.sql"
DIR_SQL_CARGA = DIR_SQL / "carga"
DIR_MAPEAMENTOS = RAIZ / "etl" / "mapeamentos"
DIR_EVIDENCIAS = RAIZ / "evidencias"

# ---------------------------------------------------------------------------
# Banco de dados (credenciais somente no .env, nunca no código)
# ---------------------------------------------------------------------------
_ENV = dotenv_values(RAIZ / ".env")


def parametros_conexao(dbname: str | None = None) -> dict:
    """Parâmetros de conexão do psycopg a partir do .env."""
    return {
        "host": _ENV.get("POSTGRES_HOST", "127.0.0.1"),
        "port": int(_ENV.get("POSTGRES_PORT", "5432")),
        "dbname": dbname or _ENV.get("POSTGRES_DB", "dw_sinistros_bh"),
        "user": _ENV.get("POSTGRES_USER"),
        "password": _ENV.get("POSTGRES_PASSWORD"),
        "connect_timeout": 15,
        "application_name": "etl_bi_bhtrans",
    }


NOME_CONTAINER = "bi_bhtrans_postgis"

# ---------------------------------------------------------------------------
# Fontes de dados
# ---------------------------------------------------------------------------
USER_AGENT = "Mozilla/5.0 (Projeto academico de BI - PUC Minas)"

# Portal de dados abertos da PBH (CKAN). As duas URLs apontam para o mesmo
# CKAN; a primeira que responder é usada.
CKAN_BASES = ("https://ckan.pbh.gov.br", "https://dados.pbh.gov.br")

# conjunto lógico -> slug do dataset no CKAN
CONJUNTOS_PBH = {
    "si_bol": "relacao-de-ocorrencias-de-acidentes-de-transito-com-vitima",
    "si_log": "relacao-dos-logradouros-dos-locais-de-acidentes-de-transito-com-vitima",
    "si_veic": "relacao-dos-veiculos-envolvidos-nos-acidentes-de-transito-com-vitima",
    "si_env": "relacao-das-pessoas-envolvidas-nos-acidentes-de-transito-com-vitima",
    "regional": "regiao-administrativa",
}

# IBGE
IBGE_MUNICIPIO = 3106200  # Belo Horizonte
IBGE_API_LOCALIDADES = "https://servicodados.ibge.gov.br/api/v1/localidades"
IBGE_API_AGREGADOS = "https://servicodados.ibge.gov.br/api/v3/agregados"
IBGE_TAB_ESTIMATIVAS = 6579  # População residente estimada (variável 9324)
IBGE_TAB_CENSO_2010 = 202  # População residente (variável 93), Censo 2010
IBGE_TAB_CENSO_2022 = 9923  # População residente (variável 93), Censo 2022
IBGE_FTP_AGREGADOS_SETOR_2010 = (
    "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2010/Resultados_do_Universo/"
    "Agregados_por_Setores_Censitarios/"
)
IBGE_MALHA_SETORES_2010 = (
    "https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/"
    "malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2010/"
    "setores_censitarios_shp/mg/mg_setores_censitarios.zip"
)

# INMET: um ZIP por ano com todas as estações automáticas do país
INMET_URL_ZIP = "https://portal.inmet.gov.br/uploads/dadoshistoricos/{ano}.zip"
# Estações automáticas de BH (código OMM/INMET -> papel no DW)
INMET_ESTACOES_BH = {"A521": "principal", "F501": "reserva"}

# Fuso horário local dos sinistros
FUSO_LOCAL = "America/Sao_Paulo"

# Projeções
SRID_UTM_SIRGAS = 31983  # SIRGAS 2000 / UTM 23S (coordenadas dos boletins)
SRID_WGS84 = 4326
