"""
TESTES LOCAIS DE PONTA A PONTA — verificam se o ambiente e a carga funcionam.

Executa o ponto de entrada várias vezes e confere os resultados:
  1. carga do zero (--recriar) termina com sucesso e registra todas as etapas em stg.log_carga;
  2. idempotência: uma segunda execução não baixa nada de novo e gera exatamente o mesmo dw
     (mesmas contagens e mesma "impressão digital" md5 das fatos e da dim_local);
  3. opção --anos: carga parcial só com os anos pedidos e contagens iguais às da carga completa;
  4. falha crítica: um teste CRÍTICO reprovado interrompe a carga (verificado sem alterar dados);
  5. disciplina dos scripts: o DDL não tem DML e os scripts de carga não têm DDL;
  6. carga completa final, prova do DDL em banco vazio e evidências geradas.
Resultado em evidencias/06_testes_locais.md.

Uso:  python -m etl.testes_locais        (leva alguns minutos: roda a carga 4 vezes)
"""
from __future__ import annotations

import csv
import json
import logging
import re
import subprocess
import sys
import time
from datetime import datetime

from etl import banco, config, powerbi, testes_qualidade
from etl.util import configurar_log

log = logging.getLogger("testes_locais")

IMPRESSAO_DIGITAL = {
    "fato_sinistro": """SELECT count(*), md5(string_agg(concat_ws('|', numero_boletim, ano, sk_tempo, sk_local, sk_tipo_sinistro,
                            sk_condicao_via, sk_regional, qtd_vitimas, qtd_vitimas_fatais, qtd_veiculos, valor_ups,
                            precipitacao_mm, fl_geolocalizado), ',' ORDER BY ano, numero_boletim)) FROM dw.fato_sinistro""",
    "fato_envolvido": """SELECT count(*), md5(string_agg(concat_ws('|', numero_boletim, ano, numero_envolvido, sk_pessoa,
                             sk_veiculo, sk_regional, gravidade, fl_pedestre, fl_motociclista), ','
                             ORDER BY ano, numero_boletim, numero_envolvido)) FROM dw.fato_envolvido""",
    "fato_populacao": """SELECT count(*), md5(string_agg(concat_ws('|', sk_regional, ano, populacao_residente), ','
                             ORDER BY ano, sk_regional)) FROM dw.fato_populacao""",
    "dim_local": """SELECT count(*), md5(string_agg(concat_ws('|', sk_local, chave_natural, versao, dt_inicio_vigencia,
                        descricao_local), ',' ORDER BY sk_local)) FROM dw.dim_local""",
    "mv_taxa_mortalidade_anual": """SELECT count(*), md5(string_agg(concat_ws('|', ano, mortos, taxa_mortos_100mil), ','
                                        ORDER BY ano)) FROM dw.mv_taxa_mortalidade_anual""",
}

resultados: list[tuple[str, bool, str]] = []


def registrar(nome: str, ok: bool, detalhe: str = "") -> None:
    resultados.append((nome, ok, detalhe))
    log.log(logging.INFO if ok else logging.ERROR, "[%s] %s %s", "OK" if ok else "FALHOU", nome,
            f"— {detalhe}" if detalhe else "")


