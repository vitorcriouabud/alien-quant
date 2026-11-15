import smc, numpy as np
D=smc.load_m1("xauusd")
for k in "ohlc": D["b"+k]=D["m"+k]; D["a"+k]=D["m"+k]
D["comm"]=0; D["slip"]=0; P=smc.prepare(D)
for en in ["fvg","mkt"]:
    t=smc.run(D,smc.signals(D,P,bias_tf="D1",entry=en,tp="2R"))
    same=(t.entry_i==t.exit_i); rng=np.median((D["mh"]-D["ml"])[t.entry_i])
    print(en,"n",len(t),"expR",round(t.R.mean(),3),"stopped on fill bar",round(same.mean(),3),"expR excl",round(t.R[~same].mean(),3),"median stop",round(np.median(t.risk),2),"median M1 range at entry",round(rng,2))
