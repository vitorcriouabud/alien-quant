//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR.mq5                                              |
//| Indicador de APOIO À DECISÃO para operador manual.               |
//| NÃO envia ordens, NÃO fecha posições, NÃO usa AlgoTrading.       |
//| XAUUSD e índices (.US500Cash, .USTECHCash, .DE40Cash)            |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "12.50"
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
input double InpMinRR             = 1.5;         // R:R mínimo do alvo (abaixo disso o plano é inválido)

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
input bool   InpLinhasChave       = true;        // Linhas dos níveis principais no gráfico
input bool   InpMarcasGrafico     = true;        // Varridas, mudanças e vazios no gráfico
input int    InpMaxMarcas         = 8;           // Quantas marcas recentes (leve)
input bool   InpCenariosGrafico   = true;        // Setas do cenário projetado (não é certeza)
input bool   InpArrumarRotulos    = true;        // Afastar/esconder textos que ficam um em cima do outro no gráfico

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
int      g_engPag=0;  // página do painel (0=professor, 1..3 motor)
bool     g_painelMin=false;

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
   AddNivel("Máxima de ontem",iHigh(_Symbol,PERIOD_D1,1),d1,d0,NV_ABOVE);
   AddNivel("Mínima de ontem",iLow(_Symbol,PERIOD_D1,1),d1,d0,NV_BELOW);
   datetime w0=iTime(_Symbol,PERIOD_W1,0), w1=iTime(_Symbol,PERIOD_W1,1);
   AddNivel("Máxima da semana passada",iHigh(_Symbol,PERIOD_W1,1),w1,w0,NV_ABOVE);
   AddNivel("Mínima da semana passada",iLow(_Symbol,PERIOD_W1,1),w1,w0,NV_BELOW);
   double H,L; datetime t0,te;
   if(SessaoHL(InpAsiaIni,InpAsiaFim,now,H,L,t0,te)){ AddNivel("Máxima da Ásia",H,t0,te,NV_ABOVE); AddNivel("Mínima da Ásia",L,t0,te,NV_BELOW); }
   if(SessaoHL(InpLondresIni,InpLondresFim,now,H,L,t0,te)){ AddNivel("Máxima de Londres",H,t0,te,NV_ABOVE); AddNivel("Mínima de Londres",L,t0,te,NV_BELOW); }
   if(SessaoHL(InpNYIni,InpNYFim,now,H,L,t0,te)){ AddNivel("Máxima de Nova York",H,t0,te,NV_ABOVE); AddNivel("Mínima de Nova York",L,t0,te,NV_BELOW); }
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
         if(ok){ AddNivel("Topos iguais (liquidez)",lv,g_r[jb].time,g_r[ja-L2].time,NV_ABOVE); fe++; break; }
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
         if(ok){ AddNivel("Fundos iguais (liquidez)",lv,g_r[jb].time,g_r[ja-L2].time,NV_BELOW); fe++; break; }
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
bool NivelEhChave(const string nome)
{
   if(StringFind(nome,"ontem")>=0) return true;
   if(StringFind(nome,"Ásia")>=0 || StringFind(nome,"Asia")>=0) return true;
   if(StringFind(nome,"Londres")>=0) return true;
   return false;
}
int MaxMarcas(){ return (InpMaxMarcas>0?InpMaxMarcas:8); }
void DrawNiveis()
{
   DelPrefix("NV"); DelPrefix("SWP");
   if(g_noDraw) return;
   datetime tR=g_r[0].time+PeriodSeconds(InpTFExec)*16;
   int nSw=0;
   // varridas recentes primeiro (marca + rótulo em português)
   int idx[]; ArrayResize(idx,0);
   for(int v=0;v<ArraySize(g_niv);v++)
      if(g_niv[v].estado==ST_VARRIDA && g_niv[v].tSweep>0){ int k=ArraySize(idx); ArrayResize(idx,k+1); idx[k]=v; }
   // ordem: mais recente no fim; desenha as últimas N
   int maxm=MaxMarcas();
   int st=MathMax(0,ArraySize(idx)-maxm);
   for(int iS=ArraySize(idx)-1;iS>=st;iS--)
   {
      int v=idx[iS];
      if(!InpMarcasGrafico) break;
      color c=g_niv[v].lado==NV_ABOVE?clrGold:clrWhite;
      string lab=RotuloVarrida(g_niv[v].nome);
      // pequeno marcador
      string ar=PFX+"SWP"+IntegerToString(nSw);
      if(ObjectFind(0,ar)<0)
      {
         ObjectCreate(0,ar,OBJ_ARROW,0,g_niv[v].tSweep,g_niv[v].sweepExt);
         ObjectSetInteger(0,ar,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,ar,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,ar,OBJPROP_ARROWCODE,g_niv[v].lado==NV_ABOVE?242:241);
      }
      ObjectMove(0,ar,0,g_niv[v].tSweep,g_niv[v].sweepExt);
      ObjectSetInteger(0,ar,OBJPROP_COLOR,c); ObjectSetInteger(0,ar,OBJPROP_WIDTH,1);
      ObjTxtGraf("SWPt"+IntegerToString(nSw),g_niv[v].tSweep,g_niv[v].sweepExt,lab,c,8,g_niv[v].lado==NV_ABOVE?ANCHOR_LOWER:ANCHOR_UPPER);
      nSw++;
   }
   // linhas dos demais níveis (os principais vão em DrawLinhasChave)
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      if(InpLinhasChave && NivelEhChave(g_niv[v].nome) && g_niv[v].estado!=ST_VARRIDA) continue;
      if(g_niv[v].estado==ST_ROMPIDO) continue;
      color c = g_niv[v].lado==NV_ABOVE? clrGold : clrWhite;
      ENUM_LINE_STYLE s=STYLE_SOLID;
      if(g_niv[v].estado==ST_VARRIDA) s=STYLE_DASH;
      ObjLine("NV"+IntegerToString(v),g_niv[v].t0,g_niv[v].preco,tR,c,s,1,g_niv[v].nome+" "+Fmt(g_niv[v].preco),c);
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
   if(InpFVG_H1 && t1!=0 && t1!=g_fvgH1Bar && CopyRates(_Symbol,PERIOD_H1,0,300,r)>50){ ScanFVG(r,PERIOD_H1,200,g_fvgH1); g_fvgH1Bar=t1; DrawFVGHTF(g_fvgH1,"FH1","Vazio de preço",C'0,55,95',C'95,0,75'); }
   datetime t2=iTime(_Symbol,PERIOD_M15,0);
   if(InpFVG_M15 && t2!=0 && t2!=g_fvgM15Bar && CopyRates(_Symbol,PERIOD_M15,0,300,r)>50){ ScanFVG(r,PERIOD_M15,200,g_fvgM15); g_fvgM15Bar=t2; DrawFVGHTF(g_fvgM15,"FM15","Vazio de preço",C'0,80,90',C'110,50,0'); }
}
void DrawFVGHTF(const FVGz &f[],string pf,string lbl,color cUp,color cDn)
{
   if(g_noDraw) return;
   DelPrefix(pf);
   if(!InpMarcasGrafico) return;
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
      if(InpMarcasGrafico) ObjTxtGraf(pf+"t"+IntegerToString(m),f[m].t0,f[m].top,lbl,clrGold,8,ANCHOR_LEFT_LOWER);
      shown++;
   }
}
// preco dentro de algum FVG H1/M15 a favor?
string InHTFFVG(int dir,double px)
{
   for(int m=0;m<ArraySize(g_fvgH1);m++) if(!g_fvgH1[m].filled && g_fvgH1[m].dir==dir && px<=g_fvgH1[m].top && px>=g_fvgH1[m].bot) return "vazio de preço no H1";
   for(int m=0;m<ArraySize(g_fvgM15);m++) if(!g_fvgM15[m].filled && g_fvgM15[m].dir==dir && px<=g_fvgM15[m].top && px>=g_fvgM15[m].bot) return "vazio de preço no M15";
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
   if(g_noDraw) return;
   int nb=ArraySize(g_bos);
   int maxm=MaxMarcas();
   int k0=MathMax(0,nb-maxm);
   for(int k=k0;k<nb;k++)
   {
      if(!InpMarcasGrafico) break;
      color c=g_bos[k].dir==1?clrGold:clrSilver;
      string t=RotuloBos(g_bos[k]);
      ObjLine("BOS"+IntegerToString(k),g_bos[k].tSwing,g_bos[k].preco,g_bos[k].tBreak,c,STYLE_DASH,1,"",c);
      ObjTxtGraf("BOSt"+IntegerToString(k),g_bos[k].tBreak,g_bos[k].preco,t,c,8,g_bos[k].dir==1?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER);
   }
   int open=0, filled=0; datetime tR=g_r[0].time+PeriodSeconds(InpTFExec)*12;
   if(InpMarcasGrafico)
   for(int m=ArraySize(g_fvg)-1;m>=0;m--)
   {
      if(!g_fvg[m].filled && open<maxm){
         color cf=g_fvg[m].dir==1?C'70,60,0':C'50,50,50';
         ObjBox("FVG"+IntegerToString(m),g_fvg[m].t0,g_fvg[m].top,tR,g_fvg[m].bot,cf);
         ObjectSetInteger(0,PFX+"FVG"+IntegerToString(m),OBJPROP_FILL,false);
         ObjectSetInteger(0,PFX+"FVG"+IntegerToString(m),OBJPROP_WIDTH,1);
         ObjectSetInteger(0,PFX+"FVG"+IntegerToString(m),OBJPROP_COLOR,g_fvg[m].dir==1?clrGold:clrSilver);
         ObjTxtGraf("FVGt"+IntegerToString(m),g_fvg[m].t0,g_fvg[m].top,"Vazio de preço",g_fvg[m].dir==1?clrGold:clrSilver,8,ANCHOR_LEFT_LOWER);
         open++;
      }
      else if(g_fvg[m].filled && filled<2){ ObjBox("FVG"+IntegerToString(m),g_fvg[m].t0,g_fvg[m].top,g_fvg[m].tFill,g_fvg[m].bot,C'42,42,42'); filled++; }
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
// ---- horário de Brasília (UTC-3, sem horário de verão) ----
long SrvOffsetSeg()
{
   datetime srv=TimeTradeServer(), gmt=TimeGMT();
   if(srv<=0 || gmt<=0) return 0;
   long off=(long)(srv-gmt);
   return (long)(MathRound(off/1800.0)*1800);
}
datetime SrvParaBR(datetime t){ if(t<=0) return t; return (datetime)(t-SrvOffsetSeg()-3*3600); }
datetime AgoraBR(){ datetime g=TimeGMT(); if(g<=0) g=TimeCurrent(); return (datetime)(g-3*3600); }
string HHMMBR(datetime srv){ return TimeToString(SrvParaBR(srv),TIME_MINUTES); }
// próximas notícias em hora de Brasília
string NewsListaBR(int maxN,string sep)
{
   if(!CalOn()) return InpCalendario?"calendário não roda no testador":"calendário desligado";
   LoadNews(); datetime now=TimeTradeServer(); string s=""; int n=0;
   for(int i=0;i<ArraySize(g_news) && n<maxN;i++)
   {
      if(g_news[i].t<now-1800) continue;
      datetime b=SrvParaBR(g_news[i].t);
      string quando=DayStart(b)==DayStart(AgoraBR())?TimeToString(b,TIME_MINUTES):TimeToString(b,TIME_DATE|TIME_MINUTES);
      s+=(s==""?"":sep)+StringFormat("%s %s %s %s",quando,g_news[i].imp==3?"🔴":"🟡",g_news[i].cur,g_news[i].nome);
      n++;
   }
   if(s=="") s=(g_newsErr!=""?g_newsErr:"nenhuma notícia forte ou média nas próximas 36 horas");
   return s;
}
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
      s+=(s==""?"":",")+StringFormat("{\"data_brasilia\":\"%s\",\"hora_brasilia\":\"%s\",\"min\":%d,\"moeda\":\"%s\",\"impacto\":\"%s\",\"evento\":\"%s\"}",TimeToString(SrvParaBR(g_news[i].t),TIME_DATE),TimeToString(SrvParaBR(g_news[i].t),TIME_MINUTES),(int)((g_news[i].t-now)/60),g_news[i].cur,ImpTxt(g_news[i].imp),nm);
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
double RRMinAlvo(){ return (InpMinRR>0.0?InpMinRR:1.5); }
string PlanoSemSetup(int dir){ return StringFormat("%s: sem setup válido (R<%.1f)",dir==1?"COMPRA":"VENDA",RRMinAlvo()); }
bool PlanoGeoOk(const Plano &p)
{
   if(p.entry<=0 || p.stop<=0 || p.target<=0) return false;
   if(p.dir==1) return (p.stop<p.entry && p.entry<p.target);
   if(p.dir==-1) return (p.target<p.entry && p.entry<p.stop);
   return false;
}
bool PlanoValido(const Plano &p)
{
   if(!PlanoGeoOk(p)) return false;
   double risk=MathAbs(p.entry-p.stop);
   if(risk<=0) return false;
   return (p.rr+1e-12>=RRMinAlvo());
}
void PlanoConsideraAlvo(Plano &p,double risk,double minRR,double lv,string nome)
{
   if(risk<=0 || lv<=0 || p.entry<=0) return;
   if(p.dir==1 && !(lv>p.entry)) return;
   if(p.dir==-1 && !(lv<p.entry)) return;
   double rr=MathAbs(lv-p.entry)/risk;
   if(rr+1e-12<minRR) return;
   if(p.target<=0 || MathAbs(lv-p.entry)+1e-12<MathAbs(p.target-p.entry))
   { p.target=lv; p.alvoNome=nome; p.rr=rr; }
}
void PlanoSomaFVG(Plano &p,double risk,double minRR,const FVGz &f[])
{
   for(int iF=0;iF<ArraySize(f);iF++)
   {
      if(f[iF].filled) continue;
      double lv=(p.dir==1?f[iF].top:f[iF].bot);
      string nm="vazio de preço "+StringSubstr(EnumToString(f[iF].tf),7);
      PlanoConsideraAlvo(p,risk,minRR,lv,nm);
   }
}
Plano MelhorPlano()
{
   bool vb=PlanoValido(g_pb), vs=PlanoValido(g_ps);
   if(vb && !vs) return g_pb;
   if(vs && !vb) return g_ps;
   if(g_pb.score>=g_ps.score) return g_pb;
   return g_ps;
}
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
   if(fi>=0){ p.entry=(g_fvg[fi].top+g_fvg[fi].bot)/2; p.entNome="meio do vazio de preço"; }
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
   // alvo: liquidez/POI mais próximo do lado certo com R >= InpMinRR
   double risk=MathAbs(p.entry-p.stop);
   p.target=0; p.alvoNome=""; p.rr=0;
   double minRR=RRMinAlvo();
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      if(g_niv[v].estado==ST_ROMPIDO) continue;
      PlanoConsideraAlvo(p,risk,minRR,g_niv[v].preco,g_niv[v].nome);
   }
   PlanoSomaFVG(p,risk,minRR,g_fvg);
   PlanoSomaFVG(p,risk,minRR,g_fvgM15);
   PlanoSomaFVG(p,risk,minRR,g_fvgH1);
   if(p.target<=0 || !PlanoGeoOk(p))
   { p.target=0; p.rr=0; p.alvoNome=PlanoSemSetup(dir); }
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
   if(!PlanoValido(p) || p.score<InpScoreAmarelo || g_pare!="" || NoticiaAviso(TimeTradeServer())!="") return;
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
   else if(StringFind(b.entNome,"vazio")>=0 || StringFind(b.entNome,"FVG")>=0) t+=", vazio de preço de "+d+" em "+Fmt(b.entry);
   t+=". ";
   if(b.score>=InpScoreVerde)
   {
      if((StringFind(b.entNome,"vazio")>=0||StringFind(b.entNome,"FVG")>=0) && MathAbs(px-b.entry)>0.3*g_atr) t+="=> Esperar o preço VOLTAR ao vazio de preço ("+Fmt(b.entry)+") e confirmar no M1; stop "+Fmt(b.stop)+", alvo "+b.alvoNome+".";
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
   PainelMontaEDesenha();
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
   EngBotoes();
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
      if(refresh){ g_fvgH1Bar=0; g_fvgM15Bar=0; ArrayInitialize(g_mtfBar,0); }
      g_lastBar=bt; g_ready=true; lastFull=GetTickCount64();
      EngCalc();
      if(!g_noDraw){ DrawNiveis(); DrawEstrutura(); DrawLinhasChave(); EngDrawBlocos(); DrawCenarios(); RotulosArruma(); }
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
   Plano b=MelhorPlano();
   if(!g_noDraw){ DrawPlano(b); if(newBar||refresh){ DrawLinhasChave(); DrawCenarios(); RotulosArruma(); } Painel(); }
   // alerta (uma vez por barra)
   static int prevOk=0; // 0 = abaixo; +1/-1 = já avisou nessa direção
   bool okNow=(PlanoValido(b) && b.score>=InpScoreAlerta && g_pare=="" && NoticiaAviso(now)=="");
   if(newBar && !okNow) prevOk=0;
   if(newBar && okNow && prevOk!=b.dir && g_lastAlert!=bt)
   {
      g_lastAlert=bt; prevOk=b.dir;
      string m=StringFormat("Olha só, %s: setup de %s nota %d/10. Entrada %s, 🛑 stop %s, 🎯 alvo %s (%.1fR), lote %.2f (risco $%.2f). Confere o checklist — a decisão é sua.",
                            _Symbol,b.dir==1?"🟢 COMPRA":"🔴 VENDA",b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.rr,b.lot,b.riskUSD);
      if(!g_noDraw) DrawSinal(b,bt);
      ExportaSinal(b,bt,m);
      if(InpAlerta) Alert(m);
      if(InpPush) SendNotification(m);
   }
   ChartRedraw(0);
}

//====================================================================
// Motor de análise LOCAL (sem internet). Recalcula só em barra nova.
// Checklist / confluência — NÃO é previsão.
//====================================================================
#define ENG_PAGS 4
datetime g_engBar=0;
string   g_engJson="{}";
string   g_engAMD="", g_engKZ="", g_engDR="", g_engPA="", g_engVol="", g_engBB="", g_engDiv="", g_engCorr="", g_engOB="";
double   g_engVWAP=0, g_engPOC=0, g_engPOCOntem=0;
struct EngOB { int dir; double hi, lo; datetime t0; bool brk; };
EngOB    g_obs[];
string EngEsc(string t)
{
   string o=""; int n=StringLen(t);
   for(int i=0;i<n;i++)
   {
      ushort c=StringGetCharacter(t,i);
      if(c=='\\') o+="\\\\";
      else if(c=='"') o+="\\\"";
      else if(c=='\n') o+="\\n";
      else if(c=='\r') o+="\\r";
      else if(c=='\t') o+="\\t";
      else if(c<32) o+="\\u00"+StringFormat("%02X",c);
      else o+=ShortToString(c);
   }
   return o;
}
struct EngF { string nome; int buy; int sell; }; // -1 / 0 / +1
EngF g_ef[];
int g_efBuy=0, g_efSell=0;

void EngAdd(string n,int b,int s)
{
   int k=ArraySize(g_ef); ArrayResize(g_ef,k+1);
   g_ef[k].nome=n; g_ef[k].buy=b; g_ef[k].sell=s;
   g_efBuy+=b; g_efSell+=s;
}
string EngSinal(int v){ return v>0?"+":(v<0?"-":"·"); }

int EngBars(string sym,ENUM_TIMEFRAMES tf,MqlRates &r[],int need)
{
   ArraySetAsSeries(r,true);
   int n=CopyRates(sym,tf,0,need,r);
   return n;
}
double EngSMA(const MqlRates &r[],int n,int per,int sh)
{
   if(per<=0 || sh<0 || sh+per>n) return 0;
   double s=0; for(int i=0;i<per;i++) s+=r[sh+i].close;
   return s/per;
}
double EngStd(const MqlRates &r[],int n,int per,int sh,double mean)
{
   if(per<=1 || sh<0 || sh+per>n) return 0;
   double s=0; for(int i=0;i<per;i++){ double d=r[sh+i].close-mean; s+=d*d; }
   return MathSqrt(s/(per-1));
}
double EngEMAAt(const MqlRates &r[],int n,int per,int want)
{
   if(n<per+2 || per<=0 || want<0 || want>=n) return 0;
   double k=2.0/(per+1.0), e=r[n-1].close;
   for(int i=n-2;i>=0;i--){ e=r[i].close*k+e*(1.0-k); if(i==want) return e; }
   return e;
}
bool EngBB(const MqlRates &r[],int n,double &mid,double &up,double &dn,double &width,bool &squeeze,int &pos)
{
   mid=0; up=0; dn=0; width=0; squeeze=false; pos=0;
   if(n<40) return false;
   mid=EngSMA(r,n,20,0); if(mid<=0) return false;
   double sd=EngStd(r,n,20,0,mid);
   up=mid+2.0*sd; dn=mid-2.0*sd;
   width=(up-dn)/mid;
   double wsum=0; int wc=0;
   for(int s=1;s<=20 && s+20<n;s++)
   {
      double m=EngSMA(r,n,20,s); if(m<=0) continue;
      double sd2=EngStd(r,n,20,s,m); wsum+=(2.0*2.0*sd2)/m; wc++;
   }
   double wavg=(wc>0?wsum/wc:width);
   squeeze=(wavg>0 && width<0.75*wavg);
   double px=r[0].close;
   if(px>up) pos=1; else if(px<dn) pos=-1; else pos=0;
   return true;
}
void EngRSI(const MqlRates &r[],int n,int per,double &rsi[])
{
   ArrayResize(rsi,0);
   if(n<per+5) return;
   ArrayResize(rsi,n); ArrayInitialize(rsi,0);
   double ag=0, al=0;
   for(int i=n-2;i>=n-1-per && i>=0;i--)
   {
      double d=r[i].close-r[i+1].close;
      if(d>0) ag+=d; else al-=d;
   }
   ag/=per; al/=per;
   for(int i=n-2-per;i>=0;i--)
   {
      double d=r[i].close-r[i+1].close;
      double g=(d>0?d:0), l=(d<0?-d:0);
      ag=(ag*(per-1)+g)/per; al=(al*(per-1)+l)/per;
      double rs=(al>0?ag/al: (ag>0?100:0));
      rsi[i]=(al<=0 && ag<=0)?50:(al<=0?100:100.0-100.0/(1.0+rs));
   }
}
int EngDiverg(const MqlRates &r[],const double &ind[],int n)
{
   // +1 bullish div (price LL, ind HL), -1 bearish (price HH, ind LH)
   if(n<30 || ArraySize(ind)<n) return 0;
   int p1=-1,p2=-1, v1=-1,v2=-1;
   for(int j=3;j<n-3 && (p1<0||v1<0||p2<0||v2<0);j++)
   {
      if(p1<0 && IsSH(r,j,2)) p1=j;
      else if(p1>0 && p2<0 && IsSH(r,j,2)) p2=j;
      if(v1<0 && IsSL(r,j,2)) v1=j;
      else if(v1>0 && v2<0 && IsSL(r,j,2)) v2=j;
   }
   int out=0;
   if(p1>0 && p2>p1 && p1<ArraySize(ind) && p2<ArraySize(ind))
      if(r[p1].high>r[p2].high && ind[p1]<ind[p2] && ind[p1]>0 && ind[p2]>0) out=-1;
   if(v1>0 && v2>v1 && v1<ArraySize(ind) && v2<ArraySize(ind))
      if(r[v1].low<r[v2].low && ind[v1]>ind[v2] && ind[v1]>0 && ind[v2]>0) out=(out==-1?0:1);
   return out;
}
string EngSimboloExiste(string cands)
{
   string p[]; int n=StringSplit(cands,',',p);
   for(int i=0;i<n;i++)
   {
      string s=p[i]; StringTrimLeft(s); StringTrimRight(s);
      bool cu=false; if(s!="" && SymbolExist(s,cu)) return s;
   }
   return "";
}
double EngCorr(string sym,int bars)
{
   if(sym=="" || bars<15) return 0;
   MqlRates a[], b[];
   int na=CopyRates(_Symbol,PERIOD_H1,0,bars,a), nb=CopyRates(sym,PERIOD_H1,0,bars,b);
   if(na<15 || nb<15) return 0;
   ArraySetAsSeries(a,true); ArraySetAsSeries(b,true);
   int n=MathMin(na,nb)-1; if(n<14) return 0;
   double sa=0,sb=0,sab=0,sa2=0,sb2=0;
   int c=0;
   for(int i=0;i<n;i++)
   {
      if(a[i+1].close<=0 || b[i+1].close<=0) continue;
      double da=a[i].close-a[i+1].close, db=b[i].close-b[i+1].close;
      sa+=da; sb+=db; sab+=da*db; sa2+=da*da; sb2+=db*db; c++;
   }
   if(c<10) return 0;
   double cova=sab-sa*sb/c, va=sa2-sa*sa/c, vb=sb2-sb*sb/c;
   if(va<=0 || vb<=0) return 0;
   return cova/MathSqrt(va*vb);
}
void EngVP(const MqlRates &r[],int n,datetime t0,datetime t1,double &poc,double &vah,double &val)
{
   poc=0; vah=0; val=0;
   if(n<5 || t1<=t0) return;
   double hi=0, lo=0; bool first=true; double tv=0;
   for(int i=0;i<n;i++)
   {
      if(r[i].time<t0 || r[i].time>=t1) continue;
      if(first){ hi=r[i].high; lo=r[i].low; first=false; }
      else { if(r[i].high>hi) hi=r[i].high; if(r[i].low<lo) lo=r[i].low; }
      tv+=(double)r[i].tick_volume;
   }
   if(first || hi<=lo || tv<=0) return;
   int B=24; double vol[]; ArrayResize(vol,B); ArrayInitialize(vol,0);
   double rng=hi-lo; if(rng<=0) return;
   for(int i=0;i<n;i++)
   {
      if(r[i].time<t0 || r[i].time>=t1) continue;
      double typ=0.5*(r[i].high+r[i].low);
      int b=(int)MathFloor((typ-lo)/rng*(B-1));
      if(b<0) b=0; if(b>=B) b=B-1;
      vol[b]+=(double)r[i].tick_volume;
   }
   int im=0; for(int b=1;b<B;b++) if(vol[b]>vol[im]) im=b;
   poc=lo+(im+0.5)*rng/B;
   double need=0.70*tv, acc=vol[im]; int L=im, R=im;
   while(acc<need)
   {
      double left=(L>0?vol[L-1]:-1), right=(R<B-1?vol[R+1]:-1);
      if(left<0 && right<0) break;
      if(right>=left){ R++; if(R<B) acc+=vol[R]; else break; }
      else { L--; if(L>=0) acc+=vol[L]; else break; }
      if(L==0 && R==B-1) break;
   }
   val=lo+L*rng/B; vah=lo+(R+1)*rng/B;
}
string EngPA(const MqlRates &r[],int n,double poi,double atr)
{
   if(n<3 || atr<=0) return "n/d";
   double body=MathAbs(r[1].close-r[1].open), up=r[1].high-MathMax(r[1].close,r[1].open), dn=MathMin(r[1].close,r[1].open)-r[1].low;
   string s="";
   if(body>0 && dn>=2.0*body && MathAbs(r[1].low-poi)<=0.3*atr) s="pin de alta no POI";
   else if(body>0 && up>=2.0*body && MathAbs(r[1].high-poi)<=0.3*atr) s="pin de baixa no POI";
   if(r[1].close>r[1].open && r[2].close<r[2].open && r[1].close>=r[2].open && r[1].open<=r[2].close) s+=(s==""?"":", ")+"engolfo de alta";
   if(r[1].close<r[1].open && r[2].close>r[2].open && r[1].close<=r[2].open && r[1].open>=r[2].close) s+=(s==""?"":", ")+"engolfo de baixa";
   if(r[1].high<=r[2].high && r[1].low>=r[2].low) s+=(s==""?"":", ")+"inside bar";
   return s==""?"nenhum no último fechamento":s;
}
// horário de Nova York com horário de verão dos EUA (2º domingo de março 2h até 1º domingo de novembro 2h)
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

void EngCalc()
{
   ArrayResize(g_ef,0); g_efBuy=0; g_efSell=0;
   g_engAMD=g_engKZ=g_engDR=g_engPA=g_engVol=g_engBB=g_engDiv=g_engCorr=g_engOB="";
   g_engVWAP=0; g_engPOC=0; g_engPOCOntem=0; ArrayResize(g_obs,0);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   if(bid<=0){ g_engJson="{}"; return; }
   datetime gmt=TimeGMT(); if(gmt<=0) gmt=TimeCurrent();

   // --- BB M15/H1 ---
   MqlRates r15[], rH1[], rM5[];
   int n15=EngBars(_Symbol,PERIOD_M15,r15,80);
   int nH1=EngBars(_Symbol,PERIOD_H1,rH1,80);
   int nM5=EngBars(_Symbol,PERIOD_M5,rM5,120);
   /* D1 reservado p/ VP de sessão via g_r */
   string bbj="{";
   for(int t=0;t<2;t++)
   {
      double mid,up,dn,w; bool sq; int pos;
      string tf=(t==0?"M15":"H1");
      bool okbb=(t==0?EngBB(r15,n15,mid,up,dn,w,sq,pos):EngBB(rH1,nH1,mid,up,dn,w,sq,pos));
      if(!okbb) continue;
      bbj+=(StringLen(bbj)>1?",":"")+"\""+tf+"\":"+StringFormat("{\"meio\":%s,\"sup\":%s,\"inf\":%s,\"largura\":%.5f,\"squeeze\":%s,\"pos\":%d}",
         Fmt(mid),Fmt(up),Fmt(dn),w,sq?"true":"false",pos);
      if(t==0)
      {
         g_engBB=StringFormat("BB M15: %s  largura %.4f%s", pos==1?"acima da banda":(pos==-1?"abaixo da banda":"dentro"), w, sq?"  SQUEEZE":"");
         if(sq && pos==1) EngAdd("BB squeeze rompeu para cima",1,0);
         else if(sq && pos==-1) EngAdd("BB squeeze rompeu para baixo",0,1);
         else if(pos==1) EngAdd("preço acima da BB M15",0,1);
         else if(pos==-1) EngAdd("preço abaixo da BB M15",1,0);
      }
   }
   g_engBB=(g_engBB==""?"BB: sem dados":g_engBB);
   bbj+="}";

   // --- AMD ---
   double aH=0,aL=0,lH=0,lL=0; datetime t0,te;
   datetime now=TimeTradeServer(); if(now==0) now=TimeCurrent();
   bool hasA=SessaoHL(InpAsiaIni,InpAsiaFim,now,aH,aL,t0,te);
   bool hasL=SessaoHL(InpLondresIni,InpLondresFim,now,lH,lL,t0,te);
   string st; SessaoNota(now,st);
   string amd="indefinido";
   if(hasA && aH>aL)
   {
      amd="Ásia acumulação ("+Fmt(aL)+"-"+Fmt(aH)+")";
      if(hasL)
      {
         if(lH>aH && bid<aH) { amd="Londres manipulação (varreu Ásia máx. "+Fmt(aH)+")"; EngAdd("varredura Ásia máx. (manip. Londres)",0,1); }
         else if(lL<aL && bid>aL){ amd="Londres manipulação (varreu Ásia mín. "+Fmt(aL)+")"; EngAdd("varredura Ásia mín. (manip. Londres)",1,0); }
      }
      if(StringFind(st,"Nova York")>=0 && hasL)
      {
         if(lH>aH && bid<aH-0.1*(aH-aL)) { amd="NY distribuição após varredura da Ásia máx."; EngAdd("NY distribuição após sweep de alta",0,1); }
         else if(lL<aL && bid>aL+0.1*(aH-aL)){ amd="NY distribuição após varredura da Ásia mín."; EngAdd("NY distribuição após sweep de baixa",1,0); }
      }
   }
   g_engAMD=amd;

   // --- dealing range / premium-discount / OTE ---
   double sh=0,sl=0;
   if(ArraySize(g_r)>=30)
   {
      for(int j=3;j<ArraySize(g_r)-3;j++){ if(sh<=0 && IsSH(g_r,j,2)) sh=g_r[j].high; if(sl<=0 && IsSL(g_r,j,2)) sl=g_r[j].low; if(sh>0 && sl>0) break; }
   }
   string dr="n/d";
   if(sh>sl && sl>0)
   {
      double midDR=sl+0.5*(sh-sl), oteL=sl+0.62*(sh-sl), oteH=sl+0.79*(sh-sl);
      bool disc=bid<midDR, prem=bid>midDR, oteC=(bid>=sl+0.21*(sh-sl) && bid<=sl+0.38*(sh-sl)), oteV=(bid>=oteL && bid<=oteH);
      dr=StringFormat("range %s-%s  meio %s  %s",Fmt(sl),Fmt(sh),Fmt(midDR),disc?"DESCONTO":(prem?"PRÊMIO":"equilíbrio"));
      if(oteC) dr+="  OTE compra 62-79% do trecho de baixa";
      if(oteV) dr+="  OTE venda 62-79% do trecho de alta";
      if(disc) EngAdd("preço em desconto (abaixo de 50%)",1,0);
      if(prem) EngAdd("preço em prêmio (acima de 50%)",0,1);
      if(oteC) EngAdd("OTE zona de compra",1,0);
      if(oteV) EngAdd("OTE zona de venda",0,1);
   }
   g_engDR=dr;

   // --- iguais (liquidez) ---
   int eqH=0,eqL=0; double atr=g_atr>0?g_atr:(ArraySize(g_r)>16?ATRof(g_r,14,1):0);
   if(ArraySize(g_r)>20 && atr>0)
   {
      double th[8], tl[8]; int nh=0,nl=0;
      for(int j2=3;j2<ArraySize(g_r)-3 && (nh<8||nl<8);j2++)
      {
         if(nh<8 && IsSH(g_r,j2,2)) th[nh++]=g_r[j2].high;
         if(nl<8 && IsSL(g_r,j2,2)) tl[nl++]=g_r[j2].low;
      }
      for(int a=0;a<nh;a++) for(int b=a+1;b<nh;b++) if(MathAbs(th[a]-th[b])<=0.10*atr) eqH++;
      for(int a2=0;a2<nl;a2++) for(int b2=a2+1;b2<nl;b2++) if(MathAbs(tl[a2]-tl[b2])<=0.10*atr) eqL++;
      if(eqH>0) EngAdd("liquidez acima (topos iguais)",0,1);
      if(eqL>0) EngAdd("liquidez abaixo (fundos iguais)",1,0);
   }

   // FVG abertos
   int fvgUp=0,fvgDn=0;
   for(int iF=0;iF<ArraySize(g_fvg);iF++) if(!g_fvg[iF].filled){ if(g_fvg[iF].dir==1) fvgUp++; else fvgDn++; }
   if(fvgUp>0) EngAdd("vazio de preço de alta ainda aberto",1,0);
   if(fvgDn>0) EngAdd("vazio de preço de baixa ainda aberto",0,1);

   // BOS/CHoCH por TF (reusa TrendTFs + último BOS do gráfico)
   string bosJ="{";
   int nb=ArraySize(g_bos);
   if(nb>0)
   {
      string tBos=g_bos[nb-1].choch?"CHoCH":"BOS";
      bosJ+="\"exec\":\""+tBos+" "+(g_bos[nb-1].dir==1?"alta":"baixa")+"\"";
      if(g_bos[nb-1].dir==1) EngAdd(tBos+" de alta no TF de execução",1,0);
      else EngAdd(tBos+" de baixa no TF de execução",0,1);
   }
   for(int iT=0;iT<6;iT++)
   {
      int tr=g_mtf[iT];
      bosJ+=(StringLen(bosJ)>1?",":"")+"\""+g_mtfNm[iT]+"\":"+IntegerToString(tr);
   }
   bosJ+="}";
   if(g_mtf[2]==1) EngAdd("viés H1 de alta",1,0);
   if(g_mtf[2]==-1) EngAdd("viés H1 de baixa",0,1);

   g_engOB="nenhum";
   if(nb>0 && ArraySize(g_r)>10)
   {
      datetime tB=g_bos[nb-1].tBreak, tS=g_bos[nb-1].tSwing;
      int dir=g_bos[nb-1].dir;
      int ib=-1;
      for(int iO=1;iO<ArraySize(g_r)-1;iO++)
      {
         if(g_r[iO].time>tB) continue;
         if(g_r[iO].time<tS) break;
         bool bear=g_r[iO].close<g_r[iO].open;
         if(dir==1 && bear){ ib=iO; break; }
         if(dir==-1 && !bear){ ib=iO; break; }
      }
      if(ib>=0)
      {
         double obH=g_r[ib].high, obL=g_r[ib].low;
         bool mit=false, brk=false;
         for(int iM=0;iM<ib;iM++)
         {
            if(g_r[iM].low<=obH && g_r[iM].high>=obL) mit=true;
            if(dir==1 && g_r[iM].close<obL) brk=true;
            if(dir==-1 && g_r[iM].close>obH) brk=true;
         }
         string kind=brk?"bloco quebrado":(mit?"bloco de ordens já testado":"bloco de ordens ainda aberto");
         g_engOB=kind+" "+Fmt(obL)+"-"+Fmt(obH);
         int ko=ArraySize(g_obs); ArrayResize(g_obs,ko+1);
         g_obs[ko].dir=dir; g_obs[ko].hi=obH; g_obs[ko].lo=obL; g_obs[ko].t0=g_r[ib].time; g_obs[ko].brk=brk;
         if(!mit && !brk && dir==1) EngAdd("bloco de ordens de alta ainda aberto",1,0);
         if(!mit && !brk && dir==-1) EngAdd("bloco de ordens de baixa ainda aberto",0,1);
         if(mit && !brk && dir==1) EngAdd("teste do bloco de ordens de alta",1,0);
         if(mit && !brk && dir==-1) EngAdd("teste do bloco de ordens de baixa",0,1);
         if(brk && dir==1) EngAdd("bloco de alta quebrado (virou resistência)",0,1);
         if(brk && dir==-1) EngAdd("bloco de baixa quebrado (virou suporte)",1,0);
      }
   }


   // Inducement: último swing menor contra o H1
   if(ArraySize(g_r)>10 && g_mtf[2]!=0)
   {
      if(g_mtf[2]==1 && sl>0 && bid>sl && (sh<=0 || sl>sh-0.5*(sh>sl?sh-sl:atr))) EngAdd("inducement / fundo menor acima da liquidez maior",1,0);
      if(g_mtf[2]==-1 && sh>0 && bid<sh) EngAdd("inducement / topo menor abaixo da liquidez maior",0,1);
   }

   // price action at mid/POI
   double poi=(sh>sl && sl>0? (bid<sl+0.5*(sh-sl)?sl:sh) : bid);
   g_engPA=EngPA(g_r,ArraySize(g_r),poi,atr>0?atr:1);
   if(StringFind(g_engPA,"pin de alta")>=0 || StringFind(g_engPA,"engolfo de alta")>=0) EngAdd("price action de alta no POI",1,0);
   if(StringFind(g_engPA,"pin de baixa")>=0 || StringFind(g_engPA,"engolfo de baixa")>=0) EngAdd("price action de baixa no POI",0,1);

   // killzones
   g_engKZ=EngKillzone(gmt);
   if(StringFind(g_engKZ,"Killzone")>=0 && StringFind(g_engKZ,"fora")<0) EngAdd("dentro de killzone ICT",0,0); // contexto, sem lado

   // volume + VWAP + VP
   string volj="{\"ok\":false}";
   if(ArraySize(g_r)>=22)
   {
      double sum=0; for(int k=1;k<=20 && k<ArraySize(g_r);k++) sum+=(double)g_r[k].tick_volume;
      double avg=sum/20.0, v=(double)g_r[0].tick_volume, raz=(avg>0?v/avg:0);
      bool spike=(raz>=2.0);
      // VWAP da sessão do servidor (desde o início do dia)
      datetime day0=DayStart(now);
      double pv=0, vv=0, acc2=0; int vc=0;
      for(int iV=0;iV<ArraySize(g_r);iV++)
      {
         if(g_r[iV].time<day0) break;
         double typ=(g_r[iV].high+g_r[iV].low+g_r[iV].close)/3.0;
         double vol=(double)g_r[iV].tick_volume; if(vol<=0) vol=1;
         pv+=typ*vol; vv+=vol; acc2+=typ*typ*vol; vc++;
      }
      double vwap=(vv>0?pv/vv:0), band=0;
      if(vv>0 && vc>2)
      {
         double var=acc2/vv-(vwap*vwap); if(var>0) band=MathSqrt(var);
      }
      double poc=0,vah=0,val=0, pPoc=0,pVah=0,pVal=0;
      datetime d1=day0-86400;
      EngVP(g_r,ArraySize(g_r),day0,now+PeriodSeconds(InpTFExec),poc,vah,val);
      EngVP(g_r,ArraySize(g_r),d1,day0,pPoc,pVah,pVal);
      g_engVWAP=vwap; g_engPOC=poc; g_engPOCOntem=pPoc;
      g_engVol=StringFormat("vol %s média  razão %.2f%s  preço médio %s", spike?"SPIKE vs":"vs", raz, spike?"":"", vwap>0?Fmt(vwap):"-");
      if(pPoc>0) g_engVol+=StringFormat("  ontem POC %s VAH %s VAL %s",Fmt(pPoc),Fmt(pVah),Fmt(pVal));
      if(spike) EngAdd("spike de volume",0,0);
      if(vwap>0 && bid>vwap) EngAdd("preço acima do VWAP da sessão",1,0);
      if(vwap>0 && bid<vwap) EngAdd("preço abaixo do VWAP da sessão",0,1);
      volj=StringFormat("{\"atual\":%.0f,\"media20\":%.0f,\"razao\":%.2f,\"spike\":%s,\"vwap\":%s,\"vwap_banda\":%s,\"poc_sessao\":%s,\"vah_sessao\":%s,\"val_sessao\":%s,\"poc_ontem\":%s,\"vah_ontem\":%s,\"val_ontem\":%s}",
         v,avg,raz,spike?"true":"false",vwap>0?Fmt(vwap):"null",band>0?Fmt(band):"null",
         poc>0?Fmt(poc):"null",vah>0?Fmt(vah):"null",val>0?Fmt(val):"null",
         pPoc>0?Fmt(pPoc):"null",pVah>0?Fmt(pVah):"null",pVal>0?Fmt(pVal):"null");
   }
   else g_engVol="volume: sem dados";

   // RSI / MACD div M5 M15
   string divj="{";
   g_engDiv="sem divergência clara";
   if(nM5>=60)
   {
      double rsi[]; EngRSI(rM5,nM5,14,rsi);
      int d=EngDiverg(rM5,rsi,nM5);
      double mac[]; ArrayResize(mac,nM5); ArrayInitialize(mac,0);
      for(int i5=0;i5<nM5;i5++){ double e12a=EngEMAAt(rM5,nM5,12,i5), e26a=EngEMAAt(rM5,nM5,26,i5); if(e12a>0 && e26a>0) mac[i5]=e12a-e26a; }
      int dm=EngDiverg(rM5,mac,nM5);
      divj+="\"M5\":{\"rsi\":"+IntegerToString(d)+",\"macd\":"+IntegerToString(dm)+"}";
      if(d==1||dm==1){ g_engDiv="divergência de ALTA no M5"; EngAdd("divergência de alta M5",1,0); }
      if(d==-1||dm==-1){ g_engDiv="divergência de BAIXA no M5"; EngAdd("divergência de baixa M5",0,1); }
   }
   if(n15>=60)
   {
      double rsi2[]; EngRSI(r15,n15,14,rsi2);
      int d2=EngDiverg(r15,rsi2,n15);
      double mac2[]; ArrayResize(mac2,n15); ArrayInitialize(mac2,0);
      for(int i15=0;i15<n15;i15++){ double e12b=EngEMAAt(r15,n15,12,i15), e26b=EngEMAAt(r15,n15,26,i15); if(e12b>0 && e26b>0) mac2[i15]=e12b-e26b; }
      int dm2=EngDiverg(r15,mac2,n15);
      divj+=(StringLen(divj)>1?",":"")+"\"M15\":{\"rsi\":"+IntegerToString(d2)+",\"macd\":"+IntegerToString(dm2)+"}";
      if(d2==1||dm2==1){ g_engDiv+=(g_engDiv=="sem divergência clara"?"":" | ")+"divergência de ALTA no M15"; EngAdd("divergência de alta M15",1,0); }
      if(d2==-1||dm2==-1){ g_engDiv+=(StringFind(g_engDiv,"sem")>=0?"":" | ")+"divergência de BAIXA no M15"; EngAdd("divergência de baixa M15",0,1); }
   }
   divj+="}";

   // correlação (silêncio se o símbolo não existir)
   string dx=EngSimboloExiste("DXY,USDX,USDIDX,DX"), us10=EngSimboloExiste("US10Y,US10YT,UST10Y"), xag=EngSimboloExiste("XAGUSD,XAGUSD.");
   string corr="(sem símbolo de correlação neste terminal)";
   string cj="{";
   if(dx!=""){ double cd=EngCorr(dx,50); cj+="\"dxy\":{\"simbolo\":\""+dx+"\",\"corr\":"+DoubleToString(cd,2)+"}"; corr="DXY "+dx+" corr "+DoubleToString(cd,2); if(cd<-0.3) EngAdd("DXY correlacionado inversamente (favorece ouro na queda do dólar)",1,0); if(cd>0.3) EngAdd("DXY correlacionado (alta do dólar pressiona)",0,1); }
   if(us10!=""){ double c10=EngCorr(us10,50); cj+=(StringLen(cj)>1?",":"")+"\"us10y\":{\"simbolo\":\""+us10+"\",\"corr\":"+DoubleToString(c10,2)+"}"; corr+=(StringGetCharacter(corr,0)=='('?"":" | ")+"US10Y "+DoubleToString(c10,2); }
   if(xag!=""){ double cx=EngCorr(xag,50); cj+=(StringLen(cj)>1?",":"")+"\"xag\":{\"simbolo\":\""+xag+"\",\"corr\":"+DoubleToString(cx,2)+"}"; corr+=(StringGetCharacter(corr,0)=='('?"":" | ")+"XAG "+DoubleToString(cx,2); if(cx>0.4) EngAdd("prata anda junto (confirma o metal)",0,0); }
   cj+="}";
   g_engCorr=corr;

   // JSON cache
   string fat="[";
   for(int iFator=0;iFator<ArraySize(g_ef);iFator++)
      fat+=(iFator?",":"")+StringFormat("{\"nome\":\"%s\",\"compra\":\"%s\",\"venda\":\"%s\"}",EngEsc(g_ef[iFator].nome),EngSinal(g_ef[iFator].buy),EngSinal(g_ef[iFator].sell));
   fat+="]";
   g_engJson=StringFormat("{\"aviso\":\"checklist, nao previsao\",\"compra\":%d,\"venda\":%d,\"amd\":\"%s\",\"killzone\":\"%s\",\"dealing\":\"%s\",\"poi_ob\":\"%s\",\"price_action\":\"%s\",\"bollinger\":%s,\"volume\":%s,\"divergencias\":%s,\"correlacao\":%s,\"fvg_abertos\":{\"alta\":%d,\"baixa\":%d},\"bos\":%s,\"topos_iguais\":%d,\"fundos_iguais\":%d,\"fatores\":%s}",
      g_efBuy,g_efSell,EngEsc(g_engAMD),EngEsc(g_engKZ),EngEsc(g_engDR),EngEsc(g_engOB),EngEsc(g_engPA),bbj,volj,divj,cj,fvgUp,fvgDn,bosJ,eqH,eqL,fat);
   g_engBar=iTime(_Symbol,InpTFExec,0);
}

string EngineJSON(){ return g_engJson==""?"{}":g_engJson; }

void EngBotao(string n,int x,int largura,string txt)
{
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,MathMax(2,InpPainelY-22));
      ObjectSetInteger(0,n,OBJPROP_YSIZE,20);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(0,n,OBJPROP_COLOR,clrGold);
      ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,clrGold);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,largura);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
}
void EngBotoes()
{
   if(g_noDraw) return;
   EngBotao(PFX+"PAG",InpPainelX,90,"PÁG "+IntegerToString(g_engPag+1)+"/"+IntegerToString(ENG_PAGS));
   EngBotao(PFX+"MIN",InpPainelX+94,88,g_painelMin?"ABRIR":"RECOLHER");
}
void EngDrawBlocos()
{
   DelPrefix("OBL");
   if(g_noDraw || !InpMarcasGrafico) return;
   int n=ArraySize(g_obs); if(n<=0) return;
   int maxm=MaxMarcas(); int st=MathMax(0,n-maxm);
   datetime tR=TimeCurrent()+PeriodSeconds(InpTFExec)*10;
   for(int iB=st;iB<n;iB++)
   {
      color c=clrGold;
      ObjBox("OBL"+IntegerToString(iB),g_obs[iB].t0,g_obs[iB].hi,tR,g_obs[iB].lo,C'50,45,0');
      ObjectSetInteger(0,PFX+"OBL"+IntegerToString(iB),OBJPROP_FILL,false);
      ObjectSetInteger(0,PFX+"OBL"+IntegerToString(iB),OBJPROP_WIDTH,1);
      ObjectSetInteger(0,PFX+"OBL"+IntegerToString(iB),OBJPROP_COLOR,c);
      ObjTxtGraf("OBLt"+IntegerToString(iB),g_obs[iB].t0,g_obs[iB].hi,"Bloco de ordens",c,8,ANCHOR_LEFT_LOWER);
   }
}
void EngPainelExtra()
{
   PL("────────  (checklist, NÃO previsão)  ────────",clrGold,InpFonte-1);
   if(g_engPag==1)
   {
      PL("Confluência  compra "+IntegerToString(g_efBuy)+"   venda "+IntegerToString(g_efSell)+"  (lista, não previsão)",clrGold,0,true);
      int n=ArraySize(g_ef); if(n<=0) PL("  (ainda sem fatores — aguarde barra nova)",clrSilver);
      for(int i=0;i<n && i<16;i++)
         PL(StringFormat("  C:%s  V:%s   %s",EngSinal(g_ef[i].buy),EngSinal(g_ef[i].sell),g_ef[i].nome), clrWhite, InpFonte-1);
   }
   else if(g_engPag==2)
   {
      PL("Fases, janelas e pontos de interesse",clrGold,0,true);
      PL("  AMD: "+g_engAMD,clrWhite);
      PL("  "+g_engKZ,clrWhite);
      PL("  Range: "+g_engDR,clrWhite);
      PL("  Ação de preço: "+g_engPA,clrWhite);
      PL("  Ponto de interesse: "+g_engOB,clrWhite);
      int nb=ArraySize(g_bos);
      if(nb>0) PL("  "+RotuloBos(g_bos[nb-1])+" em "+Fmt(g_bos[nb-1].preco),clrWhite);
   }
   else if(g_engPag==3)
   {
      PL("Volume, bandas, divergência e correlação",clrGold,0,true);
      PL("  "+g_engBB,clrWhite);
      PL("  "+g_engVol,clrWhite);
      PL("  "+g_engDiv,clrWhite);
      PL("  "+g_engCorr,clrWhite);
   }
   if(g_engBar>0) PL("  calculado na barra "+TimeToString(g_engBar,TIME_DATE|TIME_MINUTES)+" (só em barra nova)",clrSilver,InpFonte-1);
}
bool EngChartEvent(const int id,const string sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return false;
   if(sparam==PFX+"MIN")
   {
      g_painelMin=!g_painelMin;
      ObjectSetInteger(0,PFX+"MIN",OBJPROP_STATE,false);
      EngBotoes();
      if(g_ready) Painel();
      return true;
   }
   if(sparam!=PFX+"PAG") return false;
   g_engPag=(g_engPag+1)%ENG_PAGS;
   ObjectSetInteger(0,PFX+"PAG",OBJPROP_STATE,false);
   EngBotoes();
   if(g_ready) Painel();
   return true;
}

