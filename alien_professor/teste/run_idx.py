import sys, glob, time, pickle, numpy as np, pandas as pd
sys.path.insert(0,"/workspace/alien-professor/teste")
from sinais import *
sym=sys.argv[1]; spread=float(sys.argv[2])
fs=[f for f in sorted(glob.glob(R+f"data/m5/{sym}_bid_20*.csv")) if int(f[-8:-4])<2026]
df=pd.concat([pd.read_csv(f) for f in fs]); df.index=pd.to_datetime(df.timestamp,unit="ms",utc=True); df=df[df.index<CUT]
df=df[~df.index.duplicated()].sort_index()
df=df[(df.high>df.low)|(df.volume>0 if "volume" in df else df.high>df.low)]  # remove flat filler bars (market closed)
srv,ny=srv_minutes(df.index)
bo,bh,bl,bc=[df[c].values.astype(float) for c in ["open","high","low","close"]]
nyhm=(ny.hour*60+ny.minute).values
spr=np.where((nyhm>=9*60+30)&(nyhm<9*60+35),2*spread,spread)
ao,ah,al,ac=bo+spr,bh+spr,bl+spr,bc+spr
B5=bars(srv//5,bo,bh,bl,bc,np.zeros(len(bo)))
spr5=spr[B5["last"]]
H1=bars(srv//60,bo,bh,bl,bc); M15=bars(srv//15,bo,bh,bl,bc)
sc,en,st,tg,lim,bos,pts=build_signals(B5,H1,M15,spr5)
win=(nyhm>=16*60+50)&(nyhm<18*60); N=len(df); nxt=np.full(N,N,np.int64); last=N
for j in range(N-1,-1,-1):
    if win[j]: last=j
    nxt[j]=last
EX=dict(arr=(bo,bh,bl,bc,ao,ah,al,ac),xts=(df.index.as_unit("s").asi8//60).astype(np.int64),closeidx=nxt-1)
startmap=B5["first"]; years=pd.to_datetime(B5["key"]*5,unit="m").year.values; dayk=B5["key"]*5//1440
out={n:run_set(n,sc,en,st,tg,lim,bos,pts,B5,EX,0.0,startmap,dayk,years) for n in ("A","B")}
pickle.dump(dict(out=out),open(f"/workspace/alien-professor/teste/{sym}_trades.pkl","wb"))
print(sym,{n:len(E) for n,E in out.items()})
