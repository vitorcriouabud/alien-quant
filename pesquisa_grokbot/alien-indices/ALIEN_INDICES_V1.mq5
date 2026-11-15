//+------------------------------------------------------------------+
//|                                           ALIEN_INDICES_V1.mq5   |
//|  Projeto ALIEN (Vitor Lima) - cesta de reversao a media em       |
//|  indices: RSI2 + IBS no grafico diario (D1), 3 indices, 6 fluxos.|
//|                                                                  |
//|  Regras copiadas EXATAMENTE da pesquisa (alien-research/code/v2: |
//|  fam2.py rsi2(th=10, stopk=3) e ibs(th=0.25, stopk=4),           |
//|  engine2.py sim()). Nada foi inventado ou otimizado aqui.        |
//|                                                                  |
//|  Um unico EA, colocado em UM grafico qualquer (ex.: .US500Cash), |
//|  opera os 3 simbolos. Sem martingale, sem grid, sem preco medio. |
//+------------------------------------------------------------------+
#property copyright "Projeto ALIEN - Vitor Lima"
#property version   "1.00"
#property description "ALIEN INDICES V1 - RSI2 + IBS diario em US500, US Tech e DE40."
#property description "1 trade por fluxo, stop fixo por ATR, risco % por trade. Sem martingale/grid."
#include <Trade/Trade.mqh>

//================== ENTRADAS (explicadas em portugues) ==================
input group "=== Simbolos (nomes da sua corretora) ==="
input string InpSimbolo1 = ".US500Cash";   // Indice 1 (S&P 500). RoboForex-ECN: .US500Cash
input string InpSimbolo2 = ".USTECHCash";  // Indice 2 (Nasdaq 100). RoboForex-ECN: .USTECHCash
input string InpSimbolo3 = ".DE40Cash";    // Indice 3 (DAX 40). RoboForex-ECN: .DE40Cash. Deixe vazio para nao usar
input bool   InpUsarRSI2 = true;           // Usar a estrategia RSI2 (compra e venda)
input bool   InpUsarIBS  = true;           // Usar a estrategia IBS (so compra)

input group "=== Risco (o mais importante) ==="
input double InpRiscoPorTrade   = 1.0;  // Risco por trade em % da conta (pesquisa: 1%)
input double InpRiscoTeto       = 2.0;  // Teto duro: nunca arriscar mais que isto por trade (%)
input double InpRiscoAbertoMax  = 6.5;  // Soma maxima do risco aberto em %. 6.5 = na pratica igual a pesquisa (6 fluxos x 1% + folga de arredondamento); 3 = mais conservador
input double InpPerdaDiariaMax  = 3.0;  // Se a conta cair isto (%) no dia, nao abre mais nada hoje (posicoes abertas seguem suas regras)
input double InpTravaDDPico     = 15.0; // Se a conta cair isto (%) do pico, PAUSA novas entradas (revisar antes de religar)
input bool   InpSoContaDemo     = true; // Seguranca: so opera em conta DEMO (mude para false so quando decidir ir pro real)

input group "=== Regras da pesquisa (NAO mexer sem novo teste) ==="
input double InpRSI_Limite   = 10.0;  // RSI2: compra se RSI(2) < isto; vende se RSI(2) > 100 - isto
input double InpRSI_StopATR  = 3.0;   // RSI2: stop = isto x ATR(20)
input int    InpRSI_MaxBarras= 10;    // RSI2: sai depois de tantas barras D1
input double InpIBS_Limite   = 0.25;  // IBS: compra se IBS < isto
input double InpIBS_StopATR  = 4.0;   // IBS: stop = isto x ATR(20)
input int    InpIBS_MaxBarras= 5;     // IBS: sai depois de tantas barras D1

input group "=== Execucao e painel ==="
input long   InpMagicBase    = 20261115; // Numero magico base (cada fluxo usa base+0..5)
input int    InpDesvioPontos = 50;       // Desvio maximo de preco na ordem (pontos)
input double InpSpreadMaxFracStop = 0.10; // Se o spread for maior que esta fracao do stop, espera (nao pula) ate melhorar
input bool   InpPainel       = true;     // Mostrar painel amarelo/preto no grafico
input bool   InpLogCSV       = true;     // Gravar ALIEN_INDICES_log.csv (pasta MQL5/Files) com cada decisao e trade

