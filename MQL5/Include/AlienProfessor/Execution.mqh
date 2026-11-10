#ifndef ALIEN_PROFESSOR_EXECUTION_MQH
#define ALIEN_PROFESSOR_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "DailyEquityGuard.mqh"

bool APEA_GetDailyStats(const string symbol,
                        const long magic,
                        double &net_pnl,
                        int &entries)
{
   net_pnl = 0.0;
   entries = 0;

   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);
   now_parts.hour = 0;
   now_parts.min = 0;
   now_parts.sec = 0;
   datetime day_start = StructToTime(now_parts);
   if(!HistorySelect(day_start, TimeCurrent()))
      return false;

   int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol ||
         HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;

      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      net_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      net_pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      net_pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
      net_pnl += HistoryDealGetDouble(ticket, DEAL_FEE);

      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
         entries++;
   }

   // net_pnl aqui e apenas REALIZADO no dia; nao e usado como trava.
   // A protecao diaria verdadeira usa equity de conta em DailyEquityGuard.mqh.
   return true;
}

bool APEA_LogSignal(const string symbol,
                    const ENUM_TIMEFRAMES timeframe,
                    const double minimum_score,
                    const double reward_risk,
                    const bool require_structure_trigger,
                    const APEA_Signal &signal)
{
   if(!signal.valid)
      return true;

   string file_name = "EA_MT5_Educativo_signals.csv";
   ResetLastError();
   int handle = FileOpen(file_name,
                         FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                         ';');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Não foi possível abrir o diário de sinais %s; erro %d.",
                  file_name, GetLastError());
      return false;
   }

   if(FileSize(handle) == 0)
   {
      uint header_written = FileWrite(handle,
                                      "server_time", "signal_time", "symbol",
                                      "timeframe", "direction",
                                      "bullish_score", "bearish_score",
                                      "context_bias", "local_bias",
                                      "sweep_bullish", "sweep_bearish",
                                      "bos_bullish", "bos_bearish",
                                      "engulfing_bullish", "engulfing_bearish",
                                      "fvg_bullish", "fvg_bearish",
                                      "amd_bullish", "amd_bearish",
                                      "entry_theoretical", "stop_loss",
                                      "take_profit", "minimum_score",
                                      "reward_risk", "structure_trigger_required",
                                      "reasons");
      if(header_written == 0)
      {
         PrintFormat("Falha ao escrever cabeçalho do diário %s; erro %d.",
                     file_name, GetLastError());
         FileClose(handle);
         return false;
      }
   }

   FileSeek(handle, 0, SEEK_END);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   uint row_written = FileWrite(handle,
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                TimeToString(signal.confirmed_at, TIME_DATE | TIME_MINUTES),
                                symbol, EnumToString(timeframe),
                                signal.direction > 0 ? "BUY" : "SELL",
                                DoubleToString(signal.bullish_score, 1),
                                DoubleToString(signal.bearish_score, 1),
                                signal.context_bias, signal.local_bias,
                                signal.swept_bullish, signal.swept_bearish,
                                signal.bos_bullish, signal.bos_bearish,
                                signal.engulfing_bullish, signal.engulfing_bearish,
                                signal.fvg_bullish, signal.fvg_bearish,
                                signal.amd_bullish, signal.amd_bearish,
                                DoubleToString(signal.entry, digits),
                                DoubleToString(signal.stop_loss, digits),
                                DoubleToString(signal.take_profit, digits),
                                DoubleToString(minimum_score, 1),
                                DoubleToString(reward_risk, 2),
                                require_structure_trigger,
                                signal.reasons);
   if(row_written == 0)
   {
      PrintFormat("Falha ao gravar sinal em %s; erro %d.",
                  file_name, GetLastError());
      FileClose(handle);
      return false;
   }

   FileFlush(handle);
   FileClose(handle);
   return true;
}

bool APEA_IsOnePositionOpen(const string symbol, const long magic)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
   }
   return false;
}