//====================================================================
// Painel compacto (amarelo/preto/branco) + linhas e cenários no gráfico
//====================================================================
#define PAINEL_W 456
// v12.6: blocos do painel e modo limpo (o Vitor liga/desliga pelo Telegram)
bool g_modoLimpo=false;
bool g_pnIA=true, g_pnNiv=true, g_pnConf=true, g_pnConta=true, g_pnOculto=false;
// g_painelMin vive em core.mqh
datetime g_aiPanelT=0;
string   g_aiPanelPrev="";

void AIPanelSet(string t)
{
   if(t!=g_aiPanel)
   {
      g_aiPanel=t;
      datetime n=TimeTradeServer(); g_aiPanelT=(n>0?n:TimeCurrent());
   }
   if(t!="" && g_aiPanelT==0){ datetime n=TimeTradeServer(); g_aiPanelT=(n>0?n:TimeCurrent()); }
}

bool GraficoComEmoji(){ return !MQLInfoInteger(MQL_TESTER); }
string GraficoFonte(){ return GraficoComEmoji()?"Segoe UI Emoji":"Arial"; }
string IcoLiq(){ return GraficoComEmoji()?"💧":"●"; }
string IcoAlvo(){ return GraficoComEmoji()?"🎯":"▶"; }
string IcoStop(){ return GraficoComEmoji()?"🛑":"×"; }

