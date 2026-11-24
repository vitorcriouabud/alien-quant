# ALIEN A/B — Candle M1 alinhado em Sweep (laboratório)

Status: código preparado em branch experimental e pacote Windows gerado, **sem compilação/backtest local pelo assistente**. `main` e branches existentes não alteradas.

## Pergunta

O filtro pré-entrada `RequireSweepCandleAlignment=true` melhora a expectativa líquida em XAUUSD M1, se comparado à mesma lógica sem o filtro, após os custos?

O filtro consulta **`lastFactor.candle`** gerado em `ScoreSignal` com `candleDelta=(tick.bid-barOpen)/_Point` antes de avaliar SendEntry. A regra veda **apenas signalSetup==1 (Sweep)** quando `lastFactor.candle==0`; não espera o fechamento futuro do candle. `lastFactor.candle>0` equivale ao movimento intrabar M1 estar a favor da direção, incluindo a situação de deslocamento zero que recebe 7 pontos. Não é confirmação por vela fechada, nem previsão de lucro. O veto ocorre após validadores do setup/score e antes de marcar evento como negociado.

## Controle rigoroso

- Um único código fonte, commit `1ddac12c5f5810ad3d24594abf6ed89387e4bb15`, Git blob SHA1 `e995614ee534f9baac0fee59371be2c56bc0c12b`, compilado **uma vez** em `ALIEN_LAB_AB_CANDLE`.
- Preset A: `RequireSweepCandleAlignment=false` (controle, mesmo comportamento do Observador).
- Preset B: `RequireSweepCandleAlignment=true` (candidato).
- Os demais valores são idênticos: `EnableBreakRetest=false`; `EnableLiquiditySweep=true`; `SweepOnlyTradeMode=true`; `EnableEntryObserver=true`; `AllowLiveRealTrading=false`; lote 0,01; teto 0,25% equity/trade; `RiskStopMoney=12.50`; `RoundTurnCommissionPerLot=8.00` (entrada estimada); 5.000 USD demo, XAUUSD M1, alavancagem 1:100.
- Teste temporariamente fora da janela de descoberta 13–22/11/2026: **02–12/11/2026** (a data foi vista em outras avaliações históricas, portanto não é um holdout puro; a hipótese específica do fator candle foi selecionada do último teste). Modo 4 ticks reais; exigir que CADA HTML confirme 100% e a contagem/tick history seja comparável.
- Desabilitados otimização/cloud/remote, `AllowLiveTrading=0`, sem trades reais e sem merge.
- Cada variante cria seu próprio conjunto de arquivos `ALIEN_V1089_TRADES_..._A...` e `..._B...` para não agregar os dois testes em um CSV (proteção de proveniência).
- Script: `ABRIR_COMPARACAO_ALIEN.cmd` gera `ENVIAR_ALIEN_AB_*.zip` com HTML de A e B, hashes, CSV e relatório TXT dos agentes, se localizados. Não exige carregar presets manualmente.

## Interpretação

- Não comparar com resultados de 13–22/11 como se fossem validação externa. São dados de seleção da hipótese.
- Não prometer que as 7 operações com `p_candle>0` dariam lucro em execução modificada: os filtros alteram quais sinais futuros ficam elegíveis.
- Checar diferenças em lucro/prejuízo **líquido**, profit factor, DD máximo, quantidade de operações, distribuição por dias, horários e custos. Pior resultado em A ou B nesta janela significa continuar investigando, não ajustar parâmetros no mesmo período até vencer.
- Resultado positivo em 02–12/11 ainda requer validação em mais meses/corretora (sem antecipar o conhecimento do futuro) para reduzir sobreajuste.
- Um CSV vazio, uma qualidade abaixo de 100%, problema de compilação ou divergência de presets invalida a comparação.
- É necessário um número suficiente de operações; não declarar edge com poucos trades.
