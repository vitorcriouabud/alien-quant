//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_AUTO.mq5                                         |
//| EA que OPERA os sinais do ALIEN PROFESSOR (nota >= limite).      |
//| AVISO: no teste 2016-2025 esses sinais PERDERAM dinheiro.        |
//| Sem martingale, sem grade, sem preço médio. 1 posição por vez.   |
//| Stop e alvo vão junto com a ordem. Conta real bloqueada padrão.  |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "1.00"
#property description "Robô dos sinais do ALIEN PROFESSOR. Risco fixo, 1 posição, travas diárias, DD 15%, bloqueio de conta real. ATENÇÃO: o teste histórico dos sinais foi NEGATIVO."
#define APROF_EA
#include <Trade\Trade.mqh>

input group "=== ROBÔ (AUTO) ==="
input bool   InpTradeEnabled      = true;        // Operar? (false = MODO ASSISTENTE: só analisa e avisa, não manda ordem)
input bool   InpAllowRealAccount  = false;       // Permitir conta REAL (padrão: NÃO)
input double InpRiskUSD           = 45.0;        // Risco fixo por operação (US$)
input int    InpScoreTrade        = 7;           // Nota mínima pra operar
input long   InpMagic             = 77261115;    // Número mágico (único deste robô)
input double InpSpreadMaxPctStop  = 10.0;        // Spread máximo (% da distância do stop) (0 = desligado)
input double InpDDPausaPct        = 15.0;        // Pausa se cair X% do pico (0 = desligado)
input int    InpLimiteMin         = 60;          // Ordem limitada vale N minutos (0 = não cancela)
input int    InpMaxHoras          = 8;           // Fecha a posição depois de N horas (0 = desligado)
input int    InpFecharHHMM        = 2345;        // Fecha tudo neste horário do servidor HHMM (0 = desligado)
input bool   InpBloquearHorarioRuim = true;      // Não opera em horário ruim (Ásia / fim de NY)

input group "=== Aprendizado (histórico) ==="
input bool   InpAprenderDesativar = false;       // Pular faixa nota/lado/sessão que está perdendo no SEU histórico
input int    InpAprenderMinN      = 30;          // Mínimo de trades na faixa pra poder desativar

input group "=== Telegram (opcional) ==="
input bool   InpUseTelegram       = true;        // Usar Telegram (precisa de token e chat id)
input string InpTelegramToken     = "";          // Token do bot (crie um NOVO no @BotFather)
input string InpTelegramChatId    = "";          // Seu chat id
input bool   InpTgFoto            = true;        // Mandar print do gráfico junto
input bool   InpTgChat            = true;        // Conversar pelo Telegram (/analise /status /noticias /ajuda e perguntas)
input int    InpTgPollSeg         = 4;           // Ler mensagens a cada N segundos
input int    InpPreAlertaMin      = 15;          // Avisar N min antes de notícia FORTE (0 = desligado)
input string InpPreAlertaMoedas   = "USD";       // Moedas do pré-aviso
input bool   InpResumos           = true;        // Resumo automático na abertura de Londres e NY
input string InpResumoLondres     = "10:00";     // Abertura de Londres (hora do SERVIDOR) (vazio = sem resumo)
input string InpResumoNY          = "16:30";     // Abertura de NY (hora do SERVIDOR) (vazio = sem resumo)
#define InpRiscoUSD InpRiskUSD

//+------------------------------------------------------------------+
//| ALIEN PROFESSOR - nucleo (apenas leitura e desenho, NUNCA opera) |
//+------------------------------------------------------------------+
#include <Canvas\Canvas.mqh>

//--- entradas
input group "=== Tempo gráfico ==="
input ENUM_TIMEFRAMES InpTFExec   = PERIOD_M5;   // TF da estrutura (BOS / FVG / volume)
input ENUM_TIMEFRAMES InpTFTrend  = PERIOD_H1;   // TF da tendência (EMA200 + topos/fundos)
input int    InpSwingLen          = 3;           // Barras de cada lado p/ topo/fundo (swing)
input int    InpBarrasScan        = 300;         // Barras do TF da estrutura analisadas

input group "=== Risco e plano ==="
#ifndef APROF_EA
input double InpRiscoUSD          = 45.0;        // Risco por operação (US$)
#endif
input double InpLimiteFlutuante   = 50.0;        // Limite de perda flutuante da mesa (Goat: US$50)
input double InpComissaoMilhao    = -1;          // Comissão US$ por milhão por lado (-1 = auto: ouro 20, índices 5)
input double InpBufferATR         = 0.15;        // Folga do stop além da varrida/swing (x ATR)
input double InpRRMin             = 2.0;         // R:R mínimo p/ contar ponto de "espaço até o alvo"

input group "=== Disciplina ==="
input int    InpMaxStopsDia       = 2;           // Máximo de stops por dia (0 = desligado)
input double InpMetaDiaUSD        = 100.0;       // Meta do dia (US$) - bateu, para (0 = desligado)
input double InpPerdaMaxDiaUSD    = 90.0;        // Perda máxima do dia (US$) (0 = desligado)
input string InpNoticias          = "";          // Horários de notícia hoje (servidor), ex: 15:30,21:00 (vazio = desligado)
input int    InpNoticiaMin        = 30;          // Minutos antes/depois da notícia = não operar
input bool   InpCalendario        = true;        // Ler o calendário econômico do MT5 (notícias automáticas)
input string InpCalMoedas         = "USD,EUR";   // Moedas do calendário
input bool   InpCalBloquearForte  = true;        // Notícia FORTE (alto impacto) = não operar ±InpNoticiaMin

input group "=== Sessões (hora do SERVIDOR) ==="
input int    InpAsiaIni           = 1;           // Ásia início
input int    InpAsiaFim           = 9;           // Ásia fim
input int    InpLondresIni        = 9;           // Londres início
input int    InpLondresFim        = 15;          // Londres fim
input int    InpNYIni             = 16;          // Nova York início
input int    InpNYFim             = 23;          // Nova York fim
input int    InpBomIni1           = 10;          // Horário bom 1 (abertura Londres) início
input int    InpBomFim1           = 13;          // Horário bom 1 fim
input int    InpBomIni2           = 16;          // Horário bom 2 (abertura NY) início
input int    InpBomFim2           = 19;          // Horário bom 2 fim
input int    InpRuimIni           = 21;          // Horário ruim (fim de NY) a partir de

input group "=== Sinais e alertas ==="
input int    InpVarridaValida     = 36;          // Varrida vale por quantas barras do TF da estrutura
input int    InpBOSValido         = 24;          // BOS vale por quantas barras
input double InpEqualTolATR       = 0.10;        // Tolerância p/ topos/fundos iguais (x ATR)
input double InpFVGMinATR         = 0.10;        // Tamanho mínimo do FVG (x ATR)
input int    InpScoreVerde        = 7;           // Nota mínima p/ VERDE
input int    InpScoreAmarelo      = 4;           // Nota mínima p/ AMARELO
input int    InpScoreAlerta       = 7;           // Alerta quando a nota chegar em
input bool   InpAlerta            = true;        // Alerta na tela
input bool   InpPush              = false;       // Notificação no celular (push)

input group "=== Visual ==="
input bool   InpFVG_H1            = true;        // Desenhar FVG do H1
input bool   InpFVG_M15           = true;        // Desenhar FVG do M15
input bool   InpPainelMTF         = true;        // Painel de tendência D1/H4/H1/M15/M5/M1
input bool   InpCompacto          = false;       // Painel compacto (esconde contexto/liquidez/estrutura detalhados)
input bool   InpTemaAlien         = true;        // Fundo preto / velas no estilo ALIEN
input bool   InpMostrarHonestidade= true;        // Mostrar linha de honestidade (estatística VO3)
input int    InpPainelX           = 10;          // Painel X
input int    InpPainelY           = 20;          // Painel Y
input int    InpFonte             = 13;          // Tamanho da fonte do painel

#define PFX "APROF_"
bool   g_noDraw=false;          // tester sem visual: não desenha nada (mais rápido)
string g_extra=""; color g_extraC=clrGold; string g_aiPanel=""; string g_statusSvc=""; // linha extra do painel (status do AUTO)
#define NV_ABOVE  1
#define NV_BELOW -1
#define ST_INTACTO 0
#define ST_VARRIDA 1
#define ST_ROMPIDO 2

struct Nivel { string nome; double preco; datetime t0; datetime tAfter; int lado; int estado; datetime tSweep; double sweepExt; };
struct FVGz  { int dir; double top; double bot; datetime t0; datetime tFill; bool filled; ENUM_TIMEFRAMES tf; };
struct BOSe  { int dir; double preco; datetime tSwing; datetime tBreak; bool choch; };
struct Plano { int dir; double entry; double stop; double target; string alvoNome; string entNome; double rr; double lot; double riskUSD; double targetUSD; bool loteMinAcima; int score; bool pts[7]; };

Nivel  g_niv[];
FVGz   g_fvg[];
BOSe   g_bos[];
MqlRates g_r[];          // TF da estrutura, serie (0 = atual)
double g_atr=0;
int    g_trend=0;        // +1 alta, -1 baixa, 0 lateral
string g_trendTxt="carregando...";
int    g_bias=0; string g_biasTxt="sem dados do D1 ainda";
int    g_volDir=0; datetime g_volT=0; int g_volAge=999;
double g_lastSH=0,g_lastSL=0;
Plano  g_pb,g_ps; double g_comLote=0;
datetime g_lastBar=0, g_lastAlert=0;
bool   g_ready=false;
CCanvas g_cv; bool g_cvOk=false;
// disciplina
int g_stopsHoje=0, g_tradesHoje=0; double g_netHoje=0; string g_pare="";

//--------------------------------------------------------------------
string Fmt(double p){ return DoubleToString(p,_Digits); }
string HHMM(datetime t){ return TimeToString(t,TIME_MINUTES); }
int    HourOf(datetime t){ MqlDateTime d; TimeToStruct(t,d); return d.hour; }
int    MinOfDay(datetime t){ MqlDateTime d; TimeToStruct(t,d); return d.hour*60+d.min; }
datetime DayStart(datetime t){ return t-(t%86400); }

double ATRof(const MqlRates &r[],int n,int from)
{
   int sz=ArraySize(r); double s=0; int c=0;
   for(int i=from;i<from+n && i+1<sz;i++){ double tr=MathMax(r[i].high,r[i+1].close)-MathMin(r[i].low,r[i+1].close); s+=tr; c++; }
   return c>0? s/c : 0;
}
bool IsSH(const MqlRates &r[],int j,int L){ int sz=ArraySize(r); if(j-L<1||j+L>=sz) return false; for(int k=1;k<=L;k++){ if(r[j-k].high>=r[j].high) return false; if(r[j+k].high>r[j].high) return false; } return true; }
bool IsSL(const MqlRates &r[],int j,int L){ int sz=ArraySize(r); if(j-L<1||j+L>=sz) return false; for(int k=1;k<=L;k++){ if(r[j-k].low<=r[j].low) return false; if(r[j+k].low<r[j].low) return false; } return true; }

//--------------------------------------------------------------------
// objetos
void ObjLine(string n,datetime t1,double p,datetime t2,color c,ENUM_LINE_STYLE st,int w,string txt,color tc)
{
   string o=PFX+n;
   if(ObjectFind(0,o)<0){ ObjectCreate(0,o,OBJ_TREND,0,t1,p,t2,p); ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,o,OBJPROP_HIDDEN,true); ObjectSetInteger(0,o,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,o,OBJPROP_BACK,true); }
   ObjectMove(0,o,0,t1,p); ObjectMove(0,o,1,t2,p);
   ObjectSetInteger(0,o,OBJPROP_COLOR,c); ObjectSetInteger(0,o,OBJPROP_STYLE,st); ObjectSetInteger(0,o,OBJPROP_WIDTH,w);
   if(txt!="")
   {
      string l=o+"_t";
      if(ObjectFind(0,l)<0){ ObjectCreate(0,l,OBJ_TEXT,0,t2,p); ObjectSetInteger(0,l,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,l,OBJPROP_HIDDEN,true); ObjectSetInteger(0,l,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); ObjectSetString(0,l,OBJPROP_FONT,"Arial"); }
      ObjectMove(0,l,0,t2,p); ObjectSetString(0,l,OBJPROP_TEXT,txt); ObjectSetInteger(0,l,OBJPROP_COLOR,tc); ObjectSetInteger(0,l,OBJPROP_FONTSIZE,9);
   }
}
void ObjBox(string n,datetime t1,double p1,datetime t2,double p2,color c)
{
   string o=PFX+n;
   if(ObjectFind(0,o)<0){ ObjectCreate(0,o,OBJ_RECTANGLE,0,t1,p1,t2,p2); ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,o,OBJPROP_HIDDEN,true); ObjectSetInteger(0,o,OBJPROP_FILL,true); ObjectSetInteger(0,o,OBJPROP_BACK,true); }
   ObjectMove(0,o,0,t1,p1); ObjectMove(0,o,1,t2,p2); ObjectSetInteger(0,o,OBJPROP_COLOR,c);
}
void ObjTxt(string n,datetime t,double p,string txt,color c,int sz,ENUM_ANCHOR_POINT a)
{
   string o=PFX+n;
   if(ObjectFind(0,o)<0){ ObjectCreate(0,o,OBJ_TEXT,0,t,p); ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,o,OBJPROP_HIDDEN,true); ObjectSetString(0,o,OBJPROP_FONT,"Arial Black"); }
   ObjectMove(0,o,0,t,p); ObjectSetString(0,o,OBJPROP_TEXT,txt); ObjectSetInteger(0,o,OBJPROP_COLOR,c); ObjectSetInteger(0,o,OBJPROP_FONTSIZE,sz); ObjectSetInteger(0,o,OBJPROP_ANCHOR,a);
}
void DelPrefix(string p){ ObjectsDeleteAll(0,PFX+p); }

//--------------------------------------------------------------------
// TENDENCIA H1 + VIES DIARIO
bool CalcTrend()
{
   MqlRates h[]; ArraySetAsSeries(h,true);
   int n=CopyRates(_Symbol,InpTFTrend,0,700,h);
   if(n<260) { g_trendTxt="sem dados do "+EnumToString(InpTFTrend)+" ainda"; return false; }
   // EMA200 calculada do mais antigo pro mais novo
   double k=2.0/201.0, ema=h[n-1].close, emaAnt=ema; double emaArr[]; ArrayResize(emaArr,n);
   for(int i=n-1;i>=0;i--){ ema = (i==n-1)? h[i].close : h[i].close*k+ema*(1-k); emaArr[i]=ema; }
   double e1=emaArr[1], e6=emaArr[6]; emaAnt=e6;
   double atrh=ATRof(h,14,1);
   int slope = (e1-emaAnt > 0.05*atrh)? 1 : (emaAnt-e1 > 0.05*atrh ? -1 : 0);
   int side  = h[1].close>e1 ? 1 : -1;
   // estrutura: 2 ultimos topos e fundos (swing 3)
   double sh[2]={0,0}, sl[2]={0,0}; int csh=0, csl=0;
   for(int j=4;j<n-4 && (csh<2||csl<2);j++)
   {
      if(csh<2 && IsSH(h,j,3)) sh[csh++]=h[j].high;
      if(csl<2 && IsSL(h,j,3)) sl[csl++]=h[j].low;
   }
   int st=0; string stt="topos/fundos mistos";
   if(csh==2&&csl==2)
   {
      if(sh[0]>sh[1] && sl[0]>sl[1]){ st=1; stt="topos e fundos subindo"; }
      else if(sh[0]<sh[1] && sl[0]<sl[1]){ st=-1; stt="topos e fundos descendo"; }
   }
   int score=slope+side+st;
   g_trend = score>=2 ? 1 : (score<=-2 ? -1 : 0);
   string tf=StringSubstr(EnumToString(InpTFTrend),7);
   g_trendTxt=StringFormat("%s: %s  (EMA200 %s, preço %s dela, %s)",tf,
      g_trend==1?"ALTA":(g_trend==-1?"BAIXA":"LATERAL / INDEFINIDA"),
      slope==1?"subindo":(slope==-1?"caindo":"reta"), side==1?"acima":"abaixo", stt);
   // vies do dia
   double pdh=iHigh(_Symbol,PERIOD_D1,1), pdl=iLow(_Symbol,PERIOD_D1,1), dop=iOpen(_Symbol,PERIOD_D1,0);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(pdh>0 && pdl>0 && dop>0)
   {
      double mid=(pdh+pdl)/2; int b=(px>dop?1:-1)+(px>mid?1:-1);
      g_bias = b>=2?1:(b<=-2?-1:0);
      g_biasTxt = g_bias==1?"COMPRADOR (acima da abertura e do meio de ontem)":(g_bias==-1?"VENDEDOR (abaixo da abertura e do meio de ontem)":"NEUTRO (preço no meio)");
   }
   return true;
}

