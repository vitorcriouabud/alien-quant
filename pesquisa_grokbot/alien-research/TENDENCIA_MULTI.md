# TENDÊNCIA EM VÁRIOS MERCADOS (time-series momentum) — pré-registro
Escrito em 15/11/2026, ~01:15 (horário de Brasília), **antes de rodar qualquer resultado de estratégia**.
Até aqui só baixei os dados diários e conferi a qualidade (datas de início, buracos, saltos). Nenhum backtest rodado.

## Pergunta
O efeito de tendência publicado (Moskowitz, Ooi & Pedersen 2012, "Time Series Momentum"; Hurst, Ooi & Pedersen
"A Century of Evidence on Trend-Following") funciona numa **cesta de mercados que dá para operar na RoboForex MT5**,
depois de spread, comissão e **swap realista**? E, se funcionar, juntar com a cesta de índices RSI2/IBS deixa a curva mais constante?
No ouro sozinho já foi reprovado (FRENTES.md). O efeito publicado é de carteira com muitos ativos; esta é a última peça que faltava.

## Universo (19 mercados, todos existem como CFD na RoboForex)
- Forex (7): EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF, NZDUSD
- Índices (8): US500, NAS100 (USTEC), US30, DE40, UK100, JP225, F40, AUS200
- Commodities (4): XAUUSD, XAGUSD, WTI, Brent
- Dados: Dukascopy D1 bid/ask, 01/2010 → 13/11/2026 (`data/d1/`). Preço = meio (bid+ask)/2. Fins de semana sem negociação descartados.
  US30 e DE40 começam em 30/09/2013; AUS200 em 06/2014. Cada mercado entra quando tem 1 ano de histórico.

## Regras (6 tentativas, todas comprado/vendido, iguais em todos os mercados — nada otimizado por mercado)
| id | sinal (calculado no fechamento do dia t) |
|---|---|
| M3 | sinal do retorno de 63 dias (3 meses): +1 se subiu, −1 se caiu |
| M6 | idem, 126 dias (6 meses) |
| M12 | idem, 252 dias (12 meses) |
| MB | média de M3, M6, M12 (valores −1, −1/3, +1/3, +1) |
| D50 | Donchian: compra no fechamento acima da máxima dos 50 dias anteriores, vende abaixo da mínima de 50; sai na mínima/máxima oposta de 25 dias |
| D100 | idem com 100 / 50 |

- **Execução com 1 dia de atraso:** sinal no fechamento do dia t, posição muda no fechamento do dia t+1 (conservador).
- **Tamanho por volatilidade:** vol de cada mercado = desvio-padrão EWMA (span 60 dias) dos retornos diários, anualizado.
  Alvo por mercado = 10% / √N (N = mercados ativos naquele dia). Posição = sinal × alvo / vol.
- **Teto de risco da carteira:** vol ex-ante da carteira (covariância dos últimos 120 dias) limitada a 10% ao ano — só reduz, nunca alavanca para cima.
  Teto de alavancagem nocional total 3× o capital.
- **Banda anti-giro:** só ajusta a posição se a diferença para o alvo for > 25% do alvo (ou se o sinal mudar de lado).

## Custos (decididos antes)
- Spread: máx(spread Dukascopy do dia, spread médio publicado da RoboForex) + slippage de 25% do spread, pago em cada mudança de posição.
  Pisos: EURUSD 1,3 pip, GBPUSD 1,5, USDJPY 1,6, AUDUSD 1,5, USDCAD 2,0, USDCHF 2,0, NZDUSD 2,0; US500 0,6; NAS100 2,0; US30 3,0;
  DE40 1,5; UK100 1,5; JP225 10; F40 1,5; AUS200 2,0; XAU 0,40; XAG 0,04; WTI 0,05; Brent 0,05.
  (Spreads de conta sem comissão — já embutem o custo. Ouro com comissão ECN real de US$ 16,80/lote ≈ US$ 0,17/oz cai no mesmo piso.)
