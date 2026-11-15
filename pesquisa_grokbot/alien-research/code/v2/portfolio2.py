import sys, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/v2"); import engine2 as E, os; SUF = "_RF" if os.environ.get("COSTS") == "RF" else ""
T = pd.read_parquet("/workspace/alien-research/out/v2_trades"+SUF+".parquet"); T["key"] = T.sym + "|" + T.cid.astype(str)
T["exit"] = pd.to_datetime(T.exit)
S = pd.read_csv("/workspace/alien-research/out/v2_summary"+SUF+".csv").set_index("key")
def port(keys, risk):
    x = T[T.key.isin(keys)].copy(); x["d"] = x.exit.dt.tz_convert("America/New_York").dt.normalize()
    daily = x.groupby("d").R.sum() * risk
    idx = pd.date_range(daily.index.min(), daily.index.max(), freq="B", tz="America/New_York"); daily = daily.reindex(idx, fill_value=0)
    eq = (1 + daily).cumprod()
    def m(e, r):
        if len(e) < 20: return {}
        yrs = len(e) / 261; dd = (1 - e / e.cummax()).max()
        return dict(cagr=(e.iloc[-1] / e.iloc[0]) ** (1 / yrs) - 1, mdd=dd, sharpe=r.mean() / r.std() * np.sqrt(261) if r.std() > 0 else np.nan, ret=e.iloc[-1] / e.iloc[0] - 1)
    i = daily.index < E.OOS
    return dict(IS=m(eq[i], daily[i]), OOS=m(eq[~i] / eq[i].iloc[-1], daily[~i]), years=eq.groupby(eq.index.year).last().pct_change().round(3).to_dict(),
                n=len(x), n_oos=(x.exit >= E.OOS).sum(), wr=(x.R > 0).mean(), pf=x.R[x.R > 0].sum() / -x.R[x.R < 0].sum(), expR=x.R.mean())
idxs = ["usa500idxusd", "usatechidxusd", "deuidxeur"]
basket = [k for k in S.index if k.split("|")[0] in idxs and S.loc[k, "family"] in ("M1_rsi2", "M3_ibs") and ("'th': 10, 'stopk': 3.0" in S.loc[k, "params"] or "'th': 0.25" in S.loc[k, "params"])]
surv = ["usatechidxusd|34", "usa500idxusd|32", "deuidxeur|35", "btcusd|17"]
for name, keys in (("INDEX_MR_BASKET (6, family-level)", basket), ("SURVIVORS_4", surv)):
    for rk in (0.01, 0.03):
        r = port(keys, rk); print(name, "risk", rk, "n", r["n"], "n_oos", r["n_oos"], "WR", round(r["wr"], 3), "PF", round(r["pf"], 3), "expR", round(r["expR"], 3))
        print("   IS", {k: round(v, 3) for k, v in r["IS"].items()}, "\n   OOS", {k: round(v, 3) for k, v in r["OOS"].items()}, "\n   years", r["years"])
print(basket)
