//+------------------------------------------------------------------+
//| ALIEN GOAT5K TURBO DISCOVERY TESTER V0.120                              |
//| Research execution benchmark; NOT a validated trading system.     |
//| Orders are IMPOSSIBLE outside MT5 Strategy Tester.                |
//+------------------------------------------------------------------+
#property strict
#property version "0.120"
#property description "ALIEN GOAT5K: multiple tester-only experiments + unconditional signal tape"
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
input int    MaxOpenPositions=1;  // 1 controle; ate 5 em laboratorio tester-only

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

input group "=== TURBO: INVESTIGAR TODAS AS OPORTUNIDADES ==="
input bool   EnableSignalTape=true;
input bool   EnableM1ShadowOutcomes=true;
input double ShadowReferenceLot=0.01;
input string TapeCSVFileName="ALIEN_TURBO_CANDIDATES.csv";
input string OutcomeCSVFileName="ALIEN_TURBO_OUTCOMES.csv";

input group "=== RELATORIO E CUSTOS ESTIMADOS ==="
input double AssumedCommissionPerLot=5.0;
input double SlipReservePoints=10.0;
input string CSVFileName="ALIEN_GOAT5K_EXECUTION.csv";
input ulong  TestMagic=26111377;

int g_file=INVALID_HANDLE;
int g_tape=INVALID_HANDLE;
int g_outcomes=INVALID_HANDLE;
int g_tapeCandidates=0;
int g_shadowOpens=0;
int g_shadowResolved=0;
int g_shadowAmbiguous=0;
int g_shadowNoSlot=0;

struct ShadowOpportunity
{
 bool active;
 string id;
 datetime entryTime;
 datetime signalBarTime;
 int direction;
 double entry;
 double stop;
 double target;
 double spreadPoints;
 bool contextOk;
 bool stopOk;
 bool spreadOk;
};
ShadowOpportunity g_opportunities[512];
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


double ActiveWorstStopExposureUsd()
{
 double total=0.0;
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
   ulong ticket=PositionGetTicket(i);
   if(ticket==0 || !PositionSelectByTicket(ticket))continue;
   string symbol=PositionGetString(POSITION_SYMBOL);
   double stop=PositionGetDouble(POSITION_SL);
   if(stop<=0.0)return 1e9; // sem SL -> falha fechada
   long type=PositionGetInteger(POSITION_TYPE);
   ENUM_ORDER_TYPE kind=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double lot=PositionGetDouble(POSITION_VOLUME);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point<=0)return 1e9;
   double slWorst=stop+(type==POSITION_TYPE_BUY?-1.0:1.0)*
                        SlipReservePoints*point;
   double pnl=0.0;
   if(!OrderCalcProfit(kind,symbol,lot,entry,slWorst,pnl))
      return 1e9;
   total+=MathMax(0.0,-pnl)+lot*AssumedCommissionPerLot;
 }
 return total;
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
      NegativeFloating()>=FloatingSafetyUsd ||
      ActiveWorstStopExposureUsd()>=FloatingSafetyUsd)
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
   budget=MathMin(budget,FloatingSafetyUsd-
        MathMax(NegativeFloating(),ActiveWorstStopExposureUsd())-5.0);
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
// H1 e M15 sempre analisados mesmo quando filtro desligado,
// para evitar vies de selecao: a fita contem todas as confluencias.
// Apenas candles FECHADOS (shift 1) sao consultados.
bool ReadH1M15(int direction,string &reason,
               bool &h1Ok,bool &m15Ok,
               double &h1Close,double &h1Sma,double &h1Slope,
               double &m15Close,double &m15Eq)
{
  h1Ok=false; m15Ok=false;
  h1Close=0.0;h1Sma=0.0;h1Slope=0.0;
  m15Close=0.0;m15Eq=0.0;
  reason="";
  MqlRates h[];
  ArraySetAsSeries(h,true);
  int count=H1TrendLookback+1;
  if(CopyRates(_Symbol,PERIOD_H1,1,count,h)!=count)
  { reason="H1_DADOS_INSUFICIENTES";return false; }
  double sum1=0,sum2=0;
  for(int i=0;i<H1TrendLookback;i++)sum1+=h[i].close;
  for(int j=1;j<=H1TrendLookback;j++)sum2+=h[j].close;
  h1Sma=sum1/(double)H1TrendLookback;
  h1Slope=h1Sma-sum2/(double)H1TrendLookback;
  h1Close=h[0].close;
  h1Ok=(direction==1?
    (h1Close>h1Sma && h1Slope>0):
    (h1Close<h1Sma && h1Slope<0));

  MqlRates m[];
  ArraySetAsSeries(m,true);
  if(CopyRates(_Symbol,PERIOD_M15,1,M15EquilibriumBars,m)!=M15EquilibriumBars)
  { reason="M15_DADOS_INSUFICIENTES";return false; }
  double high=m[0].high,low=m[0].low;
  for(int k=1;k<M15EquilibriumBars;k++)
  {
     high=MathMax(high,m[k].high);
     low=MathMin(low,m[k].low);
  }
  m15Eq=(high+low)/2.0;
  m15Close=m[0].close;
  m15Ok=(direction==1?m15Close>m15Eq:m15Close<m15Eq);
  reason=StringFormat("H1=%s M15=%s",
             (h1Ok?"ALINHADO":"CONTRA"),(m15Ok?"ALINHADO":"CONTRA"));
  return h1Ok && m15Ok;
}

