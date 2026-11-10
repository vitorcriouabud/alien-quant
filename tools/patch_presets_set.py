import os

set_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"

with open(set_path, "rb") as f:
    txt = f.read().decode("utf-16")

lines = txt.splitlines()
new_lines = []

for line in lines:
    if line.startswith("DailyMaxLossMoney="):
        new_lines.append("DailyMaxLossMoney=40.0||40.0||4.000000||400.000000||N")
    elif line.startswith("MaxDailyTrades="):
        new_lines.append("MaxDailyTrades=6||6||1||60||N")
    elif line.startswith("EnforceStrictHTF="):
        new_lines.append("EnforceStrictHTF=true||false||0||true||N")
    elif line.startswith("SweepMinimumEntryScore="):
        new_lines.append("SweepMinimumEntryScore=70||70||1||700||N")
    elif line.startswith("SweepNewExtremeToRefreshPts="):
        new_lines.append("SweepNewExtremeToRefreshPts=35.0||35.0||3.500000||350.000000||N")
    elif line.startswith("LossStreakPauseAfter="):
        new_lines.append("LossStreakPauseAfter=2||2||1||20||N")
    elif line.startswith("LossStreakPauseSeconds="):
        new_lines.append("LossStreakPauseSeconds=3600||3600||1||36000||N")
        new_lines.append("SameDirectionStopCooldownSeconds=1800||1800||1||18000||N")
    else:
        new_lines.append(line)

new_content = "\r\n".join(new_lines) + "\r\n"
with open(set_path, "wb") as f:
    f.write(new_content.encode("utf-16"))

print(f"Updated {set_path} successfully. Total lines: {len(new_lines)}")
