
//====================================================================
// AGENTE ALIER (v12.3): estado persistido, aviso de volta, teclado fixo,
// avisos proativos, memória de fatos, áudio, disciplina, legenda do print.
// Tudo grátis: roda dentro do MT5 com as chaves Gemini do próprio Vitor.
//====================================================================
string   g_ligadoBR="";          // "HH:MM" (Brasília) em que o robô ligou
long     g_discPos=0;            // posição esperando o motivo (disciplina)
datetime g_discT=0;
string   g_proKeys="|";          // avisos proativos já mandados (persistido)
string   g_proHora="";           // horários (TimeGMT) dos últimos avisos, separados por ;
string   g_proTipo[]; datetime g_proTipoUlt[];
datetime g_proBarM1=0;
datetime g_proMudoAte=0;      // avisos segurados depois de um stop (InpPausaAposStopMin)

// ---------------- utilidades ----------------
string ArqLe(string f)
{
   int h=FileOpen(f,FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return "";
   string s=""; bool first=true;
   while(!FileIsEnding(h)){ string l=FileReadString(h); s+=(first?"":"\n")+l; first=false; }
   FileClose(h); return s;
}
void ArqGrava(string f,string s)
{
   int h=FileOpen(f,FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,s); FileClose(h);
}
// guarda só o fim de uma lista "|a|b|c|" (sem cortar uma chave no meio)
string ChavesCorta(string k,int maxLen=3000)
{
   if(StringLen(k)<=maxLen) return k;
   string t=StringSubstr(k,StringLen(k)-maxLen);
   int p=StringFind(t,"|"); if(p<0) return "|";
   return StringSubstr(t,p);
}
// une duas listas de chaves "|a|b|"
string ChavesUne(string a,string b)
{
   string p[]; int n=StringSplit(b,'|',p);
   for(int i=0;i<n;i++){ if(p[i]=="") continue; if(StringFind(a,"|"+p[i]+"|")<0) a+=(StringLen(a)>0 && StringGetCharacter(a,StringLen(a)-1)=='|'?"":"|")+p[i]+"|"; }
   return a;
}
string PrimeiraMinuscula(string s)
{
   if(s=="") return s;
   string f=StringSubstr(s,0,1); StringToLower(f); return f+StringSubstr(s,1);
}
string HoraBRde(datetime srv){ return TimeToString(SrvParaBR(srv),TIME_MINUTES); }
string TendPalavra(int d){ return d>0?"de alta":(d<0?"de baixa":"de lado"); }
string CsvLimpo(string s){ StringReplace(s,";",","); StringReplace(s,"\r"," "); StringReplace(s,"\n"," "); return s; }

// ---------------- 8. estado do Telegram persistido ----------------
string g_tgEstArq="ALIEN_tg_estado.txt";
void TgEstadoLoad()
{
   string s=ArqLe(g_tgEstArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   if(n>0){ long o=StringToInteger(l[0]); if(o>g_tgOff) g_tgOff=o; }
   if(n>1 && StringLen(l[1])>0) g_alertados=ChavesUne(g_alertados,l[1]);
   if(n>2 && StringLen(l[2])>0) g_resFeitos=ChavesUne(g_resFeitos,l[2]);
}
void TgEstadoSave()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   // une com o que outro gráfico já gravou (não apaga chaves dele)
   string s=ArqLe(g_tgEstArq);
   if(s!="")
   {
      string l[]; int n=StringSplit(s,'\n',l);
      if(n>0){ long o=StringToInteger(l[0]); if(o>g_tgOff) g_tgOff=o; }
      if(n>1) g_alertados=ChavesUne(g_alertados,l[1]);
      if(n>2) g_resFeitos=ChavesUne(g_resFeitos,l[2]);
   }
   g_alertados=ChavesCorta(g_alertados); g_resFeitos=ChavesCorta(g_resFeitos);
   ArqGrava(g_tgEstArq,IntegerToString(g_tgOff)+"\r\n"+g_alertados+"\r\n"+g_resFeitos+"\r\n");
}

// ---------------- 1. aviso de volta ("Voltei") só depois de queda de verdade ----------------
string ParadaArq(){ return "ALIEN_parada_"+_Symbol+".txt"; }
string MotivoParada(int r)
{
   switch(r)
   {
      case -1:              return "o MT5 fechou sem avisar (queda de energia, internet ou travamento)";
      case REASON_CLOSE:    return "o MT5 foi fechado";
      case REASON_ACCOUNT:  return "a conta reconectou ou foi trocada";
      case REASON_PROGRAM:  return "o robô se desligou sozinho";
      case REASON_INITFAILED: return "o robô não conseguiu ligar da última vez";
      default:              return "parada desconhecida";
   }
}
// motivos que são mexida sua (tirar/trocar gráfico, mudar parâmetro) -> sem aviso
bool ParadaFoiMexida(int r)
{
   return r==REASON_REMOVE || r==REASON_RECOMPILE || r==REASON_CHARTCHANGE || r==REASON_CHARTCLOSE || r==REASON_PARAMETERS || r==REASON_TEMPLATE;
}
void ParadaGrava(int rodando,int motivo)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   ArqGrava(ParadaArq(),StringFormat("%d;%I64d;%d",rodando,(long)TimeGMT(),motivo));
}
void ParadaDeinit(int r){ ParadaGrava(0,r); }
void ParadaBatimento(){ ParadaGrava(1,-1); }
bool VolteiPode()
{
   string s=ArqLe("ALIEN_voltei.txt"); long t=StringToInteger(s);
   return (t<=0 || (long)TimeGMT()-t>=15*60);
}
void VolteiMarca(){ ArqGrava("ALIEN_voltei.txt",IntegerToString((long)TimeGMT())); }
string ModoTxt(){ return TradeAtivo()?"operando na demo, dentro dos limites":(g_tradePausa?"pausado (você mandou pausar)":"modo assistente: só analiso e aviso, não mando ordem"); }
void ParadaInit()
{
   g_ligadoBR=TimeToString(AgoraBR(),TIME_MINUTES);
   if(MQLInfoInteger(MQL_TESTER)) return;
   string s=ArqLe(ParadaArq());
   ParadaGrava(1,-1);
   if(!TgOk()) return;
   if(InpTgChat && !TgMaster()) return;      // só o gráfico que atende o chat avisa
   string versao="Alier versão "+APROF_VER+", ligado às "+g_ligadoBR+" (Brasília) no "+_Symbol+".";
   if(s=="")
   {
      if(!VolteiPode()) return;
      VolteiMarca();
      SendMsgKb("Oi, Vitor! 👽 "+versao+"\nAgora: "+ModoTxt()+".\nUsa os botões aqui embaixo ou me escreve normal. /ajuda mostra tudo.");
      return;
   }
   string p[]; if(StringSplit(s,';',p)<3) return;
   int rodando=(int)StringToInteger(p[0]); long t=StringToInteger(p[1]); int motivo=(int)StringToInteger(p[2]);
   if(rodando==1) motivo=-1;                 // não passou pelo desligamento = caiu
   if(rodando==0 && ParadaFoiMexida(motivo)) return;
   if(!VolteiPode()) return;
   VolteiMarca();
   string desde=t>0?TimeToString((datetime)(t-3*3600),TIME_MINUTES):"?";
   SendMsgKb("Voltei ✅ Fiquei fora desde umas "+desde+" (Brasília) porque "+MotivoParada(motivo)+".\n"+versao+"\nAgora: "+ModoTxt()+".");
}

