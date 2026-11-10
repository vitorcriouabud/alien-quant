import re
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"
html = open(path, "r", encoding="utf-16le", errors="ignore").read()

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL | re.IGNORECASE)

deals = []
for r in rows:
    cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.DOTALL | re.IGNORECASE)]
    if len(cells) >= 13 and re.match(r'^\d{4}\.\d{2}\.\d{2}', cells[0]):
        deals.append(cells)

# Pair in and out deals by order/position
positions = []
in_deals = {}
for d in deals:
    deal_type = d[3].lower() # buy or sell
    direction = d[4].lower() # in or out
    deal_time = d[0]
    deal_id = d[1]
    order_id = d[7]
    price = float(d[6].replace(" ", "").replace(",", ".")) if d[6] else 0.0
    profit = float(d[10].replace(" ", "").replace(",", ".")) if d[10] else 0.0
    comment = d[12] if len(d) > 12 else ""
    
    if direction == "in":
        in_deals[order_id] = (deal_time, deal_type, price, comment)
    elif direction == "out":
        entry = in_deals.get(order_id)
        if entry:
            in_time, in_type, in_price, in_comm = entry
            positions.append({
                "in_time": in_time,
                "out_time": deal_time,
                "type": in_type,
                "in_price": in_price,
                "out_price": price,
                "profit": profit,
                "out_comm": comment
            })
        else:
            positions.append({
                "in_time": deal_time,
                "out_time": deal_time,
                "type": "out_only",
                "in_price": 0,
                "out_price": price,
                "profit": profit,
                "out_comm": comment
            })

print(f"Total reconstructed positions: {len(positions)}")

# Analyze losing days: Oct 27, 28, 29, Nov 03, Nov 05
target_days = ["2026.10.27", "2026.10.28", "2026.10.29", "2026.11.03", "2026.11.05"]

for target in target_days:
    print(f"\n==================== {target} ====================")
    day_pos = [p for p in positions if p["in_time"].startswith(target)]
    day_buys = [p for p in day_pos if p["type"] == "buy"]
    day_sells = [p for p in day_pos if p["type"] == "sell"]
    print(f"Total: {len(day_pos)} (Buys: {len(day_buys)}, Sells: {len(day_sells)})")
    
    for p in day_pos:
        dur = ""
        try:
            t1 = datetime.strptime(p["in_time"], "%Y.%m.%d %H:%M:%S")
            t2 = datetime.strptime(p["out_time"], "%Y.%m.%d %H:%M:%S")
            dur = f"{(t2 - t1).total_seconds():.0f}s"
        except:
            pass
        pnl = p["profit"]
        sign = "+" if pnl > 0 else ""
        print(f"  {p['in_time'][11:]} -> {p['out_time'][11:]} ({dur:>5}) | {p['type'].upper():<4} at {p['in_price']:7.2f} -> {p['out_price']:7.2f} | PnL: {sign}{pnl:6.2f} | {p['out_comm']}")