string PainelVeredito(string t)
{
   string u=t; StringToUpper(u);
   int k=-1,f=0;
   while(true){ int q=StringFind(u,"VEREDITO",f); if(q<0) break; k=q; f=q+1; }
   if(k<0) return "";
   string r=StringSubstr(u,k,48);
   if(StringFind(r,"COMPRA")>=0) return "COMPRA";
   if(StringFind(r,"VENDA")>=0) return "VENDA";
   if(StringFind(r,"ESPERA")>=0) return "ESPERAR";
   return "";
}
color CorVeredito(string v)
{
   if(v=="COMPRA") return clrLime;
   if(v=="VENDA") return clrRed;
   if(v=="ESPERAR") return clrGold;
   return clrSilver;
}
string TextoVeredito(string v)
{
   if(v=="COMPRA") return "COMPRA";
   if(v=="VENDA") return "VENDA";
   if(v=="ESPERAR") return "ESPERAR";
   return "";
}
string NewsContagem()
{
   datetime now=TimeTradeServer(); if(now==0) now=TimeCurrent();
   datetime best=0; string nome="";
   for(int iN=0;iN<ArraySize(g_news);iN++)
   {
      if(g_news[iN].t<=now) continue;
      if(best==0 || g_news[iN].t<best){ best=g_news[iN].t; nome=g_news[iN].cur; if(StringLen(g_news[iN].nome)>0) nome+=" "+g_news[iN].nome; }
   }
   if(best==0) return "sem notícia à vista";
   int mn=(int)((best-now)/60); if(mn<0) mn=0;
   if(StringLen(nome)>28) nome=StringSubstr(nome,0,28)+"...";
   if(mn>=120) return StringFormat("próxima notícia em %dh%02d",mn/60,mn%60);
   return StringFormat("%s em %d min",nome,mn);
}
int PtsDe(double lv,double px)
{
   double pt=_Point; if(pt<=0) pt=0.01;
   return (int)MathRound((lv-px)/pt);
}
string TxtPts(double lv,double px)
{
   int d=PtsDe(lv,px);
   return StringFormat("%s%d",d>0?"+":"",d);
}
double NivelPx(string trecho)
{
   for(int iN=0;iN<ArraySize(g_niv);iN++)
      if(StringFind(g_niv[iN].nome,trecho)>=0) return g_niv[iN].preco;
   return 0;
}
string RotuloVarrida(const string nome)
{
   if(StringFind(nome,"Máxima")==0) return "Varrida da máxima"+StringSubstr(nome,6);
   if(StringFind(nome,"Mínima")==0) return "Varrida da mínima"+StringSubstr(nome,6);
   return "Varrida de "+nome;
}
string RotuloBos(const BOSe &b)
{
   if(b.choch) return b.dir==1?"Mudança de direção pra cima":"Mudança de direção pra baixo";
   return b.dir==1?"Rompimento de estrutura pra cima":"Rompimento de estrutura pra baixo";
}
string KZCurta()
{
   if(g_engKZ=="") return "";
   if(StringFind(g_engKZ,"fora")>=0) return "";
   if(StringFind(g_engKZ,"Londres")>=0) return "janela de Londres";
   if(StringFind(g_engKZ,"manhã")>=0 || StringFind(g_engKZ,"manha")>=0) return "janela da manhã em NY";
   if(StringFind(g_engKZ,"tarde")>=0) return "janela da tarde em NY";
   if(StringFind(g_engKZ,"Silver")>=0 || StringFind(g_engKZ,"Bullet")>=0) return "janela rápida";
   return "janela de operação";
}
void ObjTxtGraf(string n,datetime t,double p,string txt,color c,int sz,ENUM_ANCHOR_POINT a)
{
   string o=PFX+n;
   if(ObjectFind(0,o)<0)
   {
      ObjectCreate(0,o,OBJ_TEXT,0,t,p);
      ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
   }
   ObjectMove(0,o,0,t,p);
   ObjectSetString(0,o,OBJPROP_FONT,GraficoFonte());
   ObjectSetString(0,o,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,o,OBJPROP_COLOR,c);
   ObjectSetInteger(0,o,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,o,OBJPROP_ANCHOR,a);
}
void ObjHLinha(string n,double p,color c,ENUM_LINE_STYLE st,string txt)
{
   string o=PFX+n;
   if(ObjectFind(0,o)<0)
   {
      ObjectCreate(0,o,OBJ_HLINE,0,0,p);
      ObjectSetInteger(0,o,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,o,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,o,OBJPROP_BACK,true);
   }
   ObjectSetDouble(0,o,OBJPROP_PRICE,p);
   ObjectSetInteger(0,o,OBJPROP_COLOR,c);
   ObjectSetInteger(0,o,OBJPROP_STYLE,st);
   ObjectSetInteger(0,o,OBJPROP_WIDTH,1);
   ObjectSetString(0,o,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,o,OBJPROP_STYLE,st);
}

