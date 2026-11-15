
//====================================================================
// PARTE DO ROBÔ
CTrade   g_tr;
double   g_peak=0;
bool     g_ddPause=false;
datetime g_lastSigBar=0;
int      g_prevScore[2]={0,0};
string   g_status="";

bool ContaBloqueada()
{
   if(MQLInfoInteger(MQL_TESTER)) return false;
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO && !InpAllowRealAccount);
}
bool TemPosOuOrdem()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(t>0 && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) return true; }
   for(int i=OrdersTotal()-1;i>=0;i--){ ulong t=OrderGetTicket(i); if(t>0 && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==InpMagic) return true; }
   return false;
}
double NormP(double p){ double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(ts<=0) ts=_Point; return NormalizeDouble(MathRound(p/ts)*ts,_Digits); }
void Notifica(string m){ Print(m); if(TgOk()) SendMsg(m); }

// fecha por tempo / horário e cancela limitada vencida
void Gerencia()
{
   datetime now=TimeCurrent(); MqlDateTime d; TimeToStruct(now,d); int hhmm=d.hour*100+d.min;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol || OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      if((InpLimiteMin>0 && now-(datetime)OrderGetInteger(ORDER_TIME_SETUP)>=InpLimiteMin*60) || (InpFecharHHMM>0 && hhmm>=InpFecharHHMM)) { g_tr.OrderDelete(t); }
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if((InpMaxHoras>0 && now-(datetime)PositionGetInteger(POSITION_TIME)>=InpMaxHoras*3600) || (InpFecharHHMM>0 && hhmm>=InpFecharHHMM))
      { if(g_tr.PositionClose(t)) Notifica(StringFormat("Fechei o %s por horário/tempo.",_Symbol)); }
   }
}

string Bloqueio(const Plano &b)
{
   if(ContaBloqueada()) return "BLOQUEADO: CONTA REAL (InpAllowRealAccount = false)";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && !MQLInfoInteger(MQL_TESTER)) return "AlgoTrading desligado no terminal";
   if(InpDDPausaPct>0 && g_ddPause) return StringFormat("PAUSADO: caiu %.0f%% do pico. Reinicie o robô só depois de rever tudo.",InpDDPausaPct);
   if(g_pare!="") return g_pare;
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") return nw;
   string st; int sN=SessaoNota(TimeCurrent(),st);
   if(InpBloquearHorarioRuim && sN==-1) return "horário ruim - não opera";
   MqlDateTime d; TimeToStruct(TimeCurrent(),d); if(InpFecharHHMM>0 && d.hour*100+d.min>=InpFecharHHMM-100) return "perto do fechamento do dia";
   return "";
}



