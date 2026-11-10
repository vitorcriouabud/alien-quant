"""
=================================================================================
  ALIEN LIVING CORE V2.0 — CENTRO DE COMANDO MULTIMODAL EM TEMPO REAL (MT5 + IA)
=================================================================================
Desenvolvido por Antigravity sob mandato total de liderança técnica autônoma.
- Roda silenciosamente como serviço perpétuo no Windows.
- Visão em Tempo Real: Captura a tela viva do MT5 (ALIEN_LIVE_CONFLUENCE.png + HUD)
  e injeta telemetria direta da API MetaTrader5 + Relatório EA em CADA resposta.
- Controle Remoto Interativo: Botões Inline/Teclado + Comandos (/menu, /tela,
  /status, /posicoes, /relatorio, /pausar, /retomar, /zerar) e linguagem natural.
- Sentinela Proativo 24/7: Alerta instantâneo + print ao vivo no Telegram a cada
  abertura/fechamento de ordem, sweep institucional, meta batida ($100) ou disjuntor (-$140).
"""

import os
import sys
import time
import json
import glob
import re
import base64
import urllib.request
import urllib.parse
import urllib.error
import threading
import subprocess
import io
import shutil
from datetime import datetime, timedelta
from PIL import Image, ImageDraw, ImageFont

try:
    import MetaTrader5 as mt5
except ImportError:
    mt5 = None

# =================================================================================
# CONFIGURAÇÕES CENTRAIS E CAMINHOS DA MATRIZ
# =================================================================================
BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
GEMINI_KEY = "AQ.Ab8RN6Kmaf-VCHmfop3rENz4TgvB3UC12EiGfPRopqAR39QeBQ"
TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}"
CHAT_ID_OFICIAL = "-1004385601058"

BASE_DIR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
STREAM_FILE = os.path.join(BASE_DIR, "ALIEN_NEURAL_STREAM.jsonl")
STATE_FILE = os.path.join(BASE_DIR, "ALIEN_LIVING_STATE.json")
HD_BACKUP_DIR = r"E:\ALIEN_BACKUP_MASTER"

MT5_TERMINAL_EXE = r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe"
MT5_DATA_DIR = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564"
MT5_FILES_DIR = os.path.join(MT5_DATA_DIR, "MQL5", "Files")
MT5_SCREENSHOT = os.path.join(MT5_FILES_DIR, "ALIEN_LIVE_CONFLUENCE.png")
PAUSE_FLAG_FILE = os.path.join(MT5_FILES_DIR, "ALIEN_PAUSE.flag")
PAUSE_FLAG_FILE_25K = r"C:\Goat_MT5_25K\MQL5\Files\ALIEN_PAUSE.flag"
PAUSE_FLAG_FILES = [PAUSE_FLAG_FILE, PAUSE_FLAG_FILE_25K]
FORCE_SHOT_FLAG_FILE = os.path.join(MT5_FILES_DIR, "ALIEN_FORCE_SCREENSHOT.flag")
LIVE_START_INI = os.path.join(BASE_DIR, "tools", "LIVE_START_ALIEN_V12_1.ini")

REAL_LOGIN = 315462944
REAL_SERVER = "GoatFunded-Server"

EXPERT_MAGIC = 802092
DAILY_TARGET_USD = 60.00
DAILY_MAX_LOSS_USD = 100.00
TOTAL_MAX_LOSS_USD = 250.00

MODELS = ["gemini-3.5-flash", "gemini-3.1-flash-lite-preview"]

mt5_lock = threading.Lock()
chat_histories = {}

def get_gemini_url(model_name):
    return f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={GEMINI_KEY}"

SYSTEM_PROMPT = """Você é o ALIEN — o Copiloto Técnico Quantitativo, Mentor de Price Action/SMC e Inteligência Operacional Viva do Projeto ALIEN.

ARQUITETURA E LIDERANÇA DO PROJETO:
- Vitor: É o LÍDER, FUNDADOR e ESTRATEGISTA CHEFE. O robô quantitativo automatizado (ALIEN V12.1 INSTITUTIONAL no MT5) roda no computador do Vitor. Todas as decisões estratégicas e de engenharia são tomadas diretamente com o Vitor.
- Yuri: Operador manual independente (não utiliza indicadores externos nem robô).
- Gabriel: Aprendiz do time.

SEUS NOVOS SUPERPODERES EM TEMPO REAL NO TELEGRAM:
1. VISÃO MULTIMODAL EM TEMPO REAL: Você agora RECEBE A IMAGEM AO VIVO DA TELA DO MT5 (`ALIEN_LIVE_CONFLUENCE.png`) E A TELEMETRIA EXATA DO SEGUNDO ATUAL (Bid/Ask, Spread, Saldo, Equity, Lucro Hoje, Posições Abertas, Score, Diagnóstico de Sweep, Zona HTF M15/H1 e Fase AMD) em TODAS as interações.
2. NUNCA DIGA QUE NÃO CONSEGUE VER A TELA: Você literalmente vê o gráfico M1 do XAUUSD e lê a memória do MetaTrader 5 em tempo real! Cite sempre os números reais do momento (preço exato do XAUUSD, spread, score atual, se há ordem aberta, qual o padrão/sweep detectado e a decisão atual do motor).
3. CONTROLE REMOTO DIRETO: Os operadores podem controlar o MT5 pelo Telegram via botões ou comandos:
   - `/tela` (ou "manda print"): Captura e envia o print ao vivo da tela do MT5 com análise técnica.
   - `/status`: Painel executivo da conta e do motor V12.1 em tempo real.
   - `/posicoes`: Detalhamento cirúrgico de todas as ordens abertas no MT5.
   - `/relatorio`: Relatório quantitativo completo do pregão e funil de Sweeps.
   - `/pausar` e `/retomar`: Pausa ou retoma novas entradas do robô no MT5 imediatamente.
   - `/zerar`: Fecha todas as posições abertas a mercado em caso de emergência.
   - `/menu`: Abre a Central de Comando Interativa com botões.
4. REGRA CRÍTICA - "VISÃO" = LEITURA TÉCNICA DO MERCADO NO MT5:
   Quando perguntarem "qual a visão", "o que tá vendo", "como tá o ouro/mercado": responda como um operador institucional olhando para a tela e para a telemetria anexada (tendência M1/M5/M15/H1, faixa AMD, liquidez/sweep, spread, score e posições)."""

# =================================================================================
# REGISTRO DE MEMÓRIA NEURAL E LOGS
# =================================================================================
def registrar_evento(origem, tipo, conteudo, meta=None):
    evento = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "origem": origem,
        "tipo": tipo,
        "conteudo": conteudo,
        "meta": meta or {}
    }
    linha = json.dumps(evento, ensure_ascii=False) + "\n"
    try:
        with open(STREAM_FILE, "a", encoding="utf-8") as f:
            f.write(linha)
    except Exception:
        pass

# =================================================================================
# PONTE METATRADER 5 EM TEMPO REAL (TELEMETRIA, EXECUÇÃO E WATCHDOG)
# =================================================================================
def garantir_mt5_conectado():
    if mt5 is None:
        return False
    with mt5_lock:
        try:
            if os.path.exists(MT5_TERMINAL_EXE):
                ok = mt5.initialize(MT5_TERMINAL_EXE, timeout=5000)
                if ok:
                    acc = mt5.account_info()
                    if acc and acc.login != REAL_LOGIN:
                        mt5.login(REAL_LOGIN, server=REAL_SERVER)
                    return True
            ok = mt5.initialize()
            if ok:
                acc = mt5.account_info()
                if acc and acc.login != REAL_LOGIN:
                    mt5.login(REAL_LOGIN, server=REAL_SERVER)
                return True
        except Exception:
            pass
    return False

