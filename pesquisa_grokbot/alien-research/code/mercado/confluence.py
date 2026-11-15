"""Max-confluence MTF robot (D1/H4/H1 -> M1 entry) built only from effects the study found real.
Pre-specified versions (no parameter search). Indices US500/NAS100, M1 bid/ask 2021-2026, costs as in V2/SMC.
"""
import sys, re, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/smc"); sys.path.insert(0, "/workspace/alien-research/code/v2"); sys.path.insert(0, "/workspace/alien-research/code")
import smc, engine2, engine as E
from pandas.tseries.holiday import USFederalHolidayCalendar
from dateutil.easter import easter

def rsi(c, n):
    d = c.diff(); u = d.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean(); dn = (-d.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    return 100 - 100 / (1 + u / dn)

def calendar_days():
    hol = USFederalHolidayCalendar().holidays("2015-01-01", "2026-12-31")
    hol = hol[~((hol.month == 10) | ((hol.month == 11) & (hol.day < 20)))]
    hol = hol.union(pd.DatetimeIndex([pd.Timestamp(easter(y)) - pd.Timedelta(days=2) for y in range(2015, 2027)]))
    html = open("/workspace/alien-research/data/fomc.html", encoding="utf-8", errors="ignore").read(); ann = []
    MON = {m: i for i, m in enumerate(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], 1)}
    AB = {k[:3]: v for k, v in MON.items()}
    for ym in re.finditer(r'(\d{4}) FOMC Meetings(.*?)(?=\d{4} FOMC Meetings|$)', html, re.S):
        y = int(ym.group(1))
        for m in re.finditer(r'fomc-meeting__month[^>]*>\s*<strong>([A-Za-z/]+)</strong>.*?fomc-meeting__date[^>]*>([^<]+)<', ym.group(2), re.S):
            mon, dt = m.group(1), m.group(2)
            if "notation" in dt or "-" not in dt: continue
            mm = MON[mon] if mon in MON else AB[mon.split("/")[1]]
            ann.append(pd.Timestamp(y, mm, int(re.sub(r"\D", "", dt.split("-")[1]))))
    return hol, pd.DatetimeIndex(ann)

def build(sym):
    D = smc.load_m1(sym)
    h1 = engine2.load_h1(sym)
    d1 = engine2.resample(h1, "D1"); d1.index = (d1.index + pd.Timedelta(hours=7)).normalize().tz_localize(None); d1 = d1[d1.index.dayofweek < 5]
    d1["rsi2"] = rsi(d1.close, 2); d1["ibs"] = (d1.close - d1.low) / (d1.high - d1.low); d1["sma200"] = d1.close.rolling(200).mean()
    d1["sig"] = (d1.close > d1.sma200) & ((d1.rsi2 < 10) | (d1.ibs < 0.25))
    h4 = engine2.resample(h1, "H4"); h4["ema50"] = h4.close.ewm(span=50, adjust=False).mean(); h4["up"] = h4.close > h4.ema50
    h4["close_t"] = h4.index + pd.Timedelta(hours=4)
    hb = h1.copy(); hb["lo50"] = hb.low.rolling(50).min(); hb["hi50"] = hb.high.rolling(50).max(); hb["close_t"] = hb.index + pd.Timedelta(hours=1)
    ny = D["ny"]; tv = ny.values
    # map each M1 bar to last CLOSED H1/H4 values
    i1 = np.searchsorted(hb.close_t.values, tv, side="right") - 1
    lvl25 = np.where(i1 >= 0, (hb.lo50 + 0.25 * (hb.hi50 - hb.lo50)).values[np.maximum(i1, 0)], np.nan)
    i4 = np.searchsorted(h4.close_t.values, tv, side="right") - 1
    h4up = np.where(i4 >= 0, h4.up.values[np.maximum(i4, 0)], False)
    hol, ann = calendar_days()
    days = d1.index
    nxt = pd.Series(days[1:], index=days[:-1])
    cal = {}
    ym = days.to_period("M"); first3 = d1.groupby(ym).cumcount() < 3; last1 = d1.groupby(ym).cumcount(ascending=False) == 0
    for k, T in enumerate(days):
        mon = T.dayofweek == 0
        prehol = any((hd > T) and (hd - T).days <= 3 and not any((x > T) and (x < hd) for x in days[k + 1:k + 4]) for hd in hol[(hol > T) & (hol < T + pd.Timedelta(days=5))])
        fomc = any((a == T) or (a - T).days == 1 for a in ann)
        cal[T] = bool(mon or prehol or fomc or first3.iloc[k] or last1.iloc[k])
    return D, d1, lvl25, h4up, nxt, cal

