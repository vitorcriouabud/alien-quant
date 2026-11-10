import re

for exp_name, path in [
    ("EXP-018", r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_018_V12_1_VERIFIED\EXP_018_V12_1_VERIFIED.htm"),
    ("EXP-020", r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_020_V12_1_AB\EXP_020_V12_1_AB.htm"),
]:
    print(f"\n=== {exp_name} ===")
    html = open(path, "r", encoding="utf-16le", errors="ignore").read()
    bolds = re.findall(r'<td nowrap colspan="\d+" align="left"><b>(.*?)</b></td>', html)
    if bolds:
        for b in bolds:
            for item in b.split(";"):
                if "=" in item:
                    print(" ", item.strip())
    else:
        # fallback search
        pos = html.find("FixedLot")
        if pos != -1:
            print(html[pos-100:pos+300])
