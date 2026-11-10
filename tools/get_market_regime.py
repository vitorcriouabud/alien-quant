import MetaTrader5 as mt5
from datetime import datetime

r = mt5.initialize(path=r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe")
if r:
    symbols = [s.name for s in mt5.symbols_get() if "XAU" in s.name or "GOLD" in s.name]
    print(f"Available Gold symbols: {symbols}")
    sym = "XAUUSD.x" if "XAUUSD.x" in symbols else ("XAUUSD" if "XAUUSD" in symbols else symbols[0])
    
    # Try copy rates
    rates = mt5.copy_rates_range(sym, mt5.TIMEFRAME_D1, datetime(2026, 10, 1), datetime(2026, 11, 10))
    if rates is None or len(rates) == 0:
        rates = mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_D1, 0, 30)
    
    if rates is not None:
        print(f"\nDaily bars for {sym} ({len(rates)} bars):")
        for bar in rates:
            dt = datetime.fromtimestamp(bar['time'])
            rng = bar['high'] - bar['low']
            chg = bar['close'] - bar['open']
            print(f"{dt.strftime('%Y-%m-%d (%a)')}: Open={bar['open']:.2f}, High={bar['high']:.2f}, Low={bar['low']:.2f}, Close={bar['close']:.2f}, Range={rng:5.2f}, Chg={chg:+6.2f}")
    else:
        print(f"Failed to fetch rates for {sym}, err={mt5.last_error()}")
    mt5.shutdown()
else:
    print("MT5 init failed:", mt5.last_error())
