# ALIEN GOAT5K — Verificação da base real e dos testes sintéticos (13/11/2026)

## Evidência do pacote privado (não publicar arquivos brutos)

Fonte local: `ALIEN_GOAT5K_RISK_20261113_110711.zip`.
O arquivo contém **89 candidatas hipotéticas OPEN** e 33 eventos de
ausência de pivô local M1. Todos os sinais são shadow, **nenhuma ordem
foi executada**.

| Modelo | Candidatos | Passaram todos os filtros | Passaram filtros Goat simulados | Dentro do limite individual de US$12,50 | Dentro da guarda flutuante isolada |
|---|---:|---:|---:|---:|---:|
| STOP_M5 | 61 | 0 | 0 | 59 | 60 |
| STOP_M1_LOCAL | 28 | 0 | 0 | 28 | 28 |
| Total | **89** | **0** | **0** | **87** | **88** |

O campo `goat_existing_negative_float_usd` foi **0,00 em todos
os 89 sinais**: o EA antigo consultava posições abertas no testador,
não um livro hipotético de posições. O ZIP registra abertura e
desfechos, mas NÃO disponibiliza cotação Bid/Ask por tick e snapshots
de conta ao longo de toda a vida de posições virtuais. Portanto
**não é possível calcular a pior perda flutuante simultânea real a
partir do ZIP antigo**. Não criar falsos dados para completar o histórico.

## O que foi implementado, separado do EA

- `tools/goat_virtual_portfolio.py`: livro virtual independente
  por modelo M5/M1, com eventos JSONL de quote, reset, signal e close.
- Em cada quote, apura pior flutuante de posições PERDEDORAS, sem
  compensar por posições vencedoras, e registra hard breach teórico
  antes de simular liquidação em stop/target.
- Na entrada, calcula risco pessimista por candidato, perda conjunta
  caso stops sejam acionados, piso diário/total com reservas.
- Não aceita sinal se faltar marcação aprovada do motor de estratégia,
  preço recente, stop válido ou referência de reset.
- Distingue `reset` real/assumido e exige timestamp com offset.
- `--audit-shadow` lê ZIP legado e declara explicitamente
  `independent_portfolio_simulation_executed=false`, em vez
  de fingir que a série de ticks está disponível.
- Sem dependência MetaTrader5/Python externa, sem chamadas de
  corretora, sem envio de ordens.

Os 14 testes automáticos do módulo cobrem rejeição da quarta
posição hipotética por excesso de risco acumulado (>US$40),
gap que ultrapassa o limite de US$50, lucro sem compensar
flutuante negativo, falta de reset, fuso, preços antigos e
dois modelos separados. GitHub Actions aprovou testes e sintaxe.
**Tudo isso é validação SINTÉTICA, não validação em ticks Goat.**

## Próximo gate técnico

Para simular carteira realista, precisa-se de **nova fita causal
de ticks** do servidor de execução relevante, snapshots de reset
e eventos da estratégia que tenham passado os filtros originais.
Na base atual, 0/89 candidatas passaram; portanto, nenhum livro
de posições realista seria alimentado sem mudar estratégia.

Há uma incerteza independente sobre a modalidade da conta comprada:
a variante 2 Steps GOAT 1% Floating ainda precisa ser confirmada
no painel. A referência de horário civil 17h New York (com DST)
usada no motor é suposição de engenharia: o FAQ menciona 17h EST;
confirmar o procedimento do servidor para horário de verão.

Não habilitar EA na mesa, não inferir lucro, não alterar spread/stop
apenas para passar pelo filtro e não usar VPS.

**Status:** componente de risco virtual de pesquisa entregue,
testes unitários passaram, aplicação real em Goat PENDENTE.
