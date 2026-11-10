import MetaTrader5 as mt5
import inspect

print("inspect signature:", inspect.signature(mt5.initialize))
res = mt5.initialize(timeout=3000)
print("mt5.initialize() without path:", res)
if res:
    term = mt5.terminal_info()
    acc = mt5.account_info()
    print("Default terminal path:", term.path, "login:", acc.login if acc else "none")
    mt5.shutdown()
