//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_TELEGRAM.mq5                                     |
//| EA "carteiro": só lê os sinais do indicador ALIEN_PROFESSOR e    |
//| manda no Telegram. NÃO TEM NENHUMA FUNÇÃO DE ORDEM. Nunca opera. |
//| Precisa: Ferramentas > Opções > Expert Advisors > "Permitir      |
//| WebRequest" com https://api.telegram.org na lista.               |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "1.00"
#property description "Envia os sinais do ALIEN PROFESSOR pro Telegram (texto + print do gráfico). Não opera."

input bool   InpUseTelegram    = true;  // Usar Telegram
input string InpTelegramToken  = "";    // Token do bot (crie um NOVO no @BotFather)
input string InpTelegramChatId = "";    // Seu chat id
input bool   InpEnviarFoto     = true;  // Mandar print do gráfico junto
input bool   InpTesteAoLigar   = true;  // Mandar mensagem de teste ao ligar

string   g_sym[]; double g_last[];

string UrlEnc(string s)
{
   uchar u[]; int n=StringToCharArray(s,u,0,WHOLE_ARRAY,CP_UTF8); string r="";
   for(int i=0;i<n-1;i++)
   {
      uchar c=u[i];
      if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'||c=='~') r+=CharToString(c);
      else r+=StringFormat("%%%02X",c);
   }
   return r;
}
bool TgOk(){ return InpUseTelegram && StringLen(InpTelegramToken)>20 && StringLen(InpTelegramChatId)>0; }
bool SendMsg(string text)
{
   if(!TgOk()) return false;
   string url="https://api.telegram.org/bot"+InpTelegramToken+"/sendMessage";
   string body="chat_id="+UrlEnc(InpTelegramChatId)+"&text="+UrlEnc(text);
   char data[],res[]; string rh; StringToCharArray(body,data,0,StringLen(body));
   ResetLastError();
   int code=WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",8000,data,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return false; }
   if(code!=200) Print("Telegram respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
void AddStr(char &buf[],string s){ uchar u[]; int n=StringToCharArray(s,u,0,WHOLE_ARRAY,CP_UTF8); int k=ArraySize(buf); ArrayResize(buf,k+n-1); for(int i=0;i<n-1;i++) buf[k+i]=(char)u[i]; }
bool SendPhoto(string file,string caption)
{
   if(!TgOk()) return false;
   int h=FileOpen(file,FILE_READ|FILE_BIN); if(h==INVALID_HANDLE){ Print("Telegram: sem print ",file); return false; }
   uchar img[]; FileReadArray(h,img); FileClose(h);
   string bd="----ALIENPROF"+IntegerToString(GetTickCount());
   char buf[]; ArrayResize(buf,0);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n"+InpTelegramChatId+"\r\n");
   if(StringLen(caption)>1000) caption=StringSubstr(caption,0,1000);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n"+caption+"\r\n");
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"grafico.png\"\r\nContent-Type: image/png\r\n\r\n");
   int k=ArraySize(buf); int n=ArraySize(img); ArrayResize(buf,k+n); for(int i=0;i<n;i++) buf[k+i]=(char)img[i];
   AddStr(buf,"\r\n--"+bd+"--\r\n");
   char res[]; string rh;
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+InpTelegramToken+"/sendPhoto","Content-Type: multipart/form-data; boundary="+bd+"\r\n",15000,buf,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram foto respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
string ReadTxt(string f)
{
   int h=FileOpen(f,FILE_READ|FILE_BIN); if(h==INVALID_HANDLE) return "";
   uchar u[]; FileReadArray(h,u); FileClose(h); return CharArrayToString(u,0,WHOLE_ARRAY,CP_UTF8);
}
int OnInit()
{
   if(!TgOk()) Print("Telegram: coloque token e chat id (o EA fica parado sem eles).");
   string as=AIStatus(); if(as!="") Print(as);
   // marca os sinais que já existem como enviados (não reenvia sinais velhos)
   for(int i=0;i<GlobalVariablesTotal();i++){ string n=GlobalVariableName(i); if(StringFind(n,"APROF_SIG_")==0){ int k=ArraySize(g_sym); ArrayResize(g_sym,k+1); ArrayResize(g_last,k+1); g_sym[k]=StringSubstr(n,10); g_last[k]=GlobalVariableGet(n); } }
   if(InpTesteAoLigar && TgOk()) SendMsg("ALIEN PROFESSOR conectado no "+_Symbol+". Vou avisar aqui quando a nota passar do limite. Lembre: só apoio, a decisão é sua.");
   EventSetTimer(2);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); }
void OnTimer()
{
   for(int i=0;i<GlobalVariablesTotal();i++)
   {
      string n=GlobalVariableName(i); if(StringFind(n,"APROF_SIG_")!=0) continue;
      string sym=StringSubstr(n,10); double v=GlobalVariableGet(n);
      int k=-1; for(int j=0;j<ArraySize(g_sym);j++) if(g_sym[j]==sym){ k=j; break; }
      if(k<0){ k=ArraySize(g_sym); ArrayResize(g_sym,k+1); ArrayResize(g_last,k+1); g_sym[k]=sym; g_last[k]=0; }
      if(v<=g_last[k]) continue;
      g_last[k]=v;
      string txt=ReadTxt("APROF_SINAL_"+sym+".txt"); if(txt=="") continue;
      string ia=AIAsk(txt); if(ia!="") txt+="\n\nANÁLISE IA (opinião):\n"+ia;
      bool sent=false;
      if(InpEnviarFoto && sym==_Symbol)
      {
         string f="APROF_tg_"+IntegerToString((long)v)+".png";
         ChartRedraw(0);
         if(ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)){ Sleep(500); sent=SendPhoto(f,txt); FileDelete(f); }
      }
      if(!sent) SendMsg(txt);
   }
}
void OnTick(){}

