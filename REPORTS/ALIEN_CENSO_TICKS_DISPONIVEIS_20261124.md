# Censo automático do histórico de ticks MT5 — 24/11/2026

Motivação: testes A/B em XAUUSD M1, 13–22/11/2026, deram A -USD 9,73 (49 trades, PF 0,60) e B -USD 3,46 (33 trades, PF 0,80) com 100% de ticks reais reportados. O teste 02–12/11/2026 havia informado 0%, apesar de Model=4.

**Decisão:** antes de otimizar novas regras ou repetir A/B, mapear a disponibilidade de dados históricos com simulação de risco zero, sem negociações.

## Implementação entregue (ZIP)

`ALIEN_HISTORICO_TICKS_MAPA_UM_CLIQUE.zip` contém:
- `EXECUTAR_AUDITORIA_TICKS.cmd`
- `ALIEN_AUDITAR_HISTORICO.ps1`
- `ALIEN_TICK_CENSUS.mq5`
- `LEIA_PRIMEIRO.txt`

O EA `ALIEN_TICK_CENSUS.mq5` apenas incrementa contadores em `OnTick`. Não importa `Trade.mqh`, não possui funções de envio de ordem e rejeita `OnInit` fora de `MQL_TESTER`. O PowerShell não habilita live trading, desativa nuvem/remote, compila em pasta independente `MQL5/Experts/ALIEN_LAB_TICK_CENSUS/`, usa `Model=4`, e exporta CSV de qualidade baseado no texto dos relatórios HTML do MT5. **Não é uma coleta de ticks independentes; é censo da qualidade reportada no Strategy Tester.**

Janelas avaliadas: 17–21/08, 14–18/09, 19–23/10, 02–12/11 (controle anteriormente 0%) e 13–22/11 (controle previamente 100%). Registra `QUALIDADE_100_REPORTADA`, `SEM_100_POR_CENTO`, `DATA_DIFERENTE`, `EA_DIFERENTE` ou `SEM_COMPROVACAO`; não trata silêncio ou ausência de HTML como sucesso.

Saída esperada: um único `ENVIAR_ALIEN_HISTORICO_TICKS_*.zip` com `RESUMO_TICKS.csv`, HTMLs disponíveis, configs e hash da compilação. Se não gerar HTML por não haver operações, isso será relatado como **SEM_COMPROVACAO**, não como 0 ou 100%.

## Controles e limitações

- Código criado e validação estática local realizada: ZIP descompacta sem erros, 4 arquivos, EA sem chamadas de trade, script usa as 5 janelas e modelos/tester corretos.
- **Não compilado nem executado em Windows/MT5 pelo assistente**; não existe ainda resultado de disponibilidade. Não declarar que janelas anteriores possuem ticks reais.
- Se as janelas antigas forem 0% ou desconhecidas, explorar proveniência das bases de ticks e dados do servidor antes de novos backtests. O uso de outra corretora/ativo invalida comparações diretas sem revisão de custos.
- O 13–22/11 é **controle conhecido**, não validação externa. Datas futuras ainda não podem ser chamadas de holdout.
- Nenhum merge/main alterado, nenhuma conta real conectada ou operada.
