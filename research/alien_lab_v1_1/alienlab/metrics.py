"""Métricas de triagem. SURVIVES_SCREEN não significa lucro comprovado."""

from __future__ import annotations

import numpy as np
import pandas as pd

from alienlab.signals import hypothesis_ids, pairs


def _screen(n: int, mean_net: float, mean_wo: float, month_pos_frac: float) -> str:
    if n < 30 or not np.isfinite(mean_net):
        return "INCONCLUSIVE"
    if mean_net <= 0:
        return "REJECT"
    if not np.isfinite(mean_wo) or mean_wo <= 0 or month_pos_frac < 0.5:
        return "FRAGILE"
    return "SURVIVES_SCREEN"


def _block(filled: pd.DataFrame) -> dict:
    n = int(len(filled))
    if n == 0:
        return {
            "n_filled": 0,
            "mean_net_points": np.nan,
            "median_net_points": np.nan,
            "mean_net_usd": np.nan,
            "win_rate": np.nan,
            "profit_factor": np.nan,
            "mean_without_best": np.nan,
            "removed_best_points": np.nan,
            "months": 0,
            "months_positive_frac": np.nan,
            "min_month_mean": np.nan,
            "screen": "INCONCLUSIVE",
        }
    net = filled["net_points"].to_numpy(dtype=float)
    wins = net[net > 0].sum()
    losses = -net[net < 0].sum()
    pf = float(wins / losses) if losses > 0 else (np.inf if wins > 0 else np.nan)
    order = np.argsort(net)
    without = net[order[:-1]] if n > 1 else np.array([np.nan])
    monthly = filled.groupby("month")["net_points"].mean()
    pos_frac = float((monthly > 0).mean()) if len(monthly) else np.nan
    mean_net = float(np.mean(net))
    mean_wo = float(np.mean(without)) if np.isfinite(without).any() else np.nan
    return {
        "n_filled": n,
        "mean_net_points": mean_net,
        "median_net_points": float(np.median(net)),
        "mean_net_usd": float(filled["net_usd"].mean()),
        "win_rate": float(np.mean(net > 0)),
        "profit_factor": pf,
        "mean_without_best": mean_wo,
        "removed_best_points": float(np.max(net)),
        "months": int(monthly.shape[0]),
        "months_positive_frac": pos_frac,
        "min_month_mean": float(monthly.min()) if len(monthly) else np.nan,
        "screen": _screen(n, mean_net, mean_wo, pos_frac if np.isfinite(pos_frac) else 0.0),
    }


