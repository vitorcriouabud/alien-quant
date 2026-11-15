# ALIEN — "Um tiro pra ganhar": trades de alvo alto (5R–10R+) com risco máximo de US$ 45
Pré-registro escrito em 15/11/2026, ANTES de rodar qualquer teste desta rodada. Mudança depois do resultado = tentativa nova (log no fim).

Pergunta: existe algum setup assimétrico (perde pouco muitas vezes, ganha 5–10R poucas vezes) em US500, NAS100, DE40 ou XAUUSD
com expectativa positiva depois dos custos? E qual a chance de bater a Fase 1 da Goat (+US$ 400) antes de quebrar
(−US$ 500 estático, US$ 50 flutuante somado, 4% diário) arriscando US$ 45 por trade?

## 0. Divisão e dados
- IS 01/01/2016 → 31/12/2024. Validação 2025. Retido 2026 (até 13/11), olhado **uma vez** e só para sobreviventes.
- Índices: Dukascopy **M5 bid** 2016–2026 (US500 = usa500idxusd, NAS100 = usatechidxusd, DE40 = deuidxeur), baixado nesta rodada.
  Para as regras diárias (família B/C), barras D1 montadas do H1 (fechamento 17:00 NY), caminho intradiário pelo H1 bid/ask.
- Ouro: Dukascopy M1 bid/ask 2016–2026 (`xau_m1_2016_2026.parquet`), reamostrado para M5/D1.
- **Aviso:** 2026 do ouro já foi espiado em regras parecidas (LITERATURA.md: VB2/Larry Williams, VO3; FRENTES/V2: Donchian). Para a família D,
  2026 não é inédito; a decisão é IS + 2025. ORB do ouro (Londres/NY) e faixa asiática já foram reprovados antes (RESULTS F4/F5, V2 C1) e **não** são repetidos.

## 1. Custos (Goat, conservadores)
- Índices: comissão 0; spread fixo = piso raw da Goat do GOAT.md (US500 0,6 pt, NAS100 2,0 pt, DE40 1,5 pt), **dobrado** nas barras de 09:30–09:35 NY
  (e 09:00–09:05 em Frankfurt para o DE40); slippage 0,1 / 0,5 / 0,5 pt por lado; ordens stop de entrada e stop de saída enchem no pior entre o preço
  da ordem e a abertura da barra (gap). Swap por noite (dias corridos): swaps reais RoboForex — compra −8,6%/ano (US500/NAS100), −7,2%/ano (DE40); venda −1,8%/ano.
  (Ajuste feito antes de qualquer resultado: o engine2 da V2 tinha o swap ~1000× pequeno por unidade de data; aqui uso código próprio
  com dias calculados certo, e a linha de base da cesta é re-simulada com swap corrigido.)
- Ouro: spread real bid/ask, comissão US$ 5/lote ida e volta (0,05/oz), slippage 0,05 por lado; swap compra −6%/ano, venda −1%/ano.
- Stop e alvo na mesma barra = conta o stop. US$ por ponto: US500/NAS100 1,0; DE40 1,12 (EURUSD aprox.); ouro 100 por lote (1 por oz).
- **1R = distância do stop + custo da ida e volta** (o que se perde de verdade num stop). Lote = US$ 45 / (1R × US$/pt), arredondado para baixo
  (passo 0,01; índices lote mínimo 0,1 — se não couber, o trade é pulado e contado).

