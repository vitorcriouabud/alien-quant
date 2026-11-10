import re

mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

with open(mq5_path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")

def search_lines(pattern, context=2):
    results = []
    for idx, line in enumerate(lines, 1):
        if re.search(pattern, line, re.IGNORECASE):
            start = max(1, idx - context)
            end = min(len(lines), idx + context + 1)
            results.append((idx, "".join(f"{i}: {lines[i-1]}" for i in range(start, end))))
    return results

# 1. Check bypass
print("=== 1. BYPASS OCCURRENCE ===")
for idx, snippet in search_lines(r"\bbypass\b", 2):
    print(snippet)

# 2. Check EnforceStrictHTF
print("=== 2. ENFORCESTRICTHTF ===")
for idx, snippet in search_lines(r"EnforceStrictHTF", 1):
    print(snippet)

# 3. Check Risk / Circuit Breakers inputs
print("=== 3. RISK INPUTS ===")
for idx, snippet in search_lines(r"(TotalMaxLossMoney|DailyProfitTargetMoney|DailyMaxLossMoney|WeeklyMaxLossMoney)", 1):
    print(snippet)

# 4. Check SweepReclaimPoints
print("=== 4. SWEEP RECLAIM POINTS ===")
for idx, snippet in search_lines(r"SweepReclaimPoints", 1):
    print(snippet)

# 5. Check FastBERatio & RunnerMinimumHoldSeconds
print("=== 5. FAST BE & HOLD SECONDS ===")
for idx, snippet in search_lines(r"(FastBERatio|RunnerMinimumHoldSeconds)", 1):
    print(snippet)
