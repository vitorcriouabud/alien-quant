import re
from datetime import datetime
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
        t_in = datetime.strptime(in_time, "%Y.%m.%d %H:%M:%S")
        t_out = datetime.strptime(deal_time, "%Y.%m.%d %H:%M:%S")
        trades.append({
            "in_time": in_time,
            "t_in": t_in,
            "type": in_type, # 'buy' or 'sell'
            "entry_price": in_price,
            "exit_time": deal_time,
            "t_out": t_out,
            "exit_price": price,
            "profit": profit,
            "commission": comm * 2,
            "net": profit + (comm * 2),
            "comment": comment
        })
        current_in = None

print(f"Total trades: {len(trades)}")

def simulate_directional_lockout(lockout_minutes, max_daily_loss):
    day_trades = defaultdict(list)
    for t in trades:
        day = t["in_time"].split()[0]
        day_trades[day].append(t)
        
    sim_trades = []
    blocked_trades = []
    
    for day in sorted(day_trades.keys()):
        daily_pnl = 0.0
        last_stopped_dir = None
        last_stopped_time = None
        
        for t in day_trades[day]:
            # Check circuit breaker
            if max_daily_loss > 0 and daily_pnl <= -max_daily_loss:
                continue
                
            # Check directional lockout
            if lockout_minutes > 0 and last_stopped_dir == t["type"] and last_stopped_time:
                elapsed = (t["t_in"] - last_stopped_time).total_seconds() / 60.0
                if elapsed < lockout_minutes:
                    blocked_trades.append((t, f"Blocked {t['type']} after stop {elapsed:.1f}m ago"))
                    continue
            
            # Trade executed
            sim_trades.append(t)
            daily_pnl += t["net"]
            
            if t["net"] < 0:
                last_stopped_dir = t["type"]
                last_stopped_time = t["t_out"]
            else:
                last_stopped_dir = None
                last_stopped_time = None
                
    wins = [t for t in sim_trades if t["profit"] > 0]
    losses = [t for t in sim_trades if t["profit"] <= 0]
    gross_profit = sum(t["profit"] for t in wins)
    gross_loss = sum(abs(t["profit"]) for t in losses)
    total_comm = sum(t["commission"] for t in sim_trades)
    net_pnl = gross_profit - gross_loss + total_comm
    pf = gross_profit / gross_loss if gross_loss > 0 else 99.9
    wr = len(wins) / len(sim_trades) * 100 if sim_trades else 0
    return len(sim_trades), len(blocked_trades), len(wins), len(losses), wr, gross_profit, gross_loss, net_pnl, pf

print(f"{'Lockout':<10} | {'DailyLoss':<10} | {'Trades':<7} | {'Blocked':<8} | {'WinRate':<8} | {'GrossProfit':<12} | {'GrossLoss':<10} | {'NetPnL':<10} | {'PF':<6}")
print("-" * 100)

for lmin in [0, 5, 10, 15, 20, 30, 45, 60]:
    for dloss in [140.0, 70.0, 50.0, 40.0, 35.0]:
        cnt, blk, w, l, wr, gp, gl, net, pf = simulate_directional_lockout(lmin, dloss)
        print(f"{lmin:<10}m | ${dloss:<9.1f} | {cnt:<7} | {blk:<8} | {wr:6.1f}%  | ${gp:<11.2f} | ${gl:<9.2f} | ${net:<9.2f} | {pf:5.2f}")
