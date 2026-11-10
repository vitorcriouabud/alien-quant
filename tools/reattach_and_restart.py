"""Para (temporariamente) Living Core, Mission Control e Watchdog -> anexa EA ao chart -> sobe tudo de novo."""
import os
import subprocess
import sys
import time

TOOLS = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
PYW = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe"
PY = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\python.exe"
DETACHED = 0x00000008 | 0x08000000


def kill_by_cmdline(patterns):
    ps = (
        "Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'python' } | "
        "ForEach-Object { $_.ProcessId.ToString() + '|' + $_.CommandLine }"
    )
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                         capture_output=True, text=True).stdout
    me = str(os.getpid())
    for line in out.splitlines():
        if "|" not in line:
            continue
        pid, cmd = line.split("|", 1)
        if pid.strip() == me:
            continue
        if any(p in cmd for p in patterns):
            subprocess.run(["taskkill", "/F", "/PID", pid.strip()], capture_output=True)
            print("parado:", pid.strip(), cmd[-60:])


print("1) parando daemons")
kill_by_cmdline(["alien_watchdog.py", "alien_living_core.py", "alien_mission_control.py"])
time.sleep(2)

print("2) fechando MT5")
subprocess.run(["taskkill", "/F", "/IM", "terminal64.exe"], capture_output=True)
time.sleep(4)

print("3) anexando EA")
r = subprocess.run([PY, os.path.join(TOOLS, "attach_ea_to_chart.py")], capture_output=True, text=True)
print(r.stdout, r.stderr)

print("4) aguardando MT5 carregar (60s)")
time.sleep(60)

print("5) subindo daemons")
subprocess.Popen([PYW, os.path.join(TOOLS, "alien_watchdog.py")], creationflags=DETACHED, close_fds=True)
print("watchdog iniciado (ele sobe Telegram + Mission Control)")
