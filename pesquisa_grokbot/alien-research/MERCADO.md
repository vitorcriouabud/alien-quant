# Como o mercado realmente se comporta: estudo descritivo, mitos e robô de confluência

Mercados: **XAUUSD, EURUSD, GBPUSD, US500, NAS100, DE40**. Tempos gráficos: M1, M5, M15, H1, H4 e D1.
Dados: Dukascopy bid/ask. M1 de 2021-01 a 2026-11-13 (DE40 só tem H1, desde 2015). H1 de 2015 a 2026 para 8 símbolos.
Método: **2021–2025 (ou 2015–2025) é o período de estudo, e 2026 é conferido separado** (fora da amostra).
Custos: estilo RoboForex. Ida e volta em pontos-base (bp = 0,01%): XAU 1,2, EUR 0,9, GBP 1,25, US500 1,1, NAS 1,6, DE40 1,5. Swap entra quando a posição dorme.
Código: `code/mercado/` (study.py, myths.py, published.py, confluence.py, ldn_ny.py). Números brutos: `out/mercado/*.csv`.

> **Correção de dados feita nesta fase:** o M1 da Dukascopy traz barras "paradas" (de enchimento) no fim de semana, entre 16% e 24% das barras. Isso inflava a estatística "NY reverte Londres" (dava 0,41; o valor real é cerca de 0,49). Removi essas barras e rodei tudo de novo, inclusive os testes antigos.
> - Grid V1 do ouro: continua sem nada (melhor +0,06R; correlação entre período de estudo e 2026 = 0,08).
> - Grid SMC: continua com **0 sobreviventes**. Média por trade entre −0,18R e −0,24R. Walk-forward somado = −0,36R por trade.
> - As conclusões de RESULTS.md e RESULTS_V2.md não mudam.

---

## Resumo em 10 linhas

1. **No intradiário, o mercado é praticamente aleatório.** O pouco que existe é uma leve tendência a **voltar** (reversão à média), e é menor que o custo.
2. **No diário, os índices revertem com força.** Um dia de queda forte tende a ser seguido de alta. Esse é o **único efeito grande e estável** encontrado (RSI2/IBS, já validado no V2).
3. **Volatilidade é previsível; direção não é.** Hora agitada é seguida de hora agitada, e o horário de NY (09–11h) tem 3 a 4 vezes o movimento da Ásia. Isso serve para **tamanho de posição e horário**, não para saber se compra ou vende.
4. **Sweeps de liquidez, FVG, order block, BOS/CHoCH, números redondos e confluência entre tempos gráficos não mostram vantagem.** Batem como moeda (45–55%), mesmo **sem custo**.
5. **Indicadores clássicos** (RSI, MACD, Estocástico, Bollinger, médias, divergências, Fibonacci, pivots, VWAP e padrões de candle) **não funcionam depois do custo** nos gráficos de 15 minutos e de 1 hora.
6. **Efeitos de calendário** (segunda-feira nos índices dos EUA, virada do mês, véspera de feriado, véspera de FOMC) aparecem, mas são **fracos**. Juntos dão um sinal positivo nos dois períodos que ainda não é estatisticamente sólido.
7. **Um robô de "confluência máxima" (H4→M1) fica PIOR a cada filtro.** Cada filtro corta trades sem melhorar o resultado. A versão com tudo junto perdeu em 2026: 8 trades, 8 perdas somando os dois índices.

---

## 1. Tendência ou reversão?

| Medida | O que achei | Comparado ao custo |
|---|---|---|
| Autocorrelação da barra seguinte (M1–H1) | −0,01 a −0,03 (o mais forte foi GBP M15, −0,029): leve reversão | Equivale a uma fração de 1bp. Custo ≈ 1bp. **Não paga.** |
| Variance ratio 8 barras (FX intradiário) | 0,92–0,95, abaixo de 1, ou seja, reversão | Pequeno demais |
| Depois de 3 velas da mesma cor, a 4ª continua? | **47–49%** no intradiário, ou seja, um pouco mais de reversão | Nenhuma vantagem |
| Índices no D1 (variance ratio 8) | **0,67–0,85**: reversão diária forte | **É o efeito explorável** (RSI2/IBS) |
| Índices no H4 | Continua 50–54% | Pequeno |

**Em português claro:** no M1 até o H1 o preço não "tem tendência". Rompimento tende a falhar levemente, mas o custo engole essa diferença. No diário dos índices, queda forte puxa alta no dia seguinte.

