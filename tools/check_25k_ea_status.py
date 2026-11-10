import os
import glob
import datetime

print(f"[{datetime.datetime.now()}] Checking 25K MQL5 files and logs...")

# Check MQL5\Files
files_dir = r"C:\Goat_MT5_25K\MQL5\Files"
if os.path.exists(files_dir):
    for f in os.listdir(files_dir):
        fp = os.path.join(files_dir, f)
        mt = datetime.datetime.fromtimestamp(os.path.getmtime(fp))
        print(f"  File in MQL5/Files: {f} ({os.path.getsize(fp)} bytes, mtime: {mt})")

# Check MQL5\Logs
mql_logs = glob.glob(r"C:\Goat_MT5_25K\MQL5\Logs\*.log")
print(f"MQL5 Logs found: {len(mql_logs)}")
for f in mql_logs:
    print(f"  {f} ({os.path.getsize(f)} bytes)")
    raw = open(f, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
    lines = txt.splitlines()
    for l in lines[-15:]:
        print("    ", l.encode("ascii", errors="replace").decode("ascii"))

# Check terminal log
tlog = r"C:\Goat_MT5_25K\logs\20261109.log"
raw = open(tlog, "rb").read()
txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
lines = txt.splitlines()
print(f"\nTerminal log lines ({len(lines)} total):")
for l in lines[-15:]:
    print("  ", l.encode("ascii", errors="replace").decode("ascii"))
