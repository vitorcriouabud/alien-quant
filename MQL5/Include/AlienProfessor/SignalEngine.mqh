#ifndef ALIEN_PROFESSOR_SIGNAL_ENGINE_MQH
#define ALIEN_PROFESSOR_SIGNAL_ENGINE_MQH

void APEA_AddReason(string &reasons, const string reason)
{
   if(StringLen(reasons) > 0)
      reasons += " | ";
   reasons += reason;
}

bool APEA_BuildSignal(const MqlRates &rates[],
                      const int count,
                      const int context_bias,
                      const double minimum_score,
                      const double reward_risk,
                      const bool require_structure_trigger,
                      APEA_Signal &signal)
{
   signal.valid = false;
   signal.direction = 0;
   signal.confirmed_at = 0;
   signal.entry = 0.0;
   signal.stop_loss = 0.0;
   signal.take_profit = 0.0;
   signal.bullish_score = 0.0;
   signal.bearish_score = 0.0;
   signal.swing_high = 0.0;
   signal.swing_low = 0.0;
   signal.swept_bullish = false;
   signal.swept_bearish = false;
   signal.bos_bullish = false;
   signal.bos_bearish = false;
   signal.engulfing_bullish = false;
   signal.engulfing_bearish = false;
   signal.fvg_bullish = false;
   signal.fvg_bearish = false;
   signal.fvg_top = 0.0;
   signal.fvg_bottom = 0.0;
   signal.order_block_bullish = false;
   signal.order_block_bearish = false;
   signal.order_block_top = 0.0;
   signal.order_block_bottom = 0.0;
   signal.order_block_time = 0;
   signal.amd_bullish = false;
   signal.amd_bearish = false;
   signal.local_bias = 0;
   signal.context_bias = context_bias;
   signal.reasons = "";

   if(count < 20 || reward_risk <= 0.0)
      return false;

   double older_high, older_low;
   int latest_high_index, older_high_index, latest_low_index, older_low_index;
   APEA_FindSwingLevels(rates, count,
                        signal.swing_high, older_high,
                        signal.swing_low, older_low,
                        latest_high_index, older_high_index,
                        latest_low_index, older_low_index);

   signal.swept_bullish = signal.swing_low > 0.0 &&
                          rates[0].low < signal.swing_low &&
                          rates[0].close > signal.swing_low;
   signal.swept_bearish = signal.swing_high > 0.0 &&
                          rates[0].high > signal.swing_high &&
                          rates[0].close < signal.swing_high;
   signal.bos_bullish = signal.swing_high > 0.0 &&
                        rates[0].close > signal.swing_high &&
                        rates[1].close <= signal.swing_high;
   signal.bos_bearish = signal.swing_low > 0.0 &&
                        rates[0].close < signal.swing_low &&
                        rates[1].close >= signal.swing_low;

   signal.engulfing_bullish = rates[0].close > rates[0].open &&
                              rates[1].close < rates[1].open &&
                              rates[0].close >= rates[1].open &&
                              rates[0].open <= rates[1].close;
   signal.engulfing_bearish = rates[0].close < rates[0].open &&
                              rates[1].close > rates[1].open &&
                              rates[0].open >= rates[1].close &&
                              rates[0].close <= rates[1].open;

   signal.fvg_bullish = rates[2].high < rates[0].low;
   signal.fvg_bearish = rates[2].low > rates[0].high;
   if(signal.fvg_bullish)
   {
      signal.fvg_top = rates[0].low;
      signal.fvg_bottom = rates[2].high;
   }
   else if(signal.fvg_bearish)
   {
      signal.fvg_top = rates[2].low;
      signal.fvg_bottom = rates[0].high;
   }

   double atr = APEA_AverageTrueRange(rates, count, 14);
   double range_high = rates[2].high;
   double range_low = rates[2].low;
   int range_end = (int)MathMin(12, count);
   for(int i = 3; i < range_end; i++)
   {
      range_high = MathMax(range_high, rates[i].high);
      range_low = MathMin(range_low, rates[i].low);
   }
   double body = MathAbs(rates[0].close - rates[0].open);
   bool compact_range = atr > 0.0 && range_high - range_low <= atr * 2.5;
   bool displacement = atr > 0.0 && body >= atr * 0.8;
   double range_mid = (range_high + range_low) * 0.5;
   signal.amd_bullish = compact_range && displacement &&
                        rates[0].low < range_low &&
                        rates[0].close > range_mid &&
                        rates[0].close > rates[0].open;
   signal.amd_bearish = compact_range && displacement &&
                        rates[0].high > range_high &&
                        rates[0].close < range_mid &&
                        rates[0].close < rates[0].open;

   if(signal.bos_bullish)
   {
      for(int i = 1; i <= 5 && i < count; i++)
      {
         if(rates[i].close < rates[i].open)
         {
            signal.order_block_bullish = true;
            signal.order_block_top = rates[i].high;
            signal.order_block_bottom = rates[i].low;
            signal.order_block_time = rates[i].time;
            break;
         }
      }
   }
   if(signal.bos_bearish)
   {
      for(int i = 1; i <= 5 && i < count; i++)
      {
         if(rates[i].close > rates[i].open)
         {
            signal.order_block_bearish = true;
            signal.order_block_top = rates[i].high;
            signal.order_block_bottom = rates[i].low;
            signal.order_block_time = rates[i].time;
            break;
         }
      }
   }

   signal.local_bias = APEA_StructuralBias(rates, count);
   if(signal.swept_bullish)
   {
      signal.bullish_score += 2.0;
      APEA_AddReason(signal.reasons, "varredura abaixo de swing com fechamento de volta acima");
   }
   if(signal.swept_bearish)
   {
      signal.bearish_score += 2.0;
      APEA_AddReason(signal.reasons, "varredura acima de swing com fechamento de volta abaixo");
   }
   if(signal.bos_bullish)
   {
      signal.bullish_score += 2.0;
      APEA_AddReason(signal.reasons, "BOS: fechamento acima de swing confirmado");
   }
   if(signal.bos_bearish)
   {
      signal.bearish_score += 2.0;
      APEA_AddReason(signal.reasons, "BOS: fechamento abaixo de swing confirmado");
   }
   if(signal.engulfing_bullish)
   {
      signal.bullish_score += 1.0;
      APEA_AddReason(signal.reasons, "engolfo de corpo comprador");
   }
   if(signal.engulfing_bearish)
   {
      signal.bearish_score += 1.0;
      APEA_AddReason(signal.reasons, "engolfo de corpo vendedor");
   }
   if(signal.fvg_bullish)
   {
      signal.bullish_score += 1.0;
      APEA_AddReason(signal.reasons, "FVG de três candles detectado");
   }
   if(signal.fvg_bearish)
   {
      signal.bearish_score += 1.0;
      APEA_AddReason(signal.reasons, "FVG de três candles detectado");
   }
   if(signal.amd_bullish)
   {
      signal.bullish_score += 1.0;
      APEA_AddReason(signal.reasons, "PO3/AMD heurístico: faixa compacta, varredura e deslocamento");
   }
   if(signal.amd_bearish)
   {
      signal.bearish_score += 1.0;
      APEA_AddReason(signal.reasons, "PO3/AMD heurístico: faixa compacta, varredura e deslocamento");
   }
   if(signal.order_block_bullish)
      APEA_AddReason(signal.reasons, "OB visual heurístico antes do BOS comprador (não pontuado)");
   if(signal.order_block_bearish)
      APEA_AddReason(signal.reasons, "OB visual heurístico antes do BOS vendedor (não pontuado)");

   if(signal.local_bias > 0)
   {
      signal.bullish_score += 1.0;
      APEA_AddReason(signal.reasons, "estrutura local HH/HL");
   }
   else if(signal.local_bias < 0)
   {
      signal.bearish_score += 1.0;
      APEA_AddReason(signal.reasons, "estrutura local LH/LL");
   }
   if(context_bias > 0)
   {
      signal.bullish_score += 1.0;
      APEA_AddReason(signal.reasons, "contexto multi-timeframe HH/HL");
   }
   else if(context_bias < 0)
   {
      signal.bearish_score += 1.0;
      APEA_AddReason(signal.reasons, "contexto multi-timeframe LH/LL");
   }

   bool bullish_trigger = signal.swept_bullish || signal.bos_bullish;
   bool bearish_trigger = signal.swept_bearish || signal.bos_bearish;
   bool bullish_candidate = signal.bullish_score >= minimum_score &&
                            (!require_structure_trigger || bullish_trigger) &&
                            signal.bullish_score > signal.bearish_score;
   bool bearish_candidate = signal.bearish_score >= minimum_score &&
                            (!require_structure_trigger || bearish_trigger) &&
                            signal.bearish_score > signal.bullish_score;
   if(!bullish_candidate && !bearish_candidate)
   {
      if(require_structure_trigger &&
         (signal.bullish_score >= minimum_score ||
          signal.bearish_score >= minimum_score) &&
         !bullish_trigger && !bearish_trigger)
         APEA_AddReason(signal.reasons, "sinal filtrado: sem BOS/varredura de liquidez");
      return true;
   }

   signal.direction = bullish_candidate ? 1 : -1;
   signal.entry = rates[0].close;
   signal.confirmed_at = rates[0].time;

   double stop_buffer = atr * 0.15;
   if(signal.direction > 0)
   {
      double structural_stop = signal.swing_low > 0.0 ?
                               MathMin(rates[0].low, signal.swing_low) :
                               rates[0].low;
      signal.stop_loss = structural_stop - stop_buffer;
   }
   else
   {
      double structural_stop = signal.swing_high > 0.0 ?
                               MathMax(rates[0].high, signal.swing_high) :
                               rates[0].high;
      signal.stop_loss = structural_stop + stop_buffer;
   }

   double risk_distance = MathAbs(signal.entry - signal.stop_loss);
   if(risk_distance <= 0.0)
      return false;

   signal.take_profit = signal.entry +
                        signal.direction * risk_distance * reward_risk;
   signal.valid = true;
   return true;
}

#endif
