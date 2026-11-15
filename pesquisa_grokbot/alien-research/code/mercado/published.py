"""Published anomalies tested on our data, net of costs (round-trip spread/comm + swap per night held)."""
import sys, re, numpy as np, pandas as pd
sys.path.insert(0, "/workspace/alien-research/code/v2"); sys.path.insert(0, "/workspace/alien-research/code/smc")
import engine2, smc
from pandas.tseries.holiday import USFederalHolidayCalendar
COST = dict(xauusd=1.2, eurusd=0.9, gbpusd=1.25, usdjpy=1.4, usa500idxusd=1.1, usatechidxusd=1.6, deuidxeur=1.5)
SWAPL = dict(xauusd=-5.0, eurusd=-3.0, gbpusd=-2.0, usdjpy=1.0, usa500idxusd=-7.2, usatechidxusd=-7.2, deuidxeur=-7.2)   # %/yr long
N = dict(xauusd="XAUUSD", eurusd="EURUSD", gbpusd="GBPUSD", usdjpy="USDJPY", usa500idxusd="US500", usatechidxusd="NAS100", deuidxeur="DE40")
rows = []
def rep(effect, sym, r_bp, nights, when, note=""):
    """r_bp: Series of gross long (or signed) trade returns in bp indexed by time."""
    r = r_bp.dropna(); net = r - COST[sym] + SWAPL[sym] / 365 * 1e2 * nights   # swap bp per night = %/yr/365*100
    for p, m in (("IS", r.index.year < 2026), ("2026", r.index.year >= 2026)):
        x, y = r[m], net[m]
        if len(x) < 5: continue
        rows.append(dict(effect=effect, mkt=N[sym], period=p, n=len(x), gross_bp=x.mean(), net_bp=y.mean(), t_gross=x.mean() / x.std() * np.sqrt(len(x)),
                         t_net=y.mean() / y.std() * np.sqrt(len(y)), hit=(y > 0).mean(), when=when, note=note))
H1 = {s: engine2.load_h1(s) for s in COST}
D1 = {}
for s, h in H1.items():
    d = engine2.resample(h, "D1"); d.index = (d.index + pd.Timedelta(hours=7)).normalize().tz_localize(None)  # label = trading date
    d = d[d.index.dayofweek < 5]; d["r"] = np.log(d.close / d.close.shift(1)) * 1e4; D1[s] = d
IDX = ["usa500idxusd", "usatechidxusd", "deuidxeur"]
# 1 Turn of month: long close of 2nd-last trading day -> close of 3rd trading day
for s in IDX + ["xauusd"]:
    d = D1[s]; ym = d.index.to_period("M"); pos = d.groupby(ym).cumcount(); neg = d.groupby(ym).cumcount(ascending=False)
    ent = d.index[neg == 1]; out = []
    for e in ent:
        nxt = d.index[(d.index > e)]; k = nxt[(nxt.to_period("M") > e.to_period("M"))][:3]
        if len(k) == 3: out.append((k[-1], np.log(d.close[k[-1]] / d.close[e]) * 1e4, (k[-1] - e).days))
    x = pd.Series([o[1] for o in out], index=pd.DatetimeIndex([o[0] for o in out]))
    rep("Virada do mês (TOM)", s, x, np.mean([o[2] for o in out]), "fechamento penúltimo dia útil → 3º dia útil")
# 2 Overnight vs intraday (US indices): 16:00->10:00 vs 10:00->16:00 NY (H1)
for s in ["usa500idxusd", "usatechidxusd"]:
    h = H1[s]; o10 = h.open[(h.index.hour == 10)]; c16 = h.close[(h.index.hour == 15)]   # bar 15:00-16:00 close = 16:00
    o10.index = o10.index.normalize(); c16.index = c16.index.normalize()
    intra = (np.log(c16 / o10.reindex(c16.index)) * 1e4).dropna()
    night = (np.log(o10 / c16.shift(1).reindex(o10.index)) * 1e4)
    c16s = c16.copy(); nxt_o = o10.reindex(c16.index).shift(-1)
    night = (np.log(nxt_o / c16) * 1e4).dropna(); night.index = night.index.tz_localize(None); intra.index = intra.index.tz_localize(None)
    rep("Overnight (16h→10h NY, comprado)", s, night, 1.4, "fechamento 16h → 10h do dia seguinte")
    rep("Intraday (10h→16h NY, comprado)", s, intra, 0, "10h → 16h")
# 3 Pre-holiday (NYSE approx: federal holidays except Columbus/Veterans + Good Friday)
hol = USFederalHolidayCalendar().holidays("2015-01-01", "2026-12-31")
hol = hol[~((hol.month == 10) | (hol.month == 11) & (hol.day < 20))]
from dateutil.easter import easter
gf = pd.DatetimeIndex([pd.Timestamp(easter(y)) - pd.Timedelta(days=2) for y in range(2015, 2027)])
hol = hol.union(gf)
for s in ["usa500idxusd", "usatechidxusd"]:
    d = D1[s]; pre = [d.index[d.index < hd].max() for hd in hol if (d.index < hd).any() and hd > d.index[0]]
    pre = pd.DatetimeIndex(sorted(set(pre))); rep("Véspera de feriado (EUA)", s, d.r.reindex(pre), 1, "dia útil antes do feriado (fech.→fech.)")
