"""
Inspeção dos arquivos reais da camada RAW (base para os de-paras e regras).

Gera em evidencias/inspecao_fontes/:
  * arquivos.csv   — codificação detectada, nº de linhas e colunas por arquivo;
  * cabecalhos.csv — cabeçalho original x normalizado x coluna do stg, por ano;
  * dominios.csv   — valores distintos (com contagem por ano) das colunas codificadas.

Uso:  python -m etl.inspecionar_fontes
"""
from __future__ import annotations

import collections
import csv
import logging

from etl import config, leitura
from etl.util import configurar_log

log = logging.getLogger("inspecao")

DIR_SAIDA = config.DIR_EVIDENCIAS / "inspecao_fontes"

# Colunas codificadas (domínios) inspecionadas em cada conjunto
COLUNAS_DOMINIO = {
    "si_bol": ["tipo_acidente", "desc_tipo_acidente", "cod_tempo", "desc_tempo", "cod_pavimento",
               "pavimento", "cod_regional", "desc_regional", "origem_boletim", "local_sinalizado",
               "velocidade_permitida", "hora_informada", "indicador_fatalidade", "valor_ups",
               "descricao_ups", "valor_ups_antiga", "descricao_ups_antiga"],
    "si_log": ["numero_municipio", "nome_municipio", "sequencia_logradouro", "tipo_logradouro",
               "tipo_logradouro_anterior", "tipo_bairro", "descricao_tipo_bairro"],
    "si_veic": ["sequencial_veiculo", "codigo_categoria", "descricao_categoria", "codigo_especie",
                "descricao_especie", "codigo_situacao", "descricao_situacao", "tipo_socorro",
                "descricao_tipo_socorro"],
    "si_env": ["numero_envolvido", "condutor", "codigo_severidade", "desc_severidade", "sexo",
               "cinto_seguranca", "embriaguez", "categoria_habilitacao", "declaracao_obito",
               "cod_severidade_antiga", "especie_veiculo", "pedestre", "passageiro", "usa_capacete"],
}


def executar() -> None:
    DIR_SAIDA.mkdir(parents=True, exist_ok=True)
    de_para = leitura.carregar_de_para()
    arquivos, cabecalhos = [], []
    dominios: dict[tuple[str, str, str], collections.Counter] = collections.defaultdict(collections.Counter)

    for conjunto, colunas in COLUNAS_DOMINIO.items():
        for ano, caminho in leitura.arquivos_pbh(conjunto):
            cab, linhas, cod = leitura.ler_csv(caminho)
            cols = leitura.harmonizar_cabecalho(conjunto, cab, de_para)
            arquivos.append([conjunto, ano, caminho.name, cod, len(linhas), len(cab)])
            for i, (orig, stg) in enumerate(zip(cab, cols)):
                cabecalhos.append([conjunto, ano, caminho.name, i + 1, orig.strip(),
                                   leitura.normalizar_cabecalho(orig), stg])
            idx = {c: i for i, c in enumerate(cols)}
            for col in colunas:
                if col not in idx:
                    continue
                cont = collections.Counter(l[idx[col]].strip() for l in linhas)
                for valor, qtd in cont.items():
                    dominios[(conjunto, col, valor)][ano] += qtd
            log.info("%s %d: %d linhas, %s", conjunto, ano, len(linhas), cod)

    # INMET (8 linhas de metadados antes do cabeçalho)
    for l in leitura.arquivos_manifesto("inmet"):
        caminho = config.DIR_RAW / l["arquivo"]
        cab, linhas, cod = leitura.ler_csv(caminho, pular_linhas=8)
        cols = leitura.harmonizar_cabecalho("inmet", cab, de_para)
        arquivos.append(["inmet", l["ano"], caminho.name, cod, len(linhas), len(cab)])
        for i, (orig, stg) in enumerate(zip(cab, cols)):
            cabecalhos.append(["inmet", l["ano"], caminho.name, i + 1, orig.strip(),
                               leitura.normalizar_cabecalho(orig), stg])

    with open(DIR_SAIDA / "arquivos.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["conjunto", "ano", "arquivo", "codificacao_detectada", "linhas_dados", "colunas"])
        w.writerows(arquivos)
    with open(DIR_SAIDA / "cabecalhos.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["conjunto", "ano", "arquivo", "posicao", "cabecalho_original",
                    "cabecalho_normalizado", "coluna_stg"])
        w.writerows(cabecalhos)
    anos = sorted({a for c in dominios.values() for a in c})
    with open(DIR_SAIDA / "dominios.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["conjunto", "coluna_stg", "valor", "total"] + [str(a) for a in anos])
        for (conj, col, valor), cont in sorted(dominios.items()):
            w.writerow([conj, col, valor, sum(cont.values())] + [cont.get(a, 0) for a in anos])
    log.info("Inspeção gravada em %s", DIR_SAIDA)


if __name__ == "__main__":
    configurar_log()
    executar()
