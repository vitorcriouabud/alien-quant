"""'Mitos testados': event study of popular concepts vs drift-matched baseline, net of costs.
Signal at close of bar i (direction d) -> enter next open, exit at open H bars later. Excess = d*fwd - d*mean_fwd(all bars).
"""
import sys, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/smc"); sys.path.insert(0, "/workspace/alien-research/code/v2")
import smc, engine2
MK = ["xauusd", "eurusd", "gbpusd", "usa500idxusd", "usatechidxusd", "deuidxeur"]
NAME = dict(xauusd="XAUUSD", eurusd="EURUSD", gbpusd="GBPUSD", usa500idxusd="US500", usatechidxusd="NAS100", deuidxeur="DE40")
COST = dict(xauusd=1.2, eurusd=0.9, gbpusd=1.25, usa500idxusd=1.1, usatechidxusd=1.6, deuidxeur=1.5)   # round-trip bp (spread+comm)
H = {"M15": 8, "H1": 8, "D1": 3}   # holding bars

def bars(f, rule, shift=0):
    g = f.copy(); g.index = g.index + pd.Timedelta(hours=shift)
    agg = dict(o="first", h="max", l="min", c="last"); 
    if "v" in g: agg["v"] = "sum"
    r = g.resample(rule).agg(agg).dropna(subset=["o"]); r.index = r.index - pd.Timedelta(hours=shift)
    pc = r.c.shift(1); tr = np.maximum(r.h - r.l, np.maximum((r.h - pc).abs(), (r.l - pc).abs())); r["atr"] = tr.rolling(14).mean()
    return r

