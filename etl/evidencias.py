"""
Etapa 7 — EVIDÊNCIAS.

Gera a pasta evidencias/ a partir do banco:
  01_estrutura_dw.md (+ CSVs)      schemas, tabelas, colunas, partições, índices, FKs e views
  02_contagens.md (+ CSV)          linhas por tabela e por ano
  03_relatorio_qualidade.md        (gerado pelos testes de qualidade)
  04_consultas_negocio.md          consultas de sql/consultas_validacao.sql e seus resultados
  05_prova_ddl_banco_vazio.txt     DDL executado do zero num banco temporário vazio (psql)
  ddl_exportado_pg_dump.sql        pg_dump --schema-only do banco principal

Uso isolado:  python -m etl.evidencias [--sem-prova-ddl]
"""
from __future__ import annotations

import argparse
import csv
import logging
import re
import subprocess
from datetime import datetime
from decimal import Decimal

from etl import banco, config
from etl.util import configurar_log

log = logging.getLogger("evidencias")
DIR = config.DIR_EVIDENCIAS


def _fmt(valor) -> str:
    """Formato brasileiro: milhar com ponto (a partir de 10.000, para não afetar anos e códigos)
    e decimal com vírgula."""
    if valor is None:
        return ""
    if isinstance(valor, bool):
        return "sim" if valor else "não"
    if isinstance(valor, int):
        return f"{valor:,}".replace(",", ".") if abs(valor) >= 10_000 else str(valor)
    if isinstance(valor, (float, Decimal)):
        inteiro, _, decimal = f"{valor}".partition(".")
        inteiro = _fmt(int(inteiro)) if inteiro.lstrip("-").isdigit() else inteiro
        if inteiro == "0" and str(valor).startswith("-"):
            inteiro = "-0"
        return inteiro + ("," + decimal if decimal else "")
    return str(valor).replace("|", "\\|").replace("\n", " ")


def _tabela_md(colunas: list[str], linhas: list[tuple], limite: int | None = None) -> str:
    saida = ["| " + " | ".join(colunas) + " |", "|" + "---|" * len(colunas)]
    for l in (linhas[:limite] if limite else linhas):
        saida.append("| " + " | ".join(_fmt(v) for v in l) + " |")
    return "\n".join(saida)


