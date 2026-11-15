# Auditoria matemática — ALIEN LAB V1

Este texto descreve o que o código faz. Não é um resultado financeiro.

Hash das definições congeladas, calculado por `definitions.definitions_hash()` antes dos experimentos sintéticos:

`cf3314529d3562b679fc45706fc22782cc3134ad3d94a08f8bed4064265ece4e`

O mesmo valor está em `resultados_sinteticos/definitions_frozen.json` e em `resultados_sinteticos/proof.json`.

Nenhum arquivo de sinal, simulador, custo ou métrica foi alterado nesta embalagem. O hash anterior de cada arquivo já existente está em `sha256_antes_dos_documentos_de_auditoria.txt`.

## 1. Ausência de look-ahead

Regra comum: o sinal do candle `t` usa apenas informações conhecidas no fechamento de `t`. A entrada simulada é `open[t+1]`. A saída do horizonte `h` é `close[t+h]`, porque `exit_idx = (t+1) + h - 1`.

| Família | O que entra no sinal | O que fica de fora |
|---|---|---|
| A | `SH_t = max(H[t-k:t])`, `SL_t = min(L[t-k:t])`, com `k=10`. Close quality do próprio candle. | O high/low de `t` não entra no nível. Nenhum candle `> t`. Não é pivô fractal (pivô precisaria de candles à direita). |
| B M1 | EMA, ATR14, slope `(EMA50[t]-EMA50[t-10])/ATR14[t]`, bandas e volume até `t`. | Slope e banda não usam `t+1`. |
| B H1 | EMA21 do fechamento das horas já encerradas. A hora `H` só é publicada em `H+1h`. A última hora do arquivo é descartada porque pode estar aberta. | A hora em formação não altera o slope visível. |
| C | Bandwidth das 120 observações anteriores (`shift(1)`). O gatilho de expansão usa o fechamento de `t` contra a banda de `t`. | O percentil não inclui a bandwidth de `t`. |
| D H14 | `C[t-1] > upper[t-1]` e `C[t] < upper[t]` e `C[t] < O[t]`. A banda de `t` inclui o close de `t`, como Bollinger no fechamento. | `upper[t]` não entra na comparação do candle anterior. |
| D H16 | Banda, EMA9, EMA21 e volume relativo até `t`. | Nada à frente. |
| E | Retorno da janela já fechada. Ásia é `[00:00, 08:00)` e o sinal cai na primeira barra `>= 08:00`, fora da janela. Londres `[08:00, 14:30)`, sinal `>= 14:30`. Controle `[02:00, 10:00)`, sinal `>= 10:00`. | A barra do sinal não compõe o retorno da janela. A entrada ainda espera `open` da barra seguinte: é atrasada, não antecipada. |
| F | Sweep em `s` com nível causal. Reteste só é emitido em `r > s`, com `r <= s+12`. O deslocamento, quando exigido, está em `s < d < r`. | Não se emite o sinal em `s` olhando o reteste futuro. |
| G | `TR[t]` contra o percentil 80 dos 50 TRs anteriores (`shift(1)`), mais close quality de `t`. | O TR de `t` não entra no limiar. |

Teste executado: `test_future_mutation_does_not_change_past_signals` soma 500 aos highs e closes a partir do índice 250 e exige igualdade dos sinais com `signal_idx < 250`. `test_prev_window_excludes_current_and_future` confere a janela `[t-k, t)`.

O que não foi provado barra a barra para as famílias B–G: não há um teste que mutile só o futuro de cada família separadamente. A garantia delas é a construção acima, não oito testes independentes de mutação.

## 2. Núcleo e confluência

Pares em `signals.pairs()`:

| Núcleo | Acrescenta | Tipo |
|---|---|---|
| `A_SWEEP_BUY` / `A_SWEEP_SELL` | close quality `>= 0.66` | confluência |
| `B_M1_PULLBACK_*` | volume relativo `> 1.2` | confluência |
| `C_BREAK_*` | volume relativo `> 1.2` | confluência |
| `D_H16_NO_VOL` | volume relativo `> 1.2`, e esse conjunto é a H16 original | confluência |
| `F_SWEEP_RETEST_*` | um candle de deslocamento entre o sweep e o reteste (`TR > 1.3 * ATR14` e fechamento a favor) | confluência |
| `G_DISP_*` | volume relativo `> 1.2` | confluência |
| `E_ASIA_LONDON_CONT` | lado oposto, mesmo relógio | controle, não confluência |

`A_CQ_*`, `B_RANGE_FADE_*`, `B_H1_PULLBACK_*`, `D_H14_ORIG`, `E_LONDON_NY_CONT` e `E_CLOCK_SHIFT_CONT` não têm par.

A tabela `paired.csv` compara médias de conjuntos diferentes. Não é um teste pareado trade a trade, nem um teste de significância da diferença.

Close quality, com `H>L`:

- compra: `(C-L)/(H-L)`
- venda: `(H-C)/(H-L)`

`H=L` produz NaN e nenhum sinal de qualidade ou sweep que dependa dessa divisão. Coberto por `test_doji_has_no_close_quality_signal`.

## 3. H14 e H16 originais

`D_H14_ORIG`, só venda:

1. O candle anterior fecha acima da banda superior daquele candle.
2. O candle atual fecha abaixo da banda superior atual.
3. O candle atual é de baixa: `C < O`.

`D_H16_ORIG`, só venda:

1. Candle de baixa.
2. Fecha em ou abaixo da banda inferior: `C <= lower`.
3. `EMA9 < EMA21`.
4. Volume relativo `tick_volume / SMA(tick_volume, 20) > 1.2`, SMA incluindo o candle atual.

