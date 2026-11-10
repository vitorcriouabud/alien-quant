#ifndef ALIEN_PROFESSOR_CHART_TEACHER_MQH
#define ALIEN_PROFESSOR_CHART_TEACHER_MQH

void APEA_DrawHorizontal(const string name, const double price, const color line_color)
{
   if(price <= 0.0)
   {
      ObjectDelete(0, name);
      return;
   }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void APEA_DrawRectangle(const string name,
                        const datetime start_time,
                        const datetime end_time,
                        const double top,
                        const double bottom,
                        const color fill_color)
{
   if(top <= bottom || start_time <= 0 || end_time <= start_time)
   {
      ObjectDelete(0, name);
      return;
   }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, start_time, top, end_time, bottom);
   else
   {
      ObjectMove(0, name, 0, start_time, top);
      ObjectMove(0, name, 1, end_time, bottom);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, fill_color);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void APEA_RenderTeacher(const APEA_Signal &signal,
                        const MqlRates &rates[],
                        const ENUM_TIMEFRAMES signal_timeframe,
                        const ENUM_TIMEFRAMES context_timeframe,
                        const double minimum_score,
                        const string execution_status)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int seconds = PeriodSeconds(signal_timeframe);
   if(seconds <= 0)
      seconds = 60;

   APEA_DrawHorizontal("APEA_SwingHigh", signal.swing_high, clrIndianRed);
   APEA_DrawHorizontal("APEA_SwingLow", signal.swing_low, clrDodgerBlue);

   datetime future_time = TimeCurrent() + seconds * 20;
   if(signal.fvg_bullish || signal.fvg_bearish)
      APEA_DrawRectangle("APEA_FVG",
                         rates[2].time, future_time,
                         signal.fvg_top, signal.fvg_bottom,
                         signal.fvg_bullish ? clrDarkSeaGreen : clrMistyRose);
   else
      ObjectDelete(0, "APEA_FVG");

   if(signal.order_block_bullish || signal.order_block_bearish)
      APEA_DrawRectangle("APEA_OrderBlock",
                         signal.order_block_time, future_time,
                         signal.order_block_top, signal.order_block_bottom,
                         signal.order_block_bullish ? clrPaleGreen : clrLightSalmon);
   else
      ObjectDelete(0, "APEA_OrderBlock");

   if(signal.valid)
   {
      string arrow_name = "APEA_SignalArrow";
      if(ObjectFind(0, arrow_name) < 0)
         ObjectCreate(0, arrow_name, OBJ_ARROW, 0, signal.confirmed_at, signal.entry);
      else
         ObjectMove(0, arrow_name, 0, signal.confirmed_at, signal.entry);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, signal.direction > 0 ? 233 : 234);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR,
                       signal.direction > 0 ? clrLimeGreen : clrTomato);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
   }
   else
      ObjectDelete(0, "APEA_SignalArrow");

   string local_bias = signal.local_bias > 0 ? "comprador (HH/HL)" :
                       signal.local_bias < 0 ? "vendedor (LH/LL)" : "neutro";
   string context_bias = signal.context_bias > 0 ? "comprador" :
                         signal.context_bias < 0 ? "vendedor" : "neutro";
   string decision = signal.valid ?
                     (signal.direction > 0 ?
                      "CENARIO DE COMPRA (sinal, nao ordem)" :
                      "CENARIO DE VENDA (sinal, nao ordem)") :
                     "SEM SINAL: score abaixo do minimo ou direcoes em conflito";
   string prices = signal.valid ?
                   StringFormat("Entrada teórica %s | stop/invalidação %s | alvo %s",
                                DoubleToString(signal.entry, digits),
                                DoubleToString(signal.stop_loss, digits),
                                DoubleToString(signal.take_profit, digits)) :
                   "Entrada não autorizada: aguardando score mínimo e direção sem conflito.";
   string explanations = signal.reasons == "" ?
                         "Sem confluências confirmadas." : signal.reasons;
   string panel = StringFormat("EA Professor | %s | sinal %s | contexto %s\n%s\nScore compra %.1f / venda %.1f (mín. %.1f)\nContexto %s: %s | viés local: %s\n%s\n%s\nExecucao / resultado da tentativa: %s\nBOS = fechamento alem de swing confirmado; varredura = pavio atravessa e fecha de volta.\nPO3/AMD = heuristica de faixa compacta + varredura + deslocamento; nao prova intencao institucional.",
                              _Symbol, EnumToString(signal_timeframe), EnumToString(context_timeframe),
                              decision, signal.bullish_score, signal.bearish_score, minimum_score,
                              EnumToString(context_timeframe), context_bias, local_bias,
                              prices, explanations, execution_status);
   Comment(panel);
}

void APEA_ClearTeacher()
{
   ObjectsDeleteAll(0, "APEA_");
   Comment("");
}

#endif
