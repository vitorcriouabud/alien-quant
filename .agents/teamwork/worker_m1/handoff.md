# HANDOFF REPORT: MILESTONE M1 — TEST INFRA & METRICS AUTOMATION

**Author**: `teamwork_worker` (Test Automation Worker)  
**Date**: 2026-11-09T07:14:00Z  
**Target Path**: `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\worker_m1\handoff.md`  

---

## 1. Observation

1. **Benchmark Report Inspection**:
   - Inspected `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_014_GOAT_10K\EXP_014_GOAT_10K.htm` (UTF-16LE with BOM `\xff\xfe<\x00`).
   - Verbatim HTML rows observed:
     - Row 231: `Lucro Líquido Total: 748.30`
     - Row 232: `Rebaixamento Máximo do Capital Líquido: 90.12 (0.83%)`
     - Row 235: `Fator de Lucro: 2.47`
     - Row 240: `Total de Negociações: 140`
     - Row 241: `Negociações com Lucro (% of total): 83 (59.29%)`, `Negociações com Perda (% of total): 57 (40.71%)`
     - Row 243: `Média lucro da negociação: 15.16`, `Média perda na Negociação: -7.10`
   - All 11 other `.htm` reports in `results\` also use UTF-16LE and identical table structure.

2. **Parser Implementation & Execution**:
   - Implemented `tools\parse_and_record_results.py` (360 lines) with:
     - Multi-encoding decoding (`utf-16`, `utf-16-le`, `utf-8-sig`, `utf-8`, `cp1252`).
     - Diacritic normalization (`unicodedata.normalize('NFD')`) for accent-independent token matching.
     - Bilingual dictionary matching for all MT5 Portuguese and English labels.
     - Number cleaner handling thousands spaces (`1 257.98`), commas (`1.257,98` or `748,30`), percentages, and dollar signs.
     - Metrics calculation: Net Profit, Profit Factor, Total Trades, Win Rate %, Max Equity Drawdown ($ and %), Average Win, Average Loss, Average Risk:Reward (`abs(AvgWin / AvgLoss)`).
     - Formatted Markdown summary table output.
     - Idempotent CSV recording to `EXPERIMENTOS.csv`.
   - Executing on EXP-014 benchmark:
     ```
     python tools\parse_and_record_results.py --report results\EXP_014_GOAT_10K\EXP_014_GOAT_10K.htm --exp-id EXP-014 --strategy "ALIEN V11.2 GOAT 10K" --csv EXPERIMENTOS.csv
     ```
     Produced output:
     - Total Net Profit: `+$748.30 USD`
     - Profit Factor: `2.47`
     - Total Trades: `140`
     - Win Rate: `59.29%` (83 vitórias / 57 derrotas)
     - Maximal Equity Drawdown: `$90.12 (0.83%)`
     - Average Win: `$15.16`
     - Average Loss: `$-7.10`
     - Average Risk:Reward (R:R): `2.14`
     - Daily Stop Limit ($140): `Nao (DD $90.12 < $140)`

3. **CSV Archival Verification**:
   - `EXPERIMENTOS.csv` was updated with the exact line:
     `EXP-014;2026-11-09;ALIEN V11.2 GOAT 10K;M1;2026.10.05 - 2026.10.17;XAUUSD;Real Ticks (4);10000;748.30;2.47;140;59.3%;90.12;Nao (DD $90.12 < $140);Lucro +$748.30, PF 2.47, WR 59.3%, Max DD $90.12, R:R 2.14 (140 trades).`

4. **`tools\Run-Backtest.ps1` Modernization**:
   - Updated default parameters in `tools\Run-Backtest.ps1` lines 6-10:
     - `FromDate = "2026.10.21"`
     - `ToDate = "2026.11.07"`
     - `Model = 4` (Real ticks)
     - `Deposit = 10000`
     - `Leverage = 100`
   - Added automatic repository `.set` preset synchronization (`MQL5\Profiles\Tester\$expertName.set` copied to terminal tester profile before execution).
   - Replaced previous basic regex lines with automated call to `parse_and_record_results.py`, which outputs the Markdown table and archives results into `EXPERIMENTOS.csv`.
   - Verified PowerShell syntax: `Get-Command tools\Run-Backtest.ps1 -Syntax` passed cleanly with exit code 0.

5. **Test Suite Verification**:
   - Created `tools\test_parser.py` containing 8 automated unit/regression tests.
   - Command: `python tools\test_parser.py`
   - Verbatim result:
     ```
     ........
     ----------------------------------------------------------------------
     Ran 8 tests in 0.148s

     OK
     ```

---

## 2. Logic Chain

1. MT5 exports Strategy Tester reports as HTML files encoded in UTF-16LE with standard tabular layouts where label cells end in `:` and adjacent value cells contain bolded text `<b>...</b>`.
2. By stripping accents and lowercasing keys, the parser becomes immune to locale encoding discrepancies (`Líquido` vs `Liquido` vs `Lquido`), allowing seamless matching for both Portuguese (`Lucro Líquido Total`, `Fator de Lucro`, `Rebaixamento Máximo do Capital Líquido`, `Total de Negociações`, `Negociações com Lucro`, `Média lucro da negociação`, `Média perda na Negociação`) and English (`Total Net Profit`, `Profit Factor`, `Equity Drawdown Maximal`, `Total Trades`, `Profit Trades`, `Average profit trade`, `Average loss trade`).
3. Running the parser against `EXP_014_GOAT_10K.htm` directly verified the exact required benchmark numbers (+748.30 USD Net Profit, 2.47 Profit Factor, 140 trades, 59.29% Win Rate, $90.12 / 0.83% Maximal Equity Drawdown, $15.16 Avg Win, -$7.10 Avg Loss, and 2.14 R:R).
4. Semicolon-delimited CSV updates check for the experiment ID before writing; if the ID already exists, the row is replaced in place, preventing dirty duplicates upon rerun.
5. Updating `tools\Run-Backtest.ps1` with default parameters `FromDate=2026.10.21`, `ToDate=2026.11.07`, `Model=4`, `Deposit=10000`, `Leverage=100` and invoking `parse_and_record_results.py` fulfills Milestone M1 requirements and prepares downstream milestone M3 for zero-friction mass backtesting.
6. The test suite in `tools\test_parser.py` independently validates number parsing, locale handling, edge cases (zero trades, zero losses), and CSV idempotency, confirming zero regressions.

---

## 3. Caveats

- In PowerShell interactive terminals, unescaped `$` signs in arguments like `--conclusion "Lucro +$748"` are treated by PowerShell as variable expansions (`$748` -> empty). When running from PowerShell scripts, either escape as `` `+$748 `` or omit `--conclusion` so `parse_and_record_results.py` generates the string internally without shell interpolation.
- The Strategy Tester report's `Period` field displays the trade window date range (e.g., `M1 (2026.10.05 - 2026.10.17)`). If a test has 0 trades, MT5 may omit dates from the period label, in which case the parser falls back to the CLI `--period` parameter or default `2026.10.21 - 2026.11.07`.

