"""Goat 2-Step 1% Floating ($5k) simulation with the robust edges (index D1 mean reversion basket + calendar intraday).
Per-trade $ sizing under the $50 combined-floating hard breach; MTM floating checked on every H1 bar (worst price of the bar, all open
positions summed at the same hour = conservative), incl. spread and accrued swap. Rolling monthly starts 2015-11 .. 2026-10."""
import sys, os, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/v2"); sys.path.insert(0, "/workspace/alien-research/code/mercado")
import engine2 as E, fam2
from confluence import calendar_days
SWAP_STRESS = float(os.environ.get("SWAPX", "1.0"))
IDX = ["usa500idxusd", "usatechidxusd", "deuidxeur"]
FX = {"usa500idxusd": 1.0, "usatechidxusd": 1.0, "deuidxeur": 1.12}          # $ per point per 1.00 lot (contract 1)
SPF = {"usa500idxusd": 0.6, "usatechidxusd": 2.0, "deuidxeur": 1.5}
for s in IDX:   # Goat: no commission on indices, raw spread, swap charged (use -7.2%/yr long, -1.8 short; stress x SWAPX)
    E.INSTR[s] = dict(comm=0.0, sp_scale=1.0, sp_floor=SPF[s], slip=E.INSTR[s]["slip"], swap=(-7.2 * SWAP_STRESS, -1.8 * SWAP_STRESS))
H1 = {s: E.load_h1(s) for s in IDX}; D1 = {s: E.resample(H1[s], "D1") for s in IDX}

def mr_trades(sk_rsi=3.0, sk_ibs=4.0):
    out = []
    for s in IDX:
        r = D1[s]
        for name, kw in (("RSI2", fam2.rsi2(r, 10, sk_rsi, True)), ("IBS", fam2.ibs(r, 0.25, sk_ibs))):
            t = E.run(r, s, **kw); t["sym"] = s; t["strat"] = name
            t["fp"] = r.open.values[t.ei]; t["dist"] = t.risk - (r.sp.values[t.ei] + 2 * E.INSTR[s]["slip"])
            t["cost"] = r.sp.values[t.ei] + 2 * E.INSTR[s]["slip"]; out.append(t)
    return pd.concat(out, ignore_index=True)

def cal_trades():
    """Calendar intraday on H1: Monday / pre-holiday / TOM (last day + first 3) / FOMC eve+day (2021+). Long at 10:00 NY open,
    SL 0.5 ATR(D1), TP 1 ATR(D1), exit 16:00 NY. US500 + NAS100."""
    hol, ann = calendar_days(); out = []
    for s in ["usa500idxusd", "usatechidxusd"]:
        h = H1[s]; d = D1[s].copy(); d.index = (d.index + pd.Timedelta(hours=7)).normalize().tz_localize(None)
        days = d.index; ym = days.to_period("M")
        first3 = d.groupby(ym).cumcount() < 3; last1 = d.groupby(ym).cumcount(ascending=False) == 0
        prev_atr = d.atr.shift(1)
        hd = h.copy(); hd["date"] = hd.index.tz_localize(None).normalize()
        for k, T in enumerate(days):
            mon = T.dayofweek == 0
            pre = any((x > T) and (x - T).days <= 3 and not ((days > T) & (days < x)).any() for x in hol[(hol > T) & (hol < T + pd.Timedelta(days=5))])
            fomc = any((a == T) or (a - T).days == 1 for a in ann)
            if not (mon or pre or fomc or first3.iloc[k] or last1.iloc[k]) or not np.isfinite(prev_atr.iloc[k]): continue
            bars = hd[(hd.date == T) & (hd.index.hour >= 10) & (hd.index.hour < 16)]
            if len(bars) < 5: continue
            sp = SPF[s]; fp = bars.open.iloc[0] + sp / 2; a = prev_atr.iloc[k]; st = fp - 0.5 * a; tp = fp + 1.0 * a; ex = None; xi = None
            for m in range(len(bars)):
                if bars.low.iloc[m] <= st: ex = st - E.INSTR[s]["slip"]; xi = m; break
                if bars.high.iloc[m] >= tp: ex = tp - sp / 2; xi = m; break
            if ex is None: ex = bars.close.iloc[-1] - sp / 2; xi = len(bars) - 1
            out.append(dict(sym=s, strat="CAL", entry=bars.index[0], exit=bars.index[xi] + pd.Timedelta(minutes=59), dir=1, fp=fp, dist=0.5 * a,
                            cost=sp + E.INSTR[s]["slip"], pnl=(ex - fp), risk=0.5 * a + sp, worst=min(max((bars.low.iloc[:xi + 1].min() - sp / 2) - fp, -0.5 * a - E.INSTR[s]['slip']), ex - fp)))
    t = pd.DataFrame(out); t["R"] = t.pnl / t.risk; return t

