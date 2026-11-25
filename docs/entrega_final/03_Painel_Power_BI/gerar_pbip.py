"""Gera o projeto Power BI (formato PBIP: modelo em TMDL + relatório em PBIR) do DW de sinistros de BH.

Uso:  python powerbi/gerar_pbip.py
Saída: powerbi/Painel_Sinistros_BH.pbip  (+ .SemanticModel/ e .Report/)

O modelo importa as views do schema `bi` do PostgreSQL (parâmetros Servidor e BancoDeDados) e
traz as 34 medidas de powerbi/medidas.dax mais as medidas de KPI e narrativa usadas no relatório.
O relatório tem 4 páginas em sequência de storytelling (Estratégico → Gerencial → Operacional).

Depois de gerar, abra o .pbip no Power BI Desktop e clique em Atualizar (credenciais do .env).
Se o relatório for editado e salvo no Desktop, NÃO rode este script de novo sem antes trazer as
alterações para cá, porque ele reescreve as pastas .SemanticModel e .Report.
"""
from __future__ import annotations

import json
import shutil
import uuid
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
NOME = "Painel_Sinistros_BH"
SM = RAIZ / f"{NOME}.SemanticModel"
RP = RAIZ / f"{NOME}.Report"
PBI_BASE_THEMES = Path(r"C:\Program Files\Microsoft Power BI Desktop\bin\WebView2Resources\minerva\sharedresources\BaseThemes")
BASE_THEME = "CY26SU11"

NS = uuid.UUID("6f1d7c1e-3c55-4b8e-9a43-0b6d2a1f9e10")


def tag(*partes: str) -> str:
    """lineageTag estável (o mesmo objeto recebe o mesmo id a cada geração)."""
    return str(uuid.uuid5(NS, "/".join(partes)))


def nome_tmdl(n: str) -> str:
    return n if n.replace("_", "").isalnum() and n.isascii() else "'" + n.replace("'", "''") + "'"


# =============================================================================================
# 1. MODELO SEMÂNTICO
# =============================================================================================
# tipo: int | text | date | bool | double
M_TIPO = {"int": "Int64.Type", "text": "type text", "date": "type date", "bool": "type logical", "double": "type number"}
TMDL_TIPO = {"int": "int64", "text": "string", "date": "dateTime", "bool": "boolean", "double": "double"}

# coluna: (nome, tipo, opções)  opções: hidden, sort=<col>, key, cat=<Latitude|Longitude>, fmt=<...>, summ=<...>
TABELAS: dict[str, dict] = {
    "dim_calendario": {
        "desc": "Calendário diário dos anos com sinistros carregados (marcado como tabela de datas).",
        "filtrar_anos": True, "data_table": True,
        "cols": [
            ("data", "date", {"key": True, "fmt": "dd/MM/yyyy"}),
            ("ano", "int", {"fmt": "0"}),
            ("trimestre", "int", {"fmt": "0"}),
            ("mes", "int", {"fmt": "0", "hidden": True}),
            ("nome_mes", "text", {"sort": "mes"}),
            ("nome_mes_abrev", "text", {"sort": "mes"}),
            ("ano_mes", "text", {"sort": "ano_mes_ordem"}),
            ("ano_mes_ordem", "int", {"hidden": True}),
            ("dia_semana", "int", {"hidden": True}),
            ("nome_dia_semana", "text", {"sort": "dia_semana"}),
            ("nome_dia_semana_abrev", "text", {"sort": "dia_semana"}),
            ("fl_fim_de_semana", "bool", {"hidden": True}),
        ],
        "calc_cols": [
            ("tipo_dia", "text", "IF ( 'dim_calendario'[fl_fim_de_semana], \"Fim de semana\", \"Dia útil\" )",
             "Dia útil ou fim de semana."),
            ("periodo_analise", "text",
             "VAR ultimo = MAX ( 'dim_calendario'[ano] )\nRETURN IF ( 'dim_calendario'[ano] >= ultimo - 2, \"Últimos 3 anos\", \"Anos anteriores\" )",
             "Últimos 3 anos carregados × anos anteriores (acompanha a chegada de novos anos)."),
        ],
    },
    "dim_hora": {
        "desc": "Hora do sinistro (0–23; 99 = não informada).",
        "cols": [
            ("hora", "int", {"fmt": "0"}),
            ("hora_texto", "text", {"sort": "hora"}),
            ("faixa_horaria", "text", {}),
            ("periodo_dia", "text", {"sort": "ordem_periodo_dia"}),
            ("ordem_periodo_dia", "int", {"hidden": True}),
            ("fl_hora_informada", "bool", {}),
        ],
    },
    "dim_local": {
        "desc": "Local do sinistro (logradouro, cruzamento e bairro), SCD Tipo 2; descricao_local_atual usa o nome vigente.",
        "cols": [
            ("sk_local", "int", {"hidden": True}),
            ("descricao_local_atual", "text", {}),
            ("nome_logradouro_principal_atual", "text", {}),
            ("nome_bairro", "text", {}),
            ("fl_cruzamento", "bool", {}),
            ("latitude", "double", {"cat": "Latitude", "summ": "average"}),
            ("longitude", "double", {"cat": "Longitude", "summ": "average"}),
            ("fl_versao_atual", "bool", {}),
        ],
    },
    "dim_regional": {
        "desc": "Regionais administrativas de BH (limites vigentes até jan/2025).",
        "cols": [
            ("sk_regional", "int", {"hidden": True}),
            ("cod_regional", "int", {"fmt": "0"}),
            ("nome_regional", "text", {}),
            ("sigla", "text", {}),
            ("area_km2", "double", {"fmt": "0.00"}),
            ("latitude", "double", {"cat": "Latitude", "summ": "average"}),
            ("longitude", "double", {"cat": "Longitude", "summ": "average"}),
        ],
    },
    "dim_tipo_sinistro": {
        "desc": "Tipo de sinistro e grupo (colisão, atropelamento, choque etc.).",
        "cols": [
            ("sk_tipo_sinistro", "int", {"hidden": True}),
            ("descricao", "text", {"sort": "ordem"}),
            ("grupo_tipo_sinistro", "text", {}),
            ("ordem", "int", {"hidden": True}),
        ],
    },
    "dim_condicao_via": {
        "desc": "Condição da via: clima (declarado ou imputado pelo INMET), pavimento e sinalização.",
        "cols": [
            ("sk_condicao_via", "int", {"hidden": True}),
            ("condicao_climatica", "text", {}),
            ("origem_clima", "text", {}),
            ("grupo_chuva", "text", {}),
            ("pavimento", "text", {}),
        ],
    },
    "dim_veiculo": {
        "desc": "Perfil do veículo da pessoa envolvida.",
        "cols": [
            ("sk_veiculo", "int", {"hidden": True}),
            ("especie", "text", {}),
            ("grupo_especie", "text", {}),
            ("categoria", "text", {}),
            ("situacao", "text", {}),
        ],
    },
    "dim_pessoa": {
        "desc": "Perfil da pessoa envolvida.",
        "cols": [
            ("sk_pessoa", "int", {"hidden": True}),
            ("tipo_envolvimento", "text", {}),
            ("sexo", "text", {}),
            ("faixa_etaria", "text", {"sort": "ordem_faixa_etaria"}),
            ("ordem_faixa_etaria", "int", {"hidden": True}),
            ("embriaguez", "text", {}),
        ],
    },
    "fato_sinistro": {
        "desc": "Fato sinistro: uma linha por boletim de ocorrência.",
        "cols": [
            ("ano", "int", {"hidden": True}),
            ("data", "date", {"hidden": True, "fmt": "dd/MM/yyyy"}),
            ("hora", "int", {"hidden": True}),
            ("sk_local", "int", {"hidden": True}),
            ("sk_tipo_sinistro", "int", {"hidden": True}),
            ("sk_condicao_via", "int", {"hidden": True}),
            ("sk_regional", "int", {"hidden": True}),
            ("qtd_envolvidos", "int", {"summ": "sum"}),
            ("qtd_vitimas", "int", {"summ": "sum"}),
            ("qtd_vitimas_fatais", "int", {"summ": "sum"}),
            ("qtd_veiculos", "int", {"summ": "sum"}),
            ("qtd_motocicletas", "int", {"summ": "sum"}),
            ("qtd_automoveis", "int", {"summ": "sum"}),
            ("qtd_onibus", "int", {"summ": "sum"}),
            ("qtd_caminhoes", "int", {"summ": "sum"}),
            ("qtd_bicicletas", "int", {"summ": "sum"}),
            ("qtd_outros_veiculos", "int", {"summ": "sum"}),
            ("valor_ups", "int", {"summ": "sum"}),
            ("velocidade_permitida", "int", {}),
            ("precipitacao_mm", "double", {"fmt": "0.0"}),
            ("fl_fatal", "bool", {}),
            ("fl_envolve_pedestre", "bool", {}),
            ("fl_envolve_motociclista", "bool", {}),
            ("fl_geolocalizado", "bool", {}),
            ("latitude", "double", {"cat": "Latitude", "summ": "average"}),
            ("longitude", "double", {"cat": "Longitude", "summ": "average"}),
        ],
    },
    "fato_envolvido": {
        "desc": "Fato envolvido: uma linha por pessoa envolvida no sinistro.",
        "cols": [
            ("ano", "int", {"hidden": True}),
            ("data", "date", {"hidden": True, "fmt": "dd/MM/yyyy"}),
            ("hora", "int", {"hidden": True}),
            ("sk_local", "int", {"hidden": True}),
            ("sk_pessoa", "int", {"hidden": True}),
            ("sk_veiculo", "int", {"hidden": True}),
            ("sk_regional", "int", {"hidden": True}),
            ("sk_tipo_sinistro", "int", {"hidden": True}),
            ("sk_condicao_via", "int", {"hidden": True}),
            ("idade", "int", {"summ": "average"}),
            ("gravidade", "text", {}),
            ("fl_vitima", "bool", {}),
            ("fl_vitima_fatal", "bool", {}),
            ("fl_pedestre", "bool", {}),
            ("fl_motociclista", "bool", {}),
            ("fl_condutor", "bool", {}),
        ],
        "calc_cols": [
            ("usuario_via", "text",
             "VAR especie = RELATED ( 'dim_veiculo'[grupo_especie] )\n"
             "RETURN\n"
             "    SWITCH (\n"
             "        TRUE (),\n"
             "        'fato_envolvido'[fl_pedestre], \"Pedestre\",\n"
             "        'fato_envolvido'[fl_motociclista] || especie = \"Motocicleta\", \"Motociclista\",\n"
             "        especie = \"Bicicleta\", \"Ciclista\",\n"
             "        especie = \"Automóvel/utilitário\", \"Ocupante de automóvel\",\n"
             "        especie = \"Ônibus\", \"Ocupante de ônibus\",\n"
             "        especie = \"Caminhão\", \"Ocupante de caminhão\",\n"
             "        \"Outro / não identificado\"\n"
             "    )",
             "Usuário da via derivado do tipo de envolvimento e da espécie do veículo."),
        ],
    },
    "fato_populacao": {
        "desc": "População residente por regional e ano (IBGE, 1º de julho).",
        "filtrar_anos": True,
        "cols": [
            ("sk_regional", "int", {"hidden": True}),
            ("ano", "int", {"hidden": True}),
            ("data", "date", {"hidden": True, "fmt": "dd/MM/yyyy"}),
            ("populacao_residente", "int", {"summ": "sum", "fmt": "#,0"}),
            ("origem_dado", "text", {}),
        ],
    },
}

