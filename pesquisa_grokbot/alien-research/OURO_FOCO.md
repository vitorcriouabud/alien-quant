# OURO EM FOCO (XAUUSD) — pré-registro + resultados

## Parte 0 — O que JÁ foi testado no ouro (para não repetir)
Lido em RESULTS.md, RESULTS_V2.md, MERCADO.md, DESLOCAMENTO.md, FRENTES.md, TENDENCIA_MULTI.md e REAL_TICKS_V11.md:

| Ideia no ouro | Onde | Resultado |
|---|---|---|
| Sweep de liquidez + rejeição (M5/M15, lookback rolante 12/24/48 barras) | RESULTS F1 (2023–26) | reprovado |
| FVG reteste, rompimento+reteste, ORB Londres/NY, momentum/fade de sessão, Bollinger M5/M15, sweep→CHoCH→OB | RESULTS F2–F8 | reprovado |
| Faixa asiática: rompimento e **fade após sweep da Ásia** | RESULTS F4, V2 S2 (2015–26) | reprovado |
| Hora do dia: compra/venda às 18h, 03h, 09h, 16h NY segurando 4 ou 8h (inclui 18h→02h = "Ásia") | V2 S1, RESULTS F9 | reprovado (t≈0 em 11 anos) |
| RSI2 D1 e IBS D1 (dormindo posicionado) | V2 | RSI2 negativo; IBS<0,25 PF 1,28 t 1,5 (não significativo) |
| Bollinger H1/H4 (reversão) | V2 M2 | negativo (t −1,2 a −4,7) |
| Donchian, médias, TSMOM H4/D1 (24 variantes) | V2 + FRENTES | reprovado (só "beta" + swap) |
| Notícias CPI/NFP/FOMC (rompimento, fade, straddle) | FRENTES | reprovado, perde até sem custo |
| Deslocamento M5/M15 (continuação e fade, 312 testes) | DESLOCAMENTO | reprovado |
| Modelo SMC/ICT completo (viés, PD, sweep Ásia/PDL na kill zone, CHoCH, FVG/OB) | V2 seção 4 | reprovado, perde sem custo |
| Estudo descritivo: sweep de PDH/PDL, Ásia, sessões, topos/fundos iguais → "volta pra dentro" 42–56% | MERCADO 3 | sem vantagem (só taxa de retorno, sem trade executável) |
| Indicadores clássicos M15/H1, candles, pivots, VWAP, números redondos, top-down | MERCADO 8 | reprovado |
| Virada do mês no ouro (segurando 4 noites) | MERCADO 9 | **lista de observação**: bruto t 3,0, líquido t 2,4 (2015–25), 2026 +31bp (n 11) |
| Tendência em 19 mercados | TENDENCIA_MULTI | reprovado (swap) |
| V11 scalper com ticks reais | REAL_TICKS_V11 | sem evidência de lucro |

Total já gasto: ~2.280 tentativas no projeto. Isso entra na correção global (seção 6).

---

## Parte 1 — PRÉ-REGISTRO (escrito 15/11/2026 ~01:30 horário de Brasília, ANTES de rodar qualquer teste desta rodada)
Nada abaixo muda depois de ver números. Mudança = nova tentativa, registrada no log.

### 1. Dados e divisão
- Dukascopy XAUUSD M1 bid/ask 2016-01 → 2026-11-13 (`data/xau_m1_2016_2026.parquet`, barras de enchimento removidas).
- Sinais no preço médio de barras **fechadas**. Compra entra no ask, sai no bid; venda o contrário.
- **IS = 2016–2024. Validação = 2025. 2026 guardado** e aberto **uma vez**, só para sobreviventes.
- Horários em Nova York (rollover/swap às 17:00 NY = 00:00 do servidor). Fix de Londres em horário de Londres.

### 2. Custos
- **Principal:** spread real bid/ask Dukascopy + comissão **US$ 16,80/lote ida e volta (0,168/oz)**. Stop executa no preço do stop, ou na abertura do M1 se abrir além (gap). Stop e alvo no mesmo M1 → conta o stop.
- Swap só se passar das 17:00 NY: compra −5,5%/ano do preço, venda +1,7%/ano (valores lidos na demo RoboForex-ECN), triplo na quarta.
- **Sensibilidade (não decide):** comissão US$ 8/lote.
- Tudo operacional sai antes das 16:45 NY (sem swap), exceto ToM-B.

### 3. Hipóteses e variantes (37 no total)

