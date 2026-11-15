import numpy as np, pandas as pd
from numba import njit
R="/workspace/alien-research/"
COMM=0.168

def load():
    df=pd.read_parquet(R+"data/xau_m1_2016_2026.parquet")
    t=df.index
    bid=df[["bo","bh","bl","bc"]].values.copy(); ask=df[["ao","ah","al","ac"]].values.copy()
    mid=(bid+ask)/2
    ny=t.tz_convert("America/New_York"); hm=np.asarray(ny.hour*60+ny.minute)
    ld=t.tz_convert("Europe/London"); lhm=np.asarray(ld.hour*60+ld.minute)
    # session date: day whose 17:00 NY close ends the session (session starts 18:00 previous day)
    sdate=np.asarray(((ny+pd.Timedelta(hours=6)).normalize()).tz_localize(None).values.astype("datetime64[D]").astype(np.int64))
    ts=np.asarray(t.as_unit("s").asi8//60)
    D=dict(t=t,ts=ts,mid=mid,bid=bid,ask=ask,hm=hm,lhm=lhm,sdate=sdate,year=np.asarray(t.year),
           nywd=np.asarray(ny.dayofweek))
    # eod index: last bar of the session with hm<16:45 (or hm>=18:00 before midnight not counted)
    n=len(ts); ok=~((hm>=16*60+45)&(hm<18*60))
    idx=np.arange(n); last=pd.Series(np.where(ok,idx,-1)).groupby(sdate).transform("max").values
    D["eod"]=last
    return D

@njit(cache=True)
def sim(bid,ask,ei,dr,stop,tgt,xi,comm):
    n=len(ei); pnl=np.empty(n); why=np.zeros(n,np.int64); xo=np.empty(n,np.int64)
    for k in range(n):
        i=ei[k]; d=dr[k]; s=stop[k]; g=tgt[k]
        e=ask[i,0] if d>0 else bid[i,0]
        px=np.nan; j=i
        for j in range(i,xi[k]+1):
            if d>0:
                if not np.isnan(s) and bid[j,2]<=s:
                    px=min(s,bid[j,0]); why[k]=1; break
                if j>i and not np.isnan(g) and bid[j,1]>=g:
                    px=max(g,bid[j,0]); why[k]=2; break
            else:
                if not np.isnan(s) and ask[j,1]>=s:
                    px=max(s,ask[j,0]); why[k]=1; break
                if j>i and not np.isnan(g) and ask[j,2]<=g:
                    px=min(g,ask[j,0]); why[k]=2; break
        if np.isnan(px):
            j=xi[k]; px=bid[j,3] if d>0 else ask[j,3]
        xo[k]=j
        pnl[k]=(px-e)*d-comm
    return pnl,why,xo

def bars_key(D,key):
    chg=np.r_[True,key[1:]!=key[:-1]]
    first=np.flatnonzero(chg); last=np.r_[first[1:]-1,len(key)-1]
    m=D["mid"]
    return dict(o=m[first,0],c=m[last,3],h=np.maximum.reduceat(m[:,1],first),l=np.minimum.reduceat(m[:,2],first),
                first=first,last=last,id=np.cumsum(chg)-1)

def atr(B,n=14):
    c=B["c"]; pc=np.r_[c[0],c[:-1]]
    tr=np.maximum(B["h"]-B["l"],np.maximum(abs(B["h"]-pc),abs(B["l"]-pc)))
    return pd.Series(tr).ewm(alpha=1/n,adjust=False).mean().values  # includes current bar (known at close)

def rsi2(c):
    d=np.diff(c,prepend=c[0]); up=np.maximum(d,0); dn=np.maximum(-d,0)
    au=pd.Series(up).ewm(alpha=0.5,adjust=False).mean().values; ad=pd.Series(dn).ewm(alpha=0.5,adjust=False).mean().values
    return 100-100/(1+au/np.maximum(ad,1e-12))
