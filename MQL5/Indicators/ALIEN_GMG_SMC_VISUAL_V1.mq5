//+------------------------------------------------------------------+
//| ALIEN / GMG SMC VISUAL V1 - INDICADOR DE ESTUDO (MT5)            |
//| Porta os desenhos do Pine GMG SMC Pro Revisado para MQL5.        |
//| NAO envia ordens, NAO calcula sinais de compra/venda.           |
//| OB = heuristica de engolfo; FVG = gap de tres candles.            |
//+------------------------------------------------------------------+
#property strict
#property version   "1.000"
#property description "Visual de swings confirmados, OB heuristico, FVG e sessoes; SEM NEGOCIACAO"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "Swing high confirmado"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrTomato
#property indicator_width1  1
#property indicator_label2  "Swing low confirmado"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLimeGreen
#property indicator_width2  1

input group "=== SWINGS ==="
input int  InpFractal=5;                   // Candles a esquerda e a direita para confirmar
input int  InpScanBars=600;               // Quantos candles fechados desenhar
input bool InpShowSwings=true;

input group "=== ZONAS VISUAIS ==="
input bool  InpShowOB=true;
input bool  InpShowFVG=true;
input int   InpMaxZones=180;              // Maximo de retangulos OB+FVG
input int   InpExtendBars=5;              // Extensao das zonas, em candles
input color InpBullOBColor=clrDarkGreen;
input color InpBearOBColor=clrMaroon;
input color InpFVGColor=clrDimGray;

input group "=== JANELAS HORARIAS PERSONALIZADAS ==="
input bool InpShowSessions=true;
input int  InpServerUTCOffsetMinutes=120; // Configurar fuso da corretora; NAO deduzir automaticamente
input int  InpTargetUTCOffsetMinutes=-180; // America/Sao_Paulo (atualmente UTC-3)
input int  InpAsiaStart=2000;             // HHMM no fuso-alvo
input int  InpAsiaEnd=0;
input int  InpLondonStart=800;
input int  InpLondonEnd=1100;
input int  InpNYStart=1300;
input int  InpNYEnd=1600;
input color InpAsiaColor=clrMidnightBlue;
input color InpLondonColor=clrDarkOrange;
input color InpNYColor=clrMaroon;

// Indicadores visuais: nao dependem de biblioteca de trading.
double HighBuffer[];
double LowBuffer[];
string prefix="";
datetime lastClosedBar=0;
int zonesCreated=0;

bool HHMMValid(const int value)
{
   if(value<0 || value>2359) return false;
   return (value%100)<60;
}
int MinuteOfDay(const int hhmm)
{
   return (hhmm/100)*60+hhmm%100;
}
// Aceita intervalo que cruza 00:00, como 20:00-00:00.
bool InsideWindow(const int minute,const int start,const int finish)
{
   if(start==finish) return false;
   if(start<finish) return minute>=start && minute<finish;
   return (minute>=start || minute<finish);
}
int LocalMinuteOfDay(const datetime serverBarTime)
{
   datetime target=serverBarTime+(InpTargetUTCOffsetMinutes-InpServerUTCOffsetMinutes)*60;
   MqlDateTime dt;
   TimeToStruct(target,dt);
   return dt.hour*60+dt.min;
}

void PaintRectangle(const string name,const datetime t1,const double high1,
                    const datetime t2,const double low2,const color tone,
                    const bool inBackground)
{
   if(t2<=t1 || high1<=low2) return;
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,high1,t2,low2)) return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,tone);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,inBackground);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

// Em vez de deixar objetos antigos acumulando, processa apenas
// os candles fechados e conserva as ultimas InpMaxZones zonas.
void PaintZone(const string suffix,const datetime t1,const datetime t2,
               const double top,const double bottom,const color tone)
{
   string objectName=prefix+"ZONE_"+suffix;
   PaintRectangle(objectName,t1,top,t2,bottom,tone,true);
   if(ObjectFind(0,objectName)<0) return;
   zonesCreated++;
   // Este contador nunca excede InpScanBars * 2. Exclui a caixa mais antiga.
   if(zonesCreated>InpMaxZones)
   {
      string oldest="";
      datetime oldestTime=D'2099.01.01';
      int count=ObjectsTotal(0,0,-1);
      for(int k=count-1;k>=0;k--)
      {
         string nm=ObjectName(0,k,0,-1);
         if(StringFind(nm,prefix+"ZONE_")!=0) continue;
         datetime ts=(datetime)ObjectGetInteger(0,nm,OBJPROP_TIME,0);
         if(ts<=oldestTime) {oldestTime=ts; oldest=nm;}
      }
      if(oldest!="") ObjectDelete(0,oldest);
      zonesCreated=InpMaxZones;
   }
}

// Pivots confirmados exclusivamente com velas fechadas: os InpFractal
// candles a direita do pivot devem estar disponiveis antes de desenhar.
bool ConfirmedSwingHigh(const int at,const int strength,const double &high[])
{
   for(int j=1;j<=strength;j++)
      if(high[at]<=high[at-j] || high[at]<=high[at+j]) return false;
   return true;
}
bool ConfirmedSwingLow(const int at,const int strength,const double &low[])
{
   for(int j=1;j<=strength;j++)
      if(low[at]>=low[at-j] || low[at]>=low[at+j]) return false;
   return true;
}