## 2. Horário, dia da semana e sessões

- **Volatilidade por hora:** NY das 09h às 10h é o pico, com 3 a 4 vezes a Ásia. Range típico do ouro: Ásia 49bp, Londres 55bp e NY 94bp. Nos índices a sessão de NY domina.
- **Londres pega a máxima da Ásia** 55–70% das vezes e **a mínima da Ásia** 49–67%. Londres não pega nenhuma das duas só 2–10% das vezes (no ouro em 2026 foram 25%).
- **NY pega uma das pontas de Londres** 86–99% das vezes. Isso é geometria (NY tem range maior), não sinal.
- **"NY reverte Londres"** acontece em **47–50%** dos dias. É cara ou coroa. Seguir a direção de Londres acerta 50–53% (t < 2).
- **Reabertura das 18h NY:** levemente positiva no ouro (+1,4bp, t 2,5; em 2026 +7,7bp) e nos índices (+1,0 a +1,6bp). Testado com custo no V2 (2015–25), dá cerca de 0R. **Não paga.**
- **EURUSD às 07h NY:** −1,1bp (t −5,1), mas em 2026 foi 0. Morreu.
- **Segunda-feira** (retorno do fim de semana + segunda) nos índices dos EUA:
  - US500: +12bp em 2021–25 e +41bp em 2026 (t 3,4).
  - NAS: +17bp em 2021–25 e +52bp em 2026.
  - A média dos outros dias fica entre 4 e 6bp.
  - Em 2015–2025 o efeito é mais fraco (ver seção 9).

## 3. Sweeps de liquidez (PDH/PDL, Ásia, sessões, topos e fundos iguais)

Testei as janelas de 1h, 4h e 24h depois de o preço passar de uma máxima ou mínima importante:
- A chance de **voltar para dentro do nível** é **42–56% em todos os mercados**.
- Máximas tendem a continuar e mínimas tendem a reverter. Isso é só a alta de fundo do mercado (drift).
- Topos e fundos iguais ("equal highs/lows") dão 43–53%.

**Conclusão:** o sweep não diz para onde o preço vai.

## 4. Candles grandes e FVG

- **Candle > 2 ATR:** a barra seguinte continua só 44–53% das vezes. Em ~80% dos casos metade do candle é devolvida em até 12 barras. **Não existe "momentum de deslocamento".**
- **FVG:**
  - É tocado em até 12 barras 78–85% das vezes, e em até 48 barras 87–96%. O toque mediano vem em 1–2 barras.
  - Antes de tocar, o preço anda 1 ATR contra 28–36% das vezes.
  - Isso é exatamente o que ruído aleatório produziria. "O FVG sempre é preenchido" é verdade, mas não dá dinheiro, porque o preenchimento não traz direção.

## 5. Volatilidade, NR7 e inside bar

- **A volatilidade se agrupa:** a autocorrelação do movimento absoluto fica entre 0,19 e 0,35 no intradiário, forte e estável. Esse é o fato mais confiável do estudo. **Use para dimensionar stop e lote** (stop em ATR, lote menor em dia agitado).
- **NR7 (menor range de 7 dias):** o dia seguinte tem só **0,64–0,87×** o range normal. A compressão **continua**; a "explosão depois do NR7" é mito.
- **Inside bar:** o range seguinte fica entre 0,85 e 1,0× o normal, e a direção do rompimento acerta cerca de 50%.

## 6. Gaps, fim de semana, notícias e números redondos

- **Gap de fim de semana:** mediano 0,06–0,10 ATR diário; p90 0,28–0,44; o maior chegou a 1,2–1,8 ATR diário.
  - Fecha em 24h: FX 70–75%, ouro 71%, DE40 83%, índices dos EUA 47–48%.
  - **Risco real para stop curto**: o stop pode ser executado muito pior no gap.
- **Payroll (NFP):** a barra de 08:30 tem cerca de 2× o range das outras sextas às 08:30 (3,8–4,1 contra 1,8–2,1 ATR M15). Não há calendário completo de notícias nos dados, então isso é só uma amostra.
- **Números redondos:** o preço rejeita o nível 48,8–50,6% das vezes, **igual** aos níveis de controle (meio-número). **Nenhum efeito.**

## 7. Efeito entre tempos gráficos (top-down)

