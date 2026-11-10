import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\ALIEN_V11_NOVEMBRO_2026\ALIEN_V11_NOVEMBRO_2026.htm"

with open(path, "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

pos = text.find("Transa")
deals_part = text[pos:]
deal_rows = re.findall(r'<tr[^>]*>(.*?)</tr>', deals_part, re.DOTALL | re.IGNORECASE)

print("=== AMOSTRA DE TRADES DE NOVEMBRO 2026 ===")
for r in deal_rows[1:30]:
    cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
    cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
    if len(cols) == 13:
        time_str = cols[0]
        direction = cols[4]
        deal_type = cols[3]
        price = cols[6]
        profit = cols[10]
        comment = cols[12]
        print(f"{time_str} | {deal_type:4s} | {direction:4s} | Prc: {price} | PnL: {profit:>6s} | {comment}")
