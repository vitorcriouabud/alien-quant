import os
import MetaTrader5 as mt5

print("Connecting to 25K Portable MT5 via Python API...")
ok = mt5.initialize(
    path=r"C:\Goat_MT5_25K\terminal64.exe",
    portable=True
)
print(f"mt5.initialize(portable=True) -> {ok}")
if not ok:
    print(f"Error: {mt5.last_error()}")
else:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print(f"Terminal Connected: {term.connected} | TradeAllowed: {term.trade_allowed} | Name: {term.name} | Path: {term.path}")
    if acc:
        print(f"Account: Login={acc.login}, Server={acc.server}, Name={acc.name}, Balance=${acc.balance:,.2f}, Equity=${acc.equity:,.2f}")
    else:
        print("No account info (not logged in yet?)")
        # Try explicit login
        print("Attempting explicit login via API...")
        login_res = mt5.login(436271843, password=os.environ.get("GOAT_25K_PASSWORD", "PROTECTED_PASSWORD"), server="GoatFunded-Server2")
        print(f"mt5.login() -> {login_res}")
        if login_res:
            acc = mt5.account_info()
            print(f"After login: Login={acc.login}, Server={acc.server}, Balance=${acc.balance:,.2f}")
        else:
            print(f"Login failed: {mt5.last_error()}")
    mt5.shutdown()
