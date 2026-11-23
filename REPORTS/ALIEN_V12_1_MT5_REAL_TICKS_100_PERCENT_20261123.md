# MT5 — segundo relatório de validação V12.1 (23/11/2026)

Fonte primária: `ReportTester-67315343(1).html`, recebido no chat. Este resumo não substitui o HTML original.

## Condições do ensaio
- Broker RoboForex-ECN (Build 6328), XAUUSD M1
- Período: 2026-11-13 a 2026-11-22, histórico com **100% de ticks reais** (conforme MT5)
- 8.250 barras; 3.323.422 ticks; depósito USD 5.000; alavancagem 1:100
- Inputs: `FixedLot=0.01`, `MaxRiskPercentEquity=0.25`, `RiskStopMoney=12.50`, `AllowLiveRealTrading=false`.
- **Importante:** input `RoundTurnCommissionPerLot=0.0` permaneceu ativo; portanto o preset corretivo com comissão estimada a USD 8/lote round trip NÃO estava carregado neste ensaio.
- O relatório HTML não contém versão exata do commit/hash do arquivo `.ex5`, nem logs completos do Strategy Tester.

## Resultados
- 1 operação vendida, 0 positivas / 1 negativa.
- Lucro líquido **-USD 1,49**; lucro bruto USD 0,00; perda bruta -USD 1,49; PF 0,00 com amostra unitária; drawdown máximo equity USD 1,49 (0,03%).
- **Entrada SELL** em 2026-11-13 10:09:32, 0,01 lote, 3894,18, SL 3895,36, TP 3890,63.
- **Saída por SL** em 2026-11-13 10:09:56, 0,01 lote, 3895,59; duração 24 segundos.
- Resultado de preço -USD 1,41; comissões USD 0,04 por lado (USD 0,08 total). Execução 0,23 acima do SL indicado; potencial slippage/gap em relação ao SL, sem evidência do motivo específico.
- A diferença entre limite nominal por stop (USD 12,50 ou 0,25% da conta) e perda observada não testa o comportamento do disjuntor: posição perdeu apenas USD 1,49.

## Diagnóstico
1. **Conquista:** primeira evidência primária anexada de teste V12.1 com 100% de ticks reais no período disponível.
2. **Problema aberto:** só 1 trade em 8.250 velas M1; não inferir causa sem contadores de espera, filtros e operações.
3. **Métrica insuficiente:** não se pode afirmar lucratividade ou robustez estatística com 1 trade.
4. **Input de custo faltando:** `RoundTurnCommissionPerLot=0.0` não representa os USD 8/lote round trip cobrados neste ensaio.
5. **Próxima evidência prioritária (sem repetir teste):** relatório de telemetria `ALIEN_V1089_REPORT_*.txt` produzido pelo próprio EA em `MQL5/Files` do agente, contendo ticks/candles/sinais/tentativas/motivos de espera e funil sweep. Consultar também CSVs correlatos.

Status: sem alterações de estratégia, sem merge, sem novos backtests conduzidos por esta revisão.
