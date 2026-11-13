//+------------------------------------------------------------------+
//| ALIEN GOAT5K H1M15 A/B TESTER V0.110                              |
//| Research execution benchmark; NOT a validated trading system.     |
//| Orders are IMPOSSIBLE outside MT5 Strategy Tester.                |
//+------------------------------------------------------------------+
#property strict
#property version "0.110"
#property description "ALIEN GOAT5K: A/B H1 SMA20 and M15 range location, Strategy Tester only"
#include <Trade/Trade.mqh>
CTrade trade;

input group "=== EXECUCAO APENAS NO STRATEGY TESTER ==="
input bool   EnableTesterOrders=true;
input double InitialDepositUsd=5000.0;
input double RiskLimitPct=0.25;
input double RiskMaxUsd=12.50;
input double FloatingSafetyUsd=35.0;
input double DailyLossGuardPct=1.0;
input double TotalLossGuardPct=8.0;
input double MaxLot=0.02;
input int    MaxDayTrades=6;

input group "=== BENCHMARK M1 PARA GERAR EXECUCOES ==="
input double MinBodyFraction=0.35;
input double BreakBufferPoints=2.0;
input int    StopLookbackBars=3;
input double StopBufferPoints=8.0;
input double MinStopPoints=35.0;
input double MaxStopPoints=180.0;
input double RewardRisk=2.0;
input double SpreadLimitPoints=45.0;
input int    CooldownMinutes=30;
input int    ExitAfterMinutes=90;
input int    StartServerHour=7;
input int    EndServerHour=20;

input group "=== HIPOTESE A/B CONTEXTO H1/M15 ==="
input bool   RequireH1M15Context=false; // A=false benchmark; B=true contexto
input int    H1TrendLookback=20;        // SMA20 e inclinacao H1
input int    M15EquilibriumBars=12;     // meio do range M15 fechado

input group "=== RELATORIO E CUSTOS ESTIMADOS ==="
input double AssumedCommissionPerLot=5.0;
input double SlipReservePoints=10.0;
input string CSVFileName="ALIEN_GOAT5K_EXECUTION.csv";
input ulong  TestMagic=26111377;

int g_file=INVALID_HANDLE;
datetime g_lastBar=0;
datetime g_lastTrade=0;
int g_dayKey=-1;
int g_dayTrades=0;
double g_dayReference=0.0;
bool g_locked=false;
int g_signals=0,g_attempts=0,g_entries=0,g_dealsOut=0,g_vetoes=0;

void LogRow(string action,string reason,int dir=0,
            double bid=0,double ask=0,double entry=0,
            double sl=0,double tp=0,double volume=0,
            double risk=0,long deal=0,double pnl=0)
{
   StringReplace(reason,";"," ");
   Print("[ALIEN GOAT5K TESTER] ",action," ",reason);
   if(g_file==INVALID_HANDLE) return;
   FileWrite(g_file,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      _Symbol,action,reason,(dir>0?"BUY":(dir<0?"SELL":"-")),
      DoubleToString(bid,_Digits),DoubleToString(ask,_Digits),
      (bid>0 && ask>bid?DoubleToString((ask-bid)/_Point,2):""),
      DoubleToString(entry,_Digits),DoubleToString(sl,_Digits),
      DoubleToString(tp,_Digits),DoubleToString(volume,2),
      DoubleToString(risk,2),StringFormat("%I64d",deal),
      DoubleToString(pnl,2),
      DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),
      DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
      IntegerToString(g_dayTrades));
   FileFlush(g_file);
}

double NegativeFloating()
{
   double loss=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      double net=PositionGetDouble(POSITION_PROFIT)+
                 PositionGetDouble(POSITION_SWAP);
      if(net<0) loss-=net;
   }
   return loss;
}

