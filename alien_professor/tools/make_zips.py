# Monta /workspace/ALIEN_PROFESSOR.zip (público, SEM chaves) e /workspace/ALIEN_PROFESSOR_VITOR.zip
# (pessoal = público + config/ALIEN_config.txt + SUBIR_GITHUB). Os .ex5 são os mesmos: nenhuma chave compilada.
# As chaves do kit pessoal vêm de um preset local (ALIEN_VITOR_SET, fora do git) e nunca são impressas.
import zipfile, glob, os, re
P = "/workspace/alien-professor/"; I = "/workspace/alien-indices/"; R = "ALIEN_PROFESSOR/"
VITOR_SET = os.environ.get("ALIEN_VITOR_SET", "/tmp/vk/ALIEN_PROFESSOR_AUTO_VITOR.set")

def base(z):
    for f in ["ALIEN_PROFESSOR.mq5", "ALIEN_PROFESSOR.ex5", "ALIEN_PROFESSOR_AUTO.mq5", "ALIEN_PROFESSOR_AUTO.ex5",
              "ALIEN_PROFESSOR_TELEGRAM.mq5", "ALIEN_PROFESSOR_TELEGRAM.ex5"]:
        z.write(P + f, R + f)
    for f in ["README_PT.md", "TESTE_SINAIS.md", "MUDANCAS.md", "COMO_ATUALIZAR.md", "GUIA_DO_GRAFICO.md"]:
        z.write(P + f, R + f)
    for f in ["INSTALAR.bat", "INSTALAR.ps1", "ATUALIZAR.bat", "ATUALIZAR.ps1", "VIGIA_INSTALAR.bat", "VIGIA_MT5.ps1", "ALIEN_conhecimento.txt"]:
        z.write(P + "kit/" + f, R + f)
    for f in sorted(glob.glob(P + "kit/presets/*.set")):
        z.write(f, R + "presets/" + os.path.basename(f))
    for f in sorted(glob.glob(P + "prints/*.png")):
        z.write(f, R + "prints/" + os.path.basename(f))
    for f in ["auto_xau_real", "auto_xau_2025gen", "auto_xau_2025gen_semDD"]:
        z.write(P + "tools/out/" + f + ".htm", R + "relatorios/" + f + ".htm")
    for f in sorted(glob.glob(P + "teste/*.py")):
        z.write(f, R + "teste/" + os.path.basename(f))
    for f in ["ALIEN_INDICES_V1.ex5", "ALIEN_INDICES_V1.mq5", "ALIEN_INDICES_V1.set", "README_PT.md", "TESTE.md"]:
        z.write(I + f, R + "indices/" + f)

with zipfile.ZipFile("/workspace/ALIEN_PROFESSOR.zip", "w", zipfile.ZIP_DEFLATED) as z:
    base(z); print("publico", len(z.namelist()))

def le_set(path):
    v = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if "=" in line and not line.startswith(";"):
            k, x = line.split("=", 1); v[k.strip()] = x.strip()
    return v

if os.path.isfile(VITOR_SET):
    v = le_set(VITOR_SET)
    if not v.get("InpTelegramChatId") and os.environ.get("ALIEN_VITOR_CHAT"):
        v["InpTelegramChatId"] = os.environ["ALIEN_VITOR_CHAT"]   # chat id vem do ambiente (fora do git)
    cfg = ("# ALIEN - configuracao pessoal do Vitor. NAO compartilhe este arquivo.\r\n"
           "# Fica em MQL5\\Files\\ALIEN_config.txt. Atualizar o robo nao apaga.\r\n"
           "telegram_token=" + v.get("InpTelegramToken", "") + "\r\n"
           "telegram_chat_id=" + v.get("InpTelegramChatId", "") + "\r\n"
           "gemini_chave_1=" + v.get("InpAI2Key", "") + "\r\n"
           "gemini_chave_2=" + v.get("InpGeminiKey2", "") + "\r\n"
           "# modo assistente: so analisa e avisa. Apague a linha abaixo se quiser que ele opere na DEMO.\r\n"
           "modo=assistente\r\n"
           "# autonomo=demo: o robo decide e opera SOZINHO so em conta DEMO e aprende (troque para off se nao quiser)\r\n"
           "autonomo=demo\r\n"
           "# ordens pelo Telegram (so voce, com botao Confirmar): off, demo ou real\r\n"
           "telegram_ordens=demo\r\n")
    leia = ("ALIEN PROFESSOR 12.6 - KIT PESSOAL DO VITOR\r\n\r\n"
            "ESTE ZIP TEM SUAS CHAVES no arquivo config\\ALIEN_config.txt. NAO compartilhe este zip.\r\n"
            "Se vazar: /revoke no @BotFather e apague as chaves em aistudio.google.com.\r\n\r\n"
            "COMO USAR\r\n"
            "1. Feche o MT5 e de dois cliques em INSTALAR.bat (instala so no MT5 da RoboForex,\r\n"
            "   libera o WebRequest e copia sua configuracao se ela ainda nao existir).\r\n"
            "2. Abra o MT5 e arraste Consultor expert > ALIEN > ALIEN_PROFESSOR_AUTO no grafico XAUUSD M1.\r\n"
            "   Nao precisa carregar preset nem mexer em parametro.\r\n"
            "3. No Telegram use os botoes ou mande /ajuda.\r\n"
            "4. No grupo, mande /grupo uma vez (voce, Vitor) pra liberar.\r\n\r\n"
            "IMPORTANTE: use so o ALIEN_PROFESSOR_AUTO. NAO ligue o ALIEN_PROFESSOR_TELEGRAM junto (mensagens dobradas).\r\n"
            "Vem em MODO ASSISTENTE + AUTONOMO NA DEMO: ele decide sozinho so em conta DEMO (/autonomo off desliga).\r\n"
            "Ordens pelo Telegram: so voce, sempre com botao Confirmar (telegram_ordens=demo).\r\n"
            "Atualizar no futuro: feche o MT5 e de dois cliques no ATUALIZAR.bat (baixa do GitHub). Sua configuracao nunca e apagada.\r\n"
            "Subir codigo e diarios pro GitHub: SUBIR_GITHUB.bat (branch alien-dados).\r\n"
            "No teste de 10 anos o AUTO no ouro PERDEU. Os indices (pasta indices) foram o que deu positivo.\r\n")
    out = "/workspace/ALIEN_PROFESSOR_VITOR.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        base(z)
        z.writestr(R + "config/ALIEN_config.txt", cfg)
        z.writestr(R + "LEIA_PRIMEIRO.txt", leia)
        for f in ["SUBIR_GITHUB.bat", "SUBIR_GITHUB.ps1"]:
            z.write(P + "kit/" + f, R + f)
        ok = bool(v.get("InpTelegramChatId")) and len(v.get("InpTelegramToken", "")) > 20 and len(v.get("InpAI2Key", "")) > 10
        print("pessoal", len(z.namelist()), "config completa" if ok else "CONFIG INCOMPLETA")
    os.chmod(out, 0o600)
else:
    print("pessoal PULADO: sem preset local", VITOR_SET)
