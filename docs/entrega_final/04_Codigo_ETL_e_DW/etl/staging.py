"""
Etapa 2 — STAGING.

Carrega os arquivos da camada RAW no schema stg com COPY, sem regra de
negócio: todas as colunas como texto, exatamente como vieram, com os
cabeçalhos harmonizados pelo de-para (etl/mapeamentos/de_para_cabecalhos.csv)
e as colunas de linhagem ano_arquivo, arquivo_origem, linha_arquivo, dt_carga.

Uso isolado:  python -m etl.staging [--anos 2011-2024]
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import logging

import psycopg
import shapefile
from psycopg import sql

from etl import banco, config, leitura
from etl.util import configurar_log, interpretar_anos

log = logging.getLogger("staging")

TABELAS_STG = ["manifesto_raw", "si_bol", "si_log", "si_veic", "si_env", "regional_limite",
               "ibge_sidra_valor", "ibge_localidade", "ibge_setor2010_malha",
               "ibge_setor2010_variavel", "inmet_horario", "map_dominio", "map_regional"]

COLUNA_IGNORADA = "(ignorar)"


def _copiar(conn: psycopg.Connection, tabela: str, colunas: list[str], linhas) -> int:
    """COPY ... FROM STDIN de um iterável de listas (valores texto)."""
    comando = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier("stg", tabela), sql.SQL(", ").join(map(sql.Identifier, colunas)))
    n = 0
    with conn.cursor() as cur, cur.copy(comando) as cp:
        for linha in linhas:
            cp.write_row(linha)
            n += 1
    return n


def _rel(caminho) -> str:
    return caminho.relative_to(config.DIR_RAW).as_posix()


# ---------------------------------------------------------------------------
def carregar_manifesto(conn) -> None:
    with open(config.ARQ_MANIFESTO, newline="", encoding="utf-8") as f:
        leitor = csv.DictReader(f)
        campos = leitor.fieldnames
        linhas = [[l[c] for c in campos] + ["manifesto.csv", i]
                  for i, l in enumerate(leitor, start=2)]
    n = _copiar(conn, "manifesto_raw", campos + ["arquivo_origem", "linha_arquivo"], linhas)
    log.info("stg.manifesto_raw: %d linhas", n)


def carregar_pbh(conn, conjunto: str, anos: list[int] | None) -> int:
    """si_bol / si_log / si_veic / si_env: um arquivo por ano."""
    de_para = leitura.carregar_de_para()
    total = 0
    for ano, caminho in leitura.arquivos_pbh(conjunto, anos):
        cab, linhas, cod = leitura.ler_csv(caminho)
        cols = leitura.harmonizar_cabecalho(conjunto, cab, de_para)
        usar = [i for i, c in enumerate(cols) if c != COLUNA_IGNORADA]
        destino = [cols[i] for i in usar] + ["ano_arquivo", "arquivo_origem", "linha_arquivo"]
        nome = _rel(caminho)
        n = _copiar(conn, conjunto, destino,
                    ([l[i] for i in usar] + [ano, nome, num] for num, l in enumerate(linhas, start=2)))
        log.info("stg.%s <- %s (%s): %d linhas", conjunto, caminho.name, cod, n)
        total += n
    return total


def carregar_regionais(conn) -> None:
    for l in leitura.arquivos_manifesto("pbh_ckan", "regional"):
        if not l["arquivo"].lower().endswith(".csv"):
            continue
        caminho = config.DIR_RAW / l["arquivo"]
        texto = caminho.read_text(encoding="utf-8-sig")
        delim = ";" if ";" in texto.splitlines()[0] else ","
        leitor = csv.reader(io.StringIO(texto), delimiter=delim)
        cab = [c.strip().lower() for c in next(leitor)]
        esperado = ["id_reg", "cod_reg", "sigla", "nome", "area_km2", "perimetr_m", "geometria"]
        if cab != esperado:
            raise ValueError(f"Layout inesperado em {caminho.name}: {cab}")
        n = _copiar(conn, "regional_limite", esperado + ["arquivo_origem", "linha_arquivo"],
                    (r + [_rel(caminho), i] for i, r in enumerate(leitor, start=2) if r))
        log.info("stg.regional_limite <- %s: %d regionais", caminho.name, n)


def carregar_ibge(conn) -> None:
    sidra, locais = [], []
    for l in leitura.arquivos_manifesto("ibge"):
        caminho = config.DIR_RAW / l["arquivo"]
        dados = json.loads(caminho.read_text(encoding="utf-8"))
        nome = _rel(caminho)
        if caminho.name.startswith("localidades_"):
            for i, x in enumerate(dados, start=1):
                if "distrito" in x:  # subdistrito
                    d = x["distrito"]
                    locais.append(["subdistrito", x["id"], x["nome"], d["id"], d["nome"],
                                   d["municipio"]["id"], nome, i])
                else:
                    locais.append(["distrito", x["id"], x["nome"], x["id"], x["nome"],
                                   x["municipio"]["id"], nome, i])
        elif "_metadados" not in caminho.name:
            tabela = caminho.name.split("_")[1]
            i = 0
            for var in dados:
                for res in var["resultados"]:
                    for serie in res["series"]:
                        loc = serie["localidade"]
                        for periodo, valor in serie["serie"].items():
                            i += 1
                            sidra.append([tabela, var["id"], var["variavel"], loc["nivel"]["id"],
                                          loc["id"], loc["nome"], periodo, valor, nome, i])
    _copiar(conn, "ibge_localidade", ["tipo", "localidade_id", "localidade_nome", "distrito_id",
                                      "distrito_nome", "municipio_id", "arquivo_origem", "linha_arquivo"], locais)
    _copiar(conn, "ibge_sidra_valor", ["tabela", "variavel_id", "variavel_nome", "nivel", "localidade_id",
                                       "localidade_nome", "periodo", "valor", "arquivo_origem",
                                       "linha_arquivo"], sidra)
    log.info("stg.ibge_localidade: %d | stg.ibge_sidra_valor: %d", len(locais), len(sidra))


# Variáveis de população aproveitadas dos agregados por setor de 2010
VARIAVEIS_SETOR_2010 = {"basico_mg.csv": ("Basico", ["V001", "V002"]),
                        "pessoa13_mg.csv": ("Pessoa13", ["V001"]),
                        "domicilio02_mg.csv": ("Domicilio02", ["V001"])}


def carregar_setores_2010(conn) -> None:
    mun = str(config.IBGE_MUNICIPIO)
    for l in leitura.arquivos_manifesto("ibge_setores_2010"):
        caminho = config.DIR_RAW / l["arquivo"]
        nome_arq = caminho.name.lower()
        if nome_arq.endswith(".shp"):
            campos = ["cd_geocodi", "tipo", "cd_geocodb", "nm_bairro", "cd_geocods", "nm_subdist",
                      "cd_geocodd", "nm_distrit", "cd_geocodm", "nm_municip"]
            with shapefile.Reader(str(caminho), encoding="latin-1") as shp:
                def registros():
                    for i, sr in enumerate(shp.iterShapeRecords(), start=1):
                        rec = sr.record.as_dict()
                        if rec["CD_GEOCODM"] != mun:
                            continue
                        yield ([rec[c.upper()] for c in campos]
                               + [json.dumps(sr.shape.__geo_interface__), _rel(caminho), i])
                n = _copiar(conn, "ibge_setor2010_malha", campos + ["geometria_geojson", "arquivo_origem",
                                                                    "linha_arquivo"], registros())
            log.info("stg.ibge_setor2010_malha <- %s: %d setores de BH", caminho.name, n)
        elif nome_arq in VARIAVEIS_SETOR_2010:
            planilha, variaveis = VARIAVEIS_SETOR_2010[nome_arq]
            cab, linhas, _ = leitura.ler_csv(caminho)
            idx = {c.strip(): i for i, c in enumerate(cab)}
            saida = [[r[idx["Cod_setor"]], planilha, v, r[idx[v]], _rel(caminho), num]
                     for num, r in enumerate(linhas, start=2) if r[idx["Cod_setor"]].startswith(mun)
                     for v in variaveis]
            _copiar(conn, "ibge_setor2010_variavel", ["cod_setor", "planilha", "variavel", "valor",
                                                      "arquivo_origem", "linha_arquivo"], saida)
            log.info("stg.ibge_setor2010_variavel <- %s: %d valores", caminho.name, len(saida))


def carregar_mapeamentos(conn) -> None:
    """Seeds: de-paras de domínio e de regionais (etl/mapeamentos/*.csv) -> stg.map_*."""
    for arquivo, tabela in (("dominios.csv", "map_dominio"), ("regionais.csv", "map_regional")):
        caminho = config.DIR_MAPEAMENTOS / arquivo
        with open(caminho, newline="", encoding="utf-8") as f:
            leitor = csv.DictReader(f, delimiter=";")
            campos = leitor.fieldnames
            linhas = [[(l[c] if l[c] != "" else None) for c in campos] + [f"etl/mapeamentos/{arquivo}", i]
                      for i, l in enumerate(leitor, start=2)]
        n = _copiar(conn, tabela, campos + ["arquivo_origem", "linha_arquivo"], linhas)
        log.info("stg.%s <- %s: %d linhas", tabela, arquivo, n)


def carregar_inmet(conn, anos: list[int] | None) -> None:
    de_para = leitura.carregar_de_para()
    for l in leitura.arquivos_manifesto("inmet"):
        ano = int(l["ano"])
        if anos and ano not in anos:
            continue
        caminho = config.DIR_RAW / l["arquivo"]
        texto = caminho.read_bytes().decode(leitura.detectar_codificacao(caminho.read_bytes()))
        meta_linhas = texto.splitlines()[:8]
        meta = {leitura.normalizar_cabecalho(x.split(";")[0]).rstrip(":"): x.split(";")[1].strip()
                for x in meta_linhas if ";" in x}
        codigo, nome_est = meta.get("codigo_(wmo)", ""), meta.get("estacao", "")
        cab, linhas, _ = leitura.ler_csv(caminho, pular_linhas=8)
        cols = leitura.harmonizar_cabecalho("inmet", cab, de_para)
        usar = [i for i, c in enumerate(cols) if c != COLUNA_IGNORADA]
        destino = (["estacao_codigo", "estacao_nome"] + [cols[i] for i in usar]
                   + ["ano_arquivo", "arquivo_origem", "linha_arquivo"])
        n = _copiar(conn, "inmet_horario", destino,
                    ([codigo, nome_est] + [r[i] if i < len(r) else "" for i in usar]
                     + [ano, _rel(caminho), num] for num, r in enumerate(linhas, start=10)))
        log.info("stg.inmet_horario <- %s (%s): %d horas", caminho.name, codigo, n)


# ---------------------------------------------------------------------------
def executar(conn, anos: list[int] | None = None) -> dict[str, int]:
    """Esvazia e recarrega todas as tabelas-espelho do stg. Retorna linhas por tabela."""
    conn.execute("TRUNCATE " + ", ".join(f"stg.{t}" for t in TABELAS_STG))
    carregar_manifesto(conn)
    for conjunto in ("si_bol", "si_log", "si_veic", "si_env"):
        carregar_pbh(conn, conjunto, anos)
    carregar_regionais(conn)
    carregar_ibge(conn)
    carregar_setores_2010(conn)
    carregar_inmet(conn, anos)
    carregar_mapeamentos(conn)
    conn.commit()
    contagens = {t: conn.execute(f"SELECT count(*) FROM stg.{t}").fetchone()[0] for t in TABELAS_STG}
    for t, n in contagens.items():
        log.info("  stg.%-26s %10d linhas", t, n)
    return contagens


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Carrega a camada RAW no schema stg")
    p.add_argument("--anos")
    a = p.parse_args()
    configurar_log()
    with banco.conexao() as c:
        executar(c, interpretar_anos(a.anos))