// Features nao precisam prever ou executar ordem, somente registrar.
bool M1MarketFeatures(double &atrPoints,double &bbWidthPoints,
                      double &bbPosition)
{
 atrPoints=0;bbWidthPoints=0;bbPosition=0;
 MqlRates rates[];
 ArraySetAsSeries(rates,true);
 if(CopyRates(_Symbol,PERIOD_M1,1,22,rates)!=22)return false;
 double tr=0;
 for(int i=0;i<14;i++)
 {
   double range=rates[i].high-rates[i].low;
   double t1=MathAbs(rates[i].high-rates[i+1].close);
   double t2=MathAbs(rates[i].low-rates[i+1].close);
   tr+=MathMax(range,MathMax(t1,t2));
 }
 atrPoints=tr/14.0/_Point;
 double avg=0,variance=0;
 for(int j=0;j<20;j++)avg+=rates[j].close;
 avg/=20.0;
 for(int k=0;k<20;k++)
    variance+=MathPow(rates[k].close-avg,2);
 double dev=MathSqrt(variance/20.0);
 bbWidthPoints=4.0*dev/_Point;
 if(dev>0)
    bbPosition=(rates[0].close-(avg-2.0*dev))/(4.0*dev);
 return true;
}

void TapeCandidate(string id,datetime signalTime,const MqlTick &q,
                   int dir,double candleBody,double entry,double sl,
                   double tp,double stopPts,bool h1Ok,bool m15Ok,
                   bool contextOk,const string reason,
                   double h1Close,double h1Sma,double h1Slope,
                   double m15Close,double m15Eq,
                   double atrPoints,double bbWidth,double bbPosition,
                   bool priceStopValid)
{
 if(g_tape==INVALID_HANDLE)return;
 bool inSession=SessionOK();
 bool inCooldown=(g_lastTrade>0 &&
                   TimeCurrent()-g_lastTrade<CooldownMinutes*60);
 FileWrite(g_tape,
   id,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
   StringFormat("%I64d",(long)q.time_msc),
   TimeToString(signalTime,TIME_DATE|TIME_SECONDS),
   (dir==1?"BUY":"SELL"),
   DoubleToString(q.bid,_Digits),DoubleToString(q.ask,_Digits),
   DoubleToString((q.ask-q.bid)/_Point,2),
   DoubleToString(candleBody,4),DoubleToString(entry,_Digits),
   DoubleToString(sl,_Digits),DoubleToString(tp,_Digits),
   DoubleToString(stopPts,2),
   (h1Ok?"1":"0"),(m15Ok?"1":"0"),(contextOk?"1":"0"),
   reason,
   DoubleToString(h1Close,_Digits),DoubleToString(h1Sma,_Digits),
   DoubleToString(h1Slope/_Point,4),
   DoubleToString(m15Close,_Digits),DoubleToString(m15Eq,_Digits),
   DoubleToString(atrPoints,2),DoubleToString(bbWidth,2),
   DoubleToString(bbPosition,4),
   (inSession?"1":"0"),(g_locked?"1":"0"),
   IntegerToString(PositionsTotal()),IntegerToString(g_dayTrades),
   (inCooldown?"1":"0"),
   (priceStopValid && stopPts>=MinStopPoints &&
    stopPts<=MaxStopPoints?"1":"0"),
   ((q.ask-q.bid)/_Point<=SpreadLimitPoints?"1":"0"));
 FileFlush(g_tape);
 g_tapeCandidates++;
}

