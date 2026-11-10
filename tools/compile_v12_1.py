import os
import subprocess
import shutil

editor = r"C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe"
src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
term_experts = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts"
dest = os.path.join(term_experts, "ALIEN_V12_1_INSTITUTIONAL.mq5")

shutil.copyfile(src, dest)

log = os.path.join(os.environ["TEMP"], "compile_v12_1.log")
cmd = [editor, f"/compile:{dest}", f"/log:{log}"]
res = subprocess.run(cmd, capture_output=True, text=True)

if os.path.exists(log):
    with open(log, "r", encoding="utf-16", errors="ignore") as f:
        print(f.read())
else:
    print("Log not generated")

ex5_term = os.path.join(term_experts, "ALIEN_V12_1_INSTITUTIONAL.ex5")
ex5_src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"

if os.path.exists(ex5_term):
    shutil.copyfile(ex5_term, ex5_src)
    print("Compilado com sucesso! EX5 tamanho:", os.path.getsize(ex5_term), "bytes")
else:
    print("Falha: EX5 nao gerado")
