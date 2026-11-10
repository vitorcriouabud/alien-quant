import os
import subprocess
import shutil

editor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
term_experts = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts"
dest = os.path.join(term_experts, "ALIEN_V12_1_INSTITUTIONAL.mq5")

shutil.copyfile(src, dest)
print(f"Copied {src} to {dest}")

log = os.path.join(os.environ["TEMP"], "compile_v12_1_all.log")
if os.path.exists(log):
    os.remove(log)

cmd = [editor, f"/compile:{dest}", f"/log:{log}"]
print("Executing:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True)

if os.path.exists(log):
    with open(log, "r", encoding="utf-16", errors="ignore") as f:
        print(f.read())
else:
    print("Log not generated")

ex5_term = os.path.join(term_experts, "ALIEN_V12_1_INSTITUTIONAL.ex5")

if os.path.exists(ex5_term):
    sz = os.path.getsize(ex5_term)
    print(f"Compilado com SUCESSO! EX5 gerado ({sz} bytes).")
    
    # 1. Distribuir para 5K AppData
    dest_5k = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
    shutil.copyfile(ex5_term, dest_5k)
    print(f" -> 5K Goat Terminal atualizado: {dest_5k}")
    
    # 2. Distribuir para 25K Portable
    dest_25k = r"C:\Goat_MT5_25K\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
    shutil.copyfile(ex5_term, dest_25k)
    print(f" -> 25K Goat Terminal atualizado: {dest_25k}")
    
    # 3. Distribuir para ALIEN_LAB
    dest_lab = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
    shutil.copyfile(ex5_term, dest_lab)
    print(f" -> ALIEN_LAB atualizado: {dest_lab}")
else:
    print("FALHA CRÍTICA: EX5 não foi gerado!")
