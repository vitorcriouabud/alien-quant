# ALIEN — Auditoria inicial SMC Liquidity versus V12.1
Data: 2026-11-13 | Estado: **ANALISE ESTATICA, NAO VALIDADO NO MT5**

## Escopo e proveniencia

- Entrada externa: \`SMC_Liquidity_EA.mq5\`, 1.065 linhas,
  SHA256 \`899bb405834473e6a39664e5430fb9d4ff17e87a68dfa818850aad239924d2d3\`.
  Recebido por upload no ChatGPT. **Nao foi publicado aqui**, portanto
  a auditoria ainda nao permite reproducao sem adicionar a fonte ao laboratorio.
- Base consultada: \`MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5\` do branch
  \`main\`; \`MQL5/Indicators/ALIEN_Observer.mq5\`;
  \`ESTADO_ATUAL.md\`, \`DECISOES.md\`, \`tools/Run-Backtest.ps1\`.
- Sem compilacao MetaEditor, sem backtest nem validacao de performance nesta etapa.

## Comparacao funcional

| Dimensao | V12.1 (GitHub) | SMC Liquidity (upload) |
|---|---|---|
| Execucao | Tick scalper XAUUSD M1, guardas e cooldown | Avalia entrada somente em nova barra LTF |
| Timeframes | M1 execucao; M5/M15/H1 contexto | LTF definido; H1 e H4 por padrao |
| Setup | Sweep, BOS/reteste, ticks/EMA/ATR | Sweep + CHoCH/BOS + FVG/OB + premium/discount |
| Score | Parametros/heuristicas ate 100, nao probabilidade | Pontuacao 0..10: HTF, zona, sweep, estrutura, volume, BB, KZ |
| Alvos | Stop/TP com R:R configuravel | Proxima liquidez nao varrida com R:R minimo |
| Gestao | Equidade, limites diarios, protecao por conta | PnL diario realizado, 1 exposicao, BE/parcial |
| Evidencias | Log/Observer/runner/parser ja existentes | **Sem exportacao CSV**; somente Print/painel |

## Problemas prioritarios do arquivo recebido

1. **P0 Risco excedido (linhas 628-653):** se o lote minimo ultrapassar
   o risco pretendido, o EA ainda permite ate 150% do limite. Fere
   a restricao de risco fixo. OrderCalcProfit e chamado como BUY mesmo
   para vendas; tamanhos de contrato/steps exigem validacao por simbolo.
2. **P0 Perda flutuante ignorada (684-715):** o bloqueio diario usa
   negocios historicos, nao equity/floating PnL. Stop diario nao e
   disjuntor de perda total.
3. **P1 Cronologia (469-486):** sweep na MTF pode ser aceito sem amarrar
   seu horario anterior ao BOS/CHoCH da LTF. Testar causabilidade.
4. **P1 Zona parcialmente mitigada (490-515):** criterio para FVG pode
   permitir penetracao na zona e continuar rotulando 'nao mitigado'.
5. **P1 Resultado do envio (718-745):** booleano de CTrade nao substitui
   inspecao de ResultRetcode/ordem final; evento pode ser marcado usado
   sem confirmacao da corretora.
6. **P1 Spread desligado por padrao (InpMaxSpread=0):** risco de custos
   variaveis sem filtro; validar limit/stop/freeze levels.
7. **P1 Sem telemetria de sinais recusados:** nao ha CSV com idade do
   sweep, estrutura, ATR, BB, spread, score, motivo do veto, PnL.
8. **P2 Frequencia:** InpMaxTradesDay=3 e HasExposure() bloqueiam
   multiplicidade; pode ser intencional, mas e diferente do ALIEN.
9. **P2 Viés de documentacao:** \`DECISOES.md\` D10 registra rejeicao
   do veto HTF rigido, enquanto o default do V12.1 em main tem
   \`EnforceStrictHTF=true\`. Resolver antes de comparar resultados.

## Regra de engenharia

**Nao integrar entradas do SMC diretamente no V12.1 nesta etapa.**
Preservar V10.89/V11/V12.1 e medir variantes isoladas. A boa visualizacao
de conceitos SMC nao prova vantagem estatistica.

## Matriz minima de teste (depois de corrigir P0/P1)

- **A** ALIEN V12.1 base em demo/Strategy Tester (hash e .set fixados).
- **B** SMC Liquidity puro, primeiro em modo observacao, sem ordens.
- **C** Sweep + recuperacao + CHoCH causal com contexto H1/H4.
- **D** Variante C com filtro BB/volume como experimento separado.

Mesmos dados e custos (ticks reais, corretora, spread, comissao, slippage,
janelas temporais); separar treino, validacao e holdout; comparar dias
positivos/negativos, expectativa por trade, PF, DD, frequencia, custos e
stops por sessao. Regra aprova/reprova deve ser predefinida antes de
olhar holdout. Nao trocar timeframe ou filtros apos olhar resultados
sem registrar novo EXP_ID.

## Criterio de evidencias

Toda metrica divulgada deve ter artefato primario verificavel.
O arquivo \`REPORTS/ALIEN_DEBRIEF_2026-11-09.md\` registra 0 trades
nas contas 5K e 25K; portanto ele nao sustenta performance de trades.
Relatorios em \`ESTADO_ATUAL.md\` sao afirmacoes historicas ate
serem reconciliadas com HTML/CSV originais. Nenhum lucro e garantido.
