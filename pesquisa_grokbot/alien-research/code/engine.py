"""ALIEN research engine: XAUUSD M1 bid/ask event backtester (numba).
Conventions
- Signals are computed on MID prices of closed bars only (causal).
- Longs fill at ASK, exit on BID; shorts fill at BID, exit on ASK.
- Costs: spread (scenario), commission COMM per oz round trip (US$7/lot = 0.07/oz), slippage SLIP on
  market/stop fills and on stop-loss exits (TP = limit, no slip). Gaps through SL fill at the open.
- Same-bar ambiguity: if SL and TP are both touched in one M1 bar -> SL first (conservative).
  On the fill bar of a limit/stop order only the SL is checked (conservative).
- Flat zone: every day 16:50-18:00 New York (server 23:50-01:00, GMT+2/+3) incl. weekends -> forced exit,
  no fills. Unscheduled data gaps (holidays) are NOT protected: exit at the gapped open (real gap risk).
"""
import numpy as np, pandas as pd
from numba import njit

COMM = 0.07   # US$ per oz round trip (= US$7 per 1.00 lot of 100 oz)
SLIP = 0.05   # US$ per oz on market/stop fills and SL exits
MAX_STOP = 12.0  # US$ per oz: 0.25% of 5k = 12.5 at min lot 0.01 (=1 oz)
MIN_STOP = 0.8

def load(scenario="B"):
    df = pd.read_parquet("/workspace/alien-research/data/xau_m1_bidask.parquet")
    stale = (df.bh == df.bl) & (df.ah == df.al) & (df.bc == df.bc.shift(1)) & (df.ac == df.ac.shift(1))
    df = df[~stale]   # drop Dukascopy flat filler bars (market closed)
    bid = df[["bo","bh","bl","bc"]].values; ask = df[["ao","ah","al","ac"]].values
    mid = (bid + ask) / 2.0
    real_sp = (ask - bid)
    if scenario == "A":      # full Dukascopy spread (conservative)
        sp = real_sp
    elif scenario == "B":    # ECN-like: half the Dukascopy spread, floor 0.20
        sp = np.maximum(0.20, 0.5 * real_sp)
    elif scenario == "Z":    # frictionless (sanity check only)
        sp = np.zeros_like(real_sp)
    elif scenario == "C":    # fixed 0.30
        sp = np.full_like(real_sp, 0.30)
    b = mid - sp / 2; a = mid + sp / 2
    ny = df.index.tz_convert("America/New_York")
    hm = ny.hour * 60 + ny.minute
    flat = ((hm >= 16 * 60 + 50) & (hm < 18 * 60)) | (ny.dayofweek == 5)
    D = dict(utc=df.index, ny=ny, hm=np.asarray(hm), dow=np.asarray(ny.dayofweek),
             mo=mid[:, 0].copy(), mh=mid[:, 1].copy(), ml=mid[:, 2].copy(), mc=mid[:, 3].copy(),
             bo=b[:, 0].copy(), bh=b[:, 1].copy(), bl=b[:, 2].copy(), bc=b[:, 3].copy(),
             ao=a[:, 0].copy(), ah=a[:, 1].copy(), al=a[:, 2].copy(), ac=a[:, 3].copy(),
             flat=np.asarray(flat))
    # trading-day id: day starts 18:00 NY
    tday = (ny - pd.Timedelta(hours=18)).normalize()
    D["tday"] = np.asarray(tday.tz_localize(None).values.astype("datetime64[D]").astype(np.int64))
    return D