//--------------------------------------------------------------------
// NIVEIS DE LIQUIDEZ
void AddNivel(string nome,double p,datetime t0,datetime tAfter,int lado)
{
   if(p<=0) return;
   int k=ArraySize(g_niv); ArrayResize(g_niv,k+1);
   g_niv[k].nome=nome; g_niv[k].preco=p; g_niv[k].t0=t0; g_niv[k].tAfter=tAfter; g_niv[k].lado=lado; g_niv[k].estado=ST_INTACTO; g_niv[k].tSweep=0; g_niv[k].sweepExt=0;
}
bool SessaoHL(int hi,int hf,datetime now,double &H,double &L,datetime &t0,datetime &tEnd)
{
   int n=ArraySize(g_r);
   datetime d0=DayStart(now);
   for(int back=0;back<6;back++)
   {
      datetime s=d0-back*86400+hi*3600, e=d0-back*86400+hf*3600; if(hf<=hi) e+=86400;
      if(e>now) continue;
      H=0; L=DBL_MAX; int c=0;
      for(int i=1;i<n;i++){ if(g_r[i].time<s) break; if(g_r[i].time>=e) continue; H=MathMax(H,g_r[i].high); L=MathMin(L,g_r[i].low); c++; }
      if(c>=3){ t0=s; tEnd=e; return true; }
   }
   return false;
}
void CalcNiveis()
{
   ArrayResize(g_niv,0);
   datetime now=g_r[0].time;
   datetime d0=iTime(_Symbol,PERIOD_D1,0); if(d0==0) d0=DayStart(now);
   datetime d1=iTime(_Symbol,PERIOD_D1,1);
   AddNivel("PDH (máx. ontem)",iHigh(_Symbol,PERIOD_D1,1),d1,d0,NV_ABOVE);
   AddNivel("PDL (mín. ontem)",iLow(_Symbol,PERIOD_D1,1),d1,d0,NV_BELOW);
   datetime w0=iTime(_Symbol,PERIOD_W1,0), w1=iTime(_Symbol,PERIOD_W1,1);
   AddNivel("Máx. semana passada",iHigh(_Symbol,PERIOD_W1,1),w1,w0,NV_ABOVE);
   AddNivel("Mín. semana passada",iLow(_Symbol,PERIOD_W1,1),w1,w0,NV_BELOW);
   double H,L; datetime t0,te;
   if(SessaoHL(InpAsiaIni,InpAsiaFim,now,H,L,t0,te)){ AddNivel("Ásia máx.",H,t0,te,NV_ABOVE); AddNivel("Ásia mín.",L,t0,te,NV_BELOW); }
   if(SessaoHL(InpLondresIni,InpLondresFim,now,H,L,t0,te)){ AddNivel("Londres máx.",H,t0,te,NV_ABOVE); AddNivel("Londres mín.",L,t0,te,NV_BELOW); }
   if(SessaoHL(InpNYIni,InpNYFim,now,H,L,t0,te)){ AddNivel("NY máx.",H,t0,te,NV_ABOVE); AddNivel("NY mín.",L,t0,te,NV_BELOW); }
   // topos / fundos iguais (ultimas ~ InpBarrasScan barras)
   int n=ArraySize(g_r), L2=InpSwingLen; double tol=InpEqualTolATR*g_atr;
   int shI[], slI[]; ArrayResize(shI,0); ArrayResize(slI,0);
   for(int j=L2+1;j<n-L2 && j<InpBarrasScan;j++){ if(IsSH(g_r,j,L2)){int k=ArraySize(shI);ArrayResize(shI,k+1);shI[k]=j;} if(IsSL(g_r,j,L2)){int k=ArraySize(slI);ArrayResize(slI,k+1);slI[k]=j;} }
   int fe=0;
   for(int a=0;a<ArraySize(shI)-1 && fe<2;a++) for(int b=a+1;b<ArraySize(shI) && b<a+6;b++)
   {
      int ja=shI[a], jb=shI[b]; if(jb-ja<6) continue;
      if(MathAbs(g_r[ja].high-g_r[jb].high)<=tol)
      {
         double lv=MathMax(g_r[ja].high,g_r[jb].high); bool ok=true;
         for(int m=ja+1;m<jb;m++) if(g_r[m].high>lv){ok=false;break;}
         if(ok){ AddNivel("Topos iguais (EQH)",lv,g_r[jb].time,g_r[ja-L2].time,NV_ABOVE); fe++; break; }
      }
   }
   fe=0;
   for(int a=0;a<ArraySize(slI)-1 && fe<2;a++) for(int b=a+1;b<ArraySize(slI) && b<a+6;b++)
   {
      int ja=slI[a], jb=slI[b]; if(jb-ja<6) continue;
      if(MathAbs(g_r[ja].low-g_r[jb].low)<=tol)
      {
         double lv=MathMin(g_r[ja].low,g_r[jb].low); bool ok=true;
         for(int m=ja+1;m<jb;m++) if(g_r[m].low<lv){ok=false;break;}
         if(ok){ AddNivel("Fundos iguais (EQL)",lv,g_r[jb].time,g_r[ja-L2].time,NV_BELOW); fe++; break; }
      }
   }
   // varrida: pavio atravessa e fecha de volta (somente barras fechadas)
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      for(int i=n-1;i>=1;i--)
      {
         if(g_r[i].time<g_niv[v].tAfter) continue;
         if(g_niv[v].lado==NV_ABOVE)
         {
            if(g_r[i].close>g_niv[v].preco) g_niv[v].estado=ST_ROMPIDO;
            else if(g_r[i].high>g_niv[v].preco){ g_niv[v].estado=ST_VARRIDA; g_niv[v].tSweep=g_r[i].time; g_niv[v].sweepExt=g_r[i].high; }
         }
         else
         {
            if(g_r[i].close<g_niv[v].preco) g_niv[v].estado=ST_ROMPIDO;
            else if(g_r[i].low<g_niv[v].preco){ g_niv[v].estado=ST_VARRIDA; g_niv[v].tSweep=g_r[i].time; g_niv[v].sweepExt=g_r[i].low; }
         }
      }
   }
}
void DrawNiveis()
{
   DelPrefix("NV");
   datetime tR=g_r[0].time+PeriodSeconds(InpTFExec)*12;
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      color c = g_niv[v].lado==NV_ABOVE? clrGold : clrOrange;
      ENUM_LINE_STYLE s=STYLE_SOLID; string est="";
      if(g_niv[v].estado==ST_VARRIDA){ c=clrMagenta; est="  VARRIDA "+HHMM(g_niv[v].tSweep); s=STYLE_SOLID; }
      if(g_niv[v].estado==ST_ROMPIDO){ c=clrDimGray; est="  rompido"; s=STYLE_DOT; }
      ObjLine("NV"+IntegerToString(v),g_niv[v].t0,g_niv[v].preco,tR,c,s,g_niv[v].estado==ST_VARRIDA?2:1,g_niv[v].nome+" "+Fmt(g_niv[v].preco)+est,c);
      if(g_niv[v].estado==ST_VARRIDA)
         ObjTxt("NVs"+IntegerToString(v),g_niv[v].tSweep,g_niv[v].sweepExt,"VARRIDA",clrMagenta,8,g_niv[v].lado==NV_ABOVE?ANCHOR_LOWER:ANCHOR_UPPER);
   }
}


// FVG generico (qualquer TF): procura nas ultimas maxB barras e marca se foi preenchido
void ScanFVG(const MqlRates &r[],ENUM_TIMEFRAMES tf,int maxB,FVGz &out[])
{
   ArrayResize(out,0);
   int n=ArraySize(r); if(n<30) return;
   double minGap=InpFVGMinATR*ATRof(r,14,1);
   int lim=MathMin(n-3,maxB);
   for(int i=lim;i>=1;i--)
   {
      int dir=0; double top=0,bot=0;
      if(r[i].low-r[i+2].high>minGap){ dir=1; top=r[i].low; bot=r[i+2].high; }
      else if(r[i+2].low-r[i].high>minGap){ dir=-1; top=r[i+2].low; bot=r[i].high; }
      if(dir==0) continue;
      FVGz f; f.dir=dir; f.top=top; f.bot=bot; f.t0=r[i+2].time; f.filled=false; f.tFill=0; f.tf=tf;
      for(int k=i-1;k>=0;k--)
      {
         if(dir==1 && r[k].low<=bot){ f.filled=true; f.tFill=r[k].time; break; }
         if(dir==-1 && r[k].high>=top){ f.filled=true; f.tFill=r[k].time; break; }
      }
      int m=ArraySize(out); ArrayResize(out,m+1); out[m]=f;
   }
}
//--------------------------------------------------------------------
// MULTI-TEMPO: tendencia D1/H4/H1/M15/M5/M1 e FVG do H1/M15
ENUM_TIMEFRAMES g_mtfTF[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M15,PERIOD_M5,PERIOD_M1};
string g_mtfNm[6]={"D1","H4","H1","M15","M5","M1"};
int g_mtf[6]={0,0,0,0,0,0}; datetime g_mtfBar[6]={0,0,0,0,0,0};
FVGz g_fvgH1[], g_fvgM15[]; datetime g_fvgH1Bar=0, g_fvgM15Bar=0;
// tendencia simples por TF: EMA50 (lado + inclinacao) + ultimos 2 topos/fundos
int TrendTF(ENUM_TIMEFRAMES tf){ return TrendTFs(_Symbol,tf); }
int TrendTFs(string sym,ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,tf,0,300,r); if(n<80) return 0;
   double k=2.0/51.0, e=r[n-1].close; double ea[]; ArrayResize(ea,n);
   for(int i=n-1;i>=0;i--){ e=(i==n-1)?r[i].close:r[i].close*k+e*(1-k); ea[i]=e; }
   double atr=ATRof(r,14,1);
   int slope=(ea[1]-ea[4]>0.05*atr)?1:((ea[4]-ea[1]>0.05*atr)?-1:0);
   int side=r[1].close>ea[1]?1:-1;
   double sh[2]={0,0}, sl[2]={0,0}; int a=0,b=0;
   for(int j=4;j<n-4 && (a<2||b<2);j++){ if(a<2&&IsSH(r,j,2)) sh[a++]=r[j].high; if(b<2&&IsSL(r,j,2)) sl[b++]=r[j].low; }
   int st=0; if(a==2&&b==2){ if(sh[0]>sh[1]&&sl[0]>sl[1]) st=1; else if(sh[0]<sh[1]&&sl[0]<sl[1]) st=-1; }
   int sc=slope+side+st; return sc>=2?1:(sc<=-2?-1:0);
}
void CalcMTF()
{
   for(int i=0;i<6;i++){ datetime t=iTime(_Symbol,g_mtfTF[i],0); if(t!=0 && t!=g_mtfBar[i]){ g_mtf[i]=TrendTF(g_mtfTF[i]); g_mtfBar[i]=t; } }
   MqlRates r[]; ArraySetAsSeries(r,true);
   datetime t1=iTime(_Symbol,PERIOD_H1,0);
   if(InpFVG_H1 && t1!=0 && t1!=g_fvgH1Bar && CopyRates(_Symbol,PERIOD_H1,0,300,r)>50){ ScanFVG(r,PERIOD_H1,200,g_fvgH1); g_fvgH1Bar=t1; DrawFVGHTF(g_fvgH1,"FH1","FVG H1",C'0,55,95',C'95,0,75'); }
   datetime t2=iTime(_Symbol,PERIOD_M15,0);
   if(InpFVG_M15 && t2!=0 && t2!=g_fvgM15Bar && CopyRates(_Symbol,PERIOD_M15,0,300,r)>50){ ScanFVG(r,PERIOD_M15,200,g_fvgM15); g_fvgM15Bar=t2; DrawFVGHTF(g_fvgM15,"FM15","FVG M15",C'0,80,90',C'110,50,0'); }
}
void DrawFVGHTF(const FVGz &f[],string pf,string lbl,color cUp,color cDn)
{
   if(g_noDraw) return;
   DelPrefix(pf);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   datetime tR=TimeCurrent()+PeriodSeconds(PERIOD_M5)*14;
   int shown=0;
   for(int m=ArraySize(f)-1;m>=0 && shown<4;m--)
   {
      if(f[m].filled) continue;
      if(px>0 && MathAbs((f[m].top+f[m].bot)/2-px)>40*MathMax(g_atr,_Point)) continue; // muito longe
      color c=f[m].dir==1?cUp:cDn;
      ObjBox(pf+IntegerToString(m),f[m].t0,f[m].top,tR,f[m].bot,c);
      ObjectSetInteger(0,PFX+pf+IntegerToString(m),OBJPROP_FILL,false); ObjectSetInteger(0,PFX+pf+IntegerToString(m),OBJPROP_WIDTH,2);
      ObjTxt(pf+"t"+IntegerToString(m),f[m].t0,f[m].top,lbl+(f[m].dir==1?" compra":" venda"),c==cUp?clrDeepSkyBlue:clrOrchid,8,ANCHOR_LEFT_LOWER);
      shown++;
   }
}
// preco dentro de algum FVG H1/M15 a favor?
string InHTFFVG(int dir,double px)
{
   for(int m=0;m<ArraySize(g_fvgH1);m++) if(!g_fvgH1[m].filled && g_fvgH1[m].dir==dir && px<=g_fvgH1[m].top && px>=g_fvgH1[m].bot) return "FVG H1";
   for(int m=0;m<ArraySize(g_fvgM15);m++) if(!g_fvgM15[m].filled && g_fvgM15[m].dir==dir && px<=g_fvgM15[m].top && px>=g_fvgM15[m].bot) return "FVG M15";
   return "";
}
//--------------------------------------------------------------------
// ESTRUTURA: BOS, FVG, VOLUME
void CalcEstrutura()
{
   int n=ArraySize(g_r), L=InpSwingLen; int lim=MathMin(n-1,InpBarrasScan);
   ArrayResize(g_bos,0);
   double sh=0,sl=0; datetime tsh=0,tsl=0; bool shU=true,slU=true; int lastDir=0;
   for(int i=lim-L-1;i>=1;i--)
   {
      int j=i+L;
      if(IsSH(g_r,j,L)){ sh=g_r[j].high; tsh=g_r[j].time; shU=false; }
      if(IsSL(g_r,j,L)){ sl=g_r[j].low;  tsl=g_r[j].time; slU=false; }
      if(!shU && g_r[i].close>sh){ int k=ArraySize(g_bos); ArrayResize(g_bos,k+1); g_bos[k].dir=1; g_bos[k].preco=sh; g_bos[k].tSwing=tsh; g_bos[k].tBreak=g_r[i].time; g_bos[k].choch=(lastDir==-1); lastDir=1; shU=true; }
      if(!slU && g_r[i].close<sl){ int k=ArraySize(g_bos); ArrayResize(g_bos,k+1); g_bos[k].dir=-1; g_bos[k].preco=sl; g_bos[k].tSwing=tsl; g_bos[k].tBreak=g_r[i].time; g_bos[k].choch=(lastDir==1); lastDir=-1; slU=true; }
   }
   g_lastSH=sh; g_lastSL=sl;
   ScanFVG(g_r,InpTFExec,150,g_fvg);
   // volume
   g_volDir=0; g_volAge=999;
   for(int i=1;i<=60 && i+21<n;i++)
   {
      double s=0; for(int k=i+1;k<=i+20;k++) s+=(double)g_r[k].tick_volume; s/=20.0;
      bool vs = s>0 && (double)g_r[i].tick_volume>2.0*s;
      double rg=g_r[i].high-g_r[i].low; bool strong = rg>0 && MathAbs(g_r[i].close-g_r[i].open)>0.6*rg;
      if(vs && g_volAge==999){ g_volAge=i; g_volDir=g_r[i].close>g_r[i].open?1:-1; g_volT=g_r[i].time; if(!strong) g_volDir*=1; }
   }
}
void DrawEstrutura()
{
   DelPrefix("BOS"); DelPrefix("FVG"); DelPrefix("VOL");
   int nb=ArraySize(g_bos);
   for(int k=MathMax(0,nb-5);k<nb;k++)
   {
      color c=g_bos[k].dir==1?clrLime:clrRed;
      string t=(g_bos[k].choch?"CHoCH ":"BOS ")+(g_bos[k].dir==1?"alta":"baixa");
      ObjLine("BOS"+IntegerToString(k),g_bos[k].tSwing,g_bos[k].preco,g_bos[k].tBreak,c,STYLE_DASH,1,"",c);
      ObjTxt("BOSt"+IntegerToString(k),g_bos[k].tBreak,g_bos[k].preco,t,c,7,g_bos[k].dir==1?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER);
   }
   int open=0, filled=0; datetime tR=g_r[0].time+PeriodSeconds(InpTFExec)*12;
   for(int m=ArraySize(g_fvg)-1;m>=0;m--)
   {
      if(!g_fvg[m].filled && open<6){ ObjBox("FVG"+IntegerToString(m),g_fvg[m].t0,g_fvg[m].top,tR,g_fvg[m].bot,g_fvg[m].dir==1?C'0,85,45':C'95,25,25'); open++; }
      else if(g_fvg[m].filled && filled<4){ ObjBox("FVG"+IntegerToString(m),g_fvg[m].t0,g_fvg[m].top,g_fvg[m].tFill,g_fvg[m].bot,C'42,42,42'); filled++; }
   }
   int n=ArraySize(g_r);
   for(int i=1;i<=80 && i+21<n;i++)
   {
      double s=0; for(int k=i+1;k<=i+20;k++) s+=(double)g_r[k].tick_volume; s/=20.0;
      bool vs = s>0 && (double)g_r[i].tick_volume>2.0*s;
      double rg=g_r[i].high-g_r[i].low; bool strong = rg>0 && MathAbs(g_r[i].close-g_r[i].open)>0.6*rg;
      if(!vs && !strong) continue;
      if(!vs && i>20) continue; // corpo forte sozinho: só as ultimas 20 barras
      bool up=g_r[i].close>=g_r[i].open;
      string t = vs&&strong ? "VC" : (vs ? "V" : "c");
      color c = vs ? clrYellow : clrKhaki;
      ObjTxt("VOL"+IntegerToString(i),g_r[i].time,up?g_r[i].low:g_r[i].high,t,c,vs?8:6,up?ANCHOR_UPPER:ANCHOR_LOWER);
   }
}

