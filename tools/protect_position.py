import MetaTrader5 as mt5

ok = mt5.initialize(path=r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe", timeout=5000)
if not ok:
    print("Falha ao inicializar MT5")
    exit(1)

positions = mt5.positions_get(ticket=600015144080)
if not positions:
    print("Posicao 600015144080 nao encontrada (pode ja ter sido fechada).")
    all_pos = mt5.positions_get()
    print("Posicoes restantes:", len(all_pos) if all_pos else 0)
    mt5.shutdown()
    exit(0)

pos = positions[0]
print(f"Gerenciando Ticket {pos.ticket}: SELL {pos.volume} XAUUSD @ {pos.price_open}")
print(f"Preco atual: {pos.price_current} | Lucro flutuante: +${pos.profit:.2f} USD")

# Trava no lucro (Stop Loss garantindo ganho)
# Preco de entrada: 4111.66 | Preco atual: ~4100.10
# Colocamos Stop Loss em 4106.00 (garante lucro de ~$5.66 USD mesmo se o preco subir)
# Take Profit em 4085.00 (busca +$26.66 USD)
novo_sl = 4106.00
novo_tp = 4085.00

request = {
    "action": mt5.TRADE_ACTION_SLTP,
    "position": pos.ticket,
    "symbol": pos.symbol,
    "sl": novo_sl,
    "tp": novo_tp,
}

result = mt5.order_send(request)
if result and result.retcode == mt5.TRADE_RETCODE_DONE:
    print(f"SUCESSO! Stop Loss protegido em {novo_sl} | Take Profit em {novo_tp}")
    print(f"Retcode: {result.retcode} - Lucro garantido no bolso!")
else:
    print(f"Falha ao modificar SL/TP. Codigo: {result.retcode if result else 'Nenhum'}")
    print("Detalhes:", result)

mt5.shutdown()
