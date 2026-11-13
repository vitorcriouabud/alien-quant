#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Auditoria LOCAL, somente leitura, de resultados por operacao em R.

Nao executa ordens, nao importa MetaTrader5, nao usa rede, nao instala pacotes.
O CSV original nao e alterado. O relatorio NAO certifica vantagem de trading.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
import re
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

R_ALIASES = (
    "r_liquido", "r_liq", "r_net", "net_r", "net_r_proxy", "resultado_r_liquido",
    "resultado_liquido_r", "pnl_r_liquido", "pnl_r_net", "r_final",
    "r_result", "net_result_r", "net_result", "r_after_costs",
)
TIME_ALIASES = (
    "entry_time", "entry_datetime", "time_entry", "timestamp", "datetime",
    "data_hora_entrada", "hora_entrada", "data_entrada", "signal_time",
    "tempo_entrada", "time", "date",
)
ID_ALIASES = (
    "trade_id", "id_trade", "operation_id", "operacao_id",
    "signal_id", "id_sinal", "id",
)


def norm(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def pick_column(headers, explicit, aliases, required=False):
    by_norm = {}
    for header in headers:
        key = norm(header)
        if key in by_norm:
            raise ValueError("Cabecalhos equivalentes/duplicados: " + header)
        by_norm[key] = header
    if explicit:
        key = norm(explicit)
        if key not in by_norm:
            raise ValueError("Coluna nao encontrada: %s. Disponiveis: %s" % (explicit, headers))
        return by_norm[key]
    for alias in aliases:
        if norm(alias) in by_norm:
            return by_norm[norm(alias)]
    if required:
        raise ValueError(
            "Nao foi possivel identificar coluna de R LIQUIDO. "
            "Use --r-col NOME_EXATO. Colunas: %s" % headers
        )
    return None


def parse_number(raw, line):
    value = str(raw or "").strip().replace("−", "-")
    if not value:
        raise ValueError("Linha %d: R vazio" % line)
    if "," in value and "." in value:
        raise ValueError("Linha %d: separadores decimais ambiguos: %r" % (line, value))
    try:
        number = float(value.replace(",", "."))
    except ValueError as exc:
        raise ValueError("Linha %d: R invalido: %r" % (line, value)) from exc
    if not math.isfinite(number):
        raise ValueError("Linha %d: R nao finito" % line)
    return number


def parse_timestamp(raw, line):
    value = str(raw or "").strip()
    if not value:
        raise ValueError("Linha %d: horario vazio" % line)
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        pass
    for fmt in (
        "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M",
        "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M",
        "%Y-%m-%d", "%d/%m/%Y",
    ):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    raise ValueError("Linha %d: horario nao reconhecido: %r" % (line, value))


def percentile(sorted_values, p):
    if not sorted_values:
        return None
    pos = (len(sorted_values) - 1) * p
    low = int(pos)
    high = min(low + 1, len(sorted_values) - 1)
    return sorted_values[low] * (1 - (pos - low)) + sorted_values[high] * (pos - low)


def bootstrap_by_day(day_groups, repetitions=2000, seed=20261112):
    """Amostra dias com reposicao; nao presume independencia entre trades do dia."""
    days = list(day_groups.values())
    if len(days) < 10:
        return None
    rng = random.Random(seed)
    means = []
    for _ in range(repetitions):
        total, count = 0.0, 0
        for _ in days:
            selected = days[rng.randrange(len(days))]
            total += sum(selected)
            count += len(selected)
        means.append(total / count)
    means.sort()
    return [percentile(means, 0.025), percentile(means, 0.975)]


def audit(path, r_col=None, time_col=None, id_col=None, expected=None):
    path = Path(path)
    digest = hashlib.sha256()
    with path.open("rb") as raw_file:
        for chunk in iter(lambda: raw_file.read(1024 * 1024), b""):
            digest.update(chunk)

    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        sample = stream.read(16384)
        stream.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
            delimiter = dialect.delimiter
        except csv.Error:
            first = sample.splitlines()[0] if sample.splitlines() else ""
            delimiter = max((",", ";", "\t", "|"), key=lambda d: first.count(d))
        reader = csv.DictReader(stream, delimiter=delimiter)
        headers = reader.fieldnames
        if not headers:
            raise ValueError("CSV vazio ou sem cabecalho")
        if len(set(headers)) != len(headers):
            raise ValueError("CSV com cabecalhos duplicados")
        r_name = pick_column(headers, r_col, R_ALIASES, required=True)
        t_name = pick_column(headers, time_col, TIME_ALIASES)
        i_name = pick_column(headers, id_col, ID_ALIASES)
        values, dates, ids, timestamps = [], {}, set(), []
        for line, row in enumerate(reader, 2):
            if None in row:
                raise ValueError("Linha %d: campos extras; verifique delimitador" % line)
            r = parse_number(row[r_name], line)
            values.append(r)
            if i_name:
                identifier = str(row[i_name] or "").strip()
                if not identifier:
                    raise ValueError("Linha %d: ID vazio" % line)
                if identifier in ids:
                    raise ValueError("Linha %d: ID duplicado: %s" % (line, identifier))
                ids.add(identifier)
            if t_name:
                dt = parse_timestamp(row[t_name], line)
                timestamps.append(dt)
                dates.setdefault(dt.date().isoformat(), []).append(r)

    if not values:
        raise ValueError("Nenhuma operacao no CSV")

    if timestamps:
        try:
            if any(a > b for a, b in zip(timestamps, timestamps[1:])):
                raise ValueError("CSV fora de ordem cronologica; curva em R seria enganosa")
        except TypeError as exc:
            raise ValueError("Mistura de timestamps com e sem fuso horario") from exc

    warnings = [
        "Replay historico nao e holdout independente; nenhuma promocao a conta real.",
        "Custos, fills e risco em R nao podem ser certificados somente por este CSV.",
        "CSV de trades nao mostra oportunidades ignoradas nem execucao Bid/Ask.",
    ]
    if not t_name:
        warnings.append("Sem coluna temporal: curva segue ordem do arquivo; IC por dia indisponivel.")
    elif any(t.tzinfo is None for t in timestamps):
        warnings.append("Horarios sem timezone: nao foi possivel verificar fuso/DST.")
    if not i_name:
        warnings.append("Sem ID unico: duplicatas de trades nao podem ser excluidas.")
    if len(dates) < 10:
        warnings.append("Menos de 10 datas distintas; IC bootstrap por dia indisponivel.")

    total = sum(values)
    gains = sum(x for x in values if x > 0)
    losses = -sum(x for x in values if x < 0)
    pf = gains / losses if losses > 0 else None
    equity, peak, max_dd = 0.0, 0.0, 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        max_dd = max(max_dd, peak - equity)
    sorted_r = sorted(values)
    best3 = sum(sorted_r[-3:])
    ci = bootstrap_by_day(dates)
    result = {
        "status": "TRIAGEM_HISTORICA_NAO_PROMOVER",
        "arquivo": path.name,
        "sha256": digest.hexdigest(),
        "colunas": {"r_liquido": r_name, "tempo": t_name, "id": i_name},
        "n_operacoes": len(values),
        "n_dias": len(dates) if t_name else None,
        "soma_r": round(total, 6),
        "media_r": round(total / len(values), 6),
        "mediana_r": round(percentile(sorted_r, 0.5), 6),
        "profit_factor_r": round(pf, 6) if pf is not None else None,
        "vencedoras": sum(x > 0 for x in values),
        "perdedoras": sum(x < 0 for x in values),
        "zeros": sum(x == 0 for x in values),
        "max_drawdown_r": round(max_dd, 6),
        "soma_3_maiores_r": round(best3, 6),
        "soma_sem_3_maiores_r": round(total - best3, 6),
        "ic95_media_r_bootstrap_dias": [round(x, 6) for x in ci] if ci else None,
        "avisos": warnings,
    }
    if expected:
        mismatches = []
        if expected.get("n") is not None and len(values) != expected["n"]:
            mismatches.append("N: %d != %d" % (len(values), expected["n"]))
        if expected.get("mean") is not None and abs(total / len(values) - expected["mean"]) > 0.005:
            mismatches.append("media R difere do relatorio")
        if expected.get("pf") is not None and (pf is None or abs(pf - expected["pf"]) > 0.02):
            mismatches.append("PF difere do relatorio")
        result["checagem_relatorio"] = {"consistente_com_arredondamento": not mismatches, "divergencias": mismatches}
        if mismatches:
            result["avisos"].append("Divergencia com numeros publicados: investigar colunas/definicoes.")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", help="Caminho do CSV de operacoes")
    parser.add_argument("--r-col", help="Nome da coluna R LIQUIDO por trade")
    parser.add_argument("--time-col", help="Nome da coluna de horario (entrada)")
    parser.add_argument("--id-col", help="Nome da coluna de ID unico")
    parser.add_argument("--expect-count", type=int)
    parser.add_argument("--expect-mean", type=float)
    parser.add_argument("--expect-pf", type=float)
    parser.add_argument("--output", help="Arquivo JSON de saida (opcional)")
    args = parser.parse_args(argv)
    try:
        result = audit(
            args.csv, args.r_col, args.time_col, args.id_col,
            expected={"n": args.expect_count, "mean": args.expect_mean, "pf": args.expect_pf},
        )
        payload = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False)
        if args.output:
            Path(args.output).write_text(payload + "\n", encoding="utf-8")
        print(payload)
        return 0
    except (OSError, ValueError, UnicodeError) as exc:
        print("AUDITORIA BLOQUEADA: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
