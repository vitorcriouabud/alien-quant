"""Sinais no fechamento. Nenhum índice futuro entra na decisão do candle t."""

from __future__ import annotations

import numpy as np
import pandas as pd

from alienlab.data import LabConfig
from alienlab.definitions import CANONICAL_RULES


def hypothesis_ids() -> list[str]:
    return [r["id"] for r in CANONICAL_RULES]


def pairs() -> list[tuple[str, str, str]]:
    """(core_id, confluence_or_control_id, kind)."""
    out = []
    for rule in CANONICAL_RULES:
        if "pairs_with" in rule:
            kind = "control" if rule["role"] == "control" else "confluence"
            out.append((rule["pairs_with"], rule["id"], kind))
    return out


def _emit(rows: list[dict], idx: np.ndarray, side: int, hypothesis_id: str) -> None:
    for i in idx:
        rows.append({"signal_idx": int(i), "side": side, "hypothesis_id": hypothesis_id})


def h14_mask(o: np.ndarray, c: np.ndarray, upper: np.ndarray) -> np.ndarray:
    """H14 original: venda. Não reutilizar este nome para outra regra."""
    prev_c = np.roll(c, 1)
    prev_upper = np.roll(upper, 1)
    prev_c = prev_c.astype(float, copy=True)
    prev_upper = prev_upper.astype(float, copy=True)
    prev_c[0] = np.nan
    prev_upper[0] = np.nan
    return (
        np.isfinite(prev_c)
        & np.isfinite(prev_upper)
        & np.isfinite(upper)
        & (prev_c > prev_upper)
        & (c < upper)
        & (c < o)
    )


def h16_mask(
    o: np.ndarray,
    c: np.ndarray,
    lower: np.ndarray,
    ema9: np.ndarray,
    ema21: np.ndarray,
    relvol: np.ndarray,
    relvol_min: float,
    require_volume: bool,
) -> np.ndarray:
    """H16 original quando require_volume=True. Sem volume é D_H16_NO_VOL, outro ID."""
    base = (
        np.isfinite(lower)
        & np.isfinite(ema9)
        & np.isfinite(ema21)
        & (c < o)
        & (c <= lower)
        & (ema9 < ema21)
    )
    if not require_volume:
        return base
    return base & np.isfinite(relvol) & (relvol > relvol_min)


def _finite(*cols: np.ndarray) -> np.ndarray:
    mask = np.ones(len(cols[0]), dtype=bool)
    for col in cols:
        mask &= np.isfinite(col)
    return mask


