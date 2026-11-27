"""Recepção de mensagens e cópias SQLite pelo supervisor existente."""
from contextlib import closing
from pathlib import Path
import argparse
import base64
import binascii
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import tempfile

SAFE_ID = re.compile(r"[A-Za-z0-9_-]{1,80}")
SHA256 = re.compile(r"[a-f0-9]{64}")
MAX_DB = 12 * 1024 * 1024
MAX_CMS = 48 * 1024 * 1024
DATABASES = {"alien.db": "alien.db", "science.db": "intelligence/science.db"}


def parse(envelope, role):
    if envelope.get("schema") != "alien.task/v1" or not isinstance(envelope.get("payload"), dict):
        raise ValueError("Envelope de comunicação inválido.")
    job = envelope["payload"]
    if (job.get("recipient") != role or job.get("sender") != "samsung-i3" or role != "dell-i7"
            or not isinstance(job.get("correlation_id"), str)
            or not SAFE_ID.fullmatch(job["correlation_id"])):
        raise ValueError("Rota ou correlação de mensagem inválida.")
    common = {"sender", "recipient", "correlation_id", "kind"}
    if job.get("kind") == "ping" and set(job) == common:
        return job
    if set(job) != common | {"snapshot_id", "cms_sha256", "db_sha256"} or job.get("kind") != "sqlite_snapshot":
        raise ValueError("Tipo ou campos de mensagem inválidos.")
    snapshot = job["snapshot_id"]
    hashes = job["db_sha256"]
    if (not isinstance(snapshot, str) or not SAFE_ID.fullmatch(snapshot)
            or not isinstance(hashes, dict) or set(hashes) != set(DATABASES)
            or any(not isinstance(v, str) or not SHA256.fullmatch(v)
                   for v in [job["cms_sha256"], *hashes.values()])):
        raise ValueError("Metadados de snapshot inválidos.")
    return job


