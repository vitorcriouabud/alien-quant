## 2026-11-09T07:49:12Z
You are a Reviewer subagent in the ALIEN_LAB project.
Your identity: teamwork_reviewer
Your role: Code & Parameters Reviewer
Your working directory: C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\reviewer_m4_1\

MANDATORY FIRST STEP:
Read C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\ORIGINAL_REQUEST.md completely.
Also read C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\orchestrator\PROJECT.md and C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\worker_m2\handoff.md.

Your Objective (Milestone M4 Review - Code & Parameter Integrity):
1. Review MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5 and MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set:
   - Verify AC-01: MetaEditor 64 compilation (0 errors, 0 warnings). Run `python tools\compile_v12_1.py` or inspect compile log.
   - Verify AC-02: `EnforceStrictHTF = false` is configured by default in source code and .set presets.
   - Verify AC-03: Native economic calendar filter calling CalendarValueHistory() without external dependencies.
   - Verify AC-04: Portuguese HUD labels for institutional concepts.
   - Verify AC-09: Daily loss circuit breaker at $140 in code (emergency close and persistent lock).
   - Verify AC-10: Total max account loss circuit breaker at $200 in code (hard stop from $10,000 starting equity).
   - Verify AC-11: Daily profit target lock at $100 in code (compulsory market liquidation on target and daily freeze).
   - Verify AC-12: Fast breakeven at 1.2R bypassing the 10-second hold delay.
   - Verify AC-13: Friday weekend force close at 16:45 UTC.
   - Verify dynamic margin scaling for restricted leverage in ValidVolume().
2. Conclude with an explicit verdict: **APPROVE** or **REQUEST_CHANGES**.

Deliverable:
Write a comprehensive review report to:
`C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\.agents\teamwork\reviewer_m4_1\handoff.md`
and notify the orchestrator via send_message.

## 2026-11-09T08:00:40Z
**Context**: Milestone M4 Review (Code & Parameters Reviewer)
**Content**: Checking on the status of your code and parameter review for ALIEN_V12_1_INSTITUTIONAL.mq5 and .set presets. The other 4 verification agents have completed their audits and reported APPROVE / CLEAN. How is your review progressing?
**Action**: Please report status and deliver handoff.md with your explicit verdict.
