# E2E Test Infra: ALIEN_LAB

## Test Philosophy
- Opaque-box, requirement-driven, empirical validation.
- Real ticks execution (`Model=4`) on XAUUSD M1 using local tick caches (`202610.tkc`, `202611.tkc`).
- Dual validation: Compilation & Syntax Integrity (`metaeditor64.exe`) + Backtest Execution (`terminal64.exe`) + Risk Shield Invariant Checking.

## Acceptance Criteria Mapping
| AC ID | Description | Verification Channel | Pass Criteria |
|---|---|---|---|
| AC-01 | MetaEditor 64 Clean Build | `metaeditor64.exe /compile:... /log:...` | `0 errors, 0 warnings` in log |
| AC-02 | Default `EnforceStrictHTF = false` | Code inspection & `.set` file | `EnforceStrictHTF = false` default |
| AC-03 | Native MT5 Economic Calendar Filter | EA source inspection | Calls `CalendarValueHistory()` |
| AC-04 | HUD Teacher Panel in Portuguese | Visual & code check | Proper Portuguese labels |
| AC-05 | Real Ticks Model Execution | Tester report header | `Model = 4` (Real Ticks) |
| AC-06 | Target Date Range Coverage | Tester config `.ini` & report | Covers 2026.10.21 to 2026.11.06 |
| AC-07 | Clean Execution Logs | MT5 Terminal & Tester logs | 0 trade context, 0 requotes, 0 margin errors |
| AC-08 | Automated Metric Extraction | `tools\parse_and_record_results.py` | Extracts WR, PF, DD, R:R into `EXPERIMENTOS.csv` |
| AC-09 | Daily Circuit Breaker Cutoff | Trade log analysis | Daily loss cuts before $140 |
| AC-10 | Total Max Drawdown Ceiling | Equity curve in report | Cumulative DD strictly < $200 |
| AC-11 | Daily Profit Target Lock | Trade log analysis | Trading halts upon reaching +$100 |
| AC-12 | Fast Breakeven & Trailing Stop | Deal history analysis | Stop moves to BE at 1.2R, trailing active |
| AC-13 | Friday Weekend Protection | Trade execution timestamps | Zero open trades past Friday 16:45 UTC |

## Test Architecture
- Test Runner: `tools\Run-Backtest.ps1`
- Report Parser: `tools\parse_and_record_results.py`
- Test Output Directory: `results\`
- Master Log: `EXPERIMENTOS.csv`
