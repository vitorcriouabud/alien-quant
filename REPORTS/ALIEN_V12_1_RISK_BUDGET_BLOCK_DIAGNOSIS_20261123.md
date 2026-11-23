# Diagnóstico do coletor — 23/11/2026 (XAUUSD M1, ticks reais)

Fonte: ZIP `ENVIAR_ALIEN_DIAGNOSTICO_20261123_201252.zip` recebido no chat. Arquivo contém registros de outras sessões; esta análise separa **apenas** o ambiente de backtest associado ao relatório de 2026-11-13. Dados identificadores de conta e caminhos locais omitidos deste registro.

## Evidência do EA (relatório de telemetria do agente testador)

| Contador | Valor |
|---|---:|
| Ticks observados | 3.323.422 |
| Candles | 8.250 |
| Eventos SWEEP observados | 17.196 |
| Eventos SWEEP confirmados | 6.069 |
| Sinais de setups detectados | 10.199 |
| Tentativas de ordens enviadas | 1 |
| Entradas concluídas | 1 |
| Rejeições no envio | 0 |
| `SWEEP_REJECT_RISK` e `SWEEP_REJECT_ROOM` registrados | 0 |

Sinais detectados = 3.377 `LIQUIDITY_SWEEP` + 6.822 `BOS_RETEST`. Não são necessariamente **10.199 oportunidades independentes**; a rotina pode contar múltiplas avaliações.

Motivos de espera amostrados até 1 vez/seg: custo/spread/ATR 15.138; score 1.373; ticks/impulso/pressão 154.233; outros 500.255. Categoria 'Outros' não permite atribuir uma causa única. O CSV de eventos tem 17.196 observações de sweep e apenas um SETUP, ENTRY, DEAL_EXIT e CLOSED_POSITION. Houve somente uma tentativa efetiva de ordem.

## Defeito focal no código (alta confiança, comportamento a confirmar no MT5)

O EA guardava `RiskStopMoney = 12.50` como orçamento fixo da posição, mas `CheckExposure()` recusava se o orçamento excedesse `ACCOUNT_EQUITY * MaxRiskPercentEquity / 100.0` (com percentual de 0,25%).

Após perda de USD 1,49, a equity era USD 4.998,51; o teto de 0,25% passa a **USD 12,496275**, portanto o orçamento fixo de USD 12,50 fica acima do limite por apenas USD 0,003725. O relatório final registrou exatamente: `ULTIMA DECISAO RISCO: EXPOSICAO: Risco por operacao ultrapassa % da equity`.

O `attempts` só incrementa na linha de envio da ordem; recusas anteriores de `CheckExposure` não incrementam o contador, justificando por que 10.199 sinais podem terminar em apenas 1 tentativa, embora não quantifique todos os filtros.

**Patch experimental:** em `SendEntry()`, `chosenRisk` agora é limitado a `min(chosenRisk, currentEquity*MaxRiskPercentEquity/100)` antes de `CheckExposure`. A verificação monetária do SL calculado continua exigindo risco estimado dentro dos dois limites; nenhuma proteção foi desligada. Efeito em desempenho ainda **NÃO VALIDADO**.

## Segundo achado independente

`SweepOnlyTradeMode=true` não significa literalmente só SWEEP: o código `if(SweepOnlyTradeMode && signalSetup!=1 && !(EnableBreakRetest && signalSetup==2))` permite `BOS_RETEST` quando `EnableBreakRetest=true`. O único trade do período foi `BOS_RETEST`. Não corrigido nesta etapa para preservar a estratégia atual; exige nomenclatura/hipótese explícita e comparação isolada.

## Próxima validação controlada

1. Recompilar e confirmar a versão alterada do EA, com print/log de compilação e localização do `.ex5`.
2. Repetir **mesmas datas 2026-11-13 a 2026-11-22**, XAUUSD M1, demo USD 5.000, modelagem em ticks reais 100%; usar preset de comissão estimada em USD 8 por lote round trip se confirmar com o broker.
3. Acompanhar o relatório `ALIEN_V1089_REPORT_*.txt`: tentativas, sinais, `lastRiskDecision`, risco recusado, espera, resultados. Guardar HTML, CSV TRADES, CSV eventos e Journal/Experts.
4. Se operações continuarem raras, instrumentar a quantidade de bloqueios **por estágio de decisão**, sem remover os filtros de risco por tentativa e erro.
5. Avaliar qualidade dos trades, custos e slippage antes de extrapolar retorno.

**Nenhuma compilação ou novo backtest foi executado nesta análise. Código apenas na branch experimental, sem merge em main.**
