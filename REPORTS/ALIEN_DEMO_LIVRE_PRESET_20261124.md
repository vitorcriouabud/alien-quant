# ALIEN V12.1 — DEMO LIVRE, preset experimental (24/11/2026)

**Entrega ao usuário:** `ALIEN_V12_1_DEMO_LIVRE_PRESET_20261124.zip` (4 arquivos, integridade ZIP testada). Preset UTF-16 BOM `ALIEN_V12_1_DEMO_LIVRE_SEM_FILTROS.set`, SHA256 `001ede65dc370dd646aa34b8837592f333aa310f6ff70ea9d476876c9ad52dd1`.

## Solicitação e interpretação
O usuário pediu **ativar sem nenhuma trava** após mostrar uma conta DEMO RoboForex-ECN com GoldBreakoutBot_v2, ALIEN V12.1 e GMG visual. Foi preparado perfil de **maior frequência de entradas apenas em demo**, sem alterar código existente ou parâmetros dos robôs já ativos. **Não pode ser aplicado remotamente neste chat**.

## O que muda no preset
Partiu de `ALIEN_V12_1_SWEEP_ONLY_5K_RISCO025_COMISSAO8.set` enviado anteriormente, modificando 77 parâmetros (alguns podem permanecer com o mesmo valor) e acrescentando `RequireSweepCandleAlignment=false` e `EnableEntryObserver=true`. Principais mudanças:
- Horários / janelas / notícias / veto HTF / AMD contrário desligados: `TradeLondonAndNYOnly=false`, `RestrictNewTradesToWindows=false`, `EnableNewsFilter=false`, `EnforceStrictHTF=false`, `UseHigherTimeframes=false`, `BlockOppositeConfirmedAMD=false`.
- Demais restrições de frequência/sinal reduzidas: `MaxDailyTrades=0`, `OneEntryPerM1Candle=false`, `MaxEntriesPerM1Candle=0`, `MinimumScore=1`, `SweepMinimumEntryScore=1`, `RequireTickAlignment=false`, `EnableBreakRetest=true`, `EnablePAMomentum=true`, `SweepOnlyTradeMode=false`, `RequireSetupValidation=false`, `RequireObservedSweepEvent=false`. **Não remove todas as condições hardcoded no fonte**.
- Interferência cruzada permitida em DEMO: `BlockIfOtherPendingOnSymbol=false`. **Não recomendado** enquanto GoldBreakoutBot opera na mesma conta/símbolo.
- Desabilita travas monetárias da equity global: `StopOnDailyProfitTarget=false`, `DailyMaxLossMoney=0`, `WeeklyMaxLossMoney=0`, `TotalMaxLossMoney=0`, `EnableHardCircuitBreaker=false`, `EnableDailyEquityGuard=false`, `EnableHighWaterMarkGuard=false`. **Sem disjuntor agregado — pode perder continuamente no demo**.
- **Preserva proteção individual:** `AllowLiveRealTrading=false`, `FixedLot=0.01`, `MaxRiskPercentEquity=0.25`, `RiskStopMoney=4.0`, `MaxOwnPositions=1`, `DisablePyramidInV10=true`, `EnablePyramid=false`, `BlockOnMissingSL=true`, `RequireOrderPrecheck=true`, `AbsoluteMaxSpreadPts=25`, `RoundTurnCommissionPerLot=8.00`, `UseRiskRewardTakeProfit=true`, `StopOnlyRunnerMode=true`. Os limites financeiros são orçamento calculado, **não garantem perda máxima ante slippage/gaps**.

## Procedimento
- Executar `COPIAR_PRESET_MT5.cmd` somente para **copiar o arquivo para MQL5/Presets**, detectando pasta de dados do MT5; sem negociar, parar EAs, fechar posições ou mudar conta. Gera relatório na Área de Trabalho.
- Para ativar é preciso, dentro do **MT5 em conta demo isolada**, abrir Propriedades do EA > Entradas > Carregar e escolher o preset, conferir inputs e confirmar.
- Sem acesso remoto ao terminal, não confirmar ativação. Em instalação ativa, **não reiniciar por script**; outras EAs ainda podem estar gerenciando posições.
- Código do EA inalterado. **Nenhuma compilação, execução, backtest ou resultado de trades foi produzido**. O exe local pode ter outra versão ou input schema; confirmar no terminal.
- Esse é um ensaio de alta frequência com risco acumulado elevado, não configuração recomendada para mesa, conta real ou junto a outros robôs.

**Decisão:** não fazer merge nem reconfigurar automaticamente conta com outros EAs.