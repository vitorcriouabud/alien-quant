import os

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.startswith("MT5_TERMINAL_EXE ="):
        new_lines.append('MT5_TERMINAL_EXE = r"C:\\Program Files\\Goat Funded MT5 Terminal\\terminal64.exe"\n')
    elif line.startswith("MT5_DATA_DIR ="):
        new_lines.append('MT5_DATA_DIR = r"C:\\Users\\notebook\\AppData\\Roaming\\MetaQuotes\\Terminal\\6A8B44BF3BA3300BEB24FFF647C54564"\n')
    elif line.startswith("REAL_LOGIN ="):
        new_lines.append("REAL_LOGIN = 315462944\n")
    elif line.startswith("REAL_SERVER ="):
        new_lines.append('REAL_SERVER = "GoatFunded-Server"\n')
    elif line.startswith("DAILY_TARGET_USD ="):
        new_lines.append("DAILY_TARGET_USD = 60.00\n")
    elif line.startswith("DAILY_MAX_LOSS_USD ="):
        new_lines.append("DAILY_MAX_LOSS_USD = 100.00\n")
    elif line.startswith("TOTAL_MAX_LOSS_USD ="):
        new_lines.append("TOTAL_MAX_LOSS_USD = 250.00\n")
    else:
        new_lines.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("SUCCESS: Updated alien_living_core.py with Goat 5K config!")