void CloseOwn(string why)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=TestMagic) continue;
      bool ok=trade.PositionClose(t);
      LogRow(ok?"CLOSE_REQUEST":"CLOSE_FAILED",
             why+" retcode="+IntegerToString((int)trade.ResultRetcode()));
   }
}

void RiskProtection()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   int key=d.year*1000+d.day_of_year;
   if(key!=g_dayKey)
   {
      g_dayKey=key;
      g_dayTrades=0;
      g_dayReference=MathMax(AccountInfoDouble(ACCOUNT_BALANCE),
                              AccountInfoDouble(ACCOUNT_EQUITY));
      LogRow("DAY_RESET","server calendar day, not Goat 5pm EST reset");
   }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyFloor=g_dayReference*(1.0-DailyLossGuardPct/100.0);
   double totalFloor=InitialDepositUsd*(1.0-TotalLossGuardPct/100.0);
   if(eq<=dailyFloor || balance<=dailyFloor ||
      eq<=totalFloor || balance<=totalFloor ||
      NegativeFloating()>=FloatingSafetyUsd)
   {
      if(!g_locked)
         LogRow("RISK_LOCK","floating, daily or total preventive stop");
      g_locked=true;
      CloseOwn("TESTER risk lock");
   }
}

bool SessionOK()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   return d.day_of_week>=1 && d.day_of_week<=5 &&
          d.hour>=StartServerHour && d.hour<EndServerHour;
}

void ExitByTime()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=TestMagic) continue;
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if(TimeCurrent()-opened>=ExitAfterMinutes*60 ||
         !SessionOK())
      {
         bool ok=trade.PositionClose(t);
         LogRow(ok?"TIME_EXIT_REQUEST":"TIME_EXIT_FAILED",
                StringFormat("ticket=%I64u retcode=%u",t,trade.ResultRetcode()));
      }
   }
}

bool SizeAtRisk(int direction,double entry,double stop,
                double &lot,double &riskMoney)
{
   lot=0;riskMoney=0;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minLot<=0 || maxLot<minLot || step<=0) return false;

   ENUM_ORDER_TYPE kind=(direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double inWorst=entry+(direction==1?1.0:-1.0)*SlipReservePoints*_Point;
   double outWorst=stop+(direction==1?-1.0:1.0)*SlipReservePoints*_Point;
   double oneLotPnL=0.0;
   if(!OrderCalcProfit(kind,_Symbol,1.0,inWorst,outWorst,oneLotPnL) ||
      oneLotPnL>=0) return false;
   double oneLotRisk=MathAbs(oneLotPnL)+AssumedCommissionPerLot;
   double budget=MathMin(RiskMaxUsd,AccountInfoDouble(ACCOUNT_EQUITY)*
                        RiskLimitPct/100.0);
   budget=MathMin(budget,FloatingSafetyUsd-NegativeFloating()-5.0);
   if(budget<=0 || oneLotRisk<=0) return false;
   double raw=MathMin(MathMin(maxLot,MaxLot),budget/oneLotRisk);
   double vol=NormalizeDouble(MathFloor(raw/step+1e-9)*step,8);
   if(vol+1e-9<minLot) return false;
   double finalPnL=0.0;
   if(!OrderCalcProfit(kind,_Symbol,vol,inWorst,outWorst,finalPnL))
      return false;
   double total=MathAbs(finalPnL)+AssumedCommissionPerLot*vol;
   if(total>budget+0.000001) return false;
   double margin=0.0;
   if(!OrderCalcMargin(kind,_Symbol,vol,entry,margin) ||
      margin>=AccountInfoDouble(ACCOUNT_MARGIN_FREE) ||
      margin>AccountInfoDouble(ACCOUNT_EQUITY)*0.20) return false;
   lot=vol;
   riskMoney=total;
   return true;
}

