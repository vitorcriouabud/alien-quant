
// ---- configuração pessoal local (MQL5\Files\ALIEN_config.txt) ----
// Token, chat id e chaves ficam NESTE arquivo do seu PC, não no robô. Atualizar o robô não apaga.
string g_cfgTgToken="", g_cfgTgChat=""; bool g_cfgAssistente=false; string g_cfgOrigem="parâmetros";
string CfgArq(){ return "ALIEN_config.txt"; }
// grava/troca uma linha "chave=valor" no ALIEN_config.txt (mantém o resto)
void CfgSalva(string chave,string valor)
{
   string ls[]; int n=0;
   int h=FileOpen(CfgArq(),FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE){ while(!FileIsEnding(h)){ string l=FileReadString(h); ArrayResize(ls,n+1); ls[n++]=l; } FileClose(h); }
   bool achou=false;
   for(int i=0;i<n;i++){ string k=ls[i]; int e=StringFind(k,"="); if(e>0){ k=StringSubstr(k,0,e); StringTrimLeft(k); StringTrimRight(k); StringToLower(k); if(k==chave){ ls[i]=chave+"="+valor; achou=true; } } }
   if(!achou){ if(n==0){ ArrayResize(ls,1); ls[0]="# ALIEN - configuracao pessoal (NAO compartilhe este arquivo)"; n=1; } ArrayResize(ls,n+1); ls[n++]=chave+"="+valor; }
   int w=FileOpen(CfgArq(),FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) if(!(i==n-1 && ls[i]=="")) FileWriteString(w,ls[i]+"\r\n");
   FileClose(w);
}
void CfgLoad()
{
   g_cfgTgToken=InpTelegramToken; g_cfgTgChat=InpTelegramChatId; AICfgInit(); g_cfgAssistente=false; g_cfgOrigem="parâmetros";
   int h=FileOpen(CfgArq(),FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   int n=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); StringTrimLeft(l); StringTrimRight(l);
      if(l=="" || StringGetCharacter(l,0)=='#' || StringGetCharacter(l,0)==';') continue;
      int e=StringFind(l,"="); if(e<=0) continue;
      string k=StringSubstr(l,0,e), v=StringSubstr(l,e+1); StringTrimRight(k); StringTrimLeft(v); StringToLower(k);
      if(v=="") continue;
      if(k=="telegram_token"){ g_cfgTgToken=v; n++; }
      else if(k=="telegram_chat_id"){ g_cfgTgChat=v; n++; }
      else if(k=="gemini_chave_1"){ g_cfgAI2Key=v; n++; }
      else if(k=="gemini_chave_2"){ g_cfgGem2=v; n++; }
      else if(k=="xai_chave"){ g_cfgAIKey=v; n++; }
      else if(k=="modo"){ string m=v; StringToLower(m); g_cfgAssistente=(StringFind(m,"assist")==0); n++; }
   }
   FileClose(h);
   if(n>0) g_cfgOrigem="arquivo ALIEN_config.txt";
   Print("ALIEN: configuração lida de ",g_cfgOrigem," (",n," itens; chaves não aparecem no log)");
}

// ---- Telegram (texto + foto) ----
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
// WebRequest não existe no testador -> Telegram desligado lá
bool TgTokenOk(){ return InpUseTelegram && StringLen(g_cfgTgToken)>20 && !MQLInfoInteger(MQL_TESTER); }
bool TgOk(){ return TgTokenOk() && StringLen(g_cfgTgChat)>0; }
bool SendMsg(string text){ if(!TgOk()) return false; return SendMsgTo(g_cfgTgChat,text); }
bool SendMsgTo(string chat,string text)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/sendMessage";
   string body="chat_id="+UrlEnc(chat)+"&text="+UrlEnc(text);
   char data[],res[]; string rh; StringToCharArray(body,data,0,StringLen(body));  // body já é ASCII (url-encoded)
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
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n"+g_cfgTgChat+"\r\n");
   if(StringLen(caption)>1000) caption=StringSubstr(caption,0,1000);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n"+caption+"\r\n");
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"grafico.png\"\r\nContent-Type: image/png\r\n\r\n");
   int k=ArraySize(buf); int n=ArraySize(img); ArrayResize(buf,k+n); for(int i=0;i<n;i++) buf[k+i]=(char)img[i];
   AddStr(buf,"\r\n--"+bd+"--\r\n");
   char res[]; string rh;
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+g_cfgTgToken+"/sendPhoto","Content-Type: multipart/form-data; boundary="+bd+"\r\n",15000,buf,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram foto respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