// ---------------- 5. teclado fixo + confirmação de pausa ----------------
string TgKbFixo()
{
   return "{\"keyboard\":[[{\"text\":\"📰 Notícias\"},{\"text\":\"📊 Análise\"},{\"text\":\"🧭 Plano\"}],"
          "[{\"text\":\"🗓️ Agenda\"},{\"text\":\"📸 Foto\"},{\"text\":\"ℹ️ Status\"}],[{\"text\":\"⏸️ Pausa\"},{\"text\":\"▶️ Retoma\"}]],"
          "\"resize_keyboard\":true,\"is_persistent\":true}";
}
string TgKbSimNao(string sim,string cbSim,string nao,string cbNao)
{
   return "{\"inline_keyboard\":[[{\"text\":\""+JEsc(sim)+"\",\"callback_data\":\""+cbSim+"\"},{\"text\":\""+JEsc(nao)+"\",\"callback_data\":\""+cbNao+"\"}]]}";
}
// texto de botão -> comando ("📰 Notícias" -> "/noticias")
string BotaoCmd(string t)
{
   if(StringLen(t)>24) return "";
   string u=AISemAcento(t); StringToUpper(u);
   string o="";
   for(int i=0;i<StringLen(u);i++){ ushort c=StringGetCharacter(u,i); if(c>='A' && c<='Z') o+=ShortToString(c); }
   if(o=="NOTICIAS") return "/noticias";
   if(o=="ANALISE")  return "/analise";
   if(o=="PLANO")    return "/plano";
   if(o=="FOTO")     return "/foto";
   if(o=="AGENDA")   return "/agenda";
   if(o=="STATUS")   return "/status";
   if(o=="PAUSA")    return "/pausa";
   if(o=="RETOMA")   return "/retoma";
   return "";
}
void PedeConfirmaPausa(bool pausar)
{
   if(pausar) SendMsgMarkup("Quer mesmo pausar as ordens? Os avisos continuam chegando.",TgKbSimNao("Sim, pausar ⏸️","/pausa_ok","Não","/cancela"));
   else       SendMsgMarkup("Quer mesmo voltar a mandar ordem (dentro dos limites)?",TgKbSimNao("Sim, retomar ▶️","/retoma_ok","Não","/cancela"));
}

// ---------------- legenda curta do print ----------------
string FotoLegenda()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   string s="📸 "+_Symbol+" a "+Fmt(bid)+" às "+TimeToString(AgoraBR(),TIME_MINUTES)+" (Brasília). ";
   string sw="";
   for(int i=0;i<ArraySize(g_niv);i++)
      if(g_niv[i].estado==ST_VARRIDA && g_niv[i].tSweep>0 && TimeCurrent()-g_niv[i].tSweep<3*3600)
      { sw=" Varreu a "+PrimeiraMinuscula(g_niv[i].nome)+" às "+HoraBRde(g_niv[i].tSweep)+"."; }
   Plano b=MelhorPlano();
   s+=StringFormat("H1 %s, M15 %s e M5 %s; melhor nota agora: %s %d/10.",TendPalavra(g_mtf[2]),TendPalavra(g_mtf[3]),TendPalavra(g_mtf[4]),b.dir==1?"compra":"venda",b.score);
   return s+sw;
}

