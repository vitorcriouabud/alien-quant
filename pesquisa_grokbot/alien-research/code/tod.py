import engine as E, families as F, numpy as np, pandas as pd
D=E.load("B")
r=F.tf_bars(D,15); print("median ATR(M15) USD by year:", r.atr.groupby(r.index.year).median().round(2).to_dict())
h=F.tf_bars(D,60).copy()
h["ret"]=np.log(h.c/h.o)*1e4; h["hr"]=h.hm//60; h["yr"]=h.index.year
p=h.pivot_table(index="hr",columns="yr",values="ret",aggfunc="mean").round(1)
t=h.groupby("hr").ret.agg(lambda x: x.mean()/x.std()*np.sqrt(len(x)))
p["t_all"]=t.round(1); print("mean hourly return (bp) by NY hour (bar start) and year"); print(p.to_string())
