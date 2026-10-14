"""
Etapa 3 — TRANSFORMAR.

Transforma os espelhos do stg nas tabelas de trabalho stg.trf_*, que são a
base dos testes de qualidade e da carga do dw. Combina SQL (sql/carga/1x_*.sql)
e Python nas partes em que o Python é mais claro:

  * coordenadas: correção do formato antigo e reprojeção com pyproj;
  * INMET: conversão de UTC para America/Sao_Paulo com zoneinfo;
  * população por regional: série municipal + participações + maior resto;
  * logradouros e locais: normalização de nomes, consolidação de variações por
    similaridade e versões SCD Tipo 2.

Uso isolado:  python -m etl.transformar
"""
from __future__ import annotations

import collections
import csv
import logging
import math
import re
import unicodedata
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import numpy as np
from psycopg import sql
from pyproj import Transformer
from rapidfuzz import fuzz

from etl import banco, config
from etl.util import configurar_log

log = logging.getLogger("transformar")

DATA_MIN = date(1900, 1, 1)
DATA_MAX = date(9999, 12, 31)


def _sql(conn, nome: str) -> None:
    banco.executar_arquivo(conn, config.DIR_SQL_CARGA / nome)


def _copiar(conn, tabela: str, colunas: list[str], linhas) -> int:
    comando = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier(*tabela.split(".")), sql.SQL(", ").join(map(sql.Identifier, colunas)))
    n = 0
    with conn.cursor() as cur, cur.copy(comando) as cp:
        for l in linhas:
            cp.write_row(l)
            n += 1
    return n


# =============================================================================
# 1. Coordenadas
# =============================================================================
# Faixa plausível para BH em UTM 23S (metros), com folga
FAIXA_X = (585_000.0, 630_000.0)
FAIXA_Y = (7_770_000.0, 7_830_000.0)
ULTIMO_ANO_SAD69 = 2015  # dicionário 2011–2015: "UTM - SAD 69 fuso 23S"; 2016+: SIRGAS 2000


def criar_transformadores():
    """SAD69/UTM23S -> SIRGAS2000/UTM23S -> WGS84, com autoverificação do deslocamento."""
    sad_para_sirgas = Transformer.from_crs("EPSG:29193", "EPSG:31983", always_xy=True)
    sirgas_para_wgs = Transformer.from_crs("EPSG:31983", "EPSG:4326", always_xy=True)
    x, y = sad_para_sirgas.transform(609_000.0, 7_797_000.0)
    dx, dy = x - 609_000.0, y - 7_797_000.0
    # deslocamento medido nos dados (mesmos endereços em 2015 x 2016): -44,6 m / -44,3 m
    if not (-48 < dx < -41 and -48 < dy < -41):
        raise RuntimeError(f"Transformação SAD69->SIRGAS inesperada (dx={dx:.1f} m, dy={dy:.1f} m)")
    log.info("pyproj: SAD69 -> SIRGAS 2000 em BH desloca dx=%.1f m, dy=%.1f m", dx, dy)
    return sad_para_sirgas, sirgas_para_wgs


def corrigir_escala(x: float, y: float) -> tuple[float, float, str]:
    """Detecta e corrige formatos: normal, antigo (x100 e Y sem 7.000.000), X/Y trocados."""
    if FAIXA_X[0] * 100 <= x <= FAIXA_X[1] * 100 and (FAIXA_Y[0] - 7e6) * 100 <= y <= (FAIXA_Y[1] - 7e6) * 100:
        return x / 100.0, 7_000_000.0 + y / 100.0, "ESCALA_ANTIGA"
    if FAIXA_X[0] <= y <= FAIXA_X[1] and FAIXA_Y[0] <= x <= FAIXA_Y[1]:
        return y, x, "XY_TROCADOS"
    return x, y, "NORMAL"


