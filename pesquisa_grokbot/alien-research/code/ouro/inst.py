import numpy as np, pandas as pd
from strats import window, at_clock, tradedays
R="/workspace/alien-research/"

def fade_follow(D,ma,mb,ea,xb,sgn,days=None):
    L=D["lhm"]; a=at_clock(D,L,ma); b=at_clock(D,L,mb-1)
    sa=pd.Series(a,index=D["sdate"][a]); sb=pd.Series(b,index=D["sdate"][b]); j=pd.concat([sa,sb],axis=1,join="inner")
    mv=pd.Series(D["mid"][j[1].values,3]-D["mid"][j[0].values,0],index=j.index)
    def f(ei,xi):
        sd=D["sdate"][ei]; s=pd.Series(sd).map(mv).fillna(0).values
        out=(sgn*np.sign(s)).astype(np.int64)
        if days is not None: out[~np.isin(sd,days)]=0
        return out
    return window(D,L,ea,xb,f)

def month_days(D,last=3,first=1):
    td=tradedays(D); g=pd.DataFrame({"sd":td.values,"ym":td.index.year*12+td.index.month})
    g["k"]=g.groupby("ym").cumcount()+1; g["r"]=g.groupby("ym")["k"].transform("max")-g["k"]+1
    return g.sd[(g.r<=last)|(g.k<=first)].values

def inst(C,var,sh=0,pct=90,N=156,chg=1):
    D=C.D
    if var=="IN1": return fade_follow(D,600+sh,630+sh,630+sh,690+sh,-1)
    if var=="IN2": return fade_follow(D,600+sh,630+sh,630+sh,690+sh,1)
    if var=="IN3": return fade_follow(D,810+sh,855+sh,855+sh,900+sh,1)
    if var in("IN4","IN5"):
        ei,dr,st,tg,xi=window(D,D["lhm"],930+sh,965+sh,1 if var=="IN4" else -1)
        m=np.isin(D["sdate"][ei],month_days(D)); return ei[m],dr[m],st[m],tg[m],xi[m]
    if var=="IN6":
        return fade_follow(D,720,955+sh,960+sh,1020+sh,-1,days=month_days(D,1,0))
    # COT
    c=pd.read_csv(R+"data/cot/gold_cot.csv",parse_dates=["date"])
    mm=(c.M_Money_Positions_Long_All-c.M_Money_Positions_Short_All)/c.Open_Interest_All
    sw=(c.Swap_Positions_Long_All-c.Swap__Positions_Short_All)/c.Open_Interest_All
    def pr(x): return x.rolling(N).apply(lambda w:(w[:-1]<w[-1]).mean()*100,raw=True)
    if var=="IN7": p=pr(mm); sig=np.where(p>pct,-1,np.where(p<100-pct,1,0))
    if var=="IN9": p=pr(sw); sig=np.where(p>pct,1,np.where(p<100-pct,-1,0))
    if var=="IN8": sig=np.sign(mm.diff(chg)).fillna(0).values
    ei0,dr0,st0,tg0,xi0=window(D,D["hm"],18*60+5,16*60+45,1)
    sd=D["sdate"][ei0]; E=[];X=[];DR=[]
    rd=(c.date.values.astype("datetime64[D]").astype(np.int64))
    for k in range(len(c)):
        if sig[k]==0: continue
        a,b=rd[k]+6,rd[k]+10
        m=np.flatnonzero((sd>=a)&(sd<=b))
        if len(m)==0: continue
        E.append(ei0[m[0]]); X.append(xi0[m[-1]]); DR.append(int(sig[k]))
    E=np.array(E,np.int64); n=len(E)
    return E,np.array(DR,np.int64),np.full(n,np.nan),np.full(n,np.nan),np.array(X,np.int64)
