# Teste com ticks reais: ALIEN V11 SCALPER

Teste honesto no Strategy Tester do MT5 (build 6320, Wine), conta **demo** RoboForex-ECN [login da demo omitido]. Não houve ordem na conta ao vivo nem na mesa Goat. Depósito do testador: US$ 10.000, alavancagem 1:100, XAUUSD M1, modelo 4 (cada tick baseado em ticks reais). Lote 0,01, mesmo `.set` dos testes do Vitor.

Data dos testes: 15/11/2026 (horário de Brasília).

## O que o testador de fato usou

- **Intervalo pedido (01/08 a 13/11/2026): só 13% de ticks reais.** O servidor da RoboForex só entregou ticks reais a partir de **30/10/2026**. De agosto até 29/10 o testador preencheu com ticks gerados. O diário do agente confirma: `real ticks begin from 2026.10.30` e `received too many containers without changes`.
- Por isso o lucro grande do período inteiro **não pode ser lido como resultado real**.
- Já a semana isolada **02/11 a 07/11/2026** saiu com **100% de ticks reais** (2.678.646 ticks, 6.875 barras) e bateu **exatamente** com o relatório que o Vitor já tinha: lucro líquido −7,97, fator de lucro 0,69, 65 negócios, 27,69% de acerto.

## Custos da conta ECN

Lidos no próprio terminal (símbolo XAUUSD da demo) e no site da RoboForex:

| Item | Valor |
| --- | --- |
| Tamanho do contrato | 100 oz por lote |
| Lote mínimo / passo | 0,01 / 0,01 |
| Tick | 0,01 (vale US$ 1 por lote) |
| Spread | flutuante; média publicada 5 pontos; no probe 5–6 pontos |
| Swap | longo −60, curto +19 (em pips, como no site) |

