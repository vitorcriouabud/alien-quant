import os
import sys
import glob
import subprocess
import datetime

print(f"[{datetime.datetime.now()}] Inspecting full ALIEN & MT5 environment...")

# 1. Check Python processes
ps_cmd = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "python|terminal64|metaeditor" } | Select-Object ProcessId, Name, CommandLine'
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd], capture_output=True, text=True).stdout
print("\n=== RUNNING PROCESSES ===")
print(out)

# 2. Check 5K Goat Terminal
GOAT_5K_DATA = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564"
print("\n=== GOAT 5K LOGS & CHARTS ===")
chart_files = glob.glob(os.path.join(GOAT_5K_DATA, "MQL5", "Profiles", "Charts", "Default", "*.chr"))
if not chart_files:
    chart_files = glob.glob(os.path.join(GOAT_5K_DATA, "Profiles", "Charts", "Default", "*.chr"))
print(f"Chart files found: {chart_files}")
for cf in chart_files:
    raw = open(cf, "rb").read()
    txt = raw.decode("utf-16", errors="ignore")
    has_ea = "<expert>" in txt
    sym = ""
    for line in txt.splitlines():
        if line.startswith("symbol="):
            sym = line
            break
    print(f"  {os.path.basename(cf)}: {sym} | Has EA: {has_ea}")
    if has_ea:
        for line in txt.splitlines():
            if any(k in line for k in ["name=", "path=", "FixedLot=", "DailyProfitTargetMoney=", "DailyMaxLossMoney=", "AllowLiveRealTrading="]):
                print(f"    {line.strip()}")

# 3. Check 25K MT5 folder
GOAT_25K_DIR = r"C:\Goat_MT5_25K"
print("\n=== GOAT 25K FOLDER STATUS ===")
print(f"Exists: {os.path.exists(GOAT_25K_DIR)}")
for sub in ["Config", "Profiles", "MQL5", "MQL5\\Profiles\\Charts\\Default", "Profiles\\Charts\\Default"]:
    p = os.path.join(GOAT_25K_DIR, sub)
    print(f"  {sub}: exists={os.path.exists(p)}")
    if "Charts" in sub and os.path.exists(p):
        for f in glob.glob(os.path.join(p, "*.chr")):
            raw = open(f, "rb").read()
            txt = raw.decode("utf-16", errors="ignore")
            sym = ""
            for line in txt.splitlines():
                if line.startswith("symbol="):
                    sym = line
                    break
            print(f"    {os.path.basename(f)}: {sym} | Has EA: {'<expert>' in txt}")

# 4. Check MT5 connection via python mt5 library if available
try:
    import MetaTrader5 as mt5
    print("\n=== MT5 PYTHON API CHECK ===")
    init_res = mt5.initialize()
    print(f"mt5.initialize() -> {init_res}")
    if init_res:
        term = mt5.terminal_info()
        acc = mt5.account_info()
        print(f"Terminal: {term.name} | Path: {term.path} | Connected: {term.connected} | TradeAllowed: {term.trade_allowed}")
        if acc:
            print(f"Account: Login={acc.login}, Server={acc.server}, Name={acc.name}, Balance={acc.balance}, Equity={acc.equity}, Profit={acc.profit}")
        syms = [s.name for s in mt5.symbols_get() if "XAU" in s.name or "GOLD" in s.name]
        print(f"Gold symbols: {syms}")
        mt5.shutdown()
except Exception as e:
    print(f"MT5 API error: {e}")

print("\nInspection complete.")
