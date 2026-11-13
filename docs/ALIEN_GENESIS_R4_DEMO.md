# ALIEN GENESIS MTF R4 - Estrategia substituta em DEMO

Fonte completa publicada; compilacao MetaEditor e backtest ainda pendentes.

Esta e uma nova arquitetura com todas as confluencias ligadas. Envia ordens
somente em DEMO e Strategy Tester. Conta real e bloqueada no proprio codigo.

## Cascata

- H1: SMA20 de candles fechados antes do sweep M5 e alinhamento obrigatorio.
- M15: FVG de tres candles OU Order Block heuristico, ambos scanners ativos.
- M5: sweep de topo/fundo anterior + reclaim e pavio.
- M1: candle fechado depois do sweep, corpo de forca e rompimento.
- ATR e Bollinger ativos para filtrar volatilidade versus spread.
- Sala ate liquidez oposta M5 obrigatoria para buscar o alvo 4R.

## Risco, saidas, logs

Risco alvo 0,25% da equity, stop entre 35 e 180 pontos, 4R,
spread maximo 25 pontos, slippage reservado 10 pontos, maximo
1 posicao simultanea, maximo 6 entradas por dia.
Break-even depois de 1,6R, ATR trailing depois de 2,6R, bloqueio
do dia apos 2% de perda da equity de referencia.

Os valores de pontos dependem de _Point no contrato negociado.
Se o stop estrutural exigir mais de 180 pontos, a entrada e vetada.
Se o lote minimo exceder o risco calculado, a entrada e vetada.
A comissao EstimatedRoundTurnPerLot esta em 0 apenas porque
nao temos taxa exata do broker; configurar antes de validar.
Slippage, gaps e taxas podem causar perda acima da estimativa.

## Validacao obrigatoria

1. Abrir MQL5/Experts/ALIEN_GENESIS_MTF_R4_DEMO.mq5 no MetaEditor e F7.
2. Registrar saida do compilador, SHA256 do fonte, EX5 e preset.
3. Executar somente XAUUSD M1 em DEMO ou terminal portatil do testador.
4. Coletar HTML do MT5 e CSV ALIEN_GENESIS_MTF_R4.csv.
5. Comparar H1 rigido/flexivel, FVG/OB, 3R/4R/5R com ticks reais e custos.
6. Repetir fora da amostra e exigir reproducibilidade.

Nao declarar lucratividade, versao final ou uso em REAL ate essa validacao.
O coletor CSV/HTML esta no PR #3, em branch separada.

Documentacao:
https://www.mql5.com/en/docs/trading/ordercalcprofit
https://www.mql5.com/en/docs/trading/ordercalcmargin
https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade
