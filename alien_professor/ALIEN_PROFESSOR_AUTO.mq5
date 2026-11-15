//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_AUTO.mq5                                         |
//| EA que OPERA os sinais do ALIEN PROFESSOR (nota >= limite).      |
//| AVISO: no teste 2016-2025 esses sinais PERDERAM dinheiro.        |
//| Sem martingale, sem grade, sem preço médio. 1 posição por vez.   |
//| Stop e alvo vão junto com a ordem. Conta real bloqueada padrão.  |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "12.30"
#property description "Robô dos sinais do ALIEN PROFESSOR. Risco fixo, 1 posição, travas diárias, DD 15%, bloqueio de conta real. ATENÇÃO: o teste histórico dos sinais foi NEGATIVO."
#define APROF_EA
#define APROF_VER "12.3"
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

input group "=== Agente Alier (Telegram) ==="
input bool   InpAlertasProativos  = true;        // Avisar sozinho: varrida, mudança de estrutura, bloco de ordens, VWAP
input int    InpAlertasMaxHora    = 6;           // Máximo de avisos automáticos por hora
input int    InpAlertaCooldownMin = 20;          // Mesmo tipo de aviso: esperar N minutos
input bool   InpDisciplina        = true;        // Perguntar "seguiu o plano?" quando um trade fecha
input bool   InpVoz               = true;        // Entender áudio do Telegram (usa a chave Gemini)
input int    InpPausaAposStopMin  = 0;           // Depois de um stop, segurar os avisos automáticos N min (0 = desligado; não trava ordens)
input bool   InpBackupSemanal     = true;        // Copiar os ALIEN_*.csv toda semana para MQL5/Files/ALIEN_backup/data
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
      s+=(s==""?"":",")+StringFormat("{\"hora\":\"%s\",\"hora_brasilia\":\"%s\",\"min\":%d,\"moeda\":\"%s\",\"impacto\":\"%s\",\"evento\":\"%s\"}",TimeToString(g_news[i].t,TIME_DATE|TIME_MINUTES),TimeToString(SrvParaBR(g_news[i].t),TIME_MINUTES),(int)((g_news[i].t-now)/60),g_news[i].cur,ImpTxt(g_news[i].imp),nm);
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
      if(!g_noDraw){ DrawNiveis(); DrawEstrutura(); DrawLinhasChave(); EngDrawBlocos(); DrawCenarios(); }
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
   if(!g_noDraw){ DrawPlano(b); if(newBar||refresh){ DrawLinhasChave(); DrawCenarios(); } Painel(); }
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
   int H=8+thB+6+hAi+hHead+hMtf+hNiv+hBar+hDisc+10;
   if(g_cv.Width()!=W || g_cv.Height()!=H) g_cv.Resize(W,H);
   g_cv.Erase(ColorToARGB(clrBlack,230));
   g_cv.Rectangle(0,0,W-1,H-1,ColorToARGB(clrGold,255));
   g_cv.Rectangle(1,1,W-2,H-2,ColorToARGB(clrGold,255));

   PainelFonte(f+1,true);
   g_cv.TextOut(pad,y,"ALIEN PROFESSOR",ColorToARGB(clrGold,255));
   y+=thB+6;

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
      g_cv.TextOut(pad,iy,"Atualizado às "+TimeToString(g_aiPanelT,TIME_MINUTES)+" (hora do servidor)",ColorToARGB(clrSilver,255));
   }
   y=boxY+boxH+6;

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
   g_cv.Update(true);
}

void PainelMontaEDesenha()
{
   if(g_noDraw) return;
   EngBotoes();
   if(!g_cvOk) return;
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

// ---- configuração pessoal local (MQL5\Files\ALIEN_config.txt) ----
// Token, chat id e chaves ficam NESTE arquivo do seu PC, não no robô. Atualizar o robô não apaga.
string g_cfgTgToken="", g_cfgTgChat=""; bool g_cfgAssistente=false; string g_cfgOrigem="parâmetros";
string CfgArq(){ return "ALIEN_config.txt"; }
// grava/troca uma linha "chave=valor" no ALIEN_config.txt (mantém o resto)
void CfgSalva(string chave,string valor)
{
   string ls[]; int n=0;
   int h=FileOpen(CfgArq(),FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE){ while(!FileIsEnding(h)){ string l=FileReadString(h); ArrayResize(ls,n+1); ls[n++]=l; } FileClose(h); }
   bool achou=false;
   for(int i=0;i<n;i++){ string k=ls[i]; int e=StringFind(k,"="); if(e>0){ k=StringSubstr(k,0,e); StringTrimLeft(k); StringTrimRight(k); StringToLower(k); if(k==chave){ ls[i]=chave+"="+valor; achou=true; } } }
   if(!achou){ if(n==0){ ArrayResize(ls,1); ls[0]="# ALIEN - configuracao pessoal (NAO compartilhe este arquivo)"; n=1; } ArrayResize(ls,n+1); ls[n++]=chave+"="+valor; }
   int w=FileOpen(CfgArq(),FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) if(!(i==n-1 && ls[i]=="")) FileWriteString(w,ls[i]+"\r\n");
   FileClose(w);
}
void CfgLoad()
{
   g_cfgTgToken=InpTelegramToken; g_cfgTgChat=InpTelegramChatId; AICfgInit(); g_cfgAssistente=false; g_cfgOrigem="parâmetros";
   int h=FileOpen(CfgArq(),FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   int n=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); StringTrimLeft(l); StringTrimRight(l);
      if(l=="" || StringGetCharacter(l,0)=='#' || StringGetCharacter(l,0)==';') continue;
      int e=StringFind(l,"="); if(e<=0) continue;
      string k=StringSubstr(l,0,e), v=StringSubstr(l,e+1); StringTrimRight(k); StringTrimLeft(v); StringToLower(k);
      if(v=="") continue;
      if(k=="telegram_token"){ g_cfgTgToken=v; n++; }
      else if(k=="telegram_chat_id"){ g_cfgTgChat=v; n++; }
      else if(k=="gemini_chave_1"){ g_cfgAI2Key=v; n++; }
      else if(k=="gemini_chave_2"){ g_cfgGem2=v; n++; }
      else if(k=="xai_chave"){ g_cfgAIKey=v; n++; }
      else if(k=="modo"){ string m=v; StringToLower(m); g_cfgAssistente=(StringFind(m,"assist")==0); n++; }
   }
   FileClose(h);
   if(n>0) g_cfgOrigem="arquivo ALIEN_config.txt";
   Print("ALIEN: configuração lida de ",g_cfgOrigem," (",n," itens; chaves não aparecem no log)");
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
bool TgTokenOk(){ return InpUseTelegram && StringLen(g_cfgTgToken)>20 && !MQLInfoInteger(MQL_TESTER); }
bool TgOk(){ return TgTokenOk() && StringLen(g_cfgTgChat)>0; }
bool SendMsg(string text){ if(!TgOk()) return false; return SendMsgTo(g_cfgTgChat,text); }
bool SendMsgTo(string chat,string text)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/sendMessage";
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
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n"+g_cfgTgChat+"\r\n");
   if(StringLen(caption)>1000) caption=StringSubstr(caption,0,1000);
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n"+caption+"\r\n");
   AddStr(buf,"--"+bd+"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"grafico.png\"\r\nContent-Type: image/png\r\n\r\n");
   int k=ArraySize(buf); int n=ArraySize(img); ArrayResize(buf,k+n); for(int i=0;i<n;i++) buf[k+i]=(char)img[i];
   AddStr(buf,"\r\n--"+bd+"--\r\n");
   char res[]; string rh;
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+g_cfgTgToken+"/sendPhoto","Content-Type: multipart/form-data; boundary="+bd+"\r\n",15000,buf,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram foto respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}

//====================================================================
// ANÁLISE IA (opcional). Só comenta; por padrão NUNCA muda decisão.
enum ENUM_AIMODE { AMBAS=0, PRINCIPAL_COM_RESERVA=1 };
input group "=== Análise IA (opcional) ==="
input ENUM_AIMODE InpAIMode = AMBAS;                                      // AMBAS = Grok + Gemini1 + Gemini2, 1 resposta unida | PRINCIPAL_COM_RESERVA
input bool   InpUseAI      = true;                                         // Usar análise IA (precisa de chave)
input string InpAIProvider = "xai";                                        // Provedor (qualquer API compatível com OpenAI)
input string InpAIEndpoint = "https://api.x.ai/v1/chat/completions";      // Endpoint (xAI; ou https://api.openai.com/v1/chat/completions)
input string InpAIModel    = "grok-4.20-0309-non-reasoning";               // Modelo (rápido)
input string InpAIKey      = "";                                           // Chave da API (vazio = IA desligada)
input string InpAI2Endpoint= "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"; // Reserva: Google Gemini (compatível OpenAI)
input string InpAI2Model   = "gemini-3.5-flash-lite";                      // Modelo reserva
input string InpAI2Key     = "";                                           // Chave Gemini 1 (vazio = sem esta opinião)
input string InpGeminiKey2 = "";                                           // Chave Gemini 2 (opcional; opinião à parte, unida no modo AMBAS)
input int    InpAIMinutos  = 0;                                            // Análise a cada N minutos também (0 = só nos sinais)
input bool   InpAIVeto     = false;                                        // IA pode VETAR (só opera se o VEREDITO for o lado do sinal; em AMBAS, as duas têm que concordar)
input int    InpAIMinSeg   = 15;                                           // Limite: mínimo de segundos entre perguntas à IA
input int    InpAIMaxHora  = 30;                                           // Limite: máximo de perguntas à IA por hora (0 = sem limite)

// chaves em uso: começam com os parâmetros; o robô AUTO troca pelas do arquivo MQL5\Files\ALIEN_config.txt
string   g_cfgAIKey="", g_cfgAI2Key="", g_cfgGem2="";
void AICfgInit(){ g_cfgAIKey=InpAIKey; g_cfgAI2Key=InpAI2Key; g_cfgGem2=InpGeminiKey2; }
string   g_aiTxt="";
datetime g_aiLast=0;

bool AIOn(){ return InpUseAI && (StringLen(g_cfgAIKey)>10 || StringLen(g_cfgAI2Key)>10 || StringLen(g_cfgGem2)>10) && !MQLInfoInteger(MQL_TESTER); }
string JEsc(string s)
{
   // escape JSON-string: \ " \n \r \t e controles <0x20 como \u00XX
   string o="";
   int n=StringLen(s);
   for(int i=0;i<n;i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(c=='\\')      o+="\\\\";
      else if(c=='"')  o+="\\\"";
      else if(c=='\n') o+="\\n";
      else if(c=='\r') o+="\\r";
      else if(c=='\t') o+="\\t";
      else if(c<0x20)  o+=StringFormat("\\u%04x",c);
      else             o+=ShortToString(c);
   }
   return o;
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
   return "Você é um colega de trading (SMC). PT-BR informal, no máximo 4 linhas curtas, números exatos, sem prometer lucro. "
          "Fala o que confirma, o que invalida, e o que olhar no M1. Sem rótulo robótico.";
}
// pergunta pra IA: tenta xAI; se der erro/tempo/cota, tenta a reserva (Gemini)
string AIAsk(string estado){ return AIAskEx(AISysPadrao(),estado,220,true); }   // sinais: passam do limite (poucos por dia)
string   g_aiVeredito="";   // COMPRA / VENDA / ESPERAR da última análise
bool     g_aiConcordam=false;
string   g_aiLastErr="";    // último erro HTTP (sem chave) para o log Experts
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
   for(int i=0;i<n;i++){ string u=ls[i]; StringToUpper(u); if(StringFind(u,"VEREDITO")>=0 || StringFind(u,"CONFIAN")==0 || StringFind(u,"AS DUAS LEITURAS")==0 || StringFind(u,"SÓ UMA LEITURA")==0) continue; o+=(o==""?"":"\n")+ls[i]; }
   StringTrimRight(o); return o;
}
// respostas brutas das IAs ficam em MQL5\Files\ALIEN_ia_log.txt (só respostas, nunca chaves)
void AILog(string tag,string txt)
{
   int h=FileOpen("ALIEN_ia_log.txt",FILE_READ|FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END); FileWriteString(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+" "+_Symbol+" ["+tag+"] "+txt+"\r\n"); FileClose(h);
}
string AIGeminiKey(int idx){ return idx==1 ? g_cfgAI2Key : g_cfgGem2; }
string AIAskGemini(string sys,string estado,int maxTok,int idx,double temp=0.2)
{
   string key=AIGeminiKey(idx);
   if(StringLen(key)<=10) return "";
   string t=AIAskOne(sys,estado,InpAI2Endpoint,InpAI2Model,key,maxTok,temp);
   if(t=="") Print("IA: GEMINI",idx," falhou. ",g_aiLastErr);
   return t;
}
// "custo" de uma resposta livre: tamanho + multa por bloco de plano / campo cru / veredito
int AICustoLivre(string t)
{
   string u=t; StringToLower(u);
   int c=StringLen(AISemVeredito(t));
   if(c<15) c+=2000;                      // curta demais = provavelmente cortada
   if(StringFind(u,"plano_")>=0 || StringFind(u,"alvos_locais")>=0) c+=600;
   if(StringFind(u,"se for comprar")>=0 || StringFind(u,"se for vender")>=0) c+=300;
   if(StringFind(u,"veredito")>=0) c+=200;
   return c;
}
void AIPushOp(string &names[],string &texts[],string &vers[],string &errs[],string name,string txt,string err)
{
   int k=ArraySize(names);
   ArrayResize(names,k+1); ArrayResize(texts,k+1); ArrayResize(vers,k+1); ArrayResize(errs,k+1);
   names[k]=name; texts[k]=txt; vers[k]=AIVer(txt); errs[k]=err;
   AILog(name+" "+vers[k],txt);
}

// valida entrada/stop/alvo dos cenários da IA (lado certo e R>=1). Só substitui o bloco inválido.
bool AIEhDig(ushort c){ return (c>='0' && c<='9'); }
bool AISegueR(const string s,int j)
{
   int n=StringLen(s);
   while(j<n && StringGetCharacter(s,j)==' ') j++;
   if(j>=n) return false;
   ushort c=StringGetCharacter(s,j);
   return (c=='R' || c=='r');
}
bool AILePreco(const string s,int from,int lim,double &out,int &ate)
{
   int n=StringLen(s); if(lim<=0 || lim>n) lim=n;
   int j=from;
   while(j<lim)
   {
      ushort c=StringGetCharacter(s,j);
      if(c=='-' || AIEhDig(c))
      {
         int st=j;
         if(c=='-') j++;
         int d0=j;
         while(j<lim && AIEhDig(StringGetCharacter(s,j))) j++;
         if(j==d0){ j=st+1; continue; }
         if(j<lim)
         {
            ushort sep=StringGetCharacter(s,j);
            if(sep=='.' || sep==',')
            {
               int k=j+1;
               if(k<lim && AIEhDig(StringGetCharacter(s,k)))
               { j=k; while(j<lim && AIEhDig(StringGetCharacter(s,j))) j++; }
            }
         }
         if(AISegueR(s,j)){ j=st+1; continue; }
         string tok=StringSubstr(s,st,j-st);
         StringReplace(tok,",",".");
         out=StringToDouble(tok);
         if(out==0 && tok!="0" && tok!="0.0" && tok!="0,0"){ j=st+1; continue; }
         ate=j; return (out>0);
      }
      j++;
   }
   return false;
}
int AIAchaChave(const string u,string key,int from)
{
   return StringFind(u,key,from);
}
double AINumApos(const string orig,string key,bool &ok)
{
   ok=false;
   string u=orig, k=key;
   StringToUpper(u); StringToUpper(k);
   int p=0, n=StringLen(u);
   while(true)
   {
      int i=AIAchaChave(u,k,p); if(i<0) return 0;
      int j=i+StringLen(k);
      while(j<n)
      {
         ushort c=StringGetCharacter(u,j);
         if(c==' ' || c==':' || c=='=' || c==',' || c==';' || c=='-') j++;
         else break;
      }
      double v=0; int ate=0;
      if(AILePreco(orig,j,j+80,v,ate))
      { ok=true; return v; }
      p=i+1;
   }
   return 0;
}
string AISemAcento(string s)
{
   StringReplace(s,"Á","A"); StringReplace(s,"À","A"); StringReplace(s,"Ã","A"); StringReplace(s,"Â","A");
   StringReplace(s,"É","E"); StringReplace(s,"Ê","E");
   StringReplace(s,"Í","I");
   StringReplace(s,"Ó","O"); StringReplace(s,"Ô","O"); StringReplace(s,"Õ","O");
   StringReplace(s,"Ú","U");
   StringReplace(s,"á","A"); StringReplace(s,"à","A"); StringReplace(s,"ã","A"); StringReplace(s,"â","A");
   StringReplace(s,"é","E"); StringReplace(s,"ê","E");
   StringReplace(s,"í","I");
   StringReplace(s,"ó","O"); StringReplace(s,"ô","O"); StringReplace(s,"õ","O");
   StringReplace(s,"ú","U");
   return s;
}
int AICenarioDir(string line)
{
   string u=line; StringToUpper(u); u=AISemAcento(u);
   if(StringFind(u,"CENARIO")<0) return 0;
   if(StringFind(u,"COMPRA")>=0 || StringFind(u,"BUY")>=0) return 1;
   if(StringFind(u,"VENDA")>=0 || StringFind(u,"SELL")>=0 || StringFind(u,"SHORT")>=0) return -1;
   return 0;
}
bool AIFimBloco(string line,bool primeiro)
{
   if(!primeiro && AICenarioDir(line)!=0) return true;
   string u=line; StringToUpper(u); u=AISemAcento(u);
   if(StringFind(u,"O QUE ESPERAR")>=0) return true;
   if(StringFind(u,"RISCOS")>=0 && StringFind(u,"CENARIO")<0) return true;
   if(StringFind(u,"VEREDITO")>=0) return true;
   if(StringFind(u,"CONFIAN")==0 || StringFind(u,"CONFIANCA")==0) return true;
   if(StringFind(u,"OBS.:")>=0 || StringFind(u,"OBS:")>=0) return true;
   return false;
}
string AIValidaCenarios(string t)
{
   if(t=="") return t;
   StringReplace(t,"\r","");
   string u0=t; StringToUpper(u0); u0=AISemAcento(u0);
   if(StringFind(u0,"CENARIO")<0) return t;
   string ls[]; int n=StringSplit(t,'\n',ls); if(n<=0) return t;
   int st[], dir[]; ArrayResize(st,0); ArrayResize(dir,0);
   for(int i=0;i<n;i++)
   {
      int d=AICenarioDir(ls[i]);
      if(d!=0){ int k=ArraySize(st); ArrayResize(st,k+1); ArrayResize(dir,k+1); st[k]=i; dir[k]=d; }
   }
   if(ArraySize(st)==0) return t;
   for(int b=ArraySize(st)-1;b>=0;b--)
   {
      int a=st[b], en=n;
      for(int j=a+1;j<n;j++){ if(AIFimBloco(ls[j],false)){ en=j; break; } }
      string bloco=ls[a];
      for(int j=a+1;j<en;j++) bloco+="\n"+ls[j];
      bool okE=false, okS=false, okA=false;
      double ent=AINumApos(bloco,"ENTRADA",okE); if(!okE) ent=AINumApos(bloco,"ENTRY",okE);
      double stp=AINumApos(bloco,"STOP",okS);
      if(!okS) stp=AINumApos(bloco," SL",okS);
      double alv=AINumApos(bloco,"ALVO",okA); if(!okA) alv=AINumApos(bloco,"TARGET",okA); if(!okA) alv=AINumApos(bloco," TP",okA);
      bool ruim=false;
      if(okE && okS && okA && ent>0)
      {
         double risk=MathAbs(ent-stp);
         if(risk<=0) ruim=true;
         else
         {
            double rr=MathAbs(alv-ent)/risk;
            bool geo=(dir[b]==1 ? (stp<ent && ent<alv) : (alv<ent && ent<stp));
            if(!geo || rr<1.0) ruim=true;
         }
      }
      if(ruim)
      {
         string msg=(dir[b]==1?"Cenário compra: sem setup válido (R<1)":"Cenário venda: sem setup válido (R<1)");
         // comprime o bloco em uma linha
         ls[a]=msg;
         for(int j=a+1;j<en;j++) ls[j]="";
      }
   }
   string o="";
   for(int i=0;i<n;i++)
   {
      if(ls[i]=="" && (i==0 || i==n-1 || (i>0 && ls[i-1]==""))) continue;
      if(ls[i]=="") continue;
      o+=(o==""?"":"\n")+ls[i];
   }
   return o;
}

string AIAskEx(string sys,string user,int maxTok,bool force=false,bool verdict=true,double temp=0.2)
{
   if(!AIOn()) return "";
   if(!force && AIEsperaSeg()>0){ Print("IA: limite de uso - pulei esta pergunta"); return ""; }
   AIMarca();
   g_aiVeredito=""; g_aiConcordam=false;
   string sysV=verdict ? sys+" Na última linha escreva exatamente uma destas: VEREDITO: COMPRA / VEREDITO: VENDA / VEREDITO: ESPERAR." : sys;
   bool hGrok=StringLen(g_cfgAIKey)>10, hG1=StringLen(g_cfgAI2Key)>10, hG2=StringLen(g_cfgGem2)>10;
   string names[], texts[], vers[], errs[];
   bool ambas=(InpAIMode==AMBAS);
   // AMBAS: chama todas as opiniões disponíveis (GROK, GEMINI1, GEMINI2). Reserva: GROK primeiro; se falhar, as Gemini.
   if(ambas || hGrok)
   {
      if(hGrok)
      {
         string a=AIAskOne(sysV,user,InpAIEndpoint,InpAIModel,g_cfgAIKey,maxTok,temp);
         AIPushOp(names,texts,vers,errs,"GROK",a,g_aiLastErr);
      }
   }
   bool pediGrok=hGrok && ArraySize(texts)>0;
   bool grokOk=pediGrok && texts[0]!="";
   if(ambas || !hGrok || !grokOk)
   {
      if(hG1)
      {
         string g1=AIAskGemini(sysV,user,maxTok,1,temp);
         AIPushOp(names,texts,vers,errs,"GEMINI1",g1,g_aiLastErr);
      }
      if(hG2)
      {
         string g2=AIAskGemini(sysV,user,maxTok,2,temp);
         AIPushOp(names,texts,vers,errs,"GEMINI2",g2,g_aiLastErr);
      }
   }
   string okN[], okT[], okV[];
   string falhas="";
   for(int i=0;i<ArraySize(names);i++)
   {
      if(texts[i]!=""){ int k=ArraySize(okN); ArrayResize(okN,k+1); ArrayResize(okT,k+1); ArrayResize(okV,k+1); okN[k]=names[i]; okT[k]=texts[i]; okV[k]=vers[i]; }
      else if(errs[i]!="") falhas+=(falhas==""?"":" | ")+names[i]+" "+errs[i];
   }
   int nOk=ArraySize(okN);
   if(nOk==0) return "";
   string lista="";
   for(int i=0;i<nOk;i++) lista+=(i==0?"":" + ")+okN[i];
   string t="", conf="";
   if(nOk==1)
   {
      t=okT[0]; g_aiVeredito=okV[0]; if(g_aiVeredito=="") g_aiVeredito="ESPERAR";
      if(!verdict) g_aiVeredito="";
      conf="Só uma leitura respondeu agora (a outra falhou), vai com calma";
      if(falhas!="") Print("IA: ",conf,". Falhas: ",falhas);
   }
   else
   {
      bool agree=(okV[0]!="");
      for(int i=1;i<nOk;i++) if(okV[i]=="" || okV[i]!=okV[0]) agree=false;
      g_aiConcordam=agree;
      g_aiVeredito=agree?okV[0]:"ESPERAR";
      if(!verdict){ g_aiConcordam=true; g_aiVeredito=""; }
      string det="";
      for(int i=0;i<nOk;i++) det+=(i==0?"":", ")+okN[i]+" "+(okV[i]==""?"?":okV[i]);
      // união determinística, sem nova chamada à API:
      //  análise (com veredito) -> texto mais completo; conversa livre -> a resposta mais curta e limpa
      int best=0, bl=-1;
      if(verdict)
      { for(int i=0;i<nOk;i++){ int L=StringLen(AISemVeredito(okT[i])); if(L>bl){ bl=L; best=i; } } }
      else
      { for(int i=0;i<nOk;i++){ int L=AICustoLivre(okT[i]); if(bl<0 || L<bl){ bl=L; best=i; } } }
      t=AISemVeredito(okT[best]);
      AILog("UNIDA "+g_aiVeredito+" ("+det+")",t);
      conf=agree?"As duas leituras bateram ✅":"As duas leituras discordaram, então eu esperaria 🟡";
      if(falhas!="") Print("IA: união com ",lista,". Falhas: ",falhas);
   }
   g_aiLast=TimeCurrent();
   t=AIValidaCenarios(AISemVeredito(t));
   if(!verdict){ g_aiVeredito=""; return t; }
   return t+"\nVEREDITO: "+g_aiVeredito+"\n"+conf;
}

string AIAskOne(string sys,string estado,string endpoint,string model,string key,int maxTok,double temp=0.2)
{
   g_aiLastErr="";
   if(temp<0.0) temp=0.0; if(temp>1.0) temp=1.0;
   string body="{\"model\":\""+JEsc(model)+"\",\"temperature\":"+DoubleToString(temp,1)+",\"max_tokens\":"+IntegerToString(maxTok)+",\"messages\":[{\"role\":\"system\",\"content\":\""+JEsc(sys)+"\"},{\"role\":\"user\",\"content\":\""+JEsc(estado)+"\"}]}";
   char data[],res[]; string rh;
   // UTF-8 sem o NUL final que o StringToCharArray acrescenta (xAI rejeita o body com 400)
   uchar utf8[];
   int n=StringToCharArray(body,utf8,0,WHOLE_ARRAY,CP_UTF8);
   if(n<=0) return "";
   if(utf8[n-1]==0) n--;
   ArrayResize(data,n);
   for(int i=0;i<n;i++) data[i]=(char)utf8[i];
   string hdr="Content-Type: application/json\r\nAuthorization: Bearer "+key+"\r\n";
   ResetLastError();
   int code=WebRequest("POST",endpoint,hdr,15000,data,res,rh);
   // limite do plano grátis (429) ou servidor ocupado (5xx): espera e tenta de novo (2 s, depois 5 s)
   for(int tent=0; tent<2 && (code==429 || code==500 || code==503); tent++)
   {
      Print("IA [",model,"] ocupada (",code,") - tentando de novo");
      Sleep(tent==0?2000:5000); ArrayResize(res,0); ResetLastError();
      code=WebRequest("POST",endpoint,hdr,15000,data,res,rh);
   }
   if(code==-1){ g_aiLastErr="WebRequest bloqueado (erro "+IntegerToString(GetLastError())+")"; Print("IA [",model,"] ",g_aiLastErr,". Adicione o endereço do endpoint em Ferramentas > Opções > Expert Advisors."); return ""; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ g_aiLastErr=IntegerToString(code)+": "+StringSubstr(r,0,300); Print("IA [",model,"] respondeu ",g_aiLastErr); return ""; }
   string t=JContent(r); StringReplace(t,"**",""); StringTrimLeft(t); StringTrimRight(t);
   if(t==""){ g_aiLastErr="HTTP "+IntegerToString(code)+" sem content"; Print("IA [",model,"] ",g_aiLastErr); return ""; }
   return t;
}
// veto: com InpAIVeto ligado só opera se o VEREDITO for o lado do sinal (em AMBAS, divergência = ESPERAR = não opera)
bool AIVetou(string t,int dir){ if(!InpAIVeto || t=="") return false; return g_aiVeredito!=(dir==1?"COMPRA":"VENDA"); }
// mensagem amigável quando a IA não respondeu
string AIFalhaTxt()
{
   if(StringFind(g_aiLastErr,"429")==0) return "A IA grátis do Google tá no limite agora 😅 Espera 1 minutinho e me manda de novo.";
   if(StringFind(g_aiLastErr,"WebRequest")>=0) return "Não consegui falar com a IA: o MT5 bloqueou o acesso (WebRequest). Rode o INSTALAR.bat de novo com o MT5 fechado.";
   if(StringFind(g_aiLastErr,"5")==0) return "Os servidores da IA tão ocupados agora. Tenta de novo em 1 minuto 🙏";
   return "A IA não respondeu agora. Tenta de novo em 1 minuto.";
}
string AIStatus()
{
   if(!InpUseAI) return "IA: desligada";
   if(StringLen(g_cfgAIKey)<=10 && StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10) return "IA: coloque a chave Gemini em MQL5\\Files\\ALIEN_config.txt (gemini_chave_1=...) ou em InpAI2Key";
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
      { if(g_tr.PositionClose(t)) Notifica(StringFormat("Fechei o %s por horário/tempo.",_Symbol)); }
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
   if(PlanoValido(b))
      j+=StringFormat(",\"plano\":{\"valido\":true,\"dir\":\"%s\",\"nota\":%d,\"entrada\":%s,\"stop\":%s,\"alvo\":%s,\"rr\":%.2f,\"lote\":%.2f,\"risco_usd\":%.2f},\"criterios\":{%s}",
        b.dir==1?"compra":"venda",b.score,Fmt(b.entry),Fmt(b.stop),Fmt(b.target),b.rr,b.lot,b.riskUSD,pts);
   else
      j+=StringFormat(",\"plano\":{\"valido\":false,\"dir\":\"%s\",\"nota\":%d,\"motivo\":\"%s\",\"entrada\":null,\"stop\":null,\"alvo\":null,\"rr\":0},\"criterios\":{%s}",
        b.dir==1?"compra":"venda",b.score,JEsc(PlanoSemSetup(b.dir)),pts);
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
string HoraUTC3(){ return TimeToString((datetime)(TimeGMT()-3*3600),TIME_DATE|TIME_MINUTES); }
string TfSnap(string sym,ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,tf,0,300,r);
   string nm=StringSubstr(EnumToString(tf),7);
   if(n<80) return "{\"tf\":\""+nm+"\",\"tendencia\":0,\"ema_inclinacao\":0,\"atr\":0,\"ok\":false}";
   double k=2.0/51.0, e=r[n-1].close, ea1=0, ea4=0;
   for(int i=n-1;i>=0;i--){ e=(i==n-1)?r[i].close:r[i].close*k+e*(1-k); if(i==1) ea1=e; if(i==4) ea4=e; }
   double atr=ATRof(r,14,1);
   int slope=0;
   if(atr>0){ if(ea1-ea4>0.05*atr) slope=1; else if(ea4-ea1>0.05*atr) slope=-1; }
   int dir=TrendTFs(sym,tf);
   return StringFormat("{\"tf\":\"%s\",\"tendencia\":%d,\"ema_inclinacao\":%d,\"ema50\":%s,\"atr\":%s,\"ok\":true}",
      nm,dir,slope,Fmt(ea1),Fmt(atr));
}
string VolJSON()
{
   int n=ArraySize(g_r);
   if(n<22) return "{\"ok\":false}";
   double sum=0; for(int k=1;k<=20 && k<n;k++) sum+=(double)g_r[k].tick_volume;
   double avg=sum/20.0, v=(double)g_r[0].tick_volume, raz=(avg>0?v/avg:0);
   return StringFormat("{\"atual\":%.0f,\"media20\":%.0f,\"razao\":%.2f,\"forte\":%s,\"ok\":true}",v,avg,raz,raz>=2.0?"true":"false");
}
string News2hJSON()
{
   if(!CalOn()) return "[]";
   LoadNews(); datetime now=TimeTradeServer(); string out=""; int c=0;
   for(int i=0;i<ArraySize(g_news) && c<12;i++)
   {
      int m=(int)((g_news[i].t-now)/60);
      if(m<-5 || m>120) continue;
      string nm=g_news[i].nome; StringReplace(nm,"\\",""); StringReplace(nm,"\"","'");
      out+=(out==""?"":",")+StringFormat("{\"hora\":\"%s\",\"min\":%d,\"moeda\":\"%s\",\"impacto\":\"%s\",\"evento\":\"%s\"}",
         TimeToString(g_news[i].t,TIME_DATE|TIME_MINUTES),m,g_news[i].cur,ImpTxt(g_news[i].imp),nm);
      c++;
   }
   return "["+out+"]";
}
string NivelPorNome(string nome)
{
   for(int i=0;i<ArraySize(g_niv);i++)
      if(g_niv[i].nome==nome)
         return StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"estado\":\"%s\"}",JEsc(g_niv[i].nome),Fmt(g_niv[i].preco),
            g_niv[i].estado==ST_VARRIDA?"varrida":(g_niv[i].estado==ST_ROMPIDO?"rompido":"intacto"));
   return "null";
}
string VarridasJSON()
{
   string out=""; int c=0;
   for(int i=0;i<ArraySize(g_niv) && c<8;i++)
   {
      if(g_niv[i].estado!=ST_VARRIDA) continue;
      out+=(out==""?"":",")+StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"hora\":\"%s\"}",JEsc(g_niv[i].nome),Fmt(g_niv[i].preco),HHMM(g_niv[i].tSweep));
      c++;
   }
   return "["+out+"]";
}
string ChecklistJSON(const Plano &p)
{
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"}; string z="";
   for(int i=0;i<7;i++) z+=(i?",":"")+"\""+nm[i]+"\":"+(p.pts[i]?"true":"false");
   return "{"+z+"}";
}
string MemJSON()
{
   MemLoad(); string out="";
   int n=ArraySize(g_mem), st=MathMax(0,n-16);
   for(int i=st;i<n;i++) out+=(out==""?"":",")+"\""+JEsc(g_mem[i])+"\"";
   return "["+out+"]";
}
bool ContextValido(string j)
{
   if(StringLen(j)<30) return false;
   int p=StringFind(j,"\"bid\":"); if(p<0) p=StringFind(j,"\"preco\":");
   if(p<0) return false;
   int k=StringFind(j,":",p); if(k<0) return false;
   double v=StringToDouble(StringSubstr(j,k+1,24));
   return v>0;
}
bool ParseCmd(string text,string &cmd,string &args)
{
   StringTrimLeft(text); StringTrimRight(text);
   cmd=""; args="";
   if(text=="") return false;
   int sp=StringFind(text," ");
   string head=sp>0?StringSubstr(text,0,sp):text;
   args=sp>0?StringSubstr(text,sp+1):"";
   StringTrimLeft(args); StringTrimRight(args);
   int at=StringFind(head,"@"); if(at>0) head=StringSubstr(head,0,at);
   cmd=head; StringToLower(cmd);
   return StringLen(cmd)>0 && StringGetCharacter(cmd,0)=='/';
}

string AlvosLadoJSON(int dir,const Plano &p)
{
   string alvos="["; int na=0;
   double risk=MathAbs(p.entry-p.stop), minRR=RRMinAlvo();
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      if(g_niv[v].estado==ST_ROMPIDO) continue;
      double lv=g_niv[v].preco;
      bool ladoOk=(dir==1 && lv>p.entry) || (dir==-1 && lv<p.entry && p.entry>0) || (p.entry<=0 && ((dir==1 && g_niv[v].lado==NV_ABOVE)||(dir==-1 && g_niv[v].lado==NV_BELOW)));
      if(!ladoOk) continue;
      if(p.entry>0 && risk>0 && MathAbs(lv-p.entry)/risk+1e-12<minRR) continue;
      alvos+=(na?",":"")+StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"estado\":%d}",JEsc(g_niv[v].nome),Fmt(lv),g_niv[v].estado);
      na++; if(na>=6) break;
   }
   alvos+="]";
   if(!PlanoValido(p))
      return StringFormat("{\"valido\":false,\"motivo\":\"%s\",\"alvos_liquidez\":%s}",JEsc(PlanoSemSetup(dir)),alvos);
   return StringFormat("{\"valido\":true,\"entrada\":%s,\"entrada_poi\":\"%s\",\"stop\":%s,\"alvo\":%s,\"alvo_nome\":\"%s\",\"rr\":%.2f,\"alvos_liquidez\":%s}",
      Fmt(p.entry),JEsc(p.entNome),Fmt(p.stop),Fmt(p.target),JEsc(p.alvoNome),p.rr,alvos);
}
string AlvosLocaisJSON()
{
   return "{\"aviso\":\"niveis locais, alvo minimo 1.5R\",\"compra\":"+AlvosLadoJSON(1,g_pb)+",\"venda\":"+AlvosLadoJSON(-1,g_ps)+"}";
}
string PlanoCtxJSON(const Plano &p)
{
   if(!PlanoValido(p))
      return StringFormat("{\"valido\":false,\"motivo\":\"%s\",\"entrada\":null,\"stop\":null,\"alvo\":null,\"rr\":0}",JEsc(PlanoSemSetup(p.dir)));
   return StringFormat("{\"valido\":true,\"entrada\":%s,\"stop\":%s,\"alvo\":%s,\"alvo_nome\":\"%s\",\"poi\":\"%s\",\"lote\":%.2f,\"risco_usd\":%.2f,\"rr\":%.2f}",
      Fmt(p.entry),Fmt(p.stop),Fmt(p.target),JEsc(p.alvoNome),JEsc(p.entNome),p.lot,p.riskUSD,p.rr);
}
string ContextJSON()
{
   Plano b=MelhorPlano();
   string j=StateJSON(b);
   j=StringSubstr(j,0,StringLen(j)-1);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0 || ask<=0) return "";
   string st; SessaoNota(TimeTradeServer(),st);
   j+=StringFormat(",\"bid\":%s,\"ask\":%s,\"preco\":%s,\"spread\":%s",Fmt(bid),Fmt(ask),Fmt(bid),Fmt(ask-bid));
   j+=",\"hora_servidor\":\""+TimeToString(TimeTradeServer(),TIME_DATE|TIME_MINUTES)+"\",\"hora_utc3\":\""+HoraUTC3()+"\"";
   j+=StringFormat(",\"sessao\":\"%s\",\"vies_dia\":\"%s\",\"tendencia_txt\":\"%s\"",JEsc(st),JEsc(g_biasTxt),JEsc(g_trendTxt));
   j+=",\"tendencias_detalhe\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+TfSnap(_Symbol,g_mtfTF[i]);
   j+="}";
   j+=",\"liquidez\":{\"PDH\":"+NivelPorNome("Máxima de ontem")+",\"PDL\":"+NivelPorNome("Mínima de ontem")+",\"asia_max\":"+NivelPorNome("Máxima da Ásia")+",\"asia_min\":"+NivelPorNome("Mínima da Ásia")+",\"londres_max\":"+NivelPorNome("Máxima de Londres")+",\"londres_min\":"+NivelPorNome("Mínima de Londres")+"}";
   j+=",\"varridas_recentes\":"+VarridasJSON();
   j+=StringFormat(",\"nota_compra\":%d,\"nota_venda\":%d,\"checklist_compra\":%s,\"checklist_venda\":%s",g_pb.score,g_ps.score,ChecklistJSON(g_pb),ChecklistJSON(g_ps));
   j+=",\"plano_compra\":"+PlanoCtxJSON(g_pb);
   j+=",\"plano_venda\":"+PlanoCtxJSON(g_ps);
   j+=",\"alvos_locais\":"+AlvosLocaisJSON();
   j+=",\"fvg_"+StringSubstr(EnumToString(InpTFExec),7)+"\":"+FVGJson(g_fvg,4)+",\"fvg_M15\":"+FVGJson(g_fvgM15,3)+",\"fvg_H1\":"+FVGJson(g_fvgH1,3);
   j+=",\"volume\":"+VolJSON();
   j+=",\"noticias\":"+NewsJSON()+",\"noticias_2h\":"+News2hJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\"";
   j+=",\"posicoes_abertas\":"+PosJSON();
   j+=",\"conversa_recente\":"+MemJSON()+",\"fatos_do_vitor\":"+FatosJSON();
   j+=",\"historico_veredictos\":"+VereditoStatsJSON();
   j+=",\"motor\":"+EngineJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"},\"robo\":{\"opera\":%s,\"status\":\"%s\",\"pausa_dd\":%s,\"pausa_tg\":%s}}",
        g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare),TradeAtivo()?"true":"false",JEsc(g_status),g_ddPause?"true":"false",g_tradePausa?"true":"false");
   return j;
}
bool EhPedidoAnalise(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   if(StringFind(u,"analis")>=0) return true;
   if(StringFind(u,"/plano")>=0) return true;
   if(StringFind(u,"qual o plano")>=0 || StringFind(u,"cade o plano")>=0 || StringFind(u,"me da o plano")>=0 || StringFind(u,"mostra o plano")>=0 || StringFind(u,"ver o plano")>=0) return true;
   { int pe=StringFind(u,"entro"); if(pe>=0 && (pe==0 || StringGetCharacter(u,pe-1)!='d')) return true; }
   if(StringFind(u,"entrar")>=0 || StringFind(u,"vale compr")>=0 || StringFind(u,"vale vend")>=0) return true;
   if(StringFind(u,"posso compr")>=0 || StringFind(u,"posso vend")>=0 || StringFind(u,"posso entr")>=0) return true;
   return false;
}
bool EhReclamaRepete(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   if(StringFind(u,"repet")>=0) return true;
   if(StringFind(u,"mesmo bloco")>=0 || StringFind(u,"mesmo texto")>=0 || StringFind(u,"de novo o mesmo")>=0) return true;
   return false;
}
bool EhSoNoticia(string t)
{
   if(EhPedidoAnalise(t)) return false;
   string u=t; StringToLower(u); u=AISemAcento(u);
   return StringFind(u,"notic")>=0;
}
datetime g_edgeAvisado=0;
string AvisoEdgeLinha(){ return "No teste 2016-2025 os sinais automáticos nota>=7 não tiveram edge."; }
string SemAvisoEdge(string t)
{
   string ls[]; int n=StringSplit(t,'\n',ls); string o="";
   for(int i=0;i<n;i++)
   {
      string u=ls[i]; StringToLower(u); u=AISemAcento(u);
      if(StringFind(u,"2016-2025")>=0) continue;
      if(StringFind(u,"nao tiveram edge")>=0) continue;
      o+=(o==""?"":"\n")+ls[i];
   }
   return o;
}
string EdgeSePreciso(string t)
{
   t=SemAvisoEdge(t);
   if(g_edgeAvisado>0 && TimeCurrent()-g_edgeAvisado<3600) return t;
   g_edgeAvisado=TimeCurrent();
   return t+"\n\n"+AvisoEdgeLinha();
}
string SemCamposCrus(string t)
{
   StringReplace(t,"plano_compra:","Se for comprar:");
   StringReplace(t,"plano_venda:","Se for vender:");
   StringReplace(t,"alvos_locais:","Alvos no gráfico:");
   StringReplace(t,"plano_compra","plano de compra");
   StringReplace(t,"plano_venda","plano de venda");
   StringReplace(t,"alvos_locais","alvos no gráfico");
   return t;
}
bool TemBlocoRobo(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   int hits=0;
   if(StringFind(u,"plano de compra")>=0 || StringFind(u,"se for comprar")>=0) hits++;
   if(StringFind(u,"plano de venda")>=0 || StringFind(u,"se for vender")>=0) hits++;
   if(StringFind(u,"o que fazer agora")>=0) hits++;
   if(StringFind(u,"alvos no grafico")>=0) hits++;
   return hits>=2;
}
bool LinhaDePlano(string linha)
{
   string u=linha; StringToLower(u); u=AISemAcento(u); StringToLower(u); StringTrimLeft(u);
   // tira emoji/marcadores do começo
   while(StringLen(u)>0){ ushort c=StringGetCharacter(u,0); if((c>='a'&&c<='z')||(c>='0'&&c<='9')) break; u=StringSubstr(u,1); }
   string k[]={"se for comprar","se for vender","plano de compra","plano de venda","o que fazer agora","alvos no grafico","cenario compra","cenario venda","compra:","venda:"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])==0) return true;
   return false;
}
// posição (no texto minúsculo) onde começa o bloco de plano; 0 = a resposta já começa com o plano
int CorteBloco(const string u)
{
   string k[]={"se for comprar","se for vender","plano de compra","plano de venda","o que fazer agora","alvos no grafico","macro ta "};
   int best=-1;
   for(int i=0;i<ArraySize(k);i++)
   {
      int p=StringFind(u,"\n"+k[i]);
      if(StringFind(u,k[i])==0) p=0;
      if(p>=0 && (best<0 || p<best)) best=p;
   }
   return best;
}
string SoRespostaCurta(string t,string pergunta="")
{
   t=SemAvisoEdge(t);
   t=SemCamposCrus(t);
   t=AISemVeredito(t);
   StringTrimLeft(t); StringTrimRight(t);
   bool soNot=EhSoNoticia(pergunta), rep=EhReclamaRepete(pergunta);
   bool cortar=TemBlocoRobo(t) || soNot || rep;
   if(!cortar) return t;
   // mantém as linhas de conversa; pula o plano do começo e para no primeiro bloco de plano depois
   string ls[]; int n=StringSplit(t,'\n',ls); string o=""; bool conteudo=false;
   for(int i=0;i<n;i++)
   {
      string x=ls[i]; string xt=x; StringTrimLeft(xt); StringTrimRight(xt);
      if(xt=="") continue;
      string ux=xt; StringToLower(ux); ux=AISemAcento(ux); StringToLower(ux);
      bool plano=LinhaDePlano(xt) || ((soNot||rep) && StringFind(ux,"macro")==0);
      if(plano){ if(conteudo) break; else continue; }
      o+=(o==""?"":"\n")+xt; conteudo=true;
   }
   if(o=="") o="Sem novidade além do plano. Se quiser ver, toca em 🧭 Plano.";
   return o;
}
string SysChatLivre()
{
   return "Você é o ALIEN, um colega de trading no WhatsApp. Português do Brasil, informal, frases curtas, gíria leve sem forçar. "
          "Responda SOMENTE o que foi perguntado, em 1 a 4 frases. Poucos emoji, só se couber. Sem markdown. "
          "Não monte plano, não liste compra e venda, não cite entrada/stop/alvo se não pediram, não feche com VEREDITO, não use cabeçalho. "
          "Nunca escreva nomes crus de campo (plano_compra, plano_venda, alvos_locais). Se um dia citar um setup, fale assim: 'Se for comprar: entra em X, stop Y, alvo Z (vale 2.2x o risco)'. "
          "Use SÓ os números do CONTEXTO; nunca invente preço, stop, alvo ou horário. Horários sempre em Brasília (use hora_utc3 e hora_brasilia das notícias). "
          "A conversa recente já está no contexto: não repita o que você já disse. Se o Vitor reclamar de repetição, não peça desculpa e cole o mesmo bloco — mude o comportamento e responda só o que falta, de outro jeito, bem curto. "
          "Varie a abertura. Não comece com 'Fala mano' nem com 'ALIEN PROFESSOR:'. "
          "Nunca mencione o teste 2016-2025 nem diga que os sinais não tiveram edge neste tipo de resposta. "
          "Nunca prometa lucro.";
}
string SysChatAnalise()
{
   return "Você é o ALIEN, um colega de trading brasileiro (SMC/liquidez). Fale informal, frases curtas, gíria leve (mano, bora, segura a mão, preço tá esticado) sem forçar. Português do Brasil. "
          "Use SÓ os números do CONTEXTO; nunca invente preço, stop, alvo ou horário. Horários sempre em Brasília (hora_utc3 / hora_brasilia). Sem markdown. No máximo 900 caracteres. "
          "Não use rótulos robóticos nem nomes crus de campo (plano_compra, plano_venda, alvos_locais). "
          "Fale natural, tipo: 'Macro tá vendido (D1/H4/H1 pra baixo), M1 tentando subir.' "
          "Em seguida, em poucas linhas: se tem setup de compra, escreva 'Se for comprar: entra em X, stop Y, alvo Z (vale 2.2x o risco)'; se tem de venda, o mesmo; o que fazer agora; um risco (notícia, horário, spread). "
          "Alvo só vale com no mínimo 1,5R e do lado certo (compra: stop < entrada < alvo; venda: alvo < entrada < stop). Use os planos e alvos do contexto (campos internos, não imprima os nomes). Se não tiver alvo válido, diga que não tem setup naquele lado. "
          "Feche com uma linha VEREDITO: COMPRA ou VENDA ou ESPERAR (pode usar 🟢 🔴 🟡 junto, mas as palavras COMPRA/VENDA/ESPERAR têm que aparecer). Pode usar emoji úteis: 🟢 compra, 🔴 venda, 🟡 esperar, 💧 liquidez, ⚡ volume forte, 🎯 alvo, 🛑 stop, 📰 notícia. "
          "Varie a abertura. Não comece sempre com 'Fala mano'. Não repita a conversa recente. "
          "Nunca prometa lucro. Se faltar dado, ESPERAR. Não mencione o teste 2016-2025; isso é acrescentado à parte.";
}
string SysChat(){ return SysChatAnalise(); }
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
   int st=MathMax(0,ArraySize(g_mem)-16);
   int h=FileOpen("ALIEN_chat_memoria.txt",FILE_WRITE|FILE_TXT|FILE_UNICODE); if(h==INVALID_HANDLE) return;
   for(int i=st;i<ArraySize(g_mem);i++) FileWriteString(h,g_mem[i]+"\r\n");
   FileClose(h);
}
string MemTxt(){ MemLoad(); string fz=FatosTxt(); if(ArraySize(g_mem)==0) return fz; string s=fz+"CONVERSA RECENTE (mais antiga primeiro):\n"; for(int i=0;i<ArraySize(g_mem);i++) s+=g_mem[i]+"\n"; return s+"\n"; }

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
// no texto livre, não aceitar palavra comum (ex.: "vale comprar") só porque existe um ticker homônimo
bool PareceTicker(string u)
{
   int n=StringLen(u); if(n<3) return false;
   for(int i=0;i<n;i++){ ushort c=StringGetCharacter(u,i); if(c>='0' && c<='9') return true; }
   if(n>=6) return true;
   return StringFind(u,"USD")>=0 || StringFind(u,"EUR")>=0 || StringFind(u,"GBP")>=0 || StringFind(u,"JPY")>=0
       || StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0 || StringFind(u,"BTC")>=0 || StringFind(u,"CASH")>=0;
}
bool TemCotacao(string sym)
{
   if(!SymOk(sym)) return false;
   SymbolSelect(sym,true);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID);
   for(int i=0;i<8 && bid<=0;i++){ Sleep(100); bid=SymbolInfoDouble(sym,SYMBOL_BID); }
   if(bid<=0) return false;
   MqlRates r[]; return CopyRates(sym,PERIOD_D1,0,1,r)==1 || CopyRates(sym,PERIOD_M1,0,1,r)==1;
}
string SimboloDe(string t,bool busca)
{
   string u=t; StringToUpper(u); if(StringLen(u)<3) return "";
   bool alias=false;
   if(u=="OURO"||u=="GOLD"||u=="XAU") { u="XAUUSD"; alias=true; }
   if(u=="NASDAQ"||u=="NAS"||u=="NAS100"||u=="US100"||u=="USTEC") { u="USTECH"; alias=true; }
   if(u=="SP500"||u=="SP"||u=="S&P"||u=="SPX") { u="US500"; alias=true; }
   if(u=="DAX"||u=="GER40"||u=="ALEMANHA") { u="DE40"; alias=true; }
   if(!busca && !alias && !PareceTicker(u)) return "";
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
void ChatIA(string pergunta,string titulo,string sym="",ENUM_TIMEFRAMES tf=PERIOD_CURRENT,bool exigirAlvo=false,bool forcarPlano=false)
{
   bool plano = forcarPlano || EhPedidoAnalise(pergunta);
   bool mercado = (plano || sym!="" || tf!=PERIOD_CURRENT || EhMercado(pergunta));
   bool soNoticia=EhSoNoticia(pergunta);
   // assunto que não é mercado: conversa geral (qualquer tema), sem o contexto do gráfico
   if(!mercado && AIOn()){ ChatGeral(pergunta); return; }
   if(sym=="" && tf!=PERIOD_CURRENT) sym=_Symbol;
   if(sym!="" && tf==PERIOD_CURRENT) tf=InpTFExec;
   // texto livre: sempre o contexto cheio do gráfico. só troca/acrescenta foco se o alvo tiver cotação.
   string ctx=ContextJSON();
   bool fotoAlvo=false;
   if(sym!="")
   {
      if(!TemCotacao(sym))
      {
         Print("Telegram: sem cotação de ",sym," - uso o contexto de ",_Symbol);
         if(exigirAlvo){ SendMsg("Não achei cotação de "+sym+" "+TfNome(tf)+". Confere o nome no Market Watch e tenta de novo."); return; }
         sym=""; tf=PERIOD_CURRENT;
      }
      else
      {
         string foco=TFContextJSON(sym,tf);
         if(sym==_Symbol) ctx=foco;             // já inclui professor_do_grafico
         else ctx="{\"professor_do_grafico\":"+ctx+",\"foco\":"+foco+"}";
         fotoAlvo=true;
      }
   }
   if(!ContextValido(ctx))
   {
      SendMsg("Agora não veio cotação do gráfico. Abre o "+_Symbol+" e manda de novo.");
      return;
   }
   if(!AIOn())
   {
      if(!plano)
      {
         if(soNoticia){ SendMsg(NoticiasTxt()); return; }
         SendMsg("A IA tá desligada agora (falta chave ou WebRequest). Se quiser a leitura do gráfico, manda /analise ou /plano. Notícias: /noticias.");
         return;
      }
      Plano b=MelhorPlano();
      SendMsg("A IA tá desligada agora (falta chave ou WebRequest). Segue a leitura do gráfico:\n"+EdgeSePreciso(Narrativa(b,g_pare!=""||NoticiaAviso(TimeTradeServer())!="",NoticiaAviso(TimeTradeServer()))));
      if(fotoAlvo) FotoTF(sym,tf,sym+" "+TfNome(tf)); else TgFoto(FotoLegenda());
      return;
   }
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma, a IA tá no limite. Tenta de novo em %d s.",w)); return; }
   string sys=plano?SysChatAnalise():SysChatLivre();
   if(EhReclamaRepete(pergunta)) sys+=" O Vitor reclamou que você está repetindo. NÃO peça desculpa e cole o mesmo texto. Responda só o que falta, de outro jeito, bem curto.";
   int tok=plano?600:350;
   double temp=plano?0.2:0.6;
   string r=AIAskEx(sys,MemTxt()+"CONTEXTO DO MERCADO:\n"+ctx+"\n\nMENSAGEM DO VITOR:\n"+pergunta,tok,false,plano,temp);
   if(r==""){ SendMsg(AIFalhaTxt()); return; }
   r=SemCamposCrus(r);
   if(plano) r=EdgeSePreciso(r);
   else r=SoRespostaCurta(r,pergunta);
   if(plano && StringLen(r)>900)
   {
      string tail="";
      int pv=StringFind(r,"VEREDITO"); if(pv>=0) tail=StringSubstr(r,pv);
      int keep=900-StringLen(tail)-5; if(keep<350) keep=350;
      r=StringSubstr(r,0,keep)+"\n...\n"+tail;
   }
   if(plano) VereditoLog("chat");
   FatoTalvez(pergunta); MemAdd("Vitor",pergunta); MemAdd("Alier",r);
   if((sym=="" || sym==_Symbol) && plano) AIPanelSet(r);
   string msg=r;
   if(titulo!="") msg=titulo+"\n"+r;
   if(plano) msg+="\n\n(opinião — quem decide é você)";
   SendMsg(msg);
   if(plano || (mercado && !soNoticia && !EhReclamaRepete(pergunta)))
   {
      if(sym!="") FotoTF(sym,tf,sym+" "+TfNome(tf)+" às "+TimeToString(AgoraBR(),TIME_MINUTES)+" (Brasília)");
      else TgFoto(FotoLegenda());
   }
}
#ifndef APROF_VER
#define APROF_VER "1.00"
#endif
string RoboIdent()
{
   string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
   string nome=MQLInfoString(MQL_PROGRAM_NAME);
   if(nome=="") nome="ALIEN_PROFESSOR_AUTO";
   return StringFormat("%s v%s | %s %s | magic %I64d",nome,APROF_VER,_Symbol,tf,InpMagic);
}
string StatusTxt()
{
   string s="👽 Alier versão "+APROF_VER+", ligado às "+g_ligadoBR+" (Brasília).\n"+StringFormat("Status do %s.\nTá %s, conta %s.\nRobô: %s\n",_Symbol,TradeAtivo()?"operando":(g_tradePausa?"pausado (/pausa)":"no modo assistente (não opera)"),
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",RoboIdent());
   s+=StringFormat("Saldo $%.2f, equity $%.2f.\n",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   s+=StringFormat("Hoje: %d trades, %d stops (máx %d), resultado $%+.2f (meta $%.0f / perda máx $%.0f).\n",g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD);
   s+="Disciplina: "+(g_pare!=""?g_pare:"tranquilo, pode operar")+(g_ddPause?" | pausei pelo DD":"")+"\n";
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") s+=nw+"\n";
   int np=0; string ps="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue; np++;
      ps+=StringFormat("  %s %s %.2f lote @%s  P/L $%+.2f%s\n",PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",
          PositionGetDouble(POSITION_VOLUME),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS)),
          PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?" (robô)":" (manual)");
   }
   s+=(np==0?"Nenhuma posição aberta.\n":("Posição aberta:\n"+ps));
   Plano b=MelhorPlano();
   s+=StringFormat("Nota do momento: %s %d/10 (do outro lado %d/10).\n",b.dir==1?"🟢 COMPRA":"🔴 VENDA",b.score,b.dir==1?g_ps.score:g_pb.score);
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   s+=StringFormat("No histórico (%s): %d trades, acerto %.0f%%, R médio %+.2f.\n",_Symbol,n,w,a);
   string fx[4]={"0-4","5-6","7-8","9-10"};
   for(int f=0;f<4;f++){ int nn; double ww,aa; HStat(fx[f],0,"",nn,ww,aa); if(nn>0) s+=StringFormat("  nota %s: %d trades, acerto %.0f%%, R %+.2f\n",fx[f],nn,ww,aa); }
   s+="Trava do histórico: "+(InpAprenderDesativar?"ligada":"desligada")+".";
   return s;
}
string NoticiasTxt()
{
   LoadNews(true);
   return "📰 Notícias na frente ("+InpCalMoedas+", horário de Brasília; 🔴 forte, 🟡 média):\n"+NewsListaBR(10,"\n")+
          (InpCalBloquearForte?StringFormat("\n\nEm notícia forte eu não entro %d min antes e depois.",InpNoticiaMin):"");
}
string AjudaTxt()
{
   return "Oi! Eu sou o Alier 👽 (versão "+APROF_VER+", "+_Symbol+").\n"
          "Os botões aqui embaixo fazem o principal. Também entendo:\n"
          "/analise [símbolo] [tempo] - eu olho o gráfico com a IA e mando o print\n"
          "/plano - compra e venda como estão agora\n"
          "/niveis - máxima e mínima de ontem, Ásia, Londres e varridas\n"
          "/diario - o que rolou hoje, em português\n"
          "/aprendizado - como as leituras e a sua disciplina estão indo\n"
          "/alerta <preço> - te aviso quando o preço passar\n"
          "/pausa e /retoma - paro ou volto a mandar ordem (eu confirmo antes)\n"
          "/risco - limites de agora (eu não mudo nada sozinho)\n"
          "/status - versão, posição, resultado do dia\n"
          "/noticias - próximas notícias (Brasília)  |  /agenda - só as de hoje\n"
          "/foto - print com uma explicação curtinha\n"
          "/memoria - o que eu lembro de você  |  /esquece - apago\n"
          "Pode escrever sobre qualquer assunto, mandar áudio 🎤 ou foto 📷 (até print de gráfico de outro lugar). Eu também te aviso sozinho quando varrer liquidez, mudar a estrutura ou chegar num bloco importante.";
}
void TgHandle(string chat,string text)
{
   StringTrimLeft(text); StringTrimRight(text); if(text=="") return;
   string cmd,args; bool iscmd=ParseCmd(text,cmd,args);
   if(g_cfgTgChat=="")
   {
      if(cmd=="/start")
      {
         // grava o chat id sozinho no ALIEN_config.txt: não precisa configurar nada
         CfgSalva("telegram_chat_id",chat); g_cfgTgChat=chat; g_tgHint="";
         Print("ALIEN: chat id salvo em MQL5\\Files\\ALIEN_config.txt");
         SendMsgKb("Pronto, te conectei 👽 Agora eu só respondo este chat. Manda /ajuda ou usa os botões.");
      }
      return;
   }
   if(chat!=g_cfgTgChat){ Print("Telegram: ignorei mensagem de um chat não autorizado (",chat,")"); return; }
   if(!iscmd){ string bc=BotaoCmd(text); if(bc!=""){ cmd=bc; args=""; iscmd=true; } }
   Print("Telegram: comando ",cmd!=""?cmd:"(texto livre)");
   if(!iscmd && DisciplinaMotivo(text)) return;
   if(cmd=="/start" || cmd=="/ajuda" || cmd=="/help"){ SendMsgKb(AjudaTxt()); return; }
   if(cmd=="/status"){ SendMsg(StatusTxt()); return; }
   if(cmd=="/noticias" || cmd=="/notícias"){ SendMsg(NoticiasTxt()); return; }
   if(cmd=="/foto"){ if(!TgFoto(FotoLegenda())) SendMsg("Não rolou o print agora."); return; }
   if(cmd=="/agenda"){ SendMsg(AgendaTxt()); return; }
   if(cmd=="/memoria" || cmd=="/memória"){ SendMsg(MemoriaTxt()); return; }
   if(cmd=="/esquece"){ MemoriaApaga(); SendMsg("Pronto, apaguei o que eu lembrava. Começo do zero 🙂"); return; }
   if(cmd=="/disc"){ DisciplinaResposta(args); return; }
   if(cmd=="/cancela"){ SendMsg("Beleza, deixei como estava."); return; }
   if(cmd=="/plano"){ SendMsg(EdgeSePreciso(PlanoTxt())); return; }
   if(cmd=="/niveis" || cmd=="/níveis"){ SendMsg(NiveisTxt()); return; }
   if(cmd=="/diario" || cmd=="/diário"){ SendMsg(DiarioTxt()); return; }
   if(cmd=="/aprendizado"){ SendMsg(AprendizadoTxt()); return; }
   if(cmd=="/risco"){ SendMsg(RiscoTxt()); return; }
   if(cmd=="/pausa"){ PedeConfirmaPausa(true); return; }
   if(cmd=="/retoma"){ PedeConfirmaPausa(false); return; }
   if(cmd=="/pausa_ok"){ g_tradePausa=true; PausaSave(); SendMsg("Pausei as ordens. Os avisos continuam aqui. Quando quiser voltar, manda /retoma."); return; }
   if(cmd=="/retoma_ok"){ g_tradePausa=false; PausaSave(); SendMsg(InpTradeEnabled?"Fechei a pausa. Tô operando de novo, dentro dos limites.":"O InpTradeEnabled tá false (modo assistente). /retoma não liga a operação sozinho — muda isso no MT5 se quiser que eu opere."); return; }
   if(cmd=="/alerta")
   {
      double px=StringToDouble(args);
      if(px<=0) SendMsg("Manda assim: /alerta 3870  (preço maior que zero). Alertas ativos: "+AlertaLista());
      else { AlertaAdd(px); SendMsg("Beleza, alerta em "+Fmt(px)+" salvo. Ativos: "+AlertaLista()); }
      return;
   }
   if(cmd=="/analise" || cmd=="/análise")
   {
      string asy; ENUM_TIMEFRAMES atf;
      if(args!="" && ParseAlvo(args,true,asy,atf))
      {
         if(asy=="") asy=_Symbol; if(atf==PERIOD_CURRENT) atf=InpTFExec;
         SendMsg("Deixa eu olhar o "+asy+" "+TfNome(atf)+"...");
         ChatIA("Olha o "+asy+" no "+TfNome(atf)+" com os números do contexto, no seu estilo informal, e fecha com VEREDITO.","ANÁLISE "+asy+" "+TfNome(atf),asy,atf,true,true);
         return;
      }
      if(args!=""){ SendMsg("Não achei esse símbolo/tempo. Exemplos: /analise H4  |  /analise XAUUSD M15  |  /analise US500 H1"); return; }
      SendMsg("Deixa eu olhar o "+_Symbol+"..."); ChatIA("Olha o gráfico de agora com os números do contexto, no seu estilo informal, e fecha com VEREDITO.","ANÁLISE "+_Symbol,"",PERIOD_CURRENT,false,true); return;
   }
   if(iscmd){ SendMsg("Não peguei esse comando.\n\n"+AjudaTxt()); return; }
   if(EhSoNoticia(text)){ MemAdd("Vitor",text); SendMsg(NoticiasTxt()); return; }
   string fsy; ENUM_TIMEFRAMES ftf;
   if(ParseAlvo(text,false,fsy,ftf)) ChatIA(text,"",fsy,ftf);
   else ChatIA(text,"");
}
void TgPoll()
{
   if(!TgTokenOk() || !InpTgChat) return;
   g_tgMaster=TgMaster(); if(!g_tgMaster) return;
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/getUpdates?timeout=0&limit=20&offset="+IntegerToString(g_tgOff);
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",5000,data,res,rh);
   if(code==-1){ if(g_tgErrPrint++%60==0) Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ if(g_tgErrPrint++%60==0) Print("Telegram getUpdates respondeu ",code,code==409?" (o bot tem webhook ou outro programa lendo - só um pode ler)":(code==401?" (token inválido - crie um novo no @BotFather)":""),": ",StringSubstr(r,0,200)); return; }
   int pos=0; bool mudou=false;
   while(true)
   {
      int k=StringFind(r,"\"update_id\":",pos); if(k<0) break;
      int nx=StringFind(r,"\"update_id\":",k+12);
      string seg= nx>0 ? StringSubstr(r,k,nx-k) : StringSubstr(r,k);
      long uid=StringToInteger(JNumKey(seg,"update_id"));
      if(uid>=g_tgOff){ g_tgOff=uid+1; mudou=true; }
      pos= nx>0 ? nx : StringLen(r);
      int cpos=StringFind(seg,"\"chat\":"); if(cpos<0) continue;
      string chat=JNumKey(seg,"id",cpos);
      string text="";
      if(StringFind(seg,"\"callback_query\"")>=0)
      {
         // botão apertado: vale mesmo se a mensagem do botão for antiga
         text=JStrKey(seg,"data");
         TgAckCb(JStrKey(seg,"id"));
      }
      else
      {
         long dt=StringToInteger(JNumKey(seg,"date"));
         if(dt>0 && dt<(long)g_tgStartUtc-120) continue;     // mensagem velha (antes do robô ligar)
         int fp=StringFind(seg,"\"photo\":[");
         if(fp>=0)
         {
            // a última versão da foto é a maior
            string ph=StringSubstr(seg,fp); int fe=StringFind(ph,"]"); if(fe>0) ph=StringSubstr(ph,0,fe);
            string fid=""; int q=0; while(true){ int z=StringFind(ph,"\"file_id\":\"",q); if(z<0) break; fid=JDecode(ph,z+10); q=z+1; }
            if(chat==g_cfgTgChat && fid!=""){ if(mudou) TgEstadoSave(); mudou=false; FotoHandle(chat,fid,JStrKey(seg,"caption")); }
            continue;
         }
         int vp=StringFind(seg,"\"voice\":{");
         if(vp>=0)
         {
            string fid=JStrKey(StringSubstr(seg,vp),"file_id");
            if(chat==g_cfgTgChat && fid!=""){ if(mudou) TgEstadoSave(); mudou=false; VozHandle(chat,fid); }
            continue;
         }
         text=JStrKey(seg,"text");
      }
      if(chat!="" && text!=""){ if(mudou) TgEstadoSave(); mudou=false; TgHandle(chat,text); }
   }
   if(mudou) TgEstadoSave();
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
      g_alertados+=IntegerToString((long)g_news[i].id)+"|"; TgEstadoSave();
      SendMsg(StringFormat("📰 Atenção: notícia forte de %s daqui a %d min (às %s, Brasília): %s.%s",g_news[i].cur,(int)(d/60)+1,HHMMBR(g_news[i].t),g_news[i].nome,
              InpCalBloquearForte?StringFormat(" Eu não entro %d min antes/depois. Segura a mão nas posições.",InpNoticiaMin):""));
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
      string key=TimeToString(now,TIME_DATE)+_Symbol+nomes[i]+"|"; if(StringFind(g_resFeitos,key)>=0) continue;
      g_resFeitos+=key; TgEstadoSave();
      Plano b=MelhorPlano();
      string r="";
      string ctx=ContextJSON();
      if(AIOn() && ContextValido(ctx)) r=AIAskEx(SysChatAnalise(),"CONTEXTO:\n"+ctx+"\n\nMENSAGEM: resumo informal da abertura de "+nomes[i]+", fecha com VEREDITO.",600,true,true,0.2);
      if(r=="") r=Narrativa(b,g_pare!="",NoticiaAviso(now))+"\nNotícias (Brasília): "+NewsListaBR(4," | ");
      else { r=SemAvisoEdge(SemCamposCrus(r)); AIPanelSet(r); VereditoLog("resumo"); }
      SendMsg("Abertura de "+nomes[i]+" no "+_Symbol+"\n"+r);
      TgFoto(FotoLegenda());
   }
}

