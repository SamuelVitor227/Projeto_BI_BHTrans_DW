# Guia do Power BI — DW de sinistros de trânsito de BH

Este guia leva do banco PostgreSQL ao modelo pronto no Power BI Desktop. O banco já vem preparado: o schema **`bi`** traz o mesmo modelo estrela do `dw`, mas sem os tipos que o Power BI não lê. Esta pasta tem as medidas DAX e os polígonos das regionais para os mapas.

| Arquivo | Para que serve |
|---|---|
| `medidas.dax` | 34 medidas (sinistros, vítimas, mortos, taxas por 100 mil hab., meta 2030, pedestres e motociclistas), coladas de uma vez no Power BI |
| `regionais_bh_topojson.json` | polígonos das 9 regionais para o visual **Mapa de formas** |
| `regionais_bh.geojson` | os mesmos polígonos para a camada de referência do visual **Azure Maps** |

Os dois arquivos de mapa são gerados de novo a cada `python -m etl.carga_inicial`, ou sozinhos com `python -m etl.powerbi`.

## Por que existe o schema `bi`

O conector PostgreSQL do Power BI tem quatro limitações que atrapalhariam o uso direto do `dw`:

1. **Não lê colunas `geometry` do PostGIS.** As views do `bi` não têm geometria. Os pontos vêm como `latitude`/`longitude`, e os polígonos estão nos arquivos desta pasta.
2. **Não lista views materializadas no Navegador.** Os indicadores prontos do `dw` aparecem no `bi` como views comuns (`ind_*`).
3. **A `dw.dim_tempo` tem 25 linhas por dia (24 horas + "Sem hora")**, então não pode ser marcada como tabela de datas. No `bi` ela foi dividida em `dim_calendario` (1 linha por dia, 2010–2030) e `dim_hora` (0–23 e 99 = "Não informada"). As fatos trazem as colunas `data` e `hora` para esses relacionamentos.
4. **As partições das fatos (17 por fato) poluem o Navegador.** No `bi` cada fato é uma view só.

Além disso, a `bi.fato_envolvido` traz o tipo de sinistro e a condição da via do boletim. Assim dá para analisar pessoas por tipo de sinistro e por clima sem criar relacionamento entre as duas fatos.

## 1. Antes de abrir o Power BI

1. Instale o **Power BI Desktop** (gratuito, pela Microsoft Store). Ele não está instalado nesta máquina.
2. Suba o banco: na pasta do projeto, rode `docker compose up -d` e espere o container ficar `healthy` (`docker compose ps`).
3. Tenha à mão o usuário e a senha do arquivo `.env` (`POSTGRES_USER` e `POSTGRES_PASSWORD`).

## 2. Conectar ao banco

1. **Página Inicial → Obter dados → Mais... → Banco de dados PostgreSQL**.
2. Servidor: `127.0.0.1:5432` · Banco de dados: `dw_sinistros_bh` · Modo: **Importar**.
3. Credenciais: aba **Banco de dados**, com o usuário e a senha do `.env`.
4. O banco local não usa SSL. Se o Power BI avisar que não conseguiu uma conexão criptografada, clique em **OK** para conectar sem criptografia. É seguro aqui, porque a porta só aceita conexões da própria máquina (127.0.0.1). Se o aviso não aparecer e a conexão falhar, vá em **Arquivo → Opções e configurações → Configurações da fonte de dados → Editar permissões** e desmarque **Criptografar conexões**.

## 3. Escolher as tabelas

No Navegador, marque **só as views do schema `bi`**:

- Dimensões: `bi.dim_calendario`, `bi.dim_hora`, `bi.dim_local`, `bi.dim_regional`, `bi.dim_tipo_sinistro`, `bi.dim_condicao_via`, `bi.dim_veiculo`, `bi.dim_pessoa`
- Fatos: `bi.fato_sinistro`, `bi.fato_envolvido`, `bi.fato_populacao`
- Opcional, indicadores prontos para conferência: `bi.ind_taxa_mortalidade_anual`, `bi.ind_regional_ano`, `bi.ind_ranking_locais`, `bi.ind_participacao_vitimas_ano`

