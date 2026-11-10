import os
import glob
import datetime

for d in [r"C:\Goat_MT5_25K\logs", r"C:\Goat_MT5_25K\MQL5\Logs"]:
    print(f"\n=== DIRECTORY: {d} ===")
    files = glob.glob(os.path.join(d, "*.log"))
    for f in sorted(files, key=os.path.getmtime):
        sz = os.path.getsize(f)
        mt = datetime.datetime.fromtimestamp(os.path.getmtime(f))
        print(f"File: {os.path.basename(f)} | Size: {sz} bytes | Mtime: {mt}")
        raw = open(f, "rb").read()
        txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
        lines = txt.splitlines()
        print(f"Total lines: {len(lines)}")
        for l in lines[-25:]:
            safe_l = l.encode("ascii", errors="replace").decode("ascii")
            print("  ", safe_l)
