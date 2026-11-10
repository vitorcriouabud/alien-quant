import os
import glob
import datetime
import MetaTrader5 as mt5

print("=====================================================================")
print(f"ALIEN SYSTEM FINAL DEEP AUDIT — {datetime.datetime.now()}")
print("=====================================================================")

# 1. Check Terminal 1: Goat 5K
print("\n--- 1. GOAT 5K EVALUATION PHASE 1 (Login 315462944) ---")
DATA_5K = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564"
rep_5k = glob.glob(os.path.join(DATA_5K, "MQL5", "Files", "ALIEN_V1089_REPORT_*.txt"))
png_5k = os.path.join(DATA_5K, "MQL5", "Files", "ALIEN_LIVE_CONFLUENCE.png")
if rep_5k:
    lat_5k = max(rep_5k, key=os.path.getmtime)
    print(f"Report: {os.path.basename(lat_5k)} (mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(lat_5k))})")
    raw = open(lat_5k, "rb").read()
    txt = raw.decode("utf-16", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
    for line in txt.splitlines()[:12]:
        print("  ", line.encode("ascii", errors="replace").decode("ascii"))
if os.path.exists(png_5k):
    print(f"Screenshot: {os.path.basename(png_5k)} ({os.path.getsize(png_5k)} bytes, mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(png_5k))})")

# Check Chart01 config for 5K
chr_5k = os.path.join(DATA_5K, "MQL5", "Profiles", "Charts", "Default", "chart01.chr")
raw = open(chr_5k, "rb").read()
txt = raw.decode("utf-16le", errors="ignore")
s = txt.find("<expert>")
e = txt.find("</expert>")
print("5K Chart Inputs:")
for l in txt[s:e+9].splitlines():
    if any(k in l for k in ["name=", "FixedLot=", "DailyProfitTargetMoney=", "DailyMaxLossMoney=", "TotalMaxLossMoney=", "AllowLiveRealTrading=", "ExpertMagic="]):
        print("  ", l.strip())

# 2. Check Terminal 2: Goat 25K
print("\n--- 2. GOAT 25K COMPETITION (Login 436271843) ---")
DATA_25K = r"C:\Goat_MT5_25K"
rep_25k = glob.glob(os.path.join(DATA_25K, "MQL5", "Files", "ALIEN_V1089_REPORT_*.txt"))
png_25k = os.path.join(DATA_25K, "MQL5", "Files", "ALIEN_LIVE_CONFLUENCE.png")
if rep_25k:
    lat_25k = max(rep_25k, key=os.path.getmtime)
    print(f"Report: {os.path.basename(lat_25k)} (mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(lat_25k))})")
    raw = open(lat_25k, "rb").read()
    txt = raw.decode("utf-16", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
    for line in txt.splitlines()[:12]:
        print("  ", line.encode("ascii", errors="replace").decode("ascii"))
if os.path.exists(png_25k):
    print(f"Screenshot: {os.path.basename(png_25k)} ({os.path.getsize(png_25k)} bytes, mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(png_25k))})")

# Check Chart01 config for 25K
chr_25k = os.path.join(DATA_25K, "Profiles", "Charts", "Default", "chart01.chr")
raw = open(chr_25k, "rb").read()
txt = raw.decode("utf-16le", errors="ignore")
s = txt.find("<expert>")
e = txt.find("</expert>")
print("25K Chart Inputs:")
for l in txt[s:e+9].splitlines():
    if any(k in l for k in ["name=", "FixedLot=", "DailyProfitTargetMoney=", "DailyMaxLossMoney=", "TotalMaxLossMoney=", "AllowLiveRealTrading=", "ExpertMagic="]):
        print("  ", l.strip())

# 3. Check Watchdog Log
print("\n--- 3. GUARDIAN WATCHDOG LOG ---")
wd_log = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.log"
if os.path.exists(wd_log):
    raw = open(wd_log, "r", encoding="utf-8", errors="ignore").read()
    for l in raw.splitlines()[-6:]:
        print("  ", l)

# 4. Check Living Core State
print("\n--- 4. LIVING CORE TELEGRAM BOT ---")
stream_file = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\ALIEN_NEURAL_STREAM.jsonl"
if os.path.exists(stream_file):
    print(f"Neural stream active ({os.path.getsize(stream_file)} bytes)")

print("\n=====================================================================")
print("AUDIT COMPLETE.")
print("=====================================================================")
