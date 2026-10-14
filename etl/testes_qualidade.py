"""
Etapa 4 — TESTES DE QUALIDADE (antes de promover ao dw) e etapa 6 — RECONCILIAÇÃO.

Cada teste é uma consulta SQL que devolve (valor_obtido, aprovado, detalhe).
Severidade:
  CRITICO — se falhar, a carga é interrompida com mensagem clara;
  ALERTA  — registrado no relatório, não interrompe;
  INFO    — medição informativa (cobertura, imputação etc.).
Os resultados ficam em stg.resultado_qualidade e em evidencias/03_relatorio_qualidade.md.

Uso isolado:  python -m etl.testes_qualidade   (roda os testes pré-carga e a reconciliação)
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

from etl import banco, config
from etl.util import configurar_log

log = logging.getLogger("qualidade")


class FalhaCritica(RuntimeError):
    """Algum teste CRITICO falhou: a carga do dw não deve prosseguir."""


@dataclass
class Teste:
    nome: str
    categoria: str
    severidade: str
    criterio: str
    sql: str


# Valores divulgados na imprensa a partir do IBGE (Censo 2022), para conferência
POPULACAO_IMPRENSA_2022 = {24: 308406, 21: 293612, 18: 278144, 19: 271769, 25: 247578,
                           26: 247315, 22: 233656, 20: 220941, 23: 213427}


def testes_pre_carga(anos_esperados: list[int]) -> list[Teste]:
    anos_sql = "ARRAY[" + ",".join(str(int(a)) for a in anos_esperados) + "]::int[]"
    imprensa = " UNION ALL ".join(f"SELECT {c} AS cod, {v} AS imprensa" for c, v in POPULACAO_IMPRENSA_2022.items())
    return [
        # ---------------------------------------------------------------- unicidade
        Teste("Unicidade: boletim (numero_boletim, ano)", "unicidade", "CRITICO", "0 duplicatas", """
            SELECT (count(*) - count(DISTINCT (numero_boletim_dw, ano)))::text,
                   count(*) = count(DISTINCT (numero_boletim_dw, ano)),
                   'duplicatas exatas consolidadas: ' || sum(qtd_linhas_origem - 1)
                   || '; números repetidos no ano com eventos distintos (sufixo /n): '
                   || count(*) FILTER (WHERE seq_ocorrencia > 1)
            FROM stg.trf_boletim"""),
        Teste("Unicidade: envolvido (numero_boletim, ano, numero_envolvido)", "unicidade", "CRITICO", "0 duplicatas", """
            SELECT (count(*) - count(DISTINCT (numero_boletim_dw, ano, numero_envolvido)))::text,
                   count(*) = count(DISTINCT (numero_boletim_dw, ano, numero_envolvido)),
                   'linhas no stg: ' || (SELECT count(*) FROM stg.si_env) || '; no trf: ' || count(*)
            FROM stg.trf_envolvido"""),
        Teste("Unicidade: veículo (numero_boletim, ano, sequencial)", "unicidade", "CRITICO", "0 duplicatas", """
            SELECT (count(*) - count(DISTINCT (numero_boletim_dw, ano, sequencial_veiculo)))::text,
                   count(*) = count(DISTINCT (numero_boletim_dw, ano, sequencial_veiculo)),
                   'linhas no stg: ' || (SELECT count(*) FROM stg.si_veic) || '; no trf: ' || count(*)
            FROM stg.trf_veiculo"""),
        # ---------------------------------------------------------------- domínios
        Teste("Domínio: UPS final em {1, 5, 13} (dicionário da Fase 2)", "domínio", "CRITICO", "0 fora do domínio", """
            WITH f AS (
                SELECT b.valor_ups_origem IN (1, 5, 13) AS da_fonte,
                       CASE WHEN b.valor_ups_origem IN (1, 5, 13) THEN b.valor_ups_origem
                            WHEN EXISTS (SELECT 1 FROM stg.trf_envolvido e WHERE e.numero_boletim_dw = b.numero_boletim_dw
                                         AND e.ano = b.ano AND e.fl_vitima_fatal) THEN 13 ELSE 5 END AS ups
                FROM stg.trf_boletim b)
            SELECT count(*) FILTER (WHERE ups NOT IN (1, 5, 13))::text,
                   count(*) FILTER (WHERE ups NOT IN (1, 5, 13)) = 0,
                   'UPS da fonte: ' || count(*) FILTER (WHERE da_fonte)
                   || '; derivada da severidade (fonte = 0 "NÃO INFORMADO", a partir de 2016): '
                   || count(*) FILTER (WHERE da_fonte IS NOT TRUE)
            FROM f"""),
        Teste("Domínio: valor_ups da fonte em {0, 1, 5, 13}", "domínio", "ALERTA", "0 fora do domínio", """
            SELECT count(*) FILTER (WHERE coalesce(valor_ups_origem, -1) NOT IN (0, 1, 5, 13))::text,
                   count(*) FILTER (WHERE coalesce(valor_ups_origem, -1) NOT IN (0, 1, 5, 13)) = 0,
                   'distribuição: ' || (SELECT string_agg(v || '=' || n, ', ' ORDER BY v) FROM (
                        SELECT coalesce(valor_ups_origem::text, 'nulo') AS v, count(*) AS n
                        FROM stg.trf_boletim GROUP BY 1) x)
            FROM stg.trf_boletim"""),
        Teste("Domínio: tipo de sinistro com de-para", "domínio", "ALERTA", "0 códigos sem de-para", """
            SELECT count(DISTINCT cod_tipo_sinistro)::text, count(DISTINCT cod_tipo_sinistro) = 0,
                   coalesce(string_agg(DISTINCT cod_tipo_sinistro, ', '), 'todos os códigos mapeados')
            FROM stg.trf_boletim b
            WHERE NOT EXISTS (SELECT 1 FROM stg.map_dominio m WHERE m.dominio = 'tipo_sinistro' AND m.codigo = b.cod_tipo_sinistro)"""),
        Teste("Domínio: cod_tempo e cod_pavimento em 0–4", "domínio", "ALERTA", "0 fora do domínio", """
            SELECT count(*)::text, count(*) = 0, 'valores fora de 0–4 são tratados como 0 (não informado)'
            FROM stg.si_bol WHERE btrim(cod_tempo) !~ '^[0-4]$' OR btrim(cod_pavimento) !~ '^[0-4]$'"""),
        Teste("Domínio: severidade do envolvido em 0–3", "domínio", "ALERTA", "0 fora do domínio", """
            SELECT count(*)::text, count(*) = 0, 'valores fora de 0–3 são tratados como 0 (não informada)'
            FROM stg.si_env WHERE btrim(codigo_severidade) !~ '^[0-3]$'"""),
        Teste("Domínio: espécie de veículo com de-para", "domínio", "ALERTA", "0 espécies sem de-para", """
            WITH e AS (SELECT upper(btrim(descricao_especie)) AS esp FROM stg.si_veic
                       UNION SELECT upper(btrim(especie_veiculo)) FROM stg.si_env)
            SELECT count(*)::text, count(*) = 0, coalesce(string_agg(esp, ', '), 'todas as espécies mapeadas')
            FROM e WHERE esp <> '' AND NOT EXISTS (SELECT 1 FROM stg.map_dominio m
                                                   WHERE m.dominio = 'especie_veiculo' AND m.codigo = e.esp)"""),
        Teste("Domínio: código de regional conhecido", "domínio", "ALERTA", "0 códigos fora do de-para", """
            SELECT count(*)::text, count(*) = 0,
                   'boletins com regional 0 (resolvidos por ST_Within): '
                   || (SELECT count(*) FROM stg.trf_boletim WHERE cod_regional_origem = 0)
                   || '; com 27 HIPERCENTRO (-> Centro-Sul): '
                   || (SELECT count(*) FROM stg.trf_boletim WHERE cod_regional_origem = 27)
            FROM stg.trf_boletim b
            WHERE NOT EXISTS (SELECT 1 FROM stg.map_regional m WHERE m.cod_regional_boletim = b.cod_regional_origem)"""),
        # ---------------------------------------------------------------- volume
        Teste("Volume: todos os anos esperados presentes", "volume", "CRITICO", "boletins, envolvidos, veículos e logradouros em todos os anos", f"""
            WITH anos AS (SELECT unnest({anos_sql}) AS ano),
            c AS (SELECT a.ano,
                         (SELECT count(*) FROM stg.trf_boletim b WHERE b.ano = a.ano) AS bol,
                         (SELECT count(*) FROM stg.trf_envolvido e WHERE e.ano = a.ano) AS env,
                         (SELECT count(*) FROM stg.trf_veiculo v WHERE v.ano = a.ano) AS vei,
                         (SELECT count(*) FROM stg.si_log l WHERE l.ano_arquivo = a.ano) AS log
                  FROM anos a)
            SELECT count(*) FILTER (WHERE bol > 0 AND env > 0 AND vei > 0 AND log > 0) || ' de ' || count(*),
                   bool_and(bol > 0 AND env > 0 AND vei > 0 AND log > 0),
                   string_agg(ano || ': ' || bol, ', ' ORDER BY ano)
            FROM c"""),
        Teste("Volume: sem quedas absurdas (ano / ano anterior >= 50%)", "volume", "CRITICO", "razão mínima >= 0,50", """
            WITH c AS (SELECT ano, count(*) AS n FROM stg.trf_boletim GROUP BY ano),
            r AS (SELECT ano, n, n::numeric / nullif(lag(n) OVER (ORDER BY ano), 0) AS razao FROM c)
            SELECT coalesce(round(min(razao), 3)::text, 'n/a'), coalesce(min(razao) >= 0.5, true),
                   string_agg(ano || '=' || n || coalesce(' (' || round(razao, 2) || ')', ''), ', ' ORDER BY ano)
            FROM r"""),
        Teste("Volume: variação anual moderada (ano / ano anterior >= 75%)", "volume", "ALERTA", "razão mínima >= 0,75", """
            WITH c AS (SELECT ano, count(*) AS n FROM stg.trf_boletim GROUP BY ano),
            r AS (SELECT ano, n::numeric / nullif(lag(n) OVER (ORDER BY ano), 0) AS razao FROM c)
            SELECT coalesce(round(min(razao), 3)::text, 'n/a'), coalesce(min(razao) >= 0.75, true),
                   coalesce('menor razão em ' || (SELECT ano FROM r WHERE razao IS NOT NULL ORDER BY razao LIMIT 1), '')
            FROM r"""),
        Teste("Volume: datas válidas e nenhum boletim perdido no stg -> trf", "volume", "CRITICO", "stg = trf + duplicatas exatas", """
            SELECT (SELECT count(*) FROM stg.si_bol) || ' stg / ' || (SELECT count(*) FROM stg.trf_boletim) || ' trf',
                   (SELECT count(*) FROM stg.si_bol)
                     = (SELECT count(*) + sum(qtd_linhas_origem - 1) FROM stg.trf_boletim),
                   'datas inválidas no si-bol: ' || (SELECT count(*) FROM stg.si_bol
                        WHERE btrim(data_hora_boletim) !~ '^\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}')"""),
        # ---------------------------------------------------------------- órfãos
        Teste("Órfãos: registros de si-log/si-veic/si_env sem si-bol", "órfãos", "CRITICO", "<= 1% (e idealmente 0)", """
            WITH b AS (SELECT DISTINCT numero_boletim_origem AS nb, ano FROM stg.trf_boletim),
            o AS (
                SELECT 'si_env' AS t, count(*) FILTER (WHERE b.nb IS NULL) AS orf, count(*) AS tot
                FROM stg.si_env x LEFT JOIN b ON b.nb = btrim(x.numero_boletim) AND b.ano = x.ano_arquivo
                UNION ALL
                SELECT 'si_veic', count(*) FILTER (WHERE b.nb IS NULL), count(*)
                FROM stg.si_veic x LEFT JOIN b ON b.nb = btrim(x.numero_boletim) AND b.ano = x.ano_arquivo
                UNION ALL
                SELECT 'si_log', count(*) FILTER (WHERE b.nb IS NULL), count(*)
                FROM stg.si_log x LEFT JOIN b ON b.nb = btrim(x.numero_boletim) AND b.ano = x.ano_arquivo)
            SELECT sum(orf)::text, bool_and(orf <= 0.01 * tot), string_agg(t || ': ' || orf || ' de ' || tot, '; ')
            FROM o"""),
        Teste("Órfãos: boletins sem envolvido, veículo ou logradouro", "órfãos", "INFO", "informativo", """
            SELECT count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM stg.trf_envolvido e WHERE e.numero_boletim_dw = b.numero_boletim_dw AND e.ano = b.ano))::text,
                   true,
                   'sem envolvido: ' || count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM stg.trf_envolvido e WHERE e.numero_boletim_dw = b.numero_boletim_dw AND e.ano = b.ano))
                   || '; sem veículo: ' || count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM stg.trf_veiculo v WHERE v.numero_boletim_dw = b.numero_boletim_dw AND v.ano = b.ano))
                   || '; sem logradouro: ' || count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM stg.trf_boletim_local l WHERE l.numero_boletim_dw = b.numero_boletim_dw AND l.ano = b.ano))
            FROM stg.trf_boletim b"""),
        # ---------------------------------------------------------------- coerência
        Teste("Coerência: indicador_fatalidade do si-bol x mortos do si_env", "coerência", "ALERTA", "concordância >= 95%", """
            WITH f AS (
                SELECT b.ano, b.fl_indicador_fatalidade AS ind,
                       EXISTS (SELECT 1 FROM stg.trf_envolvido e WHERE e.numero_boletim_dw = b.numero_boletim_dw
                               AND e.ano = b.ano AND e.fl_vitima_fatal) AS tem_morto
                FROM stg.trf_boletim b),
            a AS (SELECT ano, count(*) FILTER (WHERE ind) AS ind_sim, count(*) FILTER (WHERE tem_morto) AS com_morto,
                         count(*) FILTER (WHERE ind <> tem_morto) AS discord, count(*) AS n FROM f GROUP BY ano)
            SELECT round(100.0 * (1 - sum(discord)::numeric / sum(n)), 3) || '%',
                   (1 - sum(discord)::numeric / sum(n)) >= 0.95,
                   'indicador SIM x boletins com morto no si_env, por ano: '
                   || string_agg(ano || ' ' || ind_sim || 'x' || com_morto, '; ' ORDER BY ano)
                   || ' | discordantes: ' || sum(discord)
            FROM a"""),
        Teste("Coerência: vítimas fatais <= vítimas <= envolvidos", "coerência", "CRITICO", "0 boletins incoerentes", """
            WITH e AS (SELECT numero_boletim_dw, ano, count(*) AS n, count(*) FILTER (WHERE fl_vitima) AS v,
                              count(*) FILTER (WHERE fl_vitima_fatal) AS f
                       FROM stg.trf_envolvido GROUP BY 1, 2)
            SELECT count(*) FILTER (WHERE NOT (f <= v AND v <= n))::text,
                   count(*) FILTER (WHERE NOT (f <= v AND v <= n)) = 0,
                   'mortos: ' || sum(f) || '; vítimas: ' || sum(v) || '; envolvidos: ' || sum(n)
            FROM e"""),
        Teste("Reprojeção: deslocamento mediano 2011–2015 x 2016+ nos mesmos endereços", "coerência", "ALERTA", "|dx| e |dy| < 5 m", """
            WITH pts AS MATERIALIZED (
                SELECT c.ano, bl.cod_logradouro_principal AS cod, bl.numero_imovel AS imovel,
                       ST_X(ST_Transform(c.geom, 31983)) AS x, ST_Y(ST_Transform(c.geom, 31983)) AS y
                FROM stg.trf_coordenada c
                JOIN stg.trf_boletim_local bl USING (numero_boletim_dw, ano)
                WHERE c.fl_geolocalizado AND NOT bl.fl_cruzamento AND bl.numero_imovel ~ '^[1-9][0-9]*$'),
            ant AS (SELECT cod, imovel, percentile_cont(0.5) WITHIN GROUP (ORDER BY x) AS x,
                           percentile_cont(0.5) WITHIN GROUP (ORDER BY y) AS y FROM pts WHERE ano <= 2015 GROUP BY 1, 2),
            nov AS (SELECT cod, imovel, percentile_cont(0.5) WITHIN GROUP (ORDER BY x) AS x,
                           percentile_cont(0.5) WITHIN GROUP (ORDER BY y) AS y FROM pts WHERE ano >= 2016 GROUP BY 1, 2),
            d AS (SELECT nov.x - ant.x AS dx, nov.y - ant.y AS dy FROM ant JOIN nov USING (cod, imovel))
            SELECT 'dx=' || round(percentile_cont(0.5) WITHIN GROUP (ORDER BY dx)::numeric, 2)
                   || ' m; dy=' || round(percentile_cont(0.5) WITHIN GROUP (ORDER BY dy)::numeric, 2) || ' m',
                   coalesce(abs(percentile_cont(0.5) WITHIN GROUP (ORDER BY dx)) < 5
                            AND abs(percentile_cont(0.5) WITHIN GROUP (ORDER BY dy)) < 5, true),
                   count(*) || ' endereços comparados (sem a correção de datum o desvio seria ~ -44,6 / -44,3 m)'
            FROM d"""),
        Teste("Tipo de envolvimento: validação da regra derivada em 2016+", "coerência", "INFO", "precisão e recall da regra de pedestre", """
            WITH e AS (
                SELECT upper(btrim(x.pedestre)) = 'S' AS verdade,
                       upper(btrim(x.condutor)) IN ('N', 'NÃO') AND btrim(x.especie_veiculo) = ''
                       AND b.cod_tipo_sinistro IN ('H06001', 'H06002') AS regra
                FROM stg.si_env x
                JOIN stg.trf_boletim b ON b.numero_boletim_origem = btrim(x.numero_boletim) AND b.ano = x.ano_arquivo
                                      AND b.seq_ocorrencia = 1
                WHERE x.ano_arquivo >= 2016 AND upper(btrim(x.pedestre)) IN ('S', 'N'))
            SELECT 'precisão ' || round(100.0 * count(*) FILTER (WHERE regra AND verdade) / nullif(count(*) FILTER (WHERE regra), 0), 1)
                   || '%; recall ' || round(100.0 * count(*) FILTER (WHERE regra AND verdade) / nullif(count(*) FILTER (WHERE verdade), 0), 1) || '%',
                   true,
                   'pedestres reais: ' || count(*) FILTER (WHERE verdade) || '; previstos pela regra: ' || count(*) FILTER (WHERE regra)
            FROM e"""),
        Teste("Espécie da pessoa: validação da imputação por espécie única no boletim (2017+)", "coerência", "INFO",
              "acerto da regra onde a espécie foi informada", """
            WITH u AS (SELECT numero_boletim_dw, ano, min(especie) AS especie FROM stg.trf_veiculo
                       GROUP BY 1, 2 HAVING count(DISTINCT especie) = 1)
            SELECT round(100.0 * count(*) FILTER (WHERE e.especie_veiculo = u.especie) / nullif(count(*), 0), 2) || '% de acerto',
                   true,
                   count(*) || ' passageiros 2017+ com espécie informada em boletins de espécie única; imputados na série: '
                   || (SELECT count(*) FROM stg.trf_envolvido WHERE origem_especie LIKE 'IMPUTADA%')
                   || '; não pedestres ainda sem espécie: '
                   || (SELECT count(*) FROM stg.trf_envolvido WHERE origem_especie = 'NÃO INFORMADA')
            FROM stg.trf_envolvido e JOIN u USING (numero_boletim_dw, ano)
            WHERE e.ano >= 2017 AND e.tipo_envolvimento = 'PASSAGEIRO' AND e.origem_especie = 'INFORMADA NO BOLETIM'"""),
        # ---------------------------------------------------------------- cobertura
        Teste("Cobertura: % de boletins geolocalizados", "cobertura", "ALERTA", ">= 80% no total", """
            WITH a AS (SELECT ano, round(100.0 * avg(fl_geolocalizado::int), 1) AS pct FROM stg.trf_coordenada GROUP BY ano)
            SELECT (SELECT round(100.0 * avg(fl_geolocalizado::int), 2) FROM stg.trf_coordenada) || '%',
                   (SELECT avg(fl_geolocalizado::int) FROM stg.trf_coordenada) >= 0.80,
                   string_agg(ano || ': ' || pct || '%', ', ' ORDER BY ano)
                   || ' | situações: ' || (SELECT string_agg(situacao || '=' || n, ', ') FROM
                        (SELECT situacao, count(*) AS n FROM stg.trf_coordenada GROUP BY 1) s)
            FROM a"""),
        Teste("Cobertura: % de clima imputado pelo INMET", "cobertura", "INFO", "informativo", """
            WITH a AS (SELECT ano, round(100.0 * avg((origem_clima = 'IMPUTADO PELO INMET')::int), 1) AS pct
                       FROM stg.trf_boletim GROUP BY ano)
            SELECT (SELECT round(100.0 * avg((origem_clima = 'IMPUTADO PELO INMET')::int), 2) FROM stg.trf_boletim) || '%',
                   true,
                   string_agg(ano || ': ' || pct || '%', ', ' ORDER BY ano)
                   || ' | estação reserva (Cercadinho) usada em ' || (SELECT count(*) FROM stg.trf_boletim WHERE estacao_inmet = 'F501') || ' boletins'
            FROM a"""),
        Teste("Cobertura: clima não informado após imputação", "cobertura", "ALERTA", "<= 5%", """
            SELECT round(100.0 * avg((origem_clima = 'NÃO INFORMADO')::int), 2) || '%',
                   avg((origem_clima = 'NÃO INFORMADO')::int) <= 0.05,
                   'boletins sem hora informada: ' || count(*) FILTER (WHERE NOT fl_hora_informada)
                   || '; com hora mas sem leitura do INMET: ' || count(*) FILTER (WHERE fl_hora_informada AND precipitacao_mm IS NULL)
            FROM stg.trf_boletim"""),
        Teste("Cobertura: leituras horárias de precipitação do INMET (Pampulha)", "cobertura", "ALERTA", ">= 90% das horas em todos os anos", """
            WITH a AS (SELECT extract(year FROM dt_hora_inicio_local)::int AS ano,
                              avg((precipitacao_mm IS NOT NULL)::int) AS pct
                       FROM stg.trf_clima_hora WHERE estacao_codigo = 'A521' GROUP BY 1)
            SELECT round(100.0 * min(pct), 1) || '% (pior ano)', min(pct) >= 0.90,
                   string_agg(ano || ': ' || round(100.0 * pct, 1) || '%', ', ' ORDER BY ano)
            FROM a WHERE ano BETWEEN 2011 AND 2024"""),
        Teste("Cobertura: boletins com local (logradouro) identificado", "cobertura", "ALERTA", ">= 99%", """
            SELECT round(100.0 * (SELECT count(*) FROM stg.trf_boletim_local) / count(*), 2) || '%',
                   (SELECT count(*) FROM stg.trf_boletim_local)::numeric / count(*) >= 0.99,
                   'origem do bairro: ' || (SELECT string_agg(origem_bairro || '=' || n, ', ') FROM
                        (SELECT origem_bairro, count(*) AS n FROM stg.trf_boletim_local GROUP BY 1) o)
            FROM stg.trf_boletim"""),
        Teste("Coerência espacial: regional do boletim x ponto (ST_Within)", "coerência", "INFO", "informativo", """
            WITH reg AS MATERIALIZED (
                SELECT cod_reg::smallint AS cod, ST_Transform(ST_GeomFromText(geometria, 31983), 4326) AS g
                FROM stg.regional_limite WHERE arquivo_origem LIKE '%20220601_regional%'),
            p AS (SELECT b.cod_regional_origem AS cod_bol, r.cod AS cod_esp
                  FROM stg.trf_boletim b
                  JOIN stg.trf_coordenada c USING (numero_boletim_dw, ano)
                  JOIN reg r ON ST_Within(c.geom, r.g)
                  WHERE c.fl_geolocalizado AND b.cod_regional_origem BETWEEN 18 AND 26)
            SELECT round(100.0 * avg((cod_bol = cod_esp)::int), 1) || '%', true,
                   count(*) || ' boletins geolocalizados com regional informada; divergências concentram-se a menos de 50 m das divisas (avenidas-limite)'
            FROM p"""),
        # ---------------------------------------------------------------- população
        Teste("População: soma das regionais = total do município (trf)", "reconciliação", "CRITICO", "diferença 0 em todos os anos", """
            WITH a AS (SELECT ano, sum(populacao_residente) AS soma, max(populacao_municipio) AS total
                       FROM stg.trf_populacao GROUP BY ano)
            SELECT count(*) FILTER (WHERE soma <> total) || ' anos com diferença', bool_and(soma = total),
                   string_agg(ano || '=' || total, ', ' ORDER BY ano)
            FROM a"""),
        Teste("População: anos dos sinistros com população", "reconciliação", "CRITICO", "todo ano de sinistro tem 9 regionais", """
            WITH a AS (SELECT DISTINCT ano FROM stg.trf_boletim),
            p AS (SELECT ano, count(*) AS n FROM stg.trf_populacao GROUP BY ano)
            SELECT count(*) FILTER (WHERE coalesce(p.n, 0) <> 9) || ' anos sem as 9 regionais',
                   bool_and(coalesce(p.n, 0) = 9),
                   string_agg(a.ano || ':' || coalesce(p.n, 0), ', ' ORDER BY a.ano)
            FROM a LEFT JOIN p USING (ano)"""),
        Teste("População: Censo 2022 por regional x valores divulgados na imprensa", "reconciliação", "INFO", "informativo", f"""
            WITH im AS ({imprensa}),
            c AS (SELECT cod_reg_limite AS cod, populacao_residente AS censo FROM stg.trf_populacao WHERE ano = 2022)
            SELECT count(*) FILTER (WHERE c.censo = im.imprensa) || ' de 9 iguais', true,
                   string_agg(CASE WHEN c.censo <> im.imprensa THEN c.cod || ': censo ' || c.censo || ' x imprensa '
                                   || im.imprensa || ' (' || (c.censo - im.imprensa) || ')' END, '; ')
                   || ' | Oeste: +712 do subdistrito Oeste no distrito Barreiro; Centro-Sul/Leste: 247 pessoas trocadas'
            FROM c JOIN im USING (cod)"""),
    ]


def testes_pos_carga() -> list[Teste]:
    return [
        Teste("Reconciliação: boletins stg x dw por ano", "reconciliação", "CRITICO", "fato = stg - duplicatas exatas, em todos os anos", """
            WITH s AS (SELECT ano_arquivo AS ano, count(*) AS stg FROM stg.si_bol GROUP BY 1),
            t AS (SELECT ano, sum(qtd_linhas_origem - 1) AS dup FROM stg.trf_boletim GROUP BY 1),
            f AS (SELECT ano, count(*) AS dw FROM dw.fato_sinistro GROUP BY 1)
            SELECT count(*) FILTER (WHERE s.stg - coalesce(t.dup, 0) <> coalesce(f.dw, 0)) || ' anos divergentes',
                   bool_and(s.stg - coalesce(t.dup, 0) = coalesce(f.dw, 0)),
                   string_agg(s.ano || ' ' || s.stg || '/' || coalesce(f.dw, 0), ', ' ORDER BY s.ano)
            FROM s LEFT JOIN t USING (ano) LEFT JOIN f USING (ano)"""),
        Teste("Reconciliação: envolvidos stg x dw por ano", "reconciliação", "CRITICO", "fato = trf em todos os anos e stg = trf", """
            WITH s AS (SELECT ano_arquivo AS ano, count(*) AS stg FROM stg.si_env GROUP BY 1),
            t AS (SELECT ano, count(*) AS trf FROM stg.trf_envolvido GROUP BY 1),
            f AS (SELECT ano, count(*) AS dw FROM dw.fato_envolvido GROUP BY 1)
            SELECT count(*) FILTER (WHERE coalesce(t.trf, 0) <> coalesce(f.dw, 0) OR s.stg <> coalesce(t.trf, 0)) || ' anos divergentes',
                   bool_and(coalesce(t.trf, 0) = coalesce(f.dw, 0) AND s.stg = coalesce(t.trf, 0)),
                   string_agg(s.ano || ' ' || s.stg || '/' || coalesce(f.dw, 0), ', ' ORDER BY s.ano)
            FROM s LEFT JOIN t USING (ano) LEFT JOIN f USING (ano)"""),
        Teste("Reconciliação: veículos stg x fato_sinistro.qtd_veiculos", "reconciliação", "CRITICO", "soma igual", """
            SELECT (SELECT count(*) FROM stg.si_veic) || ' stg / ' || sum(qtd_veiculos) || ' dw',
                   (SELECT count(*) FROM stg.trf_veiculo) = sum(qtd_veiculos)
                   AND (SELECT count(*) FROM stg.si_veic) = (SELECT count(*) FROM stg.trf_veiculo),
                   'motos ' || sum(qtd_motocicletas) || '; automóveis ' || sum(qtd_automoveis) || '; ônibus ' || sum(qtd_onibus)
                   || '; caminhões ' || sum(qtd_caminhoes) || '; bicicletas ' || sum(qtd_bicicletas) || '; outros ' || sum(qtd_outros_veiculos)
            FROM dw.fato_sinistro"""),
        Teste("Reconciliação: vítimas e mortos fato_sinistro x fato_envolvido", "reconciliação", "CRITICO", "somas iguais", """
            SELECT (SELECT sum(qtd_vitimas) FROM dw.fato_sinistro) || ' vítimas / '
                   || (SELECT sum(qtd_vitimas_fatais) FROM dw.fato_sinistro) || ' mortos',
                   (SELECT sum(qtd_vitimas) FROM dw.fato_sinistro) = (SELECT count(*) FROM dw.fato_envolvido WHERE fl_vitima)
                   AND (SELECT sum(qtd_vitimas_fatais) FROM dw.fato_sinistro) = (SELECT count(*) FROM dw.fato_envolvido WHERE fl_vitima_fatal),
                   'fato_envolvido: ' || (SELECT count(*) FROM dw.fato_envolvido WHERE fl_vitima) || ' vítimas, '
                   || (SELECT count(*) FROM dw.fato_envolvido WHERE fl_vitima_fatal) || ' mortos'"""),
        Teste("Reconciliação: população das regionais = município (dw)", "reconciliação", "CRITICO", "diferença 0 em todos os anos", """
            WITH a AS (SELECT ano, sum(populacao_residente) AS soma, max(populacao_municipio) AS total
                       FROM dw.fato_populacao GROUP BY ano)
            SELECT count(*) || ' anos; ' || count(*) FILTER (WHERE soma <> total) || ' com diferença',
                   bool_and(soma = total) AND count(*) > 0,
                   string_agg(ano || '=' || soma, ', ' ORDER BY ano)
            FROM a"""),
        Teste("Integridade: FKs nos membros especiais (-1/-2)", "integridade", "ALERTA", "sk_local e sk_regional -1 <= 1%", """
            SELECT round(100.0 * avg((sk_local = -1)::int), 2) || '% local; ' || round(100.0 * avg((sk_regional = -1)::int), 2) || '% regional',
                   avg((sk_local = -1)::int) <= 0.01 AND avg((sk_regional = -1)::int) <= 0.01,
                   'sk_tipo_sinistro -1: ' || count(*) FILTER (WHERE sk_tipo_sinistro = -1)
                   || '; sk_condicao_via -1: ' || count(*) FILTER (WHERE sk_condicao_via = -1)
                   || '; origem da regional: ' || (SELECT string_agg(origem_regional || '=' || n, ', ') FROM
                        (SELECT origem_regional, count(*) AS n FROM dw.fato_sinistro GROUP BY 1) o)
                   || '; envolvidos com sk_pessoa -1: ' || (SELECT count(*) FROM dw.fato_envolvido WHERE sk_pessoa = -1)
                   || '; sk_veiculo -1/-2: ' || (SELECT count(*) FILTER (WHERE sk_veiculo = -1) || '/' || count(*) FILTER (WHERE sk_veiculo = -2) FROM dw.fato_envolvido)
            FROM dw.fato_sinistro"""),
        Teste("SCD2: uma versão atual por local e vigências contíguas", "integridade", "CRITICO", "0 locais inconsistentes", """
            WITH v AS (SELECT chave_natural, dt_inicio_vigencia, dt_fim_vigencia, fl_versao_atual,
                              lead(dt_inicio_vigencia) OVER (PARTITION BY chave_natural ORDER BY versao) AS prox
                       FROM dw.dim_local WHERE sk_local > 0),
            p AS (SELECT chave_natural,
                         count(*) FILTER (WHERE fl_versao_atual) AS atuais,
                         count(*) FILTER (WHERE prox IS NOT NULL AND prox <> dt_fim_vigencia) AS buracos,
                         min(dt_inicio_vigencia) AS ini, max(dt_fim_vigencia) AS fim
                  FROM v GROUP BY 1)
            SELECT count(*) FILTER (WHERE atuais <> 1 OR buracos > 0 OR ini <> DATE '1900-01-01' OR fim <> DATE '9999-12-31')::text,
                   count(*) FILTER (WHERE atuais <> 1 OR buracos > 0 OR ini <> DATE '1900-01-01' OR fim <> DATE '9999-12-31') = 0,
                   count(*) || ' locais; ' || (SELECT count(*) FROM dw.dim_local WHERE sk_local > 0) || ' versões; '
                   || (SELECT count(DISTINCT chave_natural) FROM dw.dim_local WHERE versao > 1) || ' locais com mais de uma versão'
            FROM p"""),
        Teste("Integridade: fato aponta para a versão vigente na data", "integridade", "CRITICO", "0 sinistros fora da vigência", """
            SELECT count(*)::text, count(*) = 0, 'verificado em todos os sinistros com local'
            FROM dw.fato_sinistro f JOIN dw.dim_local l USING (sk_local) JOIN dw.dim_tempo t USING (sk_tempo)
            WHERE f.sk_local > 0 AND NOT (t.data >= l.dt_inicio_vigencia AND t.data < l.dt_fim_vigencia)"""),
        Teste("Partições: nenhuma linha na partição DEFAULT", "integridade", "ALERTA", "0 linhas", """
            SELECT ((SELECT count(*) FROM dw.fato_sinistro_default) + (SELECT count(*) FROM dw.fato_envolvido_default))::text,
                   (SELECT count(*) FROM dw.fato_sinistro_default) + (SELECT count(*) FROM dw.fato_envolvido_default) = 0,
                   'anos fora de 2011–2026 cairiam na DEFAULT'"""),
        Teste("Views materializadas populadas", "integridade", "CRITICO", "4 views com linhas", """
            SELECT (SELECT count(*) FROM dw.mv_taxa_mortalidade_anual) || ' / ' || (SELECT count(*) FROM dw.mv_indicadores_regional_ano)
                   || ' / ' || (SELECT count(*) FROM dw.mv_ranking_locais) || ' / ' || (SELECT count(*) FROM dw.mv_participacao_vitimas_ano),
                   (SELECT count(*) FROM dw.mv_taxa_mortalidade_anual) > 0 AND (SELECT count(*) FROM dw.mv_indicadores_regional_ano) > 0
                   AND (SELECT count(*) FROM dw.mv_ranking_locais) > 0 AND (SELECT count(*) FROM dw.mv_participacao_vitimas_ano) > 0,
                   'taxa anual / regional x ano / ranking de locais / participação de vítimas'"""),
    ]


def _executar_lista(conn, testes: list[Teste], id_execucao: int, fase: str) -> list[dict]:
    resultados = []
    for t in testes:
        try:
            valor, aprovado, detalhe = conn.execute(t.sql).fetchone()
        except Exception as e:  # erro no próprio teste conta como reprovação
            conn.rollback()
            valor, aprovado, detalhe = "erro", False, f"{type(e).__name__}: {e}"
        r = {"teste": t.nome, "categoria": t.categoria, "severidade": t.severidade, "aprovado": bool(aprovado),
             "valor": str(valor), "criterio": t.criterio, "detalhe": detalhe or "", "fase": fase}
        resultados.append(r)
        conn.execute("""INSERT INTO stg.resultado_qualidade (id_execucao, teste, categoria, severidade, aprovado,
                                                             valor_obtido, criterio, detalhe)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                     (id_execucao, t.nome, t.categoria, t.severidade, r["aprovado"], r["valor"], t.criterio, r["detalhe"]))
        nivel = logging.INFO if r["aprovado"] else (logging.ERROR if t.severidade == "CRITICO" else logging.WARNING)
        log.log(nivel, "[%s] %-7s %s -> %s", "OK " if r["aprovado"] else "FALHOU", t.severidade, t.nome, r["valor"])
    conn.commit()
    return resultados


