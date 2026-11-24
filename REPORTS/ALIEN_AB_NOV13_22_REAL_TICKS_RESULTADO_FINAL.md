# ALIEN A/B com ticks reais — auditoria encerrada (24/11/2026)

**Fonte primária:** arquivo usuário `ENVIAR_ALIEN_AB_NOV13_22_V2_20261124_000600.zip`; cópia `ENVIAR_ALIEN_AB_NOV13_22_V2_20261124_000600(1).zip` é idêntica bit a bit (SHA256 de ambos: `ca84f5ee43f05720346e92587bda0fe955d3a43c820eb01448cff71f65e42f7f`). Contar como **um único experimento**, não dois.

## Validação de execução

- Mesmo EA: `ALIEN_V12_1_LAB_AB_CANDLE` nas duas amostras, e mesmo EX5 SHA256 **`09BDF2A747E458FE22D56B0511AAF69B8F12E53CF0EE65907FD1AF234475251C`**.
- Mesmo commit fonte `1ddac12c5f5810ad3d24594abf6ed89387e4bb15`; versão lançada pelo script `NOV13_22_V2_UNICO`.
- HTML de cada teste confirma `M1 (2026.11.13 - 2026.11.22)`, **100% de ticks reais** (reportados pelo MT5), **8.250 barras**, **3.323.422 ticks**, RoboForex-ECN, depósito virtual USD 5.000.
- Todos os **214** parâmetros de entrada em cada HTML foram comparados: **somente 1 diferença** `RequireSweepCandleAlignment=false` (A) vs `true` (B). Outros checados: `EnableBreakRetest=false`, `SweepOnlyTradeMode=true`, `EnableLiquiditySweep=true`, `AllowLiveRealTrading=false`, `EnableEntryObserver=true`, `FixedLot=0.01`, `MaxRiskPercentEquity=0.25`, `RiskStopMoney=12.50`, `RoundTurnCommissionPerLot=8.00`.
- CSV de trades separado por sufixos A/B, sem mistura; **49** e **33** posições, uma linha por `position_id`; soma de `liquido_conta` bate com o total do HTML.

## Resultado comparado

| Medida MT5 | Controle A | Filtro B |
|---|---:|---:|
| Lucro líquido | **-USD 9,73** | **-USD 3,46** |
| Operações | 49 | 33 |
| Profit factor | 0,60 | 0,80 |
| DD máx. equity | USD 13,37 / 0,27% | USD 9,55 / 0,19% |
| Lucro bruto de operações MT5 | USD 14,38 | USD 13,74 |
| Perda bruta de operações MT5 | -USD 24,11 | -USD 17,20 |
| Operações lucrativas MT5 | 19/49 (38,78%) | 15/33 (45,45%) |
| **Posições com resultado líquido >0 no CSV incluindo custos** | 15/49 (30,61%) | 15/33 (45,45%) |
| Saídas por TP | 7 (+USD 10,51 líquidos) | 4 (+USD 8,38 líquidos) |
| Saídas por SL / SL móvel | 42 (-USD 20,24 líquidos) | 29 (-USD 11,84 líquidos) |

B teve melhoria numérica relativa de **USD 6,27**, diminuindo as perdas observadas em ~64,4%, mas **continua perdedor (PF <1)**. É um ensaio de 6 pregões, no MESMO período de onde a hipótese do candle foi extraída, portanto **não é teste fora da amostra** e não prova edge.

### Resultado por data (líquido / número de posições)

| Data | A | B |
|---|---:|---:|
| 13/11 | 9 / -2,85 | 5 / +1,67 |
| 16/11 | 8 / -1,55 | 3 / +2,16 |
| 17/11 | 7 / -3,34 | 4 / -3,33 |
| 18/11 | 7 / -1,72 | 9 / +3,56 |
| 19/11 | 8 / -1,74 | 6 / -4,43 |
| 20/11 | 10 / +1,47 | 6 / -3,09 |

**Importante**: apesar de B ter 16 posições a menos no total, **somente 5** das operações de B coincidem exatamente com uma entrada de A no mesmo segundo e direção. Excluindo um sinal, o robô muda estado, cooldown, proteção e elegibilidade subsequente; **não é correto concluir que B apenas eliminou as 16 piores operações**. São trajetórias de trading distintas a partir de um único parâmetro alterado.

### Fator candle no CSV

- A: `p_candle=0` em 42 trades somando **-13,04 USD**; `p_candle>0` em 7 trades somando **+3,31 USD**.
- B: `p_candle=0` em **0** trades, confirmando que filtro foi aplicado; `p_candle=7` em 8 trades **+5,04 USD**; `p_candle=15` em 25 trades **-8,50 USD**.
- O filtro exige deslocamento do M1 ainda em formação na direção do trade na hora da decisão; **não espera fechamento de candle**, e `p_candle` não é probabilidade.
- **Não transformar esse subgrupo em nova regra** (`p_candle=7` vence `15`) sem amostra nova; diferenças podem ser amostragem/seleção retrospectiva.

## Interpretação e decisão

- **Validação técnica A/B aprovada** (identidade, datas, modelo, parâmetros), mas **validação estatística/financeira reprovada** (A e B perderam).
- B é uma **hipótese de redução de perdas** no período de descoberta, não um robô pronto para mesa.
- Não recomendar conta real, aumento de lote, afrouxamento dos disjuntores, ou alteração na `main`.
- Próximo passo: **localizar janelas adicionais com 100% de ticks reais antes de testar novas hipóteses**, preservando período de descoberta fora da comparação final; pré-registrar um único candidato, risco/custos iguais, avaliar PF, DD, P&L por mês/dia, número de trades e slippage. Não repetir o mesmo período até ficar positivo.
- Em particular, 02–12/11/2026 havia retornado **0% de ticks reais** no teste anterior; não chamar esse intervalo de validação.

**Nenhum código adicional foi alterado nesta auditoria.**
