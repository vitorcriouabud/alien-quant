# Livro de regras: Lógica do Preço, sessões e confluências

Documento de trabalho do Alier / ALIEN PROFESSOR. Serve para leitura e para o laboratório. Não é prova de lucro e não altera o código do robô.

## 0. Fontes e aviso honesto

- **Fonte principal:** "Estudos e anotações sobre a lógica do preço" (João Batista de Almeida, 2022), a partir do curso do Prof. Rodrigo Carvalho, com trechos de canais no YouTube. 223 páginas, muitas só com gráfico.
- **Sessões:** "ICT Smart Money Concepts" (The Prop Trader, jul/2022). O segundo PDF é a mesma cópia.
- **Candlesticks:** o arquivo "J2P and P2J Ver 1" é o livro *Candlestick*, Carlos Alberto Debastiani, Novatec, 2007. É livro de velas para ações, não para ouro.
- **Psicologia:** o PDF Canon de 115 páginas é *Trading: atitude mental do trader de sucesso*, versão portuguesa de *Trading in the Zone* (Mark Douglas, Bookout). Não é método de entrada.
- **"A Ciência de Ficar Rico"** (Wallace D. Wattles): mentalidade. Não entra aqui.

**Adaptação obrigatória.** Nessas anotações a Lógica do Preço foi ensinada para opção binária: CALL ou PUT na mesma vela ou na seguinte, nos primeiros 10 a 15 segundos. No ouro (XAUUSD) no MT5 isso não vale. A regra vira: marcar a região, esperar o toque e a rejeição (ou o reteste depois do rompimento), stop atrás da estrutura, alvo na próxima marca, risco definido. "É batata" e "as chances sobem 100%" são hype, não regra.

Cada regra abaixo está marcada **mensurável** (dá para programar e testar) ou **discricionária** (depende de olho, contexto ou opinião).

## 1. Vocabulário curto

- **Comando:** primeira vela de um movimento novo, **sem pavio no lado da abertura**. Alta (verde): careca embaixo. Baixa (vermelha): careca em cima. Pode nascer em reversão, rompimento ou fracionamento.
- **Vela de força:** no topo ou fundo, tem pavio no lado da abertura (impulso). Também: corpo pequeno que rompe máximas/mínimas ou uma divisão de taxa.
- **Comando nível 1** (variação, "controle de região", "candle mágico"): careca dos dois lados.
- **Comando nível 2:** o comando comum (careca só na abertura).
- **Comando nível 3** (expirado, fim de taxa, fechamento de preço): careca no fechamento. O material lê como exaustão. Em tendência, costuma vir mais uma vela da mesma cor antes da reversão.
- **Taxa dividida:** o preço começa ou termina: um comando interrompe a continuidade e fecha um ciclo. Velas da mesma cor. A mais forte, segundo o texto, é fechamento de preço + comando único.
- **Divisão de preço:** duas velas de força com pavio dos dois lados.
- **Lote:** velas da mesma cor. Macro = impulsão e correção numa região, até romper. Micro = duas ou mais. Nano (lote solitário) = uma vela de cor contrária no meio da sequência, depois o fluxo volta.
- **Nova alta / nova baixa:** o primeiro pavio novo depois que o preço rompe uma zona de pavio ou um lote. Não é gatilho sozinho; é confluência.
- **Projeção:** o pavio do lado oposto à direção da vela (embaixo numa alta = projeção de baixa; em cima numa baixa = projeção de alta).
- **Nova posição:** a vela que confirma o movimento novo. Em geral é a **segunda vela** do movimento.
- **Indecisão:** o corpo atual fecha dentro do pavio anterior, sem nova alta ou nova baixa. Dupla = uma vela assim. Tripla = duas.
- **Transferência:** pavios de velas da **mesma cor** se ligam; trava, retrai e **não** muda de cor.
- **Desistalação:** pavios de **cores diferentes** se ligam; trava, retrai e **muda de cor**. Pavios de cima alinhados, sem nova alta, tendem a cair (e o inverso).
- **Defesa:** região marcada (em especial a abertura da vela) onde o preço toca e volta, depois de reversão confirmada.
- **Ataque:** a "negativação" no começo da vela: abre e vai contra a direção anterior.

