"""Vitor's top-down SMC/ICT model, encoded objectively (causal) and simulated on M1 bid/ask with engine.simulate.
Layers:
 1 Bias  : H4 or D1 market structure (fractal 2L/2R swings, confirmed 2 bars later). BOS up (close > last swing high) => +1,
           BOS down => -1. Premium/discount: dealing range = last confirmed swing high/low of that TF; longs only below 50%.
 2 POI   : optional — sweep extreme must sit inside/near an unfilled H1 FVG of the bias direction (last 24 H1 bars).
 3 AMD   : Asian range 19:00-00:00 NY = accumulation. Manipulation = sweep of Asian low/high (or prev-day low/high) inside a
           kill zone (London 02:00-05:00 NY, New York 08:00-11:00 NY). Distribution = the trade.
 4 Trigger (M5): after the sweep, CHoCH = M5 close beyond the last M5 fractal swing (opposite side) within 24 bars.
           Entry: limit at proximal edge of the latest FVG in the displacement leg ('fvg'), or at the open of the last
           opposite candle = order block ('ob'), or market at next bar ('mkt'). Limit valid 12 M5 bars.
 5 Risk  : SL beyond sweep extreme + 0.1*ATR(M5). TP = 2R, 3R, or opposite liquidity (Asian high/low), min 1.5R.
 One trade per kill zone per day. Forced flat 16:50 NY (engine).
"""
import sys, glob, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code"); import engine as E
COST = {"xauusd": (0.07, 0.05, 0.5, 0.20), "eurusd": (0.00007, 0.00002, 1.0, 0.0), "gbpusd": (0.00007, 0.00002, 1.0, 0.0),
        "usatechidxusd": (0.0, 0.5, 1.0, 0.0), "usa500idxusd": (0.0, 0.1, 1.0, 0.0)}   # comm, slip, spread scale, spread floor

def load_m1(sym):
    def rd(side):
        fs = sorted(glob.glob(f"/workspace/alien-research/data/m1/{sym}_{side}_*.csv"))
        if sym == "xauusd": fs += sorted(glob.glob(f"/workspace/alien-research/data/raw/xau_{side}_*.csv"))
        d = pd.concat([pd.read_csv(f) for f in fs]).drop_duplicates("timestamp").set_index("timestamp").sort_index()
        return d
    b, a = rd("bid"), rd("ask"); j = b.join(a, lsuffix="_b", rsuffix="_a", how="inner")
    # drop Dukascopy "flat" filler bars (market closed: weekends/holidays/index breaks): no movement on bid AND ask
    stale = (j.high_b == j.low_b) & (j.high_a == j.low_a) & (j.close_b == j.close_b.shift(1)) & (j.close_a == j.close_a.shift(1))
    j = j[~stale.values]
    j = j[~((j.high_b == j.low_b) & (j.open_b == j.close_b) & (j.index.to_series().diff() > 60000).values)] if False else j
    comm, slip, scale, floor = COST[sym]
    mid = {c: (j[c + "_b"].values + j[c + "_a"].values) / 2 for c in ("open", "high", "low", "close")}
    sp = np.maximum(floor, scale * (j.close_a.values - j.close_b.values))
    utc = pd.to_datetime(j.index, unit="ms", utc=True); ny = utc.tz_convert("America/New_York")
    hm = ny.hour * 60 + ny.minute
    D = dict(utc=utc, ny=ny, hm=np.asarray(hm), dow=np.asarray(ny.dayofweek),
             mo=mid["open"], mh=mid["high"], ml=mid["low"], mc=mid["close"],
             flat=np.asarray(((hm >= 16 * 60 + 50) & (hm < 18 * 60)) | (ny.dayofweek == 5)))
    for k, m in (("o", "open"), ("h", "high"), ("l", "low"), ("c", "close")):
        D["b" + k] = mid[m] - sp / 2; D["a" + k] = mid[m] + sp / 2
    D["tday"] = np.asarray((ny - pd.Timedelta(hours=18)).normalize().tz_localize(None).values.astype("datetime64[D]").astype(np.int64))
    D["sym"] = sym; D["comm"] = comm; D["slip"] = slip
    return D

def bars(D, rule, shift_h=0):
    m = pd.DataFrame(dict(o=D["mo"], h=D["mh"], l=D["ml"], c=D["mc"]), index=D["ny"] + pd.Timedelta(hours=shift_h))
    r = m.resample(rule, label="left", closed="left").agg(dict(o="first", h="max", l="min", c="last")).dropna()
    step = pd.Timedelta(rule)
    r["close_t"] = r.index - pd.Timedelta(hours=shift_h) + step     # NY tz-aware close time
    pc = r.c.shift(1); tr = np.maximum(r.h - r.l, np.maximum((r.h - pc).abs(), (r.l - pc).abs())); r["atr"] = tr.rolling(14).mean()
    return r

