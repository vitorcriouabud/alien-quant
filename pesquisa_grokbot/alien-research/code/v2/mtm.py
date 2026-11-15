"""Mark-to-market daily DD check for the index MR basket (non-compounded, R units * risk)."""
import sys, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/v2"); import engine2 as E
T = pd.read_parquet("/workspace/alien-research/out/v2_trades.parquet"); T["key"] = T.sym + "|" + T.cid.astype(str)
keys = ['usa500idxusd|32', 'usa500idxusd|35', 'usatechidxusd|32', 'usatechidxusd|35', 'deuidxeur|32', 'deuidxeur|35']
tot = None
for sym in ["usa500idxusd", "usatechidxusd", "deuidxeur"]:
    r = E.resample(E.load_h1(sym), "D1"); c = r.close
    for k in [k for k in keys if k.startswith(sym)]:
        x = T[T.key == k]; s = pd.Series(0.0, index=r.index)
        for _, t in x.iterrows():
            seg = c.loc[t.entry:t.exit]
            # daily MTM in R from entry open; final day replaced by realized R
            path = (seg - r.open.loc[t.entry]) * t.dir / t.risk
            inc = path.diff().fillna(path.iloc[0]) if len(path) else path
            if len(inc): inc.iloc[-1] += t.R - path.iloc[-1]
            s.loc[inc.index] += inc.values
        s.index = s.index.normalize().tz_localize(None)
        tot = s if tot is None else tot.add(s, fill_value=0)
for rk in (0.01, 0.02, 0.03):
    eq = 1 + (tot * rk).cumsum(); dd = (eq.cummax() - eq) / eq.cummax()
    oos = tot.index >= pd.Timestamp("2026-01-01")
    print(f"risk {rk}: MTM maxDD all {dd.max():.3f} | IS {dd[~oos].max():.3f} | OOS {(lambda e:( (e.cummax()-e)/e.cummax()).max())(eq[oos]):.3f} | worst day {(tot*rk).min():.3f} | final {eq.iloc[-1]:.2f}")
