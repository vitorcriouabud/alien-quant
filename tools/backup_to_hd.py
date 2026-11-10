"""
ALIEN LAB - BACKUP AUTOMÁTICO PARA O HD EXTERNO (DRIVE E:)
==========================================================
Copia com segurança e redundância todos os códigos, executáveis,
relatórios do MT5, scripts e logs do projeto para o HD Externo E:.
"""

import os
import shutil
import time

SOURCE_LAB = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
SOURCE_MT5_EXPERTS = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts"
BACKUP_ROOT = r"E:\ALIEN_BACKUP_MASTER"

FOLDERS = {
    "EXPERTS_MQL5": os.path.join(BACKUP_ROOT, "MQL5_Experts"),
    "RELATORIOS": os.path.join(BACKUP_ROOT, "Relatorios_Auditoria"),
    "LAB_CORE": os.path.join(BACKUP_ROOT, "Lab_Core"),
    "SCRIPTS_TOOLS": os.path.join(BACKUP_ROOT, "Scripts_e_Bots"),
}

def executar_backup():
    print("=" * 60)
    print("  INICIANDO BACKUP COMPLETO DO PROJETO ALIEN PARA O HD (E:)")
    print("=" * 60)
    
    if not os.path.exists(r"E:\\"):
        print("[ERRO]: Drive E: não está acessível!")
        return False
        
    for name, path in FOLDERS.items():
        os.makedirs(path, exist_ok=True)
        print(f"Diretório garantido: {path}")

    # 1. Copia Experts do MT5
    print("\n[1/4] Fazendo backup dos Experts MQL5...")
    if os.path.exists(SOURCE_MT5_EXPERTS):
        for f in os.listdir(SOURCE_MT5_EXPERTS):
            if "ALIEN" in f.upper():
                src = os.path.join(SOURCE_MT5_EXPERTS, f)
                dst = os.path.join(FOLDERS["EXPERTS_MQL5"], f)
                if os.path.isfile(src):
                    shutil.copy2(src, dst)
                    print(f"  -> Arquivo copiado: {f}")
                elif os.path.isdir(src):
                    if os.path.exists(dst):
                        shutil.rmtree(dst)
                    shutil.copytree(src, dst)
                    print(f"  -> Pasta clonada: {f}")

    # 2. Copia arquivos centrais do Lab (ESTADO_ATUAL, EXPERIMENTOS, etc.)
    print("\n[2/4] Fazendo backup da governança e experimentos...")
    for f in os.listdir(SOURCE_LAB):
        src = os.path.join(SOURCE_LAB, f)
        if os.path.isfile(src):
            dst = os.path.join(FOLDERS["LAB_CORE"], f)
            shutil.copy2(src, dst)
            print(f"  -> Arquivo copiado: {f}")

    # 3. Copia relatórios de testes
    print("\n[3/4] Fazendo backup dos relatórios de auditoria...")
    results_dir = os.path.join(SOURCE_LAB, "results")
    if os.path.exists(results_dir):
        for root, dirs, files in os.walk(results_dir):
            for file in files:
                rel_path = os.path.relpath(root, results_dir)
                target_dir = os.path.join(FOLDERS["RELATORIOS"], rel_path)
                os.makedirs(target_dir, exist_ok=True)
                shutil.copy2(os.path.join(root, file), os.path.join(target_dir, file))
        print("  -> Relatórios e auditorias clonados com sucesso!")

    # 4. Copia ferramentas e bots
    print("\n[4/4] Fazendo backup das ferramentas e bots de integração...")
    tools_dir = os.path.join(SOURCE_LAB, "tools")
    if os.path.exists(tools_dir):
        for f in os.listdir(tools_dir):
            src = os.path.join(tools_dir, f)
            if os.path.isfile(src):
                dst = os.path.join(FOLDERS["SCRIPTS_TOOLS"], f)
                shutil.copy2(src, dst)
                print(f"  -> Arquivo copiado: {f}")

    # Criar um arquivo README no backup
    readme_path = os.path.join(BACKUP_ROOT, "README_BACKUP.txt")
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(f"PROJETO ALIEN - BACKUP OFICIAL DO SISTEMA QUANTITATIVO\n")
        f.write(f"Data do Backup: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Operador Responsável: Vitor\n")
        f.write(f"Conteúdo: Robô ALIEN V11.2 FREEDOM, Simulações de Mesa 10k, Auditorias, Telegram Bot.\n")

    print("\n" + "=" * 60)
    print("  BACKUP CONCLUÍDO COM 100% DE SUCESSO NO HD EXTERNO (E:)!")
    print("=" * 60)
    return True

if __name__ == "__main__":
    executar_backup()
