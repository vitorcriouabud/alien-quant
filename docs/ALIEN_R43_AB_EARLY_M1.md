# ALIEN R4.3 — A/B estrutural de gatilho M1 (sem ordens)

## Resultado motivador do R4.2
No intervalo 21/10–07/11/2026, conta MetaQuotes-Demo XAUUSD M1:
- 61 candidatos hipotéticos (60 deslocamentos e 1 reteste)
- Deslocamentos: 6 TP, 39 SL, 15 TIMEOUT; net_R estimado médio -0,165
- 0 candidatos aprovados ao mesmo tempo por stop 35–180 pontos,
  spread máximo 25 pontos e espaço suficiente até a liquidez oposta
- Três TIMEOUT passaram de 90 min sem tick adequado; havia um gap de fim
  de semana, então o resultado não equivale a saída aos 90 minutos.

Os dados não demonstraram vantagem. **Não aumentar stop/spread só para operar.**

## Hipótese nova: somente UMA variável de entrada

**A — DESLOCAMENTO**
- Exatamente o critério existente do R4.2: candle M1 fechado a favor
  do sweep com corpo >= 56% do range e fechamento acima/abaixo da
  máxima/mínima do candle anterior, com buffer fixo.

**B — MICROBREAK**
- Mesmo sweep M5, mesma H1 e FVG/OB M15, mesmos filtros e risco.
- Candle M1 fechado a favor do sweep rompe a máxima/mínima das
  **três velas M1 fechadas anteriores** com corpo >=25%.
- Esta definição objetiva é uma **proxy de quebra de microestrutura**
  e NÃO comprova CHoCH institucional nem detecta pivôs de mercado
  confirmados. Só a comparação empírica pode dizer se ajuda.

O arquivo .mq5 é o mesmo para A e B; apenas UseEarlyMicroBreak e
nomes de CSV diferem nos presets. O script congela o EX5 após A.

Os sinais são simulados com as mesmas fórmulas de stop extremo M5,
TP 4R, comparação de Bid/Ask, comissão estimada US$ 8,30/round trip/lote
e lote referência 0,01. Não há ordens, mesmo em demo; OnInit rejeita
qualquer execução fora do Strategy Tester ou tentativa de EnableDemoOrders.

## Correção do horizonte

ShadowUpdate usa precedência temporal: não considera TP/SL na cotação
que surgiu após o horizonte de 90 min. Para TIMEOUT registra saída
hipotética com o **último preço observado antes do prazo**;
se há grande lacuna entre essa cotação e o próximo tick, marca
GAP_TIMEOUT (não incluir na análise de TP/SL sem separar).
O CSV contém o novo campo session_ok, calculado no horário do
servidor para cada candidato.

Isso ainda é uma simplificação: no mercado real, o operador não
conseguiria encerrar num tick que já passou. Esses eventos são
**censurados operacionalmente**, não fills demonstrados.

## Execução automática em MetaQuotes-Demo / MT5 isolado

Sem baixar novamente o projeto completo: atualizar os 4 arquivos
na branch; depois fechar SOMENTE o terminal de testes e executar:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_R43_AB.ps1

O script usa XAUUSD M1, ticks reais solicitados, os mesmos 17 dias,
compila A, roda B usando EX5 congelado, salva dois HTML, quatro CSV,
dois presets e MANIFESTO.json (SHA256) num ZIP de PACOTES_MT5.

Verificar que os HTML realmente mostram ticks processados. A qualidade
100% indicada para o periodo nao basta para provar vantagem, porque
essa janela ja serviu para desenvolver a hipótese.

## O que comparar

Para cada sweep_id, unir os candidatos A e B:
- Tempo de sinal, numero e sobreposicao de candidatos
- stop_points, spread_points, spread_over_stop, session_ok
- flags stop_limit_ok, spread_limit_ok, room_ok, size_ok
- TP / SL / TIMEOUT / GAP_TIMEOUT por fase
- diferenca de resultado net_R hipotetico por sinal pareado
- diferenca nos sinais que nao tiveram par (risco de selecao)

Aceitar para a proxima versao somente uma variante com vantagem
reproduzivel após custos em holdout nao utilizado no desenvolvimento.
Ainda faltam execucao realista, robustez da corretora, custos reais,
compilacao no MetaEditor e dados fora da amostra.

## Status
- Código-fonte, presets e script publicados; compilacao MetaEditor e
  backtest R4.3 ainda **NAO** executados/verificados.
- CI verifica somente estrutura fonte, defaults e sintaxe PowerShell.
