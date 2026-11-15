import numpy as np, pandas as pd, pickle, sys
from scipy.stats import norm
sys.path.insert(0, "/workspace/alien-research/code/tiro"); from data import PPL, MINLOT
OUT = "/workspace/alien-research/out/tiro"; TR = pickle.load(open(f"{OUT}/trades.pkl", "rb"))
RISK = 45.0
def dollars(t):
    ppl = t.sym.map(PPL).values; lot = np.floor(RISK / (t.r1.values * ppl) / 0.01 + 1e-9) * 0.01
    ok = lot >= t.sym.map(MINLOT).values - 1e-12
    t = t.assign(lot=lot, ok=ok, usd=lot * t.pts.values * ppl, wusd=lot * t.worst.values * ppl)
    t["R"] = t.pts / t.r1; t["wR"] = t.worst / t.r1; return t
def maxls(R):
    m = c = 0
    for x in R: c = c + 1 if x <= 0 else 0; m = max(m, c)
    return m
rows = []
for k, t in TR.items():
    t = dollars(t); TR[k] = t
    y = t.entry.dt.year; IS = t[(y >= 2016) & (y <= 2024)]; V = t[y == 2025]
    R = IS.R.values; n = len(R); mu = R.mean(); sd = R.std(ddof=1); tt = mu / sd * np.sqrt(n)
    srt = np.sort(R)[::-1]; k1 = max(1, int(np.ceil(0.01 * n)))
    top_share = srt[:k1].sum() / R.sum() if R.sum() > 0 else np.nan
    yrs = IS.groupby(IS.entry.dt.year).R.sum()
    rows.append(dict(id=k, n=n, wr=(R > 0).mean(), avgwinR=R[R > 0].mean(), avgR=mu, exp_usd=IS[IS.ok].usd.mean(),
                     pf=R[R > 0].sum() / -R[R < 0].sum(), t=tt, p=1 - norm.cdf(tt), yrs_pos=int((yrs > 0).sum()),
                     avgR_ex_top1=srt[k1:].mean(), top1_share=top_share, maxLS=maxls(R),
                     float_breach_pct=100 * (IS[IS.ok].wusd <= -50).mean(), skip_pct=100 * (1 - IS.ok.mean()),
                     n2025=len(V), R2025=V.R.sum(), avgR2025=V.R.mean(), maxwinR=R.max(), hit5R=(R >= 4.9).mean() * 100))
S = pd.DataFrame(rows).set_index("id")
att = S[~S.index.str.startswith("ctrl")].copy()
m = len(att); o = att.p.sort_values(); bh = (o.values <= 0.10 * np.arange(1, m + 1) / m)
passbh = set(o.index[:np.max(np.nonzero(bh)[0]) + 1]) if bh.any() else set()
att["BH"] = att.index.isin(passbh); att["Bonf_round"] = att.p <= 0.05 / m; att["Bonf_project"] = att.p <= 0.05 / 2364
S.loc[att.index, ["BH", "Bonf_round", "Bonf_project"]] = att[["BH", "Bonf_round", "Bonf_project"]]
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(S.round(3).to_string())
S.to_csv(f"{OUT}/attempts.csv"); pickle.dump(TR, open(f"{OUT}/trades_usd.pkl", "wb"))
