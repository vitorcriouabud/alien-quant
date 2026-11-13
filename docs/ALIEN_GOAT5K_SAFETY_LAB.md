# ALIEN GOAT5K — Laboratório de risco, 13/11/2026

## Estado
Pesquisa sem execução em MetaQuotes-Demo, depósito de US$ 5.000.
Não conecta, não envia ordens e NÃO verifica o status da conta Goat.
As condições de spread do backtest ainda são as da MetaQuotes-Demo.

Modelo a confirmar no dashboard: **2 STEPS GOAT 1% FLOATING**.
Outras modalidades Goat têm regras diferentes.

## Fontes oficiais
- Modelo 2 Step GOAT: https://help.goatfundedtrader.com/2-step-goat.html
- Comissões: https://help.goatfundedtrader.com/en/articles/10742044-how-does-the-commission-work-for-different-trading-instruments
- EAs/autoria: https://help.goatfundedtrader.com/en/articles/10749630-can-i-use-expert-advisors-eas
- VPN/VPS proibidos: https://help.goatfundedtrader.com/en/articles/17362726-can-i-use-a-vpn-vps-proxy-or-any-other-hosting-service-while-trading
- Login somente para visualizar spreads: https://help.goatfundedtrader.com/en/articles/10741905-what-instruments-can-i-trade

Regra: daily drawdown 4% sobre max(balance,equity) no reset das
17:00 EST. Piso estático de 90% do capital inicial = 4500 USD.
Se for a variante 1% Floating, perda flutuante COMBINADA de todas
as posições >= 1% do capital inicial (= 50 USD) resulta em breach.
Goat publica comissão de 5 USD por lote em FX/metais com raw spread:
o texto não deixa explícito o custo completo de ida e volta.
A estimativa de 5 USD roundtrip usada no laboratório é HIPÓTESE,
pendente de verificação em documento oficial/lançamento da corretora.

Política de EA: somente EA próprio, pode exigir fonte; uso de EA
gerado com ajuda de IA depende de confirmação escrita. VPS/VPN/proxy/
hosting durante operações proibido. HFT e gold arbitrage proibidos.

## Perfil de pesquisa
- Capital: 5000 USD, validado no OnInit do Strategy Tester.
- Risco por candidato: 0,25% = 12,50 USD.
- Floating hard: 50 USD; guarda interna com 10 USD de reserva,
  portanto teto de risco simulado combinado < 40 USD.
- Diário: 4%; referência de reset assumida de 5000 USD =>
  piso ilustrativo de 4800 USD + margem interna 15 USD.
  NÃO é atualização automática da regra Goat; usar dashboard
  para saber a referência real às 17:00 EST.
- Total: piso estático 4500 USD + margem interna 15 USD.
- Stop 35–180 pontos; spread até 25 pontos (filtro interno,
  não regra Goat); alvo 4R e estimativa de slippage 10 pts por lado.
- Comissão no tester: 5 USD/lot roundtrip assumidos;
  resultados ainda contam spread da MetaQuotes-Demo.
- O EA recusa testes fora do Strategy Tester, envio de ordens,
  capital diferente e parâmetros essenciais alterados.

Os riscos calculados são indicadores HIPOTÉTICOS, não proteção
garantida de conta real nem substituto para verificação das regras.

## Entregáveis
1. MQL5/Experts/ALIEN_GOAT5K_RISK_SHADOW.mq5
2. MQL5/Profiles/Tester/ALIEN_GOAT5K_RISK_SHADOW.set
3. tools/RODAR_GOAT5K_RISK_LAB.ps1
4. MQL5/Experts/GOAT_XAUUSD_SPREAD_READONLY.mq5
5. tests/test_alien_goat5k_static.py e CI para sintaxe/invariantes.

O R4.4 continua intacto. A nova variante é uma branch experimental.

## Teste isolado
Na pasta existente do projeto, após baixar os 3 arquivos do
laboratório, executar no PowerShell:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_GOAT5K_RISK_LAB.ps1

O script fecha somente o terminal de testes, compila o novo MQ5,
roda ticks reais solicitados 21/10–07/11/2026 e coleta HTML,
EVENTS.csv, OUTCOMES.csv e MANIFESTO com hashes em ZIP privado.
É verificação mecânica in-sample, não validação independente.

Novos campos de cada candidato: goat_risk_worst_usd,
goat_trade_risk_cap_usd, goat_existing_negative_float_usd,
goat_floating_hard_usd, goat_floating_guard_usd,
goat_trade_risk_ok, goat_float_headroom_ok,
goat_daily_floor_assumed_usd, goat_daily_floor_ok,
goat_static_floor_usd, goat_static_floor_ok, goat_all_gates_ok.

## Medição de custos Goat
O coletor GOAT_XAUUSD_SPREAD_READONLY.mq5 foi projetado para
a conta INVESTOR/VIEW-ONLY oficial da Goat, com trading não
permitido. Aborta se o servidor não parecer Goat ou a conta
estiver habilitada para ordens. Não inclui comandos de trade.
Amostra cada cotação nova por até 30 min, registra bid/ask,
spread, contract size, tick value, tick size e min lot.
O CSV sai em MQL5/Files/GOAT_XAU_SPREAD_READONLY.csv.

A conta viewer não executa operações; logo não fornece taxa
real cobrada em cada fill. Essa comissão fica pendente de
documento, suporte ou comprovante de cobrança permitido.
Não executar coletor na conta do desafio.

## Pendências reais
1. Confirmar no dashboard Goat o nome exato da modalidade,
   fase e status ativo (sem enviar credenciais).
2. Pedir confirmação escrita à Goat sobre EA próprio
   desenvolvido com assistência de IA.
3. Coletar cotação Goat em viewer para custos de spread
   e conferir modelo de comissão.
4. Validar regras/custos da conta comprada e amostra futura
   fora do período repetidamente usado para pesquisa.

NÃO colocar o EA em conta Goat, NÃO usar VPS e NÃO prometer lucro.
