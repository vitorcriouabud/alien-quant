#property strict
#property version   "1.00"
#property description "EA didatico modular para analise de estrutura, liquidez e price action."

#include "..\Include\AlienProfessor\Types.mqh"
#include "..\Include\AlienProfessor\MarketData.mqh"
#include "..\Include\AlienProfessor\SignalEngine.mqh"
#include "..\Include\AlienProfessor\Execution.mqh"
#include "..\Include\AlienProfessor\ChartTeacher.mqh"

input ENUM_TIMEFRAMES InpSignalTimeframe = PERIOD_M5;
input ENUM_TIMEFRAMES InpContextTimeframe = PERIOD_H1;
input double InpMinimumScore = 3.0;
input double InpRewardRisk = 1.5;
input bool InpRequireStructureTrigger = false;

input ENUM_APEA_EXECUTION_MODE InpExecutionMode = APEA_EXECUTION_SIGNALS_ONLY;
input bool InpEnableAutoOrders = false;
input long InpMagicNumber = 8232401;
input double InpRiskPercent = 0.25;
input double InpMaximumDailyLossPercent = 1.0;
input int InpMaximumEntriesPerDay = 3;
input double InpMaximumSpreadPoints = 150.0;
input int InpDeviationPoints = 30;

CTrade g_trade;
datetime g_last_signal_bar = 0;