- Uma barra do tempo menor vai **a favor da tendência do maior** só **49–52%** das vezes.
- O retorno médio a favor da tendência maior fica entre −0,4 e +0,4bp, abaixo do custo.
- **A leitura top-down não melhora a entrada.**

---

## 8. Mito × Realidade (mitos testados)

**Como testei:**
- Cada conceito vira um sinal: entrada na abertura da barra seguinte, saída depois de um tempo fixo (M15 = 8 barras, H1 = 8 barras, D1 = 3 dias).
- O resultado é comparado com uma **entrada aleatória no mesmo mercado e com a mesma duração** (o "excesso" tira a tendência de fundo) e depois o custo é descontado.
- Grade mínima de parâmetros (valores padrão de livro). São 6 mercados × 3 tempos gráficos.
- **Critério de "funciona":** t ≥ 2,5 no período de estudo, mesmo sinal em 2026 e lucro líquido positivo nos dois períodos.

Os números abaixo são **medianas entre os mercados**, e "excesso" é a vantagem sobre a entrada aleatória, por trade.

| Conceito | Veredito | Número-chave | Explicação em uma linha |
|---|---|---|---|
| SMC: BOS (seguir rompimento) | **Não funciona (é até ao contrário no FX M15)** | M15 −0,5bp, t −3,5 a −4,2 no FX | Rompimento de estrutura no intradiário tende a falhar |
| SMC: CHoCH | Não funciona | ±0,6bp, acerto 49–50% | Moeda |
| SMC: Order Block (reteste) | Não funciona | −0,3 a −0,6bp | Reteste do OB não segura o preço |
| SMC: FVG (reteste) | Só sem custos / depende do mercado | Mediana +0,2bp no H1. **XAU H1 +2,3bp (t 2,5; 2026 +11,8)** | Só no ouro H1 aparece algo pequeno: **lista de observação** |
| SMC: Sweep de liquidez + reversão | Não funciona | ~0bp, 50% | Ver seção 3 |
| SMC: Premium/Discount + tendência | Só sem custos / depende do mercado | H1 +1,5bp; **EURUSD H1 +1,6bp (t 2,9), líquido +0,7/+0,3** | Positivo, mas sobra quase nada depois do custo |
| ICT kill zone de Londres (sweep da Ásia) | Só sem custos | H1 +1,8bp, líquido +0,55, não significativo | Pequeno demais |
| Média 200 (seguir) | Depende do mercado | XAU H1 +1,2bp (t 3,7), líquido +0,3/+0,1. **FX: inverso** | Ouro tem um pouco de tendência; FX reverte |
| Cruzamento de médias EMA20/50 | Não funciona | −0,5bp | Chega atrasado |
| RSI14 30/70 (reverter) | Não funciona no intradiário; no D1 é instável | M15/H1 ~0. D1 +21,7bp, mas 2026 −15bp (amostra pequena) | No intradiário dos índices, é **ao contrário** (US500 −1,0bp t −3,1; NAS −1,6bp t −4,0) |
| MACD (cruzamento) | Não funciona | −0,2 a +0,9bp | Moeda |
| Estocástico 20/80 | Não funciona | ±0,8bp | Moeda |
| Divergência RSI | Não funciona | H1 +1,9bp, 2026 −0,5 | Não se repete |
| Bollinger (fora da banda, reverter) | Não funciona no intradiário; D1 instável | H1 −0,7bp (DE40 H1 inverso). D1 +12bp, 2026 −11,6 | Igual ao RSI |
| Candles (engolfo, martelo, estrela, doji) | Não funciona | Entre −0,4 e +0,8bp, acerto 48–51% | Padrão de vela não prevê nada |
| Rompimento de inside bar | Não funciona (inverso no EURUSD) | −0,45bp no M15 | Rompimento falha |
| Suporte/Resistência (topo/fundo anterior) | Não funciona | ~0bp | Moeda |
| Números redondos | Não funciona | Rejeição 49–51%, igual ao controle | Ver seção 6 |
| Fibonacci 61,8–78,6% | Não funciona | M15/H1 ~0. D1 +11,7bp com amostra pequena | Nada além da reversão diária comum |
| Pico de volume (tick) | Não funciona | H1 +1,9bp, 2026 −3,8 | Instável |
| VWAP (longe > 1,5 ATR, reverter) | Não funciona | −0,4bp | Moeda |
| Pivot points S1/R1 | Não funciona | ~0bp; 2026 −4,9 no H1 | Moeda |