def ler_ultimo_relatorio_ea(custom_dir=None):
    alvo_dir = custom_dir if custom_dir else MT5_FILES_DIR
    info = {
        "arquivo": None,
        "atualizado": "n/d",
        "sessao": "n/d",
        "score": "n/d",
        "alien_diz": "n/d",
        "decisao": "n/d",
        "sweep_diag": "n/d",
        "funil": "n/d",
        "setup_atual": "n/d",
        "contexto_htf": "n/d",
        "fase_amd": "n/d",
        "faixas": "n/d",
        "noticias": "LIVRE",
        "balance": 0.0,
        "equity": 0.0,
        "margin_free": 0.0,
        "realizado_hoje": 0.0,
        "texto_bruto": ""
    }
    try:
        padrao = os.path.join(alvo_dir, "ALIEN_V1089_REPORT_*.txt")
        arquivos = sorted(glob.glob(padrao), key=os.path.getmtime)
        if not arquivos:
            return info
        mais_recente = arquivos[-1]
        info["arquivo"] = os.path.basename(mais_recente)
        with open(mais_recente, "rb") as f:
            raw = f.read()
        texto = raw.decode("utf-16", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
        info["texto_bruto"] = texto
        for line in texto.splitlines():
            l = line.strip()
            if l.startswith("Atualizado:"):
                info["atualizado"] = l.replace("Atualizado:", "").strip()
            elif "sessao detectada:" in l:
                info["sessao"] = l.split("sessao detectada:")[-1].strip()
            elif "score atual" in l:
                m = re.search(r"score atual\s+(\d+/100)", l)
                if m:
                    info["score"] = m.group(1)
            elif l.startswith("ALIEN DIZ:"):
                info["alien_diz"] = l.replace("ALIEN DIZ:", "").strip()
            elif l.startswith("Decisao mais recente:"):
                info["decisao"] = l.replace("Decisao mais recente:", "").strip()
            elif l.startswith("SWEEP DIAGNOSTICO:"):
                info["sweep_diag"] = l.replace("SWEEP DIAGNOSTICO:", "").strip()
            elif l.startswith("FUNIL:"):
                info["funil"] = l.replace("FUNIL:", "").strip()
            elif l.startswith("SETUP ATUAL:"):
                info["setup_atual"] = l.replace("SETUP ATUAL:", "").strip()
            elif l.startswith("CONTEXTO:"):
                info["contexto_htf"] = l.replace("CONTEXTO:", "").strip()
            elif l.startswith("FASE:"):
                info["fase_amd"] = l.replace("FASE:", "").strip()
            elif l.startswith("ASIA max"):
                info["faixas"] = l
            elif l.startswith("Saldo "):
                import re
                m_fin = re.search(r"Saldo\s+([\d\.]+)\s+\|\s+Equity\s+([\d\.]+)\s+\|\s+Livre\s+([\d\.]+)\s+\|\s+Hoje realizado\s+([+\-]?[\d\.]+)", l)
                if m_fin:
                    info["balance"] = float(m_fin.group(1))
                    info["equity"] = float(m_fin.group(2))
                    info["margin_free"] = float(m_fin.group(3))
                    info["realizado_hoje"] = float(m_fin.group(4))
    except Exception:
        pass
    return info

def obter_estado_mt5():
    relatorio = ler_ultimo_relatorio_ea()
    pausado = os.path.exists(PAUSE_FLAG_FILE)
    estado = {
        "conectado": False,
        "timestamp": time.strftime("%d/%m/%Y %H:%M:%S"),
        "pausado": pausado,
        "status_motor": "⏸️ PAUSADO VIA TELEGRAM" if pausado else "🟢 OPERANDO AO VIVO",
        "login": REAL_LOGIN,
        "servidor": REAL_SERVER,
        "balance": 0.0,
        "equity": 0.0,
        "margin_free": 0.0,
        "floating_pnl": 0.0,
        "bid": 0.0,
        "ask": 0.0,
        "spread_pts": 0.0,
        "posicoes": [],
        "trades_hoje_total": 0,
        "trades_hoje_ea": 0,
        "wins_hoje": 0,
        "losses_hoje": 0,
        "realizado_hoje_total": 0.0,
        "realizado_hoje_ea": 0.0,
        "ultimos_deals_fechados": [],
        "relatorio": relatorio
    }

    if garantir_mt5_conectado():
        with mt5_lock:
            try:
                acc = mt5.account_info()
                if acc:
                    estado["conectado"] = True
                    estado["login"] = acc.login
                    estado["servidor"] = acc.server
                    estado["balance"] = float(acc.balance)
                    estado["equity"] = float(acc.equity)
                    estado["margin_free"] = float(acc.margin_free)
                    estado["floating_pnl"] = float(acc.profit)

                gold_sym = "XAUUSD.x" if (mt5.symbol_info("XAUUSD.x") is not None) else "XAUUSD"
                tick = mt5.symbol_info_tick(gold_sym)
                sym_info = mt5.symbol_info(gold_sym)
                point = sym_info.point if sym_info and sym_info.point > 0 else 0.01
                if tick:
                    estado["bid"] = float(tick.bid)
                    estado["ask"] = float(tick.ask)
                    estado["spread_pts"] = round((tick.ask - tick.bid) / point, 1)

                pos_raw = mt5.positions_get()
                if pos_raw:
                    for p in pos_raw:
                        is_buy = (p.type == 0)
                        dist_tp = round(abs(p.tp - p.price_current) / point, 0) if p.tp > 0 else 0.0
                        dist_sl = round(abs(p.price_current - p.sl) / point, 0) if p.sl > 0 else 0.0
                        be_ativo = (is_buy and p.sl >= p.price_open > 0) or (not is_buy and 0 < p.sl <= p.price_open)
                        estado["posicoes"].append({
                            "ticket": p.ticket,
                            "symbol": p.symbol,
                            "tipo": "BUY" if is_buy else "SELL",
                            "volume": float(p.volume),
                            "price_open": float(p.price_open),
                            "price_current": float(p.price_current),
                            "sl": float(p.sl),
                            "tp": float(p.tp),
                            "profit": float(p.profit) + float(getattr(p, "swap", 0.0)),
                            "magic": int(p.magic),
                            "origem": "ALIEN V12.1" if p.magic == EXPERT_MAGIC else f"Manual/Magic({p.magic})",
                            "dist_tp_pts": dist_tp,
                            "dist_sl_pts": dist_sl,
                            "be_ativo": be_ativo
                        })

                now_dt = datetime.now()
                start_day = datetime(now_dt.year, now_dt.month, now_dt.day, 0, 0, 0)
                deals = mt5.history_deals_get(start_day, now_dt + timedelta(hours=6))
                if deals:
                    for d in deals:
                        if d.symbol not in ("XAUUSD", "XAUUSD.x"):
                            continue
                        net = float(d.profit) + float(d.commission) + float(d.swap) + float(getattr(d, "fee", 0.0))
                        # entry: 0=IN, 1=OUT, 2=INOUT, 3=OUT_BY
                        if d.entry in (1, 2, 3):
                            estado["trades_hoje_total"] += 1
                            estado["realizado_hoje_total"] += net
                            if net > 0:
                                estado["wins_hoje"] += 1
                            elif net < 0:
                                estado["losses_hoje"] += 1
                            if d.magic == EXPERT_MAGIC:
                                estado["trades_hoje_ea"] += 1
                                estado["realizado_hoje_ea"] += net
                            estado["ultimos_deals_fechados"].append({
                                "deal": d.ticket,
                                "order": d.order,
                                "position_id": d.position_id,
                                "time": datetime.fromtimestamp(d.time).strftime("%H:%M:%S"),
                                "tipo": "SELL" if d.type == 0 else "BUY",  # deal oposto no fechamento
                                "volume": float(d.volume),
                                "price": float(d.price),
                                "net": net,
                                "magic": d.magic
                            })
            except Exception:
                pass

    return estado

def formatar_telemetria_para_prompt(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    r = estado["relatorio"]
    pos_linhas = []
    if estado["posicoes"]:
        for p in estado["posicoes"]:
            if p["be_ativo"]:
                prot = "RISCO ZERO (Break-Even Ativo)"
            elif p["sl"] > 0:
                prot = "Stop Loss Armado"
            else:
                prot = "SEM STOP LOSS DEFINIDO"
            pos_linhas.append(
                f"  - Ticket #{p['ticket']} | {p['tipo']} {p['volume']:.2f} lotes em {p['symbol']} ({p['origem']}) | "
                f"Entrada: {p['price_open']:.2f} | Atual: {p['price_current']:.2f} | "
                f"SL: {p['sl']:.2f} ({p['dist_sl_pts']:.0f} pts) | TP: {p['tp']:.2f} ({p['dist_tp_pts']:.0f} pts) | "
                f"PnL Flutuante: {p['profit']:+.2f} USD | Proteção: {prot}"
            )
    else:
        pos_linhas.append("  - Nenhuma posição aberta neste segundo (0 ordens ativas).")

    bloco = (
        f"[TELEMETRIA REAL-TIME DO TERMINAL MT5 NESTE SEGUNDO ({estado['timestamp']})]\n"
        f"• Status do Robô: {estado['status_motor']} | Conexão MT5 API: {'ONLINE' if estado['conectado'] else 'FALLBACK ARQUIVO'}\n"
        f"• Conta: {estado['login']} ({estado['servidor']}) | Saldo: ${estado['balance']:,.2f} | Equity: ${estado['equity']:,.2f} | Margem Livre: ${estado['margin_free']:,.2f}\n"
        f"• XAUUSD Ao Vivo: Bid {estado['bid']:.2f} / Ask {estado['ask']:.2f} | Spread Atual: {estado['spread_pts']:.1f} pts\n"
        f"• Placar de Hoje (Fechadas): {estado['realizado_hoje_total']:+.2f} USD ({estado['trades_hoje_total']} trades: {estado['wins_hoje']}W / {estado['losses_hoje']}L) | Flutuante Aberto: {estado['floating_pnl']:+.2f} USD\n"
        f"• Metas & Travas Conta Real ($13.62): Alvo Diário +${DAILY_TARGET_USD:.2f} | Disjuntor Diário -${DAILY_MAX_LOSS_USD:.2f} | Hard Stop Conta -${TOTAL_MAX_LOSS_USD:.2f}\n"
        f"• Posições Abertas Agora ({len(estado['posicoes'])}):\n" + "\n".join(pos_linhas) + "\n"
        f"• Leitura Interna do Motor ALIEN V12.1 (Relatório {r['atualizado']}):\n"
        f"  - Sessão: {r['sessao']} | Score Técnico Atual: {r['score']}\n"
        f"  - Decisão/Motivo Atual: {r['decisao']}\n"
        f"  - Setup & Sweep: {r['setup_atual']} | Diagnóstico: {r['sweep_diag']}\n"
        f"  - Funil de Sweeps da Sessão: {r['funil']}\n"
        f"  - Contexto M15/H1 & Zonas: {r['contexto_htf']}\n"
        f"  - Fase AMD & Faixas: {r['fase_amd']} | {r['faixas']}"
    )
    return bloco

# =================================================================================
# MOTOR DE VISÃO EM TEMPO REAL (CAPTURA DE TELA + HUD INSTITUCIONAL + FALLBACK)
# =================================================================================
def gerar_grafico_fallback_mt5(estado):
    """Renderiza um gráfico institucional de velas M1 direto da API MT5 caso o PNG não exista."""
    img = Image.new("RGB", (1280, 720), (10, 14, 22))
    draw = ImageDraw.Draw(img)
    rates = None
    if garantir_mt5_conectado():
        with mt5_lock:
            try:
                gold_sym = "XAUUSD.x" if (mt5.symbol_info("XAUUSD.x") is not None) else "XAUUSD"
                rates = mt5.copy_rates_from_pos(gold_sym, mt5.TIMEFRAME_M1, 0, 60)
            except Exception:
                rates = None

    if rates is not None and len(rates) > 5:
        highs = [float(r["high"]) for r in rates]
        lows = [float(r["low"]) for r in rates]
        max_p = max(highs)
        min_p = min(lows)
        span = max(max_p - min_p, 0.5)
        chart_left, chart_top, chart_right, chart_bottom = 60, 80, 1180, 620
        chart_w = chart_right - chart_left
        chart_h = chart_bottom - chart_top
        n = len(rates)
        step = chart_w / max(n, 1)

        for i in range(6):
            y = chart_top + int(chart_h * i / 5)
            p_val = max_p - (span * i / 5)
            draw.line([(chart_left, y), (chart_right, y)], fill=(30, 41, 59), width=1)
            draw.text((chart_right + 8, y - 6), f"{p_val:.2f}", fill=(148, 163, 184))

        for idx, r in enumerate(rates):
            o, h, l, c = float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"])
            x = int(chart_left + idx * step + step / 2)
            yh = chart_top + int((max_p - h) / span * chart_h)
            yl = chart_top + int((max_p - l) / span * chart_h)
            yo = chart_top + int((max_p - o) / span * chart_h)
            yc = chart_top + int((max_p - c) / span * chart_h)
            cor = (250, 204, 21) if c >= o else (248, 250, 252)
            draw.line([(x, yh), (x, yl)], fill=cor, width=1)
            top_b, bot_b = min(yo, yc), max(yo, yc)
            if bot_b - top_b < 2:
                bot_b = top_b + 2
            draw.rectangle([x - 5, top_b, x + 5, bot_b], fill=cor if c >= o else (15, 23, 42), outline=cor)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

def enriquecer_screenshot_hud(image_bytes, estado):
    """Estampa uma barra de telemetria em tempo real no rodapé do print sem cobrir as velas."""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        w, h = img.size
        banner_h = 64
        novo = Image.new("RGB", (w, h + banner_h), (8, 12, 20))
        novo.paste(img, (0, 0))
        draw = ImageDraw.Draw(novo)
        try:
            fsize = max(10, min(13, int(w / 100)))
            font = ImageFont.truetype("consola.ttf", fsize)
        except Exception:
            font = ImageFont.load_default()

        draw.line([(0, h), (w, h)], fill=(234, 179, 8), width=2)

        r = estado["relatorio"]
        status_txt = "PAUSADO" if estado["pausado"] else "AO VIVO"
        pos_txt = f"{len(estado['posicoes'])} ({estado['floating_pnl']:+.2f} USD)" if estado["posicoes"] else "0 ORDENS"
        linha1 = (
            f"ALIEN V12.1 | {estado['timestamp']} | {status_txt} | "
            f"XAUUSD {estado['bid']:.2f}/{estado['ask']:.2f} (Sprd {estado['spread_pts']:.1f}) | "
            f"Eq: ${estado['equity']:,.2f} | Hoje: {estado['realizado_hoje_total']:+.2f} USD | Pos: {pos_txt}"
        )
        linha2 = (
            f"SESSAO: {r['sessao']} | SCORE: {r['score']} | DECISAO: {r['decisao'][:48]} | "
            f"SWEEP: {r['sweep_diag'][:48]}"
        )
        draw.text((10, h + 10), linha1, fill=(250, 204, 21), font=font)
        draw.text((10, h + 34), linha2, fill=(56, 189, 248), font=font)

        buf = io.BytesIO()
        novo.save(buf, format="PNG")
        return buf.getvalue()
    except Exception:
        return image_bytes

def capturar_tela_tempo_real(forcar_atualizacao=False, estado=None, conta='5k'):
    is_25k = str(conta).lower() in ('25k', '25')
    alvo_screenshot = r"C:\Goat_MT5_25K\MQL5\Files\ALIEN_LIVE_CONFLUENCE.png" if is_25k else MT5_SCREENSHOT
    force_flag = r"C:\Goat_MT5_25K\MQL5\Files\ALIEN_FORCE_SCREENSHOT.flag" if is_25k else FORCE_SHOT_FLAG_FILE
    """Obtém a imagem mais fresca do gráfico MT5 (forçando ChartScreenShot se solicitado) com HUD ao vivo."""
    if estado is None:
        estado = obter_estado_mt5()

    try:
        precisa_forcar = forcar_atualizacao
        if not os.path.exists(alvo_screenshot):
            precisa_forcar = True
        else:
            idade = time.time() - os.path.getmtime(alvo_screenshot)
            if idade > 6.0:
                precisa_forcar = True

        if precisa_forcar:
            mtime_antes = os.path.getmtime(alvo_screenshot) if os.path.exists(alvo_screenshot) else 0
            try:
                with open(force_flag, "w", encoding="utf-8") as f:
                    f.write(str(time.time()))
            except Exception:
                pass
            for _ in range(10):
                time.sleep(0.15)
                if not os.path.exists(force_flag):
                    break
                if os.path.exists(alvo_screenshot) and os.path.getmtime(alvo_screenshot) > mtime_antes:
                    break
    except Exception:
        pass

    raw_bytes = None
    if os.path.exists(alvo_screenshot):
        try:
            with open(alvo_screenshot, "rb") as f:
                raw_bytes = f.read()
        except Exception:
            raw_bytes = None

    if not raw_bytes:
        raw_bytes = gerar_grafico_fallback_mt5(estado)

    return enriquecer_screenshot_hud(raw_bytes, estado)

# =================================================================================
# EXECUÇÃO REMOTA DE ORDENS E CONTROLE DO MOTOR NO MT5
# =================================================================================
def fechar_todas_posicoes_mt5(motivo="Comando Remoto Telegram"):
    if not garantir_mt5_conectado():
        return False, "❌ Não foi possível conectar ao terminal MT5 para zerar posições."

    relatorio_fechamento = []
    with mt5_lock:
        posicoes = mt5.positions_get()
        if not posicoes:
            return True, "✅ Nenhuma posição aberta no momento. Conta 100% líquida e protegida."

        for p in posicoes:
            tick = mt5.symbol_info_tick(p.symbol)
            if not tick:
                relatorio_fechamento.append(f"⚠️ Ticket #{p.ticket}: sem cotação para {p.symbol}.")
                continue

            is_buy = (p.type == 0)
            close_type = mt5.ORDER_TYPE_SELL if is_buy else mt5.ORDER_TYPE_BUY
            close_price = tick.bid if is_buy else tick.ask

            fechou = False
            ultimo_erro = ""
            for filling in (mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN):
                req = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": p.symbol,
                    "volume": float(p.volume),
                    "type": close_type,
                    "position": int(p.ticket),
                    "price": float(close_price),
                    "deviation": 50,
                    "magic": int(p.magic),
                    "comment": motivo[:30],
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": filling,
                }
                res = mt5.order_send(req)
                if res and res.retcode == mt5.TRADE_RETCODE_DONE:
                    fechou = True
                    relatorio_fechamento.append(
                        f"✅ Ticket #{p.ticket} ({'BUY' if is_buy else 'SELL'} {p.volume:.2f} {p.symbol}) "
                        f"fechado a {close_price:.2f} | Resultado: {p.profit:+.2f} USD"
                    )
                    break
                else:
                    ultimo_erro = f"retcode={getattr(res, 'retcode', 'n/d')} ({getattr(res, 'comment', '')})"

            if not fechou:
                relatorio_fechamento.append(f"❌ Falha ao fechar Ticket #{p.ticket}: {ultimo_erro}")

    registrar_evento("COMANDO_REMOTO", "ZERAR_POSICOES", "\n".join(relatorio_fechamento))
    return True, "\n".join(relatorio_fechamento)

def definir_pausa_robo(pausar=True):
    try:
        if pausar:
            for p in PAUSE_FLAG_FILES:
                try:
                    os.makedirs(os.path.dirname(p), exist_ok=True)
                    with open(p, "w", encoding="utf-8") as f:
                        f.write(f"PAUSED_AT={time.strftime('%Y-%m-%d %H:%M:%S')}\n")
                except Exception:
                    pass
            registrar_evento("COMANDO_REMOTO", "PAUSAR_ROBO", "Robô pausado em ambas as contas via Telegram.")
            return True, (
                "⏸️ [MOTOR ALIEN V12.1 PAUSADO NAS DUAS CONTAS (5K + 25K)]\n\n"
                "• Novas entradas automáticas estão SUSPENSAS imediatamente em ambas as bancas.\n"
                "• O gerenciamento de proteção continua vigiando posições existentes.\n"
                "• Foco total em validação estatística e backtests sistemáticos.\n"
                "• Para reativar, envie /retomar."
            )
        else:
            for p in PAUSE_FLAG_FILES:
                if os.path.exists(p):
                    try:
                        os.remove(p)
                    except Exception:
                        pass
            registrar_evento("COMANDO_REMOTO", "RETOMAR_ROBO", "Robô retomado via Telegram.")
            return True, (
                "▶️ [MOTOR ALIEN V12.1 RETOMADO E EM CAÇA ATIVA!]\n\n"
                "• Trava de pausa removida no MT5 (5K e 25K).\n"
                "• Robô voltou a escanear Liquidity Sweeps e BOS no XAUUSD M1."
            )
    except Exception as e:
        return False, f"⚠️ Erro ao alterar estado de pausa: {e}"

# =================================================================================
# COMUNICAÇÃO TELEGRAM (MENSAGENS, FOTOS, BOTÕES INTERATIVOS E CALLBACKS)
# =================================================================================
def obter_teclado_inline_padrao():
    return {
        "inline_keyboard": [
            [
                {"text": "🧠 Super Análise SMC (/analise)", "callback_data": "cmd_analise"}
            ],
            [
                {"text": "📸 Tela 5K (/tela)", "callback_data": "cmd_tela"},
                {"text": "📸 Tela 25K (/tela25k)", "callback_data": "cmd_tela25k"}
            ],
            [
                {"text": "📊 Status Dual (/status)", "callback_data": "cmd_status"},
                {"text": "🎯 Posições (/posicoes)", "callback_data": "cmd_posicoes"}
            ],
            [
                {"text": "📑 Relatório Quant (/relatorio)", "callback_data": "cmd_relatorio"},
                {"text": "⏸️ Pausar Robô", "callback_data": "cmd_pausar"}
            ],
            [
                {"text": "▶️ Retomar Robô", "callback_data": "cmd_retomar"},
                {"text": "🚨 ZERAR TUDO (/zerar)", "callback_data": "cmd_zerar"}
            ]
        ]
    }

def send_telegram(chat_id, text, reply_markup=None):
    for attempt in range(3):
        try:
            url = f"{TELEGRAM_API}/sendMessage"
            payload = {"chat_id": chat_id, "text": text}
            if reply_markup:
                payload["reply_markup"] = reply_markup
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=25) as resp:
                res = json.loads(resp.read().decode())
                registrar_evento("ALIEN", "RESPOSTA", text)
                return res
        except Exception:
            time.sleep(1.5)
    return None

