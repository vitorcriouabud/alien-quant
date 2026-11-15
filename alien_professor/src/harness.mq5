//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_TESTE - só para TESTE VISUAL no Strategy Tester.  |
//| Usa o mesmo núcleo do indicador. Não envia ordens.               |
//+------------------------------------------------------------------+
#property version "1.00"
#include "ALIEN_PROFESSOR_core.mqh"
input string InpShotHoras="11:00,17:00"; // horários (servidor) para tirar print
int g_shots=0;
int OnInit(){ Core_Init(); return INIT_SUCCEEDED; }
void OnDeinit(const int r){ Core_Deinit(); }
void OnTick()
{
   Core_Update(false);
   static datetime lastShot=0;
   datetime t=TimeCurrent(); string hm=TimeToString(t,TIME_MINUTES);
   if(MQLInfoInteger(MQL_VISUAL_MODE) && StringFind(InpShotHoras,hm)>=0 && t-lastShot>600 && g_shots<6)
   {
      Core_Update(true); ChartRedraw(0);
      string f=StringFormat("APROF_%s_%s.png",_Symbol,TimeToString(t,TIME_DATE)); StringReplace(f,".","_"); StringReplace(f,"_png",".png");
      f=StringFormat("APROF_%s_%d.png",StringSubstr(_Symbol,0,8),g_shots);
      StringReplace(f,"..",".");
      if(ChartScreenShot(0,f,1800,1000,ALIGN_RIGHT)) { g_shots++; bool c=FileCopy(f,0,f,FILE_COMMON|FILE_REWRITE); Print("print salvo: ",f," existe=",FileIsExist(f)," copia_common=",c," ",TerminalInfoString(TERMINAL_COMMONDATA_PATH)); } else Print("falha print ",GetLastError());
      lastShot=t;
   }
   static datetime lastLog=0;
   if(t-lastLog>=3600){ lastLog=t; Print(StringFormat("APROF %s compra %d/10 venda %d/10 trend %d niveis %d bos %d fvg %d atr %.2f lote %.2f risco %.2f",hm,g_pb.score,g_ps.score,g_trend,ArraySize(g_niv),ArraySize(g_bos),ArraySize(g_fvg),g_atr,g_pb.lot,g_pb.riskUSD)); }
}
