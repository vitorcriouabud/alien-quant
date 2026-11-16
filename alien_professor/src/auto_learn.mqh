
//====================================================================
// Aprendizado honesto + alertas + comandos extras do Telegram
// Nunca altera sozinho os parâmetros do robô — só sugere.
//====================================================================
bool     g_tradePausa=false;
datetime g_lastAlertaChk=0;
double   g_prevBid=0;
string   g_alertaArq="ALIEN_alertas.csv";
string   g_verArq="ALIEN_veredictos.csv";
string   g_pausaArq="ALIEN_pausa.txt";
string   g_verHdr="hora;simbolo;bid;veredito;sessao;d1;h4;h1;m15;m5;m1;nota;pts;entrada;stop;res15;res60;origem";

bool TradeAtivo(){ return (InpTradeEnabled && !g_cfgAssistente && !g_tradePausa) || AutonomoAtivo(); }   // v12.6: autônomo só em DEMO

void PausaLoad()
{
   g_tradePausa=false;
   int h=FileOpen(g_pausaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string s=FileReadString(h); FileClose(h);
   StringTrimLeft(s); StringTrimRight(s);
   g_tradePausa=(s=="1"||s=="true"||s=="PAUSA");
}
void PausaSave()
{
   int h=FileOpen(g_pausaArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,g_tradePausa?"1":"0"); FileClose(h);
}

bool SendJsonMsg(string chat,string text,string markup)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string body="{\"chat_id\":\""+JEsc(chat)+"\",\"text\":\""+JEsc(text)+"\"";
   if(markup!="") body+=",\"reply_markup\":"+markup;
   body+="}";
   uchar utf8[]; char data[],res[]; string rh;
   int n=StringToCharArray(body,utf8,0,WHOLE_ARRAY,CP_UTF8);
   if(n<=0) return false;
   if(utf8[n-1]==0) n--;
   if(n<=0) return false;
   ArrayResize(data,n);
   for(int i=0;i<n;i++) data[i]=(char)utf8[i];
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+g_cfgTgToken+"/sendMessage","Content-Type: application/json\r\n",8000,data,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
// teclado fixo só no privado; no grupo vai o texto sem teclado
bool SendMsgKb(string text){ if(!TgOk()) return false; if(g_tgEmGrupo) return SendJsonMsg(TgDestino(),text,""); return SendJsonMsg(TgDestino(),text,TgKbFixo()); }
bool SendMsgMarkup(string text,string markup){ if(!TgOk()) return false; return SendJsonMsg(TgDestino(),text,markup); }
void TgAckCb(string qid)
{
   if(!TgTokenOk() || qid=="") return;
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/answerCallbackQuery";
   string body="callback_query_id="+UrlEnc(qid);
   char data[],res[]; string rh; StringToCharArray(body,data,0,StringLen(body));
   WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",5000,data,res,rh);
}

string PlanoLadoTxt(const Plano &p,string lado)
{
   if(!PlanoValido(p)) return PlanoSemSetup(p.dir);
   string ck=""; string nm[7]={"tendência","varrida","rompimento","vazio de preço","volume","horário","alvo 2R"};
   for(int i=0;i<7;i++) ck+=(i?", ":"")+(p.pts[i]?"[x] ":"[ ] ")+nm[i];
   return StringFormat("%s, nota %d/10.\nEntrada %s, 🛑 stop %s, 🎯 alvo %s (%.2fR). Lote %.2f, risco $%.2f.\nChecklist: %s",
      lado,p.score,Fmt(p.entry),Fmt(p.stop),Fmt(p.target),p.rr,p.lot,p.riskUSD,ck);
}
string PlanoTxt()
{
   return "Bora olhar o plano do "+_Symbol+" agora:\n"+PlanoLadoTxt(g_pb,"🟢 COMPRA")+"\n\n"+PlanoLadoTxt(g_ps,"🔴 VENDA")+"\n\nNúmeros do professor — quem manda é você.";
}
string NiveisTxt()
{
   string s="Níveis do "+_Symbol+" agora:\n";
   int n=ArraySize(g_niv);
   if(n<=0) return s+"Ainda não calculei os níveis.";
   for(int i=0;i<n;i++)
   {
      string est=g_niv[i].estado==ST_VARRIDA?"VARRIDA":(g_niv[i].estado==ST_ROMPIDO?"rompido":"intacto");
      s+=StringFormat("%s  %s  %s%s\n",g_niv[i].nome,Fmt(g_niv[i].preco),est,
         g_niv[i].estado==ST_VARRIDA && g_niv[i].tSweep>0?" "+HHMM(g_niv[i].tSweep):"");
   }
   return s;
}
string CsvHoje(string file,int maxL)
{
   int h=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "";
   string hoje=TimeToString(TimeCurrent(),TIME_DATE), out=""; int c=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      if(StringFind(l,hoje)==0){ out+=(out==""?"":"\n")+l; c++; if(c>=maxL) break; }
   }
   FileClose(h); return out;
}
string AcaoFrase(string a)
{
   if(StringFind(a,"modo assistente")>=0) return "só avisei (modo assistente)";
   if(StringFind(a,"a mercado")==0) return "entrei a mercado";
   if(StringFind(a,"ordem limitada")==0) return "deixei ordem limitada";
   if(StringFind(a,"recusada")>=0) return "a corretora recusou";
   if(StringFind(a,"pulado: ")==0) return "pulei ("+StringSubstr(a,8)+")";
   return a;
}
string ResFrase(string r)
{
   if(r=="acerto") return "deu certo";
   if(r=="erro") return "deu errado";
   if(r=="nenhum") return "não andou nem 1R";
   return "";
}
string DiarioTxt()
{
   string hoje=TimeToString(TimeCurrent(),TIME_DATE);
   string s="📒 Hoje no "+_Symbol+":\n";
   // sinais
   int ns=0; string ls="";
   int h=FileOpen("ALIEN_diario.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); if(StringFind(l,hoje)!=0) continue;
         string p[]; if(StringSplit(l,';',p)<12) continue;
         ns++; if(ns>12) continue;
         ls+=StringFormat("• %s sinal de %s nota %s: %s\n",HoraBRde(StringToTime(p[0])),p[2],p[3],AcaoFrase(p[11]));
      }
      FileClose(h);
   }
   s+=(ns==0?"Nenhum sinal do robô ainda.\n":ls+(ns>12?StringFormat("(e mais %d)\n",ns-12):""));
   // vereditos
   int nv=0,ac=0,er=0; string lv="";
   h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); if(StringFind(l,hoje)!=0) continue;
         string p[]; if(StringSplit(l,';',p)<17) continue;
         nv++; string r=p[16]!=""?p[16]:p[15]; if(r=="acerto") ac++; if(r=="erro") er++;
         if(nv>10) continue;
         string rf=ResFrase(r);
         lv+=StringFormat("• %s a IA disse %s com o preço em %s%s\n",HoraBRde(StringToTime(p[0])),p[3],p[2],rf!=""?", "+rf:(p[3]=="ESPERAR"?"":", ainda medindo"));
      }
      FileClose(h);
   }
   s+="\n🤖 Leituras da IA:\n"+(nv==0?"Nenhuma ainda.\n":lv+(ac+er>0?StringFormat("Placar de hoje: %d certas, %d erradas.\n",ac,er):""));
   s+="\n🧘 "+DisciplinaResumo(0);
   s+="\n(horários de Brasília)";
   if(StringLen(s)>3500) s=StringSubstr(s,0,3500)+"\n...";
   return s;
}
string RiscoTxt()
{
   return StringFormat(
      "Risco do %s agora.\nRobô: %s%s\n$%.2f por trade | meta do dia $%.0f | perda máx $%.0f\n"
      "Stops hoje: %d (máx %d) | resultado $%+.2f | %d trades\n"
      "Pausa de DD: %s (limite %.0f%%) | disciplina: %s\n"
      "Nota mínima pro sinal: %d | spread máx %% do stop: %.0f\n"
      "Eu não mudo parâmetro sozinho — /pausa e /retoma só ligam ou desligam a operação.",
      _Symbol, InpTradeEnabled?(g_tradePausa?"PAUSADO por /pausa":"OPERANDO"):"ASSISTENTE (InpTradeEnabled=false)",
      g_ddPause?" | PAUSADO pelo DD":"",
      InpRiskUSD,InpMetaDiaUSD,InpPerdaMaxDiaUSD,g_stopsHoje,InpMaxStopsDia,g_netHoje,g_tradesHoje,
      g_ddPause?"SIM":"não",InpDDPausaPct,g_pare!=""?g_pare:"OK",
      InpScoreTrade,InpSpreadMaxPctStop);
}