// ---------------- memória: fatos do Vitor ----------------
string g_fatosArq="ALIEN_memoria_fatos.txt";
void FatosLe(string &f[])
{
   ArrayResize(f,0); string s=ArqLe(g_fatosArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   for(int i=0;i<n;i++){ string x=l[i]; StringTrimLeft(x); StringTrimRight(x); if(x=="") continue; int k=ArraySize(f); ArrayResize(f,k+1); f[k]=x; }
}
void FatoTalvez(string txt)
{
   string u=AISemAcento(txt); StringToLower(u);
   string g[]={"eu prefiro","prefiro ","me chama de","nao gosto","não gosto","gosto de","gosto quando","lembra que","lembre que","lembra disso","meu horario","eu opero","so opero","sempre opero","nunca opero","meu stop","meu risco","minha meta","meu objetivo","nao quero","não quero"};
   bool hit=false; for(int i=0;i<ArraySize(g);i++) if(StringFind(u,g[i])>=0){ hit=true; break; }
   if(!hit || StringLen(txt)>300) return;
   string f[]; FatosLe(f);
   StringReplace(txt,"\r",""); StringReplace(txt,"\n"," ");
   string novo=TimeToString(AgoraBR(),TIME_DATE)+": "+(StringLen(txt)>160?StringSubstr(txt,0,160)+"...":txt);
   int n=ArraySize(f); ArrayResize(f,n+1); f[n]=novo;
   int st=MathMax(0,ArraySize(f)-15); string o="";
   for(int i=st;i<ArraySize(f);i++) o+=f[i]+"\r\n";
   ArqGrava(g_fatosArq,o);
}
string FatosJSON(){ string f[]; FatosLe(f); string o=""; for(int i=0;i<ArraySize(f);i++) o+=(o==""?"":",")+"\""+JEsc(f[i])+"\""; return "["+o+"]"; }
string FatosTxt(){ string f[]; FatosLe(f); if(ArraySize(f)==0) return ""; string s="O QUE EU SEI DO VITOR (ele mesmo contou):\n"; for(int i=0;i<ArraySize(f);i++) s+="- "+f[i]+"\n"; return s+"\n"; }
string MemoriaTxt()
{
   string f[]; FatosLe(f); MemLoad();
   string s="🧠 O que eu lembro:\n";
   if(ArraySize(f)==0) s+="Ainda nada sobre você. Se quiser, me conta tipo \"eu prefiro operar só em Londres\" que eu guardo.\n";
   else for(int i=0;i<ArraySize(f);i++) s+="• "+f[i]+"\n";
   s+=StringFormat("E as últimas %d mensagens da conversa. Pra eu esquecer tudo: /esquece",ArraySize(g_mem));
   return s;
}
void MemoriaApaga(){ ArqGrava(g_fatosArq,""); ArqGrava("ALIEN_chat_memoria.txt",""); ArrayResize(g_mem,0); }

// ---------------- 7. áudio do Telegram -> Gemini ----------------
bool BaixaUrl(string url,uchar &out[],int timeout=15000)
{
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",timeout,data,res,rh);
   if(code!=200) { Print("Áudio: download respondeu ",code," (erro ",GetLastError(),")"); return false; }
   int n=ArraySize(res); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=(uchar)res[i];
   return n>0;
}
// pega o texto da primeira "parte" da resposta nativa do Gemini (aceita espaço depois dos dois pontos)
string GeminiTexto(string r)
{
   int k=StringFind(r,"\"text\""); if(k<0) return "";
   int c=StringFind(r,":",k); if(c<0) return "";
   int q=StringFind(r,"\"",c+1); if(q<0) return "";
   string t=JDecode(r,q); StringTrimLeft(t); StringTrimRight(t); return t;
}
// chamada nativa do Gemini com mídia (áudio/imagem) + texto; tenta de novo no limite grátis (429)
string GeminiMidia(uchar &bin[],string mime,string pedido,int maxTok,double temp,string &erro)
{
   erro="";
   string key=StringLen(g_cfgAI2Key)>10?g_cfgAI2Key:(StringLen(g_cfgGem2)>10?g_cfgGem2:"");
   if(key==""){ erro="sem chave Gemini"; return ""; }
   uchar k0[], b64[];
   if(CryptEncode(CRYPT_BASE64,bin,k0,b64)<=0){ erro="não consegui codificar o arquivo"; return ""; }
   string sb=CharArrayToString(b64,0,ArraySize(b64),CP_ACP); StringReplace(sb,"\r",""); StringReplace(sb,"\n","");
   string body="{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\""+JEsc(pedido)+"\"},{\"inline_data\":{\"mime_type\":\""+mime+"\",\"data\":\""+sb+"\"}}]}],\"generationConfig\":{\"temperature\":"+DoubleToString(temp,1)+",\"maxOutputTokens\":"+IntegerToString(maxTok)+"}}";
   uchar u8[]; int n=StringToCharArray(body,u8,0,WHOLE_ARRAY,CP_UTF8); if(n>0 && u8[n-1]==0) n--;
   char data[],res[]; string rh; ArrayResize(data,n); for(int i=0;i<n;i++) data[i]=(char)u8[i];
   string hdr="Content-Type: application/json\r\nx-goog-api-key: "+key+"\r\n";
   int code=-1; string r="";
   for(int k=0;k<2;k++)
   {
      string url="https://generativelanguage.googleapis.com/v1beta/models/"+InpAI2Model+":generateContent";
      if(k==1){ if(StringLen(g_cfgGem2)>10 && key!=g_cfgGem2) hdr="Content-Type: application/json\r\nx-goog-api-key: "+g_cfgGem2+"\r\n"; else Sleep(3000); }
      ArrayResize(res,0); ResetLastError();
      code=WebRequest("POST",url,hdr,40000,data,res,rh);
      r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
      if(code!=429 && code!=500 && code!=503) break;
      Print("Gemini mídia ocupada (",code,") - tentando de novo");
   }
   if(code==-1){ erro="WebRequest bloqueado ("+IntegerToString(GetLastError())+")"; return ""; }
   if(code==429){ erro="limite grátis do Google"; return ""; }
   if(code!=200){ erro="Gemini respondeu "+IntegerToString(code); Print("Gemini mídia: ",erro,": ",StringSubstr(r,0,300)); return ""; }
   string t=GeminiTexto(r); StringReplace(t,"**","");
   if(t==""){ erro="Gemini não devolveu texto"; return ""; }
   return t;
}
string AudioParaTexto(uchar &aud[],string &erro)
{
   return GeminiMidia(aud,"audio/ogg","Transcreva este áudio em português do Brasil, exatamente o que a pessoa falou, sem comentar nada. Se não der pra entender, responda só: [inaudível]",400,0.0,erro);
}
// baixa um arquivo do Telegram pelo file_id (getFile + download)
bool TgBaixaArquivo(string fileId,uchar &bin[],long maxBytes,string &erro)
{
   erro=""; uchar tmp[];
   if(!BaixaUrl("https://api.telegram.org/bot"+g_cfgTgToken+"/getFile?file_id="+UrlEnc(fileId),tmp,8000)){ erro="getFile falhou"; return false; }
   string r0=CharArrayToString(tmp,0,WHOLE_ARRAY,CP_UTF8);
   string path=JStrKey(r0,"file_path"); long sz=StringToInteger(JNumKey(r0,"file_size"));
   if(path==""){ erro="sem caminho do arquivo"; return false; }
   if(sz>maxBytes){ erro="grande"; return false; }
   if(!BaixaUrl("https://api.telegram.org/file/bot"+g_cfgTgToken+"/"+path,bin,20000)){ erro="download falhou"; return false; }
   return true;
}
// foto mandada no Telegram -> Gemini olha a imagem (ex.: print de gráfico de outra plataforma)
void FotoHandle(string chat,string fileId,string legenda)
{
   if(StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10){ SendMsg("Pra eu olhar foto eu preciso da chave Gemini. Por enquanto, me descreve em texto 😉"); return; }
   uchar img[]; string erro;
   if(!TgBaixaArquivo(fileId,img,4000000,erro)){ SendMsg(erro=="grande"?"Essa foto é grande demais pra mim. Manda um print menor 🙏":"Não consegui pegar a foto agora. Tenta de novo."); return; }
   bool mercado=EhMercado(legenda) || legenda=="";
   string pedido="Você é o Alier, parceiro do Vitor no Telegram. Português do Brasil, informal, curto (até 6 frases), sem markdown. "
                 "Olhe a imagem e responda o que ele pediu"+(legenda!=""?": \""+legenda+"\"":". Se for gráfico, leia a estrutura (tendência, topos/fundos, liquidez varrida, rompimentos, zonas) e diga o que observar.")+
                 " Se for gráfico, use só preços visíveis na imagem; se não der pra ler, diga que não dá. Nunca prometa lucro; quem decide é ele.";
   if(mercado)
   {
      string ctx=ContextJSON();
      if(ContextValido(ctx)) pedido+="\nPara comparar, a leitura do "+_Symbol+" no MT5 agora (números confiáveis do robô): "+StringSubstr(ctx,0,3500);
   }
   string m=FatosTxt(); if(m!="") pedido+="\n"+m;
   string t=GeminiMidia(img,"image/jpeg",pedido,700,0.4,erro);
   if(t==""){ SendMsg(erro=="limite grátis do Google"?"A IA grátis do Google tá no limite agora 😅 Me manda a foto de novo em 1 minutinho.":"Não consegui analisar a foto agora ("+erro+"). Tenta de novo daqui a pouco."); return; }
   t=AISemVeredito(t);
   MemAdd("Vitor","[mandou uma foto] "+legenda); MemAdd("Alier",t);
   SendMsg("👀 "+t);
}
// conversa sobre qualquer assunto (não é mercado)
string SysGeral()
{
   return "Você é o Alier, assistente pessoal do Vitor no Telegram (ele é barbeiro e estuda trading). Ajuda em qualquer assunto: dúvidas, contas, textos, ideias, saúde do dia a dia, estudo. "
          "Português do Brasil, informal e acolhedor, curto (1 a 5 frases, a não ser que ele peça mais). Sem markdown. "
          "Se não souber ou for algo que muda rápido (notícia de hoje, preço, placar), diga que não tem acesso à internet em tempo real. "
          "Se ele parecer muito mal ou falar em se machucar, acolha e lembre do CVV: ligue 188 (grátis, 24h). "
          "Use o que você sabe dele e a conversa recente, sem repetir o que já disse. Nunca prometa lucro.";
}
void ChatGeral(string pergunta)
{
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma, a IA tá no limite. Tenta de novo em %d s.",w)); return; }
   string r=AIAskEx(SysGeral(),MemTxt()+"MENSAGEM DO VITOR:\n"+pergunta,500,false,false,0.7);
   if(r==""){ SendMsg(AIFalhaTxt()); return; }
   r=AISemVeredito(SemCamposCrus(r));
   FatoTalvez(pergunta); MemAdd("Vitor",pergunta); MemAdd("Alier",r);
   SendMsg(r);
}
void VozHandle(string chat,string fileId)
{
   if(!InpVoz){ SendMsg("Áudio tá desligado nas configurações (InpVoz). Me escreve que eu respondo 😉"); return; }
   if(StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10){ SendMsg("Pra entender áudio eu preciso da chave Gemini. Por enquanto, me escreve 😉"); return; }
   uchar aud[]; string erro;
   if(!TgBaixaArquivo(fileId,aud,2000000,erro)){ SendMsg(erro=="grande"?"Esse áudio ficou grande demais pra mim. Manda um de até 1 minuto 🙏":"Não consegui pegar seu áudio agora. Tenta de novo ou me escreve."); return; }
   string txt=AudioParaTexto(aud,erro);
   if(txt=="" || StringFind(txt,"[inaudível]")>=0)
   {
      Print("Áudio: ",erro);
      if(erro=="limite grátis do Google") SendMsg("A IA grátis do Google tá no limite agora 😅 Manda o áudio de novo em 1 minutinho.");
      else SendMsg(txt==""?"Ainda não consegui entender áudio aqui ("+erro+"). Me escreve que eu respondo 😉":"Não entendi o áudio 😅 Fala de novo mais perto do microfone ou me escreve.");
      return;
   }
   SendMsg("🎤 Entendi: \""+txt+"\"");
   TgHandle(chat,txt);
}

// ---------------- B. avisos proativos ----------------
string g_proArq="ALIEN_proativo.txt";
string g_alLogArq="ALIEN_alertas_log.csv";
string g_alLogHdr="hora_servidor;hora_brasilia;simbolo;tipo;dir;preco;r_pts;res15;res60;mov15_R;mov60_R;enviado";
void ProLoad()
{
   string s=ArqLe(g_proArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   if(n>0) g_proKeys=ChavesUne(g_proKeys,l[0]);
   if(n>1) g_proHora=l[1];
}
void ProSave()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   g_proKeys=ChavesCorta(g_proKeys,2500);
   ArqGrava(g_proArq,g_proKeys+"\r\n"+g_proHora+"\r\n");
}
int ProNaHora()
{
   string p[]; int n=StringSplit(g_proHora,';',p); string keep=""; int c=0; long now=(long)TimeGMT();
   if(MQLInfoInteger(MQL_TESTER)) now=(long)TimeCurrent();
   for(int i=0;i<n;i++){ long t=StringToInteger(p[i]); if(t>0 && now-t<3600){ keep+=(keep==""?"":";")+p[i]; c++; } }
   g_proHora=keep; return c;
}
bool ProTipoLivre(string tipo)
{
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_proTipo);i++) if(g_proTipo[i]==tipo) return (now-g_proTipoUlt[i]>=InpAlertaCooldownMin*60);
   return true;
}
void ProTipoMarca(string tipo)
{
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_proTipo);i++) if(g_proTipo[i]==tipo){ g_proTipoUlt[i]=now; return; }
   int k=ArraySize(g_proTipo); ArrayResize(g_proTipo,k+1); ArrayResize(g_proTipoUlt,k+1); g_proTipo[k]=tipo; g_proTipoUlt[k]=now;
}
void ProEnvia(string tipo,string key,int dir,double preco,string msg)
{
   if(StringFind(g_proKeys,"|"+key+"|")>=0) return;
   if(g_proMudoAte>0 && TimeCurrent()<g_proMudoAte) return;
   if(!ProTipoLivre(tipo)) return;
   if(ProNaHora()>=MathMax(InpAlertasMaxHora,1)) return;
   g_proKeys+=key+"|"; ProTipoMarca(tipo);
   long now=MQLInfoInteger(MQL_TESTER)?(long)TimeCurrent():(long)TimeGMT();
   g_proHora+=(g_proHora==""?"":";")+IntegerToString(now);
   double r=g_atr>0?g_atr:preco*0.0005;
   bool mandou=false;
   if(TgOk()) mandou=SendMsg(msg); else Print("ALIEN aviso: ",msg);
   CsvAppend(g_alLogArq,g_alLogHdr,StringFormat("%s;%s;%s;%s;%d;%s;%s;;;;;%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
      TimeToString(SrvParaBR(TimeCurrent()),TIME_DATE|TIME_MINUTES),_Symbol,tipo,dir,Fmt(preco),Fmt(r),mandou?"sim":"nao"));
   ProSave();
}
void ProativoBar()
{
   if(!InpAlertasProativos) return;
   if(!MQLInfoInteger(MQL_TESTER) && TgOk() && InpTgChat && !g_tgMaster) return;   // só um gráfico avisa
   datetime m1=iTime(_Symbol,PERIOD_M1,0); if(m1==0 || m1==g_proBarM1) return;
   g_proBarM1=m1;
   if(!g_ready) return;
   datetime now=TimeCurrent(); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0) return;
   int pe=PeriodSeconds(InpTFExec);
   // varrida de liquidez (Ásia, ontem, Londres)
   for(int i=0;i<ArraySize(g_niv);i++)
   {
      if(g_niv[i].estado!=ST_VARRIDA || g_niv[i].tSweep<=0) continue;
      string nm=g_niv[i].nome;
      if(StringFind(nm,"Ásia")<0 && StringFind(nm,"ontem")<0 && StringFind(nm,"Londres")<0) continue;
      if(now-g_niv[i].tSweep>2*pe+60) continue;
      int d=(g_niv[i].lado==NV_BELOW?1:-1);
      ProEnvia("varrida","v"+nm+IntegerToString((long)g_niv[i].tSweep),d,g_niv[i].preco,
         StringFormat("💧 Varreu a %s em %s (%s, Brasília). Pode ser armadilha de liquidez: olha o gráfico antes de qualquer coisa.",PrimeiraMinuscula(nm),Fmt(g_niv[i].preco),HoraBRde(g_niv[i].tSweep)));
   }
   // mudança de estrutura no TF da estrutura
   int nb=ArraySize(g_bos);
   if(nb>0 && now-g_bos[nb-1].tBreak<=2*pe+60)
   {
      BOSe e=g_bos[nb-1]; string tf=TfNome(InpTFExec);
      string m=e.choch?StringFormat("🔄 Mudou a estrutura no %s (CHoCH) pra %s: rompeu %s. Pode ser virada, espera confirmar.",tf,e.dir==1?"alta":"baixa",Fmt(e.preco))
                      :StringFormat("%s Rompeu a estrutura no %s (BOS) pra %s em %s. A tendência curta tá seguindo.",e.dir==1?"📈":"📉",tf,e.dir==1?"alta":"baixa",Fmt(e.preco));
      ProEnvia(e.choch?"choch":"bos","b"+IntegerToString((long)e.tBreak),e.dir,bid,m);
   }
   // preço dentro de um bloco de ordens não rompido
   for(int i=ArraySize(g_obs)-1;i>=0;i--)
   {
      if(g_obs[i].brk) continue;
      if(bid<=g_obs[i].hi && bid>=g_obs[i].lo)
      {
         ProEnvia("bloco","o"+IntegerToString((long)g_obs[i].t0),g_obs[i].dir,bid,
            StringFormat("🧱 Chegou no bloco de ordens de %s (%s a %s). Zona forte: olha a reação no M1.",g_obs[i].dir==1?"compra":"venda",Fmt(g_obs[i].lo),Fmt(g_obs[i].hi)));
         break;
      }
   }
   // toque na VWAP (vela M1 que acabou de fechar cruzou a VWAP, a anterior não)
   if(g_engVWAP>0)
   {
      double h1=iHigh(_Symbol,PERIOD_M1,1), l1=iLow(_Symbol,PERIOD_M1,1), h2=iHigh(_Symbol,PERIOD_M1,2), l2=iLow(_Symbol,PERIOD_M1,2);
      if(h1>=g_engVWAP && l1<=g_engVWAP && !(h2>=g_engVWAP && l2<=g_engVWAP))
         ProEnvia("vwap","w"+IntegerToString((long)(now/1800)),0,g_engVWAP,
            StringFormat("〰️ Tocou na VWAP (%s). Ela costuma segurar ou puxar o preço no dia; vê se segura.",Fmt(g_engVWAP)));
   }
   // setup completo 7/7
   Plano b=MelhorPlano();
   if(PlanoValido(b) && b.score>=InpScoreTrade)
   {
      int ok=0; for(int i=0;i<7;i++) if(b.pts[i]) ok++;
      if(ok>=7)
         ProEnvia("setup","s"+IntegerToString(b.dir)+IntegerToString((long)(now/900)),b.dir,b.entry,
            StringFormat("⚡ Montou setup completo: %s nota %d/10, checklist 7/7. Entrada %s, 🛑 stop %s, 🎯 alvo %s. Só aviso, a decisão é sua.",b.dir==1?"🟢 compra":"🔴 venda",b.score,Fmt(b.entry),Fmt(b.stop),Fmt(b.target)));
   }
}
// resultado dos avisos depois de 15 e 60 min (em R = ATR do TF da estrutura)
string MovR(datetime t0,int minutos,double preco,double r,int dir)
{
   int sh=iBarShift(_Symbol,PERIOD_M1,t0+minutos*60,false); if(sh<0) return "";
   double c=iClose(_Symbol,PERIOD_M1,sh); if(c<=0 || r<=0) return "";
   double m=(c-preco)/r; if(dir<0) m=-m;
   return DoubleToString(m,2);
}
void AlertasScore()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(g_alLogArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string lines[]; int n=0;
   while(!FileIsEnding(h) && n<3000){ string l=FileReadString(h); if(l=="") continue; ArrayResize(lines,n+1); lines[n++]=l; }
   FileClose(h);
   bool ch=false; datetime now=TimeCurrent();
   for(int i=1;i<n;i++)
   {
      string p[]; int c=StringSplit(lines[i],';',p); if(c<12 || p[2]!=_Symbol) continue;
      datetime t0=StringToTime(p[0]); if(t0<=0) continue;
      int ago=(int)((now-t0)/60); int dir=(int)StringToInteger(p[4]); double px=StringToDouble(p[5]), r=StringToDouble(p[6]);
      bool rc=false;
      MqlRates rr[]; ArraySetAsSeries(rr,true);
      if(ago>=15 && p[7]=="")
      { int k=CopyRates(_Symbol,PERIOD_M1,t0,t0+15*60,rr); p[7]=dir==0?"-":VerScoreBar(dir,px,r,rr,k,t0); p[9]=MovR(t0,15,px,r,dir); rc=true; }
      if(ago>=60 && p[8]=="")
      { int k=CopyRates(_Symbol,PERIOD_M1,t0,t0+60*60,rr); p[8]=dir==0?"-":VerScoreBar(dir,px,r,rr,k,t0); p[10]=MovR(t0,60,px,r,dir); rc=true; }
      if(rc){ string o=p[0]; for(int k=1;k<c;k++) o+=";"+p[k]; lines[i]=o; ch=true; }
   }
   if(!ch) return;
   int w=FileOpen(g_alLogArq,FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w);
}