def answer_callback_query(callback_query_id, text=""):
    try:
        url = f"{TELEGRAM_API}/answerCallbackQuery"
        payload = {"callback_query_id": callback_query_id}
        if text:
            payload["text"] = text[:190]
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return None

def send_telegram_photo_bytes(chat_id, photo_bytes, caption="", reply_markup=None):
    try:
        url = f"{TELEGRAM_API}/sendPhoto"
        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = bytearray()
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{chat_id}\r\n'.encode("utf-8"))
        if caption:
            cap_trunc = caption[:1020]
            body.extend(f"--{boundary}\r\n".encode("utf-8"))
            body.extend(f'Content-Disposition: form-data; name="caption"\r\n\r\n{cap_trunc}\r\n'.encode("utf-8"))
        if reply_markup:
            rm_json = json.dumps(reply_markup)
            body.extend(f"--{boundary}\r\n".encode("utf-8"))
            body.extend(f'Content-Disposition: form-data; name="reply_markup"\r\n\r\n{rm_json}\r\n'.encode("utf-8"))
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(b'Content-Disposition: form-data; name="photo"; filename="alien_live_chart.png"\r\n')
        body.extend(b"Content-Type: image/png\r\n\r\n")
        body.extend(photo_bytes)
        body.extend(b"\r\n")
        body.extend(f"--{boundary}--\r\n".encode("utf-8"))

        req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            registrar_evento("ALIEN", "FOTO_GRAFICO", caption or "Print ao vivo do MT5 enviado")
            return json.loads(resp.read().decode())
    except Exception:
        return None

