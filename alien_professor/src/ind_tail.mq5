
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"ALIEN PROFESSOR");
   Core_Init();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   Core_Deinit();
}
void OnTimer(){ Core_Update(true); }
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   Core_Update(false);
   return(rates_total);
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   EngChartEvent(id,sparam);
}
//+------------------------------------------------------------------+