// ---- alertas de preço persistidos ----
string AlertaLista()
{
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "(nenhum)";
   string s=""; int n=0;
   if(!FileIsEnding(h)) FileReadString(h); // header
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; if(StringSplit(l,';',p)<2) continue;
      if(p[1]=="1"){ s+=(s==""?"":", ")+p[0]; n++; }
   }
   FileClose(h); return n==0?"(nenhum)":s;
}
bool AlertaAdd(double preco)
{
   if(preco<=0) return false;
   CsvAppend(g_alertaArq,"preco;ativo",StringFormat("%s;1",Fmt(preco)));
   return true;
}
void AlertaTick()
{
   if(MQLInfoInteger(MQL_TESTER) || !TgOk()) return;
   datetime now=TimeCurrent();
   if(now-g_lastAlertaChk<1) return;
   g_lastAlertaChk=now;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0){ g_prevBid=bid; return; }
   if(g_prevBid<=0){ g_prevBid=bid; return; }
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE){ g_prevBid=bid; return; }
   string hdr=""; if(!FileIsEnding(h)) hdr=FileReadString(h);
   string keep="preco;ativo\r\n"; bool hit=false; string msg="";
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; int np=StringSplit(l,';',p); if(np<2){ keep+=l+"\r\n"; continue; }
      if(p[1]!="1"){ keep+=l+"\r\n"; continue; }
      double a=StringToDouble(p[0]);
      if(a>0 && ((g_prevBid-a)*(bid-a)<=0))
      { hit=true; msg+=StringFormat("%s atingiu %s (agora %s)\n",_Symbol,p[0],Fmt(bid)); keep+=p[0]+";0\r\n"; }
      else keep+=l+"\r\n";
   }
   FileClose(h);
   if(hit)
   {
      int w=FileOpen(g_alertaArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(w!=INVALID_HANDLE){ FileWriteString(w,keep); FileClose(w); }
      SendMsg("Opa, o preço bateu no alerta.\n"+msg+"Confere o gráfico antes de fazer qualquer coisa.");
   }
   g_prevBid=bid;
}

