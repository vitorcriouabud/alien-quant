#!/usr/bin/env python3
"""ALIEN LAB: read-only auditor of MT5 evidence ZIPs. Stdlib only, Python 3.9+.

Outputs contain aggregate/sanitized information only. Never republishes raw
MT5 reports, account numbers, original local paths, or CSV row identifiers.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import html
import io
import json
import re
import statistics
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MAX_MEMBER_BYTES = 20 * 1024 * 1024  # fail closed against oversized members
MAX_TOTAL_BYTES = 200 * 1024 * 1024
MAX_MEMBERS = 2000
VISUAL_KEYS = ("teacherpanel", "dashboard", "draw", "mapmaxdraw", "color", "font", "panel")
REGISTRY_FILE = "EXPERIMENTOS.csv"


def slug(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.-]", "_", s)


def decode(blob: bytes) -> str:
    if blob.startswith((b"\xff\xfe", b"\xfe\xff")):
        return blob.decode("utf-16")
    for enc in ("utf-8-sig", "cp1252"):
        try:
            return blob.decode(enc)
        except UnicodeDecodeError:
            pass
    return blob.decode("latin1", errors="replace")


def normal(s: str) -> str:
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFKD", str(s)) if not unicodedata.combining(c)).lower().strip().rstrip(":").strip()


def number(value):
    if value is None:
        return None
    s = str(value).replace("\xa0", " ").strip()
    match = re.search(r"[-+]?\d[\d\s.,]*", s)
    if not match:
        return None
    n = match.group(0).strip().replace(" ", "")
    if "." in n and "," in n:
        n = n.replace(",", "") if n.rfind(".") > n.rfind(",") else n.replace(".", "").replace(",", ".")
    elif "," in n:
        n = n.replace(",", ".")
    try:
        return float(n)
    except ValueError:
        return None


def group_exp(name: str):
    m = re.search(r"(?i)EXP[_-]?0*(\d{1,3})(?!\d)", name)
    return "EXP-" + str(int(m.group(1))).zfill(3) if m else None


def get_pairs(text: str):
    """MT5's HTML is table-driven; parse before the trade history sections."""
    rows = re.findall(r"<tr\b[^>]*>(.*?)</tr\s*>", text, re.I | re.S)
    fields, params = {}, {}
    broker = ""
    for index, row in enumerate(rows):
        values = [html.unescape(re.sub(r"<[^>]*>", "", td)).strip()
                  for td in re.findall(r"<t[dh]\b[^>]*>(.*?)</t[dh]\s*>", row, re.I | re.S)]
        values = [re.sub(r"\s+", " ", v) for v in values]
        if index == 1 and values:
            broker = values[0].split(" (Build")[0]
        for v in values:
            if re.fullmatch(r"[\w.]+\s*=\s*[^=\n]+", v):
                k, val = v.split("=", 1)
                if len(k) <= 100 and len(val) <= 200:
                    params[k.strip()] = val.strip()
        for i in range(len(values) - 1):
            k = values[i]
            if k.endswith(":") and len(k) < 100:
                name = normal(k)
                if name and name not in fields:
                    fields[name] = values[i + 1]
        if index > 450:
            break
    return fields, params, broker


def getval(pairs, *names):
    for n in names:
        v = pairs.get(normal(n))
        if v not in (None, ""):
            return v
    return None


