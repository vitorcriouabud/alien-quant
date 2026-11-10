import urllib.request
import json
import os

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
PHOTO_PATH = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Files\ALIEN_LIVE_CONFLUENCE.png"

caption = """📊 [LEITURA TÉCNICA AO VIVO - ALIEN V12 NO MT5]

Comandante Vitor, aqui está a visão real do robô no gráfico do XAUUSD M1 agora:

1. ⚖️ Fluxo dos Bancos: CONSOLIDADO (Mercado indeciso).
2. 🎯 Padrão Detectado: Aguardando Pegadinha dos Tubarões (Stop Hunt / Sweep). O robô NÃO entra no meio da consolidação.
3. ⏰ Sessão: Fora da janela de alta liquidez (madrugada asiática). Volatilidade ATR em 175 pts.
4. 🛡️ Gestão: 0 trades abertos, saldo intacto em $9.771,54. Proteções armadas (Trava $140 | Alvo $100).

Resumo: O robô está com o dedo fora do gatilho, esperando o mercado definir a direção ou romper falsamente para buscar liquidez institucional."""

url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto"
boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

with open(PHOTO_PATH, "rb") as f:
    photo_bytes = f.read()

body = bytearray()
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{CHAT_ID}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n'.encode("utf-8"))
body.extend(f"--{boundary}\r\n".encode("utf-8"))
body.extend(f'Content-Disposition: form-data; name="photo"; filename="mt5_live.png"\r\n'.encode("utf-8"))
body.extend(b"Content-Type: image/png\r\n\r\n")
body.extend(photo_bytes)
body.extend(b"\r\n")
body.extend(f"--{boundary}--\r\n".encode("utf-8"))

req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
with urllib.request.urlopen(req) as resp:
    res = json.loads(resp.read().decode())
    print("Foto e leitura técnica enviadas com sucesso! Message ID:", res["result"]["message_id"])
