import os
import glob
import subprocess
import datetime

print(f"[{datetime.datetime.now()}] Checking 25K Terminal status...")

# Check if terminal64.exe is running from C:\Goat_MT5_25K
ps = 'Get-Process | Where-Object { $_.ProcessName -like "*terminal*" } | Select-Object Id, ProcessName, Path'
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
print(out)

log_file = r"C:\Goat_MT5_25K\logs\20261109.log"
if os.path.exists(log_file):
    raw = open(log_file, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
    lines = txt.splitlines()
    print(f"\n--- {log_file} (Total {len(lines)} lines) ---")
    for l in lines[-25:]:
        safe_l = l.encode("ascii", errors="replace").decode("ascii")
        print("  ", safe_l)

mql_logs = glob.glob(r"C:\Goat_MT5_25K\MQL5\Logs\*.log")
if mql_logs:
    latest = max(mql_logs, key=os.path.getmtime)
    print(f"\n--- {latest} ---")
    raw = open(latest, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
    lines = txt.splitlines()
    for l in lines[-25:]:
        safe_l = l.encode("ascii", errors="replace").decode("ascii")
        print("  ", safe_l)
else:
    print("\nNo MQL5 logs yet.")