def structure(r):
    """fractal swings confirmed 2 bars later; returns per-bar (at close) trend, last swing high, last swing low."""
    h, l, c = r.h.values, r.l.values, r.c.values; n = len(r)
    tr = np.zeros(n); sh = np.full(n, np.nan); sl = np.full(n, np.nan)
    lsh = np.nan; lsl = np.nan; t = 0
    for i in range(n):
        k = i - 2
        if k >= 2:
            if h[k] > h[k-1] and h[k] > h[k-2] and h[k] >= h[k+1] and h[k] >= h[k+2]: lsh = h[k]
            if l[k] < l[k-1] and l[k] < l[k-2] and l[k] <= l[k+1] and l[k] <= l[k+2]: lsl = l[k]
        if lsh == lsh and c[i] > lsh: t = 1
        elif lsl == lsl and c[i] < lsl: t = -1
        tr[i] = t; sh[i] = lsh; sl[i] = lsl
    return pd.DataFrame(dict(trend=tr, sh=sh, sl=sl), index=r.close_t.values)

def prepare(D):
    P = {}
    m5 = bars(D, "5min"); P["m5"] = m5
    P["nxt5"] = np.searchsorted(D["ny"].values, m5.close_t.values)       # M1 index where M5 bar is actionable
    for tf, rule in (("H4", "4h"), ("D1", "1D")):
        P[tf] = structure(bars(D, rule, shift_h=7))
    h1 = bars(D, "1h"); P["h1"] = h1
    # asian range & prior day per trading day (tday of the M1 bar)
    hm, td = D["hm"], D["tday"]
    asia = (hm >= 19 * 60)
    g = pd.DataFrame(dict(td=td, h=D["mh"], l=D["ml"]))[asia]   # 19:00-24:00 NY shares tday with next morning
    P["asia"] = g.groupby("td").agg(h=("h", "max"), l=("l", "min"))
    dd = pd.DataFrame(dict(td=td, h=D["mh"], l=D["ml"])).groupby("td").agg(h=("h", "max"), l=("l", "min"))
    P["pd"] = dd.shift(1)   # previous trading day (by row; ok for weekdays)
    return P

def _asof(df, times):
    idx = np.searchsorted(df.index.values, times, side="right") - 1
    return idx

