import MetaTrader5 as mt5

res = mt5.initialize(
    path=r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe",
    login=315462944,
    server="GoatFunded-Server",
    timeout=10000
)
print("Goat 5K result:", res)
if res:
    t = mt5.terminal_info()
    a = mt5.account_info()
    print(f"Path: {t.path}")
    print(f"Connected: {t.connected}")
    print(f"Trade allowed (Algo): {t.trade_allowed}")
    print(f"Login: {a.login}")
    print(f"Server: {a.server}")
    print(f"Balance: {a.balance}")
    print(f"Equity: {a.equity}")
    print(f"Leverage: {a.leverage}")
    
    # Check rates
    rates = mt5.copy_rates_from_pos("XAUUSD.x", mt5.TIMEFRAME_M1, 0, 5)
    print("Rates count:", len(rates) if rates is not None else "None")
    if rates is not None:
        print("Last rate close:", rates[-1]["close"])
        
    mt5.shutdown()
