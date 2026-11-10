"""Spawn ALIEN 5K, 25K, Living Core and Watchdog outside Job Object via WMI Win32_Process.Create
"""
import subprocess
import time
import json
import os

MT5_5K = r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe"
MT5_25K_EXE = r"C:\Goat_MT5_25K\terminal64.exe"
MT5_25K_CMD = (
    r'"C:\Goat_MT5_25K\terminal64.exe" /portable "/config:C:\Goat_MT5_25K\startup_25k.ini" '
    r'/login:436271843 "/password:PROTECTED_PASSWORD" /server:GoatFunded-Server2 /profile:Default'
)
PYTHONW = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe"
TOOLS = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
LIVING_CORE_CMD = f'"{PYTHONW}" "{os.path.join(TOOLS, "alien_living_core.py")}"'
WATCHDOG_CMD = f'"{PYTHONW}" "{os.path.join(TOOLS, "alien_watchdog.py")}"'

def spawn_wmi(cmd):
    ps_cmd = f"Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{{ CommandLine = '{cmd}' }}"
    try:
        res = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd],
                             capture_output=True, text=True, timeout=15)
        print(f"Spawned: {cmd[:40]}... -> {res.stdout.strip()}")
    except Exception as e:
        print(f"Error spawning {cmd}: {e}")

if __name__ == "__main__":
    print("Launching Immortal ALIEN Services via WMI...")
    spawn_wmi(f'"{MT5_5K}"')
    time.sleep(2)
    spawn_wmi(MT5_25K_CMD)
    time.sleep(2)
    spawn_wmi(LIVING_CORE_CMD)
    time.sleep(1)
    spawn_wmi(WATCHDOG_CMD)
    print("All services launched under WmiPrvSE.exe!")
