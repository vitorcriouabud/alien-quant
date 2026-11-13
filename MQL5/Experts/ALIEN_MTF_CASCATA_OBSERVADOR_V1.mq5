//+------------------------------------------------------------------+
//| ALIEN MTF CASCATA OBSERVADOR V1.00 - XAUUSD / MT5                 |
//| H1 bias -> M15 FVG -> M5 sweep/reclaim -> M1 displacement        |
//| LABORATORIO: somente sinais + CSV; NUNCA envia ordens.           |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "ALIEN MTF Cascata - observador causal e CSV; NAO OPERA"

input group "=== EXPERIMENTO H1 > M15 > M5 > M1 ==="
input bool   InpHardH1Veto            = true; // true=cascata rigida; false=H1 contextual
input int    InpH1SMAPeriod           = 20;   // proxy de tendencia; nao e SMC puro
input double InpH1NeutralPoints       = 0.0;  // banda neutra acima/abaixo da SMA
input int    InpFVGScanM15Bars        = 16;
input double InpMinFVGPoints          = 10.0;
input double InpZoneTolerancePoints   = 8.0;
input int    InpM5LiquidityLookback   = 8;
input double InpSweepMinPoints        = 3.0;
input double InpReclaimMinPoints      = 2.0;
input double InpMinM5WickFraction     = 0.35; // fracao do RANGE, nao do corpo
input double InpMinM1BodyFraction     = 0.55; // fracao do RANGE
input double InpM1BreakMinPoints      = 1.0;
input int    InpConfirmationMinutes   = 4;    // validade apos o fechamento M5

input group "=== CUSTOS E RISCO APENAS HIPOTETICOS ==="
input int    InpMaxSpreadPoints       = 25;
input double InpStopBufferPoints      = 5.0;
input double InpRR                    = 2.0;
input double InpReferenceLot          = 0.01;
input double InpReferenceRiskCap      = 12.50; // em moeda da conta; 0=sem veto

input group "=== PROFESSOR E CSV ==="
input bool   InpEnableCSV             = true;
input bool   InpDrawSignals           = true;
input string InpCSVName               = "ALIEN_MTF_CASCATA_OBSERVADOR_V1.csv";

int      g_csv             = INVALID_HANDLE;
datetime g_lastM5Open      = 0;
datetime g_lastM1Open      = 0;
datetime g_armedAt         = 0;
datetime g_expiresAt       = 0;
datetime g_sweepTime       = 0;
int      g_direction       = 0;
int      g_macroBias       = 0;
double   g_liquidityLevel  = 0.0;
double   g_sweepExtreme    = 0.0;
double   g_zoneLow         = 0.0;
double   g_zoneHigh        = 0.0;
datetime g_zoneFormed      = 0;
string   g_eventId         = "";
int      g_armedCount      = 0;
int      g_confirmedCount  = 0;
int      g_sweepCount      = 0;

// Obtem somente barras FECHADAS. Em arrays series, [0] e a ultima fechada.
bool ClosedBars(const ENUM_TIMEFRAMES timeframe,const int count,MqlRates &bars[])
{
   ArraySetAsSeries(bars,true);
   return (CopyRates(_Symbol,timeframe,1,count,bars)==count);
}

string DirText(const int d)
{
   if(d>0) return "BUY";
   if(d<0) return "SELL";
   return "NEUTRO";
}

void ResetArm()
{
   g_direction=0;
   g_armedAt=0;
   g_expiresAt=0;
   g_sweepTime=0;
   g_liquidityLevel=0.0;
   g_sweepExtreme=0.0;
   g_zoneLow=0.0;
   g_zoneHigh=0.0;
   g_zoneFormed=0;
   g_eventId="";
}

void UpdatePanel(const string reason)
{
   Comment("ALIEN MTF CASCATA V1 | SOMENTE OBSERVACAO\n",
           "Macro H1: ",DirText(g_macroBias),
           " | Veto: ",(InpHardH1Veto?"RIGIDO":"CONTEXTUAL"),"\n",
           "Setup M5: ",DirText(g_direction),
           " | Armados: ",g_armedCount,
           " | Confirmados: ",g_confirmedCount,"\n",
           "Ultima decisao: ",reason,"\n",
           "NENHUMA ORDEM E ENVIADA.");
}