def generate_signals(data: dict[str, np.ndarray], feat: dict[str, np.ndarray], cfg: LabConfig) -> pd.DataFrame:
    o, h, l, c = data["open"], data["high"], data["low"], data["close"]
    n = len(c)
    ts = pd.to_datetime(data["time_utc_ns"])
    rows: list[dict] = []

    ok_cq = _finite(feat["cq_buy"], feat["cq_sell"])
    _emit(rows, np.flatnonzero(ok_cq & (feat["cq_buy"] >= cfg.cq_min) & (c > o)), 1, "A_CQ_BUY")
    _emit(rows, np.flatnonzero(ok_cq & (feat["cq_sell"] >= cfg.cq_min) & (c < o)), -1, "A_CQ_SELL")

    sweep_buy = _finite(feat["sl"]) & (l < feat["sl"]) & (c > feat["sl"])
    sweep_sell = _finite(feat["sh"]) & (h > feat["sh"]) & (c < feat["sh"])
    _emit(rows, np.flatnonzero(sweep_buy), 1, "A_SWEEP_BUY")
    _emit(rows, np.flatnonzero(sweep_sell), -1, "A_SWEEP_SELL")
    _emit(
        rows,
        np.flatnonzero(sweep_buy & (feat["cq_buy"] >= cfg.cq_min)),
        1,
        "A_SWEEP_CQ_BUY",
    )
    _emit(
        rows,
        np.flatnonzero(sweep_sell & (feat["cq_sell"] >= cfg.cq_min)),
        -1,
        "A_SWEEP_CQ_SELL",
    )

    trend_up = _finite(feat["slope"], feat["ema21"], feat["atr14"]) & (feat["slope"] > cfg.slope_thr)
    trend_dn = _finite(feat["slope"], feat["ema21"], feat["atr14"]) & (feat["slope"] < -cfg.slope_thr)
    pull_buy = trend_up & (l <= feat["ema21"]) & (c > feat["ema21"]) & (c > o)
    pull_sell = trend_dn & (h >= feat["ema21"]) & (c < feat["ema21"]) & (c < o)
    _emit(rows, np.flatnonzero(pull_buy), 1, "B_M1_PULLBACK_BUY")
    _emit(rows, np.flatnonzero(pull_sell), -1, "B_M1_PULLBACK_SELL")
    vol_ok = _finite(feat["relvol"]) & (feat["relvol"] > cfg.relvol_min)
    _emit(rows, np.flatnonzero(pull_buy & vol_ok), 1, "B_M1_PULLBACK_BUY_VOL")
    _emit(rows, np.flatnonzero(pull_sell & vol_ok), -1, "B_M1_PULLBACK_SELL_VOL")

    is_range = (
        _finite(feat["slope"], feat["bandwidth"], feat["bw_med"])
        & (np.abs(feat["slope"]) < cfg.range_slope)
        & (feat["bandwidth"] < feat["bw_med"])
    )
    _emit(
        rows,
        np.flatnonzero(is_range & _finite(feat["lower"], feat["cq_buy"]) & (c < feat["lower"]) & (feat["cq_buy"] >= cfg.cq_min)),
        1,
        "B_RANGE_FADE_BUY",
    )
    _emit(
        rows,
        np.flatnonzero(is_range & _finite(feat["upper"], feat["cq_sell"]) & (c > feat["upper"]) & (feat["cq_sell"] >= cfg.cq_min)),
        -1,
        "B_RANGE_FADE_SELL",
    )

    h1_up = _finite(feat["h1_slope"], feat["ema21"]) & (feat["h1_slope"] > 0)
    h1_dn = _finite(feat["h1_slope"], feat["ema21"]) & (feat["h1_slope"] < 0)
    _emit(
        rows,
        np.flatnonzero(h1_up & (l <= feat["ema21"]) & (c > feat["ema21"]) & (c > o)),
        1,
        "B_H1_PULLBACK_BUY",
    )
    _emit(
        rows,
        np.flatnonzero(h1_dn & (h >= feat["ema21"]) & (c < feat["ema21"]) & (c < o)),
        -1,
        "B_H1_PULLBACK_SELL",
    )

    exp_buy = (
        feat["was_squeeze"]
        & _finite(feat["upper"], feat["atr14"])
        & (c > feat["upper"])
        & ((c - o) > 0.5 * feat["atr14"])
    )
    exp_sell = (
        feat["was_squeeze"]
        & _finite(feat["lower"], feat["atr14"])
        & (c < feat["lower"])
        & ((o - c) > 0.5 * feat["atr14"])
    )
    _emit(rows, np.flatnonzero(exp_buy), 1, "C_BREAK_BUY")
    _emit(rows, np.flatnonzero(exp_sell), -1, "C_BREAK_SELL")
    _emit(rows, np.flatnonzero(exp_buy & vol_ok), 1, "C_BREAK_BUY_VOL")
    _emit(rows, np.flatnonzero(exp_sell & vol_ok), -1, "C_BREAK_SELL_VOL")

    # H14 original — venda. H16 original — venda. IDs não são reaproveitados.
    h14 = h14_mask(o, c, feat["upper"])
    _emit(rows, np.flatnonzero(h14), -1, "D_H14_ORIG")
    h16_core = h16_mask(o, c, feat["lower"], feat["ema9"], feat["ema21"], feat["relvol"], cfg.relvol_min, False)
    h16_orig = h16_mask(o, c, feat["lower"], feat["ema9"], feat["ema21"], feat["relvol"], cfg.relvol_min, True)
    _emit(rows, np.flatnonzero(h16_core), -1, "D_H16_NO_VOL")
    _emit(rows, np.flatnonzero(h16_orig), -1, "D_H16_ORIG")

    _session_signals(rows, ts, o, c)
    _sequence_signals(rows, h, l, o, c, feat)

    g_buy = (
        _finite(feat["tr"], feat["tr_p80"], feat["cq_buy"])
        & (feat["tr"] > feat["tr_p80"])
        & (feat["cq_buy"] >= 0.70)
        & (c > o)
    )
    g_sell = (
        _finite(feat["tr"], feat["tr_p80"], feat["cq_sell"])
        & (feat["tr"] > feat["tr_p80"])
        & (feat["cq_sell"] >= 0.70)
        & (c < o)
    )
    _emit(rows, np.flatnonzero(g_buy), 1, "G_DISP_BUY")
    _emit(rows, np.flatnonzero(g_sell), -1, "G_DISP_SELL")
    _emit(rows, np.flatnonzero(g_buy & vol_ok), 1, "G_DISP_BUY_VOL")
    _emit(rows, np.flatnonzero(g_sell & vol_ok), -1, "G_DISP_SELL_VOL")

    if not rows:
        return pd.DataFrame(columns=["signal_idx", "side", "hypothesis_id"])
    out = pd.DataFrame(rows)
    # um sinal por hipótese por candle
    out = out.drop_duplicates(["hypothesis_id", "signal_idx"]).reset_index(drop=True)
    out = out[out["signal_idx"] < n]
    return out


