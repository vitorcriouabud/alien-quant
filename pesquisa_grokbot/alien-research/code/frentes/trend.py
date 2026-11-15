"""Frente 1: XAUUSD trend-following H4/D1, vol-targeted, RoboForex-ECN conservative costs. Pre-registered in FRENTES.md."""
import sys, numpy as np, pandas as pd, os
sys.path.insert(0, "/workspace/alien-research/code/v2"); import engine2 as E
from scipy import stats
OUT = "/workspace/alien-research/out/frentes"
COMM = 0.168; SLIP = 0.05; FLOOR = 0.25
SWL, SWS = float(os.environ.get("SWL", -8.0)), float(os.environ.get("SWS", -2.0))
VT, LEVCAP, REB = 0.10, 3.0, 0.25
h1 = E.load_h1("xauusd"); h1 = h1[h1.index >= "2015-06-01"]
h1["sp"] = np.maximum(h1.sp / E.INSTR["xauusd"]["sp_scale"] if False else h1.sp, FLOOR)
def bars(tf):
    r = E.resample(h1, tf); r["day"] = (r.index + pd.Timedelta(hours=7)).normalize()  # server day
    return r
D1 = bars("D1"); H4 = bars("H4")
lr = np.log(D1.close).diff(); D1["vol"] = lr.rolling(60).std() * np.sqrt(252)
def sig_series(b, rule, p):
    c, h, l = b.close, b.high, b.low
    if rule == "tsmom":
        if p["L"] == "bh": return pd.Series(1.0, index=c.index)
        if p["L"] == "ens": s = sum(np.sign(c / c.shift(L) - 1) for L in (21, 63, 126, 252)) / 4
        else: s = np.sign(c / c.shift(p["L"]) - 1)
        return s.fillna(0)
    return None
def run(tf, rule, p, lo):
    b = D1 if tf == "D1" else H4
    vol_d = D1.vol.copy(); vol_d.index = D1.day
    vol = b.day.map(lambda d: np.nan).values if False else vol_d.shift(1).reindex(b.day).values  # vol known at end of previous day
    # for D1 bars, vol of the same closed bar is known at close: use same-day value
    if tf == "D1": vol = D1.vol.values
    o, h, l, c, sp, atr = (b[k].values for k in ("open", "high", "low", "close", "sp", "atr"))
    n = len(b); day = b.day.values
    lastofday = np.r_[day[1:] != day[:-1], True]
    s_ts = sig_series(b, rule, p).values if rule == "tsmom" else None
    if rule == "don":
        N, M = p["N"], p["M"]
        hiN = b.high.rolling(N).max().shift(1).values; loN = b.low.rolling(N).min().shift(1).values
        hiM = b.high.rolling(M).max().shift(1).values; loM = b.low.rolling(M).min().shift(1).values
    if rule == "ma":
        f = b.close.rolling(p["F"]).mean().values; sl_ = b.close.rolling(p["S"]).mean().values
    eq = 1.0; units = 0.0; target = 0.0; dirn = 0; stop = np.nan; extreme = np.nan
    eqs = np.empty(n); trades = []; tr_open = None; cost_tot = 0.0; swap_tot = 0.0
    def fill(new_units, px, spr):
        nonlocal eq, units, cost_tot
        dq = abs(new_units - units); cst = dq * (spr / 2 + SLIP + COMM / 2); eq -= cst; cost_tot += cst; units = new_units
    prev = c[0]
    for i in range(1, n):
        # 1) execute pending target at open
        eq += units * (o[i] - prev); prev = o[i]
        if target != units:
            if np.sign(target) != np.sign(units):
                if tr_open is not None: trades.append((tr_open[0], b.index[i], tr_open[1], eq / tr_open[2] - 1)); tr_open = None
                if target != 0: tr_open = (b.index[i], np.sign(target), eq)
            fill(target, o[i], sp[i])
        # 2) intrabar stop (don/ma)
        if rule in ("don", "ma") and units != 0 and not np.isnan(stop):
            hit = (units > 0 and l[i] <= stop) or (units < 0 and h[i] >= stop)
            if hit:
                px = min(o[i], stop) if units > 0 else max(o[i], stop)
                eq += units * (px - prev); prev = px
                fill(0.0, px, sp[i]); target = 0.0; dirn = 0
                if tr_open is not None: trades.append((tr_open[0], b.index[i], tr_open[1], eq / tr_open[2] - 1)); tr_open = None
                stop = np.nan
        eq += units * (c[i] - prev); prev = c[i]
        if lastofday[i] and units != 0:
            sw = abs(units) * c[i] * (SWL if units > 0 else SWS) / 100 / 365
            wd = pd.Timestamp(day[i]).day_of_week  # server day of the rollover bar
            mult = 3 if wd == 2 else (0 if wd >= 5 else 1)  # triple Wednesday, weekends covered by it
            eq += sw * mult; swap_tot += sw * mult
        eqs[i] = eq
        # 3) signal at close -> target for next open
        v = vol[i]
        if np.isnan(v) or v <= 0 or np.isnan(atr[i]): target = units; continue
        size = min(VT / v, LEVCAP) * eq / c[i]
        if rule == "tsmom":
            d = s_ts[i]
            if lo: d = max(d, 0)
        elif rule == "don":
            d = dirn
            if dirn == 1 and c[i] < loM[i]: d = 0
            if dirn == -1 and c[i] > hiM[i]: d = 0
            if d == 0:
                if c[i] > hiN[i]: d = 1
                elif c[i] < loN[i] and not lo: d = -1
            if d != dirn and d != 0: stop = c[i] - d * 2 * atr[i]
            if d == 0: stop = np.nan
            dirn = d
        elif rule == "ma":
            cross = 1 if f[i] > sl_[i] else -1
            pcross = 1 if f[i - 1] > sl_[i - 1] else -1
            d = dirn
            if np.isnan(sl_[i - 1]): d = 0
            elif cross != pcross or (dirn == 0 and i == 1): d = cross
            elif dirn != 0 and cross != dirn: d = 0
            if lo and d < 0: d = 0
            if d != 0 and d != dirn: extreme = c[i]
            if d != 0:
                extreme = max(extreme, c[i]) if d > 0 else min(extreme, c[i])
                stop = extreme - d * 3 * atr[i]
            else: stop = np.nan
            dirn = d
        tgt = d * size
        if np.sign(tgt) != np.sign(units) or (units != 0 and abs(tgt / units - 1) > REB): target = tgt
        else: target = units
    eqs[0] = 1.0
    e = pd.Series(eqs, index=b.index); e = e.groupby(b.day.values).last()
    T = pd.DataFrame(trades, columns=["entry", "exit", "dir", "ret"])
    return e, T, cost_tot, swap_tot
