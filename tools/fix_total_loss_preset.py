import os

set_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"

with open(set_path, "rb") as f:
    txt = f.read().decode("utf-16")

lines = txt.splitlines()
new_lines = []

for line in lines:
    if line.startswith("TotalMaxLossMoney="):
        new_lines.append("TotalMaxLossMoney=600.0||600.0||60.000000||6000.000000||N")
    elif line.startswith("DailyMaxLossMoney="):
        new_lines.append("DailyMaxLossMoney=140.0||140.0||14.000000||1400.000000||N")
    elif line.startswith("WeeklyMaxLossMoney="):
        new_lines.append("WeeklyMaxLossMoney=400.0||400.0||40.000000||4000.000000||N")
    else:
        new_lines.append(line)

new_content = "\r\n".join(new_lines) + "\r\n"
with open(set_path, "wb") as f:
    f.write(new_content.encode("utf-16"))

print("Updated TotalMaxLossMoney to 600.0 and DailyMaxLoss to 140.0.")
