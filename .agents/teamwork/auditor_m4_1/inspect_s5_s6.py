import os
from pathlib import Path

log_path = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "5FFA568149E88FCD5B44D926DCFEAA79" / "Tester" / "logs" / "20261109.log"

with open(log_path, "r", encoding="utf-16", errors="ignore") as f:
    lines = f.readlines()

print("=== SESSION 5 DETAILS ===")
for l in lines[3195:3225]:
    print(l.strip())

print("\n=== SESSION 5 TRADES COUNT ===")
s5_deals = [l for l in lines[3200:3938] if "deal performed" in l]
s5_orders = [l for l in lines[3200:3938] if "order performed" in l]
print(f"Session 5 deals performed: {len(s5_deals)}, orders performed: {len(s5_orders)}")

print("\n=== SESSION 6 DETAILS ===")
for l in lines[3935:3965]:
    print(l.strip())

s6_deals = [l for l in lines[3938:4645] if "deal performed" in l]
s6_orders = [l for l in lines[3938:4645] if "order performed" in l]
print(f"Session 6 deals performed: {len(s6_deals)}, orders performed: {len(s6_orders)}")
