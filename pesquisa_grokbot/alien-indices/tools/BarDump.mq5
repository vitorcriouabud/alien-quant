#property strict
#property description "Exporta barras D1 e H1 dos indices (so tester)."
input string Syms=".US500Cash,.USTECHCash,.DE40Cash";
int OnInit(){ if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED; return INIT_SUCCEEDED; }
void OnTick(){}
void OnDeinit(const int reason)
{
   string a[]; int k=StringSplit(Syms,',',a);
   for(int i=0;i<k;i++)
   {
      ENUM_TIMEFRAMES tfs[2]={PERIOD_D1,PERIOD_H1}; string nm[2]={"D1","H1"};
      for(int j=0;j<2;j++)
      {
         MqlRates r[]; int n=CopyRates(a[i],tfs[j],D'2015.01.01',TimeCurrent(),r);
         int h=FileOpen("bars_"+a[i]+"_"+nm[j]+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
         FileWrite(h,"time","open","high","low","close","spread","tickvol");
         for(int m=0;m<n;m++) FileWrite(h,TimeToString(r[m].time,TIME_DATE|TIME_MINUTES),r[m].open,r[m].high,r[m].low,r[m].close,r[m].spread,r[m].tick_volume);
         FileClose(h);
         Print(a[i]," ",nm[j]," ",n);
      }
   }
}
