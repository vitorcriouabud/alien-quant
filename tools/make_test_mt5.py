import subprocess
import sys

SRC_INSTALL = r"C:\Program Files\RoboForex MT5 Terminal"
SRC_DATA = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"
DST = r"C:\ALIEN_TEST_MT5"

jobs = [
    (SRC_INSTALL, DST, []),
    (SRC_DATA + r"\MQL5", DST + r"\MQL5", ["/XD", "Logs", "Files"]),
    (SRC_DATA + r"\config", DST + r"\config", []),
    (SRC_DATA + r"\bases", DST + r"\bases", ["/XD", "signals"]),
    (SRC_DATA + r"\Tester\cache", DST + r"\tester\cache", []),
]
for src, dst, extra in jobs:
    print(">>", src, "->", dst, flush=True)
    r = subprocess.run(["robocopy", src, dst, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP"] + extra)
    # robocopy: codigos 0-7 = sucesso
    if r.returncode >= 8:
        print("ERRO robocopy", r.returncode)
        sys.exit(1)
print("COPIA CONCLUIDA")
