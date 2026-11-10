mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

with open(mq5_path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

print("=== CHoCH / BOS SETUP SELECTION (lines 2150 to 2225) ===")
for i in range(2150, 2225):
    if i <= len(lines):
        print(f"{i}: {lines[i-1]}", end="")

print("\n=== NearestHTFZone and FVG (lines 1820 to 1865) ===")
for i in range(1820, 1865):
    if i <= len(lines):
        print(f"{i}: {lines[i-1]}", end="")
