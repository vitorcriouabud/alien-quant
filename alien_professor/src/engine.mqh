
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
