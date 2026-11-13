//+------------------------------------------------------------------+
//| GOAT_XAUUSD_SPREAD_READONLY.mq5                                    |
//| APENAS GOAT INVESTOR / VIEW-ONLY ACCOUNT. NO TRADE INSTRUCTIONS.  |
//| Captura spreads observados do tick da Goat, nao arbitra custo.   |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "ALIEN GOAT: spread collector for official investor view-only"
input int SampleDurationMinutes=30;
input string OutputFileName="GOAT_XAU_SPREAD_READONLY.csv";

int g_file=INVALID_HANDLE;
datetime g_start=0;
long g_lastMsc=-1;
int g_samples=0;

bool IsGoldSymbol()
{
   string upper=_Symbol;
   StringToUpper(upper);
   return StringFind(upper,"XAU")>=0 || StringFind(upper,"GOLD")>=0;
}

bool IsGoatReadOnlyAccount()
{
   string server=AccountInfoString(ACCOUNT_SERVER);
   string company=AccountInfoString(ACCOUNT_COMPANY);
   StringToUpper(server);
   StringToUpper(company);
   bool goat=(StringFind(server,"GOAT")>=0 || StringFind(company,"GOAT")>=0);
   // Sem esta trava, um EA de medicao poderia ser posto na conta de desafio.
   return goat && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)==0;
}

int OnInit()
{
   if(MQLInfoInteger(MQL_TESTER)!=0 ||
      !IsGoldSymbol() || !IsGoatReadOnlyAccount() ||
      SampleDurationMinutes<1 || SampleDurationMinutes>240 ||
      StringFind(OutputFileName,"|")>=0 ||
      StringFind(OutputFileName,"/")>=0 ||
      StringFind(OutputFileName,"\\")>=0)
   {
      Print("GOAT READONLY: requer conta Goat investor (somente leitura),");
      Print("XAUUSD/GOLD e modo fora do Strategy Tester. Nenhuma ordem.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_file=FileOpen(OutputFileName,FILE_READ|FILE_WRITE|FILE_CSV|
                   FILE_ANSI|FILE_SHARE_READ,';');
   if(g_file==INVALID_HANDLE)
   {
      Print("GOAT READONLY: nao abriu CSV ",GetLastError());
      return INIT_FAILED;
   }
   if(FileSize(g_file)==0)
      FileWrite(g_file,
         "observed_local","tick_server","symbol","bid","ask",
         "spread_points","spread_price","point","tick_size","tick_value",
         "contract_size","min_lot","lot_step","stops_level",
         "freeze_level","server","account_trading_disabled");
   FileSeek(g_file,0,SEEK_END);
   g_start=TimeLocal();
   EventSetTimer(1);
   PrintFormat("GOAT READONLY: iniciado, %s, %d min, saida MQL5/Files/%s",
               _Symbol,SampleDurationMinutes,OutputFileName);
   return INIT_SUCCEEDED;
}

void OnTimer()
{
   if(TimeLocal()-g_start>=SampleDurationMinutes*60)
   {
      PrintFormat("GOAT READONLY: %d cotacoes diferentes salvas. Terminado.",g_samples);
      ExpertRemove();return;
   }
   if(g_file==INVALID_HANDLE) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.ask<=q.bid || q.bid<=0) return;
   if((long)q.time_msc==g_lastMsc) return;
   g_lastMsc=(long)q.time_msc;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(point<=0) return;
   FileWrite(g_file,
      TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
      TimeToString((datetime)q.time,TIME_DATE|TIME_SECONDS),
      _Symbol,
      DoubleToString(q.bid,_Digits),DoubleToString(q.ask,_Digits),
      DoubleToString((q.ask-q.bid)/point,2),
      DoubleToString(q.ask-q.bid,_Digits),
      DoubleToString(point,_Digits),
      DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits),
      DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),5),
      DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),2),
      DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),2),
      DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),2),
      IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)),
      IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)),
      AccountInfoString(ACCOUNT_SERVER),
      IntegerToString((int)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)));
   FileFlush(g_file);
   g_samples++;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_file!=INVALID_HANDLE)
   {
      FileFlush(g_file);
      FileClose(g_file);
      g_file=INVALID_HANDLE;
   }
   PrintFormat("GOAT READONLY: coletadas %d cotacoes, sem ordens.",g_samples);
}
//+------------------------------------------------------------------+
