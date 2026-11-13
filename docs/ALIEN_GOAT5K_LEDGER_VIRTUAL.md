# ALIEN GOAT5K — Simulador de exposição flutuante simultânea

**Research-only.** Não se conecta à Goat, ao MT5 nem ao servidor da corretora.
Não envia ordens, não fornece proteção em conta real, não prova
rentabilidade. Este componente corrige o erro conceitual identificado
no relatório GOAT5K de 13/11/2026: os 89 sinais hipotéticos tinham
"floating existente = 0", porque o antigo EA consultava posições reais
num Strategy Tester com negociação bloqueada.

## O que mudou

O script Python tools/goat_virtual_portfolio.py implementa um mecanismo
independente que recebe uma **linha temporal de ticks e sinais aprovados**.
Ele mantém duas carteiras separadas — STOP_M5 e STOP_M1_LOCAL — para
não somar dois stops candidatos do mesmo sinal como duas posições
reais simultâneas. A cada tick, usa Bid para liquidar BUY e Ask para
SELL, apura perda flutuante sem compensar posições perdedoras por
vencedoras, testa guarda interna de US$40 e marca eventual limite
de US$50. Também apura patrimônio/balance para limites diário e
total. Em gaps, registra o breach observado **antes** do stop virtual.

No instante em que recebe uma proposta de entrada com
approved=true (essa flag deve vir do **EA que avaliou os filtros
da estratégia**, nunca ser criada pelo simulador), exige:
- preço Bid/Ask recente e stop estrutural do lado certo;
- referência de reset diário explícita às 17:00 hora civil
  de America/New_York (hipótese de fuso a confirmar com a Goat);
- perda pessimista da proposta <=US$12,50, incluindo 10 pontos
  de slippage reservado em cada lado e comissão simulada;
- perda total de TODAS as posições hipotéticas, caso seus
  stops sejam atingidos, estritamente abaixo de US$40;
- patrimônio projetado após stops ainda acima do piso diário
  e estático mais reservas internas.

A abordagem de stress simultâneo é conservadora; o conjunto de
stops não é um preço real negociável e **não garante** que o mercado
permitirá fechar sem violação.

## Limites e hipóteses
- Modelo presumido: Goat 2 Steps 1% Floating — ainda depende de
  confirmar a variante no dashboard do usuário.
- Capital US$5000, risco 0,25% (US$12,50), floating hard US$50,
  reserva US$10 => guarda interna US$40.
- Daily drawdown de 4% sobre a base mais alta entre saldo/equity
  no reset de 17:00, conforme o FAQ da Goat. O timezone de
  New York com DST é uma **hipótese técnica**, pois o FAQ
  escreve 5pm EST; confirmar como o servidor implementa DST.
- Máxima perda total 10% estática => piso US$4500; reservas
  hipotéticas de US$15 para piso diário e total.
- Comissão US$5/lot roundtrip é **hipótese não verificada**; o FAQ
  publica US$5 por lote para metais, mas não explica os dois lados.
- A execução usa o tamanho de contrato e valor de ponto que forem
  explicitamente fornecidos em cada evento; nenhum contrato é
  inferido do RoboForex.
- Eventos de cotações não são fills, slippage real nem swaps.

FAQ Goat: https://help.goatfundedtrader.com/2-step-goat.html
Comissão: https://help.goatfundedtrader.com/en/articles/10742044-how-does-the-commission-work-for-different-trading-instruments

## Testes sem precisar de outro backtest

Executar no Python 3.11+:

    python -m unittest discover -s tests -p 'test_goat_virtual_portfolio.py' -v

Os cenários automáticos incluem:
1. Três entradas hipotéticas com risco de cerca de US$10 cada
   são aceitas e a quarta é vetada porque a soma superaria US$40.
2. Gap grande de preço que fura stops virtuais e gera breach
   flutuante >US$50 **antes** da liquidação simulada.
3. Uma posição vencedora NÃO compensa a perda flutuante de outra.
4. Reset diário, ausência de referência, cotações desatualizadas,
   risco US$12,50, lado incorreto do stop e modelos independentes.

## Como usar os CSVs do último laboratório

O ZIP anterior contém apenas linhas OPEN e fechamento hipotético,
não contém o livro de Bid/Ask completo. Portanto o script aceita:

    python tools/goat_virtual_portfolio.py --audit-shadow <caminho-do-ZIP>

Isso audita as flags existentes **sem simular portfolio** e marca
explicitamente "portfolio_time_series_computable_from_this_csv=false".
Nunca preencher um caminho de preço com dados inventados.

Para simular um novo cenário, criar uma fita de eventos JSONL
em ordem cronológica, com timestamps ISO-8601 com offset:
- quote: ts, symbol, bid, ask;
- reset: ts às 17:00 de NY, assumed=true/false;
- signal: ts, model (STOP_M5 ou STOP_M1_LOCAL), id, symbol,
  side BUY/SELL, stop, volume, contract_size, approved=true/false;
- close: ts, model, id (fechamento hipotético).

    python tools/goat_virtual_portfolio.py --events eventos.jsonl --out relatorio.json

**Ainda não há fita de ticks exportada da GOAT**, nem sinais
que passem a estratégia: o estudo real contém 0/89 elegíveis.
Por isso o componente só é considerado **validado com testes
sintéticos**, não com dados de carteira GOAT nem para operação.
