import sys, pandas as pd, numpy as np
sys.path.insert(0, "."); import goat_sim as G, engine2 as E, fam2
rows=[]
for sk in (0.5, 1.0, 1.5, 2.0, 3.0, 4.0):
    out=[]
    for s in G.IDX:
        r=G.D1[s]
        for name, kw in (("RSI2", fam2.rsi2(r,10,sk,True)), ("IBS", fam2.ibs(r,0.25,sk))):
            t=E.run(r,s,**kw); t["y"]=t.entry.dt.year; out.append(t)
    t=pd.concat(out); n_yr=len(t)/10.9
    rows.append(dict(stopATR=sk, n=len(t), trades_yr=round(n_yr), expR=t.R.mean(), wr=(t.R>0).mean(), expR_2026=t[t.y>=2026].R.mean(),
       usd_yr_at_45=t.R.mean()*45*n_yr))
print(pd.DataFrame(rows).round(3).to_string())
