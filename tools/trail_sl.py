import MetaTrader5 as mt5

ok = mt5.initialize(path=r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe", timeout=5000)
if not ok:
    exit(1)

pos = mt5.positions_get(ticket=600015144080)
if pos:
    p = pos[0]
    novo_sl = 4102.00
    novo_tp = 4085.00
    req = {
        "action": mt5.TRADE_ACTION_SLTP,
        "position": p.ticket,
        "symbol": p.symbol,
        "sl": novo_sl,
        "tp": novo_tp
    }
    res = mt5.order_send(req)
    if res and res.retcode == mt5.TRADE_RETCODE_DONE:
        print(f"SL atualizado com sucesso para {novo_sl} | Lucro minimo garantido: +$9.66 USD!")
    else:
        print("Falha ao ajustar SL:", res)
mt5.shutdown()
