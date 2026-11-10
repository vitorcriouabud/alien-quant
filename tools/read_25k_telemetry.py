import os
import glob

rep_files = glob.glob(r"C:\Goat_MT5_25K\MQL5\Files\ALIEN_V1089_REPORT_*.txt")
if rep_files:
    latest = max(rep_files, key=os.path.getmtime)
    print(f"Reading: {latest}")
    raw = open(latest, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
    for line in txt.splitlines()[:35]:
        safe = line.encode("ascii", errors="replace").decode("ascii")
        print("  ", safe)
