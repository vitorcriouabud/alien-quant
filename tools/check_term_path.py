import subprocess

ps = "Get-Process | Where-Object { $_.ProcessName -like '*terminal64*' } | Select-Object Id, Path"
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
print(out)
