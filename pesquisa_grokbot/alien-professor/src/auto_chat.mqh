
//====================================================================
// CHAT TELEGRAM (duas vias) + PRÉ-AVISO DE NOTÍCIA + RESUMOS AGENDADOS
// Só aceita mensagens do chat InpTelegramChatId. Não roda no testador.
// Com o robô em vários gráficos, só UM lê as mensagens (trava por variável global).
long     g_tgOff=0;
datetime g_tgStartUtc=0;
string   g_tgHint="";        // chat id do /start (quando InpTelegramChatId está vazio)
string   g_alertados="|";    // notícias já pré-avisadas
string   g_resFeitos="|";    // resumos já enviados (data+nome)
double   g_inst=0;           // id desta instância (trava de quem lê o chat)
bool     g_tgMaster=false;
int      g_tgErrPrint=0;

bool TgMaster()
{
   string gi="APROF_TGM_ID", gt="APROF_TGM_T"; datetime now=TimeLocal();
   if(!GlobalVariableCheck(gi) || GlobalVariableGet(gi)==g_inst || now-(datetime)GlobalVariableGet(gt)>30)
   { GlobalVariableSet(gi,g_inst); GlobalVariableSet(gt,(double)now); return true; }
   return false;
}
void TgMasterSolta(){ if(GlobalVariableCheck("APROF_TGM_ID") && GlobalVariableGet("APROF_TGM_ID")==g_inst){ GlobalVariableDel("APROF_TGM_ID"); GlobalVariableDel("APROF_TGM_T"); } }

// lê string JSON a partir do índice da aspa de abertura (decodifica \n, \uXXXX...)
string JDecode(string r,int p)
{
   string out=""; int n=StringLen(r);
   for(int i=p+1;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(c=='\\' && i+1<n)
      {
         ushort d=StringGetCharacter(r,i+1); i++;
         if(d=='n') out+="\n"; else if(d=='t') out+=" "; else if(d=='r') {} 
         else if(d=='u' && i+4<n){ out+=ShortToString((ushort)StringToInteger("0x"+StringSubstr(r,i+1,4))); i+=4; }
         else out+=ShortToString(d);
         continue;
      }
      if(c=='"') break;
      out+=ShortToString(c);
   }
   return out;
}
string JStrKey(string r,string key){ int k=StringFind(r,"\""+key+"\":\""); if(k<0) return ""; return JDecode(r,k+StringLen(key)+3); }
string JNumKey(string r,string key,int from=0)
{
   int k=StringFind(r,"\""+key+"\":",from); if(k<0) return "";
   int i=k+StringLen(key)+3; string s=""; int n=StringLen(r);
   while(i<n){ ushort c=StringGetCharacter(r,i); if((c>='0'&&c<='9')||c=='-') s+=ShortToString(c); else if(s!="") break; else if(c!=' ') break; i++; }
   return s;
}

