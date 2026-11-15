"""Walk-forward selection test + Goat 2-Step 1% Floating simulation."""
import numpy as np, pandas as pd, sys
pd.set_option("display.width", 250); pd.set_option("display.max_colwidth", 100)
TAG = sys.argv[1] if len(sys.argv) > 1 else "B"
T = pd.read_parquet(f"../out/trades_{TAG}.parquet"); S = pd.read_csv(f"../out/summary_{TAG}.csv")
T["time"] = pd.to_datetime(T.time, utc=True)

# ---------- 1) walk-forward: every 6 months pick top-5 by trailing 24 months, trade next 6 months
def wf(T, train_m=24, test_m=6, topk=5, minn=100):
    starts = pd.date_range("2025-01-01", "2026-07-01", freq=f"{test_m}MS", tz="UTC")
    out = []
    for s in starts:
        tr = T[(T.time >= s - pd.DateOffset(months=train_m)) & (T.time < s)]
        te = T[(T.time >= s) & (T.time < s + pd.DateOffset(months=test_m))]
        g = tr.groupby("cid").R.agg(["mean", "count"])
        g = g[g["count"] >= minn].sort_values("mean", ascending=False).head(topk)
        x = te[te.cid.isin(g.index)]
        out.append(dict(test_start=s.date(), picked=list(g.index), train_expR=g["mean"].mean(), test_n=len(x), test_expR=x.R.mean()))
    return pd.DataFrame(out)
W = wf(T); print("WALK-FORWARD (top5 by trailing 24m, B costs)"); print(W.round(3).to_string())
allx = []
print("WF pooled test expR:", round(np.average(W.test_expR, weights=W.test_n), 3), "n", W.test_n.sum())

# ---------- 2) Goat simulation
def goat(t, start_times, bal0=5000.0, risk_pct=0.0025, tgt=(0.08, 0.06)):
    t = t.sort_values("time").reset_index(drop=True)
    oz = np.floor(bal0 * risk_pct / t.risk.values)          # 0.01 lot = 1 oz, risk sized on initial balance
    usd = oz * t.pnl.values; flo = oz * (t.mae.values + 0.07)  # worst floating incl. commission
    td = t.tday.values; tm = t.time.values
    res = []
    for st in start_times:
        i = np.searchsorted(tm, np.datetime64(st.tz_convert(None)))
        bal = bal0; phase = 0; base = bal0; pdays = set(); day = None; daystart = bal; ndays = 0; t0 = None; outcome = "unfinished"
        while i < len(t):
            if oz[i] < 1: i += 1; continue
            if td[i] != day: day = td[i]; daystart = bal; ndays += 1
            if t0 is None: t0 = tm[i]
            if flo[i] >= 0.01 * bal0: outcome = f"breach_floating_P{phase+1}"; break
            bal += usd[i]
            if bal - daystart >= 0.005 * bal0: pdays.add(day)
            if daystart - bal >= 0.04 * bal0: outcome = f"breach_daily_P{phase+1}"; break
            if bal <= 0.90 * bal0: outcome = f"breach_maxloss_P{phase+1}"; break
            if bal - base >= tgt[phase] * bal0 and len(pdays) >= 3:
                if phase == 0: phase = 1; base = bal; pdays = set(); res.append(("P1", (tm[i] - t0) / np.timedelta64(1, "D")))
                else: outcome = "passed_both"; break
            i += 1
        res.append((outcome, (tm[min(i, len(t)-1)] - t0) / np.timedelta64(1, "D") if t0 is not None else np.nan))
    r = pd.DataFrame(res, columns=["outcome", "days"])
    p1 = (r.outcome == "P1").sum(); n = (r.outcome != "P1").sum()
    return dict(starts=n, pass_P1=p1 / n, pass_both=(r.outcome == "passed_both").mean() * len(r) / n,
                breach=r.outcome.str.startswith("breach").sum() / n, floating_breach=r.outcome.str.contains("floating").sum() / n,
                daily_breach=r.outcome.str.contains("daily").sum() / n, unfinished=(r.outcome == "unfinished").sum() / n,
                med_days_P1=r[r.outcome == "P1"].days.median())

starts = pd.date_range("2023-02-01", "2026-05-01", freq="MS", tz="UTC")  # monthly rolling starts
c = ["cid", "family", "params", "is_n", "is_pf", "is_expR", "is_wr", "is_ddR", "is_maxLS", "oos_n", "oos_pf", "oos_expR", "oos_wr", "oos_ddR", "oos_maxLS", "y2023", "y2024", "y2025", "y2026"]
elig = S[(S.is_n >= 150)].sort_values("is_expR", ascending=False)
print("\nPRE-REGISTERED FILTER (IS n>=150, PF>=1.10, expR>=0.05, >=2/3 IS years >0):")
f = elig[(elig.is_pf >= 1.10) & (elig.is_expR >= 0.05) & ((elig[["y2023", "y2024", "y2025"]] > 0).sum(axis=1) >= 2)]
print(f[c].round(3).to_string() if len(f) else "none")
top = elig.drop_duplicates(subset=["is_n", "is_expR"]).head(8)
print("\nTOP-8 by IS expectancy (distinct):"); print(top[c].round(3).to_string())
rows = []
for cid in top.cid:
    g = goat(T[T.cid == cid], starts); g["cid"] = cid; rows.append(g)
G = pd.DataFrame(rows); print("\nGOAT SIM (monthly starts 2023-02..2026-05):"); print(G.round(3).to_string())
G.to_csv(f"../out/goat_{TAG}.csv", index=False); top[c].to_csv(f"../out/top_{TAG}.csv", index=False); W.to_csv(f"../out/wf_{TAG}.csv", index=False)
