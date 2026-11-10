## 2026-11-09T06:44:35Z
You are an Explorer subagent in the ALIEN_LAB project.
Your identity: teamwork_explorer
Your working directory: C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\

MANDATORY FIRST STEP:
Read C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\ORIGINAL_REQUEST.md completely.

Your Objective:
Conduct a thorough, read-only exploration of the EA source code in C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5 and any associated include files or libraries in MQL5\.

Investigate and document:
1. Micro-structure logic:
   - How are BSL/SSL liquidity sweeps, Fair Value Gaps (FVG), and Market Structure Shift (CHoCH) implemented?
   - What are the current conditions, thresholds, and calculations?
   - Where are the exact opportunities to refine/enhance this for M1 XAUUSD?
2. Parameter `EnforceStrictHTF`:
   - How is it declared, initialized, and where in the code is it evaluated?
   - How does setting `EnforceStrictHTF = false` affect entry logic, signal filtering, and liquidity sweeps (Decision D10)?
3. Trailing Stop and Breakeven:
   - What is the current trailing stop and breakeven logic?
   - What are the step sizes, trigger distances, and update frequencies?
   - How can they be optimized for rapid profit protection on M1?
4. Risk Management and Shielding (Goat Funded Trader 10K):
   - What equity/balance tracking exists?
   - Is there a daily target lock at $100 profit?
   - Is there a daily loss circuit breaker at $140 loss (locking trading for the day or closing positions)?
   - Is there a total account loss limit at $200?
   - How does the code track daily PnL vs total account drawdown?
5. Lot Sizing and Margin:
   - How is lot sizing calculated or defaulted?
   - How can it accommodate 0.18 lot on standard 1:100 leverage while also handling 1:1 leverage constraints if necessary?

Deliverable:
Write a comprehensive, structured report to:
`C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\explorer_survey_ea\handoff.md`
with sections:
- Executive Summary
- Current Architecture & Signal Pipeline
- Microstructure Implementation (Sweeps, FVG, CHoCH)
- Parameter Analysis (`EnforceStrictHTF` and inputs)
- Trailing Stop & Breakeven Analysis
- Risk Management & Prop Shielding Gap Analysis
- Recommended Implementation Strategy for Workers

Notify the orchestrator via send_message when your report is ready.
