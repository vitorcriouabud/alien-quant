import itertools, sys, numpy as np, pandas as pd, multiprocessing as mp
sys.path.insert(0, "/workspace/alien-research/code/v2")
import engine2 as E, fam2 as F, os; SUF = "_RF" if os.environ.get("COSTS") == "RF" else ""
SYMS = list(E.INSTR)
def grid():
    G = []
    for tf, N, sk, tr in itertools.product(["H4", "D1"], [20, 55], [2.0, 3.0], [True, False]):
        G.append(("T1_donchian", tf, dict(N=N, exitN=N // 2, stopk=sk, trail=tr)))
    for tf, N in itertools.product(["H4", "D1"], [20, 55]):
        G.append(("T1v_donchian_volf", tf, dict(N=N, exitN=N // 2, stopk=3.0, trail=True, volf=True)))
    for tf, (f, s) in itertools.product(["H4", "D1"], [(20, 100), (50, 200)]):
        G.append(("T2_macross", tf, dict(f=f, s=s, stopk=3.0)))
    for L, sk in itertools.product([60, 120, 250], [3.0, 5.0]):
        G.append(("T3_tsmom", "D1", dict(L=L, stopk=sk)))
    for th, sk in itertools.product([5, 10], [3.0, 5.0]):
        G.append(("M1_rsi2", "D1", dict(th=th, stopk=sk)))
    for th in [0.15, 0.25]:
        G.append(("M3_ibs", "D1", dict(th=th, stopk=4.0)))
    for tf, k in itertools.product(["H1", "H4"], [2.0, 2.5]):
        G.append(("M2_bbrev", tf, dict(k=k, stopk=2.0)))
    for d, hr, hold in itertools.product([1, -1], [18, 3, 9, 16], [4, 8]):
        G.append(("S1_tod", "H1", dict(d=d, hour=hr, hold=hold, stopk=3.0)))
    for rr in [1.0, 1.5, 2.0]:
        G.append(("S2_asia_bo", "H1", dict(rr=rr)))
    return G
FN = dict(T1_donchian=F.donchian, T1v_donchian_volf=F.donchian, T2_macross=F.macross, T3_tsmom=F.tsmom, M1_rsi2=F.rsi2,
          M3_ibs=F.ibs, M2_bbrev=F.bbrev, S1_tod=F.tod, S2_asia_bo=F.asia_bo)

def work(sym):
    h1 = E.load_h1(sym); R = {tf: E.resample(h1, tf) for tf in ("H1", "H4", "D1")}
    out = []
    for cid, (fam, tf, p) in enumerate(grid()):
        r = R[tf]; kw = FN[fam](r, **p)
        cd = kw.pop("_custom_dist", None)
        if cd is not None:   # natural structural stop: pass via atr column with stopk=1
            r = r.copy(); r["atr"] = np.where(np.isfinite(cd) & (cd > 0), cd, np.nan); kw["stopk"] = 1.0
        t = E.run(r, sym, **kw)
        t["sym"] = sym; t["cid"] = cid; t["family"] = fam; t["tf"] = tf; t["params"] = str(p)
        out.append(t)
    return pd.concat(out)

if __name__ == "__main__":
    print("configs per symbol", len(grid()), "symbols", len(SYMS), "total", len(grid()) * len(SYMS))
    with mp.get_context("fork").Pool(4) as pool:
        T = pd.concat(pool.map(work, SYMS))
    T.to_parquet("/workspace/alien-research/out/v2_trades"+SUF+".parquet"); print("trades", len(T))
