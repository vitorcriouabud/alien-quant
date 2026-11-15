import numpy as np, pandas as pd, pickle, sys
sys.path.insert(0, "/workspace/alien-research/code/tiro"); from data import PPL, MINLOT
OUT = "/workspace/alien-research/out/tiro"
TR = pickle.load(open(f"{OUT}/trades.pkl", "rb")); BL = pickle.load(open(f"{OUT}/baseline.pkl", "rb"))
RISK = 45.0; NP = 20000; HORIZON = 36
def prep(t, minlot=None):
    t = t[(t.entry.dt.year >= 2016) & (t.entry.dt.year <= 2025)].sort_values("entry")
    keep = []; busy = None
    for r in t.itertuples():
        if busy is not None and r.entry < busy: continue
        ppl = PPL[r.sym]; lot = np.floor(RISK / (r.r1 * ppl) / 0.01 + 1e-9) * 0.01
        if lot < (minlot if minlot else MINLOT[r.sym]) - 1e-12: continue
        keep.append((r.exit, lot * r.pts * ppl, lot * r.worst * ppl)); busy = r.exit
    k = pd.DataFrame(keep, columns=["exit", "usd", "wusd"])
    k["m"] = k.exit.dt.year * 12 + k.exit.dt.month - 1; k["dom"] = k.exit.dt.day
    return k
def run_path(seq):
    bal = 0.0; dp = {}; pdays = 0
    for mi, dk, u, w in seq:
        if w <= -50.0: return "float", mi
        prev = dp.get(dk, 0.0); dp[dk] = prev + u
        if dp[dk] <= -200: return "daily", mi
        if prev < 25 <= dp[dk]: pdays += 1
        elif prev >= 25 > dp[dk]: pdays -= 1
        bal += u
        if bal <= -500: return "max", mi
        if bal >= 400 and pdays >= 3: return "pass", mi
    return "running", None
def mc(k, seed=1):
    rng = np.random.default_rng(seed); months = np.arange(k.m.min(), k.m.max() + 1)
    by = {m: list(zip(g.dom.values, g.usd.values, g.wusd.values)) for m, g in k.groupby("m")}
    res = []
    for p in range(NP):
        pick = rng.choice(months, HORIZON)
        res.append(run_path(((i, (i, d), u, w) for i, m in enumerate(pick) for d, u, w in by.get(m, []))))
    st = np.array([r[0] for r in res]); mo = np.array([r[1] if r[1] is not None else 999 for r in res]); ps = st == "pass"
    return dict(P_pass_36m=ps.mean(), P_pass_3m=(ps & (mo < 3)).mean(), P_pass_6m=(ps & (mo < 6)).mean(), P_pass_12m=(ps & (mo < 12)).mean(),
                P_breach_36m=np.isin(st, ["float", "daily", "max"]).mean(), P_breach_float=(st == "float").mean(),
                P_running=(st == "running").mean(), med_months_pass=np.median(mo[ps]) + 1 if ps.any() else np.nan)
def hist(k):
    out = []
    for m0 in range(k.m.min(), k.m.max() - 11):
        sub = k[k.m >= m0]; out.append(run_path(((mm - m0, (mm, d), u, w) for mm, d, u, w in zip(sub.m, sub.dom, sub.usd, sub.wusd))))
    st = np.array([r[0] for r in out])
    return dict(hist_starts=len(st), hist_pass=(st == "pass").mean(), hist_breach=np.isin(st, ["float", "daily", "max"]).mean(),
                hist_pass12=np.mean([(r[0] == "pass") and r[1] < 12 for r in out]))
rows = []
items = [(k, v, None) for k, v in TR.items() if not k.startswith("ctrl")] + [("BASE_MR+CAL", BL["MRCAL"], 0.01), ("BASE_CAL", BL["CAL"], 0.01), ("BASE_MR", BL["MR"], 0.01)]
for name, t, ml in items:
    k = prep(t, ml); d = dict(id=name, trades_used=len(k), exp_usd=k.usd.mean(), trades_per_month=len(k) / (k.m.max() - k.m.min() + 1))
    d.update(mc(k)); d.update(hist(k)); rows.append(d); print(name, {a: round(b, 3) if isinstance(b, float) else b for a, b in d.items()}, flush=True)
pd.DataFrame(rows).to_csv(f"{OUT}/goat_mc.csv", index=False)
