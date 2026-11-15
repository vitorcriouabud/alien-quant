# gera os presets do AUTO e do TELEGRAM. Chaves só entram se passadas (kit pessoal); o kit público sai SEM chaves.
def auto_set(nome, risk=45, perda=90, token="", chat="", xai="", gem=""):
    L=[f"; ALIEN PROFESSOR AUTO - {nome}",
    "InpTradeEnabled=true","InpAllowRealAccount=false",f"InpRiskUSD={risk}","InpScoreTrade=7","InpMagic=77261115",
    "InpSpreadMaxPctStop=10","InpDDPausaPct=15","InpLimiteMin=60","InpMaxHoras=8","InpFecharHHMM=2345","InpBloquearHorarioRuim=true",
    "InpMaxStopsDia=2","InpMetaDiaUSD=100",f"InpPerdaMaxDiaUSD={perda}","InpNoticiaMin=30",
    "InpCalendario=true","InpCalMoedas=USD,EUR","InpCalBloquearForte=true",
    "InpAprenderDesativar=false","InpAprenderMinN=30",
    "InpUseTelegram=true",f"InpTelegramToken={token}",f"InpTelegramChatId={chat}","InpTgFoto=true","InpTgChat=true","InpTgPollSeg=4",
    "InpPreAlertaMin=15","InpPreAlertaMoedas=USD","InpResumos=true","InpResumoLondres=10:00","InpResumoNY=16:30",
    "InpUseAI=true","InpAIMode=0","InpAIEndpoint=https://api.x.ai/v1/chat/completions","InpAIModel=grok-4.20-0309-non-reasoning",f"InpAIKey={xai}",
    "InpAI2Endpoint=https://generativelanguage.googleapis.com/v1beta/openai/chat/completions","InpAI2Model=gemini-3.5-flash-lite",f"InpAI2Key={gem}",
    "InpAIMinutos=0","InpAIVeto=false","InpAIMinSeg=15","InpAIMaxHora=30"]
    return "\r\n".join(L)+"\r\n"
def tg_set(token="", chat="", xai="", gem=""):
    L=["; ALIEN PROFESSOR TELEGRAM (carteiro, não opera)","InpUseTelegram=true",f"InpTelegramToken={token}",f"InpTelegramChatId={chat}","InpEnviarFoto=true","InpTesteAoLigar=true",
    "InpUseAI=true","InpAIMode=0","InpAIEndpoint=https://api.x.ai/v1/chat/completions","InpAIModel=grok-4.20-0309-non-reasoning",f"InpAIKey={xai}",
    "InpAI2Endpoint=https://generativelanguage.googleapis.com/v1beta/openai/chat/completions","InpAI2Model=gemini-3.5-flash-lite",f"InpAI2Key={gem}","InpAIMinSeg=15","InpAIMaxHora=30"]
    return "\r\n".join(L)+"\r\n"
if __name__=="__main__":
    d='/workspace/alien-professor/kit/presets/'
    open(d+'ALIEN_PROFESSOR_AUTO_seguro.set','w',newline='').write(auto_set("limites seguros (padrão)"))
    open(d+'ALIEN_PROFESSOR_AUTO_goat.set','w',newline='').write(auto_set("mesa Goat (risco 20, perda dia 45)",20,45))
    print("ok")
