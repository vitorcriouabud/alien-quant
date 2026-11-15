import sys, time, pickle, numpy as np, pandas as pd
sys.path.insert(0,"/workspace/alien-research/code/ouro")
from scipy import stats
from core import *
from strats import nonoverlap, at_clock
T0=time.time()
D=load(); ts=D["ts"]; hm=D["hm"]; uhm=ts%1440; n=len(ts); mid=D["mid"]
SWAPL=-0.055/360; SWAPS=0.017/360
NAN=lambda k: np.full(k,np.nan)

def run(spec, comm=COMM):
    ei,dr,st,tg,xi=spec
    pnl,why,xo=sim(D["bid"],D["ask"],ei.astype(np.int64),dr.astype(np.int64),st.astype(float),tg.astype(float),xi.astype(np.int64),comm)
    nights=(D["sdate"][xo]-D["sdate"][ei])
    sw=np.zeros(len(ei))
    for k in np.flatnonzero(nights>0):
        days=pd.to_datetime(np.arange(D["sdate"][ei[k]],D["sdate"][xo[k]]),unit="D")
        mult=sum(3 if dd.dayofweek==2 else 1 for dd in days if dd.dayofweek<5)
        sw[k]=mult*mid[ei[k],0]*(SWAPL if dr[k]>0 else SWAPS)
    pnl=pnl+sw
    risk=np.where(np.isnan(st),np.nan,np.abs(np.where(dr>0,D["ask"][ei,0],D["bid"][ei,0])-st))
    return pd.DataFrame({"ei":ei,"xo":xo,"dr":dr,"pnl":pnl,"risk":risk,"year":D["year"][ei],"sd":D["sdate"][xo]})

def summ(t,lo=2016,hi=2024):
    s=t[(t.year>=lo)&(t.year<=hi)]
    if len(s)<3: return dict(n=len(s),mean=np.nan,pf=np.nan,t=np.nan,p=1.0,tot=np.nan)
    dd=s.groupby("sd").pnl.sum(); tt=dd.mean()/dd.std(ddof=1)*np.sqrt(len(dd))
    g=s.pnl[s.pnl>0].sum(); b=-s.pnl[s.pnl<0].sum(); q=s.pnl.sort_values(); k=max(1,int(round(len(q)*0.01))); tot=s.pnl.sum()
    return dict(n=len(s),mean=s.pnl.mean(),tot=tot,pf=g/b if b>0 else np.inf,t=tt,p=1-stats.t.cdf(tt,len(dd)-1),
        wr=(s.pnl>0).mean(),yrs=int((s.groupby("year").pnl.sum()>0).sum()),ex1=q.iloc[:-k].sum(),
        maxday=dd.max()/tot if tot>0 else np.nan,risk_med=np.nanmedian(s.risk) if s.risk.notna().any() else np.nan,p01=q.quantile(0.01))

def at(clock,mins):  # all indices where clock==mins (one per calendar occurrence)
    return np.flatnonzero(clock==mins)
def nxt(idx_from,minutes):  # index of last bar with ts <= ts[i]+minutes
    return np.searchsorted(ts,ts[idx_from]+minutes,side="right")-1
def pair(a_idx,dur,maxgap=30):
    """exit = bar at ts+dur-1 (close of that minute); require existence within maxgap"""
    x=np.searchsorted(ts,ts[a_idx]+dur-1,side="right")-1
    ok=(x>a_idx)&(ts[a_idx]+dur-1-ts[x]<=maxgap)
    return a_idx[ok],x[ok]
WD=pd.to_datetime(ts[:]*60,unit="s",utc=True).tz_convert("America/New_York").dayofweek.values

# ---------- IM ----------
def im(var,sh=0):
    e=at(hm,13*60+sh); e=e[WD[e]<5]; ei,xi=pair(e,30)
    sd=D["sdate"][ei]
    s0=at(hm,8*60+20); s1=at(hm,8*60+49); c13=at(hm,13*60+29)
    m=lambda idx,col: pd.Series(mid[idx,col],index=D["sdate"][idx]).groupby(level=0).first()
    o820=m(s0,0); c850=m(s1,3); cl=m(c13,3)
    prevcl=cl.shift(1)  # previous session close 13:30 (index by sdate order)
    if var=="IM2": sig=c850-o820
    else: sig=c850-prevcl.reindex(c850.index)
    sig=sig.reindex(sd).values
    dr=np.sign(sig)
    if var=="IM3":
        p0=m(at(hm,12*60+30),0); p1=m(at(hm,12*60+59),3); pen=(p1-p0).reindex(sd).values
        dr=np.where(np.sign(pen)==dr,dr,0)
    ok=(dr!=0)&~np.isnan(dr); dr=np.nan_to_num(dr).astype(np.int64)
    ei,xi,dr=ei[ok],xi[ok],dr[ok]
    return ei,dr,NAN(len(ei)),NAN(len(ei)),xi

