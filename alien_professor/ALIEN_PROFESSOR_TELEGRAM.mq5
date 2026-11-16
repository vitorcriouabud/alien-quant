//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_TELEGRAM.mq5                                     |
//| EA "carteiro": só lê os sinais do indicador ALIEN_PROFESSOR e    |
//| manda no Telegram. NÃO TEM NENHUMA FUNÇÃO DE ORDEM. Nunca opera. |
//| Precisa: Ferramentas > Opções > Expert Advisors > "Permitir      |
//| WebRequest" com https://api.telegram.org na lista.               |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "12.70"
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
   AICfgInit();
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
// v12.7: CONEXÃO SEM CONFIGURAR NADA
// O MT5 guarda a lista "Permitir WebRequest para URL" CRIPTOGRAFADA no config\common.ini.
// Escrever o endereço em texto lá não funciona (testado: erro 4014) e as versões antigas do
// INSTALAR.bat ainda estragavam a lista que você tinha colocado à mão -> "a IA e o Telegram caíam".
// Agora o robô fala com o Telegram e com o Gemini pelo próprio Windows (wininet.dll), que não
// depende dessa lista. O INSTALAR.bat liga "Permitir importação de DLL" (isso o MT5 aceita em texto).
// Se a DLL falhar, tenta o WebRequest normal. Sem internet: tenta de novo sozinho, cada vez
// esperando um pouco mais (2 s ... 60 s), e avisa UMA vez no painel.
//====================================================================
#import "wininet.dll"
long InternetOpenW(string agent,int access,string proxy,string bypass,int flags);
long InternetConnectW(long h,string host,int port,string user,string pass,int svc,int flags,long ctx);
long HttpOpenRequestW(long h,string verb,string obj,string ver,string ref,long acc,int flags,long ctx);
int  HttpSendRequestW(long h,string hdr,int hlen,uchar &opt[],int olen);
int  HttpQueryInfoW(long h,int lvl,int &buf,int &len,int &idx);
int  InternetReadFile(long h,uchar &buf[],int n,int &rd);
int  InternetSetOptionW(long h,int opt,int &val,int len);
int  InternetCloseHandle(long h);
#import
string   g_netAviso="";            // linha única pro painel ("" = tudo conectado)
string   g_netHost[]; int g_netFalhas[]; ulong g_netProx[];
bool     g_netAvisou=false;
int NetIdx(string host)
{
   for(int i=0;i<ArraySize(g_netHost);i++) if(g_netHost[i]==host) return i;
   int k=ArraySize(g_netHost); ArrayResize(g_netHost,k+1); ArrayResize(g_netFalhas,k+1); ArrayResize(g_netProx,k+1);
   g_netHost[k]=host; g_netFalhas[k]=0; g_netProx[k]=0; return k;
}
string NetNome(string host){ return StringFind(host,"telegram")>=0?"Telegram":"IA"; }
void NetOk(string host)
{
   int i=NetIdx(host);
   if(g_netFalhas[i]>=2) Print("ALIEN: ",NetNome(host)," conectado de novo.");
   g_netFalhas[i]=0; g_netProx[i]=0;
   bool todos=true; for(int j=0;j<ArraySize(g_netFalhas);j++) if(g_netFalhas[j]>=2) todos=false;
   if(todos){ g_netAviso=""; g_netAvisou=false; }
}
void NetFalha(string host)
{
   int i=NetIdx(host); g_netFalhas[i]++;
   int esp=(int)MathMin(60,MathPow(2,MathMin(g_netFalhas[i],6)));      // 2,4,8,16,32,60 s
   g_netProx[i]=GetTickCount64()+(ulong)esp*1000;
   if(g_netFalhas[i]>=2)
   {
      g_netAviso="Sem conexão com o "+NetNome(host)+" agora. Tô tentando de novo sozinho.";
      if(!g_netAvisou){ Print("ALIEN: ",g_netAviso," (confira a internet do PC)"); g_netAvisou=true; }
   }
}
// separa https://host/caminho
bool NetUrl(string url,string &host,string &path,int &port)
{
   port=443; string u=url;
   if(StringFind(u,"https://")==0) u=StringSubstr(u,8);
   else if(StringFind(u,"http://")==0){ u=StringSubstr(u,7); port=80; }
   int s=StringFind(u,"/");
   host=(s<0?u:StringSubstr(u,0,s)); path=(s<0?"/":StringSubstr(u,s));
   int c=StringFind(host,":"); if(c>0){ port=(int)StringToInteger(StringSubstr(host,c+1)); host=StringSubstr(host,0,c); }
   return host!="";
}
// mesma cara do WebRequest(method,url,headers,timeout,data,result,headers_resp). -1 = sem conexão.
int NetWinInet(string method,string url,string headers,int timeout,const char &data[],char &result[],string &rh)
{
   string host,path; int port;
   if(!NetUrl(url,host,path,port)) return -1;
   long hi=InternetOpenW("ALIEN",0,"","",0);            // 0 = usa o proxy do Windows
   if(hi==0) return -1;
   int to=MathMax(timeout,3000);
   InternetSetOptionW(hi,2,to,4); InternetSetOptionW(hi,5,to,4); InternetSetOptionW(hi,6,to,4);
   long hc=InternetConnectW(hi,host,port,"","",3,0,0);
   if(hc==0){ InternetCloseHandle(hi); return -1; }
   int fl=(int)(0x80000000|0x04000000|0x00000200|0x00080000);   // recarrega, sem cache, sem janela, sem cookie
   if(port==443) fl|=0x00800000;                                   // https
   long hr=HttpOpenRequestW(hc,method,path,"HTTP/1.1","",0,fl,0);
   if(hr==0){ InternetCloseHandle(hc); InternetCloseHandle(hi); return -1; }
   int n=ArraySize(data); uchar b[]; ArrayResize(b,MathMax(n,1)); for(int i=0;i<n;i++) b[i]=(uchar)data[i];
   int ok=HttpSendRequestW(hr,headers,StringLen(headers),b,n);
   int st=-1;
   if(ok!=0)
   {
      int len=4,idx=0; st=0; HttpQueryInfoW(hr,19|0x20000000,st,len,idx);
      uchar buf[8192]; int rd=0, tot=0; ArrayResize(result,0);
      while(InternetReadFile(hr,buf,8192,rd)!=0 && rd>0)
      { ArrayResize(result,tot+rd); for(int i=0;i<rd;i++) result[tot+i]=(char)buf[i]; tot+=rd; }
   }
   InternetCloseHandle(hr); InternetCloseHandle(hc); InternetCloseHandle(hi);
   rh="";
   return st;
}
void NetFalhaAviso(){ }   // o aviso já sai uma vez só pelo NetFalha()
int HttpReq(string method,string url,string headers,int timeout,const char &data[],char &result[],string &rh)
{
   string host,path; int port; NetUrl(url,host,path,port);
   int i=NetIdx(host);
   ArrayResize(result,0); rh="";
   if(g_netProx[i]>0 && GetTickCount64()<g_netProx[i]) return -1;     // esperando pra tentar de novo (não trava o robô)
   int code=-1;
   if(MQLInfoInteger(MQL_DLLS_ALLOWED)) code=NetWinInet(method,url,headers,timeout,data,result,rh);
   if(code<=0){ ResetLastError(); code=WebRequest(method,url,headers,timeout,data,result,rh); }
   if(code<=0){ NetFalha(host); return -1; }
   NetOk(host);
   return code;
}

