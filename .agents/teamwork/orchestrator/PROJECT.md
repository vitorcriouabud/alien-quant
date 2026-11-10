# Project: ALIEN_LAB — Validação e Refinamento Algorítmico do EA ALIEN_V12_1_INSTITUTIONAL

## Architecture
- **Trading Platform**: MetaTrader 5 (RoboForex MT5 Terminal / MetaEditor 64)
- **Target Asset & Timeframe**: XAUUSD (Gold), M1 timeframe
- **Target Account Rules**: Goat Funded Trader 10K ($10,000 initial balance, $100 daily target lock, $140 daily loss circuit breaker, $200 total max loss hard stop, 0.18 standard lot size, 1:100 leverage)
- **EA Core Engine**: `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5` (Microstructural SMC tick scalper)
- **Signal Pipeline**:
  1. Microstructural Order Flow & Tick Windows (350ms / 1600ms)
  2. BSL / SSL Liquidity Sweep Detection & Wick Reclaim
  3. Fair Value Gap (FVG) and Break of Structure / CHoCH Retest
  4. Soft HTF Confluence Scoring (`EnforceStrictHTF = false` per Decision D10)
  5. Dynamic Risk & Prop Shielding (Daily Target $100, Circuit Breaker $140, Total Loss $200)
  6. Execution & Margin Validation (`OrderCheck`, `CheckExposure`)
  7. Fast Breakeven (1.2R) and Adaptive ATR Trailing Stop
- **Testing & Tooling Pipeline**:
  - `tools\Run-Backtest.ps1`: Headless Strategy Tester execution with Real Ticks (`Model=4`)
  - `tools\parse_and_record_results.py`: Unified metrics extraction and consolidation into `EXPERIMENTOS.csv`
  - Tick Cache: Local cached real ticks (`202610.tkc`, `202611.tkc`) in terminal data folder

## Feature Inventory
| # | Feature | Description | Milestone | Source | Status |
|---|---------|-------------|-----------|--------|--------|
| 1 | Tick Impulse Scalping | Evaluates M1 microstructural order flow over 350ms and 1600ms tick windows | M2 | Survey | DONE |
| 2 | Liquidity Sweep Detection | Detects BSL/SSL sweeps beyond previous swing highs/lows with wick reclamation | M2 | Survey | DONE |
| 3 | BOS / CHoCH with Retest | Identifies true structural break/reversal (decoupled from trendM1 > 0) and retest | M2 | Survey | DONE |
| 4 | HTF Soft Confluence (D10) | `EnforceStrictHTF = false` default; rewards M15/H1 alignment (+5/+10) without hard veto | M2 | Survey / D10 | DONE |
| 5 | FVG Reaction & Confluence | Scans and scores Fair Value Gaps with M1 reaction support | M2 | Survey | DONE |
| 6 | Daily Profit Lock ($100) | Stops new entries for the day once realized net profit >= $100; option to bank floating | M2 | Survey / Goat 10K | DONE |
| 7 | Daily Loss Circuit Breaker ($140) | Emergency market close & daily freeze if daily floating/closed loss reaches -$140 | M2 | Survey / Goat 10K | DONE |
| 8 | Total Max Loss Circuit Breaker ($200) | Hard account loss protection strictly preventing cumulative drawdown from reaching $200 | M2 | Survey / Goat 10K | DONE |
| 9 | High-Water Mark Trailing Guard | Protects session profits if equity falls 1.5% from intraday peak | M2 | Survey | DONE |
| 10 | Loss Streak Pause | Pauses EA for 30 minutes after 3 consecutive stop losses | M2 | Survey | DONE |
| 11 | Daily Trade Frequency Cap | Limits entries to 12 trades per day to avoid overtrading | M2 | Survey | DONE |
| 12 | Friday Weekend Close | Forcibly closes all positions at 16:45 UTC Friday with zero weekend risk | M2 | Survey | DONE |
| 13 | Native MT5 News Filter | Halts entries ±15 min around High-Impact USD economic events | M2 | Survey | DONE |
| 14 | Preflight Margin & Precheck | Simulates order before dispatch via MT5 `OrderCheck()` | M2 | Survey | DONE |
| 15 | One Entry Per M1 Candle | Prevents multiple entries within the same 1-minute candle | M2 | Survey | DONE |
| 16 | Fast Breakeven Protection | Moves stop to entry + fees once profit hits 1.2R (eliminating 10s hold stall) | M2 | Survey | DONE |
| 17 | Adaptive Trailing Stop | Trails stop based on ATR and directional alignment (0.27 to 0.40 ATR) | M2 | Survey | DONE |
| 18 | Portuguese Teacher Panel HUD | Renders live SMC reading, circuit breaker levels, and trade state on chart | M2 | Survey | DONE |
| 19 | Headless Backtest Automation | Automates MT5 Strategy Tester execution with real ticks (`Model=4`) | M1 | Survey / Tools | DONE |
| 20 | Unified Metrics Parsing & CSV Tabulation | Extracts Win Rate, PF, DD ($/%), R:R, and appends to `EXPERIMENTOS.csv` | M1 | Survey / Tools | DONE |
| 21 | Mass Validation Benchmark Run | Executes real tick test covering 2026.10.21 to 2026.11.06, validating zero error logs | M3 | Survey / R1 | DONE |
| 22 | Forensic Integrity & Shield Verification | Independent audit verifying authentic logic and Goat 10K rule compliance | M4 | Survey / Forensic | DONE |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Test Infra & Metrics Automation | Extend `Run-Backtest.ps1`, create `tools\parse_and_record_results.py`, verify parsing on EXP-014 | none | DONE |
| M2 | MQL5 Refinement & Shielding | Configure `EnforceStrictHTF=false`, implement TotalMaxLoss $200, fast BE delay bypass, FVG/CHoCH refinement, compile 0 errors | none | DONE |
| M3 | Mass Backtest & Validation Run | Run Strategy Tester on real ticks (2026.10.21 - 2026.11.06), confirm clean logs, extract & tabulate metrics in EXPERIMENTOS.csv | M1, M2 | DONE |
| M4 | Final Forensic Audit & Verification | Verify Goat 10K shield criteria (Daily loss < $140, Total DD < $200, Target $100) and conduct Forensic Integrity Audit | M3 | DONE |

