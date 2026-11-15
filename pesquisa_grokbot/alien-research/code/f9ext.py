import itertools, engine as E, families as F, pandas as pd, numpy as np
OOS=pd.Timestamp("2026-01-01",tz="UTC")
rows=[]
for sc in ["Z","B","A"]:
    D=E.load(sc)
    E.COMM,E.SLIP=(0.0,0.0) if sc=="Z" else (0.07,0.05)
    for hm,hold,sk in itertools.product([18*60+30,19*60,20*60],[240,360,480],[2.0,3.0]):
        t=E.run(D,F.f9_tod(D,1,hm,hold,sk)); i=E.metrics(t[t.time<OOS]); o=E.metrics(t[t.time>=OOS])
        rows.append(dict(sc=sc,entry=f"{hm//60}:{hm%60:02d}",hold=hold,slk=sk,is_n=i["n"],is_pf=i["pf"],is_exp=i["expR"],oos_n=o["n"],oos_pf=o["pf"],oos_exp=o["expR"],
             **{f"y{y}":t[t.time.dt.year==y].R.mean() for y in (2023,2024,2025,2026)}, stop_med=np.median(t.risk)))
R=pd.DataFrame(rows); pd.set_option("display.width",250); print(R.round(3).to_string())
R.to_csv("../out/f9ext.csv",index=False)
