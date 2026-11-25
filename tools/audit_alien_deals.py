#!/usr/bin/env python3
"""Read-only reconciliation of ALIEN position CSVs against MT5 deal history.

The tool never connects to MT5 and never changes trading files. It reads CSVs
or a ZIP bundle and writes a Markdown audit report only when --output is used.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import re
import sys
import zipfile
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path


def canon(value: object) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]", "", text.lower())


def decode_bytes(raw: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-16", "utf-16-le", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeError:
            pass
    return raw.decode("utf-8", errors="replace")


def parse_csv_bytes(raw: bytes, source: str) -> dict:
    text = decode_bytes(raw)
    sample = text[:8192]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=";,\t")
        delimiter = dialect.delimiter
    except csv.Error:
        counts = {d: sample.count(d) for d in (";", ",", "\t")}
        delimiter = max(counts, key=counts.get)
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    if not reader.fieldnames:
        raise ValueError(f"{source}: CSV sem cabecalho.")
    rows = [dict(row) for row in reader if row and any(str(v or "").strip() for v in row.values())]
    return {
        "source": source,
        "headers": list(reader.fieldnames),
        "rows": rows,
        "delimiter": delimiter,
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def header_set(doc: dict) -> set[str]:
    return {canon(h) for h in doc["headers"]}


def read_path(path: Path) -> dict:
    return parse_csv_bytes(path.read_bytes(), str(path))


def read_zip_members(path: Path) -> list[dict]:
    docs = []
    with zipfile.ZipFile(path, "r") as archive:
        for name in archive.namelist():
            if name.startswith("__MACOSX/") or name.endswith("/") or not name.lower().endswith(".csv"):
                continue
            try:
                docs.append(parse_csv_bytes(archive.read(name), f"{path.name}:{name}"))
            except (ValueError, UnicodeError):
                continue
    if not docs:
        raise ValueError("O ZIP nao contem CSVs legiveis.")
    return docs


def choose_doc(docs: list[dict], role: str, explicit: str | None = None) -> dict | None:
    if explicit:
        matches = [d for d in docs if d["source"].split(":", 1)[-1] == explicit or d["source"] == explicit]
        if not matches:
            raise ValueError(f"Arquivo/membro nao encontrado para {role}: {explicit}")
        return matches[0]

    candidates = []
    for doc in docs:
        h = header_set(doc)
        if role == "trades" and {"positionid", "liquidoconta"} <= h:
            candidates.append(doc)
        elif role == "deals" and {"positionid", "magic", "profit"} <= h and "commission" in h:
            candidates.append(doc)
        elif role == "events" and "event" in h:
            candidates.append(doc)
    if not candidates:
        return None
    # Largest file is the most likely complete export; every selected source is reported.
    return max(candidates, key=lambda d: len(d["rows"]))


def field(row: dict, *aliases: str, default: str = "") -> str:
    indexed = {canon(k): str(v or "").strip() for k, v in row.items()}
    for alias in aliases:
        key = canon(alias)
        if key in indexed:
            return indexed[key]
    return default


def number(value: object) -> float:
    s = str(value or "").strip().replace("\u00a0", "").replace(" ", "")
    if not s or s in {"-", "—", "N/A", "n/a"}:
        return 0.0
    if "," in s and "." in s:
        if s.rfind(".") > s.rfind(","):
            s = s.replace(",", "")
        else:
            s = s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", ".")
    try:
        return float(s)
    except ValueError as exc:
        raise ValueError(f"Valor numerico invalido: {value!r}") from exc


def norm_id(value: object) -> str:
    s = str(value or "").strip()
    if not s:
        return ""
    if re.fullmatch(r"\d+(?:\.0+)?", s):
        return str(int(float(s)))
    return s


def magic_number(value: object) -> int | None:
    try:
        return int(float(str(value).strip()))
    except (ValueError, TypeError):
        return None


def is_entry(value: str) -> bool:
    e = canon(value)
    return e in {"0", "2", "in", "inout", "dealentryin", "dealentryinout"}


def is_exit(value: str) -> bool:
    e = canon(value)
    return e in {"1", "2", "3", "out", "inout", "outby",
                 "dealentryout", "dealentryinout", "dealentryoutby"}


def net_of_deal(row: dict) -> float:
    return (
        number(field(row, "profit", "deal_profit"))
        + number(field(row, "commission", "deal_commission"))
        + number(field(row, "swap", "deal_swap"))
        + number(field(row, "fee", "deal_fee"))
    )


def load_inputs(args):
    if args.bundle:
        docs = read_zip_members(Path(args.bundle))
        trades = choose_doc(docs, "trades", args.trades_member)
        deals = choose_doc(docs, "deals", args.deals_member)
        events = choose_doc(docs, "events", args.events_member)
        if trades is None or deals is None:
            summary = "; ".join(f"{d['source']} [{', '.join(d['headers'][:8])}]" for d in docs)
            raise ValueError("Nao foi possivel identificar CSV de trades e de deals no ZIP. CSVs: " + summary)
        return trades, deals, events

    if not args.trades or not args.deals:
        raise ValueError("Informe --bundle ou ambos --trades e --deals.")
    trades = read_path(Path(args.trades))
    deals = read_path(Path(args.deals))
    events = read_path(Path(args.events)) if args.events else None
    return trades, deals, events


def reconcile(trades_doc: dict, deals_doc: dict, events_doc: dict | None,
              symbol: str, magic: int, tolerance: float) -> dict:
    trades_by_id = {}
    exact_duplicates = 0
    conflicting_ids = set()
    for row in trades_doc["rows"]:
        pid = norm_id(field(row, "position_id", "position_identifier"))
        if not pid:
            continue
        net = number(field(row, "liquido_conta", "net", "net_pnl", "net_profit"))
        fingerprint = tuple(sorted((canon(k), str(v or "").strip()) for k, v in row.items()))
        if pid in trades_by_id:
            old = trades_by_id[pid]
            if old["fingerprint"] == fingerprint:
                exact_duplicates += 1
            else:
                conflicting_ids.add(pid)
            continue
        trades_by_id[pid] = {"net": net, "row": row, "fingerprint": fingerprint}

    deals_by_id = defaultdict(list)
    target_magic_net = 0.0
    target_magic_rows = 0
    all_deal_net = 0.0
    for row in deals_doc["rows"]:
        deal_symbol = field(row, "symbol", "deal_symbol")
        if symbol and deal_symbol and deal_symbol.upper() != symbol.upper():
            continue
        pid = norm_id(field(row, "position_id", "deal_position_id", "position_identifier"))
        if not pid:
            continue
        deal_magic = magic_number(field(row, "magic", "deal_magic"))
        deal_net = net_of_deal(row)
        all_deal_net += deal_net
        if deal_magic == magic:
            target_magic_net += deal_net
            target_magic_rows += 1
        deals_by_id[pid].append(row)

    target_open_ids = set()
    external_close_positions = 0
    for pid, rows in deals_by_id.items():
        has_target_entry = False
        has_external_exit = False
        for row in rows:
            row_magic = magic_number(field(row, "magic", "deal_magic"))
            entry = field(row, "entry", "deal_entry")
            if row_magic == magic and (not entry or is_entry(entry)):
                has_target_entry = True
            if row_magic is not None and row_magic != magic and is_exit(entry):
                has_external_exit = True
        if has_target_entry:
            target_open_ids.add(pid)
            if has_external_exit:
                external_close_positions += 1

    matched = []
    missing = []
    mismatches = []
    no_target_magic = []
    external_magic_positions = []
    for pid, trade in trades_by_id.items():
        rows = deals_by_id.get(pid, [])
        if not rows:
            missing.append(pid)
            continue
        deal_total = sum(net_of_deal(r) for r in rows)
        delta = trade["net"] - deal_total
        magics = sorted({field(r, "magic", "deal_magic") or "?" for r in rows})
        has_target = any(magic_number(field(r, "magic", "deal_magic")) == magic for r in rows)
        if not has_target:
            no_target_magic.append(pid)
        if any(magic_number(m) != magic for m in magics):
            external_magic_positions.append((pid, ",".join(magics)))
        item = {"position_id": pid, "csv_net": trade["net"], "deal_net": deal_total,
                "delta": delta, "magics": ",".join(magics)}
        matched.append(item)
        if abs(delta) > tolerance:
            mismatches.append(item)

    events = Counter()
    if events_doc:
        for row in events_doc["rows"]:
            name = field(row, "event", "evento")
            if name:
                events[name] += 1

    return {
        "trades_source": trades_doc["source"], "trades_sha256": trades_doc["sha256"],
        "deals_source": deals_doc["source"], "deals_sha256": deals_doc["sha256"],
        "events_source": events_doc["source"] if events_doc else None,
        "events_sha256": events_doc["sha256"] if events_doc else None,
        "trade_rows": len(trades_doc["rows"]), "unique_trade_ids": len(trades_by_id),
        "exact_duplicates": exact_duplicates, "conflicting_ids": sorted(conflicting_ids),
        "deals_rows": sum(len(v) for v in deals_by_id.values()),
        "position_ids_with_deals": len(deals_by_id), "target_magic_rows": target_magic_rows,
        "target_magic_net": target_magic_net, "all_deal_net": all_deal_net,
        "target_open_ids": sorted(target_open_ids),
        "trade_net": sum(v["net"] for v in trades_by_id.values()),
        "matched": matched, "missing": missing, "mismatches": mismatches,
        "no_target_magic": no_target_magic,
        "external_magic_positions": external_magic_positions,
        "external_close_positions": external_close_positions,
        "orphan_target_ids": sorted(target_open_ids - set(trades_by_id)),
        "event_counts": events, "symbol": symbol, "magic": magic, "tolerance": tolerance,
    }


def render(result: dict) -> str:
    status = "RECONCILIADO" if not (
        result["missing"] or result["mismatches"] or result["conflicting_ids"] or result["no_target_magic"]
    ) else "PENDENTE"
    lines = [
        "# ALIEN — auditoria somente leitura de deals MT5",
        "",
        f"**Status:** {status}",
        f"**Símbolo / Magic de abertura:** {result['symbol'] or 'todos'} / {result['magic']}",
        f"**Tolerância monetária:** {result['tolerance']:.4f}",
        "",
        "## Fontes e integridade",
        f"- Trades EA: {result['trades_source']} — SHA-256 {result['trades_sha256']}",
        f"- Deals MT5: {result['deals_source']} — SHA-256 {result['deals_sha256']}",
    ]
    if result["events_source"]:
        lines.append(f"- Eventos EA: {result['events_source']} — SHA-256 {result['events_sha256']}")
    lines += [
        "",
        "## Resumo",
        f"- Linhas de trades: {result['trade_rows']}; IDs únicos: {result['unique_trade_ids']}",
        f"- Duplicatas idênticas ignoradas: {result['exact_duplicates']}",
        f"- IDs com conflito de conteúdo: {len(result['conflicting_ids'])}",
        f"- Deals lidos após filtro de símbolo: {result['deals_rows']}",
        f"- IDs de posição com deals: {result['position_ids_with_deals']}",
        f"- Deals com Magic {result['magic']}: {result['target_magic_rows']}",
        f"- P&L líquido CSV EA: {result['trade_net']:+.2f}",
        f"- P&L dos deals com Magic {result['magic']}: {result['target_magic_net']:+.2f}",
        f"- P&L de todos os deals carregados: {result['all_deal_net']:+.2f}",
        f"- Posições comparadas: {len(result['matched'])}; divergentes: {len(result['mismatches'])}",
        f"- Posições sem deals: {len(result['missing'])}",
        f"- Posições sem qualquer deal do Magic alvo: {len(result['no_target_magic'])}",
        f"- Posições com outros magics no mesmo ID: {len(result['external_magic_positions'])}",
        f"- IDs abertos pelo Magic alvo sem linha no CSV: {len(result['orphan_target_ids'])}",
        f"- Posições com deal de saída usando outro Magic: {result['external_close_positions']}",
        "",
        "## Divergências",
    ]
    if result["mismatches"]:
        lines.append("| Position ID | CSV EA | Deals MT5 | Diferença | Magics encontrados |")
        lines.append("|---|---:|---:|---:|---|")
        for x in result["mismatches"]:
            lines.append(f"| {x['position_id']} | {x['csv_net']:.2f} | {x['deal_net']:.2f} | {x['delta']:+.2f} | {x['magics']} |")
    else:
        lines.append("Nenhuma divergência acima da tolerância entre posições comparadas.")
    if result["missing"]:
        lines += ["", "IDs sem histórico de deals: " + ", ".join(result["missing"][:50])]
    if result["conflicting_ids"]:
        lines += ["", "IDs duplicados com conteúdo diferente: " + ", ".join(result["conflicting_ids"][:50])]
    if result["no_target_magic"]:
        lines += ["", "IDs sem deal do Magic de abertura esperado: " + ", ".join(result["no_target_magic"][:50])]
    if result["external_magic_positions"]:
        lines += ["", "Posições que incluem outros magics (todos os deals do mesmo ID foram somados):"]
        lines += [f"- {pid}: {magics}" for pid, magics in result["external_magic_positions"][:50]]
    if result["orphan_target_ids"]:
        lines += ["", "IDs com entrada do Magic alvo, mas ausentes do CSV (podem estar abertos ou faltar no CSV):"]
        lines += ["- " + ", ".join(result["orphan_target_ids"][:50])]
    if result["event_counts"]:
        lines += ["", "## Contagem de eventos EA"]
        lines += [f"- {name}: {count}" for name, count in sorted(result["event_counts"].items())]
    lines += [
        "",
        "## Regra de reconciliação",
        "Uma posição é associada ao ALIEN pelo deal de entrada com o Magic informado. Para essa Position ID, o P&L soma lucro, comissão, swap e fee de todos os deals do mesmo símbolo/ID, inclusive eventual fechamento com Magic diferente. O relatório não atribui esse fechamento a outro EA sem evidência adicional.",
        "",
        "Limitações: a exportação deve cobrir o mesmo período, conta e símbolo dos CSVs. Ausência de deal pode indicar janela curta, símbolo com sufixo, histórico incompleto ou ID diferente. Este relatório não prova rentabilidade nem modifica o MT5.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconcilia CSV do EA com histórico de deals MT5, sem alterar entradas.")
    parser.add_argument("--bundle", help="ZIP contendo CSV de trades EA, deals MT5 e, opcionalmente, eventos.")
    parser.add_argument("--trades", help="CSV de posições fechadas pelo EA.")
    parser.add_argument("--deals", help="CSV exportado do histórico de deals MT5.")
    parser.add_argument("--events", help="CSV opcional de eventos do EA.")
    parser.add_argument("--trades-member", help="Nome do membro CSV de trades dentro do ZIP.")
    parser.add_argument("--deals-member", help="Nome do membro CSV de deals dentro do ZIP.")
    parser.add_argument("--events-member", help="Nome do membro CSV de eventos dentro do ZIP.")
    parser.add_argument("--symbol", default="XAUUSD")
    parser.add_argument("--magic", type=int, default=802092)
    parser.add_argument("--tolerance", type=float, default=0.01)
    parser.add_argument("--output", help="Grava o relatório Markdown neste caminho; sem isso, imprime no terminal.")
    args = parser.parse_args()

    try:
        trades, deals, events = load_inputs(args)
        result = reconcile(trades, deals, events, args.symbol, args.magic, args.tolerance)
        report = render(result)
        if args.output:
            Path(args.output).write_text(report, encoding="utf-8")
            print(f"Relatorio salvo: {args.output}")
        else:
            print(report)
        return 0
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
