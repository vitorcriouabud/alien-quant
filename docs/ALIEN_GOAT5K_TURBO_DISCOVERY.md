# ALIEN GOAT5K — TURBO DISCOVERY v0.120 (laboratório sem limites artificiais)

## Objetivo
Tirar o viés causado pelo limite anterior de **6 ordens por dia**,
**30 minutos de cooldown** e **somente uma posição** e registrar o
universo de sinais, sem fingir que multiplicar ordens melhora edge.

O benchmark de outubro-novembro foi reprovado:
M1 96 trades, −US$87,34, PF 0,62;
M1 + filtro H1/M15 72 trades, −US$109,92, PF 0,42.
Em amostra in-sample já conhecida, não vamos escolher o
cenário com maior PnL e chamá-lo de estratégia validada.

## Nove cenários com um mesmo MQ5/EX5 compilado

| Preset | O que testa |
|---|---|
| A_BASE | Controle original: 6 trades/dia, 30min, 1 posição, 7–20h, 2R, lote máximo 0,02 |
| B_FREQUENCY | Pacote de frequência: cap 1.440/dia e cooldown zero, ainda 1 posição |
| C_ALLDAY | Mesma configuração B, mas período completo de segunda a sexta |
| D_MULTI5 | Igual C, mas até 5 posições simultâneas se o testador for hedge |
| E_H1M15 | Igual D, exigindo H1 fechado alinhado à SMA20 e M15 em lado favorável do range |
| F_M5SWEEP | Igual D, exigindo candle M5 fechado que varreu e recuperou pool de 10 M5 anteriores |
| G_M15FVG | Igual D, exigindo FVG simples de três candles M15 fechados, na direção |
| H_RR3 | Igual D, trocando apenas alvo 2R para 3R |
| I_RISKSIZED | Igual D, teto de lote 0,05 (em vez de 0,02), mantendo risco por operação <=0,25% |

**B muda duas restrições de frequência juntas.**
C versus B, D versus C, E/F/G/H/I versus D isolam
uma dimensão conforme seus presets congelados. O cronograma
de oportunidades e seleção da carteira pode diferir.

O limite 1.440/dia equivale ao máximo de aberturas de candles
M1 num dia de 24h e deve ser tratado como virtualmente livre.
Sessões do B seguem 7h–20h do servidor; C em diante aceita
todo o dia útil. Não há abertura aos sábados ou domingos.

Uma conta em **netting** suporta só uma posição por símbolo.
A função EffectiveMaxOpenPositions reduz automaticamente 5
para 1 nesse caso e registra o modo de margem. Não alegar
que houve cinco trades simultâneos se o testador for netting.

## Instrumentação mais importante: TODOS os sinais M1

Antes de verificar cooldown, cap diário, sessão, posições
ou bloqueio de risco, a fonte registra TODO candle M1 fechado
com rompimento do high/low anterior e corpo >=35%.
Cada candidato inclui:
- ID estável, barra e tick timestamp, direção, bid, ask, spread
- corpo M1, entrada, stop local, distância e alvo
- H1 SMA20 fechada + sua inclinação
- posição do M15 fechado ante o equilíbrio do range de 12 barras
- ATR14 M1, Bollinger20 largura e posição relativa
- varredura causal do último M5 fechado ante os dez M5 anteriores
- FVG causal M15 dos três últimos candles fechados
- estado da carteira: dia, posições, cooldown, sessão e limites

O arquivo CANDIDATES.csv permite o pareamento por ID do
MESMO sinal across presets independentemente de haver
uma operação executada. Diferentemente de eventos de
negociação, não é limitado pela regra de seis ordens.

## Desfechos hipotéticos M1: limitações rigorosas

Um módulo independente rastreia cada sinal por até 90 min
nos candles M1 já fechados e classifica:
- STOP_FIRST_TOUCH_M1
- TARGET_FIRST_TOUCH_M1
- BOTH_TOUCHED_AMBIGUOUS (nunca decidir vencedor arbitrariamente)
- TIMEOUT_M1
- CENSORED_END_NO_FUTURE_DATA e NO_SLOT

