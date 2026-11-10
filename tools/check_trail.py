import os

src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_SCALPER.mq5"
with open(src, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

idx = text.find("void CheckTrailAndBE(")
if idx != -1:
    print(text[idx:idx+1500])
else:
    idx = text.find("UseAdaptiveRunner")
    print(text[idx-200:idx+600])
