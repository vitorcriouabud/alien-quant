import sys, numpy as np, pandas as pd, itertools, time
sys.path.insert(0, "/workspace/alien-research/code/goat"); import goat_sim as G
t0 = time.time()
MR = G.mr_trades(); CAL = G.cal_trades()
print("MR trades", len(MR), "expR", MR.R.mean().round(3), "WR", (MR.R > 0).mean().round(3), "| CAL", len(CAL), "expR", CAL.R.mean().round(3), round(time.time() - t0, 1), flush=True)
for nm, X in (("MR", MR), ("CAL", CAL)):
    for p, m in (("<=2025", X.entry.dt.year <= 2025), ("2026", X.entry.dt.year >= 2026)):
        print(nm, p, len(X[m]), X[m].R.mean().round(3), (X[m].R > 0).mean().round(3))
    print(X.groupby(X.entry.dt.year).R.agg(["count", "mean"]).round(3).T.to_string())
MR.to_parquet("/workspace/alien-research/out/goat_mr_trades.parquet"); CAL.to_parquet("/workspace/alien-research/out/goat_cal_trades.parquet")
BOTH = pd.concat([MR, CAL], ignore_index=True).sort_values("entry").reset_index(drop=True)
srt = lambda X: X.sort_values("entry").reset_index(drop=True)
sets = {"CAL (calendário intradiário)": srt(CAL), "MR+CAL": srt(BOTH)}
for sk in (0.5, 1.0, 2.0): sets[f"MR stop {sk} ATR"] = srt(G.mr_trades(sk, sk))
starts = pd.date_range("2015-11-01", "2026-10-01", freq="MS", tz="America/New_York")
rows = []
for sname, T in sets.items():
    P = G.paths(T)
    for (risk, cap, maxpos), (step, minlot) in itertools.product([(8, 45, 99), (12, 45, 99), (15, 45, 3), (22, 45, 2), (30, 45, 1), (40, 45, 1), (45, 48, 1)], [(0.01, 0.01), (0.1, 0.1)]):
        R = [G.goat(T, P, s, risk, cap, step, minlot, maxpos) for s in starts]
        st = pd.Series([r[0] for r in R])
        p1 = [r[2][0] if r[0] == "PASS" or (r[0] == "RUNNING" and r[1] >= 1) else (r[2][0] if isinstance(r[2], list) and len(r[2]) else None) for r in R]
        p1d = [r[2][0] for r in R if isinstance(r[2], list) and len(r[2]) >= 1] + [None for r in R if r[0].startswith("BREACH") and r[1] >= 1]
        p1days = [x for x in p1d if x is not None]
        tot = [sum(r[2]) for r in R if r[0] == "PASS"]
        # pass within horizons (P1+P2), only starts with enough data left
        def within(h):
            ok = [s for s in starts if s <= starts[-1] - pd.Timedelta(days=h)]; k = [i for i, s in enumerate(starts) if s in ok]
            return np.mean([R[i][0] == "PASS" and sum(R[i][2]) <= h for i in k]) if k else np.nan
        def p1within(h):
            k = [i for i, s in enumerate(starts) if s <= starts[-1] - pd.Timedelta(days=h)]
            return np.mean([isinstance(R[i][2], list) and len(R[i][2]) >= 1 and R[i][2][0] <= h for i in k]) if k else np.nan
        rows.append(dict(set=sname, risk_usd=risk, cap=cap, maxpos=maxpos, lotstep=step, starts=len(R), pass_both=(st == "PASS").mean(), breach=st.str.startswith("BREACH").mean(),
                         breach_float=(st == "BREACH_FLOAT").mean(), running=(st == "RUNNING").mean(), p1_any=np.mean([isinstance(r[2], list) and len(r[2]) >= 1 for r in R]),
                         p1_med_days=np.median(p1days) if p1days else np.nan, both_med_days=np.median(tot) if tot else np.nan,
                         p1_6m=p1within(183), p1_12m=p1within(365), both_12m=within(365), both_24m=within(730)))
        print(rows[-1], round(time.time() - t0), flush=True)
pd.DataFrame(rows).to_csv("/workspace/alien-research/out/goat_sim_v2.csv", index=False)
