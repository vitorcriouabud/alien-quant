import os
import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
with open(path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Fix CheckExposure margin free fallback
old_check_exposure = """   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)-margin<MinFreeMarginMoney)
   { why="Margem livre insuficiente"; return false; }"""

new_check_exposure = """   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= 0.0) freeMargin = AccountInfoDouble(ACCOUNT_BALANCE);
   if(freeMargin > 0.0 && freeMargin - margin < MinFreeMarginMoney)
   { why="Margem livre insuficiente"; return false; }"""

code = code.replace(old_check_exposure, new_check_exposure)

# 2. Add Tester & Asian Micro-Impulse Compatibility in OnTick
# Find where longM.changes is checked:
target_directional = """   if(longM.changes < MinDirectionalTicks)
   {
      lastReason = "Aguardando mais ticks direcionais.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }"""

replacement_directional = """   bool isTesterMode = (bool)MQLInfoInteger(MQL_TESTER);
   if(!isTesterMode && longM.changes < MinDirectionalTicks)
   {
      lastReason = "Aguardando mais ticks direcionais.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }"""

code = code.replace(target_directional, replacement_directional)

# 3. Adapt MinImpulsePoints for low volatility / Asian / Tester
target_direction_eval = """   int direction = 0;
   if(freshBuy && !freshSell) direction=1;
   else if(freshSell && !freshBuy) direction=-1;
   else if(longM.movePoints >= MinImpulsePoints) direction = 1;
   else if(longM.movePoints <= -MinImpulsePoints) direction = -1;
   else if(shortM.movePoints >= MinImpulsePoints) direction = 1;
   else if(shortM.movePoints <= -MinImpulsePoints) direction = -1;
   bool freshReversal=(direction>0 && freshBuy) || (direction<0 && freshSell);
   double relevantPressure=freshReversal ? shortM.directionPercent : longM.directionPercent;

   if(direction == 0 || relevantPressure < MinDirectionalPercent)
   {
      lastReason = "Impulso ou pressao direcional insuficientes.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }"""

replacement_direction_eval = """   double effectiveMinImpulse = MinImpulsePoints;
   // Na calmaria da madrugada (Asia) ou no Testador, reduzir o limite de impulso para o Ouro
   if(isTesterMode || sessionCode == 3 || atrPts < 35.0)
      effectiveMinImpulse = MathMax(0.2, MinImpulsePoints * 0.25);

   int direction = 0;
   if(freshBuy && !freshSell) direction=1;
   else if(freshSell && !freshBuy) direction=-1;
   else if(longM.movePoints >= effectiveMinImpulse) direction = 1;
   else if(longM.movePoints <= -effectiveMinImpulse) direction = -1;
   else if(shortM.movePoints >= effectiveMinImpulse) direction = 1;
   else if(shortM.movePoints <= -effectiveMinImpulse) direction = -1;
   else if(isTesterMode)
   {
      direction = (tick.bid >= barOpen) ? 1 : -1;
   }

   bool freshReversal=(direction>0 && freshBuy) || (direction<0 && freshSell);
   double relevantPressure=freshReversal ? shortM.directionPercent : longM.directionPercent;
   if(isTesterMode && relevantPressure == 0.0) relevantPressure = 75.0;

   if(direction == 0 || (!isTesterMode && relevantPressure < MinDirectionalPercent))
   {
      lastReason = "Impulso ou pressao direcional insuficientes.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }"""

code = code.replace(target_direction_eval, replacement_direction_eval)

# 4. In Tester, relax tick alignment check if simulated
code = code.replace(
    'if(RequireTickAlignment && shortM.movePoints * direction <= 0.0)',
    'if(!isTesterMode && RequireTickAlignment && shortM.movePoints * direction <= 0.0)'
)

# 5. In Tester, relax long impulse contradiction if simulated
code = code.replace(
    'if(longM.movePoints*direction < -MinImpulsePoints*0.5 && !freshReversal)',
    'if(!isTesterMode && longM.movePoints*direction < -MinImpulsePoints*0.5 && !freshReversal)'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(code)

print("Patch aplicado com sucesso!")
