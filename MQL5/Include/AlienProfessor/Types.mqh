#ifndef ALIEN_PROFESSOR_TYPES_MQH
#define ALIEN_PROFESSOR_TYPES_MQH

enum ENUM_APEA_EXECUTION_MODE
{
   APEA_EXECUTION_SIGNALS_ONLY = 0,
   APEA_EXECUTION_TESTER_ONLY = 1,
   APEA_EXECUTION_DEMO_ONLY = 2
};

struct APEA_Signal
{
   bool valid;
   int direction;
   datetime confirmed_at;
   double entry;
   double stop_loss;
   double take_profit;
   double bullish_score;
   double bearish_score;
   double swing_high;
   double swing_low;
   bool swept_bullish;
   bool swept_bearish;
   bool bos_bullish;
   bool bos_bearish;
   bool engulfing_bullish;
   bool engulfing_bearish;
   bool fvg_bullish;
   bool fvg_bearish;
   double fvg_top;
   double fvg_bottom;
   bool order_block_bullish;
   bool order_block_bearish;
   double order_block_top;
   double order_block_bottom;
   datetime order_block_time;
   bool amd_bullish;
   bool amd_bearish;
   int local_bias;
   int context_bias;
   string reasons;
};

#endif