**Comissão publicada** da RoboForex ECN: **US$ 20 por milhão de volume, em cada lado** ([especificação do XAUUSD](https://roboforex.com/forex-trading/trading/specifications/card/pro-stan-ecn/XAUUSD/) e [FAQ](https://roboforex.com/help/faq/trading-mt4-mt5/how-is-the-commission-for-trading-on-prime-ecn-accounts-calculated/)). No ouro isso **não** é um valor fixo: com 100 oz e ouro perto de US$ 4.200, daria cerca de US$ 8,40 por lado, ou ~US$ 16,80 ida e volta.

**O que o testador desta demo realmente cobrou:** US$ 0,04 por 0,01 lote **em cada lado** (US$ 4 por lote / lado, US$ 8 ida e volta), valor fixo, em todos os deals. É o mesmo valor que já aparecia nos relatórios antigos do Vitor. Não é a regra 20/mio. Pode ser simplificação da conta demo ou do testador; no live isso precisa ser conferido.

Essa comissão **já entra sozinha no lucro líquido oficial** dos relatórios. O parâmetro `RoundTurnCommissionPerLot` do robô **não cobra de novo** no relatório: ele só entra no stop, no break-even e no cálculo de risco. Por isso o teste “com comissão 8” não soma a taxa duas vezes no lucro oficial. Os dois testes abaixo já vêm com a taxa da corretora descontada (cerca de −US$ 89 no período inteiro).

## Resultado oficial: 01/08 a 13/11/2026 (13% ticks reais)

| | Comissão no robô = 8,0 (o que o testador cobra) | Comissão no robô = 0 (como nos testes antigos) |
| --- | --- | --- |
| Qualidade | 13% ticks reais | 13% ticks reais |
| Ticks / barras | 33.005.241 / 101.496 | 33.005.241 / 101.496 |
| Lucro líquido | **+491,80** | **+479,42** |
| Fator de lucro | 3,01 | 2,90 |
| Negócios | 1.096 | 1.093 |
| Taxa de acerto | 74,36% (815 / 1.096) | 57,64% (630 / 1.093) |
| Drawdown máximo (equity) | 25,67 (0,24%) | 26,48 (0,25%) |
| Lucro bruto / perda bruta | 736,19 / −244,39 | 731,27 / −251,85 |
| Comissão já cobrada pelo testador | −89,48 | −89,24 |
| Lucro só de preço (antes da comissão) | +581,28 | +568,66 |

A diferença de acerto (74% vs 58%) vem do break-even: com `RoundTurnCommissionPerLot=8` o robô espera um pouco mais e trava o stop um pouco mais longe, e classifica mais saídas como ganho. O dinheiro no final é parecido (diferença de uns US$ 12).

## Semana a semana (mesmo período)

Nas semanas de ticks **gerados**, o robô bate o teto de 15 negócios por dia, todo dia útil: **75 negócios por semana**, e todas essas semanas fecham no azul. Nas semanas com ticks **reais** (a partir de 30/10, sobretudo novembro), ele opera menos e **perde dinheiro**.

| Semana (início na segunda) | Robô=8,0 líquido (negócios / acerto) | Robô=0 líquido (negócios / acerto) |
| --- | --- | --- |
| 03/08/2026 | +45,26 (75 / 80%) | +44,85 (75 / 61%) |
| 10/08/2026 | +37,91 (75 / 81%) | +33,30 (75 / 65%) |
| 17/08/2026 | +28,92 (75 / 75%) | +28,30 (75 / 52%) |
| 24/08/2026 | +46,58 (75 / 80%) | +45,74 (75 / 67%) |
| 31/08/2026 | +51,53 (75 / 83%) | +48,38 (75 / 71%) |
| 07/09/2026 | +44,27 (75 / 79%) | +48,77 (75 / 63%) |
| 14/09/2026 | +28,81 (75 / 73%) | +20,56 (75 / 49%) |
| 21/09/2026 | +55,46 (75 / 84%) | +52,95 (75 / 60%) |
| 28/09/2026 | +51,06 (75 / 83%) | +53,62 (75 / 64%) |
| 05/10/2026 | +34,37 (75 / 76%) | +37,31 (75 / 65%) |
| 12/10/2026 | +18,69 (75 / 79%) | +17,47 (75 / 60%) |
| 19/10/2026 | +35,83 (75 / 80%) | +35,89 (75 / 65%) |
| 26/10/2026 (mista: ticks reais só a partir do dia 30) | +32,31 (75 / 69%) | +31,43 (75 / 56%) |
| 02/11/2026 (ticks reais) | **−11,79** (61 / 38%) | **−11,74** (58 / 26%) |
| 09/11/2026 (ticks reais) | **−7,41** (60 / 42%) | **−7,41** (60 / 27%) |

## O teste que vale: 100% ticks reais (02/11 a 07/11)

Mesmos parâmetros do relatório de novembro do Vitor, `RoundTurnCommissionPerLot=0`, comissão da corretora já descontada pelo testador.

- Qualidade: **100% ticks reais**
- Lucro líquido: **−7,97**
- Fator de lucro: **0,69**
- Negócios: **65** (18 ganhos, 47 perdas; acerto 27,69%)
- Drawdown máximo (equity): **10,12 (0,10%)**
- Comissão do testador: −5,20; resultado de preço antes da taxa: −2,77

Isso reproduz o relatório antigo dele, com a mesma qualidade e os mesmos números. Neste recorte o robô **não** tem vantagem.

## Leitura honesta

O +491 / +479 do período agosto–novembro é quase todo das semanas em que o testador **inventou** ticks. Aí o robô enche o dia até o limite de 15 operações e parece uma máquina (fator 3, acerto alto). Onde os ticks são reais, o resultado vira negativo, o acerto cai para a casa dos 25–40%, e o teto diário quase não é atingido.

Conclusão: **ainda não há evidência de que a V11 ganhe dinheiro com ticks reais**. O recorte honesto que temos é curto (cerca de duas semanas com arquivo real neste servidor, e uma semana isolada a 100%). Não dá para usar o lucro de agosto–outubro para decidir comprar mesa ou aumentar lote.

## Arquivos

Relatórios HTML oficiais (e um PNG de cada):

- `/workspace/alien-research/out/V11_commECN_20260801_20261113.htm` — 01/08–13/11, robô com comissão 8,0
- `/workspace/alien-research/out/V11_comm0_20260801_20261113.htm` — 01/08–13/11, robô com comissão 0
- `/workspace/alien-research/out/V11_comm0_20261102_20261107.htm` — 02/11–07/11, 100% ticks reais

Cópias, gráficos, JSON, logs e arquivos que o próprio EA gravou: `/workspace/alien-research/out/mt5/`.

Script para repetir o teste com outro robô (por exemplo AIBOTFX, se o arquivo chegar):

```bash
/workspace/alien-research/code/run_mt5_test.sh \
  <caminho-do-ea-ou-Expert> <arquivo.set> <ativo> <tempo> <aaaa.mm.dd> <aaaa.mm.dd> <deposito> [nome-do-relatorio]
```

Ele fecha o terminal gráfico, roda só o Strategy Tester (sem senha no ini) e no fim pode reabrir o MT5 no `DISPLAY=:2`. Exemplo de modelo: `MT5_MODEL=4`.
