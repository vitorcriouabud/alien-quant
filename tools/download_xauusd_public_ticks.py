#!/usr/bin/env python3
"""One-click downloader for public XAUUSD tick archives (Dukascopy feed).

Downloads weekly CSV.GZ files and metadata from the public Touhid-HZ dataset
repositories. Uses only the Python standard library; no MT5, Node, pandas,
API key, login, or broker account is required.

The data is Dukascopy OTC spot-gold quotes, not the user's broker execution
history and not exchange-traded volume.
"""
import argparse
import concurrent.futures
import datetime
import gzip
import hashlib
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DATASETS = {
    2024: "Touhid-HZ/xauusd-tick-data-2024",
    2025: "Touhid-HZ/xauusd-tick-data-2025",
    2026: "Touhid-HZ/xauusd-tick-data-2026",
}
RAW_ROOT = "https://raw.githubusercontent.com"
USER_AGENT = "ALIEN-XAUUSD-DataEngine/1.0 (historical research)"
HEADER = "timestamp,ask,bid,ask_volume,bid_volume"
CHUNK_SIZE = 1024 * 1024


def make_request(url, headers=None, timeout=90):
    request_headers = {"User-Agent": USER_AGENT, "Accept-Encoding": "identity"}
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(url, headers=request_headers)
    return urllib.request.urlopen(request, timeout=timeout)


