"""Catálogo local de evidência e inventário das fontes de dados do executor."""
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import csv
import hashlib
import json
import re


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_optional(path):
    try:
        value = read_json(path)
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(root, location):
    files = []
    if not root.is_dir():
        return files
    for kind, extension in (("ticks", ".tkc"), ("history", ".hcc"), ("history", ".hcs")):
        pattern = f"*/{kind}/*/*{extension}"
        for path in sorted(root.glob(pattern)):
            server, _, symbol, name = path.relative_to(root).parts
            if not re.fullmatch(r"[A-Za-z0-9_.#-]{1,80}", symbol):
                continue
            try:
                size = path.stat().st_size
            except OSError:
                continue
            if size <= 0:
                continue
            files.append({
                "location": location,
                "server_folder": server,
                "symbol": symbol,
                "type": "native_ticks_cache" if kind == "ticks" else "native_bars_cache",
                "filename": name,
                "nominal_period": path.stem if path.stem.isdecimal() else None,
                "bytes": size,
                "coverage_verified": False,
            })
    return files


def tester_coverage(state, source_keys, overlaps_holdout):
    periods = {}
    for folder in sorted((state / "runs").glob("task_*")):
        result = read_optional(folder / "result.json")
        job = result.get("task", {})
        if job.get("model") != 4 or result.get("status") not in {"completed", "failed"}:
            continue
        if job.get("mode") != "local" or not result.get("sha256_report"):
            continue
        try:
            ini = (folder / "tester.ini").read_text(encoding="ascii")
            server_match = re.search(r"(?m)^Server=([\w.-]+)\s*$", ini)
            start = date.fromisoformat(job["from"].replace(".", "-"))
            stop = date.fromisoformat(job["to"].replace(".", "-"))
            if not server_match or overlaps_holdout(start, stop):
                continue
            server = server_match[1]
            get_source = source_keys.get(server.casefold())
            if not get_source or digest(folder / "report.htm") != result["sha256_report"]:
                continue
        except (OSError, ValueError, KeyError):
            continue
        quality = result.get("history_quality", "")
        if not isinstance(quality, str) or not re.search(r"\d+(?:[.,]\d+)?\s*%", quality):
            continue
        key = (get_source, job.get("symbol"), start.isoformat(), stop.isoformat(), quality)
        entry = {
            "source": get_source, "server": server, "symbol": job.get("symbol"),
            "from": start.isoformat(), "to_exclusive": stop.isoformat(),
            "timeframe": "M1", "ticks_processed": result.get("ticks"),
            "bars": result.get("bars"), "history_quality": quality,
            "coverage": "verified_on_dell" if result.get("real_ticks_confirmed") is True
            and result["status"] == "completed" else "rejected_by_tester_validation",
            "evidence": {"kind": "native_report_sha256", "id": folder.name, "sha256": result["sha256_report"]},
        }
        previous = periods.get(key)
        observed = result.get("data_source", {}).get("observed_servers", [])
        if {item.casefold() for item in observed} == {server.casefold()}:
            entry["evidence"]["observed_server"] = server
        if previous is None or entry["evidence"].get("observed_server"):
            periods[key] = entry
    return list(periods.values())


def imported_proof(item, source_servers, overlaps_holdout):
    recorded = read_optional(Path(item["file"]))
    report = recorded.get("report", {})
    source = item["source"]
    if source not in source_servers or recorded.get("lab_mode") != "DEMO":
        return None
    if recorded.get("status") != "ticks_reais_confirmados" or report.get("audit") != "reconciliado":
        return None
    try:
        start, stop = map(date.fromisoformat, recorded["period"])
        if overlaps_holdout(start, stop) or not report["quality"].startswith("100%"):
            return None
        return {
            "source": source, "server": source_servers[source], "symbol": report["symbol"],
            "from": start.isoformat(), "to_exclusive": stop.isoformat(),
            "timeframe": recorded["timeframe"], "ticks_processed": int(report["ticks"]),
            "bars": int(report["bars"]), "history_quality": report["quality"],
            "coverage": "verified_on_origin_host",
            "evidence": {"kind": "reconciled_v2_report", "url": item["url"],
                         "sha256": recorded["report_sha256"], "origin_host": item.get("origin_host")},
        }
    except (ValueError, KeyError, TypeError):
        return None


def csv_metadata(item):
    path = Path(item["path"])
    try:
        with path.open("rb", buffering=0) as stream:
            line = stream.readline(4096).decode("utf-8-sig")
            header = next(csv.reader([line], delimiter=item.get("delimiter", ",")), [])
        size = path.stat().st_size
    except (OSError, UnicodeError, csv.Error):
        return None
    columns = {name.lower() for name in header}
    if {"bid", "ask"}.issubset(columns):
        kind = "bid_ask_csv"
    elif {"open", "high", "low", "close"}.issubset(columns):
        kind = "ohlc_csv"
    else:
        return None
    # O catálogo lê apenas o cabeçalho e metadados declarados, inclusive na reserva.
    return {
        "name": path.name, "type": kind, "bytes": size,
        "columns": header, "source": item.get("source"), "symbol": item.get("symbol"),
        "declared_start": item.get("declared_start"),
        "time_basis": item.get("time_basis"), "coverage_verified": False,
        "holdout": item.get("holdout", False), "selectable": False,
        "location": item.get("location"),
    }


def build_catalog(options, state, default_mt5, source_servers, source_path, check_terminal, overlaps_holdout):
    configured = options.get("catalog", {})
    by_source = {}
    files = []
    for source, server in source_servers.items():
        path = source_path(default_mt5, options, source)
        entry = {"id": source, "server": server, "selectable": False}
        entry.update(configured.get("profiles", {}).get(source, {}))
        entry["selectable"] = False
        if path is not None:
            try:
                check_terminal(path, source)
            except (OSError, RuntimeError, ValueError):
                entry["availability"] = "demo_profile_unavailable"
            else:
                entry["selectable"] = True
                entry["availability"] = "ready_on_dell"
            files.extend(inventory(path / "bases", f"portable:{source}"))
            files.extend(inventory(path / "Tester/bases", f"tester:{source}"))
        else:
            entry["availability"] = "origin_profile_inaccessible_on_dell"
        by_source[source] = entry
    for item in configured.get("inventory", []):
        files.extend(inventory(Path(item["root"]), item["label"]))
    periods = tester_coverage(state, {v.casefold(): k for k, v in source_servers.items()}, overlaps_holdout)
    for proof in configured.get("imported_proofs", []):
        item = imported_proof(proof, source_servers, overlaps_holdout)
        if item is not None:
            periods.append(item)
    csv_sources = list(configured.get("csv", []))
    for series in configured.get("csv_daily_series", []):
        for path in sorted(Path(series["directory"]).glob(f"{series['symbol']}_????????.csv")):
            try:
                day = date.fromisoformat(path.stem.rsplit("_", 1)[-1])
            except ValueError:
                continue
            csv_sources.append({
                **series, "path": path, "declared_start": day.isoformat(),
                "holdout": overlaps_holdout(day, day + timedelta(days=1)),
            })
    csv_files = [result for item in csv_sources if (result := csv_metadata(item)) is not None]
    return {
        "schema": "alien.data_catalog/v1",
        "updated_utc": datetime.now(timezone.utc).isoformat(),
        "holdout_inclusive": ["2026-11-25", "2026-12-09"],
        "interval_convention": "from inclusive, to exclusive, em datas do servidor para o tester",
        "sources": list(by_source.values()), "coverage": periods, "inventory": files + csv_files,
        "remote_inventory": configured.get("remote_inventory", {}),
    }

