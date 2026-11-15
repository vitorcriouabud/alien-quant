import sys, pandas as pd, numpy as np
sys.path.insert(0, "."); import goat_sim as G
T = pd.read_parquet("/workspace/alien-research/out/goat_mr_trades.parquet").sort_values("entry").reset_index(drop=True)
print(T[["sym","strat","entry","exit","fp","dist","cost","pnl","risk","R"]].head(8).to_string())
print(T.groupby("sym")[["dist","cost","fp"]].median())
P = G.paths(T[:50].reset_index(drop=True))
print([ (len(p[0]), p[1].min()) for p in P[:10]])
for risk in (8, 30, 45):
    print(risk, G.goat(T, G.paths(T), pd.Timestamp("2016-01-01", tz="America/New_York"), risk, 48 if risk==45 else 45, 0.01, 0.01, 99 if risk<20 else 1))
