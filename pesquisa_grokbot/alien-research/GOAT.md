# GOAT 2-Step 1% Floating (US$ 5.000): dá pra passar com robô?

**Resposta curta:** com o que existe de vantagem real nos dados, **passar é possível, mas leva anos, não semanas**.
- A melhor configuração realista passou as **duas fases em até 12 meses em só ~8–18% das simulações** e **em até 24 meses em ~31–36%**.
- O tempo mediano para passar as duas fases ficou entre **1,5 e 2,5 anos**.
- **Não existe nos dados um robô que passe em 1–2 meses** sem que isso seja, na prática, aposta.
- Os seus robôs (ALIEN V11 / V11.2 GOAT 10K) têm configurações que **podem estourar a regra de US$ 50 flutuantes num único movimento do ouro** (seção 4).

Regras usadas (FAQ oficial da Goat, consultado em 14/11/2026, https://help.goatfundedtrader.com/en/articles/13575348-2-step-goat-model):
- Fase 1: meta de **8%** (US$ 400). Fase 2: meta de **6%** (US$ 300). Cada fase exige 3 dias com lucro de ≥ 0,5%.
- Perda diária de **4%**, calculada sobre o maior entre saldo e equity às 17h de NY.
- Perda máxima de **10% estática** (US$ 4.500 de piso).
- **Perda flutuante somada de 1% = US$ 50 → conta encerrada na hora**, em todas as fases, sem aviso.
- **VPS/VPN proibidos** desde 06/10/2026. O EA tem de ser seu (com prova de código). Martingale, grid de recuperação e hedge são proibidos.

---

## 1. O que os seus logs mostram (XAUUSD, 04/11/2026, cerca de 1h30)

| Log | Magic | Período (horário do servidor) | Eventos |
|---|---|---|---|
| A | 802110 | 05:43 → 06:49 | 57 CONFLUENCE_BAR, 160 SWEEP_OBSERVED_SELL, 74 SWEEP_OBSERVED_BUY |
| B | 802120 | 06:49 → 07:14 | 26 CONFLUENCE_BAR, 25 SWEEP_OBSERVED, **8 CENT_VETO** |

> Os arquivos originais são UTF-8, não UTF-16. As cópias "decodificadas" antigas estavam corrompidas; refiz a partir dos originais.

**O que o EA estava fazendo:**
- A cada minuto ele dá uma nota de confluência de 0 a 4 por lado. Os grupos são FLUXO+, POI (ZONA/FIB), BREAK_M1, RETEST_OK e PA_FORCA/PA_DEFESA.
- Houve **BUY 4/4 duas vezes** e várias notas 3/4, mas **nenhuma ordem, entrada ou saída aparece no log**. Ou não operou, ou a execução não é registrada (falha de log).
- No log B o motivo do bloqueio aparece:
  - 7 vezes "sem pullback e retomada fechada M1";
  - 1 vez "ATR ou spread ruins".

**Problemas encontrados:**
1. **O "sweep" é registrado a cada tick.** Foram 234 eventos para só 25 níveis no log A. Cada nova máxima vira um novo "sweep", porque o nível passa a ser o último extremo. Na prática o EA chama de "sweep" qualquer preço em tendência. Em 1h o ouro subiu de 3933 para 3955 e o EA registrou dezenas de "SWEEP_SELL" seguidos, ou seja, sinais de venda contra uma alta de US$ 20.
2. **FLUXO+ aparece em quase todas as barras** (38 de 57 e 26 de 26). Um filtro que está sempre ligado não filtra nada.
3. **Faltam no log o tamanho da posição e o risco.** Não há lote, SL, TP, flutuante atual nem resultado. Sem isso não dá para auditar se a regra dos US$ 50 está sendo respeitada.
4. **Dois magics diferentes** (802110 e 802120), e nenhum deles está nos códigos-fonte que você mandou (802090 e 802092). Então os logs são de outra versão (com "CENT_VETO").
5. **Risco de gap e flutuante:** nada no log mostra uma trava de flutuante somado nem o fechamento antes do fim de semana (ver seção 4).

## 2. O que a Goat oferece (pesquisa de 14/11/2026)

- **Instrumentos:** FX, índices CFD (inclui US500, NAS100/US100 e GER40), metais, commodities, ações e cripto. Fonte: https://help.goatfundedtrader.com/en/articles/10741905-what-instruments-can-i-trade
- **Comissão:** US$ 5 por lote (ida e volta) em FX e metais. **US$ 0 em índices**, com spread raw. Fonte: https://help.goatfundedtrader.com/en/articles/10742044-how-does-the-commission-work-for-different-trading-instruments
- **Swap:** cobrado em todas as contas, sem conta islâmica. Fonte: https://help.goatfundedtrader.com/en/articles/15073594-do-you-offer-islamic-or-swap-free-accounts
- **Fim de semana:** pode segurar posição. Na conta financiada, o lucro de trade aberto nas 3 últimas horas de sexta e fechado nas 3 primeiras de segunda é removido. Fonte: https://help.goatfundedtrader.com/en/articles/14123389-do-you-allow-trading-the-weekend-gap
- **Alavancagem:** 1:100 em FX e 1:20 em índices e commodities na avaliação. No financiado cai para 1:50 e 1:10. Notícia: o lucro de trades a ±5 min de notícia vermelha fica limitado a 1%. Fonte: resumo de terceiros, proea.app.
- **Especificação de contrato:** sites de terceiros dizem US500/US100 com lote mínimo de 0,1, contrato de US$ 1 por ponto por lote e swap comprado de cerca de −3,6/−3,9 por lote por dia. **Confira no MT5 da Goat** (botão direito no ativo → Especificação). Isso muda o tamanho mínimo de risco (seção 3).

## 3. Simulação: passar a Goat com as únicas vantagens robustas

**Estratégias:**
- **MR:** a cesta de reversão diária dos índices do RESULTS_V2: RSI2 < 10 e IBS < 0,25, acima da SMA200, no US500, NAS100 e DE40. Segura de 1 a 10 dias, dorme posicionada.
  - Versão original com stop de 3–4 ATR, mais variantes com stop de 0,5, 1 e 2 ATR.
  - 2015–2026: 1.208 trades, acerto de 71%, **+0,061R por trade**; em 2026, +0,034R.
- **CAL:** o calendário intradiário (segunda, véspera de feriado, virada do mês, véspera/dia de FOMC). Compra às 10h NY, SL 0,5 ATR, TP 1 ATR, zera às 16h.
  - No H1 de 2015–2026: +0,015R por trade e **−0,009R em 2026**. É fraco, e foi escolhido olhando os mesmos dados, então o resultado é otimista.

**Como simulei:**
- **132 inícios**, um por mês, de nov/2015 a out/2026. Fase 1 e depois Fase 2, sem limite de tempo.
- O risco por trade em US$ foi fixado e o lote arredondado para baixo (passo de 0,01 ou 0,1).
- Novo trade só entra se o risco aberto somado ficar ≤ US$ 45.
- O **flutuante somado foi conferido em toda barra H1**, usando o pior preço da barra para todas as posições ao mesmo tempo e incluindo spread, swap e gap através do stop.
- Custos: comissão zero, spread raw da Dukascopy (mínimos de 0,6/2,0/1,5 pt) e swap comprado de −7,2%/ano.

**Resultados principais** (percentual dos inícios):

| Estratégia | Risco por trade | Fase 1 em 6m | Fase 1 em 12m | **As duas fases em 12m** | **As duas fases em 24m** | Passa um dia | Estoura (10%) | Mediana até passar as duas |
|---|---|---|---|---|---|---|---|---|
| MR cesta (stop 3–4 ATR) | US$ 8 a 45 | 0% | 0% | **0%** | **0%** | 0% | 0% | Fase 1 leva ~7 anos |
| MR stop 0,5 ATR | US$ 15 (até 3 posições) | 10% | 23% | 6% | 31% | 47% | 26% | 687 dias |
| MR stop 0,5 ATR | US$ 30–45 | 0–2% | 0–2% | 0–2% | 0–2% | 0–2% | **90–95%** | — |
| CAL calendário | US$ 22 (até 2 posições) | 13% | 23% | 8% | 21% | 39% | 36% | 854 dias |
| CAL calendário | US$ 45 (1 posição) | 14–17% | 25–28% | **13–18%** | **31–36%** | 48–49% | **28–30%** | 551–641 dias |
| **MR + CAL** | US$ 15 (até 3) | 3% | 17% | 0% | 18% | 77% | 0% | 1.442 dias |
| **MR + CAL** | **US$ 45 (1 posição)** | **13%** | **32%** | **8%** | **33%** | **76%** | **0%** | **915 dias (~2,5 anos)** |

**Leitura direta:**
- **A regra dos US$ 50 não foi estourada em nenhuma simulação**, porque todo trade tem stop e o risco aberto somado fica ≤ US$ 45. O que mata é o **piso de 10%** quando o risco por trade sobe e a estratégia é fraca (CAL a US$ 45 estoura em ~30% dos inícios).
- **A reversão diária, que é a vantagem mais sólida, é lenta demais para a Goat.** O stop largo de 3–4 ATR obriga a usar lote pequeno, e a US$ 45 por trade ela rende cerca de US$ 50–60 por ano. A Fase 1 levaria de 7 a 9 anos. Apertar o stop para caber mais lote **destrói** o resultado: com stop de 1 ATR a US$ 30–45, o estouro fica entre 55% e 95%.
- **A combinação MR+CAL a US$ 45 com 1 posição por vez** é o melhor equilíbrio: 0% de estouro e 76% de aprovação em algum momento, mas a **mediana é ~2,5 anos** e só ~1 em 3 passa as duas fases em 2 anos.
- **Não existe variante "mais agressiva" que melhore isso.** Com mais risco por trade a meta chega mais cedo nos casos de sorte, mas o estouro dos 10% sobe junto. O limite de US$ 50 deixa o risco por trade em no máximo ~0,9% da conta.
- **Ouro não cabe** na estratégia de virada do mês: o lote mínimo de 0,01 (1 oz), com stop de 2 ATR diário (~US$ 90), passa de US$ 50.
- **FX:** nenhum efeito sobreviveu no MERCADO.md, então não foi incluído.

**Cuidados:**
- 2015–2026 foi um período de alta forte nos índices, e estratégias só compradas se beneficiaram disso.
- O CAL foi escolhido olhando esses mesmos dados e em 2026 está levemente negativo.
- A checagem do flutuante usa barras H1; um pico dentro do minuto pode ser pior.
- Os resultados reais devem ser **piores** que a tabela.

## 4. O seu robô: ALIEN V11 / V11.2 GOAT 10K

> O .ex5 e os dois .set com os nomes citados **não chegaram na pasta de anexos**. Usei o que veio nos zips: `ALIEN_V11_SCALPER.set` (kit de teste), `ALIENLAB3M_…_SIMULADO.set`, os .mq5 do V11, V11.2 GOAT 10K, V12 e V12.1 e os relatórios do Strategy Tester. Os .ex5 são criptografados e não têm texto legível (copyright ou versão). Não tentei descompilar.

**Identificação:**
- `#property version "10.88"`, descrição "ALIEN V11.2 GOAT 10K LAB - Sweep + BOS Retest, mapa AMD, painel professor".
- V12/V12.1 "INSTITUTIONAL – Blindagem Total Goat 10K".
- Existe o código-fonte (.mq5), com 194–198 parâmetros. É uma família de EAs feitos sob medida (V10.89 → V11 → V12), não um EA comercial de prateleira.
- Pela regra da Goat, o EA precisa ser "desenvolvido por você", com o código como prova. Ter o .mq5 ajuda.

**Parâmetros principais e diferenças (V11 SCALPER .set contra o padrão do V11.2 GOAT 10K):**

| Parâmetro | SCALPER .set | GOAT 10K | Problema na Goat de US$ 5k com 1% flutuante |
|---|---|---|---|
| FixedLot | 0,01 | **0,18** (o teste DESAFIO usou 0,20) | No ouro, 0,18 lote = US$ 18 por US$ 1 de movimento. **Um movimento contra de US$ 2,8 já soma US$ 50 → conta encerrada** |
| MaxOwnPositions | 2 | 2 | Duas posições de 0,18 = 0,36 lote: **US$ 1,40 contra já encerra a conta** |
| RiskStopMoney (stop por posição) | 2 | **40** | 2 × 40 = US$ 80 de risco aberto, **acima do limite de US$ 50** |
| MaxAdaptiveStopRiskMoney / MaxAdaptiveLot | 2 / 0,02 | 50 / 0,40 | Teto de US$ 50 por posição = o limite inteiro da conta |
| **MaxFloatingLossMoney** | 0,35 | 25 | **Na prática está desligado:** no código ele só funciona se `StopOnlyRunnerMode=false` (linha 2575), e os dois arquivos usam `StopOnlyRunnerMode=true` |
| DailyMaxLossMoney / Weekly | 4 / 12 | 140 / 400 | Valores pensados para conta de US$ 10k. Na de 5k, US$ 140 é 2,8% por dia |
| UseNY0830Blackout / UseNY1000Blackout | false | false | **Opera em notícia** (NFP, CPI). No ouro, um candle de notícia anda US$ 10–30 → estouro garantido com 0,18 lote. Além disso, a Goat limita o lucro de trades perto de notícia |
| Fechar na sexta / fim de semana | não existe | não existe | Nenhum parâmetro de sexta ou fim de semana no código. O dia da semana só é usado para o reset semanal |
| SL "estrutural" mínimo | 0,15 ATR M1 | igual | Stop de US$ 1–3 no ouro em 2026 fica dentro do ruído, e o spread come de 15% a 35% do risco (RESULTS.md: entrada aleatória com esse stop dá −0,14R) |
| MaxHoldSeconds / ExitOnTimeout | 180 / false | 180 / false | O tempo máximo existe, mas está desligado |

O `ALIENLAB3M` (outro EA, mais simples) usa risco de 0,25%, perda diária de 1% e no máximo 3 entradas por dia. Essa configuração é bem mais segura.

**O que os relatórios do Tester mostram:**
- Todos os testes do V11 cobrem só **1 a 2 semanas**.
- **V11 a 0,01 lote:**
  - Semanas 1 e 2 de outubro positivas: +33,6 e +13,7.
  - 19–24/10: +10,5.
  - **26–31/10: −12,4 (PF 0,38).**
  - **02–07/11: −8,0 (PF 0,69) e −11,5 no V11.1 (PF 0,48).**
- O "GOAT 10K DESAFIO" de **+US$ 702 (PF 2,31)** e o EXP_014 de +US$ 748 cobrem **exatamente as duas semanas boas** (05–17/10). As semanas seguintes, no mesmo lote, equivaleriam a **cerca de −US$ 140 a −US$ 220 por semana**.
- O único teste longo (ALIEN_LAB_3MESES, ago–nov/2026, M5) deu **−US$ 445, PF 0,83, DD de 7,6%**.
- **Isso explica as perdas:** o resultado bom vem de escolher as semanas boas, e a vantagem some quando o período aumenta.

**Para não perder a conta Goat por causa do robô** (se insistir em rodar):
1. Lote ≤ 0,02 no ouro e **MaxOwnPositions = 1**.
2. Stop × lote ≤ **US$ 30** (sobra margem para slippage e gap até US$ 50).
3. Trava de flutuante somado que funcione de verdade (`StopOnlyRunnerMode=false` ou corrigir o código), fechando tudo a −US$ 35.
4. Ligar o bloqueio de notícias e **fechar tudo às 16:50 NY de sexta**.
5. Registrar no log o lote, SL, TP, flutuante e resultado de cada trade.

**Mesmo assim o setup em si (sweep/BOS no M1 do ouro) não tem vantagem** nos 6 anos de dados (MERCADO.md e RESULTS.md).

## 5. Veredito

- **Passar a Goat de US$ 5k com 1% flutuante usando um robô honesto é realista só no prazo de 1 a 3 anos**, com uma chance de ~1 em 3 de passar as duas fases em 24 meses (MR+CAL ou CAL a ~US$ 45 por trade).
- **Em 1–3 meses, não existe forma confiável.** Quem "passa rápido" está apostando, e na maioria das vezes perde a taxa.
- **O ALIEN V11/V11.2 com os parâmetros GOAT 10K numa conta de 5k com 1% flutuante tem risco alto de ser encerrado num único movimento ou notícia do ouro.** A trava de flutuante dele está desligada.
- **Caminho mais honesto:** rodar a cesta MR (+ calendário) **numa conta própria pequena** (cent, US$ 20, como planejado), conferir por 3–6 meses ao vivo que o resultado bate com o teste, e só depois pagar uma avaliação. De preferência sem a regra de 1% flutuante, que é feita para encerrar contas.

Arquivos: `code/goat/goat_sim.py`, `run_goat.py`, `out/goat_sim_v1.csv` (MR 3–4 ATR), `out/goat_sim_v2.csv` (CAL, MR+CAL e MR com stop curto), `out/goat_mr_trades.parquet`, `out/goat_cal_trades.parquet`. Logs: `/workspace/vitor_logs/`. EA: `/workspace/vitor_ea/`.