def signals(D, P, bias_tf="H4", pd_filter=True, pool="asia", poi="none", entry="fvg", tp="2R", zones=("LDN", "NY")):
    m5 = P["m5"]; o, h, l, c = (m5[k].values for k in "ohlc"); atr = m5.atr.values; ct = m5.close_t.values
    ny5 = m5.index; hm5 = (ny5.hour * 60 + ny5.minute).values
    td5 = D["tday"][np.minimum(P["nxt5"], len(D["tday"]) - 1)]
    # actually tday of the bar itself:
    td5 = np.asarray((ny5 - pd.Timedelta(hours=18)).normalize().tz_localize(None).values.astype("datetime64[D]").astype(np.int64))
    S = P[bias_tf]; bi = _asof(S, ct); trend = np.where(bi >= 0, S.trend.values[bi], 0)
    rsh = np.where(bi >= 0, S.sh.values[bi], np.nan); rsl = np.where(bi >= 0, S.sl.values[bi], np.nan)
    A = P["asia"]; PD = P["pd"]
    ah = A.h.reindex(td5).values; al = A.l.reindex(td5).values
    ph = PD.h.reindex(td5).values; pl = PD.l.reindex(td5).values
    if pool == "asia": lowlvl, hilvl = al, ah
    else: lowlvl, hilvl = np.fmin(al, pl), np.fmax(ah, ph)   # deeper pool: sweep must take the lower of the two? -> use Asia OR PDL
    if pool == "asia_or_pdl": lowlvl, hilvl = np.fmax(al, pl), np.fmin(ah, ph)   # first of the two to be taken
    KZ = {"LDN": (2 * 60, 5 * 60), "NY": (8 * 60, 11 * 60)}
    h1 = P["h1"]; h1h, h1l, h1ct, h1atr = h1.h.values, h1.l.values, h1.close_t.values, h1.atr.values
    out = dict(sig_i=[], dir=[], otype=[], price=[], sl=[], rr=[], tpabs=[], expiry=[], maxhold=[])
    n5 = len(m5); nM1 = len(D["utc"])
    # fractal highs/lows on M5 confirmed 2 bars later
    fh = np.zeros(n5, bool); fl = np.zeros(n5, bool)
    fh[2:-2] = (h[2:-2] > h[1:-3]) & (h[2:-2] > h[:-4]) & (h[2:-2] >= h[3:-1]) & (h[2:-2] >= h[4:])
    fl[2:-2] = (l[2:-2] < l[1:-3]) & (l[2:-2] < l[:-4]) & (l[2:-2] <= l[3:-1]) & (l[2:-2] <= l[4:])
    used = set()
    for s in range(20, n5 - 30):
        z = None
        for name in zones:
            a_, b_ = KZ[name]
            if a_ <= hm5[s] < b_: z = name
        if z is None or (td5[s], z) in used or not np.isfinite(atr[s]): continue
        for d in (1, -1):
            if trend[s] != d: continue
            lvl = lowlvl[s] if d == 1 else hilvl[s]
            if not np.isfinite(lvl): continue
            swept = (l[s] < lvl) if d == 1 else (h[s] > lvl)
            if not swept: continue
            if pd_filter:
                if not (np.isfinite(rsh[s]) and np.isfinite(rsl[s]) and rsh[s] > rsl[s]): continue
                mid = (rsh[s] + rsl[s]) / 2
                if (d == 1 and c[s] > mid) or (d == -1 and c[s] < mid): continue
            # CHoCH: close beyond last confirmed M5 fractal (opposite side) formed before s
            ref = np.nan
            for k in range(s - 3, max(s - 60, 2), -1):
                if (d == 1 and fh[k]) or (d == -1 and fl[k]): ref = h[k] if d == 1 else l[k]; break
            if not np.isfinite(ref): continue
            ext = l[s] if d == 1 else h[s]; j_ch = -1
            for j in range(s + 1, min(s + 25, n5)):
                ext = min(ext, l[j]) if d == 1 else max(ext, h[j])
                if (d == 1 and c[j] > ref) or (d == -1 and c[j] < ref): j_ch = j; break
            if j_ch < 0: continue
            used.add((td5[s], z))
            if poi == "h1fvg":
                kk = np.searchsorted(h1ct, ct[s], side="right") - 1; okp = False
                for q in range(kk, max(kk - 24, 2), -1):
                    if d == 1 and h1l[q] > h1h[q-2]:
                        bot, top = h1h[q-2], h1l[q]
                        if ext <= top and ext >= bot - 0.5 * h1atr[q]: okp = True; break
                    if d == -1 and h1h[q] < h1l[q-2]:
                        top, bot = h1l[q-2], h1h[q]
                        if ext >= bot and ext <= top + 0.5 * h1atr[q]: okp = True; break
                if not okp: break
            sl_ = ext - d * 0.1 * atr[j_ch]
            if entry == "mkt":
                ot, px = 0, np.nan
            elif entry == "fvg":
                px = np.nan
                for x in range(j_ch, s + 1, -1):
                    if d == 1 and l[x] > h[x-2]: px = l[x]; break
                    if d == -1 and h[x] < l[x-2]: px = h[x]; break
                if not np.isfinite(px): break
                ot = 1
            else:  # ob: last opposite candle in [s, j_ch)
                px = np.nan
                for x in range(j_ch - 1, s - 1, -1):
                    if d == 1 and c[x] < o[x]: px = o[x]; break
                    if d == -1 and c[x] > o[x]: px = o[x]; break
                if not np.isfinite(px): break
                ot = 1
            ref_px = c[j_ch] if ot == 0 else px
            dist = (ref_px - sl_) * d
            if dist <= 0: break
            if tp == "liq":
                tgt = ah[s] if d == 1 else al[s]
                if not np.isfinite(tgt) or (tgt - ref_px) * d < 1.5 * dist: break
                rr, tpa = 0.0, tgt
            else:
                rr, tpa = float(tp[0]), np.nan
            i1 = P["nxt5"][j_ch]
            if i1 >= nM1: break
            out["sig_i"].append(i1); out["dir"].append(d); out["otype"].append(ot); out["price"].append(px); out["sl"].append(sl_)
            out["rr"].append(rr); out["tpabs"].append(tpa); out["expiry"].append(min(i1 + 60, nM1 - 1)); out["maxhold"].append(8 * 60)
            break
    return {k: np.asarray(v) for k, v in out.items()}

def run(D, sig):
    E.COMM, E.SLIP = D["comm"], D["slip"]; E.MAX_STOP = 1e12; E.MIN_STOP = 0.0
    if len(sig["sig_i"]) == 0: return pd.DataFrame(columns=["R", "time", "dir", "reason"])
    return E.run(D, sig)
