import subprocess, os, shutil

editor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Scripts\Test_Margin.mq5"
dest = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Scripts\Test_Margin.mq5"
shutil.copyfile(src, dest)

log = os.path.join(os.environ["TEMP"], "compile_margin.log")
subprocess.run([editor, f"/compile:{dest}", f"/log:{log}"])
if os.path.exists(log):
    with open(log, "r", encoding="utf-16", errors="ignore") as f:
        print(f.read())
