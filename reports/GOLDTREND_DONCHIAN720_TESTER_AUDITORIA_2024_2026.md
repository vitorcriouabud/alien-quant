# ALIEN LAB — Auditoria GoldTrend Donchian 720 (2024–2026), realizada 18/11/2026

**Fonte primária do teste**: `ReportTester-67316641(20261118-045201).html` e captura do Journal, fornecidos pelo usuário. Não publicar histórico ou login. Configuração reportada: EA GoldTrendM1 (implementação v1.10 marcada pelas ordens `GTM1_10_720`), XAUUSD M1, Janela H1 720, Stop 3 ATR, Trail 7 ATR, risco 0,25%, depósito simulado USD 10.000 e alavancagem 1:100.

## O que o Strategy Tester de fato fez

- Período no **HTML**: **01/08/2024 a 17/11/2026**. O início solicitado inicialmente (janeiro/2024) não foi efetivamente coberto.
- **Qualidade**: 3% de ticks reais; 806.122 barras; 211.334.601 ticks gerados/efetivamente processados. Cerca de 97% do teste não foi confirmado como ticks reais.
- Lucro líquido de +USD 392,54; bruto +554,41; perdas brutas -161,87.
- Profit Factor 3,43; 21 negócios (42 deals, 12 ganhos e 9 perdas); drawdown máximo de **equity** USD 119,60 / 1,16%.
- Comissão -USD 1,41, swaps -USD 42,06. A soma do lucro sem esses itens foi +USD 436,01, antes de swap e comissão.
- A última **entrada** ocorreu em **22/09/2025**; última **saída** em **24/09/2025**. **Zero operações em 2026**, embora a curva e o relatório se estendam até novembro/2026.
- O Journal mostra repetidamente `GOLDTREND_TESTER: SEM ORDEM: lote minimo ultrapassa risco` em 2026. Isso é um bloqueio **deliberado**, e não erro de compilação ou falha de envio.

## Análise das 21 operações (reconstruídas das 42 transações do HTML)

| Ano da abertura | Operações | Compras | Vendas | Resultado líquido |
|---|---:|---:|---:|---:|
| 2024 (agosto–novembro) | 8 | 7 | 1 | +USD 175,19 |
| 2025 (janeiro–setembro) | 13 | 13 | 0 | +USD 217,35 |
| 2026 | 0 | 0 | 0 | USD 0,00 |
| **Total** | **21** | **20** | **1** | **+USD 392,54** |

- Ganho da direção compradora: +USD 368,30, 20 trades. Venda única: +USD 24,24. Não confundir esta predominância de compras com robustez em um regime lateral/baixista.
- Cinco maiores operações positivas somaram **+USD 375,04**, ou **95,5%** do resultado total. Os 16 trades restantes, somados, renderam apenas **+USD 17,50**.
- Reamostragem exploratória iid de 21 trades, 10 mil repetições, média +USD 18,69 por trade e intervalo percentil 95% de cerca de +USD 2,87 a +USD 36,14 por trade. **Não interpretar isso como prova de vantagem**: amostra selecionada, trades dependentes, regime de alta, 0 trades em 2026 e majoritariamente ticks modelados. A amostra é pequena.

## Por que houve zero novas ordens após setembro/2025?

O código `VolumeForRisk` limita a perda monetária estimada da ordem ao orçamento `Account Balance × InpRiskPercent / 100`, via `OrderCalcProfit`; caso o volume calculado fique abaixo do `SYMBOL_VOLUME_MIN`, retorna volume zero. `TryOpen` então pula a ordem.

No depósito **US$ 10.000** com risco de **0,25%**: orçamento inicial ~USD **25**, posteriormente ~USD **26** com o lucro. Na configuração comum de ouro em que 0,01 lote representa 1 onça (confirmar `SYMBOL_TRADE_CONTRACT_SIZE` da corretora), um stop de 3 × ATR(H1) maior do que USD 26 na cotação gera risco superior ao orçamento até no mínimo de 0,01 lote. Em cenários de maior volatilidade, o robô corretamente **se recusa a abrir**. O Journal registrado em 2026 confirma este motivo em vários sinais. Outras restrições (spread, horários) ainda podem filtrar sinais adicionais.

**Não corrigir** forçando o lote mínimo nem aumentando o risco somente para gerar mais trades. Repetições do log podem ser silenciadas com `InpVerbose=false`, mas durante diagnóstico é útil manter `true`.

## Testes seguintes (SEM mudar lógica da estratégia)

1. **Teste A — capacidade mecânica da estratégia:** depósito **fictício** do Strategy Tester = **USD 100.000**, `InpRiskPercent=0.25`, janela 720, stops 3/7 ATR, janela 2024-01-01 a 2026-11-17, timeframe M1, `Cada tick baseado em ticks reais`, otimização desligada. Enviar HTML e Journal. Esse capital adicional não representa recomendação de depositar fundos nem desempenho real de conta pequena.
2. **Teste B — viabilidade de capital de usuário:** repetir **mesma configuração** mas com depósito **USD 10.000** (como já feito) e, se relevante, em **USD 30.000** (somente fictício), para estudar se o risco estrito e o volume mínimo permitem operar em 2026. Nunca alterar parâmetros para “forçar” operações no comparativo.
3. **Testar dados reais:** exigir qualidade significativamente maior que **3% de ticks reais** para confirmação de execução. Se broker não oferece histórico real, rotular **simulação modelada** e testar outro feed/tick histórico.
4. **Separar resultados:** 2024, 2025, 2026 por ano, e notas de diferença de regimes, risco R, taxas de rejeição e custo. Não confundir **ausência de ordens** por limite com ausência de sinais de estratégia.
5. **Não otimizar** tamanho do trailing ou janela usando 2024–2026 em resposta aos resultados mostrados; esses anos já foram examinados.

## Veredito provisório

**Positivo no histórico disponível**, mas lucro concentrado e fortemente associado a compras; **não validado em 2026 como estratégia executável para saldo USD 10 mil a risco 0,25%**, porque mínimo de volume foi impeditivo. A qualidade do feed (3% real tick) também impede conclusão de rentabilidade executável. É preciso avaliar com tamanho de banca fictícia suficientemente grande para que os sinais sejam efetivamente negociados, e validar com ticks Bid/Ask reais.
