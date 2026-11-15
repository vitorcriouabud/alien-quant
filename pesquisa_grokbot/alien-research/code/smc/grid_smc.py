import itertools, sys, numpy as np, pandas as pd, multiprocessing as mp
sys.path.insert(0, "/workspace/alien-research/code/smc"); import smc
SYMS = ["xauusd", "eurusd", "gbpusd", "usatechidxusd", "usa500idxusd"]
G = list(itertools.product(["H4", "D1"], [True, False], ["asia", "asia_or_pdl"], ["none", "h1fvg"], ["fvg", "ob", "mkt"], ["2R", "3R", "liq"]))
def work(args):
    sym, fr = args
    D = smc.load_m1(sym)
    if fr:
        for k in "ohlc": D["b" + k] = D["m" + k]; D["a" + k] = D["m" + k]
        D["comm"] = 0.0; D["slip"] = 0.0
    P = smc.prepare(D); out = []
    for cid, (b, pdf, pool, poi, en, tp) in enumerate(G):
        t = smc.run(D, smc.signals(D, P, bias_tf=b, pd_filter=pdf, pool=pool, poi=poi, entry=en, tp=tp))
        if len(t) == 0: continue
        t = t[["time", "dir", "R", "reason", "mae", "risk"]].copy()
        t["sym"] = sym; t["cid"] = cid; t["params"] = f"bias={b} PD={pdf} pool={pool} poi={poi} entry={en} tp={tp}"
        out.append(t)
    return pd.concat(out)
if __name__ == "__main__":
    fr = len(sys.argv) > 1 and sys.argv[1] == "Z"
    print("configs/symbol", len(G), "total", len(G) * len(SYMS), flush=True)
    with mp.get_context("fork").Pool(3) as p:
        T = pd.concat(p.map(work, [(s, fr) for s in SYMS]))
    T.to_parquet(f"/workspace/alien-research/out/smc_trades{'_Z' if fr else ''}.parquet"); print("trades", len(T))
