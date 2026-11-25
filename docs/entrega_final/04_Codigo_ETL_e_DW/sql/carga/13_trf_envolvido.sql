-- =============================================================================
-- 13 — TRANSFORMAR: pessoas envolvidas (stg.si_env -> stg.trf_envolvido)
--
-- Tipo de envolvimento:
--   1) indicadores da fonte: pedestre = S -> PEDESTRE; condutor = S/SIM -> CONDUTOR;
--      passageiro = S -> PASSAGEIRO (pedestre/passageiro só existem a partir de 2016);
--   2) regra derivada (2011–2015 e lacunas): não condutor, sem espécie de veículo e
--      boletim de atropelamento de pessoa (H06001/H06002) -> PEDESTRE; demais não
--      condutores -> PASSAGEIRO. Validada em 2016+ contra os indicadores:
--      precisão 99,2% e recall 92,7% para pedestres (ver README).
-- Espécie do veículo da pessoa: até 2016 os passageiros vêm sem espécie. Quando o
-- boletim tem uma única espécie de veículo, ela é atribuída à pessoa (regra
-- validada em 2017+: 100% de acerto em 11.605 passageiros). Depende de 12_trf_veiculo.
-- Vítima = severidade 1 (não fatal) ou 2 (fatal). Ileso (3) e não informado (0)
-- não são vítimas.
-- =============================================================================
TRUNCATE stg.trf_envolvido;

WITH env AS (
    SELECT e.*,
           btrim(e.numero_boletim) AS nb,
           CASE WHEN btrim(e.data_hora_boletim) ~ '^\d{2}/\d{2}/\d{4} \d{2}:\d{2}'
                THEN to_date(substr(btrim(e.data_hora_boletim), 1, 10), 'DD/MM/YYYY')
                     + substr(btrim(e.data_hora_boletim), 12, 5)::time
           END AS data_hora_env,
           upper(btrim(e.condutor))   AS cond,
           upper(btrim(e.pedestre))   AS ped,
           upper(btrim(e.passageiro)) AS pas,
           nullif(upper(btrim(e.especie_veiculo)), '') AS especie_origem
    FROM stg.si_env e
),
-- liga ao boletim; nos números repetidos no ano, também pela data/hora
ligado AS (
    SELECT env.*, b.numero_boletim_dw, b.ano, b.cod_tipo_sinistro,
           row_number() OVER (PARTITION BY b.numero_boletim_dw, b.ano, btrim(env.numero_envolvido)
                              ORDER BY env.linha_arquivo DESC) AS rn
    FROM env
    JOIN stg.trf_boletim b
      ON b.numero_boletim_origem = env.nb
     AND b.ano = env.ano_arquivo
     AND (b.qtd_eventos_numero = 1 OR b.data_hora = env.data_hora_env)
    WHERE btrim(env.numero_envolvido) ~ '^\d+$'
),
tipado AS (
    SELECT l.*,
           CASE
               WHEN l.ped = 'S'                     THEN 'PEDESTRE'
               WHEN l.cond IN ('S', 'SIM')          THEN 'CONDUTOR'
               WHEN l.pas = 'S'                     THEN 'PASSAGEIRO'
               WHEN l.cond IN ('N', 'NÃO') AND l.especie_origem IS NULL
                    AND l.cod_tipo_sinistro IN ('H06001', 'H06002') THEN 'PEDESTRE'
               WHEN l.cond IN ('N', 'NÃO')          THEN 'PASSAGEIRO'
               WHEN l.especie_origem IS NULL
                    AND l.cod_tipo_sinistro IN ('H06001', 'H06002') THEN 'PEDESTRE'
               ELSE 'NÃO INFORMADO'
           END AS tipo_envolvimento,
           CASE
               WHEN l.ped = 'S' OR l.cond IN ('S', 'SIM') OR l.pas = 'S' THEN 'INDICADOR DA FONTE'
               ELSE 'REGRA DERIVADA'
           END AS origem_tipo_envolvimento,
           CASE WHEN btrim(l.codigo_severidade) ~ '^[0-3]$' THEN btrim(l.codigo_severidade)::smallint ELSE 0 END AS cod_severidade,
           CASE WHEN btrim(l.idade) ~ '^\d+$' AND btrim(l.idade)::int BETWEEN 1 AND 110
                THEN btrim(l.idade)::smallint END AS idade_valida
    FROM ligado l
    WHERE l.rn = 1
),
-- boletins com uma única espécie de veículo (para imputar a espécie da pessoa)
especie_unica AS (
    SELECT numero_boletim_dw, ano, min(especie) AS especie, min(grupo_especie) AS grupo_especie
    FROM stg.trf_veiculo
    GROUP BY numero_boletim_dw, ano
    HAVING count(DISTINCT especie) = 1
),
com_especie AS (
    SELECT t.*,
           CASE WHEN t.tipo_envolvimento = 'PEDESTRE' THEN NULL
                WHEN t.especie_origem IS NOT NULL THEN coalesce(me.descricao, t.especie_origem)
                ELSE u.especie END AS especie_final,
           CASE WHEN t.tipo_envolvimento = 'PEDESTRE' THEN NULL
                WHEN t.especie_origem IS NOT NULL THEN coalesce(me.grupo, 'Outros')
                ELSE u.grupo_especie END AS grupo_final,
           CASE WHEN t.tipo_envolvimento = 'PEDESTRE' THEN 'NÃO SE APLICA (PEDESTRE)'
                WHEN t.especie_origem IS NOT NULL THEN 'INFORMADA NO BOLETIM'
                WHEN u.especie IS NOT NULL THEN 'IMPUTADA (ESPÉCIE ÚNICA NO BOLETIM)'
                ELSE 'NÃO INFORMADA' END AS origem_especie
    FROM tipado t
    LEFT JOIN stg.map_dominio me ON me.dominio = 'especie_veiculo' AND me.codigo = t.especie_origem
    LEFT JOIN especie_unica u ON u.numero_boletim_dw = t.numero_boletim_dw AND u.ano = t.ano
)
INSERT INTO stg.trf_envolvido (
    numero_boletim_dw, ano, numero_envolvido, tipo_envolvimento, origem_tipo_envolvimento,
    cod_severidade, gravidade, fl_vitima, fl_vitima_fatal, fl_condutor, fl_pedestre, fl_motociclista,
    sexo, idade, faixa_etaria, embriaguez, especie_veiculo, grupo_especie, origem_especie,
    arquivo_origem, linha_arquivo)
