//+------------------------------------------------------------------+
//| ALIEN R4.4 SHADOW LAB - DEMO - XAUUSD / MetaTrader 5              |
//| H1 bias > M15 FVG/OB > M5 sweep > M1 displacement                |
//| Ordem REAL bloqueada no codigo; backtest e DEMO apenas.          |
//| Hipotese de pesquisa; resultados e compilacao ainda pendentes.   |
//+------------------------------------------------------------------+
#property strict
#property version "4.40"
#property description "ALIEN R4.4: laboratorio de stops pareados sem ordens"

#include <Trade/Trade.mqh>
CTrade trade;

input group "=== ALIEN: MODULOS ATIVOS ==="
input bool EnableDemoOrders       = false; // LAB exclusivo: proibido ativar ordens
input bool UseH1Context           = true;
input bool RequireH1Alignment     = true;
input bool UseM15FVG              = true;
input bool UseM15OrderBlock       = true;
input bool UseM5LiquiditySweep    = true;
input bool UseM1Displacement      = true;
input bool UseBollinger           = true;
input bool UseATRFilter           = true;
input bool UseLiquidityRoomFilter = true;
input bool UseSessionFilter       = true;
input bool EnableBreakEven        = true;
input bool EnableATRTrailing      = true;
input bool EnableDailyGuard       = true;
input bool EnableWeekendGuard     = true;
input bool EnablePanel            = true;
input bool EnableCSV              = true;

input group "=== CONFLUENCIA MULTITEMPORAL ==="
input int    H1SMAPeriod           = 20;
input int    M15ScanBars          = 24;
input double MinimumFVGPoints    = 10.0;
input double MinimumOBImpulsePts = 20.0;
input double POITolerancePoints  = 12.0;
input int    M5LiquidityLookback = 10;
input double MinimumSweepPoints  = 4.0;
input double MinimumReclaimPts   = 2.0;
input double MinimumWickFraction = 0.30;
input double MinimumM1BodyRatio  = 0.56;
input double MinimumM1BreakPts   = 2.0;
input int    ConfirmationMinutes = 4;
input group "=== ENTRADA POR RETESTE M1 (EXPERIMENTO A/B) ==="
input bool   EnableM1Retest = true;            // B=true R4.1; A=false baseline R4
input int    RetestWindowMinutes = 4;          // candles M1 fechados depois do displacement
input double RetestTolerancePoints = 14.0;     // alcancar faixa do nivel rompido
input double RetestMaxCrossPoints = 20.0;      // rejeitar penetracao excessiva do nivel
input double RetestRejectClosePoints = 2.0;    // fechamento de defesa do lado correto
input double RetestMinBodyFraction = 0.25;     // defesa da vela de reteste
input int    ATRPeriod            = 14;
input double MinimumATRPoints    = 30.0;
input int    BollingerPeriod     = 20;
input double BollingerDeviations = 2.0;
input double MinimumBandSpreadRatio = 2.0;

input group "=== STOP CURTO, ALVO LONGO, RISCO CONTROLADO ==="
input double RiskPercentEquity       = 0.25;
input double RewardRiskMultiple      = 4.0;
input double StopBufferPoints        = 8.0;
input double MinimumStopPoints       = 35.0;
input double MaximumStopPoints       = 180.0;
input double OppositePoolBufferPts   = 5.0;
input double MaximumSpreadPoints     = 25.0;
input double EstimatedRoundTurnPerLot= 8.30; // estimativa do HTML enviado: ~US$8.28 por 1 lote ida e volta
input double ReservedSlippagePoints  = 10.0;
input double MaximumMarginPctEquity  = 30.0;
input int    MaxSimultaneousPositions= 1;
input int    MaxTradesPerDay         = 6;
input int    MinimumMinutesBetweenEntries= 10;
input int    LossStreakPauseAfter    = 2;
input int    LossStreakPauseMinutes  = 60;
input int    BrokerDeviationPoints  = 15;
input ulong  ExpertMagic            = 26061113;

input group "=== SAIDA E PROTECAO ==="
input double BreakEvenAtR        = 1.6;
input double TrailAfterR         = 2.6;
input double TrailATRMultiplier  = 0.85;
input double MinimumTrailPoints  = 70.0;
input double TrailStepPoints     = 8.0;
input double DailyEquityLossPct  = 2.0;
input int    SessionStartServerHour= 7;
input int    SessionEndServerHour  = 20;
input int    FridayCloseServerHour= 20;

input group "=== PROFESSOR E EVIDENCIAS ==="
input string CSVFileName="ALIEN_R44_EVENTS.csv";
input group "=== LAB DE CONTRAFACTUAIS SEM ORDENS ==="
input bool   EnableShadowLab=true;
input string ShadowCSVFileName="ALIEN_R44_SHADOW.csv";
input double ShadowReferenceVolume=0.01;    // lote hipotetico fixo
input int    ShadowTimeoutMinutes=90;       // horizonte maximo hipotetico
input group "=== A/B: APENAS GATILHO M1 MUDA ==="
input bool   UseEarlyMicroBreak=false; // A=false displacement, B=true quebra micro M1
input int    MicroBreakLookbackBars=3;  // barras M1 ANTERIORES ao candle candidato
input double MicroBreakBodyFraction=0.25;
input double MicroBreakMinPoints=2.0;
input int    GapTimeoutGraceSeconds=120;
input group "=== R4.4 - STOP LOCAL M1 PAREADO ==="
input bool   EnableLocalStopPairing=true;
input int    LocalPivotLookbackBars=4; // so M1 fechados apos fim do sweep M5


input bool   ShowChartArrows=true;

struct ArmedSetup
{
   int direction;
   datetime sweepOpen;
   datetime armTime;
   datetime expiresTime;
   double sweepExtreme;
   double liquidity;
   double poiLow;
   double poiHigh;
   double oppositePool;
   string poiKind;
   string eventId;
   int stage;                // 0: idle; 1: aguarda M1; 2: aguarda reteste
   double retestLevel;       // max/min anterior ao displacement M1
   datetime retestAfter;     // reteste somente em candle posterior ao displacement
   datetime retestExpires;
   bool shadowDispSeen;
   bool shadowRetSeen;
};

ArmedSetup g_setup;
int g_csv=INVALID_HANDLE;
int g_h1bias=0;
datetime g_lastM5=0;
datetime g_lastM1=0;
datetime g_lastEntry=0;
datetime g_dayStart=0;
double g_dayEquityStart=0.0;
bool g_dayLocked=false;
string g_dayKey="";
string g_lastReason="inicializando";
int g_sweeps=0;
int g_armed=0;
int g_entries=0;
int g_rejected=0;
int g_retestsArmed=0;
int g_retestsFilled=0;
int g_retestsExpired=0;
int g_shadowFile=INVALID_HANDLE;
int g_shadowActive=0;
int g_shadowObserved=0;
int g_shadowFinished=0;
struct ShadowCandidate
{
   bool active;
   string candidateId;
   string sweepId;
   string phase;
   int direction;
   int macroBias;
   string poi;
   datetime startedAt;
   long tickMsc;
   double entry;
   double stop;
   double target;
   double stopPts;
   double spreadPts;
   double lot;
   double riskMoney;
   bool stopOK;
   bool spreadOK;
   bool roomOK;
   bool riskOK;
   bool sessionOK;
   double lastQuote;
   datetime lastQuoteAt;
   string stopModel;        // STOP_M5 ou STOP_M1_LOCAL
   datetime pivotAt;       // 0 quando nao houver pivo
   double pivotPrice;
   datetime setupAt;
};
ShadowCandidate g_shadow[64];

