# RELATÓRIO DE AUDITORIA FORENSE ADVERSARIAL E VERIFICAÇÃO EMPÍRICA (MILESTONE M4)

**Identidade**: `teamwork_challenger` (Risk Shield & Boundary Challenger)  
**Data**: 2026-11-09T08:00:00Z  
**Ambiente**: MetaTrader 5 (RoboForex Terminal / Conta Goat Funded Trader 10K)  
**Ativo & Timeframe**: XAUUSD M1  
**Benchmark Analisado**: EXP-015 (`results\EXP_015_V12_1_BENCHMARK\EXP_015_V12_1_BENCHMARK.htm`)  
**Código Analisado**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`  
**Veredito Final**: **APPROVE** (Todas as invariantes de blindagem matemática e operacional foram estritamente cumpridas)

---

## 1. Observation

A auditoria forense adversarial inspecionou diretamente os dados brutos de execução, relatórios oficiais do MT5, logs de ticks reais do Strategy Tester e o código-fonte MQL5 compilado. Todas as constatações a seguir foram extraídas e comprovadas empiricamente via script de verificação independente `tools\verify_challenge_m4.py`:

### 1.1 Invariante 1 — Trava de Meta Diária ($100 no Dia 1: 2026.10.21)
- **Histórico Completo de Deals do Dia 1 (Quarta-feira, 21/10/2026)**:
  - Depósito Inicial: `$10,000.00` (Deal #1, `2026.10.21 00:00:00`).
  - Deal #2 (11:01:00): Entry SELL 0.18 @ 4124.04 (Comissão: -$0.74, Saldo: $9,999.26).
  - Deal #3 (11:03:32): Exit BUY 0.18 @ 4124.01 (Lucro: +$0.54, Comissão: -$0.74, Saldo: $9,999.06).
  - Deal #4 (11:07:25): Entry SELL 0.18 @ 4122.67 (Comissão: -$0.74, Saldo: $9,998.32).
  - Deal #5 (11:09:35): Exit BUY 0.18 @ 4121.26 (Lucro: +$25.38, Comissão: -$0.74, Saldo: $10,022.96).
  - Deal #6 (11:10:03): Entry BUY 0.18 @ 4120.97 (Comissão: -$0.74, Saldo: $10,022.22).
  - Deal #7 (11:11:46): Exit SELL 0.18 @ 4121.02 (Lucro: +$0.90, Comissão: -$0.74, Saldo: $10,022.38).
  - Deal #8 (11:12:15): Entry SELL 0.18 @ 4121.31 (Comissão: -$0.74, Saldo: $10,021.64).
  - Deal #9 (11:15:15): Exit BUY 0.18 @ 4120.15 (Lucro: +$20.88, Comissão: -$0.74, Saldo: $10,041.78).
  - Deal #10 (11:15:24): Entry BUY 0.18 @ 4119.70 (Comissão: -$0.74, Saldo: $10,041.04).
  - Deal #11 (11:20:10): Exit SELL 0.18 @ 4120.99 (Lucro: +$23.22, Comissão: -$0.74, Saldo: $10,063.52).
  - Deal #12 (11:24:14): Entry BUY 0.18 @ 4119.93 (Comissão: -$0.74, Saldo: $10,062.78).
  - Deal #13 (11:27:00): Exit SELL 0.18 @ 4122.04 (Lucro: +$37.98, Comissão: -$0.74, Saldo: **$10,100.02**).
- **Verificação Forense de Encerramento e Congelamento**:
  - Saldo ao encerrar Deal #13: `$10,100.02`.
  - Lucro Líquido Realizado no Dia 1: Lucro bruto de trades (`+$108.90`) menos 12 comissões ECN (`-$8.88`) = **+$100.02 USD**.
  - Operações abertas ou pendentes após as 11:27:00 em 2026.10.21: **EXATAMENTE ZERO (0)**.
  - A conta congelou categoricamente por 12 horas e 33 minutos (das 11:27:00 até 23:59:59). Nenhuma ordem não autorizada foi permitida.

### 1.2 Invariante 2 — Disjuntor de Perda Diária Máxima ($140 nos Dias 2 e 3)
- **Sessão do Dia 2 (Quinta-feira, 22/10/2026)**:
  - Saldo Inicial da Sessão: `$10,100.02`.
  - Teto de Perda Diária Admissível ($140): Saldo limite `$9,960.02`.
  - Total de Negociações: 12 trades (Deals 14 a 37).
  - Resultado Realizado Fechado: Perda líquida de **-$89.58** (Saldo final: `$10,010.44`).
  - Margem de Segurança Restante até -$140: **+$50.42**.
  - Motivo do encerramento das operações no Dia 2: O EA atingiu rigorosamente o limite de frequência de 12 operações (`MaxDailyTrades = 12`) às 11:30:15 e encerrou as entradas.
  - Violação do limite diário de $140: **NÃO HOUVE**.
- **Sessão do Dia 3 (Sexta-feira, 23/10/2026)**:
  - Saldo Inicial da Sessão: `$10,010.44`.
  - Teto de Perda Diária Admissível ($140): Saldo limite `$9,870.44`.
  - Total de Negociações: 12 trades (Deals 38 a 61).
  - Resultado Realizado Fechado: Perda líquida de **-$116.10** (Saldo final: `$9,894.34`).
  - Mínima Equity Flutuante Intraday: `$9,876.74` (Perda flutuante máxima da sessão: `$133.70`).
  - Margem de Segurança Restante no pior momento: **+$6.30** acima do disjuntor de -$140.
  - Motivo do encerramento das operações no Dia 3: Atingiu o teto diário de 12 operações às 13:15:38, seguido pelo protocolo de encerramento compulsório de fim de semana (`EnableFridayClose = true`) às 16:45 UTC.
  - Violação do limite diário de $140: **NÃO HOUVE**.

### 1.3 Invariante 3 — Disjuntor Total da Conta ($200 Hard Stop da Mesa Goat)
- **Métricas Oficiais do MT5 Strategy Tester (`EXP_015_V12_1_BENCHMARK.htm`)**:
  - `Lucro Líquido Total`: `-$105.66 USD`
  - `Rebaixamento Absoluto do Saldo`: `$105.66`
  - `Rebaixamento Absoluto do Capital Líquido`: `$105.66`
  - `Rebaixamento Máximo do Saldo`: `$205.68 (2.04%)`
  - `Rebaixamento Máximo do Capital Líquido`: `$223.28 (2.21%)`
- **Origem Matemática do Valor de $223.28**:
  - Pico Histórico Máximo de Capital (High-Water Mark): `$10,100.02` (ao final do Dia 1).
  - Fundo Histórico Mínimo de Capital Flutuante: `$9,876.74` (intraday do Dia 3).
  - Cálculo MT5 (`Rebaixamento Máximo`): `$10,100.02 - $9,876.74 = $223.28`.
- **Regra da Mesa Goat Funded Trader 10K (Hard Stop $200)**:
  - Capital Inicial de Aporte: `$10,000.00`.
  - Nível Crítico de Perda Total ($200 Hard Stop): Equity < **$9,800.00**.
  - Pior Capital Líquido Registrado: `$9,876.74` (flutuante) e `$9,894.34` (fechado).
  - Rebaixamento Real sobre o Saldo Inicial: `$10,000.00 - $9,894.34 = $105.66` (fechado) e `$10,000.00 - $9,876.74 = $123.26` (flutuante).
  - Colchão Mínimo de Sobrevivência Mantido: **+$76.74** acima do nível de eliminação da mesa.
  - A equity jamais tocou ou caiu abaixo de $9,800.00.

### 1.4 Invariante 4 — Restrições de Margem e Alavancagem (1:1 vs 1:100)
- **Auditoria de Código em `ALIEN_V12_1_INSTITUTIONAL.mq5` (`ValidVolume`, linhas 1641-1680)**:
  ```mql5
  long acctLev = AccountInfoInteger(ACCOUNT_LEVERAGE);
  if(acctLev > 0 && acctLev <= 10)
     requested = minV; // Redução forçada para 0.01 lotes

  // Margem dinâmica via OrderCalcMargin
  if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, checkPrice, marginForOneLot) && marginForOneLot > 0.0)
  {
     double marginBudget = MathMin(freeMargin - MinFreeMarginMoney, 
                                  (equity > 0.0 ? equity * (MaxBaseMarginPercentEquity / 100.0) : freeMargin * 0.5));
     if(marginBudget > 0.0)
     {
        double maxAffordableLot = marginBudget / marginForOneLot;
        if(requested > maxAffordableLot) requested = MathMax(minV, maxAffordableLot);
     }
  }
  ```
- **Auditoria de Logs do MT5 (`20261109.log`, 4.645 linhas auditadas)**:
  - Ocorrências de `TRADE_RETCODE_NO_MONEY` (código 10019): **ZERO (0)**.
  - Ocorrências de falta de margem ou requotes: **ZERO (0)**.
  - Sob 1:100 (Goat 10K): Ouro a $4.025 exige $724,50 de margem para 0.18 lotes (< teto de 50% = $5.000), operando com 100% do lote pretendido.
  - Sob 1:1 (RoboForex Demo 67316641): Ouro a $4.025 exigiria $72.450 para 0.18 lotes. A camada dupla de proteção rebaixa automaticamente para 0.01 lotes (margem de $4.025 <= $5.000), impedindo que a restrição de alavancagem quebre o robô.

---

## 2. Logic Chain

1. **Validação da Trava de Lucro Diário**:
   - *Fato*: No Dia 1, após o Deal #13 às 11:27:00, o saldo atingiu $10,100.02.
   - *Inferência MQL5*: As linhas 4828-4842 de `OnTick()` executam `GlobalVariableSet(dailyEquityKey + "_PROFIT_LOCK", 1.0)` imediatamente ao detectar `dailyRealizedNet >= DailyProfitTargetMoney` ($100.00). A função `NewEntriesAllowedBySupervisor()` consulta essa chave e veta categoricamente qualquer nova ordem.
   - *Comprovação Empírica*: Nenhuma transação foi executada entre 11:27:00 e 23:59:59. A trava funcionou perfeitamente.

2. **Validação do Disjuntor de Perda Diária**:
   - *Fato*: No Dia 2, a perda realizada foi -$89.58. No Dia 3, a perda realizada foi -$116.10 e a perda flutuante máxima foi -$133.70.
   - *Inferência*: Ambas as sessões operaram estritamente abaixo do teto de -$140.00 da Goat Funded Trader. Além disso, o limite de 12 operações por sessão (`MaxDailyTrades = 12`) funcionou como mecanismo de contingência primário, desativando novas entradas antes que o disjuntor de $140 precisasse liquidar ordens forçadamente.

3. **Desmistificação da Métrica de Drawdown ($223.28 vs $105.66)**:
   - *Fato*: O relatório do Strategy Tester exibe `Rebaixamento Máximo do Capital Líquido: 223.28 (2.21%)`.
   - *Inferência Técnica*: A fórmula interna do Strategy Tester do MT5 calcula o *Maximal Equity Drawdown* como a distância do pico absoluto histórico (High-Water Mark) até o vale subsequente mais profundo. Como o EA ganhou +$100.02 no Dia 1, o pico histórico foi de $10,100.02. Quando o mercado recuou nos Dias 2 e 3 até a mínima de $9,876.74, a diferença pico-fundo foi exatamente de $223.28 ($10,100.02 - $9,876.74).
   - *Regra da Mesa*: A regra da Goat 10K avalia a perda máxima em relação ao **depósito inicial** ($10.000.00), estipulando que a conta é reprovada se a equity cair abaixo de **$9.800.00** ($200 de perda).
   - *Conclusão Lógica*: Como a menor equity flutuante de todo o teste foi de $9.876.74, a conta manteve uma folga ininterrupta de **+$76.74** acima do nível de eliminação. A perda máxima contra o capital inicial foi de apenas $105.66 (saldo) e $123.26 (flutuante), respeitando rigorosamente a regra dos $200.

4. **Identificação da Falha Dimensional no Parser Padrão**:
   - *Fato*: A ferramenta `tools\parse_and_record_results.py` em sua lógica default comparava `metrics['max_dd_money']` ($223.28) diretamente contra `$140.00`, gerando a string incorreta `Sim (DD $223.28 >= $140)`.
   - *Inferência Adversarial*: Isso representava um erro de dimensionalidade analítica — comparar o rebaixamento acumulado de múltiplos dias de teste contra o disjuntor de perda de um único dia. O Worker M3 agiu corretamente ao sobrepor manualmente esse campo no `EXPERIMENTOS.csv` com a explicação analítica correta.

---

## 3. Caveats

1. **Diferença entre Regras de Mesa (Trailing HWM vs. EOD/Static)**:
   - Na regra estrita da Goat Funded Trader 10K, o limite de $200 é calculado a partir do saldo inicial ($9.800 floor) e o limite diário de $140 é resetado no início de cada sessão (00:00 server time).
   - Em mesas proprietárias que adotam *Intraday Trailing High-Water Mark Drawdown* (onde o limite de perda persegue o pico em tempo real), o recuo de $223.28 a partir de $10.100.02 exigiria a ativação do Feature 9 (`EnableHighWaterMarkGuard = true` com `MaxTrailingDDPct = 1.5%`), que já está implementado no código e configurado no `.set`.
2. **Horizonte Amostral do Benchmark EXP-015**:
   - O teste EXP-015 cobriu 3 dias consecutivos de ticks reais (1.440.985 ticks, 30 trades). Embora estatisticamente denso para validação dos mecanismos de disjuntor, sessões com volatilidade extrema de notícias NFP exigem a manutenção incondicional do `EnableNewsFilter = true`.

---

## 4. Conclusion & Verdict

Todas as quatro alegações de blindagem da conta Goat Funded Trader 10K foram **empiricamente verificadas, matematicamente auditadas e aprovadas**:
1. **Trava de Lucro Diário ($100)**: Aprovada. O EA atingiu +$100.02 no Dia 1 e cessou 100% das operações pelo resto do dia.
2. **Disjuntor Diário de Perda ($140)**: Aprovado. Perda fechada de -$89.58 no Dia 2 e -$116.10 no Dia 3; nenhuma sessão tocou no teto de $140.
3. **Disjuntor Total da Conta ($200)**: Aprovado. O valor de $223.28 do MT5 é comprovadamente uma medida High-Water Mark (pico-fundo). O rebaixamento contra a banca inicial foi de apenas $105.66 (saldo) e a equity jamais violou o piso de $9.800 (mínima registrada foi $9.876.74).
4. **Resiliência de Margem e Alavancagem**: Aprovada. O dimensionamento dinâmico em `ValidVolume` impede rejeições por falta de margem sob qualquer alavancagem (1:1 ou 1:100).

### Veredito Final: **APPROVE**

---

## 5. Verification Method

Para reproduzir e verificar de forma independente todas as conclusões deste relatório:

1. **Executar o Script de Auditoria Adversarial**:
   ```powershell
   python C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\verify_challenge_m4.py
   ```
   *Resultado esperado*: Saída tabulada de todos os 61 deals, verificação de todas as asserções de blindagem e mensagem final:
   `EMPIRICAL ADVERSARIAL VERIFICATION COMPLETED SUCCESSFULLY.`

2. **Inspecionar Relatório Oficial MT5**:
   - Abrir no navegador: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_015_V12_1_BENCHMARK\EXP_015_V12_1_BENCHMARK.htm`
   - Confirmar: `Lucro Líquido Total: -105.66`, `Rebaixamento Absoluto do Saldo: 105.66`, `Rebaixamento Máximo do Capital Líquido: 223.28 (2.21%)`.

3. **Executar Bateria de Testes Unitários do Parser**:
   ```powershell
   python C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\test_parser.py
   ```
   *Resultado esperado*: `Ran 8 tests in ... OK`.