//====================================================================
// APRENDIZADO: diário de sinais + resultado de cada trade (MQL5\Files)
//  ALIEN_diario.csv      -> todo sinal (operado ou pulado, com motivo)
//  ALIEN_aprendizado.csv -> cada trade fechado: nota, faixa, lado, sessão, hora, R
string   g_sigInfo="";            // info do sinal da ordem aberta (1 posição por vez)
double   g_sigRiskUSD=0; int g_sigScore=0, g_sigDir=0, g_sigHour=0; string g_sigSess=""; datetime g_sigTime=0;
string Faixa(int sc){ return sc<=4?"0-4":(sc<=6?"5-6":(sc<=8?"7-8":"9-10")); }
string SessNome(datetime t){ string st; SessaoNota(t,st); int p=StringFind(st," -"); return p>0?StringSubstr(st,0,p):st; }
void CsvAppend(string file,string header,string line)
{
   int h=FileOpen(file,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0) FileWriteString(h,header+"\r\n");
   FileSeek(h,0,SEEK_END); FileWriteString(h,line+"\r\n"); FileClose(h);
}
void Diario(const Plano &b,string acao)
{
   CsvAppend("ALIEN_diario.csv","hora;simbolo;lado;nota;faixa;sessao;entrada;stop;alvo;rr;lote;acao",
      StringFormat("%s;%s;%s;%d;%s;%s;%s;%s;%s;%.2f;%.2f;%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),_Symbol,b.dir==1?"compra":"venda",b.score,Faixa(b.score),
      SessNome(TimeCurrent()),Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.rr,b.lot,acao));
}
// estatística do histórico (ALIEN_aprendizado.csv) para a IA e para a trava opcional
struct HistRow { string sym; int dir; int score; string sess; int hour; double R; };
HistRow g_hist[]; datetime g_histLoad=0;
void LoadHist()
{
   if(TimeCurrent()-g_histLoad<300 && g_histLoad>0) return;
   g_histLoad=TimeCurrent(); ArrayResize(g_hist,0);
   int h=FileOpen("ALIEN_aprendizado.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return;
   bool first=true;
   while(!FileIsEnding(h))
   {
      string ln=FileReadString(h); if(first){ first=false; continue; }
      string c[]; if(StringSplit(ln,';',c)<10) continue;
      int k=ArraySize(g_hist); ArrayResize(g_hist,k+1);
      g_hist[k].sym=c[1]; g_hist[k].dir=(c[2]=="compra"?1:-1); g_hist[k].score=(int)StringToInteger(c[3]);
      g_hist[k].sess=c[5]; g_hist[k].hour=(int)StringToInteger(c[6]); g_hist[k].R=StringToDouble(c[9]);
   }
   FileClose(h);
}
void HStat(string faixa,int dir,string sess,int &n,double &win,double &avg)
{
   n=0; double w=0,s=0;
   for(int i=0;i<ArraySize(g_hist);i++)
   {
      if(g_hist[i].sym!=_Symbol) continue;
      if(faixa!="" && Faixa(g_hist[i].score)!=faixa) continue;
      if(dir!=0 && g_hist[i].dir!=dir) continue;
      if(sess!="" && g_hist[i].sess!=sess) continue;
      n++; s+=g_hist[i].R; if(g_hist[i].R>0) w++;
   }
   win = n>0? 100.0*w/n : 0; avg = n>0? s/n : 0;
}
bool FaixaDesativada(string faixa,int dir,string sess)
{
   int n; double w,a; HStat(faixa,dir,sess,n,w,a);
   return (n>=InpAprenderMinN && a<0);
}
string HistResumo(const Plano &b)
{
   LoadHist();
   int nAll; double wAll,aAll; HStat("",0,"",nAll,wAll,aAll);
   if(nAll==0) return "{\"trades\":0,\"nota\":\"sem histórico ainda\"}";
   string fx=Faixa(b.score), ss=SessNome(TimeCurrent());
   int n; double w,a; HStat(fx,b.dir,ss,n,w,a);
   // melhores/piores horas (n>=3)
   double hs[24]; int hn[24]; ArrayInitialize(hs,0); ArrayInitialize(hn,0);
   for(int i=0;i<ArraySize(g_hist);i++) if(g_hist[i].sym==_Symbol && g_hist[i].hour>=0 && g_hist[i].hour<24){ hs[g_hist[i].hour]+=g_hist[i].R; hn[g_hist[i].hour]++; }
   int best=-1,worst=-1;
   for(int hh=0;hh<24;hh++){ if(hn[hh]<3) continue; double m=hs[hh]/hn[hh]; if(best<0||m>hs[best]/hn[best]) best=hh; if(worst<0||m<hs[worst]/hn[worst]) worst=hh; }
   // faixas que a trava desativaria
   string des=""; string fxs[4]={"0-4","5-6","7-8","9-10"}; string sss[4]={"Ásia","Londres","Nova York","fim de NY / madrugada"};
   for(int f=0;f<4;f++) for(int d=0;d<2;d++) for(int q=0;q<4;q++)
      if(FaixaDesativada(fxs[f],d==0?1:-1,sss[q])) des+=(des==""?"":",")+"\""+fxs[f]+" "+(d==0?"compra":"venda")+" "+sss[q]+"\"";
   return StringFormat("{\"trades\":%d,\"acerto_geral\":%.0f,\"R_medio_geral\":%.2f,\"parecidos\":{\"filtro\":\"%s %s %s\",\"n\":%d,\"acerto\":%.0f,\"R_medio\":%.2f},\"melhor_hora\":%s,\"pior_hora\":%s,\"faixas_desativadas\":[%s],\"trava_ligada\":%s}",
      nAll,wAll,aAll,fx,b.dir==1?"compra":"venda",ss,n,w,a,best>=0?IntegerToString(best):"null",worst>=0?IntegerToString(worst):"null",des,InpAprenderDesativar?"true":"false");
}
// estado do professor em JSON compacto (para a IA)
string StateJSON(const Plano &b)
{
   string j="{\"simbolo\":\""+_Symbol+"\",\"hora_servidor\":\""+TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+"\",\"tendencias\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+IntegerToString(g_mtf[i]);
   j+="},\"niveis\":[";
   for(int v=0;v<ArraySize(g_niv);v++) j+=(v?",":"")+StringFormat("{\"n\":\"%s\",\"p\":%s,\"e\":\"%s\"}",JEsc(g_niv[v].nome),Fmt(g_niv[v].preco),g_niv[v].estado==ST_VARRIDA?"varrida":(g_niv[v].estado==ST_ROMPIDO?"rompido":"intacto"));
   int nb=ArraySize(g_bos);
   j+="],\"ultimo_bos\":"+(nb>0?StringFormat("{\"dir\":%d,\"preco\":%s,\"choch\":%s}",g_bos[nb-1].dir,Fmt(g_bos[nb-1].preco),g_bos[nb-1].choch?"true":"false"):"null");
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"}; string pts="";
   for(int i=0;i<7;i++) pts+=(i?",":"")+"\""+nm[i]+"\":"+(b.pts[i]?"true":"false");
   if(PlanoValido(b))
      j+=StringFormat(",\"plano\":{\"valido\":true,\"dir\":\"%s\",\"nota\":%d,\"entrada\":%s,\"stop\":%s,\"alvo\":%s,\"rr\":%.2f,\"lote\":%.2f,\"risco_usd\":%.2f},\"criterios\":{%s}",
        b.dir==1?"compra":"venda",b.score,Fmt(b.entry),Fmt(b.stop),Fmt(b.target),b.rr,b.lot,b.riskUSD,pts);
   else
      j+=StringFormat(",\"plano\":{\"valido\":false,\"dir\":\"%s\",\"nota\":%d,\"motivo\":\"%s\",\"entrada\":null,\"stop\":null,\"alvo\":null,\"rr\":0},\"criterios\":{%s}",
        b.dir==1?"compra":"venda",b.score,JEsc(PlanoSemSetup(b.dir)),pts);
   j+=",\"historico_do_vitor\":"+HistResumo(b);
   j+=",\"leitura\":\""+JEsc(Narrativa(b,false,""))+"\",\"aviso\":\"teste 2016-2025: sinais nota>=7 perderam em media\"}";
   return j;
}
//@@CHAT@@
string SvcStatus()
{
   string s=AIStatus();
   if(g_tgHint!="" && g_cfgTgChat=="") return g_tgHint;
   string t = !InpUseTelegram ? "Telegram: desligado" : (StringLen(g_cfgTgToken)<=20 ? "Telegram: coloque o token" :
              (StringLen(g_cfgTgChat)==0 ? "Telegram: mande /start pro seu bot (eu me conecto sozinho)" :
              (MQLInfoInteger(MQL_TESTER) ? "Telegram: não roda no testador" : (InpTgChat ? (g_tgMaster?"Telegram: chat ATIVO neste gráfico (/ajuda)":"Telegram: chat atendido por outro gráfico") : ""))));
   if(s!="" && t!="") return s+"  |  "+t;
   return s+t;
}
void TentaOperar()
{
   Plano b; int di;
   b=MelhorPlano(); di=(b.dir==1?0:1);
   // sinal = nota cruza o limite com plano válido (RR >= InpMinRR)
   bool cruzou = (PlanoValido(b) && b.score>=InpScoreTrade && g_prevScore[di]<InpScoreTrade);
   g_prevScore[0]=PlanoValido(g_pb)?g_pb.score:0; g_prevScore[1]=PlanoValido(g_ps)?g_ps.score:0;
   string blk=Bloqueio(b);
   if(!TradeAtivo())
   {
      // assistente ou /pausa: não manda ordem, só avisa o sinal (com análise e print)
      g_status = g_tradePausa?"PAUSADO por /pausa (não opera)":("MODO ASSISTENTE: só analisa e avisa"+(blk!=""?" | "+blk:""));
      if(!cruzou) return;
      Diario(b,"sinal (modo assistente, não operou)"+(blk!=""?" - "+blk:""));
      string ia2=AIAsk(StateJSON(b)); if(ia2!=""){ AIPanelSet(ia2); ObsSet(ia2,"🤖"); VereditoLog("sinal"); }
      Notifica(StringFormat("Achei um sinal de %s no %s, nota %d/10 — mas tô no modo assistente, não operei.\nEntrada %s, stop %s, alvo %s, lote %.2f (risco ~$%.2f).\n%s%s",
               b.dir==1?"🟢 COMPRA":"🔴 VENDA",_Symbol,b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.lot,b.riskUSD,
               blk!=""?"Aviso: "+blk+"\n":"",Narrativa(b,false,""))+(ia2!=""?"\n\nO que a IA achou:\n"+ia2:""));
      if(TgOk() && InpTgFoto && !MQLInfoInteger(MQL_TESTER)) TgFoto(StringFormat("%s SINAL %s %d/10",_Symbol,b.dir==1?"COMPRA":"VENDA",b.score));
      return;
   }
   g_status = blk!="" ? blk : (TemPosOuOrdem()?"em operação (1 por vez)":StringFormat("aguardando nota >= %d",InpScoreTrade));
   if(!cruzou) return;
   if(blk!=""){ Diario(b,"pulado: "+blk); return; }
   if(TemPosOuOrdem()){ Diario(b,"pulado: já tem posição"); return; }
   LoadHist();
   if(InpAprenderDesativar && FaixaDesativada(Faixa(b.score),b.dir,SessNome(TimeCurrent()))){ Diario(b,"pulado: faixa desativada pelo histórico"); Print("ALIEN AUTO: faixa desativada pelo seu histórico - pulei"); return; }
   if(b.loteMinAcima || b.lot<=0){ Print("ALIEN AUTO: lote mínimo passa do risco - pulei"); return; }
   if(!PlanoValido(b) || b.rr+1e-12<RRMinAlvo()){ Diario(b,"pulado: "+PlanoSemSetup(b.dir)); Print("ALIEN AUTO: ",PlanoSemSetup(b.dir)," - não opero com RR abaixo do mínimo"); return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=NormP(b.stop);
   double risk=MathAbs(b.entry-b.stop);
   if(risk<=0) return;
   if(InpSpreadMaxPctStop>0 && (ask-bid)>InpSpreadMaxPctStop/100.0*risk){ Print("ALIEN AUTO: spread alto - pulei"); return; }
   double tp=NormP(b.target);
   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double lot=NormalizeDouble(b.lot,2);
   string cm=StringFormat("APROF %d/10",b.score);
   // IA: comenta o sinal; só pode VETAR se InpAIVeto = true (nunca abre trade)
   string ia=AIAsk(StateJSON(b)); if(ia!=""){ AIPanelSet(ia); ObsSet(ia,"🤖"); VereditoLog("sinal"); }
   if(AIVetou(ia,b.dir)){ Diario(b,"pulado: IA vetou"); Notifica(StringFormat("A IA vetou o sinal do %s nota %d/10. Não entrei. %s",_Symbol,b.score,ia)); return; }
   bool ok=false; bool limite=(StringFind(b.entNome,"FVG")>=0 || StringFind(b.entNome,"vazio")>=0);
   if(limite)
   {
      double e=NormP(b.entry);
      if(b.dir==1 && e<ask-minDist && sl<e-minDist && tp>e+minDist) ok=g_tr.BuyLimit(lot,e,_Symbol,sl,tp,ORDER_TIME_GTC,0,cm);
      else if(b.dir==-1 && e>bid+minDist && sl>e+minDist && tp<e-minDist) ok=g_tr.SellLimit(lot,e,_Symbol,sl,tp,ORDER_TIME_GTC,0,cm);
      else { Print("ALIEN AUTO: preço já passou da entrada do FVG - pulei"); return; }
   }
   else
   {
      if(b.dir==1 && sl<bid-minDist && tp>ask+minDist) ok=g_tr.Buy(lot,_Symbol,0,sl,tp,cm);
      else if(b.dir==-1 && sl>ask+minDist && tp<bid-minDist) ok=g_tr.Sell(lot,_Symbol,0,sl,tp,cm);
      else return;
   }
   if(ok && TgOk() && InpTgFoto && !MQLInfoInteger(MQL_TESTER)){ string f="APROF_auto.png"; ChartRedraw(0); if(ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)) SendPhoto(f,StringFormat("ALIEN AUTO %s %s nota %d/10",_Symbol,b.dir==1?"COMPRA":"VENDA",b.score)); }
   if(ok){ Diario(b,limite?"ordem limitada":"a mercado"); g_sigRiskUSD=b.riskUSD; g_sigScore=b.score; g_sigDir=b.dir; g_sigTime=TimeCurrent(); MqlDateTime md; TimeToStruct(TimeCurrent(),md); g_sigHour=md.hour; g_sigSess=SessNome(TimeCurrent()); }
   else Diario(b,"recusada pela corretora");
   if(ok) Notifica(StringFormat("Bora: mandei %s de %s no %s, nota %d/10. Lote %.2f, entrada %s, stop %s, alvo %s (risco ~$%.2f). %s",
                   limite?"limitada":"a mercado",b.dir==1?"🟢 COMPRA":"🔴 VENDA",_Symbol,b.score,lot,Fmt(b.entry),Fmt(sl),Fmt(tp),b.riskUSD,Narrativa(b,false,""))+(ia!=""?"\n\nO que a IA achou:\n"+ia:""));
   else Print("ALIEN AUTO: ordem recusada ",g_tr.ResultRetcode()," ",g_tr.ResultRetcodeDescription());
}

int OnInit()
{
   g_noDraw = MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE);
   g_tr.SetExpertMagicNumber(InpMagic);
   g_tr.SetDeviationInPoints(30);
   g_tr.SetTypeFillingBySymbol(_Symbol);
   CfgLoad();
   Core_Init();
   g_peak=MathMax(AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO (mude InpAllowRealAccount por sua conta e risco)"; g_extraC=clrRed; }
   MathSrand((uint)(GetTickCount()^(uint)(ChartID()%1000000)));
   g_inst=(double)((ChartID()%1000000)*1000+MathRand()%1000+1);
   g_tgStartUtc=TimeGMT();
   PausaLoad();
   LoadNews(true);
   g_statusSvc=SvcStatus();
   // estado persistido (offset do Telegram, notícias avisadas, resumos, avisos) e aviso de volta só após queda real
   TgEstadoLoad(); ProLoad();
   ParadaInit();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); ObsApaga(); ParadaDeinit(r); TgEstadoSave(); TgMasterSolta(); Core_Deinit(); }
