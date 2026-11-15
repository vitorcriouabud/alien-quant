import numpy as np, pandas as pd, sys
sys.path.insert(0, "/workspace/alien-research/code/tiro"); sys.path.insert(0, "/workspace/alien-research/code/v2")
from data import *
import engine2 as E

def rec(sym, fam, et, xt, d, fp, pts, r1, worst):
    return dict(sym=sym, fam=fam, entry=et, exit=xt, dir=d, fp=fp, pts=pts, r1=r1, worst=min(worst, pts))

def walk(o, h, l, c, j0, jend, d, fp, st, tp, same_bar_tp=False, trail=None):
    """walk bars j0..jend (inclusive). entry filled inside bar j0. returns (exit_px, exit_idx, worst_adverse_px_move(neg))."""
    worst = 0.0
    for m in range(j0, jend + 1):
        if m > j0 and (o[m] - st) * d <= 0:        # gap through stop
            worst = min(worst, (o[m] - fp) * d); return o[m], m, worst
        adv = (l[m] - fp) if d == 1 else (fp - h[m])
        if (l[m] <= st) if d == 1 else (h[m] >= st):
            worst = min(worst, (st - fp) * d); return st, m, worst
        worst = min(worst, adv)
        if tp is not None and (m > j0 or same_bar_tp):
            if (h[m] >= tp) if d == 1 else (l[m] <= tp):
                return (max(tp, o[m]) if d == 1 else min(tp, o[m])) if m > j0 else tp, m, worst
        if trail is not None: st = trail(m, st)
    return c[jend], jend, worst

# ---------------- A: ORB ----------------
def orb(sym, df, or_min=30, rr=10.0, mid_stop=False, nr7=False, start="09:30", last_entry="12:00", flat="15:55", ctrl=False, seed=0):
    rng = np.random.default_rng(seed)
    t = df.index; o, h, l, c = (df[x].values for x in ("open", "high", "low", "close"))
    mins = t.hour * 60 + t.minute; dates = t.normalize()
    sh, sm = map(int, start.split(":")); s0 = sh * 60 + sm; s1 = s0 + or_min
    le = int(last_entry[:2]) * 60 + int(last_entry[3:]); fl = int(flat[:2]) * 60 + int(flat[3:])
    cost = SP[sym] + 2 * SLIP[sym]
    # daily ranges for NR7
    dr = pd.DataFrame(dict(h=h, l=l, d=dates)).groupby("d").agg(h=("h", "max"), l=("l", "min")); rg = dr.h - dr.l
    isnr7 = (rg < rg.rolling(7).min().shift(1)) if nr7 else None
    out = []
    bounds = np.r_[0, np.nonzero(dates[1:] != dates[:-1])[0] + 1, len(t)]
    prevday = None
    for a, b in zip(bounds[:-1], bounds[1:]):
        day = dates[a]
        if nr7:
            if prevday is None or not bool(isnr7.get(prevday, False)): prevday = day; continue
        prevday = day
        mm = mins[a:b]
        orb_i = np.nonzero((mm >= s0) & (mm < s1))[0] + a
        if len(orb_i) < or_min // 5 - 1: continue
        H = h[orb_i].max(); L = l[orb_i].min(); W = H - L
        if W <= 0: continue
        win = np.nonzero((mm >= s1) & (mm < fl))[0] + a
        if len(win) < 5: continue
        jend = win[-1]
        if ctrl:
            j = win[0]; d = 1 if rng.random() < 0.5 else -1; fp = o[j]; dist = W / 2 if mid_stop else W
        else:
            j = None
            for m in win:
                if mins[m] >= le: break
                up = h[m] >= H; dn = l[m] <= L
                if up or dn:
                    j = m; d = 1 if up and not dn else (-1 if dn and not up else (1 if abs(o[m] - H) < abs(o[m] - L) else -1)); break
            if j is None: continue
            lvl = H if d == 1 else L
            fp = max(lvl, o[j]) if d == 1 else min(lvl, o[j])
            dist = (fp - (H + L) / 2) * d if mid_stop else (fp - L if d == 1 else H - fp)
            if dist <= 0: continue
        st = fp - d * dist; r1 = dist + cost
        tp = fp + d * rr * r1 if rr else None
        ex, xi, worst = walk(o, h, l, c, j, jend, d, fp, st, tp)
        out.append(rec(sym, "", t[j], t[xi], d, fp, (ex - fp) * d - cost, r1, worst - cost))
    return pd.DataFrame(out)

