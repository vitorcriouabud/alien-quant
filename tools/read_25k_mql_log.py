import os

mlog = r"C:\Goat_MT5_25K\MQL5\Logs\20261109.log"
if os.path.exists(mlog):
    raw = open(mlog, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
    lines = txt.splitlines()
    print(f"Total MQL5 lines: {len(lines)}")
    for l in lines[-30:]:
        print("  ", l.encode("ascii", errors="replace").decode("ascii"))
else:
    print("MQL5 log not found")
