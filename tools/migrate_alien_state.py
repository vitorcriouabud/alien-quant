"""Migra o estado local do ALIEN_CENTRAL com a instância anterior parada."""
import argparse
from contextlib import closing
import hashlib
import json
from pathlib import Path
import re
import shutil
import sqlite3
from tempfile import TemporaryDirectory


def sqlite_copy(source, target):
    with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)) as origin:
        with closing(sqlite3.connect(target)) as dest:
            origin.backup(dest)
            if dest.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise RuntimeError(f"Falha de integridade: {source.name}")


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def make_snapshot(source, target):
    import msvcrt

    db = source / "alien.db"
    if not db.is_file():
        raise FileNotFoundError("alien.db ausente no estado de origem")
    with (source / "supervisor.lock").open("a+b") as lock:
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as error:
            raise RuntimeError("O supervisor de origem ainda está em execução") from error
        sqlite_copy(db, target / "alien.db")
        intelligence = source / "intelligence"
        science = intelligence / "science.db"
        if science.is_file():
            (target / "intelligence").mkdir()
            sqlite_copy(science, target / "intelligence/science.db")
        for folder, pattern in (
            ("intelligence", r"[a-f0-9]{64}\.csv"),
            ("quant/bundles", r"task_[A-Za-z0-9_-]{1,80}\.zip"),
        ):
            original = source / folder
            for path in sorted(original.glob("*")):
                if path.is_file() and re.fullmatch(pattern, path.name):
                    destination = target / folder / path.name
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, destination)
        with closing(sqlite3.connect(target / "alien.db")) as saved:
            for task_id, digest_json in saved.execute(
                "SELECT task_id, result_json FROM tasks WHERE action='quant_backtest' AND status='publishing'"
            ):
                artifacts = json.loads(digest_json).get("artifacts", [])
                if artifacts:
                    if not re.fullmatch(r"task_[A-Za-z0-9_-]{1,80}", task_id):
                        raise ValueError("Identificador inválido na fila de publicação")
                    bundle = target / "quant/bundles" / (task_id + ".zip")
                    if not bundle.is_file() or digest(bundle) != artifacts[0]["sha256"]:
                        raise ValueError("Tarefa em publicação sem pacote íntegro no estado de origem")


def move_state(source, destination):
    source, destination = source.resolve(), destination.resolve()
    if destination.exists() or destination.is_relative_to(source):
        raise ValueError("Use um destino novo e fora da origem")
    if not source.is_dir():
        raise FileNotFoundError("Estado de origem inexistente")
    destination.parent.mkdir(parents=True, exist_ok=True)
    # O temporário e o destino ficam no mesmo volume.
    with TemporaryDirectory(prefix=".alien-migracao-", dir=destination.parent) as temp:
        staged = Path(temp) / "estado"
        staged.mkdir()
        make_snapshot(source, staged)
        staged.rename(destination)


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("source", type=Path)
    cli.add_argument("destination", type=Path)
    args = cli.parse_args()
    move_state(args.source, args.destination)
