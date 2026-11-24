# ALIEN V12.1 — coleta incremental V2 — 24/11/2026

Fonte primária inspecionada: arquivo enviado pelo usuário `ENVIAR_ALIEN_ATUALIZADO_20261124_040540.zip`, arquivos de operações, relatório, eventos e logs. Horários neste documento são do **servidor MT5**; último relatório às 09:05:34 de 24/11/2026. A conta é DEMO, XAUUSD M1, magic 802092.

## Deduplicação

Comparados `position_id` e `liquido_conta` com o relatório anterior de 47 posições: todas as 47 IDs anteriores reaparecem com valores idênticos. A nova coleta traz **18 outras posições únicas**. Total = **65 posições fechadas**.

| Métrica | 47 anteriores | 18 novas | 65 no total |
|---|---:|---:|---:|
| Resultado líquido (CSV do EA) | +USD 14,71 | +USD 0,24 | +USD 14,95 |
| Posições positivas | 32 | 9 | 41 |
| Posições negativas | 15 | 8 | 23 |
| Posições zeradas | 0 | 1 | 1 |
| Profit factor recomputado dos resultados por posição | 1,59 | 1,02 | 1,41 |

O acumulado não foi dobrado ao importar novamente a coleta anterior. O PF da amostra nova de 18 fica **muito perto do equilíbrio**; não interpretar 65 trades em poucas horas como prova de robustez.

## Setups acumulados

| Setup | Posições | Líquido |
|---|---:|---:|
| SEM_SETUP | 16 | -USD 0,41 |
| PA_MOMENTUM | 29 | +USD 4,99 |
| LIQUIDITY_SWEEP | 16 | +USD 5,41 |
| BOS_RETEST | 4 | +USD 4,96 |

Nas **18 novas**: PA_MOMENTUM 8 trades +USD 0,85; LIQUIDITY_SWEEP 8 trades **-USD 2,16**; BOS_RETEST 2 trades +USD 1,55. Nenhuma nova posição foi classificada como `SEM_SETUP`; isso é compatível com a alteração do filtro, mas o pacote não exporta inputs para comprovar o estado completo.

As 18 posições novas terminaram com classificação `STOP_LOSS`, inclusive as lucrativas (SL móvel). Maiores perdas individuais novas: -USD 3,89 e -USD 3,73. O relatório do EA informa **drawdown realizado** de USD 11,14 na sessão, excluindo P&L flutuante.

## Divergência persistente

O relatório de 09:05:34 mostra **"Hoje realizado +17.60 USD"**, mas o CSV de 65 posições reconcilia com o resumo de sessão do próprio EA em **+14,95 USD**. Diferença de USD 2,65. No arquivo de eventos: **63** linhas `DEAL_EXIT` mas **65** `CLOSED_POSITION`. Duas posições com `FECHAMENTO_EXTERNO` somam -USD 2,73, e há evidências de taxas de entrada que potencialmente explicam os USD 0,08 restantes. O código `RefreshDailyStats` acumula apenas deals `DEAL_MAGIC==ExpertMagic`, enquanto `ReconcileTrades` soma deals `HistorySelectByPosition`; possível causa: fechamentos externos por outro magic.

**Não afirmar reconciliação final antes de obter o relatório de deals originais do MT5**, contendo DEAL_POSITION_ID / DEAL_MAGIC / lucro / comissão / swap / taxas. O resultado +14,95 é a evidência mais completa dos CSVs disponíveis, não extrato de corretora auditado.

O log contém 1 `invalid stops` e 2 `position closed` na modificação de SL — falhas localizadas, não necessariamente novas na etapa de 18 trades. O relatório confirma zero posições abertas no instante da coleta.

## Decisão

Conservar versão principal e parâmetros atuais, em DEMO. Não aumentar lote ou frequência em resposta a uma única sessão. Continuar coleta incremental, verificar risco executado, reconciliar valores por deal, e examinar comportamento fora da amostra. Não atribuir saldo global da conta compartilhada ao ALIEN.

Arquivo Markdown detalhado e CSV das 18 entradas adicionais foram gerados na conversa. Nenhuma ordem foi enviada e nenhum código do EA foi modificado nesta auditoria.
