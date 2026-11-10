import re
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\ALIEN_V11_OUTUBRO_2026\ALIEN_V11_OUTUBRO_2026.htm"

with open(path, "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

pos = text.find("Transa")
deals_part = text[pos:]

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', deals_part, re.DOTALL | re.IGNORECASE)

hourly_net = defaultdict(float)
hourly_trades = defaultdict(int)
hourly_wins = defaultdict(int)
daily_net = defaultdict(float)
daily_trades = defaultdict(int)
daily_wins = defaultdict(int)

closed_trades = 0

for r in rows:
    cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
    cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
    if len(cols) == 13:
        time_str = cols[0]
        direction = cols[4].lower()
        if direction in ["out", "in/out"]:
            m = re.match(r'(\d{4}\.\d{2}\.\d{2})\s+(\d{2}):\d{2}:\d{2}', time_str)
            if m:
                day = m.group(1)
                hour = int(m.group(2))
                comm = float(cols[8].replace(' ', '').replace(',', '.'))
                swap = float(cols[9].replace(' ', '').replace(',', '.'))
                profit = float(cols[10].replace(' ', '').replace(',', '.'))
                
                hourly_net[hour] += profit + comm
                hourly_trades[hour] += 1
                if profit > 0:
                    hourly_wins[hour] += 1
                    
                daily_net[day] += profit + comm
                daily_trades[day] += 1
                if profit > 0:
                    daily_wins[day] += 1
                closed_trades += 1

print(f"Total Closed Trades: {closed_trades}")
print("\n=== PERFORMANCE ALIEN V11 POR DIA ===")
for d in sorted(daily_net.keys()):
    t = daily_trades[d]
    w = daily_wins[d]
    wr = (w / t * 100) if t > 0 else 0
    print(f"{d} : {t:2d} trades | WinRate: {wr:4.1f}% | Net: ${daily_net[d]:6.2f}")

print("\n=== PERFORMANCE ALIEN V11 POR HORA (UTC MT5) ===")
print("Hora | Trades | Win% | Net PnL")
for h in sorted(hourly_net.keys()):
    t = hourly_trades[h]
    w = hourly_wins[h]
    wr = (w / t * 100) if t > 0 else 0
    print(f" {h:02d}  |  {t:2d}   | {wr:4.1f}% | ${hourly_net[h]:6.2f}")
