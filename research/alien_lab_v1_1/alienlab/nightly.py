"""Executor noturno em um único processo, com retomada pelo hash das definições.

Não abre dezenas de workers. Se o estudo for interrompido depois do CSV de eventos,
a retomada só reconstrói métricas e o ZIP a partir dos arquivos já gravados.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

from alienlab.data import LabConfig
from alienlab.definitions import definitions_hash
from alienlab.engine import run_csv
from alienlab.metrics import summarize
from alienlab.report import write_html
from alienlab.identity import identity, sha256_file, verify_identity
import zipfile


def _cfg_from_args(args: argparse.Namespace) -> LabConfig:
    slips = tuple(float(x) for x in args.slippage.split(",") if x != "")
    return LabConfig(
        point=args.point,
        contract_oz=args.contract_oz,
        commission_usd_per_lot_rt=args.commission_usd,
        slippage_points=slips or (0.0,),
        spread_unit=args.spread_unit,
        penalty_spread0_points=args.penalty_spread0,
        timestamp_kind=args.timestamp_kind,
        server_utc_offset_hours=args.server_utc_offset,
        reserved_start=args.reserved_start,
        reserved_end=args.reserved_end,
        horizons=tuple(int(x) for x in args.horizons.split(",") if x),
        position_policy=args.position_policy,
        timezone_verified=args.timezone_verified,
    )


def resume_from_events(outdir: Path, expected_identity: dict) -> dict:
    frozen_path = outdir / "definitions_frozen.json"
    events_path = outdir / "events.csv"
    identity_path = outdir / "input_manifest.json"
    marker_path = outdir / "events_complete.json"
    if not identity_path.exists() or not marker_path.exists():
        raise RuntimeError("retomada exige manifesto do experimento e eventos completos; não reutilize CSV parcial")
    verify_identity(json.loads(identity_path.read_text(encoding="utf-8")), expected_identity)
    if not frozen_path.exists() or not events_path.exists():
        raise FileNotFoundError("retomada exige definitions_frozen.json e events.csv")
    frozen = json.loads(frozen_path.read_text(encoding="utf-8"))
    if frozen.get("sha256") != definitions_hash():
        raise RuntimeError(
            "hash das definições mudou. Não retomo um estudo congelado com outro código. "
            f"arquivo={frozen.get('sha256')} codigo={definitions_hash()}"
        )
    marker = json.loads(marker_path.read_text(encoding="utf-8"))
    if marker.get("sha256") != sha256_file(events_path):
        raise RuntimeError("events.csv alterado ou incompleto; retomada bloqueada")
    events = pd.read_csv(events_path)
    if len(events) != marker.get("rows"):
        raise RuntimeError("events.csv tem contagem de linhas diferente da marca de completude")
    metrics, monthly, sessions, paired = summarize(events, timezone_verified=bool(expected_identity["config"]["timezone_verified"]))
    metrics.to_csv(outdir / "metrics.csv", index=False)
    monthly.to_csv(outdir / "monthly.csv", index=False)
    sessions.to_csv(outdir / "sessions.csv", index=False)
    paired.to_csv(outdir / "paired.csv", index=False)
    audit_path = outdir / "audit.json"
    if not audit_path.exists():
        raise FileNotFoundError("audit.json ausente; não é seguro retomar")
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    audit["resumed"] = True
    audit["definitions_sha256"] = definitions_hash()
    audit["input_identity_sha256"] = expected_identity["experiment_sha256"]
    audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    errors = []
    err = outdir / "errors.log"
    if err.exists():
        text = err.read_text(encoding="utf-8").strip()
        if text:
            errors.append(text)
    write_html(outdir / "report.html", audit=audit, metrics=metrics, paired=paired, errors=errors)
    if audit.get("errors"):
        raise RuntimeError("resultado anterior contém falhas; não marcar retomada como concluída")
    zip_path = outdir / "ALIEN_LAB_V1_resultado.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in ("input_manifest.json", "events_complete.json", "definitions_frozen.json", "events.csv", "metrics.csv", "monthly.csv", "sessions.csv", "paired.csv", "audit.json", "report.html", "errors.log"):
            zf.write(outdir / name, arcname=name)
    with zipfile.ZipFile(zip_path) as zf:
        if zf.testzip() or "events.csv" not in zf.namelist():
            raise RuntimeError("ZIP final não passou a verificação")
    return audit


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ALIEN LAB V1 — triagem noturna de um CSV M1")
    parser.add_argument("--csv", required=True)
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--point", type=float, default=0.01)
    parser.add_argument("--contract-oz", type=float, default=100.0)
    parser.add_argument("--commission-usd", type=float, default=0.0)
    parser.add_argument("--slippage", default="10", help="pontos MT5, separados por vírgula")
    parser.add_argument("--spread-unit", choices=("points", "price"), default="points")
    parser.add_argument("--penalty-spread0", type=float, default=20.0)
    parser.add_argument("--timestamp-kind", choices=("utc", "server"), default="utc")
    parser.add_argument("--server-utc-offset", type=float, default=0.0)
    parser.add_argument("--reserved-start", default=None)
    parser.add_argument("--reserved-end", default=None)
    parser.add_argument("--horizons", default="15", help="grade 15 para notebook 8GB; escolha 5,15,30 explicitamente")
    parser.add_argument("--position-policy", choices=("independent", "one_per_hypothesis"), default="one_per_hypothesis")
    parser.add_argument("--timezone-verified", action="store_true", help="somente se conversão de fuso e DST foi validada externamente")
    args = parser.parse_args(argv)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    checkpoint = outdir / "checkpoint.json"
    try:
        cfg = _cfg_from_args(args)
        observed = identity(Path(args.csv), cfg)
        manifest = outdir / "input_manifest.json"
        if args.resume:
            if not manifest.exists() or not (outdir / "events.csv").exists():
                raise FileNotFoundError("retomada indisponível: manifesto ou eventos completos ausentes")
            resume_from_events(outdir, observed)
            checkpoint.write_text(
                json.dumps({"status": "resumed", "sha256": definitions_hash()}),
                encoding="utf-8",
            )
            if not (outdir / "ALIEN_LAB_V1_resultado.zip").is_file():
                raise RuntimeError("ZIP final não foi criado")
            print("retomada concluída com ZIP validado")
            return 0
        if manifest.exists():
            verify_identity(json.loads(manifest.read_text(encoding="utf-8")), observed)
        else:
            manifest.write_text(json.dumps(observed, ensure_ascii=False, indent=2), encoding="utf-8")
        checkpoint.write_text(
            json.dumps({"status": "running", "sha256": definitions_hash(), "stage": "frozen_before_run"}),
            encoding="utf-8",
        )
        audit = run_csv(args.csv, cfg, outdir, input_identity=observed)
        if not (outdir / "ALIEN_LAB_V1_resultado.zip").is_file():
            raise RuntimeError("motor não entregou ZIP de resultado")
        checkpoint.write_text(
            json.dumps({"status": "done" if not audit.get("errors") else "failed", "sha256": definitions_hash(), "experiment_sha256": observed["experiment_sha256"], "claim_level": audit.get("claim_level")}),
            encoding="utf-8",
        )
        print(json.dumps({"claim_level": audit.get("claim_level"), "screens": audit.get("screens"), "errors": audit.get("errors")}, ensure_ascii=False))
        return 0 if not audit.get("errors") else 1
    except Exception as exc:  # noqa: BLE001
        checkpoint.write_text(
            json.dumps({"status": "failed", "error": str(exc), "sha256": definitions_hash()}),
            encoding="utf-8",
        )
        print(f"FALHA: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