void FinishShadow(const int slot,const string status,
                  datetime observed,double exitPrice,bool priceKnown)
{
 if(!g_opportunities[slot].active)return;
 ShadowOpportunity c=g_opportunities[slot];
 double gross=0.0,net=0.0,r=0.0;
 bool calculated=false;
 if(priceKnown && exitPrice>0)
 {
   ENUM_ORDER_TYPE kind=(c.direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double pnlAtStop=0;
   calculated=OrderCalcProfit(kind,_Symbol,ShadowReferenceLot,
                              c.entry,exitPrice,gross) &&
              OrderCalcProfit(kind,_Symbol,ShadowReferenceLot,
                              c.entry,c.stop,pnlAtStop) &&
              pnlAtStop<0;
   if(calculated)
   {
      net=gross-ShadowReferenceLot*AssumedCommissionPerLot;
      double denominator=MathAbs(pnlAtStop)+ShadowReferenceLot*AssumedCommissionPerLot;
      if(denominator>0)r=net/denominator;
   }
 }
 if(g_outcomes!=INVALID_HANDLE)
 {
   FileWrite(g_outcomes,c.id,status,
      TimeToString(c.entryTime,TIME_DATE|TIME_SECONDS),
      TimeToString(observed,TIME_DATE|TIME_SECONDS),
      (c.direction==1?"BUY":"SELL"),
      DoubleToString(c.entry,_Digits),
      DoubleToString(c.stop,_Digits),
      DoubleToString(c.target,_Digits),
      DoubleToString(exitPrice,_Digits),
      DoubleToString(c.spreadPoints,2),
      (c.contextOk?"1":"0"),
      (c.stopOk?"1":"0"),(c.spreadOk?"1":"0"),
      (calculated?"1":"0"),
      (calculated?DoubleToString(gross,3):""),
      (calculated?DoubleToString(net,3):""),
      (calculated?DoubleToString(r,5):""),
      IntegerToString((int)(observed-c.entryTime)),
      (c.direction==1?"BID_M1_OHLC":"ASK_EST_FROM_BID_PLUS_ENTRY_SPREAD"),
      "SIMULACAO_OHLC_M1_NAO_TICK_FILL");
   FileFlush(g_outcomes);
 }
 if(status=="BOTH_TOUCHED_AMBIGUOUS")g_shadowAmbiguous++;
 g_shadowResolved++;
 g_opportunities[slot].active=false;
}

void StartShadow(string id,datetime signalTime,const MqlTick &q,
                 int dir,double entry,double stop,double target,
                 bool contextOk,bool stopOk,bool spreadOk)
{
 if(!EnableM1ShadowOutcomes || g_outcomes==INVALID_HANDLE)return;
 if((dir==1 && stop>=entry) || (dir==-1 && stop<=entry))return;
 int index=-1;
 for(int i=0;i<ArraySize(g_opportunities);i++)
 {
   if(!g_opportunities[i].active){index=i;break;}
 }
 if(index<0)
 {
   g_shadowNoSlot++;
   if(g_outcomes!=INVALID_HANDLE)
      FileWrite(g_outcomes,id,"NO_SLOT",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   return;
 }
 g_opportunities[index].active=true;
 g_opportunities[index].id=id;
 g_opportunities[index].entryTime=TimeCurrent();
 g_opportunities[index].signalBarTime=signalTime;
 g_opportunities[index].direction=dir;
 g_opportunities[index].entry=entry;
 g_opportunities[index].stop=stop;
 g_opportunities[index].target=target;
 g_opportunities[index].spreadPoints=(q.ask-q.bid)/_Point;
 g_opportunities[index].contextOk=contextOk;
 g_opportunities[index].stopOk=stopOk;
 g_opportunities[index].spreadOk=spreadOk;
 g_shadowOpens++;
}

// A cada M1 fechado: estimativa de primeiro toque, NAO execução por tick.
// Se stop e alvo forem tocados na mesma barra, resultado permanece AMBIGUO.
void ResolveShadowsOnClosedM1()
{
 if(!EnableM1ShadowOutcomes)return;
 MqlRates closed[];
 ArraySetAsSeries(closed,true);
 if(CopyRates(_Symbol,PERIOD_M1,1,1,closed)!=1)return;
 datetime observed=TimeCurrent();
 for(int i=0;i<ArraySize(g_opportunities);i++)
 {
   if(!g_opportunities[i].active)continue;
   ShadowOpportunity c=g_opportunities[i];
   if(closed[0].time<=c.signalBarTime)continue; // nunca incluir barra sinal
   double shift=(c.direction==1?0.0:c.spreadPoints*_Point);
   double high=closed[0].high+shift,low=closed[0].low+shift;
   bool hitStop=(c.direction==1?low<=c.stop:high>=c.stop);
   bool hitTarget=(c.direction==1?high>=c.target:low<=c.target);
   if(hitStop && hitTarget)
   {
      FinishShadow(i,"BOTH_TOUCHED_AMBIGUOUS",observed,0.0,false);
   }
   else if(hitStop)
   {
      FinishShadow(i,"STOP_FIRST_TOUCH_M1",observed,c.stop,true);
   }
   else if(hitTarget)
   {
      FinishShadow(i,"TARGET_FIRST_TOUCH_M1",observed,c.target,true);
   }
   else if(observed-c.entryTime>=ExitAfterMinutes*60)
   {
      FinishShadow(i,"TIMEOUT_M1",observed,closed[0].close+shift,true);
   }
 }
}

void TestSignal()
{
 // Descoberta ANTES de cap diario, cooldown, posicoes e filtro de contexto.
 MqlTick q;
 if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=q.bid)return;

 MqlRates b[];
 ArraySetAsSeries(b,true);
 if(CopyRates(_Symbol,PERIOD_M1,1,StopLookbackBars,b)!=StopLookbackBars)
    return;
 if(b[0].time+PeriodSeconds(PERIOD_M1)>TimeCurrent())return;

 double span=b[0].high-b[0].low;
 if(span<=0)return;
 double body=MathAbs(b[0].close-b[0].open)/span;
 if(body<MinBodyFraction)return;
 int dir=0;
 if(b[0].close>b[1].high+BreakBufferPoints*_Point &&
    b[0].close>b[0].open)dir=1;
 else if(b[0].close<b[1].low-BreakBufferPoints*_Point &&
         b[0].close<b[0].open)dir=-1;
 if(dir==0)return;
 g_signals++;

 double lo=b[0].low,hi=b[0].high;
 for(int k=1;k<StopLookbackBars;k++)
 {
   lo=MathMin(lo,b[k].low);
   hi=MathMax(hi,b[k].high);
 }
 double spread=(q.ask-q.bid)/_Point;
 double entry=(dir==1?q.ask:q.bid);
 double sl=NormalizeDouble((dir==1?lo-StopBufferPoints*_Point:
                                hi+StopBufferPoints*_Point),_Digits);
 double stopPts=MathAbs(entry-sl)/_Point;
 bool sideOK=(dir==1?sl<entry:sl>entry);
 double tp=NormalizeDouble((dir==1?entry+RewardRisk*stopPts*_Point:
                                entry-RewardRisk*stopPts*_Point),_Digits);
 bool stopOK=(sideOK && stopPts>=MinStopPoints && stopPts<=MaxStopPoints);
 bool spreadOK=(spread<=SpreadLimitPoints);

 string info="";
 bool h1OK=false,m15OK=false;
 double h1Close=0,h1Sma=0,h1Slope=0,m15Close=0,m15Eq=0;
 bool contextOK=ReadH1M15(dir,info,h1OK,m15OK,
            h1Close,h1Sma,h1Slope,m15Close,m15Eq);
 double atrPts=0,bbWidth=0,bbPosition=0;
 M1MarketFeatures(atrPts,bbWidth,bbPosition);
 string id=StringFormat("%I64d_%s", (long)b[0].time,(dir==1?"BUY":"SELL"));

 if(EnableSignalTape)
   TapeCandidate(id,b[0].time,q,dir,body,entry,sl,tp,stopPts,
          h1OK,m15OK,contextOK,info,h1Close,h1Sma,h1Slope,
          m15Close,m15Eq,atrPts,bbWidth,bbPosition,sideOK);
 StartShadow(id,b[0].time,q,dir,entry,sl,tp,contextOK,stopOK,spreadOK);

 // Limites a seguir controlam apenas EXECUCAO do Strategy Tester;
 // todos os sinais M1 ja foram registrados na fita independente.
 if(g_locked)return;
 if(!SessionOK())return;
 if(PositionsTotal()>=MaxOpenPositions)return;
 if(g_dayTrades>=MaxDayTrades)return;
 if(g_lastTrade>0 && TimeCurrent()-g_lastTrade<CooldownMinutes*60)return;
 if(RequireH1M15Context && !contextOK)
 {
   g_vetoes++;
   LogRow("VETO_CONTEXTO",info,dir,q.bid,q.ask);
   return;
 }
 if(RequireH1M15Context)
    LogRow("CONTEXTO_APROVADO",info,dir,q.bid,q.ask);
 if(!spreadOK)
 {g_vetoes++;LogRow("VETO_SPREAD","spread alto",dir,q.bid,q.ask);return;}
 if(!stopOK)
 {g_vetoes++;LogRow("VETO_STOP","stop invalido ou fora dos limites",dir,
                    q.bid,q.ask,entry,sl,tp);return;}

 double brokerMin=(double)MathMax(
      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2.0;
 if(dir==1 && ((q.bid-sl)/_Point<brokerMin ||
               (tp-q.bid)/_Point<brokerMin))return;
 if(dir==-1 && ((sl-q.ask)/_Point<brokerMin ||
                (q.ask-tp)/_Point<brokerMin))return;

 double volume=0,risk=0;
 if(!SizeAtRisk(dir,entry,sl,volume,risk))
 {
   g_vetoes++;
   LogRow("VETO_LOTE","lote seguro indisponivel",dir,q.bid,q.ask,entry,sl,tp);
   return;
 }
 g_attempts++;
 LogRow("ORDER_ATTEMPT","M1 breakout benchmark, no profit claim",
        dir,q.bid,q.ask,entry,sl,tp,volume,risk);
 bool ok=(dir==1?trade.Buy(volume,_Symbol,0.0,sl,tp,"ALIEN_TURBO_TESTER"):
                 trade.Sell(volume,_Symbol,0.0,sl,tp,"ALIEN_TURBO_TESTER"));
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
          dir,q.bid,q.ask,entry,sl,tp,volume,risk,(long)trade.ResultDeal());
 }
 else
 {
   g_vetoes++;
   LogRow("ORDER_REJECTED",
        StringFormat("ret=%u error=%d",ret,GetLastError()),
        dir,q.bid,q.ask,entry,sl,tp,volume,risk);
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
      MaxDayTrades<1 || MaxDayTrades>200 ||
      MaxOpenPositions<1 || MaxOpenPositions>5 ||
      StopLookbackBars<3 || StopLookbackBars>8 ||
      H1TrendLookback!=20 || M15EquilibriumBars!=12 ||
      MinStopPoints<35 || MaxStopPoints>180 ||
      MinStopPoints>MaxStopPoints ||
      SpreadLimitPoints<=0 || SpreadLimitPoints>45 ||
      RewardRisk<1.0 || RewardRisk>3.0 ||
      StartServerHour<0 || EndServerHour>24 ||
      StartServerHour>=EndServerHour ||
      CooldownMinutes<0 || ExitAfterMinutes<10 ||
      ShadowReferenceLot<=0 || ShadowReferenceLot>0.02 ||
      StringFind(CSVFileName,"|")>=0 ||
      StringFind(CSVFileName,"/")>=0 ||
      StringFind(CSVFileName,"\\")>=0 ||
      StringFind(TapeCSVFileName,"|")>=0 ||
      StringFind(TapeCSVFileName,"/")>=0 ||
      StringFind(TapeCSVFileName,"\\")>=0 ||
      StringFind(OutcomeCSVFileName,"|")>=0 ||
      StringFind(OutcomeCSVFileName,"/")>=0 ||
      StringFind(OutcomeCSVFileName,"\\")>=0)
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
   if(EnableSignalTape)
   {
      g_tape=FileOpen(TapeCSVFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                     FILE_ANSI|FILE_SHARE_READ,';');
      if(g_tape==INVALID_HANDLE)
      {Print("FALHA arquivo tape ",GetLastError());return INIT_FAILED;}
      if(FileSize(g_tape)==0)
         FileWrite(g_tape,"candidate_id","observed_at","tick_msc",
          "signal_bar","direction","bid","ask","spread_points",
          "m1_body_fraction","entry","stop","target","stop_points",
          "h1_ok","m15_ok","both_context_ok","context_note",
          "h1_close","h1_sma20","h1_sma_slope_pts",
          "m15_close","m15_range_mid","m1_atr14_pts",
          "bb20_width_pts","bb20_position","session_ok",
          "portfolio_locked","open_positions","day_entries",
          "cooldown_active","stop_within_limits","spread_within_limit");
      FileSeek(g_tape,0,SEEK_END);
   }
   if(EnableM1ShadowOutcomes)
   {
      g_outcomes=FileOpen(OutcomeCSVFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                          FILE_ANSI|FILE_SHARE_READ,';');
      if(g_outcomes==INVALID_HANDLE)
      {Print("FALHA arquivo shadow ",GetLastError());return INIT_FAILED;}
      if(FileSize(g_outcomes)==0)
         FileWrite(g_outcomes,"candidate_id","state","opened_at",
          "observed_at","direction","entry","stop","target",
          "exit_price","spread_points","context_ok","stop_ok",
          "spread_ok","pnl_calculated","gross_pnl","net_pnl_est",
          "net_r_est","held_seconds","price_basis","caution");
      FileSeek(g_outcomes,0,SEEK_END);
   }
   g_lastBar=iTime(_Symbol,PERIOD_M1,0);
   RiskProtection();
   LogRow("START",StringFormat("TURBO TESTER ONLY: maxDay=%d cooldown=%d maxPos=%d H1M15=%s RR=%.1f",
          MaxDayTrades,CooldownMinutes,MaxOpenPositions,
          (RequireH1M15Context?"ON":"OFF"),RewardRisk));
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(MQLInfoInteger(MQL_TESTER)==0)return;
   RiskProtection();
   if(!g_locked)ExitByTime();
   datetime curr=iTime(_Symbol,PERIOD_M1,0);
   if(curr>0 && g_lastBar>0 && curr!=g_lastBar)
   {
      g_lastBar=curr;
      ResolveShadowsOnClosedM1();
      TestSignal(); // sempre loga, mesmo quando conta em lock
   }
   else if(g_lastBar==0 && curr>0)g_lastBar=curr;
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
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_opportunities);i++)
      if(g_opportunities[i].active)
         FinishShadow(i,"CENSORED_END_NO_FUTURE_DATA",now,0.0,false);
   LogRow("END",StringFormat(
        "signals=%d attempts=%d entries=%d exits=%d vetoes=%d tape=%d shadow=%d resolved=%d ambiguous=%d noSlot=%d",
        g_signals,g_attempts,g_entries,g_dealsOut,g_vetoes,
        g_tapeCandidates,g_shadowOpens,g_shadowResolved,
        g_shadowAmbiguous,g_shadowNoSlot));
   if(g_file!=INVALID_HANDLE)
   {FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;}
   if(g_tape!=INVALID_HANDLE)
   {FileFlush(g_tape);FileClose(g_tape);g_tape=INVALID_HANDLE;}
   if(g_outcomes!=INVALID_HANDLE)
   {FileFlush(g_outcomes);FileClose(g_outcomes);g_outcomes=INVALID_HANDLE;}
}
//+------------------------------------------------------------------+