//====================================================================
// ANÁLISE IA (opcional). Só comenta; por padrão NUNCA muda decisão.
enum ENUM_AIMODE { AMBAS=0, PRINCIPAL_COM_RESERVA=1 };
input group "=== Análise IA (opcional) ==="
input ENUM_AIMODE InpAIMode = AMBAS;                                      // AMBAS = Grok + Gemini1 + Gemini2, 1 resposta unida | PRINCIPAL_COM_RESERVA
input bool   InpUseAI      = true;                                         // Usar análise IA (precisa de chave)
input string InpAIProvider = "xai";                                        // Provedor (qualquer API compatível com OpenAI)
input string InpAIEndpoint = "https://api.x.ai/v1/chat/completions";      // Endpoint (xAI; ou https://api.openai.com/v1/chat/completions)
input string InpAIModel    = "grok-4.20-0309-non-reasoning";               // Modelo (rápido)
input string InpAIKey      = "";                                           // Chave da API (vazio = IA desligada)
input string InpAI2Endpoint= "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"; // Reserva: Google Gemini (compatível OpenAI)
input string InpAI2Model   = "gemini-3.5-flash-lite";                      // Modelo reserva
input string InpAI2Key     = "";                                           // Chave Gemini 1 (vazio = sem esta opinião)
input string InpGeminiKey2 = "";                                           // Chave Gemini 2 (opcional; opinião à parte, unida no modo AMBAS)
input int    InpAIMinutos  = 0;                                            // Análise a cada N minutos também (0 = só nos sinais)
input bool   InpAIVeto     = false;                                        // IA pode VETAR (só opera se o VEREDITO for o lado do sinal; em AMBAS, as duas têm que concordar)
input int    InpAIMinSeg   = 15;                                           // Limite: mínimo de segundos entre perguntas à IA
input int    InpAIMaxHora  = 30;                                           // Limite: máximo de perguntas à IA por hora (0 = sem limite)

