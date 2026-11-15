import numpy as np, pandas as pd
from core import *

def nonoverlap(ei,xi,*others):
    o=np.argsort(ei,kind="stable"); keep=[]; last=-1
    for k in o:
        if ei[k]>last and xi[k]>ei[k]: keep.append(k); last=xi[k]
    keep=np.array(keep,dtype=np.int64)
    return [a[keep] for a in (ei,xi)+others]

class Ctx:
    def __init__(s,D):
        s.D=D; ts=D["ts"]
        s.H1=bars_key(D,ts//60); s.H1["atr"]=atr(s.H1); s.H1["rsi"]=rsi2(s.H1["c"])
        k4=D["sdate"]*6+((D["hm"]-18*60)%1440)//240
        s.H4=bars_key(D,k4); s.H4["rsi"]=rsi2(s.H4["c"])
        # H1 atr regime
        a=s.H1["atr"]; s.H1["reg"]=a/pd.Series(a).shift(1).rolling(120).median().values

def mr(C,var,side="LS",thr=None,stopk=2.0,nb=8,reg=None):
    D=C.D; H=C.H1; hm=D["hm"]; ts=D["ts"]
    if var in("MR1","MR2","MR4"): B=H
    else: B=C.H4
    if var=="MR1": t=5 if thr is None else thr; L=B["rsi"]<t; S=B["rsi"]>100-t
    if var in("MR2","MR3"): t=10 if thr is None else thr; L=B["rsi"]<t; S=B["rsi"]>100-t
    if var=="MR4":
        t=2.5 if thr is None else thr; c=B["c"]; mv=c-np.r_[np.full(4,np.nan),c[:-4]]
        L=mv<-t*H["atr"]; S=mv>t*H["atr"]
    if side=="LO": S=S&False
    if reg=="low": m=H["reg"]<1; L&=m; S&=m
    if reg=="high": m=H["reg"]>=1; L&=m; S&=m
    sig=np.flatnonzero(L|S); sig=sig[sig<len(B["c"])-1]; sig=sig[sig>130]
    ei=B["last"][sig]+1; dr=np.where(L[sig],1,-1)
    ok=(ts[ei]-ts[B["last"][sig]]<=5)&~((hm[ei]>=16*60)&(hm[ei]<18*60))
    sig,ei,dr=sig[ok],ei[ok],dr[ok]
    hb=H["id"][ei]; xi=np.empty(len(ei),np.int64)
    c,h,l,last=H["c"],H["h"],H["l"],H["last"]; nH=len(c)
    for k in range(len(ei)):
        b=hb[k]; x=last[min(b+nb-1,nH-1)]
        for j in range(b,min(b+nb,nH)):
            if (dr[k]>0 and c[j]>h[j-1]) or (dr[k]<0 and c[j]<l[j-1]): x=last[j]; break
        xi[k]=min(x,D["eod"][ei[k]])
    a=H["atr"][H["id"][ei]-1]
    e=np.where(dr>0,D["ask"][ei,0],D["bid"][ei,0]); stop=e-dr*stopk*a
    ei,xi,dr,stop=nonoverlap(ei,xi,dr,stop)
    return ei,dr,stop,np.full(len(ei),np.nan),xi

def at_clock(D,clock,mins,days_ok=None):
    """first M1 index per session-date with clock-minute == mins (clock array hm or lhm)."""
    m=np.flatnonzero(clock==mins)
    sd=D["sdate"][m]; _,u=np.unique(sd,return_index=True); return m[u]

def window(D,clock,a,b,dr,lon=False):
    """enter at open of minute a, exit at close of minute b-1 (same session); weekdays only"""
    e=at_clock(D,clock,a); x=at_clock(D,clock,b-1)
    se=pd.Series(e,index=D["sdate"][e]); sx=pd.Series(x,index=D["sdate"][x])
    j=pd.concat([se,sx],axis=1,join="inner").dropna().astype(np.int64)
    ei=j[0].values; xi=j[1].values; ok=(xi>ei)&(D["ts"][xi]-D["ts"][ei]<(b-a)%1440+30)
    ei,xi=ei[ok],xi[ok]
    if np.isscalar(dr): drr=np.full(len(ei),dr)
    else: drr=dr(ei,xi)
    keep=drr!=0
    return ei[keep],drr[keep],np.full(keep.sum(),np.nan),np.full(keep.sum(),np.nan),xi[keep]

def fix(C,var,sh=0):
    D=C.D; L=D["lhm"]
    if var=="FX1": return window(D,L,615+sh,635+sh,-1)
    if var=="FX2": return window(D,L,615+sh,635+sh,1)
    if var=="FX3": return window(D,L,885+sh,905+sh,-1)
    if var=="FX4": return window(D,L,885+sh,905+sh,1)
    a=at_clock(D,L,840+sh); b=at_clock(D,L,899+sh)
    sa=pd.Series(a,index=D["sdate"][a]); sb=pd.Series(b,index=D["sdate"][b]); j=pd.concat([sa,sb],axis=1,join="inner")
    mv=pd.Series(D["mid"][j[1].values,3]-D["mid"][j[0].values,0],index=j.index)
    sgn=-1 if var=="FX5" else 1
    def f(ei,xi):
        s=pd.Series(D["sdate"][ei]).map(mv).fillna(0).values
        return (sgn*np.sign(s)).astype(np.int64)
    return window(D,L,900+sh,960+sh,f)

def ses(C,var,ea=None,xb=None):
    D=C.D; H=D["hm"]
    if var=="SE1": return window(D,H,ea or 18*60+5,xb or 8*60+20,1)
    if var=="SE2": return window(D,H,ea or 8*60+30,xb or 16*60+45,-1)

def tradedays(D):
    sd=np.unique(D["sdate"]); dts=pd.to_datetime(sd,unit="D")
    s=pd.Series(sd,index=dts); s=s[dts.dayofweek<5]
    return s

def cal(C,var,ea=18*60+5,xb=16*60+45,win=(2,3)):
    D=C.D; H=D["hm"]
    ei,dr,st,tg,xi=window(D,H,ea,xb,1)
    sd=D["sdate"][ei]; wd=pd.to_datetime(sd,unit="D").dayofweek.values
    if var.startswith("DW"):
        k=int(var[2])-1; m=wd==k
        return ei[m],dr[m],st[m],tg[m],xi[m]
    td=tradedays(D); dts=td.index; ym=dts.year*12+dts.month
    pos=pd.Series(np.arange(len(td)),index=td.values)
    g=pd.DataFrame({"sd":td.values,"ym":ym}); g["k"]=g.groupby("ym").cumcount()+1; g["r"]=g.groupby("ym")["k"].transform("max")-g["k"]+1
    tom=set(g.sd[(g.r<=win[0])|(g.k<=win[1])])
    if var=="ToMA":
        m=np.isin(sd,list(tom)); return ei[m],dr[m],st[m],tg[m],xi[m]
    # ToMB: continuous hold from first ToM day open to last ToM day close
    g["tom"]=g.sd.isin(tom); g["blk"]=(g.tom!=g.tom.shift()).cumsum()
    blocks=g[g.tom].groupby("blk").sd.agg(["min","max"])
    eis=pd.Series(ei,index=sd); xis=pd.Series(xi,index=sd)
    E=[];X=[]
    for a,b in blocks.values:
        if a in eis.index and b in xis.index: E.append(eis[a]); X.append(xis[b])
    E=np.array(E,np.int64); X=np.array(X,np.int64)
    return E,np.ones(len(E),np.int64),np.full(len(E),np.nan),np.full(len(E),np.nan),X