// H1+M15: teste de regime OBJETIVO (nao SMC/ICT ou BOS comprovado).
// Usa somente barras FECHADAS (CopyRates com shift 1). 
// H1: close versus SMA20, e inclinação da SMA20 (1 barra H1).
// M15: close versus meio do range de 12 barras M15 fechadas.
// Para a mesma entrada, todos os demais limites continuam idênticos.
bool ContextAllowedH1M15(int direction,string &reason)
{
   reason="";
   if(!RequireH1M15Context) return true;

   MqlRates h1[];
   ArraySetAsSeries(h1,true);
   int h1Required=H1TrendLookback+1;
   if(CopyRates(_Symbol,PERIOD_H1,1,h1Required,h1)!=h1Required)
   {
      reason="H1 sem barras fechadas suficientes";
      return false;
   }
   double h1Now=0.0;
   double h1Prev=0.0;
   for(int i=0;i<H1TrendLookback;i++)
      h1Now+=h1[i].close;
   for(int i=1;i<=H1TrendLookback;i++)
      h1Prev+=h1[i].close;
   h1Now/=(double)H1TrendLookback;
   h1Prev/=(double)H1TrendLookback;

   bool h1Allowed=(direction==1?
      (h1[0].close>h1Now && h1Now>h1Prev):
      (h1[0].close<h1Now && h1Now<h1Prev));
   if(!h1Allowed)
   {
      reason=StringFormat("H1 D=%d close=%.2f SMA=%.2f SMAprev=%.2f",
           direction,h1[0].close,h1Now,h1Prev);
      return false;
   }

   MqlRates m15[];
   ArraySetAsSeries(m15,true);
   if(CopyRates(_Symbol,PERIOD_M15,1,M15EquilibriumBars,m15)!=M15EquilibriumBars)
   {
      reason="M15 sem barras fechadas suficientes";
      return false;
   }
   double hi=m15[0].high,lo=m15[0].low;
   for(int j=1;j<M15EquilibriumBars;j++)
   {
      hi=MathMax(hi,m15[j].high);
      lo=MathMin(lo,m15[j].low);
   }
   double middle=(hi+lo)/2.0;
   bool m15Allowed=(direction==1?m15[0].close>middle:m15[0].close<middle);
   if(!m15Allowed)
   {
      reason=StringFormat("M15 D=%d close=%.2f EQ=%.2f high=%.2f low=%.2f",
           direction,m15[0].close,middle,hi,lo);
      return false;
   }
   reason=StringFormat("H1/M15 OK D=%d H1=%.2f SMA20=%.2f M15=%.2f EQ=%.2f",
          direction,h1[0].close,h1Now,m15[0].close,middle);
   return true;
}