// ---------------- B. disciplina: "seguiu o plano?" ----------------
string g_discArq="ALIEN_disciplina.csv";
string g_discHdr="fechamento_servidor;fechamento_brasilia;hora_brasilia;dia_semana;simbolo;lado;origem;lote;resultado_usd;posicao;seguiu;motivo";
bool DiscTem(long pos)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE); if(h==INVALID_HANDLE) return false;
   string k=";"+IntegerToString(pos)+";"; bool achou=false;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(StringFind(l,k)>=0){ achou=true; break; } }
   FileClose(h); return achou;
}
bool DiscAtualiza(long pos,int col,string val)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ); if(h==INVALID_HANDLE) return false;
   string lines[]; int n=0;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(l=="") continue; ArrayResize(lines,n+1); lines[n++]=l; }
   FileClose(h);
   bool ok=false;
   for(int i=n-1;i>=1;i--)
   {
      string p[]; int c=StringSplit(lines[i],';',p); if(c<12) continue;
      if(StringToInteger(p[9])!=pos) continue;
      p[col]=CsvLimpo(val); string o=p[0]; for(int k=1;k<c;k++) o+=";"+p[k]; lines[i]=o; ok=true; break;
   }
   if(!ok) return false;
   int w=FileOpen(g_discArq,FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return false;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w); return true;
}
void DisciplinaFechou(ulong deal)
{
   if(MQLInfoInteger(MQL_TESTER) || !InpDisciplina) return;
   long en=HistoryDealGetInteger(deal,DEAL_ENTRY);
   if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_OUT_BY) return;
   long pos=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(PositionSelectByTicket((ulong)pos)) return;                // fechou só uma parte: espera fechar tudo
   if(TgOk() && InpTgChat && !TgMaster()) return;                 // só um gráfico pergunta
   if(DiscTem(pos)) return;
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
   long tipo=HistoryDealGetInteger(deal,DEAL_TYPE);
   string lado=(tipo==DEAL_TYPE_SELL?"compra":"venda");          // saída vendendo = era compra
   bool robo=(HistoryDealGetInteger(deal,DEAL_MAGIC)==InpMagic);
   double net=0, vol=HistoryDealGetDouble(deal,DEAL_VOLUME);
   if(HistorySelectByPosition(pos))
      for(int i=0;i<HistoryDealsTotal();i++){ ulong d=HistoryDealGetTicket(i); if(d==0) continue; net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION); }
   else net=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);
   datetime ts=(datetime)HistoryDealGetInteger(deal,DEAL_TIME), tb=SrvParaBR(ts);
   MqlDateTime md; TimeToStruct(tb,md);
   string dias[7]={"domingo","segunda","terça","quarta","quinta","sexta","sábado"};
   CsvAppend(g_discArq,g_discHdr,StringFormat("%s;%s;%02d;%s;%s;%s;%s;%.2f;%.2f;%I64d;pendente;",TimeToString(ts,TIME_DATE|TIME_MINUTES),TimeToString(tb,TIME_DATE|TIME_MINUTES),
      md.hour,dias[md.day_of_week],sym,lado,robo?"robo":"manual",vol,net,pos));
   if(net<0 && InpPausaAposStopMin>0)
   {
      g_proMudoAte=TimeCurrent()+InpPausaAposStopMin*60;
      if(TgOk()) SendMsg(StringFormat("Respira 🙏 Vou segurar os avisos automáticos por %d min. As ordens não ficam travadas.",InpPausaAposStopMin));
   }
   if(!TgOk()) return;
   string q=StringFormat("%s Fechou %s de %s (%s) com %+.2f.\nSeguiu o plano?",net>=0?"✅":"🔻",lado,sym,robo?"do robô":"sua",net);
   SendMsgMarkup(q,TgKbSimNao("👍 Segui","/disc s "+IntegerToString(pos),"👎 Não segui","/disc n "+IntegerToString(pos)));
}
void DisciplinaResposta(string args)
{
   string p[]; if(StringSplit(args,' ',p)<2){ return; }
   long pos=StringToInteger(p[1]); bool sim=(p[0]=="s");
   if(!DiscAtualiza(pos,10,sim?"sim":"nao")){ SendMsg("Não achei esse trade no diário de disciplina, mas valeu por responder."); return; }
   g_discPos=pos; g_discT=TimeCurrent();
   SendMsg(sim?"Boa! Anotado 👍 Disciplina é o que paga as contas. Se quiser, me conta em uma frase o que funcionou (ou só ignora).":
               "Anotado, sem julgamento 🙏 Me conta em uma frase o que pegou (pressa, medo, entrou fora do plano...). Isso vira aprendizado no domingo.");
}
// motivo opcional: a próxima mensagem (até 10 min, sem "?") vira o motivo
bool DisciplinaMotivo(string text)
{
   if(g_discPos<=0) return false;
   if(TimeCurrent()-g_discT>600 || StringFind(text,"?")>=0){ g_discPos=0; return false; }
   DiscAtualiza(g_discPos,11,text); g_discPos=0;
   SendMsg("Anotado ✍️ Valeu!");
   return true;
}
string DisciplinaResumo(int dias)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ); if(h==INVALID_HANDLE) return "Ainda não tenho trade seu registrado pra medir disciplina.";
   string desde=TimeToString(AgoraBR()-dias*86400,TIME_DATE);
   int s=0,nn=0,pend=0; double rs=0,rn=0; int eh[24]; ArrayInitialize(eh,0); int ec=0,ev=0;
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<12) continue;
      if(StringSubstr(p[1],0,10)<desde) continue;
      double r=StringToDouble(p[8]);
      if(p[10]=="sim"){ s++; rs+=r; }
      else if(p[10]=="nao"){ nn++; rn+=r; int hh=(int)StringToInteger(p[2]); if(hh>=0&&hh<24) eh[hh]++; if(p[5]=="compra") ec++; else ev++; }
      else pend++;
   }
   FileClose(h);
   if(s+nn+pend==0) return "Nenhum trade seu fechou nesse período.";
   string o=StringFormat("Trades fechados: %d. Você disse que seguiu o plano em %d e não seguiu em %d",s+nn+pend,s,nn)+(pend>0?StringFormat(" (%d sem resposta)",pend):"")+".";
   if(s+nn>0) o+=StringFormat(" Disciplina: %.0f%%.",100.0*s/(s+nn));
   if(s>0 && nn>0) o+=StringFormat(" Seguindo o plano deu %+.2f; fora do plano deu %+.2f.",rs,rn);
   if(nn>0)
   {
      int hb=0; for(int i=1;i<24;i++) if(eh[i]>eh[hb]) hb=i;
      o+=StringFormat(" Onde mais escapou: perto das %dh (Brasília) e mais nas %s.",hb,ec>=ev?"compras":"vendas");
   }
   return o;
}