Não marque as tabelas do `dw`, porque as que têm geometria dão erro no Power BI. Clique em **Carregar**. São cerca de 700 mil linhas no total, e a carga leva menos de um minuto.

## 4. Ajustes do modelo (uma vez só)

**4.1 Nomes das tabelas.** Se as tabelas vierem como `bi fato_sinistro`, renomeie para `fato_sinistro`, `dim_calendario` etc. Para isso, clique duas vezes no nome no painel **Dados**. As medidas DAX usam esses nomes.

**4.2 Data/hora automática.** Em **Arquivo → Opções e configurações → Opções → Arquivo atual → Carregamento de dados**, desmarque **Data/hora automática**. O calendário do projeto substitui as tabelas de data ocultas.

**4.3 Relacionamentos.** Na **Exibição de modelo**, deixe exatamente estes 16 relacionamentos. Todos são **muitos para um (\*:1)**, com direção de filtro **única**. Apague qualquer outro que o Power BI tenha criado sozinho, por exemplo pelas colunas `ano` ou `numero_boletim`, ou ligando as tabelas `ind_*`.

| Fato (lado muitos) | Dimensão (lado um) |
|---|---|
| `fato_sinistro[data]` | `dim_calendario[data]` |
| `fato_sinistro[hora]` | `dim_hora[hora]` |
| `fato_sinistro[sk_local]` | `dim_local[sk_local]` |
| `fato_sinistro[sk_tipo_sinistro]` | `dim_tipo_sinistro[sk_tipo_sinistro]` |
| `fato_sinistro[sk_condicao_via]` | `dim_condicao_via[sk_condicao_via]` |
| `fato_sinistro[sk_regional]` | `dim_regional[sk_regional]` |
| `fato_envolvido[data]` | `dim_calendario[data]` |
| `fato_envolvido[hora]` | `dim_hora[hora]` |
| `fato_envolvido[sk_local]` | `dim_local[sk_local]` |
| `fato_envolvido[sk_tipo_sinistro]` | `dim_tipo_sinistro[sk_tipo_sinistro]` |
| `fato_envolvido[sk_condicao_via]` | `dim_condicao_via[sk_condicao_via]` |
| `fato_envolvido[sk_pessoa]` | `dim_pessoa[sk_pessoa]` |
| `fato_envolvido[sk_veiculo]` | `dim_veiculo[sk_veiculo]` |
| `fato_envolvido[sk_regional]` | `dim_regional[sk_regional]` |
| `fato_populacao[data]` | `dim_calendario[data]` |
| `fato_populacao[sk_regional]` | `dim_regional[sk_regional]` |

As tabelas `ind_*` ficam soltas, sem relacionamento. Servem para conferir números e para visuais simples.

**4.4 Tabela de datas.** Selecione `dim_calendario` → **Ferramentas de tabela → Marcar como tabela de datas** → coluna `data`.

**4.5 Classificar por coluna.** Sem isso, os meses e os dias da semana aparecem em ordem alfabética. Selecione a coluna e use **Ferramentas de coluna → Classificar por coluna**:

| Tabela | Coluna | Classificar por |
|---|---|---|
| `dim_calendario` | `nome_mes`, `nome_mes_abrev` | `mes` |
| `dim_calendario` | `nome_dia_semana`, `nome_dia_semana_abrev` | `dia_semana` |
| `dim_calendario` | `ano_mes` | `ano_mes_ordem` |
| `dim_hora` | `hora_texto` | `hora` |
| `dim_hora` | `periodo_dia` | `ordem_periodo_dia` |
| `dim_pessoa` | `faixa_etaria` | `ordem_faixa_etaria` |
| `dim_tipo_sinistro` | `descricao` | `ordem` |

