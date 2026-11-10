import re
from datetime import datetime
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"
html = open(path, "r", encoding="utf-16le", errors="ignore").read()

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL | re.IGNORECASE)

deals = []
for r in rows:
    cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.DOTALL | re.IGNORECASE)]
    if len(cells) >= 13 and re.match(r'^\d{4}\.\d{2}\.\d{2}', cells[0]):
        deals.append(cells)

day_stats = defaultdict(lambda: {"trades": 0, "wins": 0, "losses": 0, "gross_profit": 0.0, "gross_loss": 0.0, "commission": 0.0, "net": 0.0, "reasons": defaultdict(int)})

for d in deals:
    direction = d[4].lower()
    if direction == "out":
        dt_str = d[0]
        day = dt_str.split()[0]
        vol = float(d[5].replace(" ", "").replace(",", "."))
        comm = float(d[8].replace(" ", "").replace(",", "."))
        profit = float(d[10].replace(" ", "").replace(",", "."))
        comment = d[12].strip() if len(d) > 12 else ""
        
        stat = day_stats[day]
        stat["trades"] += 1
        stat["commission"] += comm
        net_trade = profit + comm # MT5 report profit sometimes does or doesn't include commission in that cell
        if profit > 0:
            stat["wins"] += 1
            stat["gross_profit"] += profit
        else:
            stat["losses"] += 1
            stat["gross_loss"] += abs(profit)
        stat["net"] += (profit + comm)
        
        reason = "TP" if "tp" in comment.lower() else ("SL" if "sl" in comment.lower() else comment)
        stat["reasons"][reason] += 1

print(f"{'Data':<12} | {'Trades':<6} | {'Wins':<4} | {'Losses':<6} | {'WinRate':<7} | {'Lucro':<8} | {'Perda':<8} | {'Liquido':<9} | {'PF':<6} | Motivos")
print("-" * 90)

total_w = 0
total_l = 0
total_p = 0.0
total_loss = 0.0
total_c = 0.0

for day in sorted(day_stats.keys()):
    s = day_stats[day]
    wr = (s["wins"] / s["trades"] * 100) if s["trades"] > 0 else 0
    pf = (s["gross_profit"] / s["gross_loss"]) if s["gross_loss"] > 0 else 99.9
    reasons_str = ", ".join(f"{k}:{v}" for k, v in s["reasons"].items())
    print(f"{day:<12} | {s['trades']:<6} | {s['wins']:<4} | {s['losses']:<6} | {wr:5.1f}% | {s['gross_profit']:7.2f} | {s['gross_loss']:7.2f} | {s['net']:8.2f} | {pf:5.2f} | {reasons_str}")
    total_w += s["wins"]
    total_l += s["losses"]
    total_p += s["gross_profit"]
    total_loss += s["gross_loss"]
    total_c += s["commission"]

tot_trades = total_w + total_l
tot_wr = (total_w / tot_trades * 100) if tot_trades > 0 else 0
tot_pf = (total_p / total_loss) if total_loss > 0 else 0
tot_net = total_p - total_loss + total_c
print("-" * 90)
print(f"{'TOTAL':<12} | {tot_trades:<6} | {total_w:<4} | {total_l:<6} | {tot_wr:5.1f}% | {total_p:7.2f} | {total_loss:7.2f} | {tot_net:8.2f} | {tot_pf:5.2f}")
