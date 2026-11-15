# Replica as regras do ALIEN PROFESSOR (parametros padrao) e testa os sinais.
# Pre-registro: /workspace/alien-professor/TESTE_SINAIS.md  (2026 NUNCA é carregado)
import sys, glob, numpy as np, pandas as pd
from numba import njit
from scipy import stats
R="/workspace/alien-research/"
CUT=pd.Timestamp("2026-01-01",tz="UTC")
L=3
# ---------------------------------------------------------------- helpers
def srv_minutes(idx_utc):
    ny=idx_utc.tz_convert("America/New_York").tz_localize(None)
    srv=ny+pd.Timedelta(hours=7)
    return (srv.values.astype("datetime64[m]").astype(np.int64)), ny
def bars(key,o,h,l,c,v=None):
    chg=np.r_[True,key[1:]!=key[:-1]]; f=np.flatnonzero(chg); la=np.r_[f[1:]-1,len(key)-1]
    out=dict(key=key[f],o=o[f],h=np.maximum.reduceat(h,f),l=np.minimum.reduceat(l,f),c=c[la],first=f,last=la)
    out["v"]=np.add.reduceat(v,f) if v is not None else np.zeros(len(f))
    return out

@njit(cache=True)
def ema(c,n):
    k=2.0/(n+1); e=np.empty(len(c)); e[0]=c[0]
    for i in range(1,len(c)): e[i]=c[i]*k+e[i-1]*(1-k)
    return e
@njit(cache=True)
def atr_sma(h,l,c,n):
    out=np.full(len(c),np.nan)
    for i in range(n,len(c)):
        s=0.0
        for k in range(i-n+1,i+1):
            s+=max(h[k],c[k-1])-min(l[k],c[k-1])
        out[i]=s/n
    return out
@njit(cache=True)
def swings(h,l,Lw):
    n=len(h); sh=np.zeros(n,np.bool_); sl=np.zeros(n,np.bool_)
    for j in range(Lw,n-Lw):
        okh=True; okl=True
        for m in range(1,Lw+1):
            if h[j+m]>=h[j] or h[j-m]>h[j]: okh=False
            if l[j+m]<=l[j] or l[j-m]<l[j]: okl=False
        sh[j]=okh; sl[j]=okl
    return sh,sl
@njit(cache=True)
def trend_h1(h,l,c):
    n=len(c); e=ema(c,200); a=atr_sma(h,l,c,14); sh,sl=swings(h,l,3)
    tr=np.zeros(n,np.int64)
    s0=np.nan;s1=np.nan;l0=np.nan;l1=np.nan
    for k in range(n):
        j=k-3
        if j>=3:
            if sh[j]: s1=s0; s0=h[j]
            if sl[j]: l1=l0; l0=l[j]
        if k<210 or np.isnan(a[k]): continue
        sl_=0
        if e[k]-e[k-5]>0.05*a[k]: sl_=1
        elif e[k-5]-e[k]>0.05*a[k]: sl_=-1
        side=1 if c[k]>e[k] else -1
        st=0
        if not np.isnan(s1) and not np.isnan(l1):
            if s0>s1 and l0>l1: st=1
            elif s0<s1 and l0<l1: st=-1
        sc=sl_+side+st
        tr[k]=1 if sc>=2 else (-1 if sc<=-2 else 0)
    return tr