//--------------------------------------------------------------------
// SESSAO / NOTICIA
int SessaoNota(datetime t,string &txt)
{
   int h=HourOf(t);
   string nome = (h>=InpAsiaIni && h<InpAsiaFim)?"Ásia":((h>=InpLondresIni && h<InpLondresFim)?"Londres":((h>=InpLondresFim && h<InpRuimIni)?"Nova York":"fim de NY / madrugada"));
   if((h>=InpBomIni1 && h<InpBomFim1)||(h>=InpBomIni2 && h<InpBomFim2)){ txt=nome+" - horário BOM (abertura com volume)"; return 1; }
   if(h>=InpRuimIni || h<InpAsiaFim){ txt=nome+" - horário RUIM (pouco volume, muita armadilha)"; return -1; }
   txt=nome+" - horário normal"; return 0;
}
//--------------------------------------------------------------------
// CALENDÁRIO ECONÔMICO (MT5) - notícias de impacto alto/médio das moedas escolhidas
// horários do calendário = horário do SERVIDOR (TimeTradeServer). Não existe no testador.
struct NewsEv { ulong id; datetime t; string cur; string nome; int imp; };
NewsEv g_news[]; datetime g_newsLoad=0; string g_newsErr="";
bool CalOn(){ return InpCalendario && !MQLInfoInteger(MQL_TESTER); }
void LoadNews(bool force=false)
{
   if(!CalOn()) return;
   datetime now=TimeTradeServer(); if(now==0) return;
   if(!force && g_newsLoad>0 && now-g_newsLoad<600) return;
   g_newsLoad=now; ArrayResize(g_news,0); g_newsErr="";
   string cs[]; int nc=StringSplit(InpCalMoedas,',',cs);
   for(int c=0;c<nc;c++)
   {
      string cur=cs[c]; StringTrimLeft(cur); StringTrimRight(cur); StringToUpper(cur); if(StringLen(cur)!=3) continue;
      MqlCalendarValue v[]; ResetLastError();
      if(CalendarValueHistory(v,now-3*3600,now+36*3600,NULL,cur)<=0){ int e=GetLastError(); if(e!=0) g_newsErr=StringFormat("calendário indisponível (erro %d)",e); continue; }
      for(int i=0;i<ArraySize(v);i++)
      {
         MqlCalendarEvent ev; if(!CalendarEventById(v[i].event_id,ev)) continue;
         int imp = ev.importance==CALENDAR_IMPORTANCE_HIGH ? 3 : (ev.importance==CALENDAR_IMPORTANCE_MODERATE ? 2 : 0);
         if(imp<2) continue;
         int k=ArraySize(g_news); ArrayResize(g_news,k+1);
         g_news[k].id=v[i].id; g_news[k].t=v[i].time; g_news[k].cur=cur; g_news[k].nome=ev.name; g_news[k].imp=imp;
      }
   }
   // ordena por horário
   for(int i=1;i<ArraySize(g_news);i++){ NewsEv x=g_news[i]; int j=i-1; while(j>=0 && g_news[j].t>x.t){ g_news[j+1]=g_news[j]; j--; } g_news[j+1]=x; }
}
string ImpTxt(int imp){ return imp==3?"FORTE":"média"; }
// próximas notícias (a partir de agora - 30 min)
string NewsLista(int maxN,string sep)
{
   if(!CalOn()) return InpCalendario?"calendário não roda no testador":"calendário desligado";
   LoadNews(); datetime now=TimeTradeServer(); string s=""; int n=0;
   for(int i=0;i<ArraySize(g_news) && n<maxN;i++)
   {
      if(g_news[i].t<now-1800) continue;
      s+=(s==""?"":sep)+StringFormat("%s %s %s %s",DayStart(g_news[i].t)==DayStart(now)?HHMM(g_news[i].t):TimeToString(g_news[i].t,TIME_DATE|TIME_MINUTES),g_news[i].cur,ImpTxt(g_news[i].imp),g_news[i].nome);
      n++;
   }
   if(s=="") s=(g_newsErr!=""?g_newsErr:"nenhuma notícia alta/média nas próximas 36h");
   return s;
}
string NewsJSON()
{
   if(!CalOn()) return "[]";
   LoadNews(); datetime now=TimeTradeServer(); string s=""; int n=0;
   for(int i=0;i<ArraySize(g_news) && n<12;i++)
   {
      if(g_news[i].t<now-3600) continue;
      string nm=g_news[i].nome; StringReplace(nm,"\\",""); StringReplace(nm,"\"","'");
      s+=(s==""?"":",")+StringFormat("{\"hora\":\"%s\",\"min\":%d,\"moeda\":\"%s\",\"impacto\":\"%s\",\"evento\":\"%s\"}",TimeToString(g_news[i].t,TIME_DATE|TIME_MINUTES),(int)((g_news[i].t-now)/60),g_news[i].cur,ImpTxt(g_news[i].imp),nm);
      n++;
   }
   return "["+s+"]";
}
// notícia FORTE dentro de ±InpNoticiaMin -> texto do bloqueio
string NewsBloqueio(datetime now)
{
   if(!CalOn() || !InpCalBloquearForte || InpNoticiaMin<=0) return "";
   LoadNews();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3) continue;
      int d=(int)((g_news[i].t-now)/60);
      if(MathAbs(d)<=InpNoticiaMin) return StringFormat("NOTÍCIA FORTE %s %s %s (%s) - NÃO OPERE AGORA",g_news[i].cur,g_news[i].nome,HHMM(g_news[i].t),d>=0?StringFormat("em %d min",d):StringFormat("foi há %d min",-d));
   }
   return "";
}

string NoticiaAviso(datetime t)
{
   string cb=NewsBloqueio(t); if(cb!="") return cb;
   if(InpNoticias=="") return "";
   string p[]; int k=StringSplit(InpNoticias,',',p); int now=MinOfDay(t);
   for(int i=0;i<k;i++)
   {
      string s=p[i]; StringTrimLeft(s); StringTrimRight(s); if(StringLen(s)<4) continue;
      string hm[]; if(StringSplit(s,':',hm)<2) continue;
      int m=(int)StringToInteger(hm[0])*60+(int)StringToInteger(hm[1]);
      int d=m-now;
      if(MathAbs(d)<=InpNoticiaMin) return StringFormat("NOTÍCIA %s %s - NÃO OPERE AGORA",s,d>=0?StringFormat("em %d min",d):StringFormat("foi há %d min",-d));
   }
   return "";
}

//--------------------------------------------------------------------
// DISCIPLINA (le historico da conta - só leitura)
void CalcDisciplina(datetime now)
{
   g_stopsHoje=0; g_tradesHoje=0; g_netHoje=0; g_pare="";
   datetime d0=DayStart(now);
   if(!HistorySelect(d0,now+60)) return;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      long typ=HistoryDealGetInteger(d,DEAL_TYPE); if(typ!=DEAL_TYPE_BUY && typ!=DEAL_TYPE_SELL) continue;
      long en=HistoryDealGetInteger(d,DEAL_ENTRY);
      double v=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);
      g_netHoje+=v;
      if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_INOUT || en==DEAL_ENTRY_OUT_BY){ g_tradesHoje++; if(HistoryDealGetDouble(d,DEAL_PROFIT)<0) g_stopsHoje++; }
   }
   if(InpMaxStopsDia>0 && g_stopsHoje>=InpMaxStopsDia) g_pare=StringFormat("PARE POR HOJE: %d stops (limite %d)",g_stopsHoje,InpMaxStopsDia);
   else if(InpMetaDiaUSD>0 && g_netHoje>=InpMetaDiaUSD) g_pare=StringFormat("PARE POR HOJE: meta batida (+$%.2f)",g_netHoje);
   else if(InpPerdaMaxDiaUSD>0 && g_netHoje<=-InpPerdaMaxDiaUSD) g_pare=StringFormat("PARE POR HOJE: perda do dia $%.2f",g_netHoje);
}

//--------------------------------------------------------------------
// PLANO + NOTA
void CalcPlano(int dir,Plano &p,int sessN)
{
   p.dir=dir; p.entry=0; p.stop=0; p.target=0; p.alvoNome=""; p.entNome=""; p.rr=0; p.lot=0; p.riskUSD=0; p.targetUSD=0; p.loteMinAcima=false; p.score=0;
   for(int q=0;q<7;q++) p.pts[q]=false;
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ask<=0||bid<=0){ ask=g_r[0].close; bid=g_r[0].close; }
   double spread=ask-bid;
   datetime tNow=g_r[0].time; int tfs=PeriodSeconds(InpTFExec);
   // 1 tendencia
   int ptsT = g_trend==dir ? 2 : 0; p.pts[0]=(ptsT>0);
   // 2 varrida do lado oposto (compra: varreu fundo)
   int ptsV=0; double sweepExt=0; datetime tSw=0;
   for(int v=0;v<ArraySize(g_niv);v++)
      if(g_niv[v].lado==-dir && g_niv[v].estado==ST_VARRIDA && (tNow-g_niv[v].tSweep)<=InpVarridaValida*tfs && g_niv[v].tSweep>tSw){ tSw=g_niv[v].tSweep; sweepExt=g_niv[v].sweepExt; ptsV=2; }
   p.pts[1]=(ptsV>0);
   // 3 BOS a favor (recente)
   int ptsB=0; int nb=ArraySize(g_bos);
   if(nb>0 && g_bos[nb-1].dir==dir && (tNow-g_bos[nb-1].tBreak)<=InpBOSValido*tfs) ptsB=2;
   p.pts[2]=(ptsB>0);
   // 4 FVG aberto a favor, recente (30 barras)
   int fi=-1;
   for(int m=ArraySize(g_fvg)-1;m>=0;m--) if(!g_fvg[m].filled && g_fvg[m].dir==dir && (tNow-g_fvg[m].t0)<=30*tfs){ fi=m; break; }
   double pxn=(dir==1?ask:bid);
   p.pts[3]=(fi>=0 || InHTFFVG(dir,pxn)!="");
   // 5 volume forte a favor (12 barras)
   p.pts[4]=(g_volAge<=12 && g_volDir==dir);
   // 6 sessao
   p.pts[5]=(sessN==1);
   // plano
   double atr=g_atr, buf=InpBufferATR*atr+spread;
   if(fi>=0){ p.entry=(g_fvg[fi].top+g_fvg[fi].bot)/2; p.entNome="meio do FVG"; }
   else     { p.entry= dir==1?ask:bid; p.entNome="preço atual (sem FVG)"; }
   // stop: além da varrida (se houver) senão além do swing mais próximo do lado de proteção
   double base=0; int n=ArraySize(g_r);
   if(sweepExt>0 && ((dir==1 && sweepExt<p.entry) || (dir==-1 && sweepExt>p.entry))) base=sweepExt;
   else
   {
      for(int j=InpSwingLen+1;j<MathMin(n-InpSwingLen,80);j++)
      {
         if(dir==1 && IsSL(g_r,j,InpSwingLen) && g_r[j].low<p.entry-0.3*atr){ base=g_r[j].low; break; }
         if(dir==-1 && IsSH(g_r,j,InpSwingLen) && g_r[j].high>p.entry+0.3*atr){ base=g_r[j].high; break; }
      }
      if(base==0) base = dir==1? p.entry-atr : p.entry+atr;
   }
   p.stop = dir==1 ? base-buf : base+buf;
   if(dir==1 && p.stop>=p.entry-0.3*atr) p.stop=p.entry-MathMax(atr,buf);
   if(dir==-1 && p.stop<=p.entry+0.3*atr) p.stop=p.entry+MathMax(atr,buf);
   // alvo: liquidez intacta mais proxima do outro lado
   p.target=0; p.alvoNome="sem liquidez clara";
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      if(g_niv[v].lado!=dir || g_niv[v].estado==ST_ROMPIDO) continue;
      double lv=g_niv[v].preco;
      if(dir==1 && lv>p.entry && (p.target==0 || lv<p.target)){ p.target=lv; p.alvoNome=g_niv[v].nome; }
      if(dir==-1 && lv<p.entry && (p.target==0 || lv>p.target)){ p.target=lv; p.alvoNome=g_niv[v].nome; }
   }
   double risk=MathAbs(p.entry-p.stop);
   p.rr = (p.target>0 && risk>0)? MathAbs(p.target-p.entry)/risk : 0;
   p.pts[6]=(p.rr>=InpRRMin);
   // lote
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01; if(vmin<=0) vmin=0.01; if(vmax<=0) vmax=100;
   if(tv>0 && ts>0 && risk>0)
   {
      double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); if(cs<=0) cs=1;
      double rate=InpComissaoMilhao>=0?InpComissaoMilhao:(StringFind(_Symbol,"XAU")>=0||StringFind(_Symbol,"XAG")>=0?20.0:5.0);
      g_comLote=2.0*rate*cs*p.entry/1e6;   // ida+volta por lote
      double perLot=risk/ts*tv+g_comLote+spread/ts*tv;
      double lot=MathFloor(InpRiscoUSD/perLot/step)*step;
      if(lot<vmin){ lot=vmin; p.loteMinAcima=true; }
      lot=MathMin(lot,vmax); p.lot=lot;
      p.riskUSD=lot*perLot;
      p.targetUSD = p.target>0 ? lot*(MathAbs(p.target-p.entry)/ts*tv-g_comLote) : 0;
   }
   p.score = ptsT+ptsV+ptsB+(p.pts[3]?1:0)+(p.pts[4]?1:0)+(p.pts[5]?1:0)+(p.pts[6]?1:0);
}
void DrawPlano(const Plano &p)
{
   DelPrefix("PL");
   if(p.score<InpScoreAmarelo || g_pare!="" || NoticiaAviso(TimeTradeServer())!="") return;
   datetime t1=g_r[0].time, t2=t1+PeriodSeconds(InpTFExec)*20;
   string d=p.dir==1?"COMPRA":"VENDA";
   ObjLine("PLe",t1,p.entry,t2,clrGold,STYLE_DASH,2,"Entrada "+d+" "+Fmt(p.entry)+" ("+p.entNome+")",clrGold);
   ObjLine("PLs",t1,p.stop,t2,clrRed,STYLE_SOLID,2,StringFormat("STOP %s  (-$%.2f)",Fmt(p.stop),p.riskUSD),clrRed);
   if(p.target>0) ObjLine("PLt",t1,p.target,t2,clrLime,STYLE_SOLID,2,StringFormat("ALVO %s  (+$%.2f)  R:R %.1f",Fmt(p.target),p.targetUSD,p.rr),clrLime);
}

//--------------------------------------------------------------------
// PAINEL (canvas: sem limite de 63 caracteres dos labels)
string g_ln[]; color g_lc[]; int g_lsz[]; bool g_lb[]; string g_seg[];
void PL(string t,color c,int sz=0,bool bold=false,string seg=""){ int k=ArraySize(g_ln); ArrayResize(g_ln,k+1); ArrayResize(g_lc,k+1); ArrayResize(g_lsz,k+1); ArrayResize(g_lb,k+1); ArrayResize(g_seg,k+1); g_ln[k]=t; g_lc[k]=c; g_lsz[k]=(sz==0?InpFonte:sz); g_lb[k]=bold; g_seg[k]=seg; }
// linha colorida por pedacos: textos em t[] e cores em c[]
void PLS(const string &t[],const color &c[],int sz=0,bool bold=true)
{
   string all="", seg="";
   for(int i=0;i<ArraySize(t);i++){ all+=t[i]; seg+=t[i]+"\x01"+IntegerToString((int)c[i])+"\x02"; }
   PL(all,clrWhite,sz,bold,seg);
}
// quebra texto longo em linhas de ~maxc caracteres
void PLW(string t,color c,int maxc=110,int sz=0,bool bold=false)
{
   if(StringFind(t,"\n")>=0){ string ls[]; int n=StringSplit(t,'\n',ls); for(int i=0;i<n;i++) if(ls[i]!="") PLW((i>0?"  ":"")+ls[i],c,maxc,sz,bold); return; }
   string pre="";
   while(StringLen(t)>maxc)
   {
      int cut=maxc; while(cut>40 && StringGetCharacter(t,cut)!=' ') cut--;
      PL(pre+StringSubstr(t,0,cut),c,sz,bold); t=StringSubstr(t,cut+1); pre="   ";
   }
   PL(pre+t,c,sz,bold);
}
string Ck(bool b){ return b?"[x]":"[  ]"; }

