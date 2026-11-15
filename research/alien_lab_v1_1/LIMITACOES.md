# Limitações — ALIEN LAB V1

O motor rejeita ou marca hipóteses. Não prova lucro.

## O que este laboratório não faz

- Não lê o símbolo ao vivo no MetaTrader. `point = 0.01` e `contract_oz = 100` são parâmetros. O segundo é hipótese de contrato padrão (1,00 de preço = 100 USD por lote), não uma leitura da RoboForex.
- Não conhece comissão, swap nem slippage real. O slippage entra como grade em pontos MT5 (`0`, `10`, `20` por omissão). 10 pontos = 0,10 de preço, não 10 dólares e não 10 pips de Forex.
- A saída é o fechamento do horizonte. Não há stop intrabar, não há “o que foi tocado primeiro” e não há fila de ticks. Um candle que atravessa alvo e stop no mesmo minuto não é resolvido.
- Volume de ticks é intensidade do candle M1. Não é agressão, não é delta e não é ordem institucional.
- Bollinger usa SMA e desvio populacional (`ddof=0`). Não replica bit a bit o `iBands` do MT5.
- EMA usa o recursivo do pandas (`adjust=False`), também sem garantia bit a bit com o MT5.
- Horário de verão não é detectado. Se o CSV está no horário do servidor, é obrigatório passar `--timestamp-kind server --server-utc-offset H`. Offset errado invalida a família E.
- A última hora do arquivo não entra no slope H1, porque pode estar aberta.
A prova sintética também mostra o limite do rótulo: `A_CQ_SELL` passou `SURVIVES_SCREEN` nos horizontes curtos porque a série artificial contém um movimento de venda plantado e vários fechamentos fracos em sequência. Isso não é edge. Não há correção para testes múltiplos.
- O período já estudado (agosto–novembro de 2026, ou o que você marcar com `--reserved-start` e `--reserved-end`) sai das métricas primárias. Não vira amostra inédita.
- A V11 não é lida nem alterada. Nenhuma ordem é enviada.

## Custos

| Quantidade | Unidade |
|---|---|
| `point` | 0,01 de preço no XAUUSD da RoboForex |
| 1 ponto MT5 | 0,01 de preço |
| 1,00 de preço | 100 pontos MT5 |
| USD por lote | variação de preço × `contract_oz` − comissão |

Spread zero tem dois cenários, sempre: exclusão, e penalidade (`--penalty-spread0`, omissão 20 pontos).

## Hash

`definitions_frozen.json` é escrito antes do cálculo. Se o texto das regras mudar, a retomada noturna recusa o checkpoint.

## Apêndice V1.1 — limites adicionais

- Operações independentes (`position_policy=independent`) são somente eventos; o modo `one_per_hypothesis` impede overlap **na mesma hipótese, horizonte e cenário** mas não entre hipóteses; não interpreta como carteira real.
- `--timezone-verified` é declaração manual; conversão fixa em +2h não prova sessão NY/Londres nem cobre DST. Família E marcada `TIMEZONE_UNVERIFIED` quando não verificada.
- Análise pareada inclui sobreposição de índices, mas quando uma confluência é subconjunto do núcleo o PnL do evento coincidente é matematicamente igual; o ganho eventual é na seleção dos eventos, não na execução do trade.
- `--resume` funciona apenas após gravação atômica de events.csv; não retoma o meio do gerador de sinais. Rejeita dados/config/código alterados.
- Não há controle de múltiplos testes, intervalos de confiança corrigidos, embargo em walk-forward nem simulação de portfólio; `SURVIVES_SCREEN` continua exploratório.
- Histórico ago–nov/2026 já foi examinado na V0 e V1; não é holdout inédito.
