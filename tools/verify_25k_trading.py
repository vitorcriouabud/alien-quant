import MetaTrader5 as mt5

ok = mt5.initialize(
    path=r"C:\Goat_MT5_25K\terminal64.exe",
    login=436271843,
    password=ros.environ.get("GOAT_25K_PASSWORD", "PROTECTED_PASSWORD"),
    server="GoatFunded-Server2"
)
print("=== GOAT 25K STATUS ===")
print(f"Connected: {ok}")
if ok:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print(f"Terminal: {term.name} | Path: {term.path}")
    print(f"TradeAllowed (Algo): {term.trade_allowed} | Connected: {term.connected}")
    print(f"Account: Login={acc.login}, Server={acc.server}, Name={acc.name}, Balance=${acc.balance:,.2f}")
    
    # Check Gold symbols
    all_syms = [s.name for s in mt5.symbols_get() if "XAU" in s.name or "GOLD" in s.name]
    print(f"Gold symbols available: {all_syms}")
    
    # Check tick for XAUUSD.x
    for sym in ["XAUUSD.x", "XAUUSD"]:
        tick = mt5.symbol_info_tick(sym)
        if tick:
            print(f"Tick for {sym}: Bid={tick.bid}, Ask={tick.ask}, Spread={(tick.ask-tick.bid)/0.01:.1f} pts")
        else:
            print(f"No tick for {sym}")
            
    mt5.shutdown()
