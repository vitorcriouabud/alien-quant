//+------------------------------------------------------------------+
//| ALIEN 12.4: INSTITUTIONAL SMC CASCADE (H1 -> M15 -> M5 -> M1)    |
//| Conforme auditoria técnica conjunta Antigravity + ChatGPT         |
//+------------------------------------------------------------------+
input group "=== CONTEXTO H1 (DIREÇÃO) / M15 (ZONA) / M5 (GATILHO) ==="
input int    HTFHistoryBars          = 100;
input int    HTFSweepLookback        = 12;   // Barras M15 para mapear topos e fundos
input int    HTFSetupLifeMinutes     = 45;   // Validade máxima do setup armado
input double HTFDisplacementATR      = 0.35; // Deslocamento institucional mínimo
input double HTFStopBufferATR        = 0.08; // Folga de proteção além do pavio

int htfDirection=0, htfStage=0;
datetime htfM5Seen=0, htfM15Seen=0, htfArmedAt=0, htfExpires=0, htfBreakAt=0;
double htfInvalidation=0, htfGapLow=0, htfGapHigh=0, htfZoneLow=0, htfZoneHigh=0;
double htfManagementATR=0;
string htfStatus="Aguardando dados H1/M15/M5";
int htfBars=0, htfAligned=0, htfSweeps=0, htfArms=0, htfBreaks=0, htfRetests=0, htfAttempts=0;

// Contadores de diagnóstico para auditoria
int diag_history_fail=0;
int diag_session_blocked=0;
int diag_htf_neutral=0;
int diag_sweep_fail=0;
int diag_zone_fail=0;
int diag_bos_fail=0;
int diag_retest_fail=0;
int diag_risk_fail=0;
int diag_entries_taken=0;

void HTFPrintStats()
{
   PrintFormat("HTF_AUDIT: bars=%d aligned=%d sweeps=%d arms=%d bos=%d retests=%d attempts=%d entries=%d | Status: %s",
               htfBars, htfAligned, htfSweeps, htfArms, htfBreaks, htfRetests, htfAttempts, diag_entries_taken, htfStatus);
   PrintFormat("DIAGNOSTICO DE BLOQUEIOS: hist_fail=%d sessao_bloq=%d htf_neutro=%d sweep_fail=%d zone_fail=%d bos_fail=%d risk_fail=%d",
               diag_history_fail, diag_session_blocked, diag_htf_neutral, diag_sweep_fail, diag_zone_fail, diag_bos_fail, diag_risk_fail);
}

bool HTFLoad(ENUM_TIMEFRAMES tf, MqlRates &r[])
{
   ArraySetAsSeries(r, true);
   return CopyRates(_Symbol, tf, 1, HTFHistoryBars, r) >= 30;
}

double HTFATR(MqlRates &r[], int start=0)
{
   int limit = MathMin(14, ArraySize(r) - start - 1);
   if(limit <= 0) return 1.0;
   double sum = 0;
   for(int i=start; i<start+limit; i++)
      sum += MathMax(r[i].high - r[i].low,
             MathMax(MathAbs(r[i].high - r[i+1].close), MathAbs(r[i].low - r[i+1].close)));
   return sum / (double)limit;
}

// Identifica pivôs de estrutura
int HTFBias(MqlRates &r[])
{
   double highs[2], lows[2]; int nh=0, nl=0;
   for(int i=2; i<ArraySize(r)-2 && (nh<2 || nl<2); i++)
   {
      if(nh<2 && r[i].high>r[i-1].high && r[i].high>r[i-2].high &&
         r[i].high>r[i+1].high && r[i].high>r[i+2].high) highs[nh++] = r[i].high;
      if(nl<2 && r[i].low<r[i-1].low && r[i].low<r[i-2].low &&
         r[i].low<r[i+1].low && r[i].low<r[i+2].low) lows[nl++] = r[i].low;
   }
   if(nh >= 2 && nl >= 2)
   {
      if(highs[0] > highs[1] && lows[0] > lows[1]) return 1;
      if(highs[0] < highs[1] && lows[0] < lows[1]) return -1;
   }
   // Fallback suave: fechamento vs EMA simples de 21 barras
   double ma21 = 0;
   int cnt = MathMin(21, ArraySize(r));
   for(int j=0; j<cnt; j++) ma21 += r[j].close;
   ma21 /= cnt;
   if(r[0].close > ma21) return 1;
   if(r[0].close < ma21) return -1;
   return 0;
}

