# ALIEN V12.1 — primeiro relatório MT5 recebido (2026-11-23)

**Evidência primária:** `ReportTester-67315343.html` enviado pelo usuário (não publicar nem incorporar identificação da conta). Sem acesso ao Journal completo e sem hash de `.ex5`; não é possível provar que o binário testado corresponde exatamente ao commit experimental.

## Identificação do backtest
- Ambiente: RoboForex ECN, XAUUSD M1, período informado pelo relatório 2026-10-01 a 2026-11-21.
- Depósito inicial: USD 5.000; alavancagem 1:100.
- Histórico: 50.875 barras; 16.758.854 ticks; **15% de ticks reais**, insuficiente para validar estratégia dependente de microestrutura.
- Execução: 1 trade completo (2 deals); +USD 0.05 de variação de preço, -USD 0.08 de comissões, **-USD 0.03 líquido**.
- Profit Factor exibido 0,25; DD máximo equity USD 0,69 (0,01%). PF, win rate de 100% e DD de amostra unitária não são estimativas úteis de desempenho.

## Trade documentado
| Momento (horário do relatório) | Ação | Lote | Preço | Comissão |
|---|---|---:|---:|---:|
| 2026-10-01 11:09:30 | BUY | 0,01 | 4162,70 | -USD 0,04 |
| 2026-10-01 11:10:02 | SELL (SL após ajuste) | 0,01 | 4162,75 | -USD 0,04 |

- P&L bruto +USD 0,05; líquido -USD 0,03.
- Tempo em posição 32 s; SL inicial 4161,56 e TP inicial 4166,12; saída marcada `sl 4162.75`. O deslocamento do SL é inferido pelo resultado; logs de modificações ainda não foram recebidos.
- Preset do teste: `RoundTurnCommissionPerLot=0.0`, mas o broker cobrou 4 centavos em cada lado em 0,01 lote.
- Comissão inferida para este cenário: 0,08 / 0,01 = **USD 8 por lote round trip**; confirmar regra do símbolo e da conta. O EA usa este input para BE e estimativas de risco. Cuidado: custos podem variar.
- Preset de reprodução local proposto: `ALIEN_V12_1_DEMO_5K_RISK025_COMISSAO8_TESTE.set` — única alteração em relação ao perfil `RISK_025_EXPERIMENTAL`: comissão por lote 0 → 8. Não foi carregado no MT5 nem testado ainda.

## Pontos pendentes
1. Obter arquivo completo do **Diário** do Strategy Tester para diagnosticar bloqueios, falhas de ordem, init e mensagens do supervisor.
2. Verificar `SHA256`/data do `.ex5` efetivamente testado; o nome do EA sozinho não confirma a versão.
3. Repetir teste em período com **qualidade de ticks reais adequada**, custo efetivo, slippage e latência simulados. Não repetir só para aumentar PF.
4. Investigar por que apenas uma entrada foi aberta em 50.875 barras — não atribuir automaticamente a filtros, dados ou locks sem logs.
5. Confirmar que mudança de comissão evita saídas com lucro bruto mas prejuízo líquido, sem assumir garantia em gaps.

**Status:** achado observado sobre comissão. Falha operacional definitiva e lucratividade continuam **não demonstradas**. Sem merge ou operação real.
