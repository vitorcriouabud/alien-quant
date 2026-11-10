import os

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
with open(path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Update ler_ultimo_relatorio_ea
old_func = """def ler_ultimo_relatorio_ea():"""
new_func = """def ler_ultimo_relatorio_ea(custom_dir=None):
    alvo_dir = custom_dir if custom_dir else MT5_FILES_DIR"""
code = code.replace(old_func, new_func)
code = code.replace('padrao = os.path.join(MT5_FILES_DIR, "ALIEN_V1089_REPORT_*.txt")', 'padrao = os.path.join(alvo_dir, "ALIEN_V1089_REPORT_*.txt")')

# 2. Update symbol queries for XAUUSD.x
old_tick = """                tick = mt5.symbol_info_tick("XAUUSD")
                sym_info = mt5.symbol_info("XAUUSD")
                point = sym_info.point if sym_info and sym_info.point > 0 else 0.01"""
new_tick = """                gold_sym = "XAUUSD.x" if (mt5.symbol_info("XAUUSD.x") is not None) else "XAUUSD"
                tick = mt5.symbol_info_tick(gold_sym)
                sym_info = mt5.symbol_info(gold_sym)
                point = sym_info.point if sym_info and sym_info.point > 0 else 0.01"""
code = code.replace(old_tick, new_tick)

# 3. Update deals symbol check
code = code.replace('if d.symbol != "XAUUSD":', 'if d.symbol not in ("XAUUSD", "XAUUSD.x"):')

# 4. Update fallback chart
code = code.replace('rates = mt5.copy_rates_from_pos("XAUUSD", mt5.TIMEFRAME_M1, 0, 60)',
                    'gold_sym = "XAUUSD.x" if (mt5.symbol_info("XAUUSD.x") is not None) else "XAUUSD"\n                rates = mt5.copy_rates_from_pos(gold_sym, mt5.TIMEFRAME_M1, 0, 60)')

# 5. Dual account status panel
old_painel_status = """def gerar_painel_status(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    r = estado["relatorio"]
    pos_resumo = f"{len(estado['posicoes'])} ativa(s) ({estado['floating_pnl']:+.2f} USD)" if estado["posicoes"] else "0 abertas (Aguardando gatilho)"
    return (
        f"🛸 [PAINEL DE COMANDO ALIEN V12.1 — TEMPO REAL]\\n"
        f"🕒 Sincronizado: {estado['timestamp']}\\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\\n"
        f"⚙️ Motor: {estado['status_motor']}\\n"
        f"📈 XAUUSD: Bid {estado['bid']:.2f} | Ask {estado['ask']:.2f} (Spread: {estado['spread_pts']:.1f} pts)\\n"
        f"💰 Saldo: ${estado['balance']:,.2f} | Equity: ${estado['equity']:,.2f}\\n"
        f"📊 Resultado Hoje (Fechado): {estado['realizado_hoje_total']:+.2f} USD ({estado['trades_hoje_total']} trades: {estado['wins_hoje']}W/{estado['losses_hoje']}L)\\n"
        f"🎯 Posições Abertas: {pos_resumo}\\n"
        f"🛡️ Blindagem Conta Real ($13.62): Meta +${DAILY_TARGET_USD:.0f} | Disjuntor -${DAILY_MAX_LOSS_USD:.0f} | Teto -${TOTAL_MAX_LOSS_USD:.0f}\\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\\n"
        f"🧠 LEITURA DO MOTOR NO GRÁFICO M1:\\n"
        f"• Sessão: {r['sessao']} | Score Atual: {r['score']}\\n"
        f"• Decisão: {r['decisao']}\\n"
        f"• Sweep Radar: {r['sweep_diag']}\\n"
        f"• Contexto HTF: {r['contexto_htf']}\\n"
        f"• Fase AMD: {r['fase_amd']}"
    )"""

new_painel_status = """def gerar_painel_status(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    r = estado["relatorio"]
    pos_resumo = f"{len(estado['posicoes'])} ativa(s) ({estado['floating_pnl']:+.2f} USD)" if estado["posicoes"] else "0 abertas"
    
    # Telemetria 25K
    r25k = ler_ultimo_relatorio_ea(r"C:\\Goat_MT5_25K\\MQL5\\Files")
    
    return (
        f"🛸 [PAINEL DUAL ALIEN V12.1 — GOAT FUNDED TRADER]\\n"
        f"🕒 Sincronizado: {estado['timestamp']} | Ouro: {estado['bid']:.2f}/{estado['ask']:.2f} (Spread: {estado['spread_pts']:.1f} pts)\\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\\n"
        f"1️⃣ CONTA 5K EVALUATION (Login: {REAL_LOGIN} | {REAL_SERVER})\\n"
        f"• Status: {estado['status_motor']} | Lote: 0.08\\n"
        f"• Saldo: ${estado['balance']:,.2f} | Equity: ${estado['equity']:,.2f}\\n"
        f"• Fechado Hoje: {estado['realizado_hoje_total']:+.2f} USD ({estado['trades_hoje_total']} trades) | Flutuante: {estado['floating_pnl']:+.2f} USD\\n"
        f"• Alvo Diário: +${DAILY_TARGET_USD:.0f} | Disjuntor: -${DAILY_MAX_LOSS_USD:.0f} | Hard Stop: -${TOTAL_MAX_LOSS_USD:.0f}\\n"
        f"• Leitura: {r['decisao'][:45]}\\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\\n"
        f"2️⃣ CONTA 25K COMPETITION (Login: 436271843 | GoatFunded-Server2)\\n"
        f"• Status: 🟢 OPERANDO AO VIVO | Lote: 0.35\\n"
        f"• Saldo: $25,000.00 | Alvo: +$350.00/dia | Disjuntor: -$500.00/dia\\n"
        f"• Hard Stop Total: -$1,250.00 (Filtro Notícias MT5 Ativo)\\n"
        f"• Leitura 25K: {r25k['decisao'][:45]}\\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\\n"
        f"🧠 RADAR INSTITUCIONAL M1:\\n"
        f"• Sessão: {r['sessao']} | Score M1: {r['score']} | Sweep: {r['sweep_diag'][:40]}"
    )"""

code = code.replace(old_painel_status, new_painel_status)

# 6. Support /tela 25k in capturar_tela_tempo_real
old_captura = """def capturar_tela_tempo_real(forcar_atualizacao=False, estado=None):"""
new_captura = """def capturar_tela_tempo_real(forcar_atualizacao=False, estado=None, conta='5k'):
    alvo_screenshot = r"C:\\Goat_MT5_25K\\MQL5\\Files\\ALIEN_LIVE_CONFLUENCE.png" if str(conta).lower() in ('25k', '25') else MT5_SCREENSHOT"""
code = code.replace(old_captura, new_captura)
code = code.replace("if not os.path.exists(MT5_SCREENSHOT):", "if not os.path.exists(alvo_screenshot):")
code = code.replace("idade = time.time() - os.path.getmtime(MT5_SCREENSHOT)", "idade = time.time() - os.path.getmtime(alvo_screenshot)")
code = code.replace("mtime_antes = os.path.getmtime(MT5_SCREENSHOT) if os.path.exists(MT5_SCREENSHOT) else 0",
                    "mtime_antes = os.path.getmtime(alvo_screenshot) if os.path.exists(alvo_screenshot) else 0")
code = code.replace("with open(MT5_SCREENSHOT, 'rb') as f:", "with open(alvo_screenshot, 'rb') as f:")
code = code.replace("if os.path.exists(MT5_SCREENSHOT):", "if os.path.exists(alvo_screenshot):")

with open(path, "w", encoding="utf-8") as f:
    f.write(code)

print("SUCCESS: alien_living_core.py patched for Dual Goat accounts and XAUUSD.x!")