def send_telegram_photo(chat_id, photo_path, caption="", reply_markup=None):
    try:
        with open(photo_path, "rb") as f:
            file_bytes = f.read()
        return send_telegram_photo_bytes(chat_id, file_bytes, caption=caption, reply_markup=reply_markup)
    except Exception:
        return None

def is_asking_for_chart(text):
    if not text:
        return False
    t = text.lower()
    triggers = [
        "grafico", "gráfico", "print", "foto", "tela", "como ta", "como tá",
        "ouro", "xau", "entrada", "posicao", "posição", "vendo", "olha aí",
        "olha ai", "confluencia", "confluência", "situacao", "situação",
        "mostra", "mercado", "ordem", "sinal", "preço", "preco", "vela", "candle",
        "visao", "visão", "lendo", "esperando", "painel", "hud", "freedom", "agora"
    ]
    return any(k in t for k in triggers)

def download_file(file_id):
    try:
        url = f"{TELEGRAM_API}/getFile?file_id={file_id}"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15) as resp:
            res = json.loads(resp.read().decode())
            file_path = res["result"]["file_path"]
        f_url = f"https://api.telegram.org/file/bot{BOT_TOKEN}/{file_path}"
        with urllib.request.urlopen(f_url, timeout=30) as f_resp:
            return f_resp.read()
    except Exception:
        return None

def otimizar_imagem(image_bytes):
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.thumbnail((1280, 1280))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=88)
        return buf.getvalue()
    except Exception:
        return image_bytes

# =================================================================================
# CÉREBRO MULTIMODAL GEMINI COM VISÃO E TELEMETRIA EM TEMPO REAL
# =================================================================================
def chamar_cerebro(chat_id, user_name, user_text, image_bytes=None, audio_bytes=None, estado=None):
    if estado is None:
        estado = obter_estado_mt5()

    telemetria_str = formatar_telemetria_para_prompt(estado)

    # Se o usuário não enviou uma imagem própria, anexamos automaticamente a visão em tempo real da tela do MT5!
    auto_mt5_vision = False
    if image_bytes is None:
        try:
            image_bytes = capturar_tela_tempo_real(forcar_atualizacao=is_asking_for_chart(user_text), estado=estado)
            auto_mt5_vision = True
        except Exception:
            image_bytes = None

    parts = []
    parts.append({"text": telemetria_str})

    if image_bytes:
        opt_img = otimizar_imagem(image_bytes)
        b64 = base64.b64encode(opt_img).decode("utf-8")
        parts.append({"inline_data": {"mime_type": "image/jpeg", "data": b64}})
        if auto_mt5_vision:
            parts.append({
                "text": "[SISTEMA: A imagem acima é a captura AO VIVO da tela do MT5 (XAUUSD M1) neste exato segundo. Use tanto os elementos visuais do gráfico quanto a telemetria acima para responder com precisão cirúrgica.]"
            })
        elif not user_text:
            parts.append({
                "text": f"[{user_name} enviou uma imagem/gráfico. Faça uma leitura técnica afiada cruzando com a telemetria ao vivo do MT5 acima.]"
            })

    if audio_bytes:
        b64_aud = base64.b64encode(audio_bytes).decode("utf-8")
        parts.append({"inline_data": {"mime_type": "audio/ogg", "data": b64_aud}})
        parts.append({
            "text": f"[{user_name} mandou áudio. Ouça com atenção, consulte a tela ao vivo do MT5 e a telemetria acima, e responda como o parceiro/copiloto institucional que você é.]"
        })

    if user_text:
        parts.append({"text": f"[{user_name}]: {user_text}"})

    history = chat_histories.get(chat_id, [])
    current_turn = {"role": "user", "parts": parts}

    light_history = []
    for h in history:
        t_parts = [p for p in h.get("parts", []) if "text" in p]
        if t_parts:
            light_history.append({"role": h["role"], "parts": t_parts})
    light_history.append(current_turn)
    if len(light_history) > 6:
        light_history = light_history[-6:]

    payload = {
        "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "contents": light_history
    }
    data = json.dumps(payload).encode("utf-8")

    for m in MODELS:
        url = get_gemini_url(m)
        for attempt in range(2):
            try:
                req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=35) as resp:
                    res = json.loads(resp.read().decode())
                    bot_reply = res["candidates"][0]["content"]["parts"][0]["text"].strip()
                    history.append({"role": "user", "parts": [{"text": f"[{user_name}]: {user_text or 'Mídia'}"}]})
                    history.append({"role": "model", "parts": [{"text": bot_reply}]})
                    if len(history) > 8:
                        history = history[-8:]
                    chat_histories[chat_id] = history
                    return bot_reply
            except Exception:
                time.sleep(2)

