"""
Etapa 1 — EXTRAIR.

Baixa as fontes para a camada RAW (dados/raw/<fonte>/) sem alterar o conteúdo
dos arquivos e registra cada um no dados/raw/manifesto.csv (fonte, conjunto,
recurso, ano, url, arquivo, sha256, bytes, data/hora da coleta...).

Fontes:
  * PBH/BHTrans (CKAN): si-bol, si-log, si-veic, si_env (+ dicionários) e os
    limites das regionais. Os recursos são descobertos pela API do CKAN
    (package_show), pois os nomes dos arquivos não seguem um padrão.
  * IBGE: localidades (distritos/subdistritos), estimativas anuais (SIDRA 6579),
    Censo 2010 (SIDRA 202) e Censo 2022 (SIDRA 9923), e os setores censitários
    de 2010 (malha + agregados) para levar a população de 2010 aos limites
    atuais das regionais.
  * INMET: ZIP anual com todas as estações automáticas; só os CSVs das
    estações de BH são guardados (o ZIP é apagado, mas URL e hash ficam no
    manifesto).

Não baixa de novo o que não mudou: compara a data de modificação informada
pelo portal (CKAN) e o hash do arquivo local com o manifesto.
Uso isolado:  python -m etl.extrair [--anos 2011-2024] [--forcar-download]
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import logging
import re
import shutil
import tempfile
import time
import zipfile
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote, urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from etl import config
from etl.util import configurar_log, interpretar_anos, sha256_arquivo

log = logging.getLogger("extrair")

CAMPOS_MANIFESTO = [
    "fonte", "conjunto", "recurso", "recurso_id", "ano", "url", "arquivo",
    "sha256", "bytes", "dt_coleta", "modificado_na_origem",
    "sha256_pacote", "bytes_pacote", "observacao",
]


# ---------------------------------------------------------------------------
# Manifesto
# ---------------------------------------------------------------------------
class Manifesto:
    """Manifesto da camada RAW: uma linha por arquivo guardado (chave = caminho relativo)."""

    def __init__(self, caminho: Path = config.ARQ_MANIFESTO):
        self.caminho = caminho
        self.linhas: dict[str, dict] = {}
        if caminho.exists():
            with open(caminho, newline="", encoding="utf-8") as f:
                for linha in csv.DictReader(f):
                    self.linhas[linha["arquivo"]] = linha

    def obter(self, arquivo_rel: str) -> dict | None:
        return self.linhas.get(arquivo_rel)

    def registrar(self, **campos) -> None:
        linha = {c: "" for c in CAMPOS_MANIFESTO}
        linha.update({k: ("" if v is None else str(v)) for k, v in campos.items()})
        self.linhas[linha["arquivo"]] = linha

    def salvar(self) -> None:
        self.caminho.parent.mkdir(parents=True, exist_ok=True)
        ordenadas = sorted(self.linhas.values(),
                           key=lambda l: (l["fonte"], l["conjunto"], l["ano"], l["arquivo"]))
        with open(self.caminho, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=CAMPOS_MANIFESTO)
            w.writeheader()
            w.writerows(ordenadas)


def _rel(caminho: Path) -> str:
    return caminho.relative_to(config.DIR_RAW).as_posix()


def _agora() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


# ---------------------------------------------------------------------------
# HTTP com retry (o servidor do INMET às vezes derruba a conexão)
# ---------------------------------------------------------------------------
def _criar_sessao() -> requests.Session:
    s = requests.Session()
    s.headers["User-Agent"] = config.USER_AGENT
    retry = Retry(total=5, backoff_factor=2, status_forcelist=(429, 500, 502, 503, 504),
                  allowed_methods=("GET", "HEAD"))
    s.mount("https://", HTTPAdapter(max_retries=retry))
    s.mount("http://", HTTPAdapter(max_retries=retry))
    return s


SESSAO = _criar_sessao()


def baixar(url: str, destino: Path, tentativas: int = 6) -> tuple[str, int]:
    """Baixa url -> destino (escrita atômica). Retorna (sha256, bytes)."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    parcial = destino.with_name(destino.name + ".parcial")
    for tentativa in range(1, tentativas + 1):
        try:
            with SESSAO.get(url, stream=True, timeout=(30, 300)) as r:
                r.raise_for_status()
                h, n = hashlib.sha256(), 0
                with open(parcial, "wb") as f:
                    for bloco in r.iter_content(1 << 20):
                        f.write(bloco)
                        h.update(bloco)
                        n += len(bloco)
                esperado = r.headers.get("content-length")
                if esperado and not r.headers.get("content-encoding") and int(esperado) != n:
                    raise IOError(f"download incompleto ({n} de {esperado} bytes)")
            parcial.replace(destino)
            return h.hexdigest(), n
        except (requests.RequestException, IOError) as e:
            espera = min(90, 5 * 2 ** (tentativa - 1))
            log.warning("Falha ao baixar %s (tentativa %d/%d): %s; nova tentativa em %ds",
                        url, tentativa, tentativas, e, espera)
            parcial.unlink(missing_ok=True)
            time.sleep(espera)
    raise RuntimeError(f"Não foi possível baixar {url} após {tentativas} tentativas")


