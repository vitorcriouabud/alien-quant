# ALIEN GOAT5K — Auditoria A/B de execuções, 13/11/2026

Fonte primária privada: ALIEN_H1M15_AB_20261113_123725.zip. CSVs, dados de conta e relatórios completos ficam fora do GitHub.

## Integridade
- XAUUSD M1, MetaQuotes-Demo Strategy Tester, depósito US$5.000, 21/10–12/11/2026.
- MT5 reportou 21.415 barras e 6.617.831 ticks reais nos dois casos.
- Seis checksums SHA256 (dois HTML, dois presets, dois CSV) coincidem com manifesto.
- Manifesto declara hash EX5 idêntico nos dois testes, mas não inclui binário para verificar independentemente.
- Presets diferem apenas no contexto H1/M15 e no nome de saída CSV.

## Resultados
| Métrica | A_BASE | B_CONTEXT |
|---|---:|---:|
| Ordens completas | 96 | 72 |
| TP / SL | 23 / 73 | 13 / 59 |
| Taxa de acerto | 23,96% | 18,06% |
| Lucro líquido MT5 | **−US$87,34** | **−US$109,92** |
| PF | 0,62 | 0,42 |
| Payoff médio | −US$0,91 | −US$1,53 |
| DD equity máximo | US$111,16 (2,22%) | US$124,94 (2,49%) |
| Saldo final | US$4.912,66 | US$4.890,08 |
| Spread / stop medianos | 33 / 161 pts | 33 / 156 pts |

**O filtro B diminuiu o número de operações 25% e piorou o resultado US$22,58.**

## Pareamento de negociações
- **28** operações idênticas em ambos, mesmas entradas, stops, saídas e resultado (−US$52,62 para ambos, 4 acertos).
- **68** operações exclusivas do A: −US$34,72, 19 ganhos.
- **44** operações exclusivas do B: −US$57,30, 9 ganhos.
- O limite de seis por dia, cooldown e apenas uma posição aberta alteram quais sinais cada versão escolhe. Portanto não se trata apenas de retirar 24 negócios do A.
- A: BUY 23, −US$1,14; SELL 73, −US$86,20. B: BUY 20, −US$12,56; SELL 52, −US$97,36. Não converter isso em regra BUY-only por sobreajuste.

## Custos e funil
- Tabelas de negócios MT5 exibem comissão e swap ZERO. Premissa US$5/lote por roundtrip não foi debitada; com 0,02 lote/trade, resultado hipotético após comissão adicional seria A −US$96,94 e B −US$117,12.
- B: 2.988 VETO_CONTEXTO, 863 CONTEXTO_APROVADO, 791 VETO_STOP, 622 VETO_SPREAD e 72 ordens preenchidas. Contadores são de políticas com diferentes estados de carteira, não universo pareado completo.

## Decisão
1. **Não aprovar o filtro H1/M15** como melhoria: piorou profit factor, taxa de acerto e drawdown no intervalo estudado.
2. Não habilitar A ou B na conta Goat. MetaQuotes-Demo difere dos custos e das regras específicas da mesa; amostra já foi usada para desenvolvimento.
3. Próximo laboratório: coletor de **todos os sinais M1 antes do limite de 6 operações, cooldown ou ocupação de carteira**, registrando contexto H1 e M15, Bid/Ask, stop, spread, alvo, veto e desfecho hipotético por ticks. Isso isola efeito do filtro na mesma coorte de sinais, sem depender da seleção dinâmica de trades.
4. Separar teste independente futuro e validar cobrança real da Goat; não otimizar a posteriori operações SELL ou horários na mesma amostra.

Status: A/B finalizado e auditado. Trata-se apenas de ordens **no Strategy Tester**, não de ordens na Goat.