import os
import re

src_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\preservados\V10_89_ORIGINAL.mq5"
dst_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_SCALPER.mq5"

with open(src_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# 1. Update Header / Description
text = text.replace("ALIEN V10.89", "ALIEN V11 SCALPER")
text = text.replace("ALIEN_V10_89", "ALIEN_V11_SCALPER")

# 2. Modify Defaults for M1 Scalping & Risk Guard
text = re.sub(
    r'input bool\s+OneEntryPerM1Candle\s*=\s*false;',
    'input bool   OneEntryPerM1Candle    = true;  // ON: Maximo 1 entrada por candle M1 (elimina overtrading)',
    text
)
text = re.sub(
    r'input int\s+MaxEntriesPerM1Candle\s*=\s*2;',
    'input int    MaxEntriesPerM1Candle  = 1;     // Maximo 1 trade por setup no candle',
    text
)
text = re.sub(
    r'input int\s+AbsoluteMaxSpreadPts\s*=\s*65;',
    'input int    AbsoluteMaxSpreadPts  = 25;    // Limite rigoroso de spread no Ouro (2.5 pips)',
    text
)
text = re.sub(
    r'input ulong\s+ExpertMagic\s*=\s*802089;',
    'input ulong  ExpertMagic           = 802090; // Magic ALIEN V11',
    text
)
text = re.sub(
    r'input int\s+LossStreakPauseAfter\s*=\s*4;',
    'input int    LossStreakPauseAfter = 3;   // Pausa apos 3 stops consecutivos',
    text
)
text = re.sub(
    r'input int\s+LossStreakPauseSeconds\s*=\s*30;',
    'input int    LossStreakPauseSeconds = 1800; // 30 minutos de pausa para mercado acalmar',
    text
)

# 3. Add New Inputs for Weekly/Daily Money Guard and Session Window
new_inputs = """
input group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="
input double WeeklyMaxLossMoney     = 12.00; // Limite semanal absoluto em USD ($12 maximo)
input double DailyMaxLossMoney      = 4.00;  // Limite diario absoluto em USD ($4 maximo)
input int    MaxDailyTrades         = 15;    // Teto maximo de trades por dia (evita atrito)
input bool   TradeLondonAndNYOnly   = true;  // Operar apenas 08:00 as 18:00 UTC (Londres + NY)
input double MinTrailStepPoints     = 6.0;   // Passo minimo para mover stop (evita spam de modificacao)
"""

text = text.replace('input group "=== LABORATORIO M1 ==="', new_inputs + '\ninput group "=== LABORATORIO M1 ==="')

# 4. Insert Weekly Tracking Variables and Functions
weekly_logic = """
//+------------------------------------------------------------------+
//| ALIEN V11: GESTAO DE CAPITAL SEMANAL E DIARIA                    |
//+------------------------------------------------------------------+
string   weeklyEquityKey = "";
double   weekOpeningEquity = 0.0;
bool     weeklyGuardTripped = false;
double   weeklyRealizedNet = 0.0;
int      weeklyTradeCount = 0;

datetime BeginningOfWeek()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0;
   d.min = 0;
   d.sec = 0;
   datetime dayStart = StructToTime(d);
   int daysFromMonday = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return dayStart - (daysFromMonday * 86400);
}

void RefreshWeeklyEquityBaseline()
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
}

void RefreshWeeklyStats()
{
   weeklyRealizedNet = 0.0;
   weeklyTradeCount = 0;
   datetime weekStart = BeginningOfWeek();
   if(!HistorySelect(weekStart, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != ExpertMagic) continue;

      double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_FEE);
      weeklyRealizedNet += net;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         ++weeklyTradeCount;
   }
}
"""

text = text.replace("void RefreshDailyEquityBaseline()", weekly_logic + "\nvoid RefreshDailyEquityBaseline()")

# 5. Insert the Disjuntor checks in NewEntriesAllowedBySupervisor()
supervisor_needle = "   RefreshDailyEquityBaseline();"
supervisor_checks = """   RefreshDailyEquityBaseline();
   RefreshDailyStats();
   RefreshWeeklyEquityBaseline();
   RefreshWeeklyStats();

   // Disjuntor Semanal ($12)
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

   // Disjuntor Diario ($4)
   if(DailyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = dayOpeningEquity - curEq;
      if(dailyLoss >= DailyMaxLossMoney || dailyRealizedNet <= -DailyMaxLossMoney)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
      }
      if(dailyGuardTripped)
      {
         double curLoss = (dailyLoss > -dailyRealizedNet ? dailyLoss : -dailyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR DIARIO ATIVADO: Perda -$%.2f >= Teto -$%.2f. Pausa ate amanha.",
                                          curLoss, DailyMaxLossMoney);
         return false;
      }
   }

   // Teto Diario de Trades
   if(MaxDailyTrades > 0 && dailyEntryDeals >= MaxDailyTrades)
   {
      supervisorMessage = StringFormat("TETO DIARIO DE TRADES ATINGIDO: %d/%d operacoes realizadas hoje.",
                                       dailyEntryDeals, MaxDailyTrades);
      return false;
   }

   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)
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
"""

text = text.replace(supervisor_needle, supervisor_checks, 1)

# 6. Throttle Server Stop Modifications
# Replace direction * (candidate-sl) < 2.0 * _Point with MinTrailStepPoints * _Point
text = text.replace(
    "direction*(candidate-sl) < 2.0 * _Point",
    "direction*(candidate-sl) < MinTrailStepPoints * _Point"
)
text = text.replace(
    "direction * (candidate-sl) < 2.0*_Point",
    "direction * (candidate-sl) < MinTrailStepPoints * _Point"
)

# 7. Update Dashboard Title
text = text.replace(
    'string r0="ALIEN V11 SCALPER | PROFESSOR DE MERCADO | CONTA DEMO";',
    'string r0="ALIEN V11 SCALPER | PROFESSOR VISUAL & DISJUNTOR $12 | DEMO";'
)

with open(dst_path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"File created successfully at {dst_path}. Size: {len(text)} bytes")
