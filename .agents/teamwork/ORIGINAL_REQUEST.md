# Original User Request

## Initial Request — 2026-11-09T06:36:20Z

Executar validação e backtests em massa no MT5 e realizar o refinamento algorítmico do EA ALIEN_V12_1_INSTITUTIONAL em MQL5 no XAUUSD M1 para blindagem e consistência operacional na conta Goat Funded Trader 10K.

Working directory: C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB
Integrity mode: development

## Contexto e Recursos Forenses
- Ativo: XAUUSD (Ouro), Timeframe: M1, Corretora: RoboForex MT5 / Goat Funded Trader 10K.
- Código do EA: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- Terminal MT5: `C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`
- MetaEditor 64: `C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe`
- Scripts de compilação e teste: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\`
- Parâmetro estratégico: Ajustar `EnforceStrictHTF = false` para cumprir a Decisão D10 de sweeps de liquidez.
- Configuração do Strategy Tester: Utilizar período de ticks reais da RoboForex (a partir de 2026.10.21 até 2026.11.06) ou cache local de outubro de 2026 com modelo "Cada tick baseado em ticks reais".
- Alerta de Margem/Alavancagem: A conta Demo RoboForex 67316641 possui alavancagem 1:1 (demandando $74.160 para 0.18 lotes em XAUUSD; com 0.01 lote ou alavancagem 1:100 a margem é suficiente). Calibrar os testes garantindo que limitações de margem da conta demo não inviabilizem a execução.

## Requirements

### R1. Validação e Backtest em Massa (MT5)
- Executar e tabular backtests do `ALIEN_V12_1_INSTITUTIONAL` com dados de ticks reais no XAUUSD M1 utilizando o período de 2026.10.21 a 2026.11.06 ou histórico recente disponível no MT5.
- Analisar logs de execução do terminal e Strategy Tester para garantir que o EA executa operações normalmente sem falhas de margem, trade context ou requote.
- Reportar métricas quantitativas completas e tabuladas: Win Rate, Profit Factor, Drawdown Máximo e R:R médio.
- Estender e utilizar scripts automatizados em `tools\` (como `Run-Backtest.ps1`, ferramentas de parse de relatórios e compilação) para automatizar a extração e consolidação dos resultados.

### R2. Refinamento Algorítmico do EA (MQL5)
- Aprimorar a leitura de micro-estrutura institucional no código MQL5: detecção de sweeps de liquidez BSL/SSL, Fair Value Gaps (FVG) e quebra de estrutura (CHoCH), com `EnforceStrictHTF = false`.
- Otimizar a dinâmica do trailing stop e breakeven institucional para proteger lucros rapidamente em M1.
- Blindagem total para as regras da conta Goat Funded Trader 10K:
  - Meta diária de ganho: $100 (trava de meta batida no dia).
  - Disjuntor de perda diária máxima: $140 (trava rígida impedindo novas ordens ou fechamento compulsório ao atingir o limite no dia).
  - Limite máximo total de perda da mesa: $200 (hard stop de proteção de conta).
  - Lote padrão: 0.18 (com suporte ou ajuste controlado quando operando em ambiente de alavancagem restrita 1:1).

## Acceptance Criteria

### Compilação e Integridade Técnica
- [ ] O código `ALIEN_V12_1_INSTITUTIONAL.mq5` compila com sucesso via MetaEditor 64 sem nenhum erro (`0 errors, 0 warnings` ou apenas avisos não-bloqueantes).
- [ ] O parâmetro `EnforceStrictHTF = false` está configurado por padrão conforme a Decisão D10.

### Execução e Validação do Backtest
- [ ] Backtest executado com sucesso no Strategy Tester do MT5 em XAUUSD M1 com modelo "Cada tick baseado em ticks reais" cobrindo o período recente (2026.10.21 a 2026.11.06 ou equivalente no MT5).
- [ ] Logs do MT5 confirmam abertura e encerramento normais de posições sem erros de negociação ou falta de margem.
- [ ] Relatório consolidado gerado e tabulado contendo Win Rate, Profit Factor, Drawdown Máximo absoluto e percentual, e R:R médio.

### Mecanismos de Blindagem e Gestão de Risco
- [ ] Disjuntor de perda diária atua com corte antes de ultrapassar $140 de perda no dia em qualquer sessão testada.
- [ ] Drawdown máximo total acumulado permanece rigorosamente abaixo de $200.
- [ ] Trava de meta diária de $100 encerra as operações do dia ao atingir o objetivo.
- [ ] Lógica de trailing stop e breakeven institucional demonstrada e validada em logs/trades executados.

## Verification Resources
- Código do EA: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- Terminal MT5: `C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`
- MetaEditor 64: `C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe`
- Scripts de compilação e teste: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\`