def fetch_json(url):
    with make_request(url, timeout=60) as response:
        raw = response.read()
    return json.loads(raw.decode("utf-8")), raw


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")
    os.replace(str(temp), str(path))


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        while True:
            block = stream.read(CHUNK_SIZE)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def download_streaming(url, destination, expected_bytes, attempts=5):
    """Download to .part, resume with HTTP Range when supported, then rename."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + ".part")

    if destination.exists() and destination.stat().st_size == expected_bytes:
        return "already-present"

    for attempt in range(1, attempts + 1):
        offset = partial.stat().st_size if partial.exists() else 0
        if offset >= expected_bytes:
            partial.unlink(missing_ok=True)
            offset = 0

        headers = {"Range": "bytes=%d-" % offset} if offset else {}
        try:
            with make_request(url, headers=headers, timeout=180) as response:
                status = getattr(response, "status", response.getcode())
                append = bool(offset and status == 206)
                mode = "ab" if append else "wb"
                with open(partial, mode) as output:
                    shutil.copyfileobj(response, output, CHUNK_SIZE)

            actual = partial.stat().st_size
            if actual != expected_bytes:
                if actual > expected_bytes:
                    partial.unlink(missing_ok=True)
                if attempt == attempts:
                    raise RuntimeError(
                        "tamanho incorreto em %s: esperado %d, recebido %d"
                        % (destination.name, expected_bytes, actual)
                    )
                time.sleep(min(attempt * 2, 12))
                continue

            os.replace(str(partial), str(destination))
            return "downloaded"

        except urllib.error.HTTPError as exc:
            if exc.code == 416:
                partial.unlink(missing_ok=True)
            if attempt == attempts:
                raise
        except Exception:
            if attempt == attempts:
                raise
        time.sleep(min(attempt * 2, 12))

    raise RuntimeError("download nao concluido: " + destination.name)


def verify_gzip(path, expected_rows):
    """Stream the whole gzip: verifies CRC, schema, row count and quote sanity."""
    count = 0
    previous_timestamp = ""
    first_timestamp = None
    last_timestamp = None

    with gzip.open(path, "rt", encoding="utf-8", newline="") as stream:
        header = stream.readline().strip()
        if header != HEADER:
            raise ValueError("%s: cabecalho inesperado: %r" % (path.name, header))

        for line_number, line in enumerate(stream, start=2):
            parts = line.rstrip("\r\n").split(",")
            if len(parts) != 5:
                raise ValueError("%s: linha %d tem %d colunas" %
                                 (path.name, line_number, len(parts)))
            timestamp, ask_text, bid_text, ask_volume_text, bid_volume_text = parts
            try:
                ask = float(ask_text)
                bid = float(bid_text)
                ask_volume = float(ask_volume_text)
                bid_volume = float(bid_volume_text)
            except ValueError as exc:
                raise ValueError("%s: valor invalido na linha %d" %
                                 (path.name, line_number)) from exc

            if ask < bid:
                raise ValueError("%s: ask < bid na linha %d" %
                                 (path.name, line_number))
            if ask_volume < 0 or bid_volume < 0:
                raise ValueError("%s: volume negativo na linha %d" %
                                 (path.name, line_number))
            if previous_timestamp and timestamp < previous_timestamp:
                raise ValueError("%s: timestamp retrocedeu na linha %d" %
                                 (path.name, line_number))

            if first_timestamp is None:
                first_timestamp = timestamp
            previous_timestamp = timestamp
            last_timestamp = timestamp
            count += 1

    if count != expected_rows:
        raise ValueError("%s: esperado %d ticks, encontrados %d" %
                         (path.name, expected_rows, count))

    return {
        "rows_verified": count,
        "first_timestamp_utc": first_timestamp,
        "last_timestamp_utc": last_timestamp,
        "gzip_crc": "OK",
        "schema": "OK",
        "timestamp_order": "OK",
        "ask_ge_bid": "OK",
        "volumes_nonnegative": "OK",
    }


def process_week(year, repo, filename, output_dir, workers_note=""):
    base_url = "%s/%s/main/data/tick" % (RAW_ROOT, repo)
    meta_name = filename.replace(".csv.gz", ".meta.json")
    year_dir = output_dir / str(year)
    year_dir.mkdir(parents=True, exist_ok=True)

    meta_url = base_url + "/" + meta_name
    meta, meta_raw = fetch_json(meta_url)
    if meta.get("file") != filename:
        raise ValueError("metadado nao corresponde ao arquivo: " + filename)

    expected_bytes = int(meta["compressed_bytes"])
    expected_rows = int(meta["rows"])
    data_path = year_dir / filename
    meta_path = year_dir / meta_name
    verify_path = year_dir / (filename + ".verified.json")
    meta_hash = hashlib.sha256(meta_raw).hexdigest()

    meta_path.write_bytes(meta_raw)
    cached_ok = False
    if data_path.exists() and data_path.stat().st_size == expected_bytes and verify_path.exists():
        try:
            previous = json.loads(verify_path.read_text(encoding="utf-8"))
            cached_ok = (
                previous.get("compressed_bytes") == expected_bytes
                and previous.get("expected_rows") == expected_rows
                and previous.get("meta_sha256") == meta_hash
            )
        except Exception:
            cached_ok = False

    if cached_ok:
        return {
            "file": filename, "rows": expected_rows,
            "compressed_bytes": expected_bytes, "status": "cached-and-verified",
        }

    url = base_url + "/" + filename
    download_status = download_streaming(url, data_path, expected_bytes)
    verification = verify_gzip(data_path, expected_rows)
    verification.update({
        "file": filename,
        "year": year,
        "compressed_bytes": expected_bytes,
        "meta_sha256": meta_hash,
        "verified_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    })
    atomic_json(verify_path, verification)

    return {
        "file": filename, "rows": expected_rows,
        "compressed_bytes": expected_bytes, "status": download_status + "-verified",
    }


def year_files(year, repo, output_dir):
    status_url = "%s/%s/main/DATA_STATUS.json" % (RAW_ROOT, repo)
    status, raw = fetch_json(status_url)
    status_path = output_dir / str(year) / "DATA_STATUS.json"
    status_path.parent.mkdir(parents=True, exist_ok=True)
    status_path.write_bytes(raw)

    listed = status.get("files")
    if listed:
        filenames = [item["file"] for item in listed]
    else:
        weekly_count = int(status["totals"]["weekly_files"])
        filenames = [
            "XAUUSD_%d_w%02d.csv.gz" % (year, week)
            for week in range(1, weekly_count + 1)
        ]
    return status, filenames


def main():
    parser = argparse.ArgumentParser(
        description="Baixa ticks publicos XAUUSD 2024-2026 sem MT5 e sem dependencias externas."
    )
    parser.add_argument("--years", nargs="+", type=int, choices=sorted(DATASETS),
                        default=[2024, 2025, 2026])
    parser.add_argument("--output-dir", default="DATA/TICKS",
                        help="pasta de destino (padrao: DATA/TICKS)")
    parser.add_argument("--workers", type=int, default=3,
                        help="downloads simultaneos (padrao: 3)")
    args = parser.parse_args()

    if args.workers < 1 or args.workers > 6:
        parser.error("--workers deve ficar entre 1 e 6")

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    summary = {
        "created_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "source": "Dukascopy Bank SA public XAUUSD OTC tick feed, packaged in public weekly repositories",
        "schema": HEADER,
        "timezone": "UTC",
        "years": {},
        "limitations": [
            "Feed OTC da Dukascopy; nao e identico ao feed da corretora do usuario.",
            "Volumes sao indicativos do feed OTC, nao volume negociado de bolsa.",
            "Dados de 2026 estao atualizados ate a cobertura indicada no DATA_STATUS.json.",
        ],
    }

    for year in args.years:
        repo = DATASETS[year]
        print("\n[%d] Consultando manifesto publico..." % year, flush=True)
        status, filenames = year_files(year, repo, output_dir)
        expected_total = int(status["totals"]["ticks"])
        expected_bytes = int(status["totals"]["compressed_bytes"])
        print("[%d] %s arquivos semanais | %s ticks | %.1f MB comprimidos" %
              (year, len(filenames), format(expected_total, ","), expected_bytes / 1e6),
              flush=True)

        results = []
        failures = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {
                pool.submit(process_week, year, repo, filename, output_dir): filename
                for filename in filenames
            }
            for future in concurrent.futures.as_completed(futures):
                filename = futures[future]
                try:
                    result = future.result()
                    results.append(result)
                    print("[%d] %s | %s ticks | %s" %
                          (year, result["file"], format(result["rows"], ","), result["status"]),
                          flush=True)
                except Exception as exc:
                    failures.append({"file": filename, "error": str(exc)})
                    print("[%d] FALHOU %s: %s" % (year, filename, exc), flush=True)

        rows_downloaded = sum(item["rows"] for item in results)
        bytes_downloaded = sum(item["compressed_bytes"] for item in results)
        year_result = {
            "repository": repo,
            "coverage": status.get("coverage"),
            "expected_ticks": expected_total,
            "verified_ticks": rows_downloaded,
            "expected_compressed_bytes": expected_bytes,
            "verified_compressed_bytes": bytes_downloaded,
            "weekly_files_expected": len(filenames),
            "weekly_files_verified": len(results),
            "failures": failures,
        }
        summary["years"][str(year)] = year_result

        if failures or len(results) != len(filenames) or rows_downloaded != expected_total:
            atomic_json(output_dir / "ALIEN_XAUUSD_DOWNLOAD_SUMMARY.json", summary)
            print("\nANO %d INCOMPLETO. Rode novamente para retomar os arquivos faltantes." % year,
                  file=sys.stderr)
            return 2

    summary["total_ticks_verified"] = sum(
        item["verified_ticks"] for item in summary["years"].values()
    )
    summary["total_compressed_bytes"] = sum(
        item["verified_compressed_bytes"] for item in summary["years"].values()
    )
    summary["status"] = "ALL_SELECTED_YEARS_VERIFIED"
    atomic_json(output_dir / "ALIEN_XAUUSD_DOWNLOAD_SUMMARY.json", summary)

    print("\nCONCLUIDO: %s ticks verificados." %
          format(summary["total_ticks_verified"], ","), flush=True)
    print("Pasta: %s" % output_dir, flush=True)
    print("Resumo: %s" % (output_dir / "ALIEN_XAUUSD_DOWNLOAD_SUMMARY.json"), flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrompido pelo usuario. Arquivos completos ficam preservados; execute novamente para retomar.")
        raise SystemExit(130)
