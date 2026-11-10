//+------------------------------------------------------------------+
//|                                                Test_Calendar.mq5 |
//+------------------------------------------------------------------+
#property script_show_inputs

void OnStart()
{
   MqlCalendarValue values[];
   datetime from = TimeCurrent() - 86400;
   datetime to   = TimeCurrent() + 86400;
   
   ResetLastError();
   int count = CalendarValueHistory(values, from, to, NULL, "USD");
   Print("TESTE CALENDARIO MT5: count=", count, " Erro=", GetLastError());
   
   if(count > 0)
   {
      for(int i = 0; i < MathMin(count, 5); i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            Print("Evento #", i, ": ", event.name, " | Importancia: ", (int)event.importance, " | Hora: ", TimeToString(values[i].time));
         }
      }
   }
}
