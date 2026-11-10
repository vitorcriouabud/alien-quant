# SURVEY REPORT: MT5 TESTING INFRASTRUCTURE, SCRIPTS & ENVIRONMENT

**Author**: `teamwork_explorer`  
**Date**: 2026-11-09T06:57:00Z  
**Target File**: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_tools\handoff.md`  

---

## 1. Executive Summary

This report delivers a forensic audit and survey of the MT5 compilation, automation, data caching, margin handling, and metrics parsing infrastructure for the ALIEN_LAB project, specifically supporting the algorithmic validation of `ALIEN_V12_1_INSTITUTIONAL.mq5` on `XAUUSD M1` for the Goat Funded Trader 10K challenge.

### Core Survey Takeaways
1. **Compilation Engine**: `metaeditor64.exe` is located at `C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe`. It executes headlessly via `/compile:"<path.mq5>" /log:"<path.log>"`. `ALIEN_V12_1_INSTITUTIONAL.mq5` compiles with **0 errors, 0 warnings** (elapsed time ~75s, EX5 size: 289,272 bytes). MetaEditor generates UTF-16LE logs.
2. **Backtest Automation Engine**: `tools\Run-Backtest.ps1` orchestrates compilation, `.set` parameter deployment, `.ini` generation, headless MT5 execution via `terminal64.exe /config:"<config.ini>"`, and post-run report retrieval.
3. **Tick History & Data Cache**: Verified local presence of real tick caches in `bases\RoboForex-ECN\ticks\XAUUSD`:
   - `202610.tkc` (14,887,043 bytes — October 2026 ticks)
   - `202611.tkc` (16,345,451 bytes — November 2026 ticks through 2026.11.06)
   - `history\XAUUSD\cache\M1.hc` (6,131,798 bytes).
   The requested period (`2026.10.21` to `2026.11.06`) is **100% available and cached locally** for `Model=4` ("Every tick based on real ticks").
4. **Margin & Leverage Resolution**: RoboForex Demo account `67316641` has 1:1 leverage on the broker side (demanding $74,160 margin for 0.18 lot). In the Strategy Tester, configuring `Leverage=1:100` and `Deposit=10000` in the tester `.ini` explicitly overrides the live broker leverage in simulation mode, dropping required margin for 0.18 lot to **$741.60** (Margin Level 1,348%), allowing trades to execute seamlessly with zero margin rejections.
5. **Critical Configuration Alert**: `MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set` currently contains `EnforceStrictHTF=true`. In accordance with Decision D10 and the project specification, this MUST be set to `EnforceStrictHTF=false` before executing the benchmark backtests.
6. **Metrics Parsing & Tabulation**: Existing scripts (`parse_exp014.py`, `multiweek_validator.py`, `analyze_trades.py`) parse individual subsets of metrics from the UTF-16 `.htm` reports. A unified parser script is needed to extract Win Rate, Profit Factor, Net Profit, Absolute & % Drawdown, Average R:R, and append formatted records directly to `EXPERIMENTOS.csv`.

---

## 2. Compilation Pipeline Assessment

### 2.1 Compiler Path and Syntax
- **Executable**: `C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe` (File size: 113,825,960 bytes, Build date: 2026-11-01).
- **Command-line invocation syntax**:
  ```powershell
  & "C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe" /compile:"<absolute_path_to_source.mq5>" /log:"<absolute_path_to_log.log>"
  ```
- **Argument specifications**:
  - `/compile:"<path>"`: Specifies the full path to the `.mq5` file to compile.
  - `/log:"<path>"`: Specifies the destination for compilation logs. When omitted, MetaEditor writes to `%APPDATA%\MetaQuotes\Terminal\<TerminalID>\MQL5\Logs`.
  - Destination binary: MetaEditor outputs the compiled `.ex5` file directly into the same directory as the source `.mq5`.
- **Include file resolution**:
  - Even when the source `.mq5` is located in `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\`, MetaEditor automatically resolves standard library includes (e.g. `<Trade/Trade.mqh>`) to `%APPDATA%\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Include\`.
  - Alternatively, copying the `.mq5` into `MQL5\Experts` inside the terminal data root (as implemented in `tools\compile_v12_1.py`) guarantees 100% path resolution.

### 2.2 Compilation Log Encoding and Parsing
- **Encoding**: MetaEditor logs are strictly **UTF-16LE** (with or without BOM). Scripts reading the log with default ASCII/UTF-8 fail or encounter empty strings.
- **Success Criteria**:
  - English: `Result: 0 errors, 0 warnings`
  - Portuguese: `Resultado: 0 erros, 0 avisos`
  - Regex pattern: `(?:Result|Resultado)\s*:\s*0\s+(?:errors?|erros?)`
- **Verified Benchmark**:
  - Source: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5` (5,179 lines).
  - Log: `$env:TEMP\compile_v12_1.log`
  - Result: `Result: 0 errors, 0 warnings, 75336 ms elapsed, cpu='X64 Regular'`
  - Binary produced: `ALIEN_V12_1_INSTITUTIONAL.ex5` (289,272 bytes).