SELECT t.numero_boletim_dw,
       t.ano,
       btrim(t.numero_envolvido)::smallint,
       t.tipo_envolvimento,
       t.origem_tipo_envolvimento,
       t.cod_severidade,
       CASE t.cod_severidade WHEN 1 THEN 'NÃO FATAL' WHEN 2 THEN 'FATAL'
                             WHEN 3 THEN 'SEM FERIMENTOS' ELSE 'NÃO INFORMADA' END,
       t.cod_severidade IN (1, 2),
       t.cod_severidade = 2,
       t.tipo_envolvimento = 'CONDUTOR',
       t.tipo_envolvimento = 'PEDESTRE',
       t.tipo_envolvimento IN ('CONDUTOR', 'PASSAGEIRO') AND coalesce(t.grupo_final, '') = 'Motocicleta',
       coalesce(ms.descricao, 'NÃO INFORMADO'),
       t.idade_valida,
       CASE
           WHEN t.idade_valida IS NULL THEN 'Não informada'
           WHEN t.idade_valida <= 9  THEN '0 a 9 anos'
           WHEN t.idade_valida <= 17 THEN '10 a 17 anos'
           WHEN t.idade_valida <= 24 THEN '18 a 24 anos'
           WHEN t.idade_valida <= 29 THEN '25 a 29 anos'
           WHEN t.idade_valida <= 39 THEN '30 a 39 anos'
           WHEN t.idade_valida <= 49 THEN '40 a 49 anos'
           WHEN t.idade_valida <= 59 THEN '50 a 59 anos'
           WHEN t.idade_valida <= 69 THEN '60 a 69 anos'
           ELSE '70 anos ou mais'
       END,
       CASE upper(btrim(t.embriaguez)) WHEN 'SIM' THEN 'SIM' WHEN 'S' THEN 'SIM'
                                       WHEN 'NÃO' THEN 'NÃO' WHEN 'N' THEN 'NÃO'
                                       ELSE 'NÃO INFORMADO' END,
       t.especie_final,
       t.grupo_final,
       t.origem_especie,
       t.arquivo_origem,
       t.linha_arquivo
FROM com_especie t
LEFT JOIN stg.map_dominio ms ON ms.dominio = 'sexo' AND ms.codigo = upper(btrim(t.sexo));

ANALYZE stg.trf_envolvido;
