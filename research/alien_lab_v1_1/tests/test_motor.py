"""Provas de causalidade, direção, unidades, gaps e repetibilidade."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alienlab.data import LabConfig
from alienlab.definitions import definitions_hash
from alienlab.features import compute_features, prev_rolling_max, prev_rolling_min
from alienlab.proof import make_synthetic
from alienlab.signals import generate_signals, h14_mask, h16_mask
from alienlab.simulate import simulate


def _pack(df: pd.DataFrame) -> dict:
    n = len(df)
    return {
        "time_ns": df["time"].astype("int64").to_numpy(),
        "time_utc_ns": df["time"].astype("int64").to_numpy(),
        "open": df["open"].to_numpy(float),
        "high": df["high"].to_numpy(float),
        "low": df["low"].to_numpy(float),
        "close": df["close"].to_numpy(float),
        "tick_volume": df["tick_volume"].to_numpy(float),
        "spread_points": df["spread"].to_numpy(float),
        "reserved": np.zeros(n, dtype=bool),
    }


def test_sweep_is_causal_and_directional():
    df = make_synthetic()
    data = _pack(df)
    cfg = LabConfig()
    feat = compute_features(data, cfg)
    assert feat["sh"][220] == np.max(data["high"][210:220])
    assert not np.isfinite(feat["sh"][5])
    sig = generate_signals(data, feat, cfg)
    sell = sig[(sig.hypothesis_id == "A_SWEEP_SELL") & (sig.signal_idx == 220)].iloc[0]
    buy = sig[(sig.hypothesis_id == "A_SWEEP_BUY") & (sig.signal_idx == 300)].iloc[0]
    assert int(sell.side) == -1
    assert int(buy.side) == 1
    # qualidade de fechamento casa com o lado
    rng = data["high"][220] - data["low"][220]
    assert rng > 0
    assert (data["high"][220] - data["close"][220]) / rng >= cfg.cq_min
    cq_buy = (data["close"][300] - data["low"][300]) / (data["high"][300] - data["low"][300])
    assert cq_buy >= cfg.cq_min


def test_future_mutation_does_not_change_past_signals():
    df = make_synthetic()
    cfg = LabConfig()
    base = generate_signals(_pack(df), compute_features(_pack(df), cfg), cfg)
    cut = 250
    mutated = df.copy()
    mutated.loc[cut:, "high"] = mutated.loc[cut:, "high"] + 500
    mutated.loc[cut:, "close"] = mutated.loc[cut:, "close"] + 500
    alt = generate_signals(_pack(mutated), compute_features(_pack(mutated), cfg), cfg)
    left = base[base.signal_idx < cut].sort_values(["hypothesis_id", "signal_idx"]).reset_index(drop=True)
    right = alt[alt.signal_idx < cut].sort_values(["hypothesis_id", "signal_idx"]).reset_index(drop=True)
    pd.testing.assert_frame_equal(left, right)


def test_doji_has_no_close_quality_signal():
    df = make_synthetic()
    sig = generate_signals(_pack(df), compute_features(_pack(df), LabConfig()), LabConfig())
    assert sig[(sig.signal_idx == 50) & (sig.hypothesis_id.str.startswith("A_"))].empty


def test_h14_h16_direction_and_identity():
    o = np.array([9.0, 10.0, 10.0])
    c = np.array([9.0, 11.0, 9.0])
    upper = np.array([9.5, 10.0, 10.0])
    mask = h14_mask(o, c, upper)
    assert mask.tolist() == [False, False, True]
    # alta no candle atual não é H14
    o2 = o.copy()
    c2 = c.copy()
    o2[2] = 8.0
    c2[2] = 9.5
    assert h14_mask(o2, c2, upper)[2] == False

    n = 4
    lower = np.array([1.0, 1.0, 1.0, 5.0])
    ema9 = np.array([1.0, 1.0, 1.0, 1.0])
    ema21 = np.array([2.0, 2.0, 2.0, 2.0])
    rel = np.array([0.5, 0.5, 0.5, 1.5])
    oo = np.array([3.0, 3.0, 3.0, 6.0])
    cc = np.array([2.0, 2.0, 2.0, 4.0])  # bearish and cc <= lower only at last? 4 <= 5
    core = h16_mask(oo, cc, lower, ema9, ema21, rel, 1.2, False)
    orig = h16_mask(oo, cc, lower, ema9, ema21, rel, 1.2, True)
    assert core[3] and orig[3]
    rel[3] = 1.0
    assert h16_mask(oo, cc, lower, ema9, ema21, rel, 1.2, False)[3]
    assert not h16_mask(oo, cc, lower, ema9, ema21, rel, 1.2, True)[3]


def test_units_points_versus_price():
    # 1.00 de preço com point=0.01 são 100 pontos MT5, e 100 USD num contrato de 100 oz.
    assert 1.00 / 0.01 == 100
    assert 1.00 * 100 == 100
    # 0.50 de preço não é 0.50 ponto
    assert 0.50 / 0.01 == 50


def test_gap_and_spread_zero_and_pnl():
    df = make_synthetic()
    cfg = LabConfig(slippage_points=(0.0,), penalty_spread0_points=20.0)
    events = simulate(_pack(df), generate_signals(_pack(df), compute_features(_pack(df), cfg), cfg), cfg)
    sell = events[(events.hypothesis_id == "A_SWEEP_SELL") & (events.signal_idx == 220) & (events.horizon_min == 5)]
    excluded = sell[sell.cost_mode == "exclude_zero"].iloc[0]
    penal = sell[sell.cost_mode == "penalize_zero"].iloc[0]
    assert excluded.status == "spread0_excluded"
    assert penal.status == "filled"
    # entrada 3900, saída 3899, venda: 100 pontos brutos, penalidade 20
    assert penal.gross_points == 100
    assert penal.cost_points == 20
    assert penal.net_points == 80
    assert abs(penal.net_usd - 0.80 * 100) < 1e-9

    # gap: desloca a partir de 400; um sinal cujo horizonte cruza o buraco fica gap
    # cria um sinal artificial no índice 396
    artificial = pd.DataFrame([{"signal_idx": 396, "side": 1, "hypothesis_id": "A_CQ_BUY"}])
    ev = simulate(_pack(df), artificial, cfg)
    row = ev[(ev.horizon_min == 15) & (ev.cost_mode == "penalize_zero")].iloc[0]
    assert row.status == "gap"
    short = ev[(ev.horizon_min == 5) & (ev.cost_mode == "penalize_zero")].iloc[0]
    # 396+1=397 até 401, e o salto está em 400, então também cruza
    assert short.status == "gap"


def test_repeatable_hash_and_signals():
    assert definitions_hash() == definitions_hash()
    df = make_synthetic()
    cfg = LabConfig()
    a = generate_signals(_pack(df), compute_features(_pack(df), cfg), cfg)
    b = generate_signals(_pack(df), compute_features(_pack(df), cfg), cfg)
    pd.testing.assert_frame_equal(
        a.sort_values(["hypothesis_id", "signal_idx"]).reset_index(drop=True),
        b.sort_values(["hypothesis_id", "signal_idx"]).reset_index(drop=True),
    )


def test_prev_window_excludes_current_and_future():
    h = np.array([1.0, 2.0, 3.0, 0.5, 9.0])
    sh = prev_rolling_max(h, 3)
    assert np.isnan(sh[0]) and np.isnan(sh[1]) and np.isnan(sh[2])
    assert sh[3] == 3
    assert sh[4] == 3  # não usa o 9 atual
    sl = prev_rolling_min(h, 3)
    assert sl[4] == 0.5