// Construcao visual de caixas de sessoes por barras FECHADAS.
// Parametros sao minutos de um fuso UTC FIXO configurado pelo usuario.
void DrawSessionBars(const int n,const datetime &time[],const double &high[],
                     const double &low[],const int id,const int start,
                     const int end,const color tone,const int periodSecs)
{
   bool active=false;
   datetime tStart=0,tEnd=0;
   double top=0.0,bottom=0.0;
   for(int i=n;i>=1;i--)
   {
      int minute=LocalMinuteOfDay(time[i]);
      bool inside=InsideWindow(minute,start,end);
      if(inside)
      {
         if(!active)
         {
            active=true;
            tStart=time[i]; top=high[i]; bottom=low[i];
         }
         else
         {
            top=MathMax(top,high[i]);
            bottom=MathMin(bottom,low[i]);
         }
         tEnd=time[i]+periodSecs;
      }
      if(active && (!inside || i==1))
      {
         string name=prefix+"SESS_"+IntegerToString(id)+"_"+IntegerToString((long)tStart);
         PaintRectangle(name,tStart,top,tEnd,bottom,tone,true);
         active=false;
      }
   }
}

int OnInit()
{
   if(InpFractal<1 || InpFractal>50 || InpScanBars<20 || InpScanBars>3000 ||
      InpMaxZones<1 || InpMaxZones>400 || InpExtendBars<1 || InpExtendBars>100 ||
      InpServerUTCOffsetMinutes<(-12*60) || InpServerUTCOffsetMinutes>14*60 ||
      InpTargetUTCOffsetMinutes<(-12*60) || InpTargetUTCOffsetMinutes>14*60 ||
      !HHMMValid(InpAsiaStart) || !HHMMValid(InpAsiaEnd) ||
      !HHMMValid(InpLondonStart) || !HHMMValid(InpLondonEnd) ||
      !HHMMValid(InpNYStart) || !HHMMValid(InpNYEnd))
   {
      Print("ALIEN GMG VISUAL: parametros invalidos.");
      return INIT_PARAMETERS_INCORRECT;
   }
   SetIndexBuffer(0,HighBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,LowBuffer,INDICATOR_DATA);
   ArraySetAsSeries(HighBuffer,true);
   ArraySetAsSeries(LowBuffer,true);
   PlotIndexSetInteger(0,PLOT_ARROW,234); // Wingdings triangulo/seta para baixo
   PlotIndexSetInteger(1,PLOT_ARROW,233); // Wingdings triangulo/seta para cima
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,"ALIEN / GMG SMC VISUAL (sem ordens)");
   prefix="ALIEN_GMG_VISUAL_"+IntegerToString((long)ChartID())+"_"+IntegerToString((long)GetTickCount())+"_";
   Print("ALIEN GMG VISUAL: somente desenhos, nenhuma operacao. O fuso do servidor deve ser conferido.");
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   if(rates_total<InpFractal*2+4) return 0;
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   // Nunca recalcular por tick, somente quando um candle NOVO inicia.
   if(prev_calculated>0 && lastClosedBar==time[1]) return rates_total;
   lastClosedBar=time[1];

   ArrayInitialize(HighBuffer,EMPTY_VALUE);
   ArrayInitialize(LowBuffer,EMPTY_VALUE);
   ObjectsDeleteAll(0,prefix);
   zonesCreated=0;

   const int periodSecs=PeriodSeconds(_Period);
   if(periodSecs<=0) return rates_total;
   const int n=MathMin(InpScanBars,rates_total-3);
   // Uma confirmacao de pivot k exige barras k+strength e k-strength (>=1).
   if(InpShowSwings)
   {
      int oldestPivot=MathMin(n,rates_total-InpFractal-1);
      for(int k=oldestPivot;k>=InpFractal+1;k--)
      {
         if(ConfirmedSwingHigh(k,InpFractal,high))
            HighBuffer[k]=high[k]+_Point*4.0;
         if(ConfirmedSwingLow(k,InpFractal,low))
            LowBuffer[k]=low[k]-_Point*4.0;
      }
   }
   // Desenha zonas em ordem cronologica, excluindo automaticamente as antigas.
   for(int i=n;i>=1;i--)
   {
      if(InpShowOB && i+1<rates_total)
      {
         bool bull=close[i]>open[i] && close[i+1]<open[i+1] &&
                   close[i]>high[i+1] && low[i]<low[i+1];
         bool bear=close[i]<open[i] && close[i+1]>open[i+1] &&
                   close[i]<low[i+1] && high[i]>high[i+1];
         if(bull)
            PaintZone("OBB_"+IntegerToString((long)time[i]),time[i+1],
                      time[i]+InpExtendBars*periodSecs,high[i+1],low[i+1],InpBullOBColor);
         if(bear)
            PaintZone("OBS_"+IntegerToString((long)time[i]),time[i+1],
                      time[i]+InpExtendBars*periodSecs,high[i+1],low[i+1],InpBearOBColor);
      }
      if(InpShowFVG && i+2<rates_total)
      {
         if(low[i]>high[i+2])
            PaintZone("FVGB_"+IntegerToString((long)time[i]),time[i+2],
                      time[i]+InpExtendBars*periodSecs,low[i],high[i+2],InpFVGColor);
         if(high[i]<low[i+2])
            PaintZone("FVGS_"+IntegerToString((long)time[i]),time[i+2],
                      time[i]+InpExtendBars*periodSecs,low[i+2],high[i],InpFVGColor);
      }
   }
   if(InpShowSessions)
   {
      DrawSessionBars(n,time,high,low,1,MinuteOfDay(InpAsiaStart),
                      MinuteOfDay(InpAsiaEnd),InpAsiaColor,periodSecs);
      DrawSessionBars(n,time,high,low,2,MinuteOfDay(InpLondonStart),
                      MinuteOfDay(InpLondonEnd),InpLondonColor,periodSecs);
      DrawSessionBars(n,time,high,low,3,MinuteOfDay(InpNYStart),
                      MinuteOfDay(InpNYEnd),InpNYColor,periodSecs);
   }
   ChartRedraw(0);
   return rates_total;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,prefix);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
