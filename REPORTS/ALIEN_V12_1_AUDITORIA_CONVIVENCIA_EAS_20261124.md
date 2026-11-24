# ALIEN V12.1 — Convivência com outros EAs na demo, auditoria focal (24/11/2026)

## Escopo e fonte

Código-fonte efetivamente inspecionado: `MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5` na branch `lab/v12-1-ab-candle-20261123-gpt6`, 5714 linhas. É **código da branch**, não prova de equivalência com o EX5 anexado no terminal Windows do usuário. Capturas de tela mostraram no diário `GoldBreakoutBot_v2`, `ALIEN_V12_1_INSTITUTION...` e `ALIEN_GMG_SMC_VISUAL`; são fontes de sinais distintas numa mesma conta demo RoboForex-ECN.

## Achados verificados no código

1. **Identificação do ALIEN por magic = 802092**: input nas linhas 123–125; `trade.SetExpertMagicNumber(ExpertMagic)` na 4889.
2. **Fechamentos de emergência respeitam magic e símbolo**: `CloseAllPositionsInstantly` linhas 1559–1581 filtra `POSITION_SYMBOL==_Symbol` e `POSITION_MAGIC==ExpertMagic`; `CancelAllPendingOrders` linhas 1583–1594 também filtra símbolo e `ORDER_MAGIC`. Inspeção indica intenção de não fechar operações alheias; **não equivale a certificação de segurança em execução real**.
3. **Disjuntores usam equity global da conta**: `NewEntriesAllowedBySupervisor` linhas 1405–1469 consulta `AccountInfoDouble(ACCOUNT_EQUITY)` para teto total, semanal, diário e alvo diário. `AlienEnforceRiskCircuitBreakers` linhas 5083–5155 faz o mesmo e pode fechar posições **do próprio magic** por perda causada em parte por outros robôs. `RefreshTotalEquityBaseline` linhas 1211–1247 usa saldo da conta inteira como base persistente; `RefreshWeeklyEquityBaseline` linhas 1267–1290 usa equity global.
4. **Pendentes externas no XAUUSD bloqueiam entradas do ALIEN** quando `BlockIfOtherPendingOnSymbol=true`: entrada padrão na linha 120; ver `SymbolHasForeignPendingOrders` linhas 1888–1905.
5. **`AllowLiveRealTrading=false` NÃO é modo observador em conta demo**: linhas 1392–1396 vetam contas não demo/tester; em demo o EA continua autorizado a enviar ordens, observado nas chamadas `trade.Buy`/`trade.Sell` linhas 2808–2810.
6. **Ao remover o EA, não supor que posições deixam de existir:** ver `OnDeinit` (linhas 5020–5025 cancelam certas pendentes próprias). Stop/TP no servidor podem permanecer; gestão contínua do EA cessa. Não remover automaticamente nem fechar contas/posições por script sem verificar o estado.
7. Mesmo com base 5000 USD no teste A/B, inputs-padrão do fonte (ex. `DailyMaxLossMoney=4`, `TotalMaxLossMoney=5`, `RiskStopMoney=4`, `RoundTurnCommissionPerLot=0`) **não devem ser confundidos** com os presets que fizeram os backtests A/B; o ambiente de operação do print não foi auditado para saber qual preset está carregado.

## Recomendação técnica

- **Isolar em uma conta demo e instância/instalação MT5 exclusivas**, mantendo outras EAs e operações existentes sem intervenção. Trocar apenas o login na instalação compartilhada pode trocar a conta de todos os gráficos e robôs: evitar.
- Até isolar, deixar o **GMG visual** como instrumento de estudo. Não classificar o EA ALIEN V12.1 como passivo por causa de `AllowLiveRealTrading=false` — ele executa em demo.
- Identificar posteriormente transações no histórico por **DEAL_MAGIC=802092** e `DEAL_SYMBOL=XAUUSD`, somando lucro, swap e comissão; fotos do histórico geral da conta não atribuem PnL ao ALIEN.
- Próxima evolução sugerida: adicionar **modo OBSERVAR SEM ORDENS** explicitamente no EA experimental, testado em MT5 antes de implantá-lo na demo. Proteção deve cobrir todas as rotas Buy/Sell/pendentes/modificações/fechamentos.
- **Nenhuma mudança de código foi realizada nesta auditoria. Nenhuma ordem, merge, conta ou preset alterados.**

## Pergunta operacional só quando necessária

Se o usuário quiser que o assistente prove que a instalação é idêntica à versão auditada, obter HASH SHA256 do EX5 instalado e presets ativos; não deduzir de captura de tela.
