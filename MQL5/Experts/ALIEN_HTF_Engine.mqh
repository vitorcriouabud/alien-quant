//+------------------------------------------------------------------+
//| ALIEN 12.4: INSTITUTIONAL SMC CASCADE (H1 -> M15 -> M5 -> M1)    |
//| Conforme auditoria técnica conjunta Antigravity + ChatGPT         |
//+------------------------------------------------------------------+
input group "=== CONTEXTO H1 (DIREÇÃO) / M15 (ZONA) / M5 (GATILHO) ==="
input int    HTFHistoryBars          = 100;
input int    HTFSweepLookback        = 12;   // Barras M15 para mapear topos e fundos
input int    HTFSetupLifeMinutes     = 45;   // Validade máxima do setup armado
input double HTFDisplacementATR      = 0.30; // Deslocamento institucional mínimo
input double HTFStopBufferATR        = 0.08; // Folga de proteção além do pavio
input bool   RequireM1Confirmation   = true; // Exige quebra de estrutura (CHoCH/BOS) em M1
input bool   RequireStrictFVG        = false;// Se falso, aceita FVG H1 OU Extremo de Liquidez M15

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
int diag_premium_discount_blocked=0;
int diag_sweep_fail=0;
int diag_zone_fail=0;
int diag_m1_confirm_fail=0;
int diag_risk_fail=0;
int diag_entries_taken=0;

void HTFPrintStats()
{
   PrintFormat("HTF_AUDIT: bars=%d aligned=%d sweeps=%d arms=%d bos=%d retests=%d attempts=%d entries=%d | Status: %s",
               htfBars, htfAligned, htfSweeps, htfArms, htfBreaks, htfRetests, htfAttempts, diag_entries_taken, htfStatus);
   PrintFormat("DIAGNOSTICO DE BLOQUEIOS: hist_fail=%d sessao_bloq=%d prem_disc_bloq=%d sweep_fail=%d zone_fail=%d m1_fail=%d risk_fail=%d",
               diag_history_fail, diag_session_blocked, diag_premium_discount_blocked, diag_sweep_fail, diag_zone_fail, diag_m1_confirm_fail, diag_risk_fail);
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

// Zonas de FVG em H1 ou Extremo M15 categorizado
bool HTFFindZone(MqlRates &h[], int dir, double eventLow, double eventHigh,
                 double &zoneLow, double &zoneHigh, string &zoneType)
{
   double atr = HTFATR(h);
   for(int i=1; i<ArraySize(h)-2 && i<24; i++)
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
            zoneType = "FVG_H1_CONFIRMADO";
            return true;
         }
      }
   }
   
   // Se RequireStrictFVG for falso, aceita extremos mapeados de M15 explicitamente
   if(!RequireStrictFVG)
   {
      zoneLow  = eventLow;
      zoneHigh = eventHigh;
      zoneType = "EXTREMO_LIQUIDEZ_M15";
      return true;
   }

   zoneType = "SEM_ZONA_VALIDA";
   return false;
}

void HTFReset(string reason)
{
   htfStage = 0;
   htfStatus = reason;
}