// texto em portugues explicando a leitura atual
string Narrativa(const Plano &b,bool block,string nw)
{
   if(block) return (g_pare!=""? g_pare : nw)+". Hoje o trabalho é NÃO operar. Proteger a conta também é lucro.";
   string d=b.dir==1?"compra":"venda";
   string t="";
   t+= g_mtf[2]==1?"H1 de alta":(g_mtf[2]==-1?"H1 de baixa":"H1 sem direção");
   t+= g_mtf[3]==g_mtf[2] && g_mtf[2]!=0 ? " (M15 junto)" : " (M15 diferente)";
   // varrida
   string sw="";
   for(int v=0;v<ArraySize(g_niv);v++) if(g_niv[v].lado==-b.dir && g_niv[v].estado==ST_VARRIDA && (g_r[0].time-g_niv[v].tSweep)<=InpVarridaValida*PeriodSeconds(InpTFExec)) sw=g_niv[v].nome;
   t+= sw!="" ? ", varreu "+sw : ", ainda sem varrida do lado "+(b.dir==1?"de baixo":"de cima");
   int nb=ArraySize(g_bos);
   if(nb>0 && g_bos[nb-1].dir==b.dir && b.pts[2]) t+=", "+(g_bos[nb-1].choch?"CHoCH":"BOS")+" no "+StringSubstr(EnumToString(InpTFExec),7)+" a favor";
   else t+=", sem BOS a favor";
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(px<=0) px=g_r[0].close;
   string inH=InHTFFVG(b.dir,px);
   if(inH!="") t+=", preço DENTRO do "+inH+" de "+d;
   else if(StringFind(b.entNome,"FVG")>=0) t+=", FVG de "+d+" em "+Fmt(b.entry);
   t+=". ";
   if(b.score>=InpScoreVerde)
   {
      if(StringFind(b.entNome,"FVG")>=0 && MathAbs(px-b.entry)>0.3*g_atr) t+="=> Esperar o preço VOLTAR ao FVG ("+Fmt(b.entry)+") e confirmar no M1; stop "+Fmt(b.stop)+", alvo "+b.alvoNome+".";
      else t+="=> Setup de "+d+" montado. Só entre se o M1 confirmar; stop "+Fmt(b.stop)+", alvo "+b.alvoNome+".";
   }
   else if(b.score>=InpScoreAmarelo)
   {
      string falta="";
      string nm[7]={"tendência","varrida","BOS","FVG","volume","horário","alvo 2R"};
      for(int i=0;i<7;i++) if(!b.pts[i]) falta+=(falta==""?"":", ")+nm[i];
      t+="=> Atenção, mas ainda falta: "+falta+". Esperar.";
   }
   else t+="=> Nada pra fazer agora. Sem setup é sem operação.";
   return t;
}
void Painel()
{
   ArrayResize(g_ln,0); ArrayResize(g_lc,0); ArrayResize(g_lsz,0); ArrayResize(g_lb,0); ArrayResize(g_seg,0);
   datetime now=TimeTradeServer(); if(now==0 && ArraySize(g_r)>0) now=g_r[0].time;
   string tfE=StringSubstr(EnumToString(InpTFExec),7);
#ifdef APROF_EA
   PL("ALIEN PROFESSOR AUTO  |  "+_Symbol+"  |  estrutura "+tfE+"  |  robô em teste: sem garantia de lucro",clrGold,InpFonte+2,true);
#else
   PL("ALIEN PROFESSOR  |  "+_Symbol+"  |  estrutura "+tfE+"  |  só ajuda: quem decide é você",clrGold,InpFonte+2,true);
#endif
   if(g_extra!="") PL(g_extra,g_extraC,InpFonte+1,true);
   if(g_aiPanel!="" || g_statusSvc!="")
   {
      if(g_aiPanel!=""){ PL("ANÁLISE IA (opinião, não decide nada)",clrGold,0,true); PLW("  "+g_aiPanel,clrAqua); }
      if(g_statusSvc!="") PL("  "+g_statusSvc,clrSilver,InpFonte-1);
   }
   if(!g_ready){ PL("carregando dados... (abra o gráfico "+tfE+" e "+StringSubstr(EnumToString(InpTFTrend),7)+" uma vez se demorar)",clrWhite); }
   else
   {
      string sTxt; int sN=SessaoNota(now,sTxt);
      Plano b,o; if(g_pb.score>=g_ps.score){ b=g_pb; o=g_ps; } else { b=g_ps; o=g_pb; }
      string nw=NoticiaAviso(now);
      bool block=(g_pare!="" || nw!="");
      if(InpPainelMTF)
      {
         string t[]; color c[]; ArrayResize(t,0); ArrayResize(c,0);
         int up=0,dn=0;
         for(int i=0;i<6;i++)
         {
            int k=ArraySize(t); ArrayResize(t,k+1); ArrayResize(c,k+1);
            t[k]=g_mtfNm[i]+(g_mtf[i]==1?" ▲   ":(g_mtf[i]==-1?" ▼   ":" ■   "));
            c[k]=g_mtf[i]==1?clrLime:(g_mtf[i]==-1?clrRed:clrSilver);
            if(g_mtf[i]==1) up++; if(g_mtf[i]==-1) dn++;
         }
         int k=ArraySize(t); ArrayResize(t,k+1); ArrayResize(c,k+1);
         bool core4up=(g_mtf[1]==1&&g_mtf[2]==1&&g_mtf[3]==1&&g_mtf[4]==1), core4dn=(g_mtf[1]==-1&&g_mtf[2]==-1&&g_mtf[3]==-1&&g_mtf[4]==-1);
         if(core4up){ t[k]="ALINHADO EM ALTA ("+IntegerToString(up)+"/6)"; c[k]=clrLime; }
         else if(core4dn){ t[k]="ALINHADO EM BAIXA ("+IntegerToString(dn)+"/6)"; c[k]=clrRed; }
         else { t[k]=StringFormat("CONFLITO (%d alta / %d baixa)",up,dn); c[k]=clrOrange; }
         PLS(t,c,InpFonte+1,true);
      }
      PL("LEITURA DO PROFESSOR",clrGold,0,true);
      PLW("  "+Narrativa(b,block,nw),clrWhite);
      if(InpCalendario){ PL("PRÓXIMAS NOTÍCIAS ("+InpCalMoedas+", hora do servidor)",clrGold,0,true); PLW("  "+NewsLista(InpCompacto?2:4," | "),clrOrange); }
      if(!InpCompacto){
      PL("CONTEXTO",clrGold,0,true);
      PL("  Tendência "+g_trendTxt, g_trend==1?clrLime:(g_trend==-1?clrTomato:clrWhite));
      PL("  Viés do dia: "+g_biasTxt, g_bias==1?clrLime:(g_bias==-1?clrTomato:clrWhite));
      PL("  Sessão: "+sTxt+"   (servidor "+HHMM(now)+")", sN==1?clrLime:(sN==-1?clrOrangeRed:clrWhite));
      // liquidez mais proxima
      double px=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(px<=0) px=g_r[0].close;
      int ia=-1, ib=-1;
      for(int v=0;v<ArraySize(g_niv);v++){ if(g_niv[v].estado==ST_ROMPIDO) continue; if(g_niv[v].preco>px && (ia<0||g_niv[v].preco<g_niv[ia].preco)) ia=v; if(g_niv[v].preco<px && (ib<0||g_niv[v].preco>g_niv[ib].preco)) ib=v; }
      PL("LIQUIDEZ",clrGold,0,true);
      PL("  Acima: "+(ia>=0? g_niv[ia].nome+" "+Fmt(g_niv[ia].preco)+StringFormat(" (%.1f ATR)",(g_niv[ia].preco-px)/MathMax(g_atr,_Point)):"nenhuma perto"),clrWhite);
      PL("  Abaixo: "+(ib>=0? g_niv[ib].nome+" "+Fmt(g_niv[ib].preco)+StringFormat(" (%.1f ATR)",(px-g_niv[ib].preco)/MathMax(g_atr,_Point)):"nenhuma perto"),clrWhite);
      string sw="";
      for(int v=0;v<ArraySize(g_niv);v++) if(g_niv[v].estado==ST_VARRIDA && (g_r[0].time-g_niv[v].tSweep)<=InpVarridaValida*PeriodSeconds(InpTFExec)) sw+=(sw==""?"":" | ")+g_niv[v].nome+" "+HHMM(g_niv[v].tSweep);
      PL("  Varridas recentes: "+(sw==""?"nenhuma":sw), sw==""?clrWhite:clrMagenta);
      int nb=ArraySize(g_bos);
      string bs = nb>0 ? StringFormat("%s %s às %s em %s",g_bos[nb-1].choch?"CHoCH":"BOS",g_bos[nb-1].dir==1?"de ALTA":"de BAIXA",HHMM(g_bos[nb-1].tBreak),Fmt(g_bos[nb-1].preco)) : "nenhum";
      int fo=0; for(int m=0;m<ArraySize(g_fvg);m++) if(!g_fvg[m].filled) fo++;
      PL("ESTRUTURA "+tfE,clrGold,0,true);
      PL("  Último: "+bs+"  |  FVG abertos: "+IntegerToString(fo),clrWhite);
      PL("  Volume forte (>2x média 20): "+(g_volAge<999? StringFormat("%s às %s (%d barras atrás)",g_volDir==1?"vela de alta":"vela de baixa",HHMM(g_volT),g_volAge):"nenhum nas últimas 60 barras"),clrWhite);
      }
      // nota
      string sem; color sc;
      if(block){ sem="VERMELHO (BLOQUEADO)"; sc=clrRed; }
      else if(b.score>=InpScoreVerde){ sem="VERDE"; sc=clrLime; }
      else if(b.score>=InpScoreAmarelo){ sem="AMARELO"; sc=clrYellow; }
      else { sem="VERMELHO"; sc=clrRed; }
      PL(StringFormat("SEMÁFORO: %s   %s %d/10   (outro lado: %s %d/10)",sem,b.dir==1?"COMPRA":"VENDA",b.score,o.dir==1?"compra":"venda",o.score),sc,InpFonte+3,true);
      PL(StringFormat("  %s tendência %s (2)  %s varreu liquidez do outro lado (2)  %s BOS a favor (2)",Ck(b.pts[0]),StringSubstr(EnumToString(InpTFTrend),7),Ck(b.pts[1]),Ck(b.pts[2])),clrWhite);
      PL(StringFormat("  %s FVG aberto (1)  %s volume forte (1)  %s horário bom (1)  %s alvo >= %.0fR (1)",Ck(b.pts[3]),Ck(b.pts[4]),Ck(b.pts[5]),Ck(b.pts[6]),InpRRMin),clrWhite);
      PL("PLANO SUGERIDO ("+(b.dir==1?"COMPRA":"VENDA")+") - confira antes, nada é garantido",clrGold,0,true);
      PL(StringFormat("  Entrada %s (%s)  |  Stop %s  |  Alvo %s (%s)  |  R:R %.1f",Fmt(b.entry),b.entNome,Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.alvoNome,b.rr),clrWhite);
      bool goatOk = b.riskUSD<=InpLimiteFlutuante;
      PL(StringFormat("  Lote %.2f  ->  risco $%.2f  |  alvo +$%.2f  |  Goat: flutuante máx $%.0f %s",b.lot,b.riskUSD,b.targetUSD,InpLimiteFlutuante,goatOk?"OK":"ESTOURA! diminua o lote"), goatOk?clrWhite:clrOrangeRed);
      if(b.loteMinAcima) PL(StringFormat("  ATENÇÃO: nem o lote mínimo cabe no risco de $%.0f - stop grande demais, pule este",InpRiscoUSD),clrOrangeRed);
      PL("DISCIPLINA",clrGold,0,true);
      PL(StringFormat("  Hoje (conta toda): %d operações, %d stops (máx %d), resultado $%+.2f  (meta $%.0f / perda máx $%.0f)",g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD),clrWhite);
      if(g_pare!="") PL("  >>> "+g_pare+" <<<  feche a plataforma",clrRed,InpFonte+4,true);
      if(nw!="") PL("  >>> "+nw+" <<<",clrRed,InpFonte+2,true);
      if(sN==-1) PL("  Aviso: horário ruim. Profissional espera.",clrOrangeRed);
      if(InpMostrarHonestidade)
      {
         PL("HONESTIDADE",clrGold,0,true);
         PL("  Esta nota é um checklist, NÃO uma previsão. Teste 2016-2025 das setas (nota >= 7) seguidas à risca:",clrSilver,InpFonte-1);
         PL("  ouro -0,32R por trade, US500 -0,17R. Seguir a seta sozinha PERDE. Use como lista de conferência.",clrSilver,InpFonte-1);
         if(!InpCompacto){
         PL("  Só observação - VO3 (M15: volume 2x + corpo forte + rompe 20 barras + FVG): 67 trades 2016-24, PF 2,8,",clrSilver,InpFonte-1);
         PL("  mas em 2025 PF 0,86 (15 trades) e reprovou nos critérios. Não é sinal de entrada.",clrSilver,InpFonte-1); }
      }
   }
   // desenha
   int W=0,H=8; 
   if(!g_cvOk) return;
   for(int i=0;i<ArraySize(g_ln);i++){ g_cv.FontSet("Arial",-g_lsz[i]*10,g_lb[i]?FW_BOLD:FW_NORMAL); int w=g_cv.TextWidth(g_ln[i]); if(w>W) W=w; H+=g_cv.TextHeight(g_ln[i])+2; }
   W+=24; H+=6;
   if(g_cv.Width()!=W || g_cv.Height()!=H) g_cv.Resize(W,H);
   g_cv.Erase(ColorToARGB(clrBlack,225));
   g_cv.Rectangle(0,0,W-1,H-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(1,1,W-2,H-2,ColorToARGB(clrGold,255));
   int y=6;
   for(int i=0;i<ArraySize(g_ln);i++)
   {
      g_cv.FontSet("Arial",-g_lsz[i]*10,g_lb[i]?FW_BOLD:FW_NORMAL);
      if(g_seg[i]=="") g_cv.TextOut(12,y,g_ln[i],ColorToARGB(g_lc[i],255));
      else
      {
         string parts[]; int np=StringSplit(g_seg[i],'\x02',parts); int x=12;
         for(int q=0;q<np;q++){ string tc[]; if(StringSplit(parts[q],'\x01',tc)<2) continue; g_cv.TextOut(x,y,tc[0],ColorToARGB((color)StringToInteger(tc[1]),255)); x+=g_cv.TextWidth(tc[0]); }
      }
      y+=g_cv.TextHeight(g_ln[i])+2;
   }
   g_cv.Update(true);
}

//--------------------------------------------------------------------
void Tema()
{
   if(!InpTemaAlien) return;
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrGold);
   ChartSetInteger(0,CHART_COLOR_GRID,C'30,30,30');
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrGold);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,clrGold);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'60,60,60');
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrSilver);
   ChartSetInteger(0,CHART_COLOR_CHART_LINE,clrGold);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
}
bool Core_Init()
{
   if(InpTFExec<PERIOD_M1){} // nada
   Tema();
   if(!g_noDraw) g_cvOk=g_cv.CreateBitmapLabel(0,0,PFX+"PAINEL",InpPainelX,InpPainelY,600,200,COLOR_FORMAT_ARGB_NORMALIZE);
   if(g_cvOk){ ObjectSetInteger(0,PFX+"PAINEL",OBJPROP_SELECTABLE,false); ObjectSetInteger(0,PFX+"PAINEL",OBJPROP_HIDDEN,true); }
   return true;
}
void Core_Deinit()
{
   if(g_cvOk) g_cv.Destroy();
   ObjectsDeleteAll(0,PFX);
   ChartRedraw(0);
}