## 2. Estrutura e marcações

**R1 (mensurável).** Classificar cada vela M1/M5: comando N1, N2, N3, vela de força, ou comum. Tolerância de pavio: até 1 tick ou uma fração pequena do corpo (definir no laboratório, por exemplo 10% do corpo), porque no ouro o "careca perfeito" é mais raro que no gráfico didático.

**R2 (mensurável).** Marcações padrão:
- Comando N1: abertura, 50% do corpo e fechamento.
- Comando N2 (único): abertura e 50%.
- Comando N3 (expirado): 50% e fechamento.
- Vela de força: abertura, 50% e fechamento.
- Taxa dividida: a quebra (junção) e o pavio, se houver.
- Taxa dividida de topo ou fundo: a quebra e os 50%.
- Divisão de preço: a quebra e os pavios das duas velas de força.
- Pavio longo: a ponta e os 50% do pavio.
- Nova alta/baixa + nova posição: o pavio novo e a projeção da nova posição, se houver.
- Dupla/tripla posição: pavios + quebra.
- Nano-lote: o corpo (e o pavio, se for preciso).
- Primeira vela da reversão, depois de confirmada: o corpo.

**R3 (mensurável).** Níveis da taxa dividida:
- Nível 1: dois comandos N1 (os dois carecas dos dois lados).
- Nível 2: comando expirado + vela de força.
- Nível 3: vela de força + comando único (ou o contrário).
- Intermediária: comando expirado + comando único.
Atoalho do material: comando N1 monta taxa N1; comando N2 monta taxa N3; comando N3 monta taxa N2. Taxa de topo/fundo N1 = as duas velas do extremo sem pavio; N2 = deixam pavio.

**R4 (mensurável).** Rompimento de lote só conta se o **corpo** (não só o pavio) romper a vela que abriu o lote.

**R5 (discricionária, com parte mensurável).** Comando em topo ou fundo é tratado como mais forte do que comando no meio da pernada. Isso é opinião do curso; o laboratório pode comparar os dois casos.

**R6 (discricionária).** O material chama o comando N1 de "candle mágico" e diz que "é batata". Isso é hype. O padrão (marubozu / careca dos dois lados) é mensurável; a promessa de acerto não é.

## 3. Liquidez, pavios e confluência

**R7 (mensurável como modelo, não como verdade).** Pavio de baixo = demanda de compra. Pavio de cima = demanda de venda. Demanda rompida = continuidade. Região de venda rompida passa a ser região de compra (e o contrário). As anotações chegam a discordar da nomenclatura original do curso e fecham nessa leitura, que é a mais comum.

**R8 (mensurável).** Nova alta / nova baixa: (1) achar a zona de pavio ou o lote; (2) ver o rompimento; (3) ver se a vela do rompimento deixou um pavio novo na direção do movimento. Só isso não entra. Serve para validar a análise.

**R9 (mensurável).** Confluência forte do material: alinhamento nova alta + nova posição, ou nova baixa + nova posição. Preço **acima** do alinhamento de alta = leitura de compra. Preço **abaixo** do alinhamento de baixa = leitura de venda. Marca a defesa, espera o preço buscar a marca.

**R10 (mensurável).** Em indecisão (corpo preso no pavio anterior, dupla ou tripla posição), não seguir direção. Esperar uma vela de força romper a posição. Quando o preço voltar nessa região, tratar como defesa forte.

**R11 (mensurável).** Desistalação e máximas/mínimas iguais (pavios alinhados) são zona de liquidez. Transferência (mesma cor, sem virar) é continuação possível; desistalação (muda de cor) é reversão possível. Precisa de regra de stop e alvo para testar; o padrão sozinho não opera.

## 4. Cenário, entradas, stop e alvo (ouro, não binária)

