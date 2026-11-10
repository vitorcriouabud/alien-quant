import os
import time
import subprocess
import datetime

print(f"[{datetime.datetime.now()}] Ensuring all 4 systems are running...")

TOOLS = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
PY = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\python.exe"
PYW = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe"
DETACHED = 0x00000008 | 0x08000000

# 1. Check Goat 5K Terminal
ps_term = 'Get-Process | Where-Object { $_.ProcessName -like "*terminal64*" } | Select-Object Id, Path'
out_term = subprocess.run(["powershell", "-NoProfile", "-Command", ps_term], capture_output=True, text=True).stdout
print("Current Terminals:")
print(out_term)

has_5k = "Goat Funded MT5 Terminal" in out_term
has_25k = "Goat_MT5_25K" in out_term

if not has_5k:
    print("Launching Goat 5K MT5...")
    subprocess.Popen([r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe", "/profile:Default"], creationflags=0x00000008, close_fds=True)
else:
    print("Goat 5K MT5 is already RUNNING.")

if not has_25k:
    print("Launching Goat 25K MT5...")
    subprocess.Popen([
        r"C:\Goat_MT5_25K\terminal64.exe",
        "/portable",
        r"/config:C:\Goat_MT5_25K\startup_25k.ini",
        "/login:436271843",
        r"/password:PROTECTED_PASSWORD",
        "/server:GoatFunded-Server2",
        "/profile:Default"
    ], creationflags=0x00000008, close_fds=True)
else:
    print("Goat 25K MT5 is already RUNNING.")

# 2. Check Python processes
ps_py = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "python" } | Select-Object ProcessId, CommandLine'
out_py = subprocess.run(["powershell", "-NoProfile", "-Command", ps_py], capture_output=True, text=True).stdout
print("\nCurrent Python processes:")
print(out_py)

has_core = "alien_living_core.py" in out_py
has_wd = "alien_watchdog.py" in out_py

if not has_core:
    print("Launching alien_living_core.py...")
    subprocess.Popen([PY, "-u", os.path.join(TOOLS, "alien_living_core.py")], creationflags=DETACHED, close_fds=True)
else:
    print("alien_living_core.py is already RUNNING.")

if not has_wd:
    print("Launching alien_watchdog.py...")
    subprocess.Popen([PYW, os.path.join(TOOLS, "alien_watchdog.py")], creationflags=DETACHED, close_fds=True)
else:
    print("alien_watchdog.py is already RUNNING.")

print("\nWaiting 15 seconds for all systems to settle...")
time.sleep(15)

# Final verification
out_term_final = subprocess.run(["powershell", "-NoProfile", "-Command", ps_term], capture_output=True, text=True).stdout
out_py_final = subprocess.run(["powershell", "-NoProfile", "-Command", ps_py], capture_output=True, text=True).stdout
print("\n=== FINAL VERIFICATION ===")
print("Terminals:")
print(out_term_final)
print("Daemons:")
print(out_py_final)
