import numpy as np, pandas as pd, pickle, sys, time
from scipy import stats
from core import *; from strats import *; import sweep as SW
T0=time.time()
D=load(); C=Ctx(D); print("loaded",time.time()-T0,flush=True)
SWAPL=-0.055/360; SWAPS=0.017/360

def run(spec, comm=COMM):
    ei,dr,st,tg,xi=spec
    pnl,why,xo=sim(D["bid"],D["ask"],ei.astype(np.int64),dr.astype(np.int64),st.astype(float),tg.astype(float),xi.astype(np.int64),comm)
    # swap if crossing rollover (sessions differ)
    nights=(D["sdate"][xo]-D["sdate"][ei]).astype(float)
    if nights.any():
        # count calendar sessions crossed incl. triple Wed
        sw=np.zeros(len(ei))
        for k in np.flatnonzero(nights>0):
            days=pd.to_datetime(np.arange(D["sdate"][ei[k]],D["sdate"][xo[k]]),unit="D")
            mult=sum(3 if dd.dayofweek==2 else 1 for dd in days if dd.dayofweek<5)
            px=D["mid"][ei[k],0]; sw[k]=mult*px*(SWAPL if dr[k]>0 else SWAPS)
        pnl=pnl+sw
    risk=np.where(np.isnan(st),np.nan,np.abs(np.where(dr>0,D["ask"][ei,0],D["bid"][ei,0])-st))
    return pd.DataFrame({"ei":ei,"xo":xo,"dr":dr,"pnl":pnl,"why":why,"risk":risk,"year":D["year"][ei],"sd":D["sdate"][xo]})

def summ(t,lo=2016,hi=2024):
    s=t[(t.year>=lo)&(t.year<=hi)]
    if len(s)<2: return dict(n=len(s),mean=np.nan,pf=np.nan,t=np.nan,p=1.0)
    dd=s.groupby("sd").pnl.sum(); tt=dd.mean()/dd.std(ddof=1)*np.sqrt(len(dd))
    g=s.pnl[s.pnl>0].sum(); b=-s.pnl[s.pnl<0].sum()
    q=s.pnl.sort_values(); k=max(1,int(round(len(q)*0.01)))
    tot=s.pnl.sum()
    return dict(n=len(s),mean=s.pnl.mean(),tot=tot,pf=g/b if b>0 else np.inf,t=tt,p=1-stats.t.cdf(tt,len(dd)-1),
        wr=(s.pnl>0).mean(),yrs=int((s.groupby("year").pnl.sum()>0).sum()),nyr=s.year.nunique(),
        ex1=q.iloc[:-k].sum(),maxday=dd.max()/tot if tot>0 else np.nan,
        risk_med=np.nanmedian(s.risk) if s.risk.notna().any() else np.nan,worst=s.pnl.min(),p01=q.quantile(0.01))

# ---------- specs ----------
P={}; NB={}
for v in("MR1","MR2","MR3","MR4"):
    for side in("LS","LO"):
        P[f"{v}_{side}"]=lambda v=v,side=side,**k: mr(C,v,side,**k)
th={"MR1":(3,7),"MR2":(7,15),"MR3":(7,15),"MR4":(2.0,3.0)}
for key in list(P):
    v=key[:3]
    NB[key]=[dict(thr=th[v][0]),dict(thr=th[v][1]),dict(stopk=1.5),dict(stopk=2.5),dict(nb=6),dict(nb=10)]
P["MR1_LS_lowvol"]=lambda **k: mr(C,"MR1","LS",reg="low",**k); NB["MR1_LS_lowvol"]=NB["MR1_LS"]
P["MR1_LS_highvol"]=lambda **k: mr(C,"MR1","LS",reg="high",**k); NB["MR1_LS_highvol"]=NB["MR1_LS"]
for v in("FX1","FX2","FX3","FX4","FX5","FX6"):
    P[v]=lambda v=v,**k: fix(C,v,**k); NB[v]=[dict(sh=-5),dict(sh=5)]
P["SE1"]=lambda **k: ses(C,"SE1",**k); NB["SE1"]=[dict(ea=19*60+5),dict(xb=7*60+20),dict(xb=9*60+20)]
P["SE2"]=lambda **k: ses(C,"SE2",**k); NB["SE2"]=[dict(ea=7*60+30),dict(ea=9*60+30),dict(xb=15*60+45)]
for k_ in range(1,6):
    P[f"DW{k_}"]=lambda k_=k_,**k: cal(C,f"DW{k_}",**k); NB[f"DW{k_}"]=[dict(ea=19*60+5),dict(xb=15*60+45)]