def extract_report(name: str, blob: bytes):
    text = decode(blob)
    if "<html" not in text.lower() or not any(x in normal(text[:50000]) for x in ("testador", "strategy tester")):
        return None
    fields, inputs, broker = get_pairs(text)
    gross = getval(fields, "lucro bruto", "gross profit")
    net = getval(fields, "lucro liquido total", "total net profit")
    trades = getval(fields, "total de negociacoes", "total trades")
    if net is None or trades is None:
        return None
    period = getval(fields, "periodo", "period") or ""
    m = re.match(r"\s*([A-Z]+\d+)\s*\(\s*(\d{4}\.\d\d\.\d\d)\s*[-–]\s*(\d{4}\.\d\d\.\d\d)\s*\)", period)
    tf, start, end = m.groups() if m else (None, None, None)
    win = getval(fields, "negociacoes com lucro (% de total)", "profit trades (% of total)", "negociacoes com lucro", "profit trades")
    win_m = re.search(r"\((\d+(?:[.,]\d+)?)%\)", win or "")
    quality = getval(fields, "qualidade do historico", "history quality")
    dd = getval(fields, "rebaixamento maximo do capital liquido", "equity drawdown maximal", "maximum equity drawdown")
    if dd is None:
        dd = getval(fields, "rebaixamento relativo do capital liquido", "equity drawdown relative")
    dd_num = number(dd)
    dd_pct = re.search(r"\(([\d.,]+)%\)", dd or "")
    if not dd_pct and dd:
        pct_first = re.search(r"^([\d.,]+)%", dd)
        if pct_first:
            dd_pct = pct_first
            amount_m = re.search(r"\(([\d.,]+)\)", dd)
            dd_num = number(amount_m.group(1)) if amount_m else None
    param_sorted = json.dumps(inputs, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    econ_inputs = {k:v for k,v in inputs.items() if not any(term in k.lower() for term in VISUAL_KEYS)}
    econ_sorted = json.dumps(econ_inputs, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    source_name = Path(name).name
    result = {
        "file": source_name, "experiment": group_exp(source_name),
        "source_sha256": hashlib.sha256(blob).hexdigest(),
        "expert": (getval(fields, "expert advisor (robo)", "expert advisor", "expert") or "")[:100],
        "symbol": (getval(fields, "ativo", "symbol") or "")[:40],
        "broker": broker[:70], "timeframe": tf, "start": start, "end": end,
        "quality": (quality or "")[:80],
        "deposit": number(getval(fields, "deposito inicial", "initial deposit")),
        "leverage": (getval(fields, "alavancagem", "leverage") or "")[:20],
        "currency": (getval(fields, "moeda", "currency") or "")[:10],
        "profit": number(net), "gross_profit": number(gross),
        "gross_loss": number(getval(fields, "perda bruta", "gross loss")),
        "pf": number(getval(fields, "fator de lucro", "profit factor")),
        "trades": int(number(trades)) if number(trades) is not None else None,
        "win_rate_pct": number(win_m.group(1)) if win_m else None,
        "dd_money": dd_num, "dd_pct": number(dd_pct.group(1)) if dd_pct else None,
        "ticks": int(number(getval(fields, "ticks")) or 0),
        "input_count": len(inputs),
        "inputs_sha256": hashlib.sha256(param_sorted.encode()).hexdigest(),
        "economic_inputs_sha256": hashlib.sha256(econ_sorted.encode()).hexdigest(),
    }
    # Sensitive parameters are used only for local pairwise diagnosis and never emitted.
    result["_inputs"] = inputs
    return result


def read_table(blob: bytes):
    text = decode(blob)
    if not text or "\x00" in text[:100]:
        return None
    head = text.splitlines()[0] if text.splitlines() else ""
    sep = ";" if head.count(";") > head.count(",") else ","
    return csv.reader(io.StringIO(text), delimiter=sep)


def load_registry(zip_members):
    reg = {}
    for name, data in zip_members.items():
        if Path(name).name.upper() != REGISTRY_FILE:
            continue
        text = decode(data)
        for row in csv.DictReader(io.StringIO(text), delimiter=";"):
            key = (row.get("ID") or "").strip().upper()
            if key.startswith("EXP-"):
                reg[key] = {
                    "profit": number(row.get("Lucro_USD")),
                    "pf": number(row.get("Fator_Lucro")),
                    "trades": number(row.get("Trades")),
                    "declared_strategy": row.get("Estrategia", "")[:80],
                }
    return reg


def csv_statistics(members):
    result = {"observers": [], "opportunities": [], "trade_logs": [], "event_logs": [], "files_seen": 0}
    for name, data in members.items():
        if not name.lower().endswith(".csv") or Path(name).name == "INVENTARIO.csv":
            continue
        base = Path(name).name.upper()
        result["files_seen"] += 1
        if base == "ALIEN_CONFLUENCIA_OBSERVER.CSV":
            table = read_table(data)
            if table is None:
                continue
            reader = csv.DictReader(io.StringIO(decode(data)), delimiter=";")
            statuses, reasons, symbols, sent = collections.Counter(), collections.Counter(), collections.Counter(), 0
            spreads = []
            for row in reader:
                symbol = (row.get("symbol") or "INDEFINIDO").upper()
                symbols[symbol] += 1
                if not symbol.startswith("XAUUSD"):
                    continue
                statuses[row.get("status") or "INDEFINIDO"] += 1
                reasons[(row.get("reason") or "NÃO INFORMADO")[:90]] += 1
                sent += (row.get("orders_sent") or "").upper() in ("YES", "TRUE", "SIM")
                spread = number(row.get("spread_points_now"))
                if spread is not None:
                    spreads.append(spread)
            result["observers"].append({
                "source": "testador" if "Tester/" in name else "terminal",
                "total_rows": sum(symbols.values()), "symbols": dict(symbols),
                "xau_rows": sum(statuses.values()),
                "xau_status": dict(statuses), "xau_orders_sent_flags": sent,
                "xau_top_reasons": reasons.most_common(8),
                "xau_median_spread_points": round(statistics.median(spreads), 2) if spreads else None,
            })
        elif base == "OPORTUNIDADES_TODAS.CSV":
            t = csv.reader(io.StringIO(decode(data)), delimiter=";")
            try:
                header = next(t)
            except StopIteration:
                continue
            if "resultado_tentativa" not in header:
                continue
            outcomes = collections.Counter()
            for row in t:
                if len(row) < 8:
                    continue
                attempt = row[7].lower().strip()
                if attempt.startswith("ordem enviada"):
                    outcomes["ordem_enviada_registrada"] += 1
                elif "bloqueado" in attempt:
                    outcomes["bloqueada:" + attempt.replace("bloqueado:", "").strip()[:80]] += 1
                else:
                    outcomes[attempt[:80] or "outros"] += 1
            result["opportunities"].append({"rows": sum(outcomes.values()), "outcomes": outcomes.most_common(10)})
        elif base.startswith("ALIEN_V1089_TRADES_"):
            table = read_table(data)
            if table is None:
                continue
            rows = list(table)
            result["trade_logs"].append({"type": "V10.89", "rows": max(0, len(rows)-1), "header_only": len(rows) <= 1})
        elif base.startswith("ALIEN_V12_1_"):
            table = read_table(data)
            if table is None:
                continue
            events = collections.Counter()
            for row in table:
                if len(row) >= 4:
                    events[row[3].strip()] += 1
            result["event_logs"].append({"type": "V12.1", "events": events.most_common(12), "rows": sum(events.values())})
    return result


def compare(reports, registry):
    warnings = []
    # Do not compare across different periods/brokers/timeframes as A/B.
    by_number = collections.defaultdict(list)
    for r in reports:
        if r["experiment"]:
            by_number[r["experiment"]].append(r)
    for exp, entries in sorted(by_number.items()):
        if len(entries) < 2:
            continue
        values = {(x["profit"], x["pf"], x["trades"]) for x in entries}
        if len(values) > 1:
            baseline = entries[0]
            comparable = all((e["expert"], e["symbol"], e["timeframe"], e["start"],
                              e["end"], e["broker"], e["quality"], e["deposit"],
                              e["economic_inputs_sha256"]) ==
                             (baseline["expert"], baseline["symbol"], baseline["timeframe"],
                              baseline["start"], baseline["end"], baseline["broker"],
                              baseline["quality"], baseline["deposit"],
                              baseline["economic_inputs_sha256"]) for e in entries)
            code = "EXP_DIVERGENTE" if comparable else "ID_REUTILIZADO_CENARIOS_DISTINTOS"
            details = ("Mesmo ID e cenarios aparentemente equivalentes, mas metricas divergentes."
                       if comparable else "Mesmo ID usado em cenarios diferentes; nao tratar como reproducao exata.")
            warnings.append({"severity": "ALTA", "code": code, "experiment": exp,
                             "details": details, "files": [x["file"] for x in entries]})
    for exp, declared in sorted(registry.items()):
        matches = by_number.get(exp, [])
        if not matches:
            continue  # not all records present in a partial ZIP
        for r in matches:
            diffs = []
            for field, tolerance in (("profit", 0.011), ("pf", 0.011), ("trades", 0.1)):
                if declared[field] is not None and r[field] is not None and abs(declared[field] - r[field]) > tolerance:
                    diffs.append(field)
            if diffs:
                warnings.append({"severity": "ALTA", "code": "REGISTRO_DIVERGENTE", "experiment": exp,
                                 "details": "Divergencia do cadastro: " + ", ".join(diffs), "files": [r["file"]]})
    fingerprint = collections.defaultdict(list)
    for r in reports:
        keys = (r["expert"], r["symbol"], r["timeframe"], r["start"], r["end"],
                r["deposit"], r["leverage"], r["currency"], r["broker"], r["quality"],
                r["economic_inputs_sha256"])
        fingerprint[keys].append(r)
    for group in fingerprint.values():
        if len(group) < 2:
            continue
        different = {(r["profit"], r["pf"], r["trades"]) for r in group}
        if len(different) <= 1:
            continue
        visual_diff = sorted({k for r in group for k in r["_inputs"]
                              if len({v["_inputs"].get(k) for v in group}) > 1})
        warnings.append({"severity": "CRITICA", "code": "MESMAS_ENTRADAS_RESULTADOS_DIFERENTES",
                         "experiment": ", ".join(sorted({r["experiment"] or "SEM ID" for r in group})),
                         "details": "Mesmo ambiente e parametros nao-visuais; resultados diferentes. "
                                    "Parametros diferentes registrados: " + (", ".join(visual_diff[:12]) or "nenhum")
                                    + ". Codigo compilado/historico externo/estado nao comprovados.",
                         "files": [r["file"] for r in group]})
    return warnings


def fmt(val, decimals=2):
    return "N/D" if val is None else f"{val:+,.{decimals}f}" if isinstance(val, (float, int)) else str(val)


def create_markdown(name, reports, summary, warnings, registry):
    lines = ["# ALIEN LAB — Auditoria automatica de evidencias MT5", "",
             f"**Coleta analisada:** `{name}`", "",
             f"**Arquivos verificados:** {summary['verified_files']} de {summary['manifest_files']} (SHA256). "
             f"**Relatorios MT5 interpretados:** {len(reports)}. **Alertas:** {len(warnings)}.", "",
             "> Este relatorio compara backtests existentes. Nao executa ordens, nao valida compilacao e nao comprova lucro futuro.", "",
             "## Comparacao de relatorios originais", "",
             "| Relatorio | Experimento | Periodo | Corretora | Lucro liquido | PF | Negocios | DD equity |", "|---|---|---|---|---:|---:|---:|---:|"]
    for r in reports:
        period = f"{r['start']} a {r['end']}" if r["start"] else "N/D"
        lines.append(f"| {r['file']} | {r['experiment'] or '—'} | {period} | {r['broker'] or 'N/D'} | {fmt(r['profit'])} | {fmt(r['pf'])} | {r['trades'] if r['trades'] is not None else 'N/D'} | {fmt(r['dd_money'])} |")
    lines += ["", "## Alertas de auditoria", ""]
    if not warnings:
        lines.append("Nenhum conflito detectado pelas regras atuais; isso nao equivale a validar os testes.")
    for w in warnings:
        lines.append(f"- **{w['severity']} · {w['code']} · {w['experiment']}** — {w['details']} Arquivos: {', '.join(w['files'])}.")
    lines += ["", "## Telemetria CSV: observadores", ""]
    for index, ob in enumerate(summary["csv"]["observers"], start=1):
        lines.append(f"### Fonte {index} ({ob['source']})")
        lines.append(f"- Total: {ob['total_rows']} linhas; XAUUSD: {ob['xau_rows']}; flags de envio XAU: {ob['xau_orders_sent_flags']}.")
        lines.append(f"- Ativos: {', '.join(f'{k}={v}' for k, v in sorted(ob['symbols'].items()))}.")
        lines.append(f"- Status XAU: {', '.join(f'{k}={v}' for k, v in ob['xau_status'].items()) or 'N/D'}.")
        lines.append(f"- Principais motivos XAU: {', '.join(f'{k} ({v})' for k, v in ob['xau_top_reasons']) or 'N/D'}.")
        lines.append("")
    for ob in summary["csv"]["opportunities"]:
        lines += ["## Tentativas registradas no TURBO (nao sao necessariamente trades executados)", "",
                  f"Total de registros: **{ob['rows']}**.", ""]
        for k,v in ob["outcomes"]:
            lines.append(f"- {k}: {v}")
        lines.append("")
    blanks = sum(x["header_only"] for x in summary["csv"]["trade_logs"])
    if summary["csv"]["trade_logs"]:
        lines += ["## Telemetria de operacoes V10.89", "",
                  f"Arquivos analisados: {len(summary['csv']['trade_logs'])}. "
                  f"Com apenas cabecalho: **{blanks}**. "
                  "Um CSV com apenas cabecalho **nao prova** ausencia de trades em outros terminais ou periodos.", ""]
    lines += ["## Limites e criterio de comparacao", "",
              "- Um registro de EXPERIMENTOS.csv nao substitui relatorio original do MT5; conflitos foram explicitados.",
              "- Nao somar lucros de testes com janelas sobrepostas ou parametros diferentes.",
              "- Uma mesma versao pode ter resultados diferentes por compilacao, dados, configuracao e estado de terminal; o HTML nao inclui hash do EA compilado.",
              "- Nao concluir que um filtro funciona apenas comparando testes de duracao ou corretoras diferentes.",
              "- Os CSVs de sinais podem registrar apenas observacao ou tentativa: nao equivalem a negocios executados.",
              "- Esse relatorio nao inclui dados brutos, numeros de conta nem caminhos locais originais.", "",
              "## Proxima rodada", "",
              "1. Congelar fonte .mq5/.ex5 e .set com hashes e registrar ID exclusivo do experimento.",
              "2. Reexecutar experimentos divergentes no mesmo terminal isolado e comparar entradas/saidas.",
              "3. Usar holdout separado do periodo de ajustes; exigir custos reais e limites de risco verificaveis.", ""]
    return "\n".join(lines)


def create_html(markdown):
    # Lightweight HTML for Windows viewing; escape every line, no CDN/JS.
    lines = markdown.splitlines()
    result = ["<!doctype html><html lang='pt-BR'><meta charset='utf-8'>",
              "<meta name='viewport' content='width=device-width,initial-scale=1'><title>ALIEN LAB - Auditoria</title>",
              "<style>body{font:16px system-ui,Arial;background:#10141a;color:#eef2f5;max-width:1200px;margin:auto;padding:28px}h1,h2,h3{color:#f8d542}table{border-collapse:collapse;font-size:13px;width:100%;margin:20px 0}th,td{padding:10px;border:1px solid #48515b;text-align:left}tr:nth-child(even){background:#1b222b}code{color:#ffe891}blockquote{border-left:3px solid #f8d542;padding:8px 16px;background:#222933}li{margin:6px 0}.scroll{overflow-x:auto}</style><body>"]
    in_table = False
    in_list = False
    for line in lines:
        if line.startswith("| "):
            if "---|" in line:
                continue
            if not in_table:
                result.append("<div class='scroll'><table>")
                in_table=True
            cells=[html.escape(c.strip()) for c in line.strip().strip("|").split("|")]
            tag = "th" if line.startswith("| Relatorio ") else "td"
            result.append("<tr>"+"".join(f"<{tag}>{c}</{tag}>" for c in cells)+"</tr>")
            continue
        if in_table:
            result.append("</table></div>");in_table=False
        if line.startswith("- ") or re.match(r"^\d+\. ", line):
            if not in_list: result.append("<ul>");in_list=True
            s=re.sub(r"^(?:- |\d+\. )", "", line)
            result.append("<li>"+html.escape(s)+"</li>")
            continue
        if in_list: result.append("</ul>");in_list=False
        if not line.strip():continue
        level = len(line) - len(line.lstrip("#"))
        if line.startswith("#") and level <= 3:
            result.append(f"<h{level}>{html.escape(line[level:].strip())}</h{level}>")
        elif line.startswith(">"):
            result.append("<blockquote>"+html.escape(line[1:].strip())+"</blockquote>")
        else:
            result.append("<p>"+html.escape(line)+"</p>")
    if in_table:result.append("</table></div>")
    if in_list:result.append("</ul>")
    result.append("</body></html>")
    return "\n".join(result)


def analyze(zip_path: Path, output: Path):
    output.mkdir(parents=True, exist_ok=True)
    members = {}
    with zipfile.ZipFile(zip_path, "r") as z:
        if len(z.infolist()) > MAX_MEMBERS:
            raise ValueError("Pacote tem arquivos demais (limite de seguranca).")
        total_size = 0
        for info in z.infolist():
            if info.is_dir():
                continue
            if info.file_size > MAX_MEMBER_BYTES:
                raise ValueError("Arquivo dentro do ZIP excede limite de 20MB.")
            total_size += info.file_size
            if total_size > MAX_TOTAL_BYTES:
                raise ValueError("ZIP excede limite descompactado de 200MB.")
            members[info.filename] = z.read(info)
    if "manifest.json" not in members:
        raise ValueError("manifest.json ausente: pacote nao rastreavel.")
    manifest = json.loads(decode(members["manifest.json"]))
    verified = 0
    for item in manifest.get("files", []):
        archive_name = item.get("arcname")
        if archive_name not in members:
            raise ValueError("Arquivo listado no manifesto nao esta presente no ZIP")
        content = members[archive_name]
        if hashlib.sha256(content).hexdigest() != item.get("sha256") or len(content) != item.get("bytes"):
            raise ValueError("SHA256/tamanho divergente para arquivo listado no manifesto.")
        verified += 1
    reports = []
    for name, data in members.items():
        if name.lower().endswith((".html", ".htm")):
            report = extract_report(name, data)
            if report:
                reports.append(report)
    reports.sort(key=lambda r: (r["start"] or "", r["file"]))
    reg = load_registry(members)
    warnings = compare(reports, reg)
    telemetry = csv_statistics(members)
    summary = {
        "schema": "alien-analise-v1", "generated_utc": datetime.now(timezone.utc).isoformat(),
        "input_archive": zip_path.name, "manifest_files": len(manifest.get("files", [])),
        "verified_files": verified, "reports_count": len(reports),
        "csv": telemetry, "warnings": warnings,
        "registry_experiments": len(reg),
    }
    clean_reports = [{k:v for k,v in r.items() if not k.startswith("_")} for r in reports]
    json_data = {**summary, "reports": clean_reports}
    (output / "ALIEN_AUDITORIA.json").write_text(json.dumps(json_data, ensure_ascii=False, indent=2), encoding="utf-8")
    md = create_markdown(zip_path.name, clean_reports, summary, warnings, reg)
    (output / "ALIEN_AUDITORIA.md").write_text(md, encoding="utf-8")
    (output / "ALIEN_AUDITORIA.html").write_text(create_html(md), encoding="utf-8")
    with (output / "ALIEN_COMPARATIVO.csv").open("w", newline="", encoding="utf-8-sig") as f:
        fields = ["file", "experiment", "expert", "symbol", "broker", "timeframe", "start", "end", "quality", "deposit", "currency", "leverage", "profit", "pf", "trades", "win_rate_pct", "dd_money", "dd_pct", "input_count", "economic_inputs_sha256", "source_sha256"]
        writer = csv.DictWriter(f, delimiter=";", fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for r in clean_reports:
            writer.writerow(r)
    print(f"ALIEN LAB: {verified} hashes conferidos, {len(reports)} relatorios MT5, {len(warnings)} alertas.")
    print("Pasta de resultados:", output)
    print("Abra: ", output / "ALIEN_AUDITORIA.html")
    return summary


def main(argv=None):
    parser=argparse.ArgumentParser(description="Audita ZIP de evidencias MT5; nao publica dados brutos.")
    parser.add_argument("--zip", dest="archive", help="Caminho do ZIP do coletor")
    parser.add_argument("--latest", action="store_true", help="Analisa o ZIP mais recente da pasta PACOTES_MT5")
    parser.add_argument("--zip-dir", default=str(REPO / "PACOTES_MT5"))
    parser.add_argument("--output", default=None, help="Pasta de saida (padrao cria pasta com nome do ZIP)")
    args=parser.parse_args(argv)
    if not args.archive and not args.latest:
        parser.error("Use --zip CAMINHO ou --latest")
    p=Path(args.archive) if args.archive else None
    if args.latest:
        archives=sorted(Path(args.zip_dir).glob("ALIEN_EVIDENCIAS_*.zip"),key=lambda x:x.stat().st_mtime,reverse=True)
        if not archives:
            parser.error("Nenhum ZIP de evidencias encontrado em PACOTES_MT5")
        p=archives[0]
    if not p.is_file():
        parser.error("ZIP nao encontrado: "+str(p))
    try:
        output = Path(args.output) if args.output else REPO / "RELATORIOS_MT5" / slug(p.stem)
        analyze(p, output)
        return 0
    except (OSError, ValueError, zipfile.BadZipFile, KeyError) as exc:
        print("ERRO: evidencias nao analisadas:",exc,file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())