# ---------------- daily (B, C) on D1 built from H1 ----------------
_D1 = {}
def d1(sym):
    if sym not in _D1:
        r = E.resample(E.load_h1(sym), "D1"); _D1[sym] = r[r.index >= "2015-01-01"]
    return _D1[sym]

def daily_sim(sym, ent, stopk, rr, maxbars, trailk=0.0, be_after=None, label=""):
    r = d1(sym); o, h, l, c, atr = (r[x].values for x in ("open", "high", "low", "close", "atr")); t = r.index
    cost = SP[sym] + 2 * SLIP[sym]; swl, sws = SWAP[sym]
    out = []; i = 0; n = len(r)
    while i < n - 1:
        d = ent[i]
        if d == 0 or not np.isfinite(atr[i]): i += 1; continue
        j = i + 1; fp = o[j]; dist = stopk * atr[i]; st = fp - d * dist; r1 = dist + cost
        tp = fp + d * rr * r1 if rr else None
        jend = min(n - 1, j + maxbars - 1)
        armed = [be_after is None]
        def trail(m, st):
            if trailk <= 0: return st
            if not armed[0] and (c[m] - fp) * d >= be_after * r1:
                armed[0] = True; st = max(st, fp) if d == 1 else min(st, fp)
            if armed[0]:
                st = max(st, c[m] - trailk * atr[m]) if d == 1 else min(st, c[m] + trailk * atr[m])
            return st
        ex, xi, worst = walk(o, h, l, c, j, jend, d, fp, st, tp, trail=trail)
        days = (t[xi] - t[j]).total_seconds() / 86400.0
        rate = (swl if d == 1 else sws) / 100 / 365 * fp
        sw = rate * days
        # path-wise floating: adverse excursion of bar m (capped at stop/exit) + swap accrued until m
        mm = np.arange(j, xi + 1); adv = ((l[mm] - fp) if d == 1 else (fp - h[mm]))
        adv = np.maximum(adv, min((ex - fp) * d, worst)); adv[-1] = min(adv[-1], (ex - fp) * d) if True else adv[-1]
        adv = np.maximum(adv, worst)
        swm = rate * np.array([(t[m] - t[j]).total_seconds() / 86400.0 for m in mm])
        wpath = (adv - cost + np.minimum(swm, 0)).min()
        out.append(rec(sym, label, t[j], t[xi], d, fp, (ex - fp) * d - cost + sw, r1, min(wpath, (ex - fp) * d - cost + min(sw, 0))))
        i = xi   # next signal can be the exit bar's close -> entry next open
    return pd.DataFrame(out)