void TestSignal()
{
   if(g_locked || !SessionOK() || PositionsTotal()>0 ||
      g_dayTrades>=MaxDayTrades) return;
   if(g_lastTrade>0 &&
      TimeCurrent()-g_lastTrade<CooldownMinutes*60) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=q.bid) return;
   double spread=(q.ask-q.bid)/_Point;
   if(spread>SpreadLimitPoints)
   {g_vetoes++;LogRow("VETO_SPREAD","spread alto",0,q.bid,q.ask);return;}

   MqlRates b[];
   ArraySetAsSeries(b,true);
   if(CopyRates(_Symbol,PERIOD_M1,1,StopLookbackBars,b)!=StopLookbackBars)
      return;
   if(b[0].time+PeriodSeconds(PERIOD_M1)>TimeCurrent()) return;
   double range=b[0].high-b[0].low;
   if(range<=0 || MathAbs(b[0].close-b[0].open)/range<MinBodyFraction)
      return;
   int dir=0;
   if(b[0].close>b[1].high+BreakBufferPoints*_Point &&
      b[0].close>b[0].open) dir=1;
   else if(b[0].close<b[1].low-BreakBufferPoints*_Point &&
           b[0].close<b[0].open) dir=-1;
   if(dir==0) return;
   g_signals++;
   string contextReason="";
   if(!ContextAllowedH1M15(dir,contextReason))
   {
      g_vetoes++;
      LogRow("VETO_CONTEXTO",contextReason,dir,q.bid,q.ask);
      return;
   }
   if(RequireH1M15Context)
      LogRow("CONTEXTO_APROVADO",contextReason,dir,q.bid,q.ask);
   double lo=b[0].low,hi=b[0].high;
   for(int j=1;j<StopLookbackBars;j++)
   {
      lo=MathMin(lo,b[j].low);
      hi=MathMax(hi,b[j].high);
   }
   double entry=(dir==1?q.ask:q.bid);
   double sl=NormalizeDouble((dir==1?lo-StopBufferPoints*_Point:
                                 hi+StopBufferPoints*_Point),_Digits);
   double stopPts=MathAbs(entry-sl)/_Point;
   if((dir==1 && sl>=entry)||(dir==-1 && sl<=entry) ||
      stopPts<MinStopPoints || stopPts>MaxStopPoints)
   {
      g_vetoes++;
      LogRow("VETO_STOP","stop nao cabe 35-180 pts",dir,q.bid,q.ask,entry,sl);
      return;
   }
   double tp=NormalizeDouble((dir==1?entry+RewardRisk*stopPts*_Point:
                                 entry-RewardRisk*stopPts*_Point),_Digits);
   double brokerMin=(double)MathMax(
      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2.0;
   if(dir==1 && ((q.bid-sl)/_Point<brokerMin ||
                 (tp-q.bid)/_Point<brokerMin)) return;
   if(dir==-1 && ((sl-q.ask)/_Point<brokerMin ||
                  (q.ask-tp)/_Point<brokerMin)) return;
   double vol=0,risk=0;
   if(!SizeAtRisk(dir,entry,sl,vol,risk))
   {
      g_vetoes++;
      LogRow("VETO_LOTE","sem lote seguro",dir,q.bid,q.ask,entry,sl,tp);
      return;
   }
   g_attempts++;
   LogRow("ORDER_ATTEMPT","M1 breakout benchmark, not proven edge",
          dir,q.bid,q.ask,entry,sl,tp,vol,risk);
   bool ok=(dir==1?trade.Buy(vol,_Symbol,0.0,sl,tp,"ALIEN_TESTER"):
                    trade.Sell(vol,_Symbol,0.0,sl,tp,"ALIEN_TESTER"));
   uint ret=trade.ResultRetcode();
   bool filled=ok && (ret==TRADE_RETCODE_DONE ||
                      ret==TRADE_RETCODE_DONE_PARTIAL) &&
               trade.ResultDeal()>0;
   if(filled)
   {
      g_entries++;
      g_dayTrades++;
      g_lastTrade=TimeCurrent();
      LogRow("ORDER_FILLED",StringFormat("deal=%I64u ret=%u",
             trade.ResultDeal(),ret),
             dir,q.bid,q.ask,entry,sl,tp,vol,risk,(long)trade.ResultDeal());
   }
   else
   {
      g_vetoes++;
      LogRow("ORDER_REJECTED",
          StringFormat("retcode=%u lastError=%d",ret,GetLastError()),
          dir,q.bid,q.ask,entry,sl,tp,vol,risk);
   }
}

