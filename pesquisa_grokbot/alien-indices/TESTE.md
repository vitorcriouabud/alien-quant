# ALIEN INDICES V1 — Teste no MT5 (Strategy Tester, demo RoboForex-ECN [login da demo omitido])

Rodado em 15/11/2026 no MT5 do meu computador (Wine). **Só Strategy Tester**: nenhuma ordem real, nenhum Algo Trading em gráfico.
Gráfico `.US500Cash` D1, um único EA operando `.US500Cash`, `.USTECHCash` e `.DE40Cash`. Alavancagem 1:100, conta USD.
Modelo: **OHLC de 1 minuto** (o servidor tem histórico M1 do US500/US Tech desde 06/12/2017 e do DE40 desde 10/08/2016;
com 200 dias para a MM200, as operações começam em 29/05/2018 no DAX e em set/2018 nos EUA).
Ticks reais existem para os índices desde pelo menos 02/01/2025 → usei para conferir (tabela 3).
Custos do testador = os da conta ECN: spread histórico do servidor, comissão US$ 5 por milhão por lado, **swap atual
(compra −8,6%/ano EUA, −7,2% DAX; venda −1,8%), triplo na sexta**, aplicado a todo o histórico.

## 1. Resultado principal (depósito US$ 100.000 = tamanho de lote "contínuo", comparável à pesquisa)
| Período 29/05/2018 → 13/11/2026 | MT5 |
|---|---|
| Lucro líquido | +US$ 37.086 (+37,1%) |
| CAGR | **3,8% ao ano** |
| DD máximo de equity | **7,6%** (relativo 8,0%) |
| Profit factor / acerto | 1,28 / 68% |
| Trades | 934 (~9,2 por mês) |
| Swap pago | **−US$ 22.531** (o swap comeu ~38% do lucro bruto) |
| Comissão | −US$ 189 |
| Por índice | US500 +16.922 · US Tech +15.511 · DE40 +4.748 |

## 2. Resultado por ano (%)
| Ano | MT5 US$100k | MT5 US$5k | MT5 US$1k | MT5 US$10k, risco aberto máx 3% | Pesquisa publicada (RESULTS_V2/FRENTES) | Pesquisa com swap corrigido (taxas RF atuais) |
|---|---|---|---|---|---|---|
| 2016 | – | – | – | – | +0,3 | +0,3 |
| 2017 | – | – | – | – | +11,5 | +8,4 |
| 2018* | −2,8 | −2,7 | −2,6 | −1,7 | +1,0 | −0,4 |
| 2019 | +4,5 | +4,3 | +3,1 | +4,5 | +7,6 | +6,3 |
| 2020 | −0,1 | −0,2 | −2,9 | +2,0 | +3,6 | +2,2 |
| 2021 | +14,0 | +13,2 | +10,9 | +7,7 | +9,9 | +7,7 |
| 2022 | −1,2 | −1,2 | −1,4 | +0,6 | +1,7 | +1,2 |
| 2023 | +7,4 | +7,0 | +5,7 | +5,6 | +5,9 | +3,8 |
| 2024 | +10,7 | +10,3 | +9,0 | +5,2 | +15,5 | +12,6 |
| 2025 | +0,7 | +0,8 | +4,2 | −0,9 | +9,1 | +7,6 |
| 2026 (até 13/11) | +0,2 | +0,7 | +2,6 | −3,7 | +2,8 | +0,9 |
| **CAGR** | **3,8%** | 3,7% | 3,3% | 2,2% | 6,2% | **4,6%** |
| **DD máx** | 7,6% | 7,0% | 7,4% | 8,6% | 6,1–6,9% | 6,3% |
| Trades | 934 | 934 | 766 | 783 | 1.188 (desde 2016) | 1.186 |
*2018 no MT5 é parcial (DAX desde 29/05, EUA desde set/2018).

## 3. Ticks reais × OHLC de 1 minuto (01/01/2025 → 13/11/2026, US$ 100k)
| Modelo | Resultado | Trades | PF | DD |
|---|---|---|---|---|
| Ticks reais (99% real) | +0,66% | 225 | 1,02 | 7,6% |
| OHLC 1 minuto | +0,91% | 225 | 1,03 | 7,6% |
Para um robô diário, o modelo M1 dá praticamente o mesmo resultado que ticks reais. O teste longo em M1 é confiável.
**Mas os últimos ~23 meses ficaram no zero a zero.**

## 4. Por que o MT5 dá menos que a pesquisa (6,2% → 3,8%)
Comparei operação por operação (janela comum desde 24/09/2018, em R = múltiplos do risco):
| Etapa | Soma em R |
|---|---|
| Pesquisa como publicada | +61,2 R |
| **Bug encontrado na pesquisa:** o swap estava ~1000× menor (o pandas 3 guarda datas em microssegundos e o `engine2.py` dividia por nanossegundos/dia). Na prática a pesquisa rodou **sem swap**. Com o swap certo nas taxas atuais da RoboForex | +43,4 R (swap −17,9 R) |
| MT5 sem swap | +51,6 R |
| MT5 com swap (resultado real do teste) | +33,1 R (swap −18,5 R) |
1. **Swap (maior causa, ~18 R ≈ 2 pontos de CAGR).** Segurar índice comprado custa 8,6% ao ano do valor da posição na RoboForex.
   O MT5 e a pesquisa corrigida concordam nesse custo. Obs.: o testador usa a taxa de hoje em todo o histórico; em 2020–2021 o swap
   real era menor (juros perto de zero), então o passado no MT5 está um pouco pessimista, mas **daqui pra frente o custo é esse**.