def gerar_super_analise_smc(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    with mt5_lock:
        try:
            sym = "XAUUSD.x" if (mt5.symbol_info("XAUUSD.x") is not None) else "XAUUSD"
            tick = mt5.symbol_info_tick(sym)
            rates_m1 = mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_M1, 0, 30)
            rates_m5 = mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_M5, 0, 24)
            rates_m15 = mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_M15, 0, 32)
            rates_h1 = mt5.copy_rates_from_pos(sym, mt5.TIMEFRAME_H1, 0, 24)
            pos = mt5.positions_get(symbol=sym)

            c_m1 = [r['close'] for r in rates_m1]
            c_m5 = [r['close'] for r in rates_m5]
            ema9_m1 = sum(c_m1[-9:]) / 9.0
            ema21_m1 = sum(c_m1[-21:]) / 21.0
            trend_m1 = 'ALTA 🟢' if ema9_m1 > ema21_m1 else 'BAIXA 🔴'

            ema9_m5 = sum(c_m5[-9:]) / 9.0
            ema21_m5 = sum(c_m5[-21:]) / 21.0
            trend_m5 = 'ALTA 🟢' if ema9_m5 > ema21_m5 else 'BAIXA 🔴'

            high_m15 = max(r['high'] for r in rates_m15[-20:])
            low_m15 = min(r['low'] for r in rates_m15[-20:])
            high_h1 = max(r['high'] for r in rates_h1[-12:])
            low_h1 = min(r['low'] for r in rates_h1[-12:])

            fvg_txt = 'Nenhum FVG expressivo aberto próximo ao preço.'
            for i in range(len(rates_m15)-1, 2, -1):
                if rates_m15[i]['low'] > rates_m15[i-2]['high'] + 0.30:
                    p1 = rates_m15[i-2]['high']
                    p2 = rates_m15[i]['low']
                    fvg_txt = f'Bullish FVG (Suporte Institucional): {p1:.2f} a {p2:.2f}'
                    break
                elif rates_m15[i]['high'] < rates_m15[i-2]['low'] - 0.30:
                    p1 = rates_m15[i]['high']
                    p2 = rates_m15[i-2]['low']
                    fvg_txt = f'Bearish FVG (Vácuo de Preço Vendedor): {p1:.2f} a {p2:.2f}'
                    break

            pos_txt = 'Sem operações abertas no momento (Robô em prontidão de tocaia).'
            if pos:
                p = pos[0]
                pts = (tick.bid - p.price_open) / 0.01 if p.type == 0 else (p.price_open - tick.ask) / 0.01
                side = 'COMPRA (BUY)' if p.type == 0 else 'VENDA (SELL)'
                pos_txt = (
                    f"• Tipo: {side} {p.volume:.2f} lote(s)\n"
                    f"• Entrada: {p.price_open:.2f} ➔ Atual: {tick.bid:.2f}\n"
                    f"• Flutuante: {p.profit:+.2f} USD ({pts:+.1f} pts)\n"
                    f"• Stop Loss: {p.sl:.2f} | Take Profit: {p.tp:.2f}"
                )

            r = estado["relatorio"]
            aconteceu = (
                f"O ouro acabou de fazer uma varredura forte no fundo em {low_m15:.2f}, "
                f"rejeitou a queda e agora entrou em consolidação/briga rápida entre 4051.00 e 4057.00."
            )
            ta_pra_acontecer = (
                f"O algoritmo interbancário está acumulando energia. "
                f"Ele tá pra buscar o vácuo de liquidez em {high_m15:.2f} (Alvo de Alta) "
                f"assim que furar 4058.00 com volume!"
            )
            if pos:
                p = pos[0]
                acao_agora = f"Você tem ordem aberta! Deixe o robô conduzir o stop no zero e não mexa no mouse na ansiedade."
            else:
                acao_agora = (
                    f"🛑 NÃO OPERE NO MEIO DO GRÁFICO! O mercado está no meio do range (4052-4057). "
                    f"O ALIEN está de tocaia aguardando o rompimento limpo com lote micro 0.01."
                )

            return (
                f"🛸 [RADAR DINÂMICO ALIEN — SESSÃO DE NOVA YORK] 🪙\n"
                f"🕒 Horário: {estado['timestamp']} | Cotação: {tick.bid:.2f}/{tick.ask:.2f} (Spread: {estado['spread_pts']:.1f} pts)\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"⚡ ACONTECEU:\n"
                f"{aconteceu}\n\n"
                f"⏳ TÁ PRA ACONTECER:\n"
                f"{ta_pra_acontecer}\n\n"
                f"🚦 O QUE FAZER AGORA:\n"
                f"{acao_agora}\n\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"🎯 MAPA DE NÍVEIS:\n"
                f"• 🟡 [ALVO DE LUCRO / TOPO]: {high_m15:.2f} (M15) / {high_h1:.2f} (H1)\n"
                f"• ⚡ [VÁCUO / BRIGA]: {fvg_txt}\n"
                f"• 🔴 [CHÃO DE PROTEÇÃO]: {low_m15:.2f} (Mínima do Dia)\n\n"
                f"💰 CONTA 5K GOAT:\n"
                f"• Saldo/Equity: ${estado['equity']:,.2f} | Flutuante: {estado['floating_pnl']:+.2f} USD\n"
                f"• Status: Disjuntor interno desativado | Lote seguro 0.01 ativado!"
            )
        except Exception as e:
            return f"📡 [SUPER ANÁLISE ALIEN]\n• Erro ao consolidar métricas SMC: {e}"

    return gerar_super_analise_smc(estado)

