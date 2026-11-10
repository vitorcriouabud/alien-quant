import os
import re
import subprocess
import shutil

src_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.mq5"
dest_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

with open(src_path, "r", encoding="utf-8") as f:
    code = f.read()

# Update version & description
code = code.replace('#property version   "12.00"', '#property version   "12.10"')
code = code.replace(
    '#property description "ALIEN V12 INSTITUTIONAL - Blindagem Total Goat Funded Trader 10K"',
    '#property description "ALIEN V12.1 INSTITUTIONAL - Blindagem Total Goat 10K + Filtro Nativo Noticias MT5"'
)

# Add News Filter Inputs right after the first group
news_inputs = """input group "=== FILTRO INSTITUCIONAL DE NOTICIAS (USD & HIGH IMPACT) ==="
input bool   EnableNewsFilter        = true;   // Bloqueio automatico por Calendario MT5
input int    NewsMinsBefore          = 15;     // Minutos de bloqueio ANTES da noticia
input int    NewsMinsAfter           = 15;     // Minutos de bloqueio DEPOIS da noticia
input bool   HighImpactNewsOnly      = true;   // Apenas noticias de Alto Impacto (Vermelhas)

"""
code = code.replace('input group "=== PROTECAO DE FIM DE SEMANA (FRIDAY CLOSE) ==="', news_inputs + 'input group "=== PROTECAO DE FIM DE SEMANA (FRIDAY CLOSE) ==="')

# Global news definitions placed before any function
news_impl = """
//+------------------------------------------------------------------+
//| FILTRO NATIVO DE CALENDARIO ECONOMICO MT5 (USD)                  |
//+------------------------------------------------------------------+
datetime lastNewsCheck = 0;
bool     isNewsBlackoutActive = false;
string   currentNewsReason = "Filtro USD Ativo";

bool CheckInstitutionalNewsFilter()
{
   if(!EnableNewsFilter) return false;
   datetime now = TimeCurrent();
   if(now - lastNewsCheck < 30) return isNewsBlackoutActive;
   lastNewsCheck = now;
   
   datetime from = now - (NewsMinsAfter * 60);
   datetime to   = now + (NewsMinsBefore * 60);
   
   MqlCalendarValue values[];
   ResetLastError();
   int count = CalendarValueHistory(values, from, to, NULL, "USD");
   if(count <= 0)
   {
      isNewsBlackoutActive = false;
      currentNewsReason = "Sem noticias USD proximas";
      return false;
   }
   
   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(CalendarEventById(values[i].event_id, event))
      {
         if(!HighImpactNewsOnly || event.importance == CALENDAR_IMPORTANCE_HIGH)
         {
            datetime eventTime = values[i].time;
            long diffSeconds = (long)(eventTime - now);
            long diffMins = diffSeconds / 60;
            
            if(diffMins >= 0 && diffMins <= NewsMinsBefore)
            {
               isNewsBlackoutActive = true;
               currentNewsReason = "BLOQUEIO NOTICIA: " + event.name + " em " + IntegerToString((int)diffMins) + "m";
               return true;
            }
            else if(diffMins < 0 && MathAbs(diffMins) <= NewsMinsAfter)
            {
               isNewsBlackoutActive = true;
               currentNewsReason = "BLOQUEIO POS-NOTICIA: " + event.name + " ha " + IntegerToString((int)MathAbs(diffMins)) + "m";
               return true;
            }
         }
      }
   }
   isNewsBlackoutActive = false;
   currentNewsReason = "Noticias USD normais";
   return false;
}
"""

# Find where functions begin. "int OnInit()" or before Dashboard. Let's find "void Dashboard("
idx = code.find("void Dashboard(")
if idx != -1:
    code = code[:idx] + news_impl + "\n" + code[idx:]

# Insert news check into AlienCanOpen
can_open_check = """   if(CheckInstitutionalNewsFilter())
   {
      lastReason = currentNewsReason;
      return false;
   }
"""
code = code.replace("bool AlienCanOpen()\n{", "bool AlienCanOpen()\n{\n" + can_open_check)

# Fix CSV file open without FILE_COMMON
code = re.sub(
    r'string fileName = "ALIEN_V10_88_"[^;]*;[\s\S]*?else Print\("ALIEN V12 INSTITUTIONAL: nao conseguiu abrir diario CSV[^;]*;',
    '''string fileName = "ALIEN_V12_1_" + _Symbol + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
      logFile = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_SHARE_READ, ';');
      if(logFile != INVALID_HANDLE)
      {
         if(FileSize(logFile) == 0)
            FileWrite(logFile, "time", "symbol", "magic", "event", "details", "value");
         FileSeek(logFile, 0, SEEK_END);
      }''',
    code
)

# Update Dashboard HUD panels[10] to show news status
target_row = 'panels[10] = "ULTIMA LEITURA: " + (StringLen(lastReason)>50 ? StringSubstr(lastReason,0,48)+"..." : lastReason);'
replacement_rows = '''CheckInstitutionalNewsFilter();
   panels[10] = "NOTICIAS: " + (isNewsBlackoutActive ? "[BLOQUEIO] " : "[LIVRE] ") + currentNewsReason;
   panels[11] = "ULTIMA LEITURA: " + (StringLen(lastReason)>40 ? StringSubstr(lastReason,0,38)+"..." : lastReason);'''

code = code.replace(target_row, replacement_rows)

# Replace all name occurrences to V12.1
code = code.replace("ALIEN V12 INSTITUTIONAL", "ALIEN V12.1 INSTITUTIONAL")
code = code.replace("ALIEN_V12_INSTITUTIONAL", "ALIEN_V12_1_INSTITUTIONAL")

with open(dest_path, "w", encoding="utf-8") as f:
    f.write(code)

print("ALIEN_V12_1_INSTITUTIONAL.mq5 gerado com sucesso!")