// SINAL: seta de compra/venda no grafico com entrada/stop/alvo/lote (NÃO envia ordem)
int g_nSig=0;
void DrawSinal(const Plano &b,datetime t)
{
   string o=PFX+"SIG"+IntegerToString(g_nSig);
   double y = b.dir==1 ? iLow(_Symbol,InpTFExec,1) : iHigh(_Symbol,InpTFExec,1);
   ObjectCreate(0,o,b.dir==1?OBJ_ARROW_BUY:OBJ_ARROW_SELL,0,t,y);
   ObjectSetInteger(0,o,OBJPROP_COLOR,b.dir==1?clrLime:clrRed); ObjectSetInteger(0,o,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
   string txt=StringFormat("%s %d/10 E %s S %s A %s lote %.2f",b.dir==1?"COMPRA":"VENDA",b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.lot);
   ObjectSetString(0,o,OBJPROP_TOOLTIP,txt);
   ObjTxt("SIGt"+IntegerToString(g_nSig),t,y,txt,b.dir==1?clrLime:clrRed,8,b.dir==1?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
   g_nSig++;
}

// Exporta o sinal para o EA ALIEN_PROFESSOR_TELEGRAM (indicador não pode usar WebRequest)
// arquivo MQL5\Files\APROF_SINAL_<simbolo>.txt + variável global APROF_SIG_<simbolo> = hora do sinal
void ExportaSinal(const Plano &b,datetime t,string m)
{
   string txt=StringFormat("ALIEN PROFESSOR - %s %s\nNota %d/10 (%s)\nEntrada %s | Stop %s | Alvo %s (%s)\nR:R %.1f | Lote %.2f | Risco $%.2f | Alvo +$%.2f\n\n%s\n\nSó apoio: a decisão é sua. Nenhuma garantia de lucro.",
      _Symbol,b.dir==1?"COMPRA":"VENDA",b.score,b.score>=InpScoreVerde?"VERDE":"AMARELO",Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.alvoNome,b.rr,b.lot,b.riskUSD,b.targetUSD,Narrativa(b,false,""));
   int h=FileOpen("APROF_SINAL_"+_Symbol+".txt",FILE_WRITE|FILE_BIN);
   if(h!=INVALID_HANDLE){ uchar u[]; int n=StringToCharArray(txt,u,0,WHOLE_ARRAY,CP_UTF8); FileWriteArray(h,u,0,MathMax(n-1,0)); FileClose(h); }
   GlobalVariableSet("APROF_SIG_"+_Symbol,(double)t);
}
// recalcula tudo; chamada a cada tick (pesado só em barra nova do TF da estrutura)
void Core_Update(bool forcePanel=false)
{
   static ulong lastPanelMs=0;
   ArraySetAsSeries(g_r,true);
   datetime bt=iTime(_Symbol,InpTFExec,0);
   bool newBar=(bt!=0 && bt!=g_lastBar);
   static ulong lastFull=0;
   bool refresh=(forcePanel && GetTickCount64()-lastFull>60000); // a cada 60s refaz (mercado parado / dados chegando)
   if(newBar || !g_ready || refresh)
   {
      int n=CopyRates(_Symbol,InpTFExec,0,MathMax(InpBarrasScan+50,1500),g_r);
      if(n<200){ g_ready=false; Painel(); return; }
      g_atr=ATRof(g_r,14,1);
      if(!CalcTrend()){ g_ready=false; Painel(); return; }
      CalcNiveis(); CalcEstrutura();
      if(!g_noDraw){ DrawNiveis(); DrawEstrutura(); }
      if(refresh){ g_fvgH1Bar=0; g_fvgM15Bar=0; ArrayInitialize(g_mtfBar,0); }
      g_lastBar=bt; g_ready=true; lastFull=GetTickCount64();
   }
   else
   {
      // atualiza só a barra atual
      MqlRates cur[]; if(CopyRates(_Symbol,InpTFExec,0,1,cur)==1) g_r[0]=cur[0];
   }
   datetime now=TimeTradeServer(); if(now==0) now=g_r[0].time;
   ulong ms=GetTickCount64();
   if(!newBar && !forcePanel && (MQLInfoInteger(MQL_TESTER) || ms-lastPanelMs<1000)) return;
   lastPanelMs=ms;
   CalcMTF();
   CalcDisciplina(now);
   string sTxt; int sN=SessaoNota(now,sTxt);
   CalcPlano(1,g_pb,sN); CalcPlano(-1,g_ps,sN);
   Plano b; if(g_pb.score>=g_ps.score) b=g_pb; else b=g_ps;
   if(!g_noDraw){ DrawPlano(b); Painel(); }
   // alerta (uma vez por barra)
   static int prevOk=0; // 0 = abaixo; +1/-1 = já avisou nessa direção
   bool okNow=(b.score>=InpScoreAlerta && g_pare=="" && NoticiaAviso(now)=="");
   if(newBar && !okNow) prevOk=0;
   if(newBar && okNow && prevOk!=b.dir && g_lastAlert!=bt)
   {
      g_lastAlert=bt; prevOk=b.dir;
      string m=StringFormat("ALIEN PROFESSOR %s: %s nota %d/10 | entrada %s stop %s alvo %s R:R %.1f lote %.2f (risco $%.2f). Confira o checklist - a decisão é sua.",
                            _Symbol,b.dir==1?"COMPRA":"VENDA",b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.rr,b.lot,b.riskUSD);
      if(!g_noDraw) DrawSinal(b,bt);
      ExportaSinal(b,bt,m);
      if(InpAlerta) Alert(m);
      if(InpPush) SendNotification(m);
   }
   ChartRedraw(0);
}

// ---- Telegram (texto + foto) ----
string UrlEnc(string s)
{
   uchar u[]; int n=StringToCharArray(s,u,0,WHOLE_ARRAY,CP_UTF8); string r="";
   for(int i=0;i<n-1;i++)
   {
      uchar c=u[i];
      if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'||c=='~') r+=CharToString(c);
      else r+=StringFormat("%%%02X",c);
   }
   return r;
}
// WebRequest não existe no testador -> Telegram desligado lá
bool TgTokenOk(){ return InpUseTelegram && StringLen(InpTelegramToken)>20 && !MQLInfoInteger(MQL_TESTER); }
bool TgOk(){ return TgTokenOk() && StringLen(InpTelegramChatId)>0; }
bool SendMsg(string text){ if(!TgOk()) return false; return SendMsgTo(InpTelegramChatId,text); }
bool SendMsgTo(string chat,string text)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string url="https://api.telegram.org/bot"+InpTelegramToken+"/sendMessage";
   string body="chat_id="+UrlEnc(chat)+"&text="+UrlEnc(text);
   char data[],res[]; string rh; StringToCharArray(body,data,0,StringLen(body));  // body já é ASCII (url-encoded)
   ResetLastError();
   int code=WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",8000,data,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return false; }
   if(code!=200) Print("Telegram respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
void AddStr(char &buf[],string s){ uchar u[]; int n=StringToCharArray(s,u,0,WHOLE_ARRAY,CP_UTF8); int k=ArraySize(buf); ArrayResize(buf,k+n-1); for(int i=0;i<n-1;i++) buf[k+i]=(char)u[i]; }
bool SendPhoto(string file,string caption)
{
   if(!TgOk()) return false;
   int h=FileOpen(file,FILE_READ|FILE_BIN); if(h==INVALID_HANDLE){ Print("Telegram: sem print ",file); return false; }
   uchar img[]; FileReadArray(h,img); FileClose(h);
   string bd="----ALIENPROF"+IntegerToString(GetTickCount());
   char buf[]; ArrayResize(buf,0);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n"+InpTelegramChatId+"\r\n");
   if(StringLen(caption)>1000) caption=StringSubstr(caption,0,1000);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n"+caption+"\r\n");
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"grafico.png\"\r\nContent-Type: image/png\r\n\r\n");
   int k=ArraySize(buf); int n=ArraySize(img); ArrayResize(buf,k+n); for(int i=0;i<n;i++) buf[k+i]=(char)img[i];
   AddStr(buf,"\r\n--"+bd+"--\r\n");
   char res[]; string rh;
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+InpTelegramToken+"/sendPhoto","Content-Type: multipart/form-data; boundary="+bd+"\r\n",15000,buf,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram foto respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}

//====================================================================
// ANÁLISE IA (opcional). Só comenta; por padrão NUNCA muda decisão.
enum ENUM_AIMODE { AMBAS=0, PRINCIPAL_COM_RESERVA=1 };
input group "=== Análise IA (opcional) ==="
input ENUM_AIMODE InpAIMode = AMBAS;                                      // AMBAS = Grok + Gemini juntos, 1 resposta unida | PRINCIPAL_COM_RESERVA
input bool   InpUseAI      = true;                                         // Usar análise IA (precisa de chave)
input string InpAIProvider = "xai";                                        // Provedor (qualquer API compatível com OpenAI)
input string InpAIEndpoint = "https://api.x.ai/v1/chat/completions";      // Endpoint (xAI; ou https://api.openai.com/v1/chat/completions)
input string InpAIModel    = "grok-4.20-0309-non-reasoning";               // Modelo (rápido)
input string InpAIKey      = "";                                           // Chave da API (vazio = IA desligada)
input string InpAI2Endpoint= "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"; // Reserva: Google Gemini (compatível OpenAI)
input string InpAI2Model   = "gemini-3.5-flash-lite";                      // Modelo reserva
input string InpAI2Key     = "";                                           // Chave Gemini (vazio = sem reserva)
input int    InpAIMinutos  = 0;                                            // Análise a cada N minutos também (0 = só nos sinais)
input bool   InpAIVeto     = false;                                        // IA pode VETAR (só opera se o VEREDITO for o lado do sinal; em AMBAS, as duas têm que concordar)
input int    InpAIMinSeg   = 15;                                           // Limite: mínimo de segundos entre perguntas à IA
input int    InpAIMaxHora  = 30;                                           // Limite: máximo de perguntas à IA por hora (0 = sem limite)

string   g_aiTxt="";
datetime g_aiLast=0;

bool AIOn(){ return InpUseAI && (StringLen(InpAIKey)>10 || StringLen(InpAI2Key)>10) && !MQLInfoInteger(MQL_TESTER); }
string JEsc(string s)
{
   StringReplace(s,"\\","\\\\"); StringReplace(s,"\"","\\\""); StringReplace(s,"\n","\\n"); StringReplace(s,"\r",""); StringReplace(s,"\t"," ");
   return s;
}
// extrai o primeiro "content":"..." da resposta
string JContent(string r)
{
   int c0=StringFind(r,"\"content\""); if(c0<0) return "";
   int k=StringFind(r,":",c0); if(k<0) return "";
   int p=StringFind(r,"\"",k+1); if(p<0) return "";
   string out=""; int n=StringLen(r);
   for(int i=p+1;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(c=='\\' && i+1<n)
      {
         ushort d=StringGetCharacter(r,i+1); i++;
         if(d=='n') out+="\n"; else if(d=='t') out+=" "; else if(d=='u' && i+4<n){ out+=ShortToString((ushort)StringToInteger("0x"+StringSubstr(r,i+1,4))); i+=4; }
         else out+=ShortToString(d);
         continue;
      }
      if(c=='"') break;
      out+=ShortToString(c);
   }
   return out;
}
// limite de uso da IA (não gastar cota / não travar o robô)
ulong g_aiCalls[]; ulong g_aiLastMs=0;
int AIEsperaSeg()   // 0 = pode perguntar; >0 = segundos para esperar
{
   ulong now=GetTickCount64();
   if(InpAIMinSeg>0 && g_aiLastMs>0 && now-g_aiLastMs<(ulong)InpAIMinSeg*1000) return (int)(((ulong)InpAIMinSeg*1000-(now-g_aiLastMs))/1000)+1;
   if(InpAIMaxHora>0)
   {
      int k=0; for(int i=0;i<ArraySize(g_aiCalls);i++) if(now-g_aiCalls[i]<3600000) g_aiCalls[k++]=g_aiCalls[i];
      ArrayResize(g_aiCalls,k);
      if(k>=InpAIMaxHora) return (int)((3600000-(now-g_aiCalls[0]))/1000)+1;
   }
   return 0;
}
void AIMarca(){ ulong now=GetTickCount64(); g_aiLastMs=now; int k=ArraySize(g_aiCalls); ArrayResize(g_aiCalls,k+1); g_aiCalls[k]=now; }
string AISysPadrao()
{
   return "Você é um professor de trading de SMC/liquidez. Responda em português do Brasil, no máximo 4 linhas curtas, sem prometer lucro. "
          "Diga o que confirma e o que invalida o setup, e o que observar no M1.";
}
// pergunta pra IA: tenta xAI; se der erro/tempo/cota, tenta a reserva (Gemini)
string AIAsk(string estado){ return AIAskEx(AISysPadrao(),estado,220,true); }   // sinais: passam do limite (poucos por dia)
string   g_aiVeredito="";   // COMPRA / VENDA / ESPERAR da última análise
bool     g_aiConcordam=false;
string AIVer(string t)
{
   string u=t; StringToUpper(u); int k=-1, f=0;
   while(true){ int q=StringFind(u,"VEREDITO",f); if(q<0) break; k=q; f=q+1; }
   if(k<0) return "";
   string r=StringSubstr(u,k,40);
   if(StringFind(r,"COMPRA")>=0) return "COMPRA";
   if(StringFind(r,"VENDA")>=0) return "VENDA";
   if(StringFind(r,"ESPERA")>=0) return "ESPERAR";
   return "";
}
string AISemVeredito(string t)
{
   string ls[]; int n=StringSplit(t,'\n',ls); string o="";
   for(int i=0;i<n;i++){ string u=ls[i]; StringToUpper(u); if(StringFind(u,"VEREDITO")>=0 || StringFind(u,"CONFIAN")==0) continue; o+=(o==""?"":"\n")+ls[i]; }
   StringTrimRight(o); return o;
}
// respostas brutas das IAs ficam em MQL5\Files\ALIEN_ia_log.txt (só respostas, nunca chaves)
void AILog(string tag,string txt)
{
   int h=FileOpen("ALIEN_ia_log.txt",FILE_READ|FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END); FileWriteString(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+" "+_Symbol+" ["+tag+"] "+txt+"\r\n"); FileClose(h);
}
string AIAskEx(string sys,string user,int maxTok,bool force=false,bool verdict=true)
{
   if(!AIOn()) return "";
   if(!force && AIEsperaSeg()>0){ Print("IA: limite de uso - pulei esta pergunta"); return ""; }
   AIMarca();
   g_aiVeredito=""; g_aiConcordam=false;
   string sysV=verdict ? sys+" Na última linha escreva exatamente uma destas: VEREDITO: COMPRA / VEREDITO: VENDA / VEREDITO: ESPERAR." : sys;
   bool hA=StringLen(InpAIKey)>10, hB=StringLen(InpAI2Key)>10;
   string t="", conf="";
   if(InpAIMode==AMBAS && hA && hB)
   {
      string a=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,InpAIKey,maxTok);
      string g=AIAskOne(sysV,user,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok);
      string va=AIVer(a), vg=AIVer(g);
      AILog("GROK "+va,a); AILog("GEMINI "+vg,g);
      if(a=="" && g=="") return "";
      if(!verdict) g_aiVeredito="";
      if(a=="" || g=="")
      {
         t=(a!=""?a:g); g_aiVeredito=(a!=""?va:vg); if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
         conf="Confiança: só "+(a!=""?"GROK":"GEMINI")+" respondeu agora";
      }
      else
      {
         g_aiConcordam=(va!="" && va==vg);
         g_aiVeredito=g_aiConcordam?va:"ESPERAR";
         if(!verdict){ g_aiConcordam=true; g_aiVeredito=""; }
         int lin = maxTok<=250 ? 5 : 12;
         string sysM= verdict ?
                     "Você une duas análises de trading em UMA só, em português do Brasil, curta (no máximo "+IntegerToString(lin)+" linhas), sem markdown, sem citar quem escreveu. "
                     "Tom direto e seguro, com os motivos claros. Use só o que está nas análises, não invente preços. Onde elas discordam, diga isso. Na última linha escreva exatamente: VEREDITO: "+g_aiVeredito+"."
                     : "Você une duas respostas em UMA só, em português do Brasil, natural e direta (no máximo "+IntegerToString(lin)+" linhas), sem markdown, sem citar quem escreveu. Fique com o melhor das duas.";
         string uM="ANÁLISE 1:\n"+AISemVeredito(a)+"\nVEREDITO 1: "+va+"\n\nANÁLISE 2:\n"+AISemVeredito(g)+"\nVEREDITO 2: "+vg;
         string m=AIAskOne(sysM,uM,InpAIEndpoint,InpAIModel,InpAIKey,maxTok);
         if(m=="") m=AIAskOne(sysM,uM,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok);
         if(StringLen(AISemVeredito(m))<20) m=a;   // união vazia -> usa a 1ª análise
         AILog("UNIDA "+g_aiVeredito,m);
         t=m;
         conf=g_aiConcordam?"Confiança: as duas IAs concordam":"Confiança: IAs divergiram (GROK "+(va==""?"?":va)+", GEMINI "+(vg==""?"?":vg)+") → ESPERAR";
      }
   }
   else
   {
      string who="";
      if(hA){ t=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,InpAIKey,maxTok); who="GROK"; }
      if(t=="" && hB){ t=AIAskOne(sysV,user,InpAI2Endpoint,InpAI2Model,InpAI2Key,maxTok); who="GEMINI"; if(t!="") Print("IA: usei a reserva (",InpAI2Model,")"); }
      if(t=="") return "";
      g_aiVeredito=AIVer(t); if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
      AILog(who+" "+g_aiVeredito,t);
      conf="Confiança: 1 IA ("+who+")";
   }
   g_aiLast=TimeCurrent();
   if(!verdict){ g_aiVeredito=""; return AISemVeredito(t); }
   return AISemVeredito(t)+"\nVEREDITO: "+g_aiVeredito+"\n"+conf;
}
string AIAskOne(string sys,string estado,string endpoint,string model,string key,int maxTok)
{
   string body="{\"model\":\""+JEsc(model)+"\",\"temperature\":0.2,\"max_tokens\":"+IntegerToString(maxTok)+",\"messages\":[{\"role\":\"system\",\"content\":\""+JEsc(sys)+"\"},{\"role\":\"user\",\"content\":\""+JEsc(estado)+"\"}]}";
   char data[],res[]; string rh;
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); ArrayResize(data,n-1);
   string hdr="Content-Type: application/json\r\nAuthorization: Bearer "+key+"\r\n";
   ResetLastError();
   int code=WebRequest("POST",endpoint,hdr,15000,data,res,rh);
   if(code==-1){ Print("IA: WebRequest bloqueado (erro ",GetLastError(),"). Adicione o endereço do endpoint em Ferramentas > Opções > Expert Advisors."); return ""; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ Print("IA respondeu ",code,": ",StringSubstr(r,0,300)); return ""; }
   string t=JContent(r); StringReplace(t,"**",""); StringTrimLeft(t); StringTrimRight(t);
   return t;
}
// veto: com InpAIVeto ligado só opera se o VEREDITO for o lado do sinal (em AMBAS, divergência = ESPERAR = não opera)
bool AIVetou(string t,int dir){ if(!InpAIVeto || t=="") return false; return g_aiVeredito!=(dir==1?"COMPRA":"VENDA"); }
string AIStatus()
{
   if(!InpUseAI) return "IA: desligada";
   if(StringLen(InpAIKey)<=10 && StringLen(InpAI2Key)<=10) return "IA: coloque sua chave em InpAIKey (xAI) ou InpAI2Key (Gemini)";
   if(MQLInfoInteger(MQL_TESTER)) return "IA: não roda no testador";
   return "";
}

//====================================================================
// PARTE DO ROBÔ
CTrade   g_tr;
double   g_peak=0;
bool     g_ddPause=false;
datetime g_lastSigBar=0;
int      g_prevScore[2]={0,0};
string   g_status="";

bool ContaBloqueada()
{
   if(MQLInfoInteger(MQL_TESTER)) return false;
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO && !InpAllowRealAccount);
}
bool TemPosOuOrdem()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(t>0 && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) return true; }
   for(int i=OrdersTotal()-1;i>=0;i--){ ulong t=OrderGetTicket(i); if(t>0 && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==InpMagic) return true; }
   return false;
}
double NormP(double p){ double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(ts<=0) ts=_Point; return NormalizeDouble(MathRound(p/ts)*ts,_Digits); }
void Notifica(string m){ Print(m); if(TgOk()) SendMsg(m); }

// fecha por tempo / horário e cancela limitada vencida
void Gerencia()
{
   datetime now=TimeCurrent(); MqlDateTime d; TimeToStruct(now,d); int hhmm=d.hour*100+d.min;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol || OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      if((InpLimiteMin>0 && now-(datetime)OrderGetInteger(ORDER_TIME_SETUP)>=InpLimiteMin*60) || (InpFecharHHMM>0 && hhmm>=InpFecharHHMM)) { g_tr.OrderDelete(t); }
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if((InpMaxHoras>0 && now-(datetime)PositionGetInteger(POSITION_TIME)>=InpMaxHoras*3600) || (InpFecharHHMM>0 && hhmm>=InpFecharHHMM))
      { if(g_tr.PositionClose(t)) Notifica(StringFormat("ALIEN AUTO %s: posição fechada por tempo/horário.",_Symbol)); }
   }
}

