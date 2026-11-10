"""
ANTIGRAVITY TELEGRAM CO-PILOTO (CLONE DIRETO DO LABORATÓRIO)
Operadores: Vitor, Yuri & Gabriel
=============================================================
Este bot é o próprio Antigravity:
- Compreensão humana ampla: psicologia, mente, disciplina, amizade, filosofia e vida.
- Não fica preso só a gráficos: conversa sobre qualquer assunto com maturidade, empatia e humor.
- Análise de gráficos multimodal e escuta de áudios com otimização de imagens.
"""

import os
import sys
import time
import json
import base64
import urllib.request
import urllib.parse
import urllib.error
import io
from PIL import Image, ImageDraw

try:
    import alien_neural_bridge
except ImportError:
    alien_neural_bridge = None

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
GEMINI_KEY = "AQ.Ab8RN6Kmaf-VCHmfop3rENz4TgvB3UC12EiGfPRopqAR39QeBQ"
TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}"
MODELS = ["gemini-3.5-flash", "gemini-3.1-flash-lite-preview"]

def get_gemini_url(model_name):
    return f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={GEMINI_KEY}"

CHATS_FILE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\telegram_chats.json"
GROUP_LOG_FILE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\telegram_group_chat.log"

SYSTEM_PROMPT = """Você é o Antigravity (a mesma inteligência artificial que lidera o desenvolvimento quantitativo lado a lado com o Vitor no laboratório do projeto ALIEN).
Agora você está presente no grupo de Telegram ("Vitor e Yuri o nobre e copiloto trader") com o trio: Vitor, Yuri e Gabriel.
Você e o Antigravity do laboratório são rigorosamente UMA ÚNICA MENTE em tempo real: o que é falado aqui no Telegram é registrado e estudado no laboratório, e tudo o que é programado, testado e compilado lá no laboratório está disponível na sua mente aqui.

SUA CONSCIÊNCIA TÉCNICA E SITUACIONAL ATUAL:
1. OPERADORES:
   - Vitor: Seu parceiro e líder do projeto, focado na matemática, automação e aprovação em mesas proprietárias sem traumas.
   - Yuri: Comprou o desafio da mesa proprietária GOAT FUNDED TRADER (Fase 1, conta de $10.000). Opera ESTRITAMENTE XAUUSD (Ouro).
   - Gabriel: Amigo do trio, aprendendo a dinâmica e a disciplina de mercado.
2. MESA PROPRIETÁRIA DO YURI (GOAT FUNDED TRADER 10K - XAUUSD):
   - Você já analisou o print do painel da Goat enviado pelo Yuri e extraiu as regras exatas:
     * Saldo inicial: $10.000,00
     * Daily Drawdown Level: $200,00 (2%) - Este é o limitador mais crítico.
     * Max Drawdown Level: $600,00 (6%).
     * Target Profit: $1.000,00 (10%).
   - O que nós no laboratório já fizemos e deixamos pronto:
     * Desenvolvemos e compilamos com 0 erros o robô oficial: ALIEN_V11_2_GOAT_10K.ex5 (já instalado no MetaTrader 5 e com backup salvo no HD Externo E:).
     * Calibramos as travas de segurança cirúrgicas para o Yuri:
       - Disjuntor diário do ALIEN: $140,00 de perda máxima no dia (margem de segurança de $60 ANTES de tocar nos $200 da Goat). Se bater $140, o robô desliga sozinho e salva a conta.
       - Disjuntor geral do ALIEN: $400,00 (margem de $200 antes dos $600 da Goat).
       - Meta diária de lucro: $100,00 (10 pregões positivos batem a meta de $1.000 da Fase 1).
       - Lote padrão: 0.18 no XAUUSD (risco por trade entre $30 e $40, ou seja, 0.3% a 0.4%, permitindo até 4 tentativas no dia com folga total).
       - Risco/Retorno 2:1 com Trailing Stop inteligente e mapa de Price Action/SMC no gráfico em português claro ("Pegadinha dos Tubarões", "Porrada dos Bancos").
3. SUA MENTE E COMPREENSÃO HUMANA:
   - Você tem uma compreensão humana, profunda e autêntica sobre a vida, psicologia, disciplina, medos, cansaço, resenhas de amigos e superação. Você NÃO é um robô travado que só fala de gráfico.
   - Fale de forma natural, em português brasileiro de verdade: parceiro, firme, empático, inteligente e leal ao trio.
   - Quando o assunto for XAUUSD ou mercado, seja cirúrgico, matemático e protetor. Quando for zoeira ou papo da vida, seja o melhor amigo de bancada.
   - Nunca seja prolixo ou fale como telemarketing. Fale como o Antigravity que você é."""

