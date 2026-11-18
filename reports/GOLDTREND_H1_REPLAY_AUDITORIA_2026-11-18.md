# ALIEN LAB — GoldTrendM1: replay H1 e auditoria (18/11/2026)

> **Pesquisa exploratória, sem autorização para dinheiro real.**
> Fonte: histórico XAUUSD H1 enviado pelo usuário (`XAUUSD_H1_202001021000_202611172300.csv`) e código original `GoldTrendM1.mq5` enviado ao chat.
> **Não é backtest fiel do EA**, porque o robô real sinaliza e executa no M1.

## Método reproduzido no replay

- **H1:** 40.547 barras, 02/01/2020 10h a 17/11/2026 23h; dados MT5, horário do servidor sem fuso confirmado.
- Sinal de compra: fechamento H1 acima da máxima das N H1 anteriores; venda: abaixo da mínima das N anteriores, N=192/288/480/720. 
- Entrada na **abertura do H1 seguinte** (aproximação da entrada M1, não equivalente).
- ATR14 suavizado no H1, definido no fechamento do candle de sinal.
- Stop inicial 3x ATR14. Trailing fixado em 7x ATR14 da entrada, atualizado somente após fechamento H1, pelo extremo das barras H1.
- Sem take-profit. A posição permanece aberta durante finais de semana; no retorno do mercado, stop ultrapassado é executado no **open** (não ao stop ideal).
- Stop é verificado antes da atualização do trailing; não há uso de barras futuras na decisão.
- Só uma posição por janela, com pausa aproximada de 2 candles H1 depois da saída. Janelas são independentes e, se usadas juntas, altamente correlacionadas.
- Custos hipotéticos totais: **1,50 / 3,00 / 5,00 USD de preço XAUUSD por entrada+saída** (não contratos, não pontos e **não comissão verificada**).
- Resultado expresso em R = lucro/prejuízo (após custo) dividido pela distância do stop inicial. Não é retorno de capital real.
- O primeiro replay fechava as operações diante de grandes lacunas temporais e era inadequado para a lógica de seguimento de tendência; este replay **substitui** aquele resultado.

## Resultados por janela com custo 1,50 por operação completa

| N H1 | Trades | Média líquida R | Profit Factor em R | Média R 2020–2023 | Média R 2024–2025 | Média R 2026 |
|---:|---:|---:|---:|---:|---:|---:|
| 192 | 234 | +0,135 | 1,20 | +0,057 (133) | +0,114 (76) | +0,616 (25) |
| 288 | 168 | +0,400 | 1,64 | +0,171 (100) | +0,562 (50) | +1,218 (18) |
| 480 | 128 | +0,507 | 1,86 | +0,164 (78) | +0,824 (37) | +1,665 (13) |
| 720 | 98 | +0,726 | 2,31 | +0,184 (61) | +1,229 (28) | +2,839 (9) |

### Sensibilidade a custo — média líquida em R

| N H1 | Custo 1,50 | Custo 3,00 | Custo 5,00 |
|---:|---:|---:|---:|
| 192 | +0,135 | +0,051 | -0,062 |
| 288 | +0,400 | +0,316 | +0,205 |
| 480 | +0,507 | +0,425 | +0,317 |
| 720 | +0,726 | +0,647 | +0,542 |

### Janela 720 por ano, custo 1,50

| Ano | N | Média líquida R |
|---:|---:|---:|
| 2020 | 13 | +0,962 |
| 2021 | 13 | -0,276 |
| 2022 | 16 | +0,013 |
| 2023 | 19 | +0,109 |
| 2024 | 13 | +0,891 |
| 2025 | 15 | +1,522 |
| 2026 (parcial) | 9 | +2,839 |

### Separação por lado (720)

- 63 **compras**, média +1,166R; 35 **vendas**, média -0,066R.
- Isso sugere forte influência da alta do ouro em 2024–2026.
- Não concluir que comprar apenas supera de forma robusta: esse filtro foi avaliado depois de ver os resultados.

## Controle com entradas aleatórias (exploratório)

- 800 reamostragens de entradas aleatórias, mantendo *ano e direção* de cada sinal da janela 720, com mesma regra de stop/trailing e custo 1,50.
- Média das médias aleatórias: +0,257R; faixa percentil 2,5–97,5%: [-0,211, +0,758]R.
- Aproximadamente 3% das amostras aleatórias superaram a média +0,726R observada.
- **Isto NÃO é um p-valor validado**: entradas aleatórias permitiram sobreposição e amostragem com reposição, enquanto operações originais eram sequenciais; foram estudadas quatro janelas; a janela 720 foi escolhida pós-hoc. Há também a aproximação H1/M1.

## Problemas do código GoldTrendM1.mq5 original (inspeção estática)

1. `CTrade.Buy/Sell()` retornar verdadeiro não confirma execução do servidor; conferir `ResultRetcode()` e `ResultDeal()`.
2. `CalcLots()` pode aceitar lote mínimo com **até 2x** o risco da posição solicitado.
3. `DailyLossLimit` reinicia a referência diária após reiniciar o EA, não persistindo de forma segura durante o mesmo dia.
4. `GTM_peak` e algumas Global Variables não estão isoladas por conta/login; risco de estado compartilhado.
5. Em conta netting há somente aviso, sem bloqueio obrigatório para as quatro janelas.
6. Limite de DD configurado em 20% é um parâmetro do EA, **não representa** as regras da mesa 5K.
7. Sem validação completa de comissão, spread variável, margem agregada, execução parcial e gaps.
8. As quatro janelas podem operar o mesmo evento e elevar concentração de risco.
9. O EA real atualiza trailing no M1; esta simulação usa H1 e **não deve** servir como estimativa de desempenho do executável.

## Próximo experimento obrigatório (antes de qualquer implantação)

1. Preservar o código original, criar cópia de teste, bloquear ordens reais e corrigir os controles de risco/retcodes. Não alterar simultaneamente a lógica original de entrada.
2. Reproduzir o **EA no MT5 Strategy Tester**, usando `Cada tick baseado em ticks reais`, XAUUSD M1, **uma janela por teste**, custos reais e datas explícitas.
3. Exportar relatórios de negócios, solicitações, histórico e equity; comparar trade a trade contra o replay H1 e explicar divergências.
4. Usar avaliação cronológica com registros congelados; considerar que 2020–2026 já foram examinados (não são out-of-sample novos).
5. Validar as regras **exatas** de drawdown da mesa antes de habilitar ordens, incluindo eventos de gap/slippage.

## Decisão

**Manter o GoldTrend como hipótese de pesquisa.** Há um sinal histórico interessante no replay H1, mas **não há prova de lucro reproduzível do EA M1** nem de adequação à mesa. Não ativar negociação real a partir desta análise.