**R12 (mensurável, com filtro visual residual).** O preço faz lateral (topos e fundos), tendência ou consolidação apertada. Para este método, o material prefere topos e fundos claros. Tendência serve melhor para operar fluxo. Consolidação apertada: o autor das anotações recomenda não operar. "Pernada de 60 graus não trabalha retração, só 45 graus" é discricionário e difícil de medir com justiça; se testar, definir o ângulo de forma explícita.

**R13 (mensurável, adaptada).** Três gatilhos, reescritos para XAUUSD com stop:
1. **Retração (pullback):** a vela atual busca a marca e é rejeitada (fecha de volta para o lado da defesa). Não usar janela de 10 a 15 segundos.
2. **Reversão:** a vela fecha com o corpo travado na marca (simetria). A entrada fica para a rejeição da vela seguinte, se ela buscar a marca.
3. **Rompimento (throwback):** a vela fecha rompendo a marca. Não perseguir. Esperar o retorno (reteste) da marca.
Se a vela abrir em gap contra a tese, o material manda abortar. No ouro M1 isso é raro (mais comum na abertura da semana).

**R14 (mensurável).** Stop: atrás do outro lado da estrutura que definiu a marca (comando, lote, pavio ou taxa dividida). Se for taxa de topo/fundo nível 2, o material prefere esperar a ponta ou os 50% do pavio, para ter margem. Alvo: a próxima marca, a máxima/mínima anterior, ou no mínimo 1:1 depois do custo. Se o alvo for menor que o risco, não entrar. Não usar os "15 a 50 pips" do texto de ICT: isso é câmbio, não ouro.

**R15 (discricionária).** "Dica de ouro": se a vela que rompe o comando está conectada à anterior, o material autoriza entrar na abertura, por continuidade. É agressivo. Só faz sentido testar com stop curto atrás da conexão e amostra honesta.

**R16 (mensurável, filtro).** Não tratar padrão isolado no M1 como ordem. Pedir alinhamento com um viés maior (pelo menos M15/H1 ou o dia). Sem isso, o ouro M1 gera ruído demais.

## 5. Sessões e kill zones (horário de Brasília)

O PDF de ICT lista os horários em **hora de Nova York** (está escrito EST, mas é o relógio de NY). Brasília está o ano todo em UTC-3 (não tem horário de verão desde 2019). Nova York muda:

- **Inverno dos EUA (EST, UTC-5):** Brasília = NY + 2 horas. Em 2026, isso vale de 1º de novembro em diante, e antes de 8 de março.
- **Verão dos EUA (EDT, UTC-4):** Brasília = NY + 1 hora. Em 2026, de 8 de março a 1º de novembro.

| Sessão | Hora de NY | Brasília no inverno dos EUA | Brasília no verão dos EUA |
|---|---|---|---|
| Faixa da Ásia (kill zone) | 20:00–00:00 | 22:00–02:00 | 21:00–01:00 |
| Abertura verdadeira do dia (TDO) | 00:00 | 02:00 | 01:00 |
| Frankfurt | 02:00–03:00 | 04:00–05:00 | 03:00–04:00 |
| Londres abertura (kill zone) | 02:00–05:00 | 04:00–07:00 | 03:00–06:00 |
| Sessão de Londres | 03:00–11:00 | 05:00–13:00 | 04:00–12:00 |
| Nova York abertura (kill zone, câmbio à vista) | 07:00–10:00 | 09:00–12:00 | 08:00–11:00 |
| Sobreposição Londres / NY | 08:00–11:00 | 10:00–13:00 | 09:00–12:00 |
| NY manhã (futuros, OTE) | 08:30–11:00 | 10:30–13:00 | 09:30–12:00 |
| Dados das 08:30 NY / macro do algoritmo | 08:30 | 10:30 | 09:30 |
| Abertura do pregão de NY | 09:30 | 11:30 | 10:30 |
| Londres fechamento (kill zone) | 10:00–11:00 | 12:00–13:00 | 11:00–12:00 |
| London Fix | 10:57:30–11:02:30 | 12:57:30–13:02:30 | 11:57:30–12:02:30 |
| Almoço de NY | 12:00–13:00 | 14:00–15:00 | 13:00–14:00 |
| NY tarde | 13:30–16:00 | 15:30–18:00 | 14:30–17:00 |
| Fechamento NYSE / CME | 16:00 | 18:00 | 17:00 |
| Fechamento do câmbio à vista | 17:00 | 19:00 | 18:00 |

