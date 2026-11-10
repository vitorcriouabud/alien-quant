import os

chr_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\chart01.chr"
raw = open(chr_path, "rb").read()
t = raw.decode("utf-16", errors="ignore")
s = t.find("<expert>")
e = t.find("</expert>")
if s != -1 and e != -1:
    print(t[s:e+9])
else:
    print("expert block not found")
