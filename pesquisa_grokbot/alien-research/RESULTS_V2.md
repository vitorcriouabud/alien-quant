# ALIEN — Pesquisa V2: busca ampla de um robô lucrativo e robusto (14/11/2026)

## Veredito direto
- **Só uma coisa sobreviveu de verdade: reversão à média de curto prazo em índices de ações (RSI2 e IBS no D1)**, no US500, US Tech (NAS100) e DE40. Ela passou na correção para testes múltiplos, ficou positiva em todos os anos de 2016 a 2026 (como cesta), segue positiva no OOS de 2026 e aguenta os custos da RoboForex. **O lucro é modesto, não é alto:** cerca de **6% ao ano com 1% de risco por trade, e drawdown máximo de ~7%**.
- **O modelo SMC/ICT top-down (o seu) foi reprovado com clareza:** 720 variações, nenhuma sobreviveu, e o modelo **perde até sem custo nenhum**. Detalhes na seção 4.
- Ouro intradiário, sessão asiática (C1), a deriva das 18h NY no ouro, rompimentos e momentum de sessão também não se sustentaram em 11 anos de dados.
- Não existe "robô de lucro alto" nestes dados. Existe um robô **defensivo, de ganho pequeno e constante**, que combina com a sua prioridade de preservar capital.

---

## 1. Dados, custos e método
- **Dados:** Dukascopy bid/ask. Em H1: 01/2015 → 13/11/2026 para XAUUSD, EURUSD, GBPUSD, USDJPY, US500, US Tech (NAS100), DE40 e BTCUSD (BTC desde 05/2017). Em M1: 2021 → 13/11/2026 para XAUUSD, EURUSD, GBPUSD, NAS100 e US500 (só para o modelo SMC). Os pacotes H4 e D1 fecham às 17:00 NY, que é a meia-noite do servidor GMT+2/+3, igual ao MT5 da RoboForex.
- **Divisão:** IS = 2015–2025 (SMC: 2021–2025). **OOS = 01/01/2026 → 13/11/2026**, nunca usado para escolher nada.
- **Execução:** sinal no fechamento da barra e entrada na abertura da próxima. Stop por ATR(20). Se stop e alvo caem na mesma barra, conta o stop. Gap passa do stop e sai na abertura.
- **Custos (dois cenários):** (1) Dukascopy: spread real + comissão de US$ 7/lote em FX e ouro + slippage. (2) **RoboForex ProCent** (site deles, 11/2026): sem comissão, com spreads médios como piso (EURUSD 1,3 pip, GBPUSD 1,5, XAU 0,18–0,25, DE40 0,9, US500 0,6, NAS 2,0).
- **Swap:** aproximação constante em % ao ano sobre o nocional, por dia corrido. Índices: compra −7,2%/ano e venda −1,8% (RF). Ouro: −5% / −1%. EURUSD: −3% / 0. GBPUSD: −2% / −0,5. USDJPY: +1% / −5%. BTC: −20% nos dois lados. É uma aproximação e não usa o histórico real de swaps.
- **Disciplina estatística:** mínimo de 100 trades no IS, t ≥ 2, ≥ 60% dos anos IS positivos e OOS positivo. Correção de **Benjamini-Hochberg (FDR 10%)** e **Bonferroni** sobre todas as configs. **Walk-forward anual:** a cada ano, escolhe as 10 melhores dos 4 anos anteriores e opera o ano seguinte.

## 2. Busca ampla (472 configs = 59 por mercado × 8 mercados)
Famílias testadas: Donchian 20/55 (H4/D1, trailing ou saída pelo canal, com e sem filtro de volatilidade), cruzamento de médias 20/100 e 50/200, momentum de série temporal (60/120/250 dias), RSI2 (Connors), IBS, reversão por Bollinger (H1/H4), horário do dia (compra e venda às 18h, 03h, 09h e 16h NY, segurando 4 ou 8h), e o rompimento asiático C1 com stop natural no lado oposto da faixa.

