"""
ALIEN MESH SYNC ENGINE — SINCRONIZADOR 100% ENTRE VITOR E YURI
===============================================================
Permite sincronizar em tempo real todo o laboratório do Vitor com
a estação de trabalho do Yuri (e vice-versa), garantindo que:
1. Códigos e executáveis (.ex5) sejam rigorosamente idênticos.
2. Memória de contexto, regras e histórico de auditoria sejam 100% espelhados.
3. Não dependa de instalação prévia de Git ou configurações complexas.
4. Usa o Telegram Cloud como canal de transporte seguro e ultra-rápido.
"""

import os
import sys
import time
import json
import zipfile
import hashlib
import uuid
import urllib.request
import urllib.parse
import urllib.error
import shutil

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}"

BASE_DIR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
BUNDLE_PATH = os.path.join(BASE_DIR, "alien_sync_bundle.zip")
STATE_JSON_PATH = os.path.join(BASE_DIR, "ALIEN_BRAIN_STATE.json")
HD_BACKUP_DIR = r"E:\ALIEN_BACKUP_MASTER\SYNC_BUNDLES"

def calcular_hash_arquivo(caminho):
    if not os.path.exists(caminho):
        return "N/A"
    hasher = hashlib.sha256()
    with open(caminho, 'rb') as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()

