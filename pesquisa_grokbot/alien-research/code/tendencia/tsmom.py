"""Multi-market trend following (TSMOM / Donchian) per TENDENCIA_MULTI.md pre-registration."""
import numpy as np, pandas as pd, sys
from scipy import stats
D = "/workspace/alien-research/data/d1"; OUT = "/workspace/alien-research/out/tendencia"
# symbol: (kind, base_ccy, quote_ccy, spread floor in price units)
U = {"eurusd":("fx","EUR","USD",0.00013),"gbpusd":("fx","GBP","USD",0.00015),"usdjpy":("fx","USD","JPY",0.016),
     "audusd":("fx","AUD","USD",0.00015),"usdcad":("fx","USD","CAD",0.00020),"usdchf":("fx","USD","CHF",0.00020),"nzdusd":("fx","NZD","USD",0.00020),
     "usa500idxusd":("idx",None,"USD",0.6),"usatechidxusd":("idx",None,"USD",2.0),"usa30idxusd":("idx",None,"USD",3.0),
     "deuidxeur":("idx",None,"EUR",1.5),"gbridxgbp":("idx",None,"GBP",1.5),"jpnidxjpy":("idx",None,"JPY",10.0),
     "fraidxeur":("idx",None,"EUR",1.5),"ausidxaud":("idx",None,"AUD",2.0),
     "xauusd":("cmd",None,"USD",0.40),"xagusd":("cmd",None,"USD",0.04),"lightcmdusd":("cmd",None,"USD",0.05),"brentcmdusd":("cmd",None,"USD",0.05)}
# approximate yearly average policy rates (%), 2010..2026
YRS = list(range(2010, 2027))
R = {"USD":[.15,.1,.15,.1,.1,.15,.4,1.0,1.8,2.2,.4,.1,1.7,5.0,5.1,4.2,3.7],
     "EUR":[.5,.75,.1,0,-.1,-.2,-.35,-.4,-.4,-.45,-.5,-.5,.3,3.3,3.6,2.2,2.0],
     "GBP":[.5,.5,.5,.5,.5,.5,.4,.3,.6,.75,.2,.1,1.5,4.7,5.1,4.2,3.8],
     "JPY":[.1,.1,.1,.1,.1,.1,-.1,-.1,-.1,-.1,-.1,-.1,-.1,-.1,.1,.5,.7],
     "AUD":[4.4,4.6,3.7,2.9,2.5,2.1,1.6,1.5,1.5,1.0,.3,.1,1.3,3.9,4.35,3.9,3.6],
     "CAD":[.6,1,1,1,1,.6,.5,.7,1.4,1.75,.4,.25,2.0,4.7,4.5,2.8,2.3],
     "CHF":[0,0,0,0,0,-.75,-.75,-.75,-.75,-.75,-.75,-.75,-.2,1.5,1.3,.3,0],
     "NZD":[2.6,2.5,2.5,2.5,3.1,3.0,2.1,1.75,1.75,1.4,.4,.4,2.5,5.4,5.3,3.6,2.6]}
def load():
    px, sp = {}, {}
    for s in U:
        b = pd.read_csv(f"{D}/{s}_bid.csv"); a = pd.read_csv(f"{D}/{s}_ask.csv")
        df = pd.DataFrame({"b": b.close.values, "a": a.close.values, "v": b.get("volume", pd.Series(np.nan, index=b.index)).values},
                          index=pd.to_datetime(b.timestamp, unit="ms"))
        df = df[df.index.dayofweek < 5]
        m = (df.a + df.b) / 2
        m = m[(m.diff() != 0)]  # drop flat (holiday/no-trade) days
        px[s] = m; sp[s] = (df.a - df.b).reindex(m.index)
    P = pd.DataFrame(px).sort_index(); S = pd.DataFrame(sp).reindex(P.index)
    P = P[P.index.dayofweek < 5]
    return P, S
def swap_rates(idx, mult_extra=0.0, credit=0.0):
    """annual swap rate (fraction of notional) for long and short positions, per day x symbol."""
    yr = np.clip(idx.year.values, 2010, 2026) - 2010
    L = pd.DataFrame(index=idx, columns=list(U), dtype=float); Sh = L.copy()
    for s, (k, base, q, _) in U.items():
        rq = np.array(R[q])[yr] / 100
        if k == "fx":
            rb = np.array(R[base])[yr] / 100; diff = rb - rq
            l = diff - 0.02; sh = -diff - 0.02
        else:
            l = -(rq + 0.025); sh = rq - 0.025
        l = np.where(l > 0, l * credit, l) - mult_extra; sh = np.where(sh > 0, sh * credit, sh) - mult_extra
        L[s] = l; Sh[s] = sh
    return L, Sh
