"""Setup families -> signal dicts for engine.run. All causal: decisions use closed bars only."""
import numpy as np, pandas as pd

def tf_bars(D, minutes):
    key = ("tf", minutes)
    if key in D: return D[key]
    idx = D["utc"]
    m = pd.DataFrame(dict(o=D["mo"], h=D["mh"], l=D["ml"], c=D["mc"]), index=idx)
    r = m.resample(f"{minutes}min", label="left", closed="left").agg(dict(o="first", h="max", l="min", c="last")).dropna()
    close_t = r.index + pd.Timedelta(minutes=minutes)
    # first M1 bar at/after bar close = when a signal on this bar becomes actionable
    nxt = np.searchsorted(idx.values, close_t.values)
    r["nxt"] = nxt
    pc = r.c.shift(1)
    tr = np.maximum(r.h - r.l, np.maximum((r.h - pc).abs(), (r.l - pc).abs()))
    r["atr"] = tr.rolling(14).mean()
    ny = r.index.tz_convert("America/New_York")
    r["hm"] = ny.hour * 60 + ny.minute   # NY time of bar START
    r["dow"] = ny.dayofweek
    r["ema50"] = r.c.ewm(span=50, adjust=False).mean()
    r["ema200"] = r.c.ewm(span=200, adjust=False).mean()
    r = r[r.nxt < len(idx)]
    D[key] = r
    return r

SESS = {  # NY local time windows (minutes) of the signal bar
    "LDN": (3 * 60, 7 * 60), "NY": (8 * 60, 12 * 60), "LDNNY": (3 * 60, 12 * 60),
    "ALL": (0, 24 * 60), "ASIA": (19 * 60, 24 * 60 + 2 * 60),
}
def in_sess(hm, s):
    a, b = SESS[s]
    if b > 24 * 60:
        return (hm >= a) | (hm < b - 24 * 60)
    return (hm >= a) & (hm < b)

def pack(nxt, d, otype, price, sl, rr, tpabs=None, expiry=None, maxhold=240):
    n = len(nxt)
    nxt = np.asarray(nxt, np.int64)
    return dict(sig_i=nxt, dir=np.asarray(d, np.int64), otype=np.full(n, otype) if np.isscalar(otype) else np.asarray(otype),
                price=np.broadcast_to(np.asarray(price, float), (n,)).copy(), sl=np.asarray(sl, float), rr=np.full(n, rr, float),
                tpabs=np.full(n, np.nan) if tpabs is None else np.asarray(tpabs, float),
                expiry=nxt if expiry is None else np.asarray(expiry, np.int64), maxhold=np.full(n, maxhold, np.int64))

def cat(*sigs):
    return {k: np.concatenate([s[k] for s in sigs]) for k in sigs[0]}

def _m1_offset(D, nxt, minutes):
    return np.minimum(nxt + minutes, len(D["utc"]) - 1)

# ---------------- F1 liquidity sweep + rejection (market entry next bar)
def f1_sweep(D, tf, N, sess, rr, sides="both"):
    r = tf_bars(D, tf)
    ph = r.h.shift(1).rolling(N).max(); pl = r.l.shift(1).rolling(N).min()
    ok = in_sess(r.hm, sess) & r.atr.notna()
    bull = ok & (r.l < pl) & (r.c > pl) & (r.c > r.o)      # swept lows, closed back above, bullish body
    bear = ok & (r.h > ph) & (r.c < ph) & (r.c < r.o)
    buf = 0.1 * r.atr
    S = []
    if sides in ("both", "long"):
        x = r[bull]; S.append(pack(x.nxt, np.ones(len(x)), 0, np.nan, x.l - buf[bull], rr, maxhold=tf * 24))
    if sides in ("both", "short"):
        x = r[bear]; S.append(pack(x.nxt, -np.ones(len(x)), 0, np.nan, x.h + buf[bear], rr, maxhold=tf * 24))
    return cat(*S)

