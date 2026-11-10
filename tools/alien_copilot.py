"""
ALIEN CO-PILOTO | QUARTEL-GENERAL (VITOR, YURI & GABRIEL)
==========================================================
Este script conecta o MetaTrader 5 e o ALIEN ao grupo de operadores.
Recursos:
1. Envia status do robo (Lucro do dia, Meta de $90, Stop de $150).
2. Avisa no grupo quando uma operacao for aberta ou fechada.
3. Permite receber prints de graficos para analise tecnica instantanea.
"""

import os
import sys
import time
import glob

# Pasta de dados do MT5 onde o ALIEN grava telemetria e operacoes
MT5_FILES_DIR = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Files"

def verificar_arquivos_alien():
    print("[ALIEN CO-PILOTO] Monitorando pasta de dados do MT5...")
    if not os.path.exists(MT5_FILES_DIR):
        print(f"Diretorio nao encontrado: {MT5_FILES_DIR}")
        return
    
    arquivos = glob.glob(os.path.join(MT5_FILES_DIR, "*ALIEN*"))
    print(f"Arquivos do ALIEN encontrados: {len(arquivos)}")
    for a in arquivos[-5:]:
        print(f" - {os.path.basename(a)}")

def obter_resumo_diario():
    # Procura arquivos de relatorio do dia
    hoje = time.strftime("%Y%m%d")
    padrao = os.path.join(MT5_FILES_DIR, f"*{hoje}*")
    matches = glob.glob(padrao)
    if matches:
        with open(matches[0], 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    return "Aguardando abertura de mercado e primeiras operacoes."

if __name__ == "__main__":
    print("=" * 60)
    print("  ALIEN CO-PILOTO PRONTO PARA CONEXAO")
    print("  Operadores: Vitor, Yuri e Gabriel")
    print("=" * 60)
    verificar_arquivos_alien()
    print("\nStatus: Pronto para receber TOKEN do Telegram ou Webhook do WhatsApp!")
