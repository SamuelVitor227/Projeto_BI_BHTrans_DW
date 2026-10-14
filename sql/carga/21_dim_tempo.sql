-- =============================================================================
-- 21 — CARREGAR: dim_tempo (2010–2030, grão data + hora)
-- sk_tempo = AAAAMMDDHH; um membro "Sem hora" por dia (HH = 99) para boletins
-- com hora não informada e para a fato_populacao (1º de julho).
-- =============================================================================
INSERT INTO dw.dim_tempo (sk_tempo, nome_mes, nome_dia_semana, fl_hora_informada, faixa_horaria, periodo_dia, arquivo_origem)
VALUES (-1, 'Não informado', 'Não informado', false, 'Não informado', 'Não informado', 'sql/carga/21_dim_tempo.sql'),
       (-2, 'Não se aplica', 'Não se aplica', false, 'Não se aplica', 'Não se aplica', 'sql/carga/21_dim_tempo.sql');

INSERT INTO dw.dim_tempo (sk_tempo, data, ano, semestre, trimestre, mes, nome_mes, ano_mes, dia,
                          dia_semana, nome_dia_semana, fl_fim_de_semana, hora, fl_hora_informada,
                          faixa_horaria, periodo_dia, arquivo_origem)
SELECT to_char(d, 'YYYYMMDD')::int * 100 + coalesce(h.hora, 99),
       d::date,
       extract(year FROM d)::smallint,
       CASE WHEN extract(month FROM d) <= 6 THEN 1 ELSE 2 END,
       extract(quarter FROM d)::smallint,
       extract(month FROM d)::smallint,
       (ARRAY['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto',
              'Setembro', 'Outubro', 'Novembro', 'Dezembro'])[extract(month FROM d)::int],
       to_char(d, 'YYYY-MM'),
       extract(day FROM d)::smallint,
       extract(isodow FROM d)::smallint,
       (ARRAY['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira',
              'Sábado', 'Domingo'])[extract(isodow FROM d)::int],
       extract(isodow FROM d) IN (6, 7),
       h.hora,
       h.hora IS NOT NULL,
       CASE WHEN h.hora IS NULL THEN 'Hora não informada'
            ELSE lpad((h.hora / 3 * 3)::text, 2, '0') || 'h–' || lpad((h.hora / 3 * 3 + 2)::text, 2, '0') || 'h' END,
       CASE WHEN h.hora IS NULL THEN 'Hora não informada'
            WHEN h.hora < 6  THEN 'Madrugada'
            WHEN h.hora < 12 THEN 'Manhã'
            WHEN h.hora < 18 THEN 'Tarde'
            ELSE 'Noite' END,
       'sql/carga/21_dim_tempo.sql'
-- TIMESTAMP sem fuso: com DATE, o generate_series vira timestamptz e, no fuso de
-- São Paulo, a meia-noite inexistente do início do horário de verão desloca a série
-- para 01:00, o que deixava 31/12/2030 de fora.
FROM generate_series(TIMESTAMP '2010-01-01', TIMESTAMP '2030-12-31', INTERVAL '1 day') AS d
CROSS JOIN (SELECT generate_series(0, 23)::smallint AS hora UNION ALL SELECT NULL::smallint) AS h;