---

## 3. Backtest Automation Infrastructure

### 3.1 `Run-Backtest.ps1` Architecture
`tools\Run-Backtest.ps1` is a complete PowerShell script that automates end-to-end execution:
1. **Target Terminal**:
   - Install directory: `C:\Program Files\RoboForex MT5 Terminal`
   - Terminal binary: `C:\Program Files\RoboForex MT5 Terminal\terminal64.exe` (129,243,464 bytes)
   - Roaming Data root: `C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`
   - Data Root link: `origin.txt` exists in the data root pointing to `C:\Program Files\RoboForex MT5 Terminal` (complying with Decision D02).
2. **Execution invocation**:
   ```powershell
   $arg = '/config:"' + $iniPath + '"'
   $proc = Start-Process -FilePath $terminal -WorkingDirectory $install -ArgumentList $arg -PassThru
   ```
3. **Tester Isolation**:
   - Compiles or copies the target expert to `MQL5\Experts\ALIEN_LAB_EXCLUSIVO_TESTADOR\<ExpertName>.ex5`.
   - Generates configuration `.ini` in `$env:TEMP\CONFIG_<ExpertName>.ini`.
   - Creates or loads `.set` file from `MQL5\Profiles\Tester\<ExpertName>.set`.
4. **Execution Monitoring**:
   - Loops with `while (-not $proc.HasExited) { Start-Sleep -Seconds 3 }`.
   - With `ShutdownTerminal=1` in the `.ini`, MT5 automatically exits immediately upon test completion.
5. **Report Archival**:
   - MT5 outputs `<ReportName>.htm` and associated screenshots (`<ReportName>.png`, `<ReportName>-holding.png`, `<ReportName>-hst.png`, `<ReportName>-mfemae.png`) directly into the data root `5FFA568149E88FCD5B44D926DCFEAA79\`.
   - `Run-Backtest.ps1` moves all report assets to `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\<ReportName>\`.

### 3.2 Strategy Tester `.ini` Configuration Reference
The configuration file consumed by `terminal64.exe /config:...` uses the following structure:

```ini
[Common]
NewsEnable=0

[Experts]
AllowLiveTrading=0
AllowDllImport=0
Enabled=1