@njit(cache=True)
def simulate(bo, bh, bl, bc, ao, ah, al, ac, flat,
             sig_i, sdir, otype, price, sl, rr, tpabs, expiry, maxhold, be_at,
             comm, slip, max_stop, min_stop):
    n = bo.shape[0]; ns = sig_i.shape[0]
    out_entry_i = np.full(ns, -1, np.int64); out_exit_i = np.full(ns, -1, np.int64)
    out_pnl = np.zeros(ns); out_risk = np.zeros(ns); out_mae = np.zeros(ns); out_dir = np.zeros(ns, np.int64)
    out_reason = np.zeros(ns, np.int64)  # 1 sl, 2 tp, 3 time, 4 flat, 5 gap-sl, 6 be
    k = 0; busy_until = -1
    for s in range(ns):
        i0 = sig_i[s]
        if i0 <= busy_until or i0 >= n:
            continue
        d = sdir[s]; st = sl[s]
        # ---- find fill
        fill_i = -1; fp = 0.0
        last = min(expiry[s], n - 1)
        for j in range(i0, last + 1):
            if flat[j]:
                if otype[s] == 0:
                    break
                continue
            if otype[s] == 0:   # market at open
                fp = (ao[j] + slip) if d == 1 else (bo[j] - slip)
                fill_i = j; break
            elif otype[s] == 1:  # limit
                L = price[s]
                if d == 1:
                    if bl[j] <= st and al[j] > L:  # stop zone reached before fill? (price ran through) -> conservative skip of order
                        pass
                    if al[j] <= L:
                        fp = min(L, ao[j]); fill_i = j; break
                    if bl[j] <= st:   # invalidated without fill
                        break
                else:
                    if bh[j] >= L:
                        fp = max(L, bo[j]); fill_i = j; break
                    if ah[j] >= st:
                        break
            else:  # stop order
                L = price[s]
                if d == 1:
                    if ah[j] >= L:
                        fp = max(L, ao[j]) + slip; fill_i = j; break
                else:
                    if bl[j] <= L:
                        fp = min(L, bo[j]) - slip; fill_i = j; break
        if fill_i < 0:
            busy_until = max(busy_until, j if otype[s] != 0 else i0)
            continue
        dist = (fp - st) * d
        if dist < min_stop or dist > max_stop:
            busy_until = fill_i  # order would not have been sent (stop size known at signal) -> just skip
            continue
        if tpabs[s] == tpabs[s]:
            tp = tpabs[s]
            if (tp - fp) * d <= 0:
                busy_until = fill_i; continue
        else:
            tp = fp + d * rr[s] * dist
        risk = dist + slip + comm
        # ---- manage
        exit_p = 0.0; reason = 0; mae = 0.0; ex_i = -1
        cur_sl = st; moved = False
        endbar = min(n - 1, fill_i + maxhold[s])
        for j in range(fill_i, n):
            if j > fill_i and (flat[j] or j > endbar):
                exit_p = (bo[j] - slip) if d == 1 else (ao[j] + slip)
                reason = 4 if flat[j] else 3; ex_i = j; break
            if d == 1:
                lo = bl[j]; hi = bh[j]; op = bo[j]
                mae = max(mae, fp - lo)
                if j > fill_i and op <= cur_sl:
                    exit_p = op - slip; reason = 5; ex_i = j; break
                if lo <= cur_sl:
                    exit_p = cur_sl - slip; reason = 6 if moved else 1; ex_i = j; break
                if j > fill_i and hi >= tp:
                    exit_p = max(tp, op); reason = 2; ex_i = j; break
                if be_at[s] > 0 and (not moved) and j > fill_i and hi >= fp + be_at[s] * dist:
                    cur_sl = fp + comm; moved = True
            else:
                lo = al[j]; hi = ah[j]; op = ao[j]
                mae = max(mae, hi - fp)
                if j > fill_i and op >= cur_sl:
                    exit_p = op + slip; reason = 5; ex_i = j; break
                if hi >= cur_sl:
                    exit_p = cur_sl + slip; reason = 6 if moved else 1; ex_i = j; break
                if j > fill_i and lo <= tp:
                    exit_p = min(tp, op); reason = 2; ex_i = j; break
                if be_at[s] > 0 and (not moved) and j > fill_i and lo <= fp - be_at[s] * dist:
                    cur_sl = fp - comm; moved = True
        if ex_i < 0:
            break
        out_entry_i[k] = fill_i; out_exit_i[k] = ex_i; out_dir[k] = d
        out_pnl[k] = (exit_p - fp) * d - comm; out_risk[k] = risk; out_mae[k] = mae; out_reason[k] = reason
        k += 1
        busy_until = ex_i
    return out_entry_i[:k], out_exit_i[:k], out_dir[:k], out_pnl[:k], out_risk[:k], out_mae[:k], out_reason[:k]

def run(D, sig, be=0.0):
    """sig: dict of arrays sig_i, dir, otype, price, sl, rr, tpabs, expiry, maxhold (sorted by sig_i)."""
    o = np.argsort(sig["sig_i"], kind="stable")
    g = lambda k, dt=np.float64: np.ascontiguousarray(np.asarray(sig[k])[o], dtype=dt)
    ns = len(o)
    r = simulate(D["bo"], D["bh"], D["bl"], D["bc"], D["ao"], D["ah"], D["al"], D["ac"], D["flat"],
                 g("sig_i", np.int64), g("dir", np.int64), g("otype", np.int64), g("price"), g("sl"), g("rr"),
                 g("tpabs"), g("expiry", np.int64), g("maxhold", np.int64), np.full(ns, be),
                 COMM, SLIP, MAX_STOP, MIN_STOP)
    t = pd.DataFrame(dict(entry_i=r[0], exit_i=r[1], dir=r[2], pnl=r[3], risk=r[4], mae=r[5], reason=r[6]))
    t["R"] = t.pnl / t.risk
    t["time"] = D["utc"][t.entry_i.values]
    t["tday"] = D["tday"][t.entry_i.values]
    return t

def metrics(t):
    if len(t) == 0:
        return dict(n=0, pf=np.nan, expR=np.nan, wr=np.nan, totR=0, ddR=0, maxLS=0, t=np.nan)
    R = t.R.values
    gp = R[R > 0].sum(); gl = -R[R < 0].sum()
    eq = np.cumsum(R); dd = (np.maximum.accumulate(np.concatenate([[0], eq]))[1:] - eq).max()
    ls = 0; c = 0
    for x in R:
        c = c + 1 if x < 0 else 0; ls = max(ls, c)
    tt = R.mean() / (R.std(ddof=1) / np.sqrt(len(R))) if len(R) > 2 and R.std() > 0 else np.nan
    return dict(n=len(R), pf=gp / gl if gl > 0 else np.inf, expR=R.mean(), wr=(R > 0).mean(), totR=R.sum(),
                ddR=dd, maxLS=ls, t=tt)