**Resumo:** nenhum conceito passou no critério "funciona" com folga. As poucas células positivas (ouro H1 com FVG/MA200, EURUSD H1 com premium/discount) dão entre 0,1 e 1,3bp líquidos. Com dezenas de testes, isso é compatível com sorte. **O único padrão que se repete é que, no intradiário, "seguir o rompimento" perde um pouco, e no diário dos índices "comprar a queda" ganha.**

### Limitações dos dados

- **FX e ouro em CFD não têm volume real nem fluxo de ordens.** Só existe tick volume da Dukascopy, de 2021 em diante. Volume profile, delta e order flow **não foram testados**.
- **Não há book de ofertas (DOM)**, então "liquidez parada no nível" não pode ser vista diretamente, só pelo comportamento do preço.
- **Não há calendário completo de notícias.** Usei só o NFP (primeira sexta) e o calendário do FOMC 2021–2026 (site do Fed).
- **DE40 não tem M1**, só H1. **O ouro em M1** vem de duas fontes (2021–22 e 2023+).
- 2026 tem só ~10,5 meses. Efeitos de calendário em 2026 têm poucas ocorrências (7 a 11).
- Os custos são estimativas (spread mediano Dukascopy + comissão/slippage RoboForex). Na conta cent real o spread pode ser maior.

---

## 9. Efeitos publicados (testados nos nossos dados, com custo)

