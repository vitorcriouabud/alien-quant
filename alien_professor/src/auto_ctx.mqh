
//====================================================================
// v12.5: CONTEXTO DE TEMPO, MERCADO, AGENDA E SEMANA PRA IA (vai em todo prompt)
// Tudo em horário de Brasília (UTC-3, sem horário de verão).
// Ouro: semana abre domingo 18:00 de NY e fecha sexta 17:00 de NY; pausa diária seg-qui 17:00-18:00 de NY.
// NY com horário de verão dos EUA (EngNyOffset): EST -> abre 20:00 Brasília; EDT -> abre 19:00 Brasília.
string g_diaSem[7]={"domingo","segunda","terça","quarta","quinta","sexta","sábado"};
string g_diaSemC[7]={"dom","seg","ter","qua","qui","sex","sáb"};
string DiaHoraBR(datetime br,bool ano=false,bool curto=false)
{
   MqlDateTime d; TimeToStruct(br,d);
   string ds=curto?g_diaSemC[d.day_of_week]:g_diaSem[d.day_of_week];
   if(ano) return StringFormat("%s %02d/%02d/%04d %02d:%02d",ds,d.day,d.mon,d.year,d.hour,d.min);
   return StringFormat("%s %02d/%02d %02d:%02d",ds,d.day,d.mon,d.hour,d.min);
}
string DuracaoTxt(long seg)
{
   if(seg<0) seg=0;
   int m=(int)((seg+59)/60), h=m/60; m%=60;
   if(h>=24) return StringFormat("%dd %dh",h/24,h%24);
   return h>0?StringFormat("%dh%02dmin",h,m):StringFormat("%dmin",m);
}
// horário "de parede" de NY -> GMT (respeita o horário de verão dos EUA)
datetime NyParaGmt(datetime ny){ datetime g=ny+5*3600; return (datetime)(ny+EngNyOffset(g)*3600); }
int NyDiaSem(datetime gmt){ MqlDateTime d; TimeToStruct(EngNyTime(gmt),d); return d.day_of_week; }
// estado da grade do ouro: 0=aberto, 1=pausa diária, 2=fim de semana. muda = próxima virada (GMT)
int GradeOuro(datetime gmt,datetime &muda)
{
   datetime ny=EngNyTime(gmt); MqlDateTime d; TimeToStruct(ny,d);
   int hm=d.hour*60+d.min; datetime dia=ny-(d.hour*3600+d.min*60+d.sec);
   int w=d.day_of_week;
   if((w==5 && hm>=17*60) || w==6 || (w==0 && hm<18*60))
   {
      int ate=(w==5?2:(w==6?1:0));
      muda=NyParaGmt(dia+ate*86400+18*3600); return 2;
   }
   if(w>=1 && w<=4 && hm>=17*60 && hm<18*60){ muda=NyParaGmt(dia+18*3600); return 1; }
   muda=NyParaGmt(hm<17*60 ? dia+17*3600 : dia+86400+17*3600);
   return 0;
}
// próxima killzone (NY 02:00 Londres, 07:00 NY manhã, 13:30 NY tarde), em dia útil
string ProxKillzoneBR(datetime gmt)
{
   datetime ny=EngNyTime(gmt); MqlDateTime d; TimeToStruct(ny,d);
   datetime dia=ny-(d.hour*3600+d.min*60+d.sec);
   int ini[3]={120,420,810}; string nm[3]={"Londres","NY manhã","NY tarde"};
   for(int k=0;k<8;k++)
      for(int i=0;i<3;i++)
      {
         datetime c=dia+k*86400+ini[i]*60; if(c<=ny) continue;
         MqlDateTime x; TimeToStruct(c,x); if(x.day_of_week==0 || x.day_of_week==6) continue;
         datetime g=NyParaGmt(c);
         return "killzone "+nm[i]+" "+DiaHoraBR(g-3*3600,false,true)+" Brasília (em "+DuracaoTxt((long)(g-gmt))+")";
      }
   return "";
}
// linha pura (testável): agora + status do mercado + reabertura/pausa
// semTick = sem tick há mais de 5 min; ultTickGmt = hora do último tick (GMT, 0 = não sei)
string MercadoAgoraTxt(datetime gmt,bool semTick,datetime ultTickGmt)
{
   datetime br=gmt-3*3600, muda; int st=GradeOuro(gmt,muda);
   int off=EngNyOffset(gmt), pIni=17+off-3;                       // pausa diária em Brasília
   string s="AGORA: "+DiaHoraBR(br,true)+" (Brasília). Hoje é "+g_diaSem[TimeDayOfWeekX(br)]+".\n";
   string desde=(ultTickGmt>0?" desde "+DiaHoraBR(ultTickGmt-3*3600)+" Brasília":"");
   if(!semTick && st==0)
   {
      bool sexta=(NyDiaSem(muda)==5);
      s+="MERCADO (ouro): ABERTO. Próxima parada: "+DiaHoraBR(muda-3*3600)+" Brasília ("+(sexta?"fecha a semana até domingo":"pausa diária de 1h")+", em "+DuracaoTxt((long)(muda-gmt))+").";
   }
   else if(!semTick)
      s+="MERCADO (ouro): ABERTO (tem tick ao vivo, mesmo no horário de pausa).";
   else if(st==0)
      s+="MERCADO: SEM TICK"+desde+", mas pela grade deveria estar aberto (pode ser feriado, corretora parada ou MT5 sem conexão). Não sei a hora exata da volta: diga isso, não invente.";
   else
      s+="MERCADO (ouro): FECHADO"+desde+" ("+(st==2?"fim de semana":"pausa diária")+"). REABRE "+DiaHoraBR(muda-3*3600)+" Brasília (em "+DuracaoTxt((long)(muda-gmt))+"). Preços = último fechamento, nada ao vivo.";
   s+=StringFormat("\nGRADE DO OURO (Brasília, NY %s): abre domingo %02d:00, fecha sexta %02d:00, pausa diária seg-qui %02d:00-%02d:00.",
      off==4?"no horário de verão":"no horário padrão",pIni+1,pIni,pIni,pIni+1);
   return s;
}
int TimeDayOfWeekX(datetime t){ MqlDateTime d; TimeToStruct(t,d); return d.day_of_week; }
string RoboLinhaIA()
{
   string modo=TradeAtivo()?"operando (manda ordens, dentro dos limites)":(g_tradePausa?"pausado pelo /pausa (não manda ordem)":"modo assistente (só analisa e avisa, não manda ordem)");
   return StringFormat("ROBÔ: você é o Alier v%s no %s %s, conta %s, %s. Hoje: %d trades, %d stops, resultado $%+.2f. Posições abertas: %d.",
      APROF_VER,_Symbol,StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",modo,g_tradesHoje,g_stopsHoje,g_netHoje,PositionsTotal());
}
string SessaoLinhaIA(datetime gmt,bool fechado)
{
   string kz=fechado?"mercado fechado":EngKillzone(gmt);
   string px=ProxKillzoneBR(gmt);
   return "SESSÃO: "+kz+(px!=""?". Próxima: "+px:"")+".";
}
// ---- agenda econômica (calendário do MT5): próximos 7 dias + resultados fortes dos últimos 7 ----
string CalFmt(double v,const MqlCalendarEvent &ev)
{
   string s=DoubleToString(v,(MathAbs(v)<10?2:1));
   if(ev.multiplier==CALENDAR_MULTIPLIER_THOUSANDS) s+="K"; else if(ev.multiplier==CALENDAR_MULTIPLIER_MILLIONS) s+="M"; else if(ev.multiplier==CALENDAR_MULTIPLIER_BILLIONS) s+="B";
   if(ev.unit==CALENDAR_UNIT_PERCENT) s+="%";
   return s;
}
string g_agIA="", g_agRes=""; datetime g_agIAt=0;
void AgendaCarrega()
{
   datetime now=TimeTradeServer(); if(now<=0) return;
   if(g_agIAt>0 && now-g_agIAt<1800) return;
   g_agIAt=now; g_agIA=""; g_agRes="";
   string cs[]; string lst="USD,"+InpCalMoedas; int nc=StringSplit(lst,',',cs);
   datetime ft[]; int fp[]; string fl[]; datetime rt[]; string rl[]; string vistos="|";
   for(int c=0;c<nc;c++)
   {
      string cur=cs[c]; StringTrimLeft(cur); StringTrimRight(cur); StringToUpper(cur);
      if(StringLen(cur)!=3 || StringFind(vistos,"|"+cur+"|")>=0) continue; vistos+=cur+"|";
      MqlCalendarValue v[];
      if(CalendarValueHistory(v,now-7*86400,now+7*86400,NULL,cur)<=0) continue;
      for(int i=0;i<ArraySize(v);i++)
      {
         MqlCalendarEvent ev; if(!CalendarEventById(v[i].event_id,ev)) continue;
         bool fer=(ev.type==CALENDAR_TYPE_HOLIDAY);
         int imp=ev.importance==CALENDAR_IMPORTANCE_HIGH?3:(ev.importance==CALENDAR_IMPORTANCE_MODERATE?2:0);
         if(!fer && (imp<2 || (cur!="USD" && imp<3))) continue;   // USD forte+média; outras só forte
         string nm=ev.name; StringReplace(nm,"\"","'"); if(StringLen(nm)>42) nm=StringSubstr(nm,0,42);
         string q=DiaHoraBR(SrvParaBR(v[i].time),false,true);
         if(v[i].time>=now-15*60)
         {
            string x="";
            if(v[i].HasForecastValue()) x+="prev "+CalFmt(v[i].GetForecastValue(),ev);
            if(v[i].HasPreviousValue()) x+=(x==""?"":", ")+"ant "+CalFmt(v[i].GetPreviousValue(),ev);
            string l=fer?q+" 🏖️ "+cur+" FERIADO: "+nm+" (mercado pode abrir mais curto/fraco)":q+" "+(imp==3?"🔴":"🟡")+" "+cur+" "+nm+(x!=""?" ("+x+")":"");
            int k=ArraySize(fl); ArrayResize(fl,k+1); ArrayResize(ft,k+1); ArrayResize(fp,k+1);
            fl[k]=l; ft[k]=v[i].time; fp[k]=fer?4:imp;
         }
         else if(!fer && imp==3 && v[i].HasActualValue())
         {
            string x="saiu "+CalFmt(v[i].GetActualValue(),ev);
            if(v[i].HasForecastValue()) x+=", prev "+CalFmt(v[i].GetForecastValue(),ev);
            if(v[i].HasPreviousValue()) x+=", ant "+CalFmt(v[i].GetPreviousValue(),ev);
            int k=ArraySize(rl); ArrayResize(rl,k+1); ArrayResize(rt,k+1);
            rl[k]=q+" "+cur+" "+nm+": "+x; rt[k]=v[i].time;
         }
      }
   }
   // próximos: até 8, primeiro feriado/forte, depois média; mostra em ordem de horário
   int n=ArraySize(fl); bool pega[]; ArrayResize(pega,n); for(int i=0;i<n;i++) pega[i]=false;
   int tot=0;
   for(int p=4;p>=2 && tot<8;p--)
      for(int i=0;i<n && tot<8;i++)
      {
         int best=-1; for(int j=0;j<n;j++) if(!pega[j] && fp[j]==p && (best<0 || ft[j]<ft[best])) best=j;
         if(best<0) break; pega[best]=true; tot++;
      }
   for(int r=0;r<tot;r++)
   {
      int best=-1; for(int j=0;j<n;j++) if(pega[j] && (best<0 || ft[j]<ft[best])) best=j;
      if(best<0) break; g_agIA+=fl[best]+"\n"; pega[best]=false;
   }
   // resultados: os 4 fortes mais recentes
   int m=ArraySize(rl); bool us[]; ArrayResize(us,m); for(int i=0;i<m;i++) us[i]=false;
   string tmp[]; int nt=0;
   for(int r=0;r<4 && r<m;r++)
   {
      int best=-1; for(int j=0;j<m;j++) if(!us[j] && (best<0 || rt[j]>rt[best])) best=j;
      if(best<0) break; us[best]=true; ArrayResize(tmp,nt+1); tmp[nt++]=rl[best];
   }
   for(int i=nt-1;i>=0;i--) g_agRes+=tmp[i]+"\n";
}
string AgendaSemanaIA(bool resultados=true)
{
   if(!CalOn()) return "AGENDA ECONÔMICA: o calendário do MT5 está "+(InpCalendario?"indisponível no testador":"desligado nas configurações (InpCalendario)")+".\n";
   AgendaCarrega();
   string s="AGENDA ECONÔMICA (calendário do MT5, Brasília; 🔴 forte 🟡 média; prev=previsão, ant=anterior). Você TEM esta agenda:\n";
   s+=(g_agIA!=""?g_agIA:"nenhuma notícia forte ou média de USD marcada nos próximos 7 dias.\n");
   if(resultados && g_agRes!="") s+="RESULTADOS FORTES DOS ÚLTIMOS 7 DIAS:\n"+g_agRes;
   return s;
}
// ---- fechamento e semana (pra 'o que esperar da abertura') ----
string SemanaIA(bool fimSemana)
{
   MqlRates w[]; ArraySetAsSeries(w,true); if(CopyRates(_Symbol,PERIOD_W1,0,2,w)<2) return "";
   double last=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(last<=0) last=iClose(_Symbol,PERIOD_M1,0); if(last<=0) return "";
   // VWAP da semana (H1, volume de tick)
   MqlRates h[]; ArraySetAsSeries(h,true); int nh=CopyRates(_Symbol,PERIOD_H1,w[0].time,TimeCurrent()+3600,h);
   double pv=0,vv=0; for(int i=0;i<nh;i++){ double tp=(h[i].high+h[i].low+h[i].close)/3.0; pv+=tp*(double)h[i].tick_volume; vv+=(double)h[i].tick_volume; }
   double vw=vv>0?pv/vv:0;
   MqlRates d[]; ArraySetAsSeries(d,true); double atrD=(CopyRates(_Symbol,PERIOD_D1,0,30,d)>=16)?ATRof(d,14,1):0;
   string a=fimSemana?"semana que fechou":"semana atual", b=fimSemana?"semana anterior":"semana passada";
   string ondeAnt=last>w[1].high?"ACIMA da máxima da "+b:(last<w[1].low?"ABAIXO da mínima da "+b:"dentro da faixa da "+b);
   string s=StringFormat("SEMANA (%s): %s %s. %s: abriu %s, máx %s, mín %s, faixa %s. %s: máx %s, mín %s. Preço %s",
      _Symbol,fimSemana?"Fechamento de sexta":"Preço agora",Fmt(last),a,Fmt(w[0].open),Fmt(w[0].high),Fmt(w[0].low),Fmt(w[0].high-w[0].low),b,Fmt(w[1].high),Fmt(w[1].low),ondeAnt);
   if(vw>0) s+=StringFormat(", %s da VWAP da semana (%s)",last>=vw?"acima":"abaixo",Fmt(vw));
   if(atrD>0) s+=StringFormat(". ATR diário ~%s",Fmt(atrD));
   s+=StringFormat(". Viés do robô: D1 %s, H4 %s, H1 %s; viés do dia: %s.",TendPalavra(g_mtf[0]),TendPalavra(g_mtf[1]),TendPalavra(g_mtf[2]),g_biasTxt);
   return s;
}
bool EhPerguntaAbertura(string t)
{
   string u=AISemAcento(t); StringToLower(u);
   string k[]={"abertura","reabr","abre ","abrir","vai abrir","fechament","fechou","semana","segunda","gap","domingo"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
bool EhPerguntaAgenda(string t)
{
   string u=AISemAcento(t); StringToLower(u);
   string k[]={"notic","agenda","calend","payroll","cpi","fomc","fed","juros","inflac","emprego","pib","semana","abertura","feriado","evento"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
// bloco compacto que vai antes de todo contexto
string CtxIA(string pergunta,bool agenda,bool semana)
{
   datetime gmt=TimeGMT(); if(gmt<=0) gmt=TimeCurrent();
   bool semTick=MercadoFechado(); datetime ut=UltTickSrv(_Symbol);
   datetime utG=(ut>0?(datetime)(ut-SrvOffsetSeg()):0);
   datetime muda; int st=GradeOuro(gmt,muda);
   string s=MercadoAgoraTxt(gmt,semTick,utG)+"\n"+SessaoLinhaIA(gmt,semTick)+"\n"+RoboLinhaIA()+"\n";
   if(agenda) s+=AgendaSemanaIA(true);
   if(semana){ string w=SemanaIA(semTick && st==2); if(w!="") s+=w+"\n"; }
   return s+"\n";
}
string RegraContextoIA(bool abertura)
{
   string r=" O bloco AGORA diz o dia da semana, a data e a hora de Brasília, se o mercado está aberto ou fechado e quando reabre: use exatamente isso e nunca calcule dia ou horário por conta própria (hoje é o dia escrito lá; não fale 'antes de domingo' se hoje é domingo). "
            "Você TEM o calendário econômico do MT5 (bloco AGENDA e campos de notícia): nunca diga que não vê notícias ou que não tem calendário; se a lista estiver vazia, diga que não tem notícia forte/média marcada. "
            "Você sabe a versão, o modo da conta e os trades de hoje pelo bloco ROBÔ. "
            "Não invente horário, preço, nível, dado econômico ou notícia que não esteja no contexto; se não estiver lá, diga que não sabe.";
   if(abertura) r+=" Se perguntarem o que esperar da abertura/semana: dê um plano curto de cenários (até 6 frases) usando só os níveis do bloco SEMANA (tipo 'se abrir acima de X...', 'se abrir abaixo de Y...'), diga que é observação, não certeza, cite a notícia forte mais próxima da AGENDA, e lembre do risco de gap e spread largo na abertura: melhor evitar os primeiros 15-30 min.";
   return r;
}
// linha curta pros sinais automáticos (AIAsk)
string AgoraCurtoIA(){ return "AGORA: "+DiaHoraBR(AgoraBR(),true)+" (Brasília). "+(MercadoFechado()?"Mercado FECHADO.":"Mercado aberto.")+"\n"; }