def paths(T):
    """per trade: list of (hour timestamp, floating pnl per 1.00 lot in points) incl. spread + swap; and final pnl points."""
    P = []
    for _, t in T.iterrows():
        if t.strat == "CAL":
            P.append((pd.DatetimeIndex([t.entry, t.exit]), np.array([min(t.worst, 0) - 0, t.pnl]))); continue
        h = H1[t.sym]; seg = h[(h.index >= t.entry) & (h.index <= t.exit)]
        st = t.fp - t.dir * t.dist; swl = E.INSTR[t.sym]["swap"][0 if t.dir == 1 else 1] / 100 / 365 * t.fp
        days = (seg.index - t.entry).total_seconds() / 86400
        worst = (seg.low.values - t.fp) if t.dir == 1 else (t.fp - seg.high.values)
        lim = -t.dist; gap = ((seg.open.values - t.fp) * t.dir) < lim
        fl = np.where(gap, (seg.open.values - t.fp) * t.dir, np.maximum(worst, lim)) - t.cost + swl * np.floor(days)
        if len(seg) == 0: P.append((pd.DatetimeIndex([t.entry]), np.array([min(t.pnl, -t.cost)]))); continue
        P.append((seg.index, fl))
    return P

def goat(T, P, start, risk_usd, cap_usd=45.0, step=0.01, minlot=0.01, maxpos=99, acct=5000.0, phases=(0.08, 0.06)):
    """Run phases sequentially from 'start'. Returns (result, days_p1, days_p2, reason)."""
    idx = np.nonzero((T.entry >= start).values)[0]
    res = []; ph = 0; bal = acct; pdays = set(); t0 = start; day_pnl = {}
    open_ = []   # (exit_time, usd_risk, trade index, lot)
    floats = {}  # hour -> summed floating $
    i_list = list(idx)
    for i in i_list:
        t = T.iloc[i]
        open_ = [o for o in open_ if o[0] > t.entry]
        if len(open_) >= maxpos: continue
        ppl = FX[t.sym]   # $ per point per lot
        lot = np.floor(risk_usd / ((t.dist + t.cost) * ppl) / step + 1e-9) * step
        if lot < minlot - 1e-12: continue
        usd_risk = lot * (t.dist + t.cost) * ppl
        if sum(o[1] for o in open_) + usd_risk > cap_usd: continue
        open_.append((t.exit, usd_risk, i, lot))
        # floating breach check: sum this trade's path with the other open trades' paths at the same hours
        ts, fl = P[i]
        bound = fl.min() * lot * ppl + sum(P[o[2]][1].min() * o[3] * FX[T.sym.iloc[o[2]]] for o in open_[:-1])
        tot = pd.Series([0.0]) if bound > -50.0 else pd.Series(fl * lot * ppl, index=ts)
        for o in (open_[:-1] if bound <= -50.0 else []):
            ts2, fl2 = P[o[2]]; s2 = pd.Series(fl2 * o[3] * FX[T.sym.iloc[o[2]]], index=ts2)
            s2 = s2[(s2.index >= ts[0]) & (s2.index <= ts[-1])]
            if len(s2): tot = tot.add(s2.reindex(tot.index.union(s2.index)).ffill().fillna(0), fill_value=0)
        if tot.min() <= -50.0:
            return ("BREACH_FLOAT", ph, (t.entry - t0).days, bal)
        pnl = t.pnl * lot * ppl; bal += pnl
        d = t.exit.tz_convert("America/New_York").normalize(); day_pnl[d] = day_pnl.get(d, 0) + pnl
        if bal <= acct * 0.90: return ("BREACH_MAX", ph, (t.exit - t0).days, bal)
        prof_days = sum(1 for v in day_pnl.values() if v >= 0.005 * acct)
        if bal >= acct * (1 + phases[ph]) and prof_days >= 3:
            res.append((t.exit - t0).days); ph += 1
            if ph == len(phases): return ("PASS", ph, res, bal)
            bal = acct; day_pnl = {}; t0 = t.exit; open_ = []
    return ("RUNNING", ph, res, bal)