// chaves em uso: começam com os parâmetros; o robô AUTO troca pelas do arquivo MQL5\Files\ALIEN_config.txt
string   g_cfgAIKey="", g_cfgAI2Key="", g_cfgGem2="";
void AICfgInit(){ g_cfgAIKey=InpAIKey; g_cfgAI2Key=InpAI2Key; g_cfgGem2=InpGeminiKey2; }
string   g_aiTxt="";
datetime g_aiLast=0;

bool AIOn(){ return (   // v12.7: IA forçada ligada quando tem chave
   StringLen(g_cfgAIKey)>10 || StringLen(g_cfgAI2Key)>10 || StringLen(g_cfgGem2)>10) && !MQLInfoInteger(MQL_TESTER); }
string JEsc(string s)
{
   // escape JSON-string: \ " \n \r \t e controles <0x20 como \u00XX
   string o="";
   int n=StringLen(s);
   for(int i=0;i<n;i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(c=='\\')      o+="\\\\";
      else if(c=='"')  o+="\\\"";
      else if(c=='\n') o+="\\n";
      else if(c=='\r') o+="\\r";
      else if(c=='\t') o+="\\t";
      else if(c<0x20)  o+=StringFormat("\\u%04x",c);
      else             o+=ShortToString(c);
   }
   return o;
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
   return "Você é um colega de trading (SMC). PT-BR informal, no máximo 4 linhas curtas, números exatos, sem prometer lucro. "
          "Fala o que confirma, o que invalida, e o que olhar no M1. Sem rótulo robótico.";
}
// pergunta pra IA: tenta xAI; se der erro/tempo/cota, tenta a reserva (Gemini)
string AIAsk(string estado){ return AIAskEx(AISysPadrao(),estado,220,true); }   // sinais: passam do limite (poucos por dia)
string   g_aiVeredito="";   // COMPRA / VENDA / ESPERAR da última análise
bool     g_aiConcordam=false;
string   g_aiLastErr="";    // último erro HTTP (sem chave) para o log Experts
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
   for(int i=0;i<n;i++){ string u=ls[i]; StringToUpper(u); if(StringFind(u,"VEREDITO")>=0 || StringFind(u,"CONFIAN")==0 || StringFind(u,"AS DUAS LEITURAS")==0 || StringFind(u,"SÓ UMA LEITURA")==0) continue; o+=(o==""?"":"\n")+ls[i]; }
   StringTrimRight(o); return o;
}
// respostas brutas das IAs ficam em MQL5\Files\ALIEN_ia_log.txt (só respostas, nunca chaves)
void AILog(string tag,string txt)
{
   int h=FileOpen("ALIEN_ia_log.txt",FILE_READ|FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END); FileWriteString(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+" "+_Symbol+" ["+tag+"] "+txt+"\r\n"); FileClose(h);
}
string AIGeminiKey(int idx){ return idx==1 ? g_cfgAI2Key : g_cfgGem2; }
string AIAskGemini(string sys,string estado,int maxTok,int idx,double temp=0.2)
{
   string key=AIGeminiKey(idx);
   if(StringLen(key)<=10) return "";
   string t=AIAskOne(sys,estado,InpAI2Endpoint,InpAI2Model,key,maxTok,temp);
   if(t=="") Print("IA: GEMINI",idx," falhou. ",g_aiLastErr);
   return t;
}
// "custo" de uma resposta livre: tamanho + multa por bloco de plano / campo cru / veredito
int AICustoLivre(string t)
{
   string u=t; StringToLower(u);
   int c=StringLen(AISemVeredito(t));
   if(c<15) c+=2000;                      // curta demais = provavelmente cortada
   if(StringFind(u,"plano_")>=0 || StringFind(u,"alvos_locais")>=0) c+=600;
   if(StringFind(u,"se for comprar")>=0 || StringFind(u,"se for vender")>=0) c+=300;
   if(StringFind(u,"veredito")>=0) c+=200;
   return c;
}
void AIPushOp(string &names[],string &texts[],string &vers[],string &errs[],string name,string txt,string err)
{
   int k=ArraySize(names);
   ArrayResize(names,k+1); ArrayResize(texts,k+1); ArrayResize(vers,k+1); ArrayResize(errs,k+1);
   names[k]=name; texts[k]=txt; vers[k]=AIVer(txt); errs[k]=err;
   AILog(name+" "+vers[k],txt);
}

