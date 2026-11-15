import sys, numpy as np, pandas as pd; sys.path.insert(0, '.'); import tsmom as t
P, S = t.load()
IS = slice("2011-01-01", "2024-12-31"); VA = slice("2025-01-01", "2025-12-31")
rules = ["M3", "M6", "M12", "MB", "D50", "D100"]
rows = []; daily = {}
bl = t.backtest(P, S, "LONG")["net"]
for r in rules:
    b = t.backtest(P, S, r); n = b["net"]; daily[r] = n
    s = t.stats_(n[IS]); yr = (1 + n[IS]).groupby(n[IS].index.year).prod() - 1
    eq = (1 + n[IS]).prod(); ex_best = (eq / (1 + yr.max())) ** (1 / (len(n[IS]) / 252 - 1)) - 1
    c = b["contrib"]; c = c.groupby(lambda x: x).sum()
    # contrib computed full sample; use IS only
    held = b["pos"].shift(1).fillna(0); ret = P.ffill().pct_change().fillna(0)
    cIS = (held * ret)[IS].sum(); best_mkt = cIS.idxmax()
    sd = t.stats_(t.backtest(P, S, r, drop=best_mkt)["net"][IS])["sharpe"]
    sc = t.stats_(t.backtest(P, S, r, cost_mult=1.5, swap_extra=0.01)["net"][IS])["sharpe"]
    scr = t.stats_(t.backtest(P, S, r, credit=0.5)["net"][IS])["sharpe"]
    x = pd.concat([n[IS], bl[IS]], axis=1).dropna(); beta, alpha = np.polyfit(x.iloc[:, 1], x.iloc[:, 0], 1)
    res = np.polyfit  # alpha annualized
    va = (1 + n[VA]).prod() - 1
    rows.append(dict(id=r, IS_cagr=s["cagr"], IS_vol=s["vol"], IS_sharpe=s["sharpe"], IS_t=s["t"], IS_mdd=s["mdd"],
                     yrs_pos=int((yr > 0).sum()), ex_best_year_cagr=ex_best, best_mkt=best_mkt, sharpe_ex_best_mkt=sd,
                     sharpe_cost15_swap1=sc, sharpe_credit_half=scr, alpha_ann_vs_long=alpha * 252, beta_vs_long=beta,
                     gross_IS_ann=b["gross"][IS].mean() * 252, tc_IS_ann=b["tc"][IS].mean() * 252, swap_IS_ann=b["sw"][IS].mean() * 252,
                     turnover_IS=b["pos"].diff().abs().sum(axis=1)[IS].mean() * 252, VA_2025=va,
                     years=" ".join(f"{k%100:02d}:{v:+.1%}" for k, v in yr.items())))
D = pd.DataFrame(rows)
from scipy import stats as st
D["p"] = 1 - st.norm.cdf(D.IS_t)
def bh(p, a):
    p = np.asarray(p); o = np.argsort(p); m = len(p); ok = p[o] <= a * np.arange(1, m + 1) / m
    k = np.max(np.where(ok)[0]) + 1 if ok.any() else 0; r = np.zeros(m, bool); r[o[:k]] = True; return r
D["BH10"] = bh(D.p, 0.10); D["Bonf"] = D.p < 0.05 / 6
D["c1"] = (D.IS_t >= 2) & D.BH10; D["c2"] = D.yrs_pos >= 9; D["c3"] = D.ex_best_year_cagr > 0; D["c4"] = D.sharpe_ex_best_mkt >= 0.3
D["c5"] = D.sharpe_cost15_swap1 >= 0.3; D["c6"] = D.VA_2025 >= -0.05; D["c7"] = D.alpha_ann_vs_long > 0
D["survivor"] = D[[f"c{i}" for i in range(1, 8)]].all(axis=1)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(D.drop(columns=["years"]).round(3).to_string()); print(D[["id", "years"]].to_string())
sl = t.stats_(bl[IS]); print("LONG benchmark IS", {k: round(v, 3) for k, v in sl.items()}, "2025", round((1 + bl[VA]).prod() - 1, 3))
D.to_csv("/workspace/alien-research/out/tendencia/summary.csv", index=False)
pd.DataFrame(daily).assign(LONG=bl).to_parquet("/workspace/alien-research/out/tendencia/daily_ALL.parquet")  # contains 2026: not read until survivors
