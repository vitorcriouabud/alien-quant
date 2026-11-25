#property strict
#property script_show_inputs
#property version   "1.00"
#property description "Exportacao somente leitura do historico de deals MT5."

// Este script APENAS le o historico da conta e grava um CSV em MQL5/Files.
// Nao envia, altera, cancela ou fecha ordens/posicoes.
// Exporta todos os magics do simbolo para identificar fechamentos externos.

input string InpSymbolFilter = "XAUUSD";       // Simbolo exato; vazio = todos
input int    InpLookbackDays = 90;             // Historico em dias (1 a 3650)
input ulong  InpAlienMagic   = 802092;         // Apenas para resumo; NAO filtra o CSV
input string InpFilePrefix   = "ALIEN_DEALS_READONLY";

string TimestampForFile(datetime value)
{
   string s = TimeToString(value, TIME_DATE | TIME_SECONDS);
   StringReplace(s, ".", "");
   StringReplace(s, ":", "");
   StringReplace(s, " ", "_");
   return s;
}

void OnStart()
{
   if(InpLookbackDays < 1 || InpLookbackDays > 3650)
   {
      Print("ALIEN READ-ONLY: InpLookbackDays deve estar entre 1 e 3650.");
      return;
   }

   string symbolFilter = InpSymbolFilter;
   StringTrimLeft(symbolFilter);
   StringTrimRight(symbolFilter);

   string prefix = InpFilePrefix;
   StringTrimLeft(prefix);
   StringTrimRight(prefix);
   if(prefix == "")
      prefix = "ALIEN_DEALS_READONLY";

   datetime toTime = TimeTradeServer();
   if(toTime <= 0)
      toTime = TimeCurrent();
   if(toTime <= 0)
   {
      Print("ALIEN READ-ONLY: horario do servidor indisponivel.");
      return;
   }

   datetime fromTime = toTime - (datetime)(InpLookbackDays * 86400);
   ResetLastError();
   if(!HistorySelect(fromTime, toTime))
   {
      PrintFormat("ALIEN READ-ONLY: HistorySelect falhou. erro=%d", GetLastError());
      return;
   }

   string fileName = prefix + "_" + TimestampForFile(toTime) + ".csv";
   ResetLastError();
   int handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_UNICODE | FILE_SHARE_READ, ';');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("ALIEN READ-ONLY: nao foi possivel criar %s. erro=%d", fileName, GetLastError());
      return;
   }

   FileWrite(handle,
      "deal_ticket",
      "order_ticket",
      "position_id",
      "time_server",
      "time_msc",
      "symbol",
      "magic",
      "entry",
      "type",
      "reason",
      "volume",
      "price",
      "profit",
      "commission",
      "swap",
      "fee",
      "comment"
   );

   int totalDeals = HistoryDealsTotal();
   int exported = 0;
   int alienMagicRows = 0;
   int otherMagicRows = 0;

   for(int i = 0; i < totalDeals; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      if(symbolFilter != "" && symbol != symbolFilter)
         continue;

      long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      ulong orderTicket = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
      ulong positionId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      long dealTimeMsc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);

      double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      double fee = HistoryDealGetDouble(deal, DEAL_FEE);
      string comment = HistoryDealGetString(deal, DEAL_COMMENT);

      FileWrite(handle,
         (string)deal,
         (string)orderTicket,
         (string)positionId,
         TimeToString(dealTime, TIME_DATE | TIME_SECONDS),
         (string)dealTimeMsc,
         symbol,
         (string)magic,
         EnumToString(entry),
         EnumToString(type),
         EnumToString(reason),
         DoubleToString(volume, 8),
         DoubleToString(price, 8),
         DoubleToString(profit, 8),
         DoubleToString(commission, 8),
         DoubleToString(swap, 8),
         DoubleToString(fee, 8),
         comment
      );

      ++exported;
      if((ulong)magic == InpAlienMagic)
         ++alienMagicRows;
      else
         ++otherMagicRows;
   }

   FileFlush(handle);
   FileClose(handle);

   PrintFormat("ALIEN READ-ONLY: exportacao concluida. Deals=%d | Magic ALIEN %I64u=%d | outros magics=%d",
               exported, InpAlienMagic, alienMagicRows, otherMagicRows);
   PrintFormat("ALIEN READ-ONLY: arquivo MQL5/Files/%s | periodo %s ate %s | simbolo=%s",
               fileName,
               TimeToString(fromTime, TIME_DATE | TIME_SECONDS),
               TimeToString(toTime, TIME_DATE | TIME_SECONDS),
               symbolFilter == "" ? "TODOS" : symbolFilter);
   Print("ALIEN READ-ONLY: nenhum pedido de negociacao, modificacao ou fechamento foi enviado.");
}
