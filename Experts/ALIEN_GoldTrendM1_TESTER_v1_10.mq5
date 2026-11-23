//+------------------------------------------------------------------+
//| ALIEN_GoldTrendM1_TESTER_v1_10.mq5                               |
//| Pesquisa XAUUSD: Donchian H1 e execucao/trailing M1              |
//| VERSAO PARA STRATEGY TESTER E DEMO - BLOQUEIA CONTA REAL          |
//| Uma janela por teste; nao modifica o GoldTrendM1 original        |
//+------------------------------------------------------------------+
#property copyright "ALIEN Quant - GoldTrend Research"
#property version   "1.10"
#property strict

#include <Trade/Trade.mqh>

input group "=== MODELO (UMA JANELA POR TESTE) ==="
input int    InpDonchianH1       = 720;     // 192, 288, 480 ou 720 H1
input bool   InpAllowShort       = true;    // Preservar lado vendido do original
input int    InpATRPeriod        = 14;
input double InpStopATR          = 3.0;
input double InpTrailATR         = 7.0;
input int    InpCooldownMinutes  = 120;
input group "=== RISCO / EXECUCAO ==="
input double InpRiskPercent      = 0.25;    // % do saldo por trade; nunca exceder por lote minimo
input double InpCommissionLotRT  = 0.0;     // estimativa na moeda da conta por lote, ida+volta
input double InpMaxSpreadPrice   = 0.80;    // unidades de PRECO do XAUUSD, NAO pontos
input double InpMaxEquityDD      = 10.0;    // pausa entrada, nao liquida posicoes abertas
input double InpDailyLossLimit   = 3.0;     // pausa entrada, nao liquida posicoes abertas
input double InpMaxMarginUsePct  = 50.0;    // margem livre maxima por nova posicao (%)
input int    InpFridayBlockHour  = 21;      // hora servidor; -1 desliga
input int    InpSlippagePoints   = 30;
input long   InpMagicBase        = 880000;  // magic = InpMagicBase + janela
input bool   InpVerbose         = true;

CTrade   g_trade;
int      g_atrHandle = INVALID_HANDLE;
datetime g_lastM1Bar = 0;
datetime g_lastExit = 0;
bool     g_hadPosition = false;
double   g_peakEquity = 0.0;
double   g_dayStartEquity = 0.0;
int      g_dayKey = -1;
string   g_prefix;