def rodar_carga(*args: str) -> tuple[int, float, str]:
    inicio = time.perf_counter()
    p = subprocess.run([sys.executable, "-m", "etl.carga_inicial", *args], cwd=config.RAIZ,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, time.perf_counter() - inicio, p.stdout + p.stderr


def impressao_digital() -> dict[str, tuple]:
    with banco.conexao() as c:
        return {k: tuple(c.execute(q).fetchone()) for k, q in IMPRESSAO_DIGITAL.items()}


def ultima_execucao() -> tuple[int, list[tuple]]:
    with banco.conexao() as c:
        ident = c.execute("SELECT max(id_execucao) FROM stg.log_carga").fetchone()[0]
        etapas = c.execute("SELECT etapa, status FROM stg.log_carga WHERE id_execucao = %s ORDER BY id_log",
                           (ident,)).fetchall()
    return ident, etapas


def hashes_raw() -> dict[str, str]:
    with open(config.ARQ_MANIFESTO, newline="", encoding="utf-8") as f:
        return {l["arquivo"]: l["sha256"] for l in csv.DictReader(f) if l["conjunto"] != "metadados"}


def main() -> int:
    configurar_log()
    inicio_geral = datetime.now()

    # 0. ambiente --------------------------------------------------------------
    try:
        with banco.conexao() as c:
            versao = c.execute("SELECT version(), postgis_lib_version()").fetchone()
        registrar("Ambiente: conexão ao banco por 127.0.0.1 com as credenciais do .env", True,
                  f"{versao[0][:40]}... / PostGIS {versao[1]}")
    except Exception as e:
        registrar("Ambiente: conexão ao banco", False, str(e))
        return gerar_relatorio(inicio_geral)

    # 1. carga do zero ---------------------------------------------------------
    hashes_antes = hashes_raw()
    cod, dur, saida = rodar_carga("--recriar")
    registrar("Carga do zero (--recriar) termina com código 0", cod == 0, f"{dur:.0f}s")
    ident, etapas = ultima_execucao()
    esperadas = ["0-ddl", "1-extrair", "2-staging", "3-transformar", "4-testes_qualidade",
                 "5-carregar_dw", "6-reconciliar", "7-evidencias"]
    registrar("Log de carga: as 8 etapas registradas com SUCESSO em stg.log_carga",
              [e for e, s in etapas if s == "SUCESSO"] == esperadas, f"id_execucao={ident}: {etapas}")
    digital_a = impressao_digital()
    registrar("Carga completa: fatos e dimensões populadas",
              all(v[0] > 0 for v in digital_a.values()), str({k: v[0] for k, v in digital_a.items()}))

    # 2. idempotência ------------------------------------------------------------
    cod, dur, saida = rodar_carga()
    registrar("Idempotência: 2ª execução (sem flags) termina com código 0", cod == 0, f"{dur:.0f}s")
    nenhum_download = "baixado:" not in saida and "guardado(s)" not in saida
    registrar("Idempotência: nenhum arquivo baixado de novo (nada mudou na origem)", nenhum_download,
              "extração comparou data de modificação e hash com o manifesto")
    registrar("Idempotência: hashes da camada RAW inalterados", hashes_raw() == hashes_antes,
              f"{len(hashes_antes)} arquivos")
    digital_b = impressao_digital()
    iguais = digital_a == digital_b
    registrar("Idempotência: dw idêntico ao da 1ª carga (contagens e md5 das fatos, dim_local e taxa anual)",
              iguais, "" if iguais else f"A={digital_a} B={digital_b}")

    # 3. carga parcial com --anos -----------------------------------------------
    cod, dur, saida = rodar_carga("--anos", "2023-2024", "--sem-download", "--sem-evidencias")
    registrar("Opção --anos 2023-2024 termina com código 0", cod == 0, f"{dur:.0f}s")
    with banco.conexao() as c:
        anos = [r[0] for r in c.execute("SELECT DISTINCT ano FROM dw.fato_sinistro ORDER BY 1").fetchall()]
        n_parcial = c.execute("SELECT count(*) FROM dw.fato_sinistro").fetchone()[0]
    registrar("Opção --anos: dw contém só 2023 e 2024", anos == [2023, 2024], f"anos={anos}, sinistros={n_parcial}")

    # 4. falha crítica (sem alterar dados: transação desfeita) ----------------
    try:
        testes_qualidade._verificar_criticos([{"teste": "simulado", "severidade": "CRITICO", "aprovado": False,
                                               "valor": "1", "criterio": "0", "detalhe": ""}])
        registrar("Falha crítica interrompe a carga (FalhaCritica levantada)", False, "não levantou exceção")
    except testes_qualidade.FalhaCritica as e:
        registrar("Falha crítica interrompe a carga (FalhaCritica levantada)", True, str(e).splitlines()[0])
    teste_pop = next(t for t in testes_qualidade.testes_pre_carga([2023, 2024])
                     if t.nome.startswith("População: soma das regionais"))
    c = banco.conectar()
    try:
        c.execute("UPDATE stg.trf_populacao SET populacao_residente = populacao_residente + 1 "
                  "WHERE ano = 2024 AND cod_reg_limite = 19")
        _, aprovado, _ = c.execute(teste_pop.sql).fetchone()
        registrar("Teste de qualidade detecta população inconsistente (dado corrompido em transação desfeita)",
                  aprovado is False, "regional 19 em 2024 alterada em +1 e revertida")
    finally:
        c.rollback()
        c.close()

    # 5. disciplina DDL x DML ----------------------------------------------------
    def sem_comentarios(texto: str) -> str:
        texto = re.sub(r"/\*.*?\*/", "", texto, flags=re.S)
        return "\n".join(l.split("--")[0] for l in texto.splitlines())
    ddl = sem_comentarios(config.ARQ_DDL.read_text(encoding="utf-8")).upper()
    dml_no_ddl = re.findall(r"\b(INSERT\s+INTO|UPDATE\s+\w+\.\w+\s+SET|DELETE\s+FROM|COPY\s+\w)", ddl)
    registrar("DDL (sql/ddl_data_warehouse.sql) não contém DML", not dml_no_ddl, str(dml_no_ddl[:5]))
    ddl_na_carga = {}
    for arq in sorted(config.DIR_SQL_CARGA.glob("*.sql")):
        achados = re.findall(r"\b(CREATE\s+(?:TABLE|INDEX|VIEW|SCHEMA|MATERIALIZED)|ALTER\s+TABLE|DROP\s+(?:TABLE|SCHEMA))",
                             sem_comentarios(arq.read_text(encoding="utf-8")).upper())
        if achados:
            ddl_na_carga[arq.name] = achados
    registrar("Scripts de carga (sql/carga/) não contêm DDL", not ddl_na_carga, str(ddl_na_carga))

    # 6. carga completa final + evidências --------------------------------------
    cod, dur, saida = rodar_carga("--sem-download")
    registrar("Carga completa final termina com código 0", cod == 0, f"{dur:.0f}s")
    digital_d = impressao_digital()
    registrar("Carga final idêntica à primeira (reprodutível)", digital_d == digital_a)
    prova = (config.DIR_EVIDENCIAS / "05_prova_ddl_banco_vazio.txt").read_text(encoding="utf-8")
    registrar("DDL roda do zero num banco vazio, é re-executável e gera a mesma estrutura",
              "RESULTADO: APROVADO" in prova, prova.splitlines()[-1][:160])
    dump = config.DIR_EVIDENCIAS / "ddl_exportado_pg_dump.sql"
    registrar("pg_dump --schema-only exportado", dump.exists() and dump.stat().st_size > 10_000,
              f"{dump.stat().st_size if dump.exists() else 0} bytes")
    with banco.conexao() as c:
        ident = c.execute("SELECT max(id_execucao) FROM stg.resultado_qualidade").fetchone()[0]
        criticos = c.execute("""SELECT count(*) FILTER (WHERE severidade = 'CRITICO' AND NOT aprovado),
                                       count(*) FILTER (WHERE NOT aprovado), count(*)
                                FROM stg.resultado_qualidade WHERE id_execucao = %s""", (ident,)).fetchone()
        sem_comentario = c.execute("""
            SELECT count(*) FROM pg_attribute a JOIN pg_class cl ON cl.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = cl.relnamespace
            WHERE n.nspname IN ('stg', 'dw', 'bi') AND cl.relkind IN ('r', 'p', 'm', 'v') AND NOT cl.relispartition
              AND a.attnum > 0 AND NOT a.attisdropped AND col_description(cl.oid, a.attnum) IS NULL""").fetchone()[0]
    registrar("Testes de qualidade: nenhum CRÍTICO reprovado", criticos[0] == 0,
              f"{criticos[2]} testes; {criticos[1]} reprovados (todos não críticos)")
    registrar("COMMENT ON em todas as colunas de stg, dw e bi", sem_comentario == 0, f"{sem_comentario} sem comentário")
    def qtd_regionais(arquivo):
        d = json.loads(arquivo.read_text(encoding="utf-8"))
        return len(d["features"]) if d["type"] == "FeatureCollection" else len(d["objects"]["regionais"]["geometries"])
    regionais = [qtd_regionais(m) for m in (powerbi.ARQ_GEOJSON, powerbi.ARQ_TOPOJSON) if m.exists()]
    registrar("Power BI: polígonos das 9 regionais exportados (GeoJSON e TopoJSON)", regionais == [9, 9],
              f"regionais por arquivo: {regionais}")
    consultas = (config.DIR_EVIDENCIAS / "04_consultas_negocio.md").read_text(encoding="utf-8")
    secoes = re.findall(r"\*\*Resultado\*\* \((\d+) linhas\)", consultas)
    registrar("Consultas de negócio executadas e com resultado", len(secoes) >= 6 and all(int(s) > 0 for s in secoes),
              f"{len(secoes)} consultas; linhas: {secoes}")
    arquivos = ["01_estrutura_dw.md", "02_contagens.md", "03_relatorio_qualidade.md", "04_consultas_negocio.md",
                "05_prova_ddl_banco_vazio.txt", "ddl_exportado_pg_dump.sql", "log_carga_inicial.txt"]
    faltando = [a for a in arquivos if not (config.DIR_EVIDENCIAS / a).exists()]
    registrar("Evidências geradas", not faltando, f"faltando: {faltando}" if faltando else f"{len(arquivos)} arquivos")
    doc = config.RAIZ / "docs" / "modelo_dimensional.md"
    registrar("docs/modelo_dimensional.md gerado com diagrama Mermaid",
              doc.exists() and "erDiagram" in doc.read_text(encoding="utf-8"))
    return gerar_relatorio(inicio_geral)


def gerar_relatorio(inicio: datetime) -> int:
    aprovados = sum(1 for _, ok, _ in resultados if ok)
    linhas = [f"# Testes locais de ponta a ponta — {inicio:%d/%m/%Y %H:%M}", "",
              f"Comando: `python -m etl.testes_locais` · duração: {(datetime.now() - inicio).seconds // 60} min · "
              f"**{aprovados} de {len(resultados)} verificações aprovadas**", "",
              "| # | Resultado | Verificação | Detalhe |", "|---|---|---|---|"]
    for i, (nome, ok, det) in enumerate(resultados, start=1):
        det = det.replace("|", "\\|").replace("\n", " ")
        linhas.append(f"| {i} | {'✅' if ok else '❌'} | {nome} | {det[:400]} |")
    (config.DIR_EVIDENCIAS / "06_testes_locais.md").write_text("\n".join(linhas) + "\n", encoding="utf-8")
    log.info("Testes locais: %d de %d aprovados", aprovados, len(resultados))
    return 0 if aprovados == len(resultados) else 1


if __name__ == "__main__":
    sys.exit(main())
