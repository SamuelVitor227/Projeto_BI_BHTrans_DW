"""
CARGA INICIAL COMPLETA — ponto de entrada único e idempotente do ETL.

    python -m etl.carga_inicial                      # tudo, todos os anos publicados
    python -m etl.carga_inicial --anos 2019-2024     # só alguns anos (útil para testes)
    python -m etl.carga_inicial --forcar-download    # baixa de novo mesmo sem mudança na origem
    python -m etl.carga_inicial --recriar            # apaga e recria os schemas stg e dw antes
    python -m etl.carga_inicial --sem-download       # usa só a camada RAW já existente

Etapas (cada uma pode virar uma task de uma DAG do Airflow):
    1. extrair      -> dados/raw/ + manifesto.csv
    2. staging      -> schema stg (espelhos, COPY)
    3. transformar  -> stg.trf_*
    4. testes       -> stg.resultado_qualidade (falha CRÍTICA interrompe)
    5. carregar     -> schema dw (dimensões, fatos, views materializadas)
    6. reconciliar  -> contagens stg x dw e populações
    7. evidências   -> evidencias/
Cada etapa é registrada em stg.log_carga.
"""
from __future__ import annotations

import argparse
import logging
import sys
import time
from contextlib import contextmanager
from datetime import datetime

from etl import (banco, carregar, config, evidencias, extrair, staging, testes_qualidade,
                 transformar)
from etl.util import configurar_log, interpretar_anos

log = logging.getLogger("carga_inicial")


