import os

ini_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\Config\common.ini"

content = """[Common]
Environment=F008C6283604CDCF1D747DFA55EB0AF34F6765C795636D6FE239209D2BC1210AA6BE9CFEF1BFF8FA1B727CF947DD1E07
Login=27313466
Server=RoboForex-Pro
ProxyEnable=0
ProxyType=0
ProxyAddress=
EnableOpenCL=7
ProxyAuth=
CertInstall=0
NewsEnable=1
Services=4294967295
NewsLanguages=
Source=my.roboforex.com

[Charts]
ProfileLast=Default
MaxBars=100000
PrintColor=0
SaveDeleted=0
TradeHistory=1
TradeLevels=1
TradeLevelsDrag=0
ObsoleteLasttime=1794177010
PreloadCharts=1

[Notification]
Enable=0
Trade=1
TradeMarginCall=0
PushID=dWnYBg5ceeU=

[Trades]
LotsMode=0
LotsLastExt=1000000
LotsDefaultExt=10000
SymbolMode=0
SymbolLast=XAUUSD
SymbolDefault=EURUSD
DeviationMode=0
DeviationDefault=0
DeviationLast=0
StopsMode=0

[Experts]
AllowDllImport=0
Enabled=1
Account=0
Profile=0
Chart=0
Api=0
DisableOpenCL=
WebRequest=0
WebRequestUrl=
"""

with open(ini_path, "w", encoding="utf-16") as f:
    f.write(content)

print("SUCCESS: Clean common.ini written with Enabled=1 and Account=0")
