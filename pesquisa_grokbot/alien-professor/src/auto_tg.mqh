
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
bool TgTokenOk(){ return InpUseTelegram && StringLen(InpTelegramToken)>20 && !MQLInfoInteger(MQL_TESTER); }
bool TgOk(){ return TgTokenOk() && StringLen(InpTelegramChatId)>0; }
bool SendMsg(string text){ if(!TgOk()) return false; return SendMsgTo(InpTelegramChatId,text); }
bool SendMsgTo(string chat,string text)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string url="https://api.telegram.org/bot"+InpTelegramToken+"/sendMessage";
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
