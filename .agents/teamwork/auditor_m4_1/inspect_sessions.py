import os
from pathlib import Path

log_path = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "5FFA568149E88FCD5B44D926DCFEAA79" / "Tester" / "logs" / "20261109.log"

with open(log_path, "r", encoding="utf-16", errors="ignore") as f:
    lines = f.readlines()

print(f"Total lines in tester log: {len(lines)}")

# Group by testing start / finish
sessions = []
current_session = []
for idx, line in enumerate(lines):
    if "testing of Experts" in line and "started" in line:
        if current_session:
            sessions.append(current_session)
        current_session = [(idx, line)]
    elif current_session:
        current_session.append((idx, line))

if current_session:
    sessions.append(current_session)

print(f"Total test sessions found: {len(sessions)}")
for s_idx, s in enumerate(sessions):
    first_idx, start_line = s[0]
    last_idx, end_line = s[-1]
    # find final balance in session
    fin = [l for i, l in s if "final balance" in l]
    fin_str = fin[-1].strip() if fin else "No final balance"
    ticks = [l for i, l in s if "ticks," in l]
    ticks_str = ticks[-1].strip() if ticks else "No ticks line"
    print(f"\n--- Session {s_idx+1} (lines {first_idx} to {last_idx}) ---")
    print(f"Start: {start_line.strip()[:110]}")
    print(f"End balance: {fin_str}")
    print(f"Ticks: {ticks_str}")