void Journal(const string eventName,const string reason,
             const datetime m1Time=0,const double spreadPts=0.0,
             const double entry=0.0,const double sl=0.0,
             const double tp=0.0,const double riskMoney=0.0)
{
   Print("[ALIEN_MTF] ",eventName," | ",reason,
         " | H1=",DirText(g_macroBias)," | M5=",DirText(g_direction));
   UpdatePanel(eventName+" "+reason);
   if(g_csv==INVALID_HANDLE) return;
   // O campo reason NAO recebe delimitador ';' para nao romper schema CSV.
   double riskPts=(entry>0 && sl>0)?MathAbs(entry-sl)/_Point:0.0;
   FileWrite(g_csv,
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      _Symbol,
      (InpHardH1Veto?"STRICT":"CONTEXT"),
      eventName,reason,DirText(g_direction),DirText(g_macroBias),
      (g_sweepTime>0?TimeToString(g_sweepTime,TIME_DATE|TIME_SECONDS):""),
      DoubleToString(g_liquidityLevel,_Digits),
      (g_zoneFormed>0?TimeToString(g_zoneFormed,TIME_DATE|TIME_SECONDS):""),
      DoubleToString(g_zoneLow,_Digits),DoubleToString(g_zoneHigh,_Digits),
      (m1Time>0?TimeToString(m1Time,TIME_DATE|TIME_SECONDS):""),
      DoubleToString(spreadPts,2),DoubleToString(entry,_Digits),
      DoubleToString(sl,_Digits),DoubleToString(tp,_Digits),
      DoubleToString(InpRR,2),DoubleToString(riskPts,2),
      DoubleToString(riskMoney,2),g_eventId);
   FileFlush(g_csv);
}

// H1 deve estar FECHADO ANTES DO INICIO do candle sweep M5.
// Implementacao direta da SMA para nao confundir handle de iMA com valor.
int H1BiasKnownBefore(const datetime sweepOpen)
{
   MqlRates h1[];
   int needed=InpH1SMAPeriod+5;
   if(!ClosedBars(PERIOD_H1,needed,h1)) return 0;
   int start=-1;
   for(int j=0;j<needed;j++)
   {
      if(h1[j].time+PeriodSeconds(PERIOD_H1)<=sweepOpen)
      {
         start=j;
         break;
      }
   }
   if(start<0 || start+InpH1SMAPeriod>needed) return 0;
   double sum=0.0;
   for(int j=start;j<start+InpH1SMAPeriod;j++) sum+=h1[j].close;
   double sma=sum/(double)InpH1SMAPeriod;
   double delta=h1[start].close-sma;
   if(delta> InpH1NeutralPoints*_Point) return 1;
   if(delta< -InpH1NeutralPoints*_Point) return -1;
   return 0;
}

// Varredura OBJETIVA do ultimo M5 fechado sobre extremos de candles anteriores.
// Calcula o alvo de liquidez ANTES da vela testada, sem shift 0.
int DetectM5Sweep(double &level,double &extreme,datetime &sweepOpen,
                  double &sweepHigh,double &sweepLow)
{
   MqlRates m5[];
   if(!ClosedBars(PERIOD_M5,InpM5LiquidityLookback+1,m5)) return 0;
   MqlRates s=m5[0];
   double previousLow=m5[1].low;
   double previousHigh=m5[1].high;
   for(int j=2;j<=InpM5LiquidityLookback;j++)
   {
      previousLow=MathMin(previousLow,m5[j].low);
      previousHigh=MathMax(previousHigh,m5[j].high);
   }
   double range=s.high-s.low;
   if(range<=0.0) return 0;
   double lowWick=(MathMin(s.open,s.close)-s.low)/range;
   double highWick=(s.high-MathMax(s.open,s.close))/range;
   bool bull=(s.low<previousLow-InpSweepMinPoints*_Point &&
              s.close>previousLow+InpReclaimMinPoints*_Point &&
              lowWick>=InpMinM5WickFraction);
   bool bear=(s.high>previousHigh+InpSweepMinPoints*_Point &&
              s.close<previousHigh-InpReclaimMinPoints*_Point &&
              highWick>=InpMinM5WickFraction);
   if(bull==bear) return 0; // sem varredura, ou candle ambiguo com duas
   sweepOpen=s.time;
   sweepHigh=s.high;
   sweepLow=s.low;
   level=(bull?previousLow:previousHigh);
   extreme=(bull?s.low:s.high);
   return (bull?1:-1);
}

