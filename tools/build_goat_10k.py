import os
import subprocess
import shutil

src_freedom = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_2_FREEDOM.mq5"
dst_goat = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_2_GOAT_10K.mq5"
me = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
log = r"C:\Users\notebook\AppData\Local\Temp\compile_goat_10k.log"
mt5_experts = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts"
hd_experts = r"E:\ALIEN_BACKUP_MASTER\MQL5_Experts"

print("=" * 65)
print("  CONFIGURANDO O ALIEN V11.2 PARA A GOAT FUNDED TRADER (10K)")
print("=" * 65)

with open(src_freedom, "r", encoding="utf-8", errors="ignore") as f:
    code = f.read()

# Ajustes cirúrgicos para as regras lidas no print do Yuri:
# - Conta: $10.000
# - Limite Diário Goat: $200 -> Trava do ALIEN: $140.00 (blindagem com margem de segurança de $60)
# - Limite Geral Goat: $600 -> Trava Máxima do ALIEN: $400.00 (blindagem com margem de $200)
# - Meta da Fase 1: $1.000 -> Meta diária: $100.00 (10 dias positivos batem a meta!)
# - Lote: 0.15 a 0.20 (Stop seguro em $35.00 a $45.00)

code = code.replace("ALIEN V11.2 FREEDOM", "ALIEN V11.2 GOAT 10K")
code = code.replace("MESA US$ 10.000", "GOAT FUNDED TRADER 10K")
code = code.replace("DailyProfitTargetMoney  = 90.00;", "DailyProfitTargetMoney  = 100.00;")
code = code.replace("DailyMaxLossMoney = 150.00;", "DailyMaxLossMoney = 140.00;") # Trava antes dos $200 da Goat
code = code.replace("WeeklyMaxLossMoney = 350.00;", "WeeklyMaxLossMoney = 400.00;") # Trava antes dos $600 da Goat
code = code.replace("FixedLot = 0.20;", "FixedLot = 0.18;") # Calibragem para $140 de limite diário

with open(dst_goat, "w", encoding="utf-8") as f:
    f.write(code)

print("Arquivo ALIEN_V11_2_GOAT_10K.mq5 gerado com sucesso!")

# Compilar com MetaEditor
cmd = [me, f"/compile:{dst_goat}", f"/log:{log}"]
print("Compilando com MetaEditor...")
subprocess.run(cmd, timeout=35)

if os.path.exists(log):
    with open(log, "r", encoding="utf-16", errors="ignore") as f:
        log_content = f.read()
    print(log_content[-250:])

# Copiar executável compilado para MT5 e para o HD Externo E:
ex5_file = dst_goat.replace(".mq5", ".ex5")
if os.path.exists(ex5_file):
    shutil.copy2(ex5_file, mt5_experts)
    shutil.copy2(dst_goat, mt5_experts)
    print(f"Copiado para pasta oficial do MT5: {os.path.basename(ex5_file)}")
    
    if os.path.exists(hd_experts):
        shutil.copy2(ex5_file, hd_experts)
        shutil.copy2(dst_goat, hd_experts)
        print(f"Copiado para o HD Externo E: (Backup Concluido!)")
else:
    print("Erro: .ex5 não foi gerado.")