O PDF traz "CBDR 14:00 / 16:00–20:00" de forma ambígua. A faixa clássica de ICT para Central Bank Dealers Range é **14:00–15:00 NY** (16:00–17:00 no inverno de Brasília; 15:00–16:00 no verão dos EUA). Não tratar o trecho confuso como horário exato.

**R17 (mensurável).** No ouro, priorizar Londres abertura, a sobreposição e NY abertura. A Ásia, na maior parte dos dias, consolida e deixa a faixa que o dia pode caçar. O almoço de NY costuma ser mais fraco.

**R18 (discricionária, com partes mensuráveis).** O material de ICT diz: a sessão de Londres tem a maior chance de marcar a máxima ou a mínima do dia e de fazer o movimento grande. Se o viés do dia é de alta, procurar a mínima do dia em Londres; se é de baixa, a máxima. Nova York ou continua Londres ou inverte; os dados das 08:30 NY pesam muito no ouro. Se Londres concordou com o viés do dia, procurar continuação na abertura de NY. O fechamento de Londres costuma recuar da máxima ou da mínima do dia. Nada disso está provado no XAUUSD; são hipóteses (ver HIPOTESES_LAB.md).

**R19 (mensurável).** OTE (entrada ótima de ICT): retração de 62% a 79% do swing (o texto destaca 70% como OTE, 50% como equilíbrio). Alvos sugeridos no Fibonacci do swing: 0 (origem), -0,27, -0,62 e -1 (simetria). Só com viés do tempo maior e dentro de kill zone. Matriz resumida: acima de 50% do range recente = prêmio (procurar venda); abaixo = desconto (procurar compra). FVG (//gap de três velas), order block e máximas/mínimas iguais são zonas objetivas; "smart money" como intenção é discricionário.

**R20 (mensurável como rotina, não como privilégio).** Leitura de cima para baixo: semana (para onde a liquidez pode ir), dia (viés e zonas), H1/M15 (zona e horário), M5/M1 (entrada). Vitor opera ouro no M1; o M1 sozinho não define o viés.

## 6. Padrões de vela (Debastiani) e atitude (Douglas)

**R21 (mensurável, só os clássicos).** Para eventual teste no ouro, só padrões com regra clara, **em topo ou fundo de um swing**, não no ruído do M1: engolfo, martelo / estrela cadente, linha de perfuração / nuvem negra, pinça, doji no extremo, três soldados / três corvos. Padrões raros (bebê engolido, buda triplo, etc.) ficam de fora. O livro é de ações, não de XAUUSD.

**R22 (discricionária — atitude, não entrada).** De *Trading in the Zone*: o trader não precisa acertar *esta* operação; precisa executar um plano com risco definido, pensando em série. Stop definido antes de entrar libera a cabeça. Cada momento do mercado é único; o padrão não "deve" funcionar só porque aparece. Isso não se testa como seta. O livro de Wattles também não.

## 7. O que é hype ou não testável

- "Candle mágico é batata", "chances sobem 100%", alvos em pips de câmbio aplicados ao ouro.
- Q-learning, "algoritmo interbancário" e linguagem de smart money como prova de intenção institucional.
- Entrada nos 10 a 15 segundos da vela, CALL/PUT na mesma vela, e qualquer regra de expiração binária.
- Psicologia e mentalidade (Douglas, Wattles): úteis para disciplina, inúteis como gatilho.
- Ângulo de 45° vs 60°, "força" subjetiva da vela e leitura de "quem abriu / quem fechou" o pavio, se não houver definição numérica.
- Volume do ouro no MT5 é contagem de ticks, não volume real da bolsa. Não usar como prova de "demanda institucional".
