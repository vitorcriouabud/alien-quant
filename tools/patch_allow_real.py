import os

mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

with open(mq5_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

inserted = False
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if 'input double DailyProfitTargetMoney' in line and not inserted:
        # insert AllowLiveRealTrading before DailyProfitTargetMoney
        new_lines.insert(-1, 'input bool   AllowLiveRealTrading     = true;   // Permissao explicita para operacao em Conta Real\n')
        inserted = True

if inserted:
    with open(mq5_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print("SUCCESS: AllowLiveRealTrading inserted successfully.")
else:
    print("ERROR: insertion anchor not found.")