| Resultado | Dukascopy | RoboForex |
|---|---|---|
| Passam BH (FDR 10%) | 4 | 4 |
| Passam Bonferroni (t > 3,7) | 2 | 2 |
| Sobreviventes (todos os critérios) | 4 | 4 |
| Walk-forward (expectativa média OOS) | **+0,040R** | **+0,063R** |
| Correlação IS × OOS | 0,31 | — |

- **Trend following** (Donchian, médias, TSMOM): a mediana é levemente positiva no IS, mas **negativa no OOS de 2026** (TSMOM −0,19R, cruzamento de médias −0,62R). Não é confiável aqui.
- **Deriva das 18h NY no ouro, testada em 11 anos** (custo menor, segurando 4–8h): **−0,005R e +0,001R por trade, t ≈ 0.** O que apareceu em 2023–2026 não se repete no histórico longo. Descartada.
- **C1 rompimento asiático com stop natural (ouro):** IS 2015–2025 entre −0,01 e −0,02R (2.469 trades). OOS 2026 +0,11R, que é um ano isolado. Descartado.

### Sobreviventes (custos Dukascopy; com RoboForex os números são praticamente iguais)
| # | Estratégia | IS trades | IS PF | IS exp R | IS t | CAGR IS (1%) | DD máx IS (1%) | OOS trades | OOS PF | OOS exp R | Acerto | Pior sequência de perdas |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **IBS < 0,15 NAS100 D1** (só compra) | 191 | 2,16 | +0,095 | 4,24 (Bonferroni ✔) | 1,8%/ano | 1,4% | 18 | 1,15 | +0,016 | 73% | 3 |
| 2 | **RSI2 < 10 / > 90 US500 D1** | 120 | 2,28 | +0,130 | 3,46 (BH ✔) | 1,5%/ano | 2,6% | 16 | 3,36 | +0,186 | 77% | 3 |
| 3 | IBS < 0,25 DE40 D1 (só compra) | 223 | 1,60 | +0,051 | 2,60 | 1,1%/ano | 1,7% | 28 | 1,18 | +0,020 | 69% | 3 |
| 4 | Donchian 55 + filtro de volatilidade, BTC H4 | 163 | 1,74 | +0,295 | 2,07 (BH ✘) | 5,6%/ano | 5,8% | 16 | 2,25 | +0,459 | 42% | 8 |

