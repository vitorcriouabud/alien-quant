# ALIEN R4.4 — Implementação do protocolo de stop local M1

## Objetivo
Comparar a viabilidade de dois stops **na mesma entrada** após
deslocamento M1 (regra controle do R4.3 A) sobre o mesmo sweep M5:

- **STOP_M5**: extremo do candle M5 que varreu liquidez mais buffer.
- **STOP_M1_LOCAL**: último pivô low/high M1 causal, formado **depois**
  do sweep M5 e confirmado por ambos os vizinhos M1 fechados antes
  do primeiro tick de entrada.

O preço de entrada, spread, tempo, direção, evento, lote hipotético,
filtro H1/M15/M5 e comissão estimada são idênticos. A **distância
do stop**, alvo 4R e risco por stop mudam mecanicamente porque são
derivados do nível escolhido.

Um pivô não confirmado vira linha \`SEM_PIVO_LOCAL\`, preservando
o denominador de cobertura; não se cria stop inventado. Os pares
são reconhecidos por \`sweep_id\` + \`phase\` e a coluna \`stop_model\`.

## Saídas
- CSV *EVENTS*: decisões e filtros originais da cascata.
- CSV *OUTCOMES*: cada entrada tem linha OPEN por stop disponível,
  seguida por TP, SL, TIMEOUT, GAP_TIMEOUT, CALC_ERROR ou censura de
  fim dos dados. Colunas extras:
  \`stop_model\`, \`pivot_at\`, \`pivot_price\`, \`setup_arm_at\`,
  \`all_filters_ok\`.
- STOP_M5 e STOP_M1_LOCAL são simultâneos e hipotéticos.
- HTML de Strategy Tester deve informar barras e ticks processados;
  0 ordens são esperadas.

## Guardas
- \`OnInit\` exige \`MQL_TESTER\`, \`EnableDemoOrders=false\`,
  \`EnableShadowLab=true\`, \`EnableLocalStopPairing=true\`
  e \`UseEarlyMicroBreak=false\`.
- Regra de cálculo não muda RiskPercentEquity=0,25%,
  RewardRiskMultiple=4, stop máximo 180 pts, spread máximo 25 pts.
- Sem ordens nem em DEMO. Sem execução real, nem slippage real, nem
  trailing/BE no resultado contrafactual.
- Não aumentar limites para forçar número de trades.

## Rodar um único backtest
O terminal ALIEN_TEST_MT5 (MetaQuotes-Demo) já deve estar configurado.
Fechar **somente** o terminal isolado antes de executar:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_R44_PAIR.ps1

Intervalo padrão 21/10–07/11/2026, XAUUSD M1 real ticks. O runner
compila o novo MQ5, executa no terminal isolado, busca CSVs de
agentes e gera ZIP privado em PACOTES_MT5 com manifesto de hashes.
Compilação é feita **no MetaEditor do notebook**: CI do GitHub faz
somente testes estáticos e parse de PowerShell, não compile MQL5.

## Critério de validação
Primeiro verificar no período conhecido se logou pares (cobertura
e consistência). Essa janela já foi usada para formular a hipótese,
portanto não pode confirmar vantagem independente.

Depois congelar parâmetros e estudar período posterior/ainda não
usado e custos da corretora de interesse. Reportar:
- quantidade de sinais controle com pares locais válidos;
- percentual sem pivô ou com lado inválido;
- mudança de stop mediano e spread/stop por par;
- interseção \`stop_limit_ok\`, \`spread_limit_ok\`, \`room_ok\`,
  \`size_ok\`, \`session_ok\`;
- diferença de TP/SL/timeout por par com mesmo primeiro tick;
- gaps e amostras pequenas separadamente.

**Não há comprovação de lucro ou prontidão para conta real.**
