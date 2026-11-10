import re
from datetime import datetime
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"
html = open(path, "r", encoding="utf-16le", errors="ignore").read()

# MT5 report deals table
# Find rows with deal data
rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL | re.IGNORECASE)

deals = []
for r in rows:
    cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.DOTALL | re.IGNORECASE)]
    # Look for deal rows: e.g. [date, time, deal_id, order_id, symbol, type, direction, volume, price, order, commission, fee, swap, profit, balance]
    if len(cells) >= 13:
        # Check if first cell is date
        if re.match(r'^\d{4}\.\d{2}\.\d{2}', cells[0]):
            deals.append(cells)

print(f"Total deal rows found: {len(deals)}")

# Group deals by day and analyze closed trades (in/out)
day_stats = defaultdict(lambda: {"trades": 0, "wins": 0, "losses": 0, "profit": 0.0, "loss": 0.0, "net": 0.0})

for d in deals:
    # Check if this deal has profit (i.e. exit deal)
    # MT5 deals columns typically: Time, Deal, Order, Symbol, Type, Direction, Volume, Price, Order, Commission, Fee, Swap, Profit, Balance
    try:
        # Find profit column
        dt_str = d[0] # date time
        day = dt_str.split()[0]
        # Look for profit number
        profit_val = None
        for col in d[-4:]:
            # Clean number
            clean_num = col.replace(" ", "").replace(",", ".")
            try:
                val = float(clean_num)
                # If there's a decimal and not an integer order id
                if "." in clean_num:
                    profit_val = val
            except ValueError:
                pass
        
        # In MT5 deal table: [Time, Deal, Symbol, Type, Direction, Volume, Price, Order, Commission, Swap, Profit, Balance]
        # or similar
        # Let's inspect the first 3 rows to be certain of column structure
    except Exception as e:
        pass

# Let's print sample rows
print("\nSample deal rows:")
for d in deals[:5]:
    print(d)
for d in deals[-5:]:
    print(d)
