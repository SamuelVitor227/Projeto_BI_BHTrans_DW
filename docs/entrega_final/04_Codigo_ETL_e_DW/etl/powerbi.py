"""
Arquivos de apoio ao Power BI (pasta powerbi/).

O conector PostgreSQL do Power BI não lê colunas geometry do PostGIS. Os pontos
(sinistros e locais) chegam ao Power BI como latitude/longitude pelas views do
schema bi; os polígonos das 9 regionais são exportados aqui em dois formatos:

  regionais_bh.geojson        camada de referência do visual Azure Maps
                              (RFC 7946: anel externo no sentido anti-horário)
  regionais_bh_topojson.json  mapa personalizado do visual "Mapa de formas"
                              (TopoJSON, anel externo no sentido horário, como o d3 espera)

Cada regional leva nome_regional, sigla e cod_regional, que casam com bi.dim_regional.
Os polígonos são simplificados com tolerância de ~1 m (diferença de área < 0,01%).

Uso:  python -m etl.powerbi
"""
from __future__ import annotations

import json
import logging

from etl import banco, config
from etl.util import configurar_log

log = logging.getLogger("powerbi")

DIR = config.RAIZ / "powerbi"
ARQ_GEOJSON = DIR / "regionais_bh.geojson"
ARQ_TOPOJSON = DIR / "regionais_bh_topojson.json"
TOLERANCIA_GRAUS = 0.00001   # ~1 m em Belo Horizonte
CASAS_DECIMAIS = 6           # ~0,1 m


def _regionais(conn, sentido: str) -> list[dict]:
    """Features GeoJSON das regionais; sentido 'CCW' (RFC 7946) ou 'CW' (d3/TopoJSON)."""
    forcar = {"CCW": "ST_ForcePolygonCCW", "CW": "ST_ForcePolygonCW"}[sentido]
    linhas = conn.execute(f"""
        SELECT cod_regional, nome_regional, sigla,
               ST_AsGeoJSON({forcar}(ST_Multi(ST_SimplifyPreserveTopology(geom, {TOLERANCIA_GRAUS}))), {CASAS_DECIMAIS})
        FROM dw.dim_regional
        WHERE sk_regional > 0
        ORDER BY cod_regional""").fetchall()
    # nome_regional primeiro: é a chave que o "Mapa de formas" casa com bi.dim_regional[nome_regional]
    return [{"type": "Feature",
             "properties": {"nome_regional": nome, "sigla": sigla, "cod_regional": cod},
             "geometry": json.loads(geo)}
            for cod, nome, sigla, geo in linhas]


def _topojson(features: list[dict]) -> dict:
    """Converte para TopoJSON sem quantização: cada anel vira um arco próprio
    (o formato permite não compartilhar as divisas entre regionais)."""
    arcos, geometrias = [], []
    for f in features:
        poligonos = []
        for poligono in f["geometry"]["coordinates"]:
            aneis = []
            for anel in poligono:
                aneis.append([len(arcos)])
                arcos.append(anel)
            poligonos.append(aneis)
        geometrias.append({"type": "MultiPolygon", "arcs": poligonos, "properties": f["properties"]})
    return {"type": "Topology",
            "objects": {"regionais": {"type": "GeometryCollection", "geometries": geometrias}},
            "arcs": arcos}


def _area_com_sinal(anel: list[list[float]]) -> float:
    """Fórmula do laço (x = longitude, y = latitude): positiva = anti-horário."""
    return sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(anel, anel[1:])) / 2


def _conferir(geo: dict, topo: dict) -> None:
    """Confere os arquivos antes de gravar: 9 regionais, anéis fechados e sentido certo."""
    assert len(geo["features"]) == 9, f"esperadas 9 regionais, vieram {len(geo['features'])}"
    for f in geo["features"]:
        for poligono in f["geometry"]["coordinates"]:
            assert all(anel[0] == anel[-1] for anel in poligono), "anel não fechado"
            assert _area_com_sinal(poligono[0]) > 0, f"{f['properties']['nome_regional']}: anel externo não está anti-horário"
    geometrias = topo["objects"]["regionais"]["geometries"]
    assert len(geometrias) == 9
    for g in geometrias:
        for poligono in g["arcs"]:
            assert _area_com_sinal(topo["arcs"][poligono[0][0]]) < 0, \
                f"{g['properties']['nome_regional']}: anel externo do TopoJSON não está horário"


def exportar(conn) -> None:
    DIR.mkdir(exist_ok=True)
    geo = {"type": "FeatureCollection", "features": _regionais(conn, "CCW")}
    topo = _topojson(_regionais(conn, "CW"))
    _conferir(geo, topo)
    ARQ_GEOJSON.write_text(json.dumps(geo, ensure_ascii=False), encoding="utf-8")
    ARQ_TOPOJSON.write_text(json.dumps(topo, ensure_ascii=False), encoding="utf-8")
    log.info("Power BI: %s (%d kB) e %s (%d kB) com %d regionais", ARQ_GEOJSON.name,
             ARQ_GEOJSON.stat().st_size // 1024, ARQ_TOPOJSON.name, ARQ_TOPOJSON.stat().st_size // 1024,
             len(geo["features"]))


if __name__ == "__main__":
    configurar_log()
    with banco.conexao() as c:
        exportar(c)
