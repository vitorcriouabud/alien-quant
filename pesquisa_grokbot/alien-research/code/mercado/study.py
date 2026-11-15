"""Descriptive market-behaviour study (no optimisation). Outputs CSVs to out/mercado and prints summaries."""
import sys, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/smc"); sys.path.insert(0, "/workspace/alien-research/code/v2")
import smc, engine2
OUT = "/workspace/alien-research/out/mercado/"
MK = ["xauusd", "eurusd", "gbpusd", "usa500idxusd", "usatechidxusd", "deuidxeur"]
NAME = dict(xauusd="XAUUSD", eurusd="EURUSD", gbpusd="GBPUSD", usa500idxusd="US500", usatechidxusd="NAS100", deuidxeur="DE40")
ROUND = dict(xauusd=10.0, eurusd=0.0050, gbpusd=0.0050, usa500idxusd=50.0, usatechidxusd=100.0, deuidxeur=100.0)

def m1_frame(sym):
    if sym == "deuidxeur":
        h = engine2.load_h1(sym); h = h[h.index >= "2021-01-01"]
        return None, h.rename(columns=dict(open="o", high="h", low="l", close="c"))
    D = smc.load_m1(sym)
    sp = D["ac"] - D["bc"]
    f = pd.DataFrame(dict(o=D["mo"], h=D["mh"], l=D["ml"], c=D["mc"], sp=sp), index=D["ny"])
    return f, None

def rs(f, rule, shift=0):
    g = f.copy(); g.index = g.index + pd.Timedelta(hours=shift)
    r = g.resample(rule, label="left", closed="left").agg(dict(o="first", h="max", l="min", c="last", sp="median")).dropna()
    r.index = r.index - pd.Timedelta(hours=shift)
    pc = r.c.shift(1); tr = np.maximum(r.h - r.l, np.maximum((r.h - pc).abs(), (r.l - pc).abs()))
    r["atr"] = tr.rolling(14).mean(); r["ret"] = np.log(r.c / r.c.shift(1)) * 1e4  # bp
    return r

def per(df):  # period label
    return np.where(df.index.year >= 2026, "2026", "2021-25")

def vr(x, q):
    x = x.dropna().values; v1 = x.var()
    s = pd.Series(x).rolling(q).sum().values[q - 1::q]
    return s.var() / (q * v1)

def streaks(r, Nmax=5):
    s = np.sign(r.c - r.o).values; out = {}
    for N in range(2, Nmax + 1):
        same = np.ones(len(s) - N, bool)
        for k in range(N): same &= (s[k:len(s) - N + k] == s[N - 1:len(s) - 1]) & (s[N - 1:len(s) - 1] != 0)
        nxt = s[N:]; m = same & (nxt != 0)
        out[N] = (nxt[m] == s[N - 1:len(s) - 1][m]).mean() if m.sum() > 50 else np.nan
    return out

