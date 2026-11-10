import urllib.request
import json
import os

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
DOC_PATH = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"

caption = """🚀 [ATUALIZAÇÃO MASTER: ALIEN V12.1 INSTITUTIONAL COM NOTÍCIAS]

Comandante Vitor e Yuri, o robô foi atualizado para a versão 12.1:
1. 🛡️ FILTRO NATIVO DE NOTÍCIAS DO MT5: Bloqueia automaticamente ordens 15 minutos antes e depois de notícias vermelhas dos EUA (USD - NFP, CPI, FED).
2. 📊 HUD ATUALIZADO: Mostra em tempo real a linha [NOTICIAS: LIVRE/BLOQUEIO].
3. 🔧 CORREÇÃO DO DIÁRIO: 0 erros de log.
4. ⚙️ BLINDAGENS MANTIDAS: Disjuntor Goat -$140, Breakeven $0.60 no Ouro e Trava de Sexta-feira.

O executável .ex5 está anexado acima e pronto no MT5!"""

url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

with open(DOC_PATH, "rb") as f:
    doc_bytes = f.read()

body = bytearray()
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{CHAT_ID}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="document"; filename="ALIEN_V12_1_INSTITUTIONAL.ex5"\r\n'.encode("utf-8"))
body.extend(b"Content-Type: application/octet-stream\r\n\r\n")
body.extend(doc_bytes)
body.extend(b"\r\n")
body.extend(f"--{boundary}--\r\n".encode("utf-8"))

req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
with urllib.request.urlopen(req) as resp:
    res = json.loads(resp.read().decode())
    print("V12.1 enviado com sucesso para o Telegram! Message ID:", res["result"]["message_id"])
