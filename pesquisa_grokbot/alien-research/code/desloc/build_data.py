"""Merge Dukascopy XAUUSD M1 bid/ask 2016-2026 -> parquet, drop flat filler bars."""
import pandas as pd, glob
R="/workspace/alien-research/data/"
def rd(side):
    fs=sorted(glob.glob(R+f"m1/xauusd_{side}_20*.csv"))+sorted(glob.glob(R+f"raw/xau_{side}_*.csv"))
    d=pd.concat([pd.read_csv(f) for f in fs]).drop_duplicates("timestamp").set_index("timestamp").sort_index()
    d.columns=[f"{side[0]}{c[0]}" for c in d.columns]; return d
df=rd("bid").join(rd("ask"),how="inner")
df.index=pd.to_datetime(df.index,unit="ms",utc=True)
stale=(df.bh==df.bl)&(df.ah==df.al)&(df.bc==df.bc.shift(1))&(df.ac==df.ac.shift(1))
print("rows",len(df),"filler dropped",int(stale.sum()))
df=df[~stale]
wd=df.index.dayofweek; h=df.index.hour
df=df[~((wd==5)|((wd==6)&(h<21))|((wd==4)&(h>=22)))]
df=df[(df.ac>df.bc*0.99)&(df.ac-df.bc<20)]
df.to_parquet(R+"xau_m1_2016_2026.parquet")
sp=df.ac-df.bc
print(df.index[0],df.index[-1]); print(sp.groupby(df.index.year).median())
print(df.groupby(df.index.year).size())
