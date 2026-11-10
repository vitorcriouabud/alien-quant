with open(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines, 1):
    if "xauusd" in line.lower():
        print(f"Line {i}: {line.strip()[:100]}")
