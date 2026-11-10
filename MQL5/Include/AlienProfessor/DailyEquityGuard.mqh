#ifndef ALIEN_PROFESSOR_DAILY_EQUITY_GUARD_MQH
#define ALIEN_PROFESSOR_DAILY_EQUITY_GUARD_MQH

// P0 — Protecao de NOVAS ENTRADAS por equity de CONTA (nao somente Magic/Symbol).
// Nao fecha posicoes existentes. Nao habilita ordens. A base e o primeiro
// patrimonio observavel do dia de servidor, nao necessariamente 00:00:00.
// Se a base nao puder ser justificada, falha FECHADA.
// Terminal Global Variables persistem a trava na DEMO; o Tester usa memoria
// para evitar contaminacao entre backtests independentes.

int      g_APEA_p0_last_day = 0;
bool     g_APEA_p0_last_day_ready = false;
datetime g_APEA_p0_last_good_observation = 0;
int      g_APEA_p0_test_day = 0;
bool     g_APEA_p0_test_ready = false;
bool     g_APEA_p0_test_locked = false;
double   g_APEA_p0_test_anchor = 0.0;
int      g_APEA_p0_cash_day = 0;
datetime g_APEA_p0_cash_updated = 0;
double   g_APEA_p0_cash_flows = 0.0;
int      g_APEA_p0_deals_today = 0;
bool     g_APEA_p0_cash_valid = false;

int APEA_P0_DayKey(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.year * 10000 + parts.mon * 100 + parts.day;
}

string APEA_P0_GuardPrefix(const int day_key)
{
   string server = AccountInfoString(ACCOUNT_SERVER);
   long hash = 7;
   for(int i = 0; i < StringLen(server); ++i)
      hash = (hash * 131 + (long)StringGetCharacter(server, i)) % 1000000007;
   return StringFormat("ALP0_%I64d_%I64d_%d",
                       AccountInfoInteger(ACCOUNT_LOGIN), hash, day_key);
}

// Equity ja reflete PnL realizado, floating, DEAL_FEE, commission e swap.
// So removemos da variacao intradiaria creditos/debitos de CAPITAL que
// nao sao desempenho da negociacao; taxas operacionais continuam na equity.
// Correcao contabil controvertida: bloquear ate revisao, sem adivinhacao.
bool APEA_P0_CashFlows(const datetime day_start,
                      const datetime now,
                      const int day_key,
                      const bool force_update,
                      double &capital_flow,
                      int &deal_count,
                      string &reason)
{
   if(!force_update && g_APEA_p0_cash_valid &&
      g_APEA_p0_cash_day == day_key && g_APEA_p0_cash_updated == now)
   {
      capital_flow = g_APEA_p0_cash_flows;
      deal_count = g_APEA_p0_deals_today;
      return true;
   }

   capital_flow = 0.0;
   deal_count = 0;
   g_APEA_p0_cash_valid = false;
   ResetLastError();
   if(!HistorySelect(day_start, now))
   {
      reason = StringFormat("P0 BLOQUEADO: historico indisponivel (%d)", GetLastError());
      return false;
   }

   deal_count = HistoryDealsTotal();
   for(int i = 0; i < deal_count; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
      {
         reason = "P0 BLOQUEADO: deal historico sem identificacao";
         return false;
      }
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(type == DEAL_TYPE_CORRECTION ||
         type == DEAL_TYPE_BUY_CANCELED ||
         type == DEAL_TYPE_SELL_CANCELED)
      {
         reason = "P0 BLOQUEADO: correcao/cancelamento contabil exige auditoria";
         return false;
      }
      if(type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT || type == DEAL_TYPE_BONUS)
      {
         capital_flow += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         capital_flow += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         capital_flow += HistoryDealGetDouble(ticket, DEAL_SWAP);
         capital_flow += HistoryDealGetDouble(ticket, DEAL_FEE);
      }
   }
   if(!MathIsValidNumber(capital_flow))
   {
      reason = "P0 BLOQUEADO: fluxo financeiro invalido";
      return false;
   }

   g_APEA_p0_cash_flows = capital_flow;
   g_APEA_p0_deals_today = deal_count;
   g_APEA_p0_cash_day = day_key;
   g_APEA_p0_cash_updated = now;
   g_APEA_p0_cash_valid = true;
   return true;
}

bool APEA_P0_StoreNewAnchor(const string key_base,
                            const string key_lock,
                            const double equity,
                            string &reason)
{
   // Lock=1 ate terminar a escrita; queda do terminal => erro seguro.
   if(GlobalVariableSet(key_lock, 1.0) == 0)
   {
      reason = "P0 BLOQUEADO: falha ao reservar trava persistente";
      return false;
   }
   if(GlobalVariableSet(key_base, equity) == 0)
   {
      reason = "P0 BLOQUEADO: falha ao persistir equity inicial";
      return false;
   }
   GlobalVariablesFlush();
   if(GlobalVariableSet(key_lock, 0.0) == 0)
   {
      reason = "P0 BLOQUEADO: falha ao liberar inicializacao persistente";
      return false;
   }
   GlobalVariablesFlush();
   return true;
}