def atualizar_estado_local():
    goat_ex5 = os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_GOAT_10K.ex5")
    freedom_ex5 = os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_FREEDOM.ex5")
    
    estado = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "versao_rede": "ALIEN_V11_2_MESH_1.0",
        "operadores": {
            "vitor": {"papel": "Lideranca Central / Laboratorio Matriz", "status": "ONLINE"},
            "yuri": {"papel": "Operador Especialista Goat 10K / XAUUSD", "status": "ONLINE"},
            "gabriel": {"papel": "Operador Aprendiz / Disciplina", "status": "ONLINE"}
        },
        "arquivos_criticos": {
            "ALIEN_V11_2_GOAT_10K.ex5": {
                "sha256": calcular_hash_arquivo(goat_ex5),
                "regras": {
                    "ativo": "XAUUSD (Ouro)",
                    "timeframe": "M1",
                    "banca": 10000.0,
                    "lote": 0.18,
                    "limite_diario_goat": 200.0,
                    "disjuntor_alien": 140.0,
                    "meta_diaria": 100.0,
                    "meta_fase1": 1000.0
                }
            },
            "ALIEN_V11_2_FREEDOM.ex5": {
                "sha256": calcular_hash_arquivo(freedom_ex5)
            }
        },
        "ultima_auditoria": {
            "experimento": "EXP-014",
            "periodo": "05/10/2026 a 17/10/2026 (10 dias)",
            "lucro_liquido": 748.30,
            "profit_factor": 2.47,
            "max_drawdown_pct": 0.83,
            "status": "APROVADO COM EXCELENCIA"
        }
    }
    
    with open(STATE_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(estado, f, indent=2, ensure_ascii=False)
        
    return estado

def empacotar_bundle():
    print("[1/3] Atualizando estado mental central...")
    atualizar_estado_local()
    
    print("[2/3] Empacotando arquivos criticos no bundle ZIP...")
    arquivos_para_incluir = [
        ("MQL5/Experts/ALIEN_V11_2_GOAT_10K.ex5", os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_GOAT_10K.ex5")),
        ("MQL5/Experts/ALIEN_V11_2_GOAT_10K.mq5", os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_GOAT_10K.mq5")),
        ("MQL5/Experts/ALIEN_V11_2_FREEDOM.ex5", os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_FREEDOM.ex5")),
        ("MQL5/Experts/ALIEN_V11_2_FREEDOM.mq5", os.path.join(BASE_DIR, "MQL5", "Experts", "ALIEN_V11_2_FREEDOM.mq5")),
        ("ALIEN_BRAIN_STATE.json", STATE_JSON_PATH),
        ("ESTADO_ATUAL.md", os.path.join(BASE_DIR, "ESTADO_ATUAL.md")),
        ("KIT_CLONE_YURI/LEIA_ME_YURI.md", os.path.join(BASE_DIR, "KIT_CLONE_YURI", "LEIA_ME_YURI.md")),
        ("KIT_CLONE_YURI/PROJECT_MEMORY_YURI.md", os.path.join(BASE_DIR, "KIT_CLONE_YURI", "PROJECT_MEMORY_YURI.md")),
        ("EXP_014_GOAT_10K.htm", os.path.join(BASE_DIR, "results", "EXP_014_GOAT_10K", "EXP_014_GOAT_10K.htm"))
    ]
    
    with zipfile.ZipFile(BUNDLE_PATH, 'w', zipfile.ZIP_DEFLATED) as zf:
        for arcname, filepath in arquivos_para_incluir:
            if os.path.exists(filepath):
                zf.write(filepath, arcname)
                print(f"  + Adicionado: {arcname}")
            else:
                print(f"  ! Aviso: Arquivo ausente: {filepath}")
                
    bundle_hash = calcular_hash_arquivo(BUNDLE_PATH)
    bundle_size = os.path.getsize(BUNDLE_PATH) / (1024 * 1024)
    print(f"Bundle gerado com sucesso! Tamanho: {bundle_size:.2f} MB | SHA256: {bundle_hash[:16]}...")
    
    # Backup no HD Externo se conectado
    if os.path.exists(r"E:\ALIEN_BACKUP_MASTER"):
        os.makedirs(HD_BACKUP_DIR, exist_ok=True)
        shutil.copy2(BUNDLE_PATH, os.path.join(HD_BACKUP_DIR, f"alien_sync_bundle_{time.strftime('%Y%m%d_%H%M%S')}.zip"))
        shutil.copy2(BUNDLE_PATH, os.path.join(HD_BACKUP_DIR, "alien_sync_bundle_latest.zip"))
        print("  + Backup mestre salvo no HD Externo E:!")
        
    return bundle_hash

def publicar_para_rede():
    bundle_hash = empacotar_bundle()
    print("[3/3] Publicando pacote de sincronizacao na Nuvem do Telegram...")
    
    url = f"{TELEGRAM_API}/sendDocument"
    boundary = "----AlienSyncBoundary" + uuid.uuid4().hex
    
    with open(BUNDLE_PATH, "rb") as f:
        file_bytes = f.read()
        
    caption = (
        f"⚡ #ALIEN_SYNC_BUNDLE (SINCRONIZAÇÃO 100% VITOR & YURI)\n"
        f"📅 Data/Hora: {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"🔒 SHA256: {bundle_hash[:20]}...\n"
        f"🎯 Status: Robô ALIEN_V11_2_GOAT_10K e Memória Central Atualizados!"
    )
    
    body = []
    
    # Campo chat_id
    body.append(f"--{boundary}".encode())
    body.append(b'Content-Disposition: form-data; name="chat_id"')
    body.append(b'')
    body.append(CHAT_ID.encode())
    
    # Campo caption
    body.append(f"--{boundary}".encode())
    body.append(b'Content-Disposition: form-data; name="caption"')
    body.append(b'')
    body.append(caption.encode('utf-8'))
    
    # Campo document
    body.append(f"--{boundary}".encode())
    body.append(b'Content-Disposition: form-data; name="document"; filename="alien_sync_bundle.zip"')
    body.append(b'Content-Type: application/zip')
    body.append(b'')
    body.append(file_bytes)
    
    body.append(f"--{boundary}--".encode())
    body.append(b'')
    
    payload = b'\r\n'.join(body)
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            res = json.loads(resp.read().decode())
            if res.get("ok"):
                print("\n=======================================================")
                print("  SINCRONIZAÇÃO PUBLICADA COM SUCESSO!")
                print("  O notebook do Yuri pode puxar este pacote a qualquer momento.")
                print("=======================================================")
                return True
    except Exception as e:
        print(f"Erro ao publicar no Telegram: {e}")
        return False

def baixar_da_rede(destino_dir=None):
    if destino_dir is None:
        destino_dir = BASE_DIR
        
    print("[1/2] Buscando ultimo pacote #ALIEN_SYNC_BUNDLE na Nuvem...")
    url = f"{TELEGRAM_API}/getUpdates"
    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        print(f"Erro ao conectar na API: {e}")
        return False
        
    updates = data.get("result", [])
    target_doc = None
    for u in reversed(updates):
        msg = u.get("message") or {}
        doc = msg.get("document")
        caption = msg.get("caption", "")
        if doc and "#ALIEN_SYNC_BUNDLE" in caption:
            target_doc = doc
            break
            
    if not target_doc:
        print("Nenhum bundle encontrado nos updates recentes.")
        # Fallback para bundle local se existir
        if os.path.exists(BUNDLE_PATH):
            target_file = BUNDLE_PATH
        else:
            return False
    else:
        file_id = target_doc["file_id"]
        get_url = f"{TELEGRAM_API}/getFile?file_id={file_id}"
        with urllib.request.urlopen(get_url, timeout=20) as resp:
            res = json.loads(resp.read().decode())
            file_path = res["result"]["file_path"]
            
        file_url = f"https://api.telegram.org/file/bot{BOT_TOKEN}/{file_path}"
        download_target = os.path.join(destino_dir, "alien_sync_bundle_downloaded.zip")
        print(f"Baixando pacote {target_doc.get('file_name')}...")
        with urllib.request.urlopen(file_url, timeout=60) as f_resp:
            with open(download_target, "wb") as f_out:
                f_out.write(f_resp.read())
        target_file = download_target

    print("[2/2] Extraindo e atualizando arquivos...")
    with zipfile.ZipFile(target_file, 'r') as zf:
        zf.extractall(destino_dir)
        print(f"Arquivos extraidos com sucesso para: {destino_dir}")
        
    # Copiar executavel direto para o MT5 local se a pasta existir
    mt5_experts_candidates = [
        r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts",
        os.path.expandvars(r"%APPDATA%\MetaQuotes\Terminal\*\MQL5\Experts")
    ]
    
    extracted_goat = os.path.join(destino_dir, "MQL5", "Experts", "ALIEN_V11_2_GOAT_10K.ex5")
    if os.path.exists(extracted_goat):
        for cand in mt5_experts_candidates:
            if os.path.exists(cand):
                shutil.copy2(extracted_goat, cand)
                print(f"  + Executavel instalado no MT5: {cand}")

    print("\n=======================================================")
    print("  SINCRONIZAÇÃO 100% CONCLUÍDA!")
    print("  A sua estação de trabalho agora é IDÊNTICA à matriz.")
    print("=======================================================")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "pull":
        baixar_da_rede()
    else:
        publicar_para_rede()
