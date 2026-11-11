# ALIEN V12.2 — hipóteses de scalping

Nova cópia baseada na V12.1 do commit `90cdaed30e82c4292120f90ba0e0eeccafa6b56f`.
A V12.1 e a V10.89 preservada não foram alteradas. Esta entrega é código experimental;
sem compilação MetaEditor, backtest ou evidência de rentabilidade nesta sessão.
Não contém todas as estratégias existentes: organiza as famílias discutidas em definições testáveis.

## Arquivos e instalação

- `MQL5/Experts/ALIEN_V12_2_SCALP_LAB.mq5`: EA completo novo.
- `MQL5/Include/AlienProfessor/ScalpHypotheses.mqh`: detector das seis hipóteses novas.
- `MQL5/Profiles/Tester/SCALP_H*.set`: 18 combinações (6 hipóteses × 3 alvos).

Copiar essas pastas para a pasta de dados do terminal de TESTE. Abrir o novo EA no
MetaEditor e compilar com F7. Não há EX5 fornecido. Não substituir o EA instalado na mesa.
No Tester, selecionar o novo EA, XAUUSD M1, ticks reais e depósito de US$5.000 para
comparação com a conta pretendida; conferir moeda, especificação do símbolo, comissões,
alavancagem e regras da mesa. Depósito simulado não recalibra limites monetários automaticamente.
Resetar inputs antes de carregar cada SET: os SETs são parciais e não substituem todos os parâmetros.

Os presets mantêm lote 0.01, teto percentual 0.25%, escalada desligada e os demais limites
da base (por exemplo, US$4 diário e US$5 total/semanal por padrão). São limites herdados,
não uma calibração aprovada para a mesa 5K. Os disjuntores podem encerrar cedo o teste.
Não aumentar o lote para forçar um sinal a gerar lucro; se o stop não couber, a ordem é recusada.
Comissão por lote precisa ser configurada conforme a corretora: zero significa que o filtro
não inclui comissão. Slippage futuro não é coberto pelo filtro de custo.

## Modos

`ScalpHypothesisMode=0` mantém o seletor original, com magic próprio 802220.
Os IDs 1..5 já existentes continuam na base: sweep, BOS/reteste, momentum, FVG e OB.
Eles continuam sujeitos às flags originais; não foram todos ativados.
Os modos 6..11 selecionam individualmente uma hipótese nova; 12 combina novas hipóteses
com fallback para a base. Não usar modo 12 como comparação independente.

| Modo | Hipótese | Definição observável (compra; venda simétrica) |
|---|---|---|
| 6 | Impulso/correção | Corpo de impulso >=0.6 ATR, correção contrária <=metade do corpo sem perder mínima, fechamento seguinte rompe máxima da correção |
| 7 | Compressão/rompimento | Faixa das oito velas anteriores <=1.5 ATR; fechamento rompe máxima, corpo >=0.4 ATR; não exige reteste |
| 8 | Falso rompimento | Fechamento anterior abaixo do fundo de uma faixa de oito velas; fechamento seguinte recupera o fundo e volta ao interior |
| 9 | Borda lateral | Faixa de 1.5..4 ATR, deslocamento entre fechamentos antigos <=25% da faixa; toque próximo ao fundo e fechamento comprador ainda abaixo do meio |
| 10 | Reação FVG | Três velas fechadas formam lacuna >=0.1 ATR com impulso >=0.5 ATR; vela seguinte toca lacuna e fecha acima da borda superior |
| 11 | Reação OB | Vela contrária seguida de corpo >=0.6 ATR que supera sua máxima; uma vela fica afastada; a seguinte revisita e fecha acima da máxima |

São definições próprias para pesquisa, não certificação de modelos ICT ou prova de fluxo institucional.
Cada padrão novo exige 12 velas M1 fechadas, fornecidas a partir do shift 1.
A entrada usa a cotação atual, após a confirmação fechada, e aceita distância máxima
de 0.25 ATR do último fechamento. Logo, não simula uma entrada anterior à confirmação.
Os parâmetros do detector são fixos nesta versão para limitar otimização excessiva.

Todas as hipóteses continuam passando pelos gates legados de ticks, direção, score,
sessão, notícias, margem e risco. Não são seis estratégias independentes de contexto.
O stop vai além da invalidação, com buffer de max(2 pontos,0.06 ATR), respeitando mínimo
do broker. Se o risco exceder orçamento monetário ou percentual, recusa; não aperta o stop.
O alvo novo deve superar 3 vezes o custo estimado em pontos (spread+comissão configurada)
e uma distância mínima operacional. Isso filtra custo, não prova vantagem.

`ScalpLabTargetR`: razão nominal alvo/stop exclusiva dos novos padrões (0.25..5).
Presets comparam 0.75R, 1R e 1.5R. R nominal não inclui custos e não é retorno garantido.
`ScalpLabFixedExit=true`: posições com comentário ALIENLAB usam SL/TP fixos; não recebem
BE/trailing/colheita/timeout do runner. Emergência sem SL e disjuntores da conta continuam ativos.
False permite comparar o mesmo sinal com o runner original em execução separada.

## Registro e limitações

Relatório existente ampliado para IDs 1..11: quantidade, vitórias, resultado líquido e sinais
que chegaram à tentativa de entrada. Esses contadores não contam todos os padrões brutos
ocorridos no mercado. Nome e explicação aparecem no painel e eventos de entrada.
Deduplicação por ID e horário da vela executada, em memória durante a sessão.
Reiniciar o EA reinicia essa memória; não é deduplicação persistente.
Modo 12 usa prioridade 6→11 e depois seletor legado: não abre uma ordem para cada hipótese;
se a primeira escolhida falhar no risco/custo, não testa as seguintes no mesmo tick.
Não isola posições em conta netting quando outros EAs operam o mesmo símbolo; usar terminal/conta
de teste separados. Não anexar simultaneamente presets com o mesmo magic.

## Protocolo de comparação

1. Referência: modo 0 e parâmetros congelados; novo magic significa histórico/estado próprios.
2. Uma combinação de padrão e alvo por backtest, com os mesmos dados, custos e limites.
3. Registrar número de trades, lucro líquido, PF, drawdown de equity, pior dia, custos e recusas.
4. Escolher parâmetros somente no período de desenvolvimento; congelar antes do período seguinte.
5. Conferir em dados seguintes e demo. Não somar resultados de testes isolados como se fossem
   carteira executável; sinais se sobrepõem e usam a mesma margem/orçamento.
6. Comparar saída fixa vs runner em testes separados. Não escolher somente pelo acerto:
   alvo menor que stop exige maior acerto e mais sensibilidade aos custos.

Não existe número mágico de trades que comprove robustez. Pesquisar 18 combinações já cria
risco de escolher um vencedor por acaso; preservar um período posterior não usado na seleção.

## Verificação nesta entrega

`python tests/test_scalp_hypotheses.py` executa o detector MQL real com shim C++ mínimo,
compilado com g++ e avisos como erros. Testa seis padrões em compra/venda, ausência de reação,
histórico insuficiente, direção/ATR inválidos e horários incorretos. Verifica pontos de integração.
Isso NÃO compila o EA em MQL5, nem testa execução do broker ou resultado financeiro.
MetaEditor, ticks reais e demo continuam pendentes.