void ClearSetup()
{
   g_setup.direction=0;
   g_setup.sweepOpen=0;
   g_setup.armTime=0;
   g_setup.expiresTime=0;
   g_setup.sweepExtreme=0.0;
   g_setup.liquidity=0.0;
   g_setup.poiLow=0.0;
   g_setup.poiHigh=0.0;
   g_setup.oppositePool=0.0;
   g_setup.poiKind="";
   g_setup.eventId="";
   g_setup.stage=0;
   g_setup.retestLevel=0.0;
   g_setup.retestAfter=0;
   g_setup.retestExpires=0;
   g_setup.shadowDispSeen=false;
   g_setup.shadowRetSeen=false;
}

string SideName(int dir)
{
   if(dir>0) return "BUY";
   if(dir<0) return "SELL";
   return "NEUTRO";
}

void Panel()
{
   if(!EnablePanel) return;
   Comment("ALIEN R4.4 SHADOW LAB | ",_Symbol," M1\n",
      "H1=",SideName(g_h1bias)," | M5 arm=",SideName(g_setup.direction),
      " | POI=",g_setup.poiKind,"\n",
      "RR alvo=",DoubleToString(RewardRiskMultiple,1),
      " | risco=",DoubleToString(RiskPercentEquity,2),"%",
      " | stop max=",DoubleToString(MaximumStopPoints,0),"pts\n",
      "Sweeps=",g_sweeps," Armados=",g_armed," Entradas=",g_entries,
      " Bloqueios=",g_rejected,"\n",
      "Retestes armados=",g_retestsArmed," Entradas reteste=",g_retestsFilled,
      " Estado=",g_setup.stage,"\n",
      "Modo=",EnableDemoOrders?"DEMO/TESTER":"OBSERVADOR",
      " | conta REAL BLOQUEADA",
      " | Dia=",g_dayLocked?"TRAVADO":"ATIVO","\n",
      "Ultima decisao: ",g_lastReason);
}

void LogEvent(string eventName,string detail,
              double entry=0.0,double sl=0.0,double tp=0.0,
              double volume=0.0,double riskMoney=0.0)
{
   // Preservar as 26 colunas CSV, mesmo com texto livre nos motivos.
   StringReplace(detail,";",",");
   g_lastReason=eventName+" "+detail;
   Print("[ALIEN_GENESIS] ",g_lastReason," event_id=",g_setup.eventId);
   if(g_csv!=INVALID_HANDLE)
   {
      MqlTick tick;
      double spread=0;
      if(SymbolInfoTick(_Symbol,tick) && tick.ask>tick.bid)
         spread=(tick.ask-tick.bid)/_Point;
      FileWrite(g_csv,
         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
         _Symbol,EnableDemoOrders?"DEMO":"OBSERVER",
         g_setup.eventId,eventName,detail,
         IntegerToString(g_setup.stage),
         DoubleToString(g_setup.retestLevel,_Digits),
         (g_setup.retestAfter>0?TimeToString(g_setup.retestAfter,TIME_DATE|TIME_SECONDS):""),
         (entry>0 && sl>0?DoubleToString(MathAbs(entry-sl)/_Point,2):""),
         SideName(g_setup.direction),
         SideName(g_h1bias),g_setup.poiKind,
         (g_setup.sweepOpen>0?TimeToString(g_setup.sweepOpen,TIME_DATE|TIME_SECONDS):""),
         DoubleToString(g_setup.liquidity,_Digits),
         DoubleToString(g_setup.poiLow,_Digits),
         DoubleToString(g_setup.poiHigh,_Digits),
         DoubleToString(g_setup.sweepExtreme,_Digits),
         DoubleToString(g_setup.oppositePool,_Digits),
         DoubleToString(spread,2),
         DoubleToString(entry,_Digits),
         DoubleToString(sl,_Digits),
         DoubleToString(tp,_Digits),
         DoubleToString(volume,2),
         DoubleToString(riskMoney,2),
         DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
      FileFlush(g_csv);
   }
   Panel();
}

bool ClosedBars(ENUM_TIMEFRAMES tf,int count,MqlRates &bars[])
{
   ArraySetAsSeries(bars,true);
   return CopyRates(_Symbol,tf,1,count,bars)==count;
}

int MacroAt(datetime sweepOpen)
{
   if(!UseH1Context) return 0;
   int count=H1SMAPeriod+6;
   MqlRates bars[];
   if(!ClosedBars(PERIOD_H1,count,bars)) return 0;
   for(int j=0;j<6;j++)
   {
      if(bars[j].time+PeriodSeconds(PERIOD_H1)>sweepOpen) continue;
      if(j+H1SMAPeriod>count) return 0;
      double avg=0;
      for(int k=j;k<j+H1SMAPeriod;k++) avg+=bars[k].close;
      avg/=H1SMAPeriod;
      if(bars[j].close>avg) return 1;
      if(bars[j].close<avg) return -1;
      return 0;
   }
   return 0;
}

// Zona M15 existente ANTES do inicio da vela M5 que varreu liquidez.
// FVG e OB sao duas hipoteses habilitadas; qualquer uma pode formar o POI.
bool FindPriorPOI(int dir,datetime sweepOpen,double lo,double hi,
                  double &zLo,double &zHi,string &kind)
{
   MqlRates b[];
   if(!ClosedBars(PERIOD_M15,M15ScanBars+5,b)) return false;
   double tol=POITolerancePoints*_Point;
   for(int j=0;j<M15ScanBars;j++)
   {
      if(b[j].time+PeriodSeconds(PERIOD_M15)>sweepOpen) continue;
      double low=0,high=0;
      string label="";
      if(UseM15FVG)
      {
         if(dir==1 && b[j].low>b[j+2].high+MinimumFVGPoints*_Point)
         {
            low=b[j+2].high;high=b[j].low;label="FVG_M15";
         }
         else if(dir==-1 && b[j].high<b[j+2].low-MinimumFVGPoints*_Point)
         {
            low=b[j].high;high=b[j+2].low;label="FVG_M15";
         }
         if(label!="")
         {
            bool broken=false;
            for(int k=j-1;k>=0;k--)
            {
               if(b[k].time+PeriodSeconds(PERIOD_M15)>sweepOpen) continue;
               if(dir==1 && b[k].close<low) broken=true;
               if(dir==-1 && b[k].close>high) broken=true;
            }
            if(!broken && lo<=high+tol && hi>=low-tol)
            {
               zLo=low;zHi=high;kind=label;return true;
            }
         }
      }
      if(UseM15OrderBlock)
      {
         double displacement=MathAbs(b[j].close-b[j].open)/_Point;
         bool impulse=(displacement>=MinimumOBImpulsePts);
         bool bullish=(dir==1 && impulse && b[j+1].close<b[j+1].open &&
                       b[j].close>b[j].open && b[j].close>b[j+1].high);
         bool bearish=(dir==-1 && impulse && b[j+1].close>b[j+1].open &&
                       b[j].close<b[j].open && b[j].close<b[j+1].low);
         if(bullish || bearish)
         {
            low=b[j+1].low;high=b[j+1].high;
            bool broken=false;
            for(int k=j-1;k>=0;k--)
            {
               if(b[k].time+PeriodSeconds(PERIOD_M15)>sweepOpen) continue;
               if(dir==1 && b[k].close<low) broken=true;
               if(dir==-1 && b[k].close>high) broken=true;
            }
            if(!broken && lo<=high+tol && hi>=low-tol)
            {
               zLo=low;zHi=high;kind="OB_M15";return true;
            }
         }
      }
   }
   return false;
}

bool DetectSweep(int &dir,datetime &sweepOpen,double &extreme,
                 double &liquidity,double &low,double &high,double &opposite)
{
   if(!UseM5LiquiditySweep) return false;
   MqlRates b[];
   if(!ClosedBars(PERIOD_M5,M5LiquidityLookback+1,b)) return false;
   double bottom=b[1].low,top=b[1].high;
   for(int j=2;j<=M5LiquidityLookback;j++)
   {
      bottom=MathMin(bottom,b[j].low);
      top=MathMax(top,b[j].high);
   }
   double range=b[0].high-b[0].low;
   if(range<=0) return false;
   double lowWick=(MathMin(b[0].open,b[0].close)-b[0].low)/range;
   double highWick=(b[0].high-MathMax(b[0].open,b[0].close))/range;
   bool bull=(b[0].low<bottom-MinimumSweepPoints*_Point &&
              b[0].close>bottom+MinimumReclaimPts*_Point &&
              lowWick>=MinimumWickFraction);
   bool bear=(b[0].high>top+MinimumSweepPoints*_Point &&
              b[0].close<top-MinimumReclaimPts*_Point &&
              highWick>=MinimumWickFraction);
   if(bull==bear) return false; // sem evento ou ambos (ambiguidade)
   dir=bull?1:-1;
   sweepOpen=b[0].time;
   extreme=bull?b[0].low:b[0].high;
   liquidity=bull?bottom:top;
   opposite=bull?top:bottom;
   low=b[0].low;high=b[0].high;
   return true;
}

bool M1ATR(double &atr)
{
   MqlRates b[];
   if(!ClosedBars(PERIOD_M1,ATRPeriod+1,b)) return false;
   double sum=0;
   for(int i=0;i<ATRPeriod;i++)
   {
      double a=b[i].high-b[i].low;
      double c=MathAbs(b[i].high-b[i+1].close);
      double d=MathAbs(b[i].low-b[i+1].close);
      sum+=MathMax(a,MathMax(c,d));
   }
   atr=sum/ATRPeriod;
   return atr>0;
}

bool BollingerWidthOkay(double spreadPts)
{
   if(!UseBollinger) return true;
   MqlRates b[];
   if(!ClosedBars(PERIOD_M1,BollingerPeriod,b)) return false;
   double mean=0,variance=0;
   for(int i=0;i<BollingerPeriod;i++) mean+=b[i].close;
   mean/=BollingerPeriod;
   for(int i=0;i<BollingerPeriod;i++)
      variance+=MathPow(b[i].close-mean,2);
   double sd=MathSqrt(variance/BollingerPeriod);
   double bandWidth=2.0*BollingerDeviations*sd/_Point;
   return bandWidth>=spreadPts*MinimumBandSpreadRatio;
}

datetime DayStart(datetime moment)
{
   MqlDateTime dt;
   TimeToStruct(moment,dt);
   dt.hour=0;dt.min=0;dt.sec=0;
   return StructToTime(dt);
}

// Persistencia protege demo se EA reiniciar; Strategy Tester usa estado isolado.
void RefreshDay()
{
   datetime day=DayStart(TimeCurrent());
   if(day==g_dayStart && g_dayEquityStart>0) return;
   g_dayStart=day;
   g_dayKey=StringFormat("AMTFR4_%I64d_%I64u_%I64d",
                        AccountInfoInteger(ACCOUNT_LOGIN),ExpertMagic,(long)day);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(MQLInfoInteger(MQL_TESTER)!=0)
   {
      g_dayEquityStart=equity;
      g_dayLocked=false;
   }
   else
   {
      if(GlobalVariableCheck(g_dayKey))
         g_dayEquityStart=GlobalVariableGet(g_dayKey);
      else
      {
         g_dayEquityStart=equity;
         GlobalVariableSet(g_dayKey,equity);
      }
      g_dayLocked=GlobalVariableCheck(g_dayKey+"_LOCK");
   }
}

bool OwnPositionSelected(int index)
{
   ulong ticket=PositionGetTicket(index);
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   return PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC)==ExpertMagic;
}

