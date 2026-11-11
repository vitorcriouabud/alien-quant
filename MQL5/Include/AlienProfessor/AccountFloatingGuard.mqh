#ifndef ALIEN_ACCOUNT_FLOATING_GUARD
#define ALIEN_ACCOUNT_FLOATING_GUARD
#include <Trade/Trade.mqh>

input group "=== SUPERVISOR CONTA INTEIRA: GOAT 5K / 1% FLOATING ==="
input bool   AGEnable=true;
input double AGInitialBalance=5000.0; // Saldo ORIGINAL contratado, em USD. Nunca saldo atual.
input double AGFloatingLimitPercent=1.0;
input double AGSafetyBufferMoney=20.0; // Fecha em 50-20=30 USD, nao aguarda 50
input double AGWarningMoney=20.0;
input int    AGDeviationPoints=25;

// Pure policy separated from terminal actions for executable fixture tests.
int AGDecision(double initial,double pct,double buffer,double warning,
               double grossLoss,double equityLoss,bool latched)
{
   if(!MathIsValidNumber(initial)||!MathIsValidNumber(pct)||
      !MathIsValidNumber(buffer)||!MathIsValidNumber(warning)||
      !MathIsValidNumber(grossLoss)||!MathIsValidNumber(equityLoss)||
      initial<=0||pct<=0||pct>100||buffer<=0||warning<=0||
      buffer>=initial*pct/100.0||warning>=initial*pct/100.0-buffer)
      return -1;
   if(latched) return 2;
   double loss=MathMax(grossLoss,equityLoss);
   if(loss>=initial*pct/100.0-buffer) return 2;
   if(loss>=warning) return 1;
   return 0;
}

CTrade agTrade;
string agKey="",agMessage="Supervisor nao inicializado";
bool agLatched=false,agBusy=false;
double agLoss=0.0,agGrossLoss=0.0,agNetFloat=0.0;
ulong agLastAction=0,agLastWarning=0,agLastError=0;

