# -*- coding: utf-8 -*-
import urllib.request
import os

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
file_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.ex5"

boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
with open(file_path, "rb") as f:
    file_bytes = f.read()

caption = (
    "🛡️ ALIEN V12 INSTITUTIONAL OFICIAL COMPILADO (0 Erros)\n\n"
    "Versão blindada para a Goat 10K com as 5 proteções ativas:\n"
    "1. Hard Circuit Breaker de flutuação (-$140 zera a mercado)\n"
    "2. Breakeven calibrado no Ouro (60 pts / $0.60 acima do spread)\n"
    "3. Trava de Sexta-feira (Zero risco de Gap de fim de semana)\n"
    "4. Veto Direcional H1 (Nunca opera contra a tendência maior)\n"
    "5. High-Water Mark Trailing DD Guard (Proteção de pico)"
)

body = bytearray()
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{CHAT_ID}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="document"; filename="ALIEN_V12_INSTITUTIONAL.ex5"\r\n'.encode("utf-8"))
body.extend(b"Content-Type: application/octet-stream\r\n\r\n")
body.extend(file_bytes)
body.extend(b"\r\n")
body.extend(f"--{boundary}--\r\n".encode("utf-8"))

req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
with urllib.request.urlopen(req) as resp:
    print("V12 .ex5 enviado com sucesso no Telegram!")
