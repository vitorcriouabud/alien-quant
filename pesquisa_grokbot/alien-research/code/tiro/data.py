import numpy as np, pandas as pd, os, sys
sys.path.insert(0, "/workspace/alien-research/code/v2")
R = "/workspace/alien-research"
SP = {"usa500idxusd": 0.6, "usatechidxusd": 2.0, "deuidxeur": 1.5}
SLIP = {"usa500idxusd": 0.1, "usatechidxusd": 0.5, "deuidxeur": 0.5, "xauusd": 0.05}
PPL = {"usa500idxusd": 1.0, "usatechidxusd": 1.0, "deuidxeur": 1.12, "xauusd": 100.0}   # $ per point per 1.00 lot
SWAP = {"usa500idxusd": (-8.6, -1.8), "usatechidxusd": (-8.6, -1.8), "deuidxeur": (-7.2, -1.8), "xauusd": (-6.0, -1.0)}
COMM = {"xauusd": 0.05}
MINLOT = {"usa500idxusd": 0.1, "usatechidxusd": 0.1, "deuidxeur": 0.1, "xauusd": 0.01}

def m5_index(sym):
    f = f"{R}/out/tiro/{sym}_m5.parquet"
    if os.path.exists(f): return pd.read_parquet(f)
    d = pd.concat([pd.read_csv(f"{R}/data/m5/{sym}_bid_{y}.csv") for y in range(2016, 2027)])
    d = d.drop_duplicates("timestamp").sort_values("timestamp")
    d = d[~((d.high == d.low) & (d.open == d.close))]
    d.index = pd.to_datetime(d.timestamp, unit="ms", utc=True).dt.tz_convert("America/New_York" if sym != "deuidxeur" else "Europe/Berlin")
    d = d[["open", "high", "low", "close"]]
    d.to_parquet(f); return d

def m5_gold():
    f = f"{R}/out/tiro/xauusd_m5.parquet"
    if os.path.exists(f): return pd.read_parquet(f)
    x = pd.read_parquet(f"{R}/data/xau_m1_2016_2026.parquet")
    x = x[~((x.bh == x.bl) & (x.bo == x.bc))]
    g = x.resample("5min").agg(dict(bo="first", bh="max", bl="min", bc="last", ao="first", ah="max", al="min", ac="last")).dropna()
    d = pd.DataFrame(index=g.index.tz_convert("America/New_York"))
    for c, b, a in (("open", "bo", "ao"), ("high", "bh", "ah"), ("low", "bl", "al"), ("close", "bc", "ac")):
        d[c] = (g[b].values + g[a].values) / 2
    d["sp"] = np.maximum(0.10, g.ac.values - g.bc.values)
    d.to_parquet(f); return d
