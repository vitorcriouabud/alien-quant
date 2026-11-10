import os
import re
import shutil

path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\V10_89_OUTUBRO_2026.htm"

with open(path, "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

print(f"Read chars: {len(text)}")
# Find rows in HTML table
rows = re.findall(r'<tr[^>]*>(.*?)</tr>', text, re.DOTALL | re.IGNORECASE)
print(f"Total HTML rows: {len(rows)}")

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

print("\n--- METRICAS DO TESTE (PORTUGUES) ---")
for k, v in extracted:
    print(f"{k} : {v}")
