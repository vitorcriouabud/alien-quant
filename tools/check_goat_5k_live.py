import os
import glob
import datetime

GOAT_5K_DATA = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564"

print("=== CHECKING GOAT 5K TERMINAL LOGS ===")
term_logs = glob.glob(os.path.join(GOAT_5K_DATA, "logs", "*.log"))
if term_logs:
    latest_term_log = max(term_logs, key=os.path.getmtime)
    print(f"Latest Terminal Log: {latest_term_log} (mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(latest_term_log))})")
    raw = open(latest_term_log, "rb").read()
    txt = raw.decode("utf-16", errors="ignore")
    lines = txt.splitlines()
    print("Last 15 lines of Terminal Log:")
    for l in lines[-15:]:
        print("  ", l)

print("\n=== CHECKING GOAT 5K EXPERT LOGS ===")
expert_logs = glob.glob(os.path.join(GOAT_5K_DATA, "MQL5", "Logs", "*.log"))
if expert_logs:
    latest_exp_log = max(expert_logs, key=os.path.getmtime)
    print(f"Latest Expert Log: {latest_exp_log} (mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(latest_exp_log))})")
    raw = open(latest_exp_log, "rb").read()
    txt = raw.decode("utf-16", errors="ignore")
    lines = txt.splitlines()
    print("Last 20 lines of Expert Log:")
    for l in lines[-20:]:
        print("  ", l)

print("\n=== CHECKING GOAT 5K FILES ===")
files_dir = os.path.join(GOAT_5K_DATA, "MQL5", "Files")
for f in os.listdir(files_dir):
    fp = os.path.join(files_dir, f)
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(fp))
    print(f"  {f} ({os.path.getsize(fp)} bytes, modified: {mtime})")