//====================================================================
// Aprendizado honesto + alertas + comandos extras do Telegram
// Nunca altera sozinho os parâmetros do robô — só sugere.
//====================================================================
bool     g_tradePausa=false;
datetime g_lastAlertaChk=0;
double   g_prevBid=0;
string   g_alertaArq="ALIEN_alertas.csv";
string   g_verArq="ALIEN_veredictos.csv";
string   g_pausaArq="ALIEN_pausa.txt";
string   g_verHdr="hora;simbolo;bid;veredito;sessao;d1;h4;h1;m15;m5;m1;nota;pts;entrada;stop;res15;res60;origem";

bool TradeAtivo(){ return InpTradeEnabled && !g_cfgAssistente && !g_tradePausa; }

void PausaLoad()
{
   g_tradePausa=false;
   int h=FileOpen(g_pausaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string s=FileReadString(h); FileClose(h);
   StringTrimLeft(s); StringTrimRight(s);
   g_tradePausa=(s=="1"||s=="true"||s=="PAUSA");
}
void PausaSave()
{
   int h=FileOpen(g_pausaArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,g_tradePausa?"1":"0"); FileClose(h);
}

bool SendJsonMsg(string chat,string text,string markup)
{
   if(!TgTokenOk() || chat=="") return false;
   if(StringLen(text)>3900) text=StringSubstr(text,0,3900)+"...";
   string body="{\"chat_id\":\""+JEsc(chat)+"\",\"text\":\""+JEsc(text)+"\"";
   if(markup!="") body+=",\"reply_markup\":"+markup;
   body+="}";
   uchar utf8[]; char data[],res[]; string rh;
   int n=StringToCharArray(body,utf8,0,WHOLE_ARRAY,CP_UTF8);
   if(n<=0) return false;
   if(utf8[n-1]==0) n--;
   if(n<=0) return false;
   ArrayResize(data,n);
   for(int i=0;i<n;i++) data[i]=(char)utf8[i];
   ResetLastError();
   int code=WebRequest("POST","https://api.telegram.org/bot"+g_cfgTgToken+"/sendMessage","Content-Type: application/json\r\n",8000,data,res,rh);
   if(code==-1){ Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),")"); return false; }
   if(code!=200) Print("Telegram respondeu ",code,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
   return code==200;
}
bool SendMsgKb(string text){ if(!TgOk()) return false; return SendJsonMsg(g_cfgTgChat,text,TgKbFixo()); }
bool SendMsgMarkup(string text,string markup){ if(!TgOk()) return false; return SendJsonMsg(g_cfgTgChat,text,markup); }
void TgAckCb(string qid)
{
   if(!TgTokenOk() || qid=="") return;
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/answerCallbackQuery";
   string body="callback_query_id="+UrlEnc(qid);
   char data[],res[]; string rh; StringToCharArray(body,data,0,StringLen(body));
   WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",5000,data,res,rh);
}

string PlanoLadoTxt(const Plano &p,string lado)
{
   if(!PlanoValido(p)) return PlanoSemSetup(p.dir);
   string ck=""; string nm[7]={"tendência","varrida","rompimento","vazio de preço","volume","horário","alvo 2R"};
   for(int i=0;i<7;i++) ck+=(i?", ":"")+(p.pts[i]?"[x] ":"[ ] ")+nm[i];
   return StringFormat("%s, nota %d/10.\nEntrada %s, 🛑 stop %s, 🎯 alvo %s (%.2fR). Lote %.2f, risco $%.2f.\nChecklist: %s",
      lado,p.score,Fmt(p.entry),Fmt(p.stop),Fmt(p.target),p.rr,p.lot,p.riskUSD,ck);
}
string PlanoTxt()
{
   return "Bora olhar o plano do "+_Symbol+" agora:\n"+PlanoLadoTxt(g_pb,"🟢 COMPRA")+"\n\n"+PlanoLadoTxt(g_ps,"🔴 VENDA")+"\n\nNúmeros do professor — quem manda é você.";
}
string NiveisTxt()
{
   string s="Níveis do "+_Symbol+" agora:\n";
   int n=ArraySize(g_niv);
   if(n<=0) return s+"Ainda não calculei os níveis.";
   for(int i=0;i<n;i++)
   {
      string est=g_niv[i].estado==ST_VARRIDA?"VARRIDA":(g_niv[i].estado==ST_ROMPIDO?"rompido":"intacto");
      s+=StringFormat("%s  %s  %s%s\n",g_niv[i].nome,Fmt(g_niv[i].preco),est,
         g_niv[i].estado==ST_VARRIDA && g_niv[i].tSweep>0?" "+HHMM(g_niv[i].tSweep):"");
   }
   return s;
}
string CsvHoje(string file,int maxL)
{
   int h=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "";
   string hoje=TimeToString(TimeCurrent(),TIME_DATE), out=""; int c=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      if(StringFind(l,hoje)==0){ out+=(out==""?"":"\n")+l; c++; if(c>=maxL) break; }
   }
   FileClose(h); return out;
}
string AcaoFrase(string a)
{
   if(StringFind(a,"modo assistente")>=0) return "só avisei (modo assistente)";
   if(StringFind(a,"a mercado")==0) return "entrei a mercado";
   if(StringFind(a,"ordem limitada")==0) return "deixei ordem limitada";
   if(StringFind(a,"recusada")>=0) return "a corretora recusou";
   if(StringFind(a,"pulado: ")==0) return "pulei ("+StringSubstr(a,8)+")";
   return a;
}
string ResFrase(string r)
{
   if(r=="acerto") return "deu certo";
   if(r=="erro") return "deu errado";
   if(r=="nenhum") return "não andou nem 1R";
   return "";
}
string DiarioTxt()
{
   string hoje=TimeToString(TimeCurrent(),TIME_DATE);
   string s="📒 Hoje no "+_Symbol+":\n";
   // sinais
   int ns=0; string ls="";
   int h=FileOpen("ALIEN_diario.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); if(StringFind(l,hoje)!=0) continue;
         string p[]; if(StringSplit(l,';',p)<12) continue;
         ns++; if(ns>12) continue;
         ls+=StringFormat("• %s sinal de %s nota %s: %s\n",HoraBRde(StringToTime(p[0])),p[2],p[3],AcaoFrase(p[11]));
      }
      FileClose(h);
   }
   s+=(ns==0?"Nenhum sinal do robô ainda.\n":ls+(ns>12?StringFormat("(e mais %d)\n",ns-12):""));
   // vereditos
   int nv=0,ac=0,er=0; string lv="";
   h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); if(StringFind(l,hoje)!=0) continue;
         string p[]; if(StringSplit(l,';',p)<17) continue;
         nv++; string r=p[16]!=""?p[16]:p[15]; if(r=="acerto") ac++; if(r=="erro") er++;
         if(nv>10) continue;
         string rf=ResFrase(r);
         lv+=StringFormat("• %s a IA disse %s com o preço em %s%s\n",HoraBRde(StringToTime(p[0])),p[3],p[2],rf!=""?", "+rf:(p[3]=="ESPERAR"?"":", ainda medindo"));
      }
      FileClose(h);
   }
   s+="\n🤖 Leituras da IA:\n"+(nv==0?"Nenhuma ainda.\n":lv+(ac+er>0?StringFormat("Placar de hoje: %d certas, %d erradas.\n",ac,er):""));
   s+="\n🧘 "+DisciplinaResumo(0);
   s+="\n(horários de Brasília)";
   if(StringLen(s)>3500) s=StringSubstr(s,0,3500)+"\n...";
   return s;
}
string RiscoTxt()
{
   return StringFormat(
      "Risco do %s agora.\nRobô: %s%s\n$%.2f por trade | meta do dia $%.0f | perda máx $%.0f\n"
      "Stops hoje: %d (máx %d) | resultado $%+.2f | %d trades\n"
      "Pausa de DD: %s (limite %.0f%%) | disciplina: %s\n"
      "Nota mínima pro sinal: %d | spread máx %% do stop: %.0f\n"
      "Eu não mudo parâmetro sozinho — /pausa e /retoma só ligam ou desligam a operação.",
      _Symbol, InpTradeEnabled?(g_tradePausa?"PAUSADO por /pausa":"OPERANDO"):"ASSISTENTE (InpTradeEnabled=false)",
      g_ddPause?" | PAUSADO pelo DD":"",
      InpRiskUSD,InpMetaDiaUSD,InpPerdaMaxDiaUSD,g_stopsHoje,InpMaxStopsDia,g_netHoje,g_tradesHoje,
      g_ddPause?"SIM":"não",InpDDPausaPct,g_pare!=""?g_pare:"OK",
      InpScoreTrade,InpSpreadMaxPctStop);
}

// ---- alertas de preço persistidos ----
string AlertaLista()
{
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "(nenhum)";
   string s=""; int n=0;
   if(!FileIsEnding(h)) FileReadString(h); // header
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; if(StringSplit(l,';',p)<2) continue;
      if(p[1]=="1"){ s+=(s==""?"":", ")+p[0]; n++; }
   }
   FileClose(h); return n==0?"(nenhum)":s;
}
bool AlertaAdd(double preco)
{
   if(preco<=0) return false;
   CsvAppend(g_alertaArq,"preco;ativo",StringFormat("%s;1",Fmt(preco)));
   return true;
}
void AlertaTick()
{
   if(MQLInfoInteger(MQL_TESTER) || !TgOk()) return;
   datetime now=TimeCurrent();
   if(now-g_lastAlertaChk<1) return;
   g_lastAlertaChk=now;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0){ g_prevBid=bid; return; }
   if(g_prevBid<=0){ g_prevBid=bid; return; }
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE){ g_prevBid=bid; return; }
   string hdr=""; if(!FileIsEnding(h)) hdr=FileReadString(h);
   string keep="preco;ativo\r\n"; bool hit=false; string msg="";
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; int np=StringSplit(l,';',p); if(np<2){ keep+=l+"\r\n"; continue; }
      if(p[1]!="1"){ keep+=l+"\r\n"; continue; }
      double a=StringToDouble(p[0]);
      if(a>0 && ((g_prevBid-a)*(bid-a)<=0))
      { hit=true; msg+=StringFormat("%s atingiu %s (agora %s)\n",_Symbol,p[0],Fmt(bid)); keep+=p[0]+";0\r\n"; }
      else keep+=l+"\r\n";
   }
   FileClose(h);
   if(hit)
   {
      int w=FileOpen(g_alertaArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(w!=INVALID_HANDLE){ FileWriteString(w,keep); FileClose(w); }
      SendMsg("Opa, o preço bateu no alerta.\n"+msg+"Confere o gráfico antes de fazer qualquer coisa.");
   }
   g_prevBid=bid;
}

// ---- vereditos: grava, pontua 15/60 min, estatísticas ----
string PtsStr(const Plano &b)
{
   string s=""; for(int i=0;i<7;i++) s+=(b.pts[i]?"1":"0"); return s;
}
void VereditoLog(string origem)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_aiVeredito=="") return;
   Plano b=MelhorPlano();
   string st; SessaoNota(TimeTradeServer(),st);
   int p=StringFind(st," -"); string sess=p>0?StringSubstr(st,0,p):st;
   CsvAppend(g_verArq,g_verHdr,StringFormat("%s;%s;%s;%s;%s;%d;%d;%d;%d;%d;%d;%d;%s;%s;%s;;%s",
      TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),_Symbol,Fmt(SymbolInfoDouble(_Symbol,SYMBOL_BID)),
      g_aiVeredito,sess,g_mtf[0],g_mtf[1],g_mtf[2],g_mtf[3],g_mtf[4],g_mtf[5],b.score,PtsStr(b),
      Fmt(b.entry),Fmt(b.stop),origem));
}

// regra: anda as barras M1 após a hora; se +1R e -1R no mesmo candle => erro (conservador)
string VerScoreBar(int dir,double bid,double r1,const MqlRates &r[],int n,datetime t0)
{
   if(r1<=0 || bid<=0 || n<=0) return "nenhum";
   double up=bid+r1, dn=bid-r1;
   for(int i=n-1;i>=0;i--)
   {
      if(r[i].time<=t0) continue;
      bool hitUp=r[i].high>=up, hitDn=r[i].low<=dn;
      if(hitUp && hitDn) return "erro";
      if(dir==1){ if(hitDn) return "erro"; if(hitUp) return "acerto"; }
      else      { if(hitUp) return "erro"; if(hitDn) return "acerto"; }
   }
   return "nenhum";
}
string VerScoreRow(string ver,double bid,double entry,double stop,datetime t0)
{
   if(ver!="COMPRA" && ver!="VENDA") return "";
   if(bid<=0) return "";
   double r1=MathAbs(entry-stop);
   if(r1<=0) r1=(g_atr>0?g_atr:bid*0.001);
   if(r1<=0) return "";
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(_Symbol,PERIOD_M1,t0,TimeCurrent(),r);
   if(n<=0) return "nenhum";
   return VerScoreBar(ver=="COMPRA"?1:-1,bid,r1,r,n,t0);
}
void VereditoScore()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string lines[]; int n=0;
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      int k=n; ArrayResize(lines,k+1); lines[k]=l; n++;
      if(n>2000) break;
   }
   FileClose(h);
   if(n<=1) return;
   bool ch=false; datetime now=TimeCurrent();
   for(int i=1;i<n;i++)
   {
      string p[]; int c=StringSplit(lines[i],';',p);
      if(c<17) continue;
      if(p[2]==""||p[3]=="") continue;
      datetime t0=StringToTime(p[0]); if(t0<=0) continue;
      int ago=(int)((now-t0)/60);
      double bid=StringToDouble(p[2]), entry=StringToDouble(p[13]), stop=StringToDouble(p[14]);
      bool rowch=false;
      if(ago>=15 && p[15]=="")
      { p[15]=VerScoreRow(p[3],bid,entry,stop,t0); rowch=true; }
      if(ago>=60 && p[16]=="")
      { p[16]=VerScoreRow(p[3],bid,entry,stop,t0); rowch=true; }
      if(rowch)
      {
         string r=p[0]; for(int k=1;k<c;k++) r+=";"+p[k];
         lines[i]=r; ch=true;
      }
   }
   if(!ch) return;
   int w=FileOpen(g_verArq,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w);
}

void StatAdd(string &ks[],int &ac[],int &tot[],string k,bool win)
{
   if(k=="") return;
   int i=-1; for(int j=0;j<ArraySize(ks);j++) if(ks[j]==k){ i=j; break; }
   if(i<0){ i=ArraySize(ks); ArrayResize(ks,i+1); ArrayResize(ac,i+1); ArrayResize(tot,i+1); ks[i]=k; ac[i]=0; tot[i]=0; }
   tot[i]++; if(win) ac[i]++;
}
string StatFmt(const string &ks[],const int &ac[],const int &tot[])
{
   string s="";
   for(int i=0;i<ArraySize(ks);i++)
      s+=(s==""?"":",\"")+ks[i]+"\":\""+IntegerToString(ac[i])+"/"+IntegerToString(tot[i])+"\"";
   return s;
}
string StatFrase(const string &ks[],const int &ac[],const int &tot[],string pref)
{
   int best=-1, worst=-1;
   for(int i=0;i<ArraySize(ks);i++)
   {
      if(tot[i]<3) continue;
      if(best<0 || ac[i]*tot[best]>ac[best]*tot[i]) best=i;
      if(worst<0 || ac[i]*tot[worst]<ac[worst]*tot[i]) worst=i;
   }
   string f="";
   if(best>=0) f=pref+ks[best]+" acertou "+IntegerToString(ac[best])+"/"+IntegerToString(tot[best]);
   return f;
}
string VereditoStatsJSON()
{
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "{\"n\":0}";
   string kv[],ks[],kb[],kc[]; int av[],tv[],as2[],ts[],ab[],tb[],ac[],tc[];
   int n=0, a15=0,t15=0,a60=0,t60=0;
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"};
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue;
      string p[]; int c=StringSplit(l,';',p); if(c<17) continue;
      n++;
      string res=p[16]!=""?p[16]:p[15];
      if(res!="acerto" && res!="erro") continue;
      bool win=(res=="acerto");
      if(p[15]=="acerto"||p[15]=="erro"){ t15++; if(p[15]=="acerto") a15++; }
      if(p[16]=="acerto"||p[16]=="erro"){ t60++; if(p[16]=="acerto") a60++; }
      StatAdd(kv,av,tv,p[3],win);
      StatAdd(ks,as2,ts,p[4],win);
      if(StringToInteger(p[5])!=0) StatAdd(kb,ab,tb,StringToInteger(p[5])>0?"D1_alta":"D1_baixa",win);
      if(StringToInteger(p[7])!=0) StatAdd(kb,ab,tb,StringToInteger(p[7])>0?"H1_alta":"H1_baixa",win);
      if(StringLen(p[12])>=7)
         for(int i=0;i<7;i++) if(StringGetCharacter(p[12],i)=='1') StatAdd(kc,ac,tc,nm[i],win);
   }
   FileClose(h);
   string frase=StatFrase(kv,av,tv,"seu histórico: veredito ");
   string fsess=StatFrase(ks,as2,ts,"em ");
   if(frase!="" && fsess!="") frase+=" "+fsess;
   string sug="";
   int worst=-1;
   for(int i=0;i<ArraySize(ks);i++)
      if(ts[i]>=5 && as2[i]*2<=ts[i] && (worst<0||as2[i]*ts[worst]<as2[worst]*ts[i])) worst=i;
   if(worst>=0) sug="considerar evitar operar na sessão "+ks[worst]+" (acertou "+IntegerToString(as2[worst])+"/"+IntegerToString(ts[worst])+") — sugestão, não aplicada automaticamente";
   return StringFormat("{\"n\":%d,\"acerto_15m\":\"%d/%d\",\"acerto_60m\":\"%d/%d\",\"por_veredito\":{%s},\"por_sessao\":{%s},\"por_vies\":{%s},\"por_criterio\":{%s},\"frase\":\"%s\",\"sugestoes\":\"%s\"}",
      n,a15,t15,a60,t60,StatFmt(kv,av,tv),StatFmt(ks,as2,ts),StatFmt(kb,ab,tb),StatFmt(kc,ac,tc),JEsc(frase),JEsc(sug));
}
string Pct(int a,int t){ return t>0?StringFormat("%d de %d (%.0f%%)",a,t,100.0*a/t):"nenhum ainda"; }
string AlertasResumo(int dias)
{
   int h=FileOpen("ALIEN_alertas_log.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return "Ainda não mandei aviso automático.";
   string desde=TimeToString(AgoraBR()-dias*86400,TIME_DATE);
   int n=0,a=0,t=0; string ks[]; int ka[],kt[];
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<12) continue;
      if(StringSubstr(p[1],0,10)<desde) continue;
      n++;
      if(p[8]=="acerto"||p[8]=="erro"){ t++; if(p[8]=="acerto") a++; StatAdd(ks,ka,kt,p[3],p[8]=="acerto"); }
   }
   FileClose(h);
   if(n==0) return "Nenhum aviso automático nesse período.";
   string o=StringFormat("Mandei %d avisos automáticos. Nos que tinham direção, o preço andou 1R a favor antes de 1R contra em %s (em 60 min).",n,Pct(a,t));
   string f=StatFrase(ks,ka,kt,"O melhor tipo foi "); if(f!="") o+=" "+f+".";
   return o;
}
string AprendizadoTxt(int dias=0)
{
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   string s="🧠 Aprendizado do "+_Symbol+(dias>0?StringFormat(" (últimos %d dias)",dias):"")+"\n";
   s+=(n==0?"O robô ainda não fechou trade neste gráfico.":StringFormat("Trades do robô: %d, acertou %.0f%% e a média foi %+.2fR por trade.",n,w,a))+"\n";
   // vereditos da IA
   int h=FileOpen(g_verArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   int a15=0,t15=0,a60=0,t60=0; string ks[]; int ka[],kt[]; string kv[]; int va[],vt[];
   string desde=dias>0?TimeToString(TimeCurrent()-dias*86400,TIME_DATE):"";
   if(h!=INVALID_HANDLE)
   {
      if(!FileIsEnding(h)) FileReadString(h);
      while(!FileIsEnding(h))
      {
         string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<17) continue;
         if(desde!="" && StringSubstr(p[0],0,10)<desde) continue;
         if(p[15]=="acerto"||p[15]=="erro"){ t15++; if(p[15]=="acerto") a15++; }
         if(p[16]=="acerto"||p[16]=="erro"){ t60++; if(p[16]=="acerto") a60++; StatAdd(ks,ka,kt,p[4],p[16]=="acerto"); StatAdd(kv,va,vt,p[3],p[16]=="acerto"); }
      }
      FileClose(h);
   }
   if(t60+t15==0) s+="As leituras da IA ainda não foram medidas (preciso de pelo menos 1 hora depois de cada uma).\n";
   else
   {
      s+="Leituras da IA que deram direção: acertaram "+Pct(a15,t15)+" em 15 min e "+Pct(a60,t60)+" em 60 min (acerto = andou 1R a favor antes de 1R contra).\n";
      string fb=StatFrase(ks,ka,kt,"Melhor sessão: "); if(fb!="") s+=fb+".\n";
      int worst=-1; for(int i=0;i<ArraySize(ks);i++) if(kt[i]>=5 && (worst<0 || ka[i]*kt[worst]<ka[worst]*kt[i])) worst=i;
      if(worst>=0 && ka[worst]*2<=kt[worst]) s+="Pior sessão: "+ks[worst]+" ("+Pct(ka[worst],kt[worst])+"). Sugestão: evitar operar nela. Eu não mudo nada sozinho.\n";
   }
   s+=AlertasResumo(dias>0?dias:30)+"\n";
   s+="🧘 "+DisciplinaResumo(dias>0?dias:30)+"\n";
   s+="Isso é estatística do seu histórico, não promessa.";
   if(StringLen(s)>3500) s=StringSubstr(s,0,3500)+"\n...";
   return s;
}
void WeeklySummary()
{
   if(MQLInfoInteger(MQL_TESTER) || !TgOk()) return;
   if(InpTgChat && !g_tgMaster) return;
   datetime br=AgoraBR(); MqlDateTime d; TimeToStruct(br,d);
   if(d.day_of_week!=0 || d.hour<20) return;               // domingo 20:00 (Brasília)
   string key="SEM"+TimeToString(br,TIME_DATE);
   if(StringFind(g_resFeitos,"|"+key+"|")>=0 || StringFind(g_resFeitos,key+"|")>=0) return;
   g_resFeitos+=key+"|"; TgEstadoSave();
   SendMsg("📅 Resumo da semana, sem enrolação:\n"+AprendizadoTxt(7)+"\n\nSão só sugestões; quem decide é você. Boa semana! 💛");
}

