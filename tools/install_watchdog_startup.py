import os

startup = os.path.join(os.environ["APPDATA"], r"Microsoft\Windows\Start Menu\Programs\Startup")
vbs = os.path.join(startup, "ALIEN_WATCHDOG.vbs")
py = r"C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe"
script = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.py"
content = (
    'Set sh = CreateObject("WScript.Shell")\r\n'
    f'sh.Run """{py}"" ""{script}""", 0, False\r\n'
)
with open(vbs, "w") as f:
    f.write(content)
print(vbs)
print(content)
