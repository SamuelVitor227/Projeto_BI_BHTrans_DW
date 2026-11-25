"""Funções auxiliares compartilhadas pelas etapas do ETL."""
from __future__ import annotations

import hashlib
import logging
import sys
from pathlib import Path

FORMATO_LOG = "%(asctime)s %(levelname)-7s %(name)s: %(message)s"


def configurar_log(arquivo: Path | None = None, nivel: int = logging.INFO) -> None:
    """Log no console e, opcionalmente, num arquivo (UTF-8)."""
    manipuladores: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]
    if arquivo:
        arquivo.parent.mkdir(parents=True, exist_ok=True)
        manipuladores.append(logging.FileHandler(arquivo, mode="w", encoding="utf-8"))
    logging.basicConfig(level=nivel, format=FORMATO_LOG, datefmt="%H:%M:%S",
                        handlers=manipuladores, force=True)
    try:  # acentos no console do Windows
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def interpretar_anos(texto: str | None) -> list[int] | None:
    """Converte '2011-2024' ou '2019,2020,2023' em lista de anos; None = todos."""
    if not texto:
        return None
    anos: set[int] = set()
    for parte in texto.split(","):
        parte = parte.strip()
        if "-" in parte:
            ini, fim = (int(x) for x in parte.split("-"))
            anos.update(range(ini, fim + 1))
        elif parte:
            anos.add(int(parte))
    return sorted(anos)


def sha256_arquivo(caminho: Path) -> str:
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()