int CountOwnPositions()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(OwnPositionSelected(i)) count++;
   return count;
}

bool OtherPositionOnSymbol()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)!=ExpertMagic) return true;
   }
   return false;
}

int DailyEntryCount()
{
   int result=0;
   if(!HistorySelect(g_dayStart,TimeCurrent()+1)) return MaxTradesPerDay;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong id=HistoryDealGetTicket(i);
      if(id==0) continue;
      if(HistoryDealGetString(id,DEAL_SYMBOL)!=_Symbol) continue;
      if((ulong)HistoryDealGetInteger(id,DEAL_MAGIC)!=ExpertMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(id,DEAL_ENTRY);
      if(e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT) result++;
   }
   return result;
}

bool LossStreakCooling()
{
   if(LossStreakPauseAfter<=0) return false;
   if(!HistorySelect(g_dayStart,TimeCurrent()+1)) return true;
   int strikes=0;
   datetime lastLoss=0;
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
   {
      ulong id=HistoryDealGetTicket(i);
      if(id==0) continue;
      if(HistoryDealGetString(id,DEAL_SYMBOL)!=_Symbol) continue;
      if((ulong)HistoryDealGetInteger(id,DEAL_MAGIC)!=ExpertMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(id,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      double net=HistoryDealGetDouble(id,DEAL_PROFIT)+
                 HistoryDealGetDouble(id,DEAL_SWAP)+
                 HistoryDealGetDouble(id,DEAL_COMMISSION)+
                 HistoryDealGetDouble(id,DEAL_FEE);
      if(net>0) break;
      if(net>=0) continue;
      if(lastLoss==0) lastLoss=(datetime)HistoryDealGetInteger(id,DEAL_TIME);
      strikes++;
      if(strikes>=LossStreakPauseAfter)
         return TimeCurrent()-lastLoss<LossStreakPauseMinutes*60;
   }
   return false;
}

bool IsDemoOrTester()
{
   if(MQLInfoInteger(MQL_TESTER)!=0) return true;
   return AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO;
}

void CloseOwnPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!OwnPositionSelected(i)) continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      bool sent=trade.PositionClose(ticket);
      uint ret=trade.ResultRetcode();
      if(!sent || (ret!=TRADE_RETCODE_DONE && ret!=TRADE_RETCODE_DONE_PARTIAL))
         LogEvent("ERRO_FECHAMENTO","retcode="+IntegerToString((int)ret));
   }
}

void EnforceAccountProtection()
{
   RefreshDay();
   if(!EnableDailyGuard || g_dayEquityStart<=0) return;
   if(g_dayLocked)
   {
      // Em reinicio, tentar novamente fechar posicoes proprias ainda abertas.
      if(CountOwnPositions()>0) CloseOwnPositions();
      return;
   }
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=g_dayEquityStart*(1.0-DailyEquityLossPct/100.0))
   {
      g_dayLocked=true;
      if(MQLInfoInteger(MQL_TESTER)==0)
         GlobalVariableSet(g_dayKey+"_LOCK",1.0);
      LogEvent("STOP_DIARIO","equity abaixo do piso diario");
      CloseOwnPositions();
   }
}

bool TimeWindowAllowed()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   if(dt.day_of_week==0 || dt.day_of_week==6) return false;
   if(EnableWeekendGuard && dt.day_of_week==5 && dt.hour>=FridayCloseServerHour)
      return false;
   if(UseSessionFilter &&
      (dt.hour<SessionStartServerHour || dt.hour>=SessionEndServerHour))
      return false;
   return true;
}

string RiskKey(ulong ticket)
{
   return StringFormat("AMTF_R_%I64d_%I64u",(long)AccountInfoInteger(ACCOUNT_LOGIN),ticket);
}

void TrackInitialRisk(double riskPrice)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!OwnPositionSelected(i)) continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      GlobalVariableSet(RiskKey(ticket),riskPrice);
   }
}