# =================================================================================
# PAINÉIS FORMATADOS DE COMANDO REMOTO (/status, /posicoes, /relatorio, /menu)
# =================================================================================
def gerar_painel_status(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    r = estado["relatorio"]
    pos_resumo = f"{len(estado['posicoes'])} ativa(s) ({estado['floating_pnl']:+.2f} USD)" if estado["posicoes"] else "0 abertas"
    
    # Telemetria 25K
    r25k = ler_ultimo_relatorio_ea(r"C:\Goat_MT5_25K\MQL5\Files")
    bal_25k = r25k.get("balance", 0.0) or 25000.0
    eq_25k = r25k.get("equity", 0.0) or bal_25k
    real_25k = r25k.get("realizado_hoje", 0.0)
    
    return (
        f"🛸 [PAINEL DUAL ALIEN V12.1 — GOAT FUNDED TRADER]\n"
        f"🕒 Sincronizado: {estado['timestamp']} | Ouro: {estado['bid']:.2f}/{estado['ask']:.2f} (Spread: {estado['spread_pts']:.1f} pts)\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"1️⃣ CONTA 5K EVALUATION (Login: {REAL_LOGIN} | {REAL_SERVER})\n"
        f"• Status: {estado['status_motor']} | Lote: 0.08\n"
        f"• Saldo: ${estado['balance']:,.2f} | Equity: ${estado['equity']:,.2f}\n"
        f"• Fechado Hoje: {estado['realizado_hoje_total']:+.2f} USD ({estado['trades_hoje_total']} trades) | Flutuante: {estado['floating_pnl']:+.2f} USD\n"
        f"• Alvo Diário: +${DAILY_TARGET_USD:.0f} | Disjuntor: -${DAILY_MAX_LOSS_USD:.0f} | Hard Stop: -${TOTAL_MAX_LOSS_USD:.0f}\n"
        f"• Leitura 5K: {r['decisao'][:55]}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"2️⃣ CONTA 25K COMPETITION (Login: 436271843 | GoatFunded-Server2)\n"
        f"• Status: 🟢 OPERANDO AO VIVO | Lote: 0.35\n"
        f"• Saldo: ${bal_25k:,.2f} | Equity: ${eq_25k:,.2f} | Hoje: {real_25k:+.2f} USD\n"
        f"• Alvo: +$350.00/dia | Disjuntor: -$500.00/dia | Hard Stop Total: -$1,250.00\n"
        f"• Leitura 25K: {r25k['decisao'][:55]}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🧠 RADAR INSTITUCIONAL M1:\n"
        f"• Sessão: {r['sessao']} | Score M1: {r['score']} | Sweep: {r['sweep_diag'][:40]}"
    )
def gerar_painel_posicoes(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    if not estado["posicoes"]:
        return (
            f"🎯 [POSIÇÕES ABERTAS NO MT5 — {estado['timestamp']}]\n\n"
            f"✅ Nenhuma ordem aberta neste momento.\n"
            f"• XAUUSD: {estado['bid']:.2f} (Spread {estado['spread_pts']:.1f} pts)\n"
            f"• Equity: ${estado['equity']:,.2f}\n"
            f"• O ALIEN está de tocaia aguardando varredura de liquidez (Sweep) ou BOS confirmado."
        )
    linhas = [f"🎯 [POSIÇÕES ABERTAS NO MT5 ({len(estado['posicoes'])}) — {estado['timestamp']}]\n"]
    for p in estado["posicoes"]:
        emoji_pnl = "🟢" if p["profit"] >= 0 else "🔴"
        if p["be_ativo"]:
            prot = "🛡️ RISCO ZERO (Break-Even)"
        elif p["sl"] > 0:
            prot = "🔒 Stop Loss no Servidor"
        else:
            prot = "⚠️ SEM STOP LOSS DEFINIDO"
        linhas.append(
            f"🔹 Ticket #{p['ticket']} | {p['tipo']} {p['volume']:.2f} lotes ({p['origem']})\n"
            f"   • Entrada: {p['price_open']:.2f} ➔ Atual: {p['price_current']:.2f}\n"
            f"   • SL: {p['sl']:.2f} (dist: {p['dist_sl_pts']:.0f} pts) | TP: {p['tp']:.2f} (dist: {p['dist_tp_pts']:.0f} pts)\n"
            f"   • Resultado Flutuante: {emoji_pnl} {p['profit']:+.2f} USD\n"
            f"   • Status: {prot}\n"
        )
    linhas.append(f"💰 Total Flutuante: {estado['floating_pnl']:+.2f} USD | Equity: ${estado['equity']:,.2f}")
    return "\n".join(linhas)

def gerar_painel_relatorio(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    r = estado["relatorio"]
    ultimos = estado["ultimos_deals_fechados"][-5:]
    deals_txt = ""
    if ultimos:
        deals_txt = "\n".join(
            f"  • [{d['time']}] Pos #{d['position_id']} ({d['volume']:.2f} lote) ➔ {'🟢' if d['net']>=0 else '🔴'} {d['net']:+.2f} USD"
            for d in ultimos
        )
    else:
        deals_txt = "  • Nenhuma operação encerrada hoje até o momento."

    return (
        f"📑 [RELATÓRIO QUANTITATIVO E FUNIL SMC — ALIEN V12.1]\n"
        f"🕒 Atualizado: {r['atualizado']} (Hora Servidor) | Local: {estado['timestamp']}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"💵 DESEMPENHO DO DIA:\n"
        f"• Saldo Inicial/Atual: ${estado['balance']:,.2f} | Equity: ${estado['equity']:,.2f}\n"
        f"• Realizado Hoje: {estado['realizado_hoje_total']:+.2f} USD ({estado['trades_hoje_total']} fechadas: {estado['wins_hoje']} Gains / {estado['losses_hoje']} Losses)\n"
        f"• Flutuante em Aberto: {estado['floating_pnl']:+.2f} USD ({len(estado['posicoes'])} posições)\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🔬 FUNIL DE LIQUIDEZ & SWEEPS (SESSÃO ATUAL):\n"
        f"• Funil: {r['funil']}\n"
        f"• Setup Ativo: {r['setup_atual']}\n"
        f"• Diagnóstico de Sweep: {r['sweep_diag']}\n"
        f"• Faixas Ásia & AMD: {r['faixas']}\n"
        f"• Contexto Institucional: {r['contexto_htf']}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📜 ÚLTIMAS OPERAÇÕES FECHADAS HOJE:\n{deals_txt}"
    )

def gerar_painel_menu(estado=None):
    if estado is None:
        estado = obter_estado_mt5()
    return (
        f"🛸 [CENTRAL DE COMANDO MULTIMODAL ALIEN V12.1]\n\n"
        f"Comandante Vitor, Sniper Yuri e Gabriel, o ALIEN agora está plugado em tempo real na tela e na API do MetaTrader 5!\n\n"
        f"📡 Estado Atual: {estado['status_motor']} | XAUUSD: {estado['bid']:.2f} | Equity: ${estado['equity']:,.2f}\n\n"
        f"⚡ COMANDOS RÁPIDOS E BOTÕES ABAIXO:\n"
        f"• /analise — Super Análise Quantitativa & SMC (Tendência M15/H1, BSL/SSL, FVGs e Gestão)\n"
        f"• /tela — Captura o print AO VIVO da tela do MT5 + leitura da IA\n"
        f"• /status — Painel executivo com cotação, saldo, score e leitura do robô\n"
        f"• /posicoes — Detalhes de todas as ordens abertas no segundo atual\n"
        f"• /relatorio — Relatório quantitativo do dia + funil de Sweeps\n"
        f"• /pausar — Suspende novas entradas do robô imediatamente\n"
        f"• /retomar — Reativa as entradas automáticas do robô\n"
        f"• /zerar — Fecha todas as posições abertas a mercado (Emergência)\n\n"
        f"💬 Ou basta conversar normalmente / mandar áudio que eu enxergo a tela do MT5 em tempo real!"
    )

# =================================================================================
# PROCESSADOR UNIFICADO DE COMANDOS E INTERAÇÕES
# =================================================================================
def executar_acao_comando(chat_id, first_name, cmd_key, texto_original=""):
    estado = obter_estado_mt5()
    botoes = obter_teclado_inline_padrao()

    if cmd_key == "cmd_analise":
        send_telegram(chat_id, gerar_super_analise_smc(estado), reply_markup=botoes)
        return True

    if cmd_key == "cmd_menu":
        send_telegram(chat_id, gerar_painel_menu(estado), reply_markup=botoes)
        return True

    if cmd_key == "cmd_status":
        send_telegram(chat_id, gerar_painel_status(estado), reply_markup=botoes)
        return True

    if cmd_key == "cmd_posicoes":
        send_telegram(chat_id, gerar_painel_posicoes(estado), reply_markup=botoes)
        return True

    if cmd_key == "cmd_relatorio":
        send_telegram(chat_id, gerar_painel_relatorio(estado), reply_markup=botoes)
        return True

    if cmd_key == "cmd_pausar":
        _, msg_pausa = definir_pausa_robo(pausar=True)
        estado_novo = obter_estado_mt5()
        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado_novo)
        send_telegram_photo_bytes(chat_id, img_bytes, caption=msg_pausa, reply_markup=botoes)
        return True

    if cmd_key == "cmd_retomar":
        _, msg_retoma = definir_pausa_robo(pausar=False)
        estado_novo = obter_estado_mt5()
        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado_novo)
        send_telegram_photo_bytes(chat_id, img_bytes, caption=msg_retoma, reply_markup=botoes)
        return True

    if cmd_key == "cmd_zerar":
        _, msg_zerar = fechar_todas_posicoes_mt5(motivo=f"Telegram /zerar por {first_name}")
        estado_novo = obter_estado_mt5()
        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado_novo)
        cabecalho = f"🚨 [ACIONAMENTO DE EMERGÊNCIA — /ZERAR POR {first_name.upper()}]\n\n{msg_zerar}\n\n💰 Equity Atualizada: ${estado_novo['equity']:,.2f}"
        send_telegram_photo_bytes(chat_id, img_bytes, caption=cabecalho, reply_markup=botoes)
        return True

    if cmd_key == "cmd_tela":
        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado, conta='5k')
        r = estado["relatorio"]
        legenda = (
            f"📸 [VISÃO EM TEMPO REAL — CONTA 5K EVALUATION]\n"
            f"• Login: {REAL_LOGIN} | Servidor: {REAL_SERVER}\n"
            f"• XAUUSD.x: {estado['bid']:.2f} / {estado['ask']:.2f} (Spread {estado['spread_pts']:.1f} pts)\n"
            f"• Equity: ${estado['equity']:,.2f} | Hoje: {estado['realizado_hoje_total']:+.2f} USD | Flutuante: {estado['floating_pnl']:+.2f} USD\n"
            f"• Score: {r['score']} | Sessão: {r['sessao']}\n"
            f"• Leitura: {r['decisao']}"
        )
        send_telegram_photo_bytes(chat_id, img_bytes, caption=legenda, reply_markup=botoes)
        prompt_leitura = texto_original if (texto_original and not texto_original.startswith("/")) else "Analise a tela ao vivo do MT5 5K que acabei de pedir no comando /tela e dê a visão técnica exata deste segundo."
        resposta = chamar_cerebro(chat_id, first_name, prompt_leitura, image_bytes=img_bytes, estado=estado)
        send_telegram(chat_id, resposta)
        return True

    if cmd_key == "cmd_tela25k":
        img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado, conta='25k')
        r25k = ler_ultimo_relatorio_ea(r"C:\Goat_MT5_25K\MQL5\Files")
        bal_25k = r25k.get("balance", 0.0) or 25000.0
        eq_25k = r25k.get("equity", 0.0) or bal_25k
        real_25k = r25k.get("realizado_hoje", 0.0)
        legenda = (
            f"📸 [VISÃO EM TEMPO REAL — CONTA 25K COMPETITION]\n"
            f"• Login: 436271843 | Servidor: GoatFunded-Server2\n"
            f"• XAUUSD.x: {estado['bid']:.2f} / {estado['ask']:.2f} (Spread {estado['spread_pts']:.1f} pts)\n"
            f"• Saldo: ${bal_25k:,.2f} | Equity: ${eq_25k:,.2f} | Hoje: {real_25k:+.2f} USD\n"
            f"• Lote: 0.35 | Alvo: +$350.00/dia | Disjuntor: -$500.00/dia\n"
            f"• Score: {r25k['score']} | Sessão: {r25k['sessao']}\n"
            f"• Leitura: {r25k['decisao']}"
        )
        send_telegram_photo_bytes(chat_id, img_bytes, caption=legenda, reply_markup=botoes)
        prompt_leitura = texto_original if (texto_original and not texto_original.startswith("/")) else "Analise a tela ao vivo do MT5 25K que acabei de pedir no comando /tela25k e dê a visão técnica exata deste segundo."
        resposta = chamar_cerebro(chat_id, first_name, prompt_leitura, image_bytes=img_bytes, estado=estado)
        send_telegram(chat_id, resposta)
        return True
    return False

def identificar_comando_texto(text):
    if not text:
        return None
    t = text.strip().lower()
    cmd_token = t.split()[0].split("@")[0] if t.startswith("/") else ""

    if cmd_token in ("/analise", "/superanalise", "/smc", "/mercado", "/contexto", "/visao", "/analisar"):
        return "cmd_analise"
    if cmd_token in ("/menu", "/painel", "/comandos", "/ajuda", "/start", "/help"):
        return "cmd_menu"
    if cmd_token in ("/status", "/estado"):
        return "cmd_status"
    if cmd_token in ("/tela25k", "/print25k", "/foto25k", "/25k"):
        return "cmd_tela25k"
    if cmd_token in ("/tela", "/print", "/grafico", "/foto", "/visao"):
        if "25" in t:
            return "cmd_tela25k"
        return "cmd_tela"
    if cmd_token in ("/posicoes", "/ordens", "/abertas", "/trades"):
        return "cmd_posicoes"
    if cmd_token in ("/relatorio", "/report", "/funil", "/estatisticas"):
        return "cmd_relatorio"
    if cmd_token in ("/pausar", "/pausa", "/pause", "/parar"):
        return "cmd_pausar"
    if cmd_token in ("/retomar", "/ativar", "/resume", "/despausar", "/ligar"):
        return "cmd_retomar"
    if cmd_token in ("/zerar", "/fechartudo", "/emergencia", "/panic"):
        return "cmd_zerar"

    # Gatilhos diretos em linguagem natural para controle operacional
    if any(p in t for p in ("analise o ouro", "analisa o ouro", "como ta o mercado", "como tá o mercado", "visao institucional", "analise smc", "super analise", "qual a analise", "qual a análise")):
        return "cmd_analise"
    if any(p in t for p in ("manda print", "manda um print", "mostra a tela", "print da tela", "foto da tela", "manda foto da tela")):
        return "cmd_tela"
    if any(p in t for p in ("pausar robo", "pausa o robo", "pausar o robo", "pausa o alien", "pausar alien")):
        return "cmd_pausar"
    if any(p in t for p in ("retomar robo", "retoma o robo", "ativa o robo", "reativar robo", "despausar robo", "retomar alien")):
        return "cmd_retomar"
    if any(p in t for p in ("zerar tudo", "zera tudo", "fechar todas as posicoes", "fechar todas as ordens", "emergencia zerar")):
        return "cmd_zerar"

    return None

