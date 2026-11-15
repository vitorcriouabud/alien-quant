import time, engine as E, families as F
t0=time.time(); D=E.load("B"); print("load",time.time()-t0)
for name,fn in [("rand",lambda: F.f0_random(D,2.0)),("sweep",lambda: F.f1_sweep(D,5,24,"LDNNY",2.0)),
                ("fvg",lambda: F.f2_fvg(D,15,0.3,"edge","gap","none","LDNNY",2.0)),("asia_bo",lambda:F.f4_asia(D,"breakout","mid",2.0)),
                ("asia_fade",lambda:F.f4_asia(D,"fade",None,2.0)),("orb",lambda:F.f5_orb(D,"NY",30,"mid",2.0)),
                ("tmom",lambda:F.f6_tmom(D,600,0.5,"cont",2.0)),("bb",lambda:F.f7_bb(D,5,2.5,"ALL","mid")),
                ("choch",lambda:F.f8_choch(D,5,24,0.5,"LDNNY",2.0)),("bret",lambda:F.f3_bretest(D,15,20,0.5,"LDNNY",2.0))]:
    t0=time.time(); s=fn(); t=E.run(D,s); m=E.metrics(t)
    print(name, len(s["sig_i"]), {k:round(v,3) for k,v in m.items()}, t.reason.value_counts().to_dict(), round(time.time()-t0,1))
