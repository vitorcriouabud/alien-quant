//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_TELEGRAM.mq5                                     |
//| EA "carteiro": só lê os sinais do indicador ALIEN_PROFESSOR e    |
//| manda no Telegram. NÃO TEM NENHUMA FUNÇÃO DE ORDEM. Nunca opera. |
//| Precisa: Ferramentas > Opções > Expert Advisors > "Permitir      |
//| WebRequest" com https://api.telegram.org na lista.               |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "12.50"
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
