import subprocess
import os

metaeditor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
source = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_2_FREEDOM.mq5"
log_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\compile_v11_2.log"

cmd = [metaeditor, f"/compile:{source}", f"/log:{log_path}"]
print("Running command:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
print("Return code:", res.returncode)

if os.path.exists(log_path):
    for enc in ["utf-16", "utf-8", "cp1252"]:
        try:
            with open(log_path, "r", encoding=enc) as f:
                content = f.read()
                if len(content) > 10:
                    print("Log content:\n", content)
                    break
        except Exception:
            pass

ex5 = source.replace(".mq5", ".ex5")
print("EX5 exists?", os.path.exists(ex5))
if os.path.exists(ex5):
    print(f"EX5 size: {os.path.getsize(ex5)} bytes")
