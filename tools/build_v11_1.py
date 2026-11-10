import os
import re

src_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_SCALPER.mq5"
dst_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_1_SNIPER.mq5"

with open(src_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# 1. Update Names & Descriptions
text = text.replace("ALIEN V11 SCALPER", "ALIEN V11.1 SNIPER")
text = text.replace("ALIEN_V11_SCALPER", "ALIEN_V11_1_SNIPER")
text = text.replace("ExpertMagic           = 802090;", "ExpertMagic           = 802091;")

# 2. Add New Inputs
new_sniper_inputs = """
input group "=== ALIEN V11.1: REFINAMENTOS SNIPER ==="
input bool   VetoAgainstBothHTF      = true;  // Bloqueia compras se M15 e H1 forem baixa (e vice-versa)
input bool   FridayEarlyClose        = true;  // Encerra entradas na sexta-feira a tarde
input int    FridayStopHourUTC       = 15;    // Horario limite na sexta (15:00 UTC)
"""

text = text.replace(
    'input group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="',
    new_sniper_inputs + '\ninput group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="'
)

# 3. Add Friday Early Close check in NewEntriesAllowedBySupervisor
supervisor_friday = """
   // Encerramento preventivo na sexta-feira
   if(FridayEarlyClose)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      if(dt.day_of_week == 5 && dt.hour >= FridayStopHourUTC)
      {
         supervisorMessage = StringFormat("SEXTA-FEIRA: Encerramento preventivo as %02d:00 UTC (evita liquidez baixa de fechamento).",
                                          FridayStopHourUTC);
         return false;
      }
   }
"""

text = text.replace(
    '   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)',
    supervisor_friday + '\n   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)'
)

# 4. Add HTF Veto in OnTick right where higherTrend is available
htf_needle = "   if(lastScore < MinimumScore)"
htf_veto = """   // V11.1 Sniper: Veto contra tendencia macro simultanea de M15 e H1
   if(VetoAgainstBothHTF && UseHigherTimeframes)
   {
      if(higherTrendM15 == -direction && higherTrendH1 == -direction)
      {
         lastReason = StringFormat("Veto Macro: contra M15 (%d) e H1 (%d) simultaneos.",
                                   higherTrendM15, higherTrendH1);
         Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
         return;
      }
   }
"""

text = text.replace(htf_needle, htf_veto + "\n" + htf_needle, 1)

with open(dst_path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"File created successfully at {dst_path}. Size: {len(text)} bytes")
