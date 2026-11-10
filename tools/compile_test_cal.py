import subprocess
import shutil
import os

editor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Scripts\Test_Calendar.mq5"
dest = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Scripts\Test_Calendar.mq5"
os.makedirs(os.path.dirname(dest), exist_ok=True)
shutil.copyfile(src, dest)

log = os.path.join(os.environ["TEMP"], "compile_cal.log")
cmd = [editor, f"/compile:{dest}", f"/log:{log}"]
res = subprocess.run(cmd, capture_output=True, text=True)

if os.path.exists(log):
    with open(log, "r", encoding="utf-16", errors="ignore") as f:
        print(f.read())
else:
    print("Log not found")