//====================================================================
// ANÁLISE IA (opcional). Só comenta; por padrão NUNCA muda decisão.
enum ENUM_AIMODE { AMBAS=0, PRINCIPAL_COM_RESERVA=1 };
input group "=== Análise IA (opcional) ==="
input ENUM_AIMODE InpAIMode = AMBAS;                                      // AMBAS = Grok + Gemini juntos, 1 resposta unida | PRINCIPAL_COM_RESERVA
input bool   InpUseAI      = true;                                         // Usar análise IA (precisa de chave)
input string InpAIProvider = "xai";                                        // Provedor (qualquer API compatível com OpenAI)
input string InpAIEndpoint = "https://api.x.ai/v1/chat/completions";      // Endpoint (xAI; ou https://api.openai.com/v1/chat/completions)
input string InpAIModel    = "grok-4.20-0309-non-reasoning";               // Modelo (rápido)
input string InpAIKey      = "";                                           // Chave da API (vazio = IA desligada)
input string InpAI2Endpoint= "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"; // Reserva: Google Gemini (compatível OpenAI)
input string InpAI2Model   = "gemini-3.5-flash-lite";                      // Modelo reserva
input string InpAI2Key     = "";                                           // Chave Gemini (vazio = sem reserva)
input int    InpAIMinutos  = 0;                                            // Análise a cada N minutos também (0 = só nos sinais)
input bool   InpAIVeto     = false;                                        // IA pode VETAR (só opera se o VEREDITO for o lado do sinal; em AMBAS, as duas têm que concordar)
input int    InpAIMinSeg   = 15;                                           // Limite: mínimo de segundos entre perguntas à IA
input int    InpAIMaxHora  = 30;                                           // Limite: máximo de perguntas à IA por hora (0 = sem limite)

string   g_aiTxt="";
datetime g_aiLast=0;