rows_ac, rows_hr, rows_wd, rows_sw, rows_big, rows_fvg, rows_vol, rows_gap, rows_rn, rows_ctf, rows_sess, rows_cost = ([] for _ in range(12))
for sym in MK:
    f, h1only = m1_frame(sym); nm = NAME[sym]; print("==", nm, flush=True)
    if f is not None:
        TF = {"M1": None, "M5": rs(f, "5min"), "M15": rs(f, "15min"), "H1": rs(f, "1h"), "H4": rs(f, "4h", 7), "D1": rs(f, "1D", 7)}
        m1 = f.copy(); m1["ret"] = np.log(m1.c / m1.c.shift(1)) * 1e4; m1["atr"] = np.nan; TF["M1"] = m1
    else:
        g = h1only.copy()
        TF = {"H1": rs(g, "1h"), "H4": rs(g, "4h", 7), "D1": rs(g, "1D", 7)}
    D1 = TF["D1"]; D1 = D1[D1.index.day_of_week != 5]; TF["D1"] = D1
    spread_bp = (TF["H1"].sp / TF["H1"].c * 1e4).median()
    rows_cost.append(dict(mkt=nm, spread_bp=spread_bp, atrH1_bp=(TF["H1"].atr / TF["H1"].c * 1e4).median(), atrD1_bp=(D1.atr / D1.c * 1e4).median(),
                          atrM15_bp=(TF["M15"].atr / TF["M15"].c * 1e4).median() if "M15" in TF else np.nan))
    # ---- 1) autocorrelation, variance ratio, streaks
    for tf, r in TF.items():
        for p in ("2021-25", "2026"):
            x = r[per(r) == p]
            if len(x) < 200: continue
            ret = x.ret.replace([np.inf, -np.inf], np.nan).dropna()
            row = dict(mkt=nm, tf=tf, period=p, n=len(ret), ac1=ret.autocorr(1), vr2=vr(ret, 2), vr4=vr(ret, 4), vr8=vr(ret, 8))
            if tf != "M1": row.update({f"P_cont_after_{k}": v for k, v in streaks(x).items()})
            rows_ac.append(row)
    # ---- 2) hour / weekday on H1
    h = TF["H1"].copy(); h["absr"] = h.ret.abs(); h["rng_bp"] = (h.h - h.l) / h.c * 1e4; h["hr"] = h.index.hour; h["wd"] = h.index.day_of_week; h["p"] = per(h)
    g = h.groupby(["p", "hr"]).agg(rng_bp=("rng_bp", "mean"), drift_bp=("ret", "mean"), sd=("ret", "std"), n=("ret", "size")).reset_index()
    g["t"] = g.drift_bp / g.sd * np.sqrt(g.n); g["mkt"] = nm; rows_hr.append(g)
    d = D1.copy(); d["p"] = per(d); d["wd"] = d.index.day_of_week; d["rng_bp"] = (d.h - d.l) / d.c * 1e4
    # D1 bar labelled by its start (17:00 NY previous day) -> trading weekday = start + 7h
    d["wd"] = (d.index + pd.Timedelta(hours=7)).day_of_week
    g = d.groupby(["p", "wd"]).agg(rng_bp=("rng_bp", "mean"), drift_bp=("ret", "mean"), sd=("ret", "std"), n=("ret", "size")).reset_index()
    g["t"] = g.drift_bp / g.sd * np.sqrt(g.n); g["mkt"] = nm; rows_wd.append(g)
    # ---- session handoffs (H1): Asia 19-02, London 02-08, NY 08-16 (NY time), trading day = start 18:00
    h["td"] = (h.index - pd.Timedelta(hours=18)).normalize()
    def sess(a, b):
        m = (h.hr >= a) | (h.hr < b) if a > b else (h.hr >= a) & (h.hr < b)
        return h[m].groupby("td").agg(H=("h", "max"), L=("l", "min"), O=("o", "first"), C=("c", "last"))
    A, L, N = sess(19, 2), sess(2, 8), sess(8, 16)
    j = A.join(L, rsuffix="_L").join(N, rsuffix="_N").dropna(); j["p"] = np.where(j.index.year >= 2026, "2026", "2021-25")
    for p, x in j.groupby("p"):
        lon_hi = x.H_L > x.H; lon_lo = x.L_L < x.L
        rows_sess.append(dict(mkt=nm, period=p, n=len(x), P_london_takes_asia_hi=lon_hi.mean(), P_london_takes_asia_lo=lon_lo.mean(),
                              P_london_takes_both=(lon_hi & lon_lo).mean(), P_london_takes_none=(~lon_hi & ~lon_lo).mean(),
                              P_ny_takes_london_extreme=((x.H_N > x.H_L) | (x.L_N < x.L_L)).mean(),
                              P_ny_reverses_london=(np.sign(x.C_N - x.O_N) != np.sign(x.C_L - x.O_L)).mean(),
                              asia_rng_bp=((x.H - x.L) / x.C * 1e4).median(), london_rng_bp=((x.H_L - x.L_L) / x.C_L * 1e4).median(), ny_rng_bp=((x.H_N - x.L_N) / x.C_N * 1e4).median()))
    # ---- 3) sweeps (on M5 if available else H1): PDH/PDL, Asia H/L (taken during 02-16 NY), measured from first take
    base = TF["M5"] if "M5" in TF else TF["H1"]
    bmin = 5 if "M5" in TF else 60
    b = base.copy(); b["td"] = (b.index - pd.Timedelta(hours=18)).normalize(); b["hr"] = b.index.hour
    dd = b.groupby("td").agg(H=("h", "max"), L=("l", "min")); pdh = dd.H.shift(1); pdl = dd.L.shift(1)
    asia = b[(b.hr >= 19) | (b.hr < 2)].groupby("td").agg(H=("h", "max"), L=("l", "min"))
    atrH1 = TF["H1"].atr.reindex(b.index, method="ffill").values
    c_, h_, l_ = b.c.values, b.h.values, b.l.values; tdv = b.td.values; hrv = b.hr.values
    HZ = {"1h": 60 // bmin, "4h": 240 // bmin, "24h": 1440 // bmin}
    levels = {"PDH/PDL": (pdh, pdl, None), "Asia H/L": (asia.H, asia.L, (2, 16))}
    for lname, (Hs, Ls, win) in levels.items():
        Hm = Hs.reindex(b.td).values; Lm = Ls.reindex(b.td).values
        for side, lvl, cross in (("high", Hm, h_ > Hm), ("low", Lm, l_ < Lm)):
            ok = cross.copy()
            if win: ok &= (hrv >= win[0]) & (hrv < win[1])
            first = pd.Series(ok, index=b.index).groupby(tdv).cumsum().values == 1
            idx = np.nonzero(first & ok)[0]
            sgn = 1 if side == "high" else -1
            for hz, k in HZ.items():
                ii = idx[idx + k < len(c_)]
                lv = lvl[ii]; mv = (c_[ii + k] - lv) * sgn                     # >0 = continued beyond level
                a = atrH1[ii]
                yrs = b.index.year[ii]
                for p, msk in (("2021-25", yrs < 2026), ("2026", yrs >= 2026)):
                    if msk.sum() < 30: continue
                    rows_sw.append(dict(mkt=nm, level=lname, side=side, horizon=hz, period=p, n=int(msk.sum()),
                                        P_back_inside=(mv[msk] < 0).mean(), med_move_ATRh1=np.nanmedian(mv[msk] / a[msk]),
                                        mean_move_bp=np.nanmean(mv[msk] / lv[msk] * 1e4)))
    # equal highs/lows on H1: two fractal highs within 0.1 ATR in last 48 bars, then price takes them
    H1 = TF["H1"]; hh, ll, cc, at = H1.h.values, H1.l.values, H1.c.values, H1.atr.values
    fh = np.zeros(len(hh), bool); fl = np.zeros(len(hh), bool)
    fh[2:-2] = (hh[2:-2] > hh[1:-3]) & (hh[2:-2] > hh[:-4]) & (hh[2:-2] >= hh[3:-1]) & (hh[2:-2] >= hh[4:])
    fl[2:-2] = (ll[2:-2] < ll[1:-3]) & (ll[2:-2] < ll[:-4]) & (ll[2:-2] <= ll[3:-1]) & (ll[2:-2] <= ll[4:])
    ev = []
    for i in range(52, len(hh) - 25):
        for sgn, F_, X in ((1, fh, hh), (-1, fl, ll)):
            cand = [k for k in range(i - 48, i - 2) if F_[k]]   # confirmed by i (k+2 < i)
            if len(cand) < 2: continue
            a1, a2 = X[cand[-1]], X[cand[-2]]
            if abs(a1 - a2) > 0.1 * at[i] or not np.isfinite(at[i]): continue
            lvl = max(a1, a2) if sgn == 1 else min(a1, a2)
            if (sgn == 1 and hh[i] > lvl and hh[i - 1] <= lvl) or (sgn == -1 and ll[i] < lvl and ll[i - 1] >= lvl):
                ev.append((i, sgn, lvl))
    for hz, k in (("1h", 1), ("4h", 4), ("24h", 24)):
        e = [(i, s, lv) for i, s, lv in ev if i + k < len(cc)]
        if not e: continue
        ii = np.array([x[0] for x in e]); ss = np.array([x[1] for x in e]); lv = np.array([x[2] for x in e])
        mv = (cc[ii + k] - lv) * ss; yrs = H1.index.year[ii]
        for p, msk in (("2021-25", yrs < 2026), ("2026", yrs >= 2026)):
            if msk.sum() < 30: continue
            rows_sw.append(dict(mkt=nm, level="Equal H/L (H1)", side="both", horizon=hz, period=p, n=int(msk.sum()), P_back_inside=(mv[msk] < 0).mean(),
                                med_move_ATRh1=np.nanmedian(mv[msk] / at[ii][msk]), mean_move_bp=np.nanmean(mv[msk] / lv[msk] * 1e4)))
    # ---- 4) big candles & FVG
    for tf in ("M5", "M15", "H1", "H4"):
        if tf not in TF: continue
        r = TF[tf]; o, hi, lo, c, a = r.o.values, r.h.values, r.l.values, r.c.values, r.atr.shift(1).values
        big = ((hi - lo) > 2 * a) & np.isfinite(a); d_ = np.sign(c - o)
        yrs = r.index.year
        for k in (1, 3, 12):
            ii = np.nonzero(big)[0]; ii = ii[ii + k < len(c)]
            mv = (c[ii + k] - c[ii]) * d_[ii]
            for p, msk in (("2021-25", yrs[ii] < 2026), ("2026", yrs[ii] >= 2026)):
                if msk.sum() < 30: continue
                rows_big.append(dict(mkt=nm, tf=tf, after_bars=k, period=p, n=int(msk.sum()), P_continue=(mv[msk] > 0).mean(),
                                     mean_move_ATR=np.nanmean(mv[msk] / a[ii][msk]), mean_move_bp=np.nanmean(mv[msk] / c[ii][msk] * 1e4),
                                     P_retrace_half=np.mean([(lo[i + 1:i + k + 1].min() <= (o[i] + c[i]) / 2) if d_[i] > 0 else (hi[i + 1:i + k + 1].max() >= (o[i] + c[i]) / 2) for i in ii[msk]])))
        # FVG
        bull = lo[2:] > hi[:-2]; bear = hi[2:] < lo[:-2]
        for sgn, m_ in ((1, bull), (-1, bear)):
            ii = np.nonzero(m_)[0] + 2
            ii = ii[ii + 48 < len(c)]
            if len(ii) == 0: continue
            # gap bounds; fill = price trades back to far edge (full fill) ; touch = proximal edge
            prox = lo[ii] if sgn == 1 else hi[ii]; far = hi[ii - 2] if sgn == 1 else lo[ii - 2]
            t_touch = np.full(len(ii), 999); t_fill = np.full(len(ii), 999); t_ext = np.full(len(ii), 999)
            for q, i in enumerate(ii):
                seg_l = lo[i + 1:i + 49]; seg_h = hi[i + 1:i + 49]
                if sgn == 1:
                    tt = np.nonzero(seg_l <= prox[q])[0]; tf_ = np.nonzero(seg_l <= far[q])[0]; te = np.nonzero(seg_h >= c[i] + a[i])[0]
                else:
                    tt = np.nonzero(seg_h >= prox[q])[0]; tf_ = np.nonzero(seg_h >= far[q])[0]; te = np.nonzero(seg_l <= c[i] - a[i])[0]
                if len(tt): t_touch[q] = tt[0] + 1
                if len(tf_): t_fill[q] = tf_[0] + 1
                if len(te): t_ext[q] = te[0] + 1
            y = r.index.year[ii]
            for p, msk in (("2021-25", y < 2026), ("2026", y >= 2026)):
                if msk.sum() < 30: continue
                rows_fvg.append(dict(mkt=nm, tf=tf, dir="bull" if sgn == 1 else "bear", period=p, n=int(msk.sum()),
                                     P_touch_12=(t_touch[msk] <= 12).mean(), P_touch_48=(t_touch[msk] <= 48).mean(), P_fullfill_48=(t_fill[msk] <= 48).mean(),
                                     med_bars_to_touch=np.median(t_touch[msk][t_touch[msk] < 999]) if (t_touch[msk] < 999).any() else np.nan,
                                     P_ext1ATR_before_touch=(t_ext[msk] < t_touch[msk]).mean()))
    # ---- 5) vol clustering & compression
    for tf in ("M15", "H1", "D1"):
        if tf not in TF: continue
        r = TF[tf]; ar = r.ret.abs()
        rng = (r.h - r.l)
        nr7 = rng == rng.rolling(7).min(); inside = (r.h < r.h.shift(1)) & (r.l > r.l.shift(1))
        nxt = rng.shift(-1) / rng.rolling(20).mean()
        nxt_dir = np.sign(r.c.shift(-1) - r.o.shift(-1))
        for p in ("2021-25", "2026"):
            m = per(r) == p
            rows_vol.append(dict(mkt=nm, tf=tf, period=p, ac_absret_1=ar[m].autocorr(1), ac_absret_10=ar[m].autocorr(10),
                                 next_range_after_NR7=nxt[m & nr7].mean(), next_range_after_inside=nxt[m & inside].mean(), next_range_normal=nxt[m].mean(),
                                 P_up_after_inside=(nxt_dir[m & inside] > 0).mean(), n_nr7=int((m & nr7).sum())))
    # ---- 6) gaps (weekend: first H1 bar of week vs last close) & NFP & round numbers
    hh1 = TF["H1"]; gap_t = hh1.index.to_series().diff() > pd.Timedelta(hours=24)
    gi = np.nonzero(gap_t.values)[0]
    gsz = (hh1.o.values[gi] - hh1.c.values[gi - 1]); aD = D1.atr.reindex(hh1.index, method="ffill").values[gi]
    filled = []
    for q, i in enumerate(gi):
        seg = hh1.iloc[i:i + 24]; pc = hh1.c.values[i - 1]
        filled.append((seg.l.min() <= pc) if gsz[q] > 0 else (seg.h.max() >= pc))
    filled = np.array(filled); big = np.abs(gsz) > 0.1 * aD
    rows_gap.append(dict(mkt=nm, n_weekends=len(gi), med_abs_gap_ATRd=np.nanmedian(np.abs(gsz) / aD), p90_abs_gap_ATRd=np.nanpercentile(np.abs(gsz) / aD, 90),
                         max_abs_gap_ATRd=np.nanmax(np.abs(gsz) / aD), P_fill_24h=filled.mean(), P_fill_24h_big=filled[big].mean() if big.any() else np.nan, n_big=int(big.sum())))
    # NFP proxy: first Friday of month 08:30-09:30 NY bar range vs other Fridays same hour
    if "M15" in TF:
        m15 = TF["M15"]; x = m15[(m15.index.day_of_week == 4) & (m15.index.hour == 8) & (m15.index.minute == 30)]
        rngx = (x.h - x.l) / x.atr; nfp = x.index.day <= 7
        rows_gap[-1].update(dict(NFP_bar_range_ATR=rngx[nfp].mean(), other_fri_0830_range_ATR=rngx[~nfp].mean()))
    # round numbers on M5 (or H1): first touch of level per bar from below/above; reaction over 12 bars; control = half-step offsets
    step = ROUND[sym]; bb = TF["M5"] if "M5" in TF else TF["H1"]; k = 12 if "M5" in TF else 1
    o, hi, lo, c, a = bb.o.values, bb.h.values, bb.l.values, bb.c.values, bb.atr.values
    for lab, off in (("round", 0.0), ("control_half", 0.5)):
        res = []
        lvl_up = (np.floor(o / step - off) + 1 + off) * step   # next level above open
        up = hi >= lvl_up
        lvl_dn = (np.ceil(o / step - off) - 1 + off) * step
        dn = lo <= lvl_dn
        for m_, lv, sgn in ((up, lvl_up, 1), (dn, lvl_dn, -1)):
            ii = np.nonzero(m_)[0]; ii = ii[ii + k < len(c)]
            res.append(((c[ii + k] - lv[ii]) * sgn < 0))
        rr = np.concatenate(res)
        rows_rn.append(dict(mkt=nm, kind=lab, step=step, n=len(rr), P_reject_back_1h=rr.mean()))
    # ---- 7) cross-timeframe: lower TF bar direction vs higher TF trend (close vs EMA50 of higher TF, previous closed bar)
    pairs = [("M5", "H1"), ("M15", "H4"), ("H1", "D1"), ("H1", "H4")]
    for lo_tf, hi_tf in pairs:
        if lo_tf not in TF: continue
        L_, H_ = TF[lo_tf], TF[hi_tf].copy()
        H_["tr"] = np.sign(H_.c - H_.c.ewm(span=50, adjust=False).mean())
        H_["close_t"] = H_.index + (pd.Timedelta(hours=4) if hi_tf == "H4" else pd.Timedelta(hours=1) if hi_tf == "H1" else pd.Timedelta(days=1))
        tr = H_.set_index("close_t").tr.reindex(L_.index, method="ffill").values   # last CLOSED higher-TF bar
        dL = np.sign(L_.c - L_.o).values; prev = np.roll(dL, 1)
        r_ = L_.ret.values
        for p in ("2021-25", "2026"):
            m = (per(L_) == p) & (tr != 0) & np.isfinite(tr) & (dL != 0)
            rows_ctf.append(dict(mkt=nm, low=lo_tf, high=hi_tf, period=p, n=int(m.sum()),
                                 P_bar_with_HTF=(dL[m] == tr[m]).mean(),
                                 P_cont_prev_bar=(dL[m] == prev[m]).mean(),
                                 P_cont_prev_if_aligned=(dL[m & (prev == tr)] == prev[m & (prev == tr)]).mean(),
                                 P_cont_prev_if_against=(dL[m & (prev == -tr)] == prev[m & (prev == -tr)]).mean(),
                                 mean_ret_with_HTF_bp=np.nanmean(r_[m] * tr[m])))
for nmx, rows in (("autocorr", rows_ac), ("sessions", rows_sess), ("sweeps", rows_sw), ("bigcandles", rows_big), ("fvg", rows_fvg),
                  ("vol", rows_vol), ("gaps_news", rows_gap), ("round", rows_rn), ("crosstf", rows_ctf), ("cost", rows_cost)):
    pd.DataFrame(rows).to_csv(OUT + nmx + ".csv", index=False)
pd.concat(rows_hr).to_csv(OUT + "hour.csv", index=False); pd.concat(rows_wd).to_csv(OUT + "weekday.csv", index=False)
print("done")
