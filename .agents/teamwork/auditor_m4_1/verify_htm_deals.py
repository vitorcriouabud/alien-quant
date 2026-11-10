import re
from pathlib import Path

htm_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_015_V12_1_BENCHMARK\EXP_015_V12_1_BENCHMARK.htm"

with open(htm_path, "r", encoding="utf-16", errors="ignore") as f:
    htm = f.read()

# Extract title and parameters
title_m = re.search(r"<title>(.*?)</title>", htm, re.IGNORECASE)
print(f"HTM Title: {title_m.group(1) if title_m else 'N/A'}")

# Extract summary table
rows = re.findall(r"<tr[^>]*>(.*?)</tr>", htm, re.DOTALL | re.IGNORECASE)
print(f"Total HTML rows: {len(rows)}")

# Find key cells
for r in rows:
    text = re.sub(r"<[^>]+>", " ", r).strip()
    if any(k in text for k in ["Lucro L", "Fator de Lucro", "Total de Negoci", "Rebaixamento M", "Mdia lucro", "Mdia perda", "Saldo final"]):
        print("METRIC ROW:", text)

# Extract deals from table
deals = []
for r in rows:
    cols = re.findall(r"<td[^>]*>(.*?)</td>", r, re.DOTALL | re.IGNORECASE)
    cleaned = [re.sub(r"<[^>]+>", "", c).strip() for c in cols]
    if len(cleaned) >= 8 and re.match(r"\d{4}\.\d\d\.\d\d \d\d:\d\d:\d\d", cleaned[0]):
        deals.append(cleaned)

print(f"\nTotal deals parsed from HTM: {len(deals)}")
if deals:
    print(f"First deal: {deals[0]}")
    print(f"Last deal: {deals[-1]}")
    # Check if deal 0 is deposit
    # Let's count trades (in/out)
    deal_types = [d[1] if len(d)>1 else '' for d in deals]
    print(f"Deal types summary: count={len(deal_types)}, buy/sell={sum(1 for t in deal_types if 'buy' in t.lower() or 'sell' in t.lower())}")
