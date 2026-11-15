import numpy as np, pandas as pd
from core import *

def sess_levels(D):
    m=D["mid"]; sd=D["sdate"]
    g=pd.DataFrame({"sd":sd,"h":m[:,1],"l":m[:,2]}).groupby("sd").agg(h=("h","max"),l=("l","min"))
    g=g[pd.to_datetime(g.index,unit="D").dayofweek<5]
    pdh=g.h.shift(1); pdl=g.l.shift(1)
    wk=pd.to_datetime(g.index,unit="D").to_period("W-SUN")
    w=g.groupby(wk).agg(h=("h","max"),l=("l","min")); pw=w.shift(1)
    pwh=pd.Series(pw.h.reindex(wk).values,index=g.index); pwl=pd.Series(pw.l.reindex(wk).values,index=g.index)
    return pdh,pdl,pwh,pwl

def eq_levels(D,B15):
    """for each M15 bar index i: list of active EQ (highs,lows) after bar i closes"""
    h,l=B15["h"],B15["l"]; A=atr(B15); n=len(h)
    fh=[];fl=[]; eqh={};eql={}  # level-> created bar
    snap_h=[None]*n; snap_l=[None]*n
    for i in range(n):
        # violations by this bar
        for lv in [x for x in eqh if h[i]>x]: del eqh[lv]
        for lv in [x for x in eql if l[i]<x]: del eql[lv]
        fh=[(p,k) for p,k in fh if p>=h[i] and i-k<=48]; fl=[(p,k) for p,k in fl if p<=l[i] and i-k<=48]
        for lv in [x for x,k in eqh.items() if i-k>48]: del eqh[lv]
        for lv in [x for x,k in eql.items() if i-k>48]: del eql[lv]
        k=i-2
        if k>=2 and h[k]>max(h[k-1],h[k-2],h[k+1],h[k+2]):
            for p,kk in fh:
                if abs(p-h[k])<0.1*A[i]: eqh[max(p,h[k])]=i
            if h[k]>=max(h[k+1:i+1]): fh.append((h[k],k))
        if k>=2 and l[k]<min(l[k-1],l[k-2],l[k+1],l[k+2]):
            for p,kk in fl:
                if abs(p-l[k])<0.1*A[i]: eql[min(p,l[k])]=i
            if l[k]<=min(l[k+1:i+1]): fl.append((l[k],k))
        snap_h[i]=tuple(eqh); snap_l[i]=tuple(eql)
    return snap_h,snap_l

def events(D,B,level,B15=None,eqs=None,lv=None):
    """returns arrays: bar idx, dir (+1 buy at low sweep, -1 sell at high sweep), extreme"""
    o,h,l,c,last=B["o"],B["h"],B["l"],B["c"],B["last"]
    sd=D["sdate"][last]; hm=D["hm"][last]
    out=[]
    if level in("PD","PW"):
        pdh,pdl,pwh,pwl=lv
        H=(pdh if level=="PD" else pwh).reindex(sd).values; L=(pdl if level=="PD" else pwl).reindex(sd).values
        hi=(o<H)&(h>H)&(c<H); lo=(o>L)&(l<L)&(c>L)
        df=pd.DataFrame({"i":np.arange(len(o)),"sd":sd,"hi":hi,"lo":lo})
        for col,d,ext in (("hi",-1,h),("lo",1,l)):
            x=df[df[col]].groupby("sd").i.first().values
            out.append(np.c_[x,np.full(len(x),d),ext[x]])
    else:
        sh,sl=eqs; l15=B15["last"]
        p=np.searchsorted(l15,last,side="right")-1  # last fully closed M15 at/before bar end
        # level available = snapshot of M15 bar strictly before current bar start
        firstm=B["first"]; p=np.searchsorted(l15,firstm-1,side="right")-1
        used=set()
        for i in range(len(o)):
            q=p[i]
            if q<0: continue
            for lvv in sh[q]:
                if o[i]<lvv<h[i] and c[i]<lvv and (lvv,1) not in used: out.append([[i,-1,h[i]]]); used.add((lvv,1)); break
            for lvv in sl[q]:
                if l[i]<lvv<o[i] and c[i]>lvv and (lvv,-1) not in used: out.append([[i,1,l[i]]]); used.add((lvv,-1)); break
        out=[np.array(x) for x in out] if out else [np.zeros((0,3))]
    E=np.vstack(out); E=E[np.argsort(E[:,0],kind="stable")]
    i=E[:,0].astype(np.int64); keep=~((hm[i]>=16*60)&(hm[i]<18*60))
    return i[keep],E[keep,1].astype(np.int64),E[keep,2]