bool APEA_HasPositionOnSymbol(const string symbol)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol)
         return true;
   }
   return false;
}

bool APEA_IsConnectedDemoAccount()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   long account_login = 0;
   account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(account_login <= 0)
      return false;

   if(StringLen(AccountInfoString(ACCOUNT_SERVER)) == 0)
      return false;

   return AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO;
}

bool APEA_TryExecute(const APEA_Signal &signal,
                     const ENUM_APEA_EXECUTION_MODE execution_mode,
                     const bool enable_auto_orders,
                     const string symbol,
                     const long magic,
                     const double risk_percent,
                     const double reward_risk,
                     const double maximum_daily_loss_percent,
                     const int maximum_entries_per_day,
                     const double maximum_spread_points,
                     const int deviation_points,
                     CTrade &trade,
                     string &status)
{
   status = "ordens automáticas desativadas";
   if(!signal.valid)
   {
      status = "sem sinal confirmado";
      return false;
   }
   if(execution_mode == APEA_EXECUTION_SIGNALS_ONLY)
   {
      status = "modo somente sinais";
      return false;
   }
   if(!enable_auto_orders)
   {
      status = "ordens automáticas desativadas pelo usuário";
      return false;
   }

   bool is_tester = MQLInfoInteger(MQL_TESTER) != 0;
   bool is_demo = APEA_IsConnectedDemoAccount();
   if(execution_mode == APEA_EXECUTION_TESTER_ONLY && !is_tester)
   {
      status = "bloqueado: modo exclusivo do Strategy Tester";
      return false;
   }
   if(execution_mode == APEA_EXECUTION_DEMO_ONLY &&
      (is_tester || !is_demo))
   {
      status = "bloqueado: ordens automáticas exigem conta demo fora do Strategy Tester";
      return false;
   }
   if(execution_mode != APEA_EXECUTION_TESTER_ONLY &&
      execution_mode != APEA_EXECUTION_DEMO_ONLY)
   {
      status = "bloqueado: modo de execução inválido";
      return false;
   }
   if(!is_tester && !is_demo)
   {
      status = "bloqueado: conta real ou tipo de conta desconhecido";
      return false;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      status = "bloqueado pelas permissões de negociação do terminal/conta";
      return false;
   }

   long spread = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, spread))
   {
      status = "erro ao ler spread do símbolo";
      return false;
   }
   if(maximum_spread_points <= 0.0 || spread > maximum_spread_points)
   {
      status = StringFormat("bloqueado: spread %d pontos acima do limite", spread);
      return false;
   }

   // Protecao por equity de CONTA; inclui variacao de posicoes overnight,
   // taxas e outras operacoes. Latch persistente e falha fechada.
   string guard_status;
   if(!APEA_DailyEquityGuardCheck(maximum_daily_loss_percent, guard_status, true))
   {
      status = guard_status;
      return false;
   }

   double realized_pnl_today = 0.0;
   int entries_today = 0;
   if(!APEA_GetDailyStats(symbol, magic, realized_pnl_today, entries_today))
   {
      status = "P0 BLOQUEADO: erro ao consultar entradas do dia";
      return false;
   }
   if(maximum_entries_per_day < 1 || entries_today >= maximum_entries_per_day)
   {
      status = "bloqueado: limite de entradas do dia atingido";
      return false;
   }
   if(APEA_IsOnePositionOpen(symbol, magic))
   {
      status = "bloqueado: já existe posição desta estratégia no símbolo";
      return false;
   }
   ENUM_ACCOUNT_MARGIN_MODE margin_mode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(margin_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING &&
      APEA_HasPositionOnSymbol(symbol))
   {
      status = "bloqueado: conta netting já tem posição aberta neste símbolo";
      return false;
   }
   if(risk_percent <= 0.0 || risk_percent > 1.0 || reward_risk <= 0.0)
   {
      status = "bloqueado: configuração de risco/relação risco-retorno inválida";
      return false;
   }

   double entry = signal.direction > 0 ?
                  SymbolInfoDouble(symbol, SYMBOL_ASK) :
                  SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(tick_size <= 0.0)
      tick_size = point;
   if(entry <= 0.0 || point <= 0.0 || tick_size <= 0.0)
   {
      status = "erro ao obter cotação ou precisão do símbolo";
      return false;
   }

   double stop_loss = signal.stop_loss;
   if((signal.direction > 0 && stop_loss >= entry) ||
      (signal.direction < 0 && stop_loss <= entry))
   {
      status = "bloqueado: preço já invalidou o stop estrutural";
      return false;
   }
   double risk_distance = MathAbs(entry - stop_loss);
   double take_profit = entry + signal.direction * risk_distance * reward_risk;
   if(signal.direction > 0)
   {
      stop_loss = MathFloor(stop_loss / tick_size) * tick_size;
      take_profit = MathCeil(take_profit / tick_size) * tick_size;
   }
   else
   {
      stop_loss = MathCeil(stop_loss / tick_size) * tick_size;
      take_profit = MathFloor(take_profit / tick_size) * tick_size;
   }
   long stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimum_distance = MathMax((double)stops_level * point, point);
   if(risk_distance < minimum_distance ||
      MathAbs(take_profit - entry) < minimum_distance)
   {
      status = "bloqueado: stop/alvo abaixo da distância mínima do símbolo";
      return false;
   }
   stop_loss = NormalizeDouble(stop_loss, digits);
   take_profit = NormalizeDouble(take_profit, digits);

   ENUM_ORDER_TYPE order_type = signal.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double loss_for_one_lot = 0.0;
   if(!OrderCalcProfit(order_type, symbol, 1.0, entry, stop_loss, loss_for_one_lot) ||
      loss_for_one_lot >= 0.0)
   {
      status = "erro ao estimar perda monetária no stop";
      return false;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = equity * risk_percent / 100.0;
   double raw_volume = risk_money / MathAbs(loss_for_one_lot);
   double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(volume_min <= 0.0 || volume_max < volume_min || volume_step <= 0.0)
   {
      status = "erro: especificação de volume inválida para o símbolo";
      return false;
   }
   double volume = MathMin(raw_volume, volume_max);
   volume = MathFloor(volume / volume_step) * volume_step;
   volume = NormalizeDouble(volume, 8);
   if(volume < volume_min)
   {
      status = "bloqueado: risco configurado produz volume inferior ao mínimo";
      return false;
   }

   double estimated_loss = 0.0;
   if(!OrderCalcProfit(order_type, symbol, volume, entry, stop_loss, estimated_loss) ||
      estimated_loss >= 0.0 ||
      MathAbs(estimated_loss) > risk_money * 1.001)
   {
      status = "erro: volume normalizado excede o risco monetário configurado";
      return false;
   }
   double required_margin = 0.0;
   if(!OrderCalcMargin(order_type, symbol, volume, entry, required_margin) ||
      required_margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      status = "bloqueado: margem livre insuficiente";
      return false;
   }

   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(deviation_points);
   trade.SetTypeFillingBySymbol(symbol);
   trade.SetAsyncMode(false);

   bool request_ok = signal.direction > 0 ?
                     trade.Buy(volume, symbol, 0.0, stop_loss, take_profit, "AlienProfessor") :
                     trade.Sell(volume, symbol, 0.0, stop_loss, take_profit, "AlienProfessor");
   uint retcode = trade.ResultRetcode();
   if(!request_ok ||
      (retcode != TRADE_RETCODE_DONE &&
       retcode != TRADE_RETCODE_DONE_PARTIAL &&
       retcode != TRADE_RETCODE_PLACED))
   {
      status = "ordem recusada: " + trade.ResultRetcodeDescription();
      return false;
   }

   status = StringFormat("ordem enviada; volume %.4f, SL %.*f, TP %.*f",
                         volume, digits, stop_loss, digits, take_profit);
   return true;
}

#endif