// valida entrada/stop/alvo dos cenários da IA (lado certo e R>=1). Só substitui o bloco inválido.
bool AIEhDig(ushort c){ return (c>='0' && c<='9'); }
bool AISegueR(const string s,int j)
{
   int n=StringLen(s);
   while(j<n && StringGetCharacter(s,j)==' ') j++;
   if(j>=n) return false;
   ushort c=StringGetCharacter(s,j);
   return (c=='R' || c=='r');
}
bool AILePreco(const string s,int from,int lim,double &out,int &ate)
{
   int n=StringLen(s); if(lim<=0 || lim>n) lim=n;
   int j=from;
   while(j<lim)
   {
      ushort c=StringGetCharacter(s,j);
      if(c=='-' || AIEhDig(c))
      {
         int st=j;
         if(c=='-') j++;
         int d0=j;
         while(j<lim && AIEhDig(StringGetCharacter(s,j))) j++;
         if(j==d0){ j=st+1; continue; }
         if(j<lim)
         {
            ushort sep=StringGetCharacter(s,j);
            if(sep=='.' || sep==',')
            {
               int k=j+1;
               if(k<lim && AIEhDig(StringGetCharacter(s,k)))
               { j=k; while(j<lim && AIEhDig(StringGetCharacter(s,j))) j++; }
            }
         }
         if(AISegueR(s,j)){ j=st+1; continue; }
         string tok=StringSubstr(s,st,j-st);
         StringReplace(tok,",",".");
         out=StringToDouble(tok);
         if(out==0 && tok!="0" && tok!="0.0" && tok!="0,0"){ j=st+1; continue; }
         ate=j; return (out>0);
      }
      j++;
   }
   return false;
}
int AIAchaChave(const string u,string key,int from)
{
   return StringFind(u,key,from);
}
double AINumApos(const string orig,string key,bool &ok)
{
   ok=false;
   string u=orig, k=key;
   StringToUpper(u); StringToUpper(k);
   int p=0, n=StringLen(u);
   while(true)
   {
      int i=AIAchaChave(u,k,p); if(i<0) return 0;
      int j=i+StringLen(k);
      while(j<n)
      {
         ushort c=StringGetCharacter(u,j);
         if(c==' ' || c==':' || c=='=' || c==',' || c==';' || c=='-') j++;
         else break;
      }
      double v=0; int ate=0;
      if(AILePreco(orig,j,j+80,v,ate))
      { ok=true; return v; }
      p=i+1;
   }
   return 0;
}
string AISemAcento(string s)
{
   StringReplace(s,"Á","A"); StringReplace(s,"À","A"); StringReplace(s,"Ã","A"); StringReplace(s,"Â","A");
   StringReplace(s,"É","E"); StringReplace(s,"Ê","E");
   StringReplace(s,"Í","I");
   StringReplace(s,"Ó","O"); StringReplace(s,"Ô","O"); StringReplace(s,"Õ","O");
   StringReplace(s,"Ú","U");
   StringReplace(s,"á","A"); StringReplace(s,"à","A"); StringReplace(s,"ã","A"); StringReplace(s,"â","A");
   StringReplace(s,"é","E"); StringReplace(s,"ê","E");
   StringReplace(s,"í","I");
   StringReplace(s,"ó","O"); StringReplace(s,"ô","O"); StringReplace(s,"õ","O");
   StringReplace(s,"ú","U");
   return s;
}
int AICenarioDir(string line)
{
   string u=line; StringToUpper(u); u=AISemAcento(u);
   if(StringFind(u,"CENARIO")<0) return 0;
   if(StringFind(u,"COMPRA")>=0 || StringFind(u,"BUY")>=0) return 1;
   if(StringFind(u,"VENDA")>=0 || StringFind(u,"SELL")>=0 || StringFind(u,"SHORT")>=0) return -1;
   return 0;
}
bool AIFimBloco(string line,bool primeiro)
{
   if(!primeiro && AICenarioDir(line)!=0) return true;
   string u=line; StringToUpper(u); u=AISemAcento(u);
   if(StringFind(u,"O QUE ESPERAR")>=0) return true;
   if(StringFind(u,"RISCOS")>=0 && StringFind(u,"CENARIO")<0) return true;
   if(StringFind(u,"VEREDITO")>=0) return true;
   if(StringFind(u,"CONFIAN")==0 || StringFind(u,"CONFIANCA")==0) return true;
   if(StringFind(u,"OBS.:")>=0 || StringFind(u,"OBS:")>=0) return true;
   return false;
}
string AIValidaCenarios(string t)
{
   if(t=="") return t;
   StringReplace(t,"\r","");
   string u0=t; StringToUpper(u0); u0=AISemAcento(u0);
   if(StringFind(u0,"CENARIO")<0) return t;
   string ls[]; int n=StringSplit(t,'\n',ls); if(n<=0) return t;
   int st[], dir[]; ArrayResize(st,0); ArrayResize(dir,0);
   for(int i=0;i<n;i++)
   {
      int d=AICenarioDir(ls[i]);
      if(d!=0){ int k=ArraySize(st); ArrayResize(st,k+1); ArrayResize(dir,k+1); st[k]=i; dir[k]=d; }
   }
   if(ArraySize(st)==0) return t;
   for(int b=ArraySize(st)-1;b>=0;b--)
   {
      int a=st[b], en=n;
      for(int j=a+1;j<n;j++){ if(AIFimBloco(ls[j],false)){ en=j; break; } }
      string bloco=ls[a];
      for(int j=a+1;j<en;j++) bloco+="\n"+ls[j];
      bool okE=false, okS=false, okA=false;
      double ent=AINumApos(bloco,"ENTRADA",okE); if(!okE) ent=AINumApos(bloco,"ENTRY",okE);
      double stp=AINumApos(bloco,"STOP",okS);
      if(!okS) stp=AINumApos(bloco," SL",okS);
      double alv=AINumApos(bloco,"ALVO",okA); if(!okA) alv=AINumApos(bloco,"TARGET",okA); if(!okA) alv=AINumApos(bloco," TP",okA);
      bool ruim=false;
      if(okE && okS && okA && ent>0)
      {
         double risk=MathAbs(ent-stp);
         if(risk<=0) ruim=true;
         else
         {
            double rr=MathAbs(alv-ent)/risk;
            bool geo=(dir[b]==1 ? (stp<ent && ent<alv) : (alv<ent && ent<stp));
            if(!geo || rr<1.0) ruim=true;
         }
      }
      if(ruim)
      {
         string msg=(dir[b]==1?"Cenário compra: sem setup válido (R<1)":"Cenário venda: sem setup válido (R<1)");
         // comprime o bloco em uma linha
         ls[a]=msg;
         for(int j=a+1;j<en;j++) ls[j]="";
      }
   }
   string o="";
   for(int i=0;i<n;i++)
   {
      if(ls[i]=="" && (i==0 || i==n-1 || (i>0 && ls[i-1]==""))) continue;
      if(ls[i]=="") continue;
      o+=(o==""?"":"\n")+ls[i];
   }
   return o;
}