# HTF FVG tracker: returns for each M5 bar i flags inside bull / inside bear (unfilled HTF FVG, formed within 200 HTF bars)
@njit(cache=True)
def htf_inside(hh,hl,hkey,P,m5key,m5h,m5l,m5c,atr_h,minr):
    n5=len(m5key); inB=np.zeros(n5,np.bool_); inS=np.zeros(n5,np.bool_)
    MAXF=4000
    top=np.zeros(MAXF); bot=np.zeros(MAXF); dr=np.zeros(MAXF,np.int64); born=np.zeros(MAXF,np.int64); alive=np.zeros(MAXF,np.bool_)
    nf=0; kclosed=-1
    for i in range(n5):
        endk=(m5key[i]+1)*5//P   # HTF bars with key < endk are closed
        while kclosed+1<len(hkey) and hkey[kclosed+1]<endk:
            kclosed+=1; c=kclosed
            if c>=2 and not np.isnan(atr_h[c]):
                g=minr*atr_h[c]
                if hl[c]-hh[c-2]>g and nf<MAXF:
                    top[nf]=hl[c]; bot[nf]=hh[c-2]; dr[nf]=1; born[nf]=c; alive[nf]=True; nf+=1
                elif hl[c-2]-hh[c]>g and nf<MAXF:
                    top[nf]=hl[c-2]; bot[nf]=hh[c]; dr[nf]=-1; born[nf]=c; alive[nf]=True; nf+=1
            # compact
            if nf>=MAXF-5:
                m=0
                for q in range(nf):
                    if alive[q]:
                        top[m]=top[q];bot[m]=bot[q];dr[m]=dr[q];born[m]=born[q];alive[m]=True;m+=1
                nf=m
        px=m5c[i]
        for q in range(nf):
            if not alive[q]: continue
            if kclosed-born[q]>200: alive[q]=False; continue
            # fill by M5 bar (after birth bar closed)
            if hkey[born[q]]*P//5 < m5key[i] :
                if dr[q]==1 and m5l[i]<=bot[q]: alive[q]=False; continue
                if dr[q]==-1 and m5h[i]>=top[q]: alive[q]=False; continue
            if px<=top[q] and px>=bot[q]:
                if dr[q]==1: inB[i]=True
                else: inS[i]=True
    return inB,inS