def baixar_json(url: str, destino: Path, params: dict | None = None) -> tuple[str, int]:
    """Baixa uma resposta JSON de API e grava exatamente os bytes recebidos."""
    r = SESSAO.get(url, params=params, timeout=(30, 300))
    r.raise_for_status()
    r.json()  # garante que é JSON válido
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_bytes(r.content)
    return hashlib.sha256(r.content).hexdigest(), len(r.content)


def _arquivo_valido(linha: dict | None, caminho: Path) -> bool:
    """O arquivo existe e o hash confere com o manifesto?"""
    return bool(linha) and caminho.exists() and sha256_arquivo(caminho) == linha["sha256"]


# ---------------------------------------------------------------------------
# PBH / CKAN
# ---------------------------------------------------------------------------
RE_ANO_ARQUIVO = re.compile(r"si[-_ ]?(bol|log|veic|env)[-_ ]*(\d{4})", re.IGNORECASE)


def ckan_package_show(slug: str) -> tuple[str, dict]:
    erros = []
    for base in config.CKAN_BASES:
        try:
            r = SESSAO.get(f"{base}/api/3/action/package_show", params={"id": slug}, timeout=60)
            r.raise_for_status()
            j = r.json()
            if j.get("success"):
                return base, j["result"]
            erros.append(f"{base}: success=false")
        except (requests.RequestException, ValueError) as e:
            erros.append(f"{base}: {e}")
    raise RuntimeError(f"CKAN indisponível para '{slug}': {erros}")


def classificar_recurso(conjunto: str, rec: dict) -> tuple[str, int | None]:
    """Devolve (tipo, ano) do recurso: dados / dicionario / limite_9_regionais / limite_10_regionais."""
    nome_arq = unquote(Path(urlparse(rec["url"]).path).name)
    texto = f"{rec.get('name', '')} {nome_arq}".lower()
    if "dicion" in texto:
        return "dicionario", None
    if conjunto == "regional":
        desc = (rec.get("description") or "").lower()
        if "até janeiro de 2025" in desc or "ate janeiro de 2025" in desc:
            return "limite_9_regionais", None
        if "a partir de" in desc:
            return "limite_10_regionais", None
        return "outro", None
    m = RE_ANO_ARQUIVO.search(nome_arq) or RE_ANO_ARQUIVO.search(rec.get("name", ""))
    if m:
        return "dados", int(m.group(2))
    return "outro", None


