"""
Utilitários de acesso ao PostgreSQL (psycopg 3).

Os arquivos .sql são lidos pelo Python e enviados ao servidor, o que evita
depender do caminho com espaço/acento da pasta do projeto.
"""
from __future__ import annotations

import logging
import time
from contextlib import contextmanager
from pathlib import Path

import psycopg

from etl import config

log = logging.getLogger(__name__)


def conectar(dbname: str | None = None, autocommit: bool = False) -> psycopg.Connection:
    return psycopg.connect(**config.parametros_conexao(dbname), autocommit=autocommit)


@contextmanager
def conexao(dbname: str | None = None, autocommit: bool = False):
    conn = conectar(dbname, autocommit)
    try:
        yield conn
        if not autocommit:
            conn.commit()
    except Exception:
        if not autocommit:
            conn.rollback()
        raise
    finally:
        conn.close()


def executar_sql(conn: psycopg.Connection, sql: str, rotulo: str = "") -> None:
    """Executa um texto SQL com um ou mais comandos (protocolo simples, sem parâmetros)."""
    inicio = time.perf_counter()
    conn.execute(sql)
    log.info("SQL %s executado em %.1fs", rotulo, time.perf_counter() - inicio)


def executar_arquivo(conn: psycopg.Connection, caminho: Path) -> None:
    executar_sql(conn, caminho.read_text(encoding="utf-8"), caminho.name)


def consultar(conn: psycopg.Connection, sql: str, params=None) -> list[tuple]:
    return conn.execute(sql, params).fetchall()
