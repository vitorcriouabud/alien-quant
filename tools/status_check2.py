import datetime
import os
import subprocess
import time

T = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"
out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout
for l in out.splitlines():
    if any(k in l.lower() for k in ("terminal64", "python", "metaeditor", "wscript")):
        print(l)
png = T + r"\MQL5\Files\ALIEN_LIVE_CONFLUENCE.png"
print("png mtime:", datetime.datetime.fromtimestamp(os.path.getmtime(png)), "agora:", datetime.datetime.now())
for d in ("logs", r"MQL5\Logs"):
    import glob
    f = max(glob.glob(os.path.join(T, d, "*.log")), key=os.path.getmtime)
    print("--", d, datetime.datetime.fromtimestamp(os.path.getmtime(f)))
    for line in open(f, encoding="utf-16", errors="ignore").read().splitlines()[-6:]:
        print("  ", line[:200])