Bollinger do motor: SMA 20, desvio populacional `ddof=0`, multiplicador 2. Não é o `iBands` do MT5 byte a byte. EMA é `ewm(span, adjust=False)`.

`D_H16_NO_VOL` é a mesma regra sem o item 4 e não pode ser chamado de H16. A família C não reutiliza esses IDs.

`test_h14_h16_direction_and_identity` cobre as máscaras, inclusive o caso em que o volume fica em 1.0 e a H16 original desaparece enquanto `D_H16_NO_VOL` permanece.

## 4. Preço, pontos MT5 e USD

Default, não lido do terminal:

- `point = 0.01`
- 1 ponto MT5 = 0,01 de preço
- pontos = variação de preço / `point`
- 1,00 de preço = 100 pontos
- 0,50 de preço = 50 pontos, não 0,50 ponto
- USD por lote = variação de preço × `contract_oz` − comissão
- `contract_oz = 100` é hipótese de contrato. 0,80 de preço seriam 80 USD nesse contrato. No teste sintético, 80 pontos líquidos = 0,80 de preço = 80 USD com comissão zero.

Spread no CSV, com `--spread-unit points`, já está em pontos MT5. Com `--spread-unit price`, divide-se por `point`.

`test_units_points_versus_price` só verifica a aritmética 1,00/0,01 = 100 e 0,50/0,01 = 50. Não lê um símbolo da RoboForex.

## 5. Spread zero, slippage e gaps

Grade sintética executada: slippage `0` e `10` pontos. Omissão do executor noturno: `0,10,20`.

Dois modos, ambos gravados:

- `exclude_zero`: spread de entrada igual a zero elimina o trade.
- `penalize_zero`: spread zero vira `penalty_spread0_points` (omissão 20) e ainda soma o slippage.

Custo em pontos = spread usado + slippage. É um custo único de ida, não um spread pago na saída.

Gap: se algum intervalo entre a barra de entrada e a de saída, inclusive, passa de 90 segundos, o status é `gap` e o trade não entra na média. Não há preço inventado no buraco.

`test_gap_and_spread_zero_and_pnl` usa o sweep de venda plantado no índice 220. A entrada 221 tem spread 0. Exclusão fica `spread0_excluded`. Penalidade: bruto 100 pontos, custo 20, líquido 80, USD 80. Um sinal artificial no índice 396 cruza o buraco de 15 minutos colocado a partir do índice 400 e sai `gap` nos horizontes 5 e 15.

## 6. MTF e candle não fechado

Só a família `B_H1_*` usa outro timeframe. O OHLC H1 é o último close M1 de cada hora. A EMA21 dessa série só fica visível na hora seguinte. A última hora do arquivo nunca é publicada.

Não há M5, M15 nem D1. Não há leitura de candle gráfico do MT5. Se faltar barra dentro da hora, a hora anterior ainda é tratada como fechada assim que aparece uma barra da hora seguinte.

## 7. Causalidade executada

Executados de fato, em `tests/test_motor.py`:

1. Nível de sweep não contém o candle atual nem o futuro.
2. Sinais com índice menor que 250 não mudam se o futuro for deslocado em +500.
3. Doji não gera família A.
4. Máscaras H14 e H16.
5. Conversão de pontos.
6. Spread zero, PnL e gap na série sintética.
7. Hash e sinais idênticos em duas chamadas.
8. Janela anterior de máximo e mínimo.

Não executados:

- Os 100.000 candles da RoboForex.
- Strategy Tester, ticks reais, stop intrabar, “o que foi tocado primeiro”.
- Comparação numérica com o ALIEN LAB V0.
- Teste de mutação futura separado para B, C, D, E, F e G.
- Leitura de `point`, contrato, comissão ou swap no terminal.

## 8. Rejeição e o que o rótulo não é

Para cada hipótese × horizonte × modo de spread × slippage, a métrica primária ignora trades com `reserved=True`.

| Rótulo | Condição |
|---|---|
| `INCONCLUSIVE` | menos de 30 trades preenchidos, ou média não finita |
| `REJECT` | média líquida `<= 0` |
| `FRAGILE` | média líquida positiva, mas a média sem o melhor trade é `<= 0`, ou menos da metade dos meses tem média positiva |
| `SURVIVES_SCREEN` | passou os três cortes acima |

O melhor trade removido é o de maior `net_points`, não o de maior módulo. Um outlier perdedor permanece.

Na prova sintética esse rótulo passou em `A_CQ_SELL` nos horizontes curtos porque a série contém um movimento de venda plantado. Isso não é edge e não sobrevive a uma interpretação fora da amostra. Não há Bonferroni, White Reality Check, Hansen SPA, deflated Sharpe, bootstrap em bloco nem Newey-West. Trades sobrepostos no horizonte de 15 ou 30 minutos são dependentes; a média não corrige essa dependência.

`claim_level` fica `exploratory`, ou `contaminated_reserved` se alguma barra cai em `--reserved-start`/`--reserved-end`. Esse intervalo sai da métrica primária. Não é uma amostra nova.

## 9. Sessões

Depois de converter o relógio para UTC (`timestamp_kind=utc`, ou `server` menos `--server-utc-offset`), a etiqueta do trade é:

- Ásia: minuto do dia `< 08:00`
- Londres: `< 14:30`
- Nova York: `< 22:00`
- resto: `late`

Horário de verão não é calculado. Offset errado desloca a família E inteira.
