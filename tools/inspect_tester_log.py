import glob

logs = glob.glob(r'C:\ALIEN_TEST_MT5\tester\logs\*.log')
latest = max(logs, key=lambda x: x)
with open(latest, 'rb') as f:
    lines = f.read().decode('utf-16le', errors='ignore').splitlines()

print(f"Total lines in log: {len(lines)}")
for line in lines:
    if ("2026.10.29" in line or "2026.11.03" in line) and ("executada" in line or "score=" in line or "V12" in line):
        print(line)
