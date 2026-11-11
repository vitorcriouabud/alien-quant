#ifndef ALIEN_SCALP_HYPOTHESES_MQH
#define ALIEN_SCALP_HYPOTHESES_MQH
// Pure closed-bar definitions. r[0] is the newest CLOSED bar, never the live bar.
// Research hypotheses: names describe observable prices, not institutional intent.
struct AlienScalpSignal
{
   int id;
   int direction;
   double level;
   double invalidation;
   datetime time;
};
string AlienScalpName(int id)
{
   if(id==6) return "IMPULSO_CORRECAO";
   if(id==7) return "COMPRESSAO_ROMPIMENTO";
   if(id==8) return "FALSO_ROMPIMENTO";
   if(id==9) return "BORDA_LATERAL";
   if(id==10) return "FVG_REACAO_FECHADA";
   if(id==11) return "OB_REACAO_FECHADA";
   return "SEM_HIPOTESE";
}
bool AlienScalpDetect(const MqlRates &r[], int count, int id, int direction,
                      double atr, double point, AlienScalpSignal &s)
{
   s.id=0; s.direction=0; s.level=0; s.invalidation=0; s.time=0;
   if(count<12 || ArraySize(r)<count || !MathIsValidNumber(atr) || !MathIsValidNumber(point) || atr<=0 || point<=0 ||
      (direction!=1 && direction!=-1) || id<6 || id>11) return false;
   for(int i=0;i<count;i++)
      if(!MathIsValidNumber(r[i].open) || !MathIsValidNumber(r[i].close) ||
         !MathIsValidNumber(r[i].high) || !MathIsValidNumber(r[i].low) || r[i].low<=0 || r[i].high<r[i].low || r[i].open<r[i].low ||
         r[i].open>r[i].high || r[i].close<r[i].low || r[i].close>r[i].high ||
         (i>0 && r[i-1].time<=r[i].time)) return false;
   double d=(double)direction;
   bool buy=direction>0;
   bool reaction=d*(r[0].close-r[0].open)>0;
   double hi=r[2].high, lo=r[2].low;
   for(int i=3;i<10;i++) { hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low); }
   double width=hi-lo;
   bool found=false;
   double level=0, invalidation=0;
   if(id==6) // Three-bar impulse, smaller counter-candle, recovery of correction.
   {
      double impulse=d*(r[2].close-r[2].open);
      bool correction=d*(r[1].close-r[1].open)<0 &&
                      MathAbs(r[1].close-r[1].open)<=0.5*impulse;
      bool held=buy ? r[1].low>r[2].low : r[1].high<r[2].high;
      level=buy?r[1].high:r[1].low;
      found=impulse>=0.6*atr && correction && held && reaction &&
            d*(r[0].close-level)>point;
      invalidation=buy?MathMin(r[0].low,r[1].low):MathMax(r[0].high,r[1].high);
   }
   if(id==7) // Close outside an eight-bar compression; not a retest strategy.
   {
      hi=r[1].high; lo=r[1].low;
      for(int i=2;i<9;i++) { hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low); }
      level=buy?hi:lo;
      found=hi-lo<=1.5*atr && reaction && d*(r[0].close-level)>point &&
            MathAbs(r[0].close-r[0].open)>=0.4*atr;
      invalidation=buy?r[0].low:r[0].high;
   }
   if(id==8) // Previous close broke box, newest close recovers inside it.
   {
      level=buy?lo:hi;
      found=width>=atr && d*(r[1].close-level)<-point &&
            d*(r[0].close-level)>point && r[0].close>lo && r[0].close<hi && reaction;
      invalidation=buy?MathMin(r[0].low,r[1].low):MathMax(r[0].high,r[1].high);
   }
   if(id==9) // Bounded range with little net drift and a closed rejection at edge.
   {
      level=buy?lo:hi;
      double extreme=buy?r[0].low:r[0].high;
      double middle=0.5*(hi+lo);
      found=width>=1.5*atr && width<=4*atr &&
            MathAbs(r[2].close-r[9].close)<=0.25*width &&
            MathAbs(extreme-level)<=0.15*atr && reaction &&
            d*(r[0].close-level)>0.15*atr && d*(middle-r[0].close)>0;
      invalidation=buy?r[0].low:r[0].high;
   }
   if(id==10) // r3,r2,r1 formed gap; r0 revisits and closes beyond near edge.
   {
      double lower=buy?r[3].high:r[1].high;
      double upper=buy?r[1].low:r[3].low;
      level=buy?upper:lower;
      found=upper-lower>=0.1*atr && d*(r[2].close-r[2].open)>=0.5*atr &&
            r[0].low<=upper && r[0].high>=lower && reaction &&
            d*(r[0].close-level)>point;
      invalidation=buy?MathMin(lower,r[0].low):MathMax(upper,r[0].high);
   }
   if(id==11) // Opposite r3, displacement r2, away r1, closed revisit r0.
   {
      level=buy?r[3].high:r[3].low;
      bool away=buy?r[1].low>level:r[1].high<level;
      found=d*(r[3].close-r[3].open)<0 &&
            d*(r[2].close-r[2].open)>=0.6*atr && d*(r[2].close-level)>point &&
            away && r[0].low<=r[3].high && r[0].high>=r[3].low && reaction &&
            d*(r[0].close-level)>point;
      invalidation=buy?MathMin(r[3].low,r[0].low):MathMax(r[3].high,r[0].high);
   }
   if(!found || d*(r[0].close-invalidation)<=point) return false;
   s.id=id; s.direction=direction; s.level=level;
   s.invalidation=invalidation; s.time=r[0].time;
   return true;
}
#endif
