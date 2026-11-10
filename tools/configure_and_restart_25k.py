import os
import sys
import time
import subprocess
import datetime

print(f"[{datetime.datetime.now()}] Configuring and restarting Goat 25K Terminal...")

GOAT_25K = r"C:\Goat_MT5_25K"
EXE_25K = os.path.join(GOAT_25K, "terminal64.exe")

# 1. Find PID of C:\Goat_MT5_25K\terminal64.exe and terminate ONLY that one
ps = 'Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "terminal64.exe" -and $_.CommandLine -like "*Goat_MT5_25K*" } | Select-Object -ExpandProperty ProcessId'
pids_out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout.strip()
print(f"Found 25K PIDs: {pids_out}")
if pids_out:
    for pid in pids_out.splitlines():
        pid = pid.strip()
        if pid:
            print(f"Terminating 25K MT5 PID {pid}...")
            subprocess.run(["taskkill", "/F", "/PID", pid], capture_output=True)

time.sleep(3)

# 2. Prepare 25K expert block
expert_block_25k = """<expert>
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

# Load 5K reference chart template
REF_CHR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\chart01_5k_reference.txt"
ref_text = open(REF_CHR, "r", encoding="utf-8").read()

# Strip any existing expert block from reference
idx_exp = ref_text.find("<expert>")
if idx_exp != -1:
    chart_base = ref_text[:idx_exp].strip()
    idx_close = ref_text.find("</chart>")
    close_tag = "</chart>" if idx_close != -1 else ""
    full_25k_chart = chart_base + "\n" + expert_block_25k + "\n" + close_tag + "\n"
else:
    full_25k_chart = ref_text + "\n" + expert_block_25k + "\n</chart>\n"

# Replace line endings to CRLF
full_25k_chart = full_25k_chart.replace("\r\n", "\n").replace("\n", "\r\n")

target_chr_paths = [
    os.path.join(GOAT_25K, "Profiles", "Charts", "Default", "chart01.chr"),
    os.path.join(GOAT_25K, "MQL5", "Profiles", "Charts", "Default", "chart01.chr")
]

for cp in target_chr_paths:
    os.makedirs(os.path.dirname(cp), exist_ok=True)
    with open(cp, "w", encoding="utf-16") as f:
        f.write(full_25k_chart)
    print(f"Written calibrated 25K chart (0.35 lot / $500 stop / $350 target) to {cp}")

# Write order.wnd
for od in [
    os.path.join(GOAT_25K, "Profiles", "Charts", "Default", "order.wnd"),
    os.path.join(GOAT_25K, "MQL5", "Profiles", "Charts", "Default", "order.wnd")
]:
    with open(od, "w", encoding="utf-16") as f:
        f.write("chart01.chr\r\n")
    print(f"Written order.wnd to {od}")

# Write common.ini
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
print(f"Written common.ini with Enabled=1, Account=0 to {common_ini_path}")

# Write startup_25k.ini
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

# 3. Launch 25K Terminal with full credentials
cmd = [
    EXE_25K,
    "/portable",
    f"/config:{startup_ini_path}",
    "/login:436271843",
    r"/password:PROTECTED_PASSWORD",
    "/server:GoatFunded-Server2",
    "/profile:Default"
]
print(f"Launching 25K Terminal: {' '.join(cmd)}")
proc = subprocess.Popen(cmd, creationflags=0x00000008, close_fds=True)
print(f"Launched new 25K MT5 PID: {proc.pid}")

print("Waiting 15 seconds for startup and initialization...")
time.sleep(15)

# 4. Verify logs
tlog = os.path.join(GOAT_25K, "logs", f"{time.strftime('%Y%m%d')}.log")
if os.path.exists(tlog):
    raw = open(tlog, "rb").read()
    txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
    lines = txt.splitlines()
    print(f"\n--- Terminal Log {tlog} (last 15 lines) ---")
    for l in lines[-15:]:
        print("  ", l.encode("ascii", errors="replace").decode("ascii"))

# Check MQL5 Files
files_dir = os.path.join(GOAT_25K, "MQL5", "Files")
print(f"\n--- Files in {files_dir} ---")
for f in os.listdir(files_dir):
    fp = os.path.join(files_dir, f)
    mt = datetime.datetime.fromtimestamp(os.path.getmtime(fp))
    print(f"  {f} ({os.path.getsize(fp)} bytes, {mt})")

print("\nRestart and verification completed.")
