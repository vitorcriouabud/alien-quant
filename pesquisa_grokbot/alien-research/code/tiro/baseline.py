"""Index basket baseline (MR RSI2+IBS, GOAT.md stops 3/4 ATR) with CORRECTED swap units + CAL from GOAT.md."""
import numpy as np, pandas as pd, sys, pickle
sys.path.insert(0, "/workspace/alien-research/code/v2"); sys.path.insert(0, "/workspace/alien-research/code/tiro")
import engine2 as E, fam2
from data import SWAP, SP
from strats import d1
out = []
for s in ["usa500idxusd", "usatechidxusd", "deuidxeur"]:
    E.INSTR[s] = dict(comm=0.0, sp_scale=1.0, sp_floor=SP[s], slip=E.INSTR[s]["slip"], swap=SWAP[s])
    r = d1(s); P = E.INSTR[s]
    r = r.assign(sp=SP[s])
    tdays = np.asarray(r.index.as_unit("ns").asi8, dtype=np.float64) / 86400e9   # FIX: ns units
    for name, kw in (("RSI2", fam2.rsi2(r, 10, 3.0, True)), ("IBS", fam2.ibs(r, 0.25, 4.0))):
        n = len(r); z = np.zeros(n, np.bool_)
        e = E.sim(r.open.values, r.high.values, r.low.values, r.close.values, r.sp.values, r.atr.values, tdays,
                  np.asarray(kw["ent"], np.int64), np.asarray(kw.get("exl", z) if kw.get("exl") is not None else z, np.bool_),
                  np.asarray(kw.get("exs") if kw.get("exs") is not None else z, np.bool_), float(kw["stopk"]), 0.0, 0.0,
                  int(kw.get("maxbars", 10**6)), P["comm"], P["slip"], P["swap"][0], P["swap"][1])
        ei, xi, dr, pnl, risk = e
        for a, b, d, p, rk in zip(ei, xi, dr, pnl, risk):
            fp = r.open.values[a]; seg = slice(a, b + 1)
            adv = ((r.low.values[seg] - fp) if d == 1 else (fp - r.high.values[seg])).min()
            cost = SP[s] + 2 * P["slip"]; dist = rk - cost
            days = (r.index[b] - r.index[a]).total_seconds() / 86400
            sw = (P["swap"][0] if d == 1 else P["swap"][1]) / 100 / 365 * fp * days
            out.append(dict(sym=s, fam=name, entry=r.index[a], exit=r.index[b], dir=d, fp=fp, pts=p, r1=rk,
                            worst=min(max(adv, -dist) - cost + min(sw, 0), p)))
mr = pd.DataFrame(out)
print("MR swap check: mean swap-free vs with:", mr.pts.mean())
cal = pd.read_parquet("/workspace/alien-research/out/goat_cal_trades.parquet")
cal = pd.DataFrame(dict(sym=cal.sym, fam="CAL", entry=cal.entry, exit=cal.exit, dir=cal.dir, fp=cal.fp, pts=cal.pnl, r1=cal.risk, worst=np.minimum(cal.worst, cal.pnl)))
for x in (mr, cal):
    x["entry"] = pd.to_datetime(x.entry, utc=True).dt.tz_convert("America/New_York"); x["exit"] = pd.to_datetime(x.exit, utc=True).dt.tz_convert("America/New_York")
mr["R"] = mr.pts / mr.r1
y = mr.entry.dt.year
print("MR trades", len(mr), "avgR 2016-24", mr[(y >= 2016) & (y <= 2024)].R.mean().round(3), "2025", mr[y == 2025].R.mean().round(3), "wr", (mr.R > 0).mean().round(3))
pickle.dump(dict(MR=mr, CAL=cal, MRCAL=pd.concat([mr, cal]).sort_values("entry").reset_index(drop=True)), open("/workspace/alien-research/out/tiro/baseline.pkl", "wb"))
