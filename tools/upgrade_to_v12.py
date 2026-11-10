# -*- coding: utf-8 -*-
import os
import sys

filepath = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.mq5"

with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

print("Original length:", len(content))

# 1. Update Header and Property
old_header = """//+------------------------------------------------------------------+
//| XAU TICK ALIEN V11.2 GOAT 10K - SESSION + AMD + YELLOW LAB                                 |
//| Tick scalper M1, soft trend scoring, costs, adaptive exits        |
//| LAB MULTISETUP: Sweep+BOS default. PA/OB had weak prior results.|
//| Keep original V10.70 for controlled comparison.                  |
//| V10.89: free-session defaults; sweep and risk checks maintained  |
//| EXPERIMENTAL: DEMO / STRATEGY TESTER ONLY                         |
//| Trading losses are possible. There is no guaranteed profit.      |
//+------------------------------------------------------------------+
#property strict
#property version   "10.88"
#property description "ALIEN V11.2 GOAT 10K LAB - Sweep + BOS Retest, mapa AMD, painel professor, demo\""""

new_header = """//+------------------------------------------------------------------+
//| XAU TICK ALIEN V12 INSTITUTIONAL - GOAT FUNDED TRADER 10K BLINDADO |
//| Arquitetura Quant: Tick scalper M1, SMC + Sweeps                 |
//| 5 Blindagens Ativas: Hard Circuit Breaker, Friday Close, HTF Veto|
//| High-Water Mark Trailing DD Guard, Calibragem de Breakeven Ouro  |
//+------------------------------------------------------------------+
#property strict
#property version   "12.00"
#property description "ALIEN V12 INSTITUTIONAL - Blindagem Total Goat Funded Trader 10K\""""

if old_header in content:
    content = content.replace(old_header, new_header, 1)
    print("Header replaced successfully!")
else:
    print("WARNING: Header exact match not found!")

# 2. Update Input Groups
old_inputs = """input group "=== ALIEN V11.2: MESA PROPRIETARIA ($10K) & META R$ 10.000/MES ==="
input double DailyProfitTargetMoney  = 100.00;  // Meta diaria de lucro em USD (R$ 510/dia = R$ 10.000/mes)
input bool   StopOnDailyProfitTarget = true;   // Ao bater a meta diaria, cessa as operacoes do dia
input bool   EnableFastBreakEven     = true;   // Puxa stop para BE assim que atingir 1.2R (nao devolve lucro)
input double FastBERatio             = 1.20;   // Relacao R para acionar o breakeven rapido

input group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="
input double WeeklyMaxLossMoney = 400.00; // Disjuntor semanal da mesa ($350) // Limite semanal absoluto em USD ($12 maximo)
input double DailyMaxLossMoney = 140.00; // Disjuntor diario da mesa ($150)  // Limite diario absoluto em USD ($4 maximo)
input int    MaxDailyTrades         = 15;    // Teto maximo de trades por dia (evita atrito)
input bool   TradeLondonAndNYOnly   = true;  // Operar apenas 08:00 as 18:00 UTC (Londres + NY)"""

new_inputs = """input group "=== ALIEN V12: MESA PROPRIETARIA ($10K) & BLINDAGEM INSTITUCIONAL ==="
input double DailyProfitTargetMoney   = 100.00; // Meta diaria de lucro em USD (R$ 510/dia = R$ 10.000/mes)
input bool   StopOnDailyProfitTarget  = true;   // Ao bater a meta diaria, cessa as operacoes do dia
input bool   EnableHardCircuitBreaker = true;   // Zera todas as posicoes a mercado se flutuante bater limite
input double DailyMaxLossMoney        = 140.00; // Disjuntor diario da mesa ($140 deixa $60 de folga da Goat)
input double WeeklyMaxLossMoney       = 400.00; // Disjuntor semanal da mesa ($400 maximo)
input int    MaxDailyTrades           = 12;     // Teto maximo de trades por dia (disciplina anti-overtrading)
input bool   TradeLondonAndNYOnly     = true;   // Operar apenas 08:00 as 18:00 UTC (Londres + NY)
input bool   EnableHighWaterMarkGuard = true;   // Trava se devolver lucro a partir do pico de equidade do dia
input double MaxTrailingDDPct         = 1.50;   // Limite de recuo do pico do dia (%)

input group "=== PROTECAO DE FIM DE SEMANA (FRIDAY CLOSE) ==="
input bool   EnableFridayClose        = true;   // Fechar todas as ordens na sexta para evitar Gap
input int    FridayStopTradingHour    = 16;     // Nao abre novas posicoes apos essa hora UTC na sexta
input int    FridayForceCloseMinute   = 45;     // Zera posicoes abertas as 16:45 UTC

input group "=== FILTRO MULTI-TIMEFRAME (HTF VETO ABSOLUTO) ==="
input bool   EnforceStrictHTF         = true;   // VETO: Nao compra se H1 for Baixa, nao vende se H1 for Alta"""

