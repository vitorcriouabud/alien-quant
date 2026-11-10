import os

src_set = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"
dst_set = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"

with open(src_set, "r", encoding="utf-16le") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.startswith("EnforceStrictHTF="):
        new_lines.append("EnforceStrictHTF=false||false||0||true||N\n")
    elif line.startswith("WeeklyMaxLossMoney="):
        new_lines.append("WeeklyMaxLossMoney=200.0||200.0||20.000000||2000.000000||N\n")
    elif line.startswith("SweepReclaimPoints="):
        new_lines.append("SweepReclaimPoints=3.0||3.0||0.300000||30.000000||N\n")
    elif line.startswith("DailyMaxLossMoney="):
        new_lines.append(line)
        new_lines.append("TotalMaxLossMoney=200.0||200.0||20.000000||2000.000000||N\n")
    elif line.startswith("TotalMaxLossMoney="):
        pass
    else:
        new_lines.append(line)

content = "".join(new_lines)

with open(src_set, "w", encoding="utf-16le") as f:
    f.write(content)

with open(dst_set, "w", encoding="utf-16le") as f:
    f.write(content)

print("Updated .set files successfully in both terminal and repository locations.")