// ---- vereditos: grava, pontua 15/60 min, estatísticas ----
string PtsStr(const Plano &b)
{
   string s=""; for(int i=0;i<7;i++) s+=(b.pts[i]?"1":"0"); return s;
}
void VereditoLog(string origem)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_aiVeredito=="") return;
   Plano b=MelhorPlano();
   string st; SessaoNota(TimeTradeServer(),st);
   int p=StringFind(st," -"); string sess=p>0?StringSubstr(st,0,p):st;
   CsvAppend(g_verArq,g_verHdr,StringFormat("%s;%s;%s;%s;%s;%d;%d;%d;%d;%d;%d;%d;%s;%s;%s;;%s",
      TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),_Symbol,Fmt(SymbolInfoDouble(_Symbol,SYMBOL_BID)),
      g_aiVeredito,sess,g_mtf[0],g_mtf[1],g_mtf[2],g_mtf[3],g_mtf[4],g_mtf[5],b.score,PtsStr(b),
      Fmt(b.entry),Fmt(b.stop),origem));
}

// regra: anda as barras M1 após a hora; se +1R e -1R no mesmo candle => erro (conservador)
string VerScoreBar(int dir,double bid,double r1,const MqlRates &r[],int n,datetime t0)
{
   if(r1<=0 || bid<=0 || n<=0) return "nenhum";
   double up=bid+r1, dn=bid-r1;
   for(int i=n-1;i>=0;i--)
   {
      if(r[i].time<=t0) continue;
      bool hitUp=r[i].high>=up, hitDn=r[i].low<=dn;
      if(hitUp && hitDn) return "erro";
      if(dir==1){ if(hitDn) return "erro"; if(hitUp) return "acerto"; }
      else      { if(hitUp) return "erro"; if(hitDn) return "acerto"; }
   }
   return "nenhum";
}
string VerScoreRow(string ver,double bid,double entry,double stop,datetime t0)
{
   if(ver!="COMPRA" && ver!="VENDA") return "";
   if(bid<=0) return "";
   double r1=MathAbs(entry-stop);
   if(r1<=0) r1=(g_atr>0?g_atr:bid*0.001);
   if(r1<=0) return "";
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(_Symbol,PERIOD_M1,t0,TimeCurrent(),r);
   if(n<=0) return "nenhum";
   return VerScoreBar(ver=="COMPRA"?1:-1,bid,r1,r,n,t0);
}
void VereditoScore()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string lines[]; int n=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      int k=n; ArrayResize(lines,k+1); lines[k]=l; n++;
      if(n>2000) break;
   }
   FileClose(h);
   if(n<=1) return;
   bool ch=false; datetime now=TimeCurrent();
   for(int i=1;i<n;i++)
   {
      string p[]; int c=StringSplit(lines[i],';',p);
      if(c<17) continue;
      if(p[2]==""||p[3]=="") continue;
      datetime t0=StringToTime(p[0]); if(t0<=0) continue;
      int ago=(int)((now-t0)/60);
      double bid=StringToDouble(p[2]), entry=StringToDouble(p[13]), stop=StringToDouble(p[14]);
      bool rowch=false;
      if(ago>=15 && p[15]=="")
      { p[15]=VerScoreRow(p[3],bid,entry,stop,t0); rowch=true; }
      if(ago>=60 && p[16]=="")
      { p[16]=VerScoreRow(p[3],bid,entry,stop,t0); rowch=true; }
      if(rowch)
      {
         string r=p[0]; for(int k=1;k<c;k++) r+=";"+p[k];
         lines[i]=r; ch=true;
      }
   }
   if(!ch) return;
   int w=FileOpen(g_verArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w);
}

