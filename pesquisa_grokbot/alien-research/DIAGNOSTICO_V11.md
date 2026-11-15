# Diagnóstico da V11: por que ela perde com ticks reais

Data: 15/11/2026. Os testes rodaram no Strategy Tester do MT5 instalado no meu computador, usando a conta **demo** RoboForex-ECN [login da demo omitido]. Nenhuma ordem foi enviada em conta real ou na Goat.

Condições do teste:
- XAUUSD M1, de 30/10 a 13/11/2026, modelo 4 (ticks reais, 100%, 5.444.792 ticks).
- Depósito de US$ 10.000, lote 0,01.
- Mesmo `.set` do Vitor (`kit_teste_1clique/ALIEN_V11_SCALPER.set`).

## Resumo em 4 linhas

1. **O lucro de agosto a outubro foi ilusão do testador.** Nas mesmas duas semanas, com ticks gerados, a V11 faz +85,46 (PF 4,42). Com ticks reais faz −24,31 (PF 0,60).
2. **Com ticks reais, a entrada não tem vantagem.** Se cada trade fosse deixado correr até o SL ou o alvo 3R originais, o acerto seria de 25,5%. Para empatar com 1:3 é preciso 25% antes dos custos. Ou seja, o resultado é zero antes da taxa.
3. **Os custos comem um terço do risco de cada trade.** Spread mais comissão dão em média 0,31R por operação.
4. **Testei 5 correções de forma honesta e nenhuma funcionou.** Nenhuma passou na semana de checagem, e nenhuma ficou positiva em 10 anos de histórico (2016–2025). Por isso **não existe ALIEN_V11_FIX.mq5**.

## 1. Ticks gerados × ticks reais: mesmo robô, mesmo período

| | Ticks GERADOS | Ticks REAIS |
|---|---|---|
| Lucro líquido | **+85,46** | **−24,31** |
| Fator de lucro | 4,42 | 0,60 |
| Negócios / acerto | 165 / 61% | 145 / 25,5% |
| Quanto o preço andou contra após a entrada (mediana) | **−4 pts** (−0,11R) | **−34 pts** (−0,84R) |
| Quanto o preço andou a favor (mediana) | 95 pts (1,73R) | 41 pts (0,53R) |
| Trades que nunca ficaram positivos | 1% | **20%** |
| Trades que bateram o alvo 3R original | 49% | 25,5% |
| Spread na entrada (mediana / máximo) | 6 / 7 pts | 7 / 22 pts |

**Por que isso acontece:** no modo "ticks gerados", o MT5 inventa os ticks dentro de cada candle de 1 minuto seguindo um caminho fixo: abertura, depois mínima ou máxima, depois fechamento. A V11 decide olhando os ticks dos últimos 350 ms e 1,6 s, mais o sweep e a retomada dentro do candle. Com ticks inventados, quando o preço "vira" depois de fazer a mínima, o caminho já está programado para ir até a máxima. Na prática o robô enxerga o futuro do candle. Por isso o preço quase nunca andava contra (−4 pts) e o robô batia o teto de 15 trades por dia, todos os dias, sempre no azul. **Os +491 de agosto a novembro vêm disso** (87% daquele teste usou ticks gerados).

## 2. Causas da perda com ticks reais, em ordem

Todos os números abaixo são dos 145 trades com ticks reais. A tabela trade a trade está em `out/v11diag_DIAG_base_m4.csv`.

| # | Causa | Evidência |
|---|---|---|
| 1 | **A entrada não tem vantagem** | Das 108 perdas, 71 (66%) nunca andaram nem 0,5R a favor. São entradas ruins, não saídas cedo. Deixando cada trade correr com o SL e o alvo originais, sobram só +10,4 pts por trade antes da comissão. Depois dos 8 pts de comissão do testador, ficam +2,4 pts (≈ zero). |
| 2 | **Stop pequeno demais para o custo** | Stop mediano de 57 pts (0,35 ATR). O custo é 7 pts de spread mais 8 de comissão, ou seja, 15 pts por trade. Em média, o custo é **0,31R** por trade. Com esse custo, para empatar com 1:3 seria preciso acertar ~33%, e o robô acerta 25%. |
| 3 | **O break-even e o trailing pioram um pouco** | O BE sobe em ~0,33 ATR e o trailing é curto. Na conta trade a trade, a gestão tira ~19 pts por trade em relação a deixar correr: 27 trades saíram no BE/trailing quando iriam bater o SL (isso ajudou), mas 13 iriam bater o alvo 3R e saíram com ganho pequeno, e 19 perdas chegaram a +1R e devolveram tudo. **Só que tirar a gestão não resolve** (veja a correção F1). Os disjuntores diários e semanais mudam a sequência de trades, e com a entrada sem vantagem o resultado não melhora. |
| 4 | **Spread largo em alguns momentos** | 17 trades entraram com spread acima de 12 pts e ficaram bem piores. É um efeito pequeno. |
| — | Slippage | Zero no testador. Com conta de verdade só pode piorar. |
| — | Duração | O trade dura em média 26 a 32 s. É scalping de microestrutura, o tipo de operação mais sensível a custo e a latência. |

Outros números:
- Por setup: Sweep teve 100 trades e −13,57; BOS/reteste teve 45 trades e −10,74. **Os dois perdem.**
- Por horário: quase todas as horas perdem. A única positiva teve +0,26 em 25 trades, o que é ruído.
- Por dia: 10 de 11 dias negativos.

## 3. Correções testadas (declaradas antes de ver o resultado)