RELACOES = [
    ("fato_sinistro", "data", "dim_calendario", "data"),
    ("fato_sinistro", "hora", "dim_hora", "hora"),
    ("fato_sinistro", "sk_local", "dim_local", "sk_local"),
    ("fato_sinistro", "sk_tipo_sinistro", "dim_tipo_sinistro", "sk_tipo_sinistro"),
    ("fato_sinistro", "sk_condicao_via", "dim_condicao_via", "sk_condicao_via"),
    ("fato_sinistro", "sk_regional", "dim_regional", "sk_regional"),
    ("fato_envolvido", "data", "dim_calendario", "data"),
    ("fato_envolvido", "hora", "dim_hora", "hora"),
    ("fato_envolvido", "sk_local", "dim_local", "sk_local"),
    ("fato_envolvido", "sk_tipo_sinistro", "dim_tipo_sinistro", "sk_tipo_sinistro"),
    ("fato_envolvido", "sk_condicao_via", "dim_condicao_via", "sk_condicao_via"),
    ("fato_envolvido", "sk_pessoa", "dim_pessoa", "sk_pessoa"),
    ("fato_envolvido", "sk_veiculo", "dim_veiculo", "sk_veiculo"),
    ("fato_envolvido", "sk_regional", "dim_regional", "sk_regional"),
    ("fato_populacao", "data", "dim_calendario", "data"),
    ("fato_populacao", "sk_regional", "dim_regional", "sk_regional"),
]

INT, DEC2, DEC1, PCT = "#,0", "0.00", "0.0", "0.0%"

# (tabela, nome, formato, pasta, DAX, descrição)
MEDIDAS = [
    # ---- sinistros
    ("fato_sinistro", "Sinistros", INT, "Sinistros", "COUNTROWS ( 'fato_sinistro' )", "Número de sinistros com vítima (boletins)."),
    ("fato_sinistro", "Sinistros fatais", INT, "Sinistros", "CALCULATE ( [Sinistros], 'fato_sinistro'[fl_fatal] = TRUE () )", "Sinistros com ao menos uma vítima fatal."),
    ("fato_sinistro", "Sinistros com pedestre", INT, "Sinistros", "CALCULATE ( [Sinistros], 'fato_sinistro'[fl_envolve_pedestre] = TRUE () )", ""),
    ("fato_sinistro", "Sinistros com motocicleta", INT, "Sinistros", "CALCULATE ( [Sinistros], 'fato_sinistro'[fl_envolve_motociclista] = TRUE () )", ""),
    ("fato_sinistro", "Vítimas", INT, "Sinistros", "SUM ( 'fato_sinistro'[qtd_vitimas] )", "Vítimas (feridos e mortos) contadas no boletim."),
    ("fato_sinistro", "Mortos", INT, "Sinistros", "SUM ( 'fato_sinistro'[qtd_vitimas_fatais] )", "Vítimas fatais registradas nos boletins."),
    ("fato_sinistro", "Veículos", INT, "Sinistros", "SUM ( 'fato_sinistro'[qtd_veiculos] )", ""),
    ("fato_sinistro", "UPS", INT, "Severidade", "SUM ( 'fato_sinistro'[valor_ups] )", "Unidade Padrão de Severidade (1, 5 ou 13 por sinistro)."),
    ("fato_sinistro", "UPS média por sinistro", DEC2, "Severidade", "DIVIDE ( [UPS], [Sinistros] )", ""),
    ("fato_sinistro", "Mortos por 1.000 sinistros", DEC1, "Severidade", "DIVIDE ( [Mortos], [Sinistros] ) * 1000", "Letalidade: mortos a cada mil sinistros."),
    ("fato_sinistro", "% sinistros geolocalizados", PCT, "Sinistros", "DIVIDE ( CALCULATE ( [Sinistros], 'fato_sinistro'[fl_geolocalizado] = TRUE () ), [Sinistros] )", ""),
    ("fato_sinistro", "Sinistros (ano anterior)", INT, "Tendência", "CALCULATE ( [Sinistros], SAMEPERIODLASTYEAR ( 'dim_calendario'[data] ) )", ""),
    ("fato_sinistro", "Var. % sinistros vs ano anterior", PCT, "Tendência", "DIVIDE ( [Sinistros] - [Sinistros (ano anterior)], [Sinistros (ano anterior)] )", ""),
    ("fato_sinistro", "Mortos (ano anterior)", INT, "Tendência", "CALCULATE ( [Mortos], SAMEPERIODLASTYEAR ( 'dim_calendario'[data] ) )", ""),
    ("fato_sinistro", "Var. % mortos vs ano anterior", PCT, "Tendência", "DIVIDE ( [Mortos] - [Mortos (ano anterior)], [Mortos (ano anterior)] )", ""),
    ("fato_sinistro", "Motocicletas", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_motocicletas] )", ""),
    ("fato_sinistro", "Automóveis", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_automoveis] )", ""),
    ("fato_sinistro", "Ônibus", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_onibus] )", ""),
    ("fato_sinistro", "Caminhões", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_caminhoes] )", ""),
    ("fato_sinistro", "Bicicletas", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_bicicletas] )", ""),
    ("fato_sinistro", "Outros veículos", INT, "Veículos por espécie", "SUM ( 'fato_sinistro'[qtd_outros_veiculos] )", ""),
    # ---- pessoas
    ("fato_envolvido", "Envolvidos", INT, "Pessoas", "COUNTROWS ( 'fato_envolvido' )", ""),
    ("fato_envolvido", "Vítimas (pessoas)", INT, "Pessoas", "CALCULATE ( [Envolvidos], 'fato_envolvido'[fl_vitima] = TRUE () )", "Use com dim_pessoa e dim_veiculo."),
    ("fato_envolvido", "Mortos (pessoas)", INT, "Pessoas", "CALCULATE ( [Envolvidos], 'fato_envolvido'[fl_vitima_fatal] = TRUE () )", "Use com dim_pessoa e dim_veiculo."),
    ("fato_envolvido", "Vítimas pedestres", INT, "Pessoas", "CALCULATE ( [Vítimas (pessoas)], 'fato_envolvido'[fl_pedestre] = TRUE () )", ""),
    ("fato_envolvido", "Vítimas motociclistas", INT, "Pessoas", "CALCULATE ( [Vítimas (pessoas)], 'fato_envolvido'[fl_motociclista] = TRUE () )", ""),
    ("fato_envolvido", "% vítimas pedestres", PCT, "Pessoas", "DIVIDE ( [Vítimas pedestres], [Vítimas (pessoas)] )", ""),
    ("fato_envolvido", "% vítimas motociclistas", PCT, "Pessoas", "DIVIDE ( [Vítimas motociclistas], [Vítimas (pessoas)] )", ""),
    ("fato_envolvido", "Mortos pedestres", INT, "Pessoas", "CALCULATE ( [Mortos (pessoas)], 'fato_envolvido'[fl_pedestre] = TRUE () )", ""),
    ("fato_envolvido", "Mortos motociclistas", INT, "Pessoas", "CALCULATE ( [Mortos (pessoas)], 'fato_envolvido'[fl_motociclista] = TRUE () )", ""),
    ("fato_envolvido", "% mortos pedestres", PCT, "Pessoas", "DIVIDE ( [Mortos pedestres], [Mortos (pessoas)] )", ""),
    ("fato_envolvido", "% mortos motociclistas", PCT, "Pessoas", "DIVIDE ( [Mortos motociclistas], [Mortos (pessoas)] )", ""),
    ("fato_envolvido", "Idade média", DEC1, "Pessoas", "AVERAGE ( 'fato_envolvido'[idade] )", ""),
    # ---- população, taxas e meta
    ("fato_populacao", "População", INT, "Taxas e meta",
     "VAR anos_com_dados = ALL ( 'fato_sinistro'[ano] )\nRETURN\n    CALCULATE (\n        SUM ( 'fato_populacao'[populacao_residente] ),\n"
     "        REMOVEFILTERS ( 'dim_calendario' ),\n        INTERSECT ( VALUES ( 'dim_calendario'[ano] ), anos_com_dados )\n    )",
     "População residente dos anos visíveis que têm sinistros carregados."),
    ("fato_populacao", "Taxa de mortos por 100 mil hab.", DEC2, "Taxas e meta", "DIVIDE ( [Mortos], [População] ) * 100000", "Indicador oficial da política municipal."),
    ("fato_populacao", "Taxa de vítimas por 100 mil hab.", DEC1, "Taxas e meta", "DIVIDE ( [Vítimas], [População] ) * 100000", ""),
    ("fato_populacao", "Taxa de sinistros por 100 mil hab.", DEC1, "Taxas e meta", "DIVIDE ( [Sinistros], [População] ) * 100000", ""),
    ("fato_populacao", "Taxa base 2014", DEC2, "Taxas e meta",
     "CALCULATE (\n    [Taxa de mortos por 100 mil hab.],\n    REMOVEFILTERS ( 'dim_calendario' ),\n    'dim_calendario'[ano] = 2014\n)", "Taxa de mortos de 2014, base da meta."),
    ("fato_populacao", "Meta 2030", DEC2, "Taxas e meta", "[Taxa base 2014] * 0.5", "Meta: metade da taxa de 2014 até 2030."),
    ("fato_populacao", "Distância para a meta", DEC2, "Taxas e meta",
     "VAR taxa = [Taxa de mortos por 100 mil hab.]\nRETURN IF ( NOT ISBLANK ( taxa ), taxa - [Meta 2030] )", ""),
    ("fato_populacao", "% redução vs 2014", PCT, "Taxas e meta",
     "VAR taxa = [Taxa de mortos por 100 mil hab.]\nRETURN IF ( NOT ISBLANK ( taxa ), DIVIDE ( [Taxa base 2014] - taxa, [Taxa base 2014] ) )", ""),
    # ---- KPIs do último ano (cartões) e narrativa
    ("fato_populacao", "Ano de referência", "0", "KPI", "MAX ( 'dim_calendario'[ano] )", "Último ano visível no filtro."),
    ("fato_populacao", "Taxa no último ano", DEC2, "KPI",
     "VAR ano_ref = [Ano de referência]\nRETURN CALCULATE ( [Taxa de mortos por 100 mil hab.], REMOVEFILTERS ( 'dim_calendario' ), 'dim_calendario'[ano] = ano_ref )", ""),
    ("fato_populacao", "Mortos no último ano", INT, "KPI",
     "VAR ano_ref = [Ano de referência]\nRETURN CALCULATE ( [Mortos], REMOVEFILTERS ( 'dim_calendario' ), 'dim_calendario'[ano] = ano_ref )", ""),
    ("fato_populacao", "Redução da taxa vs 2014", PCT, "KPI",
     "VAR taxa = [Taxa no último ano]\nRETURN IF ( NOT ISBLANK ( taxa ), DIVIDE ( [Taxa base 2014] - taxa, [Taxa base 2014] ) )",
     "Quanto a taxa do último ano caiu em relação a 2014 (meta: 50%)."),
    ("fato_populacao", "Queda ainda necessária", PCT, "KPI",
     "VAR taxa = [Taxa no último ano]\nRETURN IF ( NOT ISBLANK ( taxa ), MAX ( 0, 1 - DIVIDE ( [Meta 2030], taxa ) ) )",
     "Quanto a taxa do último ano ainda precisa cair para atingir a meta de 2030."),
    ("fato_populacao", "Motociclistas nas vítimas (último ano)", PCT, "KPI",
     "VAR ano_ref = [Ano de referência]\nRETURN CALCULATE ( [% vítimas motociclistas], REMOVEFILTERS ( 'dim_calendario' ), 'dim_calendario'[ano] = ano_ref )", ""),
    ("fato_populacao", "Taxa no último triênio", DEC2, "KPI",
     "VAR ano_ref = [Ano de referência]\nRETURN\n    CALCULATE (\n        [Taxa de mortos por 100 mil hab.],\n"
     "        REMOVEFILTERS ( 'dim_calendario' ),\n        'dim_calendario'[ano] >= ano_ref - 2 && 'dim_calendario'[ano] <= ano_ref\n    )",
     "Taxa média anual de mortos por 100 mil hab. nos três últimos anos visíveis."),
    ("fato_populacao", "Cor destaque regional", None, "KPI",
     "VAR taxa = [Taxa no último triênio]\nVAR maior =\n    MAXX ( ALLSELECTED ( 'dim_regional'[nome_regional] ), [Taxa no último triênio] )\n"
     "RETURN IF ( taxa = maior, \"#B03A2E\", \"#8EA9DB\" )", "Vermelho para a regional de maior taxa no último triênio."),
    ("fato_populacao", "Título regional", None, "KPI",
     "VAR ano_ref = [Ano de referência]\nRETURN \"Risco por regional no último triênio (\" & ano_ref - 2 & \"–\" & ano_ref & \")\"", ""),
    ("fato_sinistro", "Sinistros/ano no primeiro triênio", DEC1, "Tendência",
     "VAR a0 = CALCULATE ( MIN ( 'fato_sinistro'[ano] ), REMOVEFILTERS ( 'dim_calendario' ) )\n"
     "RETURN DIVIDE ( CALCULATE ( [Sinistros], REMOVEFILTERS ( 'dim_calendario' ), 'dim_calendario'[ano] >= a0 && 'dim_calendario'[ano] <= a0 + 2 ), 3 )", ""),
    ("fato_sinistro", "Sinistros/ano no último triênio", DEC1, "Tendência",
     "VAR a1 = CALCULATE ( MAX ( 'fato_sinistro'[ano] ), REMOVEFILTERS ( 'dim_calendario' ) )\n"
     "RETURN DIVIDE ( CALCULATE ( [Sinistros], REMOVEFILTERS ( 'dim_calendario' ), 'dim_calendario'[ano] >= a1 - 2 && 'dim_calendario'[ano] <= a1 ), 3 )", ""),
    ("fato_sinistro", "Variação % entre triênios", PCT, "Tendência",
     "DIVIDE ( [Sinistros/ano no último triênio] - [Sinistros/ano no primeiro triênio], [Sinistros/ano no primeiro triênio] )",
     "Crescimento da média anual de sinistros entre o primeiro e o último triênio da série."),
    ("fato_sinistro", "Cor da variação", None, "Tendência",
     "IF ( [Variação % entre triênios] > 0, \"#B03A2E\", \"#2E7D5B\" )", "Vermelho = cresceu; verde = caiu."),
    ("fato_populacao", "Cor da situação da meta", None, "KPI",
     "VAR taxa = [Taxa no último ano]\nRETURN IF ( taxa <= [Meta 2030], \"#2E7D5B\", \"#B03A2E\" )", "Verde se a taxa do último ano já está na meta; vermelho caso contrário."),
    ("fato_populacao", "Narrativa da meta", None, "KPI",
     "VAR ano_ref = [Ano de referência]\nVAR taxa = [Taxa no último ano]\nVAR meta = [Meta 2030]\nVAR minimo =\n"
     "    MINX ( VALUES ( 'dim_calendario'[ano] ), [Taxa de mortos por 100 mil hab.] )\n"
     "VAR ano_min =\n    MAXX ( TOPN ( 1, VALUES ( 'dim_calendario'[ano] ), [Taxa de mortos por 100 mil hab.], ASC ), 'dim_calendario'[ano] )\n"
     "RETURN\n    \"Em \" & ano_ref & \", \" & FORMAT ( [Mortos no último ano], \"#,0\" ) & \" pessoas morreram no trânsito de BH: \"\n"
     "        & FORMAT ( taxa, \"0.00\" ) & \" por 100 mil habitantes, \" & FORMAT ( taxa - meta, \"0.00\" )\n"
     "        & \" acima da meta de \" & FORMAT ( meta, \"0.00\" ) & \" para 2030. O melhor ano foi \" & ano_min\n"
     "        & \" (\" & FORMAT ( minimo, \"0.00\" ) & \").\"",
     "Texto do storytelling da página estratégica, recalculado a cada atualização."),
    ("fato_populacao", "Taxa (anos-chave)", DEC2, "KPI",
     "VAR ano_atual = SELECTEDVALUE ( 'dim_calendario'[ano] )\nVAR anos = ALLSELECTED ( 'dim_calendario'[ano] )\n"
     "VAR primeiro = MINX ( anos, 'dim_calendario'[ano] )\nVAR ultimo = MAXX ( anos, 'dim_calendario'[ano] )\n"
     "VAR melhor = MAXX ( TOPN ( 1, anos, [Taxa de mortos por 100 mil hab.], ASC ), 'dim_calendario'[ano] )\n"
     "RETURN IF ( ano_atual IN { primeiro, 2014, melhor, ultimo }, [Taxa de mortos por 100 mil hab.] )",
     "Taxa só no primeiro ano, em 2014 (base), no melhor ano e no último ano: série usada para rotular os anos-chave."),
    ("fato_populacao", "Distância da meta (texto)", None, "KPI",
     "VAR taxa = [Taxa no último ano]\nVAR meta = [Meta 2030]\nRETURN\n    IF (\n        taxa > meta,\n"
     "        \"+\" & FORMAT ( taxa - meta, \"0.00\" ) & \" acima da meta (+\" & FORMAT ( DIVIDE ( taxa - meta, meta ), \"0%\" ) & \")\",\n"
     "        \"Meta atingida: \" & FORMAT ( taxa, \"0.00\" ) & \" ≤ \" & FORMAT ( meta, \"0.00\" )\n    )",
     "Distância do último ano para a meta, em texto (substitui o percentual negativo do visual de KPI)."),
    ("fato_populacao", "Rótulo de atualização", None, "KPI",
     "VAR a0 = CALCULATE ( MIN ( 'fato_sinistro'[ano] ), ALL () )\nVAR a1 = CALCULATE ( MAX ( 'fato_sinistro'[ano] ), ALL () )\n"
     "VAR atualizado = MAX ( 'Atualizacao'[data_atualizacao] )\n"
     "RETURN \"Dados de \" & a0 & \" a \" & a1 & \" · atualizado em \" & FORMAT ( atualizado, \"dd/MM/yyyy\" )",
     "Período dos dados e data da última atualização do painel."),
    ("fato_sinistro", "Sinistros por ano (média)", INT, "Sinistros",
     "DIVIDE ( [Sinistros], DISTINCTCOUNT ( 'dim_calendario'[ano] ) )", "Média anual de sinistros no contexto (ex.: por mês)."),
    ("fato_sinistro", "% motos nos veículos", PCT, "Veículos por espécie", "DIVIDE ( [Motocicletas], [Veículos] )", ""),
    ("fato_sinistro", "% motos na cidade", PCT, "Veículos por espécie",
     "CALCULATE ( [% motos nos veículos], REMOVEFILTERS ( 'dim_regional' ) )", "Referência da cidade, ignorando o filtro de regional."),
    ("fato_sinistro", "Cor motos regional", None, "Veículos por espécie",
     "IF ( [% motos nos veículos] > [% motos na cidade], \"#E0A100\", \"#8EA9DB\" )", "Âmbar para regionais acima da média da cidade."),
    ("fato_sinistro", "Subtítulo motos", None, "Veículos por espécie",
     "\"Média da cidade: \" & FORMAT ( [% motos na cidade], \"0.0%\" ) & \" · em âmbar, as regionais acima da média\"", ""),
    ("fato_sinistro", "Título do local", None, "Local",
     "IF (\n    HASONEVALUE ( 'dim_local'[descricao_local_atual] ),\n    VALUES ( 'dim_local'[descricao_local_atual] ),\n"
     "    \"Nenhum local selecionado: na página 4, clique com o botão direito em um ponto do mapa ou do ranking e escolha Detalhar\"\n)", ""),
    ("fato_sinistro", "Horário com mais sinistros", None, "Local",
     "VAR faixas = FILTER ( VALUES ( 'dim_hora'[faixa_horaria] ), 'dim_hora'[faixa_horaria] <> \"Hora não informada\" )\n"
     "RETURN MAXX ( TOPN ( 1, faixas, [Sinistros], DESC ), 'dim_hora'[faixa_horaria] )", "Faixa de 3 horas com mais sinistros no contexto."),
    ("fato_sinistro", "Pior faixa horária", None, "Local",
     "VAR faixas = FILTER ( VALUES ( 'dim_hora'[faixa_horaria] ), 'dim_hora'[faixa_horaria] <> \"Hora não informada\" )\n"
     "VAR pior = TOPN ( 1, faixas, [Sinistros], DESC )\nRETURN \"Pior horário: \" & MAXX ( pior, 'dim_hora'[faixa_horaria] )",
     "Faixa de 3 horas com mais sinistros no contexto."),
]


