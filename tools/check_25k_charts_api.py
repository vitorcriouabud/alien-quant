import os
import MetaTrader5 as mt5

ok = mt5.initialize(
    path=r"C:\Goat_MT5_25K\terminal64.exe",
    login=436271843,
    password=os.environ.get("GOAT_25K_PASSWORD", "PROTECTED_PASSWORD"),
    server="GoatFunded-Server2",
    timeout=5000
)
print(f"initialize result: {ok}")
if ok:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print(f"Path: {term.path} | Connected: {term.connected} | Algo: {term.trade_allowed}")
    print(f"Login: {acc.login} | Server: {acc.server} | Balance: ${acc.balance:,.2f}")
    
    # Check rates on XAUUSD.x M1
    rates = mt5.copy_rates_from_pos("XAUUSD.x", mt5.TIMEFRAME_M1, 0, 5)
    if rates is not None:
        print(f"Successfully retrieved {len(rates)} M1 bars for XAUUSD.x! Latest close={rates[-1]['close']}")
    else:
        print("Failed to get rates")
        
    mt5.shutdown()