void LearnTick()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   AlertaTick();
}
void LearnTimer()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   VereditoScore(); AlertasScore(); WeeklySummary(); BackupSemanal();
}

//====================================================================
// AGENTE ALIER (v12.3): estado persistido, aviso de volta, teclado fixo,
// avisos proativos, memória de fatos, áudio, disciplina, legenda do print.
// Tudo grátis: roda dentro do MT5 com as chaves Gemini do próprio Vitor.
//====================================================================
string   g_ligadoBR="";          // "HH:MM" (Brasília) em que o robô ligou
long     g_discPos=0;            // posição esperando o motivo (disciplina)
datetime g_discT=0;
string   g_proKeys="|";          // avisos proativos já mandados (persistido)
string   g_proHora="";           // horários (TimeGMT) dos últimos avisos, separados por ;
string   g_proTipo[]; datetime g_proTipoUlt[];
datetime g_proBarM1=0;
datetime g_proMudoAte=0;      // avisos segurados depois de um stop (InpPausaAposStopMin)

// ---------------- utilidades ----------------
string ArqLe(string f)
{
   int h=FileOpen(f,FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return "";
   string s=""; bool first=true;
   while(!FileIsEnding(h)){ string l=FileReadString(h); s+=(first?"":"\n")+l; first=false; }
   FileClose(h); return s;
}
void ArqGrava(string f,string s)
{
   int h=FileOpen(f,FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,s); FileClose(h);
}
// guarda só o fim de uma lista "|a|b|c|" (sem cortar uma chave no meio)
string ChavesCorta(string k,int maxLen=3000)
{
   if(StringLen(k)<=maxLen) return k;
   string t=StringSubstr(k,StringLen(k)-maxLen);
   int p=StringFind(t,"|"); if(p<0) return "|";
   return StringSubstr(t,p);
}
// une duas listas de chaves "|a|b|"
string ChavesUne(string a,string b)
{
   string p[]; int n=StringSplit(b,'|',p);
   for(int i=0;i<n;i++){ if(p[i]=="") continue; if(StringFind(a,"|"+p[i]+"|")<0) a+=(StringLen(a)>0 && StringGetCharacter(a,StringLen(a)-1)=='|'?"":"|")+p[i]+"|"; }
   return a;
}
string PrimeiraMinuscula(string s)
{
   if(s=="") return s;
   string f=StringSubstr(s,0,1); StringToLower(f); return f+StringSubstr(s,1);
}
string HoraBRde(datetime srv){ return TimeToString(SrvParaBR(srv),TIME_MINUTES); }
string TendPalavra(int d){ return d>0?"de alta":(d<0?"de baixa":"de lado"); }
string CsvLimpo(string s){ StringReplace(s,";",","); StringReplace(s,"\r"," "); StringReplace(s,"\n"," "); return s; }

// ---------------- 8. estado do Telegram persistido ----------------
string g_tgEstArq="ALIEN_tg_estado.txt";
void TgEstadoLoad()
{
   string s=ArqLe(g_tgEstArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   if(n>0){ long o=StringToInteger(l[0]); if(o>g_tgOff) g_tgOff=o; }
   if(n>1 && StringLen(l[1])>0) g_alertados=ChavesUne(g_alertados,l[1]);
   if(n>2 && StringLen(l[2])>0) g_resFeitos=ChavesUne(g_resFeitos,l[2]);
}
void TgEstadoSave()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   // une com o que outro gráfico já gravou (não apaga chaves dele)
   string s=ArqLe(g_tgEstArq);
   if(s!="")
   {
      string l[]; int n=StringSplit(s,'\n',l);
      if(n>0){ long o=StringToInteger(l[0]); if(o>g_tgOff) g_tgOff=o; }
      if(n>1) g_alertados=ChavesUne(g_alertados,l[1]);
      if(n>2) g_resFeitos=ChavesUne(g_resFeitos,l[2]);
   }
   g_alertados=ChavesCorta(g_alertados); g_resFeitos=ChavesCorta(g_resFeitos);
   ArqGrava(g_tgEstArq,IntegerToString(g_tgOff)+"\r\n"+g_alertados+"\r\n"+g_resFeitos+"\r\n");
}

// ---------------- 1. aviso de volta ("Voltei") só depois de queda de verdade ----------------
string ParadaArq(){ return "ALIEN_parada_"+_Symbol+".txt"; }
string MotivoParada(int r)
{
   switch(r)
   {
      case -1:              return "o MT5 fechou sem avisar (queda de energia, internet ou travamento)";
      case REASON_CLOSE:    return "o MT5 foi fechado";
      case REASON_ACCOUNT:  return "a conta reconectou ou foi trocada";
      case REASON_PROGRAM:  return "o robô se desligou sozinho";
      case REASON_INITFAILED: return "o robô não conseguiu ligar da última vez";
      default:              return "parada desconhecida";
   }
}
// motivos que são mexida sua (tirar/trocar gráfico, mudar parâmetro) -> sem aviso
bool ParadaFoiMexida(int r)
{
   return r==REASON_REMOVE || r==REASON_RECOMPILE || r==REASON_CHARTCHANGE || r==REASON_CHARTCLOSE || r==REASON_PARAMETERS || r==REASON_TEMPLATE;
}
void ParadaGrava(int rodando,int motivo)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   ArqGrava(ParadaArq(),StringFormat("%d;%I64d;%d",rodando,(long)TimeGMT(),motivo));
}
void ParadaDeinit(int r){ ParadaGrava(0,r); }
void ParadaBatimento(){ ParadaGrava(1,-1); }
bool VolteiPode()
{
   string s=ArqLe("ALIEN_voltei.txt"); long t=StringToInteger(s);
   return (t<=0 || (long)TimeGMT()-t>=15*60);
}
void VolteiMarca(){ ArqGrava("ALIEN_voltei.txt",IntegerToString((long)TimeGMT())); }
string ModoTxt(){ return TradeAtivo()?"operando na demo, dentro dos limites":(g_tradePausa?"pausado (você mandou pausar)":"modo assistente: só analiso e aviso, não mando ordem"); }
void ParadaInit()
{
   g_ligadoBR=TimeToString(AgoraBR(),TIME_MINUTES);
   if(MQLInfoInteger(MQL_TESTER)) return;
   string s=ArqLe(ParadaArq());
   ParadaGrava(1,-1);
   if(!TgOk()) return;
   if(InpTgChat && !TgMaster()) return;      // só o gráfico que atende o chat avisa
   string versao="Alier versão "+APROF_VER+", ligado às "+g_ligadoBR+" (Brasília) no "+_Symbol+".";
   if(s=="")
   {
      if(!VolteiPode()) return;
      VolteiMarca();
      SendMsgKb("Oi, Vitor! 👽 "+versao+"\nAgora: "+ModoTxt()+".\nUsa os botões aqui embaixo ou me escreve normal. /ajuda mostra tudo.");
      return;
   }
   string p[]; if(StringSplit(s,';',p)<3) return;
   int rodando=(int)StringToInteger(p[0]); long t=StringToInteger(p[1]); int motivo=(int)StringToInteger(p[2]);
   if(rodando==1) motivo=-1;                 // não passou pelo desligamento = caiu
   if(rodando==0 && ParadaFoiMexida(motivo)) return;
   if(!VolteiPode()) return;
   VolteiMarca();
   string desde=t>0?TimeToString((datetime)(t-3*3600),TIME_MINUTES):"?";
   SendMsgKb("Voltei ✅ Fiquei fora desde umas "+desde+" (Brasília) porque "+MotivoParada(motivo)+".\n"+versao+"\nAgora: "+ModoTxt()+".");
}

// ---------------- 5. teclado fixo + confirmação de pausa ----------------
string TgKbFixo()
{
   return "{\"keyboard\":[[{\"text\":\"📰 Notícias\"},{\"text\":\"📊 Análise\"},{\"text\":\"🧭 Plano\"}],"
          "[{\"text\":\"🗓️ Agenda\"},{\"text\":\"📸 Foto\"},{\"text\":\"ℹ️ Status\"}],[{\"text\":\"⏸️ Pausa\"},{\"text\":\"▶️ Retoma\"}]],"
          "\"resize_keyboard\":true,\"is_persistent\":true}";
}
string TgKbSimNao(string sim,string cbSim,string nao,string cbNao)
{
   return "{\"inline_keyboard\":[[{\"text\":\""+JEsc(sim)+"\",\"callback_data\":\""+cbSim+"\"},{\"text\":\""+JEsc(nao)+"\",\"callback_data\":\""+cbNao+"\"}]]}";
}
// texto de botão -> comando ("📰 Notícias" -> "/noticias")
string BotaoCmd(string t)
{
   if(StringLen(t)>24) return "";
   string u=AISemAcento(t); StringToUpper(u);
   string o="";
   for(int i=0;i<StringLen(u);i++){ ushort c=StringGetCharacter(u,i); if(c>='A' && c<='Z') o+=ShortToString(c); }
   if(o=="NOTICIAS") return "/noticias";
   if(o=="ANALISE")  return "/analise";
   if(o=="PLANO")    return "/plano";
   if(o=="FOTO")     return "/foto";
   if(o=="AGENDA")   return "/agenda";
   if(o=="STATUS")   return "/status";
   if(o=="PAUSA")    return "/pausa";
   if(o=="RETOMA")   return "/retoma";
   return "";
}
void PedeConfirmaPausa(bool pausar)
{
   if(pausar) SendMsgMarkup("Quer mesmo pausar as ordens? Os avisos continuam chegando.",TgKbSimNao("Sim, pausar ⏸️","/pausa_ok","Não","/cancela"));
   else       SendMsgMarkup("Quer mesmo voltar a mandar ordem (dentro dos limites)?",TgKbSimNao("Sim, retomar ▶️","/retoma_ok","Não","/cancela"));
}

// ---------------- legenda curta do print ----------------
string FotoLegenda()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   string s="📸 "+_Symbol+" a "+Fmt(bid)+" às "+TimeToString(AgoraBR(),TIME_MINUTES)+" (Brasília). ";
   string sw="";
   for(int i=0;i<ArraySize(g_niv);i++)
      if(g_niv[i].estado==ST_VARRIDA && g_niv[i].tSweep>0 && TimeCurrent()-g_niv[i].tSweep<3*3600)
      { sw=" Varreu a "+PrimeiraMinuscula(g_niv[i].nome)+" às "+HoraBRde(g_niv[i].tSweep)+"."; }
   Plano b=MelhorPlano();
   s+=StringFormat("H1 %s, M15 %s e M5 %s; melhor nota agora: %s %d/10.",TendPalavra(g_mtf[2]),TendPalavra(g_mtf[3]),TendPalavra(g_mtf[4]),b.dir==1?"compra":"venda",b.score);
   return s+sw;
}