// POI = FVG de 3 candles M15 fechados, conhecido antes do sweep M5.
// Este primeiro modulo deliberadamente NAO afirma detectar OB/PDH/PDL.
bool FindPriorM15FVG(const int dir,const datetime sweepOpen,
                    const double sweepLow,const double sweepHigh,
                    double &zoneLow,double &zoneHigh,datetime &zoneTime)
{
   MqlRates m15[];
   int count=InpFVGScanM15Bars+3;
   if(!ClosedBars(PERIOD_M15,count,m15)) return false;
   for(int j=0;j<InpFVGScanM15Bars;j++)
   {
      if(m15[j].time+PeriodSeconds(PERIOD_M15)>sweepOpen)
         continue; // FVG nao era conhecido antes do sweep
      double bottom=0.0,top=0.0;
      if(dir==1 && m15[j].low>m15[j+2].high+InpMinFVGPoints*_Point)
      {
         bottom=m15[j+2].high;
         top=m15[j].low;
      }
      else if(dir==-1 && m15[j].high<m15[j+2].low-InpMinFVGPoints*_Point)
      {
         bottom=m15[j].high;
         top=m15[j+2].low;
      }
      else continue;

      bool invalidated=false;
      for(int k=j-1;k>=0;k--)
      {
         // Invalida FVG somente com FECHAMENTO alem da borda oposta.
         if(dir==1 && m15[k].close<bottom) invalidated=true;
         if(dir==-1 && m15[k].close>top) invalidated=true;
      }
      if(invalidated) continue;
      double tol=InpZoneTolerancePoints*_Point;
      bool touched=(sweepLow<=top+tol && sweepHigh>=bottom-tol);
      if(!touched) continue;
      zoneLow=bottom;
      zoneHigh=top;
      zoneTime=m15[j].time+PeriodSeconds(PERIOD_M15);
      return true;
   }
   return false;
}

void ArmFromClosedM5(const datetime newM5Open)
{
   if(g_direction!=0) Journal("EXPIRADO","novo candle M5 antes da confirmacao");
   ResetArm();
   g_macroBias=0;

   double level=0.0,extreme=0.0,hi=0.0,lo=0.0;
   datetime sweepOpen=0;
   int dir=DetectM5Sweep(level,extreme,sweepOpen,hi,lo);
   if(dir==0)
   {
      Journal("ABSTER","M5 sem sweep com reclaim de liquidez anterior");
      return;
   }
   g_sweepCount++;
   g_direction=dir; // Direcao do evento, mesmo que seja vetado
   g_liquidityLevel=level;
   g_sweepExtreme=extreme;
   g_sweepTime=sweepOpen;
   g_eventId=StringFormat("M5_%I64d_%d",(long)sweepOpen,dir);
   g_macroBias=H1BiasKnownBefore(sweepOpen);
   if(InpHardH1Veto && g_macroBias!=dir)
   {
      Journal("VETO_H1","macro nao autorizou direcao M5");
      ResetArm();
      return;
   }
   if(!FindPriorM15FVG(dir,sweepOpen,lo,hi,g_zoneLow,g_zoneHigh,g_zoneFormed))
   {
      Journal("VETO_M15","sem FVG causal tocado pelo sweep");
      ResetArm();
      return;
   }
   g_armedAt=newM5Open; // APOS fechamento do sweep M5
   g_expiresAt=newM5Open+InpConfirmationMinutes*60;
   g_armedCount++;
   Journal("ARMADO","aguardando vela M1 fechada posterior ao sweep");
}

void DrawConfirmation(const datetime barTime,const double price)
{
   if(!InpDrawSignals) return;
   string name="ALIEN_MTF_"+g_eventId;
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_ARROW,0,barTime,price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,(g_direction>0?233:234));
   ObjectSetInteger(0,name,OBJPROP_COLOR,(g_direction>0?clrLime:clrTomato));
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"ALIEN MTF: sinal hipotetico, sem ordem");
}