[Tester]
Expert=ALIEN_LAB_EXCLUSIVO_TESTADOR\ALIEN_V12_1_INSTITUTIONAL
ExpertParameters=ALIEN_V12_1_INSTITUTIONAL.set
Symbol=XAUUSD
Period=M1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2026.10.21
ToDate=2026.11.07
ForwardMode=0
Report=ALIEN_V12_1_BENCHMARK
ReplaceReport=1
ShutdownTerminal=1
Deposit=10000
Currency=USD
Leverage=1:100
UseLocal=1
UseRemote=0
UseCloud=0
Visual=0
```

#### Key Parameter Semantics:
- `Model=4`: **Every tick based on real ticks** (Modelo "Cada tick baseado em ticks reais"). (Note: `Model=1` is OHLC M1, `Model=0` is synthetic ticks).
- `FromDate=2026.10.21` and `ToDate=2026.11.07`: Covers 2026.10.21 through Friday 2026.11.06 market close (setting `ToDate=2026.11.07` ensures Friday full session inclusion).
- `ExecutionMode=0`: Normal execution (zero random delay). Set to `-1` for latency simulation.
- `ShutdownTerminal=1`: Ensures terminal process terminates when backtest finishes, allowing automated process control.

---

## 4. Terminal, Data Cache & Margin/Leverage Configuration

### 4.1 Historical Data & Tick Cache Audit
Inspected directory: `C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\`

| Category | File Path | Size (Bytes) | Verification & Date Range |
|---|---|---|---|
| **Real Ticks (Oct)** | `bases\RoboForex-ECN\ticks\XAUUSD\202610.tkc` | 14,887,043 | Verified: 100% Real ticks for October 2026 |
| **Real Ticks (Nov)** | `bases\RoboForex-ECN\ticks\XAUUSD\202611.tkc` | 16,345,451 | Verified: Real ticks up to 2026.11.06 / 2026.11.09 |
| **Ticks Meta** | `bases\RoboForex-ECN\ticks\XAUUSD\ticks.dat` | 123,312 | Verified: Tick metadata index |
| **M1 Bar History** | `bases\RoboForex-ECN\history\XAUUSD\2026.hcc` | 23,751,459 | Verified: 2026 M1 history synchronized |
| **M1 Bar Cache** | `bases\RoboForex-ECN\history\XAUUSD\cache\M1.hc` | 6,131,798 | Verified: Pre-computed M1 bar structure |
| **Higher TFs** | `history\XAUUSD\cache\M5.hc`, `H1.hc`, `Daily.hc` | ~6 MB each | Verified: Available for multi-timeframe analysis |
| **Tester Cache** | `Tester\cache\*.tst` | 70 KB to 1 MB | Verified: 10 cached test runs on XAUUSD M1 Model 4 |

**Finding**: The terminal has complete, local, pre-downloaded tick and bar data for XAUUSD M1 spanning all of October and November 2026. No network downloads or tick generation delays are required.

### 4.2 Margin and Leverage Constraint Analysis
- **The Problem**: RoboForex Demo account `67316641` is connected to server `RoboForex-ECN` with a broker-configured leverage of **1:1**.
  - Gold contract size: 100 oz per 1.00 lot.
  - At Gold price ~$4,120 / oz:
    - 0.18 lot nominal value = 18 oz × $4,120 = **$74,160 USD**.
  - At 1:1 leverage: Required margin = **$74,160 USD**.
  - If a $10,000 account attempted 0.18 lot at 1:1, `OrderCheck` would calculate `margin_free = -$64,160` and fail with error 10019 (`TRADE_RETCODE_NO_MONEY`), triggering `OrderCheck: margem livre projetada insuficiente`.
- **The Strategy Tester Mechanism**:
  - In MT5, the Strategy Tester agent (`metatester64.exe` / `Core 1`) runs in an isolated virtual execution sandbox.
  - When `Leverage=1:100` and `Deposit=10000` are specified in the `.ini` configuration file:
    ```
    Tester log verification (20261108.log, line 31448):
    "Core 1: initial deposit 10000.00 USD, leverage 1:100"
    ```
  - At 1:100 leverage:
    - Required margin for 0.18 lot = $74,160 / 100 = **$741.60 USD**.
    - Available Free Margin = $10,000 - $741.60 = **$9,258.40 USD**.
    - Projected Margin Level = ($10,000 / $741.60) × 100 = **1,348.4%**.
    - In `ALIEN_V12_1_INSTITUTIONAL.mq5`:
      - `check.margin_free ($9,258.40) >= MinFreeMarginMoney ($3.00)` -> PASS
      - `check.margin_level (1348.4%) >= MinimumMarginLevelPct (150.0%)` -> PASS
    - Orders execute normally with **zero margin rejections**.
- **Execution Log Proof**:
  - Confirmed in `Tester\logs\20261108.log` (Line 601):
    `Core 1: 2026.08.11 02:30:00 CTrade::OrderSend: market buy 0.18 XAUUSD sl: 4394.13 tp: 4397.46 [done at 4395.46]`
- **Practical Recommendations**:
  1. Always include `Leverage=1:100` and `Deposit=10000` in the test `.ini` to mirror the Goat Funded Trader 10K account environment.
  2. If 1:1 leverage ever had to be strictly simulated, either:
     - Reduce lot size: `FixedLot=0.01` (requires ~$4,120 margin on $10,000 deposit; Margin Level = 242.7%), OR
     - Increase deposit: `Deposit=100000` (provides $100K capital for $74K margin).

---

## 5. Metrics Parsing & Tabulation Capabilities

### 5.1 Existing Tooling Inventory

| Script | Location | Capabilities | Limitations |
|---|---|---|---|
| `Run-Backtest.ps1` | `tools\` | Regex parse of Net Profit, PF, Trades, DD | No Win Rate, no R:R, no CSV output |
| `parse_exp014.py` | `tools\` | Regex dump of all summary table rows | Hardcoded to EXP-014 path, prints raw text |
| `parse_v11_report.py` | `tools\` | Filters Portuguese summary keywords | Hardcoded path, no calculations |
| `analyze_trades.py` | `tools\` | Parses `Transações` HTML table for hourly/daily stats | Hardcoded to V10.89 report |
| `multiweek_validator.py` | `tools\` | Extracts Net Profit, PF, Trades, DD, Win Rate | No Average R:R, does not append to CSV |
| `EXPERIMENTOS.csv` | Root | Master record of all 12 prior experiments | Semicolon-delimited, requires manual update |

### 5.2 Metrics Extraction Logic (Specification for Automation)
MT5 HTML reports (`.htm`) use UTF-16LE encoding with a table structure containing bilingual tokens:

```python
# Metric Extraction Dictionary:
1. Net Profit:
   Tokens: "Lucro Líquido Total" or "Total Net Profit"
   Parse: float(val.replace(" ", "").replace(",", "."))

