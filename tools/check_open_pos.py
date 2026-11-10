import MetaTrader5 as mt5

ok = mt5.initialize(path=r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe", timeout=5000)
if not ok:
    print("Falha ao inicializar MT5")
    exit(1)

positions = mt5.positions_get()
print(f"Total posicoes abertas: {len(positions) if positions else 0}")
for p in (positions or []):
    tipo = "BUY" if p.type == 0 else "SELL"
    print(f"TICKET: {p.ticket}")
    print(f"SIMBOLO: {p.symbol}")
    print(f"TIPO: {tipo}")
    print(f"LOTE: {p.volume}")
    print(f"PRECO ABERTURA: {p.price_open}")
    print(f"PRECO ATUAL: {p.price_current}")
    print(f"SL ATUAL: {p.sl}")
    print(f"TP ATUAL: {p.tp}")
    print(f"LUCRO FLUTUANTE: ${p.profit:.2f} USD")
    print(f"MAGIC NUMBER: {p.magic}")
    print("------------------------------------------")

tick = mt5.symbol_info_tick("XAUUSD")
if tick:
    print(f"XAUUSD BID: {tick.bid} | ASK: {tick.ask} | SPREAD: {tick.ask - tick.bid:.2f}")

mt5.shutdown()