if old_inputs in content:
    content = content.replace(old_inputs, new_inputs, 1)
    print("Inputs replaced successfully!")
else:
    print("WARNING: Inputs exact match not found!")

# 3. Update Gold Breakeven & Trailing Parameters
old_be = """input double BreakEvenAfterPoints  = 12.0;
input double TrailStartPoints      = 22.0;
input double TrailATRMultiplier    = 0.15;
input double RunnerMinTrailPoints  = 10.0; // Minimo para trailing, sujeito ao stop/freeze corretora
input double RunnerLockBufferPts   = 3.0; // Pontos extras acima das taxas estimadas ao mover para BE"""

new_be = """input double BreakEvenAfterPoints  = 60.0; // Ativa BE apos 60 pontos ($0.60 no Ouro - acima do spread)
input double TrailStartPoints      = 90.0; // Inicia Trailing apos 90 pontos ($0.90)
input double TrailATRMultiplier    = 0.15;
input double RunnerMinTrailPoints  = 20.0; // Minimo para trailing, sujeito ao stop/freeze corretora
input double RunnerLockBufferPts   = 5.0;  // Pontos extras ($0.05) acima das taxas estimadas ao mover para BE"""

if old_be in content:
    content = content.replace(old_be, new_be, 1)
    print("BE & Trailing parameters updated successfully!")
else:
    print("WARNING: BE & Trailing exact match not found!")

# 4. Declare dailyPeakEquity
old_decl = """double   dayOpeningEquity = 0.0;
bool     dailyGuardTripped = false;"""

new_decl = """double   dayOpeningEquity = 0.0;
double   dailyPeakEquity = 0.0;
bool     dailyGuardTripped = false;"""

if old_decl in content:
    content = content.replace(old_decl, new_decl, 1)
    print("dailyPeakEquity declared successfully!")

# 5. Insert CloseAllPositionsInstantly function
target_func_point = """bool PreflightOrder(ENUM_ORDER_TYPE side,double vol,double price,double sl,string &why)"""

emergency_funcs = """//+------------------------------------------------------------------+
//| V12 INSTITUTIONAL: FECHAMENTO DE EMERGENCIA E CIRCUIT BREAKER    |
//+------------------------------------------------------------------+
void CloseAllPositionsInstantly(string exitReason)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != ExpertMagic) continue;

      RememberExitReason(ticket, exitReason);
      if(trade.PositionClose(ticket) && IsAcceptedRetcode(trade.ResultRetcode()))
      {
         LogEvent("EMERGENCY_CLOSE", exitReason, PositionGetDouble(POSITION_PROFIT));
         Print("ALIEN V12: Posicao ", ticket, " fechada em emergencia: ", exitReason);
      }
   }
}

void CancelAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != ExpertMagic) continue;
      trade.OrderDelete(ticket);
   }
}

bool PreflightOrder(ENUM_ORDER_TYPE side,double vol,double price,double sl,string &why)"""

if target_func_point in content:
    content = content.replace(target_func_point, emergency_funcs, 1)
    print("Emergency functions inserted successfully!")

# 6. Update RefreshDailyEquityBaseline
old_refresh = """      if(GlobalVariableCheck(key))
         dayOpeningEquity=GlobalVariableGet(key);
      else
      {
         dayOpeningEquity=AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(key,dayOpeningEquity);
      }
      dailyGuardTripped=GlobalVariableCheck(key+"_LOCK");"""

new_refresh = """      if(GlobalVariableCheck(key))
         dayOpeningEquity=GlobalVariableGet(key);
      else
      {
         dayOpeningEquity=AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(key,dayOpeningEquity);
      }
      dailyPeakEquity = MathMax(dayOpeningEquity, AccountInfoDouble(ACCOUNT_EQUITY));
      dailyGuardTripped=GlobalVariableCheck(key+"_LOCK");
   }
   else
   {
      double eqNow = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eqNow > dailyPeakEquity) dailyPeakEquity = eqNow;"""

if old_refresh in content:
    content = content.replace(old_refresh, new_refresh, 1)
    print("RefreshDailyEquityBaseline updated successfully!")

# 7. Update Friday Supervisor Check
old_friday_loc = """   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)
   if(TradeLondonAndNYOnly)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      if(dt.hour < 8 || dt.hour >= 18)
      {
         supervisorMessage = StringFormat("FORA DA JANELA DE ALTA LIQUIDEZ: UTC %02d:%02d (Permitido: 08:00 as 18:00 UTC).",
                                          dt.hour, dt.min);
         return false;
      }
   }"""

