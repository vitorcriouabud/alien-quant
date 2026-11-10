mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

with open(mq5_path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

print("=== EnableHighWaterMarkGuard (search) ===")
for idx, line in enumerate(lines, 1):
    if "HighWaterMark" in line:
        start = max(1, idx - 2)
        end = min(len(lines), idx + 6)
        print(f"--- Line {idx} ---")
        for i in range(start, end):
            print(f"{i}: {lines[i-1]}", end="")
