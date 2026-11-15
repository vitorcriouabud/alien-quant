"""Proxy M1 (Dukascopy 2016-2025) da familia V11: sweep + reclaim, stop estrutural, alvo 3R.
NAO e a V11 (que usa microestrutura de ticks). Serve para ver se as correcoes ajudam fora das 2 semanas.
Convencoes: sinal em barra fechada; entrada na abertura da barra seguinte; compra no ask, sai no bid.
Ambiguidade intrabar: SL antes de TP/BE (conservador). Spread = spread Dukascopy reescalado p/ mediana 8 pts por ano."""
import numpy as np, pandas as pd, sys
from numba import njit
df=pd.read_parquet('/workspace/alien-research/data/xau_m1_2016_2026.parquet')
df=df[(df.index<'2026-01-01')]
stale=(df.bh==df.bl)&(df.bc==df.bc.shift(1)); df=df[~stale]
mid=(df[['bo','bh','bl','bc']].values+df[['ao','ah','al','ac']].values)/2
rsp=(df.ac-df.bc).clip(lower=0.0)
yr=df.index.year
k=0.08/rsp.groupby(yr).transform('median').clip(lower=0.01)
sp=(rsp*k).clip(0.01,0.5).values
o,h,l,c=[mid[:,j].copy() for j in range(4)]
tr=np.maximum(h-l,np.maximum(abs(h-np.roll(c,1)),abs(l-np.roll(c,1))))
atr=pd.Series(tr).rolling(14).mean().values
utc_h=df.index.hour.values; day=((df.index.tz_localize(None).normalize()-pd.Timestamp("1970-01-01")).days).values.astype(np.int64)
yrs=yr.values

@njit
def run(o,h,l,c,atr,sp,uh,day,mode_mgmt,maxsp_sl,minstop_atr,abs_maxsp,comm):
    n=len(o); out=np.zeros((200000,4)); m=0
    i=12; lastday=-1; cnt=0
    while i<n-2:
        if day[i]!=lastday: lastday=day[i]; cnt=0
        a=atr[i]
        if not (uh[i]>=7 and uh[i]<17) or cnt>=15 or not a>0: i+=1; continue
        lo=1e18; hi=-1e18
        for j in range(i-10,i):
            lo=min(lo,l[j]); hi=max(hi,h[j])
        d=0
        if l[i]<lo-0.03 and c[i]>lo+0.01 and (min(o[i],c[i])-l[i])>=0.04*a: d=1
        elif h[i]>hi+0.03 and c[i]<hi-0.01 and (h[i]-max(o[i],c[i]))>=0.04*a: d=-1
        if d==0: i+=1; continue
        e=i+1; s=sp[e]
        if abs_maxsp>0 and s>abs_maxsp: i+=1; continue
        entry=o[e]+d*s/2
        ext=l[i] if d==1 else h[i]
        stopd=d*(entry-(ext-d*max(0.02,0.045*a)))
        stopd=max(stopd,0.15*a, s+0.03)
        if minstop_atr>0: stopd=max(stopd,minstop_atr*a)
        if stopd>2.0: i+=1; continue
        if maxsp_sl>0 and s>maxsp_sl*stopd: i+=1; continue
        sl=entry-d*stopd; tp=entry+d*3*stopd; R=stopd
        j=e; res=0.0; done=False
        while j<n and not done:
            # quotes for exit side: long exits at bid = mid - sp/2
            hs=h[j]-d*sp[j]/2 if d==1 else h[j]+sp[j]/2
            ls=l[j]-sp[j]/2 if d==1 else l[j]+sp[j]/2
            if d==1:
                adverse=ls; fav=hs
                if adverse<=sl: res=(min(sl,o[j]-sp[j]/2)-entry); done=True; break
                if fav>=tp: res=tp-entry; done=True; break
                g=fav-entry
            else:
                adverse=hs; fav=ls
                if adverse>=sl: res=(entry-max(sl,o[j]+sp[j]/2)); done=True; break
                if fav<=tp: res=entry-tp; done=True; break
                g=entry-fav
            # management applied for next bar (conservative)
            if mode_mgmt==1:   # V11 base: BE at max(.12,.33atr) -> +0.03 ; trail from max(.22,.55atr) at .27atr
                if g>=max(0.12,0.33*a):
                    nb=entry+d*0.03
                    if d*(nb-sl)>0: sl=nb
                if g>=max(0.22,0.55*a):
                    nt=(entry+d*g)-d*max(0.10,0.27*a)
                    if d*(nt-sl)>0.06: sl=nt
            elif mode_mgmt==2: # BE at 1R, trail from 2R at 1R
                if g>=R:
                    nb=entry+d*0.03
                    if d*(nb-sl)>0: sl=nb
                if g>=2*R:
                    nt=(entry+d*g)-d*R
                    if d*(nt-sl)>0: sl=nt
            if day[j]!=day[e] and uh[j]>=21: res=d*(c[j]-entry)-sp[j]/2; done=True; break
            j+=1
        out[m,0]=e; out[m,1]=res-comm; out[m,2]=R; out[m,3]=d; m+=1; cnt+=1
        i=j+1
    return out[:m]

V={'BASE(gestao V11)':(1,0,0,0),'F1 sem gestao':(0,0,0,0),'F2 spread<=0.12SL':(1,0.12,0,0),'F3 SL>=0.5ATR':(1,0,0.5,0),'F4 BE 1R/trail 2R':(2,0,0,0),'F5 spread<=10':(1,0,0,0.10)}
rows=[]
for comm,cl in [(0.08,'com8'),(0.168,'com16.8')]:
    for name,(mm,ms,mn,ab) in V.items():
        r=run(o,h,l,c,atr,sp,utc_h,day,mm,ms,mn,ab,comm)
        idx=r[:,0].astype(int); y=yrs[idx]; pnl=r[:,1]
        per=pd.Series(pnl).groupby(y).sum()
        rows.append(dict(custo=cl,variante=name,trades=len(r),por_ano=round(len(r)/10),pts_medio=round(pnl.mean()*100,1),
          liquido_usd_001=round(pnl.sum(),1),acerto=round((pnl>0).mean()*100,1),anos_pos=int((per>0).sum()),
          pf=round(pnl[pnl>0].sum()/-pnl[pnl<0].sum(),2)))
        if cl=='com8': print(name, per.round(1).to_dict())
t=pd.DataFrame(rows); print(t.to_string()); t.to_csv('/workspace/alien-research/out/v11diag_m1proxy.csv',index=False)
