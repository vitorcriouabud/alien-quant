import os
import sys

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
i = 0
n = len(lines)

while i < n:
    line = lines[i]

    # 1. ler_ultimo_relatorio_ea info dict
    if '"texto_bruto": ""' in line and i > 5 and '"noticias": "LIVRE"' in lines[i-1]:
        new_lines.append('        "balance": 0.0,\n')
        new_lines.append('        "equity": 0.0,\n')
        new_lines.append('        "margin_free": 0.0,\n')
        new_lines.append('        "realizado_hoje": 0.0,\n')
        new_lines.append(line)
        i += 1
        continue

    # 2. ler_ultimo_relatorio_ea line parsing
    if 'elif l.startswith("ASIA max"):' in line:
        new_lines.append(line)
        new_lines.append(lines[i+1])
        new_lines.append('            elif l.startswith("Saldo "):\n')
        new_lines.append('                import re\n')
        new_lines.append('                m_fin = re.search(r"Saldo\\s+([\\d\\.]+)\\s+\\|\\s+Equity\\s+([\\d\\.]+)\\s+\\|\\s+Livre\\s+([\\d\\.]+)\\s+\\|\\s+Hoje realizado\\s+([+\\-]?[\\d\\.]+)", l)\n')
        new_lines.append('                if m_fin:\n')
        new_lines.append('                    info["balance"] = float(m_fin.group(1))\n')
        new_lines.append('                    info["equity"] = float(m_fin.group(2))\n')
        new_lines.append('                    info["margin_free"] = float(m_fin.group(3))\n')
        new_lines.append('                    info["realizado_hoje"] = float(m_fin.group(4))\n')
        i += 2
        continue

    # 3. capturar_tela_tempo_real
    if line.startswith("def capturar_tela_tempo_real("):
        # Read until return enriquecer_screenshot_hud
        captura_block = [
            "def capturar_tela_tempo_real(forcar_atualizacao=False, estado=None, conta='5k'):\n",
            "    is_25k = str(conta).lower() in ('25k', '25')\n",
            '    alvo_screenshot = r"C:\\Goat_MT5_25K\\MQL5\\Files\\ALIEN_LIVE_CONFLUENCE.png" if is_25k else MT5_SCREENSHOT\n',
            '    force_flag = r"C:\\Goat_MT5_25K\\MQL5\\Files\\ALIEN_FORCE_SCREENSHOT.flag" if is_25k else FORCE_SHOT_FLAG_FILE\n',
            '    """Obtém a imagem mais fresca do gráfico MT5 (forçando ChartScreenShot se solicitado) com HUD ao vivo."""\n',
            "    if estado is None:\n",
            "        estado = obter_estado_mt5()\n",
            "\n",
            "    try:\n",
            "        precisa_forcar = forcar_atualizacao\n",
            "        if not os.path.exists(alvo_screenshot):\n",
            "            precisa_forcar = True\n",
            "        else:\n",
            "            idade = time.time() - os.path.getmtime(alvo_screenshot)\n",
            "            if idade > 6.0:\n",
            "                precisa_forcar = True\n",
            "\n",
            "        if precisa_forcar:\n",
            "            mtime_antes = os.path.getmtime(alvo_screenshot) if os.path.exists(alvo_screenshot) else 0\n",
            "            try:\n",
            '                with open(force_flag, "w", encoding="utf-8") as f:\n',
            "                    f.write(str(time.time()))\n",
            "            except Exception:\n",
            "                pass\n",
            "            for _ in range(10):\n",
            "                time.sleep(0.15)\n",
            "                if not os.path.exists(force_flag):\n",
            "                    break\n",
            "                if os.path.exists(alvo_screenshot) and os.path.getmtime(alvo_screenshot) > mtime_antes:\n",
            "                    break\n",
            "    except Exception:\n",
            "        pass\n",
            "\n",
            "    raw_bytes = None\n",
            "    if os.path.exists(alvo_screenshot):\n",
            "        try:\n",
            '            with open(alvo_screenshot, "rb") as f:\n',
            "                raw_bytes = f.read()\n",
            "        except Exception:\n",
            "            raw_bytes = None\n",
            "\n",
            "    if not raw_bytes:\n",
            "        raw_bytes = gerar_grafico_fallback_mt5(estado)\n",
            "\n",
            "    return enriquecer_screenshot_hud(raw_bytes, estado)\n"
        ]
        new_lines.extend(captura_block)
        # Advance i past old function
        while i < n and "return enriquecer_screenshot_hud" not in lines[i]:
            i += 1
        i += 1 # skip return line
        continue

    # 4. obter_teclado_inline_padrao
    if line.startswith("def obter_teclado_inline_padrao():"):
        kbd_block = [
            "def obter_teclado_inline_padrao():\n",
            "    return {\n",
            '        "inline_keyboard": [\n',
            "            [\n",
            '                {"text": "📸 Tela 5K (/tela)", "callback_data": "cmd_tela"},\n',
            '                {"text": "📸 Tela 25K (/tela25k)", "callback_data": "cmd_tela25k"}\n',
            "            ],\n",
            "            [\n",
            '                {"text": "📊 Status Dual (/status)", "callback_data": "cmd_status"},\n',
            '                {"text": "🎯 Posições (/posicoes)", "callback_data": "cmd_posicoes"}\n',
            "            ],\n",
            "            [\n",
            '                {"text": "📑 Relatório Quant (/relatorio)", "callback_data": "cmd_relatorio"},\n',
            '                {"text": "⏸️ Pausar Robô", "callback_data": "cmd_pausar"}\n',
            "            ],\n",
            "            [\n",
            '                {"text": "▶️ Retomar Robô", "callback_data": "cmd_retomar"},\n',
            '                {"text": "🚨 ZERAR TUDO (/zerar)", "callback_data": "cmd_zerar"}\n',
            "            ]\n",
            "        ]\n",
            "    }\n"
        ]
        new_lines.extend(kbd_block)
        while i < n and lines[i].strip() != "}":
            i += 1
        i += 1
        continue

    # 5. gerar_painel_status
    if line.startswith("def gerar_painel_status("):
        status_block = [
            "def gerar_painel_status(estado=None):\n",
            "    if estado is None:\n",
            "        estado = obter_estado_mt5()\n",
            '    r = estado["relatorio"]\n',
            '    pos_resumo = f"{len(estado[\'posicoes\'])} ativa(s) ({estado[\'floating_pnl\']:+.2f} USD)" if estado["posicoes"] else "0 abertas"\n',
            "    \n",
            "    # Telemetria 25K\n",
            '    r25k = ler_ultimo_relatorio_ea(r"C:\\Goat_MT5_25K\\MQL5\\Files")\n',
            '    bal_25k = r25k.get("balance", 0.0) or 25000.0\n',
            '    eq_25k = r25k.get("equity", 0.0) or bal_25k\n',
            '    real_25k = r25k.get("realizado_hoje", 0.0)\n',
            "    \n",
            "    return (\n",
            '        f"🛸 [PAINEL DUAL ALIEN V12.1 — GOAT FUNDED TRADER]\\n"\n',
            '        f"🕒 Sincronizado: {estado[\'timestamp\']} | Ouro: {estado[\'bid\']:.2f}/{estado[\'ask\']:.2f} (Spread: {estado[\'spread_pts\']:.1f} pts)\\n"\n',
            '        f"━━━━━━━━━━━━━━━━━━━━━━\\n"\n',
            '        f"1️⃣ CONTA 5K EVALUATION (Login: {REAL_LOGIN} | {REAL_SERVER})\\n"\n',
            '        f"• Status: {estado[\'status_motor\']} | Lote: 0.08\\n"\n',
            '        f"• Saldo: ${estado[\'balance\']:,.2f} | Equity: ${estado[\'equity\']:,.2f}\\n"\n',
            '        f"• Fechado Hoje: {estado[\'realizado_hoje_total\']:+.2f} USD ({estado[\'trades_hoje_total\']} trades) | Flutuante: {estado[\'floating_pnl\']:+.2f} USD\\n"\n',
            '        f"• Alvo Diário: +${DAILY_TARGET_USD:.0f} | Disjuntor: -${DAILY_MAX_LOSS_USD:.0f} | Hard Stop: -${TOTAL_MAX_LOSS_USD:.0f}\\n"\n',
            '        f"• Leitura 5K: {r[\'decisao\'][:55]}\\n"\n',
            '        f"━━━━━━━━━━━━━━━━━━━━━━\\n"\n',
            '        f"2️⃣ CONTA 25K COMPETITION (Login: 436271843 | GoatFunded-Server2)\\n"\n',
            '        f"• Status: 🟢 OPERANDO AO VIVO | Lote: 0.35\\n"\n',
            '        f"• Saldo: ${bal_25k:,.2f} | Equity: ${eq_25k:,.2f} | Hoje: {real_25k:+.2f} USD\\n"\n',
            '        f"• Alvo: +$350.00/dia | Disjuntor: -$500.00/dia | Hard Stop Total: -$1,250.00\\n"\n',
            '        f"• Leitura 25K: {r25k[\'decisao\'][:55]}\\n"\n',
            '        f"━━━━━━━━━━━━━━━━━━━━━━\\n"\n',
            '        f"🧠 RADAR INSTITUCIONAL M1:\\n"\n',
            '        f"• Sessão: {r[\'sessao\']} | Score M1: {r[\'score\']} | Sweep: {r[\'sweep_diag\'][:40]}"\n',
            "    )\n"
        ]
        new_lines.extend(status_block)
        while i < n and not (lines[i].startswith("def gerar_painel_posicoes(")):
            i += 1
        continue

    # 6. executar_acao_comando cmd_tela & cmd_tela25k
    if line.strip() == 'if cmd_key == "cmd_tela":':
        tela_block = [
            '    if cmd_key == "cmd_tela":\n',
            "        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado, conta='5k')\n",
            '        r = estado["relatorio"]\n',
            "        legenda = (\n",
            '            f"📸 [VISÃO EM TEMPO REAL — CONTA 5K EVALUATION]\\n"\n',
            '            f"• Login: {REAL_LOGIN} | Servidor: {REAL_SERVER}\\n"\n',
            '            f"• XAUUSD.x: {estado[\'bid\']:.2f} / {estado[\'ask\']:.2f} (Spread {estado[\'spread_pts\']:.1f} pts)\\n"\n',
            '            f"• Equity: ${estado[\'equity\']:,.2f} | Hoje: {estado[\'realizado_hoje_total\']:+.2f} USD | Flutuante: {estado[\'floating_pnl\']:+.2f} USD\\n"\n',
            '            f"• Score: {r[\'score\']} | Sessão: {r[\'sessao\']}\\n"\n',
            '            f"• Leitura: {r[\'decisao\']}"\n',
            "        )\n",
            "        send_telegram_photo_bytes(chat_id, img_bytes, caption=legenda, reply_markup=botoes)\n",
            '        prompt_leitura = texto_original if (texto_original and not texto_original.startswith("/")) else "Analise a tela ao vivo do MT5 5K que acabei de pedir no comando /tela e dê a visão técnica exata deste segundo."\n',
            "        resposta = chamar_cerebro(chat_id, first_name, prompt_leitura, image_bytes=img_bytes, estado=estado)\n",
            "        send_telegram(chat_id, resposta)\n",
            "        return True\n",
            "\n",
            '    if cmd_key == "cmd_tela25k":\n',
            "        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado, conta='25k')\n",
            '        r25k = ler_ultimo_relatorio_ea(r"C:\\Goat_MT5_25K\\MQL5\\Files")\n',
            '        bal_25k = r25k.get("balance", 0.0) or 25000.0\n',
            '        eq_25k = r25k.get("equity", 0.0) or bal_25k\n',
            '        real_25k = r25k.get("realizado_hoje", 0.0)\n',
            "        legenda = (\n",
            '            f"📸 [VISÃO EM TEMPO REAL — CONTA 25K COMPETITION]\\n"\n',
            '            f"• Login: 436271843 | Servidor: GoatFunded-Server2\\n"\n',
            '            f"• XAUUSD.x: {estado[\'bid\']:.2f} / {estado[\'ask\']:.2f} (Spread {estado[\'spread_pts\']:.1f} pts)\\n"\n',
            '            f"• Saldo: ${bal_25k:,.2f} | Equity: ${eq_25k:,.2f} | Hoje: {real_25k:+.2f} USD\\n"\n',
            '            f"• Lote: 0.35 | Alvo: +$350.00/dia | Disjuntor: -$500.00/dia\\n"\n',
            '            f"• Score: {r25k[\'score\']} | Sessão: {r25k[\'sessao\']}\\n"\n',
            '            f"• Leitura: {r25k[\'decisao\']}"\n',
            "        )\n",
            "        send_telegram_photo_bytes(chat_id, img_bytes, caption=legenda, reply_markup=botoes)\n",
            '        prompt_leitura = texto_original if (texto_original and not texto_original.startswith("/")) else "Analise a tela ao vivo do MT5 25K que acabei de pedir no comando /tela25k e dê a visão técnica exata deste segundo."\n',
            "        resposta = chamar_cerebro(chat_id, first_name, prompt_leitura, image_bytes=img_bytes, estado=estado)\n",
            "        send_telegram(chat_id, resposta)\n",
            "        return True\n"
        ]
        new_lines.extend(tela_block)
        while i < n and not (lines[i].strip() == "return False" and i > 945):
            i += 1
        continue

    # 7. identificar_comando_texto
    if 'if cmd_token in ("/tela", "/print", "/grafico", "/foto", "/visao"):' in line:
        id_block = [
            '    if cmd_token in ("/tela25k", "/print25k", "/foto25k", "/25k"):\n',
            '        return "cmd_tela25k"\n',
            '    if cmd_token in ("/tela", "/print", "/grafico", "/foto", "/visao"):\n',
            '        if "25" in t:\n',
            '            return "cmd_tela25k"\n',
            '        return "cmd_tela"\n'
        ]
        new_lines.extend(id_block)
        i += 2 # skip old if and return
        continue

    new_lines.append(line)
    i += 1

with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("alien_living_core.py patched line-by-line successfully!")
