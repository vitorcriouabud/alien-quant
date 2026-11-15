"""Displacement study core: data, events, context, path, execution (numba)."""
import numpy as np, pandas as pd
from numba import njit
R="/workspace/alien-research/"
COMM_MAIN=0.168; COMM_LOW=0.08

def load():
    df=pd.read_parquet(R+"data/xau_m1_2016_2026.parquet")
    t=df.index
    bid=df[["bo","bh","bl","bc"]].values; ask=df[["ao","ah","al","ac"]].values
    mid=(bid+ask)/2
    ny=t.tz_convert("America/New_York"); hm=np.asarray(ny.hour*60+ny.minute)
    flat=((hm>=16*60+50)&(hm<18*60))|(np.asarray(ny.dayofweek)==5)
    tday=np.asarray(((ny-pd.Timedelta(hours=18)).normalize()).tz_localize(None).values.astype("datetime64[D]").astype(np.int64))
    ts=np.asarray(t.as_unit("s").asi8//60)  # minutes since epoch
    return dict(t=t,ts=ts,mid=mid,bid=bid,ask=ask,flat=flat,hm=hm,tday=tday,year=np.asarray(t.year))

def spreads(D,scen):
    if scen=="real": return D["bid"],D["ask"]
    sp=np.maximum(0.10,0.5*(D["ask"]-D["bid"])); m=D["mid"]
    return m-sp/2,m+sp/2

def bars(D,mins):
    """Aggregate mid M1 to `mins` bars. returns dict with o,h,l,c, start ts, last M1 index."""
    ts=D["ts"]; key=ts//mins
    chg=np.r_[True,key[1:]!=key[:-1]]
    first=np.flatnonzero(chg); last=np.r_[first[1:]-1,len(ts)-1]
    m=D["mid"]
    o=m[first,0]; c=m[last,3]
    h=np.maximum.reduceat(m[:,1],first); l=np.minimum.reduceat(m[:,2],first)
    return dict(o=o,h=h,l=l,c=c,start=key[first]*mins,first=first,last=last,mins=mins)

def atr(B,n=14):
    pc=np.r_[B["c"][0],B["c"][:-1]]
    tr=np.maximum(B["h"]-B["l"],np.maximum(abs(B["h"]-pc),abs(B["l"]-pc)))
    a=pd.Series(tr).ewm(alpha=1/n,adjust=False).mean().values
    return np.r_[np.nan,a[:-1]]  # ATR up to previous bar

def events(B,defn,mult=1.0):
    A=atr(B); o,h,l,c=B["o"],B["h"],B["l"],B["c"]; rng=h-l; body=c-o
    if defn==1: ev=(rng>=2.0*mult*A)&(abs(body)>=0.6*rng); d=np.sign(body)
    elif defn==2: ev=abs(body)>=1.5*mult*A; d=np.sign(body)
    else:
        o2=np.r_[np.nan,np.nan,o[:-2]]; mv=c-o2; ev=abs(mv)>=2.5*mult*A; d=np.sign(mv)
    ev&=np.isfinite(A)&(d!=0); ev[:50]=False
    idx=np.flatnonzero(ev); keep=[]; lastk=-10
    for i in idx:
        if i-lastk>4: keep.append(i); lastk=i
    idx=np.array(keep,dtype=np.int64)
    return idx,d[idx].astype(np.int64),A[idx]

def h1_context(D):
    H=bars(D,60); c=H["c"]
    dc=np.abs(np.diff(c,prepend=c[0])); s=pd.Series(dc).rolling(24).sum().values
    net=c-np.r_[np.full(24,np.nan),c[:-24]]; er=np.abs(net)/s
    A=pd.Series(np.maximum(H["h"]-H["l"],0)).ewm(alpha=1/14,adjust=False).mean().values  # simple ATR proxy on H1
    pc=np.r_[c[0],c[:-1]]; tr=np.maximum(H["h"]-H["l"],np.maximum(abs(H["h"]-pc),abs(H["l"]-pc)))
    A=pd.Series(tr).ewm(alpha=1/14,adjust=False).mean().values
    comp=A/pd.Series(A).shift(1).rolling(120).median().values
    end=H["start"]+60
    return dict(end=end,er=er,dir=np.sign(net),comp=comp)

def context_for(Hc,t_close,d):
    """t_close: event close minute ts. uses last H1 bar with end<=t_close. 0 trend-with,1 trend-against,2 compressed,3 range, -1 na"""
    j=np.searchsorted(Hc["end"],t_close,side="right")-1
    er=Hc["er"][j]; hd=Hc["dir"][j]; cp=Hc["comp"][j]
    ctx=np.full(len(j),3)
    tr=er>=0.30
    ctx[tr&(hd==d)]=0; ctx[tr&(hd!=d)]=1; ctx[(~tr)&(cp<0.80)]=2
    ctx[~np.isfinite(er)|~np.isfinite(cp)|(j<0)]=-1
    return ctx

def session(hm_close):
    # NY minute of event close; Asia 18:00-02:59, London 03:00-07:59, NY 08:00-16:49 ; -1 flat
    s=np.full(len(hm_close),-1)
    s[(hm_close>=18*60)|(hm_close<3*60)]=0
    s[(hm_close>=3*60)&(hm_close<8*60)]=1
    s[(hm_close>=8*60)&(hm_close<16*60+50)]=2
    return s

@njit(cache=True)
def path(mh,ml,mc,ts,e_last,d,A,hmins):
    """from close of M1 index e_last. returns ret[h],mfe[h],mae[h] in ATR, t_mfe (min) over last horizon"""
    n=len(e_last); H=len(hmins)
    ret=np.full((n,H),np.nan); mfe=np.full((n,H),np.nan); mae=np.full((n,H),np.nan); tm=np.full(n,np.nan)
    N=len(mc)
    for k in range(n):
        i=e_last[k]; p0=mc[i]; t0=ts[i]; dd=d[k]; a=A[k]
        best=0.0; worst=0.0; tb=0.0; hh=0; j=i+1
        while j<N and hh<H:
            if ts[j]-t0>hmins[hh]:
                if j-1>i:
                    ret[k,hh]=dd*(mc[j-1]-p0)/a; mfe[k,hh]=best/a; mae[k,hh]=worst/a
                hh+=1; continue
            fav=(mh[j]-p0) if dd>0 else (p0-ml[j]); adv=(p0-ml[j]) if dd>0 else (mh[j]-p0)
            if fav>best: best=fav; tb=ts[j]-t0
            if adv>worst: worst=adv
            j+=1
        tm[k]=tb
    return ret,mfe,mae,tm

@njit(cache=True)
def simulate(bid,ask,flat,ts,ent,dirs,sl,tp,maxmin,comm):
    """ent: M1 index of market entry (at open). sequential, one position at a time.
    returns pnl per oz (nan if skipped), exit index"""
    n=len(ent); pnl=np.full(n,np.nan); exi=np.full(n,-1); busy=-1; N=len(ts)
    for k in range(n):
        i=ent[k]
        if i<0 or i>=N or i<=busy or flat[i]: continue
        d=dirs[k]
        fill=ask[i,0] if d>0 else bid[i,0]
        S=fill-d*sl[k]; T=fill+d*tp[k]; t0=ts[i]; res=np.nan; j=i
        while j<N:
            if j>i and (flat[j] or ts[j]-t0>maxmin):
                px=bid[j,0] if d>0 else ask[j,0]; res=d*(px-fill); break
            if d>0:
                lo=bid[j,2]; hi=bid[j,1]; op=bid[j,0]
                if lo<=S:
                    px=min(S,op) if j>i else S; res=px-fill; break
                if hi>=T and j>i:
                    res=max(T,op)-fill if op>=T else T-fill; break
            else:
                hi=ask[j,1]; lo=ask[j,2]; op=ask[j,0]
                if hi>=S:
                    px=max(S,op) if j>i else S; res=fill-px; break
                if lo<=T and j>i:
                    res=fill-(min(T,op) if op<=T else T); break
            j+=1
        if j>=N: continue
        pnl[k]=res-comm; exi[k]=j; busy=j
    return pnl,exi

@njit(cache=True)
def entry_A(o5,c5,last5,first5_after,d,fade,maxbars):
    """first5_after: index of first M5 bar after event. returns (M5 trigger idx, entry M1 idx)"""
    n=len(d); trig=np.full(n,-1); ent=np.full(n,-1); N5=len(c5)
    for k in range(n):
        s=first5_after[k]; seen=False
        for b in range(s,min(s+maxbars,N5)):
            mv=np.sign(c5[b]-o5[b])
            if fade:
                if mv==-d[k]: trig[k]=b; ent[k]=last5[b]+1; break
            else:
                if mv==-d[k]: seen=True
                elif mv==d[k] and seen: trig[k]=b; ent[k]=last5[b]+1; break
    return trig,ent

@njit(cache=True)
def entry_B(trig,h5,l5,last5,mc,tdir,nm1):
    n=len(trig); ent=np.full(n,-1)
    for k in range(n):
        b=trig[k]
        if b<0: continue
        i0=last5[b]+1
        for j in range(i0,min(i0+nm1,len(mc)-1)):
            if (tdir[k]>0 and mc[j]>h5[b]) or (tdir[k]<0 and mc[j]<l5[b]): ent[k]=j+1; break
    return ent