2. Profit Factor:
   Tokens: "Fator de Lucro" or "Profit Factor"
   Parse: float(val.replace(" ", "").replace(",", "."))

3. Total Trades:
   Tokens: "Total de Negociações" or "Total Trades"
   Parse: int(val.split()[0].replace(" ", ""))

4. Win Rate (%):
   Tokens: "Negociações com Lucro (% of total)" or "Profit Trades (% of total)"
   Regex: r'\(([\d\.\,]+)%\)' -> float(m.group(1).replace(",", "."))

5. Maximal Drawdown (Absolute and %):
   Tokens: "Rebaixamento Máximo do Capital Líquido" or "Equity Drawdown Maximal"
   Format: "90.12 (0.83%)"
   Regex: r'([\d\.\,\s]+)\s*\(([\d\.\,]+)%\)'
   Absolute: float(m.group(1).replace(" ", "").replace(",", "."))
   Percent: float(m.group(2).replace(",", "."))

6. Average Win / Average Loss & Average R:R:
   Avg Win Token: "Média lucro da negociação" or "Average profit trade"
   Avg Loss Token: "Média perda na Negociação" or "Average loss trade"
   Avg R:R Formula: abs(AvgWin / AvgLoss)
```

### 5.3 Extension Blueprint for Test Automation
A unified tool `tools\parse_and_record_results.py` should be implemented by the test engineer agent:
- Accepts arguments: `--report <path_or_name>`, `--exp-id EXP-015`, `--strategy "ALIEN V12.1"`.
- Automatically parses all 6 key metrics.
- Computes Average R:R.
- Formats a Markdown summary table for instant reporting.
- Formats and appends a row to `EXPERIMENTOS.csv`:
  `ID;Data;Estrategia;Timeframe;Periodo;Ativo;Modelo_Ticks;Banca_USD;Lucro_USD;Fator_Lucro;Trades;WinRate_Pct;Max_DD_USD;Semanas_Stop12_Violado;Conclusao`

---

## 6. Critical Observations & Verification Chain

### 6.1 Parameter Discrepancy: `EnforceStrictHTF`
- **Observation**:
  - `MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5` line 43:
    `input bool EnforceStrictHTF = true; // VETO: Nao compra se H1 for Baixa, nao vende se H1 for Alta`
  - `MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set` line 20:
    `EnforceStrictHTF=true||false||0||true||N`
- **Evidence**:
  - `ORIGINAL_REQUEST.md` line 16: *"Ajustar EnforceStrictHTF = false para cumprir a Decisão D10 de sweeps de liquidez."*
  - `DECISOES.md` Decision D10: *"Rejeitar o veto macro rígido de M15/H1... o veto estrito piorou o desempenho (PF caiu de 0,69 para 0,48)..."*
