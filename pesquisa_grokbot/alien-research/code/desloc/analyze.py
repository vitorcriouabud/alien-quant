import numpy as np, pandas as pd
from core import R
O=R+"out/desloc/"
M=pd.read_csv(O+"exec_raw.csv")
M=M[M.grupo.isin(["todos"])|M.grupo.str.contains(r"\|")].copy()   # 24 primary + 288 ctx|ses = 312
print("family size",len(M))
p=M.p.fillna(1).values; m=len(p); o=np.argsort(p); ranks=np.empty(m); ranks[o]=np.arange(1,m+1)
bh_thr=ranks/m*0.05; srt=p[o]; ok=srt<=np.arange(1,m+1)/m*0.05; kmax=np.max(np.flatnonzero(ok))+1 if ok.any() else 0
M["BH"]=ranks<=kmax; M["Bonf"]=p<=0.05/m
M["candidato"]=M.BH&(M.n>=150)&(M.pf>=1.10)&(M.anos_pos>=7)
M.to_csv(O+"exec_family.csv",index=False)
print("BH pass",M.BH.sum(),"Bonf pass",M.Bonf.sum(),"candidatos",M.candidato.sum())
print("positivos (media>0, n>=150):",((M.media>0)&(M.n>=150)).sum())
print(M[M.n>=150].sort_values("p").head(12)[["teste","grupo","n","media","pf","p","anos_pos","BH"]].round(3).to_string())
print(M[M.grupo=="todos"][["teste","n","media","pf","acerto","p","anos_pos"]].round(3).to_string())
