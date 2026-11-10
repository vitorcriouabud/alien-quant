import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\ALIEN_V11_OUTUBRO_2026\ALIEN_V11_OUTUBRO_2026.htm"

with open(path, "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

pos = text.find("Transa")
deals_part = text[pos:]

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', deals_part, re.DOTALL | re.IGNORECASE)

print("=== TRADES DE SEXTA-FEIRA (2026.10.23) EM ALIEN V11 ===")
for r in rows:
    cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
    cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
    if len(cols) == 13 and "2026.10.23" in cols[0]:
        time_str = cols[0]
        direction = cols[4]
        deal_type = cols[3]
        price = cols[6]
        profit = cols[10]
        comment = cols[12]
        print(f"{time_str} | {deal_type:4s} | {direction:4s} | Prc: {price} | PnL: {profit:>6s} | {comment}")
