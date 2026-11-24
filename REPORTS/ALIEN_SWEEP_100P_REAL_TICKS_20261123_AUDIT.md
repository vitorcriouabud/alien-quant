# ALIEN V12.1 LAB SWEEP ONLY — MT5 100% ticks reais (23/11/2026)

**Fonte primária:** `ALIEN_SWEEP_100P_REAL_TICKS_20261123_222346.htm`, enviado no chat. Números abaixo auditados na tabela de 98 negócios de entrada/saída do MT5, sem usar os gráficos como substituto. **Estudo curto, sem comprovação de vantagem estatística nem de robustez fora da amostra.**

## Identidade e parâmetros

- EA reportado: `ALIEN_V12_1_LAB_SWEEP_ONLY` (hash do .ex5 não consta do HTML)
- XAUUSD M1, 2026-11-13 a 2026-11-22; 100% ticks reais no MT5; 8.250 candles, 3.323.422 ticks; RoboForex-ECN, 5.000 USD, leverage 1:100.
- `EnableBreakRetest=false`, `EnableLiquiditySweep=true`, `SweepOnlyTradeMode=true`, `EnablePAMomentum=false`, `AllowZoneDirectEntries=false`, `EnableZonePendingOrders=false`; `FixedLot=0.01`, `MaxRiskPercentEquity=0.25`, `RiskStopMoney=12.50`, `RoundTurnCommissionPerLot=8.00`, `AllowLiveRealTrading=false`.
- Portanto, o preset Sweep-only **foi aplicado** neste ensaio. Sinais visuais FVG/OB habilitados não equivalem a operações desses setups.

## Resultado consolidado (MT5)

| Métrica | Valor |
|---|---:|
| Operações completas | 49 |
| Lucro/prejuízo líquido | **-9,73 USD** |
| Profit Factor | **0,60** |
| Drawdown máximo equity | 13,37 USD / 0,27% |
| Lucro bruto MT5 | +14,38 USD |
| Perda bruta MT5 | -24,11 USD |
| Posições positivas segundo MT5 | 19 / 49 (38,78% de preço positivo antes das comissões da posição) |
| Rentáveis *depois* de somar comissão de abertura e fechamento | **15 / 49 (30,61%)** |
| Posições com resultado líquido negativo | 32 |
| Posições com resultado líquido exatamente zero | 2 |
| P&L de movimento do preço (todas as saídas) | -5,81 USD |
| Comissões cobradas no teste | -3,92 USD, ou -0,08 por posição |
| Duração média / mediana | ~22,7 s / 13 s |

### Resultados por motivo de fechamento

| Saída | Quantidade | Líquido |
|---|---:|---:|
| Stop (inclusive stops alterados pelo runner) | 42 | -20,24 USD |
| Take profit | 7 | +10,51 USD |

**Dos 42 stops**, 27 coincidem com o SL inicial registrado na abertura e somaram **-22,18 USD**; 15 foram movidos em direção favorável pelo EA e somaram **+1,94 USD** (inclui alguns realizados abaixo do novo SL por diferença de execução). A perda principal veio do **SL inicial**, não apenas de um trailing excessivamente apertado.

**Diferença stop vs preenchimento**: 42 stops registraram diferença adversa média de preço 0,129 USD, mediana 0,07 USD e máximo 1,00 USD no ativo. Isso pode ocorrer por slippage/latência de execução, mas a causa exata não é identificável só pelo relatório.

### Dia de entrada (líquido)

| Data | Trades | USD |
|---|---:|---:|
| 13/11 | 9 | -2,85 |
| 16/11 | 8 | -1,55 |
| 17/11 | 7 | -3,34 |
| 18/11 | 7 | -1,72 |
| 19/11 | 8 | -1,74 |
| 20/11 | 10 | +1,47 |

5 dos 6 dias de negociação foram negativos. Compra 21 trades (-4,09); venda 28 (-5,64).

## Interpretação com cautela

1. O automatizador efetivamente realizou um teste separado, 100% real-tick reportado e isolando Sweep.
2. Essa implementação de Sweep, neste período de seis pregões, **não tem expectativa positiva observada** e não oferece respaldo para conta real.
3. A hipótese 'BOS era a única causa das perdas' é refutada para este ensaio; com BOS desativado ainda perdeu.
4. A maior parcela da perda ocorreu em operações atingindo SL *original* (27 perdas/saídas de SL original), sugerindo investigar qualidade/tempo da entrada, stop estrutural, custo relativo ao alcance e taxa de stop antes de mexer na saída. Não é prova causal de 'entrada ruim'.
5. O maior slippage aparente por stop exige auditoria de execução; reduzir proteção ou simplesmente ampliar stop sem evidência eleva risco.
6. O teste antigo misto (58 ou 60 trades) não é um grupo de controle perfeito: configuração de comissão, stop, código e seleção podem ser diferentes.

## Próximo passo de engenharia

- **Não alterar filtros ou risco cegamente.** Preservar o código validado e o pacote de um clique.
- Produzir 1 relatório de **funil por estágio** do SWEEP + por-trade MFE/MAE/SL original, duração, stop movido, custo, slippage e regime; validar com testes isolados de variantes (não otimizar e avaliar na mesma semana).
- Depois buscar dados de ticks reais de outros meses para verificação fora da amostra antes de qualquer uso real.
- O HTML sozinho não prova versão exata do `.ex5`; preservar hash no relatório do automatizador.

Nenhuma edição da lógica de execução foi feita neste registro.
