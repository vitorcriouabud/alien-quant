"""Identidade do experimento: dados, configuração, regras e código, sem conta/credenciais."""
from __future__ import annotations

import hashlib
import json
from dataclasses import asdict
from pathlib import Path

from alienlab.data import LabConfig
from alienlab.definitions import definitions_hash


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for part in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(part)
    return digest.hexdigest()


def identity(csv: Path, cfg: LabConfig) -> dict:
    if not csv.is_file():
        raise FileNotFoundError(f"CSV não encontrado: {csv}")
    root = Path(__file__).parent
    codes = {f.name: sha256_file(f) for f in sorted(root.glob("*.py"))}
    payload = {
        "schema": "alien_lab_v1_1_experiment_identity",
        "source_csv_sha256": sha256_file(csv),
        "source_csv_size_bytes": csv.stat().st_size,
        "config": asdict(cfg),
        "definitions_sha256": definitions_hash(),
        "code_sha256": codes,
    }
    # Não incluir caminho absoluto (não afeta a experiência); hash da identidade estável.
    payload = json.loads(json.dumps(payload, sort_keys=True, ensure_ascii=False))
    payload["experiment_sha256"] = hashlib.sha256(
        json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()
    return payload


def verify_identity(expected: dict, actual: dict) -> None:
    if expected != actual:
        fields = [k for k in actual if actual.get(k) != expected.get(k)]
        raise RuntimeError(f"Retomada bloqueada: dados/configuração/código diferentes: {fields}")
