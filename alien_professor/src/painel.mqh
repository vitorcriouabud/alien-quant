
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
