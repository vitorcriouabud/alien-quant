#ifndef ALIEN_PROFESSOR_MARKET_DATA_MQH
#define ALIEN_PROFESSOR_MARKET_DATA_MQH

int APEA_LoadClosedRates(const string symbol,
                         const ENUM_TIMEFRAMES timeframe,
                         const int requested,
                         MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);
   return CopyRates(symbol, timeframe, 1, requested, rates);
}

void APEA_FindSwingLevels(const MqlRates &rates[],
                          const int count,
                          double &latest_high,
                          double &older_high,
                          double &latest_low,
                          double &older_low,
                          int &latest_high_index,
                          int &older_high_index,
                          int &latest_low_index,
                          int &older_low_index)
{
   latest_high = 0.0;
   older_high = 0.0;
   latest_low = 0.0;
   older_low = 0.0;
   latest_high_index = -1;
   older_high_index = -1;
   latest_low_index = -1;
   older_low_index = -1;

   if(count < 6)
      return;

   for(int i = 2; i < count - 2; i++)
   {
      bool is_high = true;
      bool is_low = true;

      for(int offset = 1; offset <= 2; offset++)
      {
         if(rates[i].high <= rates[i - offset].high ||
            rates[i].high < rates[i + offset].high)
            is_high = false;

         if(rates[i].low >= rates[i - offset].low ||
            rates[i].low > rates[i + offset].low)
            is_low = false;
      }

      if(is_high)
      {
         if(latest_high_index < 0)
         {
            latest_high = rates[i].high;
            latest_high_index = i;
         }
         else if(older_high_index < 0)
         {
            older_high = rates[i].high;
            older_high_index = i;
         }
      }

      if(is_low)
      {
         if(latest_low_index < 0)
         {
            latest_low = rates[i].low;
            latest_low_index = i;
         }
         else if(older_low_index < 0)
         {
            older_low = rates[i].low;
            older_low_index = i;
         }
      }

      if(latest_high_index >= 0 && older_high_index >= 0 &&
         latest_low_index >= 0 && older_low_index >= 0)
         return;
   }
}

int APEA_StructuralBias(const MqlRates &rates[], const int count)
{
   double latest_high, older_high, latest_low, older_low;
   int latest_high_index, older_high_index, latest_low_index, older_low_index;
   APEA_FindSwingLevels(rates, count,
                        latest_high, older_high, latest_low, older_low,
                        latest_high_index, older_high_index,
                        latest_low_index, older_low_index);

   if(latest_high_index < 0 || older_high_index < 0 ||
      latest_low_index < 0 || older_low_index < 0)
      return 0;

   if(latest_high > older_high && latest_low > older_low)
      return 1;
   if(latest_high < older_high && latest_low < older_low)
      return -1;
   return 0;
}

double APEA_AverageTrueRange(const MqlRates &rates[],
                             const int count,
                             const int period)
{
   if(period < 1 || count <= period + 1)
      return 0.0;

   double total = 0.0;
   for(int i = 1; i <= period; i++)
   {
      double previous_close = rates[i + 1].close;
      double true_range = MathMax(rates[i].high - rates[i].low,
                                  MathMax(MathAbs(rates[i].high - previous_close),
                                          MathAbs(rates[i].low - previous_close)));
      total += true_range;
   }
   return total / period;
}

#endif
