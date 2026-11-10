import MetaTrader5 as mt5
import datetime

ok = mt5.initialize(path=r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe", timeout=5000)
if not ok:
    print("MT5 offline ou falha de init")
    exit(1)

acc = mt5.account_info()
print(f"Saldo: ${acc.balance:.2f} | Equity: ${acc.equity:.2f} | PnL Flutuante: ${acc.profit:.2f}")

positions = mt5.positions_get()
print(f"Posicoes abertas: {len(positions) if positions else 0}")
for p in (positions or []):
    side = "BUY" if p.type == 0 else "SELL"
    print(f"Ticket {p.ticket}: {p.symbol} {side} {p.volume} @ {p.price_open} -> Atual {p.price_current} | SL {p.sl} | TP {p.tp} | Lucro: ${p.profit:.2f}")

tick = mt5.symbol_info_tick("XAUUSD")
if tick:
    print(f"XAUUSD BID: {tick.bid} | ASK: {tick.ask}")

now = datetime.datetime.now()
deals = mt5.history_deals_get(now - datetime.timedelta(hours=6), now + datetime.timedelta(hours=6))
print(f"Deals executados nas ultimas 6h: {len(deals) if deals else 0}")
for d in (deals or [])[-6:]:
    print(f"Deal {d.ticket} (pos {d.position_id}): {d.symbol} {d.volume} @ {d.price} | Lucro: ${d.profit:.2f} USD")

mt5.shutdown()
