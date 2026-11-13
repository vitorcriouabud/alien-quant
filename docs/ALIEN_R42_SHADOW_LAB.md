# ALIEN R4.2 SHADOW LAB — Estudo de entradas rejeitadas

## Decisao

Depois de 21/10–07/11/2026 na MetaQuotes-Demo:
- R4.1 A: 125 setups M5, 0 operacoes.
- R4.1 B: 123 setups M5; 15 retestes, 1 confirmado, 0 entradas.
- Spread mediano *dos eventos* em A: 33 pontos, acima do teto 25.
- Stops acima do limite entre 235 e 1210 pontos nos casos vetados.

Nao ha resultados financeiros ou expectativa positiva demonstrados.
O objetivo do R4.2 e **medir o destino hipotetico** dos
deslocamentos/retestes, nao tentar ganhar mais trades de forma forçada.

## Alteracao em relacao ao R4.1

- Derivado do R4.1 numa NOVA branch; R4 e R4.1 permanecem intocados.
- Input \`EnableDemoOrders=false\` e \`OnInit\` recusa:
  * qualquer ambiente fora do Strategy Tester;
  * EnableDemoOrders=true;
  * ShadowLab desligado;
  * input de nome de CSV com | (impede regressao do erro 5004).
- **Nao envia ordens**; qualquer tentativa de habilita-las aborta o
  OnInit antes de iniciar a simulacao.
- Quando um candle M1 fechado confirma deslocamento, registra UMA
  candidata \`DESLOCAMENTO\` por sweep, mesmo se for vetada depois
  por spread, stop ou margem.
- Quando um reteste fecha e confirma, registra UMA candidata
  \`RETESTE\` por sweep (somente para setups que armaram reteste).
- Usa Bid na liquidacao de compra, Ask na liquidacao de venda,
  olhando os ticks seguintes somente; alvo = 4R, stop = estrutura M5.
- Encerra em TP, SL, 90 minutos ou censura por fim do teste.
  Gaps sao marcados pelo preco do primeiro tick, nao pelo stop
  virtual quando houver salto.
- CSV registra spread/stop, tamanho de stop, flags para filtros,
  estimativa de comissao, bruto e net_R estimado para lote 0.01.
- Nao simula execucao, fill, slippage real, margem dinamica,
  trailing stop nem breakeven. **Nao equivale ao lucro de um EA operante**.

O logger paralelo \`ALIEN_R42_SHADOW.csv\` tem colunas:
opened_at, candidate_id, sweep_id, phase, state, side, h1_bias, poi_type,
entry, stop, target, stop_points, spread_points, spread_over_stop,
stop_limit_ok, spread_limit_ok, room_ok, size_ok, ref_lot, observed_at,
exit_price, gross_pnl, estimated_commission, net_r, held_seconds.

Os estados sao OPEN, SL, TP, TIMEOUT, CALC_ERROR e CENSURADO_FIM_DADOS.
Avaliar pares pelo MESMO sweep_id; linhas OPEN nao sao trades fechados.
Cada linha TP/SL/TIMEOUT e um resultado CONTRAFACTUAL, nao um fill.

## Unico backtest de coleta

Instalacao do MT5 isolada ja foi preparada em LOCALAPPDATA.
No repositorio da branch, com MetaQuotes-Demo configurada no MT5
isolado e esse terminal fechado:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_R42_SHADOW.ps1

Periodo padrao 21/10/2026–07/11/2026, XAUUSD M1, dados ticks reais.
O runner compila, verifica MetaEditor, inicia Strategy Tester,
coleta dois CSV, HTML, preset, hashes no ZIP em PACOTES_MT5.

## Como decidir apos o ZIP

Comparar:
- Quantos sinais de deslocamento foram registrados?
- Quantos falharam no spread e qual spread/stop?
- Quantos tiveram stop excessivo? Entre esses, proporcao de SL vs TP
  hipotetico sem abrir ordem.
- Para sweep_id com reteste: mudou a distancia ate o stop?
  Mudou o resultado ou so a chance de expiracao?
- Quanto retorno bruto foi consumido pela comissao estimada?
- Quantas linhas foram censuradas no fim dos dados?

Somente com esse estudo vale escolher uma alteracao por vez
para R4.3: ponto de entrada, spread relativo ou janela temporal.
Nenhum caso de 17 dias valida lucro futuro. Para decisao de
execucao real, requer backtests operacionais em DEMO e holdout
independente.

**Status:** CI valida apenas sintaxe de PS e invariantes de fonte;
compilacao MQL5/Strategy Tester do R4.2 dependem do notebook do usuario.