new_friday_loc = """   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)
   if(TradeLondonAndNYOnly)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      if(dt.hour < 8 || dt.hour >= 18)
      {
         supervisorMessage = StringFormat("FORA DA JANELA DE ALTA LIQUIDEZ: UTC %02d:%02d (Permitido: 08:00 as 18:00 UTC).",
                                          dt.hour, dt.min);
         return false;
      }
   }

   // V12 INSTITUTIONAL: Bloqueio de novas entradas na Sexta-feira
   if(EnableFridayClose)
   {
      MqlDateTime dtF;
      TimeToStruct(TimeCurrent(), dtF);
      if(dtF.day_of_week == 5 && dtF.hour >= FridayStopTradingHour)
      {
         supervisorMessage = StringFormat("SEXTA-FEIRA: Apos %02d:00 UTC novas operacoes sao bloqueadas para evitar risco de fim de semana.", FridayStopTradingHour);
         return false;
      }
   }"""

if old_friday_loc in content:
    content = content.replace(old_friday_loc, new_friday_loc, 1)
    print("Friday check in supervisor updated successfully!")

# 8. Update OnTick Active Protections
old_ontick = """void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.time_msc <= 0) return;
   if(BeginningOfDay() != statsDayStart) RefreshDailyStats();"""

new_ontick = """void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.time_msc <= 0) return;
   if(BeginningOfDay() != statsDayStart) RefreshDailyStats();

   RefreshDailyEquityBaseline();
   double currentEq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEq > dailyPeakEquity) dailyPeakEquity = currentEq;

   // 1. HARD CIRCUIT BREAKER DE PERDA FLUTUANTE (Mesa Goat $140)
   if(EnableHardCircuitBreaker && DailyMaxLossMoney > 0.0)
   {
      double curLoss = dayOpeningEquity - currentEq;
      if(curLoss >= DailyMaxLossMoney || dailyRealizedNet <= -DailyMaxLossMoney)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("HARD_CIRCUIT_BREAKER_LOSS");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("CIRCUIT BREAKER: Perda -$%.2f >= Teto -$%.2f. Ordens zeradas.", curLoss, DailyMaxLossMoney);
      }
   }

   // 2. HIGH-WATER MARK TRAILING DRAWDOWN GUARD
   if(EnableHighWaterMarkGuard && MaxTrailingDDPct > 0.0 && dailyPeakEquity > dayOpeningEquity)
   {
      double peakDD = (dailyPeakEquity - currentEq) / dailyPeakEquity * 100.0;
      if(peakDD >= MaxTrailingDDPct)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("HIGH_WATER_MARK_PROTECTION");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("TRAILING DD PROTEGIDO: Recuo %.2f%% a partir do pico $%.2f.", peakDD, dailyPeakEquity);
      }
   }

   // 3. FRIDAY WEEKEND-HOLDING GUARD (Protecao de fim de semana)
   if(EnableFridayClose)
   {
      MqlDateTime dtW;
      TimeToStruct(TimeCurrent(), dtW);
      if(dtW.day_of_week == 5)
      {
         if(dtW.hour >= FridayStopTradingHour && dtW.min >= FridayForceCloseMinute)
         {
            CloseAllPositionsInstantly("FRIDAY_WEEKEND_FORCE_CLOSE");
            CancelAllPendingOrders();
            supervisorMessage = "SEXTA-FEIRA: Posicoes zeradas para evitar risco de Gap no fim de semana.";
         }
      }
   }"""

if old_ontick in content:
    content = content.replace(old_ontick, new_ontick, 1)
    print("OnTick active protections added successfully!")

# 9. Update HTF Hard Veto
old_htf = """   if(UseHigherTimeframes)
   {
      if(higherTrendM15==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendH1==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendM15==-direction && higherTrendH1==-direction)
         lastScore-=HTFTrendBonus;
      if(zoneId>0 && zd<=atrPts*ZoneToleranceATR) lastScore+=5;
      lastScore=(int)MathMax(0,MathMin(100,lastScore));
   }"""

new_htf = """   if(UseHigherTimeframes)
   {
      if(EnforceStrictHTF && higherTrendH1 != 0 && higherTrendH1 == -direction)
      {
         lastReason = StringFormat("VETO HTF H1: Direcao %s contraria a tendencia H1 (%s). Bloqueado.",
                                   (direction > 0 ? "COMPRA" : "VENDA"),
                                   (higherTrendH1 > 0 ? "ALTA" : "BAIXA"));
         Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
         return;
      }
      if(higherTrendM15==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendH1==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendM15==-direction && higherTrendH1==-direction)
         lastScore-=HTFTrendBonus;
      if(zoneId>0 && zd<=atrPts*ZoneToleranceATR) lastScore+=5;
      lastScore=(int)MathMax(0,MathMin(100,lastScore));
   }"""

if old_htf in content:
    content = content.replace(old_htf, new_htf, 1)
    print("HTF Hard Veto added successfully!")

# 10. Update names
content = content.replace("ALIEN V11.2 GOAT 10K", "ALIEN V12 INSTITUTIONAL")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Upgrade to V12 complete! New file length:", len(content))
