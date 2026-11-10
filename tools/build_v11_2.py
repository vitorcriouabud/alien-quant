import os
import re

src = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_SCALPER.mq5"
dst = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_2_FREEDOM.mq5"

with open(src, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# 1. Update Names & Descriptions
text = text.replace("ALIEN V11 SCALPER", "ALIEN V11.2 FREEDOM")
text = text.replace("ALIEN_V11_SCALPER", "ALIEN_V11_2_FREEDOM")
text = text.replace("ExpertMagic           = 802090;", "ExpertMagic           = 802092;")

# 2. Add Mesa Proprietaria Inputs and Profit Target
prop_firm_inputs = """
input group "=== ALIEN V11.2: MESA PROPRIETARIA ($10K) & META R$ 10.000/MES ==="
input double DailyProfitTargetMoney  = 90.00;  // Meta diaria de lucro em USD (R$ 510/dia = R$ 10.000/mes)
input bool   StopOnDailyProfitTarget = true;   // Ao bater a meta diaria, cessa as operacoes do dia
input bool   EnableFastBreakEven     = true;   // Puxa stop para BE assim que atingir 1.2R (nao devolve lucro)
input double FastBERatio             = 1.20;   // Relacao R para acionar o breakeven rapido
"""

text = text.replace(
    'input group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="',
    prop_firm_inputs + '\ninput group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="'
)

# 3. Scale all money/lot inputs consistently for 0.20 Lot and $10k Account
text = re.sub(r'input double\s+FixedLot\s*=\s*0\.01;', 'input double FixedLot = 0.20; // Lote proporcional para conta de $10.000', text)
text = re.sub(r'input double\s+MaxAdaptiveLot\s*=\s*0\.02;', 'input double MaxAdaptiveLot = 0.40;', text)
text = re.sub(r'input double\s+RiskStopMoney\s*=\s*2\.00;', 'input double RiskStopMoney = 40.00; // Risco maximo em USD (20 pips)', text)
text = re.sub(r'input double\s+MaxAdaptiveStopRiskMoney\s*=\s*2\.00;', 'input double MaxAdaptiveStopRiskMoney = 50.00;', text)
text = re.sub(r'input double\s+WeeklyMaxLossMoney\s*=\s*12\.00;', 'input double WeeklyMaxLossMoney = 350.00; // Disjuntor semanal da mesa ($350)', text)
text = re.sub(r'input double\s+DailyMaxLossMoney\s*=\s*4\.00;', 'input double DailyMaxLossMoney = 150.00; // Disjuntor diario da mesa ($150)', text)
text = re.sub(r'input double\s+MaxFloatingLossMoney\s*=\s*0\.35;', 'input double MaxFloatingLossMoney = 25.00;', text)
text = re.sub(r'input double\s+PyramidMinProfitMoney\s*=\s*0\.15;', 'input double PyramidMinProfitMoney = 5.00;', text)
text = re.sub(r'input double\s+MinNetProfitToHarvest\s*=\s*0\.02;', 'input double MinNetProfitToHarvest = 1.00;', text)

# 4. Implement Daily Profit Target Check in NewEntriesAllowedBySupervisor
profit_target_check = """
   // Meta Diaria de Lucro (Meta R$ 10.000/mes: $90/dia)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0 && dailyRealizedNet >= DailyProfitTargetMoney)
   {
      supervisorMessage = StringFormat("META DIARIA ATINGIDA: +$%.2f >= +$%.2f (R$ 510 garantidos). Operacoes encerradas hoje com sucesso!",
                                       dailyRealizedNet, DailyProfitTargetMoney);
      return false;
   }
"""

text = text.replace(
    "   // Disjuntor Diario ($4)",
    profit_target_check + "\n   // Disjuntor Diario ($150 da mesa)"
)

# 5. Fast BreakEven logic in CheckTrailAndBE
be_needle = "if(UseAdaptiveRunner && atrPts>0.0)"
be_logic = """
      // V11.2 Freedom: Fast BreakEven em 1.2R
      if(EnableFastBreakEven && sl > 0.0 && tp > 0.0)
      {
         double riskPts = MathAbs(entry - sl) / _Point;
         double gainPts = direction * (quote - entry) / _Point;
         if(riskPts > 1.0 && gainPts >= riskPts * FastBERatio)
         {
            double bePrice = entry + direction * (commissionPts + RunnerLockBufferPts) * _Point;
            if(direction > 0 && (candidate == 0.0 || candidate < bePrice)) candidate = bePrice;
            else if(direction < 0 && (candidate == 0.0 || candidate > bePrice)) candidate = bePrice;
         }
      }
"""
text = text.replace(be_needle, be_logic + "\n      " + be_needle)

# 6. Update Dashboard Title
text = text.replace(
    'string r0="ALIEN V11 SCALPER | PROFESSOR VISUAL & DISJUNTOR $12 | DEMO";',
    'string r0="ALIEN V11.2 FREEDOM | MESA $10K & META R$ 10.000/MES";'
)

with open(dst, "w", encoding="utf-8") as f:
    f.write(text)

print(f"File created successfully at {dst}. Size: {len(text)} bytes")
