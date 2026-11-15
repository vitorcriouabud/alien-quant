import sys, numpy as np, pandas as pd
def bh(p, a):
    p = np.asarray(p); o = np.argsort(p); m = len(p); thr = a * np.arange(1, m + 1) / m
    ok = p[o] <= thr; k = np.max(np.where(ok)[0]) + 1 if ok.any() else 0
    r = np.zeros(m, bool); r[o[:k]] = True; return r
OUT = "/workspace/alien-research/out/frentes"
t = pd.read_csv(f"{OUT}/trend_summary.csv"); n = pd.read_csv(f"{OUT}/news_summary.csv")
A = pd.concat([pd.DataFrame(dict(front=1, id=t.id, n_IS=t.IS_ntr, stat_t=t.IS_t, p=t.p, IS_result=t.IS_cagr.map(lambda v: f"CAGR {v:+.1%}"), IS_mdd=t.IS_mdd, yrs_pos_of9=t.yrs_pos, ex_top1=t.sum_ex_top1_trades, val2025=t.VA_ret.map(lambda v: f"{v:+.1%}"))),
               pd.DataFrame(dict(front=2, id=n.id, n_IS=n.n_IS, stat_t=n.t, p=n.p, IS_result=n.expR_IS.map(lambda v: f"{v:+.3f}R/trade"), IS_mdd=np.nan, yrs_pos_of9=n.yrs_pos, ex_top1=n.sum_ex_top1, val2025=n.sumR_VA.map(lambda v: f"{v:+.1f}R")))])
A["BH_FDR10"] = bh(A.p.clip(0, 1).values, 0.10); A["Bonferroni"] = A.p < 0.05 / len(A)
A["survivor"] = A.BH_FDR10 & (A.stat_t >= 2) & (A.yrs_pos_of9 >= 6) & (A.ex_top1 > 0)
A.to_csv(f"{OUT}/attempts.csv", index=False)
print(len(A), "attempts; BH pass:", A.BH_FDR10.sum(), "Bonf:", A.Bonferroni.sum(), "survivors:", A.survivor.sum(), "max t:", A.stat_t.max().round(2), A.loc[A.stat_t.idxmax(), "id"])
# Front 3: index basket (RF costs) daily, 1% risk
T = pd.read_parquet("/workspace/alien-research/out/v2_trades_RF.parquet"); T["key"] = T.sym + "|" + T.cid.astype(str)
keys = ['usa500idxusd|32', 'usa500idxusd|35', 'usatechidxusd|32', 'usatechidxusd|35', 'deuidxeur|32', 'deuidxeur|35']
x = T[T.key.isin(keys)].copy(); x["d"] = pd.to_datetime(x.exit).dt.tz_convert("America/New_York").dt.normalize().dt.tz_localize(None)
x = x[x.d >= "2016-01-01"]
daily = x.groupby("d").R.sum() * 0.01; daily = daily.reindex(pd.date_range("2016-01-01", daily.index.max(), freq="B"), fill_value=0)
eq = (1 + daily).cumprod(); yrs = len(daily) / 261
mo = eq.resample("ME").last().pct_change(); mo.iloc[0] = eq.resample("ME").last().iloc[0] - 1
yr = eq.resample("YE").last().pct_change(); yr.iloc[0] = eq.resample("YE").last().iloc[0] - 1
print("BASKET 2016-2026-11: CAGR %.2f%%, maxDD(fechamento) %.2f%%, pior mes %.2f%%, pior ano %.2f%%, meses positivos %.0f%%, trades %d (%.1f/mes)" % (
    100 * (eq.iloc[-1] ** (1 / yrs) - 1), 100 * (1 - eq / eq.cummax()).max(), 100 * mo.min(), 100 * yr.min(), 100 * (mo > 0).mean(), len(x), len(x) / (yrs * 12)))
print("anos:", " ".join(f"{d.year}:{v:+.1%}" for d, v in yr.items()))
print("PF %.2f WR %.0f%%" % (x.R[x.R > 0].sum() / -x.R[x.R < 0].sum(), 100 * (x.R > 0).mean()))
g = pd.read_parquet(f"{OUT}/trend_daily.parquet"); g.index = pd.DatetimeIndex(g.index).normalize()
dd = daily.copy()
for c in ("T8LS", "T9LO", "T2LO", "T12LO"):
    s = g[c].reindex(dd.index).fillna(0); print("corr basket x", c, round(np.corrcoef(dd, s)[0, 1], 3))
