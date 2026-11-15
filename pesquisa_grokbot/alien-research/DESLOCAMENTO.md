# Pesquisa: deslocamento no ouro (XAUUSD) — continua ou devolve?

## Parte 1 — Pré-registro (escrito ANTES de olhar qualquer resultado)

Data do pré-registro: 15/11/2026, ~03:35 (horário de Brasília). Nada abaixo será mudado depois de ver os números.
Qualquer mudança vira uma **nova tentativa** e entra no registro (seção "Log de tentativas").

### Pergunta única
Depois de um movimento forte (deslocamento) no XAUUSD, em quais condições o preço **continua** e em quais ele **devolve**?
Existe uma entrada executável que fique positiva **depois dos custos reais**?

### Dados
- Dukascopy XAUUSD M1 bid/ask, 2016-01 a 2026-11-13. Barras "de enchimento" (mercado fechado: máxima = mínima e fechamento repetido) são removidas.
- Sinais calculados no preço médio (mid) de barras **já fechadas**. Compra entra no ask e sai no bid; venda entra no bid e sai no ask.
- M5, M15, H1 montados a partir do M1 (após remover o enchimento).

### Divisão do tempo
- Dentro da amostra (IS): 2016–2024. Validação: 2025. **2026 fica guardado** e é olhado **uma única vez**, no fim, só para quem sobreviver.

### Definição de deslocamento (3 definições fixas, calculadas no M15 e no M5)
ATR = ATR(14) do próprio timeframe, calculado até a barra **anterior** ao evento.
- **D1 barra grande:** amplitude ≥ 2,0×ATR e corpo ≥ 60% da amplitude.
- **D2 corpo forte:** |corpo| ≥ 1,5×ATR.
- **D3 três barras:** |fechamento(t) − abertura(t−2)| ≥ 2,5×ATR.
- Direção do evento = sinal do movimento. Período refratário: mesma definição não dispara de novo em 4 barras.

### Contexto (H1, só com barras H1 fechadas antes do evento)
- ER = eficiência de Kaufman em 24 barras H1 = |fech − fech(24 atrás)| / soma |variações|.
- Compressão = ATR14(H1) / mediana de ATR14(H1) nas 120 barras H1 anteriores.
- **Tendência a favor:** ER ≥ 0,30 e direção H1 = direção do evento. **Tendência contra:** ER ≥ 0,30 e direção oposta.
- **Comprimido:** ER < 0,30 e compressão < 0,80. **Lateral:** o resto.
- Sessão (hora de Nova York do fechamento do evento): **Ásia** 18:00–02:59, **Londres** 03:00–07:59, **NY** 08:00–16:59 (16:50–18:00 não opera).

### Estudo do caminho (MFE/MAE) — descritivo
Para cada evento, a partir do fechamento (mid), na direção do evento: retorno e MFE/MAE em unidades de ATR nos horizontes 15 min, 1 h e 4 h; tempo até a MFE (em 4 h).
**Controle:** todas as barras do mesmo timeframe que **não** são evento, mesmo ano, sessão e contexto, com "direção" = sinal do corpo da barra. Diferença evento − controle (retorno em 1 h), com teste t nas médias diárias.
**Concentração:** fatia do resultado vinda do top 1% e top 5% dos eventos; maior dia.

### Execução (poucas variantes, fixas) — eventos M15
Saída igual para todas: stop 1,0×ATR(M15), alvo 1,5×ATR(M15) a partir da entrada, saída por tempo em 4 h, saída forçada antes de 16:50 NY e na sexta. Se stop e alvo caem no mesmo M1, conta o **stop** (conservador). Uma posição por vez por variante.
- **C (simples):** a mercado na abertura do M1 seguinte ao fechamento do evento M15.
- **A (entrada M5):** espera até 12 barras M5 (1 h). Continuação: primeira M5 que fecha a favor do evento **depois** de pelo menos uma M5 contra (recuo e retomada). Reversão (fade): primeira M5 que fecha contra o evento. Entra a mercado no M1 seguinte.
- **B (A + confirmação M1):** depois do gatilho de A, espera até 5 barras M1; entra quando um M1 fecha além da máxima (compra) / mínima (venda) da M5 gatilho. Senão, não entra.
- Cada variante em duas direções: **continuação** e **reversão (fade)**.
- Eventos M5: só a variante C (stop/alvo em ATR do M5, saída em 1 h), duas direções.

### Custos
- **Principal:** spread real bid/ask da Dukascopy + comissão US$16,80 por lote ida e volta (regra publicada US$20/milhão por lado com ouro ~4.200) = 0,168 por onça.
- **Sensibilidade:** comissão US$8 por lote (o que o testador da demo cobra) e spread "ECN" = metade do Dukascopy com piso 0,10.
- Decisões são tomadas **só no custo principal**.

