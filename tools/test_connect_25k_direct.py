import MetaTrader5 as mt5

print("Connecting to Goat 25K terminal...")
ok = mt5.initialize(
    path=r"C:\Goat_MT5_25K\terminal64.exe",
    login=436271843,
    password=ros.environ.get("GOAT_25K_PASSWORD", "PROTECTED_PASSWORD"),
    server="GoatFunded-Server2",
    timeout=10000
)
print(f"initialize result: {ok}")
if not ok:
    print(f"Error: {mt5.last_error()}")
else:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print(f"Terminal Path: {term.path} | Connected: {term.connected}")
    if acc:
        print(f"Account: Login={acc.login}, Server={acc.server}, Name={acc.name}, Balance=${acc.balance:,.2f}, Equity=${acc.equity:,.2f}, Leverage=1:{acc.leverage}")
    mt5.shutdown()