def signals(P, rule):
    if rule.startswith("M") and rule != "MB":
        n = {"M3": 63, "M6": 126, "M12": 252}[rule]; return np.sign(P / P.shift(n) - 1)
    if rule == "MB": return (signals(P, "M3") + signals(P, "M6") + signals(P, "M12")) / 3
    if rule == "LONG": return (P * 0 + 1)
    ne, nx = {"D50": (50, 25), "D100": (100, 50)}[rule]
    hiE = P.shift(1).rolling(ne).max(); loE = P.shift(1).rolling(ne).min()
    hiX = P.shift(1).rolling(nx).max(); loX = P.shift(1).rolling(nx).min()
    out = np.full(P.shape, np.nan); pv = P.values
    for j in range(P.shape[1]):
        pos = 0.0
        for i in range(P.shape[0]):
            p = pv[i, j]
            if np.isnan(p) or np.isnan(hiE.values[i, j]): out[i, j] = np.nan if np.isnan(p) else 0; continue
            if pos > 0 and p < loX.values[i, j]: pos = 0
            elif pos < 0 and p > hiX.values[i, j]: pos = 0
            if p > hiE.values[i, j]: pos = 1
            elif p < loE.values[i, j]: pos = -1
            out[i, j] = pos
    return pd.DataFrame(out, index=P.index, columns=P.columns)
def backtest(P, S, rule, cost_mult=1.0, swap_extra=0.0, credit=0.0, drop=None, tvol=0.10, band=0.25, levcap=3.0, P_sig=None):
    cols = [c for c in P.columns if c != drop]; P = P[cols].ffill(); S = S[cols]
    ret = P.pct_change()
    lr = np.log(P).diff()
    vol = lr.ewm(span=60, min_periods=60).std() * np.sqrt(252)
    hist = P.notna().cumsum() >= 252
    sig = signals(P, rule).where(hist & vol.notna())
    n_act = sig.notna().sum(axis=1).clip(lower=1)
    tgt = (sig.mul(0.10 / np.sqrt(n_act), axis=0) / vol).fillna(0) * (tvol / 0.10)
    # portfolio vol cap (ex-ante, 120d cov) + leverage cap
    rv = ret.fillna(0).values; T = tgt.values.copy()
    for i in range(120, len(T)):
        w = T[i]
        if not w.any(): continue
        C = np.cov(rv[i-119:i+1].T) * 252; pv_ = np.sqrt(max(w @ C @ w, 0))
        sc = min(1.0, tvol / pv_) if pv_ > 0 else 1.0
        sc = min(sc, levcap / max(np.abs(w).sum() * sc, 1e-12) * sc) if np.abs(w).sum() * sc > levcap else sc
        T[i] = w * sc
    T[:120] = 0
    # band + 1-day execution lag: target at close t -> executed at close t+1
    pos = np.zeros_like(T); cur = np.zeros(T.shape[1])
    for i in range(1, len(T)):
        t = T[i - 1]
        chg = (np.abs(t - cur) > band * np.abs(t)) | (np.sign(t) != np.sign(cur))
        cur = np.where(chg, t, cur); pos[i] = cur
    pos = pd.DataFrame(pos, index=P.index, columns=cols)
    held = pos.shift(1).fillna(0)  # position held over day d (set at close d-1)
    gross = (held * ret.fillna(0)).sum(axis=1)
    spr = np.maximum(S.ffill().values, np.array([U[c][3] for c in cols])) / P.ffill().values
    dpos = pos.diff().abs().fillna(0).values
    tc = pd.Series(np.nansum(dpos * spr * 0.75 * cost_mult, axis=1), index=P.index)  # half spread + 25% slippage per change
    L, Sh = swap_rates(P.index, swap_extra, credit); L = L[cols]; Sh = Sh[cols]
    days = pd.Series(P.index, index=P.index).diff().dt.days.fillna(1).values[:, None]
    rate = np.where(held.values > 0, L.values, Sh.values)
    sw = pd.Series((np.abs(held.values) * rate * days / 365 * (cost_mult if cost_mult > 1 else 1)).sum(axis=1), index=P.index)
    net = gross - tc + sw
    contrib = (held * ret.fillna(0)).sum()  # gross per market (approx.)
    return dict(net=net, gross=gross, tc=tc, sw=sw, pos=pos, contrib=contrib)
def stats_(r):
    r = r.dropna(); yrs = len(r) / 252
    eq = (1 + r).cumprod(); cagr = eq.iloc[-1] ** (1 / yrs) - 1 if yrs > 0 else np.nan
    sh = r.mean() / r.std() * np.sqrt(252) if r.std() > 0 else 0
    return dict(cagr=cagr, vol=r.std() * np.sqrt(252), sharpe=sh, t=sh * np.sqrt(yrs), mdd=(1 - eq / eq.cummax()).max())