string Bloqueio(const Plano &b)
{
   if(ContaBloqueada()) return "BLOQUEADO: CONTA REAL (InpAllowRealAccount = false)";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && !MQLInfoInteger(MQL_TESTER)) return "AlgoTrading desligado no terminal";
   if(InpDDPausaPct>0 && g_ddPause) return StringFormat("PAUSADO: caiu %.0f%% do pico. Reinicie o robô só depois de rever tudo.",InpDDPausaPct);
   if(g_pare!="") return g_pare;
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") return nw;
   string st; int sN=SessaoNota(TimeCurrent(),st);
   if(InpBloquearHorarioRuim && sN==-1) return "horário ruim - não opera";
   MqlDateTime d; TimeToStruct(TimeCurrent(),d); if(InpFecharHHMM>0 && d.hour*100+d.min>=InpFecharHHMM-100) return "perto do fechamento do dia";
   return "";
}



//====================================================================
// APRENDIZADO: diário de sinais + resultado de cada trade (MQL5\Files)
//  ALIEN_diario.csv      -> todo sinal (operado ou pulado, com motivo)
//  ALIEN_aprendizado.csv -> cada trade fechado: nota, faixa, lado, sessão, hora, R
string   g_sigInfo="";            // info do sinal da ordem aberta (1 posição por vez)
double   g_sigRiskUSD=0; int g_sigScore=0, g_sigDir=0, g_sigHour=0; string g_sigSess=""; datetime g_sigTime=0;
string Faixa(int sc){ return sc<=4?"0-4":(sc<=6?"5-6":(sc<=8?"7-8":"9-10")); }
string SessNome(datetime t){ string st; SessaoNota(t,st); int p=StringFind(st," -"); return p>0?StringSubstr(st,0,p):st; }
void CsvAppend(string file,string header,string line)
{
   int h=FileOpen(file,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0) FileWriteString(h,header+"\r\n");
   FileSeek(h,0,SEEK_END); FileWriteString(h,line+"\r\n"); FileClose(h);
}
void Diario(const Plano &b,string acao)
{
   CsvAppend("ALIEN_diario.csv","hora;simbolo;lado;nota;faixa;sessao;entrada;stop;alvo;rr;lote;acao",
      StringFormat("%s;%s;%s;%d;%s;%s;%s;%s;%s;%.2f;%.2f;%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),_Symbol,b.dir==1?"compra":"venda",b.score,Faixa(b.score),
      SessNome(TimeCurrent()),Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.rr,b.lot,acao));
}
// estatística do histórico (ALIEN_aprendizado.csv) para a IA e para a trava opcional
struct HistRow { string sym; int dir; int score; string sess; int hour; double R; };
HistRow g_hist[]; datetime g_histLoad=0;
void LoadHist()
{
   if(TimeCurrent()-g_histLoad<300 && g_histLoad>0) return;
   g_histLoad=TimeCurrent(); ArrayResize(g_hist,0);
   int h=FileOpen("ALIEN_aprendizado.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return;
   bool first=true;
   while(!FileIsEnding(h))
   {
      string ln=FileReadString(h); if(first){ first=false; continue; }
      string c[]; if(StringSplit(ln,';',c)<10) continue;
      int k=ArraySize(g_hist); ArrayResize(g_hist,k+1);
      g_hist[k].sym=c[1]; g_hist[k].dir=(c[2]=="compra"?1:-1); g_hist[k].score=(int)StringToInteger(c[3]);
      g_hist[k].sess=c[5]; g_hist[k].hour=(int)StringToInteger(c[6]); g_hist[k].R=StringToDouble(c[9]);
   }
   FileClose(h);
}
void HStat(string faixa,int dir,string sess,int &n,double &win,double &avg)
{
   n=0; double w=0,s=0;
   for(int i=0;i<ArraySize(g_hist);i++)
   {
      if(g_hist[i].sym!=_Symbol) continue;
      if(faixa!="" && Faixa(g_hist[i].score)!=faixa) continue;
      if(dir!=0 && g_hist[i].dir!=dir) continue;
      if(sess!="" && g_hist[i].sess!=sess) continue;
      n++; s+=g_hist[i].R; if(g_hist[i].R>0) w++;
   }
   win = n>0? 100.0*w/n : 0; avg = n>0? s/n : 0;
}
bool FaixaDesativada(string faixa,int dir,string sess)
{
   int n; double w,a; HStat(faixa,dir,sess,n,w,a);
   return (n>=InpAprenderMinN && a<0);
}
string HistResumo(const Plano &b)
{
   LoadHist();
   int nAll; double wAll,aAll; HStat("",0,"",nAll,wAll,aAll);
   if(nAll==0) return "{\"trades\":0,\"nota\":\"sem histórico ainda\"}";
   string fx=Faixa(b.score), ss=SessNome(TimeCurrent());
   int n; double w,a; HStat(fx,b.dir,ss,n,w,a);
   // melhores/piores horas (n>=3)
   double hs[24]; int hn[24]; ArrayInitialize(hs,0); ArrayInitialize(hn,0);
   for(int i=0;i<ArraySize(g_hist);i++) if(g_hist[i].sym==_Symbol && g_hist[i].hour>=0 && g_hist[i].hour<24){ hs[g_hist[i].hour]+=g_hist[i].R; hn[g_hist[i].hour]++; }
   int best=-1,worst=-1;
   for(int hh=0;hh<24;hh++){ if(hn[hh]<3) continue; double m=hs[hh]/hn[hh]; if(best<0||m>hs[best]/hn[best]) best=hh; if(worst<0||m<hs[worst]/hn[worst]) worst=hh; }
   // faixas que a trava desativaria
   string des=""; string fxs[4]={"0-4","5-6","7-8","9-10"}; string sss[4]={"Ásia","Londres","Nova York","fim de NY / madrugada"};
   for(int f=0;f<4;f++) for(int d=0;d<2;d++) for(int q=0;q<4;q++)
      if(FaixaDesativada(fxs[f],d==0?1:-1,sss[q])) des+=(des==""?"":",")+"\""+fxs[f]+" "+(d==0?"compra":"venda")+" "+sss[q]+"\"";
   return StringFormat("{\"trades\":%d,\"acerto_geral\":%.0f,\"R_medio_geral\":%.2f,\"parecidos\":{\"filtro\":\"%s %s %s\",\"n\":%d,\"acerto\":%.0f,\"R_medio\":%.2f},\"melhor_hora\":%s,\"pior_hora\":%s,\"faixas_desativadas\":[%s],\"trava_ligada\":%s}",
      nAll,wAll,aAll,fx,b.dir==1?"compra":"venda",ss,n,w,a,best>=0?IntegerToString(best):"null",worst>=0?IntegerToString(worst):"null",des,InpAprenderDesativar?"true":"false");
}
// estado do professor em JSON compacto (para a IA)
string StateJSON(const Plano &b)
{
   string j="{\"simbolo\":\""+_Symbol+"\",\"hora_servidor\":\""+TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+"\",\"tendencias\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+IntegerToString(g_mtf[i]);
   j+="},\"niveis\":[";
   for(int v=0;v<ArraySize(g_niv);v++) j+=(v?",":"")+StringFormat("{\"n\":\"%s\",\"p\":%s,\"e\":\"%s\"}",JEsc(g_niv[v].nome),Fmt(g_niv[v].preco),g_niv[v].estado==ST_VARRIDA?"varrida":(g_niv[v].estado==ST_ROMPIDO?"rompido":"intacto"));
   int nb=ArraySize(g_bos);
   j+="],\"ultimo_bos\":"+(nb>0?StringFormat("{\"dir\":%d,\"preco\":%s,\"choch\":%s}",g_bos[nb-1].dir,Fmt(g_bos[nb-1].preco),g_bos[nb-1].choch?"true":"false"):"null");
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"}; string pts="";
   for(int i=0;i<7;i++) pts+=(i?",":"")+"\""+nm[i]+"\":"+(b.pts[i]?"true":"false");
   j+=StringFormat(",\"plano\":{\"dir\":\"%s\",\"nota\":%d,\"entrada\":%s,\"stop\":%s,\"alvo\":%s,\"rr\":%.2f,\"lote\":%.2f,\"risco_usd\":%.2f},\"criterios\":{%s}",
        b.dir==1?"compra":"venda",b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"null",b.rr,b.lot,b.riskUSD,pts);
   j+=",\"historico_do_vitor\":"+HistResumo(b);
   j+=",\"leitura\":\""+JEsc(Narrativa(b,false,""))+"\",\"aviso\":\"teste 2016-2025: sinais nota>=7 perderam em media\"}";
   return j;
}

//====================================================================
// CHAT TELEGRAM (duas vias) + PRÉ-AVISO DE NOTÍCIA + RESUMOS AGENDADOS
// Só aceita mensagens do chat InpTelegramChatId. Não roda no testador.
// Com o robô em vários gráficos, só UM lê as mensagens (trava por variável global).
long     g_tgOff=0;
datetime g_tgStartUtc=0;
string   g_tgHint="";        // chat id do /start (quando InpTelegramChatId está vazio)
string   g_alertados="|";    // notícias já pré-avisadas
string   g_resFeitos="|";    // resumos já enviados (data+nome)
double   g_inst=0;           // id desta instância (trava de quem lê o chat)
bool     g_tgMaster=false;
int      g_tgErrPrint=0;

bool TgMaster()
{
   string gi="APROF_TGM_ID", gt="APROF_TGM_T"; datetime now=TimeLocal();
   if(!GlobalVariableCheck(gi) || GlobalVariableGet(gi)==g_inst || now-(datetime)GlobalVariableGet(gt)>30)
   { GlobalVariableSet(gi,g_inst); GlobalVariableSet(gt,(double)now); return true; }
   return false;
}
void TgMasterSolta(){ if(GlobalVariableCheck("APROF_TGM_ID") && GlobalVariableGet("APROF_TGM_ID")==g_inst){ GlobalVariableDel("APROF_TGM_ID"); GlobalVariableDel("APROF_TGM_T"); } }

// lê string JSON a partir do índice da aspa de abertura (decodifica \n, \uXXXX...)
string JDecode(string r,int p)
{
   string out=""; int n=StringLen(r);
   for(int i=p+1;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(c=='\\' && i+1<n)
      {
         ushort d=StringGetCharacter(r,i+1); i++;
         if(d=='n') out+="\n"; else if(d=='t') out+=" "; else if(d=='r') {} 
         else if(d=='u' && i+4<n){ out+=ShortToString((ushort)StringToInteger("0x"+StringSubstr(r,i+1,4))); i+=4; }
         else out+=ShortToString(d);
         continue;
      }
      if(c=='"') break;
      out+=ShortToString(c);
   }
   return out;
}
string JStrKey(string r,string key){ int k=StringFind(r,"\""+key+"\":\""); if(k<0) return ""; return JDecode(r,k+StringLen(key)+3); }
string JNumKey(string r,string key,int from=0)
{
   int k=StringFind(r,"\""+key+"\":",from); if(k<0) return "";
   int i=k+StringLen(key)+3; string s=""; int n=StringLen(r);
   while(i<n){ ushort c=StringGetCharacter(r,i); if((c>='0'&&c<='9')||c=='-') s+=ShortToString(c); else if(s!="") break; else if(c!=' ') break; i++; }
   return s;
}

// --- contexto completo para a IA ---
string FVGJson(const FVGz &f[],int maxN)
{
   string s=""; int n=0;
   for(int i=ArraySize(f)-1;i>=0 && n<maxN;i--){ if(f[i].filled) continue; s+=(s==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",f[i].dir==1?"alta":"baixa",Fmt(f[i].top),Fmt(f[i].bot)); n++; }
   return "["+s+"]";
}
string PosJSON()
{
   string s="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      int dg=(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS);
      s+=(s==""?"":",")+StringFormat("{\"simbolo\":\"%s\",\"lado\":\"%s\",\"lote\":%.2f,\"preco\":%s,\"stop\":%s,\"alvo\":%s,\"lucro_usd\":%.2f,\"origem\":\"%s\"}",
         PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",PositionGetDouble(POSITION_VOLUME),
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),dg),DoubleToString(PositionGetDouble(POSITION_SL),dg),DoubleToString(PositionGetDouble(POSITION_TP),dg),
         PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?"robo":"manual");
   }
   return "["+s+"]";
}
Plano MelhorPlano(){ Plano b; if(g_pb.score>=g_ps.score) b=g_pb; else b=g_ps; return b; }
string ContextJSON()
{
   Plano b=MelhorPlano();
   string j=StateJSON(b);                       // tendências D1..M1, níveis/varridas, BOS, plano, histórico, leitura
   j=StringSubstr(j,0,StringLen(j)-1);          // tira o } final
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   string st; SessaoNota(TimeTradeServer(),st);
   j+=StringFormat(",\"preco\":%s,\"spread\":%s,\"atr_%s\":%s,\"sessao\":\"%s\",\"vies_dia\":\"%s\",\"tendencia_txt\":\"%s\"",
        Fmt(bid),Fmt(ask-bid),StringSubstr(EnumToString(InpTFExec),7),Fmt(g_atr),JEsc(st),JEsc(g_biasTxt),JEsc(g_trendTxt));
   j+=StringFormat(",\"nota_compra\":%d,\"nota_venda\":%d",g_pb.score,g_ps.score);
   j+=",\"fvg_"+StringSubstr(EnumToString(InpTFExec),7)+"\":"+FVGJson(g_fvg,4)+",\"fvg_M15\":"+FVGJson(g_fvgM15,3)+",\"fvg_H1\":"+FVGJson(g_fvgH1,3);
   j+=",\"noticias\":"+NewsJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\"";
   j+=",\"posicoes_abertas\":"+PosJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"},\"robo\":{\"opera\":%s,\"status\":\"%s\",\"pausa_dd\":%s}}",
        g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare),InpTradeEnabled?"true":"false",JEsc(g_status),g_ddPause?"true":"false");
   return j;
}
string SysChat()
{
   return "Você é o ALIEN PROFESSOR, parceiro de trading do Vitor (barbeiro e trader de mesa proprietária Goat, risco fixo US$45 por trade, limite de perda flutuante US$50, opera no M1). "
          "Fale em português do Brasil, como um professor experiente: direto, seguro, com os motivos claros (tendência por tempo gráfico, liquidez e varridas, BOS, FVGs, nota, spread, notícias, posições). "
          "Use SÓ os dados do CONTEXTO para falar de preços; nunca invente números. Quando não estiver claro, diga ESPERAR sem enrolar. Nunca prometa lucro. "
          "Pode conversar sobre qualquer assunto que ele trouxer (rotina, disciplina, cabeça, vida), com respeito e sinceridade. Use a CONVERSA RECENTE para manter o fio. "
          "No máximo 12 linhas, sem markdown. Quando fizer sentido, lembre: no teste 2016-2025 os sinais nota>=7 perderam em média.";
}
// ---- memória da conversa (últimas 10 mensagens) em MQL5\Files\ALIEN_chat_memoria.txt ----
string g_mem[];
void MemLoad()
{
   ArrayResize(g_mem,0);
   int h=FileOpen("ALIEN_chat_memoria.txt",FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ); if(h==INVALID_HANDLE) return;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(l=="") continue; int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=l; }
   FileClose(h);
}
void MemAdd(string quem,string txt)
{
   MemLoad();
   StringReplace(txt,"\r",""); StringReplace(txt,"\n"," / "); if(StringLen(txt)>700) txt=StringSubstr(txt,0,700)+"...";
   int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=TimeToString(TimeTradeServer(),TIME_DATE|TIME_MINUTES)+" "+quem+": "+txt;
   int st=MathMax(0,ArraySize(g_mem)-10);
   int h=FileOpen("ALIEN_chat_memoria.txt",FILE_WRITE|FILE_TXT|FILE_UNICODE); if(h==INVALID_HANDLE) return;
   for(int i=st;i<ArraySize(g_mem);i++) FileWriteString(h,g_mem[i]+"\r\n");
   FileClose(h);
}
string MemTxt(){ MemLoad(); if(ArraySize(g_mem)==0) return ""; string s="CONVERSA RECENTE (mais antiga primeiro):\n"; for(int i=0;i<ArraySize(g_mem);i++) s+=g_mem[i]+"\n"; return s+"\n"; }

