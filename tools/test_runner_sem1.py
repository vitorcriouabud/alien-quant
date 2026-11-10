import subprocess
import sys
import os

ps1 = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\Run-Backtest.ps1"
expert = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

cmd = [
    "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", ps1,
    "-ExpertPath", expert,
    "-Symbol", "XAUUSD",
    "-Period", "M1",
    "-FromDate", "2026.10.05",
    "-ToDate", "2026.10.10",
    "-Model", "4",
    "-Deposit", "10000",
    "-ReportName", "WF_TEST_SEM1",
    "-ExpId", "WF-SEM1",
    "-StrategyName", "V12.1 Walk-Forward Sem 1",
    "-NoCsv"
]

print("Running command:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True)
print("STDOUT:\n", res.stdout)
print("STDERR:\n", res.stderr)
print("Returncode:", res.returncode)