**4.6 Categorias e resumo.**
- Em `fato_sinistro`, `dim_local` e `dim_regional`, marque `latitude` como **Categoria de dados → Latitude** e `longitude` como **Longitude**.
- Nas colunas `sk_*`, `ano`, `hora`, `cod_*`, `numero_boletim` e `numero_envolvido`, use **Resumo → Não resumir**.
- Oculte as colunas `sk_*`, `data` e `hora` das fatos (botão direito → **Ocultar no modo de exibição de relatório**). Assim, nos visuais, use sempre os campos das dimensões.

## 5. Medidas DAX

1. Abra o **Modo de exibição de consulta DAX**, o quarto ícone da barra lateral esquerda.
2. Cole todo o conteúdo de `medidas.dax` e clique em **Executar**.
3. Clique em **Atualizar modelo com alterações**. As 34 medidas passam a aparecer nas tabelas `fato_sinistro`, `fato_envolvido` e `fato_populacao`.
4. Formate as medidas, selecionando cada uma e usando **Ferramentas de medida**:
   - medidas que começam com `%` e as `Var. %` → **Porcentagem**, 1 casa;
   - taxas, meta e distância → **Decimal**, 2 casas;
   - as demais → **Número inteiro** com separador de milhar.

**Conferência.** A tabela que a consulta devolve deve bater com estes valores, que também estão em `bi.ind_taxa_mortalidade_anual`:

| Ano | Sinistros | Vítimas | Mortos | População | Taxa de mortos /100 mil | Meta 2030 | Distância | % vítimas pedestres | % vítimas motociclistas |
|---|---|---|---|---|---|---|---|---|---|
| 2014 | 14.965 | 18.477 | 177 | 2.491.109 | 7,11 | 3,55 | 3,55 | 12,88% | 48,37% |
| 2019 | 13.342 | 15.870 | 105 | 2.512.070 | 4,18 | 3,55 | 0,63 | 10,91% | 63,82% |
| 2024 | 13.266 | 15.927 | 159 | 2.416.339 | 6,58 | 3,55 | 3,03 | 8,55% | 73,27% |

Num cartão sem filtro de ano, `Taxa de mortos por 100 mil hab.` deve dar **5,83**. Esse valor é a taxa média anual de 2011 a 2024: 2.007 mortos sobre a soma das populações dos 14 anos.

**Duas famílias de medidas.** `Vítimas` e `Mortos` (fato_sinistro) dão os mesmos totais que `Vítimas (pessoas)` e `Mortos (pessoas)` (fato_envolvido). A reconciliação garante isso. Use as de `fato_sinistro` com tipo de sinistro, condição da via e local. Use as de `fato_envolvido` com `dim_pessoa` (pedestre, sexo, faixa etária) e `dim_veiculo` (espécie), que só se ligam a essa fato.

## 6. Mapas

**Pontos críticos e mapa de calor (visual Azure Maps).**
- Use `dim_local[latitude]` e `dim_local[longitude]`, que são cerca de 20 mil locais com o ponto representativo, e coloque `Sinistros`, `Mortos` ou `UPS` no tamanho da bolha. Para o mapa de calor, ative a camada **Mapa de calor**.
- Para pontos exatos, use `fato_sinistro[latitude]`/`[longitude]`. São cerca de 164 mil boletins geolocalizados; os demais têm coordenada nula e ficam fora do mapa.
- Com dezenas de milhares de pontos, os visuais de mapa passam a mostrar uma amostra. Filtre por ano ou regional, ou prefira os locais.