long MagicNumber()
{
   return InpMagicBase + InpDonchianH1;
}
string GV(string label)
{
   return g_prefix + "_" + label;
}
void LogText(string txt)
{
   if(InpVerbose) Print("GOLDTREND_TESTER: ", txt);
}
bool ValidInputs()
{
   if(InpDonchianH1!=192 && InpDonchianH1!=288 &&
      InpDonchianH1!=480 && InpDonchianH1!=720) return false;
   if(InpATRPeriod<2 || InpStopATR<=0 || InpTrailATR<=0 ||
      InpRiskPercent<=0 || InpRiskPercent>2.0 ||
      InpCommissionLotRT<0 || InpMaxSpreadPrice<0 ||
      InpMaxEquityDD<=0 || InpDailyLossLimit<=0 ||
      InpMaxMarginUsePct<=0 || InpMaxMarginUsePct>100 ||
      InpCooldownMinutes<0 || InpSlippagePoints<0) return false;
   return true;
}
bool TestOrDemo()
{
   if(MQLInfoInteger(MQL_TESTER)!=0) return true;
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL);
}
int TodayKey()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   return (d.year*1000+d.day_of_year);
}
void SaveEquityState()
{
   GlobalVariableSet(GV("peak"),g_peakEquity);
   GlobalVariableSet(GV("day"),(double)g_dayKey);
   GlobalVariableSet(GV("dayeq"),g_dayStartEquity);
}
void UpdateEquityState()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_peakEquity) g_peakEquity=eq;
   int today=TodayKey();
   if(today!=g_dayKey)
   {
      g_dayKey=today;
      g_dayStartEquity=eq;
      LogText("Novo dia, referencia equity="+DoubleToString(eq,2));
   }
   SaveEquityState();
}
bool FindOurPosition(ulong &ticket)
{
   ticket=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong pos=PositionGetTicket(i);
      if(pos==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==MagicNumber())
      {
         ticket=pos;
         return true;
      }
   }
   return false;
}
bool ForeignPositionNetting()
{
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)!=MagicNumber()) return true;
   }
   return false;
}
double MinStopDistance()
{
   long stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   return ((double)MathMax(stopLevel,freezeLevel)+2.0)*_Point;
}
bool EntriesAllowed()
{
   if(!TestOrDemo()) return false;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEquity>0.0 &&
      (g_peakEquity-eq)*100.0/g_peakEquity>=InpMaxEquityDD) return false;
   if(g_dayStartEquity>0.0 &&
      (g_dayStartEquity-eq)*100.0/g_dayStartEquity>=InpDailyLossLimit) return false;
   if(ForeignPositionNetting()) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   if(InpFridayBlockHour>=0 &&
      dt.day_of_week==5 && dt.hour>=InpFridayBlockHour) return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return false;
   if(tick.ask<=0 || tick.bid<=0 || tick.ask<tick.bid) return false;
   if(tick.ask-tick.bid>InpMaxSpreadPrice) return false;
   if(g_lastExit>0 &&
      TimeCurrent()-g_lastExit < InpCooldownMinutes*60) return false;
   return true;
}
double VolumeForRisk(ENUM_ORDER_TYPE type,double openPrice,double stopPrice)
{
   double limitMoney=AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercent/100.0;
   double pnlOneLot=0.0;
   if(limitMoney<=0 ||
      !OrderCalcProfit(type,_Symbol,1.0,openPrice,stopPrice,pnlOneLot) ||
      pnlOneLot>=0.0) return 0.0;

   double lossOneLot=-pnlOneLot+InpCommissionLotRT;
   if(lossOneLot<=0) return 0.0;
   double volMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double volMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(volMin<=0 || volMax<volMin || volStep<=0) return 0.0;
   double units=MathFloor((limitMoney/lossOneLot+1e-9)/volStep);
   double volume=NormalizeDouble(units*volStep,8);
   if(volume<volMin) // nunca eleva risco para forcar lote minimo
   {
      LogText("SEM ORDEM: lote minimo ultrapassa risco. Limite moeda="+DoubleToString(limitMoney,2));
      return 0.0;
   }
   volume=MathMin(volume,volMax);

   double actualPnL=0;
   if(!OrderCalcProfit(type,_Symbol,volume,openPrice,stopPrice,actualPnL))
      return 0.0;
   double worstLoss=-actualPnL + volume*InpCommissionLotRT;
   if(worstLoss>limitMoney+0.01) return 0.0;

   double margin=0.0;
   if(!OrderCalcMargin(type,_Symbol,volume,openPrice,margin))
      return 0.0;
   if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*InpMaxMarginUsePct/100.0)
      return 0.0;
   return volume;
}
void TrailOurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   if(!GlobalVariableCheck(GV("trail")))
   {
      LogText("Trailing pausado: distancia persistida ausente. Nao inventar ATR novo.");
      return;
   }
   double trailDist=GlobalVariableGet(GV("trail"));
   if(trailDist<=0) return;

   double highClosed=iHigh(_Symbol,PERIOD_M1,1);
   double lowClosed=iLow(_Symbol,PERIOD_M1,1);
   if(highClosed<=0 || lowClosed<=0) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;

   long type=PositionGetInteger(POSITION_TYPE);
   double oldSL=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   double minimal=MinStopDistance();
   double newSL=0;

   if(type==POSITION_TYPE_BUY)
   {
      newSL=NormalizeDouble(highClosed-trailDist,_Digits);
      if(newSL<=oldSL+_Point || newSL>=tick.bid-minimal) return;
   }
   else if(type==POSITION_TYPE_SELL)
   {
      newSL=NormalizeDouble(lowClosed+trailDist,_Digits);
      if((oldSL>0 && newSL>=oldSL-_Point) ||
         newSL<=tick.ask+minimal) return;
   }
   else return;

   bool ok=g_trade.PositionModify(ticket,newSL,tp);
   uint rc=g_trade.ResultRetcode();
   if(!ok || rc!=TRADE_RETCODE_DONE)
      LogText("Falha modify SL: retcode="+IntegerToString((int)rc)+" "+g_trade.ResultRetcodeDescription());
}
void TryOpen()
{
   if(Bars(_Symbol,PERIOD_H1)<InpDonchianH1+InpATRPeriod+5)
      return;
   int highest=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,InpDonchianH1,1);
   int lowest =iLowest(_Symbol,PERIOD_H1,MODE_LOW, InpDonchianH1,1);
   if(highest<0 || lowest<0) return;
   double top=iHigh(_Symbol,PERIOD_H1,highest);
   double bottom=iLow(_Symbol,PERIOD_H1,lowest);
   double closeM1=iClose(_Symbol,PERIOD_M1,1);
   if(closeM1<=0 || top<=0 || bottom<=0) return;

   bool buy=(closeM1>top);
   bool sell=(InpAllowShort && closeM1<bottom);
   if(!buy && !sell) return;

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer,true);
   if(CopyBuffer(g_atrHandle,0,1,1,atrBuffer)!=1) return;
   double currentATR=atrBuffer[0];
   if(currentATR<=0) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   double spread=tick.ask-tick.bid;
   double distance=MathMax(InpStopATR*currentATR,spread+MinStopDistance());
   double trailingDistance=InpTrailATR*currentATR;

   ENUM_ORDER_TYPE typ=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double entry=buy?tick.ask:tick.bid;
   double stop=NormalizeDouble(buy?entry-distance:entry+distance,_Digits);
   double lots=VolumeForRisk(typ,entry,stop);
   if(lots<=0) return;

   string comment="GTM1_10_"+IntegerToString(InpDonchianH1);
   bool sent=false;
   if(buy) sent=g_trade.Buy(lots,_Symbol,0.0,stop,0.0,comment);
   else    sent=g_trade.Sell(lots,_Symbol,0.0,stop,0.0,comment);
   uint rc=g_trade.ResultRetcode();
   if(!sent || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL) ||
      g_trade.ResultDeal()==0)
   {
      LogText("ORDEM NAO CONFIRMADA: retcode="+IntegerToString((int)rc)+
              " "+g_trade.ResultRetcodeDescription());
      return;
   }
   GlobalVariableSet(GV("trail"),trailingDistance);
   g_hadPosition=true;
   LogText((buy?"BUY ":"SELL ")+DoubleToString(lots,2)+" em "+DoubleToString(entry,_Digits)+
           " SL="+DoubleToString(stop,_Digits)+
           " trailDist="+DoubleToString(trailingDistance,_Digits));
}
int OnInit()
{
   if(_Period!=PERIOD_M1)
   {
      Print("ERRO: anexe ao M1 e use timeframe M1 no testador.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!ValidInputs())
   {
      Print("ERRO: parametros invalidos.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!TestOrDemo())
   {
      Print("BLOQUEADO: esta versao nao opera em conta REAL. Somente Tester ou DEMO.");
      return INIT_FAILED;
   }
   g_prefix="GTM2_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+
            "_"+_Symbol+"_"+IntegerToString(MagicNumber());
   g_atrHandle=iATR(_Symbol,PERIOD_H1,InpATRPeriod);
   if(g_atrHandle==INVALID_HANDLE) return INIT_FAILED;

   g_trade.SetExpertMagicNumber(MagicNumber());
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   bool tester=(MQLInfoInteger(MQL_TESTER)!=0);
   if(tester)
   {
      GlobalVariableDel(GV("peak"));
      GlobalVariableDel(GV("day"));
      GlobalVariableDel(GV("dayeq"));
      GlobalVariableDel(GV("trail"));
      GlobalVariableDel(GV("exit"));
   }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity=eq;
   if(GlobalVariableCheck(GV("peak")))
      g_peakEquity=MathMax(eq,GlobalVariableGet(GV("peak")));
   g_dayKey=TodayKey();
   g_dayStartEquity=eq;
   if(GlobalVariableCheck(GV("day")) && GlobalVariableCheck(GV("dayeq")) &&
      (int)GlobalVariableGet(GV("day"))==g_dayKey)
      g_dayStartEquity=GlobalVariableGet(GV("dayeq"));
   if(GlobalVariableCheck(GV("exit")))
      g_lastExit=(datetime)(long)GlobalVariableGet(GV("exit"));
   SaveEquityState();
   ulong ticket=0;
   g_hadPosition=FindOurPosition(ticket);
   LogText("Pronto, conta DEMO ou tester, janela H1="+IntegerToString(InpDonchianH1)+
           ", magic="+IntegerToString(MagicNumber()));
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_atrHandle!=INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
}
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=MagicNumber()) return;
   long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
   {
      g_lastExit=(datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
      GlobalVariableSet(GV("exit"),(double)g_lastExit);
      GlobalVariableDel(GV("trail"));
      g_hadPosition=false;
      LogText("Saida registrada, cooldown iniciado.");
   }
}
void OnTick()
{
   if(!TestOrDemo()) return;
   datetime bar=iTime(_Symbol,PERIOD_M1,0);
   if(bar<=0 || bar==g_lastM1Bar) return;
   g_lastM1Bar=bar;

   UpdateEquityState();
   ulong ticket=0;
   if(FindOurPosition(ticket))
   {
      g_hadPosition=true;
      TrailOurPosition(ticket);
      return;
   }
   if(g_hadPosition)
   {
      g_lastExit=TimeCurrent();
      GlobalVariableSet(GV("exit"),(double)g_lastExit);
      GlobalVariableDel(GV("trail"));
      g_hadPosition=false;
   }
   if(EntriesAllowed()) TryOpen();
}
//+------------------------------------------------------------------+