def signals(D, d1, lvl25, h4up, nxt, cal, use_d1, use_cal, mode_cal, use_h1, use_m1, use_h4, stop, every_day=False):
    ny = D["ny"]; hm = D["hm"]; mc, mh, ml, mo = D["mc"], D["mh"], D["ml"], D["mo"]
    dates = ny.normalize().tz_localize(None)
    # index of first bar of each date at/after 09:30 and position of 14:00 / 15:55
    df = pd.DataFrame(dict(d=dates.values, hm=hm, i=np.arange(len(hm))))
    sess = df[(df.hm >= 570) & (df.hm < 840)].groupby("d").i.agg(["min", "max"])
    endb = df[(df.hm <= 955)].groupby("d").i.max()
    out = dict(sig_i=[], dir=[], otype=[], price=[], sl=[], rr=[], tpabs=[], expiry=[], maxhold=[])
    for T, row in d1.iterrows():
        if T not in nxt.index or not np.isfinite(row.atr): continue
        T1 = nxt[T]
        if T1 not in sess.index: continue
        d1ok = bool(row.sig); calok = cal.get(T1, False)
        if not every_day:
            if mode_cal == "or":
                if not ((use_d1 and d1ok) or (use_cal and calok)): continue
            else:
                if use_d1 and not d1ok: continue
                if use_cal and not calok: continue
        a, b = sess.loc[T1, "min"], sess.loc[T1, "max"]; e = endb.get(T1, b)
        i = a
        if use_h1:
            cand = np.nonzero(mc[a:b] < lvl25[a:b])[0]
            if not len(cand): continue
            i = a + cand[0]
        if use_m1:
            j = i + 1
            while j < b and not (mc[j] > mh[j - 1]): j += 1
            if j >= b: continue
            i = j
        if use_h4 and not h4up[i]: continue
        ent = i + 1 if (use_h1 or use_m1) else a
        if stop == "atr": sl = mo[ent] - 0.5 * row.atr
        else: sl = ml[max(ent - 15, a):ent].min() - 0.05 * row.atr
        out["sig_i"].append(ent); out["dir"].append(1); out["otype"].append(0); out["price"].append(np.nan); out["sl"].append(sl)
        out["rr"].append(2.0); out["tpabs"].append(np.nan); out["expiry"].append(ent); out["maxhold"].append(max(1, e - ent))
    return {k: np.asarray(v) for k, v in out.items()}

def metrics(t, risk=0.01):
    if len(t) < 3: return dict(n=len(t))
    R = t.R.values; eq = np.cumprod(1 + risk * R); mdd = (1 - eq / np.maximum.accumulate(eq)).max()
    ls = c = 0
    for v in R: c = c + 1 if v < 0 else 0; ls = max(ls, c)
    yrs = max((t.time.iloc[-1] - t.time.iloc[0]).days / 365.25, 0.3)
    return dict(n=len(R), wr=(R > 0).mean(), pf=R[R > 0].sum() / max(-R[R < 0].sum(), 1e-9), expR=R.mean(), t=R.mean() / R.std(ddof=1) * np.sqrt(len(R)),
                cagr1=eq[-1] ** (1 / yrs) - 1, mdd1=mdd, maxLS=ls)

V = {  # name: (use_d1, use_cal, mode_cal, use_h1, use_m1, use_h4, stop, every_day)
    "A0 controle: todo dia, compra 09:30": (0, 0, "and", 0, 0, 0, "atr", 1),
    "A1 só D1 (RSI2/IBS sobrevendido, >SMA200)": (1, 0, "and", 0, 0, 0, "atr", 0),
    "A2 D1 + H1 discount (espera queda intradiária)": (1, 0, "and", 1, 0, 0, "atr", 0),
    "A3 D1 + H1 + gatilho M1": (1, 0, "and", 1, 1, 0, "atr", 0),
    "A3t igual A3 com stop curto (fundo M1 15 barras)": (1, 0, "and", 1, 1, 0, "tight", 0),
    "A4 A3 + tendência H4 (EMA50)": (1, 0, "and", 1, 1, 1, "atr", 0),
    "A5 (D1 OU calendário) + H1 + M1": (1, 1, "or", 1, 1, 0, "atr", 0),
    "A6 confluência máxima (D1 E calendário E H4 E H1 E M1)": (1, 1, "and", 1, 1, 1, "atr", 0),
    "A6t confluência máxima com stop curto": (1, 1, "and", 1, 1, 1, "tight", 0),
    "C1 só calendário (seg/véspera feriado/FOMC/virada do mês)": (0, 1, "and", 0, 0, 0, "atr", 0),
}
if __name__ == "__main__":
    rows = []; OOS = pd.Timestamp("2026-01-01", tz="UTC")
    for sym in ["usa500idxusd", "usatechidxusd"]:
        B = build(sym); D = B[0]
        for name, (ud, uc, mc_, uh, um, u4, st, ev) in V.items():
            t = smc.run(D, signals(*B, ud, uc, mc_, uh, um, u4, st, ev))
            for p, m in (("2021-25", t.time < OOS), ("2026", t.time >= OOS)):
                r = dict(mkt=sym, version=name, period=p); r.update(metrics(t[m])); rows.append(r)
            print(sym, name, len(t), flush=True)
    R = pd.DataFrame(rows); R.to_csv("/workspace/alien-research/out/mercado/confluence.csv", index=False)
    pd.set_option("display.width", 250); pd.set_option("display.max_colwidth", 60); print(R.round(3).to_string())
