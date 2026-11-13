# Auditoria ALIEN TURBO 9/9 — 13/11/2026

Fonte: pacote privado ALIEN_TURBO_DISCOVERY_20261113_133322_RETOMADO_20261113_140620.zip. Nenhum CSV privado foi publicado.

## Integridade
Todos os 9 experimentos concluídos, 47 hashes SHA-256 verificados (9 HTML, 9 SET, 27 CSV e MQ5/EX5). Mesmo EX5. 21.415 barras / 6.617.831 ticks reportados pelo MetaQuotes-Demo; NOT GOAT LIVE. Coorte de 9.011 candidatos M1 com ID e features iguais em cada variante.

## Desempenho de fills do Strategy Tester

| Variante | Trades | Net MT5 USD | PF | Max DD equity | Net com custo adicional hipotético USD5/lote |
|---|---:|---:|---:|---:|---:|
| A_BASE | 96 | -87,34 | 0,62 | 2,22% | -96,94 |
| B_FREQUENCY | 373 | -285,04 | 0,67 | 6,73% | -322,34 |
| C_ALLDAY | 547 | -400,19 | 0,70 | 8,79% | -454,89 |
| D_MULTI5 | 773 | -397,50 | 0,76 | 8,80% | -474,80 |
| E_H1M15 | 287 | -400,95 | 0,50 | 8,38% | -429,65 |
| F_M5SWEEP | 55 | -18,20 | 0,84 | 0,72% | -23,70 |
| G_M15FVG | 127 | -15,32 | 0,94 | 1,40% | -28,02 |
| H_RR3 | 764 | -369,81 | 0,80 | 8,60% | -446,21 |
| I_RISKSIZED | 144 | -400,02 | 0,50 | 10,10% | -435,92 |

MT5 cobrava comissão zero. Hipótese de comissão adicional NÃO é custo verificado na Goat. Todos 9 PF abaixo de 1 mesmo antes da comissão.

## P0: stop e timeout NÃO impediram perda extraordinária
H BUY 0,02 lote 09/11 22:57 a 4142,31; SL 4140,76; TP 4146,96; risk estimate USD3,60. Fechou em 10/11 01:00:13 a 4086,43, PnL -USD112,01. Posição excedeu timeout configurado de 90 minutos; padrão compatível com interrupção de cotações e gap, mas o ZIP não contém tape integral de ticks para confirmação definitiva. O mesmo fechamento extremo aparece em C e E. A proteção OnTick não garante saída em falta de ticks.

## I: reconciliar 10,10% equity drawdown
Este DD é relativo ao pico da curva, não ao depósito inicial. Saldo final USD4599,98, queda USD400,02 = 8,0004% sobre depósito de USD5000. Piso interno de perda total era USD4600; LOCK_TOTAL foi acionado e houve pequena ultrapassagem de USD0,02 no fechamento. I usou 0,05 lote em 143/144 trades, 0,03 em 1, e atingiu cedo a trava.

## Fita independente
9.011 candidatos idênticos por ID nos nove cenários. Os outcomes M1 são hipóteses por OHLC com spread ASK estimado para venda, não fills reais. 3 candidatos não tiveram outcome porque o stop estava do lado errado na abertura de sessão; sinal M1 atrasado após lacuna de preço deve ser tratado como stale.

## Decisões
Nenhuma variante é elegível para Goat. Próxima prioridade técnica: observar disponibilidade real do mercado, bloquear novas entradas quando existe risco conhecido de pausa, rejeitar candles M1 antigos, registrar exposição durante gaps e testar circuit breakers com preço variável. A documentação e os resultados A–I pertencem à amostra de desenvolvimento; qualquer hipótese vencedora exige holdout independente, custos corretos e política Goat confirmada.