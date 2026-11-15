# ALIEN — Pesquisa quantitativa do zero no XAUUSD (14/11/2026)

**Veredito direto: nada sobreviveu.** Testei 773 configurações de setup (sweep, FVG, rompimento + reteste, faixa asiática, ORB, momentum de sessão, Bollinger, CHoCH/OB, horário do dia), com stops curtos e custos realistas. Nenhuma mostrou vantagem real e repetível depois dos custos. **Não há robô aprovado para a Goat.** Abaixo está o que testei, os números e o que isso significa.

---

## 1. Dados
- **Fonte:** Dukascopy, XAUUSD **M1 bid e ask separados** (baixado com `npx dukascopy-node`). Período: **02/01/2023 → 13/11/2026** (1.700.608 barras M1). Arquivo: `data/xau_m1_bidask.parquet`.
- Spread real da Dukascopy (mediana): 0,34 (2023), 0,39 (2024), 0,61 (2025), **0,71 (2026)** US$. É mais largo que o de uma ECN típica.
- **Volatilidade explodiu:** ATR(M15) mediano de **US$ 1,54 em 2023 → US$ 7,82 em 2026**.
- **Divisão:** dentro da amostra (IS) = 2023–2025; fora da amostra (OOS) = **01/01/2026 → 13/11/2026** (10,5 meses, nunca usados pra escolher nada).

