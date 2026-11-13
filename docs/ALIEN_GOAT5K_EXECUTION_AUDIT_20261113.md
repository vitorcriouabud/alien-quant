# ALIEN GOAT5K Execution Tester — Auditoria (13/11/2026)

**Resumo anonimizado** do ZIP privado `ALIEN_GOAT5K_EXECUTION_20261113_115540.zip`. **Dados brutos das transações não foram publicados no GitHub.**

## Evidência
- XAUUSD M1, MetaQuotes-Demo, 21/10 a 12/11/2026; depósito US$5.000, alavancagem 1:100.
- MT5 reportou 100% de ticks reais, **6.617.831 ticks** e **21.415 barras** (declaração do relatório).
- Hashes de HTML, preset e CSV conferem **3/3** com o manifesto; MQ5/EX5 não constam do ZIP para checagem independente.
- **96 execuções simuladas completas**: 96 tentativas/96 fills/96 deals IN/96 deals OUT.
- Saldo final **US$4.912,66**; lucro líquido MT5 **−US$87,34**; PF **0,62**; drawdown máximo de equity **2,22% (US$111,16)**.
- 23 TP e 73 SL; taxa de acerto **23,96%**; média ganho **US$6,31** e perda **−US$3,19**; **33,5%–33,6%** de acerto necessário para equilíbrio nessa relação, sem taxas adicionais.
- 23 BUY: **−US$1,14**; 73 SELL: **−US$86,20**. Direção de venda concentrou quase todo prejuízo, mas eliminar SELL após ver esses dados seria sobreajuste.
- Todos os **96 volumes = 0,02 lote**. Stop mediano **161 pts**, spread mediano na entrada **33 pts**, razão spread/stop mediana **20,3%**. Risco pessimista calculado antes da entrada em média **US$3,58**, abaixo do teto de US$12,50; aumentar lotagem não corrige expectativa negativa.
- O HTML do MT5 registra **comissão ZERO e swap ZERO** para todos os deals. `AssumedCommissionPerLot=5` não criou cobrança no tester; serviu apenas para o sizing. Cenário ilustrativo 5 USD/lote/roundtrip implica custo adicional **US$9,60** e net ajustado **−US$96,94**. A 5 USD/lote por lado: **−US$106,54**. A cobrança real Goat permanece não verificada.
- **1128 sinais** no log; **1032 vetos STOP** e **273 vetos SPREAD**, em etapas diferentes do funil (não somar como oportunidades independentes).
- **6 trades exatos em cada um de 16 dias**: `MaxDayTrades=6` saturou diariamente; esta política seleciona sinais iniciais do dia e impede inferir desempenho de sinais posteriores.
- Máxima sequência de perdas: **10**; nenhum fechamento por timeout.
- Reset diário do EA foi baseado no calendário do servidor e não 17h EST Goat, logo este teste **não prova** conformidade com regra diária ou limite flutuante Goat.

## Interpretação
Este é um **benchmark M1 com TP 2R, spread 45 pts e stop local 35–180 pts**; não é a estratégia original ALIEN SMC 4R. Ele conseguiu um histórico de operações, mas mostrou **expectativa negativa mesmo sem comissão**. É inadequado para operar a mesa.

## Próximas decisões
1. Preservar a versão executável como **controle negativo**, sem aumentar lote/risco e sem instalar na conta Goat.
2. Conferir política, custos de comissão e spread reais da conta Goat usando somente documentação e conta de observação.
3. Não otimizar BUY-only ou horários no mesmo intervalo; medir candidatos descartados e custo relativo à distância do stop.
4. Congelar hipótese distinta, criar teste controlado com lógica estrutural objetiva e **holdout futuro não usado**.
5. Exigir histórico realista com comissão/slippage e saldo/risco equivalentes antes de qualquer promoção.

**Status: benchmark executou, performance reprovada, conformidade Goat não validada.**