**Família MR — reversão de curto prazo intradiária (H1/H4), saída antes do rollover (10 variantes)**
Motivo: o único efeito grande do projeto é reversão de curto prazo (índices D1); no ouro D1 o swap pesa e o RSI2 D1 falhou, mas a autocorrelação intradiária do ouro é levemente negativa (MERCADO 1). Ainda não testado em H1/H4 com saída no mesmo dia (Bollinger H1/H4 é outra regra e falhou — esperamos falha, testamos uma vez).
- Saída comum: compra sai no primeiro fechamento H1 acima da máxima da H1 anterior (venda: abaixo da mínima), ou após 8 barras H1, ou às 16:45 NY. Stop 2×ATR(14,H1) da entrada. Entrada na abertura da barra seguinte; sem entradas 16:00–18:00 NY.
- MR1 H1 RSI(2) < 5 compra / > 95 venda. MR2 H1 RSI(2) < 10 / > 90. MR3 H4 RSI(2) < 10 / > 90 (H4 = blocos 18,22,02,06,10,14 NY; saída por barras H1 igual, máx 8h). MR4 "esticada": movimento das últimas 4 H1 < −2,5×ATR(H1) compra / > +2,5 venda.
- Cada uma em duas versões: **ambos os lados (LS)** e **só compra (LO)** → 8.
- Filtro de regime (MR1 LS): MR1-lowvol só quando ATR(H1)/mediana(ATR H1, 120 barras) < 1; MR1-highvol quando ≥ 1 → 2.

**Família FIX — fix de Londres (6 variantes)**
Literatura: movimentos anormais em torno do fix (Caminschi & Heaney 2014; Abrantes-Metz & Metz 2014, queda no PM fix 2004–13). Desde 2015 o fix é leilão LBMA. Nunca testado no projeto.
- FX1 venda 10:15→10:35 Londres (AM fix), FX2 compra idem; FX3 venda 14:45→15:05 Londres (PM fix), FX4 compra idem.
- FX5 fade pós-PM-fix: direção = sinal do movimento 14:00→15:00 Londres; entra contra às 15:00, sai 16:00 Londres. FX6 segue a direção (continuação), mesma janela.
- Sem stop (janela curta); risco medido como pior perda.

**Família SES — overnight × dia americano (2 variantes)**
- SE1 compra 18:05 NY → 08:20 NY (Ásia+Londres, sem dormir no rollover). SE2 venda 08:30 → 16:45 NY. (Diferente do 18h+8h já testado: janela inteira, e o lado americano.)

**Família CAL — dia da semana e virada do mês intradiários (7 variantes)**
- DW1..DW5: compra da reabertura 18:05 NY da véspera → 16:45 NY, só segunda, terça, quarta, quinta, sexta (1 variante cada). Comparado também com a média de todos os dias (para separar de "beta").
- ToM-A: virada do mês (penúltimo dia útil até o 3º dia útil) operada **intradiária** (18:05→16:45 cada dia, sem swap). ToM-B: virada do mês segurando continuamente com swap real (repete a lista de observação; **2015–2025 já foi visto**, então só vale como confirmação, e 2026 já tem 11 casos vistos — declarado).

**Família SW — sweep de liquidez com definições NOVAS (12 variantes)** (pedido do Vitor)
Já testados e NÃO repetidos: sweep com lookback rolante (F1), fade do sweep da Ásia (F4/S2), sweep+CHoCH (F8 e SMC), taxas de "volta pra dentro" (MERCADO 3). Novo aqui: níveis **nomeados** com fechamento de volta para dentro e **stop além do extremo do sweep**, em 2016–2024, incluindo **máxima/mínima da semana anterior** (nunca testada).
- Níveis: **PD** = máxima/mínima do dia anterior (dia 18:00→17:00 NY); **PW** = máxima/mínima da semana anterior; **EQ** = topos/fundos iguais: dois fractais M15 (2/2) das últimas 48 barras M15 a menos de 0,1×ATR(M15) um do outro, ainda não violados.
- Evento (TF = M5 ou M15): a barra passa do nível (máxima > nível de topo) e **fecha de volta para dentro**. Venda no topo, compra no fundo. Um evento por nível por dia; janela 18:00–16:00 NY.
- Entrada na abertura da barra seguinte. Stop = extremo do sweep + 0,1×ATR(TF). Saída: **(a) alvo 2R** ou (b) **saída por tempo 4h**; ambas com saída forçada 16:45 NY. Se o stop exigir > 3×ATR(TF), não opera.
- 3 níveis × 2 TF × 2 saídas = 12.
- **Estudo do caminho (descritivo, não conta como tentativa):** a partir do fechamento do evento, na direção da reversão: retorno, MFE e MAE em ATR(TF) em 1h, 4h e fim do dia (16:45 NY); taxa de reversão (retorno > 0 em 1h). **Controle pareado:** barras do mesmo TF, mesmo ano e mesma hora NY, em que a máxima ultrapassou o máximo das últimas 12 barras e fechou de volta (topo "qualquer", não nomeado) — testa se o nível nomeado acrescenta algo.