# ---------- RO ----------
def ro(var,ea=None,xb=None):
    if var=="RO1": ea=ea or 16*60+30; xb=xb or 19*60
    else: ea=ea or 18*60+5; xb=xb or 19*60
    e=at(hm,ea); e=e[WD[e]<=3]   # Mon-Thu (calendar day of entry, NY)
    if var=="RO2": e=at(hm,ea); e=e[(WD[e]<=3)]  # 18:05 Mon..Thu evening (session of Tue..Fri)
    dur=(xb-ea)%1440
    ei,xi=pair(e,dur)
    return ei,np.ones(len(ei),np.int64),NAN(len(ei)),NAN(len(ei)),xi

# ---------- CS ----------
def cs(var,ea=0,xb=8*60):
    e=at(uhm,ea); uwd=((ts[e]//1440)+3)%7; e=e[uwd<5]  # UTC weekday Mon..Fri (1970-01-01 = Thu)
    ei,xi=pair(e,(xb-ea)%1440)
    # signal: previous UTC day 14:30->21:00
    a=at(uhm,14*60+30); b=at(uhm,20*60+59)
    day=lambda idx: ts[idx]//1440
    sa=pd.Series(mid[a,0],index=day(a)); sb=pd.Series(mid[b,3],index=day(b))
    sig=(sb-sa).dropna()
    s=pd.Series(day(ei)-1).map(sig).values
    # if prior UTC day is Sunday/no data (Monday Asia) -> use last available (Friday)
    s2=pd.Series(day(ei)-3).map(sig).values
    s=np.where(np.isnan(s)&((((ts[ei]//1440)+3)%7)==0),s2,s)
    dr=np.sign(np.nan_to_num(s)).astype(np.int64)
    if var=="CS1": dr=np.where(dr>0,1,0)
    ok=dr!=0
    return ei[ok],dr[ok],NAN(ok.sum()),NAN(ok.sum()),xi[ok]

# ---------- VB ----------
sd_all=D["sdate"]; chg=np.r_[True,sd_all[1:]!=sd_all[:-1]]; SF=np.flatnonzero(chg); SL=np.r_[SF[1:]-1,n-1]
def vb(K=0.5,stopk=0.7,rr=3.0):
    E=[];DR=[];ST=[];TG=[];X=[]
    hi=np.maximum.reduceat(mid[:,1],SF); lo=np.minimum.reduceat(mid[:,2],SF)
    for s in range(1,len(SF)):
        a,b=SF[s],SL[s]
        if b-a<600 or SL[s-1]-SF[s-1]<600: continue  # skip tiny sessions (holidays)
        R=hi[s-1]-lo[s-1]; o=mid[a,0]
        c=mid[a:b+1,3]; h=hm[a:b+1]
        ok=~((h>=16*60)&(h<18*60+5))
        up=np.flatnonzero(ok&(c>o+K*R)); dn=np.flatnonzero(ok&(c<o-K*R))
        iu=up[0] if len(up) else 10**9; idn=dn[0] if len(dn) else 10**9
        j=min(iu,idn)
        if j>=10**9 or a+j+1>D["eod"][a]: continue
        d=1 if iu<idn else -1; ei=a+j+1
        e=D["ask"][ei,0] if d>0 else D["bid"][ei,0]
        st=e-d*stopk*R; tg=e+d*rr*stopk*R
        E.append(ei);DR.append(d);ST.append(st);TG.append(tg);X.append(D["eod"][a])
    return np.array(E),np.array(DR),np.array(ST),np.array(TG),np.array(X)

# ---------- VO ----------
vol=np.zeros(n)
vv=pd.concat([pd.read_csv(f"/workspace/alien-research/data/xvol/xau_v_{y}.csv") for y in range(2016,2027)])
vv["m"]=vv.timestamp//60000; vv=vv.drop_duplicates("m")
pos=np.searchsorted(ts,vv.m.values); okp=(pos<n)&(ts[np.minimum(pos,n-1)]==vv.m.values)
vol[pos[okp]]=vv.volume.values[okp]
print("vol matched",okp.mean(),"nonzero",(vol>0).mean(),time.time()-T0,flush=True)
TFB={}
for tf,mn in (("M5",5),("M15",15),("H1",60)):
    B=bars_key(D,ts//mn); B["atr"]=atr(B); B["v"]=np.add.reduceat(vol,B["first"])
    tod=(ts[B["first"]]%1440)//mn
    B["rv"]=B["v"]/pd.Series(B["v"]).groupby(tod).transform(lambda x: x.shift(1).rolling(20,min_periods=10).mean()).values
    B["mn"]=mn; TFB[tf]=B
print("bars",time.time()-T0,flush=True)

def vo(var,tf,rv=2.0,rr=2.0):
    B=TFB[tf]; o,h,l,c,A,RV=B["o"],B["h"],B["l"],B["c"],B["atr"],B["rv"]; mn=B["mn"]
    rg=h-l; body=np.abs(c-o); Ap=np.r_[np.nan,A[:-1]]
    big=rg>=Ap; hv=RV>=rv
    if var in("VO1","VO3"):
        sig=big&hv&(body>=0.7*rg); d=np.sign(c-o)
        stopx=np.where(d>0,l,h)  # other extreme
        if var=="VO3":
            hh=pd.Series(h).shift(1).rolling(20).max().values; ll=pd.Series(l).shift(1).rolling(20).min().values
            bos=np.where(d>0,c>hh,c<ll)
            fvg=np.where(d>0,np.r_[l[2:]>h[:-2],False,False],np.r_[h[2:]<l[:-2],False,False])  # bar i+1 vs bar i-1
            sig=sig&bos&fvg; delay=2
        else: delay=1
    else:
        uw=h-np.maximum(o,c); lw=np.minimum(o,c)-l
        su=big&hv&(uw>=0.6*rg); sl=big&hv&(lw>=0.6*rg)&~su
        sig=su|sl; d=np.where(su,-1,1).astype(float)
        stopx=np.where(d<0,h+0.1*A,l-0.1*A)
        if var=="VO4":
            hh=pd.Series(h).shift(1).rolling(20).max().values; ll=pd.Series(l).shift(1).rolling(20).min().values
            sig=sig&np.where(d<0,h>hh,l<ll)
        delay=1
    idx=np.flatnonzero(sig&~np.isnan(RV)&~np.isnan(Ap)); idx=idx[(idx>25)&(idx<len(c)-delay)]
    ei=B["first"][idx+delay]
    ok=(ts[ei]-ts[B["last"][idx]]<=mn*delay+5)&~((hm[ei]>=16*60)&(hm[ei]<18*60))
    idx,ei=idx[ok],ei[ok]; dr=d[idx].astype(np.int64)
    e=np.where(dr>0,D["ask"][ei,0],D["bid"][ei,0]); st=stopx[idx]
    risk=(e-st)*dr; ok=(risk>0)&(risk<=3*A[idx])
    idx,ei,dr,st,e,risk=idx[ok],ei[ok],dr[ok],st[ok],e[ok],risk[ok]
    tg=e+dr*rr*risk
    xi=np.minimum(nxt(ei,240),D["eod"][ei]); ok=xi>ei
    ei,xi,dr,st,tg=nonoverlap(ei[ok],xi[ok],dr[ok],st[ok],tg[ok])
    return ei,dr,st,tg,xi

# ---------- GS (D1, separate engine) ----------
def d1(sym):
    b=pd.read_csv(f"/workspace/alien-research/data/d1/{sym}_bid.csv"); a=pd.read_csv(f"/workspace/alien-research/data/d1/{sym}_ask.csv")
    df=b.merge(a,on="timestamp",suffixes=("b","a")); df.index=pd.to_datetime(df.timestamp,unit="ms"); df=df[df.index.dayofweek<5]
    return df
G=d1("xauusd"); S=d1("xagusd"); J=G.join(S,lsuffix="_g",rsuffix="_s",how="inner")
J=J[(J.index>="2015-06-01")]
def gs(var,N=20,ze=2.0,zx=0.5,maxd=10,comm=COMM):
    gm=(J.closeb_g+J.closea_g)/2; smd=(J.closeb_s+J.closea_s)/2; r=np.log(gm/smd)
    z=((r-r.rolling(N).mean())/r.rolling(N).std()).values
    dates=J.index; m=len(J); rows=[]; k=0
    sl=lambda d0,d1_: sum(3 if dd.dayofweek==2 else 1 for dd in pd.date_range(d0,d1_-pd.Timedelta(days=1)) if dd.dayofweek<5)
    while k<m-1:
        if np.isnan(z[k]) or abs(z[k])<ze: k+=1; continue
        dg=-1 if z[k]>0 else 1  # ratio high -> short gold
        i=k+1; j=i
        while j<m-1 and (j-i)<maxd and abs(z[j])>=zx: j+=1
        x=j if (j-i)>=maxd or abs(z[j])<zx else j
        x=min(x+1,m-1)  # exit next open after exit signal
        if x<=i: x=i+1
        if x>=m: break
        gi=J.opena_g.iloc[i] if dg>0 else J.openb_g.iloc[i]; go=J.openb_g.iloc[x] if dg>0 else J.opena_g.iloc[x]
        nts=sl(dates[i],dates[x])
        pg=dg*(go-gi)-comm+nts*gi*(SWAPL if dg>0 else SWAPS)
        pnl=pg
        if var=="GS1":
            ds=-dg; q=gi/((J.openb_s.iloc[i]+J.opena_s.iloc[i])/2)
            si=J.opena_s.iloc[i] if ds>0 else J.openb_s.iloc[i]; so=J.openb_s.iloc[x] if ds>0 else J.opena_s.iloc[x]
            pnl+=q*(ds*(so-si)-0.00004*si+nts*si*(SWAPL if ds>0 else SWAPS))
        rows.append(dict(pnl=pnl,year=dates[i].year,sd=dates[x].value//86400_000_000_000,risk=np.nan,dr=dg))
        k=x
    return pd.DataFrame(rows)

# ---------- registry ----------
P={};NB={}
for v in("IM1","IM2","IM3"): P[v]=lambda v=v,**k: im(v,**k); NB[v]=[dict(sh=-5),dict(sh=5)]
P["RO1"]=lambda **k: ro("RO1",**k); NB["RO1"]=[dict(ea=16*60+15),dict(ea=16*60+45),dict(xb=18*60+30),dict(xb=19*60+30)]
P["RO2"]=lambda **k: ro("RO2",**k); NB["RO2"]=[dict(ea=18*60+15),dict(xb=18*60+45),dict(xb=19*60+30)]
for v in("CS1","CS2"): P[v]=lambda v=v,**k: cs(v,**k); NB[v]=[dict(ea=60),dict(xb=6*60),dict(xb=10*60)]
P["VB1"]=lambda **k: vb(**{"K":0.5,**k}); NB["VB1"]=[dict(K=0.4),dict(K=0.6),dict(stopk=0.5),dict(stopk=0.9),dict(rr=2),dict(rr=4)]
P["VB2"]=lambda **k: vb(**{"K":0.7,**k}); NB["VB2"]=[dict(K=0.6),dict(K=0.8),dict(stopk=0.5),dict(stopk=0.9),dict(rr=2),dict(rr=4)]
for v,tf in [("VO1","M5"),("VO1","M15"),("VO1","H1"),("VO2","M5"),("VO2","M15"),("VO2","H1"),("VO3","M15"),("VO4","M15")]:
    P[f"{v}_{tf}"]=lambda v=v,tf=tf,**k: vo(v,tf,**k); NB[f"{v}_{tf}"]=[dict(rv=1.5),dict(rv=3.0),dict(rr=1.5),dict(rr=3.0)]
GSN={"GS1":[dict(N=10),dict(N=40),dict(ze=1.5),dict(ze=2.5)],"GS2":[dict(N=10),dict(N=40),dict(ze=1.5),dict(ze=2.5)]}
rows=[];TR={}
def rec(name,t,t8,t0,nbp):
    r=dict(name=name,**{f"is_{k}":v for k,v in summ(t).items()})
    r.update({f"va_{k}":v for k,v in summ(t,2025,2025).items() if k in("n","mean","pf","tot")})
    r["is_mean_c8"]=summ(t8)["mean"]; r["va_mean_c8"]=summ(t8,2025,2025)["mean"]; r["is_mean_c0"]=summ(t0)["mean"]
    r["nb_pos"]=sum(x>0 for x in nbp); r["nb_n"]=len(nbp); r["nb"]=";".join(f"{x:.3f}" for x in nbp)
    rows.append(r); print(name,r["is_n"],round(r["is_mean"],3),round(r["is_t"],2),r["is_pf"],r["va_mean"],flush=True)
for name,f in P.items():
    spec=f(); t=run(spec); TR[name]=t
    rec(name,t,run(spec,0.08),run(spec,0.0),[summ(run(f(**kw)))["mean"] for kw in NB[name]])
for v in("GS1","GS2"):
    t=gs(v); TR[v]=t
    rec(v,t,gs(v,comm=0.08),gs(v,comm=0.0),[summ(gs(v,**kw))["mean"] for kw in GSN[v]])
Sm=pd.DataFrame(rows); p=Sm.is_p.values; m=len(p); o=np.argsort(p); bh=np.zeros(m,bool)
pas=np.flatnonzero(p[o]<=(np.arange(1,m+1)/m)*0.05)
if len(pas): bh[o[:pas.max()+1]]=True
Sm["bh"]=bh; Sm["bonf"]=p<0.05/m
Sm.to_csv("/workspace/alien-research/out/lit/summary.csv",index=False); pickle.dump(TR,open("/workspace/alien-research/out/lit/trades.pkl","wb"))
print("done",time.time()-T0)
