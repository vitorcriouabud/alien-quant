import subprocess
import os
import re
import time
from datetime import datetime

# Script to run sequential weekly tests of ALIEN V11 and parse results
weeks = [
    {"name": "OUT_SEM1", "from": "2026.10.05", "to": "2026.10.10"},
    {"name": "OUT_SEM2", "from": "2026.10.12", "to": "2026.10.17"},
    {"name": "OUT_SEM3", "from": "2026.10.19", "to": "2026.10.24"},
    {"name": "OUT_SEM4", "from": "2026.10.26", "to": "2026.10.31"},
    {"name": "NOV_SEM1", "from": "2026.11.02", "to": "2026.11.07"},
]

runner_ps1 = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\Run-Backtest.ps1"
expert_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_SCALPER.mq5"

print("=== SCRIPT DE VALIDACAO MULTI-SEMANAL ALIEN V11 ===")
print(f"Total de semanas planejadas: {len(weeks)}")

def parse_report_metrics(htm_path):
    if not os.path.exists(htm_path):
        return None
    try:
        with open(htm_path, "r", encoding="utf-16", errors="ignore") as f:
            text = f.read()
    except Exception:
        return None

    metrics = {}
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', text, re.DOTALL | re.IGNORECASE)
    for r in rows:
        cols = re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL | re.IGNORECASE)
        clean = [re.sub(r'<[^>]+>', '', c).strip() for c in cols if c]
        if len(clean) >= 2:
            for i in range(0, len(clean)-1, 2):
                k = clean[i].lower()
                v = clean[i+1]
                if "lucro líquido total" in k or "total net profit" in k:
                    metrics["profit"] = float(v.replace(" ", "").replace(",", "."))
                elif "fator de lucro" in k or "profit factor" in k:
                    try:
                        metrics["pf"] = float(v.replace(" ", "").replace(",", "."))
                    except:
                        metrics["pf"] = 0.0
                elif "total de negociações" in k or "total trades" in k:
                    try:
                        metrics["trades"] = int(v.split()[0].replace(" ", ""))
                    except:
                        metrics["trades"] = 0
                elif "rebaixamento máximo do capital líquido" in k or "equity drawdown maximal" in k:
                    # e.g. "11.51 (0.11%)"
                    m = re.search(r'([\d\.\,]+)', v)
                    if m:
                        metrics["max_dd"] = float(m.group(1).replace(",", "."))
                elif "negociações com lucro" in k or "profit trades" in k:
                    m = re.search(r'\(([\d\.\,]+)%\)', v)
                    if m:
                        metrics["win_rate"] = float(m.group(1).replace(",", "."))
    return metrics

if __name__ == "__main__":
    print("Script pronto para execucao.")
