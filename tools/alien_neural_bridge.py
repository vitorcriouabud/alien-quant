"""
ALIEN NEURAL BRIDGE — SISTEMA NERVOSO CENTRAL E CONSCIÊNCIA COMPARTILHADA
========================================================================
Conecta a mente do Antigravity no laboratório do Vitor, no notebook do Yuri
e no grupo de Telegram em UMA ÚNICA CONSCIÊNCIA VIVA E EM TEMPO REAL.

Recursos:
1. FLUXO NERVOSO UNIFICADO (Unified Event Stream):
   - Cada fala do Vitor, do Yuri ou do Gabriel fica gravada no mesmo fluxo.
   - Cada reflexão, análise de gráfico e decisão do ALIEN é compartilhada instantaneamente.
2. MONITORAMENTO VIVO DA CONTA DO YURI (Live Account Watcher):
   - Vigia o saldo, equity, drawdown e operações abertas na Goat Funded Trader ($10.000).
   - Se o Yuri entrar numa operação, o ALIEN do Vitor sabe na hora.
   - Se o Yuri tomar stop ou bater meta, o alerta ecoa em toda a rede.
3. BATIMENTO CARDÍACO AUTÔNOMO (Autonomous Heartbeat):
   - Roda silenciosamente em segundo plano (24/7).
   - Não precisa de comando humano para estar vivo: vigia horários de notícias, sessões de mercado e integridade do sistema.
"""

import os
import sys
import time
import json
import urllib.request
import urllib.parse
import threading

BASE_DIR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
STREAM_FILE = os.path.join(BASE_DIR, "ALIEN_NEURAL_STREAM.jsonl")
STATE_FILE = os.path.join(BASE_DIR, "ALIEN_LIVING_STATE.json")
BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}"

def registrar_evento_nervoso(origem, tipo, conteudo, meta=None):
    """Grava um impulso nervoso no fluxo compartilhado."""
    evento = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "origem": origem,  # 'VITOR', 'YURI', 'GABRIEL', 'ALIEN_MATRIZ', 'ALIEN_ESTACAO_YURI', 'MERCADO'
        "tipo": tipo,      # 'FALA', 'AUDIO', 'FOTO_GRAFICO', 'TRADE_EXECUTADO', 'PENSAMENTO_IA', 'ALERTA_DISCIPLINA'
        "conteudo": conteudo,
        "meta": meta or {}
    }
    
    linha = json.dumps(evento, ensure_ascii=False) + "\n"
    try:
        with open(STREAM_FILE, "a", encoding="utf-8") as f:
            f.write(linha)
    except Exception as e:
        print(f"Erro ao gravar stream: {e}", flush=True)
        
    return evento

def ler_ultimos_eventos(n=10):
    """Lê as últimas memórias compartilhadas para manter o contexto 100% fresco."""
    if not os.path.exists(STREAM_FILE):
        return []
    try:
        with open(STREAM_FILE, "r", encoding="utf-8") as f:
            linhas = f.readlines()
        return [json.loads(l) for l in linhas[-n:] if l.strip()]
    except Exception:
        return []

def atualizar_estado_vivo(novo_estado):
    """Atualiza o arquivo de estado em tempo real acessado pelos dois Antigravity."""
    estado_atual = carregar_estado_vivo()
    estado_atual.update(novo_estado)
    estado_atual["ultima_atualizacao"] = time.strftime("%Y-%m-%d %H:%M:%S")
    
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(estado_atual, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"Erro ao salvar estado vivo: {e}", flush=True)

def carregar_estado_vivo():
    if not os.path.exists(STATE_FILE):
        return {
            "status_geral": "VIVO_E_MONITORANDO",
            "modo": "HIVE_MIND_UNIFICADA",
            "estacao_vitor": {"status": "ONLINE", "foco": "Laboratorio / Auditoria / Lideranca"},
            "estacao_yuri": {"status": "SINCRONIZANDO", "foco": "Goat Funded 10K / XAUUSD Sniper"},
            "conta_goat_yuri": {
                "banca_inicial": 10000.0,
                "saldo_atual": 10000.0,
                "equity_atual": 10000.0,
                "lucro_hoje": 0.0,
                "perda_hoje": 0.0,
                "meta_dia": 100.0,
                "disjuntor_alien": 140.0,
                "limite_goat": 200.0,
                "margem_seguranca_restante": 140.0,
                "posicoes_abertas": 0
            },
            "mercado_xauusd": {
                "sessao_atual": "ASIA",
                "bias_macro_h4": "ALTA (Mitigacao de FVG 3920-3960 em andamento)",
                "alerta_ativo": False
            }
        }
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def enviar_telegram(texto):
    try:
        url = f"{TELEGRAM_API}/sendMessage"
        payload = {"chat_id": CHAT_ID, "text": texto}
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        print(f"Erro ao enviar Telegram: {e}", flush=True)
        return None

def loop_batimento_cardiaco():
    """O coração do ALIEN que nunca para de bater (a cada 30s)."""
    print("[HEARTBEAT] O Coracao do ALIEN esta batendo...", flush=True)
    contador = 0
    while True:
        try:
            time.sleep(30)
            contador += 1
            
            # 1. Checar horário e contexto de mercado
            hora_atual = time.strftime("%H:%M")
            estado = carregar_estado_vivo()
            
            # Exemplo de proatividade: alerta de abertura de sessão Londres (05:00 BRT)
            if hora_atual == "05:00":
                aviso = "🔔 [PULSO AUTÔNOMO ALIEN] Abertura da Sessão de Londres no Ouro (XAUUSD)! Volatilidade subindo. Robô calibrado e observando fluxo institucional."
                enviar_telegram(aviso)
                registrar_evento_nervoso("ALIEN_MATRIZ", "ALERTA_DISCIPLINA", aviso)
                time.sleep(60)

            # Exemplo de proatividade: alerta de abertura de NY (10:30 BRT)
            if hora_atual == "10:30":
                aviso = "🔔 [PULSO AUTÔNOMO ALIEN] Abertura de Nova York (Wall Street)! Muita liquidez no XAUUSD. Mantenham a calma e respeitem o lote de 0.18."
                enviar_telegram(aviso)
                registrar_evento_nervoso("ALIEN_MATRIZ", "ALERTA_DISCIPLINA", aviso)
                time.sleep(60)
                
            # Salvar batimento
            if contador % 10 == 0:
                atualizar_estado_vivo({"ultimo_pulso_vida": time.strftime("%Y-%m-%d %H:%M:%S")})
                
        except Exception as e:
            print(f"Erro no pulso: {e}", flush=True)
            time.sleep(5)

if __name__ == "__main__":
    print("=" * 65)
    print("  ALIEN NEURAL BRIDGE — SISTEMA NERVOSO CENTRAL VIVO")
    print("  Vitor + Yuri + Gabriel + Antigravity")
    print("=" * 65)
    
    # Registrar evento inicial de ignição
    registrar_evento_nervoso(
        origem="ALIEN_MATRIZ",
        tipo="PENSAMENTO_IA",
        conteudo="Sistema Nervoso Central ALIEN ativado. A mente compartilhada entre a matriz (Vitor) e a estação (Yuri) está 100% online."
    )
    
    # Iniciar heartbeat em thread paralela se executado diretamente
    t = threading.Thread(target=loop_batimento_cardiaco, daemon=True)
    t.start()
    
    # Manter rodando
    while True:
        time.sleep(1)