bool AIOn(){ return InpUseAI && (StringLen(InpAIKey)>10 || StringLen(InpAI2Key)>10) && !MQLInfoInteger(MQL_TESTER); }
string JEsc(string s)
{
   StringReplace(s,"\\","\\\\"); StringReplace(s,"\"","\\\""); StringReplace(s,"\n","\\n"); StringReplace(s,"\r",""); StringReplace(s,"\t"," ");
   return s;
}
// extrai o primeiro "content":"..." da resposta
string JContent(string r)
{
   int c0=StringFind(r,"\"content\""); if(c0<0) return "";
   int k=StringFind(r,":",c0); if(k<0) return "";
   int p=StringFind(r,"\"",k+1); if(p<0) return "";
   string out=""; int n=StringLen(r);
   for(int i=p+1;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(c=='\\' && i+1<n)
      {
         ushort d=StringGetCharacter(r,i+1); i++;
         if(d=='n') out+="\n"; else if(d=='t') out+=" "; else if(d=='u' && i+4<n){ out+=ShortToString((ushort)StringToInteger("0x"+StringSubstr(r,i+1,4))); i+=4; }
         else out+=ShortToString(d);
         continue;
      }
      if(c=='"') break;
      out+=ShortToString(c);
   }
   return out;
}
// limite de uso da IA (não gastar cota / não travar o robô)
ulong g_aiCalls[]; ulong g_aiLastMs=0;
int AIEsperaSeg()   // 0 = pode perguntar; >0 = segundos para esperar
{
   ulong now=GetTickCount64();
   if(InpAIMinSeg>0 && g_aiLastMs>0 && now-g_aiLastMs<(ulong)InpAIMinSeg*1000) return (int)(((ulong)InpAIMinSeg*1000-(now-g_aiLastMs))/1000)+1;
   if(InpAIMaxHora>0)
   {
      int k=0; for(int i=0;i<ArraySize(g_aiCalls);i++) if(now-g_aiCalls[i]<3600000) g_aiCalls[k++]=g_aiCalls[i];
      ArrayResize(g_aiCalls,k);
      if(k>=InpAIMaxHora) return (int)((3600000-(now-g_aiCalls[0]))/1000)+1;
   }
   return 0;
}
void AIMarca(){ ulong now=GetTickCount64(); g_aiLastMs=now; int k=ArraySize(g_aiCalls); ArrayResize(g_aiCalls,k+1); g_aiCalls[k]=now; }
string AISysPadrao()
{
   return "Você é um professor de trading de SMC/liquidez. Responda em português do Brasil, no máximo 4 linhas curtas, sem prometer lucro. "
          "Diga o que confirma e o que invalida o setup, e o que observar no M1.";
}
// pergunta pra IA: tenta xAI; se der erro/tempo/cota, tenta a reserva (Gemini)
string AIAsk(string estado){ return AIAskEx(AISysPadrao(),estado,220,true); }   // sinais: passam do limite (poucos por dia)
string   g_aiVeredito="";   // COMPRA / VENDA / ESPERAR da última análise
bool     g_aiConcordam=false;
string AIVer(string t)
{
   string u=t; StringToUpper(u); int k=-1, f=0;
   while(true){ int q=StringFind(u,"VEREDITO",f); if(q<0) break; k=q; f=q+1; }
   if(k<0) return "";
   string r=StringSubstr(u,k,40);
   if(StringFind(r,"COMPRA")>=0) return "COMPRA";
   if(StringFind(r,"VENDA")>=0) return "VENDA";
   if(StringFind(r,"ESPERA")>=0) return "ESPERAR";
   return "";
}
string AISemVeredito(string t)
{
   string ls[]; int n=StringSplit(t,'\n',ls); string o="";
   for(int i=0;i<n;i++){ string u=ls[i]; StringToUpper(u); if(StringFind(u,"VEREDITO")>=0 || StringFind(u,"CONFIAN")==0) continue; o+=(o==""?"":"\n")+ls[i]; }
   StringTrimRight(o); return o;
}
// respostas brutas das IAs ficam em MQL5\Files\ALIEN_ia_log.txt (só respostas, nunca chaves)
void AILog(string tag,string txt)
{
   int h=FileOpen("ALIEN_ia_log.txt",FILE_READ|FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END); FileWriteString(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+" "+_Symbol+" ["+tag+"] "+txt+"\r\n"); FileClose(h);
}
string AIAskEx(string sys,string user,int maxTok,bool force=false,bool verdict=true)
{
   if(!AIOn()) return "";
   if(!force && AIEsperaSeg()>0){ Print("IA: limite de uso - pulei esta pergunta"); return ""; }
   AIMarca();
   g_aiVeredito=""; g_aiConcordam=false;
   string sysV=verdict ? sys+" Na última linha escreva exatamente uma destas: VEREDITO: COMPRA / VEREDITO: VENDA / VEREDITO: ESPERAR." : sys;
   bool hA=StringLen(InpAIKey)>10, hB=StringLen(InpAI2Key)>10;
   string t="", conf="";
   if(InpAIMode==AMBAS && hA && hB)
   {
      string a=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,InpAIKey,maxTok);
      string g=AIAskOne(sysV,user,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok);
      string va=AIVer(a), vg=AIVer(g);
      AILog("GROK "+va,a); AILog("GEMINI "+vg,g);
      if(a=="" && g=="") return "";
      if(!verdict) g_aiVeredito="";
      if(a=="" || g=="")
      {
         t=(a!=""?a:g); g_aiVeredito=(a!=""?va:vg); if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
         conf="Confiança: só "+(a!=""?"GROK":"GEMINI")+" respondeu agora";
      }
      else
      {
         g_aiConcordam=(va!="" && va==vg);
         g_aiVeredito=g_aiConcordam?va:"ESPERAR";
         if(!verdict){ g_aiConcordam=true; g_aiVeredito=""; }
         int lin = maxTok<=250 ? 5 : 12;
         string sysM= verdict ?
                     "Você une duas análises de trading em UMA só, em português do Brasil, curta (no máximo "+IntegerToString(lin)+" linhas), sem markdown, sem citar quem escreveu. "
                     "Tom direto e seguro, com os motivos claros. Use só o que está nas análises, não invente preços. Onde elas discordam, diga isso. Na última linha escreva exatamente: VEREDITO: "+g_aiVeredito+"."
                     : "Você une duas respostas em UMA só, em português do Brasil, natural e direta (no máximo "+IntegerToString(lin)+" linhas), sem markdown, sem citar quem escreveu. Fique com o melhor das duas.";
         string uM="ANÁLISE 1:\n"+AISemVeredito(a)+"\nVEREDITO 1: "+va+"\n\nANÁLISE 2:\n"+AISemVeredito(g)+"\nVEREDITO 2: "+vg;
         string m=AIAskOne(sysM,uM,InpAIEndpoint,InpAIModel,InpAIKey,maxTok);
         if(m=="") m=AIAskOne(sysM,uM,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok);
         if(StringLen(AISemVeredito(m))<20) m=a;   // união vazia -> usa a 1ª análise
         AILog("UNIDA "+g_aiVeredito,m);
         t=m;
         conf=g_aiConcordam?"Confiança: as duas IAs concordam":"Confiança: IAs divergiram (GROK "+(va==""?"?":va)+", GEMINI "+(vg==""?"?":vg)+") → ESPERAR";
      }
   }
   else
   {
      string who="";
      if(hA){ t=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,InpAIKey,maxTok); who="GROK"; }
      if(t=="" && hB){ t=AIAskOne(sysV,user,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok); who="GEMINI"; if(t!="") Print("IA: usei a reserva (",InpAI2Model,")"); }
      if(t=="") return "";
      g_aiVeredito=AIVer(t); if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
      AILog(who+" "+g_aiVeredito,t);
      conf="Confiança: 1 IA ("+who+")";
   }
   g_aiLast=TimeCurrent();
   if(!verdict){ g_aiVeredito=""; return AISemVeredito(t); }
   return AISemVeredito(t)+"\nVEREDITO: "+g_aiVeredito+"\n"+conf;
}
string AIAskOne(string sys,string estado,string endpoint,string model,string key,int maxTok)
{
   string body="{\"model\":\""+JEsc(model)+"\",\"temperature\":0.2,\"max_tokens\":"+IntegerToString(maxTok)+",\"messages\":[{\"role\":\"system\",\"content\":\""+JEsc(sys)+"\"},{\"role\":\"user\",\"content\":\""+JEsc(estado)+"\"}]}";
   char data[],res[]; string rh;
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); ArrayResize(data,n-1);
   string hdr="Content-Type: application/json\r\nAuthorization: Bearer "+key+"\r\n";
   ResetLastError();
   int code=WebRequest("POST",endpoint,hdr,15000,data,res,rh);
   if(code==-1){ Print("IA: WebRequest bloqueado (erro ",GetLastError(),"). Adicione o endereço do endpoint em Ferramentas > Opções > Expert Advisors."); return ""; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ Print("IA respondeu ",code,": ",StringSubstr(r,0,300)); return ""; }
   string t=JContent(r); StringReplace(t,"**",""); StringTrimLeft(t); StringTrimRight(t);
   return t;
}
// veto: com InpAIVeto ligado só opera se o VEREDITO for o lado do sinal (em AMBAS, divergência = ESPERAR = não opera)
bool AIVetou(string t,int dir){ if(!InpAIVeto || t=="") return false; return g_aiVeredito!=(dir==1?"COMPRA":"VENDA"); }
string AIStatus()
{
   if(!InpUseAI) return "IA: desligada";
   if(StringLen(InpAIKey)<=10 && StringLen(InpAI2Key)<=10) return "IA: coloque sua chave em InpAIKey (xAI) ou InpAI2Key (Gemini)";
   if(MQLInfoInteger(MQL_TESTER)) return "IA: não roda no testador";
   return "";
}
