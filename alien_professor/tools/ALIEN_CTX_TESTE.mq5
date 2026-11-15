#property version "1.00"
datetime EngDomingoN(int ano,int mes,int n)
{
   MqlDateTime d; d.year=ano; d.mon=mes; d.day=1; d.hour=0; d.min=0; d.sec=0;
   datetime t=StructToTime(d); MqlDateTime x; TimeToStruct(t,x);
   int add=(7-x.day_of_week)%7; return t+(add+7*(n-1))*86400;
}
int EngNyOffset(datetime gmt)
{
   MqlDateTime d; TimeToStruct(gmt,d);
   datetime ini=EngDomingoN(d.year,3,2)+7*3600;   // 2h em NY (UTC-5) = 7h UTC
   datetime fim=EngDomingoN(d.year,11,1)+6*3600;  // 2h em NY (UTC-4) = 6h UTC
   return (gmt>=ini && gmt<fim)?4:5;
}
datetime EngNyTime(datetime gmt){ return (datetime)(gmt-EngNyOffset(gmt)*3600); }
int EngNyHour(datetime gmt){ MqlDateTime d; TimeToStruct(EngNyTime(gmt),d); return d.hour; }
string EngKillzone(datetime gmt)
{
   int h=EngNyHour(gmt), m; MqlDateTime d; TimeToStruct(EngNyTime(gmt),d); m=d.min;
   int hm=h*60+m;
   string kz="";
   if(hm>=2*60 && hm<5*60) kz="Killzone Londres (NY 02-05)";
   else if(hm>=7*60 && hm<10*60) kz="Killzone NY manhã (07-10)";
   else if(hm>=13*60+30 && hm<16*60) kz="Killzone NY tarde (13:30-16)";
   else kz="fora de killzone ICT (hora de NY)";
   string sb="";
   if(hm>=3*60 && hm<4*60) sb="Silver Bullet Londres 03-04 NY";
   else if(hm>=10*60 && hm<11*60) sb="Silver Bullet NY 10-11";
   else if(hm>=14*60 && hm<15*60) sb="Silver Bullet NY 14-15";
   if(sb!="") kz+=" | "+sb;
   return kz;
}

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

datetime G(int y,int mo,int d,int h,int mi){ MqlDateTime x; x.year=y;x.mon=mo;x.day=d;x.hour=h;x.min=mi;x.sec=0; return StructToTime(x); }
void P(string n,string s){ StringReplace(s,"\n"," / "); Print("CTXTEST ",n," | ",s); }
int OnInit()
{
   // domingo 15/11/2026 15:10 Brasília = 18:10 GMT, fechado desde sexta 13/11 18:54 BR (21:54 GMT)
   P("dom_est",MercadoAgoraTxt(G(2026,11,15,18,10),true,G(2026,11,13,21,54)));
   P("kz_dom",ProxKillzoneBR(G(2026,11,15,18,10)));
   // domingo 14/06/2026 15:10 Brasília (EDT)
   P("dom_edt",MercadoAgoraTxt(G(2026,6,14,18,10),true,G(2026,6,12,20,59)));
   // terça 17/11 19:30 BR = 22:30 GMT = 17:30 NY EST -> pausa diária
   P("pausa",MercadoAgoraTxt(G(2026,11,17,22,30),true,G(2026,11,17,21,59)));
   // terça 17/11 11:00 BR aberto
   P("aberto",MercadoAgoraTxt(G(2026,11,17,14,0),false,G(2026,11,17,14,0)));
   // sexta 20/11 15:00 BR aberto -> fecha a semana 19:00
   P("sexta",MercadoAgoraTxt(G(2026,11,20,18,0),false,G(2026,11,20,18,0)));
   // quarta sem tick no meio do dia (feriado)
   P("feriado",MercadoAgoraTxt(G(2026,11,26,15,0),true,G(2026,11,25,22,0)));
   ExpertRemove(); return INIT_SUCCEEDED;
}
void OnTick(){}