// ---- /analise em qualquer símbolo e tempo gráfico ----
ENUM_TIMEFRAMES TfDe(string t)
{
   StringToUpper(t);
   if(t=="M1") return PERIOD_M1; if(t=="M5") return PERIOD_M5; if(t=="M15") return PERIOD_M15; if(t=="M30") return PERIOD_M30;
   if(t=="H1") return PERIOD_H1; if(t=="H4") return PERIOD_H4; if(t=="D1"||t=="DIARIO"||t=="DIÁRIO") return PERIOD_D1; if(t=="W1"||t=="SEMANAL") return PERIOD_W1;
   return PERIOD_CURRENT;
}
ENUM_TIMEFRAMES TfMaior(ENUM_TIMEFRAMES tf)
{
   switch(tf){ case PERIOD_M1: return PERIOD_M15; case PERIOD_M5: return PERIOD_H1; case PERIOD_M15: return PERIOD_H4; case PERIOD_M30: return PERIOD_H4;
               case PERIOD_H1: return PERIOD_D1; case PERIOD_H4: return PERIOD_D1; case PERIOD_D1: return PERIOD_W1; default: return PERIOD_MN1; }
}
string TfNome(ENUM_TIMEFRAMES tf){ return StringSubstr(EnumToString(tf),7); }
bool SymOk(string s){ bool cu=false; return s!="" && SymbolExist(s,cu); }
string SimboloDe(string t,bool busca)
{
   string u=t; StringToUpper(u); if(StringLen(u)<3) return "";
   if(u=="OURO"||u=="GOLD"||u=="XAU") u="XAUUSD";
   if(u=="NASDAQ"||u=="NAS"||u=="NAS100"||u=="US100"||u=="USTEC") u="USTECH";
   if(u=="SP500"||u=="SP"||u=="S&P"||u=="SPX") u="US500";
   if(u=="DAX"||u=="GER40"||u=="ALEMANHA") u="DE40";
   string c[3]; c[0]=u; c[1]="."+u+"Cash"; c[2]=u+"Cash";
   for(int i=0;i<3;i++) if(SymOk(c[i])) return c[i];
   if(!busca || StringLen(u)<4) return "";
   for(int i=0;i<SymbolsTotal(false);i++){ string n=SymbolName(i,false), nu=n; StringToUpper(nu); if(StringFind(nu,u)>=0) return n; }
   return "";
}
// procura símbolo/TF no texto. busca=true só no /analise (procura parcial na lista)
bool ParseAlvo(string text,bool busca,string &sym,ENUM_TIMEFRAMES &tf)
{
   sym=""; tf=PERIOD_CURRENT;
   string t=text; string pn[]={"?","!",",",".",";",":","(",")","\"","'"}; for(int i=0;i<ArraySize(pn);i++) StringReplace(t,pn[i]," ");
   string w[]; int n=StringSplit(t,' ',w);
   for(int i=0;i<n;i++)
   {
      if(w[i]=="" || StringGetCharacter(w[i],0)=='/') continue;
      ENUM_TIMEFRAMES f=TfDe(w[i]); if(f!=PERIOD_CURRENT){ tf=f; continue; }
      if(sym==""){ string s=SimboloDe(w[i],busca); if(s!="") sym=s; }
   }
   return (sym!="" || tf!=PERIOD_CURRENT);
}
string FmtS(string sym,double p){ return DoubleToString(p,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)); }
// resumo de um TF: tendência, topos/fundos, BOS, FVGs abertos
string TfResumo(string sym,ENUM_TIMEFRAMES tf,double &sh0,double &sl0,FVGz &fv[])
{
   MqlRates r[]; ArraySetAsSeries(r,true); sh0=0; sl0=0; ArrayResize(fv,0);
   int n=CopyRates(sym,tf,0,300,r); if(n<60) return "{\"tf\":\""+TfNome(tf)+"\",\"erro\":\"sem dados\"}";
   double sh[2]={0,0}, sl[2]={0,0}; int a=0,b=0;
   for(int j=3;j<n-3 && (a<2||b<2);j++){ if(a<2&&IsSH(r,j,2)) sh[a++]=r[j].high; if(b<2&&IsSL(r,j,2)) sl[b++]=r[j].low; }
   sh0=sh[0]; sl0=sl[0];
   string bos="nenhum"; if(sh[0]>0 && r[1].close>sh[0]) bos="rompeu o topo "+FmtS(sym,sh[0])+" (alta)"; else if(sl[0]>0 && r[1].close<sl[0]) bos="rompeu o fundo "+FmtS(sym,sl[0])+" (baixa)";
   ScanFVG(r,tf,150,fv);
   string fs=""; int k=0;
   for(int i=ArraySize(fv)-1;i>=0 && k<4;i--){ if(fv[i].filled) continue; fs+=(fs==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",fv[i].dir==1?"alta":"baixa",FmtS(sym,fv[i].top),FmtS(sym,fv[i].bot)); k++; }
   string vel=""; for(int i=3;i>=1;i--) vel+=(i<3?",":"")+StringFormat("[%s,%s,%s,%s]",FmtS(sym,r[i].open),FmtS(sym,r[i].high),FmtS(sym,r[i].low),FmtS(sym,r[i].close));
   int tr=TrendTFs(sym,tf);
   return StringFormat("{\"tf\":\"%s\",\"tendencia\":%d,\"atr\":%s,\"topos\":[%s,%s],\"fundos\":[%s,%s],\"bos\":\"%s\",\"fvg_abertos\":[%s],\"ultimas_3_velas_OHLC\":[%s]}",
      TfNome(tf),tr,FmtS(sym,ATRof(r,14,1)),FmtS(sym,sh[0]),FmtS(sym,sh[1]),FmtS(sym,sl[0]),FmtS(sym,sl[1]),bos,fs,vel);
}
double g_fHi=0,g_fLo=0; FVGz g_fFvg[];
string TFContextJSON(string sym,ENUM_TIMEFRAMES tf)
{
   SymbolSelect(sym,true);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID), ask=SymbolInfoDouble(sym,SYMBOL_ASK);
   string j="{\"simbolo\":\""+sym+"\",\"tf_foco\":\""+TfNome(tf)+"\",\"hora_servidor\":\""+TimeToString(TimeTradeServer(),TIME_DATE|TIME_MINUTES)+"\",\"preco\":"+FmtS(sym,bid)+",\"spread\":"+FmtS(sym,ask-bid)+",\"tendencias\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+IntegerToString(TrendTFs(sym,g_mtfTF[i]));
   double h2,l2; FVGz f2[];
   j+="},\"foco\":"+TfResumo(sym,tf,g_fHi,g_fLo,g_fFvg)+",\"tf_maior\":"+TfResumo(sym,TfMaior(tf),h2,l2,f2);
   double pdh=iHigh(sym,PERIOD_D1,1), pdl=iLow(sym,PERIOD_D1,1), pwh=iHigh(sym,PERIOD_W1,1), pwl=iLow(sym,PERIOD_W1,1);
   j+=",\"PDH\":"+FmtS(sym,pdh)+",\"PDL\":"+FmtS(sym,pdl)+",\"semana_passada_max\":"+FmtS(sym,pwh)+",\"semana_passada_min\":"+FmtS(sym,pwl);
   j+=",\"noticias\":"+NewsJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\",\"posicoes_abertas\":"+PosJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"}",g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare));
   if(sym==_Symbol) j+=",\"professor_do_grafico\":"+ContextJSON();
   return j+"}";
}
// print de qualquer símbolo/TF: abre um gráfico temporário, desenha níveis e FVGs, tira o print e fecha
bool FotoTF(string sym,ENUM_TIMEFRAMES tf,string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   SymbolSelect(sym,true);
   long id=ChartOpen(sym,tf); if(id==0){ Print("Telegram: não abri gráfico ",sym," ",TfNome(tf)); return false; }
   ChartSetInteger(id,CHART_COLOR_BACKGROUND,clrBlack); ChartSetInteger(id,CHART_COLOR_FOREGROUND,clrGold); ChartSetInteger(id,CHART_SHOW_GRID,false);
   ChartSetInteger(id,CHART_COLOR_CANDLE_BULL,clrGold); ChartSetInteger(id,CHART_COLOR_CHART_UP,clrGold); ChartSetInteger(id,CHART_COLOR_CANDLE_BEAR,C'60,60,60');
   ChartSetInteger(id,CHART_COLOR_CHART_DOWN,clrSilver); ChartSetInteger(id,CHART_MODE,CHART_CANDLES); ChartSetInteger(id,CHART_SHIFT,true); ChartSetInteger(id,CHART_AUTOSCROLL,true); ChartSetInteger(id,CHART_SCALE,3);
   for(int i=0;i<25 && Bars(sym,tf)<100;i++) Sleep(200);
   datetime t0=iTime(sym,tf,120), t1=iTime(sym,tf,0)+PeriodSeconds(tf)*10;
   double lv[4]; string ln[4]={"PDH","PDL","topo","fundo"}; color lc[4]={clrDodgerBlue,clrDodgerBlue,clrGold,clrGold};
   lv[0]=iHigh(sym,PERIOD_D1,1); lv[1]=iLow(sym,PERIOD_D1,1); lv[2]=g_fHi; lv[3]=g_fLo;
   for(int i=0;i<4;i++){ if(lv[i]<=0) continue; string o="AP_T_L"+IntegerToString(i); ObjectCreate(id,o,OBJ_TREND,0,t0,lv[i],t1,lv[i]); ObjectSetInteger(id,o,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,o,OBJPROP_STYLE,STYLE_DASH); ObjectSetString(id,o,OBJPROP_TEXT,ln[i]);
      string ot="AP_T_T"+IntegerToString(i); ObjectCreate(id,ot,OBJ_TEXT,0,t1,lv[i]); ObjectSetString(id,ot,OBJPROP_TEXT,ln[i]+" "+FmtS(sym,lv[i])); ObjectSetInteger(id,ot,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,ot,OBJPROP_FONTSIZE,9); }
   int k=0;
   for(int i=ArraySize(g_fFvg)-1;i>=0 && k<4;i--){ if(g_fFvg[i].filled) continue; string o="AP_T_F"+IntegerToString(k++); ObjectCreate(id,o,OBJ_RECTANGLE,0,g_fFvg[i].t0,g_fFvg[i].top,t1,g_fFvg[i].bot); ObjectSetInteger(id,o,OBJPROP_COLOR,g_fFvg[i].dir==1?C'0,90,60':C'110,30,30'); ObjectSetInteger(id,o,OBJPROP_FILL,true); ObjectSetInteger(id,o,OBJPROP_BACK,true); }
   string tt="AP_T_TIT"; ObjectCreate(id,tt,OBJ_LABEL,0,0,0); ObjectSetInteger(id,tt,OBJPROP_XDISTANCE,10); ObjectSetInteger(id,tt,OBJPROP_YDISTANCE,10); ObjectSetString(id,tt,OBJPROP_TEXT,"ALIEN PROFESSOR  "+sym+"  "+TfNome(tf)); ObjectSetInteger(id,tt,OBJPROP_COLOR,clrGold); ObjectSetInteger(id,tt,OBJPROP_FONTSIZE,14);
   ChartRedraw(id); Sleep(1500); ChartRedraw(id);
   string f="APROF_tf_"+IntegerToString(GetTickCount())+".png";
   bool ok=ChartScreenShot(id,f,1600,900,ALIGN_RIGHT);
   ChartClose(id);
   if(!ok){ Print("Telegram: print do ",sym," ",TfNome(tf)," falhou"); return false; }
   ok=SendPhoto(f,caption); FileDelete(f); return ok;
}
bool EhMercado(string t)
{
   string u=t; StringToLower(u);
   string k[]={"compr","vend","entr","oper","trade","mercado","ouro","gold","xau","nasdaq","us500","dax","índice","indice","liquidez","fvg","bos","stop","alvo","tendên","tendenc","sinal","long","short","sell","buy","gráfico","grafico","preço","preco","notícia","noticia","analis","análise","agora","topo","fundo","varr"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
bool TgFoto(string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   string f="APROF_chat_"+_Symbol+".png"; ChartRedraw(0);
   if(!ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)){ Print("Telegram: não consegui tirar o print"); return false; }
   return SendPhoto(f,caption);
}
void ChatIA(string pergunta,string titulo,string sym="",ENUM_TIMEFRAMES tf=PERIOD_CURRENT)
{
   bool mercado = (sym!="" || EhMercado(pergunta));
   if(sym=="" && tf!=PERIOD_CURRENT) sym=_Symbol;
   if(sym!="" && tf==PERIOD_CURRENT) tf=InpTFExec;
   if(!AIOn())
   {
      Plano b=MelhorPlano();
      SendMsg("IA desligada (coloque a chave em InpAIKey ou InpAI2Key e libere o endereço no WebRequest). Leitura do professor:\n"+Narrativa(b,g_pare!=""||NoticiaAviso(TimeTradeServer())!="",NoticiaAviso(TimeTradeServer())));
      if(sym!="") { TFContextJSON(sym,tf); FotoTF(sym,tf,sym+" "+TfNome(tf)); } else TgFoto(_Symbol+" agora");
      return;
   }
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma: limite da IA. Tente de novo em %d s.",w)); return; }
   string ctx = sym!="" ? TFContextJSON(sym,tf) : ContextJSON();
   string r=AIAskEx(SysChat(),MemTxt()+"CONTEXTO DO MERCADO:\n"+ctx+"\n\nMENSAGEM DO VITOR:\n"+pergunta,650,false,mercado);
   if(r==""){ SendMsg("A IA não respondeu agora (veja a aba Experts do MT5). Tente de novo em 1 minuto."); return; }
   MemAdd("Vitor",pergunta); MemAdd("Professor",r);
   if(sym=="" || sym==_Symbol) g_aiPanel=r;
   SendMsg(titulo+"\n"+r+(mercado?"\n\n(opinião da IA - quem decide é você)":""));
   if(sym!="") FotoTF(sym,tf,sym+" "+TfNome(tf)+" "+TimeToString(TimeTradeServer(),TIME_MINUTES)+" (servidor)");
   else if(mercado) TgFoto(_Symbol+" "+TimeToString(TimeTradeServer(),TIME_MINUTES)+" (servidor)");
}
string StatusTxt()
{
   string s=StringFormat("ALIEN %s - STATUS\nModo: %s | conta %s\nRobô: %s\n",_Symbol,InpTradeEnabled?"OPERANDO":"ASSISTENTE (não opera)",
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",g_status);
   s+=StringFormat("Saldo $%.2f | Equity $%.2f\n",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   s+=StringFormat("Hoje: %d operações, %d stops (máx %d), resultado $%+.2f (meta $%.0f / perda máx $%.0f)\n",g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD);
   s+="Disciplina: "+(g_pare!=""?g_pare:"OK, pode operar")+(g_ddPause?" | PAUSADO pelo DD":"")+"\n";
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") s+=nw+"\n";
   int np=0; string ps="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue; np++;
      ps+=StringFormat("  %s %s %.2f lote @%s  P/L $%+.2f%s\n",PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",
          PositionGetDouble(POSITION_VOLUME),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS)),
          PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?" (robô)":" (manual)");
   }
   s+="Posições abertas: "+IntegerToString(np)+"\n"+ps;
   Plano b=MelhorPlano();
   s+=StringFormat("Nota agora: %s %d/10 (outro lado %d/10)\n",b.dir==1?"COMPRA":"VENDA",b.score,b.dir==1?g_ps.score:g_pb.score);
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   s+=StringFormat("Aprendizado (%s): %d trades, acerto %.0f%%, R médio %+.2f\n",_Symbol,n,w,a);
   string fx[4]={"0-4","5-6","7-8","9-10"};
   for(int f=0;f<4;f++){ int nn; double ww,aa; HStat(fx[f],0,"",nn,ww,aa); if(nn>0) s+=StringFormat("  nota %s: %d trades, acerto %.0f%%, R %+.2f\n",fx[f],nn,ww,aa); }
   s+="Trava do histórico: "+(InpAprenderDesativar?"LIGADA":"desligada");
   return s;
}
string AjudaTxt()
{
   return "ALIEN PROFESSOR - comandos ("+_Symbol+"):\n"
          "/analise - análise completa agora (IA) + print do gráfico\n"
          "/analise H4  ou  /analise XAUUSD M15 - qualquer símbolo e tempo (M1 M5 M15 M30 H1 H4 D1 W1)\n"
          "/status - posições, resultado de hoje, disciplina, aprendizado\n"
          "/noticias - próximas notícias fortes/médias ("+InpCalMoedas+")\n"
          "/foto - só o print do gráfico\n"
          "/ajuda - esta lista\n"
          "Ou escreva qualquer coisa (ex.: \"como tá o M15?\", \"e o ouro no H4?\", \"vale comprar agora?\"). Eu lembro das últimas 10 mensagens.";
}
void TgHandle(string chat,string text)
{
   StringTrimLeft(text); StringTrimRight(text); if(text=="") return;
   string cmd=text; int sp=StringFind(cmd," "); if(sp>0) cmd=StringSubstr(cmd,0,sp);
   int at=StringFind(cmd,"@"); if(at>0) cmd=StringSubstr(cmd,0,at);
   StringToLower(cmd);
   if(InpTelegramChatId=="")
   {
      if(cmd=="/start")
      {
         g_tgHint="Telegram: seu chat id é "+chat+" - copie para InpTelegramChatId e reinicie o robô";
         Print("ALIEN: ",g_tgHint); g_statusSvc=g_tgHint;
         SendMsgTo(chat,"Seu chat id é "+chat+". Cole em InpTelegramChatId nas configurações do robô e reinicie. Até lá eu não respondo comandos.");
      }
      return;
   }
   if(chat!=InpTelegramChatId){ Print("Telegram: ignorei mensagem de um chat não autorizado (",chat,")"); return; }
   Print("Telegram: comando ",cmd);
   if(cmd=="/start" || cmd=="/ajuda" || cmd=="/help"){ SendMsg(AjudaTxt()); return; }
   if(cmd=="/status"){ SendMsg(StatusTxt()); return; }
   if(cmd=="/noticias" || cmd=="/notícias"){ LoadNews(true); SendMsg("PRÓXIMAS NOTÍCIAS ("+InpCalMoedas+", hora do servidor):\n"+NewsLista(10,"\n")+(InpCalBloquearForte?StringFormat("\n\nNotícia FORTE: robô não entra %d min antes/depois.",InpNoticiaMin):"")); return; }
   if(cmd=="/foto"){ if(!TgFoto(_Symbol+" agora")) SendMsg("Não consegui mandar o print."); return; }
   if(cmd=="/analise" || cmd=="/análise")
   {
      string asy; ENUM_TIMEFRAMES atf;
      if(sp>0 && ParseAlvo(StringSubstr(text,sp+1),true,asy,atf))
      {
         if(asy=="") asy=_Symbol; if(atf==PERIOD_CURRENT) atf=InpTFExec;
         SendMsg("Analisando "+asy+" "+TfNome(atf)+"...");
         ChatIA("Faça a análise completa do "+asy+" no "+TfNome(atf)+" (com o contexto do tempo maior): tendência, liquidez (PDH/PDL, topos/fundos), BOS, FVGs, notícias. Vale comprar, vender ou esperar? O que confirma e o que invalida?","ANÁLISE "+asy+" "+TfNome(atf),asy,atf);
         return;
      }
      if(sp>0){ SendMsg("Não achei esse símbolo/tempo. Exemplos: /analise H4  |  /analise XAUUSD M15  |  /analise US500 H1"); return; }
      SendMsg("Analisando "+_Symbol+"..."); ChatIA("Faça a análise completa de agora: tendência em cada tempo gráfico (alinhado ou conflito), liquidez e varridas, BOS, FVGs, nota e plano, notícias. Vale entrar, esperar ou ficar fora? O que confirma e o que invalida?","ANÁLISE "+_Symbol); return; }
   if(StringGetCharacter(text,0)=='/'){ SendMsg("Comando não conhecido.\n\n"+AjudaTxt()); return; }
   string fsy; ENUM_TIMEFRAMES ftf;
   if(ParseAlvo(text,false,fsy,ftf)) ChatIA(text,"ALIEN "+(fsy!=""?fsy:_Symbol)+(ftf!=PERIOD_CURRENT?" "+TfNome(ftf):"")+":",fsy,ftf);
   else ChatIA(text,"ALIEN PROFESSOR:");
}
void TgPoll()
{
   if(!TgTokenOk() || !InpTgChat) return;
   g_tgMaster=TgMaster(); if(!g_tgMaster) return;
   string url="https://api.telegram.org/bot"+InpTelegramToken+"/getUpdates?timeout=0&limit=20&offset="+IntegerToString(g_tgOff);
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",5000,data,res,rh);
   if(code==-1){ if(g_tgErrPrint++%60==0) Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ if(g_tgErrPrint++%60==0) Print("Telegram getUpdates respondeu ",code,code==409?" (o bot tem webhook ou outro programa lendo - só um pode ler)":(code==401?" (token inválido - crie um novo no @BotFather)":""),": ",StringSubstr(r,0,200)); return; }
   int pos=0;
   while(true)
   {
      int k=StringFind(r,"\"update_id\":",pos); if(k<0) break;
      int nx=StringFind(r,"\"update_id\":",k+12);
      string seg= nx>0 ? StringSubstr(r,k,nx-k) : StringSubstr(r,k);
      long uid=StringToInteger(JNumKey(seg,"update_id"));
      if(uid>=g_tgOff) g_tgOff=uid+1;
      pos= nx>0 ? nx : StringLen(r);
      int cpos=StringFind(seg,"\"chat\":"); if(cpos<0) continue;
      string chat=JNumKey(seg,"id",cpos);
      long dt=StringToInteger(JNumKey(seg,"date"));
      if(dt>0 && dt<(long)g_tgStartUtc-120) continue;        // mensagem velha (antes do robô ligar)
      string text=JStrKey(seg,"text");
      if(chat!="" && text!="") TgHandle(chat,text);
   }
}
// pré-aviso de notícia FORTE (só a instância que lê o chat, pra não repetir)
void TgPreAlerta()
{
   if(!TgOk() || InpPreAlertaMin<=0 || !CalOn()) return;
   if(InpTgChat && !g_tgMaster) return;
   LoadNews(); datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3 || StringFind(InpPreAlertaMoedas,g_news[i].cur)<0) continue;
      long d=(long)(g_news[i].t-now); if(d<=0 || d>InpPreAlertaMin*60) continue;
      string key="|"+IntegerToString((long)g_news[i].id)+"|"; if(StringFind(g_alertados,key)>=0) continue;
      g_alertados+=IntegerToString((long)g_news[i].id)+"|";
      SendMsg(StringFormat("ATENÇÃO: notícia FORTE %s em %d min (%s servidor): %s.%s",g_news[i].cur,(int)(d/60)+1,HHMM(g_news[i].t),g_news[i].nome,
              InpCalBloquearForte?StringFormat(" O robô não entra %d min antes/depois. Proteja suas posições.",InpNoticiaMin):""));
   }
}
// resumo automático na abertura de Londres / NY
int HHMMtoMin(string s){ string p[]; if(StringSplit(s,':',p)<2) return -1; return (int)StringToInteger(p[0])*60+(int)StringToInteger(p[1]); }
void TgResumos()
{
   if(!TgOk() || !InpResumos) return;
   datetime now=TimeTradeServer(); MqlDateTime d; TimeToStruct(now,d);
   if(d.day_of_week==0 || d.day_of_week==6) return;      // fim de semana
   string nomes[2]={"LONDRES","NOVA YORK"}; string hs[2]; hs[0]=InpResumoLondres; hs[1]=InpResumoNY;
   for(int i=0;i<2;i++)
   {
      int m=HHMMtoMin(hs[i]); if(m<0) continue;
      int dm=MinOfDay(now)-m; if(dm<0 || dm>10) continue;
      string key=TimeToString(now,TIME_DATE)+nomes[i]+"|"; if(StringFind(g_resFeitos,key)>=0) continue;
      g_resFeitos+=key;
      Plano b=MelhorPlano();
      string r="";
      if(AIOn()) r=AIAskEx("Você é o ALIEN PROFESSOR. Escreva em português do Brasil o resumo da abertura da sessão de "+nomes[i]+" para o Vitor, no máximo 10 linhas, sem markdown: "
                           "tendência D1/H4/H1/M15 (alinhado ou conflito), viés do dia, liquidez acima/abaixo e o que já foi varrido, FVGs importantes, notícias fortes do dia, e o plano (o que esperar para comprar ou vender e o que invalida). Sem prometer lucro.",
                           "CONTEXTO:\n"+ContextJSON(),600,true);
      if(r=="") r=Narrativa(b,g_pare!="",NoticiaAviso(now))+"\nNotícias: "+NewsLista(4," | ");
      else g_aiPanel=r;
      SendMsg("ABERTURA DE "+nomes[i]+" - "+_Symbol+"\n"+r);
      TgFoto(_Symbol+" abertura de "+nomes[i]);
   }
}

