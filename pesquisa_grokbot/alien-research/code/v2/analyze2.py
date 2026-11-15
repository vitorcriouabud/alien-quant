import sys, numpy as np, pandas as pd
from scipy import stats as st
sys.path.insert(0, "/workspace/alien-research/code/v2"); import engine2 as E, os; SUF = "_RF" if os.environ.get("COSTS") == "RF" else ""
pd.set_option("display.width", 260); pd.set_option("display.max_colwidth", 70)
T = pd.read_parquet("/workspace/alien-research/out/v2_trades"+SUF+".parquet")
T["entry"] = pd.to_datetime(T.entry); OOS = E.OOS
T["key"] = T.sym + "|" + T.cid.astype(str)
rows = []
for key, t in T.groupby("key", sort=False):
    t = t.sort_values("entry"); i = t[t.entry < OOS]; o = t[t.entry >= OOS]
    si, so = E.stats(i), E.stats(o)
    yrs = i.groupby(i.entry.dt.year).R.sum()
    r = dict(key=key, sym=t.sym.iloc[0], family=t.family.iloc[0], tf=t.tf.iloc[0], params=t.params.iloc[0],
             yrs_pos=(yrs > 0).mean() if len(yrs) else np.nan)
    r.update({f"is_{k}": v for k, v in si.items()}); r.update({f"oos_{k}": v for k, v in so.items()})
    rows.append(r)
S = pd.DataFrame(rows)
S["p"] = 1 - st.norm.cdf(S.is_t.fillna(-9))
# Benjamini-Hochberg at q=0.10 across all configs
m = len(S); srt = S.p.sort_values(); thr = (np.arange(1, m + 1) / m) * 0.10
passed = srt.values <= thr; kmax = np.max(np.nonzero(passed)[0]) + 1 if passed.any() else 0
S["bh"] = S.p <= (srt.values[kmax - 1] if kmax else -1)
S.to_csv("/workspace/alien-research/out/v2_summary"+SUF+".csv", index=False)
print("configs:", m, "| BH(q=10%) passes:", S.bh.sum(), "| Bonferroni t>", round(st.norm.ppf(1 - 0.05 / m), 2), "passes:", (S.is_t > st.norm.ppf(1 - 0.05 / m)).sum())
c = ["key", "family", "tf", "params", "is_n", "is_pf", "is_expR", "is_t", "is_cagr", "is_mdd", "yrs_pos", "oos_n", "oos_pf", "oos_expR", "oos_cagr", "oos_mdd", "bh"]
surv = S[(S.is_n >= 100) & (S.is_t >= 2.0) & (S.yrs_pos >= 0.6) & (S.oos_expR > 0)]
print("\nSURVIVORS (IS n>=100, t>=2, >=60% years positive, OOS expR>0):", len(surv))
print(surv.sort_values("is_t", ascending=False)[c].round(3).to_string())
print("\nTop 15 by IS t:"); print(S.sort_values("is_t", ascending=False)[c].head(15).round(3).to_string())
print("\nfamily medians:"); print(S.groupby("family")[["is_expR", "oos_expR", "is_t"]].median().round(3))
print("corr IS/OOS expR:", S[S.is_n >= 100][["is_expR", "oos_expR"]].corr().iloc[0, 1].round(3))
# walk-forward: each year Y in 2019..2026 select top-10 configs by trailing 4y t (n>=40), trade year Y
W = []
for Y in range(2019, 2027):
    a = pd.Timestamp(f"{Y-4}-01-01", tz="America/New_York"); b = pd.Timestamp(f"{Y}-01-01", tz="America/New_York"); c2 = pd.Timestamp(f"{Y+1}-01-01", tz="America/New_York")
    tr = T[(T.entry >= a) & (T.entry < b)].groupby("key").R.agg(["mean", "std", "count"])
    tr = tr[tr["count"] >= 40]; tr["t"] = tr["mean"] / tr["std"] * np.sqrt(tr["count"])
    pick = tr.sort_values("t", ascending=False).head(10).index
    te = T[(T.entry >= b) & (T.entry < c2) & T.key.isin(pick)]
    W.append(dict(year=Y, picked=", ".join(pick[:4]) + "...", test_n=len(te), test_expR=te.R.mean(), test_sumR_per_cfg=te.R.sum() / 10))
W = pd.DataFrame(W); print("\nWALK-FORWARD top10 by trailing-4y t:"); print(W.round(3).to_string())
print("WF pooled expR", round(np.average(W.test_expR, weights=W.test_n), 3))
W.to_csv("/workspace/alien-research/out/v2_wf"+SUF+".csv", index=False)
