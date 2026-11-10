import os

set_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"

with open(set_path, "rb") as f:
    txt = f.read().decode("utf-16")

lines = txt.splitlines()
new_lines = []

for line in lines:
    if line.startswith("SweepOnlyTradeMode="):
        new_lines.append("SweepOnlyTradeMode=true||false||0||true||N")
    elif line.startswith("BreakEvenAfterPoints="):
        new_lines.append("BreakEvenAfterPoints=60.0||60.0||6.000000||600.000000||N")
    elif line.startswith("TrailStartPoints="):
        new_lines.append("TrailStartPoints=90.0||90.0||9.000000||900.000000||N")
    elif line.startswith("RunnerMinTrailPoints="):
        new_lines.append("RunnerMinTrailPoints=20.0||20.0||2.000000||200.000000||N")
    elif line.startswith("RunnerLockBufferPts="):
        new_lines.append("RunnerLockBufferPts=5.0||5.0||0.500000||50.000000||N")
    elif line.startswith("DailyMaxLossMoney="):
        new_lines.append("DailyMaxLossMoney=40.0||40.0||4.000000||400.000000||N")
    elif line.startswith("MaxDailyTrades="):
        new_lines.append("MaxDailyTrades=10||10||1||100||N")
    elif line.startswith("EnforceStrictHTF="):
        new_lines.append("EnforceStrictHTF=false||false||0||true||N")
    elif line.startswith("SweepNewExtremeToRefreshPts="):
        new_lines.append("SweepNewExtremeToRefreshPts=35.0||35.0||3.500000||350.000000||N")
    elif line.startswith("LossStreakPauseAfter="):
        new_lines.append("LossStreakPauseAfter=2||2||1||20||N")
    elif line.startswith("LossStreakPauseSeconds="):
        new_lines.append("LossStreakPauseSeconds=3600||3600||1||36000||N")
    elif line.startswith("SameDirectionStopCooldownSeconds="):
        new_lines.append("SameDirectionStopCooldownSeconds=1800||1800||1||18000||N")
    else:
        new_lines.append(line)

new_content = "\r\n".join(new_lines) + "\r\n"
with open(set_path, "wb") as f:
    f.write(new_content.encode("utf-16"))

print("Updated .set for In-Sample Walk-Forward Test.")
