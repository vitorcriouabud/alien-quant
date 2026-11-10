import os
import re
from collections import defaultdict

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\ALIEN_V11_NOVEMBRO_2026\ALIEN_V11_NOVEMBRO_2026.htm"

if not os.path.exists(path):
    print("Report not found at", path)
    exit(1)

with open(path, "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

rows = re.findall(r'<tr[^>]*>(.*?)</tr>', text, re.DOTALL | re.IGNORECASE)

extracted = []
for r in rows:
    cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
    clean_cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
    clean_cols = [c for c in clean_cols if c]
    if len(clean_cols) >= 2:
        for i in range(0, len(clean_cols) - 1, 2):
            k = clean_cols[i]
            v = clean_cols[i+1]
            if any(term in k.lower() for term in [
                "lucro", "fator", "rebaixamento", "negociações", "trades", "drawdown",
                "esperado", "perda", "saldo", "patrimônio", "acertos", "erro", "ganho", "retorno", "sharpe"
            ]):
                extracted.append((k, v))

print("\n=== METRICAS ALIEN V11 NOVEMBRO 2026 (02/11/2026 - 07/11/2026) ===")
for k, v in extracted:
    print(f"{k} : {v}")

# Parse deals
pos = text.find("Transa")
deals_part = text[pos:]
deal_rows = re.findall(r'<tr[^>]*>(.*?)</tr>', deals_part, re.DOTALL | re.IGNORECASE)

daily_net = defaultdict(float)
daily_trades = defaultdict(int)
daily_wins = defaultdict(int)

closed = 0
for r in deal_rows:
    cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
    cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
    if len(cols) == 13:
        direction = cols[4].lower()
        if direction in ["out", "in/out"]:
            m = re.match(r'(\d{4}\.\d{2}\.\d{2})', cols[0])
            if m:
                day = m.group(1)
                comm = float(cols[8].replace(' ', '').replace(',', '.'))
                profit = float(cols[10].replace(' ', '').replace(',', '.'))
                daily_net[day] += profit + comm
                daily_trades[day] += 1
                if profit > 0:
                    daily_wins[day] += 1
                closed += 1

print(f"\nTotal Closed Trades: {closed}")
print("\n=== PERFORMANCE POR DIA (NOVEMBRO 2026) ===")
for d in sorted(daily_net.keys()):
    t = daily_trades[d]
    w = daily_wins[d]
    wr = (w / t * 100) if t > 0 else 0
    print(f"{d} : {t:2d} trades | WinRate: {wr:4.1f}% | Net: ${daily_net[d]:6.2f}")
