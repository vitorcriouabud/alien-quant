"""Run the full pre-registered grid; save per-config trades and summary metrics."""
import itertools, sys, time, numpy as np, pandas as pd, multiprocessing as mp
import engine as E, families as F
SCEN = sys.argv[1] if len(sys.argv) > 1 else "B"
NOCAP = len(sys.argv) > 2 and sys.argv[2] == "nocap"
TAG = SCEN + ("_nocap" if NOCAP else "")
OOS_START = pd.Timestamp("2026-01-01", tz="UTC")

def grid():
    G = []
    for tf, N, s, rr in itertools.product([5, 15], [12, 24, 48], ["LDN", "NY", "LDNNY", "ALL"], [1.5, 2, 3, 4]):
        G.append(("F1_sweep", dict(tf=tf, N=N, sess=s, rr=rr)))
    for tf, gk, en, sl, tr, s, rr in itertools.product([5, 15], [0.3, 0.6], ["edge", "mid"], ["gap", "c1"], ["none", "ema"], ["LDNNY", "ALL"], [1.5, 2, 3, 4]):
        G.append(("F2_fvg", dict(tf=tf, gapk=gk, entry=en, slmode=sl, trend=tr, sess=s, rr=rr)))
    for tf, N, k, s, rr in itertools.product([5, 15], [20, 50], [0.5, 1.0], ["LDNNY", "ALL"], [1.5, 2, 3, 4]):
        G.append(("F3_bretest", dict(tf=tf, N=N, slk=k, sess=s, rr=rr)))
    for sl, rr, mw in itertools.product(["mid", "opp", "q"], [1, 1.5, 2, 3, 4], [None, 15.0]):
        G.append(("F4_asia", dict(mode="breakout", slmode=sl, rr=rr, maxw=mw)))
    for rr in [1, 1.5, 2, 3, 4]:
        G.append(("F4_asia", dict(mode="fade", slmode=None, rr=rr)))
    for s, rg, sl, rr in itertools.product(["LDN", "NY"], [15, 30, 60], ["mid", "opp"], [1, 1.5, 2, 3, 4]):
        G.append(("F5_orb", dict(sess=s, rng=rg, slmode=sl, rr=rr)))
    for t, k, md, rr, sk in itertools.product([480, 570, 600, 660], [0.25, 0.5], ["cont", "fade"], [1.5, 2, 3], [0.5, 1.0]):
        G.append(("F6_tmom", dict(t_hm=t, k=k, mode=md, rr=rr, slk=sk)))
    for tf, k, s, tg in itertools.product([5, 15], [2.0, 2.5, 3.0], ["ALL", "LDNNY", "ASIA"], ["mid", 1.5, 2]):
        G.append(("F7_bb", dict(tf=tf, kstd=k, sess=s, tgt=tg)))
    for tf, N, rt, s, rr in itertools.product([5, 15], [12, 24], [0.5, 0.7], ["LDNNY", "ALL"], [1.5, 2, 3, 4]):
        G.append(("F8_choch", dict(tf=tf, N=N, retr=rt, sess=s, rr=rr)))
    for (d, hm), hold, sk in itertools.product([(1, 18 * 60 + 5), (1, 18 * 60 + 30), (1, 19 * 60), (-1, 9 * 60), (-1, 9 * 60 + 30)], [60, 120, 180], [1.0, 2.0]):
        G.append(("F9_tod", dict(d=d, entry_hm=hm, hold=hold, slk=sk)))
    return G

FN = dict(F1_sweep=F.f1_sweep, F2_fvg=F.f2_fvg, F3_bretest=F.f3_bretest, F4_asia=F.f4_asia, F5_orb=F.f5_orb,
          F6_tmom=F.f6_tmom, F7_bb=F.f7_bb, F8_choch=F.f8_choch, F9_tod=F.f9_tod)
D = None
def work(arg):
    cid, (fam, p) = arg
    t = E.run(D, FN[fam](D, **p))
    t["cid"] = cid
    return t

def summarize(t):
    is_, oos = t[t.time < OOS_START], t[t.time >= OOS_START]
    r = {}
    for tag, x in (("is", is_), ("oos", oos), ("all", t)):
        for k, v in E.metrics(x).items(): r[f"{tag}_{k}"] = v
    for y in (2023, 2024, 2025, 2026):
        x = t[t.time.dt.year == y]; r[f"y{y}"] = x.R.mean() if len(x) else np.nan
    for d, nm in ((1, "long"), (-1, "short")):
        x = is_[is_.dir == d]; r[f"is_{nm}_expR"] = x.R.mean() if len(x) else np.nan
        x = oos[oos.dir == d]; r[f"oos_{nm}_expR"] = x.R.mean() if len(x) else np.nan
    r["gap_trades"] = int((t.reason == 5).sum()); r["worstR"] = t.R.min() if len(t) else np.nan
    return r

if __name__ == "__main__":
    D = E.load(SCEN[0])
    if SCEN == "Z": E.COMM = 0.0; E.SLIP = 0.0
    if NOCAP: E.MAX_STOP = 1e9; F.tf_bars(D, 5); F.tf_bars(D, 15)
    G = grid(); print("configs:", len(G), flush=True)
    t0 = time.time()
    with mp.get_context("fork").Pool(7) as pool:
        res = pool.map(work, list(enumerate(G)), chunksize=4)
    print("sim done", round(time.time() - t0), "s", flush=True)
    T = pd.concat(res, ignore_index=True)
    T.to_parquet(f"../out/trades_{TAG}.parquet")
    rows = []
    for cid, (fam, p) in enumerate(G):
        r = dict(cid=cid, family=fam, params=str(p)); r.update(summarize(T[T.cid == cid])); rows.append(r)
    S = pd.DataFrame(rows); S.to_csv(f"../out/summary_{TAG}.csv", index=False)
    print(S.groupby("family").agg(n=("cid", "size"), is_exp_med=("is_expR", "median"), oos_exp_med=("oos_expR", "median"),
                                   best_is=("is_expR", "max")).round(3))