@njit(cache=True)
def main_loop(key,o,h,l,c,v,spr,atr,trend,inB,inS,dkey,wkey,hour,
              pdh,pdl,pdta,pwh,pwl,pwta,sesH,sesL,sesT0,sesTA,
              goodA,goodB,goodC,goodD):
    n=len(c)
    sh,sl=swings(h,l,L)
    score=np.zeros((n,2),np.int64); ent=np.full((n,2),np.nan); stp=np.full((n,2),np.nan); tgt=np.full((n,2),np.nan)
    lim=np.zeros((n,2),np.bool_); bos=np.zeros(n,np.int64); pts=np.zeros((n,2,7),np.bool_)
    # BOS state
    lsh=np.nan; lsl=np.nan; shU=True; slU=True; lastDir=0; lastBosKey=-10**9
    # exec FVG list
    MAXF=3000; ftop=np.zeros(MAXF); fbot=np.zeros(MAXF); fdr=np.zeros(MAXF,np.int64); fkey=np.zeros(MAXF,np.int64); falive=np.zeros(MAXF,np.bool_); fborn=np.zeros(MAXF,np.int64); nf=0
    # levels: 14 slots
    NL=14
    lv=np.full(NL,np.nan); lta=np.zeros(NL,np.int64); lside=np.array([1,-1,1,-1,1,-1,1,-1,1,-1,1,1,-1,-1])
    lst=np.zeros(NL,np.int64); lsw=np.zeros(NL,np.int64); lext=np.zeros(NL)
    # swings lists for EQ
    for i in range(n):
        if np.isnan(atr[i]) or i<400: 
            continue
        # ---- BOS (swing j=i-L confirmed now)
        j=i-L
        if sh[j]: lsh=h[j]; shU=False
        if sl[j]: lsl=l[j]; slU=False
        if (not shU) and c[i]>lsh:
            bos[i]=1; shU=True; lastDir=1; lastBosKey=key[i]
        if (not slU) and c[i]<lsl:
            bos[i]=-1; slU=True; lastDir=-1; lastBosKey=key[i]
        # ---- FVG exec (pattern i-2,i-1,i)
        g=0.10*atr[i]
        if l[i]-h[i-2]>g:
            if nf>=MAXF: nf=0
            ftop[nf]=l[i]; fbot[nf]=h[i-2]; fdr[nf]=1; fkey[nf]=key[i-2]; fborn[nf]=i; falive[nf]=True; nf+=1
        elif l[i-2]-h[i]>g:
            if nf>=MAXF: nf=0
            ftop[nf]=l[i-2]; fbot[nf]=h[i]; fdr[nf]=-1; fkey[nf]=key[i-2]; fborn[nf]=i; falive[nf]=True; nf+=1
        for q in range(nf):
            if falive[q] and fborn[q]<i:
                if fdr[q]==1 and l[i]<=fbot[q]: falive[q]=False
                elif fdr[q]==-1 and h[i]>=ftop[q]: falive[q]=False
        tnow=key[i]+1
        # ---- levels
        newv=np.full(NL,np.nan); newta=np.zeros(NL,np.int64)
        newv[0]=pdh[i]; newta[0]=pdta[i]; newv[1]=pdl[i]; newta[1]=pdta[i]
        newv[2]=pwh[i]; newta[2]=pwta[i]; newv[3]=pwl[i]; newta[3]=pwta[i]
        for s_ in range(3):
            newv[4+2*s_]=sesH[i,s_]; newv[5+2*s_]=sesL[i,s_]; newta[4+2*s_]=sesTA[i,s_]; newta[5+2*s_]=sesTA[i,s_]
        # EQ levels: swings confirmed (chrono jj <= i-L), within 300 bars
        tol=0.10*atr[i]
        for side in (1,-1):
            found=0; slot0=10 if side==1 else 12
            # collect recent swings
            idx=np.empty(80,np.int64); m=0
            jj=i-L
            while jj>i-298 and m<80:
                if (side==1 and sh[jj]) or (side==-1 and sl[jj]):
                    idx[m]=jj; m+=1
                jj-=1
            for a in range(m-1):
                if found>=2: break
                for b in range(a+1,min(m,a+6)):
                    ja=idx[a]; jb=idx[b]
                    if ja-jb<6: continue
                    if side==1:
                        if abs(h[ja]-h[jb])<=tol:
                            lvv=max(h[ja],h[jb]); ok=True
                            for mm in range(jb+1,ja):
                                if h[mm]>lvv: ok=False; break
                            if ok:
                                newv[slot0+found]=lvv; newta[slot0+found]=key[ja+L]; found+=1; break
                    else:
                        if abs(l[ja]-l[jb])<=tol:
                            lvv=min(l[ja],l[jb]); ok=True
                            for mm in range(jb+1,ja):
                                if l[mm]<lvv: ok=False; break
                            if ok:
                                newv[slot0+found]=lvv; newta[slot0+found]=key[ja+L]; found+=1; break
        for s_ in range(NL):
            if np.isnan(newv[s_]):
                lv[s_]=np.nan; continue
            if newv[s_]!=lv[s_] or newta[s_]!=lta[s_]:
                lv[s_]=newv[s_]; lta[s_]=newta[s_]; lst[s_]=0; lsw[s_]=0; lext[s_]=0.0
                # rescan bars from tAfter to i
                k0=i
                while k0>0 and key[k0-1]>=lta[s_] and i-k0<3000: k0-=1
                rng_from=k0
            else:
                rng_from=i
            for k in range(rng_from,i+1):
                if key[k]<lta[s_]: continue
                if lside[s_]==1:
                    if c[k]>lv[s_]: lst[s_]=2
                    elif h[k]>lv[s_]: lst[s_]=1; lsw[s_]=key[k]; lext[s_]=h[k]
                else:
                    if c[k]<lv[s_]: lst[s_]=2
                    elif l[k]<lv[s_]: lst[s_]=1; lsw[s_]=key[k]; lext[s_]=l[k]
        # ---- volume: most recent spike in last 60 bars
        vage=999; vdir=0
        for a in range(0,60):
            k=i-a
            if k-20<0: break
            s=0.0
            for q in range(k-20,k): s+=v[q]
            s/=20.0
            if s>0 and v[k]>2.0*s:
                vage=a+1; vdir=1 if c[k]>o[k] else -1; break
        hr=hour[i]
        sess=1 if ((hr>=goodA and hr<goodB) or (hr>=goodC and hr<goodD)) else 0
        for di in range(2):
            d=1 if di==0 else -1
            pT=2 if trend[i]==d else 0
            pV=0; sext=0.0; tsw=-1
            for s_ in range(NL):
                if not np.isnan(lv[s_]) and lside[s_]==-d and lst[s_]==1 and tnow-lsw[s_]*1<=36 and lsw[s_]>tsw:
                    tsw=lsw[s_]; sext=lext[s_]; pV=2
            pB=2 if (lastDir==d and tnow-lastBosKey<=24) else 0
            fi=-1; fk=-1
            for q in range(nf):
                if falive[q] and fdr[q]==d and tnow-fkey[q]<=30 and fborn[q]>fk:
                    fk=fborn[q]; fi=q
            inh=inB[i] if d==1 else inS[i]
            pF=(fi>=0) or inh
            pVo=(vage<=12 and vdir==d)
            px= c[i]+spr[i] if d==1 else c[i]
            if fi>=0:
                e=(ftop[fi]+fbot[fi])/2; lim[i,di]=True
            else:
                e=px
            buf=0.15*atr[i]+spr[i]
            base=np.nan
            if pV>0 and ((d==1 and sext<e) or (d==-1 and sext>e)): base=sext
            else:
                for jj in range(i-L,max(i-79,L),-1):
                    if d==1 and sl[jj] and l[jj]<e-0.3*atr[i]: base=l[jj]; break
                    if d==-1 and sh[jj] and h[jj]>e+0.3*atr[i]: base=h[jj]; break
                if np.isnan(base): base=e-atr[i] if d==1 else e+atr[i]
            s=base-buf if d==1 else base+buf
            if d==1 and s>=e-0.3*atr[i]: s=e-max(atr[i],buf)
            if d==-1 and s<=e+0.3*atr[i]: s=e+max(atr[i],buf)
            t=np.nan
            for s_ in range(NL):
                if np.isnan(lv[s_]) or lside[s_]!=d or lst[s_]==2: continue
                if d==1 and lv[s_]>e and (np.isnan(t) or lv[s_]<t): t=lv[s_]
                if d==-1 and lv[s_]<e and (np.isnan(t) or lv[s_]>t): t=lv[s_]
            rk=abs(e-s); rr=abs(t-e)/rk if not np.isnan(t) else 0.0
            pR=rr>=2.0
            sc=pT+pV+pB+(1 if pF else 0)+(1 if pVo else 0)+sess+(1 if pR else 0)
            score[i,di]=sc; ent[i,di]=e; stp[i,di]=s; tgt[i,di]=t
            pts[i,di,0]=pT>0; pts[i,di,1]=pV>0; pts[i,di,2]=pB>0; pts[i,di,3]=pF; pts[i,di,4]=pVo; pts[i,di,5]=sess==1; pts[i,di,6]=pR
    return score,ent,stp,tgt,lim,bos,pts

