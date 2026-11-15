rep('''input int DiagHorizonMinutes = 240;''','''input int DiagHorizonMinutes = 240;
input group "=== V11 FIX (diagnostico ticks reais) ==="
input bool   FixNoManagement   = false; // true = sem break-even e sem trailing (so SL/TP originais)
input double FixMaxSpreadToSL  = 0.0;   // >0: recusa se spread > fracao x distancia do SL
input double FixMinStopATR     = 0.0;   // >0: SL minimo = X * ATR M1 (alvo continua 3R)
input double FixBEAfterR       = 0.0;   // >0: break-even so depois de +X R
input double FixTrailAfterR    = 2.0;   // trailing so depois de +X R (com FixBEAfterR>0)
input double FixTrailDistR     = 1.0;   // distancia do trailing em R (com FixBEAfterR>0)''')
rep('''   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0) tickSz = _Point;
   double stop = direction''','''   if(FixMinStopATR>0.0 && atrPts>0.0) stopPts=MathMax(stopPts,FixMinStopATR*atrPts);
   if(FixMaxSpreadToSL>0.0 && currentSpreadPts>FixMaxSpreadToSL*stopPts)
   {
      lastReason=StringFormat("FIX CUSTO: spread %.0f > %.2f x SL %.0f pts. RECUSADO.",currentSpreadPts,FixMaxSpreadToSL,stopPts);
      return false;
   }
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0) tickSz = _Point;
   double stop = direction''')
rep('''         TimeCurrent()-opened < RunnerMinimumHoldSeconds) continue;''','''         TimeCurrent()-opened < RunnerMinimumHoldSeconds) continue;
      if(FixNoManagement) continue;''')
rep('''      // Cost-aware break-even; never push broker SL away from profit.
      if(gainPts >= trigger)''','''      double fixTrailDist=-1.0;
      if(FixBEAfterR>0.0 && tp>0.0)
      {
         double rPts=MathAbs(tp-entry)/_Point/MathMax(1.0,RiskRewardMultiple);
         trigger=FixBEAfterR*rPts; trailingStart=FixTrailAfterR*rPts; fixTrailDist=FixTrailDistR*rPts;
      }
      // Cost-aware break-even; never push broker SL away from profit.
      if(gainPts >= trigger)''')
rep('''MathMax(RunnerMinTrailPoints, atrPts * trailingDistanceATR));''','''(fixTrailDist>0.0 ? fixTrailDist : MathMax(RunnerMinTrailPoints, atrPts * trailingDistanceATR)));''')
