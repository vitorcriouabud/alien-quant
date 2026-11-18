// GOLDTREND v3.30 - Testador DEMO, hipotese experimental
#property strict
#property version "3.300"
#include <Trade\Trade.mqh>
input bool InpEnableDemoOrders = false;
input double InpRiskPercent = 0.25;
input int InpMaxTradesDay = 1;
input int InpMaxSpreadPoints = 20;
input ulong InpMagic = 2026111830;
CTrade trader;
int e20,e50,e200,adxh,atrh;
datetime lastM5=0;
bool value(int h,double &v) {
  double a[];
  if(CopyBuffer(h,0,1,1,a)!=1) return false;
  v=a[0];
  return MathIsValidNumber(v) && v!=EMPTY_VALUE;
}
int OnInit() {
  if(InpRiskPercent<=0 || InpRiskPercent>0.25) return INIT_PARAMETERS_INCORRECT;
  if(StringFind(_Symbol,"XAUUSD")<0) return INIT_FAILED;
  if(InpEnableDemoOrders && (!MQLInfoInteger(MQL_TESTER) ||
      AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)) return INIT_FAILED;
  trader.SetExpertMagicNumber(InpMagic);
  trader.SetTypeFillingBySymbol(_Symbol);
  e20=iMA(_Symbol,PERIOD_H1,20,0,MODE_EMA,PRICE_CLOSE);
  e50=iMA(_Symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
  e200=iMA(_Symbol,PERIOD_H1,200,0,MODE_EMA,PRICE_CLOSE);
  adxh=iADX(_Symbol,PERIOD_H1,14);
  atrh=iATR(_Symbol,PERIOD_H1,14);
  if(e20==INVALID_HANDLE || e50==INVALID_HANDLE ||
     e200==INVALID_HANDLE || adxh==INVALID_HANDLE || atrh==INVALID_HANDLE) return INIT_FAILED;
  Print("GOLDTREND: estudo DEMO. Nao funciona em conta real.");
  return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) {
  IndicatorRelease(e20); IndicatorRelease(e50); IndicatorRelease(e200);
  IndicatorRelease(adxh); IndicatorRelease(atrh);
}
bool todayLimit() {
  MqlDateTime d; TimeToStruct(TimeCurrent(),d);
  d.hour=0;d.min=0;d.sec=0;
  if(!HistorySelect(StructToTime(d),TimeCurrent())) return true;
  int n=0;
  for(int i=0;i<HistoryDealsTotal();i++) {
    ulong t=HistoryDealGetTicket(i);
    if(t>0 && HistoryDealGetString(t,DEAL_SYMBOL)==_Symbol &&
       (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagic &&
       HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_IN) n++;
  }
  return n>=InpMaxTradesDay;
}
double volume(ENUM_ORDER_TYPE side,double price,double stop) {
  double loss=0,margin=0;
  if(!OrderCalcProfit(side,_Symbol,1.0,price,stop,loss) || loss>=0) return 0;
  double budget=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
  double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  if(step<=0 || minimum<=0) return 0;
  double lots=MathMin(maximum,MathFloor((budget/(-loss))/step)*step);
  lots=NormalizeDouble(lots,8);
  if(lots<minimum) { Print("SEM LOTE: minimo excede risco"); return 0; }
  double check=0;
  if(!OrderCalcProfit(side,_Symbol,lots,price,stop,check) || -check>budget) return 0;
  if(!OrderCalcMargin(side,_Symbol,lots,price,margin)) return 0;
  if(margin>=AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.9) return 0;
  return lots;
}
void OnTick() {
  if(!MQLInfoInteger(MQL_TESTER)) return;
  if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO) return;
  MqlTick t; if(!SymbolInfoTick(_Symbol,t) || t.bid<=0 || t.ask<=t.bid) return;
  MqlDateTime d;TimeToStruct(TimeCurrent(),d);
  if(d.hour<8 || d.hour>18 || d.day_of_week==0 || d.day_of_week==6) return;
  datetime m=iTime(_Symbol,PERIOD_M5,0);
  if(m<=0 || m==lastM5) return;
  double a,b,c,adx,atr;
  if(!value(e20,a)||!value(e50,b)||!value(e200,c)||
     !value(adxh,adx)||!value(atrh,atr)) return;
  MqlRates r5[],r1[];
  ArraySetAsSeries(r5,true);ArraySetAsSeries(r1,true);
  if(CopyRates(_Symbol,PERIOD_M5,1,2,r5)!=2 ||
     CopyRates(_Symbol,PERIOD_H1,1,1,r1)!=1) return;
  double pdh=iHigh(_Symbol,PERIOD_D1,1),pdl=iLow(_Symbol,PERIOD_D1,1);
  if(pdh<=0 || pdl<=0 || atr<=1.5) return;
  lastM5=m;
  bool bull=(adx>25 && a>b && b>c && r1[0].close>c);
  bool bear=(adx>25 && a<b && b<c && r1[0].close<c);
  bool buy=bull && r5[0].close>pdh && r5[1].close<=pdh &&
           r5[0].close-a<2.2*atr;
  bool sell=bear && r5[0].close<pdl && r5[1].close>=pdl &&
            a-r5[0].close<2.2*atr;
  if(!buy && !sell) return;
  PrintFormat("SINAL GoldTrend: %s em %s",buy?"COMPRA":"VENDA",TimeToString(TimeCurrent()));
  if((t.ask-t.bid)/_Point>InpMaxSpreadPoints || todayLimit()) return;
  if(PositionSelect(_Symbol)) return;
  ENUM_ORDER_TYPE side=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
  double entry=buy?t.ask:t.bid;
  double stop=NormalizeDouble(buy?entry-atr:entry+atr,_Digits);
  double target=NormalizeDouble(buy?entry+2*atr:entry-2*atr,_Digits);
  double lots=volume(side,entry,stop);
  if(lots<=0 || !InpEnableDemoOrders) return;
  bool sent=buy?trader.Buy(lots,_Symbol,0.0,stop,target,"GoldTrend DEMO"):
                trader.Sell(lots,_Symbol,0.0,stop,target,"GoldTrend DEMO");
  if(!sent) Print("Ordem recusada: ",trader.ResultRetcodeDescription());
}