string AIAskEx(string sys,string user,int maxTok,bool force=false,bool verdict=true,double temp=0.2)
{
   if(!AIOn()) return "";
   if(!force && AIEsperaSeg()>0){ Print("IA: limite de uso - pulei esta pergunta"); return ""; }
   AIMarca();
   g_aiVeredito=""; g_aiConcordam=false;
   string sysV=verdict ? sys+" Na última linha escreva exatamente uma destas: VEREDITO: COMPRA / VEREDITO: VENDA / VEREDITO: ESPERAR." : sys;
   bool hGrok=StringLen(g_cfgAIKey)>10, hG1=StringLen(g_cfgAI2Key)>10, hG2=StringLen(g_cfgGem2)>10;
   string names[], texts[], vers[], errs[];
   bool ambas=(InpAIMode==AMBAS);
   // AMBAS: chama todas as opiniões disponíveis (GROK, GEMINI1, GEMINI2). Reserva: GROK primeiro; se falhar, as Gemini.
   if(ambas || hGrok)
   {
      if(hGrok)
      {
         string a=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,g_cfgAIKey,maxTok,temp);
         AIPushOp(names,texts,vers,errs,"GROK",a,g_aiLastErr);
      }
   }
   bool pediGrok=hGrok && ArraySize(texts)>0;
   bool grokOk=pediGrok && texts[0]!="";
   if(ambas || !hGrok || !grokOk)
   {
      if(hG1)
      {
         string g1=AIAskGemini(sysV,user,maxTok,1,temp);
         AIPushOp(names,texts,vers,errs,"GEMINI1",g1,g_aiLastErr);
      }
      if(hG2)
      {
         string g2=AIAskGemini(sysV,user,maxTok,2,temp);
         AIPushOp(names,texts,vers,errs,"GEMINI2",g2,g_aiLastErr);
      }
   }
   string okN[], okT[], okV[];
   string falhas="";
   for(int i=0;i<ArraySize(names);i++)
   {
      if(texts[i]!=""){ int k=ArraySize(okN); ArrayResize(okN,k+1); ArrayResize(okT,k+1); ArrayResize(okV,k+1); okN[k]=names[i]; okT[k]=texts[i]; okV[k]=vers[i]; }
      else if(errs[i]!="") falhas+=(falhas==""?"":" | ")+names[i]+" "+errs[i];
   }
   int nOk=ArraySize(okN);
   if(nOk==0) return "";
   string lista="";
   for(int i=0;i<nOk;i++) lista+=(i==0?"":" + ")+okN[i];
   string t="", conf="";
   if(nOk==1)
   {
      t=okT[0]; g_aiVeredito=okV[0]; if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
      if(!verdict) g_aiVeredito="";
      conf="Só uma leitura respondeu agora (a outra falhou), vai com calma";
      if(falhas!="") Print("IA: ",conf,". Falhas: ",falhas);
   }
   else
   {
      bool agree=(okV[0]!="");
      for(int i=1;i<nOk;i++) if(okV[i]=="" || okV[i]!=okV[0]) agree=false;
      g_aiConcordam=agree;
      g_aiVeredito=agree?okV[0]:"ESPERAR";
      if(!verdict){ g_aiConcordam=true; g_aiVeredito=""; }
      string det="";
      for(int i=0;i<nOk;i++) det+=(i==0?"":", ")+okN[i]+" "+(okV[i]==""?"?":okV[i]);
      // união determinística, sem nova chamada à API:
      //  análise (com veredito) -> texto mais completo; conversa livre -> a resposta mais curta e limpa
      int best=0, bl=-1;
      if(verdict)
      { for(int i=0;i<nOk;i++){ int L=StringLen(AISemVeredito(okT[i])); if(L>bl){ bl=L; best=i; } } }
      else
      { for(int i=0;i<nOk;i++){ int L=AICustoLivre(okT[i]); if(bl<0 || L<bl){ bl=L; best=i; } } }
      t=AISemVeredito(okT[best]);
      AILog("UNIDA "+g_aiVeredito+" ("+det+")",t);
      conf=agree?"As duas leituras bateram ✅":"As duas leituras discordaram, então eu esperaria 🟡";
      if(falhas!="") Print("IA: união com ",lista,". Falhas: ",falhas);
   }
   g_aiLast=TimeCurrent();
   t=AIValidaCenarios(AISemVeredito(t));
   if(!verdict){ g_aiVeredito=""; return t; }
   return t+"\nVEREDITO: "+g_aiVeredito+"\n"+conf;
}