Total: 10 + 6 + 2 + 7 + 12 = **37 tentativas** (+9 da família INST abaixo = 46).

**Família INST — pegadas de fluxo institucional (9 variantes)** — adicionada em 15/11/2026 ~01:30, pedida depois; ver log.
Já testado antes? Fix de Londres: só nas variantes FX desta rodada (janelas de 20 min e pós-PM). Fix WMR / fim de mês intradiário: **nunca**. COT: **nunca**. (Virada do mês multi-dia no ouro já estava na lista de observação = ToM-A/B acima.)
1. Fix LBMA (horário de Londres), entrada e saída a mercado, sem stop:
   - IN1 fade pós-AM-fix: direção = movimento 10:00→10:30; entra contra às 10:30, sai 11:30.
   - IN2 continuação pós-AM-fix: mesma janela, a favor.
   - IN3 "drift para o PM fix": direção = movimento 13:30→14:15; segue de 14:15 até 15:00.
2. Rebalanceamento de fim de mês / WMR 16:00 Londres (últimos 3 dias úteis do mês + 1º dia útil):
   - IN4 compra 15:30→16:05 Londres. IN5 venda 15:30→16:05 Londres.
   - IN6 só último dia útil: fade do movimento 12:00→15:55 Londres, entra 16:00, sai 17:00 Londres.
   (Fim de trimestre aparece só como recorte descritivo; poucos casos.)
3. COT da CFTC (relatório "Disaggregated", só futuros, ouro COMEX código 088691; dados de terça, publicados sexta 15:30 NY). Operação semanal: entra na reabertura de domingo 18:05 NY seguinte à publicação, sai sexta 16:45 NY (dorme 4 noites → paga/recebe swap). Sem stop.
   - IN7 contrário nos extremos dos gestores (Managed Money): líquido/open interest no percentil de 156 semanas; > 90 → venda; < 10 → compra; senão fora.
   - IN8 filtro direcional: segue a variação semanal do líquido dos Managed Money (subiu → compra; caiu → venda).
   - IN9 "dinheiro de banco" (Swap Dealers): líquido/OI no percentil de 156 semanas > 90 (bancos menos vendidos que o normal) → compra; < 10 → venda.
   - Vizinhos: percentis 80/20 e janela 104/260 semanas (IN7, IN9); IN8 com variação de 2 semanas.
   - Vizinhos fix/WMR: janelas deslocadas ±5 min (IN1–IN5) / ±30 min (IN6).
Total final: 37 + 9 = **46 tentativas**; BH e Bonferroni passam a ser sobre **46**. Critérios de reprovação iguais (mín. 100 operações no IS; IN6 e COT-extremos: mín. 60 por terem poucos casos).


### 4. Estatística
- PnL líquido por operação em US$/oz (0,01 lote = 1 oz). t unilateral (> 0) sobre o PnL **agregado por dia** no IS.
- **BH (q=0,05) e Bonferroni (α=0,05) sobre as 37.** Reporto também o limiar Bonferroni global do projeto (~2.317 tentativas → t ≈ 4,2).

### 5. Critérios de REPROVAÇÃO (qualquer um reprova)
1. IS líquido ≤ 0 com custo principal, ou não passa BH sobre 37.
2. Fator de lucro IS < 1,10. Menos de 100 operações no IS (ToM-B: 60).
3. Positivo em menos de 6 dos 9 anos do IS.
4. Tirando o melhor 1% das operações o IS fica ≤ 0, ou um único dia responde por > 10% do lucro IS.
5. Validação 2025 negativa ou PF < 1,05.
6. Fragilidade: vizinhos (MR: limiar ±, stop 1,5/2,5 ATR, saída 6/10 barras; SW: buffer 0/0,2 ATR, alvo 1,5/3R; FIX: janela ±5 min; CAL/SES: entrada/saída ±1h) — reprova se menos de 2/3 dos vizinhos ficam positivos no IS.
7. Inviável para conta pequena: risco por operação com 0,01 lote (stop em US$/oz) deve ser informado; se precisar de > US$ 50 de risco mínimo por operação, marco como "só para conta ≥ US$ 5.000 a 1%".
- Quem passar tudo: abre 2026 uma vez; se positivo → EA mínimo MQL5, teste no Strategy Tester da demo (OHLC 1 minuto em 2016–2026 + ticks reais de 30/10/2026 a 13/11/2026). Nunca conta real.

