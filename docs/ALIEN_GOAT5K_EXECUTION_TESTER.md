# ALIEN GOAT5K — EXECUTION TESTER (ordens no backtest)

## O que é
Um experimento novo e independente para gerar operações reais **dentro do
simulador de execuções do Strategy Tester do MT5**. Não abre ordens na
conta Goat, RoboForex ou conta de demonstração em tempo real.

O ALIEN original segue intocado. Nos ensaios anteriores (GOAT5K Shadow)
0/89 sinais passaram simultaneamente pelos filtros, então ativar ordem
na mesma estratégia continuaria produzindo 0 trades.

## Experimento de execução
- XAUUSD M1, primeiro tick depois de candle M1 fechado.
- Direção: candle M1 fecha além da máxima/mínima do anterior por >=2 pontos,
  corpo >=35% do range, no sentido do rompimento.
- Stop: além do extremo das últimas três velas M1 fechadas e buffer 8 pts;
  entre 35 e 180 pontos de entrada, ou ignora.
- Alvo: **2R**, diferente do 4R do projeto SMC original.
- Spread cap: **45 pontos**, mais flexível do que o teto anterior de
  25; este limite **NÃO é recomendado para conta real**.
- Apenas 1 posição na conta por vez, até 6 trades/dia de servidor,
  cooldown 30min e tempo máximo de posição 90min (saída simulada).
- Rejeita períodos fora de 7h–20h do servidor (horário não
  representa automaticamente sessão NY nem horário Goat).
- Risco de cada entrada calculado com OrderCalcProfit incluindo
  reserva de 10 pts de slippage por lado e comission estimada
  US$5/lot round-trip; teto de 0,25% ou US$12,50, o menor deles.
- Lot máximo 0,02. Não força lote mínimo quando risco não comporta.
- Guarda preventiva: perda flutuante da conta >=US$35,
  drawdown diario >=1% no **dia do servidor**,
  perda total >=8% sobre $5000. Em disjuntor, tenta fechar
  posições próprias; gaps podem causar perdas maiores.
- **Trava absoluta OnInit:** \`MQL_TESTER==true\`, XAUUSD/M1, depósito $5000
  e parâmetros não mais arriscados do que limites gravados.

## Não confundir
- São deals do **Strategy Tester**, NÃO operações ao vivo
  nem fills reais do servidor GOAT.
- Esta nova entrada M1 é um **benchmark experimental** para estudar
  mecânica de execução, custo, expectativa após taxas e drawdown.
  Um histórico com muitas operações não demonstra vantagem.
- O MT5 MetaQuotes-Demo é a fonte da cotação; não reutilizar essas taxas
  para concluir que o ALIEN passará uma avaliação Goat.
- Limites da Goat (floating 1%, daily 4%, etc.) dependem da
  modalidade real e de seus horários de reset; o benchmark usa
  guardas MAIS restritivas simplificadas, não garante compliance.
- Não usar VPS, não instalar na conta Goat, não ativar trading live.

## Arquivos
- \`MQL5/Experts/ALIEN_GOAT5K_EXECUTION_TESTER.mq5\`
- \`MQL5/Profiles/Tester/ALIEN_GOAT5K_EXECUTION_TESTER.set\`
- \`tools/RODAR_GOAT5K_EXECUTION_TESTER.ps1\`

Com projeto local existente, MetaQuotes-Demo no MT5 isolado e
PowerShell aberto na pasta do repositório, executar:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_GOAT5K_EXECUTION_TESTER.ps1

O script fecha apenas o MT5 ISOLADO se ele estiver aberto,
compila o .mq5 no MetaEditor e solicita backtest por ticks reais
de 21/10 a 12/11/2026 com depósito US$5000.

Saída: \`PACOTES_MT5/ALIEN_GOAT5K_EXECUTION_*.zip\` contendo
HTML MT5, log CSV de sinal/veto/ordem/deal, preset e manifesto SHA256.

### Critérios para auditoria
Verificar **0 erros** de compilação, relatório HTML indicando ticks e
barras reais (>0), quantidade de deals IN e OUT, qualidade dos
dados, comissão observada vs taxa estimada, spread, saldo final,
max drawdown, profit factor, expectativa de R e risco de sobreajuste.
Se não houver ordens, o runner dá aviso e preserva todos os logs;
nunca relaxa automaticamente as travas.

## Status
GitHub Actions valida apenas texto, invariantes de risco e
sintaxe PowerShell. **MetaEditor e Strategy Tester reais do notebook
ainda não foram executados.** Não afirmar que já existem fills.
