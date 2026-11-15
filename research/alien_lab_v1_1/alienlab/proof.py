"""Prova sintética reproduzível. Não usa o CSV histórico."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from alienlab.data import LabConfig
from alienlab.definitions import definitions_hash
from alienlab.engine import run_frame
from alienlab.features import compute_features, prev_rolling_max
from alienlab.signals import generate_signals


def make_synthetic(n: int = 500, start: str = "2026-01-05 00:00:00") -> pd.DataFrame:
    idx = pd.date_range(start, periods=n, freq="min")
    price = np.full(n, 3900.0)
    # tendência suave para features existirem
    price = price + np.linspace(0, 2, n)
    df = pd.DataFrame(
        {
            "time": idx,
            "open": price,
            "high": price + 0.4,
            "low": price - 0.4,
            "close": price + 0.05,
            "tick_volume": np.full(n, 100.0),
            "spread": np.full(n, 10.0),  # 10 pontos MT5 = 0.10 de preço
        }
    )
    # sweep de máxima com rejeição em t=220 → VENDA
    t = 220
    df.loc[t, "open"] = df.loc[t, "close"] = df.loc[t - 1, "close"]
    prior_high = float(df.loc[t - 10 : t - 1, "high"].max())
    df.loc[t, "high"] = prior_high + 1.0
    df.loc[t, "low"] = prior_high - 1.2
    df.loc[t, "close"] = prior_high - 0.9
    df.loc[t, "open"] = prior_high + 0.2
    # caminho depois: entrada na abertura seguinte, queda de 1.00 até o close do horizonte 5
    df.loc[t + 1, "open"] = 3900.0
    for k in range(1, 40):
        df.loc[t + k, "open"] = 3900.0
        df.loc[t + k, "high"] = 3900.3
        df.loc[t + k, "low"] = 3898.8
        df.loc[t + k, "close"] = 3899.0 if k >= 5 else 3899.7
    # sweep de mínima com rejeição em t=300 → COMPRA
    b = 300
    prior_low = float(df.loc[b - 10 : b - 1, "low"].min())
    df.loc[b, "low"] = prior_low - 1.0
    df.loc[b, "high"] = prior_low + 1.2
    df.loc[b, "open"] = prior_low - 0.2
    df.loc[b, "close"] = prior_low + 0.9
    # gap de 15 minutos em 400
    df.loc[400:, "time"] = df.loc[400:, "time"] + pd.Timedelta(minutes=15)
    # um candle de spread zero
    df.loc[221, "spread"] = 0
    # um doji
    df.loc[50, "high"] = df.loc[50, "low"] = df.loc[50, "open"] = df.loc[50, "close"]
    return df


def assert_proof(df: pd.DataFrame) -> dict:
    cfg = LabConfig(slippage_points=(0.0,), timestamp_kind="utc")
    n = len(df)
    data = {
        "time_ns": df["time"].astype("int64").to_numpy(),
        "time_utc_ns": df["time"].astype("int64").to_numpy(),
        "open": df["open"].to_numpy(dtype=float),
        "high": df["high"].to_numpy(dtype=float),
        "low": df["low"].to_numpy(dtype=float),
        "close": df["close"].to_numpy(dtype=float),
        "tick_volume": df["tick_volume"].to_numpy(dtype=float),
        "spread_points": df["spread"].to_numpy(dtype=float),
        "reserved": np.zeros(n, dtype=bool),
    }
    feat = compute_features(data, cfg)
    sh = prev_rolling_max(data["high"], cfg.sweep_k)
    assert np.array_equal(sh, feat["sh"], equal_nan=True)
    assert feat["sh"][220] == np.max(data["high"][210:220])
    assert feat["sh"][220] < data["high"][220]
    future = data["high"].copy()
    future[230] = 99999.0
    assert prev_rolling_max(future, 10)[220] == feat["sh"][220]

    sig = generate_signals(data, feat, cfg)
    sell = sig[(sig["hypothesis_id"] == "A_SWEEP_SELL") & (sig["signal_idx"] == 220)]
    buy = sig[(sig["hypothesis_id"] == "A_SWEEP_BUY") & (sig["signal_idx"] == 300)]
    if sell.empty or int(sell["side"].iloc[0]) != -1:
        raise AssertionError(f"sweep de máxima não gerou VENDA em 220: {sell}")
    if buy.empty or int(buy["side"].iloc[0]) != 1:
        raise AssertionError(f"sweep de mínima não gerou COMPRA em 300: {buy}")
    doji = sig[(sig["signal_idx"] == 50) & (sig["hypothesis_id"].str.startswith("A_CQ"))]
    if not doji.empty:
        raise AssertionError("doji H=L gerou sinal de close quality")
    return {"sell": int(sell["side"].iloc[0]), "buy": int(buy["side"].iloc[0]), "hash": definitions_hash()}


def main(outdir: str = "resultados_sinteticos") -> dict:
    df = make_synthetic()
    info = assert_proof(df)
    cfg = LabConfig(slippage_points=(0.0, 10.0), timestamp_kind="utc", penalty_spread0_points=20.0)
    # o frame sintético ainda não passou pelo loader; normaliza colunas
    norm = df.rename(columns={"spread": "spread_raw"}).copy()
    norm["spread_points"] = norm["spread_raw"]
    norm["time_utc"] = norm["time"]
    norm["reserved_overlap"] = False
    audit = run_frame(norm, cfg, Path(outdir), source_name="synthetic")
    info["audit_hash"] = audit["definitions_sha256"]
    info["claim_level"] = audit["claim_level"]
    Path(outdir, "proof.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    print(json.dumps(info))
    return info


if __name__ == "__main__":
    main()