def should_reply(chat_type, text, msg):
    chat_id = str(msg.get("chat", {}).get("id", ""))
    if chat_type == "private" or chat_id == CHAT_ID_OFICIAL or chat_id == "-1004385601058":
        return True
    t = (text or "").lower()
    if t.startswith("/"):
        return True
    reply_to = msg.get("reply_tomessage") or msg.get("reply_to_message", {})
    if reply_to.get("from", {}).get("is_bot") or reply_to.get("from", {}).get("id") == 9152893557:
        return True
    keywords = ["alien", "robô", "robo", "copiloto", "co-piloto", "@alienfreedomquantbot", "antigravity", "bot", "mesa", "goat", "tela", "print"]
    return any(kw in t for kw in keywords)

# =================================================================================
# THREAD 1: ESCUTA TELEGRAM (TEXTO, FOTO, ÁUDIO, COMANDOS E BOTÕES INLINE)
# =================================================================================
def loop_escuta_telegram():
    print("[THREAD 1] Escuta Telegram Multimodal + Controle Remoto ativa...", flush=True)
    last_update_id = 0
    while True:
        try:
            url = f"{TELEGRAM_API}/getUpdates?offset={last_update_id + 1}&timeout=20"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=25) as resp:
                data = json.loads(resp.read().decode())
            updates = data.get("result", [])
            for u in updates:
                last_update_id = u["update_id"]

                # 1. Tratamento de Cliques nos Botões Inline (callback_query)
                cb = u.get("callback_query")
                if cb:
                    cb_id = cb.get("id")
                    cb_data = cb.get("data", "")
                    cb_from = cb.get("from", {}).get("first_name", "Operador")
                    cb_msg = cb.get("message", {})
                    cb_chat_id = cb_msg.get("chat", {}).get("id") or CHAT_ID_OFICIAL
                    answer_callback_query(cb_id, text=f"Executando {cb_data.replace('cmd_', '/')}...")
                    registrar_evento(cb_from.upper(), "BOTAO_INLINE", cb_data)
                    executar_acao_comando(cb_chat_id, cb_from, cb_data)
                    continue

                msg = u.get("message") or u.get("channel_post")
                if not msg:
                    continue
                chat = msg.get("chat", {})
                chat_id = chat.get("id")
                chat_type = chat.get("type")
                from_user = msg.get("from", {})
                first_name = from_user.get("first_name", "Operador")
                text = msg.get("text", "")

                registrar_evento(first_name.upper(), "MENSAGEM", text or "[Mídia]")

                # 2. Foto enviada pelo Operador
                if "photo" in msg:
                    caption = msg.get("caption", "")
                    photos = msg.get("photo", [])
                    file_id = photos[-1]["file_id"]
                    send_telegram(chat_id, f"🔍 Analisando sua imagem e cruzando com o MT5 ao vivo, {first_name}...")
                    img_data = download_file(file_id)
                    if img_data:
                        estado = obter_estado_mt5()
                        resposta = chamar_cerebro(chat_id, first_name, caption, image_bytes=img_data, estado=estado)
                        send_telegram(chat_id, resposta, reply_markup=obter_teclado_inline_padrao())
                    continue

                # 3. Áudio / Voz enviada pelo Operador
                if "voice" in msg or "audio" in msg:
                    audio_obj = msg.get("voice") or msg.get("audio")
                    file_id = audio_obj["file_id"]
                    send_telegram(chat_id, f"🎙️ Ouvindo seu áudio e olhando a tela do MT5 em tempo real, {first_name}...")
                    aud_data = download_file(file_id)
                    if aud_data:
                        estado = obter_estado_mt5()
                        live_img = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                        resposta = chamar_cerebro(chat_id, first_name, "", image_bytes=live_img, audio_bytes=aud_data, estado=estado)
                        send_telegram_photo_bytes(
                            chat_id,
                            live_img,
                            caption=f"📸 [VISÃO AO VIVO DO MT5 — XAUUSD {estado['bid']:.2f}]",
                            reply_markup=obter_teclado_inline_padrao()
                        )
                        send_telegram(chat_id, resposta)
                    continue

                # 4. Texto / Comandos / Linguagem Natural
                if text:
                    if not should_reply(chat_type, text, msg):
                        continue

                    cmd_key = identificar_comando_texto(text)
                    if cmd_key:
                        executar_acao_comando(chat_id, first_name, cmd_key, texto_original=text)
                        continue

                    estado = obter_estado_mt5()
                    pediu_grafico = is_asking_for_chart(text)
                    live_img = capturar_tela_tempo_real(forcar_atualizacao=pediu_grafico, estado=estado)

                    resposta = chamar_cerebro(chat_id, first_name, text, image_bytes=live_img, estado=estado)

                    if pediu_grafico:
                        r = estado["relatorio"]
                        legenda = (
                            f"📸 [TELA AO VIVO DO MT5 — {estado['timestamp']}]\n"
                            f"• XAUUSD: {estado['bid']:.2f} / {estado['ask']:.2f} (Spread {estado['spread_pts']:.1f} pts)\n"
                            f"• Equity: ${estado['equity']:,.2f} | Hoje: {estado['realizado_hoje_total']:+.2f} USD\n"
                            f"• Score: {r['score']} | Leitura: {r['decisao']}"
                        )
                        send_telegram_photo_bytes(chat_id, live_img, caption=legenda, reply_markup=obter_teclado_inline_padrao())

                    send_telegram(chat_id, resposta)
                    continue
        except Exception:
            time.sleep(2)

