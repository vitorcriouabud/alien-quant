import datetime
import glob
import os
import subprocess

T = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"
WD = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.log"

print("== watchdog log ==")
print(open(WD, encoding="utf-8").read()[-700:] if os.path.exists(WD) else "sem log")

ps_cmd = (
    "Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'python|terminal64' } | "
    "ForEach-Object { $_.ProcessId.ToString() + ' ' + $_.Name + ' ' + $_.CommandLine }"
)
print("== processos ==")
print(subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd],
                     capture_output=True, text=True).stdout)

print("== log EA ==")
l = max(glob.glob(T + r"\MQL5\Logs\*.log"), key=os.path.getmtime)
print(datetime.datetime.fromtimestamp(os.path.getmtime(l)), "agora", datetime.datetime.now())
for line in open(l, encoding="utf-16", errors="ignore").read().splitlines()[-6:]:
    print(line[:210])
png = T + r"\MQL5\Files\ALIEN_LIVE_CONFLUENCE.png"
print("idade screenshot (s):", int(datetime.datetime.now().timestamp() - os.path.getmtime(png)))
