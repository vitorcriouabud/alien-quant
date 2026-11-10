import subprocess

ps = "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | Select-Object ProcessId, CommandLine"
out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
print(out)
