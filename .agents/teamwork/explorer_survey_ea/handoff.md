# RELATÓRIO DE INVESTIGAÇÃO TÉCNICA E GAP ANALYSIS: ALIEN V12.1 INSTITUTIONAL

**Data**: 2026-11-09  
**Autor**: Teamwork Explorer Subagent (`teamwork_explorer`)  
**Arquivo Analisado**: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5` (5.179 linhas)  
**Destinatário**: Orchestrator & Worker Agents (`ALIEN_LAB`)  
**Status**: Concluído (Read-Only Survey)  

---

## Executive Summary

Uma auditoria exaustiva e forense de código-fonte foi conduzida no Expert Advisor `ALIEN_V12_1_INSTITUTIONAL.mq5`, confrontando seus mecanismos com os requisitos do projeto definidos em `ORIGINAL_REQUEST.md` e o registro de decisões históricas em `DECISOES.md` (especialmente a **Decisão D10**). 

Principais conclusões:
1. **Pipeline e Micro-estrutura SMC**: O EA implementa cinco famílias de setup (`LIQUIDITY_SWEEP`, `BOS_RETEST`, `PA_MOMENTUM`, `FVG_REACAO`, `ORDER_BLOCK_REACAO`). A detecção de sweeps (`BSL`/`SSL`) está baseada em uma janela deslizante de 10 barras M1 (`StructureLookbackBars = 10`) com mecanismo de evento persistente em ticks (`ObserveSweepEvent`). Contudo, o setup `BOS_RETEST` está atrelado a `trendM1 > 0`, impedindo a captura de **CHoCH** (reversão estrutural real), e os FVGs são calculados apenas em M5/M15/H1 (não em M1), com `AllowZoneDirectEntries = false` por padrão.
2. **Parâmetro `EnforceStrictHTF` (Decisão D10)**: Declarado na linha 43 como `true` por padrão e avaliado na linha 4976. Ele impõe um veto rígido (`return`) se a direção for contrária à tendência H1 (`higherTrendH1 == -direction`). Isso contradiz frontalmente a Decisão D10 de ticks reais (`DECISOES.md`), pois varreduras de liquidez em M1 são operações rápidas de reversão em extremos; esperar a tendência de H1 virar elimina assimetria e faz o robô entrar atrasado ou perder 100% dos sweeps contra-tendência macro. Ajustar `EnforceStrictHTF = false` ativa a ponderação suave (+5 / -10 pontos de score), restaurando a operação dos sweeps.
3. **Trailing Stop & Breakeven**: Implementados em `ManageOpenPosition` (linhas 2577-2750). Contém um breakeven rápido (`EnableFastBreakEven = true`, `FastBERatio = 1.20`) e um trailing stop adaptativo baseado em ATR. Todavia, a variável `RunnerMinimumHoldSeconds = 10` impõe uma trava obrigatória de 10 segundos antes de qualquer ajuste de stop; no M1 de ouro, impulsos violentos de sweep frequentemente atingem 30-60 pontos em 3 a 5 segundos e retraem, fazendo o trade devolver lucros antes de vencer os 10 segundos.
4. **Blindagem Goat Funded Trader 10K (Gap Crítico)**:
   - **Meta Diária ($100)**: Existe (`DailyProfitTargetMoney = 100.00`), mas atua apenas bloqueando *novas* entradas após PnL realizado. Não há disjuntor para zerar a mercado e garantir o dia quando o lucro flutuante + realizado atingir $100.
   - **Disjuntor Diário de Perda ($140)**: Implementado e funcional (`DailyMaxLossMoney = 140.00` + `EnableHardCircuitBreaker = true`). Fecha posições instantaneamente a mercado e trava o dia via GlobalVariable.
   - **Limite Máximo Total da Mesa ($200)**: **AUSENTE NO CÓDIGO.** O EA possui apenas `WeeklyMaxLossMoney = 400.00`. Não existe parâmetro ou disjuntor para travar a conta ao acumular $200 de perda total (drawdown máximo da mesa), representando risco imediato de quebra de regra na prop firm.
5. **Dimensionamento de Lotes e Alavancagem**: O lote padrão está configurado como `FixedLot = 0.18`. Em alavancagem padrão 1:100 (mesa Goat 10K), 0.18 lote de XAUUSD consome ~$490 de margem (~4,9% da conta), operando perfeitamente. Porém, em contas ou testes com alavancagem 1:1 (como na conta Demo RoboForex 67316641), a margem exigida salta para ~$49.000, e o EA falha com 100% de rejeição em `CheckExposure` e `PreflightOrder`. Não há redimensionamento dinâmico automático de lotes para margem restrita.

---

## 1. Observation (Evidências Diretas do Código-Fonte)

### 1.1 Arquitetura Geral e Pipeline de Sinais

O arquivo `ALIEN_V12_1_INSTITUTIONAL.mq5` é um expert autônomo e monolítico de 5.179 linhas.
Seus pontos de entrada principais são:
- `OnInit()` (linhas 4452-4673): Inicializa handles de indicadores (EMAs e ATRs para M1, M5, M15, H1), variáveis globais de terminal, telemetria e o professor visual institucional.
- `OnTick()` (linhas 4676-5101): Executado a cada tick do símbolo `_Symbol` (XAUUSD).
- `OnTradeTransaction()` (linhas 5104-5142): Atualiza estatísticas diárias e reconcilia operações.
- `OnTimer()` (linhas 5145-5177): Atualiza mapa institucional, ordens pendentes em zonas e telemetria.

O pipeline de execução em cada tick segue a seguinte ordem sequencial:
1. **Verificação de Baseline e Disjuntores de Emergência** (`OnTick`, linhas 4680-4728):
   - Atualiza `dayOpeningEquity` e `dailyPeakEquity`.
   - Executa Circuit Breaker Diário (`DailyMaxLossMoney`).
   - Executa Trailing Drawdown Guard (`MaxTrailingDDPct`).
   - Executa Proteção de Fim de Semana na Sexta-feira (`FridayStopTradingHour:FridayForceCloseMinute`).
2. **Gerenciamento de Posições Existentes** (`OnTick`, linha 4764):
   - Chama `ManageOpenPosition(tick, shortM, atrPts)` antes de examinar novas entradas.
3. **Filtros de Permissão de Entrada** (`OnTick`, linhas 4766-4869):
   - `NewEntriesAllowedBySupervisor()` (Disjuntor diário, semanal, meta de lucro, perda percentual).
   - `AlienSessionEntryAllowed()` (Horários e sessões operacionais).
   - Limite de frequência: `OneEntryPerM1Candle`, `MaxEntriesPerM1Candle`, `MinMsBetweenEntries` (250ms), `MinMsAfterExit` (1500ms).
   - Pausa pós-perdas consecutivas (`LossStreakPauseAfter = 3`, `LossStreakPauseSeconds = 1800`).
   - Anti-sobreposição de posições (`SymbolHasAnyPosition()`).
   - Checagem de integridade de ticks no candle (`MinTicksInCandle = 4`, `MinMillisecondsInBar = 750`).
   - Checagem de segurança de mercado (`EntryMarketSafe`: spread <= 25 pts, spread/ATR).
4. **Determinação de Direção e Impulso de Ticks** (`OnTick`, linhas 4870-4932):
   - Prioridade de reversão rápida para eventos de varredura frescos: `freshBuy` / `freshSell`.
   - Medição de janelas curta (`ShortWindowMs = 350`) e longa (`LongWindowMs = 1600`).
   - Verificação de pressão direcional (`MinDirectionalPercent = 54.0%`).
5. **Filtro de Contexto HTF e Scoring Técnico** (`OnTick`, linhas 4934-5010):
   - Cálculo de tendência M15 e H1 via EMAs.
   - Avaliação de `EnforceStrictHTF` (linha 4976).
   - Cálculo do score (0 a 100) via `ScoreSignal`. Exige `lastScore >= MinimumScore` (48).
6. **Seleção e Validação do Setup Institucional** (`OnTick`, linhas 5012-5069):
   - Chama `SelectSetup()`. Se `RequireSetupValidation = true` e nenhum setup bater, descarta.
   - Aplica filtros de extensão máxima de vela (`SweepMaxCandleExtensionATR = 0.70`), score mínimo do sweep (`SweepMinimumEntryScore = 50`) e deduplicação de evento (`activeSweepSeq != lastTradedSweepSeq`).
7. **Execução de Entrada** (`OnTick`, linhas 5087-5096):
   - Chama `SendEntry()` que valida exposição (`CheckExposure`), faz preflight MT5 (`PreflightOrder`) e envia a ordem a mercado via `trade.PositionOpen()`.

---

### 1.2 Microestrutura Institucional (Sweeps, FVG e CHoCH/BOS)

#### A. Liquidity Sweeps (BSL/SSL)
- **Localização**: `ObserveSweepEvent()` (linhas 1829-1925) e `SelectSetup()` (linhas 2020-2079).
- **Mapeamento de Liquidez**:
  ```mql5
  1839: StructureExtremes(1, StructureLookbackBars, sweepCachedHigh, sweepCachedLow);
  ```
  `StructureLookbackBars` está parametrizado como `10` (linha 77). Mapeia apenas as últimas 10 barras M1 fechadas.
- **Gatilho de Varredura**:
  - Compra (SSL Sweep): Rompimento de mínima:
    ```mql5
    1844: double buyBreak = sweepCachedLow - MinSweepPoints * _Point;
    1846: bool crossedLow = (sweepLastBid > 0.0 && sweepLastBid > buyBreak && tick.bid <= buyBreak);
    ```
    `MinSweepPoints` é `3.0` pontos ($0.30 no Ouro).
  - Venda (BSL Sweep): Rompimento de máxima:
    ```mql5
    1845: double sellBreak = sweepCachedHigh + MinSweepPoints * _Point;
    1847: bool crossedHigh = (sweepLastBid > 0.0 && sweepLastBid < sellBreak && tick.bid >= sellBreak);
    ```
  - Re-varredura mais profunda (`deeperBuy`/`deeperSell`): Acionada se o preço avançar `SweepNewExtremeToRefreshPts = 12.0` pontos além do extremo anterior.
- **Confirmação e Retomada (Reclaim)**:
  - Compra: `tick.bid >= sweepEventLevelBuy + SweepReclaimPoints * _Point` (`SweepReclaimPoints = 1.0` ponto = $0.10).
  - Venda: `tick.bid <= sweepEventLevelSell - SweepReclaimPoints * _Point`.
  - Requer permanência por `SweepReclaimConfirmTicks = 2` ticks consecutivos.
  - Expiração do evento: `SweepEventMaxAgeSeconds = 55` segundos.
- **Validação no Setup**:
  - Profundidade mínima da cauda: `sweepDepthPts >= atrPts * SweepMinimumWickATR` (`SweepMinimumWickATR = 0.04` ATR).
  - Distância máxima do nível para execução: `distanceFromLevelPts <= maxDistPts` (`SweepAllowedDistanceATR = 0.15` a `0.25` ATR adaptativo).

#### B. Fair Value Gaps (FVG)
- **Localização**: `NearestHTFZone()` (linhas 1727-1805) e `SelectSetup()` (linhas 2111-2121).
- **Cálculo Algorítmico**:
  - Analisa barras fechadas em M5, M15 e H1 nos últimos `HigherTFScanBars = 16` candles:
    ```mql5
    1748: if(direction > 0) {
    1750:    lo = iHigh(_Symbol, tf, shift + 1);
    1751:    hi = iLow(_Symbol, tf, shift - 1);
    1752: } else {
    1754:    lo = iHigh(_Symbol, tf, shift - 1);
    1755:    hi = iLow(_Symbol, tf, shift + 1);
    1756: }
    1758: if(lo > 0.0 && hi - lo >= MinFVGPoints * _Point && !ZoneFullyMitigated(tf, shift - 1, direction, lo, hi))
    ```
  - Tamanho mínimo do FVG: `MinFVGPoints = 10.0` pontos ($1.00 no Ouro).
  - Mitigação: `ZoneFullyMitigated()` invalida se qualquer vela subsequente violar o extremo oposto do gap.
- **Limitação Crítica Identificada**:
  - `AllowZoneDirectEntries` está como `false` por padrão (linha 76).
  - O FVG **não é calculado no timeframe M1**.
  - O FVG atua apenas fornecendo +5 pontos no score geral se o preço estiver na zona (`line 4988`).

#### C. Quebra de Estrutura (CHoCH / BOS Retest)
- **Localização**: `SelectSetup()` (linhas 2081-2109).
- **Código Existente**:
  ```mql5
  2089: bool buyBOS = direction>0 && trendM1>0 &&
  2090:    prevClose>olderHigh + BOSBreakPoints*_Point &&
  2091:    prevClose>prevOpen &&
  2092:    currentLow<=olderHigh+RetestTolerancePoints*_Point &&
  2093:    bid>olderHigh + SweepReclaimPoints*_Point &&
  2094:    shortM.movePoints>0.0;
  ```
- **Condições e Limitações**:
  - `BOSBreakPoints = 3.0` pontos.
  - `RetestTolerancePoints = 10.0` pontos.
  - **Exigência de `trendM1 > 0`**: Exige que a EMA 9 esteja acima da EMA 21 no M1. Isso define uma quebra de continuação (BOS), mas **inviabiliza a detecção de um CHoCH** (Change of Character), que por definição é a reversão inicial de uma tendência prévia onde a EMA ainda está contrária.

---

### 1.3 Parâmetro `EnforceStrictHTF` e Decisão D10

#### Declaração e Inicialização
- Linha 42-43:
  ```mql5
  input group "=== FILTRO MULTI-TIMEFRAME (HTF VETO ABSOLUTO) ==="
  input bool   EnforceStrictHTF         = true;   // VETO: Nao compra se H1 for Baixa, nao vende se H1 for Alta
  ```

#### Ponto Exato de Avaliação no Código
- Linhas 4974-4983 em `OnTick()`:
  ```mql5
  4974: if(UseHigherTimeframes)
  4975: {
  4976:    if(EnforceStrictHTF && higherTrendH1 != 0 && higherTrendH1 == -direction)
  4977:    {
  4978:       lastReason = StringFormat("VETO HTF H1: Direcao %s contraria a tendencia H1 (%s). Bloqueado.",
  4979:                                 (direction > 0 ? "COMPRA" : "VENDA"),
  4980:                                 (higherTrendH1 > 0 ? "ALTA" : "BAIXA"));
  4981:       Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
  4982:       return;
  4983:    }
  ```

#### Efeito de `EnforceStrictHTF = false`
Quando `EnforceStrictHTF = false`, a instrução `return` das linhas 4976-4983 é completamente ignorada. O fluxo prossegue imediatamente para as linhas 4984-4990:
```mql5
4984: if(higherTrendM15==direction) lastScore+=HTFTrendBonus/2;
4985: if(higherTrendH1==direction) lastScore+=HTFTrendBonus/2;
4986: if(higherTrendM15==-direction && higherTrendH1==-direction)
4987:    lastScore-=HTFTrendBonus;
4988: if(zoneId>0 && zd<=atrPts*ZoneToleranceATR) lastScore+=5;
4989: lastScore=(int)MathMax(0,MathMin(100,lastScore));
```
- Em vez de um veto cego que descarta o trade, uma tendência contrária em M15 e H1 aplica uma penalidade suave de `-10` pontos (`HTFTrendBonus = 10`).
- Se a varredura e o impulso de ticks forem fortes (score bruto de 65-75), o sinal final mantém score entre 55 e 65, superando `MinimumScore = 48` e `SweepMinimumEntryScore = 50`, permitindo a execução de reversões em ticks reais.
- Isso cumpre exatamente a **Decisão D10** de `DECISOES.md`.

---

### 1.4 Análise de Trailing Stop e Breakeven

- **Função**: `ManageOpenPosition()` (linhas 2577-2750).
- **Parâmetros de Entrada Ativos**:
  - `EnableFastBreakEven = true` (linha 28)
  - `FastBERatio = 1.20` (1.2R, linha 29)
  - `BreakEvenAfterPoints = 60.0` (linha 158)
  - `TrailStartPoints = 90.0` (linha 159)
  - `MinTrailStepPoints = 6.0` (linha 44)
  - `ModifyCooldownMs = 550` (linha 165)
  - `RunnerMinimumHoldSeconds = 10` (linha 166)
  - `RunnerLockBufferPts = 5.0` (linha 162)
  - `UseAdaptiveRunner = true` (linha 168)
  - `AdaptiveBEStartATR = 0.33` (linha 169)
  - `AdaptiveTrailStartATR = 0.55` (linha 170)
  - `AdaptiveTrendTrailATR = 0.40` (linha 171)
  - `AdaptiveNormalTrailATR = 0.27` (linha 172)
  - `AdaptiveReversalTrailATR = 0.20` (linha 173)

#### Detalhe dos Mecanismos:
1. **Breakeven Rápido em 1.2R**:
   ```mql5
   2690: if(EnableFastBreakEven && sl > 0.0 && tp > 0.0)
   2691: {
   2692:    double riskPts = MathAbs(entry - sl) / _Point;
   2693:    double gainPts = direction * (quote - entry) / _Point;
   2694:    if(riskPts > 1.0 && gainPts >= riskPts * FastBERatio)
   2695:    {
   2696:       double bePrice = entry + direction * (commissionPts + RunnerLockBufferPts) * _Point;
   2697:       if(direction > 0 && (candidate == 0.0 || candidate < bePrice)) candidate = bePrice;
   2698:       else if(direction < 0 && (candidate == 0.0 || candidate > bePrice)) candidate = bePrice;
   2699:    }
   2700: }
   ```
2. **Breakeven por Pontos Fixos / ATR**:
   - Gatilho: `gainPts >= MathMax(BreakEvenAfterPoints, atrPts * AdaptiveBEStartATR)`.
3. **Trailing Stop Adaptativo**:
   - Acionamento: `gainPts >= MathMax(TrailStartPoints, atrPts * AdaptiveTrailStartATR)`.
   - Distância dinâmica: 0.40 ATR (tendência forte), 0.27 ATR (neutro), 0.20 ATR (contra-impulso).
4. **Frequência e Throttle**:
   - `ModifyCooldownMs = 550`: Impede envio de requisições de modificação em intervalos menores que 550 ms.
   - `MinTrailStepPoints = 6.0`: Só envia `trade.PositionModify` se o novo SL for pelo menos 6 pontos melhor que o SL atual.
   - `RunnerMinimumHoldSeconds = 10`: **Trava crítica de latência.** Se `TimeCurrent() - opened < 10`, a função executa `continue` (linha 2676), ignorando breakeven e trailing stop durante os primeiros 10 segundos de vida do trade.

---

### 1.5 Gestão de Risco e Blindagem (Goat Funded Trader 10K)

Comparação entre as regras da mesa Goat 10K e o código do EA:

| Regra Goat Funded Trader 10K | Parâmetro no Código | Implementação no Código | Avaliação Forense |
|---|---|---|---|
| **Meta Diária de Ganho: $100** | `DailyProfitTargetMoney = 100.00`, `StopOnDailyProfitTarget = true` (linhas 19-20) | Linha 1215 em `NewEntriesAllowedBySupervisor()`: bloqueia *novas* entradas se `dailyRealizedNet >= 100.00`. | **PARCIAL / GAP**: Não monitora lucro flutuante nem encerra posições abertas compulsoriamente ao atingir +$100. Depende de TP/trailing para realizar. |
| **Disjuntor Diário de Perda: $140** | `DailyMaxLossMoney = 140.00`, `EnableHardCircuitBreaker = true` (linhas 21-22) | Linhas 4687-4698 em `OnTick()`: fecha todas as ordens a mercado instantaneamente (`CloseAllPositionsInstantly`) e trava novas ordens via GlobalVariable `LOCK`. | **CONFORME / BLINDADO**: Atua sobre flutuante e realizado com corte imediato. |
| **Limite Máximo Total de Perda: $200** | **INEXISTENTE** (apenas `WeeklyMaxLossMoney = 400.00`, linha 23) | Linhas 1195-1211 em `NewEntriesAllowedBySupervisor()` apenas checam `WeeklyMaxLossMoney` contra `weekOpeningEquity` (reiniciado toda segunda-feira). | **GAP CRÍTICO**: Não existe proteção para o drawdown acumulado total de $200 da conta. Risco de desclassificação na mesa. |
| **Acompanhamento de Baseline** | `dayOpeningEquity`, `weekOpeningEquity` (linhas 1115-1185) | Gravados em variáveis globais do terminal vinculadas ao login da conta e timestamp diário/semanal. | **BOM**: Persiste entre reinicializações do MT5. Falta baseline da banca inicial ($10.000). |

---

### 1.6 Dimensionamento de Lotes e Análise de Margem

- Parâmetro: `FixedLot = 0.18` (linha 120).
- Pré-validações de Margem:
  1. `CheckExposure()` (linhas 2307-2327):
     ```mql5
     2313: if(!OrderCalcMargin(side,_Symbol,volume,price,margin)) return false;
     2317: if(freeMargin > 0.0 && freeMargin - margin < MinFreeMarginMoney) return false;
     2319: double marginShare=(AccountInfoDouble(ACCOUNT_MARGIN)+margin)/eq*100.0;
     2320: if(marginShare>MaxBaseMarginPercentEquity) return false;
     ```
     `MaxBaseMarginPercentEquity = 50.0%` (linha 138).
  2. `PreflightOrder()` (linhas 1349-1401):
     Executa `OrderCheck(req, check)` nativo do MT5. Exige `check.margin_free >= 3.0` e `check.margin_level >= 150.0%`.
- Análise de Alavancagem:
  - **Em 1:100 (Goat Funded Trader 10K)**:
    - 0.18 lotes de XAUUSD (18 oz a $2.700) = $48.600 de valor nocional.
    - Margem necessária = $486,00.
    - Margem sobre capital de $10.000 = 4,86% (< 50% de teto). Margem livre restante = $9.514,00.
    - Nível de margem projetado = 2.057% (> 150%).
    - **Execução perfeitamente liberada.**
  - **Em 1:1 (RoboForex Demo 67316641)**:
    - Margem necessária = $48.600,00 (ou até $74.160 dependendo da cotação/tabela).
    - Para conta de $10.000, `marginShare` = 486% (> 50%). Margem livre fica negativa em -$38.600.
    - `CheckExposure` rejeita por "Margem livre insuficiente" ou "Margem total elevada".
    - `OrderCheck` rejeita com código 10019 (`TRADE_RETCODE_NO_MONEY`).
    - **Resultado**: 100% dos trades são bloqueados e nenhum backtest/operação é aberto se a conta estiver sob alavancagem 1:1 com lote 0.18.

---

## 2. Logic Chain (Raciocínio Lógico das Evidências à Conclusão)

### Cadeia Lógica 1: Impacto do Veto `EnforceStrictHTF = true` nos Sweeps
- **Passo 1 (Obs 1.3)**: `EnforceStrictHTF = true` executa um retorno imediato em `OnTick()` (linhas 4976-4982) caso a tendência de H1 seja contrária à direção do sinal.
- **Passo 2 (Obs 1.2)**: Uma varredura de liquidez (BSL/SSL) em M1 ocorre quando o preço estoura a máxima ou mínima dos últimos 10 candles para capturar stops e reverte bruscamente na direção oposta.
- **Passo 3 (Obs 1.3 + DECISOES.md D10)**: Em um movimento de baixa em H1 (médias apontando para baixo), varreduras de Sell-Side Liquidity (SSL) são oportunidades primárias de compra por exaustão/reversão rápida. Como H1 é Baixa, `higherTrendH1 == -1` e o sinal de compra (`direction == 1`) é 100% vetado.
- **Conclusão**: O veto rígido HTF mutila a estratégia de sweeps em M1 e degrada o Profit Factor. Mudar para `EnforceStrictHTF = false` restabelece o scoring suave, permitindo trades de reversão conforme comprovado na Decisão D10.

### Cadeia Lógica 2: Latência do Trailing Stop / BE no M1
- **Passo 1 (Obs 1.4)**: `RunnerMinimumHoldSeconds = 10` impede categoricamente qualquer modificação de stop nos primeiros 10 segundos da posição.
- **Passo 2 (Obs 1.4)**: O ativo é XAUUSD no timeframe M1, com ATR típico de 100 a 150 pontos ($1,00 a $1,50) por minuto.
- **Passo 3**: Em momentos de sweep e expansão de liquidez, o ouro percorre 40 a 70 pontos em menos de 5 segundos e pode retrair imediatamente formando pavio.
- **Conclusão**: Se uma posição atinge a meta de Breakeven rápido (1.2R = ~25-30 pontos) no segundo 4, mas recua no segundo 8, ela é fechada no stop loss inicial completo porque o robô foi proibido de agir até o segundo 10. Reduzir ou zerar esse tempo quando 1.0R for atingido é imperativo para proteger o capital.

### Cadeia Lógica 3: Risco de Violação de Regras na Goat Funded Trader 10K
- **Passo 1 (Obs 1.5)**: A regra da Goat 10K estipula: Meta Diária $100, Perda Diária Máxima $140, Perda Total Máxima $200.
- **Passo 2 (Obs 1.5)**: O código possui `DailyMaxLossMoney = 140.00` que fecha ordens a mercado e trava o dia. Isto está blindado.
- **Passo 3 (Obs 1.5)**: O código **NÃO possui disjuntor de perda total acumulada de $200**. Apenas existe `WeeklyMaxLossMoney = 400.00`.
- **Passo 4**: Se o robô tiver uma perda de $120 em um dia e $90 no dia seguinte, a perda acumulada é de $210. O disjuntor diário não disparou em nenhum dos dois dias (ambos < $140), e o semanal não disparou ($210 < $400), mas a conta da mesa proprietária foi violada e cancelada por ultrapassar o limite de $200.
- **Conclusão**: É indispensável implementar o parâmetro `TotalMaxLossMoney = 200.00` monitorando o capital inicial de depósito/balanço e abortando as operações globalmente caso a perda acumulada atinja $200.

### Cadeia Lógica 4: Incompatibilidade de Margem em Contas 1:1
- **Passo 1 (Obs 1.6)**: 0.18 lote no ouro requer ~$486 de margem em 1:100 e ~$48.600 em 1:1.
- **Passo 2 (Obs 1.6)**: A rotina `CheckExposure()` rejeita qualquer ordem onde a margem necessária exceda 50% da equidade (`MaxBaseMarginPercentEquity = 50.0%`) ou onde `freeMargin - margin < 3.0`.
- **Passo 3 (Obs 1.6)**: Em ambiente com alavancagem 1:1 (como na conta RoboForex 67316641), a margem exigida excede 400% da conta de $10.000, provocando 100% de rejeição em tempo de execução.
- **Conclusão**: Para operar em contas com restrição de alavancagem sem desativar as proteções de risco, o EA precisa de um redimensionamento automático de volume baseado na margem máxima permitida (`CalculateSafeLot()`), ou os scripts de teste devem sempre forçar `-Leverage 100` e `-Deposit 10000`.

---

## 3. Caveats (Ressalvas e Limitações da Investigação)

1. **Compilação via Linha de Comando no Ambiente Atual**: A execução interativa de scripts python externos para disparo de compilação do MetaEditor foi evitada para respeitar a política estrita de read-only e decisões de permissão do sistema operacional Windows. O código foi inspecionado de ponta a ponta via leitura estática direta dos arquivos `.mq5` e scripts `.ps1`.
2. **Dependência de Histórico de Ticks Reais da RoboForex**: A validação prática dos parâmetros depende da integridade do banco de dados de ticks reais armazenado no MT5 (`%APPDATA%\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`). Conforme documentado em D02, o arquivo `origin.txt` já se encontra devidamente ajustado.
3. **Comissões e Spreads Noturnos**: O spread do XAUUSD costuma alargar de 15-20 pontos para 45-80 pontos entre 23:50 e 01:10 UTC (virada de sessão). Os filtros existentes (`AbsoluteMaxSpreadPts = 25`) bloqueiam entradas nesse período, mas o trailing stop de posições abertas antes desse horário pode ser atingido pelo alargamento do spread se não houver fechamento prévio.

---

## 4. Conclusion & Recommended Implementation Strategy for Workers

O EA `ALIEN_V12_1_INSTITUTIONAL.mq5` possui uma base institucional e quantitativa extremamente sólida, com estruturas sofisticadas de tick scaling, AMD e leitura SMC. No entanto, para atingir a blindagem total exigida para a conta Goat Funded Trader 10K e a consistência no XAUUSD M1, os Workers de implementação devem executar as seguintes tarefas cirúrgicas:

### Plano de Implementação para os Workers (Tarefas Prioritárias):

#### Tarefa 1: Ajuste Padrão de `EnforceStrictHTF = false` (Decisão D10)
- **Arquivo**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- **Linha**: 43
- **Ação**: Alterar o valor padrão de:
  ```mql5
  input bool   EnforceStrictHTF         = true;
  ```
  para:
  ```mql5
  input bool   EnforceStrictHTF         = false;  // Decisao D10: Ponderacao suave ativada, veto rigido desligado
  ```

#### Tarefa 2: Implementação do Disjuntor de Perda Total da Mesa ($200) e Trava de Meta Flutuante ($100)
- **Arquivo**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- **Ação**:
  1. Adicionar input de perda total máxima acumulada no grupo da Mesa:
     ```mql5
     input double TotalMaxLossMoney        = 200.00; // Limite maximo total de perda da conta Goat ($200)
     ```
  2. Implementar chave persistente de equidade inicial da conta (`accountStartingEquityKey`), lendo o depósito inicial ou primeiro balanço e salvando em GlobalVariable.
  3. No `OnTick()`, junto ao disjuntor diário, incluir o disjuntor de perda total:
     ```mql5
     if(TotalMaxLossMoney > 0.0)
     {
        double totalLoss = accountStartingBalance - currentEq;
        if(totalLoss >= TotalMaxLossMoney)
        {
           CloseAllPositionsInstantly("TOTAL_ACCOUNT_CIRCUIT_BREAKER");
           CancelAllPendingOrders();
           GlobalVariableSet(accountStartingEquityKey + "_LOCK", 1.0);
           supervisorMessage = StringFormat("DISJUNTOR TOTAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. EA TRAVADO.", totalLoss, TotalMaxLossMoney);
        }
     }
     ```
  4. Adicionar trava ativa de lucro diário flutuante no `OnTick()`:
     ```mql5
     if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
     {
        double currentDailyGain = (currentEq - dayOpeningEquity);
        if(currentDailyGain >= DailyProfitTargetMoney)
        {
           CloseAllPositionsInstantly("DAILY_PROFIT_TARGET_SECURED");
           CancelAllPendingOrders();
           GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
           supervisorMessage = StringFormat("META DIARIA GARANTIDA: Lucro +$%.2f >= Meta +$%.2f. Posicoes zeradas e dia encerrado!", currentDailyGain, DailyProfitTargetMoney);
        }
     }
     ```

#### Tarefa 3: Otimização do Trailing Stop e Breakeven para M1 XAUUSD
- **Arquivo**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- **Ação**:
  1. Reduzir `RunnerMinimumHoldSeconds` de `10` para `2` (ou liberar imediatamente se `gainPts >= riskPts * FastBERatio`).
  2. Calibrar `FastBERatio` para `1.00` (1.0R em vez de 1.2R) para puxar o stop para BE + buffer assim que o preço pagar o risco inicial.
  3. Calibrar `BreakEvenAfterPoints` de `60.0` para `35.0` pontos ($0.35) e `TrailStartPoints` de `90.0` para `55.0` pontos ($0.55).

#### Tarefa 4: Refinamento de Micro-estrutura (CHoCH Reversal e FVG M1)
- **Arquivo**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- **Ação**:
  1. Desacoplar o setup de quebra estrutural pós-sweep de `trendM1 > 0` para permitir a detecção de **CHoCH** (quebra de máxima prévia em reversão de fundo mesmo antes do alinhamento das médias M1).
  2. Adicionar escaneamento de FVG no próprio timeframe `PERIOD_M1` em `NearestHTFZone()` para capturar o gap de deslocamento pós-varredura.
  3. Aumentar `SweepReclaimPoints` de `1.0` para `3.0` pontos para evitar falsos reclaims causados por ruído do spread de 20 pontos do ouro.

#### Tarefa 5: Proteção e Compatibilidade de Margem (0.18 vs 1:1)
- **Arquivo**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`
- **Ação**:
  1. Em `ValidVolume()`, incluir cálculo de lote máximo permitido pela margem livre da conta caso a alavancagem seja restrita:
     ```mql5
     double marginPerLot = 0.0;
     if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginPerLot) && marginPerLot > 0.0)
     {
        double maxAffordableLot = (AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.45) / marginPerLot;
        if(requested > maxAffordableLot)
           requested = maxAffordableLot;
     }
     ```
  2. Isso garante que se o EA for colocado em conta demo 1:1, ele opere automaticamente com lote reduzido (ex: 0.01 ou 0.02) sem gerar erros de execução, enquanto em contas 1:100 ele operará normalmente com os 0.18 lotes parametrizados.

---

## 5. Verification Method (Método de Verificação Independente)

Para que qualquer auditor ou agente verifique as conclusões deste relatório:

1. **Inspeção de Código**:
   - Abrir `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`.
   - Verificar linha 43: conferir valor de `EnforceStrictHTF`.
   - Verificar linha 4976: conferir a cláusula de veto `if(EnforceStrictHTF && higherTrendH1 != 0 && higherTrendH1 == -direction) return;`.
   - Verificar linha 2675: conferir `RunnerMinimumHoldSeconds = 10`.
   - Verificar linhas 1195-1211: constatar ausência de `TotalMaxLossMoney` (apenas `WeeklyMaxLossMoney = 400.00`).
   - Verificar linhas 2313-2321: constatar fórmula de margem máxima em `CheckExposure`.
2. **Compilação**:
   - Executar o MetaEditor 64 via PowerShell ou script `tools\compile_v12_1.py`:
     `"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe" /compile:"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5" /log:"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\compile_v12_1.log"`
   - Verificar se o log reporta `0 errors, 0 warnings`.
3. **Validação de Backtest**:
   - Executar `tools\Run-Backtest.ps1 -ExpertPath "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5" -Symbol "XAUUSD" -Period "M1" -FromDate "2026.10.21" -ToDate "2026.11.06" -Deposit 10000 -Leverage 100 -Model 4`.
   - Confirmar no relatório gerado que o número de trades, Win Rate, Profit Factor e Drawdown respeitam rigorosamente o teto de $200 de rebaixamento total e $140 de perda diária.