def transformar_coordenadas(conn) -> None:
    sad_para_sirgas, sirgas_para_wgs = criar_transformadores()
    linhas = conn.execute("""SELECT numero_boletim_dw, ano, coordenada_x_origem, coordenada_y_origem
                             FROM stg.trf_boletim""").fetchall()
    saida, contagem = [], collections.Counter()
    validos = []  # índices em 'saida' para reprojetar em lote
    for nb, ano, xo, yo in linhas:
        if xo is None or yo is None or float(xo) == 0 or float(yo) == 0:
            saida.append([nb, ano, None, None, None, None, None, "ZERADA"])
            contagem["ZERADA"] += 1
            continue
        x, y, formato = corrigir_escala(float(xo), float(yo))
        contagem[formato] += 1
        srid = 29193 if ano <= ULTIMO_ANO_SAD69 else 31983
        if not (FAIXA_X[0] <= x <= FAIXA_X[1] and FAIXA_Y[0] <= y <= FAIXA_Y[1]):
            saida.append([nb, ano, srid, round(x, 2), round(y, 2), None, None, "FORA_FAIXA_BH"])
            contagem["FORA_FAIXA_BH"] += 1
            continue
        saida.append([nb, ano, srid, round(x, 2), round(y, 2), None, None, "VALIDA"])
        validos.append(len(saida) - 1)

    # reprojeção vetorizada: primeiro SAD69 -> SIRGAS (só 2011–2015), depois SIRGAS -> WGS84
    xs = np.array([saida[i][3] for i in validos], dtype=float)
    ys = np.array([saida[i][4] for i in validos], dtype=float)
    antigos = np.array([saida[i][2] == 29193 for i in validos])
    if antigos.any():
        xs[antigos], ys[antigos] = sad_para_sirgas.transform(xs[antigos], ys[antigos])
    lon, lat = sirgas_para_wgs.transform(xs, ys)
    for k, i in enumerate(validos):
        saida[i][5], saida[i][6] = float(lon[k]), float(lat[k])

    conn.execute("TRUNCATE stg.trf_coordenada")
    _copiar(conn, "stg.trf_coordenada",
            ["numero_boletim_dw", "ano", "srid_origem", "x_utm", "y_utm", "longitude", "latitude", "situacao"],
            saida)
    log.info("Coordenadas: %d boletins; formatos/situações: %s", len(saida), dict(contagem))


# =============================================================================
# 2. INMET: UTC -> horário local
# =============================================================================
def _numero_inmet(texto: str | None) -> float | None:
    if texto is None:
        return None
    t = texto.strip().replace(",", ".")
    if t == "" or t.startswith("-9999"):
        return None
    v = float(t)
    return None if v <= -9999 else v


def transformar_clima(conn) -> None:
    fuso = ZoneInfo(config.FUSO_LOCAL)
    linhas = conn.execute("""SELECT estacao_codigo, data_medicao, hora_utc, precipitacao_mm,
                                    temperatura_ar_c, umidade_relativa_pct, arquivo_origem
                             FROM stg.inmet_horario
                             ORDER BY estacao_codigo, ano_arquivo, linha_arquivo""").fetchall()
    saida, vistos, repetidas = [], set(), 0
    for est, d, h, prec, temp, umid, arq in linhas:
        d = d.strip().replace("/", "-")                 # 2011-01-01 ou 2019/01/01
        h = h.strip().upper().replace("UTC", "").replace(":", "").strip().zfill(4)  # 00:00 ou 0000 UTC
        fim_utc = datetime.strptime(d + h, "%Y-%m-%d%H%M").replace(tzinfo=timezone.utc)
        # a leitura cobre a hora que TERMINA em fim_utc; a chave é o início em horário local
        inicio_local = (fim_utc - timedelta(hours=1)).astimezone(fuso).replace(tzinfo=None)
        chave = (est, inicio_local)
        if chave in vistos:  # hora repetida no fim do horário de verão
            repetidas += 1
            continue
        vistos.add(chave)
        p = _numero_inmet(prec)
        saida.append([est, inicio_local, fim_utc, p if p is None or p >= 0 else None,
                      _numero_inmet(temp), _numero_inmet(umid), arq])
    conn.execute("TRUNCATE stg.trf_clima_hora")
    _copiar(conn, "stg.trf_clima_hora",
            ["estacao_codigo", "dt_hora_inicio_local", "dt_hora_fim_utc", "precipitacao_mm",
             "temperatura_ar_c", "umidade_relativa_pct", "arquivo_origem"], saida)
    com_chuva = sum(1 for s in saida if s[3] is not None)
    log.info("INMET: %d horas (com precipitação válida: %d; horas repetidas do horário de verão: %d)",
             len(saida), com_chuva, repetidas)


