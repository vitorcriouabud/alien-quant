import sys, glob, time, pickle, numpy as np, pandas as pd
sys.path.insert(0,"/workspace/alien-professor/teste")
from sinais import *
T0=time.time()
df=pd.read_parquet(R+"data/xau_m1_2016_2026.parquet"); df=df[df.index<CUT]
vol=[]
for f in sorted(glob.glob(R+"data/xvol/xau_v_20*.csv")):
    y=int(f[-8:-4])
    if y>=2026: continue
    vol.append(pd.read_csv(f,usecols=["timestamp","volume"]))
vol=pd.concat(vol); vol.index=pd.to_datetime(vol.timestamp,unit="ms",utc=True)
v1=vol.volume.reindex(df.index).fillna(0).values
srv,ny=srv_minutes(df.index)
bo,bh,bl,bc=[df[c].values for c in ["bo","bh","bl","bc"]]; ao,ah,al,ac=[df[c].values for c in ["ao","ah","al","ac"]]
k5=srv//5
B5=bars(k5,bo,bh,bl,bc,v1)
spr5=(ac-bc)[B5["last"]]
H1=bars(srv//60,bo,bh,bl,bc); M15=bars(srv//15,bo,bh,bl,bc)
print("bars",len(B5["key"]),time.time()-T0,flush=True)
sc,en,st,tg,lim,bos,pts=build_signals(B5,H1,M15,spr5)
print("signals",time.time()-T0,flush=True)
nyhm=(ny.hour*60+ny.minute).values
win=(nyhm>=16*60+50)&(nyhm<18*60)
N=len(df); nxt=np.full(N,N,np.int64); last=N
for j in range(N-1,-1,-1):
    if win[j]: last=j
    nxt[j]=last
closeidx=nxt-1
xts=(df.index.as_unit("s").asi8//60).astype(np.int64)
EX=dict(arr=(bo,bh,bl,bc,ao,ah,al,ac),xts=xts,closeidx=closeidx)
startmap=B5["first"]
years=pd.to_datetime(B5["key"]*5,unit="m").year.values
dayk=B5["key"]*5//1440
out={}
for name in ("A","B"):
    E=run_set(name,sc,en,st,tg,lim,bos,pts,B5,EX,0.168,startmap,dayk,years)
    out[name]=E
    print(name,len(E),time.time()-T0,flush=True)
pickle.dump(dict(out=out),open("/workspace/alien-professor/teste/ouro_trades.pkl","wb"))
# pts frequency sanity
print("score dist A:",out["A"].score.value_counts().sort_index().to_dict())
