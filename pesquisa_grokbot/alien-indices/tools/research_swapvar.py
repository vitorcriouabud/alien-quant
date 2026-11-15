import os, sys; os.environ['COSTS']='RF'
sys.path.insert(0,'/workspace/alien-research/code/v2')
import engine2 as E, fam2 as F, pandas as pd, numpy as np
syms={'usa500idxusd':-8.6,'usatechidxusd':-8.6,'deuidxeur':-7.2}
def basket(swapmode, start='2018-09-24'):
    out=[]
    for s,sl in syms.items():
        P=E.INSTR[s]
        if swapmode=='zero': P['swap']=(0.0,0.0)
        elif swapmode=='rf_now': P['swap']=(sl,-1.8)
        else: P['swap']=(-7.2,-1.8)
        r=E.resample(E.load_h1(s),'D1')
        for cid,kw in ((32,F.rsi2(r,10,3.0)),(35,F.ibs(r,0.25,4.0))):
            t=E.run(r,s,**kw); t['key']=f'{s}|{cid}'; out.append(t)
    T=pd.concat(out); T['exit']=pd.to_datetime(T.exit); T['entry']=pd.to_datetime(T.entry)
    T=T[T.entry.dt.tz_localize(None)>=pd.Timestamp(start)]
    d=T.groupby(T.exit.dt.tz_localize(None).dt.normalize()).R.sum()*0.01
    d=d.reindex(pd.date_range(start,'2026-11-13',freq='B'),fill_value=0); eq=(1+d).cumprod(); yrs=len(d)/261
    yr=eq.resample('YE').last(); yr=pd.concat([pd.Series([1.0],index=[pd.Timestamp(start)-pd.Timedelta(days=1)]),yr]).pct_change().dropna()
    return dict(n=len(T),sumR=T.R.sum(),meanR=T.R.mean(),cagr=eq.iloc[-1]**(1/yrs)-1,mdd=(1-eq/eq.cummax()).max(),pf=T.R[T.R>0].sum()/-T.R[T.R<0].sum(),years={k.year:round(v*100,1) for k,v in yr.items()})
for m in ('zero','research','rf_now'):
    print(m, {k:(round(v,4) if isinstance(v,float) else v) for k,v in basket(m).items()})
