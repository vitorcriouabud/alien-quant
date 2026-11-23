# ALIEN LAB — Auditoria MT5 GoldTrend Donchian 720 com depósito fictício de USD 10 milhões

**Data:** 18/11/2026. **Fonte:** arquivo HTML `ReportTester-67316641(20261118-050429).html`, fornecido pelo usuário. O EA principal não foi alterado. Histórico XAUUSD M1, 01/08/2024–17/11/2026. Simulação no Strategy Tester.

## IMPORTANTE: o depósito não foi USD 100 mil

O HTML informa **Depósito Inicial = USD 10.000.000**, não USD 100.000. Isso faz os volumes variarem de ~2,58 a 22,19 lotes, e permite operações antes impedidas pelo lote mínimo com saldo USD 10.000. O resultado de USD 1,35 milhão é **fictício** e não pode ser projetado diretamente numa conta pequena.

Parâmetros congelados: Donchian 720 H1, `InpAllowShort=true`, ATR14 H1, stop 3×ATR, trailing 7×ATR, cooldown 120m, risco `InpRiskPercent=0.25`, spread máximo 0,8 unidades de preço, DD stop de novas entradas 10%, perda diária 3%, alavancagem 1:100, sem take-profit.

### Métricas oficiais do Strategy Tester

| Métrica | Valor |
|---|---:|
| Depósito fictício | USD 10.000.000 |
| Lucro líquido | +USD 1.352.140,29 (+13,5214%) |
| Profit Factor | 4,58 |
| Máximo drawdown de equity em US$ | USD 148.545,67 (1,31% do pico correspondente) |
| Maior drawdown relativo de equity | **1,33%** (USD 136.739,30 no ponto de máxima porcentagem) |
| Negociações fechadas | 41, 25 ganhadoras, 16 perdedoras |
| Qualidade do histórico | **3% de ticks reais** (aproximadamente 97% não confirmado como ticks reais) |
| Média de tempo em posição | 83:37:43 |
| Comissão somada | -USD 2.535,16 |
| Swap somado | -USD 75.364,72 |

**Observação técnica:** máximo DD monetário e máximo DD percentual podem ocorrer em momentos diferentes; não usar a porcentagem 1,33% para descrever o valor USD 148.545,67 diretamente.

### Reconstrução trade-a-trade de 82 deals / 41 posições

| Ano da abertura | N | Compras | Vendas | Ganhos | P/L líquido USD |
|---|---:|---:|---:|---:|---:|
| 2024 ago–dez | 8 | 7 | 1 | 5 | +184.982,48 |
| 2025 | 18 | 18 | 0 | 11 | +631.702,68 |
| 2026 (até 17/11) | 15 | 4 | 11 | 9 | +535.455,13 |
| **Total** | **41** | **29** | **12** | **25** | **+1.352.140,29** |

**Direção e regime:** compras acumuladas +USD 1.265.346,63; vendas +USD 86.793,66. Em 2026, somente 4 compras geraram +USD 480.717,51 e 11 vendas +USD 54.737,62. Isso mostra que parte relevante da rentabilidade observada provém de movimentos de alta, embora também haja trades vendidos positivos.

**Concentração:** o maior trade ganhou ~USD 274.632,24 (20,3% do total), os três maiores ~USD 529.584,25 (39,2%) e cinco maiores ~55,2% do resultado. Os 36 restantes ainda somaram +USD 605.172,81, mas a amostra é pequena.

**Risco inicial calculado:** usando 100 unidades XAUUSD por lote **inferidas das transações do relatório**, stop inicial e preços preenchidos, as operações observadas tinham aproximadamente USD 24.998 a USD 28.362 de perda nominal inicial (pré-gap), perto de 0,25% de saldo ao longo da curva. O R médio líquido é ~+1,246R por operação (total ~+51,10R). Esse R **não** é uma medição de risco máximo absoluto, pois gaps e slippage podem exceder o stop.

**Última operação:** venda 12/11/2026 foi **fechada pelo encerramento do teste** em 16/11/2026, e não pela lógica de stop; resultado líquido ~+USD 6.553,19. A métrica oficial inclui essa posição.

### Comparação com o teste do depósito pequeno

| Mesmo setup / mesmas datas (ago/2024–nov/2026) | Depósito USD 10.000 | Depósito USD 10.000.000 |
|---|---:|---:|
| Lucro líquido | +USD 392,54 (+3,9254%) | +USD 1.352.140,29 (+13,5214%) |
| Trades | 21 | 41 |
| Trades abertos em 2026 | **0** | **15** |
| PF | 3,43 | 4,58 |
| DD relativo de equity | 1,16% | 1,33% |
| Real ticks | 3% | 3% |

O aumento de lucro percentual **não representa retorno escalável garantido**: mudou o conjunto de operações efetivamente elegíveis, e há fortes diferenças de lote mínimo, arredondamento e regimes. Ambas as simulações têm **apenas 3% de ticks reais**, portanto a precisão de fills/trailing depende da modelagem.

### O que os logs mostraram

No teste anterior com USD 10 mil, mensagens frequentes `SEM ORDEM: lote minimo ultrapassa risco`, inclusive em 2026, significam que até `SYMBOL_VOLUME_MIN` excedia o orçamento de 0,25%. Essa barreira é intencional e **não deve ser desativada**. No teste de USD 10 milhões, as entradas em 2026 foram permitidas, comprovando que a estratégia tinha gatilhos que não podiam ser executados com saldo pequeno.

## Próximo passo e critérios

1. Testar **USD 100.000 FICTÍCIOS** na tela de configurações do Tester (confirmar que o próximo HTML mostra `100 000.00`; o teste aqui usou **10 000 000.00**). Conservar exatamente as mesmas datas, risco 0,25%, janela 720, stops 3/7 ATR e restante do preset; sem otimização.
2. Comparar 2024, 2025 e 2026 com 10k/100k/10M, em **% do capital, média por R e número de operações**, e documentar a taxa de sinais barrados por lote mínimo.
3. Procurar ticks Bid/Ask reais para obter mais do que 3% de cobertura. O resultado atual é histórico predominantemente modelado. Validar em período futuro ainda não usado (forward demo).
4. Separar 2026 **compras e vendas** e verificar robustez a lateralização/queda; não transformar a observação pós-hoc em filtro automaticamente.
5. Antes de qualquer demo forward: auditar execução e tamanho do lote em conta pequena, margem, spreads, swap, stop gaps e logs. Risco inicial não garante limite exato de perda.
6. **Não ativar conta real**. O EA experimental já tem trava REAL por projeto.

### Veredito

**O mecanismo Donchian 720 + trailing 7ATR gerou lucro simulado e também sinais em 2026, mas o desempenho não foi comprovado em ticks reais.** Este teste explora os limites de lote mínimo e é **uma simulação com capital irrealisticamente alto**, nunca uma projeção de renda para conta demo de valor pequeno.