@njit(cache=True)
def simulate(bo,bh,bl,bc,ao,ah,al,ac,xts,closeidx,start,dr,e,s,t,islim,limwin,maxmin,comm):
    n=len(start); pnl=np.full(n,np.nan); risk=np.full(n,np.nan); fill=np.full(n,-1,np.int64); why=np.zeros(n,np.int64)
    N=len(bo)
    for k in range(n):
        j0=start[k]; d=dr[k]
        if j0>=N: continue
        tg=t[k]
        if np.isnan(tg): tg=e[k]+2.0*abs(e[k]-s[k])*d
        fj=-1; fp=0.0
        if islim[k]:
            j=j0
            while j<N and xts[j]-xts[j0]<limwin:
                if d==1 and al[j]<=e[k]: fj=j; fp=min(e[k],ao[j]); break
                if d==-1 and bh[j]>=e[k]: fj=j; fp=max(e[k],bo[j]); break
                j+=1
        else:
            fj=j0; fp=ao[j0] if d==1 else bo[j0]
            if (d==1 and fp<=s[k]) or (d==-1 and fp>=s[k]): fj=-1
        if fj<0: continue
        rk=abs(e[k]-s[k]) if islim[k] else abs(fp-s[k])
        xlast=closeidx[fj]
        px=np.nan; j=fj
        while j<N:
            if xts[j]-xts[fj]>maxmin or j>xlast: j-=1; break
            if d==1:
                if bl[j]<=s[k]: px=min(s[k],bo[j]) if j>fj else s[k]; why[k]=1; break
                if j>fj and bh[j]>=tg: px=max(tg,bo[j]); why[k]=2; break
            else:
                if ah[j]>=s[k]: px=max(s[k],ao[j]) if j>fj else s[k]; why[k]=1; break
                if j>fj and al[j]<=tg: px=min(tg,ao[j]); why[k]=2; break
            j+=1
        if np.isnan(px):
            j=max(fj,min(j,N-1)); px=bc[j] if d==1 else ac[j]
        pnl[k]=(px-fp)*d-comm; risk[k]=rk; fill[k]=fj
    return pnl,risk,fill,why

