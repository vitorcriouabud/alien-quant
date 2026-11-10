//+------------------------------------------------------------------+
//|                                                  Test_Margin.mq5 |
//+------------------------------------------------------------------+
#property script_show_inputs

void OnStart()
{
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("TESTE MARGEM: Balance=", balance, " Equity=", eq, " FreeMargin=", freeMargin);
   
   double margin = 0.0;
   ResetLastError();
   bool res = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 0.01, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin);
   Print("TESTE MARGEM 0.01: res=", res, " margin=", margin, " err=", GetLastError());
   
   margin = 0.0;
   res = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 0.18, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin);
   Print("TESTE MARGEM 0.18: res=", res, " margin=", margin, " err=", GetLastError());
}