def m_particao(tabela: str, spec: dict) -> str:
    cols = [c[0] for c in spec["cols"]]
    tipos = ", ".join(f'{{"{c}", {M_TIPO[t]}}}' for c, t, _ in spec["cols"])
    linhas = [
        "let",
        "    Fonte = PostgreSQL.Database(Servidor, BancoDeDados),",
        f'    Dados = Fonte{{[Schema = "bi", Item = "{tabela}"]}}[Data],',
        "    Colunas = Table.SelectColumns(Dados, {" + ", ".join(f'"{c}"' for c in cols) + "}),",
        f"    Tipos = Table.TransformColumnTypes(Colunas, {{{tipos}}})" + ("," if spec.get("filtrar_anos") else ""),
    ]
    if spec.get("filtrar_anos"):
        linhas += [
            "    // só os anos que têm sinistros carregados (evita anos vazios nos filtros)",
            '    Anos = List.Buffer(Table.Column(Table.Distinct(Table.SelectColumns(Fonte{[Schema = "bi", Item = "fato_sinistro"]}[Data], {"ano"})), "ano")),',
            "    Resultado = Table.SelectRows(Tipos, each [ano] >= List.Min(Anos) and [ano] <= List.Max(Anos))",
            "in",
            "    Resultado",
        ]
    else:
        linhas += ["in", "    Tipos"]
    return "\n".join(linhas)


def bloco(texto: str, nivel: int) -> str:
    pre = "\t" * nivel
    return "\n".join(pre + l if l.strip() else "" for l in texto.split("\n"))


def tmdl_tabela(tabela: str, spec: dict) -> str:
    out = [f"/// {spec['desc']}", f"table {tabela}", f"\tlineageTag: {tag('t', tabela)}"]
    if spec.get("data_table"):
        out.append("\tdataCategory: Time")
    out.append("")
    for (t, nome, fmt, pasta, dax, desc) in MEDIDAS:
        if t != tabela:
            continue
        if desc:
            out.append(f"\t/// {desc}")
        if "\n" in dax:
            out.append(f"\tmeasure {nome_tmdl(nome)} =")
            out.append(bloco(dax, 3))
        else:
            out.append(f"\tmeasure {nome_tmdl(nome)} = {dax}")
        if fmt:
            out.append(f"\t\tformatString: {fmt}")
        out.append(f"\t\tdisplayFolder: {pasta}")
        out.append(f"\t\tlineageTag: {tag('m', tabela, nome)}")
        out.append("")
    for nome, tipo, op in spec["cols"]:
        out.append(f"\tcolumn {nome_tmdl(nome)}")
        out.append(f"\t\tdataType: {TMDL_TIPO[tipo]}")
        if op.get("key"):
            out.append("\t\tisKey")
        if op.get("hidden"):
            out.append("\t\tisHidden")
        fmt = op.get("fmt") or ({"int": "0", "double": "0.000000"}.get(tipo))
        if fmt:
            out.append(f"\t\tformatString: {fmt}")
        if op.get("cat"):
            out.append(f"\t\tdataCategory: {op['cat']}")
        out.append(f"\t\tlineageTag: {tag('c', tabela, nome)}")
        out.append(f"\t\tsummarizeBy: {op.get('summ', 'none')}")
        out.append(f"\t\tsourceColumn: {nome}")
        if op.get("sort"):
            out.append(f"\t\tsortByColumn: {op['sort']}")
        out.append("")
        out.append("\t\tannotation SummarizationSetBy = User")
        if tipo == "date":
            out.append("")
            out.append("\t\tannotation UnderlyingDateTimeDataType = Date")
        out.append("")
    for nome, tipo, dax, desc in spec.get("calc_cols", []):
        out.append(f"\t/// {desc}")
        out.append(f"\tcolumn {nome_tmdl(nome)} =")
        out.append(bloco(dax, 3))
        out.append(f"\t\tdataType: {TMDL_TIPO[tipo]}")
        out.append(f"\t\tlineageTag: {tag('c', tabela, nome)}")
        out.append("\t\tsummarizeBy: none")
        out.append("")
        out.append("\t\tannotation SummarizationSetBy = Automatic")
        out.append("")
    out.append(f"\tpartition {tabela} = m")
    out.append("\t\tmode: import")
    out.append("\t\tsource =")
    out.append(bloco(m_particao(tabela, spec), 4))
    out.append("")
    out.append("\tannotation PBI_ResultType = Table")
    out.append("")
    return "\n".join(out)