int OnInit()
{
   string symbol=_Symbol;
   StringToUpper(symbol);
   if(MQLInfoInteger(MQL_TESTER)==0 || !EnableTesterOrders ||
      StringFind(symbol,"XAU")<0 || _Period!=PERIOD_M1 ||
      MathAbs(InitialDepositUsd-5000.0)>0.01 ||
      MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-5000.0)>0.01 ||
      RiskLimitPct<=0 || RiskLimitPct>0.25 ||
      RiskMaxUsd<=0 || RiskMaxUsd>12.50 ||
      FloatingSafetyUsd<=0 || FloatingSafetyUsd>40.0 ||
      DailyLossGuardPct<=0 || DailyLossGuardPct>1.0 ||
      TotalLossGuardPct<=0 || TotalLossGuardPct>8.0 ||
      MaxLot<0.01 || MaxLot>0.02 ||
      MaxDayTrades<1 || MaxDayTrades>6 ||
      StopLookbackBars<3 || StopLookbackBars>8 ||
      H1TrendLookback!=20 || M15EquilibriumBars!=12 ||
      MinStopPoints<35 || MaxStopPoints>180 ||
      MinStopPoints>MaxStopPoints ||
      SpreadLimitPoints<=0 || SpreadLimitPoints>45 ||
      RewardRisk<1.0 || RewardRisk>2.0 ||
      StartServerHour<0 || EndServerHour>24 ||
      StartServerHour>=EndServerHour ||
      CooldownMinutes<1 || ExitAfterMinutes<10 ||
      StringFind(CSVFileName,"|")>=0 ||
      StringFind(CSVFileName,"/")>=0 ||
      StringFind(CSVFileName,"\\")>=0)
   {
      Print("ALIEN: BLOQUEADO. Somente Tester XAUUSD M1, deposit 5000,"
            " max 0.25% e configuracao de pesquisa segura.");
      return INIT_PARAMETERS_INCORRECT;
   }
   trade.SetExpertMagicNumber(TestMagic);
   trade.SetDeviationInPoints(15);
   trade.SetAsyncMode(false);
   if(!trade.SetTypeFillingBySymbol(_Symbol)) return INIT_FAILED;
   g_file=FileOpen(CSVFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                    FILE_ANSI|FILE_SHARE_READ,';');
   if(g_file==INVALID_HANDLE)
   {
      Print("ALIEN: nao abriu CSV erro ",GetLastError());
      return INIT_FAILED;
   }
   if(FileSize(g_file)==0)
      FileWrite(g_file,"timestamp","symbol","event","reason","side",
        "bid","ask","spread_points","entry","sl","tp","volume",
        "estimated_risk_usd","deal","realized_net_usd",
        "balance_usd","equity_usd","day_trades");
   FileSeek(g_file,0,SEEK_END);
   g_lastBar=iTime(_Symbol,PERIOD_M1,0);
   RiskProtection();
   LogRow("START",StringFormat("EXECUTION BENCHMARK TESTER ONLY H1M15=%s H1period=%d M15bars=%d",
          (RequireH1M15Context?"ON":"OFF"),H1TrendLookback,M15EquilibriumBars));
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(MQLInfoInteger(MQL_TESTER)==0) return;
   RiskProtection();
   if(g_locked) return;
   ExitByTime();
   datetime curr=iTime(_Symbol,PERIOD_M1,0);
   if(curr>0 && g_lastBar>0 && curr!=g_lastBar)
   {
      g_lastBar=curr;
      TestSignal();
   }
   else if(g_lastBar==0 && curr>0) g_lastBar=curr;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0 ||
      !HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol ||
      (ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=TestMagic)
      return;
   ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   double net=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
              HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+
              HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
              HistoryDealGetDouble(trans.deal,DEAL_FEE);
   if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT)
      g_dealsOut++;
   LogRow((e==DEAL_ENTRY_IN?"DEAL_IN":"DEAL_OUT"),
      StringFormat("ticket=%I64u",trans.deal),0,0,0,
      HistoryDealGetDouble(trans.deal,DEAL_PRICE),
      0,0,HistoryDealGetDouble(trans.deal,DEAL_VOLUME),
      0,(long)trans.deal,net);
}

void OnDeinit(const int reason)
{
   LogRow("END",StringFormat("signals=%d attempts=%d entries=%d outDeals=%d vetoes=%d",
        g_signals,g_attempts,g_entries,g_dealsOut,g_vetoes));
   if(g_file!=INVALID_HANDLE)
   {FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;}
}
//+------------------------------------------------------------------+