def rsi(cl, n=2):
    dd = cl.diff(); up = dd.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean(); dn = (-dd.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    return 100 - 100 / (1 + up / dn)

def sig_rexp(sym, long_only=False):
    r = d1(sym); rg = r.high - r.low; pos = (r.close - r.low) / rg.replace(0, np.nan)
    big = rg >= 1.5 * r.atr
    e = np.where(big & (pos >= 0.8), 1, np.where(big & (pos <= 0.2) & (not long_only), -1, 0)); return e

def sig_rsi2(sym):
    r = d1(sym); x = rsi(r.close); return np.where((x < 10) & (r.close > r.close.rolling(200).mean()), 1, 0)

# ---------------- D: gold PDH/PDL breakout ----------------
def gold_pd(g, rr=None, hold_days=1, trail_atr=0.0, long_only=False, ctrl=False, seed=0):
    rng = np.random.default_rng(seed)
    t = g.index; o, h, l, c, sp = (g[x].values for x in ("open", "high", "low", "close", "sp"))
    sess = (t + pd.Timedelta(hours=6)).normalize()        # 18:00 NY -> next date
    mins = t.hour * 60 + t.minute
    insess = ~((mins >= 16 * 60 + 45) & (mins < 18 * 60))
    S = pd.DataFrame(dict(h=h, l=l, c=c, s=sess, ok=insess))
    S = S[S.ok].groupby("s").agg(h=("h", "max"), l=("l", "min"), c=("c", "last"))
    pc = S.c.shift(1); tr = np.maximum(S.h - S.l, np.maximum((S.h - pc).abs(), (S.l - pc).abs())); S["atr"] = tr.rolling(20).mean()
    sdates = S.index; spos = {d: k for k, d in enumerate(sdates)}
    # bar index ranges by session
    keys = np.asarray(sess.asi8); bounds = np.r_[0, np.nonzero(keys[1:] != keys[:-1])[0] + 1, len(t)]
    sb = {sess[a]: (a, b) for a, b in zip(bounds[:-1], bounds[1:])}
    cost_f = COMM["xauusd"] + 2 * SLIP["xauusd"]
    out = []; busy_until = None
    for k in range(21, len(sdates)):
        day = sdates[k]
        if day not in sb: continue
        if busy_until is not None and t[sb[day][0]] <= busy_until: continue
        PH, PL, A = S.h.iloc[k - 1], S.l.iloc[k - 1], S.atr.iloc[k - 1]
        if not np.isfinite(A): continue
        a, b = sb[day]; mm = mins[a:b]
        win = np.nonzero((mm >= 180) & (mm < 720))[0] + a
        if len(win) == 0: continue
        if ctrl:
            j = win[0]; d = 1 if rng.random() < 0.5 else -1; fp = o[j]
        else:
            j = None
            for m in win:
                up = h[m] >= PH + 0.05; dn = l[m] <= PL - 0.05
                if up or dn:
                    if up and dn: break
                    j = m; d = 1 if up else -1; break
            if j is None: continue
            if long_only and d == -1: continue
            lvl = PH + 0.05 if d == 1 else PL - 0.05
            fp = max(lvl, o[j]) if d == 1 else min(lvl, o[j])
        dist = 0.5 * A; cost = sp[j] + cost_f; st = fp - d * dist; r1 = dist + cost
        tp = fp + d * rr * r1 if rr else None
        last_s = sdates[min(k + hold_days - 1, len(sdates) - 1)]
        aa, bb = sb.get(last_s, (a, b)); idx_e = np.nonzero(insess[aa:bb])[0]
        jend = aa + idx_e[-1] if len(idx_e) else b - 1
        sess_last = {}
        if trail_atr > 0:   # session-close trailing: index of last in-session bar per session
            for kk in range(k, min(k + hold_days, len(sdates))):
                s_ = sdates[kk]
                if s_ in sb:
                    a2, b2 = sb[s_]; ie = np.nonzero(insess[a2:b2])[0]
                    if len(ie): sess_last[a2 + ie[-1]] = S.atr.iloc[kk]
        def trail(m, st):
            if m in sess_last: return max(st, c[m] - trail_atr * sess_last[m]) if d == 1 else min(st, c[m] + trail_atr * sess_last[m])
            return st
        ex, xi, worst = walk(o, h, l, c, j, jend, d, fp, st, tp, trail=trail if trail_atr > 0 else None)
        days = (t[xi].normalize() - t[j].normalize()).days
        sw = (SWAP["xauusd"][0] if d == 1 else SWAP["xauusd"][1]) / 100 / 365 * fp * days
        out.append(rec("xauusd", "", t[j], t[xi], d, fp, (ex - fp) * d - cost + sw, r1, worst - cost + min(sw, 0)))
        busy_until = t[xi]
    return pd.DataFrame(out)
