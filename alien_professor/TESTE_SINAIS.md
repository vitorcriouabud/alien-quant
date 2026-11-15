# TESTE DOS SINAIS DO ALIEN PROFESSOR (pré-registro)

Escrito em 15/11/2026, às 02:33 (horário de Brasília, UTC−3), ANTES de rodar qualquer teste.
Depois de ver resultado, **não mudo nenhuma regra nem número**. Se eu errar algo no código, corrijo o erro de código e digo aqui.

## O que é testado
As mesmas regras do indicador, com os parâmetros padrão dele (nada otimizado):
- Estrutura no M5 (barras de bid), tendência no H1, swing de 3 barras de cada lado, ATR = média simples do range verdadeiro de 14 barras fechadas.
- Tendência H1: EMA200 (inclinação: e[1]−e[6] > 0,05·ATR_H1), lado do preço, últimos 2 topos/fundos do H1 (swing 3). Soma ≥ 2 = alta, ≤ −2 = baixa.
- Níveis: máx./mín. de ontem (dia do servidor), da semana passada, Ásia (01–09h servidor), Londres (09–15h), NY (16–23h) da última sessão terminada, topos/fundos iguais no M5 (tolerância 0,10·ATR, ≥ 6 barras de distância).
  Hora do servidor = hora de Nova York + 7 (RoboForex).
- Varrida: pavio passa do nível e a barra fecha de volta. Vale 36 barras M5.
- BOS: fechamento além do último topo/fundo confirmado. Vale 24 barras.
- FVG: buraco de 3 barras ≥ 0,10·ATR, não preenchido, nascido nas últimas 30 barras, OU preço dentro de FVG aberto do H1/M15 a favor.
- Volume forte: volume de ticks > 2× média das 20 anteriores, vela a favor, nas últimas 12 barras.
- Horário bom: 10–13h e 16–19h do servidor.
- Espaço até o alvo ≥ 2R.
- Nota: tendência 2 + varrida do lado oposto 2 + BOS 2 + FVG 1 + volume 1 + horário 1 + alvo ≥ 2R 1 = 10.
- Plano: entrada no meio do FVG (ordem limitada, vale 60 minutos; sem FVG = a mercado na abertura do próximo minuto).
  Stop além da varrida (ou do swing mais próximo) + 0,15·ATR + spread. Alvo = próxima liquidez intacta do outro lado; sem alvo → 2R.
  Saída por stop, alvo, 8 horas depois da entrada ou às 16:50 de NY (o que vier primeiro).

## Dois conjuntos de eventos (definidos antes)
- **A (todas as notas):** cada barra M5 em que nasce um BOS. A nota da direção do BOS é medida no fechamento dessa barra. Serve para a tabela por faixa de nota (0–4, 5–6, 7–8, 9–10).
- **B (o alerta de verdade):** a nota de uma direção cruza para ≥ 7 (estava abaixo na barra anterior). É exatamente quando o indicador mostra a seta e manda alerta.

## Custos (ouro)
- Spread real bid/ask dos dados M1 (Dukascopy), comissão US$ 16,80 por lote ida e volta (0,168 por onça), swap compra −5,5%/ano e venda +1,7%/ano se passar a noite (quase nunca, por causa da saída às 16:50 NY).
- Execução no M1: stop é checado no mesmo minuto da entrada (pior caso), alvo só a partir do minuto seguinte.

## Dados e períodos
- XAUUSD M1 bid/ask 2016–2025. **2016–2024 = teste principal (IS)**, **2025 = validação**. **2026 não é aberto** (o código corta antes de 01/01/2026).
- Volume: volume de ticks Dukascopy por minuto, somado no M5.

## Medidas
Por faixa de nota: número de trades, % de acerto, R médio (lucro ÷ risco, já com custo), PF, t (de somas diárias em R), máximo rebaixamento em R, resultado por ano.

## Critério para dizer "os sinais têm vantagem" (escrito antes)
Para a faixa 7–10 (conjunto B): t ≥ 3,0 no IS (o projeto já tentou muita coisa), PF ≥ 1,15, ≥ 100 trades, ≥ 6 de 9 anos positivos, e 2025 positivo.
Também espero que a nota "funcione": R médio crescendo das faixas baixas para as altas. Se não crescer, a nota não separa nada.

## Índices (versão rápida, aproximada)
US500 (Dukascopy M5 bid, sem M1, sem volume → o ponto de volume nunca conta, nota máx. 9), spread fixo 0,6 pt (dobrado 09:30–09:35 NY), comissão 0, swap não cobrado (saída no mesmo dia). Mesmas regras, simulação em barras M5 (stop antes do alvo na mesma barra). Só informativo.

---

# RESULTADO (escrito depois de rodar, sem mudar nenhuma regra)

Rodado às 02:36 (Brasília). Código: `teste/sinais.py`, `teste/run_ouro.py`, `teste/run_idx.py`, `teste/report.py`. Trades salvos em `teste/*_trades.pkl`.
R = lucro ÷ risco planejado, já com spread e comissão. −1R = bateu o stop. t = estatística t das somas diárias.