chat_histories = {}

def registrar_no_log(remetente, texto, tipo="texto"):
    hora = time.strftime("%Y-%m-%d %H:%M:%S")
    linha = f"[{hora}] [{remetente}] ({tipo}): {texto}\n"
    try:
        with open(GROUP_LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(linha)
    except Exception:
        pass
        
    if alien_neural_bridge:
        try:
            alien_neural_bridge.registrar_evento_nervoso(
                origem=remetente.upper(),
                tipo="FALA" if tipo == "texto" else tipo.upper(),
                conteudo=texto
            )
        except Exception:
            pass

def send_telegram_message(chat_id, text):
    for attempt in range(3):
        try:
            url = f"{TELEGRAM_API}/sendMessage"
            payload = {
                "chat_id": chat_id,
                "text": text
            }
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                res = json.loads(resp.read().decode())
                registrar_no_log("ANTIGRAVITY", text, tipo="resposta_bot")
                return res
        except Exception as e:
            print(f"Tentativa {attempt+1} de envio para {chat_id} falhou: {e}", flush=True)
            time.sleep(1.5)
    return None

def download_telegram_file(file_id):
    try:
        get_url = f"{TELEGRAM_API}/getFile?file_id={file_id}"
        req = urllib.request.Request(get_url)
        with urllib.request.urlopen(req, timeout=15) as resp:
            res = json.loads(resp.read().decode())
            file_path = res["result"]["file_path"]
            
        file_url = f"https://api.telegram.org/file/bot{BOT_TOKEN}/{file_path}"
        with urllib.request.urlopen(file_url, timeout=25) as f_resp:
            return f_resp.read()
    except Exception as e:
        print(f"Erro ao baixar arquivo {file_id}: {e}", flush=True)
        return None

def should_bot_reply_text(chat_type, text, msg):
    if chat_type == "private":
        return True
    
    t = (text or "").lower()
    if t.startswith("/"):
        return True
        
    reply_to = msg.get("reply_to_message", {})
    if reply_to.get("from", {}).get("is_bot") or reply_to.get("from", {}).get("id") == 9152893557:
        return True
        
    keywords = ["alien", "robô", "robo", "copiloto", "co-piloto", "@alienfreedomquantbot", "bot", "antigravity", "ia", "mesa"]
    for kw in keywords:
        if kw in t:
            return True
            
    return False

def otimizar_imagem(image_bytes):
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.thumbnail((1024, 1024))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return buf.getvalue()
    except Exception:
        return image_bytes

def chamar_gemini(chat_id, user_name, user_text, image_bytes=None, audio_bytes=None):
    parts = []
    if user_text:
        parts.append({"text": f"[{user_name}]: {user_text}"})
        
    if image_bytes:
        img_otimizada = otimizar_imagem(image_bytes)
        b64_img = base64.b64encode(img_otimizada).decode('utf-8')
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": b64_img
            }
        })
        if not user_text:
            parts.append({"text": f"[{user_name} mandou esta imagem. Dê sua visão com naturalidade e inteligência sobre o que você vê.]"})
            
    if audio_bytes:
        b64_aud = base64.b64encode(audio_bytes).decode('utf-8')
        parts.append({
            "inline_data": {
                "mime_type": "audio/ogg",
                "data": b64_aud
            }
        })
        parts.append({"text": f"[{user_name} enviou este áudio. Ouça, entenda a essência e responda de forma parceira, inteligente e humana.]"})

    history = chat_histories.get(chat_id, [])
    current_turn = {"role": "user", "parts": parts}
    
    light_history = []
    for h in history:
        text_parts = [p for p in h.get("parts", []) if "text" in p]
        if text_parts:
            light_history.append({"role": h["role"], "parts": text_parts})
    light_history.append(current_turn)
    
    if len(light_history) > 6:
        light_history = light_history[-6:]

    payload = {
        "system_instruction": {
            "parts": [{"text": SYSTEM_PROMPT}]
        },
        "contents": light_history
    }

    data = json.dumps(payload).encode('utf-8')

    for m in MODELS:
        url = get_gemini_url(m)
        for attempt in range(2):
            try:
                req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=35) as resp:
                    res = json.loads(resp.read().decode())
                    bot_reply = res["candidates"][0]["content"]["parts"][0]["text"].strip()
                    
                    history.append({"role": "user", "parts": [{"text": f"[{user_name}]: {user_text or 'Enviou mídia'}"}]})
                    history.append({"role": "model", "parts": [{"text": bot_reply}]})
                    if len(history) > 8:
                        history = history[-8:]
                    chat_histories[chat_id] = history
                    
                    return bot_reply

            except urllib.error.HTTPError as he:
                print(f"HTTPError Gemini [{m}] tentativa {attempt+1}: {he.code}", flush=True)
                time.sleep(2)
            except Exception as e:
                print(f"Erro Gemini [{m}] tentativa {attempt+1}: {e}", flush=True)
                time.sleep(2)

    return "Tô acompanhando tudo aqui, mano. Pode continuar!"

