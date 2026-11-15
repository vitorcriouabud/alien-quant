//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR.mq5                                              |
//| Indicador de APOIO À DECISÃO para operador manual.               |
//| NÃO envia ordens, NÃO fecha posições, NÃO usa AlgoTrading.       |
//| XAUUSD e índices (.US500Cash, .USTECHCash, .DE40Cash)            |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "1.00"
#property description "Professor: contexto H1, liquidez (PDH/PDL, Ásia, Londres, semana, topos/fundos iguais), varridas, BOS, FVG, volume, nota 0-10, plano com lote pelo risco e disciplina do dia. Só ajuda - quem decide é você. Nunca opera."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

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

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"ALIEN PROFESSOR");
   Core_Init();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   Core_Deinit();
}
void OnTimer(){ Core_Update(true); }
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   Core_Update(false);
   return(rates_total);
}
//+------------------------------------------------------------------+