## Resposta curta
**Os sinais não têm vantagem. Seguir a seta sozinha perde dinheiro, no ouro e no US500, em todos os anos de 2016 a 2025.**
E a nota não separa nada: nota 7–8 perde igual à nota 0–4. Nenhum critério do pré-registro passou.

## Ouro (XAUUSD) - conjunto B = as setas do indicador (nota cruza para ≥ 7)
| Período | Faixa | Trades | Acerto | R médio | PF | t | Pior sequência (R) |
|---|---|---|---|---|---|---|---|
| 2016–2024 | 7–8 | 12.610 | 28,9% | −0,32 | 0,58 | −20,1 | −4.068 |
| 2016–2024 | 9–10 | 248 | 32,7% | +0,02 | 1,03 | +0,2 | −23 |
| 2016–2024 | **7–10** | **12.858** | **28,9%** | **−0,32** | **0,59** | **−19,7** | −4.062 |
| 2025 | 7–10 | 1.448 | 28,7% | −0,22 | 0,69 | −4,3 | −327 |

Por ano (nota ≥ 7, soma em R): 2016 −493 · 2017 −363 · 2018 −636 · 2019 −499 · 2020 −432 · 2021 −446 · 2022 −258 · 2023 −403 · 2024 −530 · 2025 −321. **0 de 10 anos positivos.**

## Ouro - conjunto A (todo BOS do M5, por faixa de nota)
| Faixa | Trades 2016–24 | Acerto | R médio | PF | t | 2025: trades / R médio |
|---|---|---|---|---|---|---|
| 0–4 | 9.478 | 37,1% | −0,27 | 0,54 | −19,8 | 1.008 / −0,15 |
| 5–6 | 12.025 | 36,3% | −0,26 | 0,59 | −21,4 | 1.392 / −0,11 |
| 7–8 | 4.698 | 35,4% | −0,25 | 0,63 | −12,2 | 545 / −0,24 |
| 9–10 | 502 | 26,5% | −0,26 | 0,67 | −3,4 | 67 / −0,03 |

A nota mais alta não melhora o resultado (−0,27 → −0,26 → −0,25 → −0,26).

Diagnóstico (não muda nada, só explica): mesmo **sem comissão** o R médio fica em −0,17 (conjunto A) e −0,20 (B). Ou seja, não é só custo: a entrada não acerta a direção melhor que o acaso, e o spread num stop curto (risco mediano de 2,0–2,5 pontos no ouro) come o resto.
O único pedaço positivo é a nota 9–10 do conjunto B (+0,02R, t 0,2, 248 trades): é ruído e caiu para −0,10R em 2025.

## US500 (versão rápida, aproximada: barras M5, sem volume, spread fixo 0,6)
| Período | Conjunto / faixa | Trades | Acerto | R médio | PF | t |
|---|---|---|---|---|---|---|
| 2016–2024 | B 7–10 (setas) | 8.257 | 29,3% | −0,17 | 0,76 | −7,9 |
| 2016–2024 | B 9 (máximo sem volume) | 142 | 27,5% | +0,12 | 1,16 | +0,6 |
| 2025 | B 7–10 | 1.123 | 29,2% | −0,13 | 0,82 | −2,2 |
| 2016–2024 | A 0–4 / 5–6 / 7–8 / 9 | 9.372 / 10.258 / 3.393 / 242 | | −0,17 / −0,17 / −0,18 / +0,06 | | |

Por ano (setas, soma em R): 2016 −119 · 2017 −214 · 2018 −135 · 2019 −217 · 2020 −183 · 2021 −52 · 2022 −101 · 2023 −130 · 2024 −254 · 2025 −145. **0 de 10 anos positivos.**

## O que isso quer dizer pra você, Vitor
- O indicador é útil pra **ler** o gráfico (onde está a liquidez, se varreu, onde está o FVG, qual o lote pra $45, se é hora de parar). Ele **não** é uma máquina de sinal.
- A seta com nota ≥ 7 não pode ser seguida às cegas: nos 10 anos ela perdeu sempre.
- Nada aqui foi otimizado depois de ver o resultado. Mudar os números agora pra "ficar positivo" seria enganar você (é o mesmo erro do V11).

## Limitações honestas do teste
- Dados Dukascopy, não RoboForex (spread parecido no ouro; nos índices o spread foi fixo).
- Pequenas diferenças do indicador: o FVG usa o ATR do momento em que nasceu (o indicador usa o ATR atual); o preenchimento do FVG H1/M15 é checado no M5; os bloqueios de disciplina e notícia não entram (o teste opera todos os sinais).
- Stop checado no mesmo minuto da entrada (pior caso). Ordem limitada que não é tocada em 60 minutos é cancelada.
- O swap quase não aparece porque toda operação fecha antes das 16:50 de NY.
