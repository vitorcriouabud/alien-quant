import numpy as np, pandas as pd, sys, os, pickle
sys.path.insert(0, "/workspace/alien-research/code/tiro")
from strats import *
OUT = "/workspace/alien-research/out/tiro"
def tz_ny(x): return pd.to_datetime(x, utc=True).dt.tz_convert("America/New_York")
TR = {}
def add(name, df, fam):
    df = df.copy(); df["name"] = name; df["family"] = fam
    df["entry"] = tz_ny(df.entry); df["exit"] = tz_ny(df.exit); TR[name] = df.sort_values("entry").reset_index(drop=True)

IDXS = {s: m5_index(s) for s in ["usa500idxusd", "usatechidxusd", "deuidxeur"]}
G = m5_gold()
US = ["usa500idxusd", "usatechidxusd"]
cfg = dict(A1=dict(rr=5), A2=dict(rr=10), A3=dict(rr=0), A4=dict(or_min=15, rr=10), A5=dict(rr=10, mid_stop=True), A6=dict(rr=10, nr7=True))
for k, kw in cfg.items():
    add(k, pd.concat([orb(s, IDXS[s], **kw) for s in US]), "A")
add("A7", orb("deuidxeur", IDXS["deuidxeur"], rr=10, start="09:00", last_entry="12:00", flat="17:25"), "A")
add("ctrlA2", pd.concat([orb(s, IDXS[s], rr=10, ctrl=True) for s in US]), "ctrl")
ALL3 = US + ["deuidxeur"]
add("B1", pd.concat([daily_sim(s, sig_rexp(s), 1.0, 5, 20) for s in ALL3]), "B")
add("B2", pd.concat([daily_sim(s, sig_rexp(s), 1.0, 0, 40, trailk=2.0) for s in ALL3]), "B")
add("B3", pd.concat([daily_sim(s, sig_rexp(s, True), 1.0, 0, 40, trailk=2.0) for s in ALL3]), "B")
add("C1", pd.concat([daily_sim(s, sig_rsi2(s), 1.0, 5, 20) for s in ALL3]), "C")
add("C2", pd.concat([daily_sim(s, sig_rsi2(s), 1.0, 0, 30, trailk=2.0, be_after=2.0) for s in ALL3]), "C")
add("C3", pd.concat([daily_sim(s, sig_rsi2(s), 0.5, 10, 20) for s in ALL3]), "C")
add("D1", gold_pd(G, rr=5), "D"); add("D2", gold_pd(G, rr=10))if False else add("D2", gold_pd(G, rr=10), "D")
add("D3", gold_pd(G, rr=None, hold_days=5, trail_atr=1.0), "D"); add("D4", gold_pd(G, rr=None, hold_days=5, trail_atr=1.0, long_only=True), "D")
add("ctrlD2", gold_pd(G, rr=10, ctrl=True), "ctrl")
pickle.dump(TR, open(f"{OUT}/trades.pkl", "wb"))
print({k: len(v) for k, v in TR.items()})