def bh_daily(e):
    return e.pct_change().fillna(0)
VARS = [("T1", "D1", "tsmom", dict(L=21)), ("T2", "D1", "tsmom", dict(L=63)), ("T3", "D1", "tsmom", dict(L=126)), ("T4", "D1", "tsmom", dict(L=252)),
        ("T5", "D1", "tsmom", dict(L="ens")), ("T6", "D1", "don", dict(N=20, M=10)), ("T7", "D1", "don", dict(N=55, M=20)),
        ("T8", "H4", "don", dict(N=20, M=10)), ("T9", "H4", "don", dict(N=55, M=20)), ("T10", "D1", "ma", dict(F=50, S=200)),
        ("T11", "D1", "ma", dict(F=20, S=100)), ("T12", "H4", "ma", dict(F=50, S=200))]
def metrics(r, T, lo_, hi_):
    x = r[(r.index >= lo_) & (r.index < hi_)]
    if len(x) < 20: return {}
    eqc = (1 + x).cumprod(); yrs = len(x) / 252
    t = x.mean() / x.std() * np.sqrt(len(x)) if x.std() > 0 else 0
    tt = T[(T.entry >= pd.Timestamp(lo_, tz="America/New_York")) & (T.entry < pd.Timestamp(hi_, tz="America/New_York"))]
    pf = tt.ret[tt.ret > 0].sum() / -tt.ret[tt.ret < 0].sum() if (tt.ret < 0).any() else np.inf
    return dict(ret=eqc.iloc[-1] - 1, cagr=eqc.iloc[-1] ** (1 / yrs) - 1, mdd=(1 - eqc / eqc.cummax()).max(), t=t, sharpe=x.mean() / x.std() * np.sqrt(252) if x.std() > 0 else 0,
                ntr=len(tt), pf=pf, wr=(tt.ret > 0).mean() if len(tt) else np.nan)
if __name__ == "__main__":
    rows = []; curves = {}
    for vid, tf, rule, p in VARS:
        for lo in (False, True):
            name = f"{vid}{'LO' if lo else 'LS'}"
            e, T, ct, st = run(tf, rule, p, lo); r = e.pct_change().fillna(0); r.index = pd.DatetimeIndex(r.index)
            curves[name] = r; T.to_csv(f"{OUT}/trend_trades_{name}.csv", index=False)
            IS = metrics(r, T, "2016-01-01", "2025-01-01"); VA = metrics(r, T, "2025-01-01", "2026-01-01")
            ri = r[(r.index >= "2016-01-01") & (r.index < "2025-01-01")]
            yrs = (1 + ri).groupby(ri.index.year).prod() - 1
            Ti = T[(T.entry >= pd.Timestamp("2016-01-01", tz="America/New_York")) & (T.entry < pd.Timestamp("2025-01-01", tz="America/New_York"))]
            k = max(1, int(np.ceil(0.01 * len(Ti))))
            top1_tr = Ti.ret.sort_values().iloc[:-k].sum() if len(Ti) > 1 else np.nan
            kd = int(np.ceil(0.01 * len(ri))); top1_day = ri.sort_values().iloc[:-kd].sum()
            rows.append(dict(id=name, tf=tf, rule=rule, params=str(p), **{f"IS_{a}": b_ for a, b_ in IS.items()}, **{f"VA_{a}": b_ for a, b_ in VA.items()},
                             yrs_pos=int((yrs > 0).sum()), years=" ".join(f"{y}:{v:+.1%}" for y, v in yrs.items()), sum_ex_top1_trades=top1_tr, sum_ex_top1_days=top1_day,
                             cost_total=ct, swap_total=st, p=1 - stats.norm.cdf(IS.get("t", 0))))
            print(name, {k_: round(v, 3) for k_, v in IS.items()}, "VA", round(VA.get("ret", np.nan), 3), "yrs+", int((yrs > 0).sum()), flush=True)
    # buy & hold vol-targeted reference
    pd.DataFrame(rows).to_csv(f"{OUT}/trend_summary{os.environ.get('TAG','')}.csv", index=False)
    pd.DataFrame(curves).to_parquet(f"{OUT}/trend_daily{os.environ.get('TAG','')}.parquet")