void ManagePositions()
{
   if(!EnableBreakEven && !EnableATRTrailing) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=0) return;
   double atr=0;
   bool haveATR=M1ATR(atr);
   double stopMin=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                  SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!OwnPositionSelected(i)) continue;
      ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      if(sl<=0 || tp<=0) continue; // nunca administra uma posicao sem protecao existente
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      double current=(dir==1?q.bid:q.ask);
      double favorable=(dir==1?current-open:open-current);
      string key=RiskKey(ticket);
      double originalRisk=GlobalVariableCheck(key)?GlobalVariableGet(key):0.0;
      if(originalRisk<=0.0)
      {
         // Falha fechada apos restart se a referencia original se perdeu.
         LogEvent("SEM_RISCO_INICIAL","trail nao pode recalcular R com stop movido");
         continue;
      }
      double candidate=sl;
      bool move=false;
      if(EnableBreakEven && favorable>=BreakEvenAtR*originalRisk)
      {
         double be=(dir==1?open+2*_Point:open-2*_Point);
         if((dir==1 && be>candidate) || (dir==-1 && be<candidate))
         {candidate=be;move=true;}
      }
      if(EnableATRTrailing && haveATR && favorable>=TrailAfterR*originalRisk)
      {
         double trailDist=MathMax(MinimumTrailPoints*_Point,atr*TrailATRMultiplier);
         double trail=(dir==1?current-trailDist:current+trailDist);
         if((dir==1 && trail>candidate) || (dir==-1 && trail<candidate))
         {candidate=trail;move=true;}
      }
      candidate=NormalizeDouble(candidate,_Digits);
      if(!move || MathAbs(candidate-sl)<TrailStepPoints*_Point) continue;
      // Valida a modificacao contra bid/ask (stop/freeze) do broker.
      if(dir==1 && (q.bid-candidate)/_Point<stopMin) continue;
      if(dir==-1 && (candidate-q.ask)/_Point<stopMin) continue;
      bool sent=trade.PositionModify(ticket,candidate,tp);
      uint ret=trade.ResultRetcode();
      if(!sent || ret!=TRADE_RETCODE_DONE)
         LogEvent("ERRO_TRAILING","retcode="+IntegerToString((int)ret));
   }
}

bool EntryAllowed(int dir)
{
   RefreshDay();
   if(!EnableDemoOrders) { LogEvent("SINAL_SEM_ORDEM","modo observador");return false; }
   if(!IsDemoOrTester()) {LogEvent("CONTA_BLOQUEADA","apenas demo ou testador");return false;}
   if(g_dayLocked){LogEvent("VETO_DIARIO","disjuntor de equity");return false;}
   if(!TimeWindowAllowed()){LogEvent("VETO_SESSAO","fora do horario do servidor");return false;}
   if(CountOwnPositions()>=MaxSimultaneousPositions)
   {LogEvent("VETO_POSICOES","limite simultaneo");return false;}
   if(OtherPositionOnSymbol())
   {LogEvent("VETO_CONFLITO","outro magic/manual no mesmo simbolo");return false;}
   if(DailyEntryCount()>=MaxTradesPerDay)
   {LogEvent("VETO_FREQUENCIA","limite diario de entradas");return false;}
   if(g_lastEntry>0 && TimeCurrent()-g_lastEntry<MinimumMinutesBetweenEntries*60)
   {LogEvent("VETO_COOLDOWN","tempo minimo entre trades");return false;}
   if(LossStreakCooling())
   {LogEvent("VETO_STREAK","pausa apos perdas");return false;}
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(mode!=SYMBOL_TRADE_MODE_FULL &&
      !(dir==1 && mode==SYMBOL_TRADE_MODE_LONGONLY) &&
      !(dir==-1 && mode==SYMBOL_TRADE_MODE_SHORTONLY))
   {LogEvent("VETO_SIMBOLO","negociacao indisponivel");return false;}
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {LogEvent("VETO_AUTOTRADE","permissao de algoritmo desligada");return false;}
   return true;
}

bool CalculateSize(int dir,double entry,double sl,double &lot,double &riskMoney)
{
   lot=0.0;riskMoney=0.0;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minLot<=0 || maxLot<minLot || step<=0) return false;
   ENUM_ORDER_TYPE type=dir==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   // Reserva slippage em entrada e no fechamento stopado; comissao estimada.
   double openWorst=entry+(dir==1?1:-1)*ReservedSlippagePoints*_Point;
   double stopWorst=sl+(dir==1?-1:1)*ReservedSlippagePoints*_Point;
   double oneLotNet=0;
   if(!OrderCalcProfit(type,_Symbol,1.0,openWorst,stopWorst,oneLotNet)) return false;
   double perLotRisk=MathAbs(oneLotNet)+EstimatedRoundTurnPerLot;
   double cap=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercentEquity/100.0;
   if(perLotRisk<=0 || cap<=0) return false;
   double raw=MathMin(maxLot,cap/perLotRisk);
   double rounded=MathFloor(raw/step+1e-9)*step;
   rounded=NormalizeDouble(rounded,8);
   if(rounded+1e-9<minLot) return false; // nao forcar lote minimo com risco excessivo
   lot=rounded;
   double worst=0;
   if(!OrderCalcProfit(type,_Symbol,lot,openWorst,stopWorst,worst))
      return false;
   riskMoney=MathAbs(worst)+EstimatedRoundTurnPerLot*lot;
   if(riskMoney>cap+0.000001) return false;
   double margin=0;
   if(!OrderCalcMargin(type,_Symbol,lot,entry,margin)) return false;
   if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE) ||
      margin>AccountInfoDouble(ACCOUNT_EQUITY)*MaximumMarginPctEquity/100.0)
      return false;
   return true;
}

void DrawSignal(datetime when,double price,int dir)
{
   if(!ShowChartArrows) return;
   string name="ALIEN_R4_"+g_setup.eventId;
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_ARROW,0,when,price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,dir==1?233:234);
   ObjectSetInteger(0,name,OBJPROP_COLOR,dir==1?clrLime:clrTomato);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
}

void ArmLatestM5(datetime newM5Open)
{
   // Reteste pode cruzar a fronteira de um M5. Nao trocar o evento em andamento.
   if(g_setup.direction!=0 && g_setup.stage==2)
   {
      if(newM5Open<=g_setup.retestExpires) return;
      g_retestsExpired++;
      LogEvent("RET_EXPIRADO","tempo de reteste esgotado no fechamento M5");
      ClearSetup();
   }
   if(g_setup.direction!=0) LogEvent("EXPIRADO","novo candle M5");
   ClearSetup();
   if(!UseM5LiquiditySweep) return;
   int dir=0;
   datetime t=0;
   double extreme=0,level=0,lo=0,hi=0,opposite=0;
   if(!DetectSweep(dir,t,extreme,level,lo,hi,opposite))
      return;
   g_sweeps++;
   g_setup.direction=dir;
   g_setup.sweepOpen=t;
   g_setup.sweepExtreme=extreme;
   g_setup.liquidity=level;
   g_setup.oppositePool=opposite;
   g_setup.eventId=StringFormat("SWEEP_%I64d_%d",(long)t,dir);
   g_h1bias=MacroAt(t);
   if(UseH1Context && RequireH1Alignment && g_h1bias!=dir)
   {g_rejected++;LogEvent("VETO_H1","SMA H1 nao alinhada");ClearSetup();return;}
   if(!FindPriorPOI(dir,t,lo,hi,g_setup.poiLow,g_setup.poiHigh,g_setup.poiKind))
   {g_rejected++;LogEvent("VETO_POI","sem FVG/OB M15 causal na zona");ClearSetup();return;}
   g_setup.armTime=newM5Open;
   g_setup.expiresTime=newM5Open+ConfirmationMinutes*60;
   g_setup.stage=1;
   g_armed++;
   LogEvent("ARMADO","confirmacao M1 apos fechamento M5");
}