// ---------------- memória: fatos do Vitor ----------------
string g_fatosArq="ALIEN_memoria_fatos.txt";
void FatosLe(string &f[])
{
   ArrayResize(f,0); string s=ArqLe(g_fatosArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   for(int i=0;i<n;i++){ string x=l[i]; StringTrimLeft(x); StringTrimRight(x); if(x=="") continue; int k=ArraySize(f); ArrayResize(f,k+1); f[k]=x; }
}
void FatoTalvez(string txt)
{
   string u=AISemAcento(txt); StringToLower(u);
   string g[]={"eu prefiro","prefiro ","me chama de","nao gosto","não gosto","gosto de","gosto quando","lembra que","lembre que","lembra disso","meu horario","eu opero","so opero","sempre opero","nunca opero","meu stop","meu risco","minha meta","meu objetivo","nao quero","não quero"};
   bool hit=false; for(int i=0;i<ArraySize(g);i++) if(StringFind(u,g[i])>=0){ hit=true; break; }
   if(!hit || StringLen(txt)>300) return;
   string f[]; FatosLe(f);
   StringReplace(txt,"\r",""); StringReplace(txt,"\n"," ");
   string novo=TimeToString(AgoraBR(),TIME_DATE)+": "+(StringLen(txt)>160?StringSubstr(txt,0,160)+"...":txt);
   int n=ArraySize(f); ArrayResize(f,n+1); f[n]=novo;
   int st=MathMax(0,ArraySize(f)-15); string o="";
   for(int i=st;i<ArraySize(f);i++) o+=f[i]+"\r\n";
   ArqGrava(g_fatosArq,o);
}
string FatosJSON(){ string f[]; FatosLe(f); string o=""; for(int i=0;i<ArraySize(f);i++) o+=(o==""?"":",")+"\""+JEsc(f[i])+"\""; return "["+o+"]"; }
string FatosTxt(){ string f[]; FatosLe(f); if(ArraySize(f)==0) return ""; string s="O QUE EU SEI DO VITOR (ele mesmo contou):\n"; for(int i=0;i<ArraySize(f);i++) s+="- "+f[i]+"\n"; return s+"\n"; }
string MemoriaTxt()
{
   string f[]; FatosLe(f); MemLoad();
   string s="🧠 O que eu lembro:\n";
   if(ArraySize(f)==0) s+="Ainda nada sobre você. Se quiser, me conta tipo \"eu prefiro operar só em Londres\" que eu guardo.\n";
   else for(int i=0;i<ArraySize(f);i++) s+="• "+f[i]+"\n";
   s+=StringFormat("E as últimas %d mensagens da conversa. Pra eu esquecer tudo: /esquece",ArraySize(g_mem));
   return s;
}
void MemoriaApaga(){ ArqGrava(g_fatosArq,""); ArqGrava("ALIEN_chat_memoria.txt",""); ArrayResize(g_mem,0); }

// ---------------- 7. áudio do Telegram -> Gemini ----------------
bool BaixaUrl(string url,uchar &out[],int timeout=15000)
{
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",timeout,data,res,rh);
   if(code!=200) { Print("Áudio: download respondeu ",code," (erro ",GetLastError(),")"); return false; }
   int n=ArraySize(res); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=(uchar)res[i];
   return n>0;
}
// pega o texto da primeira "parte" da resposta nativa do Gemini (aceita espaço depois dos dois pontos)
string GeminiTexto(string r)
{
   int k=StringFind(r,"\"text\""); if(k<0) return "";
   int c=StringFind(r,":",k); if(c<0) return "";
   int q=StringFind(r,"\"",c+1); if(q<0) return "";
   string t=JDecode(r,q); StringTrimLeft(t); StringTrimRight(t); return t;
}
// chamada nativa do Gemini com mídia (áudio/imagem) + texto; tenta de novo no limite grátis (429)
string GeminiMidia(uchar &bin[],string mime,string pedido,int maxTok,double temp,string &erro)
{
   erro="";
   string key=StringLen(g_cfgAI2Key)>10?g_cfgAI2Key:(StringLen(g_cfgGem2)>10?g_cfgGem2:"");
   if(key==""){ erro="sem chave Gemini"; return ""; }
   uchar k0[], b64[];
   if(CryptEncode(CRYPT_BASE64,bin,k0,b64)<=0){ erro="não consegui codificar o arquivo"; return ""; }
   string sb=CharArrayToString(b64,0,ArraySize(b64),CP_ACP); StringReplace(sb,"\r",""); StringReplace(sb,"\n","");
   string body="{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\""+JEsc(pedido)+"\"},{\"inline_data\":{\"mime_type\":\""+mime+"\",\"data\":\""+sb+"\"}}]}],\"generationConfig\":{\"temperature\":"+DoubleToString(temp,1)+",\"maxOutputTokens\":"+IntegerToString(maxTok)+"}}";
   uchar u8[]; int n=StringToCharArray(body,u8,0,WHOLE_ARRAY,CP_UTF8); if(n>0 && u8[n-1]==0) n--;
   char data[],res[]; string rh; ArrayResize(data,n); for(int i=0;i<n;i++) data[i]=(char)u8[i];
   string hdr="Content-Type: application/json\r\nx-goog-api-key: "+key+"\r\n";
   int code=-1; string r="";
   for(int k=0;k<2;k++)
   {
      string url="https://generativelanguage.googleapis.com/v1beta/models/"+InpAI2Model+":generateContent";
      if(k==1){ if(StringLen(g_cfgGem2)>10 && key!=g_cfgGem2) hdr="Content-Type: application/json\r\nx-goog-api-key: "+g_cfgGem2+"\r\n"; else Sleep(3000); }
      ArrayResize(res,0); ResetLastError();
      code=WebRequest("POST",url,hdr,40000,data,res,rh);
      r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
      if(code!=429 && code!=500 && code!=503) break;
      Print("Gemini mídia ocupada (",code,") - tentando de novo");
   }
   if(code==-1){ erro="WebRequest bloqueado ("+IntegerToString(GetLastError())+")"; return ""; }
   if(code==429){ erro="limite grátis do Google"; return ""; }
   if(code!=200){ erro="Gemini respondeu "+IntegerToString(code); Print("Gemini mídia: ",erro,": ",StringSubstr(r,0,300)); return ""; }
   string t=GeminiTexto(r); StringReplace(t,"**","");
   if(t==""){ erro="Gemini não devolveu texto"; return ""; }
   return t;
}
string AudioParaTexto(uchar &aud[],string &erro)
{
   return GeminiMidia(aud,"audio/ogg","Transcreva este áudio em português do Brasil, exatamente o que a pessoa falou, sem comentar nada. Se não der pra entender, responda só: [inaudível]",400,0.0,erro);
}
// baixa um arquivo do Telegram pelo file_id (getFile + download)
bool TgBaixaArquivo(string fileId,uchar &bin[],long maxBytes,string &erro)
{
   erro=""; uchar tmp[];
   if(!BaixaUrl("https://api.telegram.org/bot"+g_cfgTgToken+"/getFile?file_id="+UrlEnc(fileId),tmp,8000)){ erro="getFile falhou"; return false; }
   string r0=CharArrayToString(tmp,0,WHOLE_ARRAY,CP_UTF8);
   string path=JStrKey(r0,"file_path"); long sz=StringToInteger(JNumKey(r0,"file_size"));
   if(path==""){ erro="sem caminho do arquivo"; return false; }
   if(sz>maxBytes){ erro="grande"; return false; }
   if(!BaixaUrl("https://api.telegram.org/file/bot"+g_cfgTgToken+"/"+path,bin,20000)){ erro="download falhou"; return false; }
   return true;
}
// foto mandada no Telegram -> Gemini olha a imagem (ex.: print de gráfico de outra plataforma)
void FotoHandle(string chat,string fileId,string legenda)
{
   if(StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10){ SendMsg("Pra eu olhar foto eu preciso da chave Gemini. Por enquanto, me descreve em texto 😉"); return; }
   uchar img[]; string erro;
   if(!TgBaixaArquivo(fileId,img,4000000,erro)){ SendMsg(erro=="grande"?"Essa foto é grande demais pra mim. Manda um print menor 🙏":"Não consegui pegar a foto agora. Tenta de novo."); return; }
   bool mercado=EhMercado(legenda) || legenda=="";
   string pedido="Você é o Alier, parceiro do Vitor no Telegram. Português do Brasil, informal, curto (até 6 frases), sem markdown. "
                 "Olhe a imagem e responda o que ele pediu"+(legenda!=""?": \""+legenda+"\"":". Se for gráfico, leia a estrutura (tendência, topos/fundos, liquidez varrida, rompimentos, zonas) e diga o que observar.")+
                 " Se for gráfico, use só preços visíveis na imagem; se não der pra ler, diga que não dá. Nunca prometa lucro; quem decide é ele.";
   if(mercado)
   {
      string ctx=ContextJSON();
      if(ContextValido(ctx)) pedido+="\nPara comparar, a leitura do "+_Symbol+" no MT5 agora (números confiáveis do robô): "+StringSubstr(ctx,0,3500);
   }
   string m=FatosTxt(); if(m!="") pedido+="\n"+m;
   string t=GeminiMidia(img,"image/jpeg",pedido,700,0.4,erro);
   if(t==""){ SendMsg(erro=="limite grátis do Google"?"A IA grátis do Google tá no limite agora 😅 Me manda a foto de novo em 1 minutinho.":"Não consegui analisar a foto agora ("+erro+"). Tenta de novo daqui a pouco."); return; }
   t=AISemVeredito(t);
   MemAdd("Vitor","[mandou uma foto] "+legenda); MemAdd("Alier",t);
   SendMsg("👀 "+t);
}
// conversa sobre qualquer assunto (não é mercado)
string SysGeral()
{
   return "Você é o Alier, assistente pessoal do Vitor no Telegram (ele é barbeiro e estuda trading). Ajuda em qualquer assunto: dúvidas, contas, textos, ideias, saúde do dia a dia, estudo. "
          "Português do Brasil, informal e acolhedor, curto (1 a 5 frases, a não ser que ele peça mais). Sem markdown. "
          "Se não souber ou for algo que muda rápido (notícia de hoje, preço, placar), diga que não tem acesso à internet em tempo real. "
          "Se ele parecer muito mal ou falar em se machucar, acolha e lembre do CVV: ligue 188 (grátis, 24h). "
          "Use o que você sabe dele e a conversa recente, sem repetir o que já disse. Nunca prometa lucro.";
}
void ChatGeral(string pergunta)
{
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma, a IA tá no limite. Tenta de novo em %d s.",w)); return; }
   string r=AIAskEx(SysGeral(),MemTxt()+"MENSAGEM DO VITOR:\n"+pergunta,500,false,false,0.7);
   if(r==""){ SendMsg(AIFalhaTxt()); return; }
   r=AISemVeredito(SemCamposCrus(r));
   FatoTalvez(pergunta); MemAdd("Vitor",pergunta); MemAdd("Alier",r);
   SendMsg(r);
}
void VozHandle(string chat,string fileId)
{
   if(!InpVoz){ SendMsg("Áudio tá desligado nas configurações (InpVoz). Me escreve que eu respondo 😉"); return; }
   if(StringLen(g_cfgAI2Key)<=10 && StringLen(g_cfgGem2)<=10){ SendMsg("Pra entender áudio eu preciso da chave Gemini. Por enquanto, me escreve 😉"); return; }
   uchar aud[]; string erro;
   if(!TgBaixaArquivo(fileId,aud,2000000,erro)){ SendMsg(erro=="grande"?"Esse áudio ficou grande demais pra mim. Manda um de até 1 minuto 🙏":"Não consegui pegar seu áudio agora. Tenta de novo ou me escreve."); return; }
   string txt=AudioParaTexto(aud,erro);
   if(txt=="" || StringFind(txt,"[inaudível]")>=0)
   {
      Print("Áudio: ",erro);
      if(erro=="limite grátis do Google") SendMsg("A IA grátis do Google tá no limite agora 😅 Manda o áudio de novo em 1 minutinho.");
      else SendMsg(txt==""?"Ainda não consegui entender áudio aqui ("+erro+"). Me escreve que eu respondo 😉":"Não entendi o áudio 😅 Fala de novo mais perto do microfone ou me escreve.");
      return;
   }
   SendMsg("🎤 Entendi: \""+txt+"\"");
   TgHandle(chat,txt);
}

// ---------------- B. avisos proativos ----------------
string g_proArq="ALIEN_proativo.txt";
string g_alLogArq="ALIEN_alertas_log.csv";
string g_alLogHdr="hora_servidor;hora_brasilia;simbolo;tipo;dir;preco;r_pts;res15;res60;mov15_R;mov60_R;enviado";
void ProLoad()
{
   string s=ArqLe(g_proArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   if(n>0) g_proKeys=ChavesUne(g_proKeys,l[0]);
   if(n>1) g_proHora=l[1];
}
void ProSave()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   g_proKeys=ChavesCorta(g_proKeys,2500);
   ArqGrava(g_proArq,g_proKeys+"\r\n"+g_proHora+"\r\n");
}
int ProNaHora()
{
   string p[]; int n=StringSplit(g_proHora,';',p); string keep=""; int c=0; long now=(long)TimeGMT();
   if(MQLInfoInteger(MQL_TESTER)) now=(long)TimeCurrent();
   for(int i=0;i<n;i++){ long t=StringToInteger(p[i]); if(t>0 && now-t<3600){ keep+=(keep==""?"":";")+p[i]; c++; } }
   g_proHora=keep; return c;
}
bool ProTipoLivre(string tipo)
{
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_proTipo);i++) if(g_proTipo[i]==tipo) return (now-g_proTipoUlt[i]>=InpAlertaCooldownMin*60);
   return true;
}
void ProTipoMarca(string tipo)
{
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_proTipo);i++) if(g_proTipo[i]==tipo){ g_proTipoUlt[i]=now; return; }
   int k=ArraySize(g_proTipo); ArrayResize(g_proTipo,k+1); ArrayResize(g_proTipoUlt,k+1); g_proTipo[k]=tipo; g_proTipoUlt[k]=now;
}
void ProEnvia(string tipo,string key,int dir,double preco,string msg)
{
   if(StringFind(g_proKeys,"|"+key+"|")>=0) return;
   if(g_proMudoAte>0 && TimeCurrent()<g_proMudoAte) return;
   if(!ProTipoLivre(tipo)) return;
   if(ProNaHora()>=MathMax(InpAlertasMaxHora,1)) return;
   g_proKeys+=key+"|"; ProTipoMarca(tipo);
   long now=MQLInfoInteger(MQL_TESTER)?(long)TimeCurrent():(long)TimeGMT();
   g_proHora+=(g_proHora==""?"":";")+IntegerToString(now);
   double r=g_atr>0?g_atr:preco*0.0005;
   bool mandou=false;
   if(TgOk()) mandou=SendMsg(msg); else Print("ALIEN aviso: ",msg);
   CsvAppend(g_alLogArq,g_alLogHdr,StringFormat("%s;%s;%s;%s;%d;%s;%s;;;;;%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
      TimeToString(SrvParaBR(TimeCurrent()),TIME_DATE|TIME_MINUTES),_Symbol,tipo,dir,Fmt(preco),Fmt(r),mandou?"sim":"nao"));
   ProSave();
}
void ProativoBar()
{
   if(!InpAlertasProativos) return;
   if(!MQLInfoInteger(MQL_TESTER) && TgOk() && InpTgChat && !g_tgMaster) return;   // só um gráfico avisa
   datetime m1=iTime(_Symbol,PERIOD_M1,0); if(m1==0 || m1==g_proBarM1) return;
   g_proBarM1=m1;
   if(!g_ready) return;
   datetime now=TimeCurrent(); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0) return;
   int pe=PeriodSeconds(InpTFExec);
   // varrida de liquidez (Ásia, ontem, Londres)
   for(int i=0;i<ArraySize(g_niv);i++)
   {
      if(g_niv[i].estado!=ST_VARRIDA || g_niv[i].tSweep<=0) continue;
      string nm=g_niv[i].nome;
      if(StringFind(nm,"Ásia")<0 && StringFind(nm,"ontem")<0 && StringFind(nm,"Londres")<0) continue;
      if(now-g_niv[i].tSweep>2*pe+60) continue;
      int d=(g_niv[i].lado==NV_BELOW?1:-1);
      ProEnvia("varrida","v"+nm+IntegerToString((long)g_niv[i].tSweep),d,g_niv[i].preco,
         StringFormat("💧 Varreu a %s em %s (%s, Brasília). Pode ser armadilha de liquidez: olha o gráfico antes de qualquer coisa.",PrimeiraMinuscula(nm),Fmt(g_niv[i].preco),HoraBRde(g_niv[i].tSweep)));
   }
   // mudança de estrutura no TF da estrutura
   int nb=ArraySize(g_bos);
   if(nb>0 && now-g_bos[nb-1].tBreak<=2*pe+60)
   {
      BOSe e=g_bos[nb-1]; string tf=TfNome(InpTFExec);
      string m=e.choch?StringFormat("🔄 Mudou a estrutura no %s (CHoCH) pra %s: rompeu %s. Pode ser virada, espera confirmar.",tf,e.dir==1?"alta":"baixa",Fmt(e.preco))
                      :StringFormat("%s Rompeu a estrutura no %s (BOS) pra %s em %s. A tendência curta tá seguindo.",e.dir==1?"📈":"📉",tf,e.dir==1?"alta":"baixa",Fmt(e.preco));
      ProEnvia(e.choch?"choch":"bos","b"+IntegerToString((long)e.tBreak),e.dir,bid,m);
   }
   // preço dentro de um bloco de ordens não rompido
   for(int i=ArraySize(g_obs)-1;i>=0;i--)
   {
      if(g_obs[i].brk) continue;
      if(bid<=g_obs[i].hi && bid>=g_obs[i].lo)
      {
         ProEnvia("bloco","o"+IntegerToString((long)g_obs[i].t0),g_obs[i].dir,bid,
            StringFormat("🧱 Chegou no bloco de ordens de %s (%s a %s). Zona forte: olha a reação no M1.",g_obs[i].dir==1?"compra":"venda",Fmt(g_obs[i].lo),Fmt(g_obs[i].hi)));
         break;
      }
   }
   // toque na VWAP (vela M1 que acabou de fechar cruzou a VWAP, a anterior não)
   if(g_engVWAP>0)
   {
      double h1=iHigh(_Symbol,PERIOD_M1,1), l1=iLow(_Symbol,PERIOD_M1,1), h2=iHigh(_Symbol,PERIOD_M1,2), l2=iLow(_Symbol,PERIOD_M1,2);
      if(h1>=g_engVWAP && l1<=g_engVWAP && !(h2>=g_engVWAP && l2<=g_engVWAP))
         ProEnvia("vwap","w"+IntegerToString((long)(now/1800)),0,g_engVWAP,
            StringFormat("〰️ Tocou na VWAP (%s). Ela costuma segurar ou puxar o preço no dia; vê se segura.",Fmt(g_engVWAP)));
   }
   // setup completo 7/7
   Plano b=MelhorPlano();
   if(PlanoValido(b) && b.score>=InpScoreTrade)
   {
      int ok=0; for(int i=0;i<7;i++) if(b.pts[i]) ok++;
      if(ok>=7)
         ProEnvia("setup","s"+IntegerToString(b.dir)+IntegerToString((long)(now/900)),b.dir,b.entry,
            StringFormat("⚡ Montou setup completo: %s nota %d/10, checklist 7/7. Entrada %s, 🛑 stop %s, 🎯 alvo %s. Só aviso, a decisão é sua.",b.dir==1?"🟢 compra":"🔴 venda",b.score,Fmt(b.entry),Fmt(b.stop),Fmt(b.target)));
   }
}
// resultado dos avisos depois de 15 e 60 min (em R = ATR do TF da estrutura)
string MovR(datetime t0,int minutos,double preco,double r,int dir)
{
   int sh=iBarShift(_Symbol,PERIOD_M1,t0+minutos*60,false); if(sh<0) return "";
   double c=iClose(_Symbol,PERIOD_M1,sh); if(c<=0 || r<=0) return "";
   double m=(c-preco)/r; if(dir<0) m=-m;
   return DoubleToString(m,2);
}
void AlertasScore()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(g_alLogArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   string lines[]; int n=0;
   while(!FileIsEnding(h) && n<3000){ string l=FileReadString(h); if(l=="") continue; ArrayResize(lines,n+1); lines[n++]=l; }
   FileClose(h);
   bool ch=false; datetime now=TimeCurrent();
   for(int i=1;i<n;i++)
   {
      string p[]; int c=StringSplit(lines[i],';',p); if(c<12 || p[2]!=_Symbol) continue;
      datetime t0=StringToTime(p[0]); if(t0<=0) continue;
      int ago=(int)((now-t0)/60); int dir=(int)StringToInteger(p[4]); double px=StringToDouble(p[5]), r=StringToDouble(p[6]);
      bool rc=false;
      MqlRates rr[]; ArraySetAsSeries(rr,true);
      if(ago>=15 && p[7]=="")
      { int k=CopyRates(_Symbol,PERIOD_M1,t0,t0+15*60,rr); p[7]=dir==0?"-":VerScoreBar(dir,px,r,rr,k,t0); p[9]=MovR(t0,15,px,r,dir); rc=true; }
      if(ago>=60 && p[8]=="")
      { int k=CopyRates(_Symbol,PERIOD_M1,t0,t0+60*60,rr); p[8]=dir==0?"-":VerScoreBar(dir,px,r,rr,k,t0); p[10]=MovR(t0,60,px,r,dir); rc=true; }
      if(rc){ string o=p[0]; for(int k=1;k<c;k++) o+=";"+p[k]; lines[i]=o; ch=true; }
   }
   if(!ch) return;
   int w=FileOpen(g_alLogArq,FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w);
}

