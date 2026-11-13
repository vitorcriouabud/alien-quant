# ALIEN MTF CASCATA V1 — Protocolo de pesquisa

## Hipotese, nao promessa de lucro

O arquivo \`MQL5/Experts/ALIEN_MTF_CASCATA_OBSERVADOR_V1.mq5\`
e um **EA de observacao sem ordens**. Nao altera V10.89, V11, V12.1,
presets da mesa, disjuntores ou contas. Qualquer entrada/preco/SL/TP
calculado e somente **hipotetico**; ainda nao existe medicao de PnL.

### Sequencia temporal (sem antecipacao)

1. H1: calcula a media dos 20 ultimos candles H1 ja **fechados antes do
   inicio** da vela M5 examinada; usa esse valor como *proxy* de bias.
   Isso **nao equivale** a uma definicao completa de tendencia SMC.
2. M15: busca FVGs de 3 candles ja fechados **antes do sweep M5** e
   verifica se a vela M5 tocou a faixa. Invalida quando um fechamento
   subsequente passa pela borda oposta. **Nao detecta Order Blocks,
   PDH/PDL, PWH/PWL**: precisam de hipoteses separadas.
3. M5: exige quebra de maxima/minima anterior, fechamento recuperando
   o nivel e pavio proporcional ao **range** do candle.
4. M1: somente velas **fechadas apos o fechamento M5**, com candle
   de deslocamento que rompe o high/low da anterior. A primeira
   confirmacao possivel e no minuto seguinte ao sweep fechado.
5. Spread e risco: usa Bid/Ask vigentes e \`OrderCalcProfit\` para
   estimar risco na moeda da conta, sem comissao/slippage futuros.
   Para vendas, acrescenta spread no stop hipotetico observado pela Ask.
6. Cada evento tem \`event_id\` de sweep; o CSV registra **ABSTER**,
   **VETO_H1**, **VETO_M15**, **ARMADO**, **AGUARDAR_M1**, **VETO_SPREAD**,
   **VETO_RISCO**, **SINAL_CONFIRMADO** e **EXPIRADO**.

A estrutura usa \`CopyRates(..., 1, ...)\` (sem barra atual). Nao ha
\`CTrade\`, \`OrderSend\` ou criacao de pendentes.

## Instalacao no Windows/MetaTrader 5

1. Abrir MetaTrader 5 e depois **Arquivo > Abrir pasta de dados**.
2. Copiar o arquivo \`.mq5\` para \`MQL5/Experts/\`.
3. Abrir MetaEditor (F4), compilar o arquivo (F7) e **conferir a saida**
   (ainda nao foi compilado no ambiente do assistente).
4. Abrir **XAUUSD M1 em conta DEMO ou Strategy Tester isolado**,
   anexar o novo EA e manter \`InpEnableCSV=true\`.
5. No testador, os CSVs ficam na pasta \`MQL5/Files\` do agente
   correspondente. Executar o coletor do laboratorio
   \`tools/COLETAR_CSV_MT5.cmd\` criado no PR de auditoria #3,
   ou localizar CSV manualmente. Essa ferramenta esta em PR separado;
   ainda nao faz parte de \`main\`.

**Padrao nao abre trades**, independentemente do tipo de conta. Se o
arquivo nao compilar, registrar as mensagens exatas e nao editar o EA
principal para tentar consertar este modulo.

## Matriz A/B obrigatoria

- **MTF-A / STRICT**: \`InpHardH1Veto=true\`, todos os demais
  parametros fixos. Somente sinais alinhados H1.
- **MTF-B / CONTEXT**: \`InpHardH1Veto=false\`, demais identicos.
  H1 ainda e calculado/logado, mas nao veta contra-sweeps.

Fixar corretora, dados reais de ticks, periodo, spread, volume
referencia e janela. Executar em serie A/B e depois numa segunda
janela fora da amostra. Os resultados iniciais devem informar:
\`sweeps\`, \`armados\`, \`confirmados\`, \`veto_H1\`, \`veto_M15\`,
\`spread\`, e quantos foram bloqueados por risco.

**Nao comparar PF nem lucro deste prototipo**: ele nao opera, portanto
o resultado financeiro de trades e zero por construcao. Para avaliar
expectativa, adicionar num experimento separado um rotulador causal de
desfecho (se alvo/stop hipotetico foi tocado com Bid/Ask, custos e
tratamento explicito de ambiguidades). So depois autorizar pesquisa
de execucao em **DEMO**, usando as travas adequadas.

## Limites do prototipo

- FVG mede ineficiencia geometrica, nao necessariamente interesse
  institucional.
- O sweep e uma regra OHLC objetiva, nao prova de participacao de
  'smart money'.
- Parada de vela M1 nao implica preenchimento da ordem no preco
  observado. Slippage, gaps e comissoes podem mudar o resultado.
- Uma combinacao H1/SMA20 + M15/FVG pode reduzir a frequencia;
  reducao de operacoes so e beneficiosa se melhorar a expectativa.
- MQL5 compilacao e teste com ticks reais **pendentes**.

Documentacao API oficial:
- https://www.mql5.com/en/docs/series/copyrates
- https://www.mql5.com/en/docs/trading/ordercalcprofit
- https://www.mql5.com/en/docs/files/fileopen