**Regionais coloridas por indicador (visual Mapa de formas).**
1. Ative o visual em **Arquivo → Opções e configurações → Opções → Recursos de visualização → Visual de mapa de formas**, e reinicie o Power BI.
2. Insira o visual. Em **Local**, use `dim_regional[nome_regional]`; em **Saturação da cor**, use uma medida, por exemplo `Taxa de mortos por 100 mil hab.`.
3. Em **Formatar → Configurações do mapa → Tipo de mapa → Mapa personalizado**, carregue `regionais_bh_topojson.json`. O arquivo casa com a dimensão pelo nome da regional (ex.: `CENTRO-SUL`).

**Contorno das regionais no Azure Maps.** Em **Formatar → Camada de referência**, carregue `regionais_bh.geojson`.

## 7. Sugestão de páginas (perguntas da Fase 1)

| Pergunta | Visual | Campos |
|---|---|---|
| Evolução da taxa por 100 mil e distância para a meta | Gráfico de linhas | eixo `dim_calendario[ano]`; valores `Taxa de mortos por 100 mil hab.` e `Meta 2030`; cartão com `Distância para a meta` |
| Regionais de maior risco ajustado pela população | Barras ou Mapa de formas | `dim_regional[nome_regional]`; `Taxa de mortos por 100 mil hab.` e `Taxa de vítimas por 100 mil hab.` |
| Pedestres e motociclistas nas vítimas | Colunas 100% ou linhas | `dim_calendario[ano]`; `% vítimas pedestres`, `% vítimas motociclistas` |
| Tipos de sinistro que mais crescem e os mais letais | Barras | `dim_tipo_sinistro[grupo_tipo_sinistro]`; `Var. % sinistros vs ano anterior`, `Mortos por 1.000 sinistros` |
| Distribuição por mês, dia da semana e faixa horária | Matriz (mapa de calor) | linhas `dim_hora[faixa_horaria]`; colunas `dim_calendario[nome_dia_semana_abrev]`; valor `Sinistros` |
| Clima e pavimento × ocorrência e severidade | Colunas agrupadas | `dim_condicao_via[grupo_chuva]` com filtro de `origem_clima`; `Mortos por 1.000 sinistros` |
| Ranking de logradouros e cruzamentos | Tabela | `dim_local[descricao_local_atual]`, `fl_cruzamento`; `Sinistros`, `Mortos`, `UPS` |
| Pontos críticos no mapa | Azure Maps | ver seção 6 |
| Perfil dos veículos por local | Barras empilhadas | `dim_local[descricao_local_atual]`; `qtd_motocicletas`, `qtd_automoveis`, `qtd_onibus` etc. de `fato_sinistro` (somar) |

## 8. Cuidados na leitura (limitações do README)

- **População com degraus em 2022 e 2024.** As estimativas do IBGE de 2011–2021 são anteriores ao Censo 2022, e as de 2024+ incorporam ajustes. Parte da variação da taxa nesses anos é metodológica. Vale uma anotação no gráfico.
- **Clima.** Compare "com chuva × sem chuva" **dentro da mesma `origem_clima`**, nunca misturando declarado com imputado pelo INMET. Os boletins com clima declarado têm severidade maior por viés de preenchimento.
- **"Não informado".** Os membros "Não informado" e "Não se aplica" (chaves -1 e -2) aparecem nos visuais. Filtre-os quando for o caso, por exemplo a regional "NÃO INFORMADA", com 0,6% dos boletins.
- **Taxa em períodos menores que um ano.** Com filtro de mês, a taxa usa a população anual. Fica correta como "mortos no período por 100 mil hab.", mas não é comparável à taxa anual.
- **Motociclistas em 2011–2016** estão subestimados, e o **tipo de envolvimento em 2011–2015** é derivado (ver README, seção 5).

## 9. Atualizar os dados

Com o banco no ar, clique em **Página Inicial → Atualizar** depois de cada `python -m etl.carga_inicial`. As chaves são reprodutíveis, então os relacionamentos e as medidas continuam valendo. Para publicar no Power BI Service com atualização automática, seria preciso um gateway de dados apontando para o banco, o que fica fora do escopo desta fase.
