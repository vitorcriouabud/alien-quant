import sys, numpy as np, pandas as pd
from scipy import stats as st
pd.set_option("display.width", 260); pd.set_option("display.max_colwidth", 80)
TAG = sys.argv[1] if len(sys.argv) > 1 else ""
T = pd.read_parquet(f"/workspace/alien-research/out/smc_trades{TAG}.parquet"); T["time"] = pd.to_datetime(T.time, utc=True)
T["key"] = T.sym + "|" + T.cid.astype(str); OOS = pd.Timestamp("2026-01-01", tz="UTC")
def m(x):
    R = x.R.values
    if len(R) < 2: return dict(n=len(R))
    eq = np.cumsum(R); dd = (np.maximum.accumulate(np.r_[0, eq])[1:] - eq).max()
    e1 = np.cumprod(1 + 0.01 * R); mdd = (1 - e1 / np.maximum.accumulate(e1)).max()
    ls = c = 0
    for v in R: c = c + 1 if v < 0 else 0; ls = max(ls, c)
    return dict(n=len(R), wr=(R > 0).mean(), pf=R[R > 0].sum() / max(-R[R < 0].sum(), 1e-9), expR=R.mean(), t=R.mean() / R.std(ddof=1) * np.sqrt(len(R)), ddR=dd, mdd1=mdd, maxLS=ls)
rows = []
for k, x in T.groupby("key"):
    x = x.sort_values("time"); i, o = x[x.time < OOS], x[x.time >= OOS]
    r = dict(key=k, sym=x.sym.iloc[0], params=x.params.iloc[0]); r.update({f"is_{a}": b for a, b in m(i).items()}); r.update({f"oos_{a}": b for a, b in m(o).items()})
    r["yrs_pos"] = (i.groupby(i.time.dt.year).R.sum() > 0).mean(); rows.append(r)
S = pd.DataFrame(rows); S.to_csv(f"/workspace/alien-research/out/smc_summary{TAG}.csv", index=False)
print("configs with trades:", len(S), "| IS n>=100:", (S.is_n >= 100).sum(), "| IS expR>0:", (S.is_expR > 0).sum(), "| IS t>=2:", (S.is_t >= 2).sum(),
      "| Bonferroni t>", round(st.norm.ppf(1 - 0.05 / 720), 2), ":", (S.is_t > st.norm.ppf(1 - 0.05 / 720)).sum())
e = S[S.is_n >= 100]; print("corr IS/OOS expR:", round(e[["is_expR", "oos_expR"]].corr().iloc[0, 1], 3))
print("median by sym:"); print(S.groupby("sym")[["is_wr", "is_pf", "is_expR", "oos_expR"]].median().round(3))
for dim in ["bias=", "PD=", "pool=", "poi=", "entry=", "tp="]:
    S[dim] = S.params.str.extract(dim.replace("=", r"=(\S+)"))
    print(dim, S.groupby(dim)[["is_expR", "oos_expR"]].median().round(3).to_dict("index"))
c = ["key", "params", "is_n", "is_wr", "is_pf", "is_expR", "is_t", "is_ddR", "is_mdd1", "is_maxLS", "yrs_pos", "oos_n", "oos_wr", "oos_pf", "oos_expR", "oos_maxLS"]
print("\nTOP 12 by IS t (n>=100):"); print(e.sort_values("is_t", ascending=False)[c].head(12).round(3).to_string())
surv = e[(e.is_t >= 2) & (e.yrs_pos >= 0.6) & (e.oos_expR > 0)]
print("\nSURVIVORS:", len(surv)); print(surv[c].round(3).to_string())
# walk-forward: yearly, top5 by trailing 2y t (n>=40)
W = []
for Y in (2023, 2024, 2025, 2026):
    a, b, c2 = (pd.Timestamp(f"{y}-01-01", tz="UTC") for y in (Y - 2, Y, Y + 1))
    tr = T[(T.time >= a) & (T.time < b)].groupby("key").R.agg(["mean", "std", "count"]); tr = tr[tr["count"] >= 40]
    tr["t"] = tr["mean"] / tr["std"] * np.sqrt(tr["count"]); pick = tr.sort_values("t", ascending=False).head(5).index
    te = T[(T.time >= b) & (T.time < c2) & T.key.isin(pick)]; W.append(dict(year=Y, train_t=tr.loc[pick, "t"].mean(), test_n=len(te), test_expR=te.R.mean()))
W = pd.DataFrame(W); print("\nWALK-FORWARD:"); print(W.round(3).to_string()); print("pooled", round(np.average(W.test_expR, weights=W.test_n), 3))