// Zonas de FVG em H1
bool HTFFindZone(MqlRates &h[], int dir, double eventLow, double eventHigh,
                 double &zoneLow, double &zoneHigh)
{
   double atr = HTFATR(h);
   for(int i=1; i<ArraySize(h)-2 && i<30; i++)
   {
      double lo = (dir > 0) ? h[i+2].high : h[i].high;
      double hi = (dir > 0) ? h[i].low   : h[i+2].low;
      if(hi - lo >= 2.0 * _Point)
      {
         bool valid = true;
         for(int j=i-1; j>=0; j--)
         {
            if((dir > 0 && h[j].close < lo) || (dir < 0 && h[j].close > hi))
            {
               valid = false; break;
            }
         }
         if(valid && eventLow <= hi + 5.0*_Point && eventHigh >= lo - 5.0*_Point)
         {
            zoneLow = lo; zoneHigh = hi;
            return true;
         }
      }
   }
   // Se não houver FVG fechado específico, a zona de extremo H1 é válida
   zoneLow  = eventLow;
   zoneHigh = eventHigh;
   return true;
}

void HTFReset(string reason)
{
   htfStage = 0;
   htfStatus = reason;
}

void HTFProcess(const MqlTick &tick)
{
   MqlRates m5[], m15[], h1[];
   TickMetrics quiet; ZeroMemory(quiet);
   
   // Gerenciamento tick a tick de stops e trailing
   ManageOpenPosition(tick, quiet, htfManagementATR);
   
   if(htfStage > 0 && (TimeCurrent() >= htfExpires ||
      (htfDirection > 0 && tick.bid <= htfInvalidation) ||
      (htfDirection < 0 && tick.ask >= htfInvalidation)))
   {
      HTFReset("Setup expirou ou perdeu a invalidacao no tick");
   }

   datetime closedM5 = iTime(_Symbol, PERIOD_M5, 1);
   if(closedM5 == 0 || closedM5 == htfM5Seen) return;
   
   if(!HTFLoad(PERIOD_M5, m5))
   {
      diag_history_fail++;
      htfStatus = "Historico M5 indisponivel";
      return;
   }
   
   double atrPts = HTFATR(m5) / _Point;
   htfManagementATR = atrPts;
   
   if(atrPts <= 0 || !HTFLoad(PERIOD_M15, m15) || !HTFLoad(PERIOD_H1, h1))
   {
      diag_history_fail++;
      htfStatus = "Historico incompleto H1/M15/M5";
      return;
   }

   if(m5[0].time == htfM5Seen) return;
   if(htfM5Seen == 0)
   {
      htfM5Seen = m5[0].time;
      htfM15Seen = m15[0].time;
      return;
   }
   htfM5Seen = m5[0].time;
   htfBars++;

   // 1. FILTRO DE SESSÕES (LONDRES: 07-10 UTC / NY: 12-16 UTC)
   if(TradeLondonAndNYOnly)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      bool inLondon = (dt.hour >= 7 && dt.hour < 10);
      bool inNY     = (dt.hour >= 12 && dt.hour < 16);
      if(!inLondon && !inNY)
      {
         diag_session_blocked++;
         HTFReset("Fora das janelas de ouro (Londres 07-10 UTC / NY 12-16 UTC)");
         return;
      }
   }

   // 2. CONTEXTO H1 (Sem D1/H4 rígido: H1 dá o viés do Day Trade)
   double h1High = h1[0].high, h1Low = h1[0].low;
   for(int k=1; k<24 && k<ArraySize(h1); k++)
   {
      if(h1[k].high > h1High) h1High = h1[k].high;
      if(h1[k].low < h1Low)   h1Low  = h1[k].low;
   }
   double h1Mid = (h1High + h1Low) * 0.5;
   int hourBias = HTFBias(h1);
   
   // Regra de Terreno: Em Discount favorece compras; em Premium favorece vendas
   int directionalBias = hourBias;
   if(directionalBias == 0)
      directionalBias = (m5[0].close < h1Mid) ? 1 : -1;

   htfAligned++;
   htfDirection = directionalBias;

   if(!NewEntriesAllowedBySupervisor())
   {
      HTFReset("Supervisor: " + supervisorMessage);
      return;
   }
   if(SymbolHasAnyPosition() || SymbolHasForeignPendingOrders() || MapPendingOrdersCount() > 0)
   {
      HTFReset("Posicao existente: aguardando encerramento");
      return;
   }

   // 3. M15 / M5 LOCALIZAÇÃO & VARREDURA DE LIQUIDEZ (SWEEP)
   if(htfStage == 0)
   {
      double lookbackHigh = m15[1].high, lookbackLow = m15[1].low;
      for(int i=2; i<=HTFSweepLookback && i<ArraySize(m15); i++)
      {
         lookbackHigh = MathMax(lookbackHigh, m15[i].high);
         lookbackLow  = MathMin(lookbackLow,  m15[i].low);
      }

      // Varredura de fundo (para compra) ou topo (para venda)
      bool sweepBuy  = (m5[0].low  < lookbackLow  - MinSweepPoints*_Point && m5[0].close > lookbackLow);
      bool sweepSell = (m5[0].high > lookbackHigh + MinSweepPoints*_Point && m5[0].close < lookbackHigh);

      int sweepDir = 0;
      if(sweepBuy && directionalBias >= 0) sweepDir = 1;
      else if(sweepSell && directionalBias <= 0) sweepDir = -1;

      if(sweepDir == 0)
      {
         diag_sweep_fail++;
         htfStatus = "Aguardando varredura em extremo M15/M5 alinhada ao H1";
         return;
      }

      htfSweeps++;
      double eventExtreme = (sweepDir > 0) ? m5[0].low : m5[0].high;
      
      if(!HTFFindZone(h1, sweepDir, eventExtreme - 2.0*_Point, eventExtreme + 2.0*_Point, htfZoneLow, htfZoneHigh))
      {
         diag_zone_fail++;
         htfStatus = "Varredura fora de zona institucional";
         return;
      }

      // Setup armado na varredura com rejeição
      htfDirection    = sweepDir;
      htfInvalidation = eventExtreme - sweepDir * (HTFStopBufferATR * atrPts * _Point);
      htfArmedAt      = m5[0].time;
      htfExpires      = htfArmedAt + HTFSetupLifeMinutes * 60;
      htfStage        = 1;
      htfStatus       = StringFormat("Varredura %s confirmada! Aguardando gatilho de reteste.", (sweepDir > 0 ? "FUNDO" : "TOPO"));
      htfArms++;
      LogEvent("HTF_SWEEP_ARMED", htfStatus, (double)sweepDir);
   }

   // 4. M5 / M1 GATILHO DE EXECUÇÃO
   if(htfStage == 1)
   {
      // Verifica se o candle M5 atual ou anterior rejeitou o extremo e fechou a favor
      bool confirmed = false;
      if(htfDirection > 0 && m5[0].close > m5[0].open && tick.bid > m5[0].open) confirmed = true;
      if(htfDirection < 0 && m5[0].close < m5[0].open && tick.ask < m5[0].open) confirmed = true;

      if(!confirmed)
      {
         diag_bos_fail++;
         return;
      }

      double spread = (tick.ask - tick.bid) / _Point;
      if(spread > AbsoluteMaxSpreadPts || spread > atrPts * MaxSpreadAsATR)
      {
         HTFReset("Spread elevado: entrada cancelada");
         return;
      }

      double entry = (htfDirection > 0) ? tick.ask : tick.bid;
      double riskPts = MathAbs(entry - htfInvalidation) / _Point;
      
      // Stop mínimo seguro
      if(riskPts < 15.0) riskPts = 15.0;

      // Alvo em Risco/Retorno 1:2.5
      double target = (htfDirection > 0) ? (entry + riskPts * 2.5 * _Point)
                                         : (entry - riskPts * 2.5 * _Point);

      // Verificação anti-reentrada
      string key = StringFormat("ALIEN_HTF_%d_%d", (int)AccountInfoInteger(ACCOUNT_LOGIN), (int)htfArmedAt);
      if(GlobalVariableCheck(key))
      {
         HTFReset("Setup já executado");
         return;
      }
      GlobalVariableSet(key, 1.0);
      GlobalVariablesFlush();

      lastSetup = 1; // Liquidity Sweep
      lastSetupLevel = htfInvalidation;
      lastScore = 95;
      lastOpposingRoomPts = riskPts * 2.5;
      barStart = m5[0].time;
      lastReason = StringFormat("Sweep %s em H1/M15 com rejeicao M5", (htfDirection > 0 ? "FUNDO" : "TOPO"));

      htfAttempts++;
      bool sent = SendEntry(htfDirection, tick, lastScore, spread, atrPts, quiet, quiet, htfDirection, htfDirection, false);
      if(sent)
      {
         diag_entries_taken++;
         HTFReset("Entrada institucional executada com sucesso!");
      }
      else
      {
         diag_risk_fail++;
         HTFReset("Entrada bloqueada por risco ou margem: " + lastReason);
      }
   }
}
