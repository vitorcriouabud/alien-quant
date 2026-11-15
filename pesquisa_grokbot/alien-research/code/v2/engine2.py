"""V2 multi-market bar engine (H1/H4/D1), Dukascopy bid/ask H1.
- Signals on MID closes of bar i -> entry at OPEN of bar i+1 (causal).
- Cost per round trip (price units) = entry-bar bid/ask spread (scaled per instrument) + commission + 2*slippage.
- Swap: annual % of notional per calendar day held (constant approximation, see SWAP).
- Stop/TP checked on bar high/low of the trading TF; SL first if both; gap through SL fills at open.
"""
import numpy as np, pandas as pd
from numba import njit
DATA = "/workspace/alien-research/data/h1"
# commission in price units per unit (round trip), spread scale, slippage (price units), swap %/yr (long, short)
INSTR = {
    "xauusd":        dict(comm=0.07,    sp_scale=0.5, sp_floor=0.20, slip=0.05,   swap=(-5.0, -1.0)),
    "eurusd":        dict(comm=0.00007, sp_scale=1.0, sp_floor=0.0,  slip=0.00002, swap=(-3.0, 0.0)),
    "gbpusd":        dict(comm=0.00007, sp_scale=1.0, sp_floor=0.0,  slip=0.00002, swap=(-2.0, -0.5)),
    "usdjpy":        dict(comm=0.007,   sp_scale=1.0, sp_floor=0.0,  slip=0.002,   swap=(1.0, -5.0)),
    "usa500idxusd":  dict(comm=0.0,     sp_scale=1.0, sp_floor=0.0,  slip=0.10,    swap=(-6.0, -1.0)),
    "usatechidxusd": dict(comm=0.0,     sp_scale=1.0, sp_floor=0.0,  slip=0.50,    swap=(-6.0, -1.0)),
    "deuidxeur":     dict(comm=0.0,     sp_scale=1.0, sp_floor=0.0,  slip=0.50,    swap=(-5.0, -1.0)),
    "btcusd":        dict(comm=0.0,     sp_scale=1.0, sp_floor=0.0,  slip=5.0,     swap=(-20.0, -20.0)),
}
import os
if os.environ.get("COSTS") == "RF":   # RoboForex ProCent-like: no commission, avg spreads as floors, RF index swaps
    INSTR = {
        "xauusd": dict(comm=0.0, sp_scale=1.0, sp_floor=0.25, slip=0.05, swap=(-5.0, -1.0)),
        "eurusd": dict(comm=0.0, sp_scale=1.0, sp_floor=0.00013, slip=0.00002, swap=(-3.0, 0.0)),
        "gbpusd": dict(comm=0.0, sp_scale=1.0, sp_floor=0.00015, slip=0.00002, swap=(-2.0, -0.5)),
        "usdjpy": dict(comm=0.0, sp_scale=1.0, sp_floor=0.016, slip=0.002, swap=(1.0, -5.0)),
        "usa500idxusd": dict(comm=0.0, sp_scale=1.0, sp_floor=0.6, slip=0.10, swap=(-7.2, -1.8)),
        "usatechidxusd": dict(comm=0.0, sp_scale=1.0, sp_floor=2.0, slip=0.50, swap=(-7.2, -1.8)),
        "deuidxeur": dict(comm=0.0, sp_scale=1.0, sp_floor=0.9, slip=0.50, swap=(-7.2, -1.8)),
        "btcusd": dict(comm=0.0, sp_scale=1.0, sp_floor=0.0, slip=5.0, swap=(-20.0, -20.0)),
    }
OOS = pd.Timestamp("2026-01-01", tz="America/New_York")

def load_h1(sym):
    b = pd.read_csv(f"{DATA}/{sym}_bid.csv"); a = pd.read_csv(f"{DATA}/{sym}_ask.csv")
    d = b.merge(a, on="timestamp", suffixes=("_b", "_a"))
    d = d[~((d.high_b == d.low_b) & (d.open_b == d.close_b))]   # drop flat filler bars
    t = pd.to_datetime(d.timestamp, unit="ms", utc=True).dt.tz_convert("America/New_York")
    P = INSTR[sym]
    df = pd.DataFrame(index=pd.DatetimeIndex(t))
    for c in ("open", "high", "low", "close"):
        df[c] = (d[c + "_b"].values + d[c + "_a"].values) / 2
    sp = (d.close_a.values - d.close_b.values)
    df["sp"] = np.maximum(P["sp_floor"], P["sp_scale"] * sp)
    return df

def resample(df, tf):
    if tf == "H1": r = df.copy()
    else:
        s = df.copy(); s.index = s.index + pd.Timedelta(hours=7)   # server time (17:00 NY = 00:00)
        rule = {"H4": "4h", "D1": "1D"}[tf]
        r = s.resample(rule).agg(dict(open="first", high="max", low="min", close="last", sp="median")).dropna()
        r.index = r.index - pd.Timedelta(hours=7)
        if tf == "D1": r = r[r.index.dayofweek != 5] if False else r
    pc = r.close.shift(1)
    tr = np.maximum(r.high - r.low, np.maximum((r.high - pc).abs(), (r.low - pc).abs()))
    r["atr"] = tr.rolling(20).mean()
    return r

