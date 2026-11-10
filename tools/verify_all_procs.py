import subprocess

ps = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -match "terminal64|python" } | Select-Object ProcessId, Name, CommandLine'
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
print(out)