def gerar_modelo() -> None:
    d = SM / "definition"
    (d / "tables").mkdir(parents=True, exist_ok=True)
    (SM / "definition.pbism").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
        "version": "4.0", "settings": {}}, indent=2), encoding="utf-8")
    (d / "database.tmdl").write_text("database\n\tcompatibilityLevel: 1601\n\n", encoding="utf-8")
    ordem = ["Servidor", "BancoDeDados"] + list(TABELAS)
    model = ["model Model", "\tculture: pt-BR", "\tdefaultPowerBIDataSourceVersion: powerBI_V3",
             "\tsourceQueryCulture: pt-BR", "\tdataAccessOptions", "\t\tlegacyRedirects", "\t\treturnErrorValuesAsNull", "",
             "annotation __PBI_TimeIntelligenceEnabled = 0", "",
             "annotation PBI_QueryOrder = " + json.dumps(ordem, ensure_ascii=False), "",
             "annotation PBI_ProTooling = [\"DevMode\"]", ""]
    model += [f"ref table {t}" for t in TABELAS] + ["ref table Atualizacao"]
    (d / "model.tmdl").write_text("\n".join(model) + "\n", encoding="utf-8")
    # tabela calculada com o momento da última atualização (recalculada a cada Atualizar)
    (d / "tables" / "Atualizacao.tmdl").write_text("\n".join([
        "/// Data e hora da última atualização do modelo (calculada no refresh).",
        "table Atualizacao", "\tisHidden", f"\tlineageTag: {tag('t', 'Atualizacao')}", "",
        "\tcolumn data_atualizacao", "\t\tdataType: dateTime", "\t\tisHidden", "\t\tisDataTypeInferred",
        "\t\tformatString: General Date", f"\t\tlineageTag: {tag('c', 'Atualizacao', 'data_atualizacao')}",
        "\t\tsummarizeBy: none", "\t\tsourceColumn: [data_atualizacao]", "",
        "\t\tannotation SummarizationSetBy = Automatic", "",
        "\tpartition Atualizacao = calculated", "\t\tmode: import",
        "\t\tsource = ROW ( \"data_atualizacao\", NOW () )", "",
        "\tannotation PBI_Id = " + tag("pbi", "Atualizacao").replace("-", ""), ""]), encoding="utf-8")
    expr = []
    for nome, valor, desc in [("Servidor", "127.0.0.1:5432", "Servidor PostgreSQL do DW (host:porta)."),
                              ("BancoDeDados", "dw_sinistros_bh", "Banco de dados do DW.")]:
        expr += [f"/// {desc}",
                 f'expression {nome} = "{valor}" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]',
                 f"\tlineageTag: {tag('e', nome)}", "", "\tannotation PBI_ResultType = Text", ""]
    (d / "expressions.tmdl").write_text("\n".join(expr) + "\n", encoding="utf-8")
    rel = []
    for f, fc, dim, dc in RELACOES:
        rel += [f"relationship {tag('r', f, fc, dim)}", f"\tfromColumn: {f}.{fc}", f"\ttoColumn: {dim}.{dc}", ""]
    (d / "relationships.tmdl").write_text("\n".join(rel), encoding="utf-8")
    for t, spec in TABELAS.items():
        (d / "tables" / f"{t}.tmdl").write_text(tmdl_tabela(t, spec), encoding="utf-8")


# =============================================================================================
# 2. RELATÓRIO (PBIR)
# =============================================================================================
VC = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json"
NAVY, AMBER, RED, SLATE, LIGHT, ICE, GREEN, GREY = "#1F3864", "#E0A100", "#B03A2E", "#5B6B85", "#8EA9DB", "#D9E2F3", "#2E7D5B", "#A6B0C3"

# tabela de cada medida (para montar as referências)
TAB_MEDIDA = {m[1]: m[0] for m in MEDIDAS}


def lit(v: str) -> dict:
    return {"expr": {"Literal": {"Value": v}}}


def s(texto: str) -> dict:  # literal de texto
    return lit("'" + texto.replace("'", "''") + "'")


def cor(hexa: str) -> dict:
    return {"solid": {"color": s(hexa)}}


def C(tab: str, col: str) -> dict:
    return {"Column": {"Expression": {"SourceRef": {"Entity": tab}}, "Property": col}}


def M(nome: str) -> dict:
    return {"Measure": {"Expression": {"SourceRef": {"Entity": TAB_MEDIDA[nome]}}, "Property": nome}}


def AVG(tab: str, col: str) -> dict:
    return {"Aggregation": {"Expression": C(tab, col), "Function": 1}}


def qref(campo: dict) -> tuple[str, str]:
    if "Aggregation" in campo:
        c = campo["Aggregation"]["Expression"]["Column"]
        n = f"Average of {c['Property']}"
        return f"Avg({c['Expression']['SourceRef']['Entity']}.{c['Property']})", n
    k = "Measure" if "Measure" in campo else "Column"
    e = campo[k]["Expression"]["SourceRef"]["Entity"]
    p = campo[k]["Property"]
    return f"{e}.{p}", p


def proj(campo: dict, ativo: bool | None = None, nome: str | None = None) -> dict:
    r, n = qref(campo)
    p = {"field": campo, "queryRef": r, "nativeQueryRef": n}
    if nome:
        p["displayName"] = nome
    if ativo is not None:
        p["active"] = ativo
    return p


def titulo(texto: str | None = None, medida: str | None = None, sub: str | None = None, sub_medida: str | None = None) -> dict:
    o = {"title": [{"properties": {"show": lit("true"), "text": s(texto) if texto else {"expr": M(medida)},
                                   "fontSize": lit("12D"), "fontColor": cor(NAVY), "bold": lit("true")}}]}
    if sub or sub_medida:
        o["subTitle"] = [{"properties": {"show": lit("true"), "text": s(sub) if sub else {"expr": M(sub_medida)},
                                         "fontSize": lit("9D"), "fontColor": cor(SLATE)}}]
    return o


class Pagina:
    def __init__(self, nome: str, exibicao: str, tipo: str = "Default", oculta: bool = False,
                 largura: int = 1280, altura: int = 720, extra: dict | None = None):
        self.nome, self.exibicao, self.visuais, self.z = nome, exibicao, [], 0
        self.tipo, self.oculta, self.largura, self.altura, self.extra = tipo, oculta, largura, altura, extra or {}

    def add(self, nome: str, x, y, w, h, visual: dict, filtros: list | None = None, alt: str | None = None):
        self.z += 1000
        v = {"$schema": VC, "name": nome,
             "position": {"x": x, "y": y, "z": self.z, "width": w, "height": h, "tabOrder": self.z},
             "visual": visual}
        if alt:
            v["visual"].setdefault("visualContainerObjects", {}).setdefault("general", [{"properties": {}}])
            v["visual"]["visualContainerObjects"]["general"][0]["properties"]["altText"] = s(alt)
        if filtros:
            v["filterConfig"] = {"filters": filtros}
        if "visualTooltip" in v["visual"].get("visualContainerObjects", {}):
            v["$schema"] = VC.replace("2.7.0", "2.11.0")
        self.visuais.append(v)


def texto(paragrafos: list[list[tuple[str, dict]]]) -> dict:
    pars = []
    for runs in paragrafos:
        pars.append({"textRuns": [{"value": t, "textStyle": st} for t, st in runs]})
    return {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": pars}}]},
            "visualContainerObjects": {"background": [{"properties": {"show": lit("false")}}],
                                       "border": [{"properties": {"show": lit("false")}}],
                                       "title": [{"properties": {"show": lit("false")}}]}}


H1 = {"fontFamily": "Segoe UI Semibold", "fontSize": "18pt", "color": NAVY}
TAG = {"fontFamily": "Segoe UI Semibold", "fontSize": "9pt", "color": AMBER}
PS = {"fontFamily": "Segoe UI", "fontSize": "9pt", "color": SLATE}

# Limites do fundo do mapa (lon/lat), calculados do GeoJSON das regionais em gerar_mapa_fundo()
MAPA = {}


def cabecalho(pg: Pagina, nivel: str, titulo_txt: str, pergunta: str):
    pg.add("cabecalho", 24, 4, 1232, 90, texto([
        [(nivel.upper(), TAG)],
        [(titulo_txt, H1)],
        [(pergunta, PS)],
    ]), alt=titulo_txt)


def card(medida: str, rotulo: str, cor_valor: str = NAVY, cor_medida: str | None = None, tam="26D") -> dict:
    cor_v = {"solid": {"color": {"expr": M(cor_medida)}}} if cor_medida else cor(cor_valor)
    return {"visualType": "card",
            "query": {"queryState": {"Values": {"projections": [proj(M(medida), nome=rotulo)]}}},
            "objects": {"labels": [{"properties": {"color": cor_v, "fontSize": lit(tam), "fontFamily": s("Segoe UI Semibold")}}],
                        "categoryLabels": [{"properties": {"show": lit("true"), "color": cor(SLATE), "fontSize": lit("10D")}}]},
            "visualContainerObjects": {"title": [{"properties": {"show": lit("false")}}]},
            "drillFilterOtherVisuals": True}


def slicer(tab: str, col: str, rotulo: str, padrao: list[str] | None = None) -> dict:
    obj = {"data": [{"properties": {"mode": s("Dropdown")}}],
           "header": [{"properties": {"show": lit("true"), "text": s(rotulo), "fontColor": cor(NAVY), "textSize": lit("10D")}}],
           "selection": [{"properties": {"selectAllCheckboxEnabled": lit("true")}}]}
    if padrao:
        obj["general"] = [{"properties": {"filter": {"filter": {
            "Version": 2, "From": [{"Name": "d", "Entity": tab, "Type": 0}],
            "Where": [{"Condition": {"In": {
                "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": col}}],
                "Values": [[{"Literal": {"Value": v}}] for v in padrao]}}}]}}}}]
    return {"visualType": "slicer",
            "query": {"queryState": {"Values": {"projections": [proj(C(tab, col), ativo=True)]}}},
            "objects": obj,
            "visualContainerObjects": {"title": [{"properties": {"show": lit("false")}}],
                                       "padding": [{"properties": {"top": lit("4D"), "bottom": lit("4D")}}]},
            "drillFilterOtherVisuals": True}


def ordenar(campo: dict, desc=True) -> dict:
    return {"sort": [{"field": campo, "direction": "Descending" if desc else "Ascending"}], "isDefaultSort": True}


EIXO_CAT = [{"properties": {"showAxisTitle": lit("false"), "axisType": s("Categorical")}}]
EIXO_BARRA = [{"properties": {"showAxisTitle": lit("false"), "maxMarginFactor": lit("45L")}}]
EIXO_VAL_OCULTO = [{"properties": {"show": lit("false"), "showAxisTitle": lit("false"), "gridlineShow": lit("false")}}]
EIXO_VAL_ZERO = [{"properties": {"showAxisTitle": lit("false"), "start": lit("0D")}}]
LEGENDA_TOPO = [{"properties": {"show": lit("true"), "position": s("Top"), "showTitle": lit("false")}}]


def grafico(tipo: str, cat: list, y: list, serie: list | None = None, sort: dict | None = None, objetos: dict | None = None,
            tit: dict | None = None) -> dict:
    qs = {"Category": {"projections": [proj(c, ativo=True) for c in cat]}, "Y": {"projections": [proj(m) for m in y]}}
    if serie:
        qs["Series"] = {"projections": [proj(c) for c in serie]}
    v = {"visualType": tipo, "query": {"queryState": qs}, "drillFilterOtherVisuals": True}
    if sort:
        v["query"]["sortDefinition"] = sort
    if objetos:
        v["objects"] = objetos
    if tit:
        v["visualContainerObjects"] = tit
    return v


