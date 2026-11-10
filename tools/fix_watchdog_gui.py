import os

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.py"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

target = 'start([MT5_EXE, f"/config:{MT5_INI}"])'
replacement = 'subprocess.Popen([MT5_EXE], close_fds=True)'

if target in text:
    text = text.replace(target, replacement)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("SUCCESS: Watchdog will launch MT5 normally without NO_WINDOW.")
else:
    print("ERROR: Target not found.")
