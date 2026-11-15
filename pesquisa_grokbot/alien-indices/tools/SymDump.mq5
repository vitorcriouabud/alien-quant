#property strict
#property description "Lista simbolos/especificacoes e historico (so no Strategy Tester)."
input string Wanted = "US500,NAS100,USTEC,DE40,GER40,SPX500,US100,NDX100,DAX40,GER30,DE30,US30";
void W(int h,string s){FileWriteString(h,s+"\n");}
void Spec(int h,string s)
{
   SymbolSelect(s,true);
   W(h,StringFormat("SPEC;%s;desc=%s;path=%s;digits=%d;point=%.6f;contract=%.4f;vmin=%.4f;vstep=%.4f;vmax=%.2f;ticksize=%.6f;tickvalue=%.8f;calc=%d;tmode=%d;swapmode=%d;swapL=%.4f;swapS=%.4f;swap3=%d;spread=%d;float=%d;stops=%d;cbase=%s;cprofit=%s;cmargin=%s;margin_init=%.4f;bid=%.5f;ask=%.5f",
      s,SymbolInfoString(s,SYMBOL_DESCRIPTION),SymbolInfoString(s,SYMBOL_PATH),(int)SymbolInfoInteger(s,SYMBOL_DIGITS),SymbolInfoDouble(s,SYMBOL_POINT),
      SymbolInfoDouble(s,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(s,SYMBOL_VOLUME_MIN),SymbolInfoDouble(s,SYMBOL_VOLUME_STEP),SymbolInfoDouble(s,SYMBOL_VOLUME_MAX),
      SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE),(int)SymbolInfoInteger(s,SYMBOL_TRADE_CALC_MODE),(int)SymbolInfoInteger(s,SYMBOL_TRADE_MODE),
      (int)SymbolInfoInteger(s,SYMBOL_SWAP_MODE),SymbolInfoDouble(s,SYMBOL_SWAP_LONG),SymbolInfoDouble(s,SYMBOL_SWAP_SHORT),(int)SymbolInfoInteger(s,SYMBOL_SWAP_ROLLOVER3DAYS),
      (int)SymbolInfoInteger(s,SYMBOL_SPREAD),(int)SymbolInfoInteger(s,SYMBOL_SPREAD_FLOAT),(int)SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),
      SymbolInfoString(s,SYMBOL_CURRENCY_BASE),SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT),SymbolInfoString(s,SYMBOL_CURRENCY_MARGIN),SymbolInfoDouble(s,SYMBOL_MARGIN_INITIAL),
      SymbolInfoDouble(s,SYMBOL_BID),SymbolInfoDouble(s,SYMBOL_ASK)));
   datetime f1=(datetime)SeriesInfoInteger(s,PERIOD_M1,SERIES_SERVER_FIRSTDATE);
   datetime fd=(datetime)SeriesInfoInteger(s,PERIOD_D1,SERIES_SERVER_FIRSTDATE);
   datetime t1=(datetime)SeriesInfoInteger(s,PERIOD_M1,SERIES_FIRSTDATE);
   MqlRates r[]; int n=CopyRates(s,PERIOD_D1,D'2000.01.01',TimeCurrent(),r);
   W(h,StringFormat("HIST;%s;server_first_M1=%s;server_first_D1=%s;local_first_M1=%s;D1_bars=%d;first=%s",s,TimeToString(f1),TimeToString(fd),TimeToString(t1),n,n>0?TimeToString(r[0].time):"-"));
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)){Print("so tester");return INIT_FAILED;}
   int h=FileOpen("symdump.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
   int tot=SymbolsTotal(false);
   W(h,"TOTAL="+IntegerToString(tot)+" time="+TimeToString(TimeCurrent()));
   for(int i=0;i<tot;i++){string s=SymbolName(i,false); W(h,"SYM;"+s+";"+SymbolInfoString(s,SYMBOL_PATH)+";"+SymbolInfoString(s,SYMBOL_DESCRIPTION));}
   string a[]; int k=StringSplit(Wanted,',',a);
   for(int i=0;i<k;i++){ bool ex=false; bool c=SymbolExist(a[i],ex); if(c) Spec(h,a[i]); else W(h,"MISSING;"+a[i]); }
   for(int i=0;i<tot;i++){string s=SymbolName(i,false); string p=SymbolInfoString(s,SYMBOL_PATH); if(StringFind(p,"ndice")>=0||StringFind(p,"ndex")>=0) Spec(h,s);}
   FileClose(h);
   return INIT_SUCCEEDED;
}
void OnTick(){ ExpertRemove(); }
