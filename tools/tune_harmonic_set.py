import os

set_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\ALIEN_V12_1_INSTITUTIONAL.set"

with open(set_path, "rb") as f:
    txt = f.read().decode("utf-16")

lines = txt.splitlines()
new_lines = []

for line in lines:
    if line.startswith("SweepOnlyTradeMode="):
        new_lines.append("SweepOnlyTradeMode=false||false||0||true||N")
    elif line.startswith("EnableBreakRetest="):
        new_lines.append("EnableBreakRetest=true||false||0||true||N")
    elif line.startswith("BreakEvenAfterPoints="):
        new_lines.append("BreakEvenAfterPoints=15.0||15.0||1.500000||150.000000||N")
    elif line.startswith("TrailStartPoints="):
        new_lines.append("TrailStartPoints=25.0||25.0||2.500000||250.000000||N")
    elif line.startswith("RunnerMinTrailPoints="):
        new_lines.append("RunnerMinTrailPoints=12.0||12.0||1.200000||120.000000||N")
    elif line.startswith("RunnerLockBufferPts="):
        new_lines.append("RunnerLockBufferPts=3.0||3.0||0.300000||30.000000||N")
    elif line.startswith("SweepReclaimPoints="):
        new_lines.append("SweepReclaimPoints=1.5||1.5||0.150000||15.000000||N")
    elif line.startswith("EnforceStrictHTF="):
        new_lines.append("EnforceStrictHTF=false||false||0||true||N") # Ponderacao suave sem cortar sweeps de reversao legitimos (conforme EXP-010/EXP-014)
    elif line.startswith("DailyMaxLossMoney="):
        new_lines.append("DailyMaxLossMoney=40.0||40.0||4.000000||400.000000||N")
    elif line.startswith("MaxDailyTrades="):
        new_lines.append("MaxDailyTrades=12||12||1||120||N")
    elif line.startswith("LossStreakPauseAfter="):
        new_lines.append("LossStreakPauseAfter=2||2||1||20||N")
    elif line.startswith("LossStreakPauseSeconds="):
        new_lines.append("LossStreakPauseSeconds=3600||3600||1||36000||N")
    elif line.startswith("SweepNewExtremeToRefreshPts="):
        new_lines.append("SweepNewExtremeToRefreshPts=35.0||35.0||3.500000||350.000000||N")
    elif line.startswith("SweepMinimumEntryScore="):
        new_lines.append("SweepMinimumEntryScore=64||64||1||640||N")
    else:
        new_lines.append(line)

new_content = "\r\n".join(new_lines) + "\r\n"
with open(set_path, "wb") as f:
    f.write(new_content.encode("utf-16"))

print(f"Updated {set_path} with harmonic scalp settings.")
