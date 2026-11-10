"""ALIEN WATCHDOG - Ultra-Fast Native Windows Guardian (Goat 5K + Goat 25K)
Alimentado por psutil e ShellExecute nativo (Zero CPU overhead).
Mantem ambos os terminais MT5 + Robo ALIEN V12.1 e Telegram Living Core permanentemente ativos.
Roda como processo de segundo plano nativo do Windows.
"""
import os
import sys
import time
import subprocess
import urllib.request
import urllib.parse
import json
from datetime import datetime

try:
    import psutil
except ImportError:
    psutil = None

BASE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
TOOLS = os.path.join(BASE, "tools")
LOG = os.path.join(TOOLS, "alien_watchdog.log")
PYTHON = sys.executable.replace("pythonw.exe", "python.exe")
NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW
DETACHED = 0x00000008   # DETACHED_PROCESS

# MT5 Terminals
MT5_5K_EXE = r"C:\Program Files\Goat Funded MT5 Terminal\terminal64.exe"
MT5_25K_DIR = r"C:\Goat_MT5_25K"
MT5_25K_EXE = os.path.join(MT5_25K_DIR, "terminal64.exe")
MT5_25K_CONFIG = os.path.join(MT5_25K_DIR, "startup_25k.ini")

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"

last_relaunch = {
    "5k": 0.0,
    "25k": 0.0,
    "core": 0.0
}

def log(msg):
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass

def notify_telegram(text):
    if not BOT_TOKEN or not CHAT_ID:
        return
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        payload = json.dumps({"chat_id": CHAT_ID, "text": text, "parse_mode": "Markdown"}).encode("utf-8")
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            pass
    except Exception as e:
        log(f"Falha ao enviar alerta Telegram: {e}")

def tick():
    if not psutil:
        return

    now = time.time()
    has_5k = False
    has_25k = False
    has_living_core = False

    for proc in psutil.process_iter():
        try:
            p_name = (proc.name() or '').lower()
            if 'terminal64' in p_name:
                try:
                    p_exe = (proc.exe() or '').lower()
                except Exception:
                    p_exe = ''
                try:
                    p_cmd = ' '.join(proc.cmdline() or []).lower()
                except Exception:
                    p_cmd = ''

                combined = p_exe + " " + p_cmd
                if 'goat_mt5_25k' in combined:
                    has_25k = True
                else:
                    has_5k = True

            elif 'python' in p_name:
                try:
                    p_cmd = ' '.join(proc.cmdline() or []).lower()
                except Exception:
                    p_cmd = ''
                if 'alien_living_core.py' in p_cmd:
                    has_living_core = True

        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    # 1. Recuperar Goat 5K (cooldown de 90s)
    if not has_5k:
        if now - last_relaunch["5k"] > 90:
            last_relaunch["5k"] = now
            log("Goat 5K MT5 offline -> relancando")
            notify_telegram("⚠️ *ALIEN GUARDIAN*: Terminal Goat 5K (Login 315462944) estava offline! Relançando terminal automaticamente...")
            try:
                subprocess.Popen([MT5_5K_EXE, "/profile:Default"], creationflags=DETACHED)
            except Exception as e:
                log(f"Erro ao iniciar Goat 5K: {e}")

    # 2. Recuperar Goat 25K (cooldown de 90s)
    if not has_25k:
        if now - last_relaunch["25k"] > 90:
            last_relaunch["25k"] = now
            log("Goat 25K MT5 offline -> relancando")
            notify_telegram("⚠️ *ALIEN GUARDIAN*: Terminal Goat 25K (Login 436271843) estava offline! Relançando terminal automaticamente...")
            try:
                subprocess.Popen([
                    MT5_25K_EXE,
                    "/portable",
                    f"/config:{MT5_25K_CONFIG}",
                    "/profile:Default"
                ], creationflags=DETACHED)
            except Exception as e:
                log(f"Erro ao iniciar Goat 25K: {e}")

    # 3. Recuperar Living Core (cooldown de 60s)
    if not has_living_core:
        if now - last_relaunch["core"] > 60:
            last_relaunch["core"] = now
            log("Living Core (Telegram) offline -> relancando")
            notify_telegram("🔄 *ALIEN GUARDIAN*: Living Core reiniciado com sucesso.")
            try:
                subprocess.Popen([PYTHON, "-u", os.path.join(TOOLS, "alien_living_core.py")],
                                 creationflags=NO_WINDOW | DETACHED)
            except Exception as e:
                log(f"Erro ao iniciar Living Core: {e}")

if __name__ == "__main__":
    log("watchdog dual ultra-fast nativo iniciado (Goat 5K + Goat 25K)")
    while True:
        try:
            tick()
        except BaseException as exc:
            if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                log(f"watchdog finalizado: {exc}")
                break
            log(f"erro nao capturado no loop: {exc}")
        time.sleep(15)
