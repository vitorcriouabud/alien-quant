// ALIEN 12.30: closed-bar, top-down engine. Arrays use index 0 = latest CLOSED bar.
input group "=== CONTEXTO D1 H4 H1 / CONFIRMACAO M15 M5 ==="
input int HTFHistoryBars=100;
input int HTFSweepLookback=10;
input int HTFSetupLifeMinutes=60;
input double HTFDisplacementATR=0.50;
input double HTFStopBufferATR=0.10;

int htfDirection=0,htfStage=0;
datetime htfM5Seen=0,htfM15Seen=0,htfArmedAt=0,htfExpires=0,htfBreakAt=0;
double htfInvalidation=0,htfGapLow=0,htfGapHigh=0,htfZoneLow=0,htfZoneHigh=0;
double htfManagementATR=0;
string htfStatus="Aguardando historico D1/H4/H1/M15/M5";
int htfBars=0,htfAligned=0,htfSweeps=0,htfArms=0,htfBreaks=0,htfRetests=0,htfAttempts=0;

void HTFPrintStats()
{
   Print("HTF_AUDIT bars=",htfBars," aligned=",htfAligned," sweeps=",htfSweeps,
         " arms=",htfArms," bos=",htfBreaks," retests=",htfRetests," attempts=",htfAttempts,
         " last=",htfStatus);
}

bool HTFLoad(ENUM_TIMEFRAMES tf,MqlRates &r[])
{
   ArraySetAsSeries(r,true);
   return CopyRates(_Symbol,tf,1,HTFHistoryBars,r)==HTFHistoryBars;
}

double HTFATR(MqlRates &r[],int start=0)
{
   double sum=0;
   for(int i=start;i<start+14;i++)
      sum+=MathMax(r[i].high-r[i].low,
           MathMax(MathAbs(r[i].high-r[i+1].close),MathAbs(r[i].low-r[i+1].close)));
   return sum/14.0;
}

// Two bars on each side confirm each pivot; the forming candle is never read.
int HTFBias(MqlRates &r[])
{
   double highs[2],lows[2]; int nh=0,nl=0;
   for(int i=2;i<ArraySize(r)-2 && (nh<2 || nl<2);i++)
   {
      if(nh<2 && r[i].high>r[i-1].high && r[i].high>r[i-2].high &&
         r[i].high>r[i+1].high && r[i].high>r[i+2].high) highs[nh++]=r[i].high;
      if(nl<2 && r[i].low<r[i-1].low && r[i].low<r[i-2].low &&
         r[i].low<r[i+1].low && r[i].low<r[i+2].low) lows[nl++]=r[i].low;
   }
   if(nh<2 || nl<2) return 0;
   if(highs[0]>highs[1] && lows[0]>lows[1]) return 1;
   if(highs[0]<highs[1] && lows[0]<lows[1]) return -1;
   return 0;
}

// H1 FVG or displaced opposite candle (OB); reject zones closed through since formation.
bool HTFFindZone(MqlRates &h[],int dir,double eventLow,double eventHigh,
                 double &zoneLow,double &zoneHigh)
{
   double atr=HTFATR(h);
   for(int i=1;i<ArraySize(h)-2;i++)
   {
      for(int kind=0;kind<2;kind++)
      {
         double lo=0,hi=0;
         if(kind==0)
         {
            lo=dir>0?h[i+2].high:h[i].high;
            hi=dir>0?h[i].low:h[i+2].low;
            if(hi-lo<MinFVGPoints*_Point) continue;
            if(dir*(h[i+1].close-h[i+1].open)<HTFDisplacementATR*atr) continue;
         }
         else
         {
            if(dir*(h[i+1].close-h[i+1].open)>=0 ||
               dir*(h[i].close-h[i].open)<HTFDisplacementATR*atr) continue;
            if(dir>0 && h[i].close<=h[i+1].high) continue;
            if(dir<0 && h[i].close>=h[i+1].low) continue;
            lo=h[i+1].low;hi=h[i+1].high;
         }
         bool valid=true;
         for(int j=i-1;j>=0;j--)
            if((dir>0 && h[j].close<lo) || (dir<0 && h[j].close>hi)) {valid=false;break;}
         if(valid && eventLow<=hi && eventHigh>=lo)
         {zoneLow=lo;zoneHigh=hi;return true;}
      }
   }
   return false;
}

