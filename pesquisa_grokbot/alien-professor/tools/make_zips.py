# monta /workspace/ALIEN_PROFESSOR.zip (público, SEM chaves) e, se existirem as chaves em /tmp, o kit pessoal /workspace/ALIEN_PROFESSOR_VITOR.zip
import zipfile,glob,os,sys
sys.path.insert(0,'/workspace/alien-professor/tools'); from presets import auto_set,tg_set
P="/workspace/alien-professor/"; I="/workspace/alien-indices/"; R="ALIEN_PROFESSOR/"
def base(z):
    for f in ["ALIEN_PROFESSOR.mq5","ALIEN_PROFESSOR.ex5","ALIEN_PROFESSOR_AUTO.mq5","ALIEN_PROFESSOR_AUTO.ex5","ALIEN_PROFESSOR_TELEGRAM.mq5","ALIEN_PROFESSOR_TELEGRAM.ex5","README_PT.md","TESTE_SINAIS.md"]: z.write(P+f,R+f)
    for f in ["INSTALAR.bat","INSTALAR.ps1","VIGIA_INSTALAR.bat","VIGIA_MT5.ps1"]: z.write(P+"kit/"+f,R+f)
    for f in sorted(glob.glob(P+"kit/presets/*.set")): z.write(f,R+"presets/"+os.path.basename(f))
    for f in sorted(glob.glob(P+"prints/*.png")): z.write(f,R+"prints/"+os.path.basename(f))
    for f in ["auto_xau_real","auto_xau_2025gen","auto_xau_2025gen_semDD"]: z.write(P+"tools/out/"+f+".htm",R+"relatorios/"+f+".htm")
    for f in sorted(glob.glob(P+"teste/*.py")): z.write(f,R+"teste/"+os.path.basename(f))
    for f in ["ALIEN_INDICES_V1.ex5","ALIEN_INDICES_V1.mq5","ALIEN_INDICES_V1.set","README_PT.md","TESTE.md"]: z.write(I+f,R+"indices/"+f)
with zipfile.ZipFile("/workspace/ALIEN_PROFESSOR.zip","w",zipfile.ZIP_DEFLATED) as z:
    base(z); print("publico",len(z.namelist()))
rd=lambda p: open(p).read().strip() if os.path.exists(p) else ""
tok,xai,gem=rd("/tmp/tg_token"),rd("/tmp/xai_key"),rd("/tmp/gemini_key"); chat=rd("/tmp/tg_chat")
if tok and xai and gem:
    leia=("ALIEN PROFESSOR - KIT PESSOAL DO VITOR\r\n\r\n"
     "ESTE ZIP TEM SUAS CHAVES (token do Telegram, chave xAI e chave Gemini) dentro de presets\\*_VITOR.set.\r\n"
     " - NAO compartilhe este zip com ninguem.\r\n - NAO suba no GitHub, Google Drive publico, grupo ou print.\r\n"
     " - Se vazar: revogue o token no @BotFather (/revoke) e apague as chaves em console.x.ai e aistudio.google.com.\r\n\r\n"
     "COMO USAR\r\n1. Rode INSTALAR.bat (copia tudo, inclusive os presets _VITOR, para o MT5).\r\n"
     "2. MT5: Ferramentas > Opcoes > Expert Advisors > Permitir WebRequest e adicione:\r\n   https://api.telegram.org\r\n   https://api.x.ai\r\n   https://generativelanguage.googleapis.com\r\n"
     "3. Robo AUTO no grafico M1 do XAUUSD (conta DEMO): aba Parametros > Carregar > ALIEN_PROFESSOR_AUTO_VITOR.set\r\n"
     "   (ou use o EA carteiro ALIEN_PROFESSOR_TELEGRAM com ALIEN_PROFESSOR_TELEGRAM_VITOR.set).\r\n"
     "4. No Telegram mande /ajuda para o seu bot.\r\n"
     +("" if chat else "\r\nATENCAO: o chat id ficou VAZIO. Ligue o robo, mande /start pro bot, ele mostra seu chat id; cole em InpTelegramChatId.\r\n")
     +"\r\nPara so conversar e receber analises sem o robo operar: InpTradeEnabled = false.\r\nNo teste de 10 anos o robo AUTO no ouro PERDEU. Os indices (pasta indices) sao o que deu positivo.\r\n")
    with zipfile.ZipFile("/workspace/ALIEN_PROFESSOR_VITOR.zip","w",zipfile.ZIP_DEFLATED) as z:
        base(z)
        z.writestr(R+"presets/ALIEN_PROFESSOR_AUTO_VITOR.set",auto_set("Vitor (chaves pessoais - NAO compartilhe)",45,90,tok,chat,xai,gem))
        z.writestr(R+"presets/ALIEN_PROFESSOR_TELEGRAM_VITOR.set",tg_set(tok,chat,xai,gem))
        z.writestr(R+"LEIA_PRIMEIRO.txt",leia)
        print("pessoal",len(z.namelist()),"chat" if chat else "SEM chat id")
    os.chmod("/workspace/ALIEN_PROFESSOR_VITOR.zip",0o600)
