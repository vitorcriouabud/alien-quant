import os

chr_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\chart01.chr"
raw = open(chr_path, "rb").read()
txt = raw.decode("utf-16", errors="ignore")

in_inputs = False
print("=== GOAT 5K CHART01.CHR INPUTS ===")
for line in txt.splitlines():
    if "<inputs>" in line:
        in_inputs = True
        continue
    if "</inputs>" in line:
        in_inputs = False
        break
    if in_inputs:
        print(line)
