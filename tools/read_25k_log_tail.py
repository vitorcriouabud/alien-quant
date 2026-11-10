import os

tlog = r"C:\Goat_MT5_25K\logs\20261109.log"
raw = open(tlog, "rb").read()
txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
lines = txt.splitlines()
print(f"Total lines: {len(lines)}")
for l in lines[-25:]:
    print("  ", l.encode("ascii", errors="replace").decode("ascii"))
