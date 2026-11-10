import re

with open(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_014_GOAT_10K\EXP_014_GOAT_10K.htm", "r", encoding="utf-16", errors="ignore") as f:
    text = f.read()

pattern = re.compile(r'<td nowrap colspan="3">([^<]+):</td>\s*<td[^>]*><b>(.*?)</b></td>')
for k, v in pattern.findall(text):
    print(f"{k.strip()}: {v.strip()}")