def extrair_pbh(man: Manifesto, anos: list[int] | None, forcar: bool) -> None:
    for conjunto, slug in config.CONJUNTOS_PBH.items():
        base, pacote = ckan_package_show(slug)
        # metadados do dataset (evidência do que o portal listava na coleta)
        destino_meta = config.DIR_RAW / "pbh_ckan_metadados" / f"{slug}.json"
        destino_meta.parent.mkdir(parents=True, exist_ok=True)
        conteudo = json.dumps(pacote, ensure_ascii=False, indent=1).encode("utf-8")
        destino_meta.write_bytes(conteudo)
        man.registrar(fonte="pbh_ckan", conjunto="metadados", recurso=slug,
                      url=f"{base}/api/3/action/package_show?id={slug}", arquivo=_rel(destino_meta),
                      sha256=hashlib.sha256(conteudo).hexdigest(), bytes=len(conteudo),
                      dt_coleta=_agora(), modificado_na_origem=pacote.get("metadata_modified"),
                      observacao=f"licença: {pacote.get('license_title')}")
        log.info("CKAN %s (%s): %d recursos, licença %s", conjunto, base,
                 len(pacote["resources"]), pacote.get("license_title"))
        for rec in pacote["resources"]:
            tipo, ano = classificar_recurso(conjunto, rec)
            if tipo == "outro":
                log.warning("Recurso não classificado, ignorado: %s (%s)", rec.get("name"), rec["url"])
                continue
            if tipo == "dados" and anos and ano not in anos:
                continue
            nome_arq = unquote(Path(urlparse(rec["url"]).path).name)
            destino = config.DIR_RAW / f"pbh_{conjunto}" / nome_arq
            modificado = rec.get("last_modified") or rec.get("metadata_modified") or rec.get("created")
            anterior = man.obter(_rel(destino))
            if (not forcar and _arquivo_valido(anterior, destino)
                    and anterior["url"] == rec["url"]
                    and anterior["modificado_na_origem"] == (modificado or "")):
                log.info("  sem mudança, mantido: %s", nome_arq)
                continue
            sha, n = baixar(rec["url"], destino)
            man.registrar(fonte="pbh_ckan", conjunto=conjunto, recurso=rec.get("name", "").strip(),
                          recurso_id=rec.get("id"), ano=ano, url=rec["url"], arquivo=_rel(destino),
                          sha256=sha, bytes=n, dt_coleta=_agora(), modificado_na_origem=modificado,
                          observacao=f"tipo={tipo}; md5_portal={rec.get('hash') or ''}")
            log.info("  baixado: %s (%d bytes)", nome_arq, n)
        man.salvar()


# ---------------------------------------------------------------------------
# IBGE
# ---------------------------------------------------------------------------
def _consultas_ibge() -> list[tuple[str, str, str, dict | None, str]]:
    """(conjunto, nome do arquivo, url, params, descrição) das consultas às APIs do IBGE."""
    mun = config.IBGE_MUNICIPIO
    loc, agr = config.IBGE_API_LOCALIDADES, config.IBGE_API_AGREGADOS
    t_est, t10, t22 = config.IBGE_TAB_ESTIMATIVAS, config.IBGE_TAB_CENSO_2010, config.IBGE_TAB_CENSO_2022
    return [
        ("localidades", f"localidades_distritos_{mun}.json", f"{loc}/municipios/{mun}/distritos", None,
         "Distritos do município (API de localidades)"),
        ("localidades", f"localidades_subdistritos_{mun}.json", f"{loc}/municipios/{mun}/subdistritos", None,
         "Subdistritos do município (API de localidades)"),
        ("estimativas", f"sidra_{t_est}_metadados.json", f"{agr}/{t_est}/metadados", None,
         "Metadados da tabela de estimativas"),
        ("estimativas", f"sidra_{t_est}_estimativas_{mun}.json",
         f"{agr}/{t_est}/periodos/all/variaveis/9324", {"localidades": f"N6[{mun}]"},
         "População residente estimada (1º de julho)"),
        ("censo_2010", f"sidra_{t10}_metadados.json", f"{agr}/{t10}/metadados", None,
         "Metadados da tabela do Censo 2010"),
        ("censo_2010", f"sidra_{t10}_censo2010_municipio_{mun}.json",
         f"{agr}/{t10}/periodos/2010/variaveis/93", {"localidades": f"N6[{mun}]"},
         "População residente, Censo 2010, município"),
        ("censo_2010", f"sidra_{t10}_censo2010_subdistritos_{mun}.json",
         f"{agr}/{t10}/periodos/2010/variaveis/93", {"localidades": f"N11[N6[{mun}]]"},
         "População residente, Censo 2010, subdistritos"),
        ("censo_2022", f"sidra_{t22}_metadados.json", f"{agr}/{t22}/metadados", None,
         "Metadados da tabela do Censo 2022"),
        ("censo_2022", f"sidra_{t22}_censo2022_municipio_{mun}.json",
         f"{agr}/{t22}/periodos/2022/variaveis/93", {"localidades": f"N6[{mun}]"},
         "População residente, Censo 2022, município"),
        ("censo_2022", f"sidra_{t22}_censo2022_distritos_{mun}.json",
         f"{agr}/{t22}/periodos/2022/variaveis/93", {"localidades": f"N10[N6[{mun}]]"},
         "População residente, Censo 2022, distritos"),
        ("censo_2022", f"sidra_{t22}_censo2022_subdistritos_{mun}.json",
         f"{agr}/{t22}/periodos/2022/variaveis/93", {"localidades": f"N11[N6[{mun}]]"},
         "População residente, Censo 2022, subdistritos"),
    ]


