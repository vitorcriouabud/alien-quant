# -*- coding: utf-8 -*-
import os
import shutil
import subprocess

editor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
term_experts = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts"
src_mq5 = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.mq5"
dest_mq5 = os.path.join(term_experts, "ALIEN_V12_INSTITUTIONAL.mq5")
log_path = os.path.join(os.environ.get("TEMP", r"C:\Windows\Temp"), "compile_v12.log")

if os.path.exists(log_path):
    os.remove(log_path)

print(f"Copiando {src_mq5} -> {dest_mq5}...")
shutil.copy2(src_mq5, dest_mq5)

cmd = [editor, f"/compile:{dest_mq5}", f"/log:{log_path}"]
print("Executando MetaEditor:", " ".join(cmd))
res = subprocess.run(cmd, capture_output=True, text=True)

print("MetaEditor exit code:", res.returncode)

if os.path.exists(log_path):
    with open(log_path, "r", encoding="utf-16", errors="ignore") as f:
        log_text = f.read()
    if not log_text.strip():
        with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
            log_text = f.read()
    print("=== LOG DE COMPILACAO ===")
    print(log_text)
else:
    print("Log nao foi encontrado em:", log_path)

dest_ex5 = os.path.join(term_experts, "ALIEN_V12_INSTITUTIONAL.ex5")
src_ex5 = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.ex5"

if os.path.exists(dest_ex5):
    print("Sucesso! EX5 gerado em:", dest_ex5, f"({os.path.getsize(dest_ex5)} bytes)")
    shutil.copy2(dest_ex5, src_ex5)
    print("Copiado de volta para o ALIEN_LAB:", src_ex5)
else:
    print("FALHA: EX5 nao foi gerado.")
