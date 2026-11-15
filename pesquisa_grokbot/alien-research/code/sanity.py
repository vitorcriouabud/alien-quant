import engine as E, families as F, numpy as np
D=E.load("Z"); E.COMM=0; E.SLIP=0
for rr in (1.0,2.0,3.0):
    R=[]
    for seed in range(5):
        t=E.run(D,F.f0_random(D,rr,seed)); R.append(t.R.mean())
    print("frictionless random rr",rr,"meanR",np.round(R,3))
D=E.load("B"); E.COMM=0.07; E.SLIP=0.05
t=E.run(D,F.f0_random(D,2.0,0)); print("B cost/risk median", np.median((t.risk- (t.risk-0.12))/t.risk))
sp=(D["ao"]-D["bo"]); import pandas as pd
print("median stop dist", np.median(t.risk-0.12), "median spread B", np.median(sp))
print(t.groupby(t.time.dt.year).R.agg(['mean','count']))