def _extrair_membros_zip(url: str, conjunto: str, destino_dir: Path, filtro, man: Manifesto,
                         fonte: str, ano: int | None = None, rotulo: str = "") -> list[Path]:
    """Baixa um ZIP para a pasta temporária do sistema (fora do OneDrive), guarda só os
    membros aceitos por filtro(nome, zip) -> bool, registra URL/hash do ZIP e apaga o ZIP."""
    with tempfile.TemporaryDirectory(prefix="bi_bhtrans_") as tmp:
        zip_local = Path(tmp) / Path(urlparse(url).path).name
        sha_zip, n_zip = baixar(url, zip_local)
        guardados = []
        with zipfile.ZipFile(zip_local) as z:
            for info in z.infolist():
                if info.is_dir() or not filtro(info.filename, z):
                    continue
                destino = destino_dir / Path(info.filename).name
                destino.parent.mkdir(parents=True, exist_ok=True)
                with z.open(info) as origem, open(destino, "wb") as saida:
                    shutil.copyfileobj(origem, saida)
                man.registrar(fonte=fonte, conjunto=conjunto, recurso=rotulo or info.filename,
                              ano=ano, url=url, arquivo=_rel(destino), sha256=sha256_arquivo(destino),
                              bytes=destino.stat().st_size, dt_coleta=_agora(),
                              sha256_pacote=sha_zip, bytes_pacote=n_zip,
                              observacao=f"extraído de {zip_local.name} (membro '{info.filename}'); ZIP apagado")
                guardados.append(destino)
        log.info("  %s: %d arquivo(s) guardado(s) de %s (%d bytes)", conjunto, len(guardados), url, n_zip)
        return guardados


def extrair_ibge(man: Manifesto, forcar: bool) -> None:
    pasta = config.DIR_RAW / "ibge"
    for conjunto, nome, url, params, desc in _consultas_ibge():
        destino = pasta / nome
        if not forcar and _arquivo_valido(man.obter(_rel(destino)), destino):
            log.info("  IBGE sem nova coleta (já existe): %s", nome)
            continue
        sha, n = baixar_json(url, destino, params)
        url_completa = requests.Request("GET", url, params=params).prepare().url
        man.registrar(fonte="ibge", conjunto=conjunto, recurso=desc, url=url_completa,
                      arquivo=_rel(destino), sha256=sha, bytes=n, dt_coleta=_agora())
        log.info("  IBGE baixado: %s", nome)
    man.salvar()

    # Setores censitários de 2010 (malha e população por setor) -----------------
    pasta_setores = config.DIR_RAW / "ibge_setores_2010"
    ja_tem = [l for l in man.linhas.values() if l["fonte"] == "ibge_setores_2010"]
    if ja_tem and not forcar and all(_arquivo_valido(l, config.DIR_RAW / l["arquivo"]) for l in ja_tem):
        log.info("  IBGE setores 2010: já existem, mantidos")
        return
    # malha de setores de MG (shapefile completo: .shp/.shx/.dbf/.prj/.cpg)
    _extrair_membros_zip(config.IBGE_MALHA_SETORES_2010, "malha_setores_2010", pasta_setores / "malha",
                         lambda nome, z: True, man, "ibge_setores_2010", 2010,
                         "Malha de setores censitários 2010 - MG")
    # agregados por setor (o nome do ZIP traz a data de publicação: descobre pela listagem)
    listagem = SESSAO.get(config.IBGE_FTP_AGREGADOS_SETOR_2010, timeout=60).text
    nomes = sorted(set(re.findall(r'href="(MG_\d{8}\.zip)"', listagem)))
    if not nomes:
        raise RuntimeError("ZIP de agregados por setor de MG não encontrado no FTP do IBGE")
    url_ag = config.IBGE_FTP_AGREGADOS_SETOR_2010 + nomes[-1]
    _extrair_membros_zip(url_ag, "agregados_setores_2010", pasta_setores / "agregados",
                         lambda nome, z: Path(nome).name.lower() in ("basico_mg.csv", "domicilio02_mg.csv",
                                                                     "pessoa13_mg.csv"),
                         man, "ibge_setores_2010", 2010, "Agregados por setor 2010 - Básico MG")
    man.salvar()


