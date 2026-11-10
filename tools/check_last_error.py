import os
import MetaTrader5 as mt5

res = mt5.initialize(
    path=r"C:\Goat_MT5_25K\terminal64.exe",
    login=436271843,
    password=os.environ.get("GOAT_25K_PASSWORD", "PROTECTED_PASSWORD"),
    server="GoatFunded-Server2",
    timeout=10000
)
print("Result:", res)
print("Last error:", mt5.last_error())