2. **Diferença de dados/sessão (~10 R).** 88% das entradas caem no mesmo dia nos dois. Nas operações em comum o resultado é
   quase idêntico (R médio sem swap 0,061 × 0,061; correlação 0,94). A diferença está nas ~110 operações que só um dos lados fez
   (os candles diários da RoboForex não são iguais aos da Dukascopy: o DAX da RoboForex abre 09:05 e o US500 03:00 do servidor;
   máximas/mínimas diferentes mudam IBS e RSI2). O DAX é o que mais perde: +3,6 R sem swap no RSI2 vs +4,6 na pesquisa, +7,0 vs +10,7 no IBS.
3. **2025:** dois stops cheios (US500 RSI2 em 24/02 e DAX RSI2 em 31/03, a queda das tarifas) que na Dukascopy não bateram o stop. Sozinhos explicam ~1,3 R.
4. Comissão é irrelevante (US$ 189 em 8 anos). Spread na abertura também (o EA espera o spread ficar < 10% do stop).
5. Arredondamento de lote (depósito pequeno) só troca quais sinais entram; não muda a vantagem.

## 5. Dá para operar com US$ 20 a US$ 1.000?
Especificações lidas no servidor (DumpSpec no tester) e no site da RoboForex:
| Símbolo | Contrato | Lote mín./passo | Valor de 1 ponto no lote mínimo | Comissão ECN | Swap compra/venda | Sessão (servidor) |
|---|---|---|---|---|---|---|
| .US500Cash | 1 × índice (US$) | 0,01 / 0,01 | US$ 0,01 | US$ 5 por milhão/lado | −8,6% / −1,8% ao ano | 03:00–23:15 |
| .USTECHCash | 1 × índice (US$) | 0,01 / 0,01 | US$ 0,01 | idem | −8,6% / −1,8% | 03:00–23:15 |
| .DE40Cash | 1 × índice (EUR) | 0,01 / 0,01 | € 0,01 | idem | −7,2% / −1,8% | 09:05–23:00 |
Depósito mínimo para que **o lote 0,01 arrisque no máximo 1%** (stop = 3 ou 4 × ATR20 do diário):
| Fluxo | Hoje (nov/2026) | Mediana 2025–26 |
|---|---|---|
| US500 RSI2 / IBS | US$ 373 / 497 | 242 / 323 |
| US Tech RSI2 / IBS | US$ 2.357 / **3.142** | 1.325 / 1.767 |
| DE40 RSI2 / IBS | US$ 1.500 / 1.999 | 1.125 / 1.499 |
- **US$ 20: não dá.** O menor stop (US500 RSI2) no lote mínimo arrisca ~US$ 3,70 = 19% da conta. O robô pularia tudo.
- **US$ 1.000: só parcialmente.** Opera o US500; Nasdaq e DAX só quando a volatilidade está baixa (no teste pulou 279 sinais por lote mínimo).
  Resultado no teste: +31% em 8,5 anos (3,3% ao ano), DD 7,4%. O risco real por trade fica entre ~0,5% e 1% (o lote é arredondado pra baixo).
- **Conta cent não resolve:** a ProCent da RoboForex **não tem índices** (só moedas, metais e cripto). Então a ideia
  "US$ 10 na cent = US$ 1.000 na padrão" não vale para este robô. Precisa de conta Pro, ECN ou Prime em dólar.
- **Para a cesta inteira a 1%: ~US$ 3.200+ hoje** (folga: US$ 5.000). Com US$ 5.000 o teste deu +35,6% em 8,5 anos (3,7%/ano), DD 7,0%.

## 6. Veredito honesto
- O robô **faz o que a pesquisa descreve** (mesmas entradas em 88% dos dias, mesmo resultado por operação) e **nunca chegou perto de quebrar**:
  DD máximo ~7–8% com 1% de risco, sem martingale e sem grid.
- Mas com o swap real da RoboForex o retorno cai para **~3,5–4% ao ano**, e **2025–2026 ficaram praticamente no zero** (+0,7% e +0,2%).
  Isso é menos que deixar o dinheiro num CDB. Não é a "máquina de dinheiro"; é um robô defensivo com vantagem pequena.
- Limitar o risco aberto a 3% piorou (2,2%/ano): os melhores trades de reversão vêm justamente quando vários índices caem juntos.
- O que o swap ensina: operações que ficam vários dias compradas pagam juros. Uma corretora/conta **sem swap** (swap-free) ou com swap menor
  mudaria bastante a conta — isso é uma hipótese a testar, não um resultado.

## Reprodução
- EA: `ALIEN_INDICES_V1.mq5` (+ `.ex5`, `.set`). Relatórios e logs: `relatorios/`.
- Teste: `bash /workspace/alien-research/code/run_mt5_test.sh /workspace/alien-indices/ALIEN_INDICES_V1.mq5 /workspace/alien-indices/ALIEN_INDICES_V1.set .US500Cash D1 2015.01.01 2026.11.13 100000 FINAL_100000` com `MT5_MODEL=1` (ou `4` para ticks reais).
- Análise: `tools/analyze_mt5.py` (relatório), `tools/compare.py` (trade a trade × pesquisa), `tools/research_swapfix.py` (pesquisa com swap corrigido).