P["ToMA"]=lambda **k: cal(C,"ToMA",**k); NB["ToMA"]=[dict(win=(1,3)),dict(win=(2,2))]
P["ToMB"]=lambda **k: cal(C,"ToMB",**k); NB["ToMB"]=[dict(win=(1,3)),dict(win=(2,2))]
# sweeps
lv=SW.sess_levels(D); B5=bars_key(D,D["ts"]//5); B15=bars_key(D,D["ts"]//15)
eqs=SW.eq_levels(D,B15); print("eq done",time.time()-T0,flush=True)
EV={}
for L in("PD","PW","EQ"):
    for tf,B in(("M5",B5),("M15",B15)):
        EV[(L,tf)]=(B,SW.events(D,B,L,B15,eqs,lv))
        print(L,tf,len(EV[(L,tf)][1][0]),flush=True)
for (L,tf),(B,ev) in EV.items():
    P[f"SW_{L}_{tf}_2R"]=lambda B=B,ev=ev,**k: SW.trades(D,B,ev,**{"buf":0.1,"rr":2.0,**k})
    NB[f"SW_{L}_{tf}_2R"]=[dict(buf=0.0),dict(buf=0.2),dict(rr=1.5),dict(rr=3.0)]
    P[f"SW_{L}_{tf}_4h"]=lambda B=B,ev=ev,**k: SW.trades(D,B,ev,**{"buf":0.1,"hold":240,**k})
    NB[f"SW_{L}_{tf}_4h"]=[dict(buf=0.0),dict(buf=0.2),dict(hold=120),dict(hold=360)]
import inst as IN
for v in ("IN1","IN2","IN3","IN4","IN5","IN6","IN7","IN8","IN9"):
    P[v]=lambda v=v,**k: IN.inst(C,v,**k)
    NB[v]={"IN6":[dict(sh=-30),dict(sh=30)],"IN7":[dict(pct=80),dict(N=104),dict(N=260)],"IN9":[dict(pct=80),dict(N=104),dict(N=260)],"IN8":[dict(chg=2)]}.get(v,[dict(sh=-5),dict(sh=5)])
assert len(P)==46, len(P)

rows=[]; TR={}
for name,f in P.items():
    spec=f(); t=run(spec); TR[name]=t
    r=dict(name=name,**{f"is_{k}":v for k,v in summ(t).items()})
    r.update({f"va_{k}":v for k,v in summ(t,2025,2025).items() if k in("n","mean","pf","tot")})
    t8=run(spec,0.08); r["is_mean_c8"]=summ(t8)["mean"]; r["va_mean_c8"]=summ(t8,2025,2025)["mean"]
    tz=run(spec,0.0); r["is_mean_c0"]=summ(tz)["mean"]
    nbp=[summ(run(f(**kw)))["mean"] for kw in NB[name]]
    r["nb_pos"]=sum(x>0 for x in nbp); r["nb_n"]=len(nbp)
    rows.append(r); print(name, r["is_n"], round(r["is_mean"],3), round(r["is_t"],2), flush=True)
S=pd.DataFrame(rows)
p=S.is_p.values; m=len(p); o=np.argsort(p); bh=np.zeros(m,bool)
thr=(np.arange(1,m+1)/m)*0.05; passed=np.flatnonzero(p[o]<=thr)
if len(passed): bh[o[:passed.max()+1]]=True
S["bh"]=bh; S["bonf"]=p<0.05/m
S.to_csv(R+"out/ouro/summary.csv",index=False)
pickle.dump(TR,open(R+"out/ouro/trades.pkl","wb"))
# path study (IS only, descriptive)
prow=[]
for (L,tf),(B,ev) in EV.items():
    yr=D["year"][B["last"][ev[0]]]; m_=yr<=2024; e2=tuple(x[m_] for x in ev)
    ce=SW.controls(D,B,ev[0]); cy=D["year"][B["last"][ce[0]]]; cm=cy<=2024
    rng=np.random.default_rng(0); sel=np.flatnonzero(cm); sel=rng.choice(sel,min(len(sel),60000),replace=False); sel.sort()
    c2=tuple(x[sel] for x in ce)
    pe=SW.path(D,B,e2); pc=SW.path(D,B,c2)
    for h in("1h","4h","eod"):
        prow.append(dict(level=L,tf=tf,h=h,n=len(e2[0]),rev_rate=(pe[h][0]>0).mean(),ret=pe[h][0].mean(),mfe=pe[h][1].mean(),mae=pe[h][2].mean(),
            ctl_n=len(c2[0]),ctl_rev=(pc[h][0]>0).mean(),ctl_ret=pc[h][0].mean(),
            diff_t=stats.ttest_ind(pe[h][0],pc[h][0],equal_var=False).statistic,
            top1share=np.sort(pe[h][0])[-max(1,len(e2[0])//100):].sum()/pe[h][0].sum() if pe[h][0].sum()!=0 else np.nan))
pd.DataFrame(prow).to_csv(R+"out/ouro/sweep_path.csv",index=False)
print("done",time.time()-T0)