## Interface Contracts
### MT5 Tester CLI <-> Strategy Tester Config
- Execution: `terminal64.exe /config:"<path.ini>"`
- Configuration keys: `Expert=ALIEN_LAB_EXCLUSIVO_TESTADOR\ALIEN_V12_1_INSTITUTIONAL`, `ExpertParameters=ALIEN_V12_1_INSTITUTIONAL.set`, `Symbol=XAUUSD`, `Period=M1`, `Model=4`, `FromDate=2026.10.21`, `ToDate=2026.11.07`, `Deposit=10000`, `Leverage=1:100`, `ShutdownTerminal=1`

### Tester HTML Report <-> `parse_and_record_results.py`
- Input: UTF-16LE `.htm` report file generated by MT5 Strategy Tester
- Output: Structured JSON/Markdown summary and append row to `EXPERIMENTOS.csv`:
  `ID;Data;Estrategia;Timeframe;Periodo;Ativo;Modelo_Ticks;Banca_USD;Lucro_USD;Fator_Lucro;Trades;WinRate_Pct;Max_DD_USD;Semanas_Stop12_Violado;Conclusao`

### Supervisor / Circuit Breakers <-> MQL5 Trade Engine
- `NewEntriesAllowedBySupervisor()` returns `false` if `dailyRealizedNet >= DailyProfitTargetMoney` ($100), `curLoss >= DailyMaxLossMoney` ($140), or `totalLoss >= TotalMaxLossMoney` ($200).
- `OnTick()` triggers `CloseAllPositionsInstantly()` immediately if floating daily loss reaches $140 or total loss reaches $200.

## Code Layout
- `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5`: Master EA source code (UTF-8, 5,320 lines)
- `MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set`: Parameter preset for MT5 Strategy Tester
- `tools\Run-Backtest.ps1`: Headless test execution script
- `tools\compile_v12_1.py`: Automated compilation script invoking `metaeditor64.exe`
- `tools\parse_and_record_results.py`: Unified report parser and CSV recorder
- `results\`: Test output reports and screenshot directories
- `EXPERIMENTOS.csv`: Historical and newly benchmarked experiment metrics
