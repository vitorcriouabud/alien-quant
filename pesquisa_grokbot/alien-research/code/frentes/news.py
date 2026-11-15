"""Frente 2: XAUUSD around CPI/NFP/FOMC, pre-registered variants N1-N3 (FRENTES.md)."""
import numpy as np, pandas as pd
from scipy import stats
R = "/workspace/alien-research"; OUT = f"{R}/out/frentes"
COMM = 0.168; SLIP = 0.05; FLOOR = 0.25; NEWS_SP = 1.0; NEWS_SLIP = 0.30
m = pd.read_parquet(f"{R}/data/xau_m1_2016_2026.parquet")
m.index = m.index.tz_convert("America/New_York")
mid = pd.DataFrame({k: (m["b" + k[0]] + m["a" + k[0]]) / 2 for k in ("open", "high", "low", "close")}); mid["sp"] = (m.ac - m.bc).values
def rd(f): return [pd.Timestamp(x.strip()) for x in open(f"{R}/data/news/{f}") if x.strip()]
excl = {pd.Timestamp(x) for x in ["2019-10-11", "2020-03-03", "2020-03-15", "2020-03-23", "2020-03-31", "2020-08-27", "2025-08-22"]}
ev = [("CPI", d, 8, 30) for d in rd("cpi_iso.txt")] + [("NFP", d, 8, 30) for d in rd("empsit_iso.txt")] + [("FOMC", d, 14, 0) for d in rd("fomc_iso.txt") if d not in excl]
ev = [(k, pd.Timestamp(d.year, d.month, d.day, hh, mm, tz="America/New_York")) for k, d, hh, mm in ev if pd.Timestamp("2016-01-01") <= d <= pd.Timestamp("2026-11-13")]
def cost_sp(i0, i, sp):  # effective spread at bar offset i (minutes from T)
    return max(sp, NEWS_SP if 0 <= i <= 4 else FLOOR), (NEWS_SLIP + SLIP if 0 <= i <= 4 else SLIP)
def run_event(kind, T):
    w = mid.loc[T - pd.Timedelta(minutes=215): T + pd.Timedelta(minutes=61)]
    off = ((w.index - T) / pd.Timedelta(minutes=1)).astype(int); w = w.assign(off=off).set_index("off")
    need = list(range(-15, 61))
    if not set(need).issubset(w.index): return []
    O, H, L, C, SP = (w[k] for k in ("open", "high", "low", "close", "sp"))
    pre = w.loc[-210:-1]; q = pre.groupby((pre.index + 210) // 15).agg(h=("high", "max"), l=("low", "min"))
    atr15 = (q.h - q.l).tail(14).mean()
    out = []
    def manage(var, d, entry_px, entry_off, stop, exit_off, cost_entry):
        # walk bars entry_off..exit_off-1 for stop; exit at open of exit_off
        for k in range(entry_off, exit_off):
            hit = (d > 0 and L[k] <= stop) or (d < 0 and H[k] >= stop)
            if hit:
                px = (min(O[k], stop) if d > 0 else max(O[k], stop)) if k > entry_off else stop
                spe, sl = cost_sp(0, k, SP[k]); xp = px - d * (spe / 2 + sl); reason = "SL"; break
        else:
            spe, sl = cost_sp(0, exit_off, SP[exit_off]); xp = O[exit_off] - d * (spe / 2 + sl); reason = "TIME"
        pnl = (xp - entry_px) * d - COMM; risk = abs(entry_px - stop) + 1e-9
        out.append(dict(var=var, kind=kind, T=T, dir=d, entry=entry_px, exit=xp, stop=stop, R=pnl / risk, risk_usd=risk, reason=reason, atr15=atr15))
    # N1 breakout after first minute
    d = np.sign(C[0] - O[0]); rng = max(H[0] - L[0], 0.5)
    if d != 0:
        spe, sl = cost_sp(0, 2, SP[2]); ep = O[2] + d * (spe / 2 + sl)
        for v, x in (("N1a", 30), ("N1b", 60)): manage(v, d, ep, 2, ep - d * rng, x, 0)
    # N2 fade
    mv = C[4] - O[0]
    if abs(mv) > atr15:
        d = -np.sign(mv); ext = H.loc[0:4].max() if d < 0 else L.loc[0:4].min(); st = ext - d * 0.5
        spe, sl = cost_sp(0, 5, SP[5]); ep = O[5] + d * (spe / 2 + sl)
        if (st - ep) * d < 0:
            for v, x in (("N2a", 30), ("N2b", 60)): manage(v, d, ep, 5, st, x, 0)
    # N3 straddle OCO
    hi, lo = H.loc[-15:-1].max(), L.loc[-15:-1].min(); h = hi - lo; bs, ss = hi + 0.2 * h, lo - 0.2 * h
    for k in range(0, 10):
        up, dn = H[k] >= bs, L[k] <= ss
        if up or dn:
            spe, sl = cost_sp(0, k, SP[k]); r_ = H[k] - L[k]
            if up and dn:  # whipsaw inside one bar: conservative full loss on the long side
                d = 1; ep = max(O[k], bs) + spe / 2 + sl + 0.2 * r_; st = lo
                for v, x in (("N3a", 30), ("N3b", 60)):
                    xp = st - (spe / 2 + sl); pnl = (xp - ep) - COMM
                    out.append(dict(var=v, kind=kind, T=T, dir=1, entry=ep, exit=xp, stop=st, R=pnl / abs(ep - st), risk_usd=abs(ep - st), reason="WHIP", atr15=atr15))
            else:
                d = 1 if up else -1; lvl = bs if up else ss
                ep = (max(O[k], lvl) if up else min(O[k], lvl)) + d * (spe / 2 + sl + 0.2 * r_); st = lo if up else hi
                for v, x in (("N3a", 30), ("N3b", 60)): manage(v, d, ep, k, st, x, 0)
            break
    return out
rows = []
for kind, T in ev: rows += run_event(kind, T)
X = pd.DataFrame(rows); X.to_csv(f"{OUT}/news_trades.csv", index=False)
print("events", len(ev), "trades", len(X)); print(X.groupby(["var", "kind"]).size().unstack())
X["y"] = X["T"].map(lambda t: t.year)
res = []
for v in sorted(X["var"].unique()):
    for kind in ("ALL", "CPI", "NFP", "FOMC"):
        x = X[(X["var"] == v) & ((X.kind == kind) | (kind == "ALL"))]
        i = x[x.y <= 2024]; va = x[x.y == 2025]
        t = i.R.mean() / i.R.std() * np.sqrt(len(i)) if len(i) > 2 else 0
        k = max(1, int(np.ceil(0.01 * len(i))))
        yrs = i.groupby("y").R.sum()
        res.append(dict(id=f"{v}_{kind}", n_IS=len(i), expR_IS=i.R.mean(), t=t, p=1 - stats.norm.cdf(t), pf=i.R[i.R > 0].sum() / -i.R[i.R < 0].sum(), wr=(i.R > 0).mean(),
                        yrs_pos=int((yrs > 0).sum()), sum_ex_top1=i.R.sort_values().iloc[:-k].sum(), n_VA=len(va), expR_VA=va.R.mean(), sumR_VA=va.R.sum(),
                        years=" ".join(f"{a}:{b:+.1f}R" for a, b in yrs.items())))
S = pd.DataFrame(res); S.to_csv(f"{OUT}/news_summary.csv", index=False)
pd.set_option("display.width", 250); print(S.drop(columns="years").round(3).to_string())
