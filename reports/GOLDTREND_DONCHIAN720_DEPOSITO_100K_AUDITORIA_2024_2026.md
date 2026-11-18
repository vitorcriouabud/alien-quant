# ALIEN LAB — Auditoria do GoldTrend Donchian 720 com depósito fictício USD 100.000
**Data de registro:** 18/11/2026. **Fonte:** arquivo enviado pelo usuário `ReportTester-67316641(20261118-051859).html`. Apenas pesquisa e simulação.

## Parâmetros congelados (MT5)
- XAUUSD / M1, histórico efetivamente testado **01/08/2024 a 17/11/2026**.
- RoboForex-ECN, depósito **USD 100.000 fictícios**, alavancagem 1:100.
- Donchian 720 H1, ambos os lados; ATR14 H1; stop 3 ATR, trailing 7 ATR, sem alvo.
- 0,25% de saldo em risco inicialmente por trade, lote arredondado por passo; 120 minutos cooldown.
- Qualidade relatada pelo testador: **apenas 3% de ticks reais** (o restante não confirmado como histórico Bid/Ask real).
- O último negócio foi encerrado com motivo **`end of test`**, não por stop.

## Métricas oficiais do relatório
| Métrica | Valor |
|---|---:|
| Depósito fictício | USD 100.000 |
| Lucro líquido total | **+USD 11.917,75 (+11,91775% acumulado)** |
| Lucro bruto | USD 15.416,86 |
| Perda bruta | -USD 3.499,11 |
| Profit Factor | **4,41** |
| Máximo drawdown de equity | USD 1.295,11 (**1,26%**) |
| Trades / win rate | 41 / 25 vencedores (60,98%) |
| Tick real | **3%** |
| Swaps nas 41 operações | -USD 696,31 |
| Comissões nas 41 operações | -USD 23,59 |
| Média de tempo em posição | 83h37min43s |

O lucro é **acumulado** em ~27 meses, não mensal. O DD histórico não é limite garantido para uma conta real.

## Verificação dos 82 deals: 41 pares entrada/saída, sem par incompleto
| Ano da abertura | Trades | Compras | Vendas | Resultado líquido |
|---|---:|---:|---:|---:|
| 2024 (ago–nov) | 8 | 7 | 1 | +USD 1.829,89 |
| 2025 | 18 | 18 | 0 | +USD 5.717,88 |
| 2026 (até nov) | 15 | 4 | 11 | +USD 4.369,98 |
| **Total** | **41** | **29** | **12** | **+USD 11.917,75** |

**Direção:** 29 compras +USD 11.170,30; 12 vendas +USD 747,45. Em 2026, 4 compras +USD 3.937,75 e 11 vendas +USD 432,23. Vendas têm amostra mais fraca, mas não foram isoladamente negativas nesta simulação.

**Concentração:** cinco maiores trades geraram +USD 6.775,19 (~56,8% do lucro); outros 36 ainda +USD 5.142,56, PF desses outros ~2,47. Dos **21 meses que tiveram operação**, 15 positivos e 6 negativos. Não extrapolar para meses sem operações.

**R por operação:** inferindo multiplicador do XAUUSD de 100 unidades/lote com preços, volume e SL do relatório, média líquida **+1,246R**, soma **+51,10R**. R inicial considera stop financeiro estimado e não elimina risco de gap/slippage. Risco inicial das 41 operações ~USD 203,61 a USD 263,10 (comparável a 0,25% de capital variável), não há garantia de perda máxima de 0,25%.

**Operação final:** venda aberta 12/11/2026 e encerrada 16/11/2026, motivo `end of test`, resultado líquido +USD 59,18. Tratar separadamente se analisar apenas saídas por stop.

## Comparação controlada dos três depósitos (mesmo EA, mesmos inputs, mesmo histórico predominantemente modelado)

| Depósito fictício | N trades | Trades em 2026 | Retorno total | PF | Maior DD relativo de equity | Ticks reais |
|---:|---:|---:|---:|---:|---:|---:|
| USD 10.000 | 21 | **0** | +3,93% (USD 392,54) | 3,43 | 1,16% | 3% |
| USD 100.000 | **41** | **15** | +11,92% (USD 11.917,75) | 4,41 | 1,26% | 3% |
| USD 10.000.000 | **41** | **15** | +13,52% (USD 1.352.140,29) | 4,58 | 1,33% | 3% |

**Interpretação:** os testes de 100 mil e 10 milhões foram executados com *mesmo conjunto de 41 eventos*, sujeito a arredondamento diferente no tamanho de lote, e **não são dois testes independentes da estratégia**. Eles mostram que o lote mínimo bloqueou 2026 com 10 mil, e que a capacidade de executar os sinais depende de capital + especificação do símbolo + risco. Não aumentar o risco só para produzir operações.

## Fragilidade de evidência e próximos passos
1. **3% de ticks reais** é a lacuna principal. No modo `Cada tick baseado em ticks reais`, o MT5 usa ticks gerados a partir de candles M1 nas janelas sem histórico real. Não confundir grande número de ticks processados com histórico Bid/Ask confirmado (fonte oficial: https://www.metatrader5.com/pt/terminal/help/algotrading/tick_generation).
2. Solicitar no MT5 **Símbolos (Ctrl+U) > XAUUSD > Ticks > período > Pedido**, examinar data inicial disponível e exportar um intervalo com Bid/Ask. O feed é limitado à disponibilidade da corretora; histórico de candles longo não garante o de ticks (fonte: https://www.metatrader5.com/pt/terminal/help/trading/market_watch).
3. Repetir **somente um teste controlado com ticks reais disponíveis**, sem mudança de lógica: Donchian 720, stop 3ATR, trailing 7ATR, risco 0,25%, depósito fictício 100 mil, datas exatamente correspondentes aos ticks disponíveis; exportar HTML + Journal e verificar que a porcentagem real aumentou. Comparar trade-a-trade com a simulação modelada, não presumir que manterá PF.
4. Posteriormente, demo forward por várias semanas/meses, comparar slippage, custo real, liquidez, fills e estabilidade.
5. Para demo pequena, preservar recusa de ordens quando 0,01 lote ultrapassar risco. Avaliar símbolo com contrato menor ou volume mínimo menor disponível na própria corretora, sem forçar risco. Sem dinheiro real.

**Veredito:** o setup Donchian 720 teve expectativa líquida positiva nesta simulação em 2024 (parcial), 2025 e 2026, mas **não há validação independente de execução em ticks reais** nem garantia de desempenho futuro.
