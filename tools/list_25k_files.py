import os
import glob
import datetime

files = glob.glob(r"C:\Goat_MT5_25K\MQL5\Files\*")
for f in sorted(files, key=os.path.getmtime):
    sz = os.path.getsize(f)
    mt = datetime.datetime.fromtimestamp(os.path.getmtime(f))
    print(f"{os.path.basename(f)}: size={sz}, mtime={mt}")