void CheckClosedM1Confirmation()
{
   if(g_direction==0) return;
   MqlRates m1[];
   if(!ClosedBars(PERIOD_M1,2,m1))
   {
      Journal("ABSTER_M1","dados M1 fechados indisponiveis");
      return;
   }
   // m1[0] = ultimo candle fechado. Nao aceitar vela do M5 de sweep.
   if(m1[0].time<g_armedAt) return;
   if(m1[0].time>=g_expiresAt)
   {
      Journal("EXPIRADO","janela M1 de confirmacao esgotada",m1[0].time);
      ResetArm();
      return;
   }
   double range=m1[0].high-m1[0].low;
   if(range<=0.0) return;
   double body=MathAbs(m1[0].close-m1[0].open)/range;
   bool directionOk=false;
   if(g_direction==1)
      directionOk=(m1[0].close>m1[0].open &&
                   m1[0].close>m1[1].high+InpM1BreakMinPoints*_Point);
   else
      directionOk=(m1[0].close<m1[0].open &&
                   m1[0].close<m1[1].low-InpM1BreakMinPoints*_Point);
   if(!directionOk || body<InpMinM1BodyFraction)
   {
      Journal("AGUARDAR_M1","sem deslocamento fechado valido",m1[0].time);
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0)
   {
      Journal("VETO_COTACAO","bid ask indisponiveis",m1[0].time);
      return;
   }
   double spreadPoints=(tick.ask-tick.bid)/_Point;
   if(spreadPoints<0.0 || spreadPoints>InpMaxSpreadPoints)
   {
      Journal("VETO_SPREAD","spread acima do limite",m1[0].time,spreadPoints);
      return;
   }
   double entry=(g_direction==1?tick.ask:tick.bid);
   // Buy SL observado pela linha Bid; Sell SL pela Ask.
   double sl=(g_direction==1?
              g_sweepExtreme-InpStopBufferPoints*_Point:
              g_sweepExtreme+(InpStopBufferPoints+spreadPoints)*_Point);
   bool stopValid=(g_direction==1?sl<entry:sl>entry);
   if(!stopValid)
   {
      Journal("VETO_STOP","stop do sweep ficou do lado errado",m1[0].time,spreadPoints,entry,sl);
      ResetArm();
      return;
   }
   double distance=MathAbs(entry-sl);
   double tp=(g_direction==1?entry+InpRR*distance:entry-InpRR*distance);
   double riskMoney=0.0;
   double profitAtStop=0.0;
   ENUM_ORDER_TYPE kind=(g_direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(kind,_Symbol,InpReferenceLot,entry,sl,profitAtStop))
   {
      Journal("VETO_RISCO","OrderCalcProfit indisponivel",m1[0].time,spreadPoints,entry,sl,tp);
      ResetArm();
      return;
   }
   riskMoney=MathAbs(profitAtStop);
   if(InpReferenceRiskCap>0.0 && riskMoney>InpReferenceRiskCap)
   {
      Journal("VETO_RISCO","risco estimado acima do teto de referencia",m1[0].time,spreadPoints,entry,sl,tp,riskMoney);
      ResetArm();
      return;
   }
   g_confirmedCount++;
   Journal("SINAL_CONFIRMADO","hipotese MTF completa SEM enviar ordem",m1[0].time,
           spreadPoints,entry,sl,tp,riskMoney);
   DrawConfirmation(m1[0].time,m1[0].close);
   ResetArm(); // apenas um sinal por evento M5
}

int OnInit()
{
   if(InpH1SMAPeriod<2 || InpFVGScanM15Bars<1 || InpM5LiquidityLookback<2 ||
      InpM1BreakMinPoints<0 || InpRR<=0 || InpReferenceLot<=0 ||
      InpConfirmationMinutes<1 || InpConfirmationMinutes>4 ||
      InpMaxSpreadPoints<=0 || InpMinM5WickFraction<0 ||
      InpMinM5WickFraction>1 || InpMinM1BodyFraction<0 ||
      InpMinM1BodyFraction>1)
   {
      Print("[ALIEN_MTF] Parametros invalidos. Verifique configuracoes.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_lastM5Open=iTime(_Symbol,PERIOD_M5,0);
   g_lastM1Open=iTime(_Symbol,PERIOD_M1,0);
   ResetArm();
   if(InpEnableCSV)
   {
      g_csv=FileOpen(InpCSVName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';');
      if(g_csv==INVALID_HANDLE)
      {
         Print("[ALIEN_MTF] Nao foi possivel abrir CSV: ",InpCSVName," err=",GetLastError());
         return INIT_FAILED;
      }
      if(FileSize(g_csv)==0)
         FileWrite(g_csv,"logged_at","symbol","macro_mode","event","reason","direction",
                   "h1_bias","m5_sweep_open","liquidity_level","fvg_known_at",
                   "fvg_low","fvg_high","m1_confirmation_open","spread_points",
                   "reference_entry","proposed_sl","proposed_tp","rr",
                   "risk_points","risk_reference_currency","event_id");
      FileSeek(g_csv,0,SEEK_END);
   }
   UpdatePanel("monitorando fechamentos M5 e M1");
   Print("[ALIEN_MTF] OBSERVADOR iniciado: nao existe OrderSend ou CTrade neste EA.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_csv!=INVALID_HANDLE)
   {
      FileFlush(g_csv);
      FileClose(g_csv);
   }
   Comment("");
}

void OnTick()
{
   datetime m5Open=iTime(_Symbol,PERIOD_M5,0);
   if(m5Open>0 && g_lastM5Open>0 && m5Open!=g_lastM5Open)
   {
      g_lastM5Open=m5Open; // SEMPRE atualizar, inclusive quando ha veto
      ArmFromClosedM5(m5Open);
   }
   else if(g_lastM5Open==0 && m5Open>0)
      g_lastM5Open=m5Open;

   datetime m1Open=iTime(_Symbol,PERIOD_M1,0);
   if(m1Open>0 && g_lastM1Open>0 && m1Open!=g_lastM1Open)
   {
      g_lastM1Open=m1Open;
      CheckClosedM1Confirmation();
   }
   else if(g_lastM1Open==0 && m1Open>0)
      g_lastM1Open=m1Open;
}
//+------------------------------------------------------------------+