@njit(cache=True)
def sim(o, h, l, c, sp, atr, tdays, ent, exl, exs, stopk, rr, trailk, maxbars, cost_fixed, slip, swl, sws):
    n = o.shape[0]
    ei = np.empty(n, np.int64); xi = np.empty(n, np.int64); dr = np.empty(n, np.int64)
    pnl = np.empty(n); risk = np.empty(n); k = 0
    i = 0
    while i < n - 1:
        d = ent[i]
        if d == 0 or atr[i] != atr[i]:
            i += 1; continue
        j = i + 1
        fp = o[j]
        cost = sp[j] + cost_fixed + 2 * slip
        dist = stopk * atr[i]
        st = fp - d * dist
        tp = fp + d * rr * dist if rr > 0 else np.nan
        ex = 0.0; xj = -1
        for m in range(j, n):
            if d == 1:
                if m > j and o[m] <= st: ex = o[m]; xj = m; break
                if l[m] <= st: ex = st; xj = m; break
                if rr > 0 and h[m] >= tp and m > j: ex = max(tp, o[m]); xj = m; break
            else:
                if m > j and o[m] >= st: ex = o[m]; xj = m; break
                if h[m] >= st: ex = st; xj = m; break
                if rr > 0 and l[m] <= tp and m > j: ex = min(tp, o[m]); xj = m; break
            # bar-close decisions -> act at next open
            if m + 1 < n:
                if (d == 1 and exl[m]) or (d == -1 and exs[m]) or (m - j + 1 >= maxbars):
                    ex = o[m + 1]; xj = m + 1; break
                if trailk > 0 and atr[m] == atr[m]:
                    if d == 1: st = max(st, c[m] - trailk * atr[m])
                    else: st = min(st, c[m] + trailk * atr[m])
        if xj < 0: break
        days = tdays[xj] - tdays[j]
        swap = (swl if d == 1 else sws) / 100.0 / 365.0 * fp * days
        ei[k] = j; xi[k] = xj; dr[k] = d
        pnl[k] = (ex - fp) * d - cost + swap
        risk[k] = dist + cost
        k += 1
        i = xj if xj > i else i + 1
        if ent[i] != 0 and i == xj: pass
    return ei[:k], xi[:k], dr[:k], pnl[:k], risk[:k]

def run(r, sym, ent, exl=None, exs=None, stopk=2.0, rr=0.0, trailk=0.0, maxbars=10**6):
    P = INSTR[sym]; n = len(r)
    z = np.zeros(n, np.bool_)
    tdays = (r.index.view("int64") / 86400e9).astype(np.float64) if hasattr(r.index, "view") else None
    tdays = np.asarray(r.index.asi8, dtype=np.float64) / 86400e9
    e = sim(r.open.values, r.high.values, r.low.values, r.close.values, r.sp.values, r.atr.values, tdays,
            np.asarray(ent, np.int64), z if exl is None else np.asarray(exl, np.bool_), z if exs is None else np.asarray(exs, np.bool_),
            float(stopk), float(rr), float(trailk), int(maxbars), P["comm"], P["slip"], P["swap"][0], P["swap"][1])
    t = pd.DataFrame(dict(ei=e[0], xi=e[1], dir=e[2], pnl=e[3], risk=e[4]))
    t["R"] = t.pnl / t.risk
    t["entry"] = r.index[t.ei.values]; t["exit"] = r.index[t.xi.values]
    return t

def stats(t, risk=0.01):
    if len(t) < 2:
        return dict(n=len(t), pf=np.nan, expR=np.nan, wr=np.nan, t=np.nan, cagr=np.nan, mdd=np.nan, maxLS=0)
    R = t.R.values; gp = R[R > 0].sum(); gl = -R[R < 0].sum()
    eq = np.cumprod(1 + risk * R); peak = np.maximum.accumulate(np.concatenate([[1.0], eq]))[1:]
    mdd = (1 - eq / peak).max()
    yrs = max((t.exit.iloc[-1] - t.entry.iloc[0]).days / 365.25, 0.25)
    ls = c_ = 0
    for x in R:
        c_ = c_ + 1 if x < 0 else 0; ls = max(ls, c_)
    return dict(n=len(R), pf=gp / gl if gl > 0 else np.inf, expR=R.mean(), wr=(R > 0).mean(),
                t=R.mean() / R.std(ddof=1) * np.sqrt(len(R)) if R.std() > 0 else np.nan,
                cagr=eq[-1] ** (1 / yrs) - 1, mdd=mdd, maxLS=ls)
