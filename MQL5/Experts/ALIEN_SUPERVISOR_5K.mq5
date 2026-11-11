#property strict
#property version "1.00"
#property description "Supervisor de perda flutuante da conta inteira. Nao abre operacoes."
#include <AlienProfessor/AccountFloatingGuard.mqh>
int OnInit()
{
   if(!AGInit())return INIT_PARAMETERS_INCORRECT;
   if(!EventSetMillisecondTimer(250))return INIT_FAILED;
   AGCheck();Comment(AGStatus());
   return INIT_SUCCEEDED;
}
void OnTick(){AGCheck();Comment(AGStatus());}
void OnTimer(){AGCheck();Comment(AGStatus());}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{AGCheck();Comment(AGStatus());}
void OnDeinit(const int reason){EventKillTimer();Comment("");}