// ---------------- backup semanal dos CSV (MQL5\Files\ALIEN_backup\AAAA-MM-DD) ----------------
void BackupSemanal()
{
   if(MQLInfoInteger(MQL_TESTER) || !InpBackupSemanal) return;
   datetime br=AgoraBR();
   string ult=ArqLe("ALIEN_backup_ultimo.txt");
   if(StringToInteger(ult)>0 && (long)br-StringToInteger(ult)<7*86400) return;
   string pasta="ALIEN_backup\\"+StringSubstr(TimeToString(br,TIME_DATE),0,10);
   StringReplace(pasta,".","-");
   string nome; int n=0;
   long h=FileFindFirst("ALIEN_*.csv",nome);
   if(h!=INVALID_HANDLE)
   {
      do { if(FileCopy(nome,0,pasta+"\\"+nome,FILE_REWRITE)) n++; } while(FileFindNext(h,nome));
      FileFindClose(h);
   }
   ArqGrava("ALIEN_backup_ultimo.txt",IntegerToString((long)br));
   Print("ALIEN: backup semanal de ",n," arquivos em MQL5\\Files\\",pasta);
}

// ---------------- notícias: agenda do dia, bom dia e resultado depois da notícia ----------------
string AgendaTxt()
{
   if(!CalOn()) return "O calendário não está ligado agora.";
   LoadNews(true);
   datetime hoje=DayStart(AgoraBR()); string s=""; int n=0;
   for(int i=0;i<ArraySize(g_news);i++)
   {
      datetime b=SrvParaBR(g_news[i].t); if(DayStart(b)!=hoje) continue;
      s+=StringFormat("%s %s %s %s\n",TimeToString(b,TIME_MINUTES),g_news[i].imp==3?"🔴":"🟡",g_news[i].cur,g_news[i].nome); n++;
   }
   if(n==0) s="Nenhuma notícia forte ou média hoje ("+InpCalMoedas+"). Dia mais limpo 🙂\n";
   return "🗓️ Agenda de hoje (Brasília; 🔴 forte, 🟡 média):\n"+s;
}
void BomDia()
{
   if(!TgOk() || (InpTgChat && !g_tgMaster)) return;
   datetime br=AgoraBR(); MqlDateTime d; TimeToStruct(br,d);
   if(d.day_of_week==0 || d.day_of_week==6) return;
   if(d.hour!=8 || d.min>30) return;                         // ~08:00 de Brasília, dias úteis
   string key="BOMDIA"+TimeToString(br,TIME_DATE);
   if(StringFind(g_resFeitos,key+"|")>=0) return;
   g_resFeitos+=key+"|"; TgEstadoSave();
   Plano b=MelhorPlano();
   SendMsg("☀️ Bom dia, Vitor!\n"+AgendaTxt()+StringFormat("\nNo %s: viés do dia %s; H1 %s, M15 %s. Melhor nota agora: %s %d/10.\nAntes de notícia forte eu te aviso 15 min antes.",
      _Symbol,g_biasTxt,TendPalavra(g_mtf[2]),TendPalavra(g_mtf[3]),b.dir==1?"compra":"venda",b.score));
}
string CalNum(double v){ return DoubleToString(v,(MathAbs(v)<10?2:1)); }
void NoticiaResultado()
{
   if(!TgOk() || !CalOn() || (InpTgChat && !g_tgMaster)) return;
   LoadNews(); datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3 || StringFind(InpPreAlertaMoedas,g_news[i].cur)<0) continue;
      long dt=(long)(now-g_news[i].t); if(dt<5*60 || dt>40*60) continue;
      string key="P"+IntegerToString((long)g_news[i].id);
      if(StringFind(g_alertados,"|"+key+"|")>=0) continue;
      MqlCalendarValue v; string num="";
      if(CalendarValueById(g_news[i].id,v))
      {
         if(v.HasActualValue()) num+="atual "+CalNum(v.GetActualValue());
         if(v.HasForecastValue()) num+=(num==""?"":", ")+"previsão "+CalNum(v.GetForecastValue());
         if(v.HasPreviousValue()) num+=(num==""?"":", ")+"anterior "+CalNum(v.GetPreviousValue());
      }
      if(StringFind(num,"atual")<0 && dt<20*60) continue;     // espera o número sair (até 20 min)
      g_alertados+=key+"|"; TgEstadoSave();
      int s0=iBarShift(_Symbol,PERIOD_M1,g_news[i].t,false), s5=iBarShift(_Symbol,PERIOD_M1,g_news[i].t+5*60,false);
      string mov="";
      if(s0>=0 && s5>=0)
      {
         double p0=iOpen(_Symbol,PERIOD_M1,s0), p5=iClose(_Symbol,PERIOD_M1,s5);
         if(p0>0 && p5>0) mov=StringFormat(" O %s andou %+.2f nos 5 min depois (%s → %s).",_Symbol,p5-p0,Fmt(p0),Fmt(p5));
      }
      SendMsg(StringFormat("📰 Saiu %s (%s, %s Brasília)%s.%s Espera a poeira baixar antes de entrar.",g_news[i].nome,g_news[i].cur,HHMMBR(g_news[i].t),num!=""?": "+num:" (sem número no calendário)",mov));
   }
}
