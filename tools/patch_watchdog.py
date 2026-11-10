"""
Atualiza o alien_watchdog.py para integrar alertas automaticos diretamente no grupo do Telegram.
"""
import re

core_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
watchdog_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.py"

with open(core_path, "r", encoding="utf-8") as f:
    core_text = f.read()

m_tok = re.search(r'BOT_TOKEN\s*=\s*[\'"]([^\'"]+)[\'"]', core_text)
bot_token = m_tok.group(1) if m_tok else ""

m_chat = re.search(r'CHAT_ID_OFICIAL\s*=\s*[\'"]([^\'"]+)[\'"]', core_text)
chat_id = m_chat.group(1) if m_chat else "-1004385601058"

watchdog_code = f'''"""ALIEN WATCHDOG - Guardian 100% Autonomo
Mantem MT5 + Robo, Telegram Living Core e Mission Control sempre de pe.
Roda de forma independente do Antigravity/Chat.
Envia notificacoes no Telegram quando reinicia qualquer servico.
"""
import os
import sys
import time
import socket
import subprocess
import urllib.request
import urllib.parse
import json
from datetime import datetime

BASE = r"C:\\Users\\notebook\\.gemini\\antigravity\\scratch\\ALIEN_LAB"
TOOLS = os.path.join(BASE, "tools")
MT5_EXE = r"C:\\Program Files\\RoboForex MT5 Terminal\\terminal64.exe"
MT5_INI = os.path.join(TOOLS, "LIVE_START_ALIEN_V12_1.ini")
LOG = os.path.join(TOOLS, "alien_watchdog.log")
PYTHON = sys.executable.replace("pythonw.exe", "python.exe")
NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW
DETACHED = 0x00000008   # DETACHED_PROCESS

BOT_TOKEN = "{bot_token}"
CHAT_ID = "{chat_id}"

def log(msg):
    line = f"[{{datetime.now():%Y-%m-%d %H:%M:%S}}] {{msg}}"
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\\n")
    except OSError:
        pass

def notify_telegram(text):
    if not BOT_TOKEN or not CHAT_ID:
        return
    try:
        url = f"https://api.telegram.org/bot{{BOT_TOKEN}}/sendMessage"
        payload = json.dumps({{"chat_id": CHAT_ID, "text": text, "parse_mode": "Markdown"}}).encode("utf-8")
        req = urllib.request.Request(url, data=payload, headers={{"Content-Type": "application/json"}})
        with urllib.request.urlopen(req, timeout=8) as resp:
            pass
    except Exception as e:
        log(f"Falha ao enviar alerta Telegram: {{e}}")

def process_cmdlines(image):
    ps = f"Get-CimInstance Win32_Process -Filter \\"Name=\'{{image}}\'\\" | ForEach-Object {{ $_.CommandLine }}"
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                             capture_output=True, text=True, timeout=25).stdout
    except Exception as exc:
        log(f"erro listando {{image}}: {{exc}}")
        return None
    return [l for l in out.splitlines() if l.strip()]

def port_open(port):
    with socket.socket() as s:
        s.settimeout(2)
        return s.connect_ex(("127.0.0.1", port)) == 0

def start(args):
    subprocess.Popen(args, creationflags=NO_WINDOW | DETACHED, close_fds=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)

def tick():
    mt5 = process_cmdlines("terminal64.exe")
    if mt5 is not None and not any("RoboForex" in c or "terminal64" in c for c in mt5):
        log("MT5 offline -> relancando com ALIEN V12.1")
        notify_telegram("⚠️ *ALIEN GUARDIAN*: MT5 estava offline! Relançando terminal e robô automaticamente...")
        start([MT5_EXE, f"/config:{{MT5_INI}}"])

    py = process_cmdlines("python.exe")
    if py is not None:
        if not any("alien_living_core.py" in c for c in py):
            log("Living Core (Telegram) offline -> relancando")
            notify_telegram("🔄 *ALIEN GUARDIAN*: Bot do Telegram reiniciado com sucesso.")
            start([PYTHON, "-u", os.path.join(TOOLS, "alien_living_core.py")])
        if not any("alien_mission_control.py" in c for c in py) and not port_open(5000):
            log("Mission Control offline -> relancando")
            start([PYTHON, "-u", os.path.join(TOOLS, "alien_mission_control.py")])

if __name__ == "__main__":
    log("watchdog iniciado com alertas telegram")
    notify_telegram("🛡️ *ALIEN GUARDIAN ATIVADO*\\nO sistema agora monitora e auto-recupera MT5, robô e Telegram 24/7 de forma 100% autônoma no Windows.")
    while True:
        try:
            tick()
        except Exception as exc:
            log(f"erro no ciclo: {{exc}}")
        time.sleep(60)
'''

with open(watchdog_path, "w", encoding="utf-8") as f:
    f.write(watchdog_code)

print("alien_watchdog.py atualizado com sucesso!")
