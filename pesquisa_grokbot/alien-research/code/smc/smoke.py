import time, smc, sys
sys.path.insert(0,"/workspace/alien-research/code"); import engine as E
t0=time.time(); D=smc.load_m1("xauusd"); P=smc.prepare(D); print("prep",round(time.time()-t0,1), len(D["utc"]), D["utc"][0], D["utc"][-1])
for kw in [dict(), dict(entry="mkt"), dict(entry="ob"), dict(tp="liq"), dict(pd_filter=False), dict(poi="h1fvg"), dict(bias_tf="D1")]:
    t0=time.time(); s=smc.signals(D,P,**kw); t=smc.run(D,s); m=E.metrics(t)
    print(kw, len(s["sig_i"]), {k:round(float(v),3) for k,v in m.items()}, round(time.time()-t0,1))
