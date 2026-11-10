import os

p5k = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\chart01.chr"
raw = open(p5k, "rb").read()
txt = raw.decode("utf-16", errors="ignore")
with open(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\chart01_5k_reference.txt", "w", encoding="utf-8") as f:
    f.write(txt)
print(f"Dumped {len(txt)} chars of chart01.chr")
