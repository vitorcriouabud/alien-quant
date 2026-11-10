import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"
html = open(path, "r", encoding="utf-16le", errors="ignore").read()

bolds = re.findall(r'<td nowrap colspan="10" align="left"><b>(.*?)</b></td>', html)
for b in bolds:
    print(b)
