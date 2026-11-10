import os
import re
from pathlib import Path

# Paths
htm_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_015_V12_1_BENCHMARK\EXP_015_V12_1_BENCHMARK.htm"
log_path = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "5FFA568149E88FCD5B44D926DCFEAA79" / "Tester" / "logs" / "20261109.log"

print(f"HTM exists: {os.path.exists(htm_path)}, size: {os.path.getsize(htm_path)} bytes")
print(f"LOG exists: {log_path.exists()}, size: {log_path.stat().st_size if log_path.exists() else 0} bytes")

# Read HTM
with open(htm_path, "r", encoding="utf-16", errors="ignore") as f:
    htm_content = f.read()

# Check key metrics in HTM
print("=== HTM SEARCH ===")
for pattern in [
    r"Total Net Profit.*",
    r"Lucro L[^q<]*quido Total.*",
    r"Profit Factor.*",
    r"Fator de Lucro.*",
    r"Total Trades.*",
    r"Total de Neg[^o<]*cios.*",
    r"Ticks.*",
    r"Ticks modelados.*",
    r"initial deposit.*",
    r"deposito inicial.*"
]:
    m = re.findall(pattern, htm_content, re.IGNORECASE)
    if m:
        # strip tags
        clean = re.sub(r"<[^>]+>", " ", m[0])
        print(f"Found: {clean.strip()[:100]}")

# Count deals / trades in HTM
deals = re.findall(r"<tr[^>]*>\s*<td[^>]*>\d{4}\.\d\d\.\d\d \d\d:\d\d:\d\d</td>", htm_content)
print(f"Total deal rows matched in HTM: {len(deals)}")

# Read LOG
if log_path.exists():
    with open(log_path, "r", encoding="utf-16", errors="ignore") as f:
        log_content = f.read()
    
    print("\n=== TESTER LOG SEARCH ===")
    print(f"Total log length: {len(log_content)} chars")
    
    # Search for EXP_015 or ALIEN_V12_1 in log
    exp_lines = [l for l in log_content.splitlines() if "ALIEN_V12_1" in l or "EXP_015" in l or "final balance" in l or "ticks" in l]
    print(f"Matching log lines: {len(exp_lines)}")
    for l in exp_lines[-20:]:
        print(f"LOG: {l.strip()}")
else:
    print("Tester log not found at path")