# =============================================================================
# 3. População por regional
# =============================================================================
def maior_resto(total: int, pesos: dict[int, float]) -> dict[int, int]:
    """Distribui 'total' proporcionalmente aos pesos, com inteiros que somam exatamente o total."""
    soma = sum(pesos.values())
    brutos = {k: total * v / soma for k, v in pesos.items()}
    base = {k: math.floor(v) for k, v in brutos.items()}
    falta = total - sum(base.values())
    for k in sorted(brutos, key=lambda k: brutos[k] - base[k], reverse=True)[:falta]:
        base[k] += 1
    return base


def _sem_acento(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")


def transformar_populacao(conn) -> None:
    valores = conn.execute("""SELECT tabela, nivel, localidade_id, localidade_nome, periodo, valor
                              FROM stg.ibge_sidra_valor WHERE valor ~ '^\\d+$'""").fetchall()
    estimativas = {int(p): int(v) for t, n, _, _, p, v in valores if t == str(config.IBGE_TAB_ESTIMATIVAS) and n == "N6"}
    censo2010 = next(int(v) for t, n, _, _, p, v in valores if t == str(config.IBGE_TAB_CENSO_2010) and n == "N6")
    censo2022 = next(int(v) for t, n, _, _, p, v in valores if t == str(config.IBGE_TAB_CENSO_2022) and n == "N6")

    # série municipal --------------------------------------------------------
    serie: dict[int, tuple[int, str]] = {2010: (censo2010, "CENSO 2010 (SIDRA 202)"),
                                         2022: (censo2022, "CENSO 2022 (SIDRA 9923)")}
    for ano, v in estimativas.items():
        if ano >= 2011 and ano != 2022:
            serie[ano] = (v, "ESTIMATIVA IBGE 1º/JUL (SIDRA 6579)")
    anos = range(2010, max(serie) + 1)
    for ano in anos:  # lacunas (ex.: 2023): interpolação geométrica entre os vizinhos
        if ano not in serie:
            a0 = max(a for a in serie if a < ano)
            a1 = min(a for a in serie if a > ano)
            p0, p1 = serie[a0][0], serie[a1][0]
            v = round(p0 * (p1 / p0) ** ((ano - a0) / (a1 - a0)))
            serie[ano] = (v, f"INTERPOLAÇÃO GEOMÉTRICA {a0}–{a1}")
            log.info("População %d interpolada geometricamente entre %d (%d) e %d (%d): %d",
                     ano, a0, p0, a1, p1, v)

    # participações das regionais ---------------------------------------------
    mapa_nome = {_sem_acento(n).upper(): cod for cod, n in conn.execute(
        """SELECT DISTINCT cod_reg_limite, nome_subdistrito_ibge FROM stg.map_regional
           WHERE nome_subdistrito_ibge IS NOT NULL""").fetchall()}
    pop2022: dict[int, int] = collections.Counter()
    pop2010_subdistrito: dict[int, int] = collections.Counter()
    for t, n, _, nome, p, v in valores:
        if n != "N11":
            continue
        cod = mapa_nome.get(_sem_acento(nome.split(" - ")[0]).upper())
        if cod is None:
            raise ValueError(f"Subdistrito do IBGE sem regional no de-para: {nome}")
        if t == str(config.IBGE_TAB_CENSO_2022):
            pop2022[cod] += int(v)
        elif t == str(config.IBGE_TAB_CENSO_2010):
            pop2010_subdistrito[cod] += int(v)
    pop2010 = dict(conn.execute("""SELECT cod_reg_limite, sum(populacao)::int FROM stg.trf_setor2010_regional
                                   GROUP BY 1""").fetchall())
    if sum(pop2022.values()) != censo2022:
        raise ValueError(f"Subdistritos 2022 somam {sum(pop2022.values())} != {censo2022}")
    if sum(pop2010.values()) != censo2010:
        raise ValueError(f"Setores 2010 somam {sum(pop2010.values())} != {censo2010}")
    s2010 = {k: v / censo2010 for k, v in pop2010.items()}
    s2022 = {k: v / censo2022 for k, v in pop2022.items()}
    for cod in sorted(s2022):
        log.info("  regional %d: 2010 setores %7d (%.4f) | 2010 subdistritos IBGE %7d | 2022 %7d (%.4f)",
                 cod, pop2010[cod], s2010[cod], pop2010_subdistrito[cod], pop2022[cod], s2022[cod])

    saida = []
    for ano in anos:
        total, origem_total = serie[ano]
        if ano == 2022:
            contagens, partes = dict(pop2022), s2022
            origem, metodo = "CENSO", "Censo 2022: subdistritos do IBGE agregados por regional (SIDRA 9923, N11)"
        elif ano == 2010:
            contagens, partes = dict(pop2010), s2010
            origem, metodo = "CENSO", "Censo 2010: setores censitários agregados aos limites 20220601 (PostGIS)"
        else:
            if ano >= 2020:
                partes = s2022
                metodo = "Participação do Censo 2022 (mesma lógica da Nota Técnica SUPTEC/SMSA nº 1/2026)"
            else:
                f = (ano - 2010) / 12
                partes = {k: s2010[k] + (s2022[k] - s2010[k]) * f for k in s2022}
                metodo = "Participação interpolada linearmente entre os Censos 2010 (setores) e 2022"
            contagens = maior_resto(total, partes)
            origem = ("INTERPOLADO x PROPORÇÃO" if origem_total.startswith("INTERPOLA")
                      else "ESTIMATIVA IBGE x PROPORÇÃO")
        for cod, pop in sorted(contagens.items()):
            saida.append([ano, cod, pop, round(pop / total, 10), total, origem, origem_total, metodo])
    conn.execute("TRUNCATE stg.trf_populacao")
    _copiar(conn, "stg.trf_populacao",
            ["ano", "cod_reg_limite", "populacao_residente", "participacao", "populacao_municipio",
             "origem_dado", "origem_total_municipio", "metodo_regional"], saida)
    log.info("População: %d linhas (regional x ano), anos %d–%d", len(saida), min(anos), max(anos))


# =============================================================================
# 4. Logradouros e locais (SCD Tipo 2)
# =============================================================================
RE_NAO_INFORMADO = re.compile(r"^(N.?O INFORMADO|NI|SEM NOME)?$")
RE_ARTIGO_INICIAL = re.compile(r"^(DO|DA|DOS|DAS|DE|D)\s+")
LIMIAR_SIMILARIDADE = 90


def carregar_abreviaturas() -> dict[str, str]:
    with open(config.DIR_MAPEAMENTOS / "abreviaturas_logradouro.csv", newline="", encoding="utf-8") as f:
        return {l["abreviatura"]: l["expansao"] for l in csv.DictReader(f, delimiter=";")}


def normalizar_nome(texto: str | None, abreviaturas: dict[str, str]) -> str:
    """Maiúsculas, sem acento, abreviaturas com ponto expandidas ("PROF." -> PROFESSOR),
    sem pontuação e espaços repetidos. Retorna '' para nomes não informados."""
    if not texto:
        return ""
    s = _sem_acento(texto.upper())
    s = re.sub(r"\b([A-Z]+)\.", lambda m: abreviaturas.get(m.group(1), m.group(1)) + " ", s)
    s = s.replace("'", "")
    s = re.sub(r"[^A-Z0-9 ]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return "" if RE_NAO_INFORMADO.match(s) else s


def chave_comparacao(nome: str) -> str:
    """Para comparar variações: sem artigo inicial e sem espaços ('DO CONTORNO' ~ 'CONTORNO')."""
    return RE_ARTIGO_INICIAL.sub("", nome).replace(" ", "")


def mesma_denominacao(a: str, b: str) -> bool:
    """Variação de grafia do mesmo nome? Similaridade >= 90 sem artigo inicial, ou um nome
    contém todas as palavras do outro ("CASTELO BRANCO" ~ "PRESIDENTE CASTELO BRANCO"),
    desde que o menor tenha ao menos 2 palavras (evita juntar nomes provisórios como "DOIS")."""
    ka, kb = chave_comparacao(a), chave_comparacao(b)
    if ka == kb or fuzz.ratio(ka, kb) >= LIMIAR_SIMILARIDADE:
        return True
    menor = min(RE_ARTIGO_INICIAL.sub("", a).split(), RE_ARTIGO_INICIAL.sub("", b).split(), key=len)
    return len(menor) >= 2 and fuzz.token_set_ratio(a, b) == 100


def agrupar_variantes(contagem: collections.Counter) -> dict[str, str]:
    """Agrupa grafias semelhantes do mesmo código: nome -> representante do grupo."""
    representantes: list[str] = []
    grupo = {}
    for nome, _ in contagem.most_common():
        for rep in representantes:
            if mesma_denominacao(nome, rep):
                grupo[nome] = rep
                break
        else:
            representantes.append(nome)
            grupo[nome] = nome
    return grupo


def versionar_logradouro(registros: list[tuple]) -> list[dict]:
    """registros: (data, tipo, nome_norm, nome_anterior_norm), ordenados por data.
    Uma nova versão começa quando o nome dominante (moda do ano) muda para um nome
    que ainda não foi usado; retorno a um nome antigo é tratado como ruído."""
    contagem = collections.Counter(r[2] for r in registros)
    grupo = agrupar_variantes(contagem)
    por_ano: dict[int, collections.Counter] = collections.defaultdict(collections.Counter)
    for d, _, nome, _ in registros:
        por_ano[d.year][grupo[nome]] += 1
    sequencia: list[tuple[str, int]] = []  # (grupo, primeiro ano dominante)
    for ano in sorted(por_ano):
        dominante = por_ano[ano].most_common(1)[0][0]
        if sequencia and sequencia[-1][0] == dominante:
            continue
        anteriores = [g for g, _ in sequencia]
        if dominante in anteriores:  # voltou a um nome anterior: descarta as versões intermediárias
            sequencia = sequencia[: anteriores.index(dominante) + 1]
        else:
            sequencia.append((dominante, ano))

    versoes = []
    for i, (g, ano_ini) in enumerate(sequencia):
        if i == 0:
            inicio = DATA_MIN
        else:  # primeiro registro do novo nome a partir do ano anterior (transição dentro do ano)
            inicio = min(d for d, _, nome, _ in registros if grupo[nome] == g and d.year >= ano_ini - 1)
            inicio = max(inicio, versoes[-1]["dt_inicio"] + timedelta(days=1))
        versoes.append({"grupo": g, "dt_inicio": inicio})
    for i, v in enumerate(versoes):
        v["dt_fim"] = versoes[i + 1]["dt_inicio"] if i + 1 < len(versoes) else DATA_MAX
        regs = [r for r in registros if v["dt_inicio"] <= r[0] < v["dt_fim"]]
        do_grupo = [r for r in regs if grupo[r[2]] == v["grupo"]] or [r for r in registros if grupo[r[2]] == v["grupo"]]
        v["nome"] = do_grupo[-1][2]                      # grafia mais recente do nome dominante
        v["tipo"] = collections.Counter(r[1] for r in do_grupo if r[1]).most_common(1)[0][0] if any(r[1] for r in do_grupo) else "NI"
        v["variantes"] = " | ".join(sorted({r[2] for r in regs if grupo[r[2]] == v["grupo"]}))
        v["qtd"] = len(regs)
        anteriores_fonte = collections.Counter(r[3] for r in regs if r[3])
        if i == 0:
            v["nome_anterior"] = anteriores_fonte.most_common(1)[0][0] if anteriores_fonte else None
            v["confirmada"] = False
        else:
            ant = versoes[i - 1]["nome"]
            v["nome_anterior"] = ant
            v["confirmada"] = any(mesma_denominacao(a, ant) for a in anteriores_fonte)
    return versoes


def _intervalos(vers_a: list[dict], vers_b: list[dict] | None):
    """Interseção das vigências de dois logradouros -> [(inicio, fim, va, vb)]."""
    pontos = sorted({v["dt_inicio"] for v in vers_a} | ({v["dt_inicio"] for v in vers_b} if vers_b else set()))
    pontos.append(DATA_MAX)
    saida = []
    for ini, fim in zip(pontos, pontos[1:]):
        va = next(v for v in vers_a if v["dt_inicio"] <= ini < v["dt_fim"])
        vb = next(v for v in vers_b if v["dt_inicio"] <= ini < v["dt_fim"]) if vers_b else None
        saida.append((ini, fim, va, vb))
    return saida


def transformar_locais(conn) -> None:
    abrev = carregar_abreviaturas()
    linhas = conn.execute(r"""
        WITH log AS (
            SELECT l.*, btrim(l.numero_boletim) AS nb,
                   CASE WHEN btrim(l.data_boletim) ~ '^\d{2}/\d{2}/\d{4} \d{2}:\d{2}'
                        THEN to_date(substr(btrim(l.data_boletim), 1, 10), 'DD/MM/YYYY')
                             + substr(btrim(l.data_boletim), 12, 5)::time END AS data_hora_log
            FROM stg.si_log l
            WHERE btrim(l.sequencia_logradouro) ~ '^\d+$'
        )
        SELECT b.numero_boletim_dw, b.ano, b.data, btrim(log.sequencia_logradouro)::int AS seq,
               CASE WHEN btrim(log.numero_logradouro) ~ '^\d+$' THEN btrim(log.numero_logradouro)::int ELSE 0 END,
               btrim(log.tipo_logradouro), log.nome_logradouro, log.nome_logradouro_anterior,
               CASE WHEN btrim(log.numero_bairro) ~ '^\d+$' THEN btrim(log.numero_bairro)::int ELSE 0 END,
               log.nome_bairro, btrim(log.numero_imovel), log.linha_arquivo
        FROM log
        JOIN stg.trf_boletim b
          ON b.numero_boletim_origem = log.nb AND b.ano = log.ano_arquivo
         AND (b.qtd_eventos_numero = 1 OR b.data_hora = log.data_hora_log)
        ORDER BY b.ano, b.numero_boletim_dw, seq, log.linha_arquivo""").fetchall()
    log.info("Logradouros: %d registros do si-log ligados a boletins", len(linhas))

    # registros por boletim (duplicatas exatas de sequência: fica a última linha)
    boletins: dict[tuple, dict[int, tuple]] = collections.defaultdict(dict)
    por_codigo: dict[int, list[tuple]] = collections.defaultdict(list)
    bairro_nome: dict[int, tuple[date, str]] = {}
    for nb, ano, data, seq, cod, tipo, nome, nome_ant, cod_bairro, nome_bairro, imovel, _ in linhas:
        nome_n, ant_n = normalizar_nome(nome, abrev), normalizar_nome(nome_ant, abrev)
        boletins[(nb, ano, data)][seq] = (cod, tipo, nome_n, cod_bairro, imovel)
        if cod > 0 and nome_n:
            por_codigo[cod].append((data, tipo if tipo and tipo != "NI" else "", nome_n, ant_n))
        bn = normalizar_nome(nome_bairro, abrev)
        if cod_bairro > 0 and bn and (cod_bairro not in bairro_nome or data >= bairro_nome[cod_bairro][0]):
            bairro_nome[cod_bairro] = (data, bn)

    # versões de cada logradouro -------------------------------------------------
    versoes: dict[int, list[dict]] = {}
    for cod, regs in por_codigo.items():
        regs.sort(key=lambda r: r[0])
        versoes[cod] = versionar_logradouro(regs)
    multiplas = {c: v for c, v in versoes.items() if len(v) > 1}
    log.info("Logradouros: %d códigos, %d com mais de uma versão (renomeação)", len(versoes), len(multiplas))

    # principal e cruzamento de cada boletim --------------------------------------
    locais_bol = []
    for (nb, ano, data), seqs in boletins.items():
        validos = [(s, r) for s, r in sorted(seqs.items()) if r[0] > 0 and r[0] in versoes]
        if not validos:
            continue
        principal = validos[0][1]
        cruz = next((r for _, r in validos[1:] if r[0] != principal[0]), None)
        locais_bol.append((nb, ano, data, principal, cruz))

    # modas para imputar bairro não informado
    moda_par = collections.defaultdict(collections.Counter)
    orientacao = collections.defaultdict(collections.Counter)
    moda_endereco = collections.defaultdict(collections.Counter)
    bairros_logradouro = collections.defaultdict(set)
    for _, _, _, p, c in locais_bol:
        if p[3] > 0:
            bairros_logradouro[p[0]].add(p[3])
            if c:
                moda_par[tuple(sorted((p[0], c[0])))][p[3]] += 1
            elif p[4] and p[4].isdigit() and int(p[4]) > 0:
                moda_endereco[(p[0], p[4])][p[3]] += 1
        if c:
            orientacao[tuple(sorted((p[0], c[0])))][p[0]] += 1

    saida_bl, chaves = [], {}
    contagem_origem = collections.Counter()
    for nb, ano, data, p, c in locais_bol:
        if c:
            par = tuple(sorted((p[0], c[0])))
            bairro = moda_par[par].most_common(1)[0][0] if moda_par[par] else 0
            origem = ("INFORMADO" if bairro and bairro == p[3] else
                      "IMPUTADO (moda do cruzamento)" if bairro else "NÃO INFORMADO")
            cod_p = orientacao[par].most_common(1)[0][0]
            cod_c = par[1] if cod_p == par[0] else par[0]
            chave = f"{par[0]}-{par[1]}-{bairro}"
        else:
            bairro, origem = p[3], "INFORMADO"
            if not bairro:
                end = moda_endereco.get((p[0], p[4])) if p[4] else None
                if end:
                    bairro, origem = end.most_common(1)[0][0], "IMPUTADO (mesmo endereço)"
                elif len(bairros_logradouro[p[0]]) == 1:
                    bairro, origem = next(iter(bairros_logradouro[p[0]])), "IMPUTADO (logradouro de bairro único)"
                else:
                    origem = "NÃO INFORMADO"
            cod_p, cod_c = p[0], 0
            chave = f"{p[0]}-0-{bairro}"
        contagem_origem[origem] += 1
        chaves[chave] = (cod_p, cod_c, bairro)
        saida_bl.append([nb, ano, data, chave, cod_p, cod_c, bairro, bool(c), origem, p[4] or None])
    log.info("Locais: %d boletins com local; origem do bairro: %s", len(saida_bl), dict(contagem_origem))

    # versões dos locais ------------------------------------------------------------
    def rotulo(tipo: str, nome: str) -> str:
        return f"{tipo} {nome}".strip() if tipo else nome

    saida_lv = []
    for chave, (cod_p, cod_c, bairro) in chaves.items():
        vp, vc = versoes[cod_p], (versoes[cod_c] if cod_c else None)
        nome_bairro = bairro_nome.get(bairro, (None, "NÃO INFORMADO"))[1] if bairro else "NÃO INFORMADO"
        atual_p, atual_c = vp[-1], (vc[-1] if vc else None)

        def descricao(a, b):
            if b:
                return f"{rotulo(a['tipo'], a['nome'])} x {rotulo(b['tipo'], b['nome'])}"
            return rotulo(a["tipo"], a["nome"]) + (f" ({nome_bairro})" if bairro else "")

        intervalos = _intervalos(vp, vc)
        for i, (ini, fim, va, vb) in enumerate(intervalos, start=1):
            if i == 1:
                motivo = "Versão inicial"
            else:
                _, _, pa, pb = intervalos[i - 2]
                mudancas = []
                for antes, depois in ((pa, va), (pb, vb)):
                    if antes is not None and antes is not depois:
                        mudancas.append(f"{rotulo(antes['tipo'], antes['nome'])} -> "
                                        f"{rotulo(depois['tipo'], depois['nome'])}"
                                        + (" (confirmada pelo nome anterior)" if depois["confirmada"] else ""))
                motivo = "Renomeação: " + "; ".join(mudancas)
            saida_lv.append([
                chave, i, ini, fim, i == len(intervalos),
                cod_p, va["tipo"] or "NI", va["nome"], va["nome_anterior"],
                cod_c, (vb["tipo"] or "NI") if vb else None, vb["nome"] if vb else None,
                vb["nome_anterior"] if vb else None,
                bairro, nome_bairro, bool(cod_c), descricao(va, vb), descricao(atual_p, atual_c), motivo])

    saida_lg = [[cod, i, v["dt_inicio"], v["dt_fim"], v["tipo"] or "NI", v["nome"], v["nome_anterior"],
                 v["confirmada"], v["variantes"], v["qtd"]]
                for cod, vs in versoes.items() for i, v in enumerate(vs, start=1)]

    conn.execute("TRUNCATE stg.trf_logradouro_versao, stg.trf_boletim_local, stg.trf_local_versao")
    _copiar(conn, "stg.trf_logradouro_versao",
            ["cod_logradouro", "versao", "dt_inicio", "dt_fim", "tipo_logradouro", "nome_logradouro",
             "nome_anterior", "fl_renomeacao_confirmada", "variantes", "qtd_registros"], saida_lg)
    _copiar(conn, "stg.trf_boletim_local",
            ["numero_boletim_dw", "ano", "data", "chave_local", "cod_logradouro_principal",
             "cod_logradouro_cruzamento", "cod_bairro", "fl_cruzamento", "origem_bairro", "numero_imovel"],
            saida_bl)
    _copiar(conn, "stg.trf_local_versao",
            ["chave_local", "versao", "dt_inicio", "dt_fim", "fl_versao_atual",
             "cod_logradouro_principal", "tipo_logradouro_principal", "nome_logradouro_principal",
             "nome_anterior_principal", "cod_logradouro_cruzamento", "tipo_logradouro_cruzamento",
             "nome_logradouro_cruzamento", "nome_anterior_cruzamento", "cod_bairro", "nome_bairro",
             "fl_cruzamento", "descricao_local", "descricao_local_atual", "motivo_versao"], saida_lv)
    n_versionados = len({l[0] for l in saida_lv if l[1] > 1})
    log.info("Locais: %d locais distintos, %d versões (%d locais com mais de uma versão)",
             len(chaves), len(saida_lv), n_versionados)


# =============================================================================
def executar(conn) -> None:
    etapas = [
        ("boletins (SQL 10)", lambda: _sql(conn, "10_trf_boletim.sql")),
        ("coordenadas (pyproj)", lambda: transformar_coordenadas(conn)),
        ("geolocalização (SQL 11)", lambda: _sql(conn, "11_trf_geolocalizacao.sql")),
        ("veículos (SQL 12)", lambda: _sql(conn, "12_trf_veiculo.sql")),
        ("envolvidos (SQL 13)", lambda: _sql(conn, "13_trf_envolvido.sql")),
        ("clima INMET (zoneinfo)", lambda: transformar_clima(conn)),
        ("clima do sinistro (SQL 15)", lambda: _sql(conn, "15_trf_clima.sql")),
        ("setores 2010 x regionais (SQL 14)", lambda: _sql(conn, "14_trf_setor2010_regional.sql")),
        ("população por regional", lambda: transformar_populacao(conn)),
        ("logradouros e locais (SCD2)", lambda: transformar_locais(conn)),
    ]
    for nome, funcao in etapas:
        log.info("-- transformar: %s", nome)
        funcao()
        conn.commit()


if __name__ == "__main__":
    configurar_log()
    with banco.conexao() as c:
        executar(c)
