//+------------------------------------------------------------------+
//| ALIEN FORWARD OBSERVADOR V1.00 - SOMENTE COLETA EM CONTA DEMO     |
//| Registra cotacoes recebidas: nao importa Trade.mqh nem opera.    |
//| OBS: OnTick nao garante capturar TODOS os ticks do servidor.     |
//+------------------------------------------------------------------+
#property strict
#property version "1.000"
#property description "ALIEN: coletor passivo Bid/Ask, SOMENTE DEMO, sem ordens."

input bool RestrictToXAU = true;   // Evita usar outro instrumento
input int  MaxDailyFileMB = 64;   // Limite de disco por simbolo e dia
input bool PrintPeriodicStatus = true;

int      fileHandle = INVALID_HANDLE;
string   currentDate = "";
string   currentFile = "";
long     savedToday = 0;
long     savedSession = 0;
bool     dailyLimitReached = false;
datetime lastStatus = 0;

// Transforma data da cotacao recebida em AAAAMMDD (horario do servidor).
string DayStamp(datetime sourceTime)
{
   MqlDateTime dt;
   TimeToStruct(sourceTime,dt);
   return StringFormat("%04d%02d%02d",dt.year,dt.mon,dt.day);
}

void CloseDay()
{
   if(fileHandle == INVALID_HANDLE) return;
   FileFlush(fileHandle);
   FileClose(fileHandle);
   fileHandle=INVALID_HANDLE;
}

bool OpenDay(string day)
{
   CloseDay();
   currentDate=day;
   savedToday=0;
   dailyLimitReached=false;
   currentFile="ALIEN_FORWARD_"+_Symbol+"_"+day+".csv";
   fileHandle=FileOpen(currentFile,
                       FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';');
   if(fileHandle==INVALID_HANDLE)
   {
      Print("ALIEN FORWARD: falhou ao abrir ",currentFile,
            " erro=",GetLastError());
      return false;
   }
   if(FileSize(fileHandle)==0)
   {
      FileWrite(fileHandle,"horario_servidor","time_msc","simbolo",
                "bid","ask","last","volume","volume_real",
                "flags","spread_pts");
      FileFlush(fileHandle);
   }
   FileSeek(fileHandle,0,SEEK_END);
   if(MaxDailyFileMB>0 &&
      FileTell(fileHandle)>=(long)MaxDailyFileMB*1024*1024)
      dailyLimitReached=true;
   Print("ALIEN FORWARD: registrando em MQL5/Files/",currentFile);
   return true;
}

int OnInit()
{
   // Recusa conta REAL e conta CONTEST; nao depende do estado AutoTrading.
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)
      != ACCOUNT_TRADE_MODE_DEMO)
   {
      Print("ALIEN FORWARD: somente em conta DEMO. Nenhuma ordem enviada.");
      return INIT_FAILED;
   }
   if(RestrictToXAU && StringFind(_Symbol,"XAU")<0)
   {
      Print("ALIEN FORWARD: selecione o grafico XAUUSD da conta DEMO.");
      return INIT_FAILED;
   }
   if(MaxDailyFileMB<4 || MaxDailyFileMB>1024)
   {
      Print("ALIEN FORWARD: MaxDailyFileMB precisa estar entre 4 e 1024.");
      return INIT_PARAMETERS_INCORRECT;
   }
   EventSetTimer(5);
   Print("ALIEN FORWARD OBSERVADOR ativado: SOMENTE LEITURA. ",
         "Nao abre, modifica nem fecha trades.");
   Print("IMPORTANTE: CSV registra callbacks OnTick recebidos; ",
         "nao e garantia de feed completo de ticks para backtest.");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || quote.time_msc<=0 ||
      quote.bid<=0.0 || quote.ask<=0.0)
      return;

   string day=DayStamp(quote.time);
   if(day!=currentDate || fileHandle==INVALID_HANDLE)
      if(!OpenDay(day)) return;

   if(dailyLimitReached) return;

   double spreadPts=(quote.ask-quote.bid)/_Point;
   FileWrite(fileHandle,
             TimeToString(quote.time,TIME_DATE|TIME_SECONDS),
             (long)quote.time_msc,_Symbol,
             DoubleToString(quote.bid,_Digits),
             DoubleToString(quote.ask,_Digits),
             DoubleToString(quote.last,_Digits),
             (long)quote.volume,
             DoubleToString(quote.volume_real,2),
             (int)quote.flags,
             DoubleToString(spreadPts,2));
   savedToday++;
   savedSession++;

   // Guardas de espaco e flush em lotes para reduzir trabalho por tick.
   if(savedToday%256==0)
   {
      FileFlush(fileHandle);
      if(MaxDailyFileMB>0 &&
         FileTell(fileHandle)>=(long)MaxDailyFileMB*1024*1024)
      {
         dailyLimitReached=true;
         Print("ALIEN FORWARD: limite diario de ",MaxDailyFileMB,
               " MB atingido. Coleta deste dia pausada; volta no proximo dia.");
      }
   }
}

void OnTimer()
{
   if(fileHandle!=INVALID_HANDLE)
      FileFlush(fileHandle);
   if(PrintPeriodicStatus && TimeCurrent()-lastStatus>=60)
   {
      lastStatus=TimeCurrent();
      Print("ALIEN FORWARD: ",savedToday,
            " cotacoes recebidas hoje; ",savedSession,
            " na sessao; arquivo ",currentFile,
            dailyLimitReached?" [LIMITE DIARIO ATINGIDO]":"");
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   CloseDay();
   Print("ALIEN FORWARD: encerrado; cotacoes gravadas na sessao=",savedSession,
         ". Nenhuma ordem foi enviada.");
}
//+------------------------------------------------------------------+