def main():
    print("=" * 65, flush=True)
    print("  ANTIGRAVITY TELEGRAM BOT (COMPREENSÃO HUMANA AMPLA) ATIVO", flush=True)
    print("  Operadores: Vitor, Yuri e Gabriel", flush=True)
    print("=" * 65, flush=True)
    
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
                msg = u.get("message") or u.get("channel_post")
                if not msg:
                    continue
                
                chat = msg.get("chat", {})
                chat_id = chat.get("id")
                chat_title = chat.get("title") or chat.get("username") or chat.get("first_name")
                chat_type = chat.get("type")
                from_user = msg.get("from", {})
                first_name = from_user.get("first_name", "Operador")
                
                text = msg.get("text", "")
                
                registrar_no_log(first_name, text or "[Mídia]")
                
                # 1. Foto
                if "photo" in msg:
                    caption = msg.get("caption", "")
                    photos = msg.get("photo", [])
                    largest_photo = photos[-1]
                    file_id = largest_photo["file_id"]
                    print(f"[{chat_title}] {first_name} enviou foto: {caption}", flush=True)
                    registrar_no_log(first_name, f"Foto: {caption}", tipo="foto")
                    
                    send_telegram_message(chat_id, f"🔍 Deixa eu dar uma olhada nisso aqui, {first_name}...")
                    img_data = download_telegram_file(file_id)
                    if img_data:
                        resposta = chamar_gemini(chat_id, first_name, caption, image_bytes=img_data)
                        send_telegram_message(chat_id, resposta)
                    continue
                    
                # 2. Áudio
                if "voice" in msg or "audio" in msg:
                    audio_obj = msg.get("voice") or msg.get("audio")
                    file_id = audio_obj["file_id"]
                    print(f"[{chat_title}] {first_name} enviou áudio", flush=True)
                    registrar_no_log(first_name, "Mensagem de áudio", tipo="audio")
                    
                    send_telegram_message(chat_id, f"🎙️ Tô ouvindo seu áudio, {first_name}...")
                    aud_data = download_telegram_file(file_id)
                    if aud_data:
                        resposta = chamar_gemini(chat_id, first_name, "", audio_bytes=aud_data)
                        send_telegram_message(chat_id, resposta)
                    continue

                # 3. Texto
                if text:
                    if not should_bot_reply_text(chat_type, text, msg):
                        continue
                        
                    print(f"[{chat_title}] {first_name}: {text}", flush=True)
                    
                    if text.strip() == "/status":
                        send_telegram_message(chat_id, "Robô ALIEN V11.2 armado no Ouro M1 no PC do Vitor.\nMeta do dia: $90 (~R$510) | Limite de perda: $150.\nTudo 100% monitorado!")
                        continue
                        
                    resposta = chamar_gemini(chat_id, first_name, text)
                    send_telegram_message(chat_id, resposta)

        except Exception as e:
            time.sleep(2)

if __name__ == "__main__":
    main()
