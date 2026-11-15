"""Merge Dukascopy XAUUSD M1 bid/ask CSVs -> parquet with UTC + New York time."""
import pandas as pd, glob, numpy as np
def rd(side):
    fs = sorted(glob.glob(f"data/raw/xau_{side}_*.csv"))
    d = pd.concat([pd.read_csv(f) for f in fs]).drop_duplicates("timestamp").set_index("timestamp").sort_index()
    d.columns = [f"{side[0]}{c[0]}" for c in d.columns]  # bo bh bl bc / ao ah al ac
    return d
b, a = rd("bid"), rd("ask")
df = b.join(a, how="inner")
df.index = pd.to_datetime(df.index, unit="ms", utc=True)
df.index.name = "utc"
df.to_parquet("data/xau_m1_bidask.parquet")
sp = df.ac - df.bc
print(df.shape, df.index[0], df.index[-1])
print("spread close quantiles", sp.quantile([.01,.1,.5,.9,.99]).round(3).to_dict())
print(sp.groupby(df.index.year).median())
print("neg/zero spread bars", (sp<=0).sum())