def summarize(events: pd.DataFrame, primary_only_fresh: bool = True, timezone_verified: bool = False) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    ids = hypothesis_ids()
    if events.empty:
        events = pd.DataFrame(columns=["hypothesis_id", "status", "reserved", "horizon_min", "cost_mode", "slippage_points", "net_points", "net_usd", "month", "session"])

    metric_rows = []
    month_rows = []
    sess_rows = []
    keys = events.groupby(["horizon_min", "cost_mode", "slippage_points"]).size().reset_index() if len(events) else pd.DataFrame(columns=["horizon_min", "cost_mode", "slippage_points"])
    # sempre materializa a grade mesmo sem eventos
    horizons = sorted(events["horizon_min"].dropna().unique()) if len(events) else [5, 15, 30]
    modes = sorted(events["cost_mode"].dropna().unique()) if len(events) else ["exclude_zero", "penalize_zero"]
    slips = sorted(events["slippage_points"].dropna().unique()) if len(events) else [0.0]
    if keys.empty:
        grid = [(h, m, s) for h in horizons for m in modes for s in slips]
    else:
        grid = list(keys[["horizon_min", "cost_mode", "slippage_points"]].itertuples(index=False, name=None))

    for hid in ids:
        sub_all = events[events["hypothesis_id"] == hid] if len(events) else events
        for horizon, mode, slip in grid:
            chunk = sub_all[
                (sub_all["horizon_min"] == horizon)
                & (sub_all["cost_mode"] == mode)
                & (sub_all["slippage_points"] == slip)
            ] if len(sub_all) else sub_all
            n_candidates = int(len(chunk))
            n_gap = int((chunk["status"] == "gap").sum()) if n_candidates else 0
            n_nofuture = int((chunk["status"] == "no_future").sum()) if n_candidates else 0
            n_spread0 = int((chunk["status"] == "spread0_excluded").sum()) if n_candidates else 0
            n_overlap = int((chunk["status"] == "overlap_skipped").sum()) if n_candidates else 0
            filled = chunk[chunk["status"] == "filled"] if n_candidates else chunk
            n_reserved = int(filled["reserved"].sum()) if len(filled) else 0
            primary = filled[~filled["reserved"]] if primary_only_fresh and len(filled) else filled
            stats = _block(primary)
            if hid.startswith("E_") and not timezone_verified:
                stats["screen"] = "TIMEZONE_UNVERIFIED"
            metric_rows.append(
                {
                    "hypothesis_id": hid,
                    "horizon_min": horizon,
                    "cost_mode": mode,
                    "slippage_points": slip,
                    "n_candidates": n_candidates,
                    "n_gap": n_gap,
                    "n_no_future": n_nofuture,
                    "n_spread0_excluded": n_spread0,
                    "n_overlap_skipped": n_overlap,
                    "n_reserved_excluded": n_reserved if primary_only_fresh else 0,
                    **stats,
                }
            )
            if len(primary):
                for month, g in primary.groupby("month"):
                    month_rows.append(
                        {
                            "hypothesis_id": hid,
                            "horizon_min": horizon,
                            "cost_mode": mode,
                            "slippage_points": slip,
                            "month": month,
                            "n": int(len(g)),
                            "mean_net_points": float(g["net_points"].mean()),
                        }
                    )
                for sess, g in primary.groupby("session"):
                    sess_rows.append(
                        {
                            "hypothesis_id": hid,
                            "horizon_min": horizon,
                            "cost_mode": mode,
                            "slippage_points": slip,
                            "session": sess,
                            "n": int(len(g)),
                            "mean_net_points": float(g["net_points"].mean()),
                        }
                    )

    metrics = pd.DataFrame(metric_rows)
    paired_rows = []
    for core, other, kind in pairs():
        for horizon, mode, slip in grid:
            a = metrics[
                (metrics["hypothesis_id"] == core)
                & (metrics["horizon_min"] == horizon)
                & (metrics["cost_mode"] == mode)
                & (metrics["slippage_points"] == slip)
            ]
            b = metrics[
                (metrics["hypothesis_id"] == other)
                & (metrics["horizon_min"] == horizon)
                & (metrics["cost_mode"] == mode)
                & (metrics["slippage_points"] == slip)
            ]
            if a.empty or b.empty:
                continue
            mean_core = float(a["mean_net_points"].iloc[0])
            mean_other = float(b["mean_net_points"].iloc[0])
            # Comparação por evento: mostrar explicitamente a intersecção dos sinais.
            # Confluências são subconjuntos: resultado no MESMO trade será idêntico,
            # portanto o ganho da confluência é seleção, não melhora mecânica do fill.
            filt = (events["horizon_min"] == horizon) & (events["cost_mode"] == mode) & (events["slippage_points"] == slip) & (events["status"] == "filled") & (~events["reserved"]) if len(events) else pd.Series([], dtype=bool)
            pool = events.loc[filt, ["hypothesis_id", "signal_idx", "side", "net_points"]] if len(events) else pd.DataFrame()
            ca = pool[pool["hypothesis_id"] == core] if len(pool) else pool
            cb = pool[pool["hypothesis_id"] == other] if len(pool) else pool
            if len(ca) and len(cb):
                joined = ca.merge(cb, on="signal_idx", suffixes=("_core", "_other"))
                if kind == "confluence":
                    joined = joined[joined["side_core"] == joined["side_other"]]
                mean_matched_core = float(joined["net_points_core"].mean()) if len(joined) else float("nan")
                mean_matched_other = float(joined["net_points_other"].mean()) if len(joined) else float("nan")
                n_matched = int(len(joined))
            else:
                n_matched = 0
                mean_matched_core = float("nan")
                mean_matched_other = float("nan")
            paired_rows.append(
                {
                    "n_matched_events": n_matched,
                    "mean_core_on_matched": mean_matched_core,
                    "mean_other_on_matched": mean_matched_other,
                    "delta_same_events": mean_matched_other - mean_matched_core if n_matched else float("nan"),
                    "comparison_warning": "Seleção de eventos diferentes; delta de médias não é efeito causal da confluência",
                    "core_id": core,
                    "other_id": other,
                    "kind": kind,
                    "horizon_min": horizon,
                    "cost_mode": mode,
                    "slippage_points": slip,
                    "n_core": int(a["n_filled"].iloc[0]),
                    "n_other": int(b["n_filled"].iloc[0]),
                    "mean_core": mean_core,
                    "mean_other": mean_other,
                    "delta_other_minus_core": mean_other - mean_core if np.isfinite(mean_other) and np.isfinite(mean_core) else np.nan,
                    "screen_core": a["screen"].iloc[0],
                    "screen_other": b["screen"].iloc[0],
                }
            )
    return metrics, pd.DataFrame(month_rows), pd.DataFrame(sess_rows), pd.DataFrame(paired_rows)