O teste vale para 2015–2025 (o FOMC só para 2021–25) e depois para 2026. "Líquido" já desconta o custo e o swap das noites. Valores em bp por trade.
Lembrete: **anomalias publicadas encolhem cerca de 1/3 depois da publicação** (McLean & Pontiff, 2016, *Journal of Finance*, https://doi.org/10.1111/jofi.12365).

| Efeito (referência) | Mercado | Estudo: bruto / líquido (t) | 2026: líquido (n) | Ainda funciona? |
|---|---|---|---|---|
| **Virada do mês**: penúltimo dia útil até o 3º dia útil (McConnell & Xu 2008, *Financial Analysts Journal*, https://doi.org/10.2469/faj.v64.n2.11) | US500 / NAS | +12,8 / +0,2 (t 0,8); +18,6 / +5,5 | +97 / +100 (11) | **Fraco.** O swap de 4 noites come quase tudo. 2026 foi forte |
| idem | **XAUUSD** | **+44,9 / +35,7 (t 3,0 bruto, 2,4 líquido)** | +31 (11) | **Sim, no ouro (curiosidade)**: positivo nos dois períodos |
| **Overnight × intraday** (Cliff, Cooper & Gulen 2008, https://ssrn.com/abstract=1004081) | US500 / NAS | Overnight bruto +3,0 (t 2,1) / +4,9 (t 2,8). **Líquido −0,9 / +0,5.** Intraday +1,4 / +1,6 (t < 1) | ~0 | O ganho acontece de noite, como o paper diz, mas **o swap do CFD come tudo** |
| **Véspera de feriado** (Ariel 1990, *Journal of Finance*, https://doi.org/10.1111/j.1540-6261.1990.tb03731.x) | US500 / NAS | +16,9 / +13,8 (t 2,2 bruto); +17,3 / +13,7 (t 1,8) | +1 / −10 (8) | **Talvez.** Positivo no estudo, poucos casos |
| **Drift pré-FOMC**: 14h da véspera até 14h do anúncio (Lucca & Moench 2015, *Journal of Finance*, https://doi.org/10.1111/jofi.12196) | US500 / NAS / DE40 | +26 / +23 (t 2,2); +40 / +37 (t 2,3); +36 / +33 (t 2,5), só 40 eventos | −20 / +4 / −6 (7) | **Duvidoso.** Bom em 2021–25, falhou em 2026 |
| **Efeito segunda-feira** (French 1980, *Journal of Financial Economics*, https://doi.org/10.1016/0304-405X(80)90021-5; o original diz segunda **negativa**) | US500 / NAS / DE40 | +6,7 / −0,3 (t 1,4); **+11,9 / +4,4 (t 2,1)**; +4,5 / −3,0 | **+20 / +32 / +22 (45)** | **Invertido:** hoje a segunda é **positiva**. Forte em 2026, fraco em 2015–25 |
| **Halloween / "sell in May"** (Bouman & Jacobsen 2002, *American Economic Review*, https://doi.org/10.1257/000282802762024683) | Índices | Nov–abr por dia +4,1 / +5,2 / +5,7 contra mai–out +4,4 / +7,4 / +0,9 | igual | **Não**, exceto talvez no DE40 |
| **Ouro no outono** (setembro + novembro) (Baur 2013, *Research in International Business and Finance*, https://doi.org/10.1016/j.ribaf.2012.05.001) | XAUUSD | Set+Nov **−86bp/mês** contra +129 nos outros meses | — | **Não** (inverteu depois da publicação) |
| **Momentum intradiário**: 1ª meia hora prevê a última (Gao, Han, Li & Zhou 2018, *Journal of Financial Economics*, https://doi.org/10.1016/j.jfineco.2018.05.009) | US500 / NAS (M1 2021–26) | −0,6 / −1,7; **NAS −2,0 / −3,6 (t −2,3)** | −1,8 / −1,1 | **Não.** No CFD de 2021–26 é até levemente ao contrário |
| **Reversão de curto prazo**: RSI2/IBS nos índices (Connors & Alvarez 2009, *Short Term Trading Strategies That Work*) | Índices D1 | V2: +6,4%/ano com risco de 1%, DD 6,9%, **todos os anos positivos 2016–2026** | positivo | **Sim, o melhor achado** |
| Reversão diária no FX (contra o dia anterior) | EUR / GBP / JPY / XAU | −0,9 a +0,6 bruto; líquido −1,3 a −2,7 | ~0 | **Não** |
| **Time-series momentum** (Moskowitz, Ooi & Pedersen 2012, *Journal of Financial Economics*, https://doi.org/10.1016/j.jfineco.2011.11.003) | 8 mercados (V2) | Mediana fora da amostra negativa | — | **Não** nessa amostra (2015–26 e com custos de CFD) |
| **Carry no FX** (Lustig, Roussanov & Verdelhan 2011, *Review of Financial Studies*, https://doi.org/10.1093/rfs/hhr068) | — | Não testado: falta o histórico de juros e swaps reais | — | Limitação |

**Leitura:**
- O que mais funciona hoje é **comprar índice depois de dia ruim** (reversão diária). Há também uma tendência de **segunda-feira positiva** e de **virada do mês positiva no ouro**.
- O resto ou enfraqueceu depois de publicado ou é engolido pelo **swap do CFD**. O swap pesa cerca de 2bp por noite nos índices, mais que o custo de entrada.

---

## 10. Robô de confluência máxima multi-timeframe (H4 → M1)

**Regra:** entram apenas conceitos com efeito real ou quase real no estudo. As versões foram **definidas antes de rodar, sem otimização**.
- **D1:** sobrevenda RSI2 < 10 ou IBS < 0,25, com preço acima da SMA200. Opera no dia seguinte.
- **Calendário:** segunda-feira, véspera de feriado, véspera/dia de FOMC ou virada do mês.
- **H4:** preço acima da EMA50 (incluído porque foi pedido, apesar de o estudo não mostrar efeito).
- **H1:** preço na zona de "discount", nos 25% de baixo do range das últimas 50 barras H1.
- **Horário:** janela de entrada 09:30–14:00 NY (o mais líquido).
- **Gatilho M1:** primeiro fechamento M1 acima da máxima do M1 anterior.
- **Saídas pré-definidas:**
  - SL = 0,5 ATR diário e TP = 2R.
  - Na versão "t", o stop é curto: fundo das últimas 15 barras M1.
  - Fecha tudo até 15:55 NY (não dorme posicionado).

Base: M1 bid/ask, custos RoboForex, simulador com stop primeiro. **US500 e NAS100**; o DE40 não tem M1, e o efeito diário não existe no FX nem no ouro. A tabela mostra R médio por trade, PF e n para 2021–25 | 2026.

| Versão | US500 2021–25 | US500 2026 | NAS 2021–25 | NAS 2026 |
|---|---|---|---|---|
| A0 controle: compra todo dia às 09:30 | +0,01R, PF 1,03, n 1288 | −0,01R (225) | +0,03R, PF 1,07 | +0,04R |
| A1 só D1 | +0,03R, PF 1,07, n 240 | +0,03R (53) | +0,04R, PF 1,09 | −0,02R (47) |
| A2 D1 + H1 discount | +0,02R (160) | +0,04R (33) | −0,00R (174) | −0,08R (32) |
| A3 D1 + H1 + gatilho M1 | −0,01R (159) | +0,05R (33) | −0,02R (174) | −0,12R (32) |
| A3t igual, stop curto M1 | **−0,08R**, acerto 32%, 17 perdas seguidas | −0,18R | −0,07R | −0,24R |
| A4 A3 + tendência H4 | +0,13R (48) | **−0,31R (8)** | −0,10R (45) | −0,22R (8) |
| A5 (D1 **ou** calendário) + H1 + M1 | −0,02R (310) | +0,02R (57) | −0,01R (338) | −0,04R (53) |
| **A6 confluência máxima** (tudo junto) | **−0,07R (25)** | **0 de 4, −0,67R** | **−0,20R (19)** | **0 de 4, −1,0R** |
| A6t máxima com stop curto | −0,36R (25) | −0,26R (4) | −0,22R (19) | −1,0R (4) |
| C1 só calendário (entrada 09:30, sem outros filtros) | **+0,05R, PF 1,16, t 1,4 (543)** | +0,06R (98) | **+0,07R, PF 1,20, t 1,8 (543)** | +0,09R (98) |
| *Referência V2: RSI2/IBS no D1, segurando por dias (dorme posicionado)* | *+6,4%/ano a 1% de risco, DD 6,9%, todo ano positivo* | | | |

**Por que a confluência piora:**
1. **O efeito diário vive na passagem da noite e em vários dias.** Quando o trade fica preso dentro do pregão (09:30–15:55), quase todo o efeito some: A1 dá só +0,03R contra os +6,4%/ano da versão diária.
2. **Cada filtro intradiário (H4, H1, M1) não tem poder de previsão** (seções 1, 3, 7 e 8). Ele só corta trades, **deixa a amostra pequena e o resultado vira sorte**. O A4 parecia ótimo no US500 2021–25 (+0,13R) e caiu para −0,31R em 2026.
3. **O stop curto no M1 sempre piora**: acerto de ~30% e sequências de até 17 perdas, porque o custo pesa muito mais em relação ao stop.
4. O **calendário sozinho** é o único que fica positivo nos dois períodos e nos dois índices. Ainda **não é significativo** (t 1,4–1,8) e é só um pouco melhor que o controle no NAS, que tem alta de fundo forte.

**Veredito final do robô:** **REPROVADO.** A confluência máxima H4→M1 não cria vantagem; ela **destrói** a pouca vantagem que existe. Mais filtros resultam em menos trades, mais ruído e pior desempenho fora da amostra.

---

## 11. Os comportamentos mais promissores (em ordem)

1. **Reversão diária nos índices** (RSI2/IBS, D1, comprado acima da SMA200, segurando 1 a 5 dias). Único efeito grande, publicado, que continua funcionando e foi positivo todos os anos 2016–2026. É o candidato principal para o ALIEN (ver RESULTS_V2.md).
2. **Volatilidade previsível** (agrupamento e horário). Não diz a direção, mas serve para **stop e lote em ATR**, para evitar abrir antes de NFP/FOMC e para operar no horário certo.
3. **Calendário nos índices dos EUA**: segunda-feira positiva, virada do mês, véspera de feriado e véspera de FOMC. Fraco, mas positivo nos dois períodos. Bom como **filtro de "dia de não vender"** ou para aumentar um pouco a exposição do item 1. Não serve como robô sozinho por enquanto.
4. **Virada do mês no ouro** (t 3,0 bruto, 2,4 líquido, positivo em 2026). Lista de observação. Precisa de mais anos de dados e de checar o swap real da RoboForex.
5. **Lista de observação no H1:** ouro (FVG/MA200, um pouco de tendência) e EURUSD (premium/discount). Os efeitos são de 0,1 a 1,3bp líquidos, próximos do zero. Não operar com dinheiro.

**O que o estudo mostra sobre o "modelo SMC/ICT":** as peças (sweep, FVG, OB, BOS, kill zone, top-down) foram testadas uma por uma e juntas, em M1 até D1, em 6 mercados e por quase 6 anos. Elas se comportam como **entrada aleatória** antes do custo e **perdem** depois do custo. Isso não quer dizer que ninguém ganha com SMC. Quer dizer que **a vantagem não está nessas regras mecânicas**.
