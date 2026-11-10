import re

path = r'C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V11_2_FREEDOM.mq5'
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

m = re.search(r'void\s+AlienTeacherPanel\s*\([^)]*\)\s*\{', text)
start = m.start()
end = text.find('\nvoid ', start + 1)

new_func = """void AlienTeacherPanel(const MqlTick &tk,double atrPts,int trend1,int trend5)
{
   if(!ShowDashboard || !UseGraphicTeacherPanel) return;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<=80 || ch<=90) return;
   int width=(int)MathMin(TeacherPanelWidth,MathMax(220,cw-20));
   int rows=TeacherPanelCompactRows ? 9 : 12;
   int height=rows*29+12;
   if(ch<height+16) { rows=(int)MathMax(5,(ch-30)/29); height=rows*29+12; }
   int offsetX=(int)MathMax(4,TeacherPanelXOffset);
   int offsetY=(int)MathMax(4,TeacherPanelYOffset);
   bool onRight=(TeacherPanelCorner==1 || TeacherPanelCorner==3);
   bool onBottom=(TeacherPanelCorner==2 || TeacherPanelCorner==3);
   int left=onRight ? cw-width-offsetX : offsetX;
   int top=onBottom ? ch-height-offsetY : offsetY;
   left=(int)MathMax(2,MathMin(left,cw-width-2));
   top=(int)MathMax(2,MathMin(top,ch-height-2));
   string bg=teacherPrefix+"BG";
   if(ObjectFind(0,bg)<0) ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,left);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,top);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'15,20,30');
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,clrGold);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,bg,OBJPROP_ZORDER,0);

   bool dailyTargetHit = (StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0 && dailyRealizedNet >= DailyProfitTargetMoney);
   bool dailyLossHit   = (DailyMaxLossMoney > 0.0 && dailyRealizedNet <= -DailyMaxLossMoney);
   bool weeklyLossHit  = (weeklyGuardTripped || (WeeklyMaxLossMoney > 0.0 && weeklyRealizedNet <= -WeeklyMaxLossMoney));
   double curWeeklyLoss = (weeklyRealizedNet < 0.0 ? -weeklyRealizedNet : 0.0);

   string estadoRobo = "OPERANDO AO VIVO";
   if(dailyTargetHit)
      estadoRobo = "META DO DIA BATIDA! [MOTOR DESLIGADO]";
   else if(dailyLossHit)
      estadoRobo = "LIMITE DIARIO ATINGIDO [DESLIGADO ATE AMANHA]";
   else if(weeklyLossHit)
      estadoRobo = "DISJUNTOR SEMANAL ATIVO [PROTECAO TOTAL]";

   string panels[12];
   panels[0] = "=== ALIEN FREEDOM | MESA US$ 10.000 | OPERADOR VITOR ===";
   panels[1] = StringFormat("STATUS: %s | XAUUSD M1", estadoRobo);
   panels[2] = StringFormat("LUCRO HOJE: %+.2f USD | META DO DIA: $%.2f", dailyRealizedNet, DailyProfitTargetMoney);
   panels[3] = StringFormat("PERDA HOJE: $%.2f | LIMITE DIARIO: $%.2f", (dailyRealizedNet<0 ? -dailyRealizedNet : 0.0), DailyMaxLossMoney);
   panels[4] = StringFormat("DISJUNTOR SEMANAL: $%.2f / TETO: $%.2f", curWeeklyLoss, WeeklyMaxLossMoney);
   panels[5] = StringFormat("TRADES HOJE: %d / %d (Blindagem contra excesso de cliques)", dailyEntryDeals, MaxDailyTrades);

   string direcaoBancos = (trend1>0 && trend5>0) ? "ALTA (Compradores no comando)" :
                          ((trend1<0 && trend5<0) ? "BAIXA (Vendedores no comando)" : "CONSOLIDADO (Mercado indeciso)");
   panels[6] = "FLUXO DOS BANCOS: " + direcaoBancos;

   string setupClaro = "Aguardando Pegadinha dos Tubaroes";
   if(lastSetup == 1) setupClaro = "Pegadinha de Fundo/Topo (Falso Rompimento)";
   else if(lastSetup == 2) setupClaro = "Rompeu Estrutura e Veio Testar";
   else if(lastSetup == 3) setupClaro = "Porrada Institucional com Volume";
   else if(lastSetup == 4) setupClaro = "Preenchimento de Vacuo de Preco";
   else if(lastSetup == 5) setupClaro = "Defesa de Regiao dos Bancos";

   panels[7] = "PADRAO DETECTADO: " + setupClaro;
   panels[8] = StringFormat("CUSTOS: Spread %.1f pts | Volatilidade ATR: %.0f pts", (tk.ask-tk.bid)/_Point, atrPts);
   panels[9] = "MATEMATICA: Arrisca pouco para buscar mais que o dobro (R:R > 2:1)";
   panels[10] = "ULTIMA LEITURA: " + (StringLen(lastReason)>50 ? StringSubstr(lastReason,0,48)+"..." : lastReason);
   panels[11] = "SEGURANCA: Stop Loss e Take Profit automaticos no servidor";

   if(LiveTradeTeacherMode && OurPositionCount()>0)
   {
      for(int pi=PositionsTotal()-1; pi>=0; pi--)
      {
         ulong ticket=PositionGetTicket(pi);
         if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
            (ulong)PositionGetInteger(POSITION_MAGIC)!=ExpertMagic) continue;
         bool buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
         int dir=buy?1:-1;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double sl=PositionGetDouble(POSITION_SL);
         double tp=PositionGetDouble(POSITION_TP);
         double vol=PositionGetDouble(POSITION_VOLUME);
         double price=buy?tk.bid:tk.ask;
         double pl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);

         double distanceTP=tp>0.0?MathAbs(tp-price)/_Point:0.0;
         double distanceSL=sl>0.0?MathAbs(price-sl)/_Point:0.0;

         string protecao = "Stop Loss Protegendo a Conta";
         if((buy && sl>=entry) || (!buy && sl<=entry))
            protecao = "RISCO ZERO! Stop ja colocado no Lucro (Break-Even)";

         panels[0] = "=== ALIEN FREEDOM | OPERACAO AO VIVO NA TELA ===";
         panels[1] = StringFormat("ORDEM: %s %.2f LOTES | RESULTADO: %+.2f USD", buy?"COMPRA JUNTO AOS BANCOS":"VENDA JUNTO AOS BANCOS", vol, pl);
         panels[2] = StringFormat("ENTRADA: %.2f | ATUAL: %.2f | PADRAO: %s", entry, price, setupClaro);
         panels[3] = StringFormat("ALVO (TP): %.2f (Faltam %.0f pts) | STOP: %.2f (Faltam %.0f pts)", tp, distanceTP, sl, distanceSL);
         panels[4] = "STATUS DA PROTECAO: " + protecao;
         panels[5] = pl>0 ? "ANDAMENTO: Ouro correndo a nosso favor! Buscando alvo..." : "ANDAMENTO: Flutuacao normal; ordem blindada pelo stop.";
         panels[6] = StringFormat("LUCRO HOJE COM FECHADAS: %+.2f USD | META: $%.2f", dailyRealizedNet, DailyProfitTargetMoney);
         panels[7] = "REGRA: Deixe o robo trabalhar. Nunca feche por panico!";
         panels[8] = StringFormat("TRAVA DIARIA: Perda maxima controlada em $%.2f", DailyMaxLossMoney);
         panels[9] = "PROXIMO PASSO: Stop move sozinho pro zero a zero quando avancar.";
         panels[10] = "DISCIPLINA: A matematica do lucro esta programada em codigo.";
         panels[11] = "OPERADOR VITOR: Relaxe e observe a maquina executar.";
         break;
      }
   }

   for(int r=0;r<rows;r++)
   {
      color rowColor = clrWhite;
      if(r==0 || r==2) rowColor = clrGold;
      else if(r==1 && dailyTargetHit) rowColor = clrLime;
      else if(r==4 || r==7) rowColor = clrAqua;
      AlienPanelRow(r,panels[r],rowColor,left,top,width);
   }
   for(int r=rows;r<12;r++)
   {
      ObjectSetString(0,teacherPrefix+"R"+IntegerToString(r),OBJPROP_TEXT," ");
      ObjectSetString(0,teacherPrefix+"R"+IntegerToString(r)+"_B",OBJPROP_TEXT," ");
   }
}
"""

new_text = text[:start] + new_func + text[end:]
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_text)

print('ALIEN_V11_2_FREEDOM.mq5 atualizado com variaveis corretas!')