- **Swap (financiamento), por dia corrido, sobre o nocional, usando juros básicos aproximados de cada ano** (Fed, BCE, BoE, BoJ, RBA, BoC, SNB, RBNZ — tabela no código):
  - Forex: swap = mín(0, diferencial de juros a favor da posição − 2%). **Nunca recebo swap positivo** (conservador).
  - Índices: compra paga (juros da moeda + 2,5%); venda paga máx(0, 2,5% − juros). Nunca recebe.
  - Ouro, prata, petróleo: compra paga (juros USD + 2,5%); venda paga máx(0, 2,5% − juros USD). Nunca recebe.
- Sensibilidade (só informação, não decide): custos ×1,5 e taxa extra de +1%/ano no swap; e "creditando metade do swap positivo".

## Divisão dos dados
- **IS (dentro da amostra): 2011–2024** (2010 só para aquecer os indicadores).
- **Validação: 2025.**
- **2026 (até 13/11): guardado. Abro uma vez só, só para sobreviventes.**

## Critérios de reprovação (qualquer um reprova)
1. **Estatística:** t do Sharpe no IS (Sharpe anual × √anos) < 2, ou não passa em Benjamini-Hochberg a 10% entre as 6 tentativas.
   (Bonferroni 5%/6 reportado também.)
2. **Constância:** menos de 9 dos 14 anos IS positivos.
3. **Dependência de um ano:** tirando o melhor ano IS, CAGR ≤ 0.
4. **Dependência de um mercado:** tirando o mercado que mais lucrou, Sharpe IS < 0,3.
5. **Custos:** com custos ×1,5 e swap +1%/ano, Sharpe IS < 0,3.
6. **Validação 2025:** retorno < −5% (meia volatilidade-alvo).
7. **Só "beta":** se a regressão dos retornos diários contra uma carteira só-comprada com o mesmo tamanho por volatilidade der alfa ≤ 0.

## Carteira com a cesta de índices (só se houver sobrevivente)
Cesta RSI2/IBS (US500, NAS100, DE40; 1% de risco; custos RF, já calculada em FRENTES.md). Combinação pré-definida: 50% do capital de risco em cada
(retornos diários somados com peso 0,5/0,5 e também 1/1 — mesma conta, os dois robôs ao mesmo tempo). Reporto: CAGR, DD máximo (marcado a mercado),
pior ano, % meses positivos, correlação diária e mensal. Combinação só é "melhor" se o Sharpe subir e o DD máximo não piorar em relação à cesta sozinha no IS.
Mesmo se ninguém sobreviver, reporto a correlação só como informação.

## Viabilidade em conta pequena
Para sobrevivente: com lote mínimo 0,01, calculo o capital mínimo para que o arredondamento do lote erre o tamanho em menos de 25% em 80% dos dias
(conta Pro/ECN em dólar e ProCent).

## Registro de tentativas
6 tentativas novas. Acumulado do projeto antes desta rodada: ~2.277 (RESULTS, V2, SMC, DESLOCAMENTO, FRENTES). Toda mudança de regra depois de ver resultado = tentativa nova, registrada aqui.

---
# RESULTADOS (rodado em 15/11/2026, ~01:30 horário de Brasília)
Código: `code/tendencia/tsmom.py` (motor), `run.py` (6 tentativas + critérios), `diag.py` (diagnóstico), `corr.py` (cesta).
Saídas: `out/tendencia/summary.csv`, `out/tendencia/daily_ALL.parquet` (inclui 2026, **não lido** — ninguém sobreviveu, então 2026 continua guardado).
Única interpretação feita depois: "spread + slippage de 25%" = meio spread + 25% do spread em cada mudança de posição (ida e volta = 1,5 spread).

## Veredito: **nenhuma das 6 passou. Resultado nulo.** As 6 perdem dinheiro no IS 2011–2024 depois dos custos.