// =================================================================
// R4.2 SHADOW LAB - NAO envia ordens. Cada abertura e um contrafactual
// coletado no PRIMEIRO TICK depois do fechamento do candle M1.
// Desfecho: Bid para compra, Ask para venda; nenhum dado futuro usado.
// ==========================================================================
void ShadowWrite(const ShadowCandidate &c,string status,datetime observed,
                 double closePrice=0.0,double gross=0.0,
                 double netR=0.0)
{
   if(g_shadowFile==INVALID_HANDLE) return;
   int held=(observed>c.startedAt ? (int)(observed-c.startedAt) : 0);
   FileWrite(g_shadowFile,
      TimeToString(c.startedAt,TIME_DATE|TIME_SECONDS),
      c.candidateId,c.sweepId,c.phase,status,SideName(c.direction),
      SideName(c.macroBias),c.poi,
      DoubleToString(c.entry,_Digits),
      DoubleToString(c.stop,_Digits),
      DoubleToString(c.target,_Digits),
      DoubleToString(c.stopPts,2),
      DoubleToString(c.spreadPts,2),
      DoubleToString(c.stopPts>0?c.spreadPts/c.stopPts:0.0,5),
      (c.stopOK?"1":"0"),(c.spreadOK?"1":"0"),
      (c.roomOK?"1":"0"),(c.riskOK?"1":"0"),(c.sessionOK?"1":"0"),
      DoubleToString(c.lot,2),
      TimeToString(observed,TIME_DATE|TIME_SECONDS),
      DoubleToString(closePrice,_Digits),
      DoubleToString(gross,2),
      DoubleToString(c.lot*EstimatedRoundTurnPerLot,2),
      DoubleToString(netR,5),
      IntegerToString(held),
      c.stopModel,
      (c.pivotAt>0?TimeToString(c.pivotAt,TIME_DATE|TIME_SECONDS):""),
      DoubleToString(c.pivotPrice,_Digits),
      TimeToString(c.setupAt,TIME_DATE|TIME_SECONDS),
      (c.stopOK && c.spreadOK && c.roomOK && c.riskOK && c.sessionOK?"1":"0"));
   FileFlush(g_shadowFile);
}

// Pivo local M1 casual: o candle j (j>=1) e conhecido e
// confirmado pelos vizinhos FECHADOS j+1 e j-1 ate o fechamento
// do proprio candle sinal bars[0]. So contar pivos depois do M5 sweep.
// Nunca ler candle atual (CopyRates inicia no shift 1).
bool ConfirmedLocalPivot(const MqlRates &signalBar,int dir,
                         double &pivotPrice,datetime &pivotAt)
{
   pivotPrice=0.0;pivotAt=0;
   MqlRates bars[];
   int required=LocalPivotLookbackBars+2;
   if(!ClosedBars(PERIOD_M1,required,bars)) return false;
   if(bars[0].time!=signalBar.time) return false;

   for(int j=1;j<=LocalPivotLookbackBars;j++)
   {
      if(j+1>=required) break;
      if(bars[j].time<g_setup.armTime) break;
      bool pivotFound=(dir==1?
         (bars[j].low<bars[j-1].low && bars[j].low<bars[j+1].low):
         (bars[j].high>bars[j-1].high && bars[j].high>bars[j+1].high));
      if(pivotFound)
      {
         pivotPrice=(dir==1?bars[j].low:bars[j].high);
         pivotAt=bars[j].time;
         return true; // pivo confirmado MAIS RECENTE, sem lookahead
      }
   }
   return false;
}