As operações **reais do Strategy Tester** vão ao TRADES.csv
e ao HTML gerado pelo terminal.
O OUTCOMES.csv é uma aproximação por OHLC M1, NÃO é fill
do broker. BUY usa high/low de BID; SELL estima ASK ao adicionar
spread da entrada a high/low de BID, que pode variar ao longo
do candle. Stops/targets com gap não têm slippage real nesta
modelagem. A taxa de comissão é estimada, não debitada
automaticamente no MT5 MetaQuotes-Demo.

## Risco e limites ainda necessários

- `MQL_TESTER` obrigatório, XAUUSD M1, capital inicial
  US$5000: instala fora do tester => OnInit ABORTA.
- <=0,25% e <=US$12,50 por ordem. Não aumenta risco por trade.
- Volume máximo configurável até 0,05 lote **no tester**;
  tamanho efetivo pode ser menor conforme stop/margem.
- Controles de perda flutuante <=US$35 com margem preventiva,
  exposição das perdas teóricas até todos os stops (pior cenário)
  calculada sobre posições reais do próprio testador,
  drawdown diário preventivo 1% por dia do servidor,
  drawdown total preventivo 8% do capital inicial.
- A perda total bloqueia permanentemente; a trava diária
  só libera no novo dia do servidor, mas **não replica** reset
  de 5PM EST da Goat nem constitui proteção garantida.
- Ordens não podem abrir em conta comprada, nem em demo
  conectada, pois OnInit exige Strategy Tester.
- Stop 35–180 pts, spread máximo 45 pts permanecem no
  universo executável; candidatos além desses limites
  continuam na fita para diagnóstico e não viram ordens.

## Uso no notebook Windows

Na pasta existente `alien-quant`, baixar só:
- MQL5/Experts/ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5
- 9 presets `MQL5/Profiles/Tester/ALIEN_TURBO_*.set`
- tools/RODAR_ALIEN_TURBO_DISCOVERY.ps1
- tools/audit_alien_turbo.py (opcional)

Executar:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_ALIEN_TURBO_DISCOVERY.ps1

O script protege o terminal RoboForex original: fecha
**apenas** terminal64.exe cujo caminho completo é
o do MT5 portátil isolado. Compila uma vez e usa o
mesmo EX5 para os nove cenários. Solicita ticks reais
de 21/10 a 12/11/2026 no MetaQuotes-Demo e compara
as mesmas nove janelas do histórico. Pacote:
`PACOTES_MT5/ALIEN_TURBO_DISCOVERY_YYYYMMDD_HHMMSS.zip`
com nove HTML, presets, três CSV por cenário
(TRADES, CANDIDATES, OUTCOMES), fonte MQ5, EX5,
SHA256s e MANIFESTO.

Se um dos testes falhar, o runner **empacota os testes
anteriores completos** com `success=false` e motivo.
Enviar esse ZIP para investigar, sem baixar tudo de novo.

Auditoria Python opcional:

    python tools/audit_alien_turbo.py PACOTES_MT5/ALIEN_TURBO_DISCOVERY_....zip

Checa hashes, número de negócios, custo adicional
ilustrativo, estatísticas dos candidatos e igualdade de
preço e features no mesmo ID entre variantes. Drawdown
da equity correto deve ser conferido em HTML, não no
CSV de eventos que só amostra alguns ticks.

## Critério de avanço
1. Reproduzir aproximadamente A=96 trades e resultado
   −US$87,34 no mesmo período (se dados e execução iguais).
2. Confirmar que a fita de TODOS os sinais é idêntica entre
   os nove testes, independente da seleção da carteira.
3. Identificar estrutura e regime com **expectativa líquida**
   hipotética e depois executável, desconsiderando barras
   ambíguas do M1 e cobrando comissão.
4. Congelar hipóteses e avaliar em período NOVO, realmente
   independente, sem escolher um vencedor pelos mesmos
   dados utilizados para pesquisá-lo.
5. Só considerar testar no ambiente compatível com a Goat
   após confirmar modalidade e política de EAs por escrito.

**Estado: testes estáticos/PowerShell verificados por CI;
compilação .mq5 e backtests ainda precisam rodar no notebook.**
