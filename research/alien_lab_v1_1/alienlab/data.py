"""Leitura de CSV M1. Não abre MT5 e não envia ordens."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd


@dataclass
class LabConfig:
    point: float = 0.01
    contract_oz: float = 100.0
    commission_usd_per_lot_rt: float = 0.0
    slippage_points: tuple[float, ...] = (0.0, 10.0, 20.0)
    spread_unit: str = "points"
    penalty_spread0_points: float = 20.0
    timestamp_kind: str = "utc"
    server_utc_offset_hours: float = 0.0
    bb_period: int = 20
    bb_mult: float = 2.0
    sweep_k: int = 10
    cq_min: float = 0.66
    relvol_period: int = 20
    relvol_min: float = 1.2
    slope_lookback: int = 10
    slope_thr: float = 0.25
    range_slope: float = 0.10
    horizons: tuple[int, ...] = (5, 15, 30)
    reserved_start: str | None = None
    reserved_end: str | None = None
    gap_seconds: float = 90.0
    position_policy: str = "independent"
    timezone_verified: bool = False

    def validate(self) -> None:
        if self.point <= 0:
            raise ValueError("point deve ser > 0")
        if self.spread_unit not in {"points", "price"}:
            raise ValueError("spread_unit deve ser 'points' ou 'price'")
        if self.timestamp_kind not in {"utc", "server"}:
            raise ValueError("timestamp_kind deve ser 'utc' ou 'server'")
        if self.contract_oz <= 0:
            raise ValueError("contract_oz deve ser > 0")
        if self.position_policy not in {"independent", "one_per_hypothesis"}:
            raise ValueError("position_policy inválida")
        if not self.horizons or any(h <= 0 for h in self.horizons):
            raise ValueError("horizons devem ser positivos")
        if not self.slippage_points or any(s < 0 for s in self.slippage_points):
            raise ValueError("slippage deve ser não negativo")


_TIME = ("time_server", "time", "datetime", "date", "timestamp", "time_msc")
_OPEN = ("open", "o")
_HIGH = ("high", "h")
_LOW = ("low", "l")
_CLOSE = ("close", "c")
_VOL = ("tick_volume", "tickvolume", "volume", "vol", "tickvol")
_SPREAD = ("spread", "spread_points", "spr")


def _pick(columns: list[str], options: tuple[str, ...]) -> str | None:
    lookup = {c.lower(): c for c in columns}
    for name in options:
        if name in lookup:
            return lookup[name]
    return None


def load_m1_csv(path: str, cfg: LabConfig) -> pd.DataFrame:
    """Aceita vírgula ou ponto-e-vírgula, utf-8 ou utf-16."""
    cfg.validate()
    last_error: Exception | None = None
    frame = None
    for enc in ("utf-8", "utf-8-sig", "utf-16", "utf-16le", "latin1"):
        for sep in (",", ";", "\t"):
            try:
                trial = pd.read_csv(path, sep=sep, encoding=enc, engine="python")
            except Exception as exc:  # noqa: BLE001 — tentativas de formato
                last_error = exc
                continue
            if trial.shape[1] >= 5 and len(trial) > 0:
                frame = trial
                break
        if frame is not None:
            break
    if frame is None:
        raise RuntimeError(f"CSV ilegível: {path} ({last_error})")

    cols = list(frame.columns)
    tcol = _pick(cols, _TIME)
    ocol = _pick(cols, _OPEN)
    hcol = _pick(cols, _HIGH)
    lcol = _pick(cols, _LOW)
    ccol = _pick(cols, _CLOSE)
    vcol = _pick(cols, _VOL)
    scol = _pick(cols, _SPREAD)
    missing = [
        name
        for name, col in (
            ("time", tcol),
            ("open", ocol),
            ("high", hcol),
            ("low", lcol),
            ("close", ccol),
            ("tick_volume", vcol),
            ("spread", scol),
        )
        if col is None
    ]
    if missing:
        raise ValueError(
            "CSV sem colunas obrigatórias: "
            + ", ".join(missing)
            + f". Encontradas: {cols}"
        )

    out = pd.DataFrame(
        {
            "time": pd.to_datetime(frame[tcol], errors="coerce"),
            "open": pd.to_numeric(frame[ocol], errors="coerce"),
            "high": pd.to_numeric(frame[hcol], errors="coerce"),
            "low": pd.to_numeric(frame[lcol], errors="coerce"),
            "close": pd.to_numeric(frame[ccol], errors="coerce"),
            "tick_volume": pd.to_numeric(frame[vcol], errors="coerce"),
            "spread_raw": pd.to_numeric(frame[scol], errors="coerce"),
        }
    )
    # Não corrigimos nem interpolamos registros inválidos em silêncio.
    bad_rows = int(out.isna().any(axis=1).sum())
    if bad_rows:
        raise ValueError(f"CSV contém {bad_rows} linhas inválidas; corrigir na origem, sem preenchimento silencioso")
    if out.empty:
        raise ValueError("CSV vazio após limpeza")
    if not out["time"].is_monotonic_increasing:
        raise ValueError("timestamps fora de ordem; recuse o arquivo e investigue a origem")
    if out["time"].duplicated().any():
        dup = int(out["time"].duplicated().sum())
        raise ValueError(f"{dup} timestamps duplicados — recuse o arquivo, não faça média silenciosa")
    if (out["high"] < out[["open", "close", "low"]].max(axis=1) - 1e-9).any():
        raise ValueError("há candles com high menor que open/close/low")
    if (out["low"] > out[["open", "close", "high"]].min(axis=1) + 1e-9).any():
        raise ValueError("há candles com low maior que open/close/high")

    if (out["spread_raw"] < 0).any():
        raise ValueError("spread negativo no CSV")
    if (out["tick_volume"] < 0).any():
        raise ValueError("tick_volume negativo no CSV")
    if cfg.spread_unit == "points":
        out["spread_points"] = out["spread_raw"].astype(float)
    else:
        out["spread_points"] = out["spread_raw"].astype(float) / cfg.point

    if cfg.timestamp_kind == "utc":
        out["time_utc"] = out["time"]
    else:
        out["time_utc"] = out["time"] - pd.to_timedelta(cfg.server_utc_offset_hours, unit="h")

    out["reserved_overlap"] = False
    if cfg.reserved_start and cfg.reserved_end:
        start = pd.Timestamp(cfg.reserved_start)
        end = pd.Timestamp(cfg.reserved_end)
        out["reserved_overlap"] = (out["time"] >= start) & (out["time"] <= end)
    out.attrs["time_column"] = tcol
    return out


def arrays_from_frame(df: pd.DataFrame) -> dict[str, np.ndarray]:
    return {
        "time_ns": df["time"].astype("int64").to_numpy(),
        "time_utc_ns": df["time_utc"].astype("int64").to_numpy(),
        "open": df["open"].to_numpy(dtype=np.float64),
        "high": df["high"].to_numpy(dtype=np.float64),
        "low": df["low"].to_numpy(dtype=np.float64),
        "close": df["close"].to_numpy(dtype=np.float64),
        "tick_volume": df["tick_volume"].to_numpy(dtype=np.float64),
        "spread_points": df["spread_points"].to_numpy(dtype=np.float64),
        "reserved": df["reserved_overlap"].to_numpy(dtype=bool),
    }