| Regra | CAGR IS | Sharpe | t | DD máx | anos + (de 14) | bruto/ano | spread/ano | swap/ano | 2025 |
|---|---|---|---|---|---|---|---|---|---|
| M3 | −6,4% | −0,58 | −2,19 | 69% | 3 | +1,4% | −2,4% | −5,0% | −5,4% |
| M6 | −5,7% | −0,49 | −1,85 | 62% | 6 | +1,6% | −1,8% | −5,1% | −7,4% |
| M12 | −3,1% | −0,26 | −1,00 | 44% | 5 | +3,7% | −1,3% | −5,1% | +9,5% |
| MB | −4,0% | −0,33 | −1,26 | 53% | 5 | +3,0% | −2,0% | −4,6% | −1,2% |
| D50 | −7,1% | −0,62 | −2,37 | 67% | 3 | −1,6% | −1,0% | −4,2% | +7,4% |
| D100 | −4,7% | −0,38 | −1,44 | 54% | 3 | +0,7% | −0,5% | −4,3% | −5,2% |
| Ref.: só comprado, mesmo tamanho | −1,0% | −0,04 | −0,14 | 38% | — | — | — | — | +4,3% |

(Volatilidade realizada ~10–11% ao ano em todas, como planejado.) BH 10%: 0 de 6. Bonferroni: 0. Critérios 1, 2, 3, 4, 5 e 7 reprovam todas.

## Por que não funcionou (em português simples)
1. **O efeito bruto existe, mas é pequeno nesse período e nesse universo:** antes de qualquer custo, o Sharpe foi 0,28 (MB) a 0,36 (M12).
   Mesmo com custo zero, o t ficaria em ~1,0–1,3 — abaixo de 2. 2011–2024 foi uma época fraca para tendência, e a cesta da RoboForex
   **não tem títulos/juros**, que foram a maior fonte de lucro dos fundos de tendência (ex.: 2022).
2. **O swap do CFD mata o resto:** para ter 10% de volatilidade com 19 mercados a carteira fica ~2× alavancada em nocional, e o swap
   de corretora (juros + taxa da corretora, sem receber o lado positivo) custa ~4–5% do capital por ano. Nos estudos publicados, com futuros,
   esse custo praticamente não existe. **É a diferença entre o artigo e a conta da RoboForex.**
3. **Spread do giro diário:** mais 0,5–2,4% ao ano. Só com spread (sem swap) o Sharpe cai para 0,10–0,23.
4. Sensibilidade (informação): creditando metade do swap positivo, quase não muda (Sharpe −0,25 a −0,62). Com custos ×1,5, Sharpe −0,83 a −1,22.

## Junto com a cesta de índices (informação, IS 2016–2024)
Correlação diária com a cesta RSI2/IBS: +0,05 a +0,15 (mensal −0,00 a +0,23). Baixa, mas como a tendência perde dinheiro,
juntar só piora: Sharpe da cesta sozinha 1,43 → combinada 50/50 entre −0,35 e +0,14; DD de 6,1% → 15–22%.
**Conclusão: não juntar.** A cesta de índices continua sozinha como a única coisa aprovada.

## Viabilidade em conta pequena / EA
Sem sobrevivente → não calculei lote mínimo e **não escrevi EA** (seria construir em cima de algo reprovado). Observação: ela precisaria
de 19 posições ao mesmo tempo; com lote mínimo 0,01 isso já exigiria conta grande, e índices/petróleo não existem na ProCent.

## O que continua desconhecido
- Swap histórico exato da RoboForex (usei juros aproximados + taxa de 2–2,5%). Mesmo sem nenhum swap a estatística não chega a t = 2.
- Tendência com futuros de verdade (títulos, juros, dezenas de commodities) e corretora de futuros — fora do alcance da conta MT5 CFD.
- 2026 não foi aberto.

## Registro
6 tentativas novas (M3, M6, M12, MB, D50, D100), todas reprovadas. Diagnósticos (bruto, por classe, sem swap) não contam como tentativa
e não mudaram regra nenhuma. Acumulado do projeto: ~2.283 tentativas.
