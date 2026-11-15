exec(open("lit.py").read().split("# ---------- registry ----------")[0])
for tf in ("M5","H1"):
    f=lambda **k: vo("VO3",tf,**k); t=run(f()); s=summ(t); v=summ(t,2025,2025)
    nb=[summ(run(f(**kw)))["mean"] for kw in [dict(rv=1.5),dict(rv=3.0),dict(rr=1.5),dict(rr=3.0)]]
    tt=t[t.year<=2025]
    print(tf,{k:round(x,3) for k,x in s.items()},"2025",v["n"],round(v["mean"],3),round(v["pf"],2),"nb",[round(x,3) for x in nb])
    print(tt.groupby("year").pnl.sum().round(1).to_dict())