Regras do teste:
- Escolhi as correções olhando o diagnóstico, cada uma testada sozinha.
- A escolha era feita pela semana **A (30/10–06/11)**. A confirmação vinha da semana **B (09–13/11)**.
- Regra declarada antes: a F6 seria a combinação das correções que melhorassem a semana A.
- Lucro em US$ com lote 0,01, já com a comissão que o testador cobra (US$ 8 por lote, ida e volta).
- A coluna "com 16,80" aplica a comissão publicada pela RoboForex (~US$ 16,80 por lote, ida e volta).

| Teste | Semana A | Semana B | Total | Total com 16,80 | PF | Acerto |
|---|---|---|---|---|---|---|
| BASE (V11 original) | −12,29 | −12,02 | **−24,31** | −37,07 | 0,60 | 25,5% |
| F1: sem BE/trailing (só SL/TP 3R) | −17,77 | −12,10 | −29,87 | −37,35 | 0,53 | 20,0% |
| F2: recusa se spread > 12% do SL | −15,41 | −12,02 | −27,43 | −34,03 | 0,35 | 21,3% |
| F3: SL mínimo de 0,5 ATR | −14,58 | −12,22 | −26,80 | −34,02 | 0,41 | 26,8% |
| F4: BE só em +1R, trailing em +2R | −16,68 | −7,83 | −24,51 | −32,69 | 0,49 | 18,3% |
| F5: spread máximo de 10 pts | **−7,05** | −12,12 | −19,17 | −30,52 | 0,62 | 27,9% |
| F6: combinação | = F5 (foi a única que melhorou a semana A) | | | | | |

Observação: em quase todas as linhas a semana fecha perto de −12 porque o disjuntor semanal de US$ 12 desliga o robô. **Ele funcionou: nunca deixou perder mais que isso por semana.**

**Resultado:** só a F5 melhorou a semana de escolha. Na semana de checagem ela perdeu igual (−12,12, PF 0,30). **Reprovada.** A F4 foi melhor na semana B, mas pior na semana A. Escolher a F4 agora seria escolher olhando a resposta, e por isso também está reprovada.

## 4. Conferência em 10 anos (Dukascopy M1, 2016–2025)

Aproximei a ideia da V11 com candles de 1 minuto:
- **Entrada:** sweep da mínima ou máxima dos 10 candles anteriores, com fechamento de volta. Entra na abertura do candle seguinte.
- **Stop:** estrutural, mínimo de 0,15 ATR. Alvo de 3R.
- **Horário e limite:** das 07 às 17 UTC, no máximo 15 trades por dia.
- **Custos:** spread reescalado para a mediana de 8 pts. Quando o mesmo candle toca stop e alvo, contei como stop.

**Isso não é a V11.** Ela usa ticks, então essa conferência só mostra se a família de ideia tem vantagem.

| Variante (~3.870 trades por ano) | pts por trade (comissão 8) | Anos positivos | pts por trade (comissão 16,80) |
|---|---|---|---|
| Gestão da V11 | −13,3 | 0 de 10 | −22,1 |
| F1 sem gestão | −12,9 | 0 de 10 | −21,7 |
| F2 spread ≤ 12% do SL | −12,6 | 0 de 10 | −21,4 |
| F3 SL ≥ 0,5 ATR | −13,2 | 0 de 10 | −22,0 |
| F4 BE 1R / trail 2R | −13,5 | 0 de 10 | −22,3 |
| F5 spread ≤ 10 | −13,1 | 0 de 10 | −21,9 |

Sem nenhum custo, a ideia ganha só **+2,6 pts por trade (0,08R)**. O custo real é de ~16 pts por trade, seis vezes maior que essa vantagem. Isso confirma o que os ticks reais mostraram: a vantagem bruta é minúscula e o custo é grande.

## 5. Veredito

- A V11 não "quebrou" em novembro. **Ela nunca teve vantagem.** O lucro anterior era um efeito dos ticks gerados pelo testador.
- O problema principal é a **entrada**: dois terços das perdas nunca andam a favor. Mexer em stop, BE, trailing ou filtro de spread não cria vantagem que não existe. As 5 correções, com regra declarada antes, foram reprovadas nas 2 semanas reais e nos 10 anos de histórico.
- **Não salvei ALIEN_V11_FIX.mq5**, porque nada sobreviveu. O original não foi alterado.
- Seguir ajustando parâmetros nessas 2 semanas seria sobreajuste: com 145 trades, alguma combinação vai parecer boa por sorte.

## 6. O que continua desconhecido

- Só existem ~2 semanas de ticks reais no servidor (desde 30/10). Daqui a alguns meses dá para repetir o teste com mais dados.
- O testador cobra US$ 8 de comissão por lote. A tabela publicada indica ~US$ 16,80. Falta conferir na conta de verdade.
- A conta real teria slippage e atraso, que o testador não simula. Para scalping de 30 segundos, isso só piora.
- Pode existir vantagem em outra forma de entrada (outra pergunta, outro timeframe), mas isso é pesquisa nova, não conserto da V11.

## Arquivos

Código e dados:
- `code/v11diag/ALIEN_V11_DIAG.mq5`: cópia com registro de diagnóstico. Não muda sinais.
- `code/v11diag/ALIEN_V11_FIXLAB.mq5`: diagnóstico mais as chaves das correções, todas desligadas por padrão.
- `code/v11diag/F1..F5.set`: um arquivo por correção.
- `code/v11diag/analyze.py`, `compare.py`, `m1_proxy.py`: análises.
- `out/v11diag_compare.csv`, `out/v11diag_m1proxy.csv`, `out/v11diag_DIAG_base_m4.csv`, `out/v11diag_DIAG_base_m0.csv`: resultados.

Relatórios do MT5 em `out/mt5/`:
- `DIAG_base_m4` (reais) e `DIAG_base_m0` (gerados)
- `FIX_F1_m4` … `FIX_F5_m4`
