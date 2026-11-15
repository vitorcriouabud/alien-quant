"""Simulação OHLC: entrada na abertura seguinte, saída no fechamento do horizonte.

Não modela stop intrabar nem fila de ticks. Isso fica para a etapa MT5.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from alienlab.data import LabConfig

_SESSION_EDGES = (
    (8 * 60, "asia"),
    (14 * 60 + 30, "london"),
    (22 * 60, "ny"),
)


def session_of(ts: pd.Timestamp) -> str:
    minute = ts.hour * 60 + ts.minute
    for edge, name in _SESSION_EDGES:
        if minute < edge:
            return name
    return "late"


def _contiguous(time_ns: np.ndarray, i0: int, i1: int, gap_ns: int) -> bool:
    if i1 >= len(time_ns) or i0 < 0 or i1 < i0:
        return False
    diffs = np.diff(time_ns[i0 : i1 + 1])
    if len(diffs) == 0:
        return True
    return bool(np.all(diffs > 0) and np.all(diffs <= gap_ns))


def simulate(data: dict[str, np.ndarray], signals: pd.DataFrame, cfg: LabConfig) -> pd.DataFrame:
    """Um registro por sinal × horizonte × cenário de spread × slippage."""
    n = len(data["close"])
    gap_ns = int(cfg.gap_seconds * 1_000_000_000)
    times = pd.to_datetime(data["time_utc_ns"])
    columns = [
        "hypothesis_id",
        "signal_idx",
        "entry_idx",
        "exit_idx",
        "side",
        "horizon_min",
        "cost_mode",
        "slippage_points",
        "status",
        "entry_price",
        "exit_price",
        "spread_points",
        "gross_points",
        "cost_points",
        "net_points",
        "net_price",
        "net_usd",
        "session",
        "month",
        "reserved",
    ]
    if signals.empty:
        return pd.DataFrame(columns=columns)

    records: list[dict] = []
    opens = data["open"]
    closes = data["close"]
    spreads = data["spread_points"]
    reserved = data["reserved"]
    point = cfg.point
    reserved_prefix = np.r_[0, np.cumsum(reserved.astype(np.int64))]
    busy_until: dict[tuple, int] = {}  # política isolada por hipótese e cenário

    for sig in signals.itertuples(index=False):
        sidx = int(sig.signal_idx)
        side = int(sig.side)
        entry_idx = sidx + 1
        base_reserved = bool(reserved[sidx]) if sidx < n else True
        for horizon in cfg.horizons:
            exit_idx = entry_idx + horizon - 1
            if entry_idx >= n or exit_idx >= n:
                for mode in ("exclude_zero", "penalize_zero"):
                    for slip in cfg.slippage_points:
                        records.append(
                            _row(sig.hypothesis_id, sidx, entry_idx, exit_idx, side, horizon, mode, slip,
                                 "no_future", np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.nan, np.nan,
                                 "", "", base_reserved)
                        )
                continue
            spread = float(spreads[entry_idx])
            entry_px = float(opens[entry_idx])
            exit_px = float(closes[exit_idx])
            ok_gap = _contiguous(data["time_ns"], sidx, exit_idx, gap_ns)
            ts = times[entry_idx]
            sess = session_of(ts)
            month = f"{ts.year:04d}-{ts.month:02d}"
            # Reserva na janela INTEIRA, incluindo signal, entrada e saída.
            is_res = bool(reserved_prefix[exit_idx + 1] - reserved_prefix[sidx])
            gross_points = side * (exit_px - entry_px) / point
            for mode in ("exclude_zero", "penalize_zero"):
                for slip in cfg.slippage_points:
                    if not ok_gap:
                        records.append(
                            _row(sig.hypothesis_id, sidx, entry_idx, exit_idx, side, horizon, mode, slip,
                                 "gap", entry_px, exit_px, spread, gross_points, np.nan, np.nan, np.nan, np.nan,
                                 sess, month, is_res)
                        )
                        continue
                    if mode == "exclude_zero" and spread == 0:
                        records.append(
                            _row(sig.hypothesis_id, sidx, entry_idx, exit_idx, side, horizon, mode, slip,
                                 "spread0_excluded", entry_px, exit_px, spread, gross_points, np.nan, np.nan, np.nan, np.nan,
                                 sess, month, is_res)
                        )
                        continue
                    key = (sig.hypothesis_id, int(horizon), mode, float(slip))
                    if cfg.position_policy == "one_per_hypothesis" and entry_idx <= busy_until.get(key, -1) and not is_res:
                        records.append(
                            _row(sig.hypothesis_id, sidx, entry_idx, exit_idx, side, horizon, mode, slip,
                                 "overlap_skipped", entry_px, exit_px, spread, gross_points, np.nan, np.nan, np.nan, np.nan,
                                 sess, month, is_res)
                        )
                        continue
                    spread_used = cfg.penalty_spread0_points if (mode == "penalize_zero" and spread == 0) else spread
                    cost_points = spread_used + float(slip)
                    net_points = gross_points - cost_points
                    net_price = net_points * point
                    net_usd = net_price * cfg.contract_oz - cfg.commission_usd_per_lot_rt
                    if cfg.position_policy == "one_per_hypothesis" and not is_res:
                        busy_until[key] = exit_idx
                    records.append(
                        _row(sig.hypothesis_id, sidx, entry_idx, exit_idx, side, horizon, mode, slip,
                             "filled", entry_px, exit_px, spread, gross_points, cost_points, net_points, net_price, net_usd,
                             sess, month, is_res)
                    )
    return pd.DataFrame.from_records(records, columns=columns)


def _row(*values) -> dict:
    keys = [
        "hypothesis_id", "signal_idx", "entry_idx", "exit_idx", "side", "horizon_min",
        "cost_mode", "slippage_points", "status", "entry_price", "exit_price", "spread_points",
        "gross_points", "cost_points", "net_points", "net_price", "net_usd", "session", "month", "reserved",
    ]
    return dict(zip(keys, values))
