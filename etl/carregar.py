"""
Etapa 5 — CARREGAR.

Aplica o DDL (idempotente) e carrega o schema dw a partir das tabelas de
trabalho do stg: dimensões, depois fatos, depois REFRESH das views
materializadas. Toda a carga do dw roda numa única transação: se algo falhar,
o dw continua como estava.

Uso isolado:  python -m etl.carregar
"""
from __future__ import annotations

import logging

from etl import banco, config
from etl.util import configurar_log

log = logging.getLogger("carregar")

SCRIPTS_DW = [
    "20_limpar_dw.sql",
    "21_dim_tempo.sql",
    "22_dim_regional.sql",
    "23_dim_tipo_sinistro.sql",
    "24_dim_condicao_via.sql",
    "25_dim_veiculo.sql",
    "26_dim_pessoa.sql",
    "27_dim_local.sql",
    "30_fato_sinistro.sql",
    "31_fato_envolvido.sql",
    "32_fato_populacao.sql",
    "40_atualizar_views.sql",
]


def aplicar_ddl(conn, recriar: bool = False) -> None:
    """Executa sql/ddl_data_warehouse.sql. Com recriar=True apaga antes os schemas bi, dw e stg."""
    if recriar:
        log.warning("Recriando a estrutura: DROP SCHEMA bi, dw e stg")
        conn.execute("DROP SCHEMA IF EXISTS bi CASCADE; DROP SCHEMA IF EXISTS dw CASCADE; DROP SCHEMA IF EXISTS stg CASCADE;")
    banco.executar_arquivo(conn, config.ARQ_DDL)
    conn.commit()


def executar(conn) -> dict[str, int]:
    for nome in SCRIPTS_DW:
        banco.executar_arquivo(conn, config.DIR_SQL_CARGA / nome)
    conn.commit()
    tabelas = ["dim_tempo", "dim_regional", "dim_local", "dim_tipo_sinistro", "dim_condicao_via",
               "dim_veiculo", "dim_pessoa", "fato_sinistro", "fato_envolvido", "fato_populacao"]
    contagens = {t: conn.execute(f"SELECT count(*) FROM dw.{t}").fetchone()[0] for t in tabelas}
    for t, n in contagens.items():
        log.info("  dw.%-20s %10d linhas", t, n)
    return contagens


if __name__ == "__main__":
    configurar_log()
    with banco.conexao() as c:
        aplicar_ddl(c)
        executar(c)