void PainelFonte(int sz,bool bold)
{
   g_cv.FontSet("Arial",-(sz*10),bold?FW_BOLD:FW_NORMAL);
}
int PainelTexH(int sz,bool bold){ PainelFonte(sz,bold); return g_cv.TextHeight("Ag")+1; }
void PainelQuebra(const string t,int maxw,int sz,bool bold,string &out[])
{
   ArrayResize(out,0);
   string s=t; StringReplace(s,"\r","");
   string ls[]; int n=StringSplit(s,'\n',ls); if(n<=0){ ArrayResize(out,1); out[0]=t; return; }
   PainelFonte(sz,bold);
   for(int iL=0;iL<n;iL++)
   {
      string line=ls[iL];
      while(StringLen(line)>0)
      {
         if(g_cv.TextWidth(line)<=maxw){ int k=ArraySize(out); ArrayResize(out,k+1); out[k]=line; break; }
         int cut=StringLen(line);
         while(cut>8)
         {
            cut--;
            if(StringGetCharacter(line,cut)==' ' && g_cv.TextWidth(StringSubstr(line,0,cut))<=maxw) break;
            if(g_cv.TextWidth(StringSubstr(line,0,cut))<=maxw && cut<12) break;
         }
         if(cut<4) cut=MathMin(40,StringLen(line));
         int k=ArraySize(out); ArrayResize(out,k+1); out[k]=StringSubstr(line,0,cut);
         line=StringSubstr(line,cut); StringTrimLeft(line);
      }
   }
}

