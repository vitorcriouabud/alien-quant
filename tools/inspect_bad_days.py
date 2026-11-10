import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_021_V12_1_VALIDATED\EXP_021_V12_1_VALIDATED.htm"
html = open(path, "r", encoding="utf-16le", errors="ignore").read()

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL | re.IGNORECASE)

deals = []
for r in rows:
    cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.DOTALL | re.IGNORECASE)]
    if len(cells) >= 13 and re.match(r'^\d{4}\.\d{2}\.\d{2}', cells[0]):
        deals.append(cells)

print(f"{'Time':<20} | {'Order':<8} | {'Type':<6} | {'Dir':<4} | {'Price':<10} | {'Profit':<8} | {'Comment'}")
print("-" * 80)
for d in deals:
    dt = d[0]
    if "2026.11.05" in dt:
        print(f"{d[0]:<20} | {d[1]:<8} | {d[3]:<6} | {d[4]:<4} | {d[6]:<10} | {d[10]:<8} | {d[12] if len(d)>12 else ''}")
