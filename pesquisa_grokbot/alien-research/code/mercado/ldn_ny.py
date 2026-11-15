import sys, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/v2"); import engine2
for sym in ["xauusd","eurusd","gbpusd","usa500idxusd","usatechidxusd","deuidxeur"]:
    h = engine2.load_h1(sym); h = h[h.index >= "2021-01-01"]; hr = h.index.hour
    td = (h.index - pd.Timedelta(hours=18)).normalize()
    def S(a,b):
        m=(hr>=a)&(hr<b); g=h[m].groupby(td[m]); return pd.DataFrame(dict(O=g.open.first(),C=g.close.last()))
    L,N=S(2,8),S(8,16); j=L.join(N,lsuffix="L",rsuffix="N").dropna()
    sgn=np.sign(j.CL-j.OL); r=(np.log(j.CN/j.ON)*1e4)*sgn
    for p,m in (("2021-25",j.index.year<2026),("2026",j.index.year>=2026)):
        x=r[m]; print(sym,p,"n",len(x),"P_same",round((x>0).mean(),3),"mean NY move w/ London dir bp",round(x.mean(),2),"t",round(x.mean()/x.std()*np.sqrt(len(x)),2), "median |NY move| bp", round(np.abs(np.log(j.CN/j.ON)[m]*1e4).median(),1))
