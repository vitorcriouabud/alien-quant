# ALIEN — R4.4 PROTOCOLO DE PESQUISA: STOP LOCAL M1

Status: **especificacao experimental, sem codigo executavel e sem trades**.
Base: R4.3 observador; preservar R4.1, R4.2, R4.3 e seus resultados.

## 1. Evidencias que motivam a mudanca
- R4.3, MetaQuotes-Demo XAUUSD M1, 21/10–07/11/2026: A e B produziram 60 sinais hipoteticos diretos cada, 0 entradas que passaram simultaneamente spread, distancia do stop e espaco 4R.
- A teve 6 TP, 39 SL; B teve 4 TP, 39 SL (ambos com TIMEOUT e GAP_TIMEOUT); medias -0,150R e -0,179R, hipoteticas.
- Stops medianos 433 pts (A) e 447,5 pts (B), contra teto de 180 pts.
- 37 de 49 sinais pareados ocorreram no mesmo instante; a mudanca do gatilho nao trouxe antecipacao consistente.
- Resultados nao demonstram vantagem, e os dois estudos exploraram o mesmo periodo (nao e holdout).

## 2. Hipotese unica (R4.4)
**Mantendo o gatilho A do R4.3 e TODAS as outras condicoes fixas**, comparar dois stops hipoteticos no MESMO sinal, para descobrir se a invalidaçao local M1 reduz a distancia sem perder acuracia:

- **Controle C / STOP_M5**: extremo da varredura M5 +/- buffer, conforme R4.3.
- **Tratamento L / STOP_M1_LOCAL**: pivô local formado APOS o sweep, conhecido antes da confirmacao/entrada; ultimo fundo local para BUY ou ultimo topo local para SELL, mais buffer. Nao usar valores futuros. Necessita pelo menos uma microestrutura visivel; se nao existir, `SEM_PIVO_LOCAL`, e nao inventar stop.
- Pivô causal (especificacao para implementacao): um candle M1 fechado e confirmado como swing pela vela fechada seguinte, ambas estritamente anteriores ao tick de entrada. Nao usar fractal que exige velas posteriores ao sinal, nem indices `0` de candle corrente.
- Stop local invalida somente a **hipotese de reacao M1**. Um stop mais curto pode aumentar perdas mesmo se o sweep M5 continuar valido. Proibir contar a mesma movimentacao como confirmacao futura.

**NAO mudar ainda o ponto de entrada, filtro de sessao, H1, POI, ATR, BB, TP=4R, calculo de custo nem limite de risco.**
Todos os sinais de ambos os grupos devem ter os mesmos `sweep_id` e `signal_at`, com `pair_id` estavel.

## 3. Estudo de viabilidade antes de simular retorno
Para cada par registrar:
- preco no primeiro tick apos o candle fechado; Bid/Ask, spread em pontos e spread / stop;
- stop M5 e stop M1, risco em USD/0.01 lote e volume maximo para risco=0,25% do saldo; custo round-turn estimado;
- `stop_valid` (lado correto, 35–180 pts), `spread_ok` (<=25 pts), `room_4R_ok`, `session_ok`, `size_ok`;
- flag `local_pivot_confirmed_before_entry` e origem temporal exata de cada nivel;
- MAE/MFE em R por 90min e desfecho causal TP/SL/TIMEOUT/GAP_TIMEOUT/CENSURADO, separando fim de semana;
- classificar NAO_EXECUTAVEL se falhar qualquer filtro. Nao operar nem em DEMO.

Se stop local ficar muito perto do ruido/spread, registrar o veto — NAO alargar stop artificialmente nem aumentar risco.

## 4. Controle de qualidade
- Um UNICO backtest de ticks reais com duas candidatas shadow por sinal (nao dois EAs diferentes).
- Mesma cotacao e mesmo momento de decisao; sem lookahead.
- Nenhuma ordem real ou demo; guardas de OnInit proibem `EnableDemoOrders=true`, e proíbem fora de Strategy Tester.
- Evitar comparar apenas sinais que tiveram pivô M1: relatar cobertura (quantos eventos sem pivô) para evitar vies de selecao.
- Exibir distribuicoes de stop e spread/stop, intersecao de filtros, taxa de TP/SL por stop e por regime; custos explicitos.
- Aplicar modelo de encerramento de timeout sem usar ticks apos o prazo como fills reais. Em gap, classificar intervalo sem cotacao; nao usar retorno de gap como TP/SL dentro da janela.
- Guardar dois CSVs, HTML, preset e hashes num ZIP **privado**. Nao publicar arquivo de contas/log completo no GitHub.
- Exigir compilacao MetaEditor e tester MT5 Windows primarios; CI de sintaxe nao prova estrategia.

## 5. Regime de validacao e decisao
O estudo de 21/10–07/11/2026 ja foi usado para formular R4.4. Pode ser usado para detectar bugs e checar comportamento mecanico, **nao** como confirmacao estatistica independente.
Antes de concluir, congelar parametros e avaliar em periodo e dados de broker ainda nao usados para selecionar esta hipotese, respeitando disponibilidade de ticks. Preferir condicoes do contrato/conta 5K que o usuario pretende operar, nao assumir que spreads de MetaQuotes-Demo representam o broker.
Resultado prometido do proximo experimento: dizer quantas entradas continuam inviaveis, quantos stops M1 sao causais e quais desfechos alteram, com incerteza e sample size, SEM anunciar lucro futuro.

**Gate de avanco:** se o stop local nao aumentar a quantidade de candidatos viaveis E nao melhorar desempenho hipotetico apos custos de forma robusta, descartar R4.4; nao ficar afrouxando limiares para forcar operacoes.

## 6. Fora do escopo
- IA decidindo ao vivo, otimizacao automatica, grid/martingale, entradas em conta real ou mesa proprietaria.
- Inventar vantagem de SMC/ICT, CHoCH ou FVG sem medicao.
- Criar R4.5 antes de validar o R4.4.

## 7. Entregavel da implementacao posterior
`ALIEN_R44_LOCAL_STOP_SHADOW.mq5` + preset unico observador + runner unico + CI + relatorio de viabilidade/pareamento. **Nao criados neste commit**: este documento e uma especificacao auditavel, nao um artefato pronto para rodar.