void HTFReset(string reason)
{
   htfStage=0;htfStatus=reason;
}

void HTFProcess(const MqlTick &tick)
{
   MqlRates m5[],m15[],d1[],h4[],h1[];
   TickMetrics quiet; ZeroMemory(quiet);
   // Manage SL/BE/trailing every tick, even if context history or entry permission is missing.
   ManageOpenPosition(tick,quiet,htfManagementATR);
   if(htfStage>0 && (TimeCurrent()>=htfExpires ||
      (htfDirection>0 && tick.bid<=htfInvalidation) ||
      (htfDirection<0 && tick.ask>=htfInvalidation)))
      HTFReset("Setup expirou ou perdeu a invalidacao no tick");
   datetime closedM5=iTime(_Symbol,PERIOD_M5,1);
   if(closedM5==0 || closedM5==htfM5Seen) return;
   if(!HTFLoad(PERIOD_M5,m5))
   {htfStatus="Historico M5 indisponivel";return;}
   double atrPts=HTFATR(m5)/_Point;
   htfManagementATR=atrPts;
   if(atrPts<=0 || !HTFLoad(PERIOD_M15,m15) || !HTFLoad(PERIOD_D1,d1) ||
      !HTFLoad(PERIOD_H4,h4) || !HTFLoad(PERIOD_H1,h1))
   {htfStatus="Historico incompleto: novas entradas bloqueadas";return;}
   if(m5[0].time==htfM5Seen) return;
   // Do not replay a historical signal on attachment/restart.
   if(htfM5Seen==0)
   {htfM5Seen=m5[0].time;htfM15Seen=m15[0].time;return;}
   htfM5Seen=m5[0].time;
   htfBars++;
   int daily=HTFBias(d1),four=HTFBias(h4),hour=HTFBias(h1);
   if(daily==0 || daily!=four || daily!=hour)
   {HTFReset("D1/H4/H1 neutros ou divergentes: aguardar alinhamento");return;}
   htfAligned++;
   if(htfStage>0 && (daily!=htfDirection || TimeCurrent()>=htfExpires ||
      (htfDirection>0 && tick.bid<=htfInvalidation) ||
      (htfDirection<0 && tick.ask>=htfInvalidation)))
      HTFReset("Setup expirou ou perdeu a invalidacao");
   htfDirection=daily;
   bool freshM15=m15[0].time!=htfM15Seen;
   htfM15Seen=m15[0].time;
   if(!NewEntriesAllowedBySupervisor() || !AlienSessionEntryAllowed(TimeCurrent()))
   {HTFReset("Sessao/supervisor: "+supervisorMessage);return;}
   if(SymbolHasAnyPosition() || SymbolHasForeignPendingOrders() || MapPendingOrdersCount()>0)
   {HTFReset("Posicao ou pendente existente: sem nova entrada");return;}
   if(freshM15 && htfStage==0)
   {
      double high=m15[1].high,low=m15[1].low;
      for(int i=2;i<=HTFSweepLookback;i++)
      {high=MathMax(high,m15[i].high);low=MathMin(low,m15[i].low);}
      bool sweep=daily>0 ? m15[0].low<low-MinSweepPoints*_Point && m15[0].close>low
                         : m15[0].high>high+MinSweepPoints*_Point && m15[0].close<high;
      double atr15=HTFATR(m15,1);
      if(!sweep || daily*(m15[0].close-m15[0].open)<HTFDisplacementATR*atr15)
      {htfStatus="Contexto alinhado: aguardar varredura e deslocamento M15";return;}
      htfSweeps++;
      if(!HTFFindZone(h1,daily,m15[0].low,m15[0].high,htfZoneLow,htfZoneHigh))
      {htfStatus="Varredura M15 fora de FVG/OB valido H1";return;}
      htfInvalidation=daily>0?m15[0].low:m15[0].high;
      htfArmedAt=m15[0].time+PeriodSeconds(PERIOD_M15);
      htfExpires=htfArmedAt+HTFSetupLifeMinutes*60;
      htfStage=1;htfStatus="M15 confirmou: aguardar BOS com FVG em M5";
      htfArms++;
      LogEvent("HTF_ARM",htfStatus,(double)daily);
      return;
   }
   if(htfStage==0 || m5[0].time<htfArmedAt) return;
   double atr=HTFATR(m5,1);
   if(htfStage==1)
   {
      double level=daily>0?m5[1].high:m5[1].low;
      for(int i=2;i<=5;i++) level=daily>0?MathMax(level,m5[i].high):MathMin(level,m5[i].low);
      bool broke=daily*(m5[0].close-level)>BOSBreakPoints*_Point;
      double lo=daily>0?m5[2].high:m5[0].high;
      double hi=daily>0?m5[0].low:m5[2].low;
      if(!broke || daily*(m5[0].close-m5[0].open)<HTFDisplacementATR*atr ||
         hi-lo<MinFVGPoints*_Point) return;
      htfGapLow=lo;htfGapHigh=hi;htfBreakAt=m5[0].time;
      htfStage=2;htfStatus="BOS M5 fechado: aguardar retorno ao FVG M5";
      htfBreaks++;
      return;
   }
   if(m5[0].time<=htfBreakAt) return;
   if((daily>0 && m5[0].close<htfGapLow) || (daily<0 && m5[0].close>htfGapHigh))
   {HTFReset("FVG M5 invalidado no fechamento");return;}
   double mid=(htfGapLow+htfGapHigh)/2;
   if(m5[0].low>htfGapHigh || m5[0].high<htfGapLow ||
      daily*(m5[0].close-mid)<=0 || daily*(m5[0].close-m5[0].open)<=0) return;
   htfRetests++;
   double spread=(tick.ask-tick.bid)/_Point;
   if(spread>AbsoluteMaxSpreadPts || spread>atrPts*MaxSpreadAsATR ||
      atrPts<MinimumATRPoints || atrPts<spread*MinimumATRToSpread)
   {HTFReset("Retorno confirmado mas spread/volatilidade bloqueou");return;}
   double entry=daily>0?tick.ask:tick.bid;
   // Reject chase after the confirming close and ensure room to H1 opposing liquidity.
   if(MathAbs(entry-m5[0].close)>0.25*atr)
   {HTFReset("Preco afastou do fechamento M5: sem perseguir");return;}
   double invalid=daily>0?MathMin(htfInvalidation,m5[0].low):MathMax(htfInvalidation,m5[0].high);
   invalid-=daily*HTFStopBufferATR*atr;
   double risk=daily*(entry-invalid)+(daily<0?tick.ask-tick.bid:0);
   double target=daily>0?h1[0].high:h1[0].low;
   for(int i=1;i<24;i++) target=daily>0?MathMax(target,h1[i].high):MathMin(target,h1[i].low);
   double minRisk=((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+spread+3)*_Point;
   risk=MathMax(risk,minRisk);
   // SendEntry adds a 0.06 ATR stop buffer; account for it in available room.
   if(daily*(target-entry)<RiskRewardMultiple*(risk+MathMax(2*_Point,0.06*atrPts*_Point)))
   {HTFReset("Liquidez H1 proxima: espaco insuficiente para o alvo em R");return;}
   string key="ALIEN123_USED_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
              IntegerToString((long)ExpertMagic)+"_"+_Symbol;
   if(GlobalVariableCheck(key) && (datetime)GlobalVariableGet(key)>=htfArmedAt)
   {HTFReset("Setup M15 ja consumido");return;}
   GlobalVariableSet(key,(double)htfArmedAt);GlobalVariablesFlush();
   lastSetup=2;lastSetupLevel=invalid;lastScore=100;
   lastOpposingRoomPts=daily*(target-entry)/_Point;
   barStart=iTime(_Symbol,PERIOD_M5,0);
   lastReason="D1/H4/H1 + zona H1 + sweep M15 + BOS/FVG/reteste M5";
   htfAttempts++;
   bool sent=SendEntry(daily,tick,lastScore,spread,atrPts,quiet,quiet,daily,daily,false);
   HTFReset(sent?"Entrada HTF executada; setup consumido":"Entrada bloqueada: "+lastReason);
}
