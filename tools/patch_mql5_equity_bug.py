import os
import subprocess
import shutil

TARGET_FILES = [
    r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5",
    r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5",
    r"C:\Goat_MT5_25K\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
]

def patch_file(fpath):
    print(f"Patching {fpath}...")
    with open(fpath, "r", encoding="utf-8") as f:
        code = f.read()

    # 1. Patch RefreshTotalEquityBaseline
    old_total = """void RefreshTotalEquityBaseline()
{
   string key = StringFormat("ALIEN_V12_BASE_%I64d_%s_%I64u",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic);
   if(key != accountStartingEquityKey)
   {
      accountStartingEquityKey = key;
      if(GlobalVariableCheck(key))
      {
         accountStartingEquity = GlobalVariableGet(key);
      }
      else
      {
         accountStartingEquity = AccountInfoDouble(ACCOUNT_BALANCE);
         if(accountStartingEquity <= 0.0)
            accountStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         if(accountStartingEquity <= 0.0)
            accountStartingEquity = 10000.0;
         GlobalVariableSet(key, accountStartingEquity);
      }
      totalGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
}"""

    new_total = """void RefreshTotalEquityBaseline()
{
   string key = StringFormat("ALIEN_V12_BASE_%I64d_%s_%I64u",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic);
   double curBal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(curBal <= 0.0)
      curBal = AccountInfoDouble(ACCOUNT_EQUITY);

   if(key != accountStartingEquityKey)
   {
      accountStartingEquityKey = key;
      double stored = 0.0;
      if(GlobalVariableCheck(key))
         stored = GlobalVariableGet(key);

      if(stored > 1.0)
         accountStartingEquity = stored;
      else if(curBal > 1.0)
      {
         accountStartingEquity = curBal;
         GlobalVariableSet(key, accountStartingEquity);
      }
      else
      {
         accountStartingEquity = 0.0;
      }
      totalGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
   else
   {
      if(accountStartingEquity <= 1.0 && curBal > 1.0)
      {
         accountStartingEquity = curBal;
         GlobalVariableSet(key, accountStartingEquity);
      }
   }
}"""

    if old_total in code:
        code = code.replace(old_total, new_total)
        print("  [x] Total equity baseline patched")
    else:
        print("  [!] Total equity baseline pattern NOT found, skipping or already patched")

    # 2. Patch RefreshWeeklyEquityBaseline
    old_weekly = """void RefreshWeeklyEquityBaseline()
{
   string key = StringFormat("ALIEN_V11_WK_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfWeek());
   if(key != weeklyEquityKey)
   {
      weeklyEquityKey = key;
      if(GlobalVariableCheck(key))
         weekOpeningEquity = GlobalVariableGet(key);
      else
      {
         weekOpeningEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(key, weekOpeningEquity);
      }
      weeklyGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
}"""

    new_weekly = """void RefreshWeeklyEquityBaseline()
{
   string key = StringFormat("ALIEN_V11_WK_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfWeek());
   double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(curEq <= 0.0)
      curEq = AccountInfoDouble(ACCOUNT_BALANCE);

   if(key != weeklyEquityKey)
   {
      weeklyEquityKey = key;
      double stored = 0.0;
      if(GlobalVariableCheck(key))
         stored = GlobalVariableGet(key);

      if(stored > 1.0)
         weekOpeningEquity = stored;
      else if(curEq > 1.0)
      {
         weekOpeningEquity = curEq;
         GlobalVariableSet(key, weekOpeningEquity);
      }
      else
      {
         weekOpeningEquity = 0.0;
      }
      weeklyGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
   else
   {
      if(weekOpeningEquity <= 1.0 && curEq > 1.0)
      {
         weekOpeningEquity = curEq;
         GlobalVariableSet(key, weekOpeningEquity);
      }
   }
}"""

    if old_weekly in code:
        code = code.replace(old_weekly, new_weekly)
        print("  [x] Weekly equity baseline patched")
    else:
        print("  [!] Weekly equity baseline pattern NOT found")

    # 3. Patch RefreshDailyEquityBaseline
    old_daily = """void RefreshDailyEquityBaseline()
{
   string key = StringFormat("ALIEN_V1089_EQ_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfDay());
   if(key != dailyEquityKey)
   {
      dailyEquityKey=key;
      if(GlobalVariableCheck(key))
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
      if(eqNow > dailyPeakEquity) dailyPeakEquity = eqNow;
   }
}"""

    new_daily = """void RefreshDailyEquityBaseline()
{
   string key = StringFormat("ALIEN_V1089_EQ_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfDay());
   double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(curEq <= 0.0)
      curEq = AccountInfoDouble(ACCOUNT_BALANCE);

   if(key != dailyEquityKey)
   {
      dailyEquityKey=key;
      double stored = 0.0;
      if(GlobalVariableCheck(key))
         stored = GlobalVariableGet(key);

      if(stored > 1.0)
         dayOpeningEquity = stored;
      else if(curEq > 1.0)
      {
         dayOpeningEquity = curEq;
         GlobalVariableSet(key, dayOpeningEquity);
         if(GlobalVariableCheck(key + "_PROFIT_LOCK"))
            GlobalVariableDel(key + "_PROFIT_LOCK");
      }
      else
      {
         dayOpeningEquity = 0.0;
      }
      dailyPeakEquity = MathMax(dayOpeningEquity, curEq);
      dailyGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
   else
   {
      if(dayOpeningEquity <= 1.0 && curEq > 1.0)
      {
         dayOpeningEquity = curEq;
         GlobalVariableSet(key, dayOpeningEquity);
         if(GlobalVariableCheck(key + "_PROFIT_LOCK"))
            GlobalVariableDel(key + "_PROFIT_LOCK");
      }
      if(curEq > dailyPeakEquity) dailyPeakEquity = curEq;
   }
}"""

    if old_daily in code:
        code = code.replace(old_daily, new_daily)
        print("  [x] Daily equity baseline patched")
    else:
        print("  [!] Daily equity baseline pattern NOT found")

    # 4. Patch NewEntriesAllowedBySupervisor checks
    old_supervisor = """   // Disjuntor Total da Conta ($200 Hard Stop da Mesa Goat)
   if(TotalMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double totalLoss = accountStartingEquity - curEq;
      if(totalLoss >= TotalMaxLossMoney || totalGuardTripped)
      {
         totalGuardTripped = true;
         GlobalVariableSet(accountStartingEquityKey + "_LOCK", 1.0);
         supervisorMessage = StringFormat("DISJUNTOR TOTAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. Bloqueio permanente de novas ordens.",
                                          totalLoss, TotalMaxLossMoney);
         return false;
      }
   }

   // Disjuntor Semanal ($200)
   if(WeeklyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double weeklyLoss = weekOpeningEquity - curEq;
      if(weeklyLoss >= WeeklyMaxLossMoney || weeklyRealizedNet <= -WeeklyMaxLossMoney)
      {
         weeklyGuardTripped = true;
         GlobalVariableSet(weeklyEquityKey + "_LOCK", 1.0);
      }
      if(weeklyGuardTripped)
      {
         double curLoss = (weeklyLoss > -weeklyRealizedNet ? weeklyLoss : -weeklyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR SEMANAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. Travado ate segunda-feira.",
                                          curLoss, WeeklyMaxLossMoney);
         return false;
      }
   }

   // Meta Diaria de Lucro (Goat $100)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double currentDailyGain = curEq - dayOpeningEquity;
      if(dailyRealizedNet >= DailyProfitTargetMoney || currentDailyGain >= DailyProfitTargetMoney || GlobalVariableCheck(dailyEquityKey + "_PROFIT_LOCK"))
      {
         supervisorMessage = StringFormat("META DIARIA ATINGIDA: +$%.2f >= +$%.2f. Operacoes encerradas hoje com sucesso!",
                                          (currentDailyGain > dailyRealizedNet ? currentDailyGain : dailyRealizedNet), DailyProfitTargetMoney);
         return false;
      }
   }

   // Disjuntor Diario ($140 da mesa Goat; proporcional se banca for pequena < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(effectiveDailyLossLimit > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = dayOpeningEquity - curEq;
      if(dailyLoss >= effectiveDailyLossLimit || dailyRealizedNet <= -effectiveDailyLossLimit)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
      }
      if(dailyGuardTripped)
      {
         double curLoss = (dailyLoss > -dailyRealizedNet ? dailyLoss : -dailyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR DIARIO ATIVADO: Perda -$%.2f >= Teto -$%.2f. Pausa ate amanha.",
                                          curLoss, effectiveDailyLossLimit);
         return false;
      }
   }"""

    new_supervisor = """   // Disjuntor Total da Conta ($200 Hard Stop da Mesa Goat)
   if(TotalMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double totalLoss = (accountStartingEquity > 1.0) ? (accountStartingEquity - curEq) : 0.0;
      if((accountStartingEquity > 1.0 && totalLoss >= TotalMaxLossMoney) || totalGuardTripped)
      {
         totalGuardTripped = true;
         GlobalVariableSet(accountStartingEquityKey + "_LOCK", 1.0);
         supervisorMessage = StringFormat("DISJUNTOR TOTAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. Bloqueio permanente de novas ordens.",
                                          totalLoss, TotalMaxLossMoney);
         return false;
      }
   }

   // Disjuntor Semanal ($200)
   if(WeeklyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double weeklyLoss = (weekOpeningEquity > 1.0) ? (weekOpeningEquity - curEq) : 0.0;
      if((weekOpeningEquity > 1.0 && weeklyLoss >= WeeklyMaxLossMoney) || weeklyRealizedNet <= -WeeklyMaxLossMoney)
      {
         weeklyGuardTripped = true;
         GlobalVariableSet(weeklyEquityKey + "_LOCK", 1.0);
      }
      if(weeklyGuardTripped)
      {
         double curLoss = (weeklyLoss > -weeklyRealizedNet ? weeklyLoss : -weeklyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR SEMANAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. Travado ate segunda-feira.",
                                          curLoss, WeeklyMaxLossMoney);
         return false;
      }
   }

   // Meta Diaria de Lucro (Goat $100)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double currentDailyGain = (dayOpeningEquity > 1.0) ? (curEq - dayOpeningEquity) : 0.0;
      if(dailyRealizedNet >= DailyProfitTargetMoney || (dayOpeningEquity > 1.0 && currentDailyGain >= DailyProfitTargetMoney) || GlobalVariableCheck(dailyEquityKey + "_PROFIT_LOCK"))
      {
         supervisorMessage = StringFormat("META DIARIA ATINGIDA: +$%.2f >= +$%.2f. Operacoes encerradas hoje com sucesso!",
                                          (currentDailyGain > dailyRealizedNet ? currentDailyGain : dailyRealizedNet), DailyProfitTargetMoney);
         return false;
      }
   }

   // Disjuntor Diario ($140 da mesa Goat; proporcional se banca for pequena < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(effectiveDailyLossLimit > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = (dayOpeningEquity > 1.0) ? (dayOpeningEquity - curEq) : 0.0;
      if((dayOpeningEquity > 1.0 && dailyLoss >= effectiveDailyLossLimit) || dailyRealizedNet <= -effectiveDailyLossLimit)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
      }
      if(dailyGuardTripped)
      {
         double curLoss = (dailyLoss > -dailyRealizedNet ? dailyLoss : -dailyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR DIARIO ATIVADO: Perda -$%.2f >= Teto -$%.2f. Pausa ate amanha.",
                                          curLoss, effectiveDailyLossLimit);
         return false;
      }
   }"""

    if old_supervisor in code:
        code = code.replace(old_supervisor, new_supervisor)
        print("  [x] Supervisor checks patched")
    else:
        print("  [!] Supervisor checks pattern NOT found")

    # 5. Patch OnTick circuit breakers
    old_ontick_breakers = """   // 0. TOTAL ACCOUNT LOSS CIRCUIT BREAKER (Mesa Goat $200 Hard Stop)
   if(TotalMaxLossMoney > 0.0)
   {
      double totalLoss = accountStartingEquity - currentEq;
      if(totalLoss >= TotalMaxLossMoney || totalGuardTripped)
      {
         totalGuardTripped = true;
         GlobalVariableSet(accountStartingEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("TOTAL_ACCOUNT_CIRCUIT_BREAKER");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("DISJUNTOR TOTAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. EA TRAVADO PERMANENTEMENTE.", totalLoss, TotalMaxLossMoney);
         return;
      }
   }

   // 1. HARD CIRCUIT BREAKER DE PERDA FLUTUANTE (Mesa Goat $140; proporcional se banca < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(EnableHardCircuitBreaker && effectiveDailyLossLimit > 0.0)
   {
      double curLoss = dayOpeningEquity - currentEq;
      if(curLoss >= effectiveDailyLossLimit || dailyRealizedNet <= -effectiveDailyLossLimit || dailyGuardTripped)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("HARD_CIRCUIT_BREAKER_LOSS");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("CIRCUIT BREAKER: Perda -$%.2f >= Teto -$%.2f. Ordens zeradas.", curLoss, effectiveDailyLossLimit);
      }
   }

   // 1.1 DAILY PROFIT TARGET LOCK (Mesa Goat $100 Meta Garantida)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
   {
      double currentDailyGain = currentEq - dayOpeningEquity;
      if(currentDailyGain >= DailyProfitTargetMoney || dailyRealizedNet >= DailyProfitTargetMoney || GlobalVariableCheck(dailyEquityKey + "_PROFIT_LOCK"))
      {
         GlobalVariableSet(dailyEquityKey + "_PROFIT_LOCK", 1.0);
         if(OurPositionCount() > 0)
         {
            CloseAllPositionsInstantly("DAILY_PROFIT_TARGET_SECURED");
            CancelAllPendingOrders();
         }
         supervisorMessage = StringFormat("META DIARIA GARANTIDA: Lucro +$%.2f >= Meta +$%.2f. Posicoes zeradas e dia encerrado!", 
                                          (currentDailyGain > dailyRealizedNet ? currentDailyGain : dailyRealizedNet), DailyProfitTargetMoney);
      }
   }"""

    new_ontick_breakers = """   // 0. TOTAL ACCOUNT LOSS CIRCUIT BREAKER (Mesa Goat $200 Hard Stop)
   if(TotalMaxLossMoney > 0.0)
   {
      double totalLoss = (accountStartingEquity > 1.0) ? (accountStartingEquity - currentEq) : 0.0;
      if((accountStartingEquity > 1.0 && totalLoss >= TotalMaxLossMoney) || totalGuardTripped)
      {
         totalGuardTripped = true;
         GlobalVariableSet(accountStartingEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("TOTAL_ACCOUNT_CIRCUIT_BREAKER");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("DISJUNTOR TOTAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. EA TRAVADO PERMANENTEMENTE.", totalLoss, TotalMaxLossMoney);
         return;
      }
   }

   // 1. HARD CIRCUIT BREAKER DE PERDA FLUTUANTE (Mesa Goat $140; proporcional se banca < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(EnableHardCircuitBreaker && effectiveDailyLossLimit > 0.0)
   {
      double curLoss = (dayOpeningEquity > 1.0) ? (dayOpeningEquity - currentEq) : 0.0;
      if((dayOpeningEquity > 1.0 && curLoss >= effectiveDailyLossLimit) || dailyRealizedNet <= -effectiveDailyLossLimit || dailyGuardTripped)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
         CloseAllPositionsInstantly("HARD_CIRCUIT_BREAKER_LOSS");
         CancelAllPendingOrders();
         supervisorMessage = StringFormat("CIRCUIT BREAKER: Perda -$%.2f >= Teto -$%.2f. Ordens zeradas.", curLoss, effectiveDailyLossLimit);
      }
   }

   // 1.1 DAILY PROFIT TARGET LOCK (Mesa Goat $100 Meta Garantida)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
   {
      double currentDailyGain = (dayOpeningEquity > 1.0) ? (currentEq - dayOpeningEquity) : 0.0;
      if((dayOpeningEquity > 1.0 && currentDailyGain >= DailyProfitTargetMoney) || dailyRealizedNet >= DailyProfitTargetMoney || GlobalVariableCheck(dailyEquityKey + "_PROFIT_LOCK"))
      {
         GlobalVariableSet(dailyEquityKey + "_PROFIT_LOCK", 1.0);
         if(OurPositionCount() > 0)
         {
            CloseAllPositionsInstantly("DAILY_PROFIT_TARGET_SECURED");
            CancelAllPendingOrders();
         }
         supervisorMessage = StringFormat("META DIARIA GARANTIDA: Lucro +$%.2f >= Meta +$%.2f. Posicoes zeradas e dia encerrado!", 
                                          (currentDailyGain > dailyRealizedNet ? currentDailyGain : dailyRealizedNet), DailyProfitTargetMoney);
      }
   }"""

    if old_ontick_breakers in code:
        code = code.replace(old_ontick_breakers, new_ontick_breakers)
        print("  [x] OnTick circuit breakers patched")
    else:
        print("  [!] OnTick circuit breakers pattern NOT found")

    # 6. Patch OnInit to auto-clean corrupted profit lock
    old_oninit = """   RefreshDailyStats();
   RefreshDailyEquityBaseline();
   if(EnableTelemetry)
      Print("ALIEN V12.1 INSTITUTIONAL: Inicio diario de equity = ",DoubleToString(dayOpeningEquity,2));"""

    new_oninit = """   RefreshDailyStats();
   RefreshDailyEquityBaseline();
   if(GlobalVariableCheck(dailyEquityKey + "_PROFIT_LOCK") && dailyRealizedNet < DailyProfitTargetMoney)
   {
      GlobalVariableDel(dailyEquityKey + "_PROFIT_LOCK");
   }
   if(EnableTelemetry)
      Print("ALIEN V12.1 INSTITUTIONAL: Inicio diario de equity = ",DoubleToString(dayOpeningEquity,2));"""

    if old_oninit in code:
        code = code.replace(old_oninit, new_oninit)
        print("  [x] OnInit auto-clean patched")
    else:
        print("  [!] OnInit auto-clean pattern NOT found")

    with open(fpath, "w", encoding="utf-8") as f:
        f.write(code)
    print(f"Finished {fpath}\n")

for target in TARGET_FILES:
    if os.path.exists(target):
        patch_file(target)