def rsi(c, n=14):
    d = c.diff(); u = d.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean(); dn = (-d.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    return 100 - 100 / (1 + u / dn)

def fractals(r):
    h, l = r.h.values, r.l.values; n = len(h)
    fh = np.zeros(n, bool); fl = np.zeros(n, bool)
    fh[2:-2] = (h[2:-2] > h[1:-3]) & (h[2:-2] > h[:-4]) & (h[2:-2] >= h[3:-1]) & (h[2:-2] >= h[4:])
    fl[2:-2] = (l[2:-2] < l[1:-3]) & (l[2:-2] < l[:-4]) & (l[2:-2] <= l[3:-1]) & (l[2:-2] <= l[4:])
    # confirmed 2 bars later: last confirmed swing level as of bar i
    sh = pd.Series(np.where(fh, h, np.nan)).shift(2).ffill().values
    sl = pd.Series(np.where(fl, l, np.nan)).shift(2).ffill().values
    return sh, sl

def concepts(r, tf):
    o, h, l, c, a = (r[k].values for k in ("o", "h", "l", "c", "atr")); n = len(c); S = {}
    body = c - o; rng = h - l
    sh, sl = fractals(r)
    bos_up = (c > sh) & (np.roll(c, 1) <= np.roll(sh, 1)); bos_dn = (c < sl) & (np.roll(c, 1) >= np.roll(sl, 1))
    S["SMC: BOS (rompimento de estrutura, a favor)"] = np.where(bos_up, 1, np.where(bos_dn, -1, 0))
    # CHoCH: first break against the last BOS direction
    st = np.zeros(n); t = 0; ch = np.zeros(n, int)
    for i in range(n):
        if bos_up[i]:
            if t == -1: ch[i] = 1
            t = 1
        elif bos_dn[i]:
            if t == 1: ch[i] = -1
            t = -1
        st[i] = t
    S["SMC: CHoCH (mudança de caráter)"] = ch
    # Order block retest: after BOS up, last down candle within 10 bars before; first return into it within 48 bars
    ob = np.zeros(n, int)
    for i in np.nonzero(bos_up | bos_dn)[0]:
        d = 1 if bos_up[i] else -1
        ks = [k for k in range(max(0, i - 10), i) if (body[k] < 0 if d == 1 else body[k] > 0)]
        if not ks: continue
        k = ks[-1]; top, bot = max(o[k], c[k]), min(o[k], c[k])
        for j in range(i + 1, min(n, i + 48)):
            if d == 1 and l[j] <= top and c[j] >= bot: ob[j] = 1; break
            if d == -1 and h[j] >= bot and c[j] <= top: ob[j] = -1; break
    S["SMC: Order Block (reteste)"] = ob
    # FVG retest
    fv = np.zeros(n, int)
    for i in range(2, n):
        if l[i] > h[i - 2]: d, prox, far = 1, l[i], h[i - 2]
        elif h[i] < l[i - 2]: d, prox, far = -1, h[i], l[i - 2]
        else: continue
        for j in range(i + 1, min(n, i + 48)):
            if d == 1 and l[j] <= prox:
                if c[j] >= far: fv[j] = 1
                break
            if d == -1 and h[j] >= prox:
                if c[j] <= far: fv[j] = -1
                break
    S["SMC: FVG (reteste do gap)"] = fv
    ph = pd.Series(h).shift(1).rolling(20).max().values; pl = pd.Series(l).shift(1).rolling(20).min().values
    S["SMC: Sweep de liquidez (20 barras) e reversão"] = np.where((h > ph) & (c < ph), -1, np.where((l < pl) & (c > pl), 1, 0))
    hi50 = pd.Series(h).rolling(50).max().values; lo50 = pd.Series(l).rolling(50).min().values; pos = (c - lo50) / (hi50 - lo50)
    ema200 = pd.Series(c).ewm(span=200, adjust=False).mean().values
    S["SMC: Premium/Discount + tendência"] = np.where((pos < 0.25) & (c > ema200), 1, np.where((pos > 0.75) & (c < ema200), -1, 0))
    e20 = pd.Series(c).ewm(span=20, adjust=False).mean().values; e50 = pd.Series(c).ewm(span=50, adjust=False).mean().values
    up = (e20 > e50) & (np.roll(e20, 1) <= np.roll(e50, 1)); dn = (e20 < e50) & (np.roll(e20, 1) >= np.roll(e50, 1))
    S["Cruzamento de médias EMA20/50"] = np.where(up, 1, np.where(dn, -1, 0))
    sma200 = pd.Series(c).rolling(200).mean().values
    S["Preço acima/abaixo da média 200 (seguir)"] = np.where(c > sma200, 1, np.where(c < sma200, -1, 0))
    R = rsi(r.c).values
    S["RSI14 sobrevendido<30 / sobrecomprado>70 (reverter)"] = np.where(R < 30, 1, np.where(R > 70, -1, 0))
    lo20 = pd.Series(l).rolling(20).min().values; hi20 = pd.Series(h).rolling(20).max().values
    div = np.zeros(n, int)
    for i in range(25, n):
        if l[i] <= lo20[i]:
            k = i - 5 - np.argmin(l[i - 20:i - 4][::-1]) if False else (i - 20 + np.argmin(l[i - 20:i - 4]))
            if R[i] > R[k] + 3: div[i] = 1
        elif h[i] >= hi20[i]:
            k = i - 20 + np.argmax(h[i - 20:i - 4])
            if R[i] < R[k] - 3: div[i] = -1
    S["Divergência RSI (reverter)"] = div
    m = pd.Series(c).ewm(span=12, adjust=False).mean() - pd.Series(c).ewm(span=26, adjust=False).mean(); sg = m.ewm(span=9, adjust=False).mean()
    m, sg = m.values, sg.values
    S["MACD cruzando a linha de sinal"] = np.where((m > sg) & (np.roll(m, 1) <= np.roll(sg, 1)), 1, np.where((m < sg) & (np.roll(m, 1) >= np.roll(sg, 1)), -1, 0))
    ll14 = pd.Series(l).rolling(14).min(); hh14 = pd.Series(h).rolling(14).max(); k_ = (100 * (pd.Series(c) - ll14) / (hh14 - ll14)).rolling(3).mean(); d_ = k_.rolling(3).mean()
    k_, d_ = k_.values, d_.values
    S["Estocástico cruzando <20 / >80 (reverter)"] = np.where((k_ > d_) & (np.roll(k_, 1) <= np.roll(d_, 1)) & (k_ < 20), 1, np.where((k_ < d_) & (np.roll(k_, 1) >= np.roll(d_, 1)) & (k_ > 80), -1, 0))
    bm = pd.Series(c).rolling(20).mean().values; bs = pd.Series(c).rolling(20).std().values
    S["Bollinger: fechou fora da banda (reverter)"] = np.where(c < bm - 2 * bs, 1, np.where(c > bm + 2 * bs, -1, 0))
    po, pc_ = np.roll(o, 1), np.roll(c, 1)
    S["Candle: engolfo (engulfing)"] = np.where((pc_ < po) & (c > o) & (c >= po) & (o <= pc_), 1, np.where((pc_ > po) & (c < o) & (c <= po) & (o >= pc_), -1, 0))
    lw = np.minimum(o, c) - l; uw = h - np.maximum(o, c)
    S["Candle: pin bar / martelo"] = np.where((lw >= 0.66 * rng) & (rng > 0.8 * a), 1, np.where((uw >= 0.66 * rng) & (rng > 0.8 * a), -1, 0))
    mv3 = c - np.roll(c, 3)
    S["Candle: doji após 3 barras (reverter)"] = np.where((np.abs(body) < 0.1 * rng) & (rng > 0) & (mv3 > a), -1, np.where((np.abs(body) < 0.1 * rng) & (rng > 0) & (mv3 < -a), 1, 0))
    inside_prev = (np.roll(h, 1) < np.roll(h, 2)) & (np.roll(l, 1) > np.roll(l, 2))
    S["Candle: rompimento de inside bar"] = np.where(inside_prev & (c > np.roll(h, 2)), 1, np.where(inside_prev & (c < np.roll(l, 2)), -1, 0))
    b1 = np.roll(body, 2); b2 = np.roll(body, 1); avgb = pd.Series(np.abs(body)).rolling(20).mean().values
    mid1 = (np.roll(o, 2) + np.roll(c, 2)) / 2
    S["Candle: estrela da manhã/tarde"] = np.where((b1 < -avgb) & (np.abs(b2) < 0.3 * avgb) & (body > 0) & (c > mid1), 1, np.where((b1 > avgb) & (np.abs(b2) < 0.3 * avgb) & (body < 0) & (c < mid1), -1, 0))
    S["Suporte/Resistência: rejeição em topo/fundo anterior"] = np.where((np.abs(h - sh) < 0.1 * a) & (c < sh), -1, np.where((np.abs(l - sl) < 0.1 * a) & (c > sl), 1, 0))
    # Fibonacci 61.8-78.6 of last swing (fractal low->high), impulse > 2 ATR
    fib = np.zeros(n, int)
    for i in range(1, n):
        if np.isfinite(sh[i]) and np.isfinite(sl[i]) and sh[i] - sl[i] > 2 * a[i]:
            z1, z2 = sh[i] - 0.786 * (sh[i] - sl[i]), sh[i] - 0.618 * (sh[i] - sl[i])
            if l[i] <= z2 and l[i] >= z1 and c[i] > z1 and l[i - 1] > z2: fib[i] = 1
            y1, y2 = sl[i] + 0.618 * (sh[i] - sl[i]), sl[i] + 0.786 * (sh[i] - sl[i])
            if h[i] >= y1 and h[i] <= y2 and c[i] < y2 and h[i - 1] < y1: fib[i] = -1 if fib[i] == 0 else 0
    S["Fibonacci 61,8–78,6% (reverter na zona)"] = fib
    if tf != "D1":
        # pivots from previous trading day
        td = (r.index - pd.Timedelta(hours=18)).normalize()
        dd = pd.DataFrame(dict(h=h, l=l, c=c, td=td)).groupby("td").agg(h=("h", "max"), l=("l", "min"), c=("c", "last")).shift(1)
        P = ((dd.h + dd.l + dd.c) / 3).reindex(td).values; R1 = 2 * P - dd.l.reindex(td).values; S1 = 2 * P - dd.h.reindex(td).values
        S["Pivot points: rejeição em S1/R1"] = np.where((l <= S1) & (c > S1), 1, np.where((h >= R1) & (c < R1), -1, 0))
        hm = r.index.hour
        S["ICT: kill zone Londres (02–05h NY) — sweep da Ásia e reversão"] = np.zeros(n, int)
        asia = pd.DataFrame(dict(h=np.where((hm >= 19), h, np.nan), l=np.where((hm >= 19), l, np.nan), td=td)).groupby("td").agg(h=("h", "max"), l=("l", "min"))
        AH, AL = asia.h.reindex(td).values, asia.l.reindex(td).values
        kz = (hm >= 2) & (hm < 5)
        S["ICT: kill zone Londres (02–05h NY) — sweep da Ásia e reversão"] = np.where(kz & (l < AL) & (c > AL), 1, np.where(kz & (h > AH) & (c < AH), -1, 0))
    if "v" in r and r.v.notna().any() and tf == "H1":
        v = r.v.values; va = pd.Series(v).rolling(20).mean().shift(1).values
        S["Pico de volume (tick) a favor do candle"] = np.where((v > 3 * va) & (body > 0), 1, np.where((v > 3 * va) & (body < 0), -1, 0))
        pv = pd.DataFrame(dict(pv=c * v, v=v, td=(r.index - pd.Timedelta(hours=18)).normalize())); vw = (pv.groupby("td").pv.cumsum() / pv.groupby("td").v.cumsum()).values
        S["VWAP da sessão: longe >1,5 ATR (reverter)"] = np.where(c < vw - 1.5 * a, 1, np.where(c > vw + 1.5 * a, -1, 0))
    return S

def evaluate(r, S, Hb, cost):
    op = r.o.values; n = len(op)
    fwd = np.full(n, np.nan); fwd[:n - Hb - 1] = np.log(op[1 + Hb:n] / op[1:n - Hb]) * 1e4
    per = np.where(r.index.year >= 2026, "2026", "2021-25"); rows = []
    for name, sig in S.items():
        for p in ("2021-25", "2026"):
            m = (per == p) & np.isfinite(fwd); base = np.nanmean(fwd[m])
            k = m & (sig != 0)
            if k.sum() < 30: rows.append(dict(concept=name, period=p, n=int(k.sum()))); continue
            g = sig[k] * fwd[k]; ex = g - sig[k] * base
            rows.append(dict(concept=name, period=p, n=int(k.sum()), gross_bp=g.mean(), excess_bp=ex.mean(), t_excess=ex.mean() / ex.std() * np.sqrt(len(ex)),
                             net_bp=g.mean() - cost, hit=(g > 0).mean()))
    return rows

if __name__ == "__main__":
    out = []
    for sym in MK:
        print(NAME[sym], flush=True)
        if sym != "deuidxeur":
            D = smc.load_m1(sym); f = pd.DataFrame(dict(o=D["mo"], h=D["mh"], l=D["ml"], c=D["mc"]), index=D["ny"])
            TF = {"M15": bars(f, "15min"), "H1": bars(f, "1h"), "D1": bars(f, "1D", 7)}
        else:
            h1 = engine2.load_h1(sym).rename(columns=dict(open="o", high="h", low="l", close="c")); h1 = h1[h1.index >= "2021-01-01"]
            TF = {"H1": bars(h1, "1h"), "D1": bars(h1, "1D", 7)}
        vv = pd.read_csv(f"/workspace/alien-research/data/vol/{sym}_h1v.csv")
        vv.index = pd.DatetimeIndex(pd.to_datetime(vv.timestamp, unit="ms", utc=True)).tz_convert("America/New_York")
        TF["H1"]["v"] = vv.volume.reindex(TF["H1"].index)
        TF["D1"] = TF["D1"][TF["D1"].index.day_of_week != 5]
        for tf, r in TF.items():
            for row in evaluate(r, concepts(r, tf), H[tf], COST[sym]):
                row.update(mkt=NAME[sym], tf=tf); out.append(row)
    pd.DataFrame(out).to_csv("/workspace/alien-research/out/mercado/myths.csv", index=False); print("done")