# ---------------- F2 FVG retrace (limit)
def f2_fvg(D, tf, gapk, entry, slmode, trend, sess, rr):
    r = tf_bars(D, tf)
    h1 = r.h.shift(2); l1 = r.l.shift(2)
    ok = in_sess(r.hm, sess) & r.atr.notna()
    if trend == "ema":
        up = r.c > r.ema50; dn = r.c < r.ema50
    else:
        up = dn = pd.Series(True, index=r.index)
    bull = ok & up & ((r.l - h1) > gapk * r.atr)
    bear = ok & dn & ((l1 - r.h) > gapk * r.atr)
    S = []
    exp_bars = 12 * tf
    x = r[bull]
    top, bot = x.l, h1[bull]
    lim = top if entry == "edge" else (top + bot) / 2
    sl = (bot - 0.1 * x.atr) if slmode == "gap" else (l1[bull] - 0.1 * x.atr)
    S.append(pack(x.nxt, np.ones(len(x)), 1, lim, sl, rr, expiry=_m1_offset(D, x.nxt.values, exp_bars), maxhold=tf * 24))
    x = r[bear]
    bot, top = x.h, l1[bear]
    lim = bot if entry == "edge" else (top + bot) / 2
    sl = (top + 0.1 * x.atr) if slmode == "gap" else (h1[bear] + 0.1 * x.atr)
    S.append(pack(x.nxt, -np.ones(len(x)), 1, lim, sl, rr, expiry=_m1_offset(D, x.nxt.values, exp_bars), maxhold=tf * 24))
    return cat(*S)

# ---------------- F3 break + retest (limit at broken level)
def f3_bretest(D, tf, N, slk, sess, rr):
    r = tf_bars(D, tf)
    ph = r.h.shift(1).rolling(N).max(); pl = r.l.shift(1).rolling(N).min()
    ok = in_sess(r.hm, sess) & r.atr.notna()
    bull = ok & (r.c > ph) & (r.c.shift(1) <= ph.shift(1))
    bear = ok & (r.c < pl) & (r.c.shift(1) >= pl.shift(1))
    S = []
    x = r[bull]; lv = ph[bull]
    S.append(pack(x.nxt, np.ones(len(x)), 1, lv, lv - slk * x.atr, rr, expiry=_m1_offset(D, x.nxt.values, 12 * tf), maxhold=tf * 24))
    x = r[bear]; lv = pl[bear]
    S.append(pack(x.nxt, -np.ones(len(x)), 1, lv, lv + slk * x.atr, rr, expiry=_m1_offset(D, x.nxt.values, 12 * tf), maxhold=tf * 24))
    return cat(*S)

# ---------------- helpers for daily ranges on M1
def _daily_range(D, a_hm, b_hm):
    """Range of mid prices in NY window [a,b) (a may be > b => crosses midnight, belongs to next trading day)."""
    hm = D["hm"]; td = D["tday"]
    if a_hm < b_hm: m = (hm >= a_hm) & (hm < b_hm)
    else: m = (hm >= a_hm) | (hm < b_hm)
    df = pd.DataFrame(dict(td=td[m], h=D["mh"][m], l=D["ml"][m], i=np.nonzero(m)[0]))
    g = df.groupby("td").agg(h=("h", "max"), l=("l", "min"), last=("i", "max"), cnt=("i", "size"))
    return g

def _first_break(D, start_i, end_i, hi, lo):
    """first M1 index in [start,end] where mid high>hi (dir+1) or mid low<lo (dir-1); both same bar -> skip."""
    mh, ml = D["mh"], D["ml"]
    res_i = []; res_d = []
    for s, e, H, L in zip(start_i, end_i, hi, lo):
        if s >= e: res_i.append(-1); res_d.append(0); continue
        up = np.nonzero(mh[s:e] > H)[0]; dn = np.nonzero(ml[s:e] < L)[0]
        u = up[0] if len(up) else 10**9; d_ = dn[0] if len(dn) else 10**9
        if u == d_: res_i.append(-1); res_d.append(0)
        elif u < d_: res_i.append(s + u); res_d.append(1)
        else: res_i.append(s + d_); res_d.append(-1)
    return np.array(res_i), np.array(res_d)

def _window_end(D, start_i, minutes_until_hm):
    hm = D["hm"]; n = len(hm); out = []
    for s in start_i:
        e = s
        while e < n and e - s < 1440 and hm[e] != minutes_until_hm and not (D["flat"][e]):
            e += 1
        out.append(e)
    return np.array(out)

