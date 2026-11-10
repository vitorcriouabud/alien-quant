import re
from datetime import datetime
from collections import defaultdict

def analyze_report(path):
    html = open(path, "r", encoding="utf-16le", errors="ignore").read()
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL | re.IGNORECASE)
    deals = []
    for r in rows:
        cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.DOTALL | re.IGNORECASE)]
        if len(cells) >= 13 and re.match(r'^\d{4}\.\d{2}\.\d{2}', cells[0]):
            deals.append(cells)
            
    trades = []
    current_in = None
    for d in deals:
        deal_type = d[3].lower()
        direction = d[4].lower()
        deal_time = d[0]
        price = float(d[6].replace(" ", "").replace(",", ".")) if d[6] else 0.0
        profit = float(d[10].replace(" ", "").replace(",", ".")) if d[10] else 0.0
        comm = float(d[8].replace(" ", "").replace(",", ".")) if d[8] else 0.0
        comment = d[12] if len(d) > 12 else ""
        
        if direction == "in":
            current_in = (deal_time, deal_type, price, comment)
        elif direction == "out" and current_in:
            in_time, in_type, in_price, in_comm = current_in
            trades.append({
                "in_time": in_time,
                "type": in_type,
                "profit": profit,
                "net": profit + (comm * 2),
            })
            current_in = None
    return trades

t21 = analyze_report(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_021_V12_1_VALIDATED\EXP_021_V12_1_VALIDATED.htm")
print(f"EXP-021 total trades: {len(t21)}")

def sim(trades, max_loss, max_trades):
    day_trades = defaultdict(list)
    for t in trades:
        day = t["in_time"].split()[0]
        day_trades[day].append(t)
    sim_t = []
    for day in sorted(day_trades.keys()):
        pnl = 0.0
        count = 0
        for t in day_trades[day]:
            if max_loss > 0 and pnl <= -max_loss:
                break
            if max_trades > 0 and count >= max_trades:
                break
            count += 1
            sim_t.append(t)
            pnl += t["net"]
            
    wins = [t for t in sim_t if t["profit"] > 0]
    losses = [t for t in sim_t if t["profit"] <= 0]
    gp = sum(t["profit"] for t in wins)
    gl = sum(abs(t["profit"]) for t in losses)
    net = gp - gl
    pf = gp / gl if gl > 0 else 99.9
    wr = len(wins) / len(sim_t) * 100 if sim_t else 0
    return len(sim_t), len(wins), len(losses), wr, gp, gl, net, pf

for dloss in [50.0, 40.0, 35.0, 30.0, 25.0, 20.0]:
    for mtrades in [6, 8, 10, 12]:
        c, w, l, wr, gp, gl, net, pf = sim(t21, dloss, mtrades)
        print(f"Loss ${dloss:<4.0f} | Trades {mtrades:<2} -> Count {c:<2} | WinRate {wr:5.1f}% | GrossProfit ${gp:6.2f} | GrossLoss ${gl:6.2f} | Net ${net:7.2f} | PF {pf:4.2f}")
