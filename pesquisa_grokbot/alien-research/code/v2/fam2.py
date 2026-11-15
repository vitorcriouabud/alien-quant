"""V2 families. Each returns kwargs for engine2.run (ent, exl, exs, stopk, rr, trailk, maxbars)."""
import numpy as np, pandas as pd

def rsi(c, n):
    d = c.diff(); up = d.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean(); dn = (-d.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    return 100 - 100 / (1 + up / dn)

def donchian(r, N, exitN, stopk, trail, volf=False):
    hh = r.high.rolling(N).max().shift(1); ll = r.low.rolling(N).min().shift(1)
    ent = np.where(r.close > hh, 1, np.where(r.close < ll, -1, 0))
    if volf:
        ent = np.where(r.atr > r.atr.rolling(100).mean(), ent, 0)
    exl = (r.close < r.low.rolling(exitN).min().shift(1)).values
    exs = (r.close > r.high.rolling(exitN).max().shift(1)).values
    return dict(ent=ent, exl=exl, exs=exs, stopk=stopk, trailk=stopk if trail else 0.0)

def macross(r, f, s, stopk):
    a = r.close.ewm(span=f, adjust=False).mean(); b = r.close.ewm(span=s, adjust=False).mean()
    up = (a > b) & (a.shift(1) <= b.shift(1)); dn = (a < b) & (a.shift(1) >= b.shift(1))
    ent = np.where(up, 1, np.where(dn, -1, 0))
    return dict(ent=ent, exl=(a < b).values, exs=(a > b).values, stopk=stopk)

def tsmom(r, L, stopk):
    m = r.close / r.close.shift(L) - 1
    s = np.sign(m).fillna(0)
    ent = np.where((s != s.shift(1)) | True, s, 0)  # enter whenever flat in the sign direction
    return dict(ent=ent.astype(int), exl=(m < 0).values, exs=(m > 0).values, stopk=stopk)

def rsi2(r, th, stopk, shorts=True):
    x = rsi(r.close, 2); sma200 = r.close.rolling(200).mean(); sma5 = r.close.rolling(5).mean()
    lg = (r.close > sma200) & (x < th); sh = (r.close < sma200) & (x > 100 - th)
    ent = np.where(lg, 1, np.where(sh & shorts, -1, 0))
    return dict(ent=ent, exl=(r.close > sma5).values, exs=(r.close < sma5).values, stopk=stopk, maxbars=10)

def ibs(r, th, stopk):
    v = (r.close - r.low) / (r.high - r.low).replace(0, np.nan)
    sma200 = r.close.rolling(200).mean()
    ent = np.where((v < th) & (r.close > sma200), 1, 0)
    return dict(ent=ent, exl=(r.close > r.high.shift(1)).values, exs=None, stopk=stopk, maxbars=5)

def bbrev(r, k, stopk):
    m = r.close.rolling(20).mean(); s = r.close.rolling(20).std()
    lg = (r.close.shift(1) < (m - k * s).shift(1)) & (r.close > m - k * s)
    sh = (r.close.shift(1) > (m + k * s).shift(1)) & (r.close < m + k * s)
    ent = np.where(lg, 1, np.where(sh, -1, 0))
    return dict(ent=ent, exl=(r.close > m).values, exs=(r.close < m).values, stopk=stopk, maxbars=48)

def tod(r, d, hour, hold, stopk):
    """H1 only: enter at the OPEN of the bar starting at NY `hour` (signal on prior bar close), hold `hold` bars."""
    nxt_hour = pd.Series(r.index.hour, index=r.index).shift(-1)
    ent = np.where(nxt_hour.values == hour, d, 0)
    return dict(ent=ent, stopk=stopk, maxbars=hold)

def asia_bo(r, rr):
    """H1: range 19:00-02:00 NY; first H1 close beyond range between 02:00-10:00 -> enter next open; SL opposite side."""
    idx = r.index; hr = idx.hour
    day = (idx + pd.Timedelta(hours=5)).normalize()   # 19:00 NY belongs to next day
    asia = (hr >= 19) | (hr < 2)
    g = pd.DataFrame(dict(h=r.high.where(asia), l=r.low.where(asia), day=day)).groupby("day").agg(h=("h", "max"), l=("l", "min"))
    H = g.h.reindex(day).values; L = g.l.reindex(day).values
    win = (hr >= 2) & (hr < 10)
    up = win & (r.close.values > H); dn = win & (r.close.values < L)
    first = pd.Series(up | dn, index=idx).groupby(day).cumsum().values == 1
    ent = np.where(first & up, 1, np.where(first & dn, -1, 0))
    W = H - L
    # stop distance = distance from close to opposite side, expressed via stopk*atr -> encode with custom atr
    return dict(ent=ent, rr=rr, maxbars=8, _custom_dist=np.where(ent == 1, r.close.values - L, H - r.close.values))