### 6. Log de tentativas
- T1: este pré-registro (37 variantes), rodado uma vez às ~01:25.
- T1b: família INST (9 variantes) escrita depois que as 37 primeiras já tinham rodado (vi os números delas), mas **antes** de qualquer número da INST. As regras da INST não dependem dos resultados vistos. A correção múltipla é feita sobre as 46.

---

## Parte 2 — RESULTADOS (15/11/2026 ~01:40 horário de Brasília)
Código: `code/ouro/` (core.py, strats.py, sweep.py, inst.py, run.py). Saídas: `out/ouro/summary.csv`, `out/ouro/sweep_path.csv`, `out/ouro/trades.pkl`. COT: `data/cot/gold_cot.csv` (CFTC, 2006–03/11/2026).
Valores em **US$ por onça por operação** (= US$ por operação com 0,01 lote), 2016–2024, custo principal (spread real + US$ 16,80/lote).

### Resposta curta
**Nenhuma das 46 tentativas sobreviveu.** 0 de 46 passam BH, 0 passam Bonferroni, e só 4 ficam sequer positivas no IS (todas com t < 1,2). Não abri 2026, não escrevi EA. Resultado nulo, registrado.

### Tabela (IS 2016–2024 | validação 2025)
| Família | Variante | Operações IS | Média IS | PF | t | Anos + (de 9) | 2025 média |
|---|---|---|---|---|---|---|---|
| MR reversão H1/H4 | MR1–MR4, LS e LO, filtros de volatilidade (10) | 712–5.658 | −0,37 a −0,62 | 0,73–0,84 | −1,7 a −5,7 | 0–3 | −2,5 a +0,7 |
| FIX LBMA 20 min | FX1–FX4 | 2.322 | −0,34 a −0,65 | 0,32–0,75 | −4,7 a −18 | 0–1 | −2,0 a +0,3 |
| Pós-PM-fix fade/segue | FX5, FX6 | 2.322 | −0,57 / −0,45 | 0,72 / 0,77 | −5,3 / −4,2 | 0–1 | negativo |
| Sessões | SE1 compra Ásia+Londres | 2.316 | −0,14 | 0,96 | −0,7 | 2 | +3,3 |
| | SE2 venda NY | 2.244 | −0,52 | 0,88 | −2,1 | 0 | −2,7 |
| Dia da semana (compra intradiária) | seg / ter / qua / qui / sex | ~450 cada | −1,68 / −0,09 / −0,47 / **+0,35** / **+0,48** | 0,72–1,09 | −2,3 a +0,6 | 1 / 4 / 5 / 3 / 6 | variado |
| Virada do mês | ToM-A intradiária | 511 | +0,24 | 1,04 | 0,37 | 4 | +8,8 |
| | ToM-B segurando (com swap) | 98 | +3,64 | 1,35 | 1,11 | 5 | (já visto) |
| Sweep PD (dia anterior) | M5/M15 × alvo 2R / 4h | 1.581–1.688 | −0,35 a −0,45 | 0,63–0,76 | −3,3 a −6,8 | 0–2 | negativo |
| Sweep PW (semana anterior) | idem | 662–748 | −0,29 a −0,65 | 0,48–0,82 | −1,3 a −7,2 | 0–3 | negativo |
| Sweep topos/fundos iguais | idem | 1.037–1.059 | −0,52 a −0,57 | 0,43–0,61 | −4,9 a −10,3 | 0 | negativo |
| INST fix AM fade/segue, drift PM | IN1–IN3 | 2.321 | −0,44 a −0,51 | 0,54–0,76 | −4,5 a −10 | 0–1 | negativo |
| INST fim de mês WMR 16h | IN4 compra / IN5 venda | 426 | −0,37 / −0,63 | 0,72 / 0,57 | −2,3 / −3,9 | 1 / 0 | +0,4 / −1,9 |
| INST último dia fade | IN6 | 108 | −1,21 | 0,36 | −3,4 | 1 | +5,0 (12) |
| INST COT | IN7 extremo gestores (contra) / IN8 segue variação / IN9 bancos | 143 / 470 / 182 | −1,47 / −3,43 / −0,72 | 0,89 / 0,75 / 0,95 | −0,5 / −2,2 / −0,3 | 2 / 1 / 6 | negativo |

