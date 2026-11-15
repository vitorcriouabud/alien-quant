import numpy as np, pandas as pd
T = pd.read_parquet("/workspace/alien-research/out/v2_trades_RF.parquet"); T["key"] = T.sym + "|" + T.cid.astype(str)
keys = ['usa500idxusd|32', 'usa500idxusd|35', 'usatechidxusd|32', 'usatechidxusd|35', 'deuidxeur|32', 'deuidxeur|35']
x = T[T.key.isin(keys)].copy(); x["d"] = pd.to_datetime(x.exit).dt.tz_convert("America/New_York").dt.normalize().dt.tz_localize(None)
bk = x.groupby("d").R.sum() * 0.01
g = pd.read_parquet("/workspace/alien-research/out/tendencia/daily_ALL.parquet")
g = g.loc["2016-01-01":"2024-12-31"]; bk = bk.reindex(g.index, fill_value=0)
for c in g.columns:
    d = np.corrcoef(g[c], bk)[0, 1]; m = np.corrcoef((1+g[c]).resample("ME").prod(), (1+bk).resample("ME").prod())[0, 1]
    comb = 0.5 * g[c] + 0.5 * bk; sh = lambda r: r.mean() / r.std() * np.sqrt(252)
    eq = (1 + comb).cumprod(); eqb = (1 + bk).cumprod()
    print(f"{c:5s} corr diaria {d:+.2f} mensal {m:+.2f} | Sharpe cesta {sh(bk):.2f} combo50/50 {sh(comb):.2f} | DD cesta {(1-eqb/eqb.cummax()).max():.1%} combo {(1-eq/eq.cummax()).max():.1%}")