// Entrada hipotetica em UMA cotacao; ambas as variantes usam o MESMO
// preco de entrada, a MESMA hora e o MESMO numero de lote de referencia.
// Calcula flags sem afrouxar filtros para a candidata local.
void RecordShadowVariant(ShadowCandidate &c)
{
   c.stopPts=MathAbs(c.entry-c.stop)/_Point;
   c.stopOK=(c.stopPts>=MinimumStopPoints && c.stopPts<=MaximumStopPoints);
   c.spreadOK=(c.spreadPts<=MaximumSpreadPoints);
   c.riskOK=false;
   c.roomOK=false;
   c.riskMoney=0.0;
   c.target=0.0;
   bool correctSide=(c.direction==1?c.stop<c.entry:c.stop>c.entry);
   if(!correctSide || c.stopPts<=0.0)
   {
      ShadowWrite(c,"STOP_LADO_INVALIDO",c.startedAt);
      return;
   }
   c.target=NormalizeDouble((c.direction==1?
      c.entry+RewardRiskMultiple*c.stopPts*_Point:
      c.entry-RewardRiskMultiple*c.stopPts*_Point),_Digits);
   c.roomOK=(c.direction==1?
      c.target<=g_setup.oppositePool-OppositePoolBufferPts*_Point:
      c.target>=g_setup.oppositePool+OppositePoolBufferPts*_Point);
   double hypotheticalLot=0.0,riskMoney=0.0;
   c.riskOK=CalculateSize(c.direction,c.entry,c.stop,hypotheticalLot,riskMoney);

   ENUM_ORDER_TYPE kind=(c.direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double grossStop=0.0;
   if(!OrderCalcProfit(kind,_Symbol,c.lot,c.entry,c.stop,grossStop)
      || grossStop>=0.0)
   {
      ShadowWrite(c,"SEM_CALC_RISCO",c.startedAt);
      return;
   }
   c.riskMoney=MathAbs(grossStop);
   int slot=-1;
   for(int i=0;i<ArraySize(g_shadow);i++)
   {
      if(!g_shadow[i].active) {slot=i;break;}
   }
   if(slot<0)
   {
      ShadowWrite(c,"SEM_SLOT_SHADOW",c.startedAt);
      return;
   }
   g_shadow[slot]=c;
   g_shadowActive++;
   g_shadowObserved++;
   ShadowWrite(c,"OPEN",c.startedAt);
}

void ShadowStart(bool fromRetest,const MqlRates &signalBar,const MqlTick &q)
{
   if(!EnableShadowLab || !EnableLocalStopPairing ||
      g_shadowFile==INVALID_HANDLE || g_setup.direction==0 ||
      q.bid<=0 || q.ask<=q.bid) return;
   // Garantia causal: entrada somente depois do FECHAMENTO do M1 sinal.
   if((datetime)q.time < signalBar.time+PeriodSeconds(PERIOD_M1)) return;

   if(fromRetest)
   {
      if(g_setup.shadowRetSeen) return;
      g_setup.shadowRetSeen=true;
   }
   else
   {
      if(g_setup.shadowDispSeen) return;
      g_setup.shadowDispSeen=true;
   }

   ShadowCandidate c;
   c.active=true;
   c.sweepId=g_setup.eventId;
   string sourcePhase=(fromRetest?"RETESTE":"DESLOCAMENTO");
   c.phase=sourcePhase;
   c.stopModel="STOP_M5";
   c.candidateId=c.sweepId+"_"+sourcePhase+"_"+c.stopModel;
   c.direction=g_setup.direction;
   c.macroBias=g_h1bias;
   c.poi=g_setup.poiKind;
   c.startedAt=(datetime)q.time;
   c.tickMsc=(long)q.time_msc;
   c.entry=(c.direction==1?q.ask:q.bid);
   c.spreadPts=(q.ask-q.bid)/_Point;
   c.stop=NormalizeDouble((c.direction==1?
      g_setup.sweepExtreme-StopBufferPoints*_Point:
      g_setup.sweepExtreme+(StopBufferPoints+c.spreadPts)*_Point),_Digits);
   c.lot=ShadowReferenceVolume;
   c.pivotAt=0;
   c.pivotPrice=0.0;
   c.setupAt=g_setup.armTime;
   c.lastQuote=(c.direction==1?q.bid:q.ask);
   c.lastQuoteAt=c.startedAt;
   MqlDateTime tm;
   TimeToStruct(c.startedAt,tm);
   c.sessionOK=(tm.day_of_week!=0 && tm.day_of_week!=6);
   if(EnableWeekendGuard && tm.day_of_week==5 &&
      tm.hour>=FridayCloseServerHour) c.sessionOK=false;
   if(UseSessionFilter &&
      (tm.hour<SessionStartServerHour ||
       tm.hour>=SessionEndServerHour)) c.sessionOK=false;
   RecordShadowVariant(c);

   // Candidato local mantem o MESMO momento e preço de entrada.
   // Ausencia de pivo e um resultado observavel: nunca excluir silenciosamente.
   c.stopModel="STOP_M1_LOCAL";
   c.candidateId=c.sweepId+"_"+sourcePhase+"_"+c.stopModel;
   double pivot=0.0;
   datetime pivotTime=0;
   if(!ConfirmedLocalPivot(signalBar,c.direction,pivot,pivotTime))
   {
      c.pivotPrice=0.0;c.pivotAt=0;
      c.stop=0.0;c.stopPts=0.0;c.target=0.0;
      c.stopOK=false;c.roomOK=false;c.riskOK=false;c.riskMoney=0.0;
      c.spreadOK=(c.spreadPts<=MaximumSpreadPoints);
      ShadowWrite(c,"SEM_PIVO_LOCAL",c.startedAt);
      return;
   }
   c.pivotPrice=pivot;
   c.pivotAt=pivotTime;
   c.stop=NormalizeDouble((c.direction==1?
      pivot-StopBufferPoints*_Point:
      pivot+(StopBufferPoints+c.spreadPts)*_Point),_Digits);
   RecordShadowVariant(c);
}

void ShadowUpdate()
{
   if(g_shadowActive==0) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=q.bid) return;
   for(int i=0;i<ArraySize(g_shadow);i++)
   {
      if(!g_shadow[i].active) continue;
      ShadowCandidate c=g_shadow[i];
      if((long)q.time_msc<=c.tickMsc) continue;
      double liquidation=(c.direction==1?q.bid:q.ask);
      bool timedOut=(q.time-c.startedAt)>=ShadowTimeoutMinutes*60;
      bool stopReached=(c.direction==1?liquidation<=c.stop:liquidation>=c.stop);
      bool targetReached=(c.direction==1?liquidation>=c.target:liquidation<=c.target);
      string label="";
      double exitPrice=liquidation;

      // O primeiro tick DEPOIS do horizonte nao pode ser usado para afirmar
      // que stop/alvo aconteceu dentro da janela sem cotacoes.
      if(timedOut)
      {
         exitPrice=c.lastQuote;
         label=((q.time-c.lastQuoteAt)>GapTimeoutGraceSeconds?
                "GAP_TIMEOUT":"TIMEOUT");
      }
      else if(stopReached) label="SL";
      else if(targetReached) label="TP";
      else
      {
         c.lastQuote=liquidation;
         c.lastQuoteAt=(datetime)q.time;
         g_shadow[i]=c;
         continue;
      }

      ENUM_ORDER_TYPE typ=(c.direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      double gross=0.0;
      if(exitPrice<=0.0 ||
         !OrderCalcProfit(typ,_Symbol,c.lot,c.entry,exitPrice,gross))
         ShadowWrite(c,"CALC_ERROR",(datetime)q.time,exitPrice);
      else
      {
         double r=(c.riskMoney>0.0?
            (gross-c.lot*EstimatedRoundTurnPerLot)/c.riskMoney:0.0);
         ShadowWrite(c,label,(datetime)q.time,exitPrice,gross,r);
      }
      g_shadow[i].active=false;
      g_shadowActive--;
      g_shadowFinished++;
   }
}

void ShadowFinish()
{
   for(int i=0;i<ArraySize(g_shadow);i++)
   {
      if(!g_shadow[i].active) continue;
      ShadowWrite(g_shadow[i],"CENSURADO_FIM_DADOS",TimeCurrent());
      g_shadow[i].active=false;
   }
   g_shadowActive=0;
}

// Arma reteste APENAS se o deslocamento M1 confirmou e o stop ficou longo.
// Nenhuma ordem e enviada neste ponto, e o stop segue atras do M5.
void ArmRetestFromDisplacement(const MqlRates &displacement,
                               const MqlRates &previous,double oversizedStopPoints)
{
   if(!EnableM1Retest) return;
   g_setup.stage=2;
   g_setup.retestLevel=(g_setup.direction==1?previous.high:previous.low);
   g_setup.retestAfter=displacement.time+PeriodSeconds(PERIOD_M1);
   g_setup.retestExpires=g_setup.retestAfter+RetestWindowMinutes*60;
   g_retestsArmed++;
   LogEvent("RET_ARMADO",
      "deslocamento confirmado; stop inicial "+DoubleToString(oversizedStopPoints,1)+
      "pts, aguardar reteste sem alargar stop");
}

void ExecuteWithStructuralStop(const MqlRates &confirmBar,bool fromRetest)
{
   int dir=g_setup.direction;
   if(dir==0) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=q.bid)
   {g_rejected++;LogEvent("VETO_COTACAO","bid/ask invalido");return;}
   // Registrar possibilidade ANTES dos vetos, sem enviar ordem.
   ShadowStart(fromRetest,confirmBar,q);
   double spread=(q.ask-q.bid)/_Point;
   if(spread>MaximumSpreadPoints)
   {g_rejected++;LogEvent("VETO_SPREAD","spread acima do teto");return;}
   double atr=0;
   if(UseATRFilter && (!M1ATR(atr) || atr/_Point<MinimumATRPoints))
   {g_rejected++;LogEvent("VETO_ATR","volatilidade insuficiente");return;}
   if(!BollingerWidthOkay(spread))
   {g_rejected++;LogEvent("VETO_BB","banda estreita");return;}
   double entry=(dir==1?q.ask:q.bid);
   double sl=(dir==1?
      g_setup.sweepExtreme-StopBufferPoints*_Point:
      g_setup.sweepExtreme+(StopBufferPoints+spread)*_Point);
   sl=NormalizeDouble(sl,_Digits);
   double stopPoints=MathAbs(entry-sl)/_Point;
   if((dir==1 && sl>=entry) || (dir==-1 && sl<=entry))
   {
      g_rejected++;
      LogEvent("VETO_STOP_LADO","stop nao invalida estrutura",entry,sl);
      ClearSetup();
      return;
   }
   if(stopPoints>MaximumStopPoints)
   {
      if(!fromRetest && EnableM1Retest)
      {
         MqlRates previous[];
         if(ClosedBars(PERIOD_M1,2,previous))
         {
            ArmRetestFromDisplacement(confirmBar,previous[1],stopPoints);
            return;
         }
      }
      g_rejected++;
      LogEvent(fromRetest?"RET_STOP_LONGO":"VETO_STOP_LONGO",
               "distancia do stop acima do teto",entry,sl);
      ClearSetup();
      return;
   }
   if(stopPoints<MinimumStopPoints)
   {
      g_rejected++;
      LogEvent("VETO_STOP_CURTO","stop menor que minimo do modelo",entry,sl);
      ClearSetup();
      return;
   }
   double tp=(dir==1?entry+RewardRiskMultiple*stopPoints*_Point:
                     entry-RewardRiskMultiple*stopPoints*_Point);
   tp=NormalizeDouble(tp,_Digits);
   double brokerMin=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                   SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+2.0;
   if(dir==1 && ((q.bid-sl)/_Point<brokerMin || (tp-q.bid)/_Point<brokerMin))
   {g_rejected++;LogEvent("VETO_STOPS_LEVEL","distancia buy abaixo do broker",entry,sl,tp);ClearSetup();return;}
   if(dir==-1 && ((sl-q.ask)/_Point<brokerMin || (q.ask-tp)/_Point<brokerMin))
   {g_rejected++;LogEvent("VETO_STOPS_LEVEL","distancia sell abaixo do broker",entry,sl,tp);ClearSetup();return;}
   if(UseLiquidityRoomFilter)
   {
      double limit=(dir==1?
            g_setup.oppositePool-OppositePoolBufferPts*_Point:
            g_setup.oppositePool+OppositePoolBufferPts*_Point);
      if((dir==1 && tp>limit) || (dir==-1 && tp<limit))
      {g_rejected++;LogEvent("VETO_ROOM","4R nao cabe antes da liquidez oposta",entry,sl,tp);ClearSetup();return;}
   }
   double lot=0,risk=0;
   if(!CalculateSize(dir,entry,sl,lot,risk))
   {g_rejected++;LogEvent("VETO_RISCO","risco estimado ou margem indisponivel",entry,sl,tp);ClearSetup();return;}
   // Contas reais continuam bloqueadas, independente da configuracao do input.
   if(!EntryAllowed(dir))
   {g_rejected++;ClearSetup();return;}
   DrawSignal(confirmBar.time,confirmBar.close,dir);
   ENUM_ORDER_TYPE kind=(dir==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double margin=0.0;
   if(!OrderCalcMargin(kind,_Symbol,lot,entry,margin))
   {g_rejected++;LogEvent("VETO_MARGEM","OrderCalcMargin falhou");ClearSetup();return;}
   bool submitted=(dir==1?
      trade.Buy(lot,_Symbol,entry,sl,tp,"ALIEN_MTF_R41"):
      trade.Sell(lot,_Symbol,entry,sl,tp,"ALIEN_MTF_R41"));
   uint ret=trade.ResultRetcode();
   bool filled=submitted &&
      (ret==TRADE_RETCODE_DONE || ret==TRADE_RETCODE_DONE_PARTIAL) &&
      trade.ResultDeal()>0;
   if(!filled)
   {
      g_rejected++;
      LogEvent("ORDEM_REJEITADA","retcode="+IntegerToString((int)ret),entry,sl,tp,lot,risk);
      ClearSetup();
      return;
   }
   g_lastEntry=TimeCurrent();
   g_entries++;
   TrackInitialRisk(MathAbs(entry-sl));
   if(fromRetest) g_retestsFilled++;
   LogEvent(fromRetest?"RET_ORDEM_EXECUTADA":"ORDEM_EXECUTADA",
            "retcode="+IntegerToString((int)ret),entry,sl,tp,lot,risk);
   ClearSetup();
}

void CheckRetestClosedM1(const MqlRates &bar)
{
   if(g_setup.stage!=2) return;
   if(bar.time<g_setup.retestAfter) return; // nao usar candle do displacement
   if(bar.time>=g_setup.retestExpires)
   {
      g_retestsExpired++;
      LogEvent("RET_EXPIRADO","janela de reteste atingida");
      ClearSetup();
      return;
   }
   int dir=g_setup.direction;
   double ref=g_setup.retestLevel;
   double tol=RetestTolerancePoints*_Point;
   double maxCross=RetestMaxCrossPoints*_Point;
   // Invalida com violacao estrutural. Nao reposicionar SL para esconder perda.
   bool invalid=(dir==1?
      bar.low<=g_setup.sweepExtreme-StopBufferPoints*_Point:
      bar.high>=g_setup.sweepExtreme+StopBufferPoints*_Point);
   if(invalid)
   {
      g_rejected++;
      LogEvent("RET_INVALIDADO","M1 violou extremo estrutural do sweep");
      ClearSetup();
      return;
   }
   // Voltar ao high/low anterior ao candle de deslocamento, e defender.
   bool overCross=(dir==1?bar.low<ref-maxCross:bar.high>ref+maxCross);
   if(overCross)
   {
      g_rejected++;
      LogEvent("RET_INVALIDADO","reteste penetrou alem do limite");
      ClearSetup();
      return;
   }
   bool touched=(dir==1?bar.low<=ref+tol:bar.high>=ref-tol);
   double range=bar.high-bar.low;
   double bodyRatio=(range>0?MathAbs(bar.close-bar.open)/range:0.0);
   bool defense=(dir==1?
      (bar.close>ref+RetestRejectClosePoints*_Point && bar.close>bar.open):
      (bar.close<ref-RetestRejectClosePoints*_Point && bar.close<bar.open));
   if(!touched || !defense || bodyRatio<RetestMinBodyFraction)
   {LogEvent("RET_AGUARDANDO","sem toque e fechamento de defesa");return;}
   LogEvent("RET_CONFIRMADO","reteste e vela de defesa fechados");
   ExecuteWithStructuralStop(bar,true);
}

void TryEntryFromClosedM1()
{
   if(g_setup.direction==0) return;
   MqlRates b[];
   if(!ClosedBars(PERIOD_M1,2,b)) return;
   if(g_setup.stage==2)
   {
      CheckRetestClosedM1(b[0]);
      return;
   }
   if(g_setup.stage!=1 || b[0].time<g_setup.armTime) return;
   if(b[0].time>=g_setup.expiresTime)
   {LogEvent("EXPIRADO","janela M1 de deslocamento");ClearSetup();return;}
   int dir=g_setup.direction;
   double range=b[0].high-b[0].low;
   if(range<=0) return;
   double body=MathAbs(b[0].close-b[0].open)/range;
   bool displacement=true;
   if(UseEarlyMicroBreak)
   {
      // Proxy objetivo de quebra microestrutural (nao rotular como
      // CHoCH institucional): candle fechado rompe extremos dos N
      // M1 anteriores, conhecidos ANTES do candle sinal.
      MqlRates micro[];
      if(!ClosedBars(PERIOD_M1,MicroBreakLookbackBars+1,micro)) return;
      double high=micro[1].high,low=micro[1].low;
      for(int k=2;k<=MicroBreakLookbackBars;k++)
      {
         high=MathMax(high,micro[k].high);
         low=MathMin(low,micro[k].low);
      }
      displacement=(dir==1?
         (b[0].close>high+MicroBreakMinPoints*_Point &&
          b[0].close>b[0].open):
         (b[0].close<low-MicroBreakMinPoints*_Point &&
          b[0].close<b[0].open));
      displacement=displacement && body>=MicroBreakBodyFraction;
   }
   else if(UseM1Displacement)
   {
      displacement=(dir==1?
         (b[0].close>b[0].open && b[0].close>b[1].high+MinimumM1BreakPts*_Point):
         (b[0].close<b[0].open && b[0].close<b[1].low-MinimumM1BreakPts*_Point));
      displacement=displacement && body>=MinimumM1BodyRatio;
   }
   if(!displacement)
   {LogEvent("AGUARDAR_M1","sem deslocamento fechado");return;}
   ExecuteWithStructuralStop(b[0],false);
}

int OnInit()
{
   // Guardas duras: este laboratorio NAO pode enviar ordens, nem em DEMO.
   if(MQLInfoInteger(MQL_TESTER)==0 || EnableDemoOrders || !EnableShadowLab ||
      !EnableLocalStopPairing || UseEarlyMicroBreak ||
      LocalPivotLookbackBars<2 || LocalPivotLookbackBars>8 ||
      MicroBreakLookbackBars<2 || MicroBreakLookbackBars>8 ||
      MicroBreakMinPoints<0 || MicroBreakBodyFraction<0 ||
      MicroBreakBodyFraction>1 || GapTimeoutGraceSeconds<0 ||
      ShadowTimeoutMinutes<1 || ShadowReferenceVolume<=0.0 ||
      StringFind(CSVFileName,"|")>=0 || StringFind(ShadowCSVFileName,"|")>=0 ||
      StringFind(ShadowCSVFileName,"/")>=0 || StringFind(ShadowCSVFileName,"\\")>=0)
   {
      Print("ALIEN R4.4 LAB: somente no Strategy Tester, ordens desativadas e CSV valido.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(_Period!=PERIOD_M1)
   {Print("ALIEN R4.4 exige grafico M1.");return INIT_PARAMETERS_INCORRECT;}
   if(StringFind(_Symbol,"XAU")<0 && StringFind(_Symbol,"GOLD")<0)
   {Print("ALIEN R4.4 configurado apenas para Ouro.");return INIT_PARAMETERS_INCORRECT;}
   if((EnableM1Retest && (RetestWindowMinutes<1 || RetestWindowMinutes>12 ||
        RetestTolerancePoints<0 || RetestMaxCrossPoints<0 ||
        RetestRejectClosePoints<0 || RetestMinBodyFraction<0 ||
        RetestMinBodyFraction>1.0)) ||
      EstimatedRoundTurnPerLot<0 || ReservedSlippagePoints<0 ||
      RiskPercentEquity<=0 || RiskPercentEquity>1.0 ||
      RewardRiskMultiple<2.0 || RewardRiskMultiple>8.0 ||
      MinimumStopPoints<=0 || MaximumStopPoints<MinimumStopPoints ||
      H1SMAPeriod<2 || M15ScanBars<3 || M5LiquidityLookback<2 ||
      ATRPeriod<2 || BollingerPeriod<3 || MaximumSpreadPoints<=0 ||
      ConfirmationMinutes<1 || ConfirmationMinutes>4 ||
      EnableDailyGuard && (DailyEquityLossPct<=0 || DailyEquityLossPct>20.0) ||
      SessionStartServerHour<0 || SessionStartServerHour>23 ||
      SessionEndServerHour<1 || SessionEndServerHour>24 ||
      SessionStartServerHour>=SessionEndServerHour ||
      FridayCloseServerHour<0 || FridayCloseServerHour>23 ||
      MaxSimultaneousPositions<1 || MaxTradesPerDay<1 ||
      BreakEvenAtR<=0 || TrailAfterR<=BreakEvenAtR)
   {Print("ALIEN R4.4: parametros invalidos.");return INIT_PARAMETERS_INCORRECT;}
   if(!UseM5LiquiditySweep || (!UseM15FVG && !UseM15OrderBlock))
   {Print("ALIEN R4.4: cascade precisa de sweep e ao menos uma zona.");return INIT_PARAMETERS_INCORRECT;}
   trade.SetExpertMagicNumber(ExpertMagic);
   trade.SetDeviationInPoints(BrokerDeviationPoints);
   trade.SetAsyncMode(false);
   if(!trade.SetTypeFillingBySymbol(_Symbol))
   {Print("ALIEN R4.4: tipo de preenchimento indefinido.");return INIT_FAILED;}
   if(EnableCSV)
   {
      g_csv=FileOpen(CSVFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                    FILE_ANSI|FILE_SHARE_READ,';');
      if(g_csv==INVALID_HANDLE)
      {Print("ALIEN R4.4: erro CSV ",GetLastError());return INIT_FAILED;}
      if(FileSize(g_csv)==0)
         FileWrite(g_csv,"timestamp","symbol","execution_mode","event_id",
            "event","reason","setup_stage","retest_level","retest_eligible_after",
            "stop_points","direction","h1_bias","poi_type","m5_sweep_open",
            "liquidity","poi_low","poi_high","sweep_extreme","opposite_pool",
            "spread_points","entry","stop","take_profit","volume","risk_money",
            "equity");
      FileSeek(g_csv,0,SEEK_END);
   }
   g_shadowFile=FileOpen(ShadowCSVFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                         FILE_ANSI|FILE_SHARE_READ,';');
   if(g_shadowFile==INVALID_HANDLE)
   {Print("ALIEN R4.4: erro abrindo CSV shadow ",GetLastError());return INIT_FAILED;}
   if(FileSize(g_shadowFile)==0)
      FileWrite(g_shadowFile,
         "opened_at","candidate_id","sweep_id","phase","state","side",
         "h1_bias","poi_type","entry","stop","target","stop_points",
         "spread_points","spread_over_stop","stop_limit_ok","spread_limit_ok",
         "room_ok","size_ok","session_ok","ref_lot","observed_at","exit_price",
         "gross_pnl","estimated_commission","net_r","held_seconds",
         "stop_model","pivot_at","pivot_price","setup_arm_at","all_filters_ok");
   FileSeek(g_shadowFile,0,SEEK_END);
   ClearSetup();
   RefreshDay();
   g_lastM5=iTime(_Symbol,PERIOD_M5,0);
   g_lastM1=iTime(_Symbol,PERIOD_M1,0);
   if(!IsDemoOrTester())
      LogEvent("CONTA_REAL_BLOQUEADA","codigo nunca envia ordens em REAL");
   else
      LogEvent("INICIADO","cascata completa ativa e modo demo/testador");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ShadowFinish();
   if(g_shadowFile!=INVALID_HANDLE)
   {FileFlush(g_shadowFile);FileClose(g_shadowFile);g_shadowFile=INVALID_HANDLE;}
   Comment("");
   if(g_csv!=INVALID_HANDLE)
   {FileFlush(g_csv);FileClose(g_csv);g_csv=INVALID_HANDLE;}
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Para reconstruir PnL com comissao e swap, sem fingir que sinais
   // vetados sao operacoes. Filtrar magic e simbolo do proprio ALIEN.
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;
   if((ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=ExpertMagic) return;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY &&
      entry!=DEAL_ENTRY_INOUT) return;
   double net=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
              HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+
              HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
              HistoryDealGetDouble(trans.deal,DEAL_FEE);
   LogEvent("TRADE_FECHADO",
      StringFormat("deal=%I64u net_deal=%.2f",trans.deal,net));
}

void OnTick()
{
   ShadowUpdate(); // desfecho tick a tick antes dos novos sinais
   // Bloqueio absoluto de toda acao de trading em conta REAL, inclusive
   // fechamentos automaticos e modificacoes de SL/TP.
   if(!IsDemoOrTester())
   {
      if(EnablePanel)
         Comment("ALIEN GENESIS R4: CONTA REAL BLOQUEADA - SEM ORDENS");
      return;
   }
   if(EnableDemoOrders)
   {
      EnforceAccountProtection();
      ManagePositions();
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(),dt);
      if(EnableWeekendGuard && dt.day_of_week==5 && dt.hour>=FridayCloseServerHour)
         CloseOwnPositions();
   }
   else RefreshDay();

   datetime m5=iTime(_Symbol,PERIOD_M5,0);
   if(m5>0 && g_lastM5>0 && m5!=g_lastM5)
   {
      g_lastM5=m5;
      ArmLatestM5(m5);
   }
   else if(g_lastM5==0 && m5>0) g_lastM5=m5;

   datetime m1=iTime(_Symbol,PERIOD_M1,0);
   if(m1>0 && g_lastM1>0 && m1!=g_lastM1)
   {
      g_lastM1=m1;
      TryEntryFromClosedM1();
   }
   else if(g_lastM1==0 && m1>0) g_lastM1=m1;
}
//+------------------------------------------------------------------+
