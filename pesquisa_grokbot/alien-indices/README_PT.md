# ALIEN INDICES V1 — como instalar (3 passos)

Robô de **reversão à média no gráfico diário** em 3 índices (S&P 500, Nasdaq 100 e DAX 40).
Ele compra quando o índice caiu demais em poucos dias, dentro de uma tendência de alta, e sai no repique.
**Sem martingale, sem grid, sem preço médio.** Cada operação tem stop fixo desde a entrada.

## Os 3 passos
1. **Copiar o robô.** No MT5: `Arquivo > Abrir pasta de dados > MQL5 > Experts`. Cole ali o arquivo `ALIEN_INDICES_V1.ex5`
   (e, se quiser, o `ALIEN_INDICES_V1.mq5`). Feche e abra o MT5 (ou clique com o botão direito em "Expert Advisors" > Atualizar).
2. **Abrir UM gráfico.** Abra o gráfico de `.US500Cash` (qualquer tempo gráfico serve, sugiro D1).
   Na `Observação do Mercado`, deixe visíveis `.US500Cash`, `.USTECHCash` e `.DE40Cash`
   (botão direito > Símbolos > Indices). **Um único robô opera os 3 índices**; não coloque em 3 gráficos.
3. **Ligar.** Arraste o `ALIEN_INDICES_V1` para o gráfico, aba "Comum": marque "Permitir Algo Trading".
   Aba "Entradas": clique em "Carregar" e escolha `ALIEN_INDICES_V1.set` (são os valores da pesquisa). OK.
   Ligue o botão "Algo Trading" no topo do MT5. O painel amarelo e preto aparece no gráfico.

Pronto. O MT5 precisa ficar ligado (PC ou VPS) — o robô decide **uma vez por dia**, na abertura de cada índice
(cerca de 03:00 no horário do servidor para EUA e 09:05 para o DAX).

## O que o painel mostra
- Saldo, equity, risco aberto somado e o risco por trade.
- Para cada índice: fechamento, RSI2, IBS, média de 200, ATR e **a decisão em português**, por exemplo:
  - "Comprei US500 0.03 lote(s) a 6650.2 porque RSI2=4.1 (<10, queda exagerada) e preço acima da MM200 ... Risco 7.20 USD (0.72% da conta)."
  - "Sem entrada IBS: IBS=0.65, precisa <0.25 ..."
  - "Sem entrada USTECH IBS: o lote mínimo (0.01) arriscaria 3.10% da conta, acima dos 1.00% permitidos. Nunca arredondo pra cima."
- Tudo também vai para a aba "Experts" (diário) e para o arquivo `MQL5/Files/ALIEN_INDICES_log.csv`.

## Regras (iguais à pesquisa, não mexa sem novo teste)
- **RSI2** (compra e venda): compra se RSI(2) < 10 e preço acima da MM200; vende se RSI(2) > 90 e preço abaixo da MM200.
  Stop = 3 × ATR(20). Sai quando fecha acima da MM5 (compra) / abaixo da MM5 (venda), ou depois de 10 dias.
- **IBS** (só compra): IBS = (fechamento − mínima) / (máxima − mínima). Compra se IBS < 0,25 e preço acima da MM200.
  Stop = 4 × ATR(20). Sai quando fecha acima da máxima do dia anterior, ou depois de 5 dias.
- Sinal no fechamento do dia, execução na abertura do dia seguinte. Uma posição por estratégia e por índice (6 "fluxos").

## Proteções
| Entrada | Padrão | O que faz |
|---|---|---|
| Risco por trade | 1% | Lote calculado pelo stop (ATR) para perder no máximo ~1% se bater o stop |
| Teto duro | 2% | Nunca passa disso, mesmo se você digitar errado |
| Risco aberto máximo | 6,5% | Soma do risco de todas as posições (6 fluxos × 1%). 3% é mais conservador, mas no teste rendeu menos |
| Perda diária máxima | 3% | Se a conta cair 3% no dia, não abre nada novo hoje |
| Trava de DD do pico | 15% | Se cair 15% do topo, pausa novas entradas até você revisar |
| Só conta demo | sim | Não opera em conta real até você mudar para `false` de propósito |
| Lote mínimo | — | Se o lote mínimo arriscar mais que o permitido, **não entra** (nunca arredonda pra cima) |

## Conta e dinheiro: leia antes
- Os índices **não existem na conta ProCent (cent)** da RoboForex. Só nas contas **Pro, ECN e Prime** (em dólar).
- Lote mínimo 0,01 = US$ 0,01 por ponto do índice. Hoje (nov/2026) o stop do Nasdaq vale ~2.300 a 3.100 pontos, então
  **para operar os 3 índices a 1% você precisa de uns US$ 3.200 ou mais**. Com US$ 1.000 o robô opera o S&P 500 e pula
  quase todos os sinais de Nasdaq e DAX. **Com US$ 20 ele não opera nada** (o lote mínimo arriscaria 20–40% da conta).
- Expectativa honesta (teste no MT5 com custos e swap reais da RoboForex): **~3,5–4% ao ano, queda máxima ~7–8%**, ~9 operações por mês.
  É um robô lento e defensivo. Veja `TESTE.md`.
