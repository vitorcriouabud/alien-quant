import os
import time
import subprocess
import datetime

print(f"[{datetime.datetime.now()}] Restarting Living Core and Watchdog...")

TOOLS = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
PY = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\python.exe"
PYW = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe"
DETACHED = 0x00000008 | 0x08000000

# 1. Kill old python processes running alien_living_core.py or alien_watchdog.py
ps = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "python" -and ($_.CommandLine -like "*alien_living_core*" -or $_.CommandLine -like "*alien_watchdog*") } | Select-Object -ExpandProperty ProcessId'
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout.strip()
if out:
    for pid in out.splitlines():
        pid = pid.strip()
        if pid:
            print(f"Stopping old process PID: {pid}")
            subprocess.run(["taskkill", "/F", "/PID", pid], capture_output=True)

time.sleep(2)

# 2. Start Living Core
core_proc = subprocess.Popen([PY, "-u", os.path.join(TOOLS, "alien_living_core.py")], creationflags=DETACHED, close_fds=True)
print(f"Started alien_living_core.py PID: {core_proc.pid}")

# 3. Start Watchdog
wd_proc = subprocess.Popen([PYW, os.path.join(TOOLS, "alien_watchdog.py")], creationflags=DETACHED, close_fds=True)
print(f"Started alien_watchdog.py PID: {wd_proc.pid}")

time.sleep(3)

# 4. Check status
ps_check = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "python|terminal64" } | Select-Object ProcessId, Name, CommandLine'
out_check = subprocess.run(["powershell", "-NoProfile", "-Command", ps_check], capture_output=True, text=True).stdout
print("\n=== ACTIVE PROCESSES ===")
print(out_check)
