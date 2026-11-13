# ALIEN GENESIS R4.1 — Reteste inteligente, experimento controlado

Status: **codigo e presets publicados na branch, ainda sem compilacao
MetaEditor nem backtest confirmados**. Nao usar em conta REAL.
O motor de ordens roda apenas em DEMO/testador.

## Por que essa versao existe (evidencia do R4)

O CSV bruto \`ALIEN_GENESIS_MTF_R4.csv\` do backtest XAUUSD M1
01/08–24/10/2026 contem 4.152 eventos de log (alem do cabecalho):
- 1.989 sweeps, reconstruidos pela soma dos resultados
  \`VETO_H1\` (1.073), \`VETO_POI\` (322) e \`ARMADO\` (594).
- 594 setups armados; \`EXPIRADO\` (301),
  \`VETO_STOP\` (279), 5 trades executados, 4 vetos de espaco,
  4 vetos de sessao e 1 cooldown. Eventos \`AGUARDAR_M1\` repetidos
  representam checagens M1, nao novos setups.
- Os 279 stops vetados variaram de aprox. 183 a 4.355 pontos,
  mediana 461 pontos (o teto era 180 pontos).

O HTML do R4: +US$120,78, 5 trades, 3% de ticks reais.
Amostra insuficiente, sem comprovacao de lucratividade.

## O que muda no R4.1

**Um fator experimental isolavel: \`EnableM1Retest\`.**

1. Continua exigindo H1 + POI M15 + sweep M5 + displacement M1.
2. Se o displacement estiver longe e exigir stop maior que 180
   pontos, **NAO abre ordem**; registra \`RET_ARMADO\` e passa ao
   estado de reteste M1.
3. O nivel de reteste e a maxima (compra) ou minima (venda) da vela
   M1 anterior ao candle de deslocamento.
4. Apenas candles M1 fechados **depois** do deslocamento podem
   satisfazer o reteste. Exige toque na faixa, ausencia de
   penetracao excessiva, candle de defesa e fechamento alem do nivel.
5. O setup preserva o extremo do sweep M5 como invalidez estrutural.
   Se violar esse extremo, aborta \`RET_INVALIDADO\`.
6. A cada confirmacao recalcula **Bid/Ask, spread, stop, TP, ATR,
   Bollinger, espaco para 4R e risco monetario**. Sem stop curto
   suficiente, aborta em vez de forcar trade.
7. O estado de reteste permanece valido por 4 candles M1 apos o
   displacement, mesmo que um novo M5 abra. Expira se nao confirmar.

O novo CSV \`ALIEN_GENESIS_MTF_R41.csv\` contem:
\`RET_ARMADO\`, \`RET_AGUARDANDO\`, \`RET_CONFIRMADO\`,
\`RET_INVALIDADO\`, \`RET_STOP_LONGO\`, \`RET_EXPIRADO\`,
\`RET_ORDEM_EXECUTADA\` e \`TRADE_FECHADO\`.
A contagem de retestes nao mede lucro; usar relatorio HTML do MT5.

## Protecoes preservadas

- \`RiskPercentEquity=0.25\`; maximo de 180 pontos para stop.
- \`RewardRiskMultiple=4\` com alvo permitido apenas se houver
  espaco ate a liquidez oposta M5.
- Bloqueio de conta REAL, max 1 posicao, 6 entradas/dia,
  disjuntor diario 2%, BE/trailing, cooldown.
- \`EstimatedRoundTurnPerLot=8.30\`: estimativa aproximada com base
  na conta demonstrada no relatorio R4 anterior (USD 10,35 de
  comissoes sobre 1,25 lotes ida/volta = USD 8,28 por lote).
  Revisar conforme a conta/corretora. Nao e garantia de custos.

## Um clique no notebook: A/B automatizado

O script \`tools/RODAR_R41_AB.ps1\` usa **somente**
\`C:\\ALIEN_TEST_MT5\` (terminal portatil), e para se estiver ausente.
Ele executa duas simulacoes sequenciais:

- **A_BASELINE**: \`EnableM1Retest=false\`.
- **B_RETESTE**: \`EnableM1Retest=true\`.

Ambas recebem os outros 67 parametros identicos (exceto nome do CSV).
O wrapper usa \`Run-Backtest.ps1 -PresetPath\` com preset completo.
Os resultados e manifests sao gravados em \`results/\` e num
ZIP local em \`PACOTES_MT5/\`. **Nao faz upload** para GitHub nem
para ChatGPT. Anexe o ZIP aqui depois de conferir privacidade.

Com a pasta clonada da branch R4.1:

    powershell -ExecutionPolicy Bypass -File .\tools\RODAR_R41_AB.ps1

Por padrao: XAUUSD M1, 21/10/2026 a 07/11/2026,
modelo 4 (ticks reais solicitados), deposito 10K, alavancagem 1:100.
O modelo solicitado nao prova cobertura: **conferir o percentual
"Qualidade do historico" no HTML** para A e B.

Uma outra janela, que nao foi usada para calibrar o R4, deve entrar
como holdout. Nao considerar o A/B sobre 2026-10/11 como
validacao definitiva: o projeto ja pesquisou essas datas.

## Como julgar o resultado

Registrar para A/B: qualidade ticks reais, numero de trades,
frequencia, ganhos/perdas, PF, valor liquido, drawdown max equity,
comissao, desvio e quantidade de \`RET_ARMADO\`,
\`RET_INVALIDADO\`, \`RET_EXPIRADO\`, \`RET_ORDEM_EXECUTADA\`.

Aceitar a funcionalidade se o B produzir registros coerentes e
retornos reproduziveis, **nao se apenas gerar mais ordens**.
Rejeitar ou calibrar a hipotese se o reteste aumentar custo,
DD ou stop-outs sem melhorar resultado fora da amostra.

## Limites

Testes automaticos no GitHub verificam sintaxe PowerShell e guardas
estaticas MQL5; nao sao compilacao nem estrategia validada.
O risco de mercado real pode ultrapassar o estimado por slippage/gaps.
O risco de lote usa parametros do simbolo no tester.
Verificar eventuais ordens parciais, recalculo do risco apos fills
e estado do terminal em auditoria posterior.

APIs MQL5:
- https://www.mql5.com/en/docs/series/copyrates
- https://www.mql5.com/en/docs/event_handlers/ontradetransaction
- https://www.mql5.com/en/docs/trading/historydealselect