# ---------------- F4 Asian range: breakout or fade into London/NY
def f4_asia(D, mode, slmode, rr, maxw=None):
    g = _daily_range(D, 19 * 60, 2 * 60)   # 19:00-02:00 NY
    g = g[g.cnt > 300]
    start = g["last"].values + 1
    end = _window_end(D, start, 10 * 60)   # trade window until 10:00 NY
    H, L = g.h.values, g.l.values; W = H - L
    bi, bd = _first_break(D, start, end, H + 0.0, L - 0.0)
    keep = bi >= 0
    if maxw is not None: keep &= W <= maxw
    bi, bd, H, L, W, end = bi[keep], bd[keep], H[keep], L[keep], W[keep], end[keep]
    if mode == "breakout":
        lvl = np.where(bd == 1, H + 0.10, L - 0.10)
        if slmode == "mid": sl = (H + L) / 2
        elif slmode == "opp": sl = np.where(bd == 1, L, H)
        else: sl = lvl - bd * 0.25 * W   # quarter range
        return pack(bi, bd, 2, lvl, sl, rr, expiry=bi, maxhold=8 * 60)
    else:  # fade: after sweep, wait for M5 close back inside range -> market entry, SL beyond extreme since sweep
        r = tf_bars(D, 5); rt = r.nxt.values  # M1 index after each M5 close
        sig_i, dd, sls = [], [], []
        mh, ml = D["mh"], D["ml"]
        for b, d_, h_, l_, e in zip(bi, bd, H, L, end):
            k0 = np.searchsorted(rt, b + 1)
            for k in range(k0, min(k0 + 24, len(r))):
                if rt[k] > e: break
                c = r.c.values[k]
                if (d_ == 1 and c < h_) or (d_ == -1 and c > l_):
                    seg = slice(b, rt[k])
                    ext = mh[seg].max() if d_ == 1 else ml[seg].min()
                    sig_i.append(rt[k]); dd.append(-d_); sls.append(ext + 0.10 * d_)
                    break
        return pack(sig_i, dd, 0, np.full(len(sig_i), np.nan), sls, rr, maxhold=8 * 60)

# ---------------- F5 Opening range breakout (London 03:00 / NY 09:30 NY time)
def f5_orb(D, sess, rng, slmode, rr):
    a = 3 * 60 if sess == "LDN" else 9 * 60 + 30
    g = _daily_range(D, a, a + rng)
    g = g[g.cnt >= rng * 0.8]
    start = g["last"].values + 1
    end = np.minimum(start + 180, len(D["hm"]) - 1)  # 3h window
    H, L = g.h.values, g.l.values
    bi, bd = _first_break(D, start, end, H, L)
    k = bi >= 0; bi, bd, H, L = bi[k], bd[k], H[k], L[k]
    lvl = np.where(bd == 1, H + 0.10, L - 0.10)
    sl = (H + L) / 2 if slmode == "mid" else np.where(bd == 1, L, H)
    return pack(bi, bd, 2, lvl, sl, rr, expiry=bi, maxhold=6 * 60)

# ---------------- F6 session momentum / fade at fixed time
def f6_tmom(D, t_hm, k, mode, rr, slk=1.0):
    r = tf_bars(D, 15)
    # move from London open (03:00 NY) to decision time
    hm = D["hm"]
    a_i = np.nonzero(hm == 3 * 60)[0]; t_i = np.nonzero(hm == t_hm)[0]
    td = D["tday"]
    A = pd.Series(D["mo"][a_i], index=td[a_i]); T = pd.Series(t_i, index=td[t_i])
    A = A[~A.index.duplicated()]; T = T[~T.index.duplicated()]
    j = A.index.intersection(T.index)
    ti = T[j].values; mv = D["mo"][ti] - A[j].values
    atr = r.atr.values[np.searchsorted(r.nxt.values, ti, side="right") - 1]
    sel = np.abs(mv) > k * atr * 4
    ti, mv, atr = ti[sel], mv[sel], atr[sel]
    d = np.sign(mv).astype(int) * (1 if mode == "cont" else -1)
    sl = D["mo"][ti] - d * slk * atr
    return pack(ti, d, 0, np.nan, sl, rr, maxhold=6 * 60)