### Testes e correção para múltiplas comparações
- Testes primários: 3 definições × 3 variantes × 2 direções (M15) = 18 + 3 definições × 2 direções (M5, var. C) = 6 → **24**.
- Testes condicionais: cada um dos 24 dentro de 4 contextos × 3 sessões = **288**.
- Família total = **312 testes**. Estatística: média do PnL líquido por dia (agregado por dia de negociação), teste t unilateral (>0) no IS. Correções **Benjamini-Hochberg (q=0,05)** e **Bonferroni (α=0,05)** sobre os 312.
- Mínimo de 150 operações no IS para um teste contar como candidato.

### Critérios de REPROVAÇÃO (qualquer um reprova)
1. Perde dinheiro no IS com o custo principal, ou não passa BH.
2. Fator de lucro no IS < 1,10.
3. Positivo em menos de 7 dos 9 anos do IS.
4. Depende de poucos: tirando o melhor 1% das operações fica ≤ 0, ou um único dia responde por > 10% do lucro.
5. Validação 2025 negativa ou fator de lucro < 1,05.
6. Só funciona num parâmetro: vizinhos = stop {0,75; 1,0; 1,25}×ATR × alvo {1,0; 1,5; 2,0}×ATR (8 vizinhos sem o central) + limiar do deslocamento ±20% (2) = 10 vizinhos; reprova se menos de 8 dos 10 ficam positivos no IS.
- Quem passar tudo vai a 2026 (uma vez) e, se ainda positivo, vira um EA mínimo em MQL5 testado no MT5 da demo (Strategy Tester apenas, Modelo 4, 30/10–13/11/2026).

### Log de tentativas
- T1: este pré-registro, rodado uma vez.
- T1 (execução): na primeira rodada um erro de unidade de tempo no código (microssegundos vs nanossegundos) gerou **zero eventos**; corrigido antes de qualquer número ser visto. Nenhuma regra mudou. A rodada válida é a T1 corrigida.
- Nenhuma outra tentativa foi feita. **2026 não foi aberto** (ninguém sobreviveu).

---

## Parte 2 — Resultados (15/11/2026, ~04:00 horário de Brasília)

Código: `code/desloc/` (`build_data.py`, `core.py`, `run.py`, `analyze.py`, `sens.py`). Saídas: `out/desloc/`.
Dados: 4,4 milhões de barras M1 reais (2016–2026), 920 mil barras de enchimento e fins de semana removidos.

### Resposta curta
**Não achei vantagem.** Depois de um deslocamento forte no ouro, o preço continua e devolve quase na mesma proporção.
Nenhuma das 312 combinações testadas ficou positiva com custo real. Nada passou na correção (BH e Bonferroni: **0 de 312**).
Por isso **não fiz robô** e **não abri 2026**. Resultado nulo, registrado.

### 1. O que o preço faz depois do deslocamento (estudo do caminho, 2016–2024)
Unidades em ATR do próprio timeframe (1 ATR M15 ≈ US$1 a 3 até 2024).

| Evento | Nº eventos | Continuou em 1 h | Retorno médio 1 h | Andou a favor em 1 h (MFE) | Andou contra em 1 h (MAE) | Tempo até o melhor ponto (4 h) |
| --- | --- | --- | --- | --- | --- | --- |
| M15 D1 barra grande | 5.592 | 47,7% | −0,02 ATR | 1,69 | 1,58 | 78 min |
| M15 D2 corpo forte | 6.725 | 47,3% | +0,01 ATR | 1,69 | 1,55 | 79 min |
| M15 D3 três barras | 4.920 | 47,0% | −0,02 ATR | 1,67 | 1,57 | 77 min |
| M5 D1 | 15.702 | 47,3% | −0,01 ATR | 2,72 | 2,58 | 85 min |
| M5 D2 | 20.069 | 47,0% | −0,04 ATR | 2,63 | 2,54 | 86 min |
| M5 D3 | 14.497 | 47,0% | −0,01 ATR | 2,67 | 2,50 | 83 min |

- **Comparado com barras comuns** (mesmo ano, sessão e contexto), a diferença em 1 h fica entre −0,01 e +0,01 ATR. Estatisticamente zero.
- O quanto ele anda a favor e contra é quase igual (MFE ≈ MAE). Isso quer dizer que **o deslocamento sozinho não diz a direção seguinte**.
- **Concentração:** somando o retorno de 1 h dos eventos M15 D2, o total é +38 ATR. Só o melhor 1% dos eventos soma **+634 ATR**; sem eles o total vira **−596 ATR**. Ou seja, qualquer "lucro" de continuação vem de pouquíssimos dias explosivos.
- **Contexto e sessão:** houve diferenças pequenas (ex.: M15 com tendência H1 **contra** o evento continuou um pouco mais que o controle, +0,07 ATR, p=0,03 sem correção; no M5 em compressão, +0,16 ATR, p=0,007). Com ~54 comparações nessa tabela, nenhuma passa a correção. Um padrão que **passa** a correção: no M5, **a favor da tendência H1**, o dia típico **devolve** (t ≈ −3,5), mas a média por evento é positiva por causa de poucos dias gigantes. É o mesmo padrão de concentração.