**Robustez da família:** as 18 variantes de RSI2 e IBS nos 3 índices têm **todas** PF IS > 1 (de 1,15 a 2,96). A ideia é robusta, não um parâmetro sortudo. O BTC (#4) **não** passou no BH e depende de um swap incerto. Fica como observação.

> Por que o CAGR é baixo com 1% de risco: o stop é largo (3–4 ATR diário) e quase nunca é atingido. A maioria das saídas é por sinal, com ganho de ~0,1R. O retorno por trade é pequeno, mas a taxa de acerto é de ~70% e o DD é baixo.

## 3. Carteira diversificada
**Cesta de reversão em índices (definida pela família, sem escolher a melhor variante):** RSI2 (10, stop 3 ATR) + IBS (0,25, stop 4 ATR) × US500, NAS100 e DE40 = 6 fluxos, cada um com 1% de risco por trade.

| Risco/trade | CAGR IS | DD IS (no fechamento do trade) | **DD diário marcado a mercado** | Sharpe IS | OOS 2026 (10,5 meses) | DD OOS |
|---|---|---|---|---|---|---|
| **1%** | **6,4%** | 6,1% | **6,9%** (pior dia −3,5%) | 1,54 | **+2,8%** | 3,7% |
| 2% | ~13% | ~12% | 12,5% (pior dia −7,1%) | 1,54 | ~+5,6% | 4,5% |
| 3% | 20% | 18% | 18,6% (pior dia −10,6%) | 1,54 | +8,0% | 10,9% |

1.208 trades, acerto de 71%, PF 1,58, +0,061R por trade. **Todos os anos de 2016 a 2026 foram positivos**, inclusive 2020 e 2022. Com custos e swaps da RoboForex: CAGR IS de 6,4%, OOS de +2,8% (sem diferença relevante).
Os 4 sobreviventes juntos (inclui BTC), com 1%: CAGR IS de 8,6%, DD de 3,8%, OOS +8,6%. Só 2022 foi negativo (−1,3%).

**Risco honesto:** é uma estratégia **comprada** em índices que compra quedas dentro de tendência de alta (SMA200). O período testado foi majoritariamente de alta. Num mercado de baixa longo (tipo 2008), o filtro SMA200 tira o robô do mercado, mas um crash rápido pode gerar perdas de vários R seguidos. O pior dia da amostra foi −3,5% com 1% de risco.

## 4. Seu modelo: SMC/ICT top-down multi-timeframe
**Codificação objetiva (sem olhar o futuro):**
1. **Viés D1 ou H4:** estrutura por fractais 2/2 confirmados. BOS para cima (fechamento acima do último topo) dá viés de compra, BOS para baixo dá viés de venda. **Premium/discount:** faixa = último topo e fundo confirmados. Compra só na metade inferior, venda só na superior (variante liga/desliga).
2. **POI H1 (opcional):** o extremo do sweep precisa estar dentro (ou a até 0,5 ATR) de um FVG H1 ainda não preenchido, a favor do viés, das últimas 24 barras.
3. **AMD / Power of 3:** acumulação = faixa asiática das 19:00–00:00 NY. Manipulação = sweep da mínima (ou máxima) asiática, ou da mínima do dia anterior, **dentro da kill zone** (Londres 02–05h NY ou NY 08–11h NY). Distribuição = o trade.
4. **Gatilho M5:** depois do sweep, um CHoCH (fechamento M5 além do último fractal oposto) em até 24 barras. Entrada: limite na borda do **FVG** do deslocamento, ou na abertura do **OB** (último candle contrário), ou **a mercado**. A ordem limite vale 1h.
5. **Stop** além do extremo do sweep + 0,1 ATR(M5). **Alvo:** 2R, 3R ou **liquidez oposta** (máxima/mínima asiática, mínimo 1,5R). Um trade por kill zone por dia, e zera tudo às 16:50 NY.

**Grade:** viés (H4/D1) × PD (sim/não) × pool (Ásia / Ásia ou dia anterior) × POI (nenhum / FVG H1) × entrada (FVG/OB/mercado) × alvo (2R/3R/liquidez) = **144 × 5 mercados = 720 configs**. M1 com bid/ask, 2021–2026.

| Métrica (mediana das configs, com custos) | XAUUSD | EURUSD | GBPUSD | NAS100 | US500 |
|---|---|---|---|---|---|
| Acerto | 29% | 28% | 28% | 26% | 26% |
| PF IS | 0,70 | 0,67 | 0,66 | 0,71 | 0,75 |
| Expectativa média IS | −0,20R | −0,22R | −0,23R | −0,21R | −0,18R |
| Expectativa média OOS 2026 | −0,22R | −0,18R | −0,42R | −0,22R | −0,27R |

- Configs com expectativa IS > 0: **29 de 720**. Com t ≥ 2: **0**. Sobreviventes: **0**. Correlação IS × OOS: 0,07.
- **Melhor config** (US500, viés D1, PD ligado, pool Ásia, entrada a mercado, alvo na liquidez): IS de 169 trades, acerto de 27%, PF 1,11, +0,08R, t 0,36, DD de 25R (22% com 1% de risco), **pior sequência de 24 perdas**. No OOS: 36 trades, acerto de 19%, PF 0,47, **−0,42R**.
- **Walk-forward** (as 5 melhores dos 2 anos anteriores): 2023 −0,45R, 2024 −0,38R, 2025 −0,08R, 2026 −0,42R. **Média de −0,33R por trade.**
- **Sem custo nenhum** o modelo ainda perde: mediana de −0,10R, e 0 configs com t ≥ 2. Uma entrada aleatória sem custo dá ≈ 0R. **Ou seja, o problema não é a corretora, é a lógica.** Na média, entrar depois de sweep + CHoCH a favor do viés não tem vantagem nestes mercados.
- Cada camada (viés D1, PD, POI H1 FVG, entrada FVG) melhora a mediana em poucos centésimos de R, mas nenhuma combinação vira positiva.
- Também verifiquei que a resolução M1 não distorce o teste: o stop mediano é ~5× o tamanho de uma vela M1, e praticamente nenhum trade é stopado na vela de entrada.

**Conclusão:** como regra automática e objetiva, o SMC/ICT perde dinheiro em ouro, FX e índices em 2021–2026. Se você opera SMC manualmente com lucro, a vantagem está em algo que essa codificação não captura (seleção discricionária). Isso só se prova com um diário de trades reais.

## 5. Regras exatas para portar ao MQL5 (D1 = barra do servidor RoboForex, fecha 00:00 do servidor = 17:00 NY)
Definições comuns: ATR(20) = média simples do True Range de 20 barras D1. RSI(2) de Wilder. Sinal no fechamento da barra D1 e execução na abertura da barra seguinte. Uma posição por estratégia e símbolo. Stop fixo na entrada, sem trailing.

**#1 IBS NAS100 (US Tech) — só compra**
- IBS = (Close − Low) / (High − Low) da barra D1 fechada.
- Entrada: IBS < 0,15 **e** Close > SMA(200) → compra na abertura seguinte.
- Stop: entrada − 4 × ATR(20).
- Saída: no primeiro fechamento D1 acima da máxima da barra anterior (sai na abertura seguinte), **ou** depois de 5 barras. Sem take profit.

**#2 RSI2 US500 — compra e venda**
- Compra: Close > SMA(200) e RSI(2) < 10. Venda: Close < SMA(200) e RSI(2) > 90.
- Stop: 3 × ATR(20) a partir da entrada.
- Saída da compra: Close > SMA(5). Saída da venda: Close < SMA(5). Ou depois de 10 barras. Sem take profit.

**#3 Cesta de índices (recomendada para preservar capital):** #2 (RSI2 < 10, stop 3 ATR) e IBS < 0,25 (stop 4 ATR, regras do #1) aplicados a US500, NAS100 e DE40 = 6 fluxos. **Risco de 0,5–1% por trade e no máximo 3% de risco aberto somado.**

## 6. Viabilidade com US$ 20 numa conta cent RoboForex (ProCent)
- US$ 20 = **2.000 USC**. Com 1% de risco = 20 USC por trade. Stop-out da ProCent em 30% de margem.
- Stops típicos em 2026 (ATR D1 mediano): US500 3 × 85 ≈ **255 pts**, NAS100 4 × 502 ≈ **2.000 pts**, DE40 4 × 366 ≈ **1.465 pts**.
- Fórmula do lote no EA: `lots = floor( (equity × risco%) / (SL_em_pontos × valor_do_ponto_por_lote) / step ) × step`. **Se o lote resultante for menor que o mínimo, NÃO opere** (nunca arredonde para cima).
- Exemplo, assumindo contrato de US$ 1/ponto por lote padrão (**confira no MT5**: `SYMBOL_TRADE_CONTRACT_SIZE` e `SYMBOL_TRADE_TICK_VALUE`): na cent, 0,01 lote ≈ 0,01 USC/ponto. US500: 255 × 0,01 = 2,6 USC (0,13% da conta), viável até ~1%. NAS100: 2.000 × 0,01 = 20 USC (1% exato no lote mínimo). DE40 ≈ 15 USC (~0,75%). **Na conta cent dá para operar a cesta com ~1%. Numa conta padrão com US$ 20 não dá** (o lote mínimo já arriscaria 10–100% da conta).
- Confirme se os índices estão disponíveis na ProCent do MT5 (o site lista DE40, US500 e US Tech). Swaps dos índices: compra −7,2%/ano (já incluído no teste).
- Proteções obrigatórias: risco de ≤ 1% por trade, ≤ 3% abertos no total, **trava de DD em 15% do pico** (pausa e revisão), nada de martingale, e demo de pelo menos 2–3 meses (~25–40 trades da cesta) antes de colocar dinheiro real.
- Expectativa realista com 1%: **US$ 20 → ~US$ 21,30 em um ano** (+6%). É uma prova de conceito, não renda.

## 7. Log de perdas por trade (design para o EA)
Gravar um CSV por trade (`ALIEN_tradelog.csv`) com:
- **Identificação:** ticket, strategy_id (#1/#2/#3), símbolo, direção, versão do EA + hash dos parâmetros.
- **Contexto do sinal:** hora do sinal, Close, IBS, RSI2, SMA200, distância Close–SMA200 em ATR, ATR20, ATR20 / ATR100 (regime de volatilidade), dia da semana, spread no sinal.
- **Execução:** preço pedido × preço executado (slippage), lote, risco em USC e em % da conta, SL, motivo se o trade foi pulado (`LOT_BELOW_MIN`, `SPREAD_TOO_WIDE`, `MAX_OPEN_RISK`, `MARKET_CLOSED`).
- **Saída:** hora, preço, `exit_reason` (SL, SIGNAL_EXIT, TIME_EXIT, GAP_SL, MANUAL, STOP_OUT), resultado em R e em USC, swap pago, barras segurando, MAE/MFE em R.
- **`loss_tag` automático** (o que falhou), avaliado em ordem:
  - `GAP`: saída pior que o SL por mais de 0,2R.
  - `TREND_BREAK`: Close < SMA200 (compra) durante o trade.
  - `VOL_SPIKE`: ATR na saída > 1,5 × ATR na entrada.
  - `TIMEOUT_LOSS`: saída por tempo com R < 0.
  - `COST_ONLY`: perda de até 0,1R, só de spread/swap.
  - `NEWS_DAY`: dia de evento macro, por calendário manual.
  - `NORMAL_STOP`: nenhum dos anteriores.
- Relatório semanal: perdas por `loss_tag`, R acumulado × backtest esperado (+0,06R/trade, acerto ~70%), e alerta se 6 perdas seguidas (o dobro da pior sequência histórica de 3 por fluxo) ou DD > 10%.
- Se você ainda quiser testar o SMC em demo, logue cada camada: `bias_ok`, `pd_ok`, `pool_swept` (qual), `poi_ok`, `choch_bar`, `entry_type`, `filled` (sim/não), e se o preço voltou ao extremo do sweep. Assim cada perda mostra qual camada falhou.

## 8. Reprodução e contagem de testes
- **Configs nesta V2:** 472 (amplas) × 2 cenários de custo + 720 SMC × 2 (com e sem custo) = **~2.384 backtests**. Somando a V1 (773 configs), já foram **~1.245 ideias diferentes testadas**. É por isso que só conta o que passa em BH/Bonferroni + OOS + walk-forward.
- **Código:**
  - `code/v2/` (engine2.py, fam2.py, grid2.py, analyze2.py, portfolio2.py, mtm.py; use `COSTS=RF` para o cenário RoboForex)
  - `code/smc/` (smc.py, grid_smc.py, analyze_smc.py, diag.py)
- **Resultados em `out/`:**
  - `v2_summary*.csv`, `v2_trades*.parquet`, `v2_wf*.csv`
  - `smc_summary*.csv`, `smc_trades*.parquet`
- Nada foi enviado ao GitHub.