# ---------------------------------------------------------------- level arrays (python, per M5 bar)
def level_arrays(B5,dkey_m5):
    key=B5["key"]; h=B5["h"]; l=B5["l"]; n=len(key)
    day=key*5//1440
    # daily H/L
    dfd=pd.DataFrame({"d":day,"h":h,"l":l}).groupby("d").agg(h=("h","max"),l=("l","min"))
    days=dfd.index.values
    pos=np.searchsorted(days,day)   # current day position
    pdh=np.where(pos>0,dfd.h.values[np.maximum(pos-1,0)],np.nan); pdl=np.where(pos>0,dfd.l.values[np.maximum(pos-1,0)],np.nan)
    pdta=day*1440//5
    wk=(day+4)//7
    dfw=pd.DataFrame({"w":wk,"h":h,"l":l}).groupby("w").agg(h=("h","max"),l=("l","min"))
    wks=dfw.index.values; wp=np.searchsorted(wks,wk)
    pwh=np.where(wp>0,dfw.h.values[np.maximum(wp-1,0)],np.nan); pwl=np.where(wp>0,dfw.l.values[np.maximum(wp-1,0)],np.nan)
    pwta=(wk*7-4)*1440//5
    # sessions: most recent completed session (end <= now = key+1), using bars < now
    sesH=np.full((n,3),np.nan); sesL=np.full((n,3),np.nan); sesT0=np.zeros((n,3),np.int64); sesTA=np.zeros((n,3),np.int64)
    hrs=[(1,9),(9,15),(16,23)]
    mod=(key*5)%1440
    for s_,(a,b) in enumerate(hrs):
        inside=(mod>=a*60)&(mod<b*60)
        g=pd.DataFrame({"d":day[inside],"h":h[inside],"l":l[inside]}).groupby("d").agg(h=("h","max"),l=("l","min"),c=("h","size"))
        g=g[g.c>=3]
        ends=(g.index.values*1440+b*60)//5   # in m5 key units
        now=key+1
        p=np.searchsorted(ends,now,side="right")-1
        ok=p>=0
        sesH[ok,s_]=g.h.values[p[ok]]; sesL[ok,s_]=g.l.values[p[ok]]; sesTA[ok,s_]=ends[p[ok]]
        # must be within 6 days
        old=ok & ((now-sesTA[:,s_])>6*288)
        sesH[old,s_]=np.nan; sesL[old,s_]=np.nan
    return pdh,pdl,pdta,pwh,pwl,pwta,sesH,sesL,sesT0,sesTA

