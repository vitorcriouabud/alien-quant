# ALIEN Lab — GoldTrendM1_v3_1 PDH/PDL: auditoria de teste MT5

**Escopo:** relatório fornecido `ReportTester-67316641(20261118-044254).html` e código fonte v3.10 colado pelo usuário. Sem alteração ao GoldTrend Donchian 720 nem ao branch `main`.

## É UMA ESTRATÉGIA DIFERENTE

| | Donchian 720 / GTM1_10_720 | PDH/PDL v3.1 |
|---|---:|---:|
| Período testado | 2020-08-01 a 2022-10-24 | 2020-08-01 a 2022-10-24 |
| Setup | Breakout N H1 e trailing stop M1 | Rompimento PDH/PDL M5, EMAs 20/50/200+ADX H1 |
| Depósito inicial | USD 10.000 | USD 10.000 |
| Risco input | 0,25% | 1,00% |
| Lucro líquido | +USD 247,41 | +USD 1.301,31 |
| Profit Factor | 1,71 | 1,17 |
| Máx. DD equity | 2,07% | 12,01% |
| Trades | 34 | 121 |
| Ticks reais | **0%** | **0%** |

Os dois testes referem-se ao MESMO período e não validam a janela nova 2024–2026. **Não comparar lucro absoluto como mérito de setup, pois risco/duração são diferentes.**

## v3.1: trades extraídos do HTML (242 deals = 121 entradas e 121 saídas)

| Subperíodo | Trades | Lucro líquido | PF calculado com trades líquidos |
|---|---:|---:|---:|
| 2020 Ago–Dez | 24 | +401,98 | 1,293 |
| 2021 | 50 | +117,19 | 1,036 |
| 2022 Jan–Out | 47 | +782,14 | 1,263 |
| Total | 121 | +1.301,31 | 1,171 |

- Compras 57, +USD 825,46; vendas 64, +USD 475,85.
- 47 ganhos, 74 perdas; custo de comissões -USD 114,87 e swap -USD 26,40 já incluídos nos resultados.
- Cinco maiores lucros juntos: USD 1.140,19; os outros 116 trades somaram apenas USD 161,12.
- 16 de 27 meses com entradas ficaram positivos.
- P&L por risco inicial estimado usando preço preenchido, SL original e contrato ~100 unidades/lote: +13,74 R totais, média +0,114R; p50 risco sobre saldo pré-entrada ~0,982%, faixa p5 0,952% e p95 0,997%. Valores aproximados.
- Reamostragem exploratória 8 mil vezes: intervalo percentil 95% da média em USD/trade [-15,08, +37,07] com amostra individual, [-22,02, +44,79] com blocos por mês. **Não comprova vantagem estatística**. Não corrige seleção de hipóteses.

## Sensibilidade hipotética a custos extras

Volume total de entradas: ~31,81 lotes; assuma contrato **100 unidades de XAUUSD por lote**, inferido dos P&Ls. Esse contrato deve ser confirmado na especificação do símbolo.

Custo adicional por operação na forma de diferença extra no preço do ouro, sobre o que já consta no relatório (não é custo observado da corretora):

| Extra na cotação (round-trip) | Lucro líquido ajustado |
|---:|---:|
| 0,00 | +USD 1.301,31 |
| 0,10 | +USD 983,21 |
| 0,20 | +USD 665,11 |
| 0,30 | +USD 347,01 |
| 0,40 | +USD 28,91 |
| 0,50 | **-USD 289,19** |

Ponto de equilíbrio aproximado: **+0,409 na cotação** por operação completa, como custo extra. O resultado é sensível à qualidade de ticks e à execução. Não se afirma que o custo observado esteja faltando: é *stress test*.

## Auditoria estática do código v3.1

- A lógica usa fechamento M5 [1] para romper PDH/PDL contra M5 [2], EMAs 20/50/200 e ADX H1 [1], e filtro de extensão da EMA20. Uma operação por dia, horário servidor 08–18, fechamento diário 22:30.
- `CalculateLotSize` eleva lote para mínimo mesmo se arriscar acima do percentual; **corrigir** se for operar menor saldo.
- Chamadas `trade.Buy/Sell/PositionClose` não validam `ResultRetcode`/deal; **corrigir** e manter logs.
- Ausência de limite diário e DD máximo para bloquear entradas (além de 1 trade/dia).
- Zeragem EOD é executada em `OnTick` e pode falhar se não chegar tick naquele horário ou houver recusa da ordem.
- Horário servidor 08–18 varia com timezone/DST broker; não inferir sessão NY a partir de hora local.
- Este EA não tem trava explícita para conta REAL; caso se crie versão demo, incluir trava e conta/símbolo/magic isolados.
- Falta de tick real (0%) torna execução M1 com stop e alvo (1ATR/2ATR) incerta.
- Cuidado: não atribuir histórico Donchian ao v3.1 nem vice-versa.

## Próximo teste congelado e indispensável

1. **Mesmo GoldTrend v3.1, mesmos inputs e depósito US$ 10.000.** Apenas alterar datas para 2024-01-01 a 2025-12-31 e depois 2026-01-01 a 2026-11-17.
2. Em paralelo repetir Donchian 720 nesses MESMOS períodos, sem alterar parâmetros. Dados/qualidade comparáveis.
3. Exigir modo `Cada tick baseado em ticks reais`, e verificar no HTML **% de ticks reais > 0**; se não houver histórico Bid/Ask, tratar como modelagem e fazer análise de sensibilidade explícita, nunca chamar de teste de ticks reais.
4. Comparar **retorno/DD, PF, R médio, resultados anuais, comissões, swaps, slippage, majors por mês e tendência**, não só lucro USD.
5. Sem otimização após ver 2024–26; esses dados já foram explorados antes e devem ser descritos como validação histórica exploratória, não prova inédita.
6. Manter exclusivamente ambiente DEMO/Tester, sem uso real.

**Veredito:** resultado positivo e auditável no tester, mas PF 1,17, DD 12,01% e ticks reais 0% não permitem inferir lucro executável nem consistência fora do período.
