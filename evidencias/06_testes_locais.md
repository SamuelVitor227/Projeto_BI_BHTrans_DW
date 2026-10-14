# Testes locais de ponta a ponta — 13/10/2026 22:03

Comando: `python -m etl.testes_locais` · duração: 4 min · **23 de 23 verificações aprovadas**

| # | Resultado | Verificação | Detalhe |
|---|---|---|---|
| 1 | ✅ | Ambiente: conexão ao banco por 127.0.0.1 com as credenciais do .env | PostgreSQL 16.9 (Debian 16.9-1.pgdg110+1... / PostGIS 3.5.2 |
| 2 | ✅ | Carga do zero (--recriar) termina com código 0 | 80s |
| 3 | ✅ | Log de carga: as 8 etapas registradas com SUCESSO em stg.log_carga | id_execucao=20261013220321: [('0-ddl', 'SUCESSO'), ('1-extrair', 'SUCESSO'), ('2-staging', 'SUCESSO'), ('3-transformar', 'SUCESSO'), ('4-testes_qualidade', 'SUCESSO'), ('5-carregar_dw', 'SUCESSO'), ('6-reconciliar', 'SUCESSO'), ('7-evidencias', 'SUCESSO')] |
| 4 | ✅ | Carga completa: fatos e dimensões populadas | {'fato_sinistro': 184728, 'fato_envolvido': 404957, 'fato_populacao': 153, 'dim_local': 22393, 'mv_taxa_mortalidade_anual': 14} |
| 5 | ✅ | Idempotência: 2ª execução (sem flags) termina com código 0 | 82s |
| 6 | ✅ | Idempotência: nenhum arquivo baixado de novo (nada mudou na origem) | extração comparou data de modificação e hash com o manifesto |
| 7 | ✅ | Idempotência: hashes da camada RAW inalterados | 111 arquivos |
| 8 | ✅ | Idempotência: dw idêntico ao da 1ª carga (contagens e md5 das fatos, dim_local e taxa anual) |  |
| 9 | ✅ | Opção --anos 2023-2024 termina com código 0 | 22s |
| 10 | ✅ | Opção --anos: dw contém só 2023 e 2024 | anos=[2023, 2024], sinistros=27152 |
| 11 | ✅ | Falha crítica interrompe a carga (FalhaCritica levantada) | 1 teste(s) CRÍTICO(s) falharam; a carga do dw foi interrompida: |
| 12 | ✅ | Teste de qualidade detecta população inconsistente (dado corrompido em transação desfeita) | regional 19 em 2024 alterada em +1 e revertida |
| 13 | ✅ | DDL (sql/ddl_data_warehouse.sql) não contém DML | [] |
| 14 | ✅ | Scripts de carga (sql/carga/) não contêm DDL | {} |
| 15 | ✅ | Carga completa final termina com código 0 | 76s |
| 16 | ✅ | Carga final idêntica à primeira (reprodutível) |  |
| 17 | ✅ | DDL roda do zero num banco vazio, é re-executável e gera a mesma estrutura | RESULTADO: APROVADO — o DDL roda do zero sem erros, é re-executável e gera a mesma estrutura do banco principal |
| 18 | ✅ | pg_dump --schema-only exportado | 303535 bytes |
| 19 | ✅ | Testes de qualidade: nenhum CRÍTICO reprovado | 40 testes; 0 reprovados (todos não críticos) |
| 20 | ✅ | COMMENT ON em todas as colunas de stg e dw | 0 sem comentário |
| 21 | ✅ | Consultas de negócio executadas e com resultado | 8 consultas; linhas: ['14', '9', '10', '10', '14', '7', '5', '7'] |
| 22 | ✅ | Evidências geradas | 7 arquivos |
| 23 | ✅ | docs/modelo_dimensional.md gerado com diagrama Mermaid |  |