int OnInit()
{
   if(InpMinimumScore < 1.0 ||
      InpRewardRisk <= 0.0 ||
      InpRiskPercent <= 0.0 ||
      InpRiskPercent > 1.0 ||
      InpMaximumDailyLossPercent <= 0.0 ||
      InpMaximumDailyLossPercent > 5.0 ||
      InpMaximumEntriesPerDay < 1 ||
      InpMaximumSpreadPoints <= 0.0 ||
      InpDeviationPoints < 0 ||
      InpMagicNumber <= 0 ||
      InpExecutionMode < APEA_EXECUTION_SIGNALS_ONLY ||
      InpExecutionMode > APEA_EXECUTION_DEMO_ONLY)
   {
      Print("Parâmetros inválidos: revise score, risco, limites e magic number.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpEnableAutoOrders && InpExecutionMode == APEA_EXECUTION_DEMO_ONLY)
   {
      if(MQLInfoInteger(MQL_TESTER) ||
         !APEA_IsConnectedDemoAccount())
      {
         Print("Inicialização bloqueada: ordens automáticas deste modo exigem terminal conectado a uma conta demo identificada, fora do Strategy Tester.");
         return INIT_FAILED;
      }
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   string execution_description = "somente sinais; ordens desativadas";
   if(InpEnableAutoOrders && InpExecutionMode == APEA_EXECUTION_DEMO_ONLY)
      execution_description = "ordens automáticas apenas em conta demo";
   else if(InpEnableAutoOrders && InpExecutionMode == APEA_EXECUTION_TESTER_ONLY)
      execution_description = "ordens simuladas apenas no Strategy Tester";

   Print("EA educativo iniciado em ", _Symbol,
         "; sinais em ", EnumToString(InpSignalTimeframe),
         "; modo: ", execution_description, ".");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   APEA_ClearTeacher();
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(transaction.type != TRADE_TRANSACTION_DEAL_ADD || transaction.deal == 0)
      return;
   if(!HistoryDealSelect(transaction.deal))
   {
      PrintFormat("Resultado do EA indisponivel: nao foi possivel ler o deal %I64u.",
                  transaction.deal);
      return;
   }

   string deal_symbol = HistoryDealGetString(transaction.deal, DEAL_SYMBOL);
   long deal_magic = HistoryDealGetInteger(transaction.deal, DEAL_MAGIC);
   if(deal_symbol != _Symbol || deal_magic != InpMagicNumber)
      return;

   ENUM_DEAL_TYPE deal_type =
      (ENUM_DEAL_TYPE)HistoryDealGetInteger(transaction.deal, DEAL_TYPE);
   if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
      return;

   ENUM_DEAL_ENTRY entry_type =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
   string deal_action = "ajuste";
   if(entry_type == DEAL_ENTRY_IN)
      deal_action = "entrada";
   else if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY)
      deal_action = "saida";
   else if(entry_type == DEAL_ENTRY_INOUT)
      deal_action = "reversao";

   double net_result = HistoryDealGetDouble(transaction.deal, DEAL_PROFIT) +
                       HistoryDealGetDouble(transaction.deal, DEAL_COMMISSION) +
                       HistoryDealGetDouble(transaction.deal, DEAL_SWAP) +
                       HistoryDealGetDouble(transaction.deal, DEAL_FEE);
   int digits = (int)SymbolInfoInteger(deal_symbol, SYMBOL_DIGITS);
   PrintFormat("Negocio EA | %s %s | deal %I64u | posicao %I64u | volume %.2f | preco %.*f | resultado liquido deste deal %.2f %s",
               deal_action,
               deal_type == DEAL_TYPE_BUY ? "COMPRA" : "VENDA",
               transaction.deal,
               HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID),
               HistoryDealGetDouble(transaction.deal, DEAL_VOLUME),
               digits,
               HistoryDealGetDouble(transaction.deal, DEAL_PRICE),
               net_result,
               AccountInfoString(ACCOUNT_CURRENCY));
}

void OnTick()
{
   // Enquanto execucao for permitida, observar a equity em CADA tick para
   // registrar a trava mesmo que o mercado recupere antes da proxima barra.
   // Nunca envia ordem aqui; TryExecute ainda revalida com historico atualizado.
   if(InpEnableAutoOrders && InpExecutionMode != APEA_EXECUTION_SIGNALS_ONLY &&
      (MQLInfoInteger(MQL_TESTER) || APEA_IsConnectedDemoAccount()))
   {
      string risk_status;
      APEA_DailyEquityGuardCheck(InpMaximumDailyLossPercent, risk_status);
   }

   datetime current_bar = iTime(_Symbol, InpSignalTimeframe, 0);
   if(current_bar == 0 || current_bar == g_last_signal_bar)
      return;
   g_last_signal_bar = current_bar;

   MqlRates signal_rates[];
   int signal_count = APEA_LoadClosedRates(_Symbol, InpSignalTimeframe, 300, signal_rates);
   if(signal_count < 20)
   {
      string data_error = StringFormat("Histórico insuficiente em %s: %d candles.",
                                       EnumToString(InpSignalTimeframe), signal_count);
      Comment("EA Professor | ", data_error);
      Print(data_error);
      return;
   }

   MqlRates context_rates[];
   int context_count = APEA_LoadClosedRates(_Symbol, InpContextTimeframe, 300, context_rates);
   if(context_count < 20)
   {
      string data_error = StringFormat("Histórico insuficiente no contexto %s: %d candles.",
                                       EnumToString(InpContextTimeframe), context_count);
      Comment("EA Professor | ", data_error);
      Print(data_error);
      return;
   }

   int context_bias = APEA_StructuralBias(context_rates, context_count);
   APEA_Signal signal;
   if(!APEA_BuildSignal(signal_rates, signal_count, context_bias,
                        InpMinimumScore, InpRewardRisk,
                        InpRequireStructureTrigger, signal))
   {
      string signal_error = "Erro ao calcular o cenário; ordem não avaliada.";
      Comment("EA Professor | ", signal_error);
      Print(signal_error);
      return;
   }

   int signal_period_seconds = PeriodSeconds(InpSignalTimeframe);
   if(signal.valid &&
      (signal_period_seconds <= 0 ||
       signal.confirmed_at != current_bar - signal_period_seconds))
   {
      signal.valid = false;
      signal.reasons = "sinal antigo após intervalo sem candles; descartado";
      string stale_status = StringFormat(
         "ordem bloqueada: sinal não pertence à barra %s imediatamente anterior",
         EnumToString(InpSignalTimeframe));
      Print(stale_status);
      APEA_RenderTeacher(signal, signal_rates, InpSignalTimeframe, InpContextTimeframe,
                         InpMinimumScore, stale_status);
      return;
   }

   string execution_status;
   APEA_TryExecute(signal,
                   InpExecutionMode,
                   InpEnableAutoOrders,
                   _Symbol,
                   InpMagicNumber,
                   InpRiskPercent,
                   InpRewardRisk,
                   InpMaximumDailyLossPercent,
                   InpMaximumEntriesPerDay,
                   InpMaximumSpreadPoints,
                   InpDeviationPoints,
                   g_trade,
                   execution_status);

   if(signal.valid)
      APEA_LogSignal(_Symbol, InpSignalTimeframe, InpMinimumScore,
                     InpRewardRisk, InpRequireStructureTrigger, signal);

   APEA_RenderTeacher(signal, signal_rates, InpSignalTimeframe, InpContextTimeframe,
                      InpMinimumScore, execution_status);

   if(signal.valid)
   {
      PrintFormat("%s %s | score compra %.1f, venda %.1f | entrada teórica %.*f | SL %.*f | TP %.*f | motivo: %s | resultado da tentativa: %s",
                  _Symbol,
                  signal.direction > 0 ? "COMPRA" : "VENDA",
                  signal.bullish_score,
                  signal.bearish_score,
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS), signal.entry,
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS), signal.stop_loss,
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS), signal.take_profit,
                  signal.reasons,
                  execution_status);
   }
}
