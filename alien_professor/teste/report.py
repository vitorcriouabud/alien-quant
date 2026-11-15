import sys,pickle,numpy as np,pandas as pd
sys.path.insert(0,"/workspace/alien-professor/teste")
from sinais import summarize
fn=sys.argv[1]; D=pickle.load(open(fn,"rb"))["out"]
def tab(E,per):
    rows=[]
    for b in ["0-4","5-6","7-8","9-10","7-10"]:
        s=E[E.bucket.isin(["7-8","9-10"])] if b=="7-10" else E[E.bucket==b]
        s=s[(s.year>=per[0])&(s.year<=per[1])]
        r=summarize(s); r["faixa"]=b; rows.append(r)
    return pd.DataFrame(rows).set_index("faixa")
pd.set_option("display.width",200); pd.set_option("display.float_format",lambda x:f"{x:.3f}")
for name,E in D.items():
    print("=== conjunto",name,"| trades",len(E),"| limite%",round(E.lim.mean()*100,1),"| why stop/alvo/tempo",E.why.value_counts(normalize=True).round(3).to_dict())
    print("risco mediano (pontos)",round(E.risk.median(),3),"| R p1/p50/p99",np.round(E.R.quantile([.01,.5,.99]).values,2))
    print("-- IS 2016-2024"); print(tab(E,(2016,2024)).round(3))
    print("-- 2025"); print(tab(E,(2025,2025)).round(3))
    s=E[E.score>=7]
    print("-- por ano (nota>=7): soma R / n"); print(s.groupby("year").R.agg(["sum","count","mean"]).round(2).T)
