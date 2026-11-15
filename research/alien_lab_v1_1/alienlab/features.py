"""Features causais. Janelas rolling não usam center=True."""

from __future__ import annotations

import numpy as np
import pandas as pd

from alienlab.data import LabConfig


def _ema(x: np.ndarray, span: int) -> np.ndarray:
    return pd.Series(x).ewm(span=span, adjust=False).mean().to_numpy()


def _sma(x: np.ndarray, n: int) -> np.ndarray:
    return pd.Series(x).rolling(n, min_periods=n).mean().to_numpy()


def _std_pop(x: np.ndarray, n: int) -> np.ndarray:
    return pd.Series(x).rolling(n, min_periods=n).std(ddof=0).to_numpy()


def prev_rolling_max(x: np.ndarray, k: int) -> np.ndarray:
    """max(x[t-k:t]) — k valores estritamente anteriores."""
    return pd.Series(x).shift(1).rolling(k, min_periods=k).max().to_numpy()


def prev_rolling_min(x: np.ndarray, k: int) -> np.ndarray:
    return pd.Series(x).shift(1).rolling(k, min_periods=k).min().to_numpy()


def true_range(h: np.ndarray, l: np.ndarray, c: np.ndarray) -> np.ndarray:
    prev_c = np.roll(c, 1)
    prev_c[0] = c[0]
    return np.maximum(h - l, np.maximum(np.abs(h - prev_c), np.abs(l - prev_c)))


def close_quality(h: np.ndarray, l: np.ndarray, c: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    rng = h - l
    valid = rng > 0
    cq_buy = np.divide(c - l, rng, out=np.full(len(c), np.nan), where=valid)
    cq_sell = np.divide(h - c, rng, out=np.full(len(c), np.nan), where=valid)
    return cq_buy, cq_sell


def _completed_h1_slope(time_utc_ns: np.ndarray, close: np.ndarray) -> np.ndarray:
    """Slope da EMA21 H1 visível só após a hora fechar.

    A hora H entra no cálculo quando existe barra em H+1 (a última hora do arquivo
    fica de fora porque ainda pode estar aberta). O valor é publicado no primeiro
    instante >= H+1h.
    """
    ts = pd.to_datetime(time_utc_ns)
    hour = ts.floor("h")
    last_close = pd.DataFrame({"hour": hour, "close": close}).groupby("hour", sort=True)["close"].last()
    if len(last_close) < 3:
        return np.full(len(close), np.nan)
    complete = last_close.iloc[:-1]
    ema = complete.ewm(span=21, adjust=False).mean()
    slope = ema.diff()
    published = pd.DataFrame(
        {
            "ts": complete.index + pd.Timedelta(hours=1),
            "slope": slope.to_numpy(dtype=np.float64),
        }
    ).sort_values("ts")
    probe = pd.DataFrame({"ts": pd.to_datetime(time_utc_ns)})
    merged = pd.merge_asof(probe, published, on="ts", direction="backward")
    return merged["slope"].to_numpy(dtype=np.float64)


def compute_features(data: dict[str, np.ndarray], cfg: LabConfig) -> dict[str, np.ndarray]:
    o = data["open"]
    h = data["high"]
    l = data["low"]
    c = data["close"]
    v = data["tick_volume"]
    tr = true_range(h, l, c)
    atr14 = _sma(tr, 14)
    ema9 = _ema(c, 9)
    ema21 = _ema(c, 21)
    ema50 = _ema(c, 50)
    mid = _sma(c, cfg.bb_period)
    std = _std_pop(c, cfg.bb_period)
    upper = mid + cfg.bb_mult * std
    lower = mid - cfg.bb_mult * std
    bandwidth = np.divide(upper - lower, mid, out=np.full(len(c), np.nan), where=np.abs(mid) > 1e-12)
    vol_sma = _sma(v, cfg.relvol_period)
    relvol = np.divide(v, vol_sma, out=np.full(len(c), np.nan), where=vol_sma > 0)
    ema50_prev = np.roll(ema50, cfg.slope_lookback)
    ema50_prev[: cfg.slope_lookback] = np.nan
    slope = np.divide(ema50 - ema50_prev, atr14, out=np.full(len(c), np.nan), where=atr14 > 0)
    bw_s = pd.Series(bandwidth)
    # percentil e mediana só do passado, sem o candle atual
    bw_p20 = bw_s.shift(1).rolling(120, min_periods=120).quantile(0.20).to_numpy()
    bw_med = bw_s.shift(1).rolling(100, min_periods=100).median().to_numpy()
    tr_p80 = pd.Series(tr).shift(1).rolling(50, min_periods=50).quantile(0.80).to_numpy()
    cq_buy, cq_sell = close_quality(h, l, c)
    sh = prev_rolling_max(h, cfg.sweep_k)
    sl = prev_rolling_min(l, cfg.sweep_k)
    h1_slope = _completed_h1_slope(data["time_utc_ns"], c)
    # compressão recente: bandwidth anterior abaixo do p20 anterior, em alguma das últimas 5 barras já fechadas
    squeezed = (bw_s.shift(1) < pd.Series(bw_p20)).fillna(False)
    was_squeeze = squeezed.rolling(5, min_periods=1).max().fillna(0).to_numpy().astype(bool)
    return {
        "tr": tr,
        "atr14": atr14,
        "ema9": ema9,
        "ema21": ema21,
        "ema50": ema50,
        "mid": mid,
        "upper": upper,
        "lower": lower,
        "bandwidth": bandwidth,
        "relvol": relvol,
        "slope": slope,
        "bw_p20": bw_p20,
        "bw_med": bw_med,
        "tr_p80": tr_p80,
        "cq_buy": cq_buy,
        "cq_sell": cq_sell,
        "sh": sh,
        "sl": sl,
        "h1_slope": h1_slope,
        "was_squeeze": was_squeeze,
    }
