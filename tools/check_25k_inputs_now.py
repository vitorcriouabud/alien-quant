import os

cp = r"C:\Goat_MT5_25K\Profiles\Charts\Default\chart01.chr"
raw = open(cp, "rb").read()
txt = raw.decode("utf-16le", errors="ignore")
s = txt.find("<expert>")
e = txt.find("</expert>")
if s != -1 and e != -1:
    print(txt[s:e+9])
else:
    print("<expert> not found")
