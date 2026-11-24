//+------------------------------------------------------------------+
//| ALIEN GMG AUTO-ATTACH V1 (SCRIPT SEM OPERACOES)                   |
//| Localiza grafico XAUUSD M1, inclui indicador visual e registra  |
//| resultado em MQL5/Files/ALIEN_GMG_AUTOSTART_RESULTADO.txt.       |
//+------------------------------------------------------------------+
#property strict
#property version "1.000"
#property description "Inicializa indicador visual GMG sem enviar ordens"

string resultFile="ALIEN_GMG_AUTOSTART_RESULTADO.txt";

void SaveResult(const string code,const string message)
{
   int f=FileOpen(resultFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(f!=INVALID_HANDLE)
   {
      FileWriteString(f,code+"\r\n"+message+"\r\n"+TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS)+"\r\n");
      FileClose(f);
   }
   Print("ALIEN GMG AUTO: ",code," - ",message);
}

bool IsGold(const string symbol)
{
   if(StringFind(symbol,"XAUUSD")>=0) return true;
   if(StringFind(symbol,"GOLD")>=0) return true;
   return false;
}

string FindGold()
{
   if(SymbolSelect("XAUUSD",true)) return "XAUUSD";
   for(int all=0;all<2;all++)
   {
      bool selectedOnly=(all==0);
      int total=SymbolsTotal(selectedOnly);
      for(int i=0;i<total;i++)
      {
         string s=SymbolName(i,selectedOnly);
         if(!IsGold(s)) continue;
         if(SymbolSelect(s,true)) return s;
      }
   }
   return "";
}

long ExistingChart(const string symbol)
{
   long id=ChartFirst();
   while(id>=0)
   {
      if(ChartSymbol(id)==symbol && ChartPeriod(id)==PERIOD_M1)
         return id;
      id=ChartNext(id);
   }
   return -1;
}

bool HasGMG(const long chart)
{
   int total=ChartIndicatorsTotal(chart,0);
   for(int i=0;i<total;i++)
   {
      string name=ChartIndicatorName(chart,0,i);
      if(StringFind(name,"ALIEN / GMG SMC VISUAL")==0) return true;
   }
   return false;
}

void OnStart()
{
   string symbol=FindGold();
   if(symbol=="")
   {
      SaveResult("ERRO_SIMBOLO","XAUUSD/GOLD indisponivel na conta conectada.");
      return;
   }
   long chart=ExistingChart(symbol);
   if(chart<0)
   {
      chart=ChartOpen(symbol,PERIOD_M1);
      if(chart<=0)
      {
         SaveResult("ERRO_ABRIR_GRAFICO","Nao conseguiu abrir "+symbol+" M1; erro="+IntegerToString(GetLastError()));
         return;
      }
   }
   // Da ao MT5 oportunidade de concluir a criacao do grafico novo.
   for(int attempt=0;attempt<30;attempt++)
   {
      if(ChartSymbol(chart)==symbol && ChartPeriod(chart)==PERIOD_M1) break;
      Sleep(200);
   }
   if(HasGMG(chart))
   {
      ChartSetInteger(chart,CHART_BRING_TO_TOP,true);
      ChartRedraw(chart);
      SaveResult("OK_JA_INSTALADO",symbol+" M1 | indicador ja presente.");
      return;
   }
   int handle=iCustom(symbol,PERIOD_M1,"ALIEN_GMG_SMC_VISUAL_V1");
   if(handle==INVALID_HANDLE)
   {
      SaveResult("ERRO_CRIAR_INDICADOR","iCustom falhou; erro="+IntegerToString(GetLastError()));
      return;
   }
   bool added=false;
   int lastErr=0;
   for(int tryAdd=0;tryAdd<15;tryAdd++)
   {
      ResetLastError();
      if(ChartIndicatorAdd(chart,0,handle)) {added=true; break;}
      lastErr=GetLastError();
      Sleep(250);
   }
   if(!added)
   {
      SaveResult("ERRO_ANEXAR_INDICADOR","ChartIndicatorAdd falhou; erro="+IntegerToString(lastErr));
      IndicatorRelease(handle);
      return;
   }
   ChartSetInteger(chart,CHART_BRING_TO_TOP,true);
   ChartRedraw(chart);
   SaveResult("OK_ADICIONADO",symbol+" M1 | indicador anexado ao grafico; sem ordens.");
   // O proprio grafico passou a referenciar o indicador; nao liberamos
   // explicitamente o handle apos ChartIndicatorAdd.
}