---

## 4. Conclusion

Milestone M1 (Test Infra & Metrics Automation) is **100% complete**:
- `tools\parse_and_record_results.py` is implemented, tested, and verified.
- Benchmark report `EXP_014_GOAT_10K.htm` was parsed and confirmed with 100% mathematical fidelity.
- `tools\Run-Backtest.ps1` defaults are updated to `Leverage=100`, `Deposit=10000`, `Model=4`, `FromDate=2026.10.21`, `ToDate=2026.11.07`, and it now automatically calls `parse_and_record_results.py` upon completion.
- All 8 unit tests in `tools\test_parser.py` pass.
- No files in `MQL5\` were modified, complying strictly with exclusive write boundaries.

---

## 5. Verification Method

To independently verify this milestone:

1. **Run Parser Unit Test Suite**:
   ```powershell
   python C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\test_parser.py
   ```
   *Expected result*: `Ran 8 tests in ... OK`.

2. **Run Parser on Benchmark Report**:
   ```powershell
   python C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\parse_and_record_results.py --report results\EXP_014_GOAT_10K\EXP_014_GOAT_10K.htm --exp-id EXP-014
   ```
   *Expected output*: Formatted Markdown table containing `+$748.30 USD` profit, `2.47` PF, `140` trades, `59.29%` win rate, `$90.12 (0.83%)` max equity DD, and `2.14` average R:R.

3. **Verify `tools\Run-Backtest.ps1` Parameters**:
   ```powershell
   powershell -ExecutionPolicy Bypass -Command "Get-Command C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\Run-Backtest.ps1 -Syntax"
   ```
   *Expected output*: Syntax with all parameters accepted.

4. **Inspect `EXPERIMENTOS.csv`**:
   ```powershell
   Get-Content C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\EXPERIMENTOS.csv -Tail 2
   ```
   *Expected output*: Row starting with `EXP-014;...` containing `748.30;2.47;140;59.3%;90.12`.
