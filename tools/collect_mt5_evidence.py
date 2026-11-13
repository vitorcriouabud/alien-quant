#!/usr/bin/env python3
# ALIEN LAB | Coletor local de evidencias do MetaTrader 5.
# Python 3, somente biblioteca padrao. Nao executa ordens nem faz upload.
import argparse
import csv
import hashlib
import io
import json
import os
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EXTENSIONS = {".csv", ".htm", ".html"}
IGNORED_DIRS = {".git", ".venv", "node_modules", "__pycache__", "PACOTES_MT5"}
SENSITIVE_PARTS = ("password", "passwd", "secret", "token", "credential", ".env")


def default_sources():
    candidates = [REPO / "results", REPO / "REPORTS", REPO / "EXPERIMENTOS.csv"]
    legacy = Path.home() / ".gemini" / "antigravity" / "scratch" / "ALIEN_LAB"
    candidates += [legacy / "results", legacy / "EXPERIMENTOS.csv"]
    appdata = os.environ.get("APPDATA")
    if appdata:
        terminals = Path(appdata) / "MetaQuotes" / "Terminal"
        if terminals.is_dir():
            for folder in terminals.iterdir():
                if folder.is_dir():
                    candidates += [
                        folder / "MQL5" / "Files",
                        folder / "Tester",
                        folder / "tester",
                    ]
        tester = Path(appdata) / "MetaQuotes" / "Tester"
        if tester.is_dir():
            candidates.append(tester)
    portable = Path("C:/ALIEN_TEST_MT5")
    candidates += [portable / "MQL5" / "Files", portable / "Tester", portable / "tester",
                   portable / "reports"]
    return candidates


def iter_files(source, include_logs):
    allowed = EXTENSIONS | ({".log"} if include_logs else set())
    if source.is_file():
        if source.suffix.lower() in allowed:
            yield source
        return
    if not source.is_dir():
        return
    for base, dirs, files in os.walk(source, followlinks=False):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not d.startswith(".")]
        for filename in sorted(files):
            p = Path(base) / filename
            if p.suffix.lower() in allowed:
                yield p


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for data in iter(lambda: f.read(1024 * 1024), b""):
            h.update(data)
    return h.hexdigest()


def collect(args):
    dest = Path(args.output).expanduser().resolve()
    dest.mkdir(parents=True, exist_ok=True)
    sources = [Path(p).expanduser() for p in args.source] if args.source else default_sources()
    sources = [p.resolve() for p in sources if p.exists()]
    now = datetime.now(timezone.utc)
    cutoff = now.timestamp() - args.days * 86400 if args.days > 0 else None
    max_size = int(args.max_file_mb * 1024 * 1024)
    seen = set()
    selected = []
    skipped = {"duplicate": 0, "old": 0, "too_large": 0, "empty": 0, "sensitive_name": 0,
               "unreadable": 0, "limit": 0}

    for index, root in enumerate(sources, start=1):
        for path in iter_files(root, args.include_logs):
            try:
                resolved = path.resolve()
                if resolved in seen or dest == resolved or dest in resolved.parents:
                    skipped["duplicate"] += 1
                    continue
                seen.add(resolved)
                if any(k in path.name.lower() for k in SENSITIVE_PARTS):
                    skipped["sensitive_name"] += 1
                    continue
                stat = path.stat()
                if stat.st_size <= 0:
                    skipped["empty"] += 1
                    continue
                if stat.st_size > max_size:
                    skipped["too_large"] += 1
                    continue
                if cutoff is not None and stat.st_mtime < cutoff:
                    skipped["old"] += 1
                    continue
                if len(selected) >= args.max_files:
                    skipped["limit"] += 1
                    continue
                rel = path.relative_to(root) if root.is_dir() else Path(path.name)
                archive_name = f"fontes/{index:02d}_{root.name}/{rel.as_posix()}"
                selected.append({
                    "source": str(path), "arcname": archive_name,
                    "bytes": stat.st_size, "modified_utc": datetime.fromtimestamp(
                        stat.st_mtime, timezone.utc).isoformat(),
                    "sha256": sha256_file(path)
                })
            except (OSError, ValueError):
                skipped["unreadable"] += 1

    if not selected:
        print("NENHUM CSV/HTML encontrado. Verifique o local do MT5 ou use --source PASTA.", file=sys.stderr)
        return 2

    stamp = now.strftime("%Y%m%d_%H%M%S")
    zip_path = dest / f"ALIEN_EVIDENCIAS_{stamp}.zip"
    counter = 1
    while zip_path.exists():
        zip_path = dest / f"ALIEN_EVIDENCIAS_{stamp}_{counter}.zip"
        counter += 1

    manifest = {
        "schema": "alien-evidencia-v1", "collected_utc": now.isoformat(),
        "files": selected, "skipped": skipped,
        "note": "Coleta automatica, NAO e comprovacao de lucro. Verificar relatorios MT5 originais."
    }
    mem = io.StringIO()
    writer = csv.writer(mem, delimiter=";")
    writer.writerow(["arquivo_no_zip", "bytes", "sha256", "modificado_utc"])
    for f in selected:
        writer.writerow([f["arcname"], f["bytes"], f["sha256"], f["modified_utc"]])

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=6, allowZip64=True) as z:
        for item in selected:
            try:
                z.write(item["source"], item["arcname"])
            except (OSError, ValueError):
                print("Falha ao arquivar:", item["source"], file=sys.stderr)
                return 3
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        z.writestr("INVENTARIO.csv", mem.getvalue().encode("utf-8-sig"))
        z.writestr("LEIA_PRIMEIRO.txt",
                   "ALIEN LAB - Coleta automatica de CSVs e relatórios do MT5.\n"
                   "Enviar este ZIP na conversa do ChatGPT para auditoria.\n"
                   "Nao publique no GitHub publico sem conferir dados pessoais.\n"
                   "O pacote NAO contem comprovacao automatica de resultados.\n")
    with zipfile.ZipFile(zip_path) as z:
        bad = z.testzip()
        if bad is not None:
            raise RuntimeError(f"ZIP corrompido: {bad}")

    sidecar = zip_path.with_suffix(".manifest.json")
    sidecar.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"OK: {len(selected)} arquivos | ZIP: {zip_path}")
    print("Agora anexe esse ZIP na conversa do ChatGPT. Nada foi enviado automaticamente.")
    if any(skipped.values()):
        print("Ignorados:", json.dumps(skipped, ensure_ascii=False))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Empacota CSVs e HTML do MT5 para auditoria ALIEN.")
    parser.add_argument("--source", action="append", default=[],
                        help="Arquivo ou pasta especifica; repetir para varias fontes")
    parser.add_argument("--output", default=str(REPO / "PACOTES_MT5"),
                        help="Pasta local de saida")
    parser.add_argument("--days", type=int, default=30,
                        help="Apenas arquivos modificados nos ultimos N dias (0 = todos)")
    parser.add_argument("--max-file-mb", type=int, default=250)
    parser.add_argument("--max-files", type=int, default=800)
    parser.add_argument("--include-logs", action="store_true", help="Incluir .log (revisar privacidade)")
    args = parser.parse_args()
    if args.days < 0 or args.max_file_mb <= 0 or args.max_files <= 0:
        parser.error("Parametros numericos invalidos.")
    return collect(args)


if __name__ == "__main__":
    sys.exit(main())