- **Impact**: If `Run-Backtest.ps1` runs without overriding this parameter, MT5 will load the `.set` file with `EnforceStrictHTF=true`, violating Decision D10 and impairing liquidity sweep entries.

---

## 7. 5-Component Handoff Report

### 1. Observation
- `metaeditor64.exe` is at `C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe` (113,825,960 bytes).
- Compiling `ALIEN_V12_1_INSTITUTIONAL.mq5` via `tools\compile_v12_1.py` yielded `Result: 0 errors, 0 warnings, 75336 ms elapsed, cpu='X64 Regular'`, producing `ALIEN_V12_1_INSTITUTIONAL.ex5` (289,272 bytes).
- `tools\Run-Backtest.ps1` successfully invokes `terminal64.exe` via `/config:"<iniPath>"`.
- Verified existence of real tick caches in `bases\RoboForex-ECN\ticks\XAUUSD`:
  `202610.tkc` (14.88 MB), `202611.tkc` (16.34 MB), and history `2026.hcc` (23.75 MB).
- `Tester\logs\20261108.log` line 31448 confirms MT5 agent initialized with `initial deposit 10000.00 USD, leverage 1:100` and executed 0.18 lot trades without margin error.
- `ALIEN_V12_1_INSTITUTIONAL.set` currently has `EnforceStrictHTF=true`.

### 2. Logic Chain
1. MetaEditor operates headlessly and produces valid EX5 binaries directly from PowerShell/CLI.
2. The Strategy Tester configuration `.ini` with `Model=4`, `Symbol=XAUUSD`, `Period=M1`, `Deposit=10000`, `Leverage=1:100` correctly engages local tick caches without network overhead.
3. At 1:100 leverage, 0.18 lot requires $741.60 margin on a $10,000 account (1,348% margin level), completely bypassing the demo account's 1:1 broker constraint.
4. Setting `FromDate=2026.10.21` and `ToDate=2026.11.07` tests the full required period through Friday 2026.11.06 close.
5. Updating `EnforceStrictHTF=false` in the `.set` or `.mq5` is mandatory to satisfy Acceptance Criterion AC2 and Decision D10.
6. Extending existing parsing logic into a consolidated extraction script will allow seamless tabulation into `EXPERIMENTOS.csv`.

### 3. Caveats
- MT5 Strategy Tester takes approximately 3 to 6 minutes per week of real-tick simulation on this Core i3 CPU. A full multi-week test (2026.10.21 to 2026.11.06 = ~16 calendar days / ~12 trading days) will take approximately 8 to 12 minutes.
- If `ToDate=2026.11.06` is specified, MT5 stops at `2026.11.06 00:00:00`, excluding Friday's trading session. Using `ToDate=2026.11.07` ensures full Friday session coverage.
- If `Run-Backtest.ps1` runs without deleting or modifying `ALIEN_V12_1_INSTITUTIONAL.set`, MT5 loads the cached `.set` file rather than code defaults.

### 4. Conclusion
The testing infrastructure, compiler, scripts, and environment are fully operational, validated, and ready for automated backtesting of `ALIEN_V12_1_INSTITUTIONAL`. All local real-tick data for October and November 2026 is present. Margin handling is solved via `Leverage=1:100` in the tester `.ini`. The only pre-flight adjustments required before test execution are setting `EnforceStrictHTF = false` and running the unified metrics parser.

### 5. Verification Method
To independently verify the survey findings:
1. **Compilation Check**:
   ```powershell
   & "C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe" /compile:"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5" /log:"$env:TEMP\verify_compile.log"
   Get-Content "$env:TEMP\verify_compile.log" -Raw
   ```
   *Expected output*: `Result: 0 errors, 0 warnings`
2. **Tick Cache Check**:
   ```powershell
   Get-ChildItem "C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\bases\RoboForex-ECN\ticks\XAUUSD\*.tkc"
   ```
   *Expected output*: `202610.tkc` (~14.8 MB) and `202611.tkc` (~16.3 MB) present.
3. **Tester Leverage & Margin Check**:
   Inspect `C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\Tester\logs\20261108.log` lines 31445-31460 to verify `initial deposit 10000.00 USD, leverage 1:100`.