def rotulos(mostrar=True, tam="9D") -> list:
    return [{"properties": {"show": lit("true" if mostrar else "false"), "fontSize": lit(tam), "color": cor(SLATE)}}]


def cor_serie(medida: str, hexa: str) -> dict:
    r, _ = qref(M(medida))
    return {"properties": {"fill": cor(hexa)}, "selector": {"metadata": r}}


def cor_por_medida(base: str, medida: str) -> list:
    """Cor de cada barra definida por uma medida (formatação condicional por valor do campo)."""
    return [{"properties": {"fill": cor(base)}},
            {"properties": {"fill": {"solid": {"color": {"expr": M(medida)}}}},
             "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}}]


def fid(n: int) -> str:
    return f"{n:020x}"[-20:]


def filtro_nao_in(tab: str, col: str, valores: list[str], n: int) -> dict:
    return {"name": fid(0xF11 + n), "field": C(tab, col), "type": "Categorical",
            "filter": {"Version": 2, "From": [{"Name": "t", "Entity": tab, "Type": 0}],
                       "Where": [{"Condition": {"Not": {"Expression": {"In": {
                           "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "t"}}, "Property": col}}],
                           "Values": [[{"Literal": {"Value": "'" + v + "'"}}] for v in valores]}}}}}]},
            "objects": {"general": [{"properties": {"isInvertedSelectionMode": lit("true")}}]}}


def filtro_topn(tab: str, col: str, n: int, medida: str, k: int) -> dict:
    """Filtro Top N: subconsulta com os N primeiros pela medida + condição In sobre ela."""
    tab_m = TAB_MEDIDA[medida]
    sub = {"Version": 2,
           "From": [{"Name": "d", "Entity": tab, "Type": 0}, {"Name": "f", "Entity": tab_m, "Type": 0}],
           "Select": [{"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": col}, "Name": "field"}],
           "OrderBy": [{"Direction": 2, "Expression": {"Measure": {"Expression": {"SourceRef": {"Source": "f"}}, "Property": medida}}}],
           "Top": n}
    return {"name": fid(0x70F + k), "field": C(tab, col), "type": "TopN",
            "filter": {"Version": 2,
                       "From": [{"Name": "subquery", "Expression": {"Subquery": {"Query": sub}}, "Type": 2},
                                {"Name": "d", "Entity": tab, "Type": 0}],
                       "Where": [{"Condition": {"In": {
                           "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": col}}],
                           "Table": {"SourceRef": {"Source": "subquery"}}}}}]}}


def tabela(colunas: list[tuple[dict, str | None]], sort: dict, tit: dict, barra: tuple[str, str] | None = None, fonte="10D") -> dict:
    obj = {"values": [{"properties": {"fontSize": lit(fonte)}}],
           "columnHeaders": [{"properties": {"fontSize": lit(fonte), "fontColor": cor(NAVY), "bold": lit("true")}}],
           "total": [{"properties": {"totals": lit("false")}}]}
    if barra:
        obj["dataBars"] = [{"properties": {"positiveColor": cor(barra[1]), "hideText": lit("false")},
                            "selector": {"metadata": qref(M(barra[0]))[0]}}]
    return {"visualType": "tableEx",
            "query": {"queryState": {"Values": {"projections": [proj(c, nome=n) for c, n in colunas]}}, "sortDefinition": sort},
            "objects": obj, "visualContainerObjects": tit, "drillFilterOtherVisuals": True}


REG_INVALIDAS = ["NÃO INFORMADA", "NÃO SE APLICA"]
TIPO_INVALIDO = ["Não informado", "Não se aplica"]


PAGINAS_NAV = [("p1_estrategico", "1 · Meta 2030"), ("p2_onde_quem", "2 · Onde e quem"),
               ("p3_quando_como", "3 · Quando e como"), ("p4_onde_agir", "4 · Onde agir")]
SEM_MOLDURA = {"background": [{"properties": {"show": lit("false")}}], "border": [{"properties": {"show": lit("false")}}],
               "title": [{"properties": {"show": lit("false")}}], "visualHeader": [{"properties": {"show": lit("false")}}],
               "padding": [{"properties": {"top": lit("0D"), "bottom": lit("0D"), "left": lit("0D"), "right": lit("0D")}}]}


def botao(texto_b: str, destino: str | None = None, tipo: str = "PageNavigation", ativo: bool = False, tam="9D") -> dict:
    fundo, letra = (NAVY, "#FFFFFF") if ativo else (ICE, NAVY)
    link = {"show": lit("true"), "type": s(tipo)}
    if destino:
        link["navigationSection"] = s(destino)
    return {"visualType": "actionButton",
            "objects": {"icon": [{"properties": {"show": lit("false")}}],
                        "text": [{"properties": {"show": lit("true")}},
                                 {"properties": {"text": s(texto_b), "fontSize": lit(tam), "fontColor": cor(letra), "bold": lit("true"),
                                                 "fontFamily": s("Segoe UI")}, "selector": {"id": "default"}}],
                        "fill": [{"properties": {"show": lit("true")}},
                                 {"properties": {"fillColor": cor(fundo), "transparency": lit("0D")}, "selector": {"id": "default"}}],
                        "outline": [{"properties": {"show": lit("false")}}],
                        "shape": [{"properties": {"roundEdge": lit("6L")}, "selector": {"id": "default"}}]},
            "visualContainerObjects": {**SEM_MOLDURA, "visualLink": [{"properties": link}]},
            "drillFilterOtherVisuals": True}


def texto_medida(medida: str, tam="9D", cor_txt=SLATE, fundo: str | None = None) -> dict:
    """Card sem moldura que exibe uma medida de texto."""
    vco = dict(SEM_MOLDURA)
    if fundo:
        vco = {**vco, "background": [{"properties": {"show": lit("true"), "color": cor(fundo)}}]}
    return {"visualType": "card",
            "query": {"queryState": {"Values": {"projections": [proj(M(medida))]}}},
            "objects": {"labels": [{"properties": {"color": cor(cor_txt), "fontSize": lit(tam), "fontFamily": s("Segoe UI")}}],
                        "categoryLabels": [{"properties": {"show": lit("false")}}],
                        "wordWrap": [{"properties": {"show": lit("true")}}]},
            "visualContainerObjects": vco, "drillFilterOtherVisuals": True}


def navegacao(pg: Pagina, atual: str):
    pg.add("atualizacao", 516, 4, 276, 24, texto_medida("Rótulo de atualização", tam="8D"), alt="Período dos dados e data da atualização")
    for i, (destino, rot) in enumerate(PAGINAS_NAV):
        pg.add(f"nav_{i + 1}", 800 + i * 114, 6, 110, 22, botao(rot, destino, ativo=(destino == atual), tam="8D"), alt=f"Ir para a página {rot}")


def dica_local() -> dict:
    """Dica padrão (a página de dica personalizada não foi aplicada pelo Desktop; os campos extras vão no papel Tooltips)."""
    return {}


def campos_dica() -> dict:
    return {"Tooltips": {"projections": [proj(M("Sinistros")), proj(M("Mortos")), proj(M("Horário com mais sinistros"))]}}


def pagina_estrategica() -> Pagina:
    pg = Pagina("p1_estrategico", "1 · Meta 2030 (estratégico)")
    cabecalho(pg, "Visão estratégica · Gabinete e Diretoria de Segurança Viária",
              "BH está longe da meta de reduzir pela metade as mortes no trânsito até 2030",
              "Pergunta: a taxa de mortos por 100 mil habitantes está caindo no ritmo da meta (−50% sobre 2014 até 2030)?")
    navegacao(pg, "p1_estrategico")
    pg.add("narrativa", 24, 100, 1232, 40, texto_medida("Narrativa da meta", tam="12D", cor_txt="#1B1F2A", fundo="#FFF7E0"),
           alt="Resumo em texto da situação da meta")
    ano = C("dim_calendario", "ano")
    pg.add("kpi_taxa", 24, 150, 296, 122, {
        "visualType": "kpi",
        "query": {"queryState": {
            "Indicator": {"projections": [proj(M("Taxa de mortos por 100 mil hab."))]},
            "TrendLine": {"projections": [proj(ano)]},
            "Goal": {"projections": [proj(M("Meta 2030"))]}}},
        "objects": {"status": [{"properties": {"direction": s("Negative")}}],
                    "indicator": [{"properties": {"fontSize": lit("24D")}}],
                    "goals": [{"properties": {"showGoal": lit("true"), "showDistance": lit("false")}}]},
        "visualContainerObjects": titulo("KPI · Taxa de mortos/100 mil × meta 2030", sub_medida="Distância da meta (texto)"),
        "drillFilterOtherVisuals": True}, alt="KPI da taxa de mortos com tendência anual e meta de 2030")
    pg.add("card_mortos", 336, 150, 224, 122, card("Mortos no último ano", "Mortos no último ano"))
    pg.add("card_reducao", 576, 150, 224, 122, card("Redução da taxa vs 2014", "Redução vs 2014 (meta: 50%)",
                                                   cor_medida="Cor da situação da meta"))
    pg.add("card_falta", 816, 150, 216, 122, card("Queda ainda necessária", "Queda que falta até 2030", cor_valor=RED))
    pg.add("kpi_moto", 1048, 150, 208, 122, {
        "visualType": "kpi",
        "query": {"queryState": {
            "Indicator": {"projections": [proj(M("% vítimas motociclistas"))]},
            "TrendLine": {"projections": [proj(ano)]}}},
        "objects": {"indicator": [{"properties": {"fontSize": lit("22D")}}],
                    "trendline": [{"properties": {"show": lit("true"), "transparency": lit("70D")}}]},
        "visualContainerObjects": titulo("Motociclistas nas vítimas"),
        "drillFilterOtherVisuals": True}, alt="KPI da participação de motociclistas nas vítimas com tendência anual")
    taxa_ref, meta_ref, base_ref = (qref(M("Taxa de mortos por 100 mil hab."))[0], qref(M("Meta 2030"))[0],
                                    qref(M("Taxa base 2014"))[0])
    dest_ref = qref(M("Taxa (anos-chave)"))[0]
    pg.add("linha_taxa_meta", 24, 284, 700, 420, grafico(
        "lineChart", [ano], [M("Taxa de mortos por 100 mil hab."), M("Meta 2030"), M("Taxa base 2014"), M("Taxa (anos-chave)")],
        sort=ordenar(ano, desc=False),
        objetos={"dataPoint": [cor_serie("Taxa de mortos por 100 mil hab.", NAVY), cor_serie("Meta 2030", AMBER),
                               cor_serie("Taxa base 2014", GREY), cor_serie("Taxa (anos-chave)", NAVY)],
                 "lineStyles": [{"properties": {"strokeWidth": lit("3D"), "showMarker": lit("true")}},
                                {"properties": {"lineStyle": s("dashed"), "showMarker": lit("false")}, "selector": {"metadata": meta_ref}},
                                {"properties": {"lineStyle": s("dotted"), "showMarker": lit("false"), "strokeWidth": lit("2D")},
                                 "selector": {"metadata": base_ref}},
                                {"properties": {"strokeWidth": lit("0D"), "showMarker": lit("true"), "markerSize": lit("6D")},
                                 "selector": {"metadata": dest_ref}}],
                 "labels": [{"properties": {"show": lit("true"), "fontSize": lit("11D"), "color": cor(NAVY)}},
                            {"properties": {"showSeries": lit("false")}, "selector": {"metadata": taxa_ref}},
                            {"properties": {"showSeries": lit("false")}, "selector": {"metadata": meta_ref}},
                            {"properties": {"showSeries": lit("false")}, "selector": {"metadata": base_ref}},
                            {"properties": {"showSeries": lit("true"), "labelPosition": s("Above")}, "selector": {"metadata": dest_ref}}],
                 "legend": [{"properties": {"show": lit("false")}}], "categoryAxis": EIXO_CAT, "valueAxis": EIXO_VAL_ZERO},
        tit=titulo("A taxa caiu até 2019 e voltou a subir: em 2024 está quase no dobro da meta",
                   sub="Azul: mortos por 100 mil hab. · âmbar tracejado: meta 2030 · cinza pontilhado: base 2014 · "
                       "2022 e 2024 têm degraus na população do IBGE")),
        alt="Linha da taxa de mortos por 100 mil habitantes de 2011 a 2024 com a meta de 2030 e a base de 2014")
    reg = C("dim_regional", "nome_regional")
    pg.add("barra_regional", 740, 284, 516, 272, grafico(
        "barChart", [reg], [M("Taxa no último triênio")], sort=ordenar(M("Taxa no último triênio")),
        objetos={"dataPoint": cor_por_medida(LIGHT, "Cor destaque regional"), "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO,
                 "categoryAxis": [{"properties": {"showAxisTitle": lit("false"), "maxMarginFactor": lit("45L"), "innerPadding": lit("12L")}}]},
        tit=titulo(medida="Título regional")),
        filtros=[filtro_nao_in("dim_regional", "nome_regional", REG_INVALIDAS, 1)],
        alt="Barras da taxa de mortos por 100 mil habitantes por regional no último triênio")
    pg.add("linha_grupos", 740, 568, 516, 136, grafico(
        "lineChart", [ano], [M("% mortos motociclistas"), M("% mortos pedestres")], sort=ordenar(ano, desc=False),
        objetos={"dataPoint": [cor_serie("% mortos motociclistas", AMBER), cor_serie("% mortos pedestres", NAVY)],
                 "legend": LEGENDA_TOPO, "categoryAxis": EIXO_CAT, "valueAxis": EIXO_VAL_ZERO},
        tit=titulo("Grupos prioritários entre os mortos (%)")),
        alt="Linhas da participação de motociclistas e pedestres entre os mortos por ano")
    return pg