class RegistroCarga:
    """Grava cada etapa em stg.log_carga numa conexão própria (autocommit), para que o
    registro sobreviva mesmo se a etapa falhar e a transação principal for desfeita."""

    def __init__(self, id_execucao: int, parametros: str):
        self.id_execucao, self.parametros = id_execucao, parametros
        self.conn = None

    def _conectar(self):
        if self.conn is None:
            try:
                self.conn = banco.conectar(autocommit=True)
                self.conn.execute("SELECT 1 FROM stg.log_carga LIMIT 1")
            except Exception:
                self.conn = None  # schema ainda não existe (antes do DDL)
        return self.conn

    @contextmanager
    def etapa(self, nome: str, registrar_inicio: bool = True):
        inicio = time.perf_counter()
        log.info("========== ETAPA: %s ==========", nome)
        id_log = None
        c = self._conectar() if registrar_inicio else None
        if c:
            id_log = c.execute("""INSERT INTO stg.log_carga (id_execucao, etapa, status, parametros)
                                  VALUES (%s, %s, 'INICIADA', %s) RETURNING id_log""",
                               (self.id_execucao, nome, self.parametros)).fetchone()[0]
        resultado = {"linhas": None, "mensagem": None}
        try:
            yield resultado
        except Exception as e:
            if c:
                c.execute("""UPDATE stg.log_carga SET status = 'FALHA', dt_fim = now(), mensagem = %s
                             WHERE id_log = %s""", (f"{type(e).__name__}: {e}"[:4000], id_log))
            raise
        duracao = time.perf_counter() - inicio
        c = self._conectar()
        msg = (resultado["mensagem"] or "") + f" ({duracao:.1f}s)"
        if c and id_log:
            c.execute("""UPDATE stg.log_carga SET status = 'SUCESSO', dt_fim = now(), linhas = %s, mensagem = %s
                         WHERE id_log = %s""", (resultado["linhas"], msg.strip(), id_log))
        elif c:  # etapa que criou o próprio schema (DDL)
            c.execute("""INSERT INTO stg.log_carga (id_execucao, etapa, status, dt_fim, linhas, mensagem, parametros)
                         VALUES (%s, %s, 'SUCESSO', now(), %s, %s, %s)""",
                      (self.id_execucao, nome, resultado["linhas"], msg.strip(), self.parametros))
        log.info("Etapa %s concluída em %.1fs", nome, duracao)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Carga inicial completa do DW de sinistros de trânsito de BH")
    p.add_argument("--anos", help="anos a carregar, ex.: 2011-2024 ou 2019,2020 (padrão: todos os publicados)")
    p.add_argument("--forcar-download", action="store_true", help="baixa novamente mesmo sem mudança na origem")
    p.add_argument("--sem-download", action="store_true", help="não acessa a internet; usa a camada RAW existente")
    p.add_argument("--recriar", action="store_true", help="apaga e recria os schemas stg e dw antes da carga")
    p.add_argument("--sem-evidencias", action="store_true", help="não regenera a pasta evidencias/")
    a = p.parse_args(argv)

    configurar_log(config.DIR_EVIDENCIAS / "log_carga_inicial.txt")
    anos = interpretar_anos(a.anos)
    id_execucao = int(datetime.now().strftime("%Y%m%d%H%M%S"))
    parametros = (f"anos={a.anos or 'todos'}; forcar_download={a.forcar_download}; "
                  f"sem_download={a.sem_download}; recriar={a.recriar}")
    log.info("Execução %d — %s", id_execucao, parametros)
    reg = RegistroCarga(id_execucao, parametros)

    try:
        with banco.conexao() as conn:
            with reg.etapa("0-ddl", registrar_inicio=False) as r:
                carregar.aplicar_ddl(conn, recriar=a.recriar)
                r["mensagem"] = "sql/ddl_data_warehouse.sql aplicado" + (" (schemas recriados)" if a.recriar else "")

            with reg.etapa("1-extrair") as r:
                if a.sem_download:
                    r["mensagem"] = "pulada (--sem-download): usando a camada RAW existente"
                else:
                    extrair.executar(anos, a.forcar_download)
                    r["mensagem"] = "camada RAW atualizada; ver dados/raw/manifesto.csv"

            with reg.etapa("2-staging") as r:
                cont = staging.executar(conn, anos)
                r["linhas"] = sum(cont.values())
                r["mensagem"] = "; ".join(f"{k}={v}" for k, v in cont.items())

            with reg.etapa("3-transformar") as r:
                transformar.executar(conn)
                r["linhas"] = conn.execute("SELECT count(*) FROM stg.trf_boletim").fetchone()[0]
                r["mensagem"] = "stg.trf_* atualizadas"

            anos_esperados = anos or [x[0] for x in conn.execute(
                "SELECT DISTINCT ano_arquivo FROM stg.si_bol ORDER BY 1").fetchall()]
            try:
                with reg.etapa("4-testes_qualidade") as r:
                    res = testes_qualidade.executar_pre_carga(conn, id_execucao, anos_esperados)
                    r["linhas"] = len(res)
                    r["mensagem"] = f"{sum(x['aprovado'] for x in res)}/{len(res)} aprovados"

                with reg.etapa("5-carregar_dw") as r:
                    cont = carregar.executar(conn)
                    r["linhas"] = cont["fato_sinistro"] + cont["fato_envolvido"]
                    r["mensagem"] = "; ".join(f"{k}={v}" for k, v in cont.items())

                with reg.etapa("6-reconciliar") as r:
                    res = testes_qualidade.executar_reconciliacao(conn, id_execucao)
                    r["linhas"] = len(res)
                    r["mensagem"] = f"{sum(x['aprovado'] for x in res)}/{len(res)} aprovados"
            finally:
                testes_qualidade.gerar_relatorio(conn, id_execucao)

            if not a.sem_evidencias:
                with reg.etapa("7-evidencias") as r:
                    evidencias.executar(conn)
                    r["mensagem"] = "evidencias/ atualizada"
    except testes_qualidade.FalhaCritica as e:
        log.error("%s", e)
        log.error("Carga INTERROMPIDA. Veja evidencias/03_relatorio_qualidade.md e stg.log_carga (id_execucao=%d).",
                  id_execucao)
        return 2
    except Exception:
        log.exception("Carga INTERROMPIDA por erro inesperado (id_execucao=%d).", id_execucao)
        return 1
    log.info("Carga inicial concluída com sucesso (id_execucao=%d).", id_execucao)
    return 0


if __name__ == "__main__":
    sys.exit(main())
