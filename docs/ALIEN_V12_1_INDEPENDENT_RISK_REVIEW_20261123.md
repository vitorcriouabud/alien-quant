# Revisão independente — ALIEN V12.1 (23/11/2026)

**Estado:** EXPERIMENTAL / NÃO COMPILADO / SEM BACKTEST. Não utilizar em conta real ou funded. Não houve merge em `main`.

## Origem e escopo
- Base: `main` no commit `90cdaed30e82c4292120f90ba0e0eeccafa6b56f`.
- Insumos: `AUDIT_V12_1_RISK_REVIEW_2026-11-23.md`, `_exploration_map.md` e `ALIEN_V12_1_DEMO_5K_CANONICAL.set` enviados pelo usuário; verificação direta do código e da Issue #17.
- Alteração isolada a `MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5` e inclusão de dois presets de laboratório; versões anteriores preservadas.

## Ressalvas à auditoria Abacus
1. `OnTimer()` não era exclusivamente visual: além de telemetria, tinha rotinas opcionais de manutenção/colocação de pendentes (`MapMaybePlacePending()`). No preset em análise, `EnableZonePendingOrders=false` e `AllowZoneDirectEntries=false`.
2. `MaxHoldSeconds=180` não implica saída em 180 segundos: `ExitOnTimeout=false` e `StopOnlyRunnerMode=true` desativam o timeout e a proteção flutuante legada em `ManageOpenPosition()`.
3. Limites do código e presets não coincidem. O `.set` carregado muda inputs operacionais; confirmar os valores efetivamente carregados no Strategy Tester.
4. Issue #17 descreve teste H_RR3/TURBO (conta MetaQuotes-Demo, depósito de US$ 5.000); não estabelece que o EA V12.1 do `main` causou a perda de US$ 112,01. Atribuição a gap/pausa permanece hipótese sem a fita de ticks e execução.
5. A questão da sexta-feira é independente daquele incidente ocorrido de segunda para terça-feira. O horário UTC deve ser validado contra o fuso do broker e mudanças de horário.

## Mudanças no EA experimental
- Extraído o bloco de circuit breakers em `AlienEnforceRiskCircuitBreakers()`, chamado tanto em `OnTick()` quanto em `OnTimer()` (timer do EA já configurado para 5 segundos). A estrutura e os inputs principais permanecem.
- A proteção semanal, que antes vetava apenas novas entradas, agora tenta fechar posições do próprio EA e cancelar suas pendentes quando o teto dispara.
- Ao atingir a meta diária, pendentes passam a ser canceladas mesmo quando não há posição aberta.
- Falhas de `PositionClose` e `OrderDelete` são registradas com retcode/detalhe; mensagens não afirmam sucesso sem confirmação.
- Janela de fechamento de sexta passa por `AlienServerUTC()` com relógio do servidor para o timer; bloqueio de novas entradas da sexta também usa conversão UTC.
- As proteções só tentam executar ordens; `OnTimer()` NÃO força execução quando o mercado está fechado, sem preço, sem conexão ou com slippage. SL no servidor também pode preencher pior que o preço planejado.

## Presets incluídos (UTF-16LE com BOM, CRLF)

| Arquivo | Finalidade | Risco por ordem (input) | Lote base | Risco nominal por stop |
|---|---|---:|---:|---:|
| `ALIEN_V12_1_DEMO_5K_CANONICAL_ABACUS.set` | Proposta original recebida | 0,50% | 0,05 | US$ 20 |
| `ALIEN_V12_1_DEMO_5K_RISK_025_EXPERIMENTAL.set` | Variante conservadora | 0,25% | 0,01 | US$ 12,50 |

Ambos mantêm `AllowLiveRealTrading=false`, limites configurados de US$ 20 por dia e US$ 100 de perda total, e `RoundTurnCommissionPerLot=0.0`, que é um placeholder e exige conferência dos custos reais. Limites nominalmente configurados NÃO são garantias de perda máxima em gaps.

## Validação ainda obrigatória
1. Compilar a versão desta branch no MetaEditor (F7) e conservar log completo de compilação.
2. Carregar cada `.set` na aba Inputs do MT5; conferir todas as alterações e exportar o preset realmente carregado.
3. Executar primeiro backtest controlado no XAUUSD M1, modelo **Cada tick baseado em ticks reais** (Model 4), com spread variável e custos compatíveis com o broker, em datas com histórico verificável.
4. Ensaiar cenários de sexta-feira, falta de ticks, retomada após pausa, SL ausente, fechamento rejeitado, cancelamento de pendente, limite diário/semanal/total e lock de lucro.
5. Conferir se o timer realmente provoca tentativas no tester e se eventuais diferenças entre backtest, demo e terminal conectado exigem ajustes. Eventos do timer não tornam possível fechar posições em horário sem negociação.
6. Comparar relatórios, Deals, Journal/Experts, parâmetros, depósito, símbolo e modelo de ticks. Não promover versão sem evidência.

## Pendências críticas fora deste patch mínimo
- Revisão abrangente do código de 5.483 linhas não concluída aqui; inspeção focal nas rotinas de risco, fechamento, gerenciamento e presets.
- Verificar todas as interações entre `DailyMaxLossMoney`, `DailyEquityLossPct`, `MaxTrailingDDPct` e as linhas globais persistentes de lock.
- Adicionar proteção de retomada após pausa e detecção de cotação obsoleta antes de novas entradas, depois de testes reproduzíveis.
- Confirmar precisão do fuso/horário de verão e disponibilidade real do broker.
- Validar regras específicas da mesa de avaliação separadamente das regras de risco do EA.

**Conclusão:** pacote de hipóteses e correções experimentais, não versão pronta. Sem compilação e sem resultado real de teste.