# 4 Pre-FOMC drift: 14:00 NY day before announcement -> 14:00 announcement day (2021-2026 calendar from federalreserve.gov)
html = open("/workspace/alien-research/data/fomc.html", encoding="utf-8", errors="ignore").read(); ann = []
MON = {m: i for i, m in enumerate(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], 1)}
for ym in re.finditer(r'(\d{4}) FOMC Meetings(.*?)(?=\d{4} FOMC Meetings|$)', html, re.S):
    y = int(ym.group(1))
    for m in re.finditer(r'fomc-meeting__month[^>]*>\s*<strong>([A-Za-z/]+)</strong>.*?fomc-meeting__date[^>]*>([^<]+)<', ym.group(2), re.S):
        mon, dt = m.group(1), m.group(2)
        if "notation" in dt or "-" not in dt: continue
        d2 = int(re.sub(r"\D", "", dt.split("-")[1])); mm = MON[mon] if mon in MON else None
        if "/" in mon: mm = MON[{"Jan": "January", "Feb": "February", "Mar": "March", "Apr": "April", "May": "May", "Jun": "June", "Jul": "July", "Aug": "August", "Sep": "September", "Oct": "October", "Nov": "November", "Dec": "December"}[mon.split("/")[1]]]
        ann.append(pd.Timestamp(y, mm, d2))
ann = [a for a in ann if a < pd.Timestamp("2026-11-13")]
for s in IDX:
    h = H1[s]; o14 = h.open[h.index.hour == 14]; o14.index = o14.index.normalize().tz_localize(None)
    x = {}
    for a in ann:
        prev = o14.index[o14.index < a]
        if a in o14.index and len(prev): x[a] = np.log(o14[a] / o14[prev[-1]]) * 1e4
    rep("Drift pré-FOMC (14h véspera → 14h dia)", s, pd.Series(x), 1, "2021–2026 (calendário Fed)")
# 7 Short-term reversal FX daily (fade yesterday)
for s in ["eurusd", "gbpusd", "usdjpy", "xauusd"]:
    d = D1[s]; sig = -np.sign(d.r.shift(1)); g = sig * d.r
    rows_n = g.dropna()
    rep("Reversão de 1 dia (FX/ouro, contra ontem)", s, rows_n, 1, "D1")
# 9 Gold autumn effect (Sep+Nov long)
d = D1["xauusd"]; mo = d.close.resample("ME").last(); mr = np.log(mo / mo.shift(1)) * 1e4
rep("Ouro: efeito outono (setembro+novembro)", "xauusd", mr[mr.index.month.isin([9, 11])], 30, "mês inteiro comprado")
rep("Ouro: demais meses (controle)", "xauusd", mr[~mr.index.month.isin([9, 11])], 30, "controle")
# 10 Monday / weekend: Fri close -> Mon close
for s in IDX + ["xauusd"]:
    d = D1[s]; mon = d.r[d.index.dayofweek == 0]; rep("Segunda-feira (sexta fech. → segunda fech.)", s, mon, 3, "D1")
    oth = d.r[d.index.dayofweek != 0]; rep("Outros dias (controle)", s, oth, 1, "D1")
# 11 Halloween (Nov-Apr long vs May-Oct)
for s in IDX:
    d = D1[s]; w = d.r[d.index.month.isin([11, 12, 1, 2, 3, 4])]; sm = d.r[~d.index.month.isin([11, 12, 1, 2, 3, 4])]
    rep("Halloween: nov–abr (por dia)", s, w, 1.4, "D1"); rep("Halloween: mai–out (por dia, controle)", s, sm, 1.4, "D1")
pd.DataFrame(rows).to_csv("/workspace/alien-research/out/mercado/published.csv", index=False)
# 8 Intraday momentum (Gao et al. 2018) on M1 2021-2026: sign(prev 16:00 close -> 10:00) -> trade 15:30->16:00
for s in ["usa500idxusd", "usatechidxusd"]:
    D = smc.load_m1(s); f = pd.Series(D["mc"], index=D["ny"]); fo = pd.Series(D["mo"], index=D["ny"])
    t = f.index; hm = t.hour * 60 + t.minute
    c1600 = f[hm == 15 * 60 + 59]; c1000 = f[hm == 9 * 60 + 59]; o1530 = fo[hm == 15 * 60 + 30]
    for z in (c1600, c1000, o1530): z.index = z.index.normalize().tz_localize(None)
    r1 = np.log(c1000 / c1600.shift(1)) * 1e4; last = np.log(c1600 / o1530) * 1e4
    j = pd.concat([r1, last], axis=1, keys=["r1", "last"]).dropna(); g = np.sign(j.r1) * j["last"]
    rep("Momentum intradiário (1ª meia hora → última meia hora)", s, g, 0, "M1 2021–2026")
pd.DataFrame(rows).to_csv("/workspace/alien-research/out/mercado/published.csv", index=False)
P = pd.DataFrame(rows); pd.set_option("display.width", 250); pd.set_option("display.max_rows", 200)
print(P[["effect", "mkt", "period", "n", "gross_bp", "net_bp", "t_gross", "t_net", "hit"]].round(2).to_string())