def build_signals(B5,H1,M15,spr5):
    key=B5["key"]
    atr5=atr_sma(B5["h"],B5["l"],B5["c"],14)
    trH=trend_h1(H1["h"],H1["l"],H1["c"])
    endk=(key+1)*5//60; kk=np.searchsorted(H1["key"],endk,side="left")-1
    trend=np.where(kk>=0,trH[np.maximum(kk,0)],0)
    atrH=atr_sma(H1["h"],H1["l"],H1["c"],14); atrQ=atr_sma(M15["h"],M15["l"],M15["c"],14)
    b1,s1=htf_inside(H1["h"],H1["l"],H1["key"],60,key,B5["h"],B5["l"],B5["c"],atrH,0.10)
    b2,s2=htf_inside(M15["h"],M15["l"],M15["key"],15,key,B5["h"],B5["l"],B5["c"],atrQ,0.10)
    inB=b1|b2; inS=s1|s2
    hour=((key+1)*5%1440)//60
    lv=level_arrays(B5,None)
    return main_loop(key,B5["o"],B5["h"],B5["l"],B5["c"],B5["v"].astype(np.float64),spr5,atr5,trend.astype(np.int64),inB,inS,
                     key*5//1440,(key*5//1440+4)//7,hour,*lv,10,13,16,19)

def stats_tab(T,label):
    rows=[]
    for name,s in T.groupby("bucket",sort=False) if len(T) else []:
        pass
    return rows

def summarize(T):
    if len(T)<2: return dict(n=len(T))
    Rr=T.R.values; g=Rr[Rr>0].sum(); b=-Rr[Rr<0].sum()
    dd=T.groupby("day").R.sum()
    tt=dd.mean()/dd.std(ddof=1)*np.sqrt(len(dd)) if len(dd)>2 and dd.std(ddof=1)>0 else np.nan
    eq=np.cumsum(T.sort_values("fill").R.values); mdd=np.max(np.maximum.accumulate(eq)-eq) if len(eq) else 0
    return dict(n=len(T),win=(Rr>0).mean()*100,avgR=Rr.mean(),PF=g/b if b>0 else np.inf,t=tt,maxDD=mdd,totR=Rr.sum())

def run_set(name,sc,en,st,tg,lim,bos,pts,B5,EX,comm,startmap,dayk,years,maxmin=480):
    n=len(sc); evs=[]
    for di,d in enumerate((1,-1)):
        if name=="A":
            idx=np.flatnonzero(bos==d)
        else:
            s=sc[:,di]; prev=np.r_[0,s[:-1]]
            idx=np.flatnonzero((s>=7)&(prev<7))
        idx=idx[~np.isnan(en[idx,di])]
        evs.append(pd.DataFrame({"i":idx,"d":d,"score":sc[idx,di],"e":en[idx,di],"s":st[idx,di],"t":tg[idx,di],"lim":lim[idx,di]}))
    E=pd.concat(evs,ignore_index=True)
    E=E[E.i+1<len(startmap)]
    start=startmap[E.i.values+1]
    pnl,risk,fill,why=simulate(*EX["arr"],EX["xts"],EX["closeidx"],start,E.d.values.astype(np.int64),E.e.values,E.s.values,E.t.values,E.lim.values,60,maxmin,comm)
    E["pnl"]=pnl; E["risk"]=risk; E["fill"]=fill; E["why"]=why
    E=E[E.fill>=0].copy()
    E["R"]=E.pnl/E.risk
    E["year"]=years[E.i.values]; E["day"]=dayk[E.i.values]
    E["bucket"]=pd.cut(E.score,[-1,4,6,8,10],labels=["0-4","5-6","7-8","9-10"])
    return E