def _csv(nome: str, colunas: list[str], linhas: list[tuple]) -> None:
    with open(DIR / nome, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(colunas)
        w.writerows(linhas)


def _consulta(conn, sql: str) -> tuple[list[str], list[tuple]]:
    cur = conn.execute(sql)
    return [d.name for d in cur.description], cur.fetchall()


# ---------------------------------------------------------------------------
def estrutura(conn) -> None:
    secoes = []
    consultas = {
        "Schemas": ("01a_schemas.csv", """
            SELECT n.nspname AS schema, obj_description(n.oid, 'pg_namespace') AS comentario
            FROM pg_namespace n WHERE n.nspname IN ('stg', 'dw', 'bi') ORDER BY 1"""),
        "Tabelas (sem partições), views materializadas e views do Power BI": ("01b_tabelas.csv", """
            SELECT n.nspname AS schema, c.relname AS tabela,
                   CASE c.relkind WHEN 'p' THEN 'tabela particionada' WHEN 'r' THEN 'tabela'
                                  WHEN 'm' THEN 'view materializada' WHEN 'v' THEN 'view (Power BI)' END AS tipo,
                   (SELECT count(*) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS colunas,
                   obj_description(c.oid, 'pg_class') AS comentario
            FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname IN ('stg', 'dw', 'bi') AND c.relkind IN ('r', 'p', 'm', 'v') AND NOT c.relispartition
            ORDER BY 1 DESC, 3, 2"""),
        "Partições das fatos": ("01c_particoes.csv", """
            SELECT p.relname AS tabela_pai, c.relname AS particao, pg_get_expr(c.relpartbound, c.oid) AS limites
            FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid JOIN pg_class p ON p.oid = i.inhparent
            JOIN pg_namespace n ON n.oid = p.relnamespace
            WHERE n.nspname = 'dw' ORDER BY 1, 2"""),
        "Chaves primárias, únicas, checks e estrangeiras (dw)": ("01d_constraints.csv", """
            SELECT cl.relname AS tabela, co.conname AS restricao,
                   CASE co.contype WHEN 'p' THEN 'PK' WHEN 'f' THEN 'FK' WHEN 'u' THEN 'UNIQUE' WHEN 'c' THEN 'CHECK' END AS tipo,
                   pg_get_constraintdef(co.oid) AS definicao
            FROM pg_constraint co JOIN pg_class cl ON cl.oid = co.conrelid JOIN pg_namespace n ON n.oid = cl.relnamespace
            WHERE n.nspname = 'dw' AND NOT cl.relispartition AND co.contype IN ('p', 'f', 'u', 'c')
            ORDER BY 1, 3, 2"""),
        "Índices (dw, sem os herdados pelas partições)": ("01e_indices.csv", """
            SELECT t.relname AS tabela, i.relname AS indice, am.amname AS metodo, pg_get_indexdef(i.oid) AS definicao
            FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid JOIN pg_class t ON t.oid = x.indrelid
            JOIN pg_am am ON am.oid = i.relam JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE n.nspname = 'dw' AND NOT t.relispartition
            ORDER BY 1, 2"""),
    }
    for titulo, (arquivo, sql) in consultas.items():
        cols, linhas = _consulta(conn, sql)
        _csv(arquivo, cols, linhas)
        secoes.append(f"## {titulo}\n\nArquivo completo: `{arquivo}` ({len(linhas)} linhas)\n\n"
                      + _tabela_md(cols, linhas))
    cols, linhas = _consulta(conn, """
        SELECT n.nspname AS schema, c.relname AS tabela, a.attnum AS ordem, a.attname AS coluna,
               format_type(a.atttypid, a.atttypmod) AS tipo, NOT a.attnotnull AS aceita_nulo,
               col_description(c.oid, a.attnum) AS comentario
        FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('stg', 'dw', 'bi') AND c.relkind IN ('r', 'p', 'm', 'v') AND NOT c.relispartition
          AND a.attnum > 0 AND NOT a.attisdropped
        ORDER BY 1 DESC, 2, 3""")
    _csv("01f_colunas.csv", cols, linhas)
    sem_comentario = [l for l in linhas if not l[6]]
    resumo = conn.execute("""
        SELECT count(*) FILTER (WHERE n.nspname = 'dw' AND c.relkind IN ('r','p') AND NOT c.relispartition),
               count(*) FILTER (WHERE n.nspname = 'dw' AND c.relispartition),
               count(*) FILTER (WHERE n.nspname = 'dw' AND c.relkind = 'm'),
               count(*) FILTER (WHERE n.nspname = 'stg' AND c.relkind = 'r'),
               count(*) FILTER (WHERE n.nspname = 'bi' AND c.relkind = 'v')
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname IN ('stg', 'dw', 'bi')""").fetchone()
    versao = conn.execute("SELECT version(), postgis_full_version()").fetchone()
    md = [f"# Estrutura do Data Warehouse — gerado em {datetime.now():%d/%m/%Y %H:%M}", "",
          f"- SGBD: `{versao[0]}`", f"- PostGIS: `{versao[1][:120]}...`",
          f"- dw: **{resumo[0]}** tabelas (7 dimensões + 3 fatos), **{resumo[1]}** partições, **{resumo[2]}** views materializadas",
          f"- stg: **{resumo[3]}** tabelas (espelhos, de-paras, trabalho, log e qualidade)",
          f"- bi: **{resumo[4]}** views de consumo do Power BI (sem geometria e sem partições)",
          f"- Colunas: **{len(linhas)}** em stg, dw e bi; sem COMMENT: **{len(sem_comentario)}**"
          + (f" ({', '.join(f'{l[1]}.{l[3]}' for l in sem_comentario[:10])})" if sem_comentario else ""),
          f"- Dicionário completo das colunas (tipo, nulidade, comentário): `01f_colunas.csv`", ""]
    (DIR / "01_estrutura_dw.md").write_text("\n".join(md) + "\n\n".join(secoes) + "\n", encoding="utf-8")
    log.info("Estrutura: %d colunas documentadas (%d sem comentário)", len(linhas), len(sem_comentario))


def contagens(conn) -> None:
    tabelas = conn.execute("""
        SELECT n.nspname, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('stg', 'dw') AND c.relkind IN ('r', 'p', 'm') AND NOT c.relispartition
        ORDER BY 1 DESC, 2""").fetchall()
    linhas = [(s, t, conn.execute(f'SELECT count(*) FROM "{s}"."{t}"').fetchone()[0]) for s, t in tabelas]
    _csv("02a_linhas_por_tabela.csv", ["schema", "tabela", "linhas"], linhas)
    cols, por_ano = _consulta(conn, """
        WITH s AS (SELECT ano_arquivo AS ano, count(*) AS stg_si_bol FROM stg.si_bol GROUP BY 1),
             e AS (SELECT ano_arquivo AS ano, count(*) AS stg_si_env FROM stg.si_env GROUP BY 1),
             v AS (SELECT ano_arquivo AS ano, count(*) AS stg_si_veic FROM stg.si_veic GROUP BY 1),
             l AS (SELECT ano_arquivo AS ano, count(*) AS stg_si_log FROM stg.si_log GROUP BY 1),
             fs AS (SELECT ano, count(*) AS fato_sinistro, sum(qtd_vitimas) AS vitimas, sum(qtd_vitimas_fatais) AS mortos,
                           round(100.0 * avg(fl_geolocalizado::int), 1) AS pct_geolocalizado
                    FROM dw.fato_sinistro GROUP BY 1),
             fe AS (SELECT ano, count(*) AS fato_envolvido FROM dw.fato_envolvido GROUP BY 1),
             c AS (SELECT ano, round(100.0 * avg((origem_clima = 'IMPUTADO PELO INMET')::int), 1) AS pct_clima_imputado
                   FROM stg.trf_boletim GROUP BY 1),
             p AS (SELECT ano, sum(populacao_residente) AS populacao, max(origem_dado) AS origem_populacao
                   FROM dw.fato_populacao GROUP BY 1)
        SELECT p.ano, s.stg_si_bol, fs.fato_sinistro, e.stg_si_env, fe.fato_envolvido, v.stg_si_veic, l.stg_si_log,
               fs.vitimas, fs.mortos, fs.pct_geolocalizado, c.pct_clima_imputado, p.populacao, p.origem_populacao
        FROM p LEFT JOIN s USING (ano) LEFT JOIN fs USING (ano) LEFT JOIN e USING (ano) LEFT JOIN fe USING (ano)
        LEFT JOIN v USING (ano) LEFT JOIN l USING (ano) LEFT JOIN c USING (ano)
        ORDER BY 1""")
    _csv("02b_contagens_por_ano.csv", cols, por_ano)
    cols_p, part = _consulta(conn, """
        SELECT c.relname AS particao, c.reltuples::bigint AS linhas_estimadas
        FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname IN ('fato_sinistro', 'fato_envolvido') ORDER BY 1""")
    md = [f"# Contagens da carga — gerado em {datetime.now():%d/%m/%Y %H:%M}", "",
          "## Linhas por tabela", "", _tabela_md(["schema", "tabela", "linhas"], linhas), "",
          "## Por ano: staging x dw, vítimas, mortos, geolocalização, clima imputado e população", "",
          _tabela_md(cols, por_ano), "",
          "## Linhas por partição (estatística do PostgreSQL após ANALYZE)", "", _tabela_md(cols_p, part), ""]
    (DIR / "02_contagens.md").write_text("\n".join(md), encoding="utf-8")
    log.info("Contagens: %d tabelas, %d anos", len(linhas), len(por_ano))


def consultas_negocio(conn) -> None:
    texto = (config.DIR_SQL / "consultas_validacao.sql").read_text(encoding="utf-8")
    blocos = re.split(r"^-- @consulta:", texto, flags=re.M)[1:]
    md = [f"# Consultas de negócio (requisitos da Fase 1) — gerado em {datetime.now():%d/%m/%Y %H:%M}", "",
          "Fonte das consultas: `sql/consultas_validacao.sql`.", ""]
    for bloco in blocos:
        titulo, resto = bloco.split("\n", 1)
        m = re.search(r"^-- @pergunta:(.*)$", resto, flags=re.M)
        pergunta = m.group(1).strip() if m else ""
        consulta = re.sub(r"^-- @pergunta:.*$", "", resto, flags=re.M).strip().rstrip(";")
        cols, linhas = _consulta(conn, consulta)
        md += [f"## {titulo.strip()}", "", f"**Pergunta:** {pergunta}", "",
               "```sql", consulta, "```", "", f"**Resultado** ({len(linhas)} linhas):", "",
               _tabela_md(cols, linhas), ""]
    (DIR / "04_consultas_negocio.md").write_text("\n".join(md), encoding="utf-8")
    log.info("Consultas de negócio: %d executadas", len(blocos))


# ---------------------------------------------------------------------------
def _docker_psql(args: list[str], entrada: bytes | None = None) -> subprocess.CompletedProcess:
    p = config.parametros_conexao()
    return subprocess.run(["docker", "exec", "-i", config.NOME_CONTAINER, "psql", "-U", p["user"]] + args,
                          input=entrada, capture_output=True, timeout=600)


def prova_ddl(conn) -> None:
    """Cria um banco temporário vazio, roda o DDL com psql (ON_ERROR_STOP), confere os objetos e apaga o banco."""
    banco_prova = "dw_prova_ddl_tmp"
    admin = banco.conectar(dbname="postgres", autocommit=True)
    try:
        admin.execute(f"DROP DATABASE IF EXISTS {banco_prova}")
        admin.execute(f"CREATE DATABASE {banco_prova}")
        ddl = config.ARQ_DDL.read_bytes()
        r1 = _docker_psql(["-d", banco_prova, "-v", "ON_ERROR_STOP=1", "-X", "-q"], ddl)
        r2 = _docker_psql(["-d", banco_prova, "-v", "ON_ERROR_STOP=1", "-X", "-q"], ddl)  # re-execução
        consulta = """SELECT n.nspname || ': ' || count(*) FILTER (WHERE c.relkind IN ('r','p') AND NOT c.relispartition) || ' tabelas, '
                             || count(*) FILTER (WHERE c.relispartition) || ' partições, '
                             || count(*) FILTER (WHERE c.relkind = 'm') || ' views materializadas, '
                             || count(*) FILTER (WHERE c.relkind = 'v') || ' views, '
                             || count(*) FILTER (WHERE c.relkind = 'i') || ' índices'
                      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                      WHERE n.nspname IN ('stg', 'dw', 'bi') GROUP BY n.nspname ORDER BY n.nspname"""
        with banco.conectar(dbname=banco_prova) as cp:
            objetos_prova = [l[0] for l in cp.execute(consulta).fetchall()]
        objetos_principal = [l[0] for l in conn.execute(consulta).fetchall()]
    finally:
        admin.execute(f"DROP DATABASE IF EXISTS {banco_prova}")
        apagado = admin.execute("SELECT count(*) FROM pg_database WHERE datname = %s", (banco_prova,)).fetchone()[0] == 0
        admin.close()
    ok = r1.returncode == 0 and r2.returncode == 0 and objetos_prova == objetos_principal
    texto = [
        f"PROVA DO DDL EM BANCO VAZIO — {datetime.now():%d/%m/%Y %H:%M:%S}",
        f"Arquivo: sql/ddl_data_warehouse.sql ({len(ddl):,} bytes)",
        f"Banco temporário: {banco_prova} (CREATE DATABASE vazio; DROP ao final: {'sim' if apagado else 'NÃO'})",
        f"Comando: docker exec -i {config.NOME_CONTAINER} psql -U <usuario> -d {banco_prova} -v ON_ERROR_STOP=1 < sql/ddl_data_warehouse.sql",
        "",
        f"1ª execução (banco vazio): código de saída {r1.returncode}",
        "  stderr: " + (r1.stderr.decode('utf-8', 'replace').strip() or "(vazio — nenhum erro)"),
        f"2ª execução (re-execução sobre a estrutura existente): código de saída {r2.returncode}",
        "  stderr: " + (r2.stderr.decode('utf-8', 'replace').strip() or "(vazio — nenhum erro)"),
        "",
        "Objetos criados no banco temporário:", *[f"  {o}" for o in objetos_prova],
        "Objetos no banco principal (dw_sinistros_bh):", *[f"  {o}" for o in objetos_principal],
        "",
        f"RESULTADO: {'APROVADO — o DDL roda do zero sem erros, é re-executável e gera a mesma estrutura do banco principal' if ok else 'REPROVADO'}",
    ]
    (DIR / "05_prova_ddl_banco_vazio.txt").write_text("\n".join(texto) + "\n", encoding="utf-8")
    log.info("Prova do DDL em banco vazio: %s", "APROVADA" if ok else "REPROVADA")
    if not ok:
        raise RuntimeError("A prova do DDL em banco vazio falhou; veja evidencias/05_prova_ddl_banco_vazio.txt")

    p = config.parametros_conexao()
    dump = subprocess.run(["docker", "exec", config.NOME_CONTAINER, "pg_dump", "-U", p["user"], "-d", p["dbname"],
                           "--schema-only", "--no-owner", "--no-privileges"], capture_output=True, timeout=600)
    if dump.returncode != 0:
        raise RuntimeError("pg_dump falhou: " + dump.stderr.decode("utf-8", "replace"))
    (DIR / "ddl_exportado_pg_dump.sql").write_bytes(dump.stdout)
    log.info("pg_dump --schema-only exportado (%d bytes)", len(dump.stdout))


DIAGRAMA_MERMAID = """```mermaid
erDiagram
    DIM_TEMPO ||--o{ FATO_SINISTRO : "sk_tempo"
    DIM_LOCAL ||--o{ FATO_SINISTRO : "sk_local (versão vigente)"
    DIM_TIPO_SINISTRO ||--o{ FATO_SINISTRO : "sk_tipo_sinistro"
    DIM_CONDICAO_VIA ||--o{ FATO_SINISTRO : "sk_condicao_via"
    DIM_REGIONAL ||--o{ FATO_SINISTRO : "sk_regional"
    DIM_TEMPO ||--o{ FATO_ENVOLVIDO : "sk_tempo"
    DIM_LOCAL ||--o{ FATO_ENVOLVIDO : "sk_local"
    DIM_PESSOA ||--o{ FATO_ENVOLVIDO : "sk_pessoa"
    DIM_VEICULO ||--o{ FATO_ENVOLVIDO : "sk_veiculo"
    DIM_REGIONAL ||--o{ FATO_ENVOLVIDO : "sk_regional (conformada)"
    DIM_REGIONAL ||--o{ FATO_POPULACAO : "sk_regional"
    DIM_TEMPO ||--o{ FATO_POPULACAO : "sk_tempo (1/jul, sem hora)"

    FATO_SINISTRO {
        text numero_boletim PK "degenerada"
        smallint ano PK "partição"
        int sk_tempo FK
        int sk_local FK
        smallint sk_tipo_sinistro FK
        smallint sk_condicao_via FK
        smallint sk_regional FK
        smallint qtd_envolvidos
        smallint qtd_vitimas
        smallint qtd_vitimas_fatais
        smallint qtd_veiculos
        smallint qtd_motocicletas "e demais grupos"
        smallint valor_ups "1, 5 ou 13"
        smallint velocidade_permitida "não aditiva"
        numeric precipitacao_mm "INMET"
        boolean fl_fatal
        boolean fl_envolve_pedestre
        boolean fl_envolve_motociclista
        boolean fl_geolocalizado
        geometry geom "ponto exato 4326"
    }
    FATO_ENVOLVIDO {
        text numero_boletim PK
        smallint ano PK "partição"
        smallint numero_envolvido PK
        int sk_tempo FK
        int sk_local FK
        smallint sk_pessoa FK
        smallint sk_veiculo FK
        smallint sk_regional FK
        smallint idade
        text gravidade "degenerada"
        boolean fl_vitima
        boolean fl_vitima_fatal
        boolean fl_pedestre
        boolean fl_motociclista
        boolean fl_condutor
    }
    FATO_POPULACAO {
        smallint sk_regional PK
        smallint ano PK
        int sk_tempo FK
        int populacao_residente "semiaditiva"
        text origem_dado
    }
    DIM_TEMPO {
        int sk_tempo PK "AAAAMMDDHH; HH=99 sem hora"
        date data
        smallint ano
        smallint mes
        smallint dia_semana
        smallint hora
        text periodo_dia
        text faixa_horaria
    }
    DIM_LOCAL {
        int sk_local PK
        text chave_natural "códigos"
        smallint versao "SCD2"
        text descricao_local
        text descricao_local_atual
        text nome_bairro
        boolean fl_cruzamento
        date dt_inicio_vigencia
        date dt_fim_vigencia
        boolean fl_versao_atual
        geometry geom "ponto representativo"
    }
    DIM_TIPO_SINISTRO {
        smallint sk_tipo_sinistro PK
        text cod_tipo_sinistro
        text descricao
        text grupo_tipo_sinistro
    }
    DIM_CONDICAO_VIA {
        smallint sk_condicao_via PK
        text condicao_climatica
        text origem_clima
        text grupo_chuva
        text pavimento
        text local_sinalizado
    }
    DIM_VEICULO {
        smallint sk_veiculo PK
        text especie
        text grupo_especie
        text categoria
        text situacao
    }
    DIM_PESSOA {
        smallint sk_pessoa PK
        text tipo_envolvimento
        text sexo
        text faixa_etaria
        text embriaguez
    }
    DIM_REGIONAL {
        smallint sk_regional PK
        smallint cod_regional
        text nome_regional
        numeric area_km2
        geometry geom "MultiPolygon 4326"
    }
```"""


def documentacao_modelo(conn) -> None:
    """docs/modelo_dimensional.md: diagrama Mermaid + dicionário de dados do dw (dos COMMENT ON)."""
    tabelas = conn.execute("""
        SELECT c.oid, c.relname, CASE c.relkind WHEN 'm' THEN 'view materializada' WHEN 'p' THEN 'fato particionada por ano'
                                  ELSE CASE WHEN c.relname LIKE 'fato%%' THEN 'fato' ELSE 'dimensão' END END,
               obj_description(c.oid, 'pg_class')
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'dw' AND c.relkind IN ('r', 'p', 'm') AND NOT c.relispartition
        ORDER BY CASE WHEN c.relname LIKE 'dim%%' THEN 1 WHEN c.relname LIKE 'fato%%' THEN 2 ELSE 3 END, c.relname""").fetchall()
    md = ["# Modelo dimensional do DW de sinistros de trânsito de BH", "",
          "Modelo estrela com **3 fatos** e **7 dimensões** (nomes da Fase 2), schema `dw` do banco `dw_sinistros_bh`.",
          "Este arquivo é gerado por `python -m etl.evidencias` a partir dos comentários do banco (`COMMENT ON`).", "",
          "## Diagrama", "",
          "Correção em relação ao diagrama da Fase 2: `DIM_PESSOA` e `DIM_VEICULO` ligam-se à `FATO_ENVOLVIDO` "
          "(grão: pessoa), e não à `FATO_SINISTRO` (grão: boletim). A `FATO_SINISTRO` responde ao perfil de veículos "
          "por local com contagens por espécie. A `DIM_REGIONAL` é conformada entre as três fatos.", "",
          DIAGRAMA_MERMAID, "",
          "Membros especiais em todas as dimensões: `-1` = Não informado, `-2` = Não se aplica.", "",
          "## Dicionário de dados", ""]
    for oid, nome, tipo, comentario in tabelas:
        colunas = conn.execute("""
            SELECT a.attname, format_type(a.atttypid, a.atttypmod), NOT a.attnotnull, col_description(%s, a.attnum)
            FROM pg_attribute a WHERE a.attrelid = %s AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum""",
                               (oid, oid)).fetchall()
        md += [f"### dw.{nome} ({tipo})", "", comentario or "", "",
               _tabela_md(["coluna", "tipo", "aceita nulo", "descrição"],
                          [(c, t, "sim" if n else "não", d) for c, t, n, d in colunas]), ""]
    destino = config.RAIZ / "docs" / "modelo_dimensional.md"
    destino.parent.mkdir(exist_ok=True)
    destino.write_text("\n".join(md), encoding="utf-8")
    log.info("Documentação do modelo: %d objetos do dw", len(tabelas))


def executar(conn, prova: bool = True) -> None:
    DIR.mkdir(exist_ok=True)
    estrutura(conn)
    contagens(conn)
    consultas_negocio(conn)
    documentacao_modelo(conn)
    if prova:
        prova_ddl(conn)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--sem-prova-ddl", action="store_true")
    a = ap.parse_args()
    configurar_log()
    with banco.conexao() as c:
        executar(c, prova=not a.sem_prova_ddl)
