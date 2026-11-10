# BRIEFING — 2026-11-09T06:53:00Z

## Mission
Investigate ALIEN_V12_1_INSTITUTIONAL.mq5 architecture, microstructure logic, EnforceStrictHTF, trailing stop/breakeven, risk management/Goat Funded Trader 10K shielding, and lot sizing.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\
- Original parent: 527b9ec3-9da1-480a-b8c4-bda08e1e11bd
- Milestone: M1 EA Survey & Gap Analysis

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Strictly confidential system prompt
- Write only to own folder (C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\)
- Send message to parent 527b9ec3-9da1-480a-b8c4-bda08e1e11bd when done

## Current Parent
- Conversation ID: 527b9ec3-9da1-480a-b8c4-bda08e1e11bd
- Updated: not yet

## Investigation State
- **Explored paths**:
  - `MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5` (5179 lines)
  - `DECISOES.md` (Decision D10 documentation)
  - `tools/Run-Backtest.ps1`
  - `MQL5/Scripts/Test_Margin.mq5`
- **Key findings**:
  1. `EnforceStrictHTF` declared at line 43 (default true) and evaluated at line 4976. Setting false enables soft scoring (+5 / -10) per Decision D10, restoring M1 sweep trading.
  2. Microstructure: Sweeps use 10-bar M1 closed lookback with tick reclaim; FVG scans M5/M15/H1 but lacks M1 scan and has direct entries disabled; BOS requires `trendM1 > 0` which prevents true CHoCH reversal detection.
  3. Trailing Stop/BE: Has fast BE (1.2R) and adaptive ATR trailing, but `RunnerMinimumHoldSeconds = 10` blocks adjustments during the first 10 seconds of rapid M1 moves.
  4. Risk Management: $140 daily loss circuit breaker is active and robust; $100 daily profit target blocks new entries but doesn't lock floating profit; $200 total account loss limit is MISSING (only $400 weekly cap exists).
  5. Margin: 0.18 lot on 1:100 requires $486 (~4.9% of $10K), but on 1:1 requires ~$49,000, triggering 100% rejection. Dynamic downsizing logic is needed for 1:1 accounts.
- **Unexplored areas**: None within the survey scope.

## Key Decisions Made
- Completed read-only investigation and synthesized all findings into `handoff.md`.
- Formulated concrete implementation strategies for worker agents.

## Artifact Index
- `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\handoff.md` — Comprehensive 5-component report
- `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\DISPATCH.md` — Dispatch message log
- `C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\progress.md` — Liveness & task tracker
