import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"
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
            "commission": comm * 2,
            "comment": comment
        })
        current_in = None

print(f"Total paired trades: {len(trades)}")

for day in ["2026.10.28", "2026.10.29", "2026.11.03", "2026.11.05"]:
    print(f"\n--- {day} ---")
    day_t = [t for t in trades if t["in_time"].startswith(day)]
    for t in day_t:
        pnl = t["profit"]
        sign = "+" if pnl > 0 else ""
        print(f"  {t['in_time'][11:]} -> {t['exit_time'][11:]} | {t['type'].upper():<4} at {t['entry_price']:.2f} -> {t['exit_price']:.2f} | PnL: {sign}{pnl:6.2f} | {t['comment']}")
