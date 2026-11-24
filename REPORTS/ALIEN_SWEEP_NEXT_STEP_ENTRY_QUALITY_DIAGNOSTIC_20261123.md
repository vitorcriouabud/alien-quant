# Fase seguinte do ALIEN: auditar entradas, sem "mexer nos .set"

**Fonte primária:** MT5 `ALIEN_SWEEP_100P_REAL_TICKS_20261123_222346.htm`, SHA256 `4b972c2cc327a8d102af4d96828488f5d3f40698ef85fb5400cf8e70cfe5028b`. Resultado reportado pelo MT5 com 100% ticks reais no período 2026-11-13 a 2026-11-22. Robô `ALIEN_V12_1_LAB_SWEEP_ONLY`, conta demo de USD 5.000.

## Achado objetivo (reconstrução das 49 posições)

- 49 operações; lucro líquido -USD 9,73; profit factor 0,60; máximo DD equity USD 13,37 (0,27%).
- 19 operações fechadas em até **10 segundos**, perda líquida conjunta **-USD 6,98**. São 71,7% do prejuízo do período.
- 7 TP: +USD 10,51 líquidos; 42 SL, incluindo trailing: -USD 20,24 líquidos.
- Antes das comissões: -USD 5,81; comissões totais: -USD 3,92.
- 5 dos 6 pregões foram negativos.
- Resultado é de **seis pregões** e não valida uma estratégia para uso real.

**Atenção:** duração da posição e resultado da saída só são observáveis depois da entrada. Não se deve criar uma regra retrospectiva que filtra "trades menores que 10 segundos", tampouco adiar stop para esconder perdas.

## Decisão de engenharia

**Pausar otimização de parâmetros com base somente nesses seis pregões.** Manter o robô executando apenas em demo/laboratório, com `AllowLiveRealTrading=false`, sem alterar a estratégia da `main`.

Próxima mudança de código — na branch de laboratório, sem afetar execução:
1. Registrar por **sinal de entrada**: direção, horário, spread efetivo, ATR, distância do stop, tamanho do sweep, distância/reclaim do nível, idade do sweep, score, M5/M15/H1, condições do candle M1, teto de risco e tipo do setup.
2. Registrar **mesmo quando o sinal for recusado**, com motivo codificado e estágio do funil.
3. Para posições enviadas, registrar MFE e MAE sobre bid/ask nos primeiros 5/10/30/60 segundos e até o fechamento, preço inicialmente solicitado e preço de fill, motivo de saída e custo líquido.
4. Preservar também journal, HTML do MT5, CSV e hash do `.ex5` compilado em cada teste automático.
5. Separar rigorosamente **período exploratório** de novos dados ou períodos futuros **fora da amostra** antes de aceitar qualquer melhoria.

**Status:** análise e especificação registradas; **instrumentação não foi implementada ou compilada**. Não declarar lucro, melhoria de PF, ou execução futura como comprovados.
