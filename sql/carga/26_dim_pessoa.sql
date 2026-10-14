-- =============================================================================
-- 26 — CARREGAR: dim_pessoa (perfil): produto cartesiano dos domínios
-- tipo de envolvimento x sexo x faixa etária x embriaguez.
-- O perfil em que tudo é "não informado" é o próprio membro -1.
-- =============================================================================
INSERT INTO dw.dim_pessoa (sk_pessoa, tipo_envolvimento, sexo, faixa_etaria, ordem_faixa_etaria, embriaguez, arquivo_origem)
OVERRIDING SYSTEM VALUE
VALUES (-1, 'NÃO INFORMADO', 'NÃO INFORMADO', 'Não informada', 10, 'NÃO INFORMADO', 'sql/carga/26_dim_pessoa.sql'),
       (-2, 'NÃO SE APLICA', 'NÃO SE APLICA', 'Não se aplica', 99, 'NÃO SE APLICA', 'sql/carga/26_dim_pessoa.sql');

INSERT INTO dw.dim_pessoa (tipo_envolvimento, sexo, faixa_etaria, ordem_faixa_etaria, embriaguez, arquivo_origem)
SELECT t.tipo, s.sexo, f.faixa, f.ordem, e.embriaguez, 'sql/carga/26_dim_pessoa.sql'
FROM (VALUES ('CONDUTOR', 1), ('PASSAGEIRO', 2), ('PEDESTRE', 3), ('NÃO INFORMADO', 4)) AS t (tipo, ot)
CROSS JOIN (VALUES ('MASCULINO', 1), ('FEMININO', 2), ('NÃO INFORMADO', 3)) AS s (sexo, os)
CROSS JOIN (VALUES ('0 a 9 anos', 1), ('10 a 17 anos', 2), ('18 a 24 anos', 3), ('25 a 29 anos', 4),
                   ('30 a 39 anos', 5), ('40 a 49 anos', 6), ('50 a 59 anos', 7), ('60 a 69 anos', 8),
                   ('70 anos ou mais', 9), ('Não informada', 10)) AS f (faixa, ordem)
CROSS JOIN (VALUES ('SIM', 1), ('NÃO', 2), ('NÃO INFORMADO', 3)) AS e (embriaguez, oe)
WHERE NOT (t.tipo = 'NÃO INFORMADO' AND s.sexo = 'NÃO INFORMADO'
           AND f.faixa = 'Não informada' AND e.embriaguez = 'NÃO INFORMADO')
ORDER BY t.ot, s.os, f.ordem, e.oe;