// --- contexto completo para a IA ---
string FVGJson(const FVGz &f[],int maxN)
{
   string s=""; int n=0;
   for(int i=ArraySize(f)-1;i>=0 && n<maxN;i--){ if(f[i].filled) continue; s+=(s==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",f[i].dir==1?"alta":"baixa",Fmt(f[i].top),Fmt(f[i].bot)); n++; }
   return "["+s+"]";
}
string PosJSON()
{
   string s="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      int dg=(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS);
      s+=(s==""?"":",")+StringFormat("{\"simbolo\":\"%s\",\"lado\":\"%s\",\"lote\":%.2f,\"preco\":%s,\"stop\":%s,\"alvo\":%s,\"lucro_usd\":%.2f,\"origem\":\"%s\"}",
         PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",PositionGetDouble(POSITION_VOLUME),
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),dg),DoubleToString(PositionGetDouble(POSITION_SL),dg),DoubleToString(PositionGetDouble(POSITION_TP),dg),
         PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?"robo":"manual");
   }
   return "["+s+"]";
}
Plano MelhorPlano(){ Plano b; if(g_pb.score>=g_ps.score) b=g_pb; else b=g_ps; return b; }
string ContextJSON()
{
   Plano b=MelhorPlano();
   string j=StateJSON(b);                       // tendências D1..M1, níveis/varridas, BOS, plano, histórico, leitura
   j=StringSubstr(j,0,StringLen(j)-1);          // tira o } final
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   string st; SessaoNota(TimeTradeServer(),st);
   j+=StringFormat(",\"preco\":%s,\"spread\":%s,\"atr_%s\":%s,\"sessao\":\"%s\",\"vies_dia\":\"%s\",\"tendencia_txt\":\"%s\"",
        Fmt(bid),Fmt(ask-bid),StringSubstr(EnumToString(InpTFExec),7),Fmt(g_atr),JEsc(st),JEsc(g_biasTxt),JEsc(g_trendTxt));
   j+=StringFormat(",\"nota_compra\":%d,\"nota_venda\":%d",g_pb.score,g_ps.score);
   j+=",\"fvg_"+StringSubstr(EnumToString(InpTFExec),7)+"\":"+FVGJson(g_fvg,4)+",\"fvg_M15\":"+FVGJson(g_fvgM15,3)+",\"fvg_H1\":"+FVGJson(g_fvgH1,3);
   j+=",\"noticias\":"+NewsJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\"";
   j+=",\"posicoes_abertas\":"+PosJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"},\"robo\":{\"opera\":%s,\"status\":\"%s\",\"pausa_dd\":%s}}",
        g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare),InpTradeEnabled?"true":"false",JEsc(g_status),g_ddPause?"true":"false");
   return j;
}
string SysChat()
{
   return "Você é o ALIEN PROFESSOR, parceiro de trading do Vitor (barbeiro e trader de mesa proprietária Goat, risco fixo US$45 por trade, limite de perda flutuante US$50, opera no M1). "
          "Fale em português do Brasil, como um professor experiente: direto, seguro, com os motivos claros (tendência por tempo gráfico, liquidez e varridas, BOS, FVGs, nota, spread, notícias, posições). "
          "Use SÓ os dados do CONTEXTO para falar de preços; nunca invente números. Quando não estiver claro, diga ESPERAR sem enrolar. Nunca prometa lucro. "
          "Pode conversar sobre qualquer assunto que ele trouxer (rotina, disciplina, cabeça, vida), com respeito e sinceridade. Use a CONVERSA RECENTE para manter o fio. "
          "No máximo 12 linhas, sem markdown. Quando fizer sentido, lembre: no teste 2016-2025 os sinais nota>=7 perderam em média.";
}
// ---- memória da conversa (últimas 10 mensagens) em MQL5\Files\ALIEN_chat_memoria.txt ----
string g_mem[];
void MemLoad()
{
   ArrayResize(g_mem,0);
   int h=FileOpen("ALIEN_chat_memoria.txt",FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ); if(h==INVALID_HANDLE) return;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(l=="") continue; int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=l; }
   FileClose(h);
}
void MemAdd(string quem,string txt)
{
   MemLoad();
   StringReplace(txt,"\r",""); StringReplace(txt,"\n"," / "); if(StringLen(txt)>700) txt=StringSubstr(txt,0,700)+"...";
   int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=TimeToString(TimeTradeServer(),TIME_DATE|TIME_MINUTES)+" "+quem+": "+txt;
   int st=MathMax(0,ArraySize(g_mem)-10);
   int h=FileOpen("ALIEN_chat_memoria.txt",FILE_WRITE|FILE_TXT|FILE_UNICODE); if(h==INVALID_HANDLE) return;
   for(int i=st;i<ArraySize(g_mem);i++) FileWriteString(h,g_mem[i]+"\r\n");
   FileClose(h);
}
string MemTxt(){ MemLoad(); if(ArraySize(g_mem)==0) return ""; string s="CONVERSA RECENTE (mais antiga primeiro):\n"; for(int i=0;i<ArraySize(g_mem);i++) s+=g_mem[i]+"\n"; return s+"\n"; }

