import os
import re
import subprocess
import shutil

mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
with open(mq5_path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Ensure FixedLot defaults to 0.01
code = re.sub(r'input double FixedLot\s*=\s*0\.18;', 'input double FixedLot                 = 0.01;   // Lote base inicial (0.01 seguro para micro/demo; 0.18 para Goat 10K)', code)

# 2. Add proportional scaling in NewEntriesAllowedBySupervisor
old_supervisor = """   // Disjuntor Diario ($140 da mesa Goat)
   if(DailyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = dayOpeningEquity - curEq;
      if(dailyLoss >= DailyMaxLossMoney || dailyRealizedNet <= -DailyMaxLossMoney)"""

new_supervisor = """   // Disjuntor Diario ($140 da mesa Goat; proporcional se banca for pequena < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(effectiveDailyLossLimit > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = dayOpeningEquity - curEq;
      if(dailyLoss >= effectiveDailyLossLimit || dailyRealizedNet <= -effectiveDailyLossLimit)"""

code = code.replace(old_supervisor, new_supervisor)

# Also update the message inside NewEntriesAllowedBySupervisor
code = code.replace(
    'curLoss, DailyMaxLossMoney);',
    'curLoss, effectiveDailyLossLimit);'
)

# 3. Add proportional scaling in ApplyEquityCircuitBreakers
old_breaker = """   // 1. HARD CIRCUIT BREAKER DE PERDA FLUTUANTE (Mesa Goat $140)
   if(EnableHardCircuitBreaker && DailyMaxLossMoney > 0.0)
   {
      double curLoss = dayOpeningEquity - currentEq;
      if(curLoss >= DailyMaxLossMoney || dailyRealizedNet <= -DailyMaxLossMoney || dailyGuardTripped)"""

new_breaker = """   // 1. HARD CIRCUIT BREAKER DE PERDA FLUTUANTE (Mesa Goat $140; proporcional se banca < $100)
   double effectiveDailyLossLimit = DailyMaxLossMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyLossLimit = MathMax(2.50, dayOpeningEquity * 0.25);

   if(EnableHardCircuitBreaker && effectiveDailyLossLimit > 0.0)
   {
      double curLoss = dayOpeningEquity - currentEq;
      if(curLoss >= effectiveDailyLossLimit || dailyRealizedNet <= -effectiveDailyLossLimit || dailyGuardTripped)"""

code = code.replace(old_breaker, new_breaker)

# Also update circuit breaker message
code = code.replace(
    'curLoss, DailyMaxLossMoney);',
    'curLoss, effectiveDailyLossLimit);'
)

# 4. Proportional Target Lock in ApplyEquityCircuitBreakers
old_target = """   // 1.1 DAILY PROFIT TARGET LOCK (Mesa Goat $100 Meta Garantida)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0)
   {
      double currentDailyGain = currentEq - dayOpeningEquity;
      if(currentDailyGain >= DailyProfitTargetMoney || dailyRealizedNet >= DailyProfitTargetMoney)"""

new_target = """   // 1.1 DAILY PROFIT TARGET LOCK (Mesa Goat $100; proporcional se banca < $100)
   double effectiveDailyTarget = DailyProfitTargetMoney;
   if(dayOpeningEquity > 0.0 && dayOpeningEquity < 100.0)
      effectiveDailyTarget = MathMax(1.50, dayOpeningEquity * 0.15);

   if(StopOnDailyProfitTarget && effectiveDailyTarget > 0.0)
   {
      double currentDailyGain = currentEq - dayOpeningEquity;
      if(currentDailyGain >= effectiveDailyTarget || dailyRealizedNet >= effectiveDailyTarget)"""

code = code.replace(old_target, new_target)

with open(mq5_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Patch de proporcionalidade aplicado com sucesso!")
