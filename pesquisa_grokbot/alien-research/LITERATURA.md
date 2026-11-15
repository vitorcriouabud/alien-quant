# LITERATURA — o que livros, artigos e cursos dizem sobre o ouro, e o que ainda não testamos

Projeto ALIEN (Vitor Lima). Foco XAUUSD, conta pequena (0,01 lote = 1 oz), RoboForex-ECN MT5.
Escrito em 15/11/2026 ~01:40 (horário de Brasília). **A Parte 2 (pré-registro) foi escrita ANTES de rodar qualquer teste desta rodada.**

## Parte 1 — Varredura da literatura

"Já testado?" confere com RESULTS.md, RESULTS_V2.md, MERCADO.md, DESLOCAMENTO.md, FRENTES.md, TENDENCIA_MULTI.md e OURO_FOCO.md.

| # | Ideia | Fonte | O que a fonte afirma | Já testado por nós? | Dá pra testar com nossos dados? |
|---|---|---|---|---|---|
| 1 | Momentum intradiário: 1ª meia hora prevê a última (Gao et al.) aplicado ao **ouro** | Gao, Han, Li & Zhou 2018, *JFE* (https://doi.org/10.1016/j.jfineco.2018.05.009); ouro chinês: Zhou et al. "Night trading momentum" (https://acfr.aut.ac.nz/__data/assets/pdf_file/0008/686816/4a-Z-Ivy-Zhou.pdf) e *Global Finance J.* 2025 (https://ideas.repec.org/a/eee/glofin/v64y2025ics1044028325000110.html); GLD: Zhang et al. 2020 (https://pmc.ncbi.nlm.nih.gov/articles/PMC7480318/) | Ouro chinês: 1ª meia hora prevê a 6ª (t 4,4) antes do pregão noturno; GLD: a 5ª meia hora prevê a última (t 3,0). Estudo de varejo em XAUUSD 2022–26 (Liquidity Hunters, https://liquidityhunters.cl/en/studies/gold-trading-sessions/) **não** achou (t −0,15 a 1,44) | Só nos índices (MERCADO 9, falhou). **No ouro: não** | Sim (M1) → **família IM** |
| 2 | Overnight positivo × dia negativo no ouro | Blose & Gondhalekar 2014, *Applied Econ. Letters* (https://doi.org/10.1080/13504851.2014.922661); Blose et al. 2018, *J. Econ. Finance* (https://ideas.repec.org/a/spr/jecfin/v42y2018i3d10.1007_s12197-017-9403-0.html) | Overnight do COMEX positivo e dia negativo 1985–2012, "enfraquecendo" | **Sim**: SE1/SE2 (OURO_FOCO) e hora do dia (V2). Reprovado | — (não repetir) |
| 3 | **Deriva da reabertura** 16:30→19:00 NY (passa pelo rollover) | Liquidity Hunters 2026 (link acima) | +1,4 bp/dia 2015–21 (t 4,3), +3,3 bp 2022–26 (t 3,9); parte é o carry que o CFD cobra no swap; no CFD sobra ~1,2%/ano | Parcial: compras às 18h segurando 4/8h (V2) começam depois da reabertura; a janela 16:30→18:05 com swap **nunca** | Sim → **família RO** |
| 4 | Momentum entre sessões: sessão americana prevê a asiática; ganho do ouro concentrado na Ásia | Wei 2026, SSRN 7257240 (https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7257240) | Autocorrelação +0,13 da sessão anterior para a Ásia; só a versão "só compra" sobrevive ao custo (amostra curta: 2024–26, alta forte do ouro) | Ásia incondicional sim (SE1, 18h→02h); **condicionada à sessão americana: não** | Sim → **família CS** |
| 5 | Rompimento de volatilidade de Larry Williams (abertura ± K × range de ontem) | Williams, *Long-Term Secrets to Short-Term Trading* (1999); reteste no ouro: YuRa Trading 2026 (https://yuratrading.com/blogs/williams-vol-breakout) | No ouro 2022–26 fora da amostra: PF 1,07–1,20, ~4–8%/ano, DD 16–24%, quase todo lucro em 2025 | Parcial: ORB de Londres/NY (RESULTS F5) e Donchian; **âncora na abertura do dia + range de ontem: não** | Sim → **família VB** |
| 6 | Razão ouro/prata volta para a média | Wahab, Cohn & Lashgari 1994, *J. Futures Markets* (https://doi.org/10.1002/fut.3990140606); Liu & Chou 2003, *Applied Fin. Econ.* (https://ideas.repec.org/a/taf/apfiec/v13y2003i12p899-911.html) | Spread cointegrado; Wahab: lucro vira prejuízo com custo > ~US$7 por operação; Liu & Chou: lucro com modelo de correção de erro | **Não** | Sim (D1 bid/ask de XAU e XAG da Dukascopy) → **família GS** |
| 7 | Dólar (DXY) ou juros reais "puxam" o ouro com atraso | Picard 2017, SSRN 2990010 (https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2990010): informação se espalha em < 100 ms; Parmeshwar (https://rahulsp.com/papers/cross-asset-lead-lag): sem lead-lag do DXY, prata ou índices para o XAUUSD no M1 (R² fora da amostra negativo) | Relação é **simultânea**, não com atraso | Não | Possível, mas a evidência já é contra e custaria um download grande → **não testo** (registrado) |
| 8 | Fix de Xangai (SGE 10:15/14:15 Pequim) | BullionStar (https://www.bullionstar.com/blogs/ronan-manly/shanghai-gold-benchmark-price-new-sge-gold-fix/); spillover COMEX/LBMA/SGE, *J. Econ. Finance* 2020 (https://link.springer.com/article/10.1007/s12197-020-09517-5) | A SGE **recebe** preço de Londres/NY; nenhum estudo de efeito no fix | Não (mas o fix de Londres, que é maior, falhou: movimento 4× menor que o custo) | Sim, mas sem evidência → **não testo** |
| 9 | Vencimento de opções COMEX "derruba"/"prende" o ouro | Blogs (Goldmoney); teste de pin: Delta Terminal (https://deltaterminal.io/blog/does-opex-really-pin-gold/) | Sem pin em 39 vencimentos; range até menor | Não | Sem evidência → **não testo** |
| 10 | Prêmio de risco de volatilidade (vender opção) | literatura de opções | Real em opções | Não | **Não**: no CFD não há opções |
| 11 | Fluxo de ETFs (GLD) | vários | Fluxo segue preço (não antecede) na maioria dos estudos | Não | Sem dados diários grátis confiáveis → não testo |
| 12 | Virada do mês | McConnell & Xu 2008 | — | **Sim** (lista de observação, t 1,1 em OURO_FOCO) | — |
| 13 | RSI2/IBS (Connors & Alvarez 2009); padrões gráficos (Bulkowski); candles; Fibonacci; pivôs | livros | — | **Sim** (V2, MERCADO 8). Reprovados no ouro | — |
| 14 | Tendência/carry (Carver, *Systematic Trading*; Kaufman, *Trading Systems and Methods*; Moskowitz et al. 2012) | livros/artigos | Funciona em futuros, carteira grande | **Sim** (V2, FRENTES, TENDENCIA_MULTI). Swap do CFD come | — |
| 15 | Pares GLD/GDX (Chan, *Algorithmic Trading* 2013) | Chan; quebra da cointegração: https://epchan.blogspot.com/2011/06/when-cointegration-of-pair-breaks-down.html | O próprio Chan mostra que o par parou de funcionar | Não | Não temos GDX no MT5 da RoboForex → só a versão ouro/prata (item 6) |
| 16 | Notícias, fix de Londres, COT, fim de mês, SMC/ICT, liquidez, AMD | cursos/artigos | — | **Sim**, todos reprovados | — |
| 17 | **Volume (tick volume)** + tipo de candle + contexto (BOS/extremo) — Wyckoff/VSA ("volume confirma", "volume de clímax") | Cursos de VSA/Wyckoff (Tom Williams, *Master the Markets*; Anna Coulling, *A Complete Guide to Volume Price Analysis*). Evidência acadêmica em FX/ouro spot é fraca (tick volume é só proxy) | Barra de corpo forte com volume alto = continuação; pavio grande com volume alto = virada | Parcial: "pico de volume" genérico no H1, 2021+ (MERCADO 8: H1 +1,9bp bruto, 2026 −3,8, instável). **Com candle + contexto, M5/M15/H1, 2016+: não** | Sim (baixei tick volume M1 Dukascopy 2016–2026) → **família VO** (pedido) |

**Leitura honesta da literatura:** quase todo efeito acadêmico do ouro é (a) antigo e enfraquecido depois de publicado, (b) em futuros chineses, que têm horário e participantes diferentes, ou (c) pequeno demais para o custo de varejo. Os dois estudos recentes em XAUUSD com custo real (Liquidity Hunters, YuRa) acham **no máximo** coisas "reais mas pequenas demais para operar". Expectativa declarada: **provavelmente nada passa**.

## Parte 2 — PRÉ-REGISTRO (antes de qualquer número desta rodada)

### Dados, divisão, custos (iguais ao OURO_FOCO)
- XAUUSD M1 bid/ask Dukascopy (`data/xau_m1_2016_2026.parquet`). Tick volume M1 Dukascopy (bid) em `data/xvol/`. XAG/XAU D1 bid/ask em `data/d1/`.
- **IS 2016–2024, validação 2025, 2026 guardado** (abre uma vez só para quem passar tudo).
- Compra entra no ask e sai no bid. Comissão US$16,80/lote ida e volta (0,168/oz); sensibilidade US$8. Swap se cruzar 17:00 NY: compra −5,5%/ano, venda +1,7%/ano, triplo na quarta. Prata: comissão 0,004% do nocional ida e volta (mesma regra US$20 por milhão por lado), mesmo swap do ouro (premissa declarada).
- Stop no preço do stop (ou abertura do M1 se passou por gap); stop e alvo no mesmo M1 = stop.

### Famílias e variantes (19 no total)

**IM — momentum intradiário (horário COMEX, NY) — 3**
- IM1: sinal = retorno de 13:30 NY do dia anterior até 08:50 NY (noite + 1ª meia hora do COMEX). Opera **13:00→13:30 NY** na direção do sinal.
- IM2: sinal = só 08:20→08:50 NY. Mesma operação.
- IM3: só opera se o sinal do IM1 e a penúltima meia hora (12:30→13:00) têm o mesmo sinal (versão combinada de Gao).
- Vizinhos: janela de operação ±5 min.

**RO — deriva da reabertura — 2** (só seg–qui; sexta não, pois pega o fim de semana)
- RO1: compra 16:30 NY → 19:00 NY (paga 1 swap; quarta paga triplo).
- RO2: compra 18:05 → 19:00 NY (depois da reabertura, sem swap).
- Vizinhos: RO1 entrada 16:15/16:45 e saída 18:30/19:30; RO2 entrada 18:15, saída 18:45/19:30.

**CS — momentum sessão americana → Ásia (UTC, como no artigo) — 2**
- Sinal = retorno 14:30→21:00 UTC do dia anterior (fim antes do rollover).
- CS1: se sinal > 0, compra 00:00 → 08:00 UTC; senão fora (só compra, a versão que o artigo diz sobreviver).
- CS2: compra se > 0, vende se < 0.
- Vizinhos: entrada 01:00 UTC; saída 06:00 / 10:00 UTC.

**VB — rompimento de volatilidade de Larry Williams — 2**
- Dia = sessão 18:00→16:45 NY. R = máxima − mínima da sessão anterior (segunda usa a sexta). Abertura = 1º preço da sessão.
- Gatilho: 1º fechamento M1 acima de abertura + K×R (compra) ou abaixo de abertura − K×R (venda), a partir das 18:05; entra na abertura do M1 seguinte; 1 operação por dia; sem entradas depois das 16:00 NY.
- Stop = 0,7×R da entrada; alvo 3R; saída forçada 16:45 NY (sem swap — diferente do blog, declarado).
- VB1: K = 0,5. VB2: K = 0,7 (o melhor fora da amostra no blog).
- Vizinhos: K ±0,1; stop 0,5/0,9 R; alvo 2R/4R.

**GS — razão ouro/prata volta para a média (D1) — 2**
- z = (log(XAU/XAG) − média 20 dias)/desvio 20 dias, no fechamento D1 (mid).
- GS1 (par): z > 2 → vende 1 oz de ouro e compra prata no mesmo valor em dólar; z < −2 → o contrário. Sai quando |z| < 0,5 ou após 10 dias. Entra/sai na abertura D1 seguinte (bid/ask). Paga spread, comissão e swap dos dois lados.
- GS2 (só ouro, que é o foco): mesma regra, só a perna do ouro.
- Mínimo de operações no IS: 40 (sinal raro, declarado). Vizinhos: janela 10/40 dias; entrada z 1,5/2,5.

**VO — tick volume + candle + contexto (pedido) — 8**
- Volume relativo RV = volume da barra / média do volume das barras do **mesmo horário** nos 20 dias anteriores.
- Corpo forte: corpo ≥ 0,7×range e range ≥ 1×ATR(14). Pavio de rejeição: pavio de um lado ≥ 0,6×range e range ≥ 1×ATR(14).
- VO1 (M5, M15, H1): corpo forte + RV ≥ 2 → **segue** a direção do corpo. Stop = outro extremo da barra.
- VO2 (M5, M15, H1): pavio de rejeição + RV ≥ 2 → **contra** o pavio (pavio de cima = venda). Stop = extremo do pavio + 0,1×ATR.
- VO3 (M15): VO1 + a barra fecha acima da máxima (abaixo da mínima) das 20 barras anteriores (= BOS) e deixa FVG com a barra seguinte — entra na abertura da barra **depois** da que confirma o FVG.
- VO4 (M15): VO2 + o pavio passou da máxima/mínima das 20 barras anteriores (= varrida com volume de clímax).
- Saída comum: alvo 2R ou 4 horas, saída forçada 16:45 NY; entrada na abertura da barra seguinte; sem entradas 16:00–18:00 NY; não opera se stop > 3×ATR; sem sobreposição.
- Vizinhos: RV ≥ 1,5 e ≥ 3; alvo 1,5R/3R.

### Estatística e reprovação
- t unilateral sobre o PnL **somado por dia** no IS. **BH (q 0,05) e Bonferroni sobre as 19.** Projeto todo: ~2.326 + 19 = **~2.345 tentativas → t necessário ≈ 4,1** (Bonferroni global, unilateral 5%). Reporto os dois.
- Reprova se qualquer um: (1) IS ≤ 0 ou não passa BH; (2) PF IS < 1,10 ou < 100 operações (GS: 40); (3) positivo em < 6 de 9 anos do IS; (4) sem o melhor 1% fica ≤ 0, ou um dia > 10% do lucro; (5) 2025 negativo ou PF < 1,05; (6) < 2/3 dos vizinhos positivos; (7) informar risco por operação em 0,01 lote.
- Sobrevivente: abre 2026 uma vez; se positivo → EA mínimo MQL5 e teste no Strategy Tester da demo (nunca conta real).
- Fora do IS só olho 2025 e 2026 do jeito acima. Nada muda depois de ver números; mudança = tentativa nova no log.

### Log
- L1: pré-registro escrito ~01:40 de 15/11/2026, antes de rodar. A família VO foi pedida às ~01:35 (pedido repassado do Vitor) e entrou aqui também antes de qualquer número.
- L2 (~01:55, DEPOIS de ver os 19 resultados): o VO3_M15 foi o único com t alto (mas reprovou por regra). Para ver se é padrão ou sorte, rodo a **mesma regra VO3 sem nenhuma mudança no M5 e no H1** (2 tentativas novas, total 21). Só IS e 2025. Se for real, deveria aparecer pelo menos com o mesmo sinal nos outros tempos gráficos.
- Aviso de honestidade: ao conferir o VO3 por ano, a tabela imprimiu também 2026 para VO3_M15, VB2, GS2 e VO1_H1. Ou seja, **2026 deixou de ser inédito para essas 4 regras** (o resultado está anotado na Parte 3, mas não conta como validação).

---

## Parte 3 — RESULTADOS (15/11/2026 ~02:00, horário de Brasília)
Código: `code/lit/lit.py` (19 regras) e `code/lit/vo3x.py` (L2). Saídas: `out/lit/summary.csv`, `out/lit/trades.pkl`. Tick volume: `data/xvol/`.
Valores em **US$ por operação com 0,01 lote** (= US$/oz), IS 2016–2024, custo principal (spread real + US$16,80/lote + swap quando dorme).

### Resposta curta
**Nada sobreviveu.** 0 de 21 passam em todos os critérios. Um único resultado chamou atenção (VO3_M15, volume + BOS + FVG), mas ele reprova em 3 regras escritas antes (poucas operações, um dia concentra o lucro, 2025 negativo) e o mesmo padrão no M5 ficou fraco (t 1,2). Não abri 2026 como validação, não fiz EA, não rodei o MT5.

### Tabela (IS 2016–2024 | validação 2025)
| Família | Regra | Operações IS | Média IS | PF | t | Anos + (de 9) | 2025 média (n) | Sem comissão |
|---|---|---|---|---|---|---|---|---|
| IM momentum intradiário (Gao) | IM1 noite+1ª meia hora → 13:00–13:30 | 2.281 | −0,41 | 0,58 | −9,0 | 0 | −0,47 (257) | −0,24 |
| | IM2 só 1ª meia hora | 2.284 | −0,52 | 0,50 | −11,3 | 0 | −0,73 | −0,35 |
| | IM3 combinado (com penúltima meia hora) | 1.136 | −0,42 | 0,57 | −6,5 | 0 | −0,70 | −0,26 |
| RO deriva da reabertura | RO1 compra 16:30→19:00 (com swap) | 1.790 | −0,63 | 0,38 | −13,0 | 0 | −0,30 | −0,46 |
| | RO2 compra 18:05→19:00 | 1.856 | −0,50 | 0,35 | −13,7 | 0 | −0,42 | −0,33 |
| CS sessão EUA → Ásia | CS1 só compra | 1.048 | −0,51 | 0,82 | −2,3 | 1 | +1,58 (137) | −0,34 |
| | CS2 compra e venda | 2.054 | −0,64 | 0,77 | −4,1 | 2 | −0,03 | −0,47 |
| VB Larry Williams | VB1 K 0,5 | 1.646 | −0,05 | 0,99 | −0,2 | 3 | −0,57 | +0,12 |
| | VB2 K 0,7 | 1.164 | **+0,19** | 1,05 | 0,6 | 5 | +2,17 (135) | +0,36 |
| GS razão ouro/prata | GS1 par ouro × prata | 91 | −16,86 | 0,42 | −2,7 | 1 | −120 (9) | −16,7 |
| | GS2 só a perna do ouro | 91 | +1,93 | 1,13 | 0,4 | 6 | +14,6 (9) | +2,1 |
| VO volume + candle | VO1 corpo forte + volume alto (M5 / M15 / H1) | 3.204 / 1.051 / 229 | −0,56 / −0,75 / −0,19 | 0,65 / 0,68 / 0,94 | −9,0 / −4,7 / −0,3 | 0 / 1 / 3 | −0,30 / +0,59 / +3,05 | todos ≤ 0 |
| | VO2 pavio + volume alto, contra o pavio (M5 / M15 / H1) | 1.990 / 681 / 125 | −0,36 / −0,58 / −0,82 | 0,74 / 0,74 / 0,74 | −5,1 / −3,1 / −1,2 | 0 / 3 / 3 | negativo | negativo |
| | VO4 pavio + volume + varrida de 20 barras (M15) | 340 | −0,69 | 0,71 | −2,6 | 2 | −0,73 | −0,52 |
| | **VO3 corpo forte + volume + BOS + FVG (M15)** | **67** | **+2,77** | **2,82** | **3,0** | 6 | **−0,55 (15), PF 0,86** | +2,94 |
| L2 (depois) | VO3 no M5 / no H1 | 244 / 7 | +0,39 / −1,48 | 1,22 / 0,63 | 1,2 / −0,4 | 5 / 2 | +1,42 (36) / — | — |

### Critérios de reprovação
| Critério | Resultado |
|---|---|
| 1. IS positivo e passa BH (19) | Só 3 positivas (VB2, GS2, VO3_M15). **Só o VO3_M15 passa BH e até Bonferroni das 19** (p 0,002) |
| 2. PF ≥ 1,10 e ≥ 100 operações (GS: 40) | VO3_M15 tem **67 operações → reprova**. VB2 PF 1,05 → reprova. GS2 PF 1,13 e 91 operações, mas t 0,4 |
| 3. ≥ 6/9 anos positivos | VO3_M15 6/9 (2016–2018 negativos); GS2 6/9; VB2 5/9 |
| 4. Sem o melhor 1% / dia > 10% do lucro | VO3_M15: **um único dia = 14,5% do lucro → reprova** |
| 5. 2025 positivo e PF ≥ 1,05 | VO3_M15: **2025 −0,55, PF 0,86 → reprova** |
| 6. Vizinhos | VO3_M15 4/4 positivos (passaria) |
| Limiar do projeto inteiro | ~2.347 tentativas → precisa t ≈ 4,1. O melhor foi 3,0 |

### O que cada ideia da literatura mostrou nos nossos dados
- **Momentum intradiário (Gao) no ouro:** não existe no XAUUSD. A última meia hora do COMEX não segue a primeira (o estudo da Liquidity Hunters achou o mesmo). O que aparece em futuros chineses não vale para o spot de Londres/NY.
- **Deriva da reabertura (16:30→19:00):** existe uma alta pequena, mas o custo é maior: mesmo **sem comissão** perde (−0,46 e −0,33 por operação), porque o spread perto do rollover e o swap comem tudo. Bate com o próprio autor: "pequeno demais para operar no CFD".
- **Sessão americana → Ásia (artigo SSRN 2026):** perde no IS (t −2,3). O artigo usou só 2024–26, quando o ouro subiu 80%. Em 9 anos não se sustenta.
- **Larry Williams:** VB2 levemente positivo (+0,19, PF 1,05, t 0,6), bem parecido com o reteste do blog ("real, mas pequeno"). O lucro aparece quase todo em anos de alta forte do ouro (2020, 2024, 2025).
- **Razão ouro/prata:** o par completo perde muito (dois spreads, duas comissões, dois swaps). Só a perna do ouro dá +1,93 por operação, mas com 91 operações e t 0,4 é ruído.
- **Volume (pedido):** tick volume alto sozinho, com corpo forte ou com pavio de rejeição, **não ajuda** (M5, M15 e H1 negativos). A única combinação positiva foi corpo forte + volume 2× o normal + rompimento da máxima/mínima de 20 barras + FVG no M15, mas com só 67 operações em 9 anos (~7 por ano), 3 anos negativos, um dia respondendo por 14,5% do lucro e **2025 negativo**. No M5 a mesma regra ficou fraca (t 1,2, um dia = 31% do lucro). Isso tem cara de sorte de amostra pequena, não de vantagem. Fica como **lista de observação**, não como robô.

### Honestidade sobre 2026
Por descuido, ao abrir a tabela por ano vi 2026 de 4 regras: VO3_M15 +134 em 5 operações (uma operação grande), VB2 +708, GS2 −368, VO1_H1 −40. **Isso não conta como validação** (nenhuma delas passou nos critérios antes) e 2026 deixa de ser inédito para essas 4. Uma nota: valores em US$/oz crescem com o preço do ouro (em 2026 o ouro está em ~US$4.000), por isso anos recentes pesam mais.

### Não testado (registrado)
- Lead-lag dólar/juros → ouro: a literatura recente mostra relação simultânea (Picard 2017; Parmeshwar). Não gastei tentativa.
- Fix de Xangai, vencimento de opções, fluxo de ETF, volatilidade implícita: sem evidência ou sem dado/instrumento no MT5.

### Veredito
Livros, artigos e cursos não trouxeram nenhuma vantagem nova no XAUUSD com custo real. Total do projeto: **~2.347 tentativas**. A única regra com vantagem que se repete continua sendo a cesta de índices (RSI2/IBS). No ouro, o que sobra é lento e fraco (virada do mês, Larry Williams K 0,7, VO3), tudo no tamanho do ruído.
