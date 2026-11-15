import numpy as np, pandas as pd, sys, json
from scipy import stats
from core import *
OUT=R+"out/desloc/"; import os; os.makedirs(OUT,exist_ok=True)
D=load(); mid=D["mid"]; mh,ml,mc=mid[:,1].copy(),mid[:,2].copy(),mid[:,3].copy(); ts=D["ts"]
Hc=h1_context(D)
B={5:bars(D,5),15:bars(D,15)}
YEAR=D["year"]; TDAY=D["tday"]
CTXN=["tend_favor","tend_contra","comprimido","lateral"]; SESN=["Asia","Londres","NY"]

def ev_table(tf,defn,mult=1.0):
    Bt=B[tf]; idx,d,A=events(Bt,defn,mult)
    last=Bt["last"][idx]; tclose=Bt["start"][idx]+tf
    ctx=context_for(Hc,tclose,d); ses=session(D["hm"][last]+1 if False else ((D["hm"][last]+1)%1440))
    return pd.DataFrame(dict(bi=idx,last=last,d=d,A=A,ctx=ctx,ses=ses,year=YEAR[last],tday=TDAY[last]))

# ---------------- path study ----------------
HM=np.array([15,60,240],dtype=np.int64)
def path_study():
    rows=[]; conc=[]
    for tf in (15,5):
        Bt=B[tf]; At=atr(Bt)
        # control: all bars, direction = sign of body
        allb=np.arange(60,len(Bt["c"])); dall=np.sign(Bt["c"]-Bt["o"])[allb].astype(np.int64)
        ok=(dall!=0)&np.isfinite(At[allb]); allb,dall=allb[ok],dall[ok]
        lastc=Bt["last"][allb]; tcl=Bt["start"][allb]+tf
        cctx=context_for(Hc,tcl,dall); cses=session((D["hm"][lastc]+1)%1440)
        r,_,_,_=path(mh,ml,mc,ts,lastc,dall,At[allb],HM)
        C=pd.DataFrame(dict(bi=allb,ctx=cctx,ses=cses,year=YEAR[lastc],r60=r[:,1]))
        for defn in (1,2,3):
            E=ev_table(tf,defn); E=E[(E.ctx>=0)&(E.ses>=0)]
            r,mfe,mae,tm=path(mh,ml,mc,ts,E["last"].values,E["d"].values,E["A"].values,HM)
            for h,hn in enumerate(["15m","1h","4h"]):
                E[f"r_{hn}"]=r[:,h]; E[f"mfe_{hn}"]=mfe[:,h]; E[f"mae_{hn}"]=mae[:,h]
            E["tmfe"]=tm
            Cn=C[~C.bi.isin(E.bi)&(C.ctx>=0)&(C.ses>=0)]
            cm=Cn.groupby(["year","ses","ctx"]).r60.mean().rename("ctrl")
            E=E.join(cm,on=["year","ses","ctx"]); E["ex"]=E["r_1h"]-E["ctrl"]
            E.to_parquet(OUT+f"path_M{tf}_D{defn}.parquet")
            IS=E[E.year<=2024]
            def summ(G,label):
                g=G.dropna(subset=["ex"]); dd=g.groupby("tday").ex.mean()
                t,p=stats.ttest_1samp(dd,0) if len(dd)>2 else (np.nan,np.nan)
                return dict(tf=f"M{tf}",defn=f"D{defn}",grupo=label,n=len(g),
                    r15=g.r_15m.mean(),r1h=g.r_1h.mean(),r4h=g.r_4h.mean(),ctrl1h=g.ctrl.mean(),ex1h=g.ex.mean(),
                    t_ex=t,p_ex=p,mfe1h=g.mfe_1h.mean(),mae1h=g.mae_1h.mean(),mfe4h=g.mfe_4h.mean(),mae4h=g.mae_4h.mean(),
                    tmfe_med=g.tmfe.median(),pct_cont1h=(g.r_1h>0).mean())
            rows.append(summ(IS,"IS_todos"))
            rows.append(summ(E[E.year==2025],"2025_todos"))
            for c in range(4): rows.append(summ(IS[IS.ctx==c],"IS_"+CTXN[c]))
            for s in range(3): rows.append(summ(IS[IS.ses==s],"IS_"+SESN[s]))
            x=IS.r_1h.dropna().values; xs=np.sort(np.abs(x))[::-1]
            # concentration: share of |sum| from top events by absolute move
            tot=x.sum(); srt=np.sort(x)[::-1]
            conc.append(dict(tf=f"M{tf}",defn=f"D{defn}",n=len(x),soma_r1h=tot,
                top1pct_soma=srt[:max(1,len(x)//100)].sum(),top5pct_soma=srt[:max(1,len(x)//20)].sum(),
                soma_sem_top1pct=srt[max(1,len(x)//100):].sum()))
    P=pd.DataFrame(rows); P.to_csv(OUT+"path_summary.csv",index=False)
    pd.DataFrame(conc).to_csv(OUT+"path_concentration.csv",index=False)
    return P

# ---------------- execution ----------------
def first5_after(last_m1):
    # first M5 bar whose first M1 index > last_m1
    return np.searchsorted(B[5]["first"],last_m1,side="right").astype(np.int64)

def run_exec(tf,defn,var,fade,scen="real",comm=COMM_MAIN,slm=1.0,tpm=1.5,mult=1.0):
    E=ev_table(tf,defn,mult); E=E[(E.ctx>=0)&(E.ses>=0)].reset_index(drop=True)
    d=E.d.values.astype(np.int64); tdir=(-d if fade else d).astype(np.int64); last=E["last"].values.astype(np.int64)
    if var=="C": ent=last+1
    else:
        B5=B[5]; f5=first5_after(last)
        trig,entA=entry_A(B5["o"],B5["c"],B5["last"],f5,d,fade,12)
        ent=entA if var=="A" else entry_B(trig,B5["h"],B5["l"],B5["last"],mc,tdir,5)
    ent=ent.astype(np.int64)
    # only allow entries within 75 min of event (A/B windows) - already bounded
    o=np.argsort(np.where(ent<0,np.iinfo(np.int64).max,ent),kind="stable"); E=E.iloc[o].reset_index(drop=True); ent=ent[o]; tdir=tdir[o]
    bid,ask=spreads(D,scen)
    maxmin=240 if tf==15 else 60
    pnl,exi=simulate(bid,ask,D["flat"],ts,ent,tdir,slm*E.A.values,tpm*E.A.values,maxmin,comm)
    E["pnl"]=pnl; E["ent"]=ent; E["tdir"]=tdir
    T=E.dropna(subset=["pnl"]).copy(); T["year"]=YEAR[T.ent.values]; T["tday"]=TDAY[T.ent.values]
    return T

def metrics(T):
    if len(T)<2: return dict(n=len(T))
    x=T.pnl.values; dd=T.groupby("tday").pnl.sum()
    t,p=stats.ttest_1samp(dd,0); p1=p/2 if t>0 else 1-p/2
    gw=x[x>0].sum(); gl=-x[x<0].sum()
    yr=T.groupby("year").pnl.sum()
    srt=np.sort(x)[::-1]; k=max(1,len(x)//100)
    return dict(n=len(x),media=x.mean(),soma=x.sum(),pf=gw/gl if gl>0 else np.nan,acerto=(x>0).mean(),
        t=t,p=p1,anos_pos=int((yr>0).sum()),anos=len(yr),sem_top1=srt[k:].sum(),
        maior_dia_pct=dd.max()/x.sum() if x.sum()>0 else np.nan)

TESTS=[(15,df,v,f) for df in (1,2,3) for v in ("C","A","B") for f in (False,True)]+[(5,df,"C",f) for df in (1,2,3) for f in (False,True)]
def main_tests():
    rows=[]; allT={}
    for (tf,defn,var,fade) in TESTS:
        T=run_exec(tf,defn,var,fade); name=f"M{tf}_D{defn}_{var}_{'FADE' if fade else 'CONT'}"
        allT[name]=T; IS=T[T.year<=2024]
        m=metrics(IS); m.update(teste=name,grupo="todos"); rows.append(m)
        for c in range(4):
            mm=metrics(IS[IS.ctx==c]); mm.update(teste=name,grupo=CTXN[c]); rows.append(mm)
        for s in range(3):
            mm=metrics(IS[IS.ses==s]); mm.update(teste=name,grupo=SESN[s]); rows.append(mm)
        # (ctx x ses) as pre-registered 4x3 = 12 conditional cells
        for c in range(4):
            for s in range(3):
                mm=metrics(IS[(IS.ctx==c)&(IS.ses==s)]); mm.update(teste=name,grupo=f"{CTXN[c]}|{SESN[s]}"); rows.append(mm)
        T.to_parquet(OUT+f"trades_{name}.parquet")
        print(name,{k:(round(v,3) if isinstance(v,float) else v) for k,v in m.items() if k in("n","media","pf","p","anos_pos")},flush=True)
    M=pd.DataFrame(rows)
    return M,allT

if __name__=="__main__":
    P=path_study(); print(P.round(3).to_string())
    M,allT=main_tests(); M.to_csv(OUT+"exec_raw.csv",index=False)