def pagina_onde_quem() -> Pagina:
    pg = Pagina("p2_onde_quem", "2 · Onde e quem (gerencial)")
    cabecalho(pg, "Visão gerencial · Diretoria, Engenharia de Tráfego e BHTrans Educa",
              "No último triênio, a Pampulha é a regional mais letal; motociclistas e pedestres concentram as mortes",
              "Perguntas: onde está o risco por habitante, quem morre e quais tipos crescem? · Abre nos últimos 3 anos (filtro Período)")
    navegacao(pg, "p2_onde_quem")
    pg.add("sl_periodo", 24, 100, 160, 64, slicer("dim_calendario", "periodo_analise", "Período", padrao=["'Últimos 3 anos'"]))
    pg.add("sl_ano", 192, 100, 132, 64, slicer("dim_calendario", "ano", "Ano"))
    pg.add("sl_regional", 332, 100, 144, 64, slicer("dim_regional", "nome_regional", "Regional"))
    reg = C("dim_regional", "nome_regional")
    pg.add("tabela_regional", 24, 176, 452, 288, tabela(
        [(reg, "Regional"), (M("Mortos"), None), (M("Taxa de vítimas por 100 mil hab."), "Vítimas/100 mil"),
         (M("Taxa de mortos por 100 mil hab."), "Mortos/100 mil")],
        ordenar(M("Taxa de mortos por 100 mil hab.")),
        titulo("Regionais ajustadas pela população", sub="Taxas = média anual do período · na série completa, a Noroeste lidera"),
        barra=("Taxa de mortos por 100 mil hab.", RED)),
        filtros=[filtro_nao_in("dim_regional", "nome_regional", REG_INVALIDAS, 2)],
        alt="Tabela de mortos e taxas por 100 mil habitantes por regional")
    usuario = C("fato_envolvido", "usuario_via")
    pg.add("barra_usuario", 492, 100, 372, 364, grafico(
        "barChart", [usuario], [M("Mortos (pessoas)")], sort=ordenar(M("Mortos (pessoas)")),
        objetos={"dataPoint": [{"properties": {"fill": cor(LIGHT)}},
                               {"properties": {"fill": cor(AMBER)}, "selector": {"data": [{"scopeId": {"Comparison": {
                                   "ComparisonKind": 0, "Left": usuario, "Right": {"Literal": {"Value": "'Motociclista'"}}}}}]}},
                               {"properties": {"fill": cor(NAVY)}, "selector": {"data": [{"scopeId": {"Comparison": {
                                   "ComparisonKind": 0, "Left": usuario, "Right": {"Literal": {"Value": "'Pedestre'"}}}}}]}}],
                 "labels": rotulos(), "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Quem morre: vítimas fatais por usuário da via", sub="Motociclistas e pedestres são os grupos prioritários")),
        alt="Barras de mortos por tipo de usuário da via")
    grupo = C("dim_tipo_sinistro", "grupo_tipo_sinistro")
    pg.add("barra_letalidade", 880, 100, 376, 364, grafico(
        "barChart", [grupo], [M("Mortos por 1.000 sinistros")], sort=ordenar(M("Mortos por 1.000 sinistros")),
        objetos={"dataPoint": [{"properties": {"fill": cor(RED)}}], "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Letalidade: mortos a cada 1.000 sinistros", sub="Atropelamento de pessoa é o tipo mais letal")),
        filtros=[filtro_nao_in("dim_tipo_sinistro", "grupo_tipo_sinistro", TIPO_INVALIDO, 3)],
        alt="Barras de mortos por mil sinistros por tipo de sinistro")
    pg.add("barra_crescimento", 24, 476, 600, 228, grafico(
        "barChart", [grupo], [M("Variação % entre triênios")], sort=ordenar(M("Variação % entre triênios")),
        objetos={"dataPoint": cor_por_medida(GREEN, "Cor da variação"), "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Quais tipos mais crescem", sub="Variação da média anual: primeiro × último triênio da série (não segue o filtro de ano)")),
        filtros=[filtro_nao_in("dim_tipo_sinistro", "grupo_tipo_sinistro", TIPO_INVALIDO, 4)],
        alt="Barras da variação percentual de sinistros entre o primeiro e o último triênio por tipo")
    faixa = C("dim_pessoa", "faixa_etaria")
    pg.add("coluna_idade", 640, 476, 616, 228, grafico(
        "columnChart", [faixa], [M("Mortos (pessoas)")], sort=ordenar(faixa, desc=False),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false")}}]},
        tit=titulo("Vítimas fatais por faixa etária",
                   sub="Números absolutos: não há população por idade para calcular taxa · público das campanhas")),
        filtros=[filtro_nao_in("dim_pessoa", "faixa_etaria", ["Não informada", "Não se aplica"], 9)],
        alt="Colunas de mortos por faixa etária")
    return pg