string SvcStatus()
{
   string s=AIStatus();
   if(g_tgHint!="" && InpTelegramChatId=="") return g_tgHint;
   string t = !InpUseTelegram ? "Telegram: desligado" : (StringLen(InpTelegramToken)<=20 ? "Telegram: coloque o token" :
              (StringLen(InpTelegramChatId)==0 ? "Telegram: mande /start pro seu bot para ver seu chat id" :
              (MQLInfoInteger(MQL_TESTER) ? "Telegram: não roda no testador" : (InpTgChat ? (g_tgMaster?"Telegram: chat ATIVO neste gráfico (/ajuda)":"Telegram: chat atendido por outro gráfico") : ""))));
   if(s!="" && t!="") return s+"  |  "+t;
   return s+t;
}
void TentaOperar()
{
   Plano b; int di;
   if(g_pb.score>=g_ps.score){ b=g_pb; di=0; } else { b=g_ps; di=1; }
   // sinal = nota cruza o limite (estava abaixo na barra anterior) - igual ao teste
   bool cruzou = (b.score>=InpScoreTrade && g_prevScore[di]<InpScoreTrade);
   g_prevScore[0]=g_pb.score; g_prevScore[1]=g_ps.score;
   string blk=Bloqueio(b);
   if(!InpTradeEnabled)
   {
      // MODO ASSISTENTE: não manda ordem, só avisa o sinal (com análise e print)
      g_status = "MODO ASSISTENTE: só analisa e avisa"+(blk!=""?" | "+blk:"");
      if(!cruzou) return;
      Diario(b,"sinal (modo assistente, não operou)"+(blk!=""?" - "+blk:""));
      string ia2=AIAsk(StateJSON(b)); if(ia2!="") g_aiPanel=ia2;
      Notifica(StringFormat("ALIEN %s: SINAL %s nota %d/10 (modo assistente - NÃO operei)\nEntrada %s | Stop %s | Alvo %s | Lote %.2f (risco ~$%.2f)\n%s%s",
               _Symbol,b.dir==1?"COMPRA":"VENDA",b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.lot,b.riskUSD,
               blk!=""?"AVISO: "+blk+"\n":"",Narrativa(b,false,""))+(ia2!=""?"\n\nANÁLISE IA (opinião):\n"+ia2:""));
      if(TgOk() && InpTgFoto && !MQLInfoInteger(MQL_TESTER)) TgFoto(StringFormat("%s SINAL %s %d/10",_Symbol,b.dir==1?"COMPRA":"VENDA",b.score));
      return;
   }
   g_status = blk!="" ? blk : (TemPosOuOrdem()?"em operação (1 por vez)":StringFormat("aguardando nota >= %d",InpScoreTrade));
   if(!cruzou) return;
   if(blk!=""){ Diario(b,"pulado: "+blk); return; }
   if(TemPosOuOrdem()){ Diario(b,"pulado: já tem posição"); return; }
   LoadHist();
   if(InpAprenderDesativar && FaixaDesativada(Faixa(b.score),b.dir,SessNome(TimeCurrent()))){ Diario(b,"pulado: faixa desativada pelo histórico"); Print("ALIEN AUTO: faixa desativada pelo seu histórico - pulei"); return; }
   if(b.loteMinAcima || b.lot<=0){ Print("ALIEN AUTO: lote mínimo passa do risco - pulei"); return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=NormP(b.stop);
   double risk=MathAbs(b.entry-b.stop);
   if(risk<=0) return;
   if(InpSpreadMaxPctStop>0 && (ask-bid)>InpSpreadMaxPctStop/100.0*risk){ Print("ALIEN AUTO: spread alto - pulei"); return; }
   double tp=b.target>0? b.target : b.entry+2.0*risk*b.dir;
   tp=NormP(tp);
   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double lot=NormalizeDouble(b.lot,2);
   string cm=StringFormat("APROF %d/10",b.score);
   // IA: comenta o sinal; só pode VETAR se InpAIVeto = true (nunca abre trade)
   string ia=AIAsk(StateJSON(b));
   if(ia!="") g_aiPanel=ia;
   if(AIVetou(ia,b.dir)){ Diario(b,"pulado: IA vetou"); Notifica(StringFormat("ALIEN AUTO %s: IA vetou o sinal %d/10. %s",_Symbol,b.score,ia)); return; }
   bool ok=false; bool limite=(StringFind(b.entNome,"FVG")>=0);
   if(limite)
   {
      double e=NormP(b.entry);
      if(b.dir==1 && e<ask-minDist && sl<e-minDist && tp>e+minDist) ok=g_tr.BuyLimit(lot,e,_Symbol,sl,tp,ORDER_TIME_GTC,0,cm);
      else if(b.dir==-1 && e>bid+minDist && sl>e+minDist && tp<e-minDist) ok=g_tr.SellLimit(lot,e,_Symbol,sl,tp,ORDER_TIME_GTC,0,cm);
      else { Print("ALIEN AUTO: preço já passou da entrada do FVG - pulei"); return; }
   }
   else
   {
      if(b.dir==1 && sl<bid-minDist && tp>ask+minDist) ok=g_tr.Buy(lot,_Symbol,0,sl,tp,cm);
      else if(b.dir==-1 && sl>ask+minDist && tp<bid-minDist) ok=g_tr.Sell(lot,_Symbol,0,sl,tp,cm);
      else return;
   }
   if(ok && TgOk() && InpTgFoto && !MQLInfoInteger(MQL_TESTER)){ string f="APROF_auto.png"; ChartRedraw(0); if(ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)) SendPhoto(f,StringFormat("ALIEN AUTO %s %s nota %d/10",_Symbol,b.dir==1?"COMPRA":"VENDA",b.score)); }
   if(ok){ Diario(b,limite?"ordem limitada":"a mercado"); g_sigRiskUSD=b.riskUSD; g_sigScore=b.score; g_sigDir=b.dir; g_sigTime=TimeCurrent(); MqlDateTime md; TimeToStruct(TimeCurrent(),md); g_sigHour=md.hour; g_sigSess=SessNome(TimeCurrent()); }
   else Diario(b,"recusada pela corretora");
   if(ok) Notifica(StringFormat("ALIEN AUTO %s: %s %s nota %d/10 lote %.2f entrada %s stop %s alvo %s (risco ~$%.2f). %s",
                   _Symbol,limite?"ordem LIMITADA":"a mercado",b.dir==1?"COMPRA":"VENDA",b.score,lot,Fmt(b.entry),Fmt(sl),Fmt(tp),b.riskUSD,Narrativa(b,false,""))+(ia!=""?"\n\nANÁLISE IA (opinião):\n"+ia:""));
   else Print("ALIEN AUTO: ordem recusada ",g_tr.ResultRetcode()," ",g_tr.ResultRetcodeDescription());
}

int OnInit()
{
   g_noDraw = MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE);
   g_tr.SetExpertMagicNumber(InpMagic);
   g_tr.SetDeviationInPoints(30);
   g_tr.SetTypeFillingBySymbol(_Symbol);
   Core_Init();
   g_peak=MathMax(AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO (mude InpAllowRealAccount por sua conta e risco)"; g_extraC=clrRed; }
   MathSrand((uint)(GetTickCount()^(uint)(ChartID()%1000000)));
   g_inst=(double)((ChartID()%1000000)*1000+MathRand()%1000+1);
   g_tgStartUtc=TimeGMT();
   LoadNews(true);
   g_statusSvc=SvcStatus();
   // aviso de (re)início no Telegram - útil com o VIGIA_MT5 (mostra que o MT5 voltou)
   if(!MQLInfoInteger(MQL_TESTER) && TgOk())
      SendMsg(StringFormat("ALIEN reiniciado: robô ligado no %s %s (conta %s %I64d). Saldo $%.2f. Motivo da última parada: %d.",
              _Symbol,StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),
              AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",AccountInfoInteger(ACCOUNT_LOGIN),
              AccountInfoDouble(ACCOUNT_BALANCE),UninitializeReason())+(InpTradeEnabled?"":" MODO ASSISTENTE (não opera).")+(InpTgChat?" Mande /ajuda para ver os comandos.":""));
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); TgMasterSolta(); Core_Deinit(); }
void OnTimer()
{
   if(MQLInfoInteger(MQL_TESTER)) return;          // no testador não existe WebRequest/calendário
   Core_Update(true);
   static ulong lastPoll=0, lastMin=0; ulong ms=GetTickCount64();
   if(ms-lastPoll>=(ulong)MathMax(InpTgPollSeg,2)*1000){ lastPoll=ms; TgPoll(); }
   if(ms-lastMin>=30000){ lastMin=ms; LoadNews(); TgPreAlerta(); TgResumos(); g_statusSvc=SvcStatus(); }
}
void OnTick()
{
   Core_Update(false);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_peak) g_peak=eq;
   if(InpDDPausaPct>0 && !g_ddPause && g_peak>0 && eq<g_peak*(1.0-InpDDPausaPct/100.0)){ g_ddPause=true; Notifica(StringFormat("ALIEN AUTO %s: PAUSADO - equity caiu %.0f%% do pico.",_Symbol,InpDDPausaPct)); }
   Gerencia();
   datetime bt=iTime(_Symbol,InpTFExec,0);
   if(bt!=0 && bt!=g_lastSigBar && g_ready)
   {
      g_lastSigBar=bt;
      TentaOperar();
      g_statusSvc=SvcStatus();
      if(AIOn() && InpAIMinutos>0 && TimeCurrent()-g_aiLast>=InpAIMinutos*60)
      { Plano pb; if(g_pb.score>=g_ps.score) pb=g_pb; else pb=g_ps; string t=AIAsk(StateJSON(pb)); if(t!="") g_aiPanel=t; }
      if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO"; g_extraC=clrRed; }
      else { g_extra="ROBÔ: "+g_status; g_extraC= StringFind(g_status,"aguardando")==0||StringFind(g_status,"em operação")==0 ? clrLime : (StringFind(g_status,"MODO ASSISTENTE")==0 ? clrGold : clrOrangeRed); }
   }
}
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(tr.deal)) return;
   if(HistoryDealGetInteger(tr.deal,DEAL_MAGIC)!=InpMagic) return;
   long en=HistoryDealGetInteger(tr.deal,DEAL_ENTRY);
   if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY)
   {
      double net=HistoryDealGetDouble(tr.deal,DEAL_PROFIT)+HistoryDealGetDouble(tr.deal,DEAL_SWAP)+HistoryDealGetDouble(tr.deal,DEAL_COMMISSION);
      double R = g_sigRiskUSD>0 ? net/g_sigRiskUSD : 0;
      if(g_sigScore>0)
         CsvAppend("ALIEN_aprendizado.csv","abertura;simbolo;lado;nota;faixa;sessao;hora;risco_usd;resultado_usd;R;motivo",
            StringFormat("%s;%s;%s;%d;%s;%s;%d;%.2f;%.2f;%.3f;%s",TimeToString(g_sigTime,TIME_DATE|TIME_MINUTES),_Symbol,g_sigDir==1?"compra":"venda",g_sigScore,Faixa(g_sigScore),
            g_sigSess,g_sigHour,g_sigRiskUSD,net,R,EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(tr.deal,DEAL_REASON))));
      g_histLoad=0;
      Notifica(StringFormat("ALIEN AUTO %s: saiu com %+.2f (%.2fR).",_Symbol,net,R));
   }
}
//+------------------------------------------------------------------+