void PainelFlushLinhas()
{
   if(!g_cvOk) return;
   int pad=12, W=PAINEL_W, H=8;
   for(int i=0;i<ArraySize(g_ln);i++)
   {
      PainelFonte(g_lsz[i],g_lb[i]);
      string wr[]; PainelQuebra(g_ln[i],W-24,g_lsz[i],g_lb[i],wr);
      int th=PainelTexH(g_lsz[i],g_lb[i]);
      H+=(ArraySize(wr)>0?ArraySize(wr):1)* (th+2);
   }
   H+=8;
   if(g_cv.Width()!=W || g_cv.Height()!=H) g_cv.Resize(W,H);
   g_cv.Erase(ColorToARGB(clrBlack,230));
   g_cv.Rectangle(0,0,W-1,H-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(1,1,W-2,H-2,ColorToARGB(clrGold,255));
   int y=6;
   for(int i=0;i<ArraySize(g_ln);i++)
   {
      PainelFonte(g_lsz[i],g_lb[i]);
      int th=PainelTexH(g_lsz[i],g_lb[i]);
      string wr[]; PainelQuebra(g_ln[i],W-24,g_lsz[i],g_lb[i],wr);
      for(int jw=0;jw<ArraySize(wr);jw++)
      {
         if(g_seg[i]=="" || jw>0) g_cv.TextOut(pad,y,wr[jw],ColorToARGB(g_lc[i],255));
         else
         {
            string parts[]; int np=StringSplit(g_seg[i],'\x02',parts); int x=pad;
            for(int q=0;q<np;q++){ string tc[]; if(StringSplit(parts[q],'\x01',tc)<2) continue; g_cv.TextOut(x,y,tc[0],ColorToARGB((color)StringToInteger(tc[1]),255)); x+=g_cv.TextWidth(tc[0]); }
         }
         y+=th+2;
      }
   }
   g_cv.Update(true);
}

void PainelDesenhaMini()
{
   if(!g_cvOk) return;
   string ver=PainelVeredito(g_aiPanel);
   int W=PAINEL_W, H=36;
   if(g_cv.Width()!=W || g_cv.Height()!=H) g_cv.Resize(W,H);
   g_cv.Erase(ColorToARGB(clrBlack,230));
   g_cv.Rectangle(0,0,W-1,H-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(1,1,W-2,H-2,ColorToARGB(clrGold,255));
   PainelFonte(InpFonte,true);
   g_cv.TextOut(10,8,"ALIEN  "+_Symbol,ColorToARGB(clrGold,255));
   if(ver!="")
   {
      color cv=CorVeredito(ver);
      int tw=0; PainelFonte(InpFonte-1,true); tw=g_cv.TextWidth("  "+ver+"  ")+8;
      int bx=W-12-tw, by=7, bh=20;
      g_cv.FillRectangle(bx,by,bx+tw,by+bh,ColorToARGB(cv,220));
      g_cv.TextOut(bx+4,by+2,ver,ColorToARGB(clrBlack,255));
   }
   g_cv.Update(true);
}

void PainelLinhaCabecalho()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   double spr=ask>bid?ask-bid:0;
   string st; SessaoNota(TimeTradeServer()>0?TimeTradeServer():TimeCurrent(),st);
   string kz=KZCurta();
   string amd=g_engAMD; if(StringLen(amd)>36) amd=StringSubstr(amd,0,36)+"...";
   string cab=StringFormat("%s  spread %s  ·  %s%s",_Symbol,spr>0?Fmt(spr):"-",st,kz!=""?"  ·  "+kz:"");
   PL(cab,clrWhite,InpFonte-1);
   if(amd!="") PL("Fase: "+amd,clrGold,InpFonte-1);
   PL(NewsContagem(),clrSilver,InpFonte-1);
}

void PainelDesenhaDash()
{
   if(!g_cvOk) return;
   int pad=12, W=PAINEL_W, f=InpFonte, y=8;
   string ver=PainelVeredito(g_aiPanel);
   string ai=g_aiPanel;
   if(StringLen(ai)>900) ai=StringSubstr(ai,0,900)+"...";
   string aiLin[];
   if(ai!="") PainelQuebra(ai,W-28,f-1,false,aiLin);
   else { ArrayResize(aiLin,1); aiLin[0]="Ainda sem análise da IA neste gráfico."; }
   int nAi=ArraySize(aiLin); if(nAi>8) nAi=8;
   int th=PainelTexH(f,false), thB=PainelTexH(f,true), thS=PainelTexH(f-1,false);
   int hAi=10+thB+4+nAi*(thS+1)+ (g_aiPanelT>0?thS+2:0)+8;
   int hHead=thS*2+thB+10;
   int hMtf=thB+8;
   int hNiv=thB+8*thS+8;
   int hBar=22+thS;
   int hDisc=thS+thB+8;
   if(!g_pnIA) hAi=-6; if(!g_pnNiv) hNiv=0; if(!g_pnConf) hBar=0; if(!g_pnConta) hDisc=0;
   int H=8+thB+6+hAi+hHead+hMtf+hNiv+hBar+hDisc+10;
   if(g_cv.Width()!=W || g_cv.Height()!=H) g_cv.Resize(W,H);
   g_cv.Erase(ColorToARGB(clrBlack,230));
   g_cv.Rectangle(0,0,W-1,H-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(1,1,W-2,H-2,ColorToARGB(clrGold,255));

   PainelFonte(f+1,true);
   g_cv.TextOut(pad,y,"ALIEN PROFESSOR",ColorToARGB(clrGold,255));
   y+=thB+6;

   if(g_pnIA){
   // caixa da IA
   int boxY=y, boxH=hAi;
   g_cv.FillRectangle(6,boxY,W-7,boxY+boxH-1,ColorToARGB(C'18,16,0',240));
   g_cv.Rectangle(6,boxY,W-7,boxY+boxH-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(7,boxY+1,W-8,boxY+boxH-2,ColorToARGB(clrGold,255));
   int iy=boxY+6;
   PainelFonte(f,true);
   g_cv.TextOut(pad,iy,"Análise da IA",ColorToARGB(clrGold,255));
   if(ver!="")
   {
      color cv=CorVeredito(ver);
      PainelFonte(f-1,true);
      int tw=g_cv.TextWidth("  "+ver+"  ")+6;
      int bx=W-14-tw, by=iy-1, bh=thB+2;
      g_cv.FillRectangle(bx,by,bx+tw,by+bh,ColorToARGB(cv,230));
      g_cv.TextOut(bx+4,by+1,ver,ColorToARGB(clrBlack,255));
   }
   iy+=thB+4;
   PainelFonte(f-1,false);
   for(int ja=0;ja<nAi;ja++)
   { g_cv.TextOut(pad,iy,aiLin[ja],ColorToARGB(clrWhite,255)); iy+=thS+1; }
   if(g_aiPanelT>0)
   {
      PainelFonte(f-2,false);
      g_cv.TextOut(pad,iy,"Atualizado às "+TimeToString(SrvParaBR(g_aiPanelT),TIME_MINUTES)+" (Brasília)",ColorToARGB(clrSilver,255));
   }
   y=boxY+boxH+6;
   }

   // cabeçalho compacto
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   if(ask<=0) ask=bid;
   double spr=ask-bid; if(spr<0) spr=0;
   string st; SessaoNota(TimeTradeServer()>0?TimeTradeServer():TimeCurrent(),st);
   string kz=KZCurta();
   PainelFonte(f-1,false);
   g_cv.TextOut(pad,y,StringFormat("%s   spread %s   ·   %s%s",_Symbol,spr>0?Fmt(spr):"-",st,kz!=""?"   ·   "+kz:""),ColorToARGB(clrWhite,255));
   y+=thS+1;
   string amd=g_engAMD; if(amd=="") amd="fase ainda indefinida";
   if(StringLen(amd)>52) amd=StringSubstr(amd,0,52)+"...";
   PainelFonte(f-1,true);
   g_cv.TextOut(pad,y,"Fase: "+amd,ColorToARGB(clrGold,255));
   y+=thS+1;
   PainelFonte(f-1,false);
   g_cv.TextOut(pad,y,NewsContagem(),ColorToARGB(clrSilver,255));
   y+=thS+6;

   // faixa de tempos
   PainelFonte(f-1,true);
   g_cv.TextOut(pad,y,"Tempos",ColorToARGB(clrGold,255));
   y+=thB;
   int x=pad;
   for(int im=0;im<6;im++)
   {
      string seta=g_mtf[im]==1?"▲":(g_mtf[im]==-1?"▼":"●");
      color cm=g_mtf[im]==1?clrGold:(g_mtf[im]==-1?clrSilver:clrWhite);
      string lab=g_mtfNm[im]+" "+seta+"  ";
      PainelFonte(f,true);
      g_cv.TextOut(x,y,lab,ColorToARGB(cm,255));
      x+=g_cv.TextWidth(lab);
   }
   y+=thB+6;

   if(g_pnNiv){
   // níveis
   PainelFonte(f-1,true);
   g_cv.TextOut(pad,y,"Níveis (distância em pontos)",ColorToARGB(clrGold,255));
   y+=thB;
   string nms[8]; double pxs[8];
   nms[0]="Máxima de ontem"; pxs[0]=NivelPx("Máxima de ontem");
   nms[1]="Mínima de ontem"; pxs[1]=NivelPx("Mínima de ontem");
   nms[2]="Máxima da Ásia"; pxs[2]=NivelPx("Máxima da Ásia");
   nms[3]="Mínima da Ásia"; pxs[3]=NivelPx("Mínima da Ásia");
   nms[4]="Máxima de Londres"; pxs[4]=NivelPx("Máxima de Londres");
   nms[5]="Mínima de Londres"; pxs[5]=NivelPx("Mínima de Londres");
   nms[6]="Preço médio da sessão"; pxs[6]=g_engVWAP;
   nms[7]="Preço de maior volume"; pxs[7]=(g_engPOC>0?g_engPOC:g_engPOCOntem);
   PainelFonte(f-1,false);
   for(int iv=0;iv<8;iv++)
   {
      if(pxs[iv]<=0){ g_cv.TextOut(pad,y,StringFormat("  %s  —",nms[iv]),ColorToARGB(clrSilver,255)); y+=thS; continue; }
      color cn=pxs[iv]>=bid?clrGold:clrWhite;
      g_cv.TextOut(pad,y,StringFormat("  %s  %s  (%s)",nms[iv],Fmt(pxs[iv]),TxtPts(pxs[iv],bid)),ColorToARGB(cn,255));
      y+=thS;
   }
   y+=4;
   }

   if(g_pnConf){
   // barra de confluência
   PainelFonte(f-1,true);
   int cb=g_efBuy, cs=g_efSell; if(cb<0) cb=0; if(cs<0) cs=0;
   g_cv.TextOut(pad,y,StringFormat("Confluência   compra %d    venda %d    (lista, não previsão)",cb,cs),ColorToARGB(clrGold,255));
   y+=thB+1;
   int barX=pad, barW=W-2*pad, barH=10;
   g_cv.FillRectangle(barX,y,barX+barW,y+barH,ColorToARGB(C'40,40,40',255));
   int tot=cb+cs;
   if(tot>0)
   {
      int wBuy=(int)MathRound((double)cb/tot*barW);
      if(wBuy>0) g_cv.FillRectangle(barX,y,barX+wBuy,y+barH,ColorToARGB(clrGold,255));
      if(wBuy<barW) g_cv.FillRectangle(barX+wBuy,y,barX+barW,y+barH,ColorToARGB(clrSilver,255));
   }
   g_cv.Rectangle(barX,y,barX+barW,y+barH,ColorToARGB(clrGold,255));
   y+=barH+8;
   }

   if(g_pnConta){
   // disciplina
   PainelFonte(f-1,true);
   g_cv.TextOut(pad,y,"Hoje na conta",ColorToARGB(clrGold,255));
   y+=thB;
   PainelFonte(f-1,false);
   string disc=StringFormat("%d operações, %d stops (máx %d), resultado $%+.2f  (meta $%.0f / perda máx $%.0f)",
      g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD);
   g_cv.TextOut(pad,y,disc,ColorToARGB(clrWhite,255));
   y+=thS;
   if(g_pare!="") { PainelFonte(f-1,true); g_cv.TextOut(pad,y,g_pare,ColorToARGB(clrGold,255)); }
   }
   g_cv.Update(true);
}

void PainelMontaEDesenha()
{
   if(g_noDraw) return;
   EngBotoes();
   if(!g_cvOk) return;
   ObjectSetInteger(0,PFX+"PAINEL",OBJPROP_TIMEFRAMES,g_pnOculto?OBJ_NO_PERIODS:OBJ_ALL_PERIODS);
   if(g_pnOculto) return;
   if(g_painelMin){ PainelDesenhaMini(); return; }
   if(g_engPag>0)
   {
      ArrayResize(g_ln,0); ArrayResize(g_lc,0); ArrayResize(g_lsz,0); ArrayResize(g_lb,0); ArrayResize(g_seg,0);
#ifdef APROF_EA
      PL("ALIEN PROFESSOR AUTO  ·  "+_Symbol,clrGold,InpFonte+1,true);
#else
      PL("ALIEN PROFESSOR  ·  "+_Symbol,clrGold,InpFonte+1,true);
#endif
      PainelLinhaCabecalho();
      EngPainelExtra();
      PainelFlushLinhas();
      return;
   }
   PainelDesenhaDash();
}

void DrawLinhasChave()
{
   DelPrefix("CHV");
   if(g_noDraw || !InpLinhasChave) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   string nms[8]; double pxs[8]; color cs[8];
   nms[0]="Máxima de ontem"; pxs[0]=NivelPx("Máxima de ontem"); cs[0]=clrGold;
   nms[1]="Mínima de ontem"; pxs[1]=NivelPx("Mínima de ontem"); cs[1]=clrWhite;
   nms[2]="Máxima da Ásia"; pxs[2]=NivelPx("Máxima da Ásia"); cs[2]=clrGold;
   nms[3]="Mínima da Ásia"; pxs[3]=NivelPx("Mínima da Ásia"); cs[3]=clrWhite;
   nms[4]="Máxima de Londres"; pxs[4]=NivelPx("Máxima de Londres"); cs[4]=clrGold;
   nms[5]="Mínima de Londres"; pxs[5]=NivelPx("Mínima de Londres"); cs[5]=clrWhite;
   nms[6]="Preço médio da sessão"; pxs[6]=g_engVWAP; cs[6]=clrGold;
   nms[7]="Preço de maior volume"; pxs[7]=(g_engPOC>0?g_engPOC:g_engPOCOntem); cs[7]=clrSilver;
   for(int iC=0;iC<8;iC++)
   {
      if(pxs[iC]<=0) continue;
      ObjHLinha("CHV"+IntegerToString(iC),pxs[iC],cs[iC],(iC>=6?STYLE_DOT:STYLE_SOLID),nms[iC]+" "+Fmt(pxs[iC]));
   }
}

void DrawCenarioLado(const Plano &p,bool principal,datetime t0)
{
   if(!PlanoValido(p)) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   int passo=PeriodSeconds(InpTFExec); if(passo<=0) passo=60;
   datetime t1=t0+passo*8;
   datetime t2=t0+passo*16;
   color c=principal?clrGold:C'130,130,130';
   int w=principal?2:1;
   double atr=g_atr>0?g_atr:_Point*50;
   double mag=p.entry;
   // se o preço já está na entrada, busca liquidez do outro lado (varrida) antes do alvo
   if(MathAbs(bid-p.entry)<=0.25*atr)
   {
      double alt=0;
      for(int iL=0;iL<ArraySize(g_niv);iL++)
      {
         if(g_niv[iL].estado==ST_ROMPIDO) continue;
         double lv=g_niv[iL].preco;
         if(p.dir==1 && lv<bid && (alt==0 || lv>alt)) alt=lv;
         if(p.dir==-1 && lv>bid && (alt==0 || lv<alt)) alt=lv;
      }
      if(alt>0 && MathAbs(alt-bid)>3*_Point) mag=alt;
   }
   string pf=principal?"CEN0":"CEN1";
   bool temMag=(MathAbs(mag-bid)>3*_Point && MathAbs(mag-p.target)>3*_Point);
   if(temMag)
   {
      string a1=PFX+pf+"A";
      if(ObjectFind(0,a1)<0){ ObjectCreate(0,a1,OBJ_ARROWED_LINE,0,t0,bid,t1,mag); ObjectSetInteger(0,a1,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,a1,OBJPROP_HIDDEN,true); ObjectSetInteger(0,a1,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,a1,OBJPROP_RAY_LEFT,false); }
      ObjectMove(0,a1,0,t0,bid); ObjectMove(0,a1,1,t1,mag);
      ObjectSetInteger(0,a1,OBJPROP_COLOR,c); ObjectSetInteger(0,a1,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,a1,OBJPROP_WIDTH,w);
      ObjTxtGraf(pf+"At",t1,mag,IcoLiq()+" Vem buscar liquidez aqui",c,8,p.dir==1?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
   }
   else t1=t0+passo*6;
   datetime tAlvo=t2;
   double pIni=temMag?mag:bid;
   datetime tIni=temMag?t1:t0;
   string a2=PFX+pf+"B";
   if(ObjectFind(0,a2)<0){ ObjectCreate(0,a2,OBJ_ARROWED_LINE,0,tIni,pIni,tAlvo,p.target); ObjectSetInteger(0,a2,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,a2,OBJPROP_HIDDEN,true); ObjectSetInteger(0,a2,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,a2,OBJPROP_RAY_LEFT,false); }
   ObjectMove(0,a2,0,tIni,pIni); ObjectMove(0,a2,1,tAlvo,p.target);
   ObjectSetInteger(0,a2,OBJPROP_COLOR,c); ObjectSetInteger(0,a2,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,a2,OBJPROP_WIDTH,w);
   string labAlvo=(p.dir==1?IcoAlvo()+" Depois sobe até aqui (alvo)":IcoAlvo()+" Depois desce até aqui (alvo)");
   ObjTxtGraf(pf+"Bt",tAlvo,p.target,labAlvo,c,8,p.dir==1?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
   // stop
   string hs=PFX+pf+"S";
   datetime ts0=t0, ts1=t0+passo*4;
   if(ObjectFind(0,hs)<0){ ObjectCreate(0,hs,OBJ_TREND,0,ts0,p.stop,ts1,p.stop); ObjectSetInteger(0,hs,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,hs,OBJPROP_HIDDEN,true); ObjectSetInteger(0,hs,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,hs,OBJPROP_RAY_LEFT,false); }
   ObjectMove(0,hs,0,ts0,p.stop); ObjectMove(0,hs,1,ts1,p.stop);
   ObjectSetInteger(0,hs,OBJPROP_COLOR,c); ObjectSetInteger(0,hs,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,hs,OBJPROP_WIDTH,1);
   ObjTxtGraf(pf+"St",ts1,p.stop,IcoStop()+" Se passar daqui, cancela",c,8,ANCHOR_LEFT_UPPER);
   if(principal)
      ObjTxtGraf(pf+"Tg",t0,bid,"cenário, não certeza",clrSilver,7,ANCHOR_LEFT_LOWER);
}
void DrawCenarios()
{
   DelPrefix("CEN");
   if(g_noDraw || !InpCenariosGrafico) return;
   if(ArraySize(g_r)<=0) return;
   datetime t0=g_r[0].time+PeriodSeconds(InpTFExec);
   if(t0<=0) t0=TimeCurrent();
   Plano main=MelhorPlano();
   if(PlanoValido(main)) DrawCenarioLado(main,true,t0);
   Plano outr=(main.dir==1?g_ps:g_pb);
   if(PlanoValido(outr) && !(PlanoValido(main) && outr.dir==main.dir)) DrawCenarioLado(outr,false,t0);
}

//====================================================================
// v12.6: gráfico limpo. Textos que caem um em cima do outro são afastados
// (sobe/desce alguns pixels) ou escondidos; "modo limpo" mostra só o essencial.
// Painel: blocos que o Vitor pode esconder pelo Telegram.
//====================================================================
string g_rotNome[]; double g_rotOrig[]; double g_rotMov[];
// objetos que o modo limpo esconde (os níveis-chave, o plano e as suas linhas ficam)
bool RotuloSoDetalhe(string n)
{
   string pf[]={"NV","SWP","BOS","FVG","FH1","FM15","OBL","VOL","SIG","CEN1"};
   for(int i=0;i<ArraySize(pf);i++) if(StringFind(n,PFX+pf[i])==0) return true;
   return false;
}
// prioridade: maior fica no lugar, menor é que se mexe
int RotuloPrioridade(string n)
{
   if(StringFind(n,PFX+"USR")==0) return 6;
   if(StringFind(n,PFX+"PL")==0) return 5;
   if(StringFind(n,PFX+"CEN0")==0) return 4;
   if(StringFind(n,PFX+"SWP")==0) return 3;
   if(StringFind(n,PFX+"BOS")==0) return 2;
   return 1;
}
double RotuloOrigem(string n,double cur)
{
   for(int i=0;i<ArraySize(g_rotNome);i++) if(g_rotNome[i]==n){ if(MathAbs(g_rotMov[i]-cur)<_Point*0.5) return g_rotOrig[i]; return cur; }
   return cur;
}
void RotuloGuarda(string n,double orig,double mov)
{
   for(int i=0;i<ArraySize(g_rotNome);i++) if(g_rotNome[i]==n){ g_rotOrig[i]=orig; g_rotMov[i]=mov; return; }
   int k=ArraySize(g_rotNome); ArrayResize(g_rotNome,k+1); ArrayResize(g_rotOrig,k+1); ArrayResize(g_rotMov,k+1);
   g_rotNome[k]=n; g_rotOrig[k]=orig; g_rotMov[k]=mov;
}
bool RotuloBate(int x,int y,int w,int h,const int &bx[],const int &by[],const int &bw[],const int &bh[],int nb)
{
   for(int i=0;i<nb;i++) if(x<bx[i]+bw[i] && bx[i]<x+w && y<by[i]+bh[i] && by[i]<y+h) return true;
   return false;
}
void RotulosArruma()
{
   if(g_noDraw) return;
   int tot=ObjectsTotal(0,0,-1);
   string nm[]; int pr[]; ArrayResize(nm,0); ArrayResize(pr,0);
   for(int i=0;i<tot;i++)
   {
      string n=ObjectName(0,i,0,-1); if(StringFind(n,PFX)!=0) continue;
      bool det=RotuloSoDetalhe(n);
      ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,(g_modoLimpo && det)?OBJ_NO_PERIODS:OBJ_ALL_PERIODS);
      if(g_modoLimpo && det) continue;
      if(ObjectGetInteger(0,n,OBJPROP_TYPE)!=OBJ_TEXT) continue;
      int k=ArraySize(nm); ArrayResize(nm,k+1); ArrayResize(pr,k+1); nm[k]=n; pr[k]=RotuloPrioridade(n);
   }
   if(!InpArrumarRotulos) return;
   int n=ArraySize(nm); if(n==0) return;
   // ordena por prioridade (maior primeiro)
   for(int a=0;a<n-1;a++) for(int b=a+1;b<n;b++) if(pr[b]>pr[a]){ int tp=pr[a]; pr[a]=pr[b]; pr[b]=tp; string tn=nm[a]; nm[a]=nm[b]; nm[b]=tn; }
   int bx[],by[],bw[],bh[]; ArrayResize(bx,n); ArrayResize(by,n); ArrayResize(bw,n); ArrayResize(bh,n); int nb=0;
   int off[]={0,-14,14,-28,28};
   for(int i=0;i<n;i++)
   {
      string o=nm[i];
      datetime t=(datetime)ObjectGetInteger(0,o,OBJPROP_TIME,0);
      double cur=ObjectGetDouble(0,o,OBJPROP_PRICE,0);
      double orig=RotuloOrigem(o,cur);
      int x,y; if(!ChartTimePriceToXY(0,0,t,orig,x,y)){ continue; }
      int sz=(int)ObjectGetInteger(0,o,OBJPROP_FONTSIZE); if(sz<=0) sz=8;
      int w=(int)(StringLen(ObjectGetString(0,o,OBJPROP_TEXT))*sz*0.62)+6, h=sz+6;
      long an=ObjectGetInteger(0,o,OBJPROP_ANCHOR);
      if(an==ANCHOR_RIGHT_LOWER || an==ANCHOR_RIGHT_UPPER || an==ANCHOR_RIGHT) x-=w;
      if(an==ANCHOR_LOWER || an==ANCHOR_UPPER || an==ANCHOR_CENTER) x-=w/2;
      if(an==ANCHOR_LEFT_LOWER || an==ANCHOR_RIGHT_LOWER || an==ANCHOR_LOWER) y-=h;
      int achou=-1;
      for(int q=0;q<ArraySize(off);q++) if(!RotuloBate(x,y+off[q],w,h,bx,by,bw,bh,nb)){ achou=q; break; }
      if(achou<0){ ObjectSetInteger(0,o,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS); RotuloGuarda(o,orig,cur); continue; }
      double novo=orig;
      if(off[achou]!=0)
      {
         int sub=0; datetime t2; double p2;
         int yAnc=y+off[achou]+((an==ANCHOR_LEFT_LOWER || an==ANCHOR_RIGHT_LOWER || an==ANCHOR_LOWER)?h:0);
         if(ChartXYToTimePrice(0,x>0?x:1,yAnc,sub,t2,p2) && p2>0) novo=p2;
      }
      ObjectSetDouble(0,o,OBJPROP_PRICE,0,novo);
      RotuloGuarda(o,orig,novo);
      bx[nb]=x; by[nb]=y+off[achou]; bw[nb]=w; bh[nb]=h; nb++;
   }
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
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   EngChartEvent(id,sparam);
   if(id==CHARTEVENT_CHART_CHANGE){ static uint ult=0; uint ms=GetTickCount(); if(ms-ult>300){ ult=ms; RotulosArruma(); ChartRedraw(0); } }
}
//+------------------------------------------------------------------+
