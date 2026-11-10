import os
import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\ALIEN_V11_OUTUBRO_2026\ALIEN_V11_OUTUBRO_2026.htm"

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

print("\n=== METRICAS ALIEN V11 SCALPER (19/10/2026 - 24/10/2026) ===")
for k, v in extracted:
    print(f"{k} : {v}")