// ---------------- B. disciplina: "seguiu o plano?" ----------------
string g_discArq="ALIEN_disciplina.csv";
string g_discHdr="fechamento_servidor;fechamento_brasilia;hora_brasilia;dia_semana;simbolo;lado;origem;lote;resultado_usd;posicao;seguiu;motivo";
bool DiscTem(long pos)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE); if(h==INVALID_HANDLE) return false;
   string k=";"+IntegerToString(pos)+";"; bool achou=false;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(StringFind(l,k)>=0){ achou=true; break; } }
   FileClose(h); return achou;
}
bool DiscAtualiza(long pos,int col,string val)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ); if(h==INVALID_HANDLE) return false;
   string lines[]; int n=0;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(l=="") continue; ArrayResize(lines,n+1); lines[n++]=l; }
   FileClose(h);
   bool ok=false;
   for(int i=n-1;i>=1;i--)
   {
      string p[]; int c=StringSplit(lines[i],';',p); if(c<12) continue;
      if(StringToInteger(p[9])!=pos) continue;
      p[col]=CsvLimpo(val); string o=p[0]; for(int k=1;k<c;k++) o+=";"+p[k]; lines[i]=o; ok=true; break;
   }
   if(!ok) return false;
   int w=FileOpen(g_discArq,FILE_WRITE|FILE_TXT|FILE_ANSI); if(w==INVALID_HANDLE) return false;
   for(int i=0;i<n;i++) FileWriteString(w,lines[i]+"\r\n");
   FileClose(w); return true;
}
void DisciplinaFechou(ulong deal)
{
   if(MQLInfoInteger(MQL_TESTER) || !InpDisciplina) return;
   long en=HistoryDealGetInteger(deal,DEAL_ENTRY);
   if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_OUT_BY) return;
   long pos=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(PositionSelectByTicket((ulong)pos)) return;                // fechou só uma parte: espera fechar tudo
   if(TgOk() && InpTgChat && !TgMaster()) return;                 // só um gráfico pergunta
   if(DiscTem(pos)) return;
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
   long tipo=HistoryDealGetInteger(deal,DEAL_TYPE);
   string lado=(tipo==DEAL_TYPE_SELL?"compra":"venda");          // saída vendendo = era compra
   bool robo=(HistoryDealGetInteger(deal,DEAL_MAGIC)==InpMagic);
   double net=0, vol=HistoryDealGetDouble(deal,DEAL_VOLUME);
   if(HistorySelectByPosition(pos))
      for(int i=0;i<HistoryDealsTotal();i++){ ulong d=HistoryDealGetTicket(i); if(d==0) continue; net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION); }
   else net=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);
   datetime ts=(datetime)HistoryDealGetInteger(deal,DEAL_TIME), tb=SrvParaBR(ts);
   MqlDateTime md; TimeToStruct(tb,md);
   string dias[7]={"domingo","segunda","terça","quarta","quinta","sexta","sábado"};
   CsvAppend(g_discArq,g_discHdr,StringFormat("%s;%s;%02d;%s;%s;%s;%s;%.2f;%.2f;%I64d;pendente;",TimeToString(ts,TIME_DATE|TIME_MINUTES),TimeToString(tb,TIME_DATE|TIME_MINUTES),
      md.hour,dias[md.day_of_week],sym,lado,robo?"robo":"manual",vol,net,pos));
   if(net<0 && InpPausaAposStopMin>0)
   {
      g_proMudoAte=TimeCurrent()+InpPausaAposStopMin*60;
      if(TgOk()) SendMsg(StringFormat("Respira 🙏 Vou segurar os avisos automáticos por %d min. As ordens não ficam travadas.",InpPausaAposStopMin));
   }
   if(!TgOk()) return;
   string q=StringFormat("%s Fechou %s de %s (%s) com %+.2f.\nSeguiu o plano?",net>=0?"✅":"🔻",lado,sym,robo?"do robô":"sua",net);
   SendMsgMarkup(q,TgKbSimNao("👍 Segui","/disc s "+IntegerToString(pos),"👎 Não segui","/disc n "+IntegerToString(pos)));
}
void DisciplinaResposta(string args)
{
   string p[]; if(StringSplit(args,' ',p)<2){ return; }
   long pos=StringToInteger(p[1]); bool sim=(p[0]=="s");
   if(!DiscAtualiza(pos,10,sim?"sim":"nao")){ SendMsg("Não achei esse trade no diário de disciplina, mas valeu por responder."); return; }
   g_discPos=pos; g_discT=TimeCurrent();
   SendMsg(sim?"Boa! Anotado 👍 Disciplina é o que paga as contas. Se quiser, me conta em uma frase o que funcionou (ou só ignora).":
               "Anotado, sem julgamento 🙏 Me conta em uma frase o que pegou (pressa, medo, entrou fora do plano...). Isso vira aprendizado no domingo.");
}
// motivo opcional: a próxima mensagem (até 10 min, sem "?") vira o motivo
bool DisciplinaMotivo(string text)
{
   if(g_discPos<=0) return false;
   if(TimeCurrent()-g_discT>600 || StringFind(text,"?")>=0){ g_discPos=0; return false; }
   DiscAtualiza(g_discPos,11,text); g_discPos=0;
   SendMsg("Anotado ✍️ Valeu!");
   return true;
}
string DisciplinaResumo(int dias)
{
   int h=FileOpen(g_discArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ); if(h==INVALID_HANDLE) return "Ainda não tenho trade seu registrado pra medir disciplina.";
   string desde=TimeToString(AgoraBR()-dias*86400,TIME_DATE);
   int s=0,nn=0,pend=0; double rs=0,rn=0; int eh[24]; ArrayInitialize(eh,0); int ec=0,ev=0;
   if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); string p[]; if(StringSplit(l,';',p)<12) continue;
      if(StringSubstr(p[1],0,10)<desde) continue;
      double r=StringToDouble(p[8]);
      if(p[10]=="sim"){ s++; rs+=r; }
      else if(p[10]=="nao"){ nn++; rn+=r; int hh=(int)StringToInteger(p[2]); if(hh>=0&&hh<24) eh[hh]++; if(p[5]=="compra") ec++; else ev++; }
      else pend++;
   }
   FileClose(h);
   if(s+nn+pend==0) return "Nenhum trade seu fechou nesse período.";
   string o=StringFormat("Trades fechados: %d. Você disse que seguiu o plano em %d e não seguiu em %d",s+nn+pend,s,nn)+(pend>0?StringFormat(" (%d sem resposta)",pend):"")+".";
   if(s+nn>0) o+=StringFormat(" Disciplina: %.0f%%.",100.0*s/(s+nn));
   if(s>0 && nn>0) o+=StringFormat(" Seguindo o plano deu %+.2f; fora do plano deu %+.2f.",rs,rn);
   if(nn>0)
   {
      int hb=0; for(int i=1;i<24;i++) if(eh[i]>eh[hb]) hb=i;
      o+=StringFormat(" Onde mais escapou: perto das %dh (Brasília) e mais nas %s.",hb,ec>=ev?"compras":"vendas");
   }
   return o;
}

// ---------------- backup semanal dos CSV (MQL5\Files\ALIEN_backup\AAAA-MM-DD) ----------------
void BackupSemanal()
{
   if(MQLInfoInteger(MQL_TESTER) || !InpBackupSemanal) return;
   datetime br=AgoraBR();
   string ult=ArqLe("ALIEN_backup_ultimo.txt");
   if(StringToInteger(ult)>0 && (long)br-StringToInteger(ult)<7*86400) return;
   string pasta="ALIEN_backup\\"+StringSubstr(TimeToString(br,TIME_DATE),0,10);
   StringReplace(pasta,".","-");
   string nome; int n=0;
   long h=FileFindFirst("ALIEN_*.csv",nome);
   if(h!=INVALID_HANDLE)
   {
      do { if(FileCopy(nome,0,pasta+"\\"+nome,FILE_REWRITE)) n++; } while(FileFindNext(h,nome));
      FileFindClose(h);
   }
   ArqGrava("ALIEN_backup_ultimo.txt",IntegerToString((long)br));
   Print("ALIEN: backup semanal de ",n," arquivos em MQL5\\Files\\",pasta);
}

// ---------------- notícias: agenda do dia, bom dia e resultado depois da notícia ----------------
string AgendaTxt()
{
   if(!CalOn()) return "O calendário não está ligado agora.";
   LoadNews(true);
   datetime hoje=DayStart(AgoraBR()); string s=""; int n=0;
   for(int i=0;i<ArraySize(g_news);i++)
   {
      datetime b=SrvParaBR(g_news[i].t); if(DayStart(b)!=hoje) continue;
      s+=StringFormat("%s %s %s %s\n",TimeToString(b,TIME_MINUTES),g_news[i].imp==3?"🔴":"🟡",g_news[i].cur,g_news[i].nome); n++;
   }
   if(n==0) s="Nenhuma notícia forte ou média hoje ("+InpCalMoedas+"). Dia mais limpo 🙂\n";
   return "🗓️ Agenda de hoje (Brasília; 🔴 forte, 🟡 média):\n"+s;
}
void BomDia()
{
   if(!TgOk() || (InpTgChat && !g_tgMaster)) return;
   datetime br=AgoraBR(); MqlDateTime d; TimeToStruct(br,d);
   if(d.day_of_week==0 || d.day_of_week==6) return;
   if(d.hour!=8 || d.min>30) return;                         // ~08:00 de Brasília, dias úteis
   string key="BOMDIA"+TimeToString(br,TIME_DATE);
   if(StringFind(g_resFeitos,key+"|")>=0) return;
   g_resFeitos+=key+"|"; TgEstadoSave();
   Plano b=MelhorPlano();
   SendMsg("☀️ Bom dia, Vitor!\n"+AgendaTxt()+StringFormat("\nNo %s: viés do dia %s; H1 %s, M15 %s. Melhor nota agora: %s %d/10.\nAntes de notícia forte eu te aviso 15 min antes.",
      _Symbol,g_biasTxt,TendPalavra(g_mtf[2]),TendPalavra(g_mtf[3]),b.dir==1?"compra":"venda",b.score));
}
string CalNum(double v){ return DoubleToString(v,(MathAbs(v)<10?2:1)); }
void NoticiaResultado()
{
   if(!TgOk() || !CalOn() || (InpTgChat && !g_tgMaster)) return;
   LoadNews(); datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3 || StringFind(InpPreAlertaMoedas,g_news[i].cur)<0) continue;
      long dt=(long)(now-g_news[i].t); if(dt<5*60 || dt>40*60) continue;
      string key="P"+IntegerToString((long)g_news[i].id);
      if(StringFind(g_alertados,"|"+key+"|")>=0) continue;
      MqlCalendarValue v; string num="";
      if(CalendarValueById(g_news[i].id,v))
      {
         if(v.HasActualValue()) num+="atual "+CalNum(v.GetActualValue());
         if(v.HasForecastValue()) num+=(num==""?"":", ")+"previsão "+CalNum(v.GetForecastValue());
         if(v.HasPreviousValue()) num+=(num==""?"":", ")+"anterior "+CalNum(v.GetPreviousValue());
      }
      if(StringFind(num,"atual")<0 && dt<20*60) continue;     // espera o número sair (até 20 min)
      g_alertados+=key+"|"; TgEstadoSave();
      int s0=iBarShift(_Symbol,PERIOD_M1,g_news[i].t,false), s5=iBarShift(_Symbol,PERIOD_M1,g_news[i].t+5*60,false);
      string mov="";
      if(s0>=0 && s5>=0)
      {
         double p0=iOpen(_Symbol,PERIOD_M1,s0), p5=iClose(_Symbol,PERIOD_M1,s5);
         if(p0>0 && p5>0) mov=StringFormat(" O %s andou %+.2f nos 5 min depois (%s → %s).",_Symbol,p5-p0,Fmt(p0),Fmt(p5));
      }
      SendMsg(StringFormat("📰 Saiu %s (%s, %s Brasília)%s.%s Espera a poeira baixar antes de entrar.",g_news[i].nome,g_news[i].cur,HHMMBR(g_news[i].t),num!=""?": "+num:" (sem número no calendário)",mov));
   }
}

string SvcStatus()
{
   string s=AIStatus();
   if(g_tgHint!="" && g_cfgTgChat=="") return g_tgHint;
   string t = !InpUseTelegram ? "Telegram: desligado" : (StringLen(g_cfgTgToken)<=20 ? "Telegram: coloque o token" :
              (StringLen(g_cfgTgChat)==0 ? "Telegram: mande /start pro seu bot (eu me conecto sozinho)" :
              (MQLInfoInteger(MQL_TESTER) ? "Telegram: não roda no testador" : (InpTgChat ? (g_tgMaster?"Telegram: chat ATIVO neste gráfico (/ajuda)":"Telegram: chat atendido por outro gráfico") : ""))));
   if(s!="" && t!="") return s+"  |  "+t;
   return s+t;
}
void TentaOperar()
{
   Plano b; int di;
   b=MelhorPlano(); di=(b.dir==1?0:1);
   // sinal = nota cruza o limite com plano válido (RR >= InpMinRR)
   bool cruzou = (PlanoValido(b) && b.score>=InpScoreTrade && g_prevScore[di]<InpScoreTrade);
   g_prevScore[0]=PlanoValido(g_pb)?g_pb.score:0; g_prevScore[1]=PlanoValido(g_ps)?g_ps.score:0;
   string blk=Bloqueio(b);
   if(!TradeAtivo())
   {
      // assistente ou /pausa: não manda ordem, só avisa o sinal (com análise e print)
      g_status = g_tradePausa?"PAUSADO por /pausa (não opera)":("MODO ASSISTENTE: só analisa e avisa"+(blk!=""?" | "+blk:""));
      if(!cruzou) return;
      Diario(b,"sinal (modo assistente, não operou)"+(blk!=""?" - "+blk:""));
      string ia2=AIAsk(StateJSON(b)); if(ia2!=""){ AIPanelSet(ia2); VereditoLog("sinal"); }
      Notifica(StringFormat("Achei um sinal de %s no %s, nota %d/10 — mas tô no modo assistente, não operei.\nEntrada %s, stop %s, alvo %s, lote %.2f (risco ~$%.2f).\n%s%s",
               b.dir==1?"🟢 COMPRA":"🔴 VENDA",_Symbol,b.score,Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.lot,b.riskUSD,
               blk!=""?"Aviso: "+blk+"\n":"",Narrativa(b,false,""))+(ia2!=""?"\n\nO que a IA achou:\n"+ia2:""));
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
   if(!PlanoValido(b) || b.rr+1e-12<RRMinAlvo()){ Diario(b,"pulado: "+PlanoSemSetup(b.dir)); Print("ALIEN AUTO: ",PlanoSemSetup(b.dir)," - não opero com RR abaixo do mínimo"); return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=NormP(b.stop);
   double risk=MathAbs(b.entry-b.stop);
   if(risk<=0) return;
   if(InpSpreadMaxPctStop>0 && (ask-bid)>InpSpreadMaxPctStop/100.0*risk){ Print("ALIEN AUTO: spread alto - pulei"); return; }
   double tp=NormP(b.target);
   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double lot=NormalizeDouble(b.lot,2);
   string cm=StringFormat("APROF %d/10",b.score);
   // IA: comenta o sinal; só pode VETAR se InpAIVeto = true (nunca abre trade)
   string ia=AIAsk(StateJSON(b)); if(ia!=""){ AIPanelSet(ia); VereditoLog("sinal"); }
   if(AIVetou(ia,b.dir)){ Diario(b,"pulado: IA vetou"); Notifica(StringFormat("A IA vetou o sinal do %s nota %d/10. Não entrei. %s",_Symbol,b.score,ia)); return; }
   bool ok=false; bool limite=(StringFind(b.entNome,"FVG")>=0 || StringFind(b.entNome,"vazio")>=0);
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
   if(ok) Notifica(StringFormat("Bora: mandei %s de %s no %s, nota %d/10. Lote %.2f, entrada %s, stop %s, alvo %s (risco ~$%.2f). %s",
                   limite?"limitada":"a mercado",b.dir==1?"🟢 COMPRA":"🔴 VENDA",_Symbol,b.score,lot,Fmt(b.entry),Fmt(sl),Fmt(tp),b.riskUSD,Narrativa(b,false,""))+(ia!=""?"\n\nO que a IA achou:\n"+ia:""));
   else Print("ALIEN AUTO: ordem recusada ",g_tr.ResultRetcode()," ",g_tr.ResultRetcodeDescription());
}

int OnInit()
{
   g_noDraw = MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE);
   g_tr.SetExpertMagicNumber(InpMagic);
   g_tr.SetDeviationInPoints(30);
   g_tr.SetTypeFillingBySymbol(_Symbol);
   CfgLoad();
   Core_Init();
   g_peak=MathMax(AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO (mude InpAllowRealAccount por sua conta e risco)"; g_extraC=clrRed; }
   MathSrand((uint)(GetTickCount()^(uint)(ChartID()%1000000)));
   g_inst=(double)((ChartID()%1000000)*1000+MathRand()%1000+1);
   g_tgStartUtc=TimeGMT();
   PausaLoad();
   LoadNews(true);
   g_statusSvc=SvcStatus();
   // estado persistido (offset do Telegram, notícias avisadas, resumos, avisos) e aviso de volta só após queda real
   TgEstadoLoad(); ProLoad();
   ParadaInit();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); ParadaDeinit(r); TgEstadoSave(); TgMasterSolta(); Core_Deinit(); }
void OnTimer()
{
   if(MQLInfoInteger(MQL_TESTER)) return;          // no testador não existe WebRequest/calendário
   Core_Update(true);
   static ulong lastPoll=0, lastMin=0; ulong ms=GetTickCount64();
   if(ms-lastPoll>=(ulong)MathMax(InpTgPollSeg,2)*1000){ lastPoll=ms; TgPoll(); }
   if(ms-lastMin>=30000){ lastMin=ms; ParadaBatimento(); LoadNews(); TgPreAlerta(); NoticiaResultado(); BomDia(); TgResumos(); LearnTimer(); g_statusSvc=SvcStatus(); }
}
void OnTick()
{
   Core_Update(false);
   LearnTick();
   ProativoBar();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_peak) g_peak=eq;
   if(InpDDPausaPct>0 && !g_ddPause && g_peak>0 && eq<g_peak*(1.0-InpDDPausaPct/100.0)){ g_ddPause=true; Notifica(StringFormat("Pausei o %s: a equity caiu %.0f%% do pico. Melhor revisar antes de ligar de novo.",_Symbol,InpDDPausaPct)); }
   Gerencia();
   datetime bt=iTime(_Symbol,InpTFExec,0);
   if(bt!=0 && bt!=g_lastSigBar && g_ready)
   {
      g_lastSigBar=bt;
      TentaOperar();
      g_statusSvc=SvcStatus();
      if(AIOn() && InpAIMinutos>0 && TimeCurrent()-g_aiLast>=InpAIMinutos*60)
      { Plano pb=MelhorPlano(); string t=AIAsk(StateJSON(pb)); if(t!=""){ AIPanelSet(t); VereditoLog("periodo"); } }
      if(ContaBloqueada()){ g_extra="BLOQUEADO: CONTA REAL - este robô só opera em DEMO"; g_extraC=clrRed; }
      else { g_extra="ROBÔ: "+g_status; g_extraC= StringFind(g_status,"aguardando")==0||StringFind(g_status,"em operação")==0 ? clrLime : (StringFind(g_status,"MODO ASSISTENTE")==0 ? clrGold : clrOrangeRed); }
   }
}
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(tr.deal)) return;
   DisciplinaFechou(tr.deal);                       // qualquer trade da conta (seu ou do robô)
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
      Notifica(StringFormat("Saiu do %s com %+.2f (%.2fR).",_Symbol,net,R));
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   EngChartEvent(id,sparam);
}
