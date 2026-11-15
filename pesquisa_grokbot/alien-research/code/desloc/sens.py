import numpy as np, pandas as pd
import run as Rn
from core import *
rows=[]
D=Rn.D
mid=D["mid"]
for (tf,defn,var,fade) in Rn.TESTS:
    name=f"M{tf}_D{defn}_{var}_{'FADE' if fade else 'CONT'}"
    r={"teste":name}
    for lab,scen,comm in [("ecn_8",'ecn',COMM_LOW),("bruto_mid",'mid',0.0)]:
        if scen=='mid':
            sb,sa=D["bid"],D["ask"]; D["bid"]=mid; D["ask"]=mid
            T=Rn.run_exec(tf,defn,var,fade,scen="real",comm=0.0); D["bid"],D["ask"]=sb,sa
        else: T=Rn.run_exec(tf,defn,var,fade,scen=scen,comm=comm)
        IS=T[T.year<=2024]; x=IS.pnl
        r[lab+"_media"]=x.mean(); r[lab+"_pf"]=x[x>0].sum()/-x[x<0].sum(); r[lab+"_anos_pos"]=int((IS.groupby("year").pnl.sum()>0).sum())
        if lab=="ecn_8":
            V=T[T.year==2025].pnl; r["ecn_8_2025"]=V.mean()
    rows.append(r); print(r,flush=True)
S=pd.DataFrame(rows); S.to_csv(R+"out/desloc/sensibilidade.csv",index=False); print(S.round(3).to_string())
# ATR vs cost
B15=Rn.B[15]; A=atr(B15); y=Rn.YEAR[B15["last"]]; sp=(D["ask"]-D["bid"])[B15["last"],3]
print(pd.DataFrame(dict(y=y,A=A,sp=sp)).groupby("y").median().round(3))