def trades(D,B,ev,buf=0.1,rr=2.0,hold=None):
    i,d,ext=ev; A=atr(B)
    ei=B["last"][i]+1; ok=(ei<len(D["ts"]))
    i,d,ext,ei=i[ok],d[ok],ext[ok],ei[ok]
    ok=(D["ts"][ei]-D["ts"][B["last"][i]]<=5)
    i,d,ext,ei=i[ok],d[ok],ext[ok],ei[ok]
    a=A[i]; e=np.where(d>0,D["ask"][ei,0],D["bid"][ei,0])
    stop=ext-d*buf*a; risk=(e-stop)*d
    ok=(risk>0)&(risk<=3*a)
    i,d,e,stop,risk,ei=i[ok],d[ok],e[ok],stop[ok],risk[ok],ei[ok]
    tgt=e+d*rr*risk if hold is None else np.full(len(e),np.nan)
    h=240 if hold is None else hold
    xi=np.searchsorted(D["ts"],D["ts"][ei]+h,side="right")-1
    xi=np.minimum(xi,D["eod"][ei])
    from strats import nonoverlap
    ei,xi,d,stop,tgt=nonoverlap(ei,xi,d,stop,tgt)
    return ei,d,stop,tgt,xi

def path(D,B,ev):
    i,d,_=ev; A=atr(B); c0=B["c"][i]; t0=D["ts"][B["last"][i]]; a=A[i]; m=D["mid"]; ts=D["ts"]
    res={}
    for name,mins in (("1h",60),("4h",240),("eod",None)):
        s=B["last"][i]+1
        x=np.searchsorted(ts,t0+mins,side="right")-1 if mins else D["eod"][np.minimum(s,len(ts)-1)]
        x=np.maximum(x,s)
        r=(m[x,3]-c0)*d/a
        mfe=np.empty(len(i)); mae=np.empty(len(i))
        for k in range(len(i)):
            hh=m[s[k]:x[k]+1,1].max(); ll=m[s[k]:x[k]+1,2].min()
            mfe[k]=((hh-c0[k]) if d[k]>0 else (c0[k]-ll))/a[k]; mae[k]=((c0[k]-ll) if d[k]>0 else (hh-c0[k]))/a[k]
        res[name]=(r,mfe,mae)
    return res

def controls(D,B,ev_idx,n=12):
    o,h,l,c=B["o"],B["h"],B["l"],B["c"]
    mh=pd.Series(h).shift(1).rolling(n).max().values; ml=pd.Series(l).shift(1).rolling(n).min().values
    hi=(o<mh)&(h>mh)&(c<mh); lo=(o>ml)&(l<ml)&(c>ml)
    hm=D["hm"][B["last"]]; ok=~((hm>=16*60)&(hm<18*60))
    hi&=ok; lo&=ok; hi[ev_idx]=False; lo[ev_idx]=False
    i=np.r_[np.flatnonzero(hi),np.flatnonzero(lo)]; d=np.r_[-np.ones(hi.sum()),np.ones(lo.sum())].astype(np.int64)
    ext=np.r_[h[hi],l[lo]]; o_=np.argsort(i); return i[o_],d[o_],ext[o_]