def _session_signals(rows: list[dict], ts: pd.DatetimeIndex, o: np.ndarray, c: np.ndarray) -> None:
    frame = pd.DataFrame({"ts": ts, "open": o, "close": c})
    frame["date"] = frame["ts"].dt.floor("D")
    frame["_i"] = np.arange(len(frame))

    def window_return(day: pd.DataFrame, start_min: int, end_min: int) -> float | None:
        m = day["ts"].dt.hour * 60 + day["ts"].dt.minute
        sl = day[(m >= start_min) & (m < end_min)]
        if len(sl) < 2:
            return None
        return float(sl["close"].iloc[-1] - sl["open"].iloc[0])

    by_day = {d: g for d, g in frame.groupby("date", sort=True)}
    dates = list(by_day.keys())

    def first_at_or_after(day_df: pd.DataFrame, minute_of_day: int) -> int | None:
        m = day_df["ts"].dt.hour * 60 + day_df["ts"].dt.minute
        hit = day_df[m >= minute_of_day]
        if hit.empty:
            return None
        return int(hit["_i"].iloc[0])

    for day in dates:
        g = by_day[day]
        asia = window_return(g, 0, 8 * 60)
        if asia is not None and asia != 0:
            idx = first_at_or_after(g, 8 * 60)
            if idx is not None:
                side = 1 if asia > 0 else -1
                rows.append({"signal_idx": idx, "side": side, "hypothesis_id": "E_ASIA_LONDON_CONT"})
                rows.append({"signal_idx": idx, "side": -side, "hypothesis_id": "E_ASIA_LONDON_FADE"})
        london = window_return(g, 8 * 60, 14 * 60 + 30)
        if london is not None and london != 0:
            idx = first_at_or_after(g, 14 * 60 + 30)
            if idx is not None:
                side = 1 if london > 0 else -1
                rows.append({"signal_idx": idx, "side": side, "hypothesis_id": "E_LONDON_NY_CONT"})
        shift = window_return(g, 2 * 60, 10 * 60)
        if shift is not None and shift != 0:
            idx = first_at_or_after(g, 10 * 60)
            if idx is not None:
                side = 1 if shift > 0 else -1
                rows.append({"signal_idx": idx, "side": side, "hypothesis_id": "E_CLOCK_SHIFT_CONT"})


def _sequence_signals(rows: list[dict], h, l, o, c, feat) -> None:
    """Sequências confirmadas só no candle do reteste."""
    n = len(c)
    sh, sl = feat["sh"], feat["sl"]
    atr = feat["atr14"]
    tr = feat["tr"]
    sweep_hi = np.isfinite(sh) & (h > sh) & (c < sh)
    sweep_lo = np.isfinite(sl) & (l < sl) & (c > sl)
    pending_hi: list[int] = []
    pending_lo: list[int] = []
    for t in range(n):
        pending_hi = [s for s in pending_hi if t - s <= 12]
        pending_lo = [s for s in pending_lo if t - s <= 12]
        if sweep_hi[t]:
            pending_hi.append(t)
        if sweep_lo[t]:
            pending_lo.append(t)
        if not np.isfinite(atr[t]):
            continue
        for s in pending_hi:
            if t <= s:
                continue
            level = sh[s]
            if not np.isfinite(level):
                continue
            retest = (h[t] >= level - 0.25 * atr[t]) and (c[t] < level) and (c[t] < o[t])
            if not retest:
                continue
            rows.append({"signal_idx": t, "side": -1, "hypothesis_id": "F_SWEEP_RETEST_SELL"})
            displaced = False
            for d in range(s + 1, t):
                if (
                    np.isfinite(atr[d])
                    and tr[d] > 1.3 * atr[d]
                    and c[d] < o[d]
                    and c[d] < c[s]
                ):
                    displaced = True
                    break
            if displaced:
                rows.append({"signal_idx": t, "side": -1, "hypothesis_id": "F_SWEEP_DISP_RETEST_SELL"})
        for s in pending_lo:
            if t <= s:
                continue
            level = sl[s]
            if not np.isfinite(level):
                continue
            retest = (l[t] <= level + 0.25 * atr[t]) and (c[t] > level) and (c[t] > o[t])
            if not retest:
                continue
            rows.append({"signal_idx": t, "side": 1, "hypothesis_id": "F_SWEEP_RETEST_BUY"})
            displaced = False
            for d in range(s + 1, t):
                if (
                    np.isfinite(atr[d])
                    and tr[d] > 1.3 * atr[d]
                    and c[d] > o[d]
                    and c[d] > c[s]
                ):
                    displaced = True
                    break
            if displaced:
                rows.append({"signal_idx": t, "side": 1, "hypothesis_id": "F_SWEEP_DISP_RETEST_BUY"})