# ---------------- F7 Bollinger band reversion (close back inside)
def f7_bb(D, tf, kstd, sess, tgt):
    r = tf_bars(D, tf)
    m = r.c.rolling(20).mean(); s = r.c.rolling(20).std()
    up, lo = m + kstd * s, m - kstd * s
    ok = in_sess(r.hm, sess) & r.atr.notna()
    bull = ok & (r.l.shift(1) < lo.shift(1)) & (r.c.shift(1) < lo.shift(1)) & (r.c > lo)
    bear = ok & (r.h.shift(1) > up.shift(1)) & (r.c.shift(1) > up.shift(1)) & (r.c < up)
    S = []
    for msk, d in ((bull, 1), (bear, -1)):
        x = r[msk]
        ext = np.minimum(x.l, r.l.shift(1)[msk]) if d == 1 else np.maximum(x.h, r.h.shift(1)[msk])
        sl = ext - d * 0.2 * x.atr
        if tgt == "mid":
            S.append(pack(x.nxt, np.full(len(x), d), 0, np.nan, sl, 0.0, tpabs=m[msk].values, maxhold=tf * 24))
        else:
            S.append(pack(x.nxt, np.full(len(x), d), 0, np.nan, sl, float(tgt), maxhold=tf * 24))
    return cat(*S)

# ---------------- F8 sweep -> CHoCH -> retrace entry (OB-like)
def f8_choch(D, tf, N, retr, sess, rr, W=12):
    r = tf_bars(D, tf)
    o, h, l, c = r.o.values, r.h.values, r.l.values, r.c.values
    ph = r.h.shift(1).rolling(N).max().values; pl = r.l.shift(1).rolling(N).min().values
    ok = in_sess(r.hm, sess).values & r.atr.notna().values
    nxt = r.nxt.values; atr = r.atr.values
    sig_i, dd, lim, sls, exp = [], [], [], [], []
    n = len(r); i = N + 2
    while i < n - 1:
        if ok[i] and l[i] < pl[i]:   # sweep low -> look for bullish CHoCH: close above highest high of the 3 bars before the sweep
            sw = l[i]; ref = h[max(0, i - 3):i + 1].max()
            for j in range(i + 1, min(n, i + W)):
                sw = min(sw, l[j])
                if c[j] > ref:
                    entry = c[j] - retr * (c[j] - sw)
                    sig_i.append(nxt[j]); dd.append(1); lim.append(entry); sls.append(sw - 0.1 * atr[j]); exp.append(nxt[j] + 12 * tf)
                    i = j; break
        elif ok[i] and h[i] > ph[i]:
            sw = h[i]; ref = l[max(0, i - 3):i + 1].min()
            for j in range(i + 1, min(n, i + W)):
                sw = max(sw, h[j])
                if c[j] < ref:
                    entry = c[j] + retr * (sw - c[j])
                    sig_i.append(nxt[j]); dd.append(-1); lim.append(entry); sls.append(sw + 0.1 * atr[j]); exp.append(nxt[j] + 12 * tf)
                    i = j; break
        i += 1
    exp = np.minimum(np.array(exp, dtype=np.int64), len(D["utc"]) - 1)
    return pack(sig_i, dd, 1, lim, sls, rr, expiry=exp, maxhold=tf * 24)

# ---------------- baseline: random direction, ATR stop, at random M15 closes in LDN/NY
def f0_random(D, rr, seed=0, slk=1.0):
    r = tf_bars(D, 15)
    x = r[in_sess(r.hm, "LDNNY") & r.atr.notna()]
    rng = np.random.default_rng(seed)
    x = x[rng.random(len(x)) < 0.15]
    d = rng.choice([-1, 1], len(x))
    return pack(x.nxt, d, 0, np.nan, x.c.values - d * slk * x.atr.values, rr, maxhold=15 * 24)

# ---------------- F9 time-of-day drift (fixed-time entry, time exit, ATR protective stop)
def f9_tod(D, d, entry_hm, hold, slk):
    r = tf_bars(D, 15)
    ti = np.nonzero((D["hm"] == entry_hm) & (D["dow"] != 5))[0]
    atr = r.atr.values[np.searchsorted(r.nxt.values, ti, side="right") - 1]
    k = ~np.isnan(atr); ti, atr = ti[k], atr[k]
    sl = D["mo"][ti] - d * slk * atr
    return pack(ti, np.full(len(ti), d), 0, np.nan, sl, 100.0, maxhold=hold)