void StatAdd(string &ks[],int &ac[],int &tot[],string k,bool win)
{
   if(k=="") return;
   int i=-1; for(int j=0;j<ArraySize(ks);j++) if(ks[j]==k){ i=j; break; }
   if(i<0){ i=ArraySize(ks); ArrayResize(ks,i+1); ArrayResize(ac,i+1); ArrayResize(tot,i+1); ks[i]=k; ac[i]=0; tot[i]=0; }
   tot[i]++; if(win) ac[i]++;
}
string StatFmt(const string &ks[],const int &ac[],const int &tot[])
{
   string s="";
   for(int i=0;i<ArraySize(ks);i++)
      s+=(s==""?"":",\"")+ks[i]+"\":\""+IntegerToString(ac[i])+"/"+IntegerToString(tot[i])+"\"";
   return s;
}
string StatFrase(const string &ks[],const int &ac[],const int &tot[],string pref)
{
   int best=-1, worst=-1;
   for(int i=0;i<ArraySize(ks);i++)
   {
      if(tot[i]<3) continue;
      if(best<0 || ac[i]*tot[best]>ac[best]*tot[i]) best=i;
      if(worst<0 || ac[i]*tot[worst]<ac[worst]*tot[i]) worst=i;
   }
   string f="";
   if(best>=0) f=pref+ks[best]+" acertou "+IntegerToString(ac[best])+"/"+IntegerToString(tot[best]);
   return f;
}
string VereditoStatsJSON()
{
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "{\"n\":0}";
   string kv[],ks[],kb[],kc[]; int av[],tv[],as2[],ts[],ab[],tb[],ac[],tc[];
   int n=0, a15=0,t15=0,a60=0,t60=0;
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"};
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; int c=StringSplit(l,';',p); if(c<17) continue;
      n++;
      string res=p[16]!=""?p[16]:p[15];
      if(res!="acerto" && res!="erro") continue;
      bool win=(res=="acerto");
      if(p[15]=="acerto"||p[15]=="erro"){ t15++; if(p[15]=="acerto") a15++; }
      if(p[16]=="acerto"||p[16]=="erro"){ t60++; if(p[16]=="acerto") a60++; }
      StatAdd(kv,av,tv,p[3],win);
      StatAdd(ks,as2,ts,p[4],win);
      if(StringToInteger(p[5])!=0) StatAdd(kb,ab,tb,StringToInteger(p[5])>0?"D1_alta":"D1_baixa",win);
      if(StringToInteger(p[7])!=0) StatAdd(kb,ab,tb,StringToInteger(p[7])>0?"H1_alta":"H1_baixa",win);
      if(StringLen(p[12])>=7)
         for(int i=0;i<7;i++) if(StringGetCharacter(p[12],i)=='1') StatAdd(kc,ac,tc,nm[i],win);
   }
   FileClose(h);
   string frase=StatFrase(kv,av,tv,"seu histórico: veredito ");
   string fsess=StatFrase(ks,as2,ts,"em ");
   if(frase!="" && fsess!="") frase+=" "+fsess;
   string sug="";
   int worst=-1;
   for(int i=0;i<ArraySize(ks);i++)
      if(ts[i]>=5 && as2[i]*2<=ts[i] && (worst<0||as2[i]*ts[worst]<as2[worst]*ts[i])) worst=i;
   if(worst>=0) sug="considerar evitar operar na sessão "+ks[worst]+" (acertou "+IntegerToString(as2[worst])+"/"+IntegerToString(ts[worst])+") — sugestão, não aplicada automaticamente";
   return StringFormat("{\"n\":%d,\"acerto_15m\":\"%d/%d\",\"acerto_60m\":\"%d/%d\",\"por_veredito\":{%s},\"por_sessao\":{%s},\"por_vies\":{%s},\"por_criterio\":{%s},\"frase\":\"%s\",\"sugestoes\":\"%s\"}",
      n,a15,t15,a60,t60,StatFmt(kv,av,tv),StatFmt(ks,as2,ts),StatFmt(kb,ab,tb),StatFmt(kc,ac,tc),JEsc(frase),JEsc(sug));
}
string Pct(int a,int t){ return t>0?StringFormat("%d de %d (%.0f%%)",a,t,100.0*a/t):"nenhum ainda"; }
string AlertasResumo(int dias)
{
   int h=FileOpen("ALIEN_alertas_log.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "Ainda não mandei aviso automático.";
   string desde=TimeToString(AgoraBR()-dias*86400,TIME_DATE);
   int n=0,a=0,t=0; string ks[]; int ka[],kt[];
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<12) continue;
      if(StringSubstr(p[1],0,10)<desde) continue;
      n++;
      if(p[8]=="acerto"||p[8]=="erro"){ t++; if(p[8]=="acerto") a++; StatAdd(ks,ka,kt,p[3],p[8]=="acerto"); }
   }
   FileClose(h);
   if(n==0) return "Nenhum aviso automático nesse período.";
   string o=StringFormat("Mandei %d avisos automáticos. Nos que tinham direção, o preço andou 1R a favor antes de 1R contra em %s (em 60 min).",n,Pct(a,t));
   string f=StatFrase(ks,ka,kt,"O melhor tipo foi "); if(f!="") o+=" "+f+".";
   return o;
}
string AprendizadoTxt(int dias=0)
{
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   string s="🧠 Aprendizado do "+_Symbol+(dias>0?StringFormat(" (últimos %d dias)",dias):"")+"\n";
   s+=(n==0?"O robô ainda não fechou trade neste gráfico.":StringFormat("Trades do robô: %d, acertou %.0f%% e a média foi %+.2fR por trade.",n,w,a))+"\n";
   // vereditos da IA
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   int a15=0,t15=0,a60=0,t60=0; string ks[]; int ka[],kt[]; string kv[]; int va[],vt[];
   string desde=dias>0?TimeToString(TimeCurrent()-dias*86400,TIME_DATE):"";
   if(h!=INVALID_HANDLE)
   {
      if(!FileIsEnding(h)) FileReadString(h);
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<17) continue;
         if(desde!="" && StringSubstr(p[0],0,10)<desde) continue;
         if(p[15]=="acerto"||p[15]=="erro"){ t15++; if(p[15]=="acerto") a15++; }
         if(p[16]=="acerto"||p[16]=="erro"){ t60++; if(p[16]=="acerto") a60++; StatAdd(ks,ka,kt,p[4],p[16]=="acerto"); StatAdd(kv,va,vt,p[3],p[16]=="acerto"); }
      }
      FileClose(h);
   }
   if(t60+t15==0) s+="As leituras da IA ainda não foram medidas (preciso de pelo menos 1 hora depois de cada uma).\n";
   else
   {
      s+="Leituras da IA que deram direção: acertaram "+Pct(a15,t15)+" em 15 min e "+Pct(a60,t60)+" em 60 min (acerto = andou 1R a favor antes de 1R contra).\n";
      string fb=StatFrase(ks,ka,kt,"Melhor sessão: "); if(fb!="") s+=fb+".\n";
      int worst=-1; for(int i=0;i<ArraySize(ks);i++) if(kt[i]>=5 && (worst<0 || ka[i]*kt[worst]<ka[worst]*kt[i])) worst=i;
      if(worst>=0 && ka[worst]*2<=kt[worst]) s+="Pior sessão: "+ks[worst]+" ("+Pct(ka[worst],kt[worst])+"). Sugestão: evitar operar nela. Eu não mudo nada sozinho.\n";
   }
   s+=AlertasResumo(dias>0?dias:30)+"\n";
   s+="🧘 "+DisciplinaResumo(dias>0?dias:30)+"\n";
   s+="Isso é estatística do seu histórico, não promessa.";
   if(StringLen(s)>3500) s=StringSubstr(s,0,3500)+"\n...";
   return s;
}
void WeeklySummary()
{
   if(MQLInfoInteger(MQL_TESTER) || !TgOk()) return;
   if(InpTgChat && !g_tgMaster) return;
   datetime br=AgoraBR(); MqlDateTime d; TimeToStruct(br,d);
   if(d.day_of_week!=0 || d.hour<20) return;               // domingo 20:00 (Brasília)
   string key="SEM"+TimeToString(br,TIME_DATE);
   if(StringFind(g_resFeitos,"|"+key+"|")>=0 || StringFind(g_resFeitos,key+"|")>=0) return;
   g_resFeitos+=key+"|"; TgEstadoSave();
   SendMsg("📅 Resumo da semana, sem enrolação:\n"+AprendizadoTxt(7)+"\n\nSão só sugestões; quem decide é você. Boa semana! 💛");
}

void LearnTick()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   AlertaTick();
}
void LearnTimer()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   VereditoScore(); AlertasScore(); WeeklySummary(); BackupSemanal();
}