string AGAccountKey()
{
   // Hash server name to avoid collisions between brokers reusing login numbers.
   uint h=2166136261;
   string server=AccountInfoString(ACCOUNT_SERVER);
   for(int i=0;i<StringLen(server);i++) h=(h^(uint)StringGetCharacter(server,i))*16777619;
   string scope=MQLInfoInteger(MQL_TESTER)?"AG_TEST_":"AG_LIVE_";
   return scope+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)h);
}
void AGLog(string event,string details)
{
   Print("ALIEN SUPERVISOR ",event,": ",details);
   string name="ALIEN_SUPERVISOR_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+".csv";
   int f=FileOpen(name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';');
   if(f==INVALID_HANDLE) return;
   if(FileSize(f)==0) FileWrite(f,"time","event","loss_observed","details");
   FileSeek(f,0,SEEK_END);
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),event,DoubleToString(agLoss,2),details);
   FileFlush(f); FileClose(f);
}
bool AGInit()
{
   if(!AGEnable) {agMessage="Supervisor desativado";return true;}
   if(AGDecision(AGInitialBalance,AGFloatingLimitPercent,AGSafetyBufferMoney,
                 AGWarningMoney,0,0,false)<0 || AGDeviationPoints<0 ||
      AccountInfoString(ACCOUNT_CURRENCY)!="USD")
   {
      Print("SUPERVISOR: parametros invalidos ou moeda diferente de USD. Alerta < gatilho < limite.");
      return false;
   }
   agKey=AGAccountKey();
   // Tester runs must not inherit a latch from a previous simulation.
   agLatched=!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(agKey) && GlobalVariableGet(agKey)>0;
   agTrade.SetAsyncMode(false);
   agTrade.SetDeviationInPoints(AGDeviationPoints);
   agMessage="Supervisor inicializado; conta inteira, inclusive ordens manuais";
   AGLog("KEY",agKey);
   AGLog("INIT",StringFormat("Base %.2f | limite %.2f | gatilho %.2f | alerta %.2f | trava %s",
         AGInitialBalance,AGInitialBalance*AGFloatingLimitPercent/100.0,
         AGInitialBalance*AGFloatingLimitPercent/100.0-AGSafetyBufferMoney,
         AGWarningMoney,agLatched?"ATIVA":"LIVRE"));
   return true;
}
void AGCloseAccount()
{
   // All symbols and all magics are intentional: the prop rule is account-wide.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0)continue;
      if(!agTrade.OrderDelete(ticket) || agTrade.ResultRetcode()!=TRADE_RETCODE_DONE)
      {
         if(GetTickCount64()-agLastError>=5000 || agLastError==0)
         {AGLog("DELETE_FAILED",agTrade.ResultRetcodeDescription());agLastError=GetTickCount64();}
      }
   }
   ulong tickets[]; double pnl[];
   int n=PositionsTotal();ArrayResize(tickets,n);ArrayResize(pnl,n);
   for(int i=0;i<n;i++)
   {
      tickets[i]=PositionGetTicket(i);
      pnl[i]=tickets[i]>0?PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP):0;
   }
   // Worst floating losses first. Every snapshot ticket is attempted once per pass.
   for(int i=0;i<n;i++)for(int j=i+1;j<n;j++)if(pnl[j]<pnl[i])
   {double p=pnl[i];pnl[i]=pnl[j];pnl[j]=p;ulong t=tickets[i];tickets[i]=tickets[j];tickets[j]=t;}
   for(int i=0;i<n;i++)
   {
      ulong ticket=tickets[i];
      if(ticket==0 || !PositionSelectByTicket(ticket))continue;
      agTrade.SetTypeFillingBySymbol(PositionGetString(POSITION_SYMBOL));
      bool sent=agTrade.PositionClose(ticket);
      uint rc=agTrade.ResultRetcode();
      if(sent && rc==TRADE_RETCODE_DONE)
         AGLog("CLOSE_CONFIRMED",IntegerToString((long)ticket));
      else if(GetTickCount64()-agLastError>=5000 || agLastError==0)
      {AGLog("CLOSE_RETRY",IntegerToString((long)ticket)+" "+agTrade.ResultRetcodeDescription());agLastError=GetTickCount64();}
   }
}
bool AGCheck()
{
   if(!AGEnable)return false;
   if(agBusy)return agLatched;
   agBusy=true;
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(agKey) && GlobalVariableGet(agKey)>0)
      agLatched=true;
   agGrossLoss=0;agNetFloat=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0)continue;
      double pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      agNetFloat+=pnl;agGrossLoss+=MathMax(0.0,-pnl);
   }
   // Conservative: profitable positions do not offset losing ones. Balance-equity
   // also captures account-level floating deductions not reflected per position.
   double equityLoss=PositionsTotal()>0?
      MathMax(0.0,AccountInfoDouble(ACCOUNT_BALANCE)-AccountInfoDouble(ACCOUNT_EQUITY)):0.0;
   agLoss=MathMax(agGrossLoss,equityLoss);
   int decision=AGDecision(AGInitialBalance,AGFloatingLimitPercent,AGSafetyBufferMoney,
                           AGWarningMoney,agGrossLoss,equityLoss,agLatched);
   ulong now=GetTickCount64();
   if(decision==2 || decision<0)
   {
      if(!agLatched)
      {
         agLatched=true;
         if(!MQLInfoInteger(MQL_TESTER))
         {
            if(GlobalVariableSet(agKey,1)==0)Print("SUPERVISOR: falha persistindo trava; mantida em memoria.");
            GlobalVariablesFlush();
         }
         AGLog("LATCH",StringFormat("Gatilho atingido; perda %.2f; fecha TODA conta",agLoss));
         Alert("ALIEN: protecao acionada. Encerrando posicoes e pendentes da conta inteira.");
      }
      if(agLastAction==0 || now-agLastAction>=250)
      {agLastAction=now;AGCloseAccount();}
      agMessage=StringFormat("TRAVADO | perda %.2f | restantes: %d posicoes / %d pendentes",agLoss,PositionsTotal(),OrdersTotal());
   }
   else
   {
      agMessage=StringFormat("%s | perda %.2f | alerta %.2f | fecha %.2f | limite %.2f USD",
          decision==1?"ALERTA":"LIVRE",agLoss,AGWarningMoney,
          AGInitialBalance*AGFloatingLimitPercent/100.0-AGSafetyBufferMoney,
          AGInitialBalance*AGFloatingLimitPercent/100.0);
      if(decision==1 && (agLastWarning==0 || now-agLastWarning>=60000))
      {agLastWarning=now;AGLog("WARNING",agMessage);Alert("ALIEN ",agMessage);}
   }
   agBusy=false;
   return agLatched;
}
string AGStatus()
{
   string status="SUPERVISOR: "+agMessage;
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))status+=" | SEM CONEXAO";
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))status+=" | EXECUCAO AUTOMATICA INDISPONIVEL";
   }
   return status;
}

bool AGCanOpen(ENUM_ORDER_TYPE side,double volume,double price,double stop,double commission,string &reason)
{
   if(!AGEnable)return true;
   if(AGCheck()){reason="Supervisor da conta acionado";return false;}
   if(OrdersTotal()>0){reason="Supervisor: pendentes na conta; risco agregado nao conhecido";return false;}
   double total=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0)continue;
      double sl=PositionGetDouble(POSITION_SL);
      if(sl<=0){reason="Supervisor: posicao na conta sem SL";return false;}
      ENUM_ORDER_TYPE existing=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
      double pnl=0;
      if(!OrderCalcProfit(existing,PositionGetString(POSITION_SYMBOL),PositionGetDouble(POSITION_VOLUME),
                          PositionGetDouble(POSITION_PRICE_OPEN),sl,pnl))
      {reason="Supervisor: falha calculando risco da conta";return false;}
      pnl+=MathMin(0.0,PositionGetDouble(POSITION_SWAP));
      double floating=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      total+=MathMax(MathMax(0.0,-pnl),MathMax(0.0,-floating));
   }
   total=MathMax(total,agLoss);
   double candidate=0;
   if(!OrderCalcProfit(side,_Symbol,volume,price,stop,candidate))
   {reason="Supervisor: risco candidato indisponivel";return false;}
   total+=MathMax(0.0,-candidate)+MathMax(0.0,commission);
   if(total>=AGInitialBalance*AGFloatingLimitPercent/100.0-AGSafetyBufferMoney)
   {reason=StringFormat("Supervisor: risco conjunto %.2f excede orcamento de protecao",total);return false;}
   return true;
}
#endif
