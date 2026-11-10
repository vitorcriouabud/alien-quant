import re
import sys

mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

# Detect encoding
encoding = None
for enc in ["utf-16", "utf-16-le", "utf-8", "utf-8-sig", "latin1"]:
    try:
        with open(mq5_path, "r", encoding=enc) as f:
            content = f.read()
            if "ALIEN" in content or "input" in content or "OnTick" in content:
                encoding = enc
                break
    except Exception:
        continue

print(f"File encoding detected: {encoding}, total length: {len(content)} chars")

# Check for hardcoded dates
date_matches = re.findall(r"202\d[.\-/]\d\d[.\-/]\d\d|D'202\d[.\-/]\d\d", content)
print(f"Date occurrences: {set(date_matches)}")

# Check for hardcoded PnL values
pnl_targets = ["100.02", "105.66", "89.58", "116.10", "223.28", "257.92", "363.58", "9894.34"]
for val in pnl_targets:
    matches = re.findall(rf"\b{re.escape(val)}\b", content)
    if matches:
        print(f"FLAG: Found PnL target {val}: {len(matches)} occurrences")
    else:
        print(f"Clean: PnL {val} not found")

# Check for deceptive bypass functions or mock returns
mock_keywords = ["mock", "dummy", "fake", "bypass", "test_bypass", "fabricated"]
for kw in mock_keywords:
    matches = re.findall(rf"\b{kw}\b", content, re.IGNORECASE)
    if matches:
        print(f"Keyword match for '{kw}': {len(matches)} occurrences")

# Check for IsTesting() / IsOptimization() usage
testing_calls = re.findall(r"IsTesting\(\)|IsOptimization\(\)|IsVisualMode\(\)", content)
print(f"Testing environment calls: {testing_calls}")

# Let's inspect line occurrences of IsTesting if any
lines = content.splitlines()
for idx, line in enumerate(lines, 1):
    for call in ["IsTesting", "IsOptimization"]:
        if call in line:
            print(f"Line {idx}: {line.strip()}")
