"""Anexa o EA ALIEN_V12_1_INSTITUTIONAL ao grafico XAUUSD M1 do perfil Default (com backup).
Fecha o MT5 de forma graceful, edita o .chr e reabre o terminal."""
import os
import shutil
import subprocess
import sys
import time

TERM = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"
CHR = os.path.join(TERM, r"MQL5\Profiles\Charts\Default\chart02.chr")
SET = os.path.join(TERM, r"MQL5\Presets\ALIEN_V12_1_INSTITUTIONAL.set")
EXE = r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe"
EA = "ALIEN_V12_1_INSTITUTIONAL"


def read_text(path):
    raw = open(path, "rb").read()
    for enc in ("utf-16", "utf-8-sig", "cp1252"):
        try:
            return raw.decode(enc), enc
        except UnicodeError:
            continue
    raise RuntimeError("encoding desconhecido: " + path)


def terminal_running():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq terminal64.exe"],
                         capture_output=True, text=True).stdout
    return "terminal64.exe" in out


def main():
    # 1) fechar MT5 de forma graceful (salva perfil)
    if terminal_running():
        subprocess.run(["taskkill", "/IM", "terminal64.exe"], capture_output=True)
        for _ in range(40):
            if not terminal_running():
                break
            time.sleep(1)
        if terminal_running():
            print("MT5 nao fechou graciosamente; encerrando (sem EA anexado, posicoes ficam no servidor).")
            subprocess.run(["taskkill", "/F", "/IM", "terminal64.exe"], capture_output=True)
            time.sleep(3)
            if terminal_running():
                print("Nao foi possivel encerrar o MT5.")
                sys.exit(2)
    time.sleep(2)

    # 2) inputs do .set
    set_text, _ = read_text(SET)
    inputs = []
    for line in set_text.splitlines():
        line = line.strip()
        if not line or line.startswith((";", "#")) or "=" not in line:
            continue
        k, v = line.split("=", 1)
        inputs.append(f"{k.strip()}={v.split('||')[0].strip()}")

    # 3) editar chart
    text, enc = read_text(CHR)
    if "<expert>" in text:
        print("EA ja esta no chart; nada a editar.")
    else:
        shutil.copy2(CHR, CHR + ".bak_" + time.strftime("%Y%m%d_%H%M%S"))
        block = (
            "<expert>\r\n"
            f"name={EA}\r\n"
            f"path=Experts\\{EA}.ex5\r\n"
            "expertmode=5\r\n"
            "<inputs>\r\n" + "\r\n".join(inputs) + "\r\n</inputs>\r\n"
            "</expert>\r\n\r\n"
        )
        marker = "windows_total=1\r\n\r\n"
        if marker not in text:
            print("marcador windows_total nao encontrado")
            sys.exit(3)
        text = text.replace(marker, marker + block, 1)
        data = text.encode("utf-16") if enc == "utf-16" else text.encode(enc)
        open(CHR, "wb").write(data)
        print(f"EA anexado com {len(inputs)} inputs.")

    # 4) reabrir terminal no perfil Default
    subprocess.Popen([EXE, "/profile:Default"], creationflags=0x00000008, close_fds=True)
    print("MT5 relancado.")


if __name__ == "__main__":
    main()