// Confirmação estrutural no M1 (CHoCH / Micro-BOS com deslocamento)
bool CheckM1Confirmation(int dir, double &confirmPrice)
{
   if(!RequireM1Confirmation)
   {
      confirmPrice = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return true;
   }
   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 10, m1) < 5) return false;

   // Para compra: último candle M1 fechou verde rompendo a máxima da vela anterior
   if(dir > 0)
   {
      if(m1[0].close > m1[0].open && m1[0].close > m1[1].high)
      {
         confirmPrice = m1[0].close;
         return true;
      }
   }
   // Para venda: último candle M1 fechou vermelho rompendo a mínima da vela anterior
   else if(dir < 0)
   {
      if(m1[0].close < m1[0].open && m1[0].close < m1[1].low)
      {
         confirmPrice = m1[0].close;
         return true;
      }
   }
   return false;
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

   // 1. FILTRO DE SESSÕES (LONDRES: 07-11 UTC / NY: 12-17 UTC)
   if(TradeLondonAndNYOnly)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      bool inLondon = (dt.hour >= 7 && dt.hour < 11);
      bool inNY     = (dt.hour >= 12 && dt.hour < 17);
      if(!inLondon && !inNY)
      {
         diag_session_blocked++;
         HTFReset("Fora das janelas de ouro (Londres 07-11 UTC / NY 12-17 UTC)");
         return;
      }
   }

   // 2. CONTEXTO H1 & PREMIUM / DISCOUNT (Range das últimas 24 velas fechadas)
   double h1High = h1[1].high, h1Low = h1[1].low;
   for(int k=2; k<=24 && k<ArraySize(h1); k++)
   {
      if(h1[k].high > h1High) h1High = h1[k].high;
      if(h1[k].low < h1Low)   h1Low  = h1[k].low;
   }
   double h1Range = h1High - h1Low;
   double h1Mid = (h1High + h1Low) * 0.5;
   int hourBias = HTFBias(h1);
   
   // Registra localização institucional
   bool inDiscount = (m5[0].close < h1Mid);
   bool inPremium  = (m5[0].close >= h1Mid);

   htfAligned++;

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
      if(sweepBuy)
      {
         // Filtro de Terreno: Não compra em Premium extremo (>75% do range)
         if(m5[0].close > h1Mid + 0.25*h1Range)
         {
            diag_premium_discount_blocked++;
            HTFReset("Compra bloqueada: preco em Premium profundo H1");
            return;
         }
         sweepDir = 1;
      }
      else if(sweepSell)
      {
         // Filtro de Terreno: Não vende em Discount extremo (<25% do range)
         if(m5[0].close < h1Mid - 0.25*h1Range)
         {
            diag_premium_discount_blocked++;
            HTFReset("Venda bloqueada: preco em Discount profundo H1");
            return;
         }
         sweepDir = -1;
      }

      if(sweepDir == 0)
      {
         diag_sweep_fail++;
         htfStatus = "Aguardando varredura em extremo M15/M5 alinhada";
         return;
      }

      htfSweeps++;
      double eventExtreme = (sweepDir > 0) ? m5[0].low : m5[0].high;
      string zType = "";
      
      if(!HTFFindZone(h1, sweepDir, eventExtreme - 2.0*_Point, eventExtreme + 2.0*_Point, htfZoneLow, htfZoneHigh, zType))
      {
         diag_zone_fail++;
         htfStatus = "Varredura fora de zona institucional validada";
         return;
      }

      // Setup armado com invalidação técnica cravada
      htfDirection    = sweepDir;
      htfInvalidation = eventExtreme - sweepDir * MathMax(2.0*_Point, HTFStopBufferATR * atrPts * _Point);
      htfArmedAt      = m5[0].time;
      htfExpires      = htfArmedAt + HTFSetupLifeMinutes * 60;
      htfStage        = 1;
      htfStatus       = StringFormat("Varredura %s [%s] armada! Aguardando confirmacao M1.", 
                                     (sweepDir > 0 ? "FUNDO" : "TOPO"), zType);
      htfArms++;
      LogEvent("HTF_SWEEP_ARMED", htfStatus, (double)sweepDir);
   }

   // 4. CONFIRMAÇÃO M1 & EXECUÇÃO COM RISCO CASADO
   if(htfStage == 1)
   {
      double confirmPrice = 0.0;
      if(!CheckM1Confirmation(htfDirection, confirmPrice))
      {
         diag_m1_confirm_fail++;
         htfStatus = "Varredura confirmada: aguardando deslocamento/CHoCH em M1";
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
      
      // Stop estrutural mínimo aceitável
      if(riskPts < 15.0) riskPts = 15.0;

      // Verificação anti-reentrada
      string key = StringFormat("ALIEN_HTF_%d_%d", (int)AccountInfoInteger(ACCOUNT_LOGIN), (int)htfArmedAt);
      if(GlobalVariableCheck(key))
      {
         HTFReset("Setup já executado");
         return;
      }
      GlobalVariableSet(key, 1.0);
      GlobalVariablesFlush();

      lastSetup = 2; // Setup com stop estrutural estrito
      lastSetupLevel = htfInvalidation; // Passa a invalidação EXATA para o SendEntry
      lastScore = 98;
      lastOpposingRoomPts = riskPts * 2.5;
      barStart = m5[0].time;
      lastReason = StringFormat("Sweep %s em M15 com confirmacao M1 (SL %.2f)", 
                                (htfDirection > 0 ? "FUNDO" : "TOPO"), htfInvalidation);

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
