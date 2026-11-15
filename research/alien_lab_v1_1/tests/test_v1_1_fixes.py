"""Regressões da auditoria V1.1: origem, retomar, reserva e política de execução."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from alienlab.data import LabConfig, load_m1_csv
from alienlab.nightly import main
from alienlab.proof import make_synthetic
from alienlab.signals import generate_signals
from alienlab.features import compute_features
from alienlab.simulate import simulate


def _small_signal_data(n=20):
    times = pd.date_range('2026-10-05', periods=n, freq='min').astype('int64').to_numpy()
    return dict(time_ns=times, time_utc_ns=times, open=np.full(n, 100.), high=np.full(n, 100.3),
                low=np.full(n, 99.8), close=np.linspace(100, 102, n), tick_volume=np.full(n, 50.),
                spread_points=np.full(n, 5.), reserved=np.zeros(n, dtype=bool))


def _synthetic_csv(path: Path) -> None:
    df = make_synthetic()
    df = df.rename(columns={'time': 'time_server', 'spread': 'spread_points'})
    df.to_csv(path, sep=';', index=False)


def test_native_roboforex_time_server_csv(tmp_path):
    csv = tmp_path / 'm1.csv'
    _synthetic_csv(csv)
    df = load_m1_csv(str(csv), LabConfig(timestamp_kind='server', server_utc_offset_hours=2))
    assert len(df) == 500
    assert df.attrs['time_column'] == 'time_server'
    assert (df.time.iloc[0] - df.time_utc.iloc[0]).total_seconds() == 7200


def test_reject_corrupted_csv_instead_of_silently_dropping_rows(tmp_path):
    csv = tmp_path / 'broken.csv'
    _synthetic_csv(csv)
    s = csv.read_text(encoding='utf-8').replace(';3900.', ';INVALID.', 1)
    csv.write_text(s, encoding='utf-8')
    with pytest.raises(ValueError, match='inválidas'):
        load_m1_csv(str(csv), LabConfig())


def test_reserved_bar_anywhere_inside_trade_is_excluded():
    d = _small_signal_data()
    d['reserved'][4] = True
    signals = pd.DataFrame([{'hypothesis_id': 'A_CQ_BUY', 'signal_idx': 1, 'side': 1}])
    ev = simulate(d, signals, LabConfig(horizons=(5,), slippage_points=(0.,)))
    assert ev.reserved.all()
    assert (ev.status == 'filled').all()  # logged, never included in primary metrics


def test_separate_position_policy_prevents_overlap_per_hypothesis():
    d = _small_signal_data()
    signals = pd.DataFrame([{'hypothesis_id':'A_CQ_BUY','signal_idx':i,'side':1} for i in range(1, 7)])
    cfg = LabConfig(horizons=(5,), slippage_points=(0.,), position_policy='one_per_hypothesis')
    ev = simulate(d, signals, cfg)
    x = ev[ev.cost_mode == 'penalize_zero']
    assert int((x.status == 'filled').sum()) == 2
    assert int((x.status == 'overlap_skipped').sum()) == 4
    cfg2 = LabConfig(horizons=(5,), slippage_points=(0.,), position_policy='independent')
    ev2 = simulate(d, signals, cfg2)
    assert int(((ev2.cost_mode == 'penalize_zero') & (ev2.status == 'filled')).sum()) == 6


def test_resume_rejects_missing_or_changed_csv_and_rebuilds_zip(tmp_path):
    csv = tmp_path / 'roboforex.csv'
    _synthetic_csv(csv)
    out = tmp_path / 'result'
    opts = ['--csv', str(csv), '--outdir', str(out), '--horizons', '5', '--slippage', '0', '--timestamp-kind', 'server', '--server-utc-offset', '2']
    assert main(opts) == 0
    zip_file = out / 'ALIEN_LAB_V1_resultado.zip'
    assert zip_file.is_file()
    zip_file.unlink()
    assert main(opts + ['--resume']) == 0
    assert zip_file.is_file()
    assert main(opts + ['--resume', '--slippage', '20']) == 1
    before = csv.read_bytes()
    csv.write_bytes(before + b'\n')
    assert main(opts + ['--resume']) == 1
    csv.unlink()
    assert main(opts + ['--resume']) == 1


def test_resume_rejects_tampered_events(tmp_path):
    csv = tmp_path / 'raw.csv'
    _synthetic_csv(csv)
    out = tmp_path / 'result'
    opts = ['--csv', str(csv), '--outdir', str(out), '--horizons', '5', '--slippage', '0']
    assert main(opts) == 0
    with (out / 'events.csv').open('a', encoding='utf-8') as f:
        f.write('corrupted\n')
    assert main(opts + ['--resume']) == 1


def test_mutating_future_does_not_change_prior_family_signals():
    df = make_synthetic()
    for cut in (210, 350, 620):
        truncated = df.iloc[:cut].copy()
        def signals_of(x):
            d = dict(time_ns=x.time.astype('int64').to_numpy(), time_utc_ns=x.time.astype('int64').to_numpy(),
                open=x.open.to_numpy(), high=x.high.to_numpy(), low=x.low.to_numpy(), close=x.close.to_numpy(),
                tick_volume=x.tick_volume.to_numpy(), spread_points=x.spread.to_numpy(), reserved=np.zeros(len(x),bool))
            return generate_signals(d, compute_features(d, LabConfig()), LabConfig())
        full = signals_of(df)
        prior = signals_of(truncated)
        full = full[full.signal_idx < cut].sort_values(['hypothesis_id','signal_idx']).reset_index(drop=True)
        prior = prior.sort_values(['hypothesis_id','signal_idx']).reset_index(drop=True)
        pd.testing.assert_frame_equal(full, prior)
