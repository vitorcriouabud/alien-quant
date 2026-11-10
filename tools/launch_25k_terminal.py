import os
import time
import glob
import subprocess
import datetime

EXE = r"C:\Goat_MT5_25K\terminal64.exe"
CONFIG = r"C:\Goat_MT5_25K\startup_25k.ini"
DETACHED = 0x00000008

print(f"[{datetime.datetime.now()}] Launching Goat 25K MT5 terminal in portable mode...")
cmd = [EXE, "/portable", f"/config:{CONFIG}", "/profile:Default"]
print(f"Executing: {' '.join(cmd)}")

proc = subprocess.Popen(cmd, creationflags=DETACHED, close_fds=True)
print(f"Launched process PID: {proc.pid}")

# Wait for terminal to start and write logs
print("Waiting 15s for initialization and connection...")
time.sleep(15)

# Check logs in C:\Goat_MT5_25K\logs and MQL5\Logs
for log_dir in [r"C:\Goat_MT5_25K\logs", r"C:\Goat_MT5_25K\MQL5\Logs"]:
    print(f"\n--- Checking {log_dir} ---")
    files = glob.glob(os.path.join(log_dir, "*.log"))
    if files:
        latest = max(files, key=os.path.getmtime)
        print(f"Latest log: {latest} (mtime: {datetime.datetime.fromtimestamp(os.path.getmtime(latest))})")
        raw = open(latest, "rb").read()
        txt = raw.decode("utf-16le", errors="ignore")
        lines = txt.splitlines()
        for l in lines[-20:]:
            print("  ", l)
    else:
        print("No log files found yet.")

# Check processes
ps = 'Get-Process | Where-Object { $_.ProcessName -like "*terminal*" } | Select-Object Id, ProcessName, Path'
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
print("\n=== RUNNING TERMINAL PROCESSES ===")
print(out)