def run_cms(command, **kwargs):
    powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    try:
        return subprocess.run(
            [str(powershell), "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop';" + command],
            capture_output=True, check=True, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW, **kwargs,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        raise ValueError("Operação CMS falhou com o certificado local.") from None


def decrypt(path, thumbprint):
    if not isinstance(thumbprint, str) or not re.fullmatch(r"[A-F0-9]{40}", thumbprint):
        raise ValueError("Certificado local inválido.")
    command = (
        f"$cert=Get-Item 'Cert:\\CurrentUser\\My\\{thumbprint}';"
        "$cms=[Console]::In.ReadToEnd(); Unprotect-CmsMessage -Content $cms -To $cert"
    )
    with path.open("rb") as stream:
        return json.loads(run_cms(command, stdin=stream))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inspect_sqlite(path, name):
    with closing(sqlite3.connect(f"{path.as_uri()}?mode=ro&immutable=1", uri=True)) as connection:
        connection.execute("PRAGMA trusted_schema=OFF")
        if connection.execute("PRAGMA integrity_check").fetchmany(2) != [("ok",)]:
            raise ValueError("Falha de integridade SQLite.")
        tables = set(row[0] for row in connection.execute("SELECT name FROM sqlite_schema WHERE type='table'"))
        expected = {"tasks", "execution_log", "supervisor_state", "artifacts"} if name == "alien.db" else {"datasets", "strategies", "campaigns"}
        if not expected.issubset(tables):
            raise ValueError("O arquivo SQLite pertence a um esquema inesperado.")
    return {"sha256": digest(path), "bytes": path.stat().st_size, "integrity_check": "ok"}


def store_snapshot(entrada, state, job, options):
    snapshot = job["snapshot_id"]
    expected = options.get("expected_snapshots", {}).get(snapshot)
    if expected is not None and expected != job["db_sha256"]:
        raise ValueError("Hashes da tarefa divergem da evidência publicada pelo Samsung.")
    path = entrada / f"{snapshot}.cms"
    if not path.is_file() or not 0 < path.stat().st_size <= MAX_CMS:
        raise ValueError("Anexo CMS ausente ou acima do limite.")
    destination = state / "transferencias" / snapshot
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix=".peer-", dir=destination.parent) as work:
            stage = Path(work) / "validado"
            stage.mkdir()
            # Use a mesma cópia para verificar o anexo e descriptografá-lo.
            package = Path(work) / "entrada.cms"
            with path.open("rb") as source:
                package.write_bytes(source.read(MAX_CMS + 1))
            if package.stat().st_size > MAX_CMS or digest(package) != job["cms_sha256"]:
                raise ValueError("SHA-256 do anexo CMS divergente.")
            contents = decrypt(package, options["certificate_thumbprint"])
            if not isinstance(contents, dict) or set(contents) != {"snapshot_id", "databases"} or contents["snapshot_id"] != snapshot:
                raise ValueError("Identificador interno do snapshot divergente.")
            items = contents["databases"]
            if not isinstance(items, dict) or set(items) != set(DATABASES):
                raise ValueError("O snapshot deve conter exatamente os dois bancos.")
            evidence = {}
            for name, filename in DATABASES.items():
                encoded = items[name]
                if not isinstance(encoded, str) or len(encoded) > 4 * ((MAX_DB + 2) // 3):
                    raise ValueError("Banco fora do limite de tamanho.")
                data = base64.b64decode(encoded, validate=True)
                if len(data) > MAX_DB or hashlib.sha256(data).hexdigest() != job["db_sha256"][name]:
                    raise ValueError("SHA-256 do banco SQLite divergente.")
                db = stage / filename
                db.parent.mkdir(parents=True, exist_ok=True)
                db.write_bytes(data)
                evidence[name] = inspect_sqlite(db, name)
            if destination.exists():
                if any(digest(destination / filename) != job["db_sha256"][name] for name, filename in DATABASES.items()):
                    raise ValueError("Snapshot local anterior preservado por divergência.")
            else:
                stage.rename(destination)
    except (UnicodeError, binascii.Error, KeyError, OSError, sqlite3.Error):
        raise ValueError("Falha ao validar ou armazenar uma cópia SQLite.") from None
    return {"snapshot_id": snapshot, "db": evidence, "applied_to_supervisor": False}


def receive(entrada, state, envelope, options):
    job = parse(envelope, options["role"])
    reply = {
        "schema": "alien.peer_reply/v1", "sender": job["recipient"], "recipient": job["sender"],
        "correlation_id": job["correlation_id"], "uses_ai": False,
    }
    if job["kind"] == "ping":
        return {"summary": "Mensagem recebida pelo supervisor Dell.", **reply}
    snapshot = store_snapshot(entrada, state, job, options)
    return {"summary": "Dois snapshots SQLite recebidos e verificados em estado local.", **reply, "snapshot": snapshot}


def send(central, snapshot_root, snapshot_id, task_id, correlation_id, fingerprint):
    for tag in (snapshot_id, task_id, correlation_id):
        if not SAFE_ID.fullmatch(tag):
            raise ValueError("Identificador de envio inválido.")
    cert = central / "ALIEN_DELL_SQLITE_PUBLICO.cer"
    if not SHA256.fullmatch(fingerprint) or digest(cert) != fingerprint:
        raise ValueError("SHA-256 do certificado público divergente.")
    entrada = central / "MT5_DELL/ENTRADA"
    pending = entrada / "pendentes"
    if not pending.is_dir():
        raise ValueError("Fila Dell indisponível.")
    target = entrada / f"{snapshot_id}.cms"
    task = pending / f"{task_id}.json"
    if task.exists():
        raise FileExistsError("Consulte o resultado deste ID antes de reenviar.")

    contents, hashes = {}, {}
    for name, filename in DATABASES.items():
        with (snapshot_root / filename).open("rb") as file:
            data = file.read(MAX_DB + 1)
        if not data or len(data) > MAX_DB:
            raise ValueError("Banco fora do limite de tamanho.")
        hashes[name] = hashlib.sha256(data).hexdigest()
        contents[name] = base64.b64encode(data).decode("ascii")

    if not target.exists():
        with tempfile.TemporaryDirectory(prefix=".peer-", dir=entrada) as work:
            draft = Path(work) / "encrypted.cms"
            run_cms(
                "$cert=$env:ALIEN_PEER_CERT; $target=$env:ALIEN_PEER_DRAFT;"
                "$plain=[Console]::In.ReadToEnd(); Protect-CmsMessage -To $cert -Content $plain -OutFile $target",
                input=json.dumps({"snapshot_id": snapshot_id, "databases": contents}).encode("ascii"),
                env={**os.environ, "ALIEN_PEER_CERT": str(cert), "ALIEN_PEER_DRAFT": str(draft)},
            )
            if not 0 < draft.stat().st_size <= MAX_CMS:
                raise ValueError("CMS fora do limite de tamanho.")
            draft.rename(target)
    if not 0 < target.stat().st_size <= MAX_CMS:
        raise ValueError("CMS fora do limite de tamanho.")
    cms_sha256 = digest(target)
    payload = {
        "schema": "alien.task/v1", "id": task_id, "action": "peer_exchange",
        "payload": {
            "sender": "samsung-i3", "recipient": "dell-i7", "kind": "sqlite_snapshot",
            "correlation_id": correlation_id, "snapshot_id": snapshot_id,
            "cms_sha256": cms_sha256, "db_sha256": hashes,
        },
    }
    with tempfile.TemporaryDirectory(prefix=".peer-", dir=pending) as work:
        draft = Path(work) / "job.json"
        draft.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        draft.rename(task)
    print(json.dumps({"task_id": task_id, "snapshot_id": snapshot_id, "cms_sha256": cms_sha256}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--central", required=True, type=Path)
    parser.add_argument("--snapshot-root", required=True, type=Path)
    parser.add_argument("--snapshot-id", required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--correlation-id", required=True)
    parser.add_argument("--certificate-sha256", required=True)
    args = parser.parse_args()
    try:
        send(args.central.resolve(), args.snapshot_root.resolve(), args.snapshot_id, args.task_id,
             args.correlation_id, args.certificate_sha256)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Falha de envio: {exc}\n")


if __name__ == "__main__":
    main()
