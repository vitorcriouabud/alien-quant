import os

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.py"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "Get-CimInstance" in line and "ForEach-Object" in line:
        new_lines.append("    ps = '(Get-CimInstance Win32_Process -Filter \"Name=\\'' + image + '\\\'\").CommandLine'\n")
    else:
        new_lines.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("SUCCESS: alien_watchdog.py fixed!")