## 2. Variantes (17 tentativas)
**A — Rompimento da faixa de abertura (ORB) em NY, US500 + NAS100 juntos, M5, intradiário (zera 15:55 NY, sem swap)**
Faixa = máxima/mínima de 09:30–10:00 NY (A4: 09:30–09:45). Ordens stop nos dois lados (a primeira que encher vale, a outra é cancelada),
válidas até 12:00 NY. Stop = lado oposto da faixa (A5: meio da faixa). Um trade por dia e símbolo.
- A1: alvo 5R, senão sai 15:55.  A2: alvo 10R, senão 15:55.  A3: sem alvo, sai 15:55 (corredor até o fechamento).
- A4: faixa de 15 min, alvo 10R, senão 15:55.  A5: faixa 30 min, stop no meio da faixa, alvo 10R, senão 15:55.
- A6: como A2, mas só depois de dia NR7 (o dia anterior teve o menor range de 7) — combinação clássica do Crabel.
- A7: DE40, faixa 09:00–09:30 Frankfurt, alvo 10R, senão 17:25 Frankfurt.
**B — Expansão de range diária (índices US500, NAS100, DE40 juntos, segura dias)**
Sinal no fechamento D1: range do dia ≥ 1,5×ATR(20) e fechamento no 20% superior (compra) ou inferior (venda) do dia. Entra na abertura D1 seguinte.
Stop = 1×ATR(20). Gap pelo stop sai na abertura.
- B1: alvo 5R, máximo 20 dias.  B2: sem alvo, stop móvel de 2×ATR (chandelier no fechamento), máximo 40 dias.  B3: B2 só compra.
**C — Cesta RSI2 dos índices com saída "corredor" (mesma entrada da cesta: RSI2 < 10, acima da SMA200, compra na abertura seguinte)**
- C1: stop 1×ATR, alvo 5R, máximo 20 dias.  C2: stop 1×ATR, sem alvo; depois de +2R o stop vai para o empate e passa a seguir 2×ATR; máximo 30 dias.
- C3: stop 0,5×ATR, alvo 10R, máximo 20 dias.
**D — Ouro, rompimento da máxima/mínima do dia anterior segurando o "dia grande"**
Dia = 18:00→16:45 NY. Ordem stop na máxima e na mínima do dia anterior (+/− 0,05), a partir das 03:00 NY, primeira que encher, até 12:00 NY.
Stop = 0,5×ATR(20) D1 da entrada.
- D1: alvo 5R, senão sai 16:45 NY.  D2: alvo 10R, senão 16:45.  D3: sem alvo, stop móvel 1×ATR no fechamento D1, máximo 5 dias (dorme posicionado).
- D4: D3 só compra.
Controle (não é tentativa): a mesma saída com entrada aleatória, para saber se o resultado vem da entrada ou só da forma da saída.

## 3. Critérios de sobrevivência (todos)
1. IS 2016–2024 positivo depois dos custos com t ≥ 2 (por trade, em R). 2. Passa BH (FDR 10%) nas 17 desta rodada (p unilateral).
Reporto também Bonferroni com o **total do projeto** (~2.347 + 17 = ~2.364 → precisa t ≈ 4,1); quem não passa nele fica marcado como "provável sorte".
3. ≥ 6 dos 9 anos IS positivos. 4. Positivo tirando o **1% melhor dos trades** (crítico aqui: estratégia de cauda vive dos raros trades grandes).
5. ≥ 100 trades no IS. 6. Vizinhas da mesma família positivas na maioria. 7. 2025 positivo.
8. **Regra Goat:** o flutuante pior de cada trade (pior preço da barra, incluindo gap) não pode passar de US$ 50 em mais de 1% dos trades.

## 4. Métricas e Monte Carlo
Por variante: trades, acerto, ganho médio em R, expectativa (R e US$ a US$ 45), PF, t, anos +, 2025, dependência do 1% melhor
(% do lucro e expectativa sem eles), maior sequência de perdas, % de trades com flutuante > US$ 50.
**Monte Carlo Goat Fase 1** (20.000 caminhos, sorteio com reposição dos trades IS+2025, na ordem de dias de calendário reais da estratégia):
US$ 45 por trade, uma posição por vez. Passa = saldo ≥ +US$ 400 **e** 3 dias com lucro ≥ US$ 25. Quebra = saldo ≤ −US$ 500,
ou flutuante do trade ≤ −US$ 50, ou perda no dia ≤ −US$ 200. Reporto P(passa antes de quebrar), P(passa em 3/6/12 meses) e mediana de dias.
Também reporto a versão histórica (inícios mensais reais 2016–2025). Comparo com a cesta de índices (MR+CAL a US$ 45, GOAT.md),
re-simulada com o mesmo Monte Carlo.

## 5. Se houver sobrevivente
EA mínimo MQL5, teste só no Strategy Tester do MT5 do box (demo), nunca ao vivo.

## 6. Log de tentativas
`out/tiro/attempts.csv` (as 17, inclusive as que falharam).