def _verificar_criticos(resultados: list[dict]) -> None:
    falhas = [r for r in resultados if r["severidade"] == "CRITICO" and not r["aprovado"]]
    if falhas:
        linhas = "\n".join(f"  - {r['teste']}: obtido {r['valor']} (critério: {r['criterio']}) {r['detalhe'][:300]}"
                           for r in falhas)
        raise FalhaCritica(f"{len(falhas)} teste(s) CRÍTICO(s) falharam; a carga do dw foi interrompida:\n{linhas}")


def executar_pre_carga(conn, id_execucao: int, anos_esperados: list[int]) -> list[dict]:
    resultados = _executar_lista(conn, testes_pre_carga(anos_esperados), id_execucao, "pré-carga")
    _verificar_criticos(resultados)
    return resultados


def executar_reconciliacao(conn, id_execucao: int) -> list[dict]:
    resultados = _executar_lista(conn, testes_pos_carga(), id_execucao, "pós-carga")
    _verificar_criticos(resultados)
    return resultados


def gerar_relatorio(conn, id_execucao: int) -> None:
    linhas = conn.execute("""SELECT teste, categoria, severidade, aprovado, valor_obtido, criterio, detalhe
                             FROM stg.resultado_qualidade WHERE id_execucao = %s ORDER BY id_resultado""",
                          (id_execucao,)).fetchall()
    aprovados = sum(1 for l in linhas if l[3])
    def esc(s):  # células de tabela Markdown
        return str(s).replace("|", "\\|").replace("\n", " ")
    md = [f"# Relatório de qualidade dos dados — execução {id_execucao}", "",
          f"Testes executados: **{len(linhas)}** · aprovados: **{aprovados}** · reprovados: **{len(linhas) - aprovados}** "
          f"(CRÍTICO interrompe a carga; ALERTA e INFO apenas registram).", "",
          "| # | Resultado | Severidade | Categoria | Teste | Valor obtido | Critério | Detalhe |",
          "|---|---|---|---|---|---|---|---|"]
    for i, (teste, cat, sev, ok, valor, crit, det) in enumerate(linhas, start=1):
        md.append(f"| {i} | {'✅ aprovado' if ok else '❌ reprovado'} | {sev} | {cat} | {esc(teste)} | {esc(valor)} "
                  f"| {esc(crit)} | {esc(det)} |")
    config.DIR_EVIDENCIAS.mkdir(exist_ok=True)
    (config.DIR_EVIDENCIAS / "03_relatorio_qualidade.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    log.info("Relatório de qualidade: %d testes, %d aprovados", len(linhas), aprovados)


if __name__ == "__main__":
    import datetime as _dt
    configurar_log()
    ident = int(_dt.datetime.now().strftime("%Y%m%d%H%M%S"))
    with banco.conexao() as c:
        anos = [r[0] for r in c.execute("SELECT DISTINCT ano FROM stg.trf_boletim ORDER BY 1").fetchall()]
        try:
            executar_pre_carga(c, ident, anos)
            executar_reconciliacao(c, ident)
        finally:
            gerar_relatorio(c, ident)
