import re
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_REPRO\EXP_020_REPRO.htm"
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
            "entry_price": in_price,
            "exit_time": deal_time,
            "exit_price": price,
            "profit": profit,
            "commission": comm * 2, # round trip
            "net": profit + (comm * 2),
            "comment": comment
        })
        current_in = None

print(f"Total trades: {len(trades)}")

# Let's test various Daily Loss Limits and Max Consecutive Stops
def simulate_rules(max_daily_loss, max_daily_trades, max_consec_stops):
    day_trades = defaultdict(list)
    for t in trades:
        day = t["in_time"].split()[0]
        day_trades[day].append(t)
    
    sim_trades = []
    for day in sorted(day_trades.keys()):
        daily_pnl = 0.0
        consec_stops = 0
        trade_count = 0
        for t in day_trades[day]:
            # Check circuit breaker before taking trade
            if max_daily_loss > 0 and daily_pnl <= -max_daily_loss:
                break
            if max_daily_trades > 0 and trade_count >= max_daily_trades:
                break
            if max_consec_stops > 0 and consec_stops >= max_consec_stops:
                break
            
            # Take trade
            trade_count += 1
            sim_trades.append(t)
            daily_pnl += t["net"]
            if t["net"] < 0:
                consec_stops += 1
            else:
                consec_stops = 0
                
    wins = [t for t in sim_trades if t["profit"] > 0]
    losses = [t for t in sim_trades if t["profit"] <= 0]
    gross_profit = sum(t["profit"] for t in wins)
    gross_loss = sum(abs(t["profit"]) for t in losses)
    total_comm = sum(t["commission"] for t in sim_trades)
    net_pnl = gross_profit - gross_loss + total_comm
    pf = gross_profit / gross_loss if gross_loss > 0 else 99.9
    wr = len(wins) / len(sim_trades) * 100 if sim_trades else 0
    return len(sim_trades), len(wins), len(losses), wr, gross_profit, gross_loss, net_pnl, pf

print("\n--- SIMULATION GRID OVER EXP_020 TRADES ---")
print(f"{'DailyMaxLoss':<13} | {'MaxTrades':<10} | {'MaxConsec':<10} | {'Trades':<7} | {'WinRate':<8} | {'GrossProfit':<12} | {'GrossLoss':<10} | {'NetPnL':<10} | {'PF':<6}")
print("-" * 100)

configs = [
    (140.0, 12, 0),  # Baseline EXP_020
    (100.0, 12, 0),
    (70.0,  12, 0),
    (50.0,  12, 0),
    (40.0,  12, 0),
    (30.0,  12, 0),
    (140.0, 6,  0),
    (50.0,  6,  0),
    (40.0,  6,  0),
    (140.0, 12, 2),  # Stop day after 2 consecutive stops
    (70.0,  12, 2),
    (50.0,  12, 2),
    (40.0,  8,  2),
    (40.0,  6,  2),
    (35.0,  5,  2),
]

for dloss, mtrades, cstop in configs:
    cnt, w, l, wr, gp, gl, net, pf = simulate_rules(dloss, mtrades, cstop)
    print(f"${dloss:<12.1f} | {mtrades:<10} | {cstop:<10} | {cnt:<7} | {wr:6.1f}%  | ${gp:<11.2f} | ${gl:<9.2f} | ${net:<9.2f} | {pf:5.2f}")