def pagina_quando_como() -> Pagina:
    pg = Pagina("p3_quando_como", "3 · Quando e como (gerencial)")
    cabecalho(pg, "Visão gerencial · Fiscalização, Operação e Comunicação",
              "Os sinistros se concentram nos dias úteis no fim da tarde; as madrugadas são as mais letais",
              "Perguntas: em que meses, dias e horários os sinistros acontecem, e como clima e pavimento afetam a gravidade?")
    navegacao(pg, "p3_quando_como")
    pg.add("sl_ano", 24, 100, 300, 64, slicer("dim_calendario", "ano", "Ano"))
    pg.add("sl_regional", 344, 100, 300, 64, slicer("dim_regional", "nome_regional", "Regional"))
    faixa, dia = C("dim_hora", "faixa_horaria"), C("dim_calendario", "nome_dia_semana_abrev")
    pg.add("matriz_dia_hora", 24, 176, 620, 304, {
        "visualType": "pivotTable",
        "query": {"queryState": {
            "Rows": {"projections": [proj(faixa, ativo=True, nome="Faixa horária")]},
            "Columns": {"projections": [proj(dia, ativo=True)]},
            "Values": {"projections": [proj(M("Sinistros"))]}}},
        "objects": {"values": [{"properties": {"fontSize": lit("10D"), "backColor": {"solid": {"color": {"expr": {"FillRule": {
            "Input": M("Sinistros"),
            "FillRule": {"linearGradient2": {"min": {"color": {"Literal": {"Value": "'#FFFFFF'"}}},
                                             "max": {"color": {"Literal": {"Value": "'#E0A100'"}}},
                                             "nullColoringStrategy": {"strategy": {"Literal": {"Value": "'asZero'"}}}}}}}}}}},
            "selector": {"data": [{"dataViewWildcard": {"matchingOption": 1}}], "metadata": qref(M("Sinistros"))[0]}}],
                    "columnHeaders": [{"properties": {"fontSize": lit("10D"), "fontColor": cor(NAVY), "bold": lit("true")}}],
                    "rowHeaders": [{"properties": {"fontSize": lit("10D")}}],
                    "subTotals": [{"properties": {"rowSubtotals": lit("true"), "columnSubtotals": lit("true")}}]},
        "visualContainerObjects": titulo("Mapa de calor: sinistros por dia da semana e faixa horária",
                                         sub="Quanto mais escuro, mais sinistros · base para escalar agentes e fiscalização"),
        "drillFilterOtherVisuals": True}, alt="Matriz de sinistros por faixa horária e dia da semana com escala de cor")
    mes = C("dim_calendario", "nome_mes_abrev")
    pg.add("coluna_mes", 660, 100, 596, 180, grafico(
        "columnChart", [mes], [M("Sinistros por ano (média)")], sort=ordenar(mes, desc=False),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false")}}]},
        tit=titulo("Sazonalidade: média de sinistros por mês", sub="Média por ano dos anos filtrados")),
        alt="Colunas da média anual de sinistros por mês")
    origem, chuva = C("dim_condicao_via", "origem_clima"), C("dim_condicao_via", "grupo_chuva")
    pg.add("coluna_clima", 660, 292, 280, 188, grafico(
        "clusteredColumnChart", [origem], [M("Mortos por 1.000 sinistros")], serie=[chuva],
        objetos={"labels": rotulos(), "legend": LEGENDA_TOPO,
                 "dataPoint": [{"properties": {"fill": cor(NAVY)}, "selector": {"data": [{"scopeId": {"Comparison": {
                     "ComparisonKind": 0, "Left": chuva, "Right": {"Literal": {"Value": "'COM CHUVA'"}}}}}]}},
                               {"properties": {"fill": cor(LIGHT)}, "selector": {"data": [{"scopeId": {"Comparison": {
                                   "ComparisonKind": 0, "Left": chuva, "Right": {"Literal": {"Value": "'SEM CHUVA'"}}}}}]}}],
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false"), "fontSize": lit("8D")}}]},
        tit=titulo("Clima × gravidade", sub="Mortos/1.000 sinistros · compare dentro da mesma origem do dado")),
        filtros=[filtro_nao_in("dim_condicao_via", "origem_clima", ["NÃO INFORMADO", "NÃO SE APLICA"], 5)],
        alt="Colunas de mortos por mil sinistros com e sem chuva, por origem do dado de clima")
    pav = C("dim_condicao_via", "pavimento")
    pg.add("tabela_pavimento", 952, 292, 304, 188, tabela(
        [(pav, "Pavimento"), (M("Sinistros"), None), (M("Mortos por 1.000 sinistros"), "Mortos/mil")],
        ordenar(M("Sinistros")), titulo("Pavimento × gravidade", sub="62% sem informação; poucos casos fora do asfalto"),
        fonte="8D"),
        filtros=[filtro_nao_in("dim_condicao_via", "pavimento", ["NÃO SE APLICA"], 10)],
        alt="Tabela de sinistros e mortos por mil sinistros por tipo de pavimento")
    ano = C("dim_calendario", "ano")
    pg.add("linha_severidade", 24, 492, 620, 212, grafico(
        "lineChart", [ano], [M("Mortos por 1.000 sinistros")], sort=ordenar(ano, desc=False),
        objetos={"dataPoint": [cor_serie("Mortos por 1.000 sinistros", RED)], "labels": rotulos(),
                 "categoryAxis": EIXO_CAT, "valueAxis": EIXO_VAL_ZERO},
        tit=titulo("Evolução da severidade: mortos a cada 1.000 sinistros", sub="Índice de letalidade por ano")),
        alt="Linha de mortos por mil sinistros por ano")
    periodo = C("dim_hora", "periodo_dia")
    pg.add("coluna_periodo", 660, 492, 596, 212, grafico(
        "clusteredColumnChart", [periodo], [M("Mortos por 1.000 sinistros")], serie=[C("dim_calendario", "tipo_dia")],
        objetos={"labels": rotulos(), "legend": LEGENDA_TOPO,
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false")}}]},
        tit=titulo("Gravidade por período do dia", sub="Mortos por 1.000 sinistros · dia útil × fim de semana")),
        filtros=[filtro_nao_in("dim_hora", "periodo_dia", ["Hora não informada"], 6)],
        alt="Colunas de mortos por mil sinistros por período do dia, separando fim de semana")
    return pg


def mapa_dispersao(n_top: int, w: int, h: int, dica: bool = True) -> dict:
    local = C("dim_local", "descricao_local_atual")
    img = {"image": {"name": s("mapa_regionais_bh.svg"),
                     "url": {"expr": {"ResourcePackageItem": {"PackageName": "RegisteredResources", "PackageType": 1,
                                                             "ItemName": "mapa_regionais_bh.svg"}}},
                     "scaling": s("Fit")}}
    vco = titulo(f"Mapa dos {n_top} locais mais severos", sub="Bolha = UPS · botão direito num ponto → Detalhar")
    if dica:
        vco.update(dica_local())
    return {"visualType": "scatterChart",
            "query": {"queryState": {
                "Category": {"projections": [proj(local, ativo=True)]},
                "X": {"projections": [proj(AVG("dim_local", "longitude"), nome="Longitude")]},
                "Y": {"projections": [proj(AVG("dim_local", "latitude"), nome="Latitude")]},
                "Size": {"projections": [proj(M("UPS"))]}, **campos_dica()},
                "sortDefinition": ordenar(M("UPS"))},
            "objects": {
                "categoryAxis": [{"properties": {"show": lit("false"), "showAxisTitle": lit("false"), "gridlineShow": lit("false"),
                                                 "start": lit(f"{MAPA['lon0']}D"), "end": lit(f"{MAPA['lon1']}D")}}],
                "valueAxis": [{"properties": {"show": lit("false"), "showAxisTitle": lit("false"), "gridlineShow": lit("false"),
                                              "start": lit(f"{MAPA['lat0']}D"), "end": lit(f"{MAPA['lat1']}D")}}],
                "plotArea": [{"properties": {"image": img, "transparency": lit("0D")}}],
                "dataPoint": [{"properties": {"fill": cor(RED)}}],
                "bubbles": [{"properties": {"bubbleSize": lit("-27L")}}],
                "legend": [{"properties": {"show": lit("false")}}]},
            "visualContainerObjects": vco, "drillFilterOtherVisuals": True}


def pagina_onde_agir() -> Pagina:
    pg = Pagina("p4_onde_agir", "4 · Onde agir (operacional)")
    cabecalho(pg, "Visão operacional · Engenharia de Tráfego e Fiscalização",
              "Poucos corredores concentram a severidade: Antônio Carlos, Anel Rodoviário e Cristiano Machado",
              "Perguntas: quais locais pedem intervenção física, em que horários e com que frota? · Botão direito num local → Detalhar")
    navegacao(pg, "p4_onde_agir")
    pg.add("sl_ano", 24, 100, 164, 64, slicer("dim_calendario", "ano", "Ano"))
    pg.add("sl_regional", 200, 100, 164, 64, slicer("dim_regional", "nome_regional", "Regional"))
    local = C("dim_local", "descricao_local_atual")
    pg.add("mapa_pontos", 24, 176, 340, 528, mapa_dispersao(300, 340, 528),
           filtros=[filtro_topn("dim_local", "descricao_local_atual", 300, "UPS", 1)],
           alt="Mapa de BH com as regionais e bolhas nos 300 locais de maior severidade")
    pg.add("bt_mapa_ruas", 246, 680, 112, 20, botao("Mapa de ruas ↗", "p6_mapa_ruas", tam="8D"),
           alt="Abrir o mapa com ruas (Azure Maps, requer login no Power BI)")
    tit_rank = titulo("Ranking dos 25 locais mais severos", sub="UPS = severidade ponderada (morte vale 13) · botão direito → Detalhar")
    tit_rank.update(dica_local())
    pg.add("tabela_locais", 380, 100, 876, 296, tabela(
        [(local, "Local (nome atual)"), (C("dim_local", "nome_bairro"), "Bairro"), (M("Sinistros"), None),
         (M("Mortos"), None), (M("UPS"), None)],
        ordenar(M("UPS")), tit_rank, barra=("UPS", AMBER), fonte="9D"),
        filtros=[filtro_topn("dim_local", "descricao_local_atual", 25, "UPS", 2)],
        alt="Tabela dos 25 locais com maior UPS")
    faixa = C("dim_hora", "faixa_horaria")
    pg.add("coluna_horario", 380, 408, 430, 296, grafico(
        "columnChart", [faixa], [M("Sinistros")], sort=ordenar(faixa, desc=False),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(tam="8D"),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false"), "fontSize": lit("8D")}}]},
        tit=titulo("Faixas horárias críticas", sub="Sinistros por faixa de 3 horas · filtre a regional")),
        filtros=[filtro_nao_in("dim_hora", "faixa_horaria", ["Hora não informada"], 7)],
        alt="Colunas de sinistros por faixa horária")
    reg = C("dim_regional", "nome_regional")
    pg.add("barra_motos", 826, 408, 430, 296, grafico(
        "barChart", [reg], [M("% motos nos veículos")], sort=ordenar(M("% motos nos veículos")),
        objetos={"dataPoint": cor_por_medida(LIGHT, "Cor motos regional"), "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Peso das motos na frota envolvida, por regional", sub_medida="Subtítulo motos")),
        filtros=[filtro_nao_in("dim_regional", "nome_regional", REG_INVALIDAS, 8)],
        alt="Barras da participação de motocicletas entre os veículos envolvidos, por regional, comparada à média da cidade")
    return pg


def pagina_detalhe_local() -> Pagina:
    filtro_dt = "f0000000000000000d71"
    pg = Pagina("p5_detalhe_local", "Detalhe do local", oculta=True, extra={
        "pageBinding": {"name": "drill_local", "type": "Drillthrough", "referenceScope": "Default",
                        "parameters": [{"name": "param_local", "boundFilter": filtro_dt,
                                        "fieldExpr": C("dim_local", "descricao_local_atual")}]},
        "filterConfig": {"filters": [{"name": filtro_dt, "field": C("dim_local", "descricao_local_atual"),
                                      "type": "Categorical", "howCreated": "Drillthrough"}]}})
    pg.add("cabecalho", 24, 4, 1000, 34, texto([[("DETALHE DO LOCAL · ENGENHARIA DE TRÁFEGO (botão direito → Detalhar, na página 4)", TAG)]]))
    pg.add("titulo_local", 24, 34, 1000, 56, texto_medida("Título do local", tam="16D", cor_txt=NAVY), alt="Nome do local detalhado")
    pg.add("voltar", 1136, 12, 120, 30, botao("← Voltar", tipo="Back", ativo=True, tam="10D"), alt="Voltar para a página anterior")
    for i, (med, rot, c) in enumerate([("Sinistros", "Sinistros", NAVY), ("Vítimas", "Vítimas", NAVY), ("Mortos", "Mortos", RED),
                                        ("UPS", "UPS (severidade)", AMBER), ("Mortos por 1.000 sinistros", "Mortos a cada mil sinistros", RED)]):
        pg.add(f"card_{i + 1}", 24 + i * 248, 100, 232, 100, card(med, rot, cor_valor=c, tam="24D"))
    ano = C("dim_calendario", "ano")
    pg.add("evolucao", 24, 212, 740, 240, {
        "visualType": "lineClusteredColumnComboChart",
        "query": {"queryState": {"Category": {"projections": [proj(ano, ativo=True)]},
                                 "Y": {"projections": [proj(M("Sinistros"))]},
                                 "Y2": {"projections": [proj(M("Mortos"))]}},
                  "sortDefinition": ordenar(ano, desc=False)},
        "objects": {"dataPoint": [cor_serie("Sinistros", LIGHT), cor_serie("Mortos", RED)],
                    "labels": [{"properties": {"show": lit("true"), "fontSize": lit("9D"), "color": cor(SLATE), "enableBackground": lit("false")}},
                               {"properties": {"color": cor(RED), "labelPosition": s("Above")}, "selector": {"metadata": qref(M("Mortos"))[0]}}],
                    "legend": LEGENDA_TOPO, "categoryAxis": EIXO_CAT,
                    "valueAxis": [{"properties": {"showAxisTitle": lit("false"), "secShowAxisTitle": lit("false")}}]},
        "visualContainerObjects": titulo("Evolução no local: sinistros (colunas) e mortos (linha)",
                                         sub="Compare antes e depois de uma intervenção"),
        "drillFilterOtherVisuals": True}, alt="Colunas de sinistros e linha de mortos por ano no local")
    faixa = C("dim_hora", "faixa_horaria")
    pg.add("horario", 780, 212, 476, 240, grafico(
        "columnChart", [faixa], [M("Sinistros")], sort=ordenar(faixa, desc=False),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(tam="8D"),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false"), "fontSize": lit("8D")}}]},
        tit=titulo(medida="Pior faixa horária", sub="Sinistros por faixa de 3 horas no local")),
        filtros=[filtro_nao_in("dim_hora", "faixa_horaria", ["Hora não informada"], 11)],
        alt="Colunas de sinistros por faixa horária no local")
    grupo = C("dim_tipo_sinistro", "grupo_tipo_sinistro")
    pg.add("tipos", 24, 464, 400, 240, grafico(
        "barChart", [grupo], [M("Sinistros")], sort=ordenar(M("Sinistros")),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Tipos de sinistro no local")),
        filtros=[filtro_nao_in("dim_tipo_sinistro", "grupo_tipo_sinistro", TIPO_INVALIDO, 12)],
        alt="Barras de sinistros por tipo no local")
    usuario = C("fato_envolvido", "usuario_via")
    pg.add("usuarios", 440, 464, 400, 240, grafico(
        "barChart", [usuario], [M("Vítimas (pessoas)")], sort=ordenar(M("Vítimas (pessoas)")),
        objetos={"dataPoint": [{"properties": {"fill": cor(LIGHT)}},
                               {"properties": {"fill": cor(AMBER)}, "selector": {"data": [{"scopeId": {"Comparison": {
                                   "ComparisonKind": 0, "Left": usuario, "Right": {"Literal": {"Value": "'Motociclista'"}}}}}]}}],
                 "labels": rotulos(), "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": EIXO_BARRA},
        tit=titulo("Quem se feriu no local", sub="Vítimas por usuário da via")),
        alt="Barras de vítimas por usuário da via no local")
    dia = C("dim_calendario", "nome_dia_semana_abrev")
    pg.add("dias", 856, 464, 400, 240, grafico(
        "columnChart", [dia], [M("Sinistros")], sort=ordenar(dia, desc=False),
        objetos={"dataPoint": [{"properties": {"fill": cor(NAVY)}}], "labels": rotulos(),
                 "valueAxis": EIXO_VAL_OCULTO, "categoryAxis": [{"properties": {"showAxisTitle": lit("false")}}]},
        tit=titulo("Dias da semana no local")),
        alt="Colunas de sinistros por dia da semana no local")
    return pg


def pagina_mapa_ruas() -> Pagina:
    pg = Pagina("p6_mapa_ruas", "Mapa de ruas (Azure Maps)", oculta=True)
    cabecalho(pg, "Visão operacional · mapa com ruas (opcional)",
              "Os 300 locais mais severos sobre o mapa de ruas",
              "Requer login em uma conta Microsoft no Power BI (botão Entrar); sem login, use o mapa da página 4, que funciona offline.")
    pg.add("voltar", 1136, 12, 120, 30, botao("← Voltar", tipo="Back", ativo=True, tam="10D"), alt="Voltar para a página anterior")
    pg.add("sl_ano", 24, 100, 200, 64, slicer("dim_calendario", "ano", "Ano"))
    pg.add("sl_regional", 236, 100, 240, 64, slicer("dim_regional", "nome_regional", "Regional"))
    local = C("dim_local", "descricao_local_atual")
    vco = titulo("Locais mais severos (tamanho = UPS)", sub="Zoom e arraste para navegar pelas ruas")
    vco.update(dica_local())
    pg.add("mapa_azure", 24, 176, 1232, 528, {
        "visualType": "azureMap",
        "query": {"queryState": {
            "Category": {"projections": [proj(local, ativo=True)]},
            "Y": {"projections": [proj(AVG("dim_local", "latitude"), nome="Latitude")]},
            "X": {"projections": [proj(AVG("dim_local", "longitude"), nome="Longitude")]},
            "Size": {"projections": [proj(M("UPS"))]}, **campos_dica()},
            "sortDefinition": ordenar(M("UPS"))},
        "objects": {"bubbleLayer": [{"properties": {"clusteringEnabled": lit("false"), "bubbleStrokeWidth": lit("1L"),
                                                    "markerRangeType": s("magnitude")}}],
                    "dataPoint": [{"properties": {"fill": cor(RED)}}],
                    "heatMapLayer": [{"properties": {"show": lit("false")}}],
                    "mapControls": [{"properties": {"defaultStyle": s("road"), "autoZoom": lit("true")}}]},
        "visualContainerObjects": vco, "drillFilterOtherVisuals": True},
        filtros=[filtro_topn("dim_local", "descricao_local_atual", 300, "UPS", 3)],
        alt="Mapa de ruas com os 300 locais de maior severidade (Azure Maps)")
    return pg


def pagina_dica_local() -> Pagina:
    pg = Pagina("tt_local", "Dica: local", tipo="Tooltip", oculta=True, largura=320, altura=240,
                extra={"pageBinding": {"name": "dica_local", "type": "Tooltip", "parameters": []}})
    pg.add("nome", 8, 6, 304, 58, texto_medida("Título do local", tam="11D", cor_txt=NAVY), alt="Nome do local")
    for i, (med, rot, c) in enumerate([("Sinistros", "Sinistros", NAVY), ("Mortos", "Mortos", RED), ("UPS", "UPS", AMBER)]):
        pg.add(f"card_{i + 1}", 8 + i * 102, 70, 96, 96, card(med, rot, cor_valor=c, tam="15D"))
    pg.add("pior_horario", 8, 174, 304, 58, texto_medida("Pior faixa horária", tam="11D", cor_txt="#1B1F2A", fundo="#FFF7E0"),
           alt="Faixa horária com mais sinistros no local")
    return pg


def gerar_mapa_fundo(destino: Path) -> None:
    """Desenha os limites das regionais (GeoJSON) em SVG, na mesma escala lon/lat dos eixos do mapa."""
    g = json.loads((RAIZ / "regionais_bh.geojson").read_text(encoding="utf-8"))
    xs, ys = [], []

    def pontos(c):
        if isinstance(c[0], (int, float)):
            xs.append(c[0]); ys.append(c[1])
        else:
            for k in c:
                pontos(k)
    for f in g["features"]:
        pontos(f["geometry"]["coordinates"])
    mx, my = (max(xs) - min(xs)) * 0.03, (max(ys) - min(ys)) * 0.02
    MAPA.update(lon0=round(min(xs) - mx, 5), lon1=round(max(xs) + mx, 5), lat0=round(min(ys) - my, 5), lat1=round(max(ys) + my, 5))
    import math
    k = math.cos(math.radians((MAPA["lat0"] + MAPA["lat1"]) / 2))
    W = 1000
    H = round(W * (MAPA["lat1"] - MAPA["lat0"]) / ((MAPA["lon1"] - MAPA["lon0"]) * k))
    px = lambda lon: (lon - MAPA["lon0"]) / (MAPA["lon1"] - MAPA["lon0"]) * W
    py = lambda lat: (MAPA["lat1"] - lat) / (MAPA["lat1"] - MAPA["lat0"]) * H
    partes = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
              f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>']
    rotulos_xy = []
    for f in g["features"]:
        polys = f["geometry"]["coordinates"] if f["geometry"]["type"] == "MultiPolygon" else [f["geometry"]["coordinates"]]
        d, maior, area_maior = [], None, -1
        for poly in polys:
            for anel in poly:
                d.append("M" + " L".join(f"{px(a):.1f},{py(b):.1f}" for a, b in anel) + " Z")
            anel = poly[0]
            area = 0.0; cx = cy = 0.0
            for (x1, y1), (x2, y2) in zip(anel, anel[1:] + anel[:1]):
                cr = x1 * y2 - x2 * y1
                area += cr; cx += (x1 + x2) * cr; cy += (y1 + y2) * cr
            if abs(area) > area_maior:
                area_maior, maior = abs(area), (cx / (3 * area), cy / (3 * area))
        partes.append(f'<path d="{" ".join(d)}" fill="#EEF2F9" stroke="#8EA9DB" stroke-width="2.5" fill-rule="evenodd"/>')
        rotulos_xy.append((f["properties"]["nome_regional"], px(maior[0]), py(maior[1])))
    for nome, x, y in rotulos_xy:
        partes.append(f'<text x="{x:.0f}" y="{y:.0f}" font-family="Segoe UI, Arial" font-size="30" font-weight="600" '
                      f'fill="#5B6B85" text-anchor="middle" opacity="0.75">{nome}</text>')
    partes.append("</svg>")
    destino.write_text("\n".join(partes), encoding="utf-8")


def tema() -> dict:
    return {
        "name": "Sinistros BH",
        "dataColors": [NAVY, AMBER, LIGHT, RED, SLATE, GREEN, "#C9A227", GREY, "#3E5C99", "#7A4E9C"],
        "good": GREEN, "bad": RED, "neutral": AMBER, "maximum": AMBER, "center": "#F3D27A", "minimum": "#FFFFFF",
        "foreground": "#1B1F2A", "foregroundNeutralSecondary": SLATE, "background": "#FFFFFF",
        "backgroundLight": "#F4F6FA", "tableAccent": NAVY,
        "textClasses": {
            "callout": {"fontFace": "Segoe UI Semibold", "fontSize": 26, "color": NAVY},
            "title": {"fontFace": "Segoe UI Semibold", "fontSize": 12, "color": NAVY},
            "header": {"fontFace": "Segoe UI Semibold", "fontSize": 11, "color": NAVY},
            "label": {"fontFace": "Segoe UI", "fontSize": 10, "color": "#1B1F2A"},
        },
        "visualStyles": {
            "*": {"*": {
                "background": [{"show": True, "color": {"solid": {"color": "#FFFFFF"}}, "transparency": 0}],
                "border": [{"show": True, "color": {"solid": {"color": "#DDE3EE"}}, "radius": 8}],
                "dropShadow": [{"show": False}],
                "padding": [{"top": 8, "bottom": 8, "left": 12, "right": 12}],
                "visualHeader": [{"show": True}],
            }},
            "page": {"*": {"background": [{"color": {"solid": {"color": "#F4F6FA"}}, "transparency": 0}],
                           "outspace": [{"color": {"solid": {"color": "#E9EDF4"}}, "transparency": 0}]}},
            "textbox": {"*": {"background": [{"show": False}], "border": [{"show": False}]}},
        },
    }


def gerar_relatorio() -> None:
    d = RP / "definition"
    sr = RP / "StaticResources"
    (sr / "RegisteredResources").mkdir(parents=True, exist_ok=True)
    gerar_mapa_fundo(sr / "RegisteredResources" / "mapa_regionais_bh.svg")
    paginas = [pagina_estrategica(), pagina_onde_quem(), pagina_quando_como(), pagina_onde_agir(),
               pagina_detalhe_local(), pagina_mapa_ruas()]
    (d / "pages").mkdir(parents=True, exist_ok=True)
    (RP / "definition.pbir").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
        "version": "4.0", "datasetReference": {"byPath": {"path": f"../{NOME}.SemanticModel"}}}, indent=2), encoding="utf-8")
    (d / "version.json").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",
        "version": "2.0.0"}, indent=2), encoding="utf-8")
    rv = {"visual": "2.1.0", "report": "3.0.0", "page": "2.0.0"}
    (d / "report.json").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/3.0.0/schema.json",
        "themeCollection": {"baseTheme": {"name": BASE_THEME, "reportVersionAtImport": rv, "type": "SharedResources"},
                            "customTheme": {"name": "SinistrosBH.json", "reportVersionAtImport": rv, "type": "RegisteredResources"}},
        "objects": {"outspacePane": [{"properties": {"expanded": lit("false"), "visible": lit("true")}}]},
        "resourcePackages": [
            {"name": "SharedResources", "type": "SharedResources",
             "items": [{"name": BASE_THEME, "path": f"BaseThemes/{BASE_THEME}.json", "type": "BaseTheme"}]},
            {"name": "RegisteredResources", "type": "RegisteredResources",
             "items": [{"name": "SinistrosBH.json", "path": "SinistrosBH.json", "type": "CustomTheme"},
                       {"name": "mapa_regionais_bh.svg", "path": "mapa_regionais_bh.svg", "type": "Image"}]}],
        "settings": {"useStylableVisualContainerHeader": True, "defaultFilterActionIsDataFilter": True,
                     "defaultDrillFilterOtherVisuals": True, "allowChangeFilterTypes": True,
                     "allowInlineExploration": True, "useEnhancedTooltips": True}}, indent=2, ensure_ascii=False), encoding="utf-8")
    (sr / "SharedResources" / "BaseThemes").mkdir(parents=True, exist_ok=True)
    (sr / "RegisteredResources").mkdir(parents=True, exist_ok=True)
    origem_tema = PBI_BASE_THEMES / f"{BASE_THEME}.json"
    if origem_tema.exists():
        shutil.copy(origem_tema, sr / "SharedResources" / "BaseThemes" / f"{BASE_THEME}.json")
    (sr / "RegisteredResources" / "SinistrosBH.json").write_text(json.dumps(tema(), indent=2, ensure_ascii=False), encoding="utf-8")
    (d / "pages" / "pages.json").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.0.0/schema.json",
        "pageOrder": [p.nome for p in paginas], "activePageName": paginas[0].nome}, indent=2), encoding="utf-8")
    for p in paginas:
        pd = d / "pages" / p.nome
        (pd / "visuals").mkdir(parents=True, exist_ok=True)
        versao_pg = "2.1.0" if p.tipo == "Tooltip" else "1.4.0"
        pj = {"$schema": f"https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/{versao_pg}/schema.json",
              "name": p.nome, "displayName": p.exibicao,
              "displayOption": "ActualSize" if p.tipo == "Tooltip" else "FitToPage",
              "height": p.altura, "width": p.largura}
        if p.tipo != "Default":
            pj["type"] = p.tipo
        if p.oculta:
            pj["visibility"] = "HiddenInViewMode"
        pj.update(p.extra)
        (pd / "page.json").write_text(json.dumps(pj, indent=2, ensure_ascii=False), encoding="utf-8")
        for v in p.visuais:
            vd = pd / "visuals" / v["name"]
            vd.mkdir(parents=True, exist_ok=True)
            (vd / "visual.json").write_text(json.dumps(v, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    for pasta in (SM / "definition", RP / "definition", RP / "StaticResources"):
        if pasta.exists():
            shutil.rmtree(pasta)
    gerar_modelo()
    gerar_relatorio()
    (RAIZ / f"{NOME}.pbip").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
        "version": "1.0", "artifacts": [{"report": {"path": f"{NOME}.Report"}}],
        "settings": {"enableAutoRecovery": True}}, indent=2), encoding="utf-8")
    n_vis = sum(1 for _ in (RP / "definition" / "pages").rglob("visual.json"))
    print(f"ok: {len(TABELAS)} tabelas, {len(RELACOES)} relacionamentos, {len(MEDIDAS)} medidas, {n_vis} visuais")


if __name__ == "__main__":
    main()
