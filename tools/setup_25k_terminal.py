import os
import shutil
import hashlib

print("Starting setup of Goat 25K MT5 terminal...")

GOAT_25K = r"C:\Goat_MT5_25K"
SOURCE_EX5 = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
DEST_EX5 = os.path.join(GOAT_25K, "MQL5", "Experts", "ALIEN_V12_1_INSTITUTIONAL.ex5")

# 1. Copy EX5
shutil.copy2(SOURCE_EX5, DEST_EX5)
print(f"Copied fresh EX5 to {DEST_EX5} (hash: {hashlib.sha256(open(DEST_EX5, 'rb').read()).hexdigest()[:12]})")

# 2. Build 25K chart content based on 5K reference
REF_CHR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\chart01_5k_reference.txt"
ref_text = open(REF_CHR, "r", encoding="utf-8").read()

# Replace expert block inputs
old_expert = """<expert>
name=ALIEN_V12_1_INSTITUTIONAL
path=Experts\\ALIEN_V12_1_INSTITUTIONAL.ex5
expertmode=5
DailyProfitTargetMoney=60.0
StopOnDailyProfitTarget=true
EnableHardCircuitBreaker=true
DailyMaxLossMoney=100.0
TotalMaxLossMoney=250.0
WeeklyMaxLossMoney=200.0
MaxDailyTrades=10
TradeLondonAndNYOnly=true
EnableNewsFilter=true
FixedLot=0.08
MaxAdaptiveLot=0.12
MaxAdaptiveStopRiskMoney=35.0
MaxRiskPercentEquity=0.70
RiskStopMoney=30.0
MaxFloatingLossMoney=25.0
DailyEquityLossPct=2.0
AllowLiveRealTrading=true
ExpertMagic=802092
</expert>"""

new_expert = """<expert>
name=ALIEN_V12_1_INSTITUTIONAL
path=Experts\\ALIEN_V12_1_INSTITUTIONAL.ex5
expertmode=5
DailyProfitTargetMoney=350.0
StopOnDailyProfitTarget=true
EnableHardCircuitBreaker=true
DailyMaxLossMoney=500.0
TotalMaxLossMoney=1250.0
WeeklyMaxLossMoney=1000.0
MaxDailyTrades=12
TradeLondonAndNYOnly=true
EnableNewsFilter=true
FixedLot=0.35
MaxAdaptiveLot=0.45
MaxAdaptiveStopRiskMoney=120.0
MaxRiskPercentEquity=0.70
RiskStopMoney=90.0
MaxFloatingLossMoney=80.0
DailyEquityLossPct=2.0
AllowLiveRealTrading=true
ExpertMagic=802095
</expert>"""

chart_content_25k = ref_text.replace(old_expert, new_expert)

# Write to both profile locations in UTF-16LE with BOM
target_chr_paths = [
    os.path.join(GOAT_25K, "Profiles", "Charts", "Default", "chart01.chr"),
    os.path.join(GOAT_25K, "MQL5", "Profiles", "Charts", "Default", "chart01.chr")
]

for cp in target_chr_paths:
    os.makedirs(os.path.dirname(cp), exist_ok=True)
    with open(cp, "w", encoding="utf-16") as f:
        f.write(chart_content_25k)
    print(f"Written 25K chart to {cp}")

# Write order.wnd to only load chart01.chr
order_wnd_content = "chart01.chr\r\n"
for od in [
    os.path.join(GOAT_25K, "Profiles", "Charts", "Default", "order.wnd"),
    os.path.join(GOAT_25K, "MQL5", "Profiles", "Charts", "Default", "order.wnd")
]:
    with open(od, "w", encoding="utf-16") as f:
        f.write(order_wnd_content)
    print(f"Written clean order.wnd to {od}")

# 3. Write common.ini
common_ini_path = os.path.join(GOAT_25K, "Config", "common.ini")
common_ini_content = """[Common]
Login=436271843
Server=GoatFunded-Server2
ProxyEnable=0
ProxyType=0
ProxyAddress=
EnableOpenCL=7
ProxyAuth=
CertInstall=0
NewsEnable=1
Services=4294967295
NewsLanguages=

[Charts]
ProfileLast=Default
MaxBars=100000
PrintColor=0
SaveDeleted=0
TradeHistory=1
TradeLevels=1
TradeLevelsDrag=0
PreloadCharts=1

[Experts]
AllowDllImport=1
Enabled=1
Account=0
Profile=0
Chart=0
Api=0
DisableOpenCL=
WebRequest=0
WebRequestUrl=
"""

with open(common_ini_path, "w", encoding="utf-16") as f:
    f.write(common_ini_content)
print(f"Written clean common.ini to {common_ini_path}")

# 4. Write startup_25k.ini
startup_ini_path = os.path.join(GOAT_25K, "startup_25k.ini")
startup_ini_content = """[Common]
Login=436271843
Password=PROTECTED_PASSWORD
Server=GoatFunded-Server2
EnableOpenCL=7
NewsEnable=1

[Experts]
AllowDllImport=1
Enabled=1
Account=0
Profile=0
Chart=0

[Charts]
ProfileLast=Default
"""

with open(startup_ini_path, "w", encoding="utf-16") as f:
    f.write(startup_ini_content)
print(f"Written startup_25k.ini to {startup_ini_path}")

print("25K Terminal setup complete!")