// Retorno TRUE = apenas esta verificacao de perda diaria permite tentar
// uma nova entrada. Outras portas de risco/exposicao continuam obrigatorias.
bool APEA_DailyEquityGuardCheck(const double maximum_daily_loss_percent,
                                string &status,
                                const bool force_history = false)
{
   status = "P0: nao inicializado";
   if(maximum_daily_loss_percent <= 0.0 || maximum_daily_loss_percent > 5.0)
   {
      status = "P0 BLOQUEADO: limite diario invalido";
      return false;
   }
   const datetime now = TimeCurrent();
   if(now <= 0 || AccountInfoInteger(ACCOUNT_LOGIN) <= 0)
   {
      status = "P0 BLOQUEADO: horario/conta nao disponivel";
      return false;
   }
   const int day_key = APEA_P0_DayKey(now);
   MqlDateTime fields;
   TimeToStruct(now, fields);
   fields.hour = 0; fields.min = 0; fields.sec = 0;
   const datetime day_start = StructToTime(fields);
   const int previous_day_key = APEA_P0_DayKey(day_start - 1);
   // So aceitamos rollover se a guarda estava VALIDADA no dia anterior
   // e houve observacao perto da virada; um erro no dia anterior nao serve.
   const bool observed_previous_day =
      (g_APEA_p0_last_day == previous_day_key &&
       g_APEA_p0_last_day_ready &&
       g_APEA_p0_last_good_observation >= day_start - 7200 &&
       now <= day_start + 7200);
   if(g_APEA_p0_last_day != day_key)
   {
      g_APEA_p0_last_day = day_key;
      g_APEA_p0_last_day_ready = false;
   }

   double capital_flow = 0.0;
   int deals_today = 0;
   string reason = "";
   if(!APEA_P0_CashFlows(day_start, now, day_key, force_history,
                         capital_flow, deals_today, reason))
   {
      status = reason;
      return false;
   }

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(equity) || equity <= 0.0)
   {
      status = "P0 BLOQUEADO: equity indisponivel/invalida";
      return false;
   }

   const bool tester = (MQLInfoInteger(MQL_TESTER) != 0);
   double anchor = 0.0;
   bool locked = false;
   if(tester)
   {
      if(g_APEA_p0_test_day != day_key)
      {
         g_APEA_p0_test_day = day_key;
         g_APEA_p0_test_ready = false;
         g_APEA_p0_test_locked = false;
         g_APEA_p0_test_anchor = 0.0;
      }
      if(!g_APEA_p0_test_ready)
      {
         // Primeira observacao segura: nenhuma posicao e nenhum deal hoje,
         // OU um rollover realmente observado nesta execucao (sem deals novos).
         if(deals_today > 0 || (PositionsTotal() > 0 && !observed_previous_day))
         {
            status = "P0 BLOQUEADO: sem foto confiavel do inicio do dia";
            return false;
         }
         g_APEA_p0_test_anchor = equity;
         g_APEA_p0_test_ready = true;
      }
      anchor = g_APEA_p0_test_anchor;
      locked = g_APEA_p0_test_locked;
   }
   else
   {
      const string key = APEA_P0_GuardPrefix(day_key);
      const string key_base = key + "_B";
      const string key_lock = key + "_L";
      const bool base_exists = GlobalVariableCheck(key_base);
      const bool lock_exists = GlobalVariableCheck(key_lock);
      if(base_exists != lock_exists)
      {
         status = "P0 BLOQUEADO: dados persistentes incompletos";
         return false;
      }
      if(!base_exists)
      {
         if(deals_today > 0 || (PositionsTotal() > 0 && !observed_previous_day))
         {
            status = "P0 BLOQUEADO: sem foto confiavel do inicio do dia";
            return false;
         }
         if(!APEA_P0_StoreNewAnchor(key_base, key_lock, equity, status))
            return false;
      }
      double lock_number = 0.0;
      if(!GlobalVariableGet(key_base, anchor) ||
         !GlobalVariableGet(key_lock, lock_number))
      {
         status = "P0 BLOQUEADO: nao foi possivel recuperar a foto persistente";
         return false;
      }
      if(lock_number != 0.0 && lock_number != 1.0)
      {
         status = "P0 BLOQUEADO: trava persistente invalida";
         return false;
      }
      locked = (lock_number > 0.5);
   }

   if(!MathIsValidNumber(anchor) || anchor <= 0.0)
   {
      status = "P0 BLOQUEADO: equity inicial invalida";
      return false;
   }
   const double daily_change = equity - anchor - capital_flow;
   const double maximum_loss_money = anchor * maximum_daily_loss_percent / 100.0;
   if(!MathIsValidNumber(daily_change) || maximum_loss_money <= 0.0)
   {
      status = "P0 BLOQUEADO: calculo do limite diario invalido";
      return false;
   }

   if(daily_change <= -maximum_loss_money && !locked)
   {
      if(tester)
      {
         g_APEA_p0_test_locked = true;
         locked = true;
      }
      else
      {
         const string key_lock = APEA_P0_GuardPrefix(day_key) + "_L";
         if(!GlobalVariableSetOnCondition(key_lock, 1.0, 0.0))
         {
            status = "P0 BLOQUEADO: falha ao persistir disparo da trava";
            return false;
         }
         GlobalVariablesFlush();
         locked = true;
      }
      PrintFormat("ALIEN P0: TRAVA DIARIA ACIONADA | data %d | base %.2f | equity %.2f | fluxo %.2f | delta %.2f | limite %.2f",
                  day_key, anchor, equity, capital_flow, daily_change, maximum_loss_money);
   }
   // Referencia verificada nesta observacao; sera elegivel para rollover.
   g_APEA_p0_last_day_ready = true;
   g_APEA_p0_last_good_observation = now;
   if(locked)
   {
      status = StringFormat("P0 BLOQUEADO: perda diaria/trava persistente | %d | base %.2f | equity %.2f | fluxo %.2f | delta %.2f | limite %.2f",
                            day_key, anchor, equity, capital_flow, daily_change, maximum_loss_money);
      return false;
   }
   status = StringFormat("P0 OK | %d | base %.2f | equity %.2f | fluxo %.2f | delta %.2f | limite %.2f",
                         day_key, anchor, equity, capital_flow, daily_change, maximum_loss_money);
   return true;
}

#endif
