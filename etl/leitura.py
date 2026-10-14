"""
Leitura dos arquivos da camada RAW (funções compartilhadas pelo staging e
pela inspeção das fontes).

Os CSVs da PBH são separados por ';', sem aspas, em Latin-1 — exceto o
si-veic-2023, gravado em CP850 (código de página do DOS). A codificação é
detectada arquivo a arquivo e registrada na evidência da inspeção.
"""
from __future__ import annotations

import csv
import io
import re
import unicodedata
from pathlib import Path

from etl import config

csv.field_size_limit(1 << 30)

# Sequências que só aparecem quando a decodificação está correta.
_MARCADORES_PT = ("ÃO", "ÇÃ", "Nº", "ÕE", "ÁR", "ÍC", "ÉR", "ÚB")


def detectar_codificacao(dados: bytes) -> str:
    """UTF-8 se for válido; senão escolhe entre Latin-1 e CP850 pelo texto em português."""
    try:
        dados.decode("utf-8")
        return "utf-8"
    except UnicodeDecodeError:
        pass

    def pontuar(cod: str) -> int:
        texto = dados.decode(cod)
        return sum(texto.count(m) for m in _MARCADORES_PT)

    return "cp850" if pontuar("cp850") > pontuar("latin-1") else "latin-1"


def normalizar_cabecalho(nome: str) -> str:
    """'  Nº_boletim' -> 'no_boletim'; 'data hora_boletim' -> 'data_hora_boletim'."""
    nome = nome.replace("º", "o").replace("°", "o").replace("ª", "a")
    nome = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode("ascii")
    nome = re.sub(r"\s+", "_", nome.strip().lower())
    return nome or "(vazio)"


def carregar_de_para() -> dict[tuple[str, str], str]:
    """(conjunto, cabeçalho normalizado) -> coluna do stg, lido de mapeamentos/de_para_cabecalhos.csv."""
    with open(config.DIR_MAPEAMENTOS / "de_para_cabecalhos.csv", newline="", encoding="utf-8") as f:
        return {(l["conjunto"], l["cabecalho_normalizado"]): l["coluna_stg"]
                for l in csv.DictReader(f, delimiter=";")}


def harmonizar_cabecalho(conjunto: str, cabecalho: list[str],
                         de_para: dict[tuple[str, str], str]) -> list[str]:
    """Traduz o cabeçalho original para as colunas do stg. Cabeçalho desconhecido = erro
    (o de-para deve ser atualizado após inspecionar o arquivo novo)."""
    saida = []
    for c in cabecalho:
        chave = (conjunto, normalizar_cabecalho(c))
        if chave not in de_para:
            raise KeyError(f"Cabeçalho sem de-para em {conjunto}: '{c}' (normalizado: '{chave[1]}'). "
                           "Atualize etl/mapeamentos/de_para_cabecalhos.csv")
        saida.append(de_para[chave])
    return saida


def ler_csv(caminho: Path, delimitador: str = ";", codificacao: str | None = None,
            pular_linhas: int = 0) -> tuple[list[str], list[list[str]], str]:
    """Lê um CSV inteiro: (cabeçalho original, linhas, codificação usada)."""
    dados = caminho.read_bytes()
    cod = codificacao or detectar_codificacao(dados)
    texto = dados.decode(cod)
    if texto.startswith("﻿"):
        texto = texto[1:]
    leitor = csv.reader(io.StringIO(texto, newline=""), delimiter=delimitador)
    for _ in range(pular_linhas):
        next(leitor)
    cabecalho = next(leitor)
    linhas = [l for l in leitor if any(c.strip() for c in l)]
    return cabecalho, linhas, cod


def arquivos_pbh(conjunto: str, anos: list[int] | None = None) -> list[tuple[int, Path]]:
    """(ano, caminho) dos arquivos de dados de um conjunto da PBH, a partir do manifesto."""
    import csv as _csv
    saida = []
    with open(config.ARQ_MANIFESTO, newline="", encoding="utf-8") as f:
        for l in _csv.DictReader(f):
            if l["fonte"] == "pbh_ckan" and l["conjunto"] == conjunto and l["ano"]:
                ano = int(l["ano"])
                if anos is None or ano in anos:
                    saida.append((ano, config.DIR_RAW / l["arquivo"]))
    return sorted(saida)


def arquivos_manifesto(fonte: str, conjunto: str | None = None) -> list[dict]:
    with open(config.ARQ_MANIFESTO, newline="", encoding="utf-8") as f:
        return [l for l in csv.DictReader(f)
                if l["fonte"] == fonte and (conjunto is None or l["conjunto"] == conjunto)]