void OnTimer()
{
   ObsTimer();
   if(MQLInfoInteger(MQL_TESTER)) return;          // no testador não existe WebRequest/calendário
   Core_Update(true);
   static ulong lastPoll=0, lastMin=0; ulong ms=GetTickCount64();
   if(ms-lastPoll>=(ulong)MathMax(InpTgPollSeg,2)*1000){ lastPoll=ms; TgPoll(); }
   if(ms-lastMin>=30000){ lastMin=ms; ParadaBatimento(); LoadNews(); TgPreAlerta(); NoticiaResultado(); BomDia(); TgResumos(); LearnTimer(); g_statusSvc=SvcStatus(); }
}
void OnTick()
{
   Core_Update(false);
   LearnTick();
   ProativoBar();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_peak) g_peak=eq;
   if(InpDDPausaPct>0 && !g_ddPause && g_peak>0 && eq<g_peak*(1.0-InpDDPausaPct/100.0)){ g_ddPause=true; Notifica(StringFormat("Pausei o %s: a equity caiu %.0f%% do pico. Melhor revisar antes de ligar de novo.",_Symbol,InpDDPausaPct)); }
   Gerencia();
   datetime bt=iTime(_Symbol,InpTFExec,0);
   if(bt!=0 && bt!=g_lastSigBar && g_ready)
   {
      g_lastSigBar=bt;
      TentaOperar();
      g_statusSvc=SvcStatus();
      if(AIOn() && InpAIMinutos>0 && TimeCurrent()-g_aiLast>=InpAIMinutos*60)
      { Plano pb=MelhorPlano(); string t=AIAsk(StateJSON(pb)); if(t!=""){ AIPanelSet(t); ObsSet(t,"🤖"); VereditoLog("periodo"); } }
      if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO"; g_extraC=clrRed; }
      else { g_extra="ROBÔ: "+g_status; g_extraC= StringFind(g_status,"aguardando")==0||StringFind(g_status,"em operação")==0 ? clrLime : (StringFind(g_status,"MODO ASSISTENTE")==0 ? clrGold : clrOrangeRed); }
   }
}
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(tr.deal)) return;
   DisciplinaFechou(tr.deal);                       // qualquer trade da conta (seu ou do robô)
   if(!HistoryDealSelect(tr.deal)) return;
   if(HistoryDealGetInteger(tr.deal,DEAL_MAGIC)!=InpMagic) return;
   long en=HistoryDealGetInteger(tr.deal,DEAL_ENTRY);
   if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY)
   {
      double net=HistoryDealGetDouble(tr.deal,DEAL_PROFIT)+HistoryDealGetDouble(tr.deal,DEAL_SWAP)+HistoryDealGetDouble(tr.deal,DEAL_COMMISSION);
      double R = g_sigRiskUSD>0 ? net/g_sigRiskUSD : 0;
      if(g_sigScore>0)
         CsvAppend("ALIEN_aprendizado.csv","abertura;simbolo;lado;nota;faixa;sessao;hora;risco_usd;resultado_usd;R;motivo",
            StringFormat("%s;%s;%s;%d;%s;%s;%d;%.2f;%.2f;%.3f;%s",TimeToString(g_sigTime,TIME_DATE|TIME_MINUTES),_Symbol,g_sigDir==1?"compra":"venda",g_sigScore,Faixa(g_sigScore),
            g_sigSess,g_sigHour,g_sigRiskUSD,net,R,EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(tr.deal,DEAL_REASON))));
      g_histLoad=0;
      Notifica(StringFormat("Saiu do %s com %+.2f (%.2fR).",_Symbol,net,R));
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   EngChartEvent(id,sparam);
   if(id==CHARTEVENT_CHART_CHANGE) ObsDesenha();
}