## 2. Motor de backtest (`code/engine.py`)
- Sinais só com velas fechadas (sem olhar o futuro). Compra entra no **ask** e sai no **bid**. Venda, o contrário.
- **Custos:** comissão de US$ 7/lote ida e volta (0,07/oz) + slippage de 0,05 nas entradas a mercado e stop e nas saídas por stop. Gap através do stop sai no preço de abertura (o mesmo problema da issue #17).
- **Cenários de spread:** **B (principal)** = metade do spread Dukascopy, mínimo 0,20, parecido com ECN. **A (estresse)** = spread Dukascopy cheio. **Z** = sem nenhum custo (só pra diagnóstico).
- **Stop e alvo na mesma vela M1:** conta o stop primeiro (conservador). Na vela em que a ordem é executada, só o stop vale.
- **Fuso:** sessões em horário de Nova York com horário de verão (servidor GMT+2/+3 = NY+7). **Zera tudo às 16:50 NY** (23:50 no servidor) todo dia e antes do fim de semana. Não entra ordem entre 16:50 e 18:00 NY.
- **Restrição da conta:** 0,25% de US$ 5.000 = US$ 12,50, e o lote mínimo de 0,01 é 1 oz. Então **o stop precisa ser ≤ US$ 12/oz**. Trade com stop maior é descartado. Também rodei uma versão "sem limite" (`B_nocap`) só pra ver se existe vantagem com stop largo.
- Teste de sanidade: entrada aleatória sem custos deu ≈ −0,015R (o viés de contar o stop primeiro é pequeno). **Com custos B, a entrada aleatória dá −0,14R por trade.** Esse é o "pedágio" do stop curto: o custo de ~0,43 US$/oz contra um stop mediano de ~US$ 3,9.

## 3. O que foi testado (grade definida antes de ver os resultados)
| Família | Configs |
|---|---|
| F1 Sweep de liquidez + rejeição (M5/M15, lookback 12/24/48, sessões, RR 1,5–4) | 96 |
| F2 FVG reteste (M5/M15, tamanho do gap, entrada borda/meio, stop no gap/vela 1, filtro EMA50, sessões, RR) | 256 |
| F3 Rompimento + reteste (limite no nível rompido) | 64 |
| F4 Faixa asiática 19h–02h NY: rompimento (stop no meio/lado oposto/¼) e fade após sweep | 35 |
| F5 ORB Londres 03:00 / NY 09:30 (15/30/60 min) | 60 |
| F6 Momentum ou fade de sessão (movimento desde 03:00 NY, decisão às 08:00–11:00) | 96 |
| F7 Bollinger: volta pra dentro da banda (alvo na média ou RR) | 54 |
| F8 Sweep → CHoCH → entrada no reteste (tipo OB) | 64 |
| F9 Horário do dia (compra na reabertura asiática, venda às 09:00/09:30 NY) | 30 + 18 extras |
| **Total** | **773 configs**, ~3.070 backtests somando os 4 cenários de custo |

Com 773 testes, o acaso sozinho já produz um |t| máximo de ~3,6. Qualquer coisa abaixo disso é indistinguível de sorte.

## 4. Resultados
**Cenário B (custos realistas), 755 configs da grade:**
- Só **33** têm expectativa positiva no IS, e a melhor é de **+0,06R**. Só **3** são positivas no IS e no OOS ao mesmo tempo (com n ≥ 50 no OOS).
- **A correlação entre o resultado no IS e no OOS é de 0,006.** Ou seja, ir bem no passado não diz nada sobre o futuro. É ruído.
- **Walk-forward** (a cada 6 meses, escolhe as 5 melhores dos 24 meses anteriores e opera os 6 meses seguintes): **−0,116R por trade** em 582 trades. O próprio processo de "escolher o melhor setup" perde dinheiro.
- Mediana de PF no cenário B: FVG M15 ≈ 0,80 IS / 0,89 OOS; Sweep M5 ≈ 0,75 / 0,90. Isso confirma os testes anteriores no MT5 (0,94 e 0,84).
- **Cenário A (spread cheio): nenhuma** config fica positiva no IS e no OOS.
- **Mesmo sem nenhum custo (Z),** o melhor t-stat é de 2,77, abaixo dos 3,6 que o acaso já gera. Não existe uma vantagem bruta clara pra ser "salva" com custo menor.

### Os "menos ruins" (lista de observação, NÃO aprovados)
| # | Setup | IS (B) | OOS 2026 (B) | Observação |
|---|---|---|---|---|
| C1 | Rompimento da faixa asiática, stop no lado oposto, RR 1–1,5 | n 357, PF 1,11–1,13, +0,05–0,06R, DD 10R, pior sequência 8 | **0 trades** (a faixa de 2026 passa de US$ 12) | 2025 negativo (−0,14R). Sem limite de stop: OOS n 194, PF 1,25–1,34, +0,07–0,09R, t total 1,8, **não significativo**. Precisa de stop de US$ 20–50, que não cabe nos 0,25% |
| C2 | ORB NY 60 min, stop no lado oposto, RR 1 | n 379, PF 1,12, +0,035R | 5 trades (inútil) | Sem limite de stop: OOS PF 1,17, +0,05R |
| C3 | Momentum 09:30 NY (movimento desde Londres > 2×ATR15), stop 1 ATR, RR 2 | n 376, PF 1,04, +0,02R, pior sequência 13 | n 73, PF 1,27, +0,16R | Com spread cheio, IS −0,01R. A variante RR 3 virou ~0 no OOS. É o mais parecido com sorte |

**Horário do dia:** a hora da reabertura (18h NY / 01h servidor) subiu em todos os 4 anos (+3,6 pontos-base em média, t 3,6), e a hora das 09h NY caiu em todos. É um padrão real, mas pequeno. **Sem custos dá +0,10 a +0,20R por trade. Com custos B fica em ~0, e com o spread cheio, negativo.** O spread da reabertura come tudo. E isso também depende de o ouro continuar em alta.

## 5. Simulação Goat (2-Step 1% Floating, US$ 5.000)
Regras usadas (FAQ da Goat, atualizado em 12/11/2026): Fase 1 com meta de 8%, Fase 2 com 6%, perda diária de 4%, perda máxima de 10% estática, **perda flutuante combinada de 1% (US$ 50) = conta encerrada**, mínimo de 3 dias com lucro ≥ 0,5%. O lote é arredondado pra baixo em 0,01 com risco de US$ 12,50, e cada simulação começa no início de um mês (40 inícios, de fev/2023 a mai/2026).
- **Top-7 por IS: 0% de aprovação na Fase 1, mesmo com até 3 anos de operação.** O FVG M15 RR4 passou a Fase 1 em 12,5% dos inícios, levando ~400 dias. Nenhum passou as duas fases.
- Não houve estouro da regra de 1% flutuante nem da diária, porque com 1 posição e risco ≤ US$ 12,50 isso só acontece com gap. O pior trade foi de **−3,1R (B) / −4,35R (A)**, por gaps em feriado mesmo zerando às 16:50 NY.
- **A conta que mata:** 8% a 0,25% por trade = **32R líquidos**. Com +0,05R por trade, são ~640 trades. Pra passar em 1–2 meses seria preciso algo como **+0,2R por trade com 150–200 trades**, e nada chegou nem perto disso depois dos custos.

## 6. Veredito e o que isso significa
1. **Nada mostrou vantagem real.** Os números positivos ficam dentro do que o acaso produz em 773 tentativas, e o walk-forward perde.
2. **O inimigo principal é o custo contra o stop curto.** No ouro de 2026 (ATR M15 de ~US$ 8), um stop de US$ 3–5 fica dentro do ruído, e o custo (~US$ 0,43/oz) leva 10–15% do risco em todo trade.
3. **A combinação da conta é estruturalmente difícil para o ouro:** lote mínimo de 1 oz, risco de US$ 12,50 e trava flutuante de US$ 50. Os únicos setups com algum sinal (faixa asiática, ORB 60) precisam de stops de US$ 20–50, que essa conta não permite.
4. **Recomendação:** não operar a Goat com nenhum desses setups. Caminhos honestos: (a) testar instrumentos com tick menor por lote mínimo (EURUSD, GBPUSD, índices), onde 0,01 lote permite stop técnico dentro de US$ 12,50; (b) conta maior ou risco maior por trade, se a mesa permitir, pra caber o stop da faixa asiática (C1) e retestar; (c) se insistir no ouro, só operar sinais com stop ≥ ~1 ATR(M15) e alvo ≥ 2R, e mesmo assim nada passou aqui.

## 7. Regras exatas dos candidatos (só pra teste em demo/Tester, NÃO aprovados)
Horários em NY (servidor = NY+7). Zera tudo às 16:50 NY. Uma posição por vez.
- **C1 Rompimento asiático:** faixa = máxima e mínima de 19:00–02:00 NY. Das 02:00 às 10:00 NY, a primeira ruptura vale: buy stop na máxima + 0,10 (ou sell stop na mínima − 0,10). SL no lado oposto da faixa, TP = 1,0R ou 1,5R. Saída por tempo após 8h. Pula o dia se o stop passar de US$ 12 (com 0,25% em US$ 5k, quase todos os dias de 2026 são pulados).
- **C2 ORB NY 60:** faixa de 09:30–10:30 NY. Das 10:30 às 13:30 NY, stop na ruptura (±0,10). SL no lado oposto, TP 1R. Saída por tempo após 6h.
- **C3 Momentum 09:30:** às 09:30 NY, se |preço − abertura das 03:00 NY| > 2×ATR(14, M15), entra a mercado na direção do movimento. SL = 1×ATR(M15), TP 2R, saída por tempo após 6h.

## 8. Reprodução
`./run_all.sh` (baixa os dados, roda as 4 grades, as extensões e as análises). Código em `code/`, resultados em `out/` (summary_*.csv, trades_*.parquet, wf_*.csv, goat_*.csv, f9ext.csv), hashes em `out/SHA256SUMS.txt`. Nada foi enviado ao GitHub.
