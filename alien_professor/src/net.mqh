
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
