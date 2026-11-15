import sys, numpy as np, pandas as pd; sys.path.insert(0, '.'); import tsmom as t
P, S = t.load(); IS = slice("2011-01-01", "2024-12-31")
for r in ["M12", "MB"]:
    b = t.backtest(P, S, r); held = b["pos"].shift(1).fillna(0); ret = P.ffill().pct_change().fillna(0)
    g = (held * ret)[IS]
    cls = {c: t.U[c][0] for c in P.columns}
    print(r, "gross IS ann by class:", {k: round(v * 252 / 1, 4) for k, v in g.T.groupby(cls).sum().T.mean().items()})
    print(r, "gross by market (ann):", (g.mean() * 252).round(4).sort_values().to_dict())
    print(r, "avg gross leverage IS:", round(held[IS].abs().sum(axis=1).mean(), 2), " gross Sharpe:", round(t.stats_(b['gross'][IS])['sharpe'], 2), "net-of-tc-only Sharpe:", round(t.stats_((b['gross'] - b['tc'])[IS])['sharpe'], 2))