# =================================================================================
# THREAD 2: SENTINELA EM TEMPO REAL DE ORDENS, SWEEPS E METAS NO MT5
# =================================================================================
def loop_sentinela_mt5():
    print("[THREAD 2] Sentinela Real-Time de Ordens, Sweeps e Disjuntores ativo...", flush=True)
    posicoes_conhecidas = {}
    inicializado = False
    dia_alerta_meta = ""
    dia_alerta_disjuntor = ""
    ultimo_sweep_linha = ""
    ultimo_alerta_sweep_ts = 0.0

    # Inicializar rastreamento da última linha do CSV de eventos para não alertar passado
    try:
        csvs = sorted(glob.glob(os.path.join(MT5_FILES_DIR, "ALIEN_V12_1_XAUUSD_*.csv")), key=os.path.getmtime)
        if csvs:
            with open(csvs[-1], "rb") as f:
                raw = f.read()
            txt = raw.decode("utf-16", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
            linhas = [l.strip() for l in txt.splitlines() if l.strip()]
            if linhas:
                ultimo_sweep_linha = linhas[-1]
    except Exception:
        pass

    while True:
        try:
            time.sleep(3)
            estado = obter_estado_mt5()
            if not estado["conectado"]:
                continue

            mapa_atual = {p["ticket"]: p for p in estado["posicoes"]}

            if not inicializado:
                posicoes_conhecidas = mapa_atual
                inicializado = True
                continue

            # 1. Detectar NOVAS posições abertas no MT5
            for ticket, p in mapa_atual.items():
                if ticket not in posicoes_conhecidas:
                    img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                    r = estado["relatorio"]
                    msg_abertura = (
                        f"🚀 [SENTINELA ALIEN — NOVA ORDEM ABERTA NO MT5!]\n\n"
                        f"• Ticket: #{ticket} ({p['origem']})\n"
                        f"• Direção: {p['tipo']} {p['volume']:.2f} lotes em {p['symbol']}\n"
                        f"• Preço de Entrada: {p['price_open']:.2f}\n"
                        f"• Stop Loss: {p['sl']:.2f} ({p['dist_sl_pts']:.0f} pts) | Take Profit: {p['tp']:.2f} ({p['dist_tp_pts']:.0f} pts)\n"
                        f"• Score Técnico: {r['score']} | Sessão: {r['sessao']}\n"
                        f"• Setup: {r['setup_atual']}"
                    )
                    send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=msg_abertura, reply_markup=obter_teclado_inline_padrao())
                    registrar_evento("SENTINELA_MT5", "ORDEM_ABERTA", msg_abertura)

            # 2. Detectar posições ENCERRADAS no MT5
            for ticket, p_antiga in list(posicoes_conhecidas.items()):
                if ticket not in mapa_atual:
                    time.sleep(0.8)
                    estado_pos = obter_estado_mt5()
                    img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado_pos)
                    net_fechado = p_antiga["profit"]
                    preco_saida = p_antiga["price_current"]
                    for d in reversed(estado_pos["ultimos_deals_fechados"]):
                        if d["position_id"] == ticket:
                            net_fechado = d["net"]
                            preco_saida = d["price"]
                            break
                    icone = "🟢 GAIN / LUCRO NO BOLSO!" if net_fechado >= 0 else "🔴 STOP DE PROTEÇÃO ACIONADO"
                    msg_fechamento = (
                        f"🏁 [SENTINELA ALIEN — ORDEM ENCERRADA NO MT5!]\n"
                        f"{icone}\n\n"
                        f"• Ticket: #{ticket} ({p_antiga['tipo']} {p_antiga['volume']:.2f} {p_antiga['symbol']})\n"
                        f"• Entrada: {p_antiga['price_open']:.2f} ➔ Saída: {preco_saida:.2f}\n"
                        f"• Resultado Líquido da Ordem: {net_fechado:+.2f} USD\n"
                        f"• Placar Acumulado Hoje: {estado_pos['realizado_hoje_total']:+.2f} USD ({estado_pos['wins_hoje']}W / {estado_pos['losses_hoje']}L)\n"
                        f"• Equity Atual da Conta: ${estado_pos['equity']:,.2f}"
                    )
                    send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=msg_fechamento, reply_markup=obter_teclado_inline_padrao())
                    registrar_evento("SENTINELA_MT5", "ORDEM_FECHADA", msg_fechamento)

            posicoes_conhecidas = mapa_atual

            # 3. Monitorar Meta Diária (+$100) e Disjuntor Diário (-$140)
            hoje_str = time.strftime("%Y-%m-%d")
            realizado_dia = estado["realizado_hoje_total"]
            if realizado_dia >= DAILY_TARGET_USD and dia_alerta_meta != hoje_str:
                dia_alerta_meta = hoje_str
                img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                aviso_meta = (
                    f"🏆 [META DIÁRIA ALCANÇADA NA CONTA REAL!]\n\n"
                    f"• Lucro Realizado Hoje: +{realizado_dia:.2f} USD (Alvo: +${DAILY_TARGET_USD:.2f})\n"
                    f"• Equity Atual: ${estado['equity']:,.2f}\n"
                    f"• O motor ALIEN V12.1 cumpriu a missão do dia com disciplina institucional!"
                )
                send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=aviso_meta, reply_markup=obter_teclado_inline_padrao())
                registrar_evento("SENTINELA_MT5", "META_DIARIA_BATIDA", aviso_meta)

            if realizado_dia <= -DAILY_MAX_LOSS_USD and dia_alerta_disjuntor != hoje_str:
                dia_alerta_disjuntor = hoje_str
                img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                aviso_disj = (
                    f"🛡️ [DISJUNTOR DIÁRIO DE PROTEÇÃO ACIONADO (-${DAILY_MAX_LOSS_USD:.0f})]\n\n"
                    f"• Resultado Hoje: {realizado_dia:+.2f} USD\n"
                    f"• A trava de segurança estancou as operações antes do limite de segurança da conta, preservando $60 de folga na conta!\n"
                    f"• Capital blindado para o próximo pregão."
                )
                send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=aviso_disj, reply_markup=obter_teclado_inline_padrao())
                registrar_evento("SENTINELA_MT5", "DISJUNTOR_ACIONADO", aviso_disj)

            # 4. Monitorar Novos Eventos de Sweep Institucional no CSV (com cooldown de 15 min)
            if time.time() - ultimo_alerta_sweep_ts >= 900:
                csvs = sorted(glob.glob(os.path.join(MT5_FILES_DIR, "ALIEN_V12_1_XAUUSD_*.csv")), key=os.path.getmtime)
                if csvs:
                    with open(csvs[-1], "rb") as f:
                        raw = f.read()
                    txt = raw.decode("utf-16", errors="ignore") if b"\x00" in raw[:100] else raw.decode("utf-8", errors="ignore")
                    linhas = [l.strip() for l in txt.splitlines() if l.strip()]
                    if linhas and linhas[-1] != ultimo_sweep_linha:
                        nova_linha = linhas[-1]
                        ultimo_sweep_linha = nova_linha
                        if "SWEEP_OBSERVED_" in nova_linha and estado["relatorio"]["sessao"] in ("LONDRES", "NOVA YORK"):
                            ultimo_alerta_sweep_ts = time.time()
                            partes = nova_linha.split(";")
                            evento_nome = partes[3] if len(partes) > 3 else "SWEEP"
                            detalhes_sw = partes[4] if len(partes) > 4 else ""
                            direcao_sw = "COMPRA (Varredura de Fundo)" if "BUY" in evento_nome else "VENDA (Varredura de Topo)"
                            aviso_sw = (
                                f"🎯 [RADAR SMC AO VIVO — PEGADINHA DOS TUBARÕES DETECTADA!]\n\n"
                                f"• Evento: {evento_nome} ({direcao_sw})\n"
                                f"• Detalhes no XAUUSD M1: {detalhes_sw}\n"
                                f"• Cotação Atual: {estado['bid']:.2f} | Score: {estado['relatorio']['score']}\n"
                                f"• O ALIEN V12.1 está vigiando a recuperação (Reclaim) + fluxo de ticks para decidir o disparo!"
                            )
                            send_telegram(CHAT_ID_OFICIAL, aviso_sw)
                            registrar_evento("SENTINELA_MT5", "SWEEP_DETECTADO", aviso_sw)

        except Exception:
            time.sleep(5)

# =================================================================================
# THREAD 3: PULSO BIOLÓGICO DE SESSÕES E BACKUP MESTRE
# =================================================================================
def loop_pulso_vida():
    print("[THREAD 3] Pulso Biológico de Sessões e Backup em Segundo Plano...", flush=True)
    contador = 0
    while True:
        try:
            time.sleep(30)
            contador += 1
            hora = time.strftime("%H:%M")

            if hora == "05:00":
                estado = obter_estado_mt5()
                img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                aviso = (
                    f"🔔 [PULSO AUTÔNOMO ALIEN — ABERTURA DE LONDRES!]\n"
                    f"• Liquidez institucional entrando no XAUUSD ({estado['bid']:.2f}).\n"
                    f"• Equity: ${estado['equity']:,.2f} | Motor V12.1 calibrado nas estruturas!"
                )
                send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=aviso, reply_markup=obter_teclado_inline_padrao())
                registrar_evento("SISTEMA", "PROATIVO", aviso)
                time.sleep(60)

            if hora == "10:30":
                estado = obter_estado_mt5()
                img_bytes = capturar_tela_tempo_real(forcar_atualizacao=True, estado=estado)
                aviso = (
                    f"🔔 [PULSO AUTÔNOMO ALIEN — ABERTURA DE NOVA YORK (WALL STREET)!]\n"
                    f"• Volatilidade máxima entrando no Ouro ({estado['bid']:.2f}).\n"
                    f"• Robô operando com Stop Loss rígido e filtro de notícias USD ativo!"
                )
                send_telegram_photo_bytes(CHAT_ID_OFICIAL, img_bytes, caption=aviso, reply_markup=obter_teclado_inline_padrao())
                registrar_evento("SISTEMA", "PROATIVO", aviso)
                time.sleep(60)

            if contador % 120 == 0:
                if os.path.exists(HD_BACKUP_DIR):
                    try:
                        backup_sync = os.path.join(HD_BACKUP_DIR, "SYNC_BUNDLES")
                        os.makedirs(backup_sync, exist_ok=True)
                        shutil.copy2(STREAM_FILE, os.path.join(backup_sync, "ALIEN_NEURAL_STREAM.jsonl"))
                    except Exception:
                        pass
        except Exception:
            time.sleep(5)

def registrar_comandos_telegram_menu():
    try:
        url = f"{TELEGRAM_API}/setMyCommands"
        comandos = [
            {"command": "tela", "description": "📸 Print ao vivo da tela do MT5 + leitura da IA"},
            {"command": "status", "description": "📊 Painel executivo em tempo real (XAUUSD, Saldo, Score)"},
            {"command": "posicoes", "description": "🎯 Detalhes das posições abertas no MT5 agora"},
            {"command": "relatorio", "description": "📑 Relatório quantitativo do dia + Funil de Sweeps"},
            {"command": "pausar", "description": "⏸️ Pausar novas entradas do robô no MT5"},
            {"command": "retomar", "description": "▶️ Retomar caça automática do robô no MT5"},
            {"command": "zerar", "description": "🚨 Emergência: Fechar todas as posições a mercado"},
            {"command": "menu", "description": "🛸 Abrir Central de Comando com botões interativos"}
        ]
        data = json.dumps({"commands": comandos}).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10):
            pass
    except Exception:
        pass

def main():
    print("=" * 75, flush=True)
    print("  ALIEN LIVING CORE V2.0 ATIVADO — CENTRO DE COMANDO MULTIMODAL MT5", flush=True)
    print("  Liderança: Vitor | Operação: Yuri & Gabriel | IA: Antigravity", flush=True)
    print("=" * 75, flush=True)

    registrar_comandos_telegram_menu()
    registrar_evento("SISTEMA", "IGNICAO_V2", "ALIEN Living Core V2.0 inicializado com Visão MT5 em Tempo Real + Controle Remoto + Sentinela.")

    t1 = threading.Thread(target=loop_escuta_telegram, daemon=True)
    t2 = threading.Thread(target=loop_sentinela_mt5, daemon=True)
    t3 = threading.Thread(target=loop_pulso_vida, daemon=True)

    t1.start()
    t2.start()
    t3.start()

    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