Com comissão de US$ 8 (o que o testador da demo cobra), tudo melhora só US$ 0,09/oz: **continua negativo** em todas, exceto as mesmas 4. Com comissão zero (pagando só o spread), só SE1 (+0,03) e DW2 (+0,08) viram levemente positivas, sem significância.

### Critérios de reprovação
| Critério | Resultado |
|---|---|
| 1. IS positivo e passa BH (46) | **0/46 passam BH; 0/46 Bonferroni.** Só 4 positivas: DW4 (t 0,48), DW5 (0,62), ToM-A (0,37), ToM-B (1,11) |
| 2. PF ≥ 1,10 | Só ToM-B (1,35, mas 98 operações e t 1,1) |
| 3. ≥ 6/9 anos positivos | Só DW5 (6/9), sem significância |
| 4. Tirar o melhor 1% | DW4, DW5, ToM-A ficam **negativos** sem o 1% melhor; ToM-B fica positivo, mas é a lista de observação antiga, já vista |
| 5–7 | Não se aplicam: ninguém passou 1–3. 2026 não foi aberto |
Limiar global do projeto (~2.326 tentativas): t ≈ 4,2. O melhor desta rodada foi t 1,1.

### O que o sweep de liquidez faz de verdade (estudo do caminho, 2016–2024)
Depois de o preço passar da máxima/mínima do dia anterior, da semana anterior ou de topos/fundos iguais e **fechar de volta pra dentro**:
- **Taxa de reversão em 1h: 47–51%** (controle "qualquer topo de 12 barras": 51–52%). É cara ou coroa.
- Andou a favor e contra quase igual: MFE ≈ MAE (ex.: PD M15 em 4h: 2,30 vs 2,44 ATR).
- **O nível nomeado não acrescenta nada** em relação a um topo/fundo qualquer (diferença t entre −2,6 e +0,9; os sinais mais fortes são **contra** a ideia: topos/fundos iguais no M5 continuam mais do que revertem até o fim do dia, t −2,6).
- Como trade (stop além do pavio, alvo 2R ou 4h): perde em todas as 12, de −0,29 a −0,65 US$/oz, PF 0,43–0,82. O stop fica curto (mediana US$ 0,8–1,6/oz) e o custo (~US$ 0,45/oz) come 30–50% do risco. Mesmo sem comissão continua negativo.
Isso confirma o que MERCADO.md e o SMC já tinham mostrado, agora também para a **semana anterior** e topos/fundos iguais, com 9 anos.

### O que mais aprendemos
- **Fix de Londres:** existe um movimento bruto pequeno (ex.: vender 10:15→10:35 rende ~+0,12/oz antes do custo), mas o custo (~0,45/oz) é 4× maior. Não dá para operar.
- **Fim de mês / WMR:** nenhum padrão de compra ou venda às 16h de Londres que sobreviva.
- **COT:** posição extrema dos fundos ou dos bancos **não** previu a semana seguinte do ouro (t −0,5 e −0,3). Seguir a variação dos fundos perdeu (t −2,2). Ainda paga swap.
- **Reversão H1/H4:** perde em todos os formatos (0–3 anos positivos de 9); filtro de volatilidade não ajuda.
- **Segunda-feira foi o pior dia para comprar ouro** (−1,68/oz, t −2,3); quinta e sexta levemente positivas, mas do tamanho do ruído.
- **Virada do mês segurando (ToM-B)** segue como **curiosidade**: PF 1,35, mas t 1,1 em 98 casos e já tinha sido vista antes. Não é robô.

### Viabilidade em conta pequena
Irrelevante, pois nada passou. Só para registro: os sweeps arriscam US$ 0,8–1,6 por operação com 0,01 lote (cabe numa conta de US$ 100–500); as janelas de horário sem stop tiveram pior 1% de −US$ 5 a −33 por 0,01 lote; COT/ToM (semana inteira) até −US$ 90 por 0,01 lote.

### Veredito
Em XAUUSD, nesta rodada, **nada tem vantagem depois do custo**. Somando o projeto: ~2.326 tentativas, e o ouro intradiário (M1 até H4) se comporta como passeio aleatório com custo. As únicas coisas positivas no ouro são lentas e fracas (virada do mês, quinta/sexta) e não passam na estatística. Não foi feito EA nem teste no MT5, porque o pré-registro só permitia isso para sobreviventes.

### O que continua desconhecido
- Dados de book/volume real (futuros COMEX) — não temos.
- Execução real abaixo do spread Dukascopy (o spread da ECN pode ser menor). Mas como até sem comissão quase tudo segue negativo, custo menor não salva.
- 2026 continua inédito para estas 46 regras.