//================== CONSTANTES ==================
#define NSYM 3
#define NSTR 2   // 0 = RSI2, 1 = IBS
#define BARS_NEED 260

string   g_sym[NSYM];
bool     g_ok[NSYM];
datetime g_lastBar[NSYM];
bool     g_pendEntry[NSYM][NSTR];   // sinal valido aguardando spread/mercado
int      g_pendDir[NSYM][NSTR];
double   g_pendDist[NSYM][NSTR];
string   g_pendWhy[NSYM][NSTR];
datetime g_pendBar[NSYM][NSTR];
string   g_msg[NSYM];               // ultima decisao (painel)
string   g_ind[NSYM];               // indicadores (painel)
string   g_status = "";
double   g_dayStartEq = 0; int g_day = -1;
double   g_peakEq = 0;
bool     g_ddPaused = false;
int      g_csv = INVALID_HANDLE;
CTrade   trade;

string StrName(int k){ return k==0 ? "RSI2" : "IBS"; }
long   MagicOf(int s,int k){ return InpMagicBase + s*NSTR + k; }
string Nice(string s)
{
   string t=s; StringReplace(t,".",""); StringReplace(t,"Cash",""); return t;
}
//--------------------------------------------------------------------
void Log(string txt)
{
   Print("[ALIEN_INDICES] ", txt);
}
void Csv(string evt,string sym,string strat,string txt)
{
   if(g_csv==INVALID_HANDLE) return;
   FileWrite(g_csv, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS), evt, sym, strat,
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2), txt);
   FileFlush(g_csv);
}
//--------------------------------------------------------------------
// Indicadores da pesquisa, calculados sobre barras D1 FECHADAS.
// r[] em ordem cronologica (0 = mais antiga), ultima = barra fechada (shift 1).
struct Sig
{
   double close, high, low, prevHigh;
   double rsi2, ibs, sma200, sma5, atr20;
   bool   ok;
};
bool CalcSig(string sym, Sig &g)
{
   g.ok=false;
   MqlRates r[];
   ArraySetAsSeries(r,false);
   int n = CopyRates(sym, PERIOD_D1, 1, BARS_NEED, r);   // a partir da barra fechada
   if(n < 205) return false;
   int L = n-1;
   g.close=r[L].close; g.high=r[L].high; g.low=r[L].low; g.prevHigh=r[L-1].high;
   // SMA200 e SMA5 do fechamento (pandas rolling mean)
   double s=0; for(int i=L-199;i<=L;i++) s+=r[i].close; g.sma200=s/200.0;
   s=0; for(int i=L-4;i<=L;i++) s+=r[i].close; g.sma5=s/5.0;
   // ATR(20) = media SIMPLES do True Range (engine2.resample)
   s=0; for(int i=L-19;i<=L;i++)
   {
      double pc=r[i-1].close;
      double tr=MathMax(r[i].high-r[i].low, MathMax(MathAbs(r[i].high-pc), MathAbs(r[i].low-pc)));
      s+=tr;
   }
   g.atr20=s/20.0;
   // RSI(2) Wilder = ewm(alpha=1/2, adjust=False) desde o inicio da janela (fam2.rsi)
   double up=0,dn=0; bool first=true;
   for(int i=1;i<=L;i++)
   {
      double d=r[i].close-r[i-1].close;
      double u=d>0?d:0, w=d<0?-d:0;
      if(first){ up=u; dn=w; first=false; }
      else { up=up+0.5*(u-up); dn=dn+0.5*(w-dn); }
   }
   if(dn==0) g.rsi2 = (up==0? 50.0 : 100.0); else g.rsi2 = 100.0-100.0/(1.0+up/dn);
   double rg=g.high-g.low;
   g.ibs = rg>0 ? (g.close-g.low)/rg : -1;   // -1 = indefinido (barra sem range)
   g.ok = (g.atr20>0);
   return g.ok;
}
//--------------------------------------------------------------------
bool FindPos(int s,int k,ulong &ticket)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==g_sym[s] && PositionGetInteger(POSITION_MAGIC)==MagicOf(s,k))
      { ticket=t; return true; }
   }
   return false;
}
double MoneyPerPricePerLot(string sym)
{
   double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv<=0) tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0) return 0;
   return tv/ts;
}
// risco aberto (em dinheiro) de todas as posicoes deste EA
double OpenRiskMoney()
{
   double tot=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg<InpMagicBase || mg>=InpMagicBase+NSYM*NSTR) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL), op=PositionGetDouble(POSITION_PRICE_OPEN), v=PositionGetDouble(POSITION_VOLUME);
      if(sl<=0) continue;
      double dist=MathAbs(op-sl);
      long typ=PositionGetInteger(POSITION_TYPE);
      // se o stop ja esta no lucro, o risco e zero
      if((typ==POSITION_TYPE_BUY && sl>=op) || (typ==POSITION_TYPE_SELL && sl<=op)) continue;
      tot+=dist*MoneyPerPricePerLot(sym)*v;
   }
   return tot;
}
bool MarketOpen(string sym)
{
   MqlTick tk; if(!SymbolInfoTick(sym,tk)) return false;
   if(tk.bid<=0 || tk.ask<=0) return false;
   long mode=SymbolInfoInteger(sym,SYMBOL_TRADE_MODE);
   if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY) return false;
   // sessao: tick recente (ate 2 min)
   return (TimeCurrent()-tk.time) <= 120;
}
//--------------------------------------------------------------------
int OnInit()
{
   g_sym[0]=InpSimbolo1; g_sym[1]=InpSimbolo2; g_sym[2]=InpSimbolo3;
   trade.SetDeviationInPoints(InpDesvioPontos);
   if(InpSoContaDemo && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      Alert("ALIEN_INDICES: conta REAL detectada e 'So conta DEMO' = true. O robo NAO vai operar.");
      return INIT_FAILED;
   }
   if(InpRiscoPorTrade<=0 || InpRiscoTeto<=0){ Alert("ALIEN_INDICES: risco invalido"); return INIT_PARAMETERS_INCORRECT; }
   for(int s=0;s<NSYM;s++)
   {
      g_ok[s]=false; g_lastBar[s]=0; g_msg[s]="aguardando a primeira barra diaria fechada"; g_ind[s]="";
      for(int k=0;k<NSTR;k++){ g_pendEntry[s][k]=false; }
      if(g_sym[s]=="") { g_msg[s]="simbolo desligado"; continue; }
      bool custom=false;
      if(!SymbolExist(g_sym[s],custom)) { Log("Simbolo "+g_sym[s]+" NAO existe nesta corretora. Confira o nome no Observacao do Mercado."); g_msg[s]="simbolo nao existe na corretora"; continue; }
      SymbolSelect(g_sym[s],true);
      g_ok[s]=true;
      double vmin=SymbolInfoDouble(g_sym[s],SYMBOL_VOLUME_MIN);
      Log(StringFormat("%s pronto. Lote minimo %.2f, valor por ponto (1 lote) = %.4f %s.",g_sym[s],vmin,
          MoneyPerPricePerLot(g_sym[s]),AccountInfoString(ACCOUNT_CURRENCY)));
   }
   if(InpLogCSV)
   {
      g_csv=FileOpen("ALIEN_INDICES_log.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,';');
      if(g_csv!=INVALID_HANDLE) FileWrite(g_csv,"hora","evento","simbolo","estrategia","equity","detalhe");
   }
   g_peakEq=AccountInfoDouble(ACCOUNT_EQUITY);
   EventSetTimer(30);
   Log("ALIEN INDICES V1 ligado. Regras: RSI2<"+DoubleToString(InpRSI_Limite,0)+" (stop "+DoubleToString(InpRSI_StopATR,1)+" ATR) e IBS<"+
       DoubleToString(InpIBS_Limite,2)+" (stop "+DoubleToString(InpIBS_StopATR,1)+" ATR), risco "+DoubleToString(InpRiscoPorTrade,2)+"% por trade. Sem martingale, sem grid.");
   Process();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_csv!=INVALID_HANDLE) FileClose(g_csv);
   ObjectsDeleteAll(0,"ALIENIDX_");
   Comment("");
}
void OnTick(){ Process(); }
void OnTimer(){ Process(); }
//--------------------------------------------------------------------
void Guards()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   if(dt.day_of_year!=g_day){ g_day=dt.day_of_year; g_dayStartEq=eq; }
   if(eq>g_peakEq) g_peakEq=eq;
   if(!g_ddPaused && g_peakEq>0 && (1.0-eq/g_peakEq)*100.0>=InpTravaDDPico)
   {
      g_ddPaused=true;
      Log(StringFormat("TRAVA DE DD: conta caiu %.1f%% do pico (%.2f -> %.2f). Novas entradas PAUSADAS. Revise antes de religar o robo.",(1.0-eq/g_peakEq)*100.0,g_peakEq,eq));
      Csv("TRAVA_DD","","",DoubleToString((1.0-eq/g_peakEq)*100.0,2));
   }
}
bool DailyLossHit()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   return (g_dayStartEq>0 && (1.0-eq/g_dayStartEq)*100.0>=InpPerdaDiariaMax);
}
//--------------------------------------------------------------------
void Process()
{
   Guards();
   for(int s=0;s<NSYM;s++)
   {
      if(!g_ok[s]) continue;
      datetime b0=iTime(g_sym[s],PERIOD_D1,0);
      if(b0==0) continue;
      if(b0!=g_lastBar[s])
      {
         bool firstRun=(g_lastBar[s]==0);
         g_lastBar[s]=b0;
         NewBar(s, firstRun);
      }
      for(int k=0;k<NSTR;k++) if(g_pendEntry[s][k]) TryEnter(s,k);
   }
   if(InpPainel) Panel();
}
//--------------------------------------------------------------------
// Chamado na abertura de cada barra D1 do simbolo s: decide com a barra que acabou de fechar.
void NewBar(int s,bool firstRun)
{
   string sym=g_sym[s];
   Sig g;
   if(!CalcSig(sym,g)){ g_msg[s]="historico D1 insuficiente (precisa de 205 barras)"; return; }
   g_ind[s]=StringFormat("Fech %.1f | RSI2 %.1f | IBS %.2f | MM200 %.1f (%s) | ATR20 %.1f",
            g.close,g.rsi2,g.ibs,g.sma200,g.close>g.sma200?"acima":"abaixo",g.atr20);
   string out="";
   for(int k=0;k<NSTR;k++)
   {
      if(k==0 && !InpUsarRSI2) continue;
      if(k==1 && !InpUsarIBS) continue;
      g_pendEntry[s][k]=false;   // sinal antigo expira na barra nova
      bool closedNow=false;
      ulong tk;
      if(FindPos(s,k,tk))
      {
         // ---- regras de SAIDA (decididas no fechamento, executadas agora na abertura) ----
         long typ=PositionGetInteger(POSITION_TYPE);
         datetime et=(datetime)PositionGetInteger(POSITION_TIME);
         int held=iBarShift(sym,PERIOD_D1,et,false);   // barras D1 desde a barra de entrada ate a fechada (m-j+1)
         int maxb=(k==0?InpRSI_MaxBarras:InpIBS_MaxBarras);
         string why="";
         if(k==0)
         {
            if(typ==POSITION_TYPE_BUY && g.close>g.sma5)  why=StringFormat("fechamento %.1f acima da MM5 %.1f (alvo da reversao atingido)",g.close,g.sma5);
            if(typ==POSITION_TYPE_SELL && g.close<g.sma5) why=StringFormat("fechamento %.1f abaixo da MM5 %.1f (alvo da reversao atingido)",g.close,g.sma5);
         }
         else
         {
            if(g.close>g.prevHigh) why=StringFormat("fechamento %.1f acima da maxima anterior %.1f (alvo do IBS atingido)",g.close,g.prevHigh);
         }
         if(why=="" && held>=maxb) why=StringFormat("tempo maximo: %d barras D1 (regra da pesquisa)",held);
         if(why!="")
         {
            double pr=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
            trade.SetExpertMagicNumber(MagicOf(s,k));
            if(trade.PositionClose(tk))
            {
               string m=StringFormat("Fechei %s %s (%s) porque %s. Resultado aprox. %.2f %s.",
                        typ==POSITION_TYPE_BUY?"compra":"venda",Nice(sym),StrName(k),why,pr,AccountInfoString(ACCOUNT_CURRENCY));
               Log(m); Csv("SAIDA",sym,StrName(k),m); out+=m+" ";
               closedNow=true;
            }
            else Log("ERRO ao fechar "+sym+" "+StrName(k)+": "+trade.ResultRetcodeDescription()+" (vou tentar de novo no proximo tick)");
            if(!closedNow){ g_lastBar[s]=0; }   // forca nova tentativa
         }
         else
         {
            string m=StringFormat("Mantendo %s %s (%s): %d de %d barras, sem sinal de saida ainda.",
                     typ==POSITION_TYPE_BUY?"compra":"venda",Nice(sym),StrName(k),held,maxb);
            out+=m+" ";
         }
         continue;   // pesquisa: com posicao aberta (ou saindo agora) o fluxo nao entra de novo nesta barra
      }
      if(firstRun) { out+=StrName(k)+": robo acabou de ligar, espera a proxima barra diaria para nao entrar atrasado. "; continue; }
      // ---- regras de ENTRADA ----
      int dir=0; string why="";
      if(k==0)
      {
         if(g.close>g.sma200 && g.rsi2<InpRSI_Limite){ dir=1; why=StringFormat("RSI2=%.1f (<%.0f, queda exagerada) e preco acima da MM200 (tendencia de alta)",g.rsi2,InpRSI_Limite); }
         else if(g.close<g.sma200 && g.rsi2>100.0-InpRSI_Limite){ dir=-1; why=StringFormat("RSI2=%.1f (>%.0f, alta exagerada) e preco abaixo da MM200 (tendencia de baixa)",g.rsi2,100.0-InpRSI_Limite); }
         else why=StringFormat("RSI2=%.1f, precisa <%.0f com preco acima da MM200 ou >%.0f abaixo dela",g.rsi2,InpRSI_Limite,100.0-InpRSI_Limite);
      }
      else
      {
         if(g.ibs>=0 && g.ibs<InpIBS_Limite && g.close>g.sma200){ dir=1; why=StringFormat("IBS=%.2f (fechou perto da minima do dia) e preco acima da MM200",g.ibs); }
         else why=StringFormat("IBS=%.2f, precisa <%.2f com preco acima da MM200 (%s)",g.ibs,InpIBS_Limite,g.close>g.sma200?"esta acima":"esta abaixo");
      }
      if(dir==0){ out+="Sem entrada "+StrName(k)+": "+why+". "; continue; }
      double stopk=(k==0?InpRSI_StopATR:InpIBS_StopATR);
      g_pendEntry[s][k]=true; g_pendDir[s][k]=dir; g_pendDist[s][k]=stopk*g.atr20; g_pendBar[s][k]=g_lastBar[s];
      g_pendWhy[s][k]=why+StringFormat(", stop %.1f x ATR20 = %.1f pontos",stopk,stopk*g.atr20);
      out+="Sinal "+StrName(k)+": "+why+". ";
   }
   g_msg[s]=out;
   Csv("BARRA",sym,"",g_ind[s]+" || "+out);
}
//--------------------------------------------------------------------
void TryEnter(int s,int k)
{
   string sym=g_sym[s];
   if(g_pendBar[s][k]!=iTime(sym,PERIOD_D1,0)){ g_pendEntry[s][k]=false; return; }
   ulong tk; if(FindPos(s,k,tk)){ g_pendEntry[s][k]=false; return; }
   int dir=g_pendDir[s][k]; double dist=g_pendDist[s][k];
   string tag=Nice(sym)+" "+StrName(k);
   if(!MarketOpen(sym)) return;   // espera o mercado abrir
   if(g_ddPaused){ Skip(s,k,"Sem entrada "+tag+": trava de drawdown ligada ("+DoubleToString(InpTravaDDPico,0)+"% do pico)."); return; }
   if(DailyLossHit()){ Skip(s,k,"Sem entrada "+tag+": perda do dia passou de "+DoubleToString(InpPerdaDiariaMax,1)+"%."); return; }
   MqlTick t; SymbolInfoTick(sym,t);
   double spread=t.ask-t.bid;
   if(spread>InpSpreadMaxFracStop*dist) return;   // espera o spread normalizar (abertura costuma ser larga)
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double mpp=MoneyPerPricePerLot(sym);
   if(mpp<=0){ Skip(s,k,"Sem entrada "+tag+": nao consegui o valor do ponto."); return; }
   double riskPct=MathMin(InpRiscoPorTrade,InpRiscoTeto);
   double vmin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), vstep=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP), vmax=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double lots=MathFloor((eq*riskPct/100.0)/(dist*mpp)/vstep)*vstep;
   lots=MathMin(lots,vmax);
   if(lots<vmin-1e-9)
   {
      double rmin=vmin*dist*mpp/eq*100.0;
      Skip(s,k,StringFormat("Sem entrada %s: o lote minimo (%.2f) arriscaria %.2f%% da conta, acima dos %.2f%% permitidos. Nunca arredondo pra cima.",tag,vmin,rmin,riskPct));
      return;
   }
   double riskMoney=lots*dist*mpp;
   double openRisk=OpenRiskMoney();
   if((openRisk+riskMoney)/eq*100.0>InpRiscoAbertoMax+1e-9)
   {
      Skip(s,k,StringFormat("Sem entrada %s: risco aberto ficaria %.2f%% (> limite %.1f%%).",tag,(openRisk+riskMoney)/eq*100.0,InpRiscoAbertoMax));
      return;
   }
   int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   trade.SetExpertMagicNumber(MagicOf(s,k));
   bool ok;
   string cmt="ALIEN_IDX "+StrName(k);
   if(dir==1){ double sl=NormalizeDouble(t.ask-dist,dg); ok=trade.Buy(lots,sym,0,sl,0,cmt); }
   else      { double sl=NormalizeDouble(t.bid+dist,dg); ok=trade.Sell(lots,sym,0,sl,0,cmt); }
   if(ok && (trade.ResultRetcode()==TRADE_RETCODE_DONE || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      double fp=trade.ResultPrice();
      // stop exato a partir do preco executado (como na pesquisa: st = fill - dir*dist)
      ulong t2; if(FindPos(s,k,t2))
      {
         double sl2=NormalizeDouble(fp-dir*dist,dg);
         if(MathAbs(PositionGetDouble(POSITION_SL)-sl2)>=SymbolInfoDouble(sym,SYMBOL_POINT)) trade.PositionModify(t2,sl2,0);
      }
      string m=StringFormat("%s %s %.2f lote(s) a %.1f porque %s. Risco %.2f %s (%.2f%% da conta). Saida: %s.",
               dir==1?"Comprei":"Vendi",Nice(sym),lots,fp,g_pendWhy[s][k],riskMoney,AccountInfoString(ACCOUNT_CURRENCY),riskMoney/eq*100.0,
               k==0?(dir==1?"fechar acima da MM5 ou 10 barras":"fechar abaixo da MM5 ou 10 barras"):"fechar acima da maxima anterior ou 5 barras");
      Log(m); Csv("ENTRADA",sym,StrName(k),StringFormat("pos=%I64d;risk=%.2f;dist=%.5f;dir=%d;",trade.ResultOrder(),riskMoney,dist,dir)+m);
      g_msg[s]=m;
      g_pendEntry[s][k]=false;
   }
   else
   {
      Log("Ordem recusada em "+tag+": "+trade.ResultRetcodeDescription()+". Tento de novo no proximo tick.");
   }
}
void Skip(int s,int k,string m)
{
   Log(m); Csv("PULOU",g_sym[s],StrName(k),m);
   g_msg[s]=m; g_pendEntry[s][k]=false;
}
//--------------------------------------------------------------------
// Registra toda saida (inclusive STOP feito pela corretora) com resultado liquido.
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(tr.deal)) return;
   long mg=HistoryDealGetInteger(tr.deal,DEAL_MAGIC);
   if(mg<InpMagicBase || mg>=InpMagicBase+NSYM*NSTR) return;
   long en=HistoryDealGetInteger(tr.deal,DEAL_ENTRY);
   if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_OUT_BY) return;
   string sym=HistoryDealGetString(tr.deal,DEAL_SYMBOL);
   int k=(int)((mg-InpMagicBase)%NSTR);
   long rsn=HistoryDealGetInteger(tr.deal,DEAL_REASON);
   double net=HistoryDealGetDouble(tr.deal,DEAL_PROFIT)+HistoryDealGetDouble(tr.deal,DEAL_SWAP)+HistoryDealGetDouble(tr.deal,DEAL_COMMISSION);
   // swap/comissao acumulados ficam no deal de saida no MT5; soma tambem a comissao da entrada
   long pid=HistoryDealGetInteger(tr.deal,DEAL_POSITION_ID);
   double swp=HistoryDealGetDouble(tr.deal,DEAL_SWAP);
   if(HistorySelectByPosition(pid))
      for(int i=0;i<HistoryDealsTotal();i++){ ulong d=HistoryDealGetTicket(i); if(d!=tr.deal) net+=HistoryDealGetDouble(d,DEAL_COMMISSION); }
   string why = (rsn==DEAL_REASON_SL) ? "STOP atingido (a reversao nao veio; perda limitada ao risco planejado)" :
                (rsn==DEAL_REASON_SO) ? "STOP OUT da corretora" : "saida pela regra";
   string m=StringFormat("Resultado %s %s: %+.2f %s liquido (swap %.2f). Motivo: %s.",Nice(sym),StrName(k),net,AccountInfoString(ACCOUNT_CURRENCY),swp,why);
   if(rsn==DEAL_REASON_SL || rsn==DEAL_REASON_SO) Log(m);
   Csv(rsn==DEAL_REASON_SL?"FECHOU_STOP":"FECHOU",sym,StrName(k),StringFormat("pos=%I64d;net=%.2f;swap=%.2f;",pid,net,swp)+m);
   for(int s=0;s<NSYM;s++) if(g_sym[s]==sym && rsn==DEAL_REASON_SL) g_msg[s]=m;
}
//--------------------------------------------------------------------
// PAINEL estilo ALIEN: fundo preto, titulos amarelos, texto branco.
void Lbl(string name,int x,int y,string txt,color c,int sz=9,string font="Consolas")
{
   string n="ALIENIDX_"+name;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetString(0,n,OBJPROP_FONT,font); ObjectSetString(0,n,OBJPROP_TEXT,txt);
}
void Panel()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   static datetime last=0; if(TimeCurrent()-last<2) return; last=TimeCurrent();
   string bg="ALIENIDX_bg";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,8); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,18);
      ObjectSetInteger(0,bg,OBJPROP_XSIZE,900); ObjectSetInteger(0,bg,OBJPROP_YSIZE,330);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrBlack); ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_COLOR,clrGold); ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY), bal=AccountInfoDouble(ACCOUNT_BALANCE);
   int y=24;
   Lbl("t",16,y,"ALIEN INDICES V1  |  Reversao a media diaria (RSI2 + IBS)  |  sem martingale, sem grid",clrGold,10,"Arial Black"); y+=22;
   string st=StringFormat("Saldo %.2f  Equity %.2f  Risco aberto %.2f%% (max %.1f%%)  Risco/trade %.2f%%",bal,eq,OpenRiskMoney()/MathMax(eq,1e-9)*100.0,InpRiscoAbertoMax,MathMin(InpRiscoPorTrade,InpRiscoTeto));
   Lbl("s",16,y,st,clrWhite); y+=16;
   string gd = g_ddPaused ? "TRAVA DE DD LIGADA: novas entradas pausadas" : (DailyLossHit() ? "Perda do dia no limite: sem novas entradas hoje" : "Protecoes OK (perda diaria e DD do pico dentro do limite)");
   Lbl("g",16,y,gd,g_ddPaused||DailyLossHit()?clrOrangeRed:clrGold); y+=22;
   for(int s=0;s<NSYM;s++)
   {
      Lbl("n"+IntegerToString(s),16,y,(g_sym[s]==""?"(desligado)":Nice(g_sym[s]))+"   "+g_ind[s],clrGold,9); y+=15;
      string m=g_msg[s];
      // quebra em linhas de ~120 caracteres
      for(int ln=0;ln<4;ln++)
      {
         string part = StringLen(m)>0 ? StringSubstr(m,0,125) : "";
         Lbl("m"+IntegerToString(s)+"_"+IntegerToString(ln),26,y,part,clrWhite,8);
         m = StringLen(m)>125 ? StringSubstr(m,125) : "";
         y+=13;
      }
      y+=8;
   }
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