// ---- /analise em qualquer símbolo e tempo gráfico ----
ENUM_TIMEFRAMES TfDe(string t)
{
   StringToUpper(t);
   if(t=="M1") return PERIOD_M1; if(t=="M5") return PERIOD_M5; if(t=="M15") return PERIOD_M15; if(t=="M30") return PERIOD_M30;
   if(t=="H1") return PERIOD_H1; if(t=="H4") return PERIOD_H4; if(t=="D1"||t=="DIARIO"||t=="DIÁRIO") return PERIOD_D1; if(t=="W1"||t=="SEMANAL") return PERIOD_W1;
   return PERIOD_CURRENT;
}
ENUM_TIMEFRAMES TfMaior(ENUM_TIMEFRAMES tf)
{
   switch(tf){ case PERIOD_M1: return PERIOD_M15; case PERIOD_M5: return PERIOD_H1; case PERIOD_M15: return PERIOD_H4; case PERIOD_M30: return PERIOD_H4;
               case PERIOD_H1: return PERIOD_D1; case PERIOD_H4: return PERIOD_D1; case PERIOD_D1: return PERIOD_W1; default: return PERIOD_MN1; }
}
string TfNome(ENUM_TIMEFRAMES tf){ return StringSubstr(EnumToString(tf),7); }
bool SymOk(string s){ bool cu=false; return s!="" && SymbolExist(s,cu); }
string SimboloDe(string t,bool busca)
{
   string u=t; StringToUpper(u); if(StringLen(u)<3) return "";
   if(u=="OURO"||u=="GOLD"||u=="XAU") u="XAUUSD";
   if(u=="NASDAQ"||u=="NAS"||u=="NAS100"||u=="US100"||u=="USTEC") u="USTECH";
   if(u=="SP500"||u=="SP"||u=="S&P"||u=="SPX") u="US500";
   if(u=="DAX"||u=="GER40"||u=="ALEMANHA") u="DE40";
   string c[3]; c[0]=u; c[1]="."+u+"Cash"; c[2]=u+"Cash";
   for(int i=0;i<3;i++) if(SymOk(c[i])) return c[i];
   if(!busca || StringLen(u)<4) return "";
   for(int i=0;i<SymbolsTotal(false);i++){ string n=SymbolName(i,false), nu=n; StringToUpper(nu); if(StringFind(nu,u)>=0) return n; }
   return "";
}
// procura símbolo/TF no texto. busca=true só no /analise (procura parcial na lista)
bool ParseAlvo(string text,bool busca,string &sym,ENUM_TIMEFRAMES &tf)
{
   sym=""; tf=PERIOD_CURRENT;
   string t=text; string pn[]={"?","!",",",".",";",":","(",")","\"","'"}; for(int i=0;i<ArraySize(pn);i++) StringReplace(t,pn[i]," ");
   string w[]; int n=StringSplit(t,' ',w);
   for(int i=0;i<n;i++)
   {
      if(w[i]=="" || StringGetCharacter(w[i],0)=='/') continue;
      ENUM_TIMEFRAMES f=TfDe(w[i]); if(f!=PERIOD_CURRENT){ tf=f; continue; }
      if(sym==""){ string s=SimboloDe(w[i],busca); if(s!="") sym=s; }
   }
   return (sym!="" || tf!=PERIOD_CURRENT);
}
string FmtS(string sym,double p){ return DoubleToString(p,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)); }
// resumo de um TF: tendência, topos/fundos, BOS, FVGs abertos
string TfResumo(string sym,ENUM_TIMEFRAMES tf,double &sh0,double &sl0,FVGz &fv[])
{
   MqlRates r[]; ArraySetAsSeries(r,true); sh0=0; sl0=0; ArrayResize(fv,0);
   int n=CopyRates(sym,tf,0,300,r); if(n<60) return "{\"tf\":\""+TfNome(tf)+"\",\"erro\":\"sem dados\"}";
   double sh[2]={0,0}, sl[2]={0,0}; int a=0,b=0;
   for(int j=3;j<n-3 && (a<2||b<2);j++){ if(a<2&&IsSH(r,j,2)) sh[a++]=r[j].high; if(b<2&&IsSL(r,j,2)) sl[b++]=r[j].low; }
   sh0=sh[0]; sl0=sl[0];
   string bos="nenhum"; if(sh[0]>0 && r[1].close>sh[0]) bos="rompeu o topo "+FmtS(sym,sh[0])+" (alta)"; else if(sl[0]>0 && r[1].close<sl[0]) bos="rompeu o fundo "+FmtS(sym,sl[0])+" (baixa)";
   ScanFVG(r,tf,150,fv);
   string fs=""; int k=0;
   for(int i=ArraySize(fv)-1;i>=0 && k<4;i--){ if(fv[i].filled) continue; fs+=(fs==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",fv[i].dir==1?"alta":"baixa",FmtS(sym,fv[i].top),FmtS(sym,fv[i].bot)); k++; }
   string vel=""; for(int i=3;i>=1;i--) vel+=(i<3?",":"")+StringFormat("[%s,%s,%s,%s]",FmtS(sym,r[i].open),FmtS(sym,r[i].high),FmtS(sym,r[i].low),FmtS(sym,r[i].close));
   int tr=TrendTFs(sym,tf);
   return StringFormat("{\"tf\":\"%s\",\"tendencia\":%d,\"atr\":%s,\"topos\":[%s,%s],\"fundos\":[%s,%s],\"bos\":\"%s\",\"fvg_abertos\":[%s],\"ultimas_3_velas_OHLC\":[%s]}",
      TfNome(tf),tr,FmtS(sym,ATRof(r,14,1)),FmtS(sym,sh[0]),FmtS(sym,sh[1]),FmtS(sym,sl[0]),FmtS(sym,sl[1]),bos,fs,vel);
}
double g_fHi=0,g_fLo=0; FVGz g_fFvg[];
string TFContextJSON(string sym,ENUM_TIMEFRAMES tf)
{
   SymbolSelect(sym,true);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID), ask=SymbolInfoDouble(sym,SYMBOL_ASK);
   string j="{\"simbolo\":\""+sym+"\",\"tf_foco\":\""+TfNome(tf)+"\",\"hora_servidor\":\""+TimeToString(TimeTradeServer(),TIME_DATE|TIME_MINUTES)+"\",\"preco\":"+FmtS(sym,bid)+",\"spread\":"+FmtS(sym,ask-bid)+",\"tendencias\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+IntegerToString(TrendTFs(sym,g_mtfTF[i]));
   double h2,l2; FVGz f2[];
   j+="},\"foco\":"+TfResumo(sym,tf,g_fHi,g_fLo,g_fFvg)+",\"tf_maior\":"+TfResumo(sym,TfMaior(tf),h2,l2,f2);
   double pdh=iHigh(sym,PERIOD_D1,1), pdl=iLow(sym,PERIOD_D1,1), pwh=iHigh(sym,PERIOD_W1,1), pwl=iLow(sym,PERIOD_W1,1);
   j+=",\"PDH\":"+FmtS(sym,pdh)+",\"PDL\":"+FmtS(sym,pdl)+",\"semana_passada_max\":"+FmtS(sym,pwh)+",\"semana_passada_min\":"+FmtS(sym,pwl);
   j+=",\"noticias\":"+NewsJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\",\"posicoes_abertas\":"+PosJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"}",g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare));
   if(sym==_Symbol) j+=",\"professor_do_grafico\":"+ContextJSON();
   return j+"}";
}
// print de qualquer símbolo/TF: abre um gráfico temporário, desenha níveis e FVGs, tira o print e fecha
bool FotoTF(string sym,ENUM_TIMEFRAMES tf,string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   SymbolSelect(sym,true);
   long id=ChartOpen(sym,tf); if(id==0){ Print("Telegram: não abri gráfico ",sym," ",TfNome(tf)); return false; }
   ChartSetInteger(id,CHART_COLOR_BACKGROUND,clrBlack); ChartSetInteger(id,CHART_COLOR_FOREGROUND,clrGold); ChartSetInteger(id,CHART_SHOW_GRID,false);
   ChartSetInteger(id,CHART_COLOR_CANDLE_BULL,clrGold); ChartSetInteger(id,CHART_COLOR_CHART_UP,clrGold); ChartSetInteger(id,CHART_COLOR_CANDLE_BEAR,C'60,60,60');
   ChartSetInteger(id,CHART_COLOR_CHART_DOWN,clrSilver); ChartSetInteger(id,CHART_MODE,CHART_CANDLES); ChartSetInteger(id,CHART_SHIFT,true); ChartSetInteger(id,CHART_AUTOSCROLL,true); ChartSetInteger(id,CHART_SCALE,3);
   for(int i=0;i<25 && Bars(sym,tf)<100;i++) Sleep(200);
   datetime t0=iTime(sym,tf,120), t1=iTime(sym,tf,0)+PeriodSeconds(tf)*10;
   double lv[4]; string ln[4]={"PDH","PDL","topo","fundo"}; color lc[4]={clrDodgerBlue,clrDodgerBlue,clrGold,clrGold};
   lv[0]=iHigh(sym,PERIOD_D1,1); lv[1]=iLow(sym,PERIOD_D1,1); lv[2]=g_fHi; lv[3]=g_fLo;
   for(int i=0;i<4;i++){ if(lv[i]<=0) continue; string o="AP_T_L"+IntegerToString(i); ObjectCreate(id,o,OBJ_TREND,0,t0,lv[i],t1,lv[i]); ObjectSetInteger(id,o,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,o,OBJPROP_STYLE,STYLE_DASH); ObjectSetString(id,o,OBJPROP_TEXT,ln[i]);
      string ot="AP_T_T"+IntegerToString(i); ObjectCreate(id,ot,OBJ_TEXT,0,t1,lv[i]); ObjectSetString(id,ot,OBJPROP_TEXT,ln[i]+" "+FmtS(sym,lv[i])); ObjectSetInteger(id,ot,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,ot,OBJPROP_FONTSIZE,9); }
   int k=0;
   for(int i=ArraySize(g_fFvg)-1;i>=0 && k<4;i--){ if(g_fFvg[i].filled) continue; string o="AP_T_F"+IntegerToString(k++); ObjectCreate(id,o,OBJ_RECTANGLE,0,g_fFvg[i].t0,g_fFvg[i].top,t1,g_fFvg[i].bot); ObjectSetInteger(id,o,OBJPROP_COLOR,g_fFvg[i].dir==1?C'0,90,60':C'110,30,30'); ObjectSetInteger(id,o,OBJPROP_FILL,true); ObjectSetInteger(id,o,OBJPROP_BACK,true); }
   string tt="AP_T_TIT"; ObjectCreate(id,tt,OBJ_LABEL,0,0,0); ObjectSetInteger(id,tt,OBJPROP_XDISTANCE,10); ObjectSetInteger(id,tt,OBJPROP_YDISTANCE,10); ObjectSetString(id,tt,OBJPROP_TEXT,"ALIEN PROFESSOR  "+sym+"  "+TfNome(tf)); ObjectSetInteger(id,tt,OBJPROP_COLOR,clrGold); ObjectSetInteger(id,tt,OBJPROP_FONTSIZE,14);
   ChartRedraw(id); Sleep(1500); ChartRedraw(id);
   string f="APROF_tf_"+IntegerToString(GetTickCount())+".png";
   bool ok=ChartScreenShot(id,f,1600,900,ALIGN_RIGHT);
   ChartClose(id);
   if(!ok){ Print("Telegram: print do ",sym," ",TfNome(tf)," falhou"); return false; }
   ok=SendPhoto(f,caption); FileDelete(f); return ok;
}
bool EhMercado(string t)
{
   string u=t; StringToLower(u);
   string k[]={"compr","vend","entr","oper","trade","mercado","ouro","gold","xau","nasdaq","us500","dax","índice","indice","liquidez","fvg","bos","stop","alvo","tendên","tendenc","sinal","long","short","sell","buy","gráfico","grafico","preço","preco","notícia","noticia","analis","análise","agora","topo","fundo","varr"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
bool TgFoto(string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   string f="APROF_chat_"+_Symbol+".png"; ChartRedraw(0);
   if(!ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)){ Print("Telegram: não consegui tirar o print"); return false; }
   return SendPhoto(f,caption);
}
void ChatIA(string pergunta,string titulo,string sym="",ENUM_TIMEFRAMES tf=PERIOD_CURRENT)
{
   bool mercado = (sym!="" || EhMercado(pergunta));
   if(sym=="" && tf!=PERIOD_CURRENT) sym=_Symbol;
   if(sym!="" && tf==PERIOD_CURRENT) tf=InpTFExec;
   if(!AIOn())
   {
      Plano b=MelhorPlano();
      SendMsg("IA desligada (coloque a chave em InpAIKey ou InpAI2Key e libere o endereço no WebRequest). Leitura do professor:\n"+Narrativa(b,g_pare!=""||NoticiaAviso(TimeTradeServer())!="",NoticiaAviso(TimeTradeServer())));
      if(sym!="") { TFContextJSON(sym,tf); FotoTF(sym,tf,sym+" "+TfNome(tf)); } else TgFoto(_Symbol+" agora");
      return;
   }
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma: limite da IA. Tente de novo em %d s.",w)); return; }
   string ctx = sym!="" ? TFContextJSON(sym,tf) : ContextJSON();
   string r=AIAskEx(SysChat(),MemTxt()+"CONTEXTO DO MERCADO:\n"+ctx+"\n\nMENSAGEM DO VITOR:\n"+pergunta,650,false,mercado);
   if(r==""){ SendMsg("A IA não respondeu agora (veja a aba Experts do MT5). Tente de novo em 1 minuto."); return; }
   MemAdd("Vitor",pergunta); MemAdd("Professor",r);
   if(sym=="" || sym==_Symbol) g_aiPanel=r;
   SendMsg(titulo+"\n"+r+(mercado?"\n\n(opinião da IA - quem decide é você)":""));
   if(sym!="") FotoTF(sym,tf,sym+" "+TfNome(tf)+" "+TimeToString(TimeTradeServer(),TIME_MINUTES)+" (servidor)");
   else if(mercado) TgFoto(_Symbol+" "+TimeToString(TimeTradeServer(),TIME_MINUTES)+" (servidor)");
}
string StatusTxt()
{
   string s=StringFormat("ALIEN %s - STATUS\nModo: %s | conta %s\nRobô: %s\n",_Symbol,InpTradeEnabled?"OPERANDO":"ASSISTENTE (não opera)",
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",g_status);
   s+=StringFormat("Saldo $%.2f | Equity $%.2f\n",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   s+=StringFormat("Hoje: %d operações, %d stops (máx %d), resultado $%+.2f (meta $%.0f / perda máx $%.0f)\n",g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD);
   s+="Disciplina: "+(g_pare!=""?g_pare:"OK, pode operar")+(g_ddPause?" | PAUSADO pelo DD":"")+"\n";
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") s+=nw+"\n";
   int np=0; string ps="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue; np++;
      ps+=StringFormat("  %s %s %.2f lote @%s  P/L $%+.2f%s\n",PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",
          PositionGetDouble(POSITION_VOLUME),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS)),
          PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?" (robô)":" (manual)");
   }
   s+="Posições abertas: "+IntegerToString(np)+"\n"+ps;
   Plano b=MelhorPlano();
   s+=StringFormat("Nota agora: %s %d/10 (outro lado %d/10)\n",b.dir==1?"COMPRA":"VENDA",b.score,b.dir==1?g_ps.score:g_pb.score);
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   s+=StringFormat("Aprendizado (%s): %d trades, acerto %.0f%%, R médio %+.2f\n",_Symbol,n,w,a);
   string fx[4]={"0-4","5-6","7-8","9-10"};
   for(int f=0;f<4;f++){ int nn; double ww,aa; HStat(fx[f],0,"",nn,ww,aa); if(nn>0) s+=StringFormat("  nota %s: %d trades, acerto %.0f%%, R %+.2f\n",fx[f],nn,ww,aa); }
   s+="Trava do histórico: "+(InpAprenderDesativar?"LIGADA":"desligada");
   return s;
}
string AjudaTxt()
{
   return "ALIEN PROFESSOR - comandos ("+_Symbol+"):\n"
          "/analise - análise completa agora (IA) + print do gráfico\n"
          "/analise H4  ou  /analise XAUUSD M15 - qualquer símbolo e tempo (M1 M5 M15 M30 H1 H4 D1 W1)\n"
          "/status - posições, resultado de hoje, disciplina, aprendizado\n"
          "/noticias - próximas notícias fortes/médias ("+InpCalMoedas+")\n"
          "/foto - só o print do gráfico\n"
          "/ajuda - esta lista\n"
          "Ou escreva qualquer coisa (ex.: \"como tá o M15?\", \"e o ouro no H4?\", \"vale comprar agora?\"). Eu lembro das últimas 10 mensagens.";
}
void TgHandle(string chat,string text)
{
   StringTrimLeft(text); StringTrimRight(text); if(text=="") return;
   string cmd=text; int sp=StringFind(cmd," "); if(sp>0) cmd=StringSubstr(cmd,0,sp);
   int at=StringFind(cmd,"@"); if(at>0) cmd=StringSubstr(cmd,0,at);
   StringToLower(cmd);
   if(InpTelegramChatId=="")
   {
      if(cmd=="/start")
      {
         g_tgHint="Telegram: seu chat id é "+chat+" - copie para InpTelegramChatId e reinicie o robô";
         Print("ALIEN: ",g_tgHint); g_statusSvc=g_tgHint;
         SendMsgTo(chat,"Seu chat id é "+chat+". Cole em InpTelegramChatId nas configurações do robô e reinicie. Até lá eu não respondo comandos.");
      }
      return;
   }
   if(chat!=InpTelegramChatId){ Print("Telegram: ignorei mensagem de um chat não autorizado (",chat,")"); return; }
   Print("Telegram: comando ",cmd);
   if(cmd=="/start" || cmd=="/ajuda" || cmd=="/help"){ SendMsg(AjudaTxt()); return; }
   if(cmd=="/status"){ SendMsg(StatusTxt()); return; }
   if(cmd=="/noticias" || cmd=="/notícias"){ LoadNews(true); SendMsg("PRÓXIMAS NOTÍCIAS ("+InpCalMoedas+", hora do servidor):\n"+NewsLista(10,"\n")+(InpCalBloquearForte?StringFormat("\n\nNotícia FORTE: robô não entra %d min antes/depois.",InpNoticiaMin):"")); return; }
   if(cmd=="/foto"){ if(!TgFoto(_Symbol+" agora")) SendMsg("Não consegui mandar o print."); return; }
   if(cmd=="/analise" || cmd=="/análise")
   {
      string asy; ENUM_TIMEFRAMES atf;
      if(sp>0 && ParseAlvo(StringSubstr(text,sp+1),true,asy,atf))
      {
         if(asy=="") asy=_Symbol; if(atf==PERIOD_CURRENT) atf=InpTFExec;
         SendMsg("Analisando "+asy+" "+TfNome(atf)+"...");
         ChatIA("Faça a análise completa do "+asy+" no "+TfNome(atf)+" (com o contexto do tempo maior): tendência, liquidez (PDH/PDL, topos/fundos), BOS, FVGs, notícias. Vale comprar, vender ou esperar? O que confirma e o que invalida?","ANÁLISE "+asy+" "+TfNome(atf),asy,atf);
         return;
      }
      if(sp>0){ SendMsg("Não achei esse símbolo/tempo. Exemplos: /analise H4  |  /analise XAUUSD M15  |  /analise US500 H1"); return; }
      SendMsg("Analisando "+_Symbol+"..."); ChatIA("Faça a análise completa de agora: tendência em cada tempo gráfico (alinhado ou conflito), liquidez e varridas, BOS, FVGs, nota e plano, notícias. Vale entrar, esperar ou ficar fora? O que confirma e o que invalida?","ANÁLISE "+_Symbol); return; }
   if(StringGetCharacter(text,0)=='/'){ SendMsg("Comando não conhecido.\n\n"+AjudaTxt()); return; }
   string fsy; ENUM_TIMEFRAMES ftf;
   if(ParseAlvo(text,false,fsy,ftf)) ChatIA(text,"ALIEN "+(fsy!=""?fsy:_Symbol)+(ftf!=PERIOD_CURRENT?" "+TfNome(ftf):"")+":",fsy,ftf);
   else ChatIA(text,"ALIEN PROFESSOR:");
}
void TgPoll()
{
   if(!TgTokenOk() || !InpTgChat) return;
   g_tgMaster=TgMaster(); if(!g_tgMaster) return;
   string url="https://api.telegram.org/bot"+InpTelegramToken+"/getUpdates?timeout=0&limit=20&offset="+IntegerToString(g_tgOff);
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",5000,data,res,rh);
   if(code==-1){ if(g_tgErrPrint++%60==0) Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ if(g_tgErrPrint++%60==0) Print("Telegram getUpdates respondeu ",code,code==409?" (o bot tem webhook ou outro programa lendo - só um pode ler)":(code==401?" (token inválido - crie um novo no @BotFather)":""),": ",StringSubstr(r,0,200)); return; }
   int pos=0;
   while(true)
   {
      int k=StringFind(r,"\"update_id\":",pos); if(k<0) break;
      int nx=StringFind(r,"\"update_id\":",k+12);
      string seg= nx>0 ? StringSubstr(r,k,nx-k) : StringSubstr(r,k);
      long uid=StringToInteger(JNumKey(seg,"update_id"));
      if(uid>=g_tgOff) g_tgOff=uid+1;
      pos= nx>0 ? nx : StringLen(r);
      int cpos=StringFind(seg,"\"chat\":"); if(cpos<0) continue;
      string chat=JNumKey(seg,"id",cpos);
      long dt=StringToInteger(JNumKey(seg,"date"));
      if(dt>0 && dt<(long)g_tgStartUtc-120) continue;        // mensagem velha (antes do robô ligar)
      string text=JStrKey(seg,"text");
      if(chat!="" && text!="") TgHandle(chat,text);
   }
}
// pré-aviso de notícia FORTE (só a instância que lê o chat, pra não repetir)
void TgPreAlerta()
{
   if(!TgOk() || InpPreAlertaMin<=0 || !CalOn()) return;
   if(InpTgChat && !g_tgMaster) return;
   LoadNews(); datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3 || StringFind(InpPreAlertaMoedas,g_news[i].cur)<0) continue;
      long d=(long)(g_news[i].t-now); if(d<=0 || d>InpPreAlertaMin*60) continue;
      string key="|"+IntegerToString((long)g_news[i].id)+"|"; if(StringFind(g_alertados,key)>=0) continue;
      g_alertados+=IntegerToString((long)g_news[i].id)+"|";
      SendMsg(StringFormat("ATENÇÃO: notícia FORTE %s em %d min (%s servidor): %s.%s",g_news[i].cur,(int)(d/60)+1,HHMM(g_news[i].t),g_news[i].nome,
              InpCalBloquearForte?StringFormat(" O robô não entra %d min antes/depois. Proteja suas posições.",InpNoticiaMin):""));
   }
}
// resumo automático na abertura de Londres / NY
int HHMMtoMin(string s){ string p[]; if(StringSplit(s,':',p)<2) return -1; return (int)StringToInteger(p[0])*60+(int)StringToInteger(p[1]); }
void TgResumos()
{
   if(!TgOk() || !InpResumos) return;
   datetime now=TimeTradeServer(); MqlDateTime d; TimeToStruct(now,d);
   if(d.day_of_week==0 || d.day_of_week==6) return;      // fim de semana
   string nomes[2]={"LONDRES","NOVA YORK"}; string hs[2]; hs[0]=InpResumoLondres; hs[1]=InpResumoNY;
   for(int i=0;i<2;i++)
   {
      int m=HHMMtoMin(hs[i]); if(m<0) continue;
      int dm=MinOfDay(now)-m; if(dm<0 || dm>10) continue;
      string key=TimeToString(now,TIME_DATE)+nomes[i]+"|"; if(StringFind(g_resFeitos,key)>=0) continue;
      g_resFeitos+=key;
      Plano b=MelhorPlano();
      string r="";
      if(AIOn()) r=AIAskEx("Você é o ALIEN PROFESSOR. Escreva em português do Brasil o resumo da abertura da sessão de "+nomes[i]+" para o Vitor, no máximo 10 linhas, sem markdown: "
                           "tendência D1/H4/H1/M15 (alinhado ou conflito), viés do dia, liquidez acima/abaixo e o que já foi varrido, FVGs importantes, notícias fortes do dia, e o plano (o que esperar para comprar ou vender e o que invalida). Sem prometer lucro.",
                           "CONTEXTO:\n"+ContextJSON(),600,true);
      if(r=="") r=Narrativa(b,g_pare!="",NoticiaAviso(now))+"\nNotícias: "+NewsLista(4," | ");
      else g_aiPanel=r;
      SendMsg("ABERTURA DE "+nomes[i]+" - "+_Symbol+"\n"+r);
      TgFoto(_Symbol+" abertura de "+nomes[i]);
   }
}