# ---------------------------------------------------------------------------
# INMET
# ---------------------------------------------------------------------------
def _metadados_inmet(z: zipfile.ZipFile, nome: str) -> dict:
    """Lê as linhas de metadados (antes do cabeçalho) de um CSV do INMET."""
    meta = {}
    with z.open(nome) as f:
        for _ in range(10):
            linha = f.readline().decode("latin-1").strip()
            if ":" in linha and ";" in linha:
                chave, valor = linha.split(";", 1)
                meta[chave.strip().rstrip(":").upper()] = valor.strip().strip(";")
    return meta


def extrair_inmet(man: Manifesto, anos: list[int], forcar: bool) -> None:
    pasta = config.DIR_RAW / "inmet"
    for ano in anos:
        existentes = [l for l in man.linhas.values() if l["fonte"] == "inmet" and l["ano"] == str(ano)]
        if (existentes and not forcar
                and all(_arquivo_valido(l, config.DIR_RAW / l["arquivo"]) for l in existentes)):
            log.info("  INMET %d: já existe, mantido", ano)
            continue
        estacoes_vistas = {}

        def eh_estacao_bh(nome: str, z: zipfile.ZipFile) -> bool:
            if not nome.upper().endswith(".CSV"):
                return False
            meta = _metadados_inmet(z, nome)
            codigo = meta.get("CODIGO (WMO)", "")
            if "BELO HORIZONTE" in meta.get("ESTACAO", meta.get("ESTAÇÃO", "")).upper() \
                    or codigo in config.INMET_ESTACOES_BH:
                estacoes_vistas[codigo] = meta
                return codigo in config.INMET_ESTACOES_BH
            return False

        for l in existentes:  # refaz o ano inteiro
            man.linhas.pop(l["arquivo"], None)
        _extrair_membros_zip(config.INMET_URL_ZIP.format(ano=ano), "estacoes_automaticas_bh",
                             pasta / str(ano), eh_estacao_bh, man, "inmet", ano)
        log.info("  INMET %d: estações de BH encontradas: %s", ano,
                 {c: m.get("ESTACAO", m.get("ESTAÇÃO")) for c, m in estacoes_vistas.items()})
        man.salvar()


# ---------------------------------------------------------------------------
def executar(anos: list[int] | None = None, forcar: bool = False) -> None:
    man = Manifesto()
    log.info("== Extração PBH/CKAN ==")
    extrair_pbh(man, anos, forcar)
    anos_sinistros = sorted({int(l["ano"]) for l in man.linhas.values()
                             if l["fonte"] == "pbh_ckan" and l["conjunto"] == "si_bol" and l["ano"]})
    if anos:
        anos_sinistros = [a for a in anos_sinistros if a in anos]
    log.info("== Extração IBGE ==")
    extrair_ibge(man, forcar)
    log.info("== Extração INMET (anos %s) ==", anos_sinistros)
    extrair_inmet(man, anos_sinistros, forcar)
    man.salvar()
    log.info("Manifesto: %d arquivos em %s", len(man.linhas), config.ARQ_MANIFESTO)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Extrai as fontes para a camada RAW")
    p.add_argument("--anos", help="ex.: 2011-2024 ou 2019,2020")
    p.add_argument("--forcar-download", action="store_true")
    a = p.parse_args()
    configurar_log()
    executar(interpretar_anos(a.anos), a.forcar_download)