### 2. Operações executáveis (custo principal: spread real Dukascopy + US$16,80/lote)
Stop 1 ATR, alvo 1,5 ATR, saída em 4 h (M15) ou 1 h (M5). Resultado por operação de 0,01 lote (1 onça), 2016–2024.

| Variante | Continuação: média / fator de lucro | Reversão (fade): média / fator de lucro |
| --- | --- | --- |
| M15 C (a mercado), D1/D2/D3 | −0,48 / 0,64 · −0,47 / 0,64 · −0,56 / 0,61 | −0,49 / 0,63 · −0,48 / 0,63 · −0,45 / 0,67 |
| M15 A (entrada M5), D1/D2/D3 | −0,49 / 0,63 · −0,50 / 0,62 · −0,50 / 0,64 | −0,59 / 0,57 · −0,56 / 0,58 · −0,51 / 0,63 |
| M15 B (A + confirmação M1), D1/D2/D3 | −0,53 / 0,60 · −0,52 / 0,61 · −0,47 / 0,66 | −0,51 / 0,61 · −0,49 / 0,62 · −0,45 / 0,67 |
| M5 C, D1/D2/D3 | −0,52 / 0,40 · −0,52 / 0,40 · −0,52 / 0,42 | −0,46 / 0,45 · −0,46 / 0,45 · −0,45 / 0,47 |

- As 24 variantes principais perdem em **todos os 9 anos**. Acerto de 22% a 33% (precisaria de ~40% com alvo 1,5:1).
- Das 288 fatias (contexto × sessão), só **1** ficou com média positiva (M15 D3 A continuação, tendência contra, NY: +0,055/onça, fator 1,04, p=0,41). É ruído.
- **M1 não ajudou:** a confirmação M1 (B) não melhorou nada em relação à M5 (A) nem à entrada simples (C). Só cortou metade das operações.
- **Sem custo nenhum** (preço médio, comissão zero), o resultado bruto fica entre −0,08 e +0,06/onça (fator de lucro 0,92 a 1,07). **A vantagem bruta é praticamente zero**, e os custos (~US$0,45 por onça ida e volta) só a deixam negativa.
- **Custo mais barato** (spread "ECN" pela metade, piso 0,10, e comissão de US$8): continua negativo em todas as 24 (−0,18 a −0,35/onça, 0 anos positivos), e também em 2025.
- O único sinal bruto levemente consistente é **reversão no M5** (+0,03 a +0,04/onça bruto, 7–8 de 9 anos positivos). Ele é menor que o spread, então não dá para operar.

### 3. Critérios de reprovação
| Critério | Resultado |
| --- | --- |
| 1. Positivo com custo e passa BH | **Reprovado**: 0/312 passam BH, 0/312 passam Bonferroni |
| 2. Fator de lucro ≥ 1,10 | Reprovado (máx. 1,04, numa fatia pequena) |
| 3. ≥ 7 de 9 anos positivos | Reprovado (variantes principais: 0 de 9) |
| 4. Não depender de poucos | Reprovado no estudo do caminho (top 1% faz todo o resultado) |
| 5 e 6. Validação 2025 e vizinhos | Não aplicados: ninguém passou dos critérios 1–3 |
| Teste em 2026 e robô MT5 | **Não feito**: nenhum sobrevivente. 2026 continua inédito |

### O que ficou confirmado
- Deslocamento no M15/M5 do ouro, por si só, **não prevê** continuação nem devolução. É cara ou coroa com caudas grossas.
- Entrar mais tarde (M5) ou com confirmação M1 **não** transforma isso em vantagem.
- O "lucro" de seguir deslocamento depende de poucos dias explosivos. Isso explica backtests bonitos em curtos períodos que depois somem (mesmo padrão do H19).

### O que foi reprovado
- Continuação após deslocamento (24 variantes e 288 fatias).
- Reversão (fade) após deslocamento (idem).
- A ideia de que confirmação no M1 melhora a entrada depois dos custos.

### O que continua desconhecido
- Deslocamento junto com **notícia** (CPI, FOMC, payroll). Não separei notícias; podem ter comportamento próprio.
- Saídas diferentes (alvo longo, trailing) em busca das caudas grossas. Como o ganho vem de poucos dias, uma saída que "deixa correr" pode mudar a conta, mas seria uma **nova pesquisa**, com novo pré-registro.
- Timeframes maiores (H1/H4/D1), onde o custo pesa bem menos em relação ao movimento.
- Custo real da RoboForex no ouro: o spread da Dukascopy (mediana 0,24–0,67) pode ser maior que o da conta ECN (5–6 pontos no testador). Mas como o bruto já é ~zero, custo menor não salva.
