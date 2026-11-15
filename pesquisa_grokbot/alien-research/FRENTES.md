# ALIEN — Pré-registro das 3 frentes (escrito em 15/11/2026, ANTES de rodar qualquer teste destas frentes)

Objetivo: achar algo com "lucro que não devolve" (curva subindo, drawdown pequeno, sem quebrar).
Este arquivo fixa as regras, as variantes e os critérios de reprovação antes de ver resultado.
Qualquer mudança depois do resultado vira nova tentativa e entra no log de tentativas (seção 5).

**Aviso de honestidade sobre dados já vistos:** na V2 (RESULTS_V2.md) já foram testadas algumas regras de tendência no ouro
(Donchian 20/55, médias 20/100 e 50/200, TSMOM 60/120/250 dias) com custos e divisão diferentes. Elas deram mediana levemente
positiva no IS e negativa em 2026. Ou seja, 2026 **já foi espiado** para tendência no ouro em regras parecidas. Por isso
2026 não é 100% inédito para a Frente 1. A validação principal desta rodada passa a ser **2025**, e 2026 é só confirmação.

## 0. Divisão e dados
- IS (desenvolvimento): 01/01/2016 → 31/12/2024. Validação: 2025. Retido: 01/01/2026 → 13/11/2026, olhado **uma vez** no fim, só para sobreviventes.
- Frente 1: XAUUSD H1 bid/ask Dukascopy reamostrado para H4/D1 (fechamento 17:00 NY = 00:00 do servidor).
- Frente 2: XAUUSD M1 bid/ask Dukascopy 2016–2026.
- Calendário de notícias (fontes públicas):
  - CPI e Payroll (NFP): datas de divulgação tiradas dos nomes dos arquivos do arquivo oficial do BLS
    (https://www.bls.gov/bls/news-release/cpi.htm e .../empsit.htm, cópia do web.archive.org). Hora 08:30 NY.
  - FOMC: comunicados das reuniões agendadas no site do Fed (fomchistorical2016–2020 e fomccalendars). Hora 14:00 NY.
    Excluídos comunicados extraordinários (03/03/2020, 15/03/2020, 23/03/2020, 31/03/2020, 11/10/2019, 27/08/2020, 22/08/2025).

## 1. Custos (RoboForex-ECN, conservadores)
- Spread: spread real Dukascopy, com piso de US$ 0,25. Slippage de US$ 0,05 por lado.
- Comissão: **US$ 16,80 por lote ida e volta** (1 lote = 100 oz → US$ 0,168 por oz).
- Swap (Frente 1): constante sobre o nocional, por dia corrido: **compra −8%/ano, venda −2%/ano** (conservador; nos anos de juros baixos
  2016–2021 o swap real foi menor). Sensibilidade com −4%/−1% só como informação, não para escolher.
- Frente 2 (notícias): nos primeiros 5 minutos após a divulgação, spread = **máx(spread real, 4× o normal = US$ 1,00)** e slippage
  extra de US$ 0,30 por lado em ordens a mercado ou stop. Ordens stop de straddle enchem no pior entre o preço do stop e
  (stop + 20% do range da vela de 1 minuto da notícia), mais o slippage.

## 2. Frente 1 — Tendência no ouro (H4/D1)
Tamanho: **volatilidade-alvo de 10% ao ano** (nocional = capital × 10% / vol realizada de 60 dias D1, teto de 3× alavancagem).
Rebalanceia só no fechamento D1 e só se o tamanho alvo mudar mais de 25% (para não pagar custo à toa).
Stop de ATR só nas famílias de rompimento e médias (abaixo). Sem alvo: lucro corre.

| ID | Regra | Saída |
|---|---|---|
| T1–T4 | TSMOM: sinal = sinal do retorno de 21, 63, 126, 252 dias (1, 3, 6, 12 meses) | inverte/zera quando o sinal muda |
| T5 | TSMOM conjunto: média dos 4 sinais acima (posição de −1 a +1) | contínua |
| T6 | Donchian D1 20 (rompe máxima/mínima de 20 dias) | canal oposto de 10 dias ou stop 2 ATR(20) |
| T7 | Donchian D1 55 | canal oposto de 20 dias ou stop 2 ATR(20) |
| T8 | Donchian H4 20 | canal oposto de 10 barras ou stop 2 ATR(20) H4 |
| T9 | Donchian H4 55 | canal oposto de 20 barras ou stop 2 ATR(20) H4 |
| T10 | Médias D1 50/200 | cruzamento contrário ou stop móvel 3 ATR(20) |
| T11 | Médias D1 20/100 | idem |
| T12 | Médias H4 50/200 | idem (ATR H4) |
Cada uma em duas versões: **compra e venda (LS)** e **só compra (LO)** = 24 tentativas.
Referência (não é tentativa): comprar e segurar ouro com o mesmo tamanho por volatilidade. Serve para ver se a regra
acrescenta algo ou só pega a alta do ouro ("beta").

## 3. Frente 2 — Ouro nas notícias (CPI, NFP, FOMC)
T = minuto da divulgação (08:30 ou 14:00 NY). Faixa pré-notícia = máxima/mínima de T−15 a T−1. Risco de 0,5% por trade.
| ID | Regra | Saída |
|---|---|---|
| N1 | **Rompimento depois do 1º minuto:** direção = cor da vela de 1 min da notícia; entra a mercado no início de T+2 | sai em T+30 (N1a) ou T+60 (N1b); stop = 1× range da vela da notícia |
| N2 | **Fade (devolução):** se o movimento de T até o fechamento de T+4 for > 1× ATR(14) de 15 min pré-notícia, entra contra em T+5 | sai em T+30 (N2a) ou T+60 (N2b); stop além do extremo de T..T+4 + US$ 0,50 |
| N3 | **Straddle (OCO):** ordens stop na faixa pré-notícia ± 0,2× a altura da faixa, colocadas em T−1, canceladas em T+10 | sai em T+30 (N3a) ou T+60 (N3b); stop = lado oposto da faixa |
Cada variante é testada no conjunto (CPI+NFP+FOMC juntos) e em cada evento separado = 6 × 4 = **24 tentativas**.

## 4. Critérios (pré-definidos)
Uma regra é **sobrevivente** só se passar em TODOS:
1. IS 2016–2024 positivo **depois dos custos**, com t ≥ 2 (retornos diários para a Frente 1, por trade na Frente 2).
2. Passa **Benjamini-Hochberg (FDR 10%)** sobre as 48 tentativas desta rodada (p unilateral). Bonferroni reportado também.
3. Pelo menos 6 dos 9 anos do IS positivos.
4. Continua positiva ao **tirar o 1% melhor dos trades** (ou dos dias, na Frente 1).
5. Mínimo de 30 trades no IS (60 na Frente 2).
6. **Não é frágil:** as vizinhas da mesma família (outros lookbacks/canais/saídas) também ficam positivas no IS em maioria.
7. Validação 2025 positiva.
8. Drawdown máximo IS ≤ 20% no tamanho pré-definido.
Para a Frente 1, se a versão LS falhar e só a LO passar, ela também tem de bater a referência de comprar e segurar
(senão é só "beta do ouro", não vantagem). 2026 é olhado uma única vez para os sobreviventes e reportado como está.

## 5. Frente 3 — Carteira
Junta os sobreviventes das frentes 1 e 2 com a cesta de índices RSI2/IBS (6 fluxos, 1% de risco, custos RoboForex, já validada na V2).
Reporta: CAGR, DD máximo, pior mês, pior ano, % de meses positivos e correlação diária entre as partes. Pesos fixos
pré-definidos: risco igual (mesma volatilidade anual de cada parte). Sem otimizar pesos.
Se nada sobreviver nas frentes 1 e 2, a carteira é só a cesta de índices, e eu digo isso.

## 6. Se houver sobrevivente
EA mínimo em MQL5 e teste no MT5 do box (demo RoboForex-ECN, só Strategy Tester). Para H4/D1, modelagem "OHLC de 1 minuto" em
período longo é aceitável (ticks reais só existem a partir de 30/10/2026 no servidor).

## 7. Log de tentativas
Ver `out/frentes/attempts.csv` (preenchido pelo código, todas as 48 tentativas, inclusive as que falharam).

---

# RESULTADOS (rodados depois do pré-registro acima, 15/11/2026)

## Resumo em uma frase
**Nenhuma das 48 tentativas sobreviveu.** Tendência no ouro (H4/D1) e operar notícias (CPI, Payroll, FOMC) não deram vantagem
depois dos custos. O único robô que continua de pé é a cesta de índices RSI2/IBS. Não escrevi EA novo, porque não há regra
aprovada para levar ao MT5. 2026 **não foi aberto** para estas regras (só seria aberto para sobreviventes).

## Frente 1 — Tendência no ouro (24 tentativas)
Custos usados para decidir: spread Dukascopy (mín. US$ 0,25) + slippage + comissão US$ 16,80/lote + swap de compra −8% e de venda −2% ao ano.
**Swap real da sua demo RoboForex-ECN (lido no MT5 em 12/11/2026):** compra −60 pontos/dia (≈ −US$ 0,60/oz ≈ −5,5% ao ano),
venda +19 pontos/dia (≈ +1,7% ao ano, você recebe). Rodei também com esse swap só para informação (última coluna).

| Regra | CAGR IS 2016–24 | DD máx IS | PF | t | trades/mês | anos + | 2025 | CAGR IS com swap real de hoje |
|---|---|---|---|---|---|---|---|---|
| T1LS TSMOM 1m | -6.4% | 51% | 0.67 | -1.71 | 2.1 | 2/9 | +16.2% | -4.2% |
| T1LO | -0.5% | 23% | 1.00 | -0.06 | 1.1 | 3/9 | +25.4% | +0.5% |
| T2LS TSMOM 3m | -0.5% | 30% | 1.03 | 0.02 | 0.8 | 5/9 | +18.6% | +1.8% |
| T2LO | +2.3% | 20% | 1.78 | 0.89 | 0.4 | 6/9 | +26.7% | +3.6% |
| T3LS TSMOM 6m | -1.7% | 33% | 1.46 | -0.31 | 0.7 | 3/9 | +34.3% | +0.5% |
| T3LO | +1.2% | 22% | 2.75 | 0.55 | 0.3 | 5/9 | +34.3% | +2.6% |
| T4LS TSMOM 12m | -3.6% | 46% | 1.12 | -0.91 | 0.6 | 3/9 | +36.7% | -1.4% |
| T4LO | -0.2% | 29% | 2.11 | 0.07 | 0.3 | 5/9 | +36.7% | +1.2% |
| T5LS TSMOM conjunto | -1.6% | 27% | 0.75 | -0.47 | 1.1 | 3/9 | +25.9% | -0.3% |
| T5LO | -0.4% | 21% | 0.95 | -0.04 | 0.6 | 3/9 | +25.9% | +0.4% |
| T6LS Donchian D1 20 | -2.9% | 29% | 0.74 | -0.82 | 0.7 | 3/9 | +6.4% | -1.3% |
| T6LO | +1.3% | 17% | 1.39 | 0.65 | 0.4 | 5/9 | +11.9% | +2.1% |
| T7LS Donchian D1 55 | -1.6% | 25% | 0.77 | -0.46 | 0.3 | 5/9 | +27.5% | -0.4% |
| T7LO | +0.5% | 16% | 1.25 | 0.31 | 0.2 | 5/9 | +27.5% | +1.3% |
| T8LS Donchian H4 20 | +1.5% | 18% | 1.13 | 0.67 | 3.8 | 6/9 | +10.6% | +2.9% |
| T8LO | +1.6% | 15% | 1.22 | 0.87 | 2.1 | 5/9 | +16.8% | +2.3% |
| T9LS Donchian H4 55 | -0.4% | 21% | 1.00 | -0.04 | 2.1 | 5/9 | +10.2% | +0.8% |
| T9LO | +2.0% | 12% | 1.39 | 1.08 | 1.2 | 6/9 | +20.9% | +2.6% |
| T10LS Médias D1 50/200 | -0.1% | 10% | 0.94 | -0.03 | 0.1 | 3/9 | 0.0% | +0.2% |
| T10LO | -0.3% | 9% | 0.56 | -0.28 | 0.1 | 3/9 | 0.0% | -0.2% |
| T11LS Médias D1 20/100 | -0.3% | 17% | 1.02 | -0.08 | 0.2 | 4/9 | 0.0% | +0.3% |
| T11LO | +0.5% | 11% | 1.39 | 0.37 | 0.1 | 4/9 | 0.0% | +0.8% |
| T12LS Médias H4 50/200 | +0.2% | 13% | 1.08 | 0.26 | 0.8 | 5/9 | -2.0% | +0.6% |
| T12LO | +0.9% | 6% | 1.57 | 0.99 | 0.4 | 6/9 | +0.8% | +1.1% |

**Referência: comprar e segurar ouro com o mesmo tamanho (10% de vol):** CAGR IS +2,0% (DD 26%) com swap conservador,
+4,3% com o swap real de hoje, +8,8% sem swap. 2025: +36%.

O que isso quer dizer, em português simples:
- **O melhor t foi 1,08 (T9LO).** Precisava de 2 e de passar no BH. Nenhuma passou. Bonferroni: nenhuma.
- **As versões que vendem (LS) perdem quase sempre.** O ouro subiu de US$ 1.060 para ~US$ 4.000 em 10 anos. Vender contra isso custou caro.
- **As versões só de compra (LO) não ganharam nem do "comprar e segurar".** Ou seja, a regra de tendência não acrescentou
  nada além da alta do próprio ouro. Isso é "beta", não vantagem (critério da seção 4).
- **O swap é o grande vilão da tendência no ouro:** segurar ouro comprado custa ~5,5% ao ano do valor da posição hoje.
  Sem swap, até comprar e segurar daria ~9% ao ano. Esse custo não aparece em backtest de YouTube.
- 2025 foi ótimo para quase todas (o ouro subiu muito), mas um ano bom não salva 9 anos fracos.
- Observação honesta: as regras de médias (T10–T12) ficaram fora do mercado em 2025 porque, depois de um stop, só
  reentram num novo cruzamento. É assim que eu pré-registrei. Mudar isso agora seria uma tentativa nova escolhida olhando o resultado.

## Frente 2 — Ouro nas notícias (24 tentativas, 345 eventos de 2016 a 11/2026)
Eventos: 129 CPI, 131 Payroll, 85 FOMC (datas oficiais BLS/Fed). Custos de notícia: spread mínimo de US$ 1,00 e slippage extra de US$ 0,30 nos 5 primeiros minutos.

| Variante (CPI+NFP+FOMC) | trades IS | resultado médio IS | PF | t | anos + | 2025 |
|---|---|---|---|---|---|---|
| N1a rompimento 1º min, sai em 30 min | 283 | −0,33R | 0,40 | −6,1 | 1/9 | −10,0R |
| N1b idem, sai em 60 min | 283 | −0,34R | 0,48 | −5,3 | 0/9 | −13,7R |
| N2a devolução (fade), 30 min | 208 | −0,27R | 0,63 | −2,6 | 1/9 | −4,7R |
| N2b fade, 60 min | 208 | −0,27R | 0,68 | −2,0 | 1/9 | +0,3R |
| N3a straddle OCO, 30 min | 278 | −0,28R | 0,56 | −4,1 | 1/9 | −4,9R |
| N3b straddle, 60 min | 278 | −0,30R | 0,56 | −4,1 | 1/9 | −5,3R |
Separado por evento (CPI, NFP, FOMC): todas as 18 negativas no IS. Detalhe em `out/frentes/news_summary.csv`.

- **Perde até sem custo nenhum** (teste de diagnóstico, não conta como tentativa): de −0,07R a −0,14R por trade.
  Ou seja, não é só a corretora. Na média, o primeiro minuto da notícia não diz para onde o ouro vai nos 30–60 minutos seguintes.
- Com 0,5% de risco por trade, o rompimento N1 perderia ~1,6% da conta por ano. Na notícia, o spread alarga, a ordem escorrega
  e o preço chicoteia para os dois lados.

## Frente 3 — Carteira
Como nada sobreviveu nas frentes 1 e 2, **a carteira é só a cesta de índices** (RSI2 + IBS em US500, US Tech e DE40, 1% de risco, custos RoboForex):

| Métrica (01/2016 → 13/11/2026) | Valor |
|---|---|
| CAGR | **6,2% ao ano** |
| DD máximo (no fechamento dos trades) | 6,1% (marcado a mercado diário: 6,9%, da V2) |
| Pior mês | −4,6% |
| Pior ano | +0,3% (2016). **Todos os anos positivos** |
| Meses positivos | 71% |
| PF / acerto | 1,59 / 71% |
| Trades | 1.188, ~9 por mês somando os 6 fluxos |
| Anos | 2016 +0,3% · 2017 +11,5% · 2018 +1,0% · 2019 +7,6% · 2020 +3,6% · 2021 +9,9% · 2022 +1,7% · 2023 +5,9% · 2024 +15,5% · 2025 +9,1% · 2026 (até 13/11) +2,8% |

Correlação diária entre a cesta e as regras de tendência no ouro: de −0,02 a +0,03 (praticamente zero). Juntar as duas
diversificaria **se** a do ouro tivesse vantagem própria. Hoje ela não tem, então juntar só adicionaria custo de swap.

## O que continua desconhecido
- Notícias com dados de tick reais (o M1 pode errar o preço exato de execução nos primeiros segundos). Como a regra perde até sem custo, é improvável que isso mude o veredito.
- Swap histórico real (usei constante). Mesmo com o swap de hoje, nada chegou perto de t = 2.
- Tendência em uma cesta grande de mercados (o efeito publicado é de carteira com dezenas de ativos, não de um ativo só).

Arquivos: `code/frentes/trend.py`, `code/frentes/news.py`, `code/frentes/attempts_port.py`, `out/frentes/attempts.csv` (48 tentativas, BH, Bonferroni), `data/news/` (datas).
