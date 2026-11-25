-- =============================================================================
-- 10 — TRANSFORMAR: boletins (stg.si_bol -> stg.trf_boletim)
-- Tipagem, "não informado" explícito, deduplicação por (numero_boletim, ano) e
-- desambiguação de números repetidos no mesmo ano que são eventos distintos.
-- =============================================================================
TRUNCATE stg.trf_boletim;

WITH base AS (
    SELECT btrim(numero_boletim)                                       AS numero_boletim_origem,
           ano_arquivo                                                  AS ano,
           -- data/hora sem fuso (evita deslocar horários inexistentes no horário de verão)
           CASE WHEN btrim(data_hora_boletim) ~ '^\d{2}/\d{2}/\d{4} \d{2}:\d{2}'
                THEN to_date(substr(btrim(data_hora_boletim), 1, 10), 'DD/MM/YYYY')
                     + substr(btrim(data_hora_boletim), 12, 5)::time
           END                                                          AS data_hora,
           upper(btrim(hora_informada)) IN ('SIM', 'S')                 AS fl_hora_informada,
           btrim(tipo_acidente)                                         AS cod_tipo_sinistro,
           CASE WHEN btrim(cod_tempo) ~ '^[0-4]$' THEN btrim(cod_tempo)::smallint ELSE 0 END         AS cod_tempo,
           CASE WHEN btrim(cod_pavimento) ~ '^[0-4]$' THEN btrim(cod_pavimento)::smallint ELSE 0 END AS cod_pavimento,
           CASE upper(btrim(local_sinalizado))
                WHEN 'SIM' THEN 'SIM' WHEN 'S' THEN 'SIM'
                WHEN 'NÃO' THEN 'NÃO' WHEN 'N' THEN 'NÃO'
                ELSE 'NÃO INFORMADO'
           END                                                          AS local_sinalizado,
           CASE WHEN btrim(cod_regional) ~ '^\d+$' THEN btrim(cod_regional)::smallint ELSE 0 END    AS cod_regional_origem,
           CASE WHEN btrim(velocidade_permitida) ~ '^\d+$'
                     AND btrim(velocidade_permitida)::int BETWEEN 10 AND 120
                THEN btrim(velocidade_permitida)::smallint
           END                                                          AS velocidade_permitida,
           CASE WHEN btrim(valor_ups) ~ '^\d+$' THEN btrim(valor_ups)::smallint END                AS valor_ups_origem,
           upper(btrim(indicador_fatalidade)) IN ('SIM', 'S')           AS fl_indicador_fatalidade,
           nullif(replace(btrim(coordenada_x), ',', '.'), '')::numeric(14,2) AS coordenada_x_origem,
           nullif(replace(btrim(coordenada_y), ',', '.'), '')::numeric(14,2) AS coordenada_y_origem,
           CASE WHEN btrim(data_inclusao) ~ '^\d{2}/\d{2}/\d{4}'
                THEN to_date(substr(btrim(data_inclusao), 1, 10), 'DD/MM/YYYY')
           END                                                          AS data_inclusao,
           arquivo_origem,
           linha_arquivo
    FROM stg.si_bol
),
-- duplicatas exatas (mesmo número, ano e data/hora): fica a de inclusão mais recente
dedup AS (
    SELECT b.*,
           count(*)     OVER (PARTITION BY numero_boletim_origem, ano, data_hora) AS qtd_linhas_origem,
           row_number() OVER (PARTITION BY numero_boletim_origem, ano, data_hora
                              ORDER BY data_inclusao DESC NULLS LAST, linha_arquivo DESC) AS rn
    FROM base b
    WHERE data_hora IS NOT NULL
),
-- mesmo número no mesmo ano com data/hora diferente = eventos distintos
eventos AS (
    SELECT d.*,
           row_number() OVER (PARTITION BY numero_boletim_origem, ano ORDER BY data_hora, linha_arquivo) AS seq_ocorrencia,
           count(*)     OVER (PARTITION BY numero_boletim_origem, ano)                                AS qtd_eventos_numero
    FROM dedup d
    WHERE rn = 1
)
INSERT INTO stg.trf_boletim (
    numero_boletim_dw, ano, numero_boletim_origem, seq_ocorrencia, data_hora, data, hora,
    fl_hora_informada, cod_tipo_sinistro, cod_tempo, cod_pavimento, local_sinalizado,
    cod_regional_origem, velocidade_permitida, valor_ups_origem, fl_indicador_fatalidade,
    coordenada_x_origem, coordenada_y_origem, qtd_linhas_origem, qtd_eventos_numero,
    arquivo_origem, linha_arquivo)
SELECT CASE WHEN seq_ocorrencia = 1 THEN numero_boletim_origem
            ELSE numero_boletim_origem || '/' || seq_ocorrencia END,
       ano, numero_boletim_origem, seq_ocorrencia, data_hora, data_hora::date,
       CASE WHEN fl_hora_informada THEN extract(hour FROM data_hora)::smallint END,
       fl_hora_informada, cod_tipo_sinistro, cod_tempo, cod_pavimento, local_sinalizado,
       cod_regional_origem, velocidade_permitida, valor_ups_origem, fl_indicador_fatalidade,
       coordenada_x_origem, coordenada_y_origem, qtd_linhas_origem, qtd_eventos_numero,
       arquivo_origem, linha_arquivo
FROM eventos;

ANALYZE stg.trf_boletim;
