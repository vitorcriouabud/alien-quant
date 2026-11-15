"""Executor único. Grava o hash das definições antes de calcular resultados."""

from __future__ import annotations

import json
import traceback
import zipfile
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from alienlab.data import LabConfig, arrays_from_frame, load_m1_csv
from alienlab.definitions import definitions_hash, frozen_document
from alienlab.features import compute_features
from alienlab.metrics import summarize
from alienlab.report import write_html
from alienlab.signals import generate_signals
from alienlab.simulate import simulate


def _claim_level(df: pd.DataFrame, cfg: LabConfig) -> str:
    if cfg.reserved_start and cfg.reserved_end and bool(df["reserved_overlap"].any()):
        return "contaminated_reserved"
    return "exploratory"


def run_frame(df: pd.DataFrame, cfg: LabConfig, outdir: Path, source_name: str, input_identity: dict | None = None) -> dict:
    outdir.mkdir(parents=True, exist_ok=True)
    if input_identity is None and not (outdir / "input_manifest.json").exists():
        (outdir / "input_manifest.json").write_text(json.dumps({"synthetic_or_direct_frame": True}), encoding="utf-8")
    frozen = frozen_document()
    (outdir / "definitions_frozen.json").write_text(
        json.dumps(frozen, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    errors: list[str] = []
    audit = {
        "lab": "ALIEN_LAB_V1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "source": source_name,
        "input_identity_sha256": input_identity.get("experiment_sha256") if input_identity else None,
        "source_csv_sha256": input_identity.get("source_csv_sha256") if input_identity else None,
        "time_basis_verified": cfg.timezone_verified,
        "session_warning": "Family E: sessões são exploratórias até confirmar o fuso/horário de verão da RoboForex" if not cfg.timezone_verified else None,
        "position_policy": cfg.position_policy,
        "definitions_sha256": definitions_hash(),
        "config": asdict(cfg),
        "n_bars": int(len(df)),
        "claim_level": _claim_level(df, cfg),
        "contract_oz_is_assumption": True,
        "point": cfg.point,
        "units": {
            "mt5_point_price": cfg.point,
            "price_to_points": f"pontos = variacao_preco / {cfg.point}",
            "usd_per_lot": "variacao_preco * contract_oz - comissao",
            "do_not_confuse": "0.50 de preço = 50 pontos MT5 quando point=0.01, não 0.50 ponto",
        },
        "execution_model": "OHLC. Entrada na abertura seguinte. Saída no fechamento do horizonte. Sem stop intrabar, sem fila de ticks.",
        "v11": "não modificada; nenhuma ordem enviada",
    }
    if audit["claim_level"] != "exploratory":
        audit["warning"] = (
            "Parte das barras cai no intervalo já analisado. "
            "Esses trades saem das métricas primárias e não contam como amostra inédita."
        )
    try:
        data = arrays_from_frame(df)
        feat = compute_features(data, cfg)
        signals = generate_signals(data, feat, cfg)
        events = simulate(data, signals, cfg)
        metrics, monthly, sessions, paired = summarize(events, timezone_verified=cfg.timezone_verified)
    except Exception as exc:  # noqa: BLE001 — o laboratório precisa registrar a falha e continuar o relatório
        errors.append(traceback.format_exc())
        signals = pd.DataFrame()
        events = pd.DataFrame()
        metrics, monthly, sessions, paired = summarize(events, timezone_verified=cfg.timezone_verified)
        audit["failed"] = str(exc)

    # A marca de completude só aparece depois da escrita atômica.
    from alienlab.identity import sha256_file
    temp_events = outdir / "events.csv.tmp"
    events.to_csv(temp_events, index=False)
    temp_events.replace(outdir / "events.csv")
    complete = {"sha256": sha256_file(outdir / "events.csv"), "rows": int(len(events))}
    (outdir / "events_complete.json").write_text(json.dumps(complete), encoding="utf-8")
    metrics.to_csv(outdir / "metrics.csv", index=False)
    monthly.to_csv(outdir / "monthly.csv", index=False)
    sessions.to_csv(outdir / "sessions.csv", index=False)
    paired.to_csv(outdir / "paired.csv", index=False)
    (outdir / "errors.log").write_text("\n".join(errors), encoding="utf-8")
    audit["finished_utc"] = datetime.now(timezone.utc).isoformat()
    audit["n_signals"] = int(len(signals)) if isinstance(signals, pd.DataFrame) else 0
    audit["n_event_rows"] = int(len(events))
    audit["screens"] = metrics["screen"].value_counts().to_dict() if len(metrics) else {}
    audit["errors"] = errors
    (outdir / "audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    write_html(outdir / "report.html", audit=audit, metrics=metrics, paired=paired, errors=errors)

    zip_path = outdir / "ALIEN_LAB_V1_resultado.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in (
            "definitions_frozen.json",
            "input_manifest.json",
            "events_complete.json",
            "events.csv",
            "metrics.csv",
            "monthly.csv",
            "sessions.csv",
            "paired.csv",
            "audit.json",
            "report.html",
            "errors.log",
        ):
            zf.write(outdir / name, arcname=name)
    if not zip_path.is_file() or zip_path.stat().st_size == 0:
        raise RuntimeError("ZIP ausente ou vazio após compactação")
    audit["zip"] = str(zip_path)
    return audit


def run_csv(path: str, cfg: LabConfig, outdir: Path, input_identity: dict | None = None) -> dict:
    df = load_m1_csv(path, cfg)
    return run_frame(df, cfg, outdir, source_name=str(path), input_identity=input_identity)