string AIAskOne(string sys,string estado,string endpoint,string model,string key,int maxTok,double temp=0.2)
{
   g_aiLastErr="";
   if(temp<0.0) temp=0.0; if(temp>1.0) temp=1.0;
   string body="{\"model\":\""+JEsc(model)+"\",\"temperature\":"+DoubleToString(temp,1)+",\"max_tokens\":"+IntegerToString(maxTok)+",\"messages\":[{\"role\":\"system\",\"content\":\""+JEsc(sys)+"\"},{\"role\":\"user\",\"content\":\""+JEsc(estado)+"\"}]}";
   char data[],res[]; string rh;
   // UTF-8 sem o NUL final que o StringToCharArray acrescenta (xAI rejeita o body com 400)
   uchar utf8[];
   int n=StringToCharArray(body,utf8,0,WHOLE_ARRAY,CP_UTF8);
   if(n<=0) return "";
   if(utf8[n-1]==0) n--;
   ArrayResize(data,n);
   for(int i=0;i<n;i++) data[i]=(char)utf8[i];
   string hdr="Content-Type: application/json\r\nAuthorization: Bearer "+key+"\r\n";
   ResetLastError();
   int code=HttpReq("POST",endpoint,hdr,15000,data,res,rh);
   // limite do plano grátis (429) ou servidor ocupado (5xx): espera e tenta de novo (2 s, depois 5 s)
   for(int tent=0; tent<2 && (code==429 || code==500 || code==503); tent++)
   {
      Print("IA [",model,"] ocupada (",code,") - tentando de novo");
      Sleep(tent==0?2000:5000); ArrayResize(res,0); ResetLastError();
      code=HttpReq("POST",endpoint,hdr,15000,data,res,rh);
   }
   if(code==-1){ g_aiLastErr="sem conexão"; NetFalhaAviso(); return ""; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ g_aiLastErr=IntegerToString(code)+": "+StringSubstr(r,0,300); Print("IA [",model,"] respondeu ",g_aiLastErr); return ""; }
   string t=JContent(r); StringReplace(t,"**",""); StringTrimLeft(t); StringTrimRight(t);
   if(t==""){ g_aiLastErr="HTTP "+IntegerToString(code)+" sem content"; Print("IA [",model,"] ",g_aiLastErr); return ""; }
   return t;
}
// veto: com InpAIVeto ligado só opera se o VEREDITO for o lado do sinal (em AMBAS, divergência = ESPERAR = não opera)
bool AIVetou(string t,int dir){ if(!InpAIVeto || t=="") return false; return g_aiVeredito!=(dir==1?"COMPRA":"VENDA"); }
// mensagem amigável quando a IA não respondeu
string AIFalhaTxt()
{
   if(StringFind(g_aiLastErr,"429")==0) return "A IA grátis do Google tá no limite agora 😅 Espera 1 minutinho e me manda de novo.";
   if(StringFind(g_aiLastErr,"sem conex")>=0) return "Tô sem conexão com a IA agora. Já tô tentando de novo sozinho, manda de novo em 1 minutinho.";
   if(StringFind(g_aiLastErr,"5")==0) return "Os servidores da IA tão ocupados agora. Tenta de novo em 1 minuto 🙏";
   return "A IA não respondeu agora. Tenta de novo em 1 minuto.";
}
string AIStatus()
{
   if(StringLen(g_cfgAIKey)<=10 && StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10) return "IA: coloque a chave Gemini em MQL5\\Files\\ALIEN_config.txt (gemini_chave_1=...) ou em InpAI2Key";
   if(MQLInfoInteger(MQL_TESTER)) return "IA: não roda no testador";
   return "";
}
