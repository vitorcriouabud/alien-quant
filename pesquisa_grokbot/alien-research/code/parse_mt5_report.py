#!/usr/bin/env python3
"""Parse an MT5 Strategy Tester HTML report (UTF-16 or UTF-8, PT or EN)."""
from __future__ import annotations

import html
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path


def _decode(raw: bytes) -> str:
    for enc in ("utf-16", "utf-16-le", "utf-8-sig", "utf-8", "cp1252"):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode("latin-1", errors="replace")


def _lines(text: str) -> list[str]:
    text = re.sub(r"<script[\s\S]*?</script>", " ", text, flags=re.I)
    text = re.sub(r"<style[\s\S]*?</style>", " ", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "\n", text)
    text = html.unescape(text).replace("\xa0", " ")
    lines = [re.sub(r"\s+", " ", ln).strip() for ln in text.splitlines()]
    return [ln for ln in lines if ln]


def _num(s: str | None) -> float | None:
    if s is None:
        return None
    s = s.strip()
    if s in {"", "-", "—"}:
        return None
    # 10 000.00 or 10.000,00 or 1 237.00
    if re.search(r",\d{2}$", s) and s.count(",") == 1:
        s = s.replace(".", "").replace(" ", "").replace(",", ".")
    else:
        s = s.replace(" ", "").replace("\u00a0", "")
        s = s.replace(",", "")
    s = s.replace("%", "")
    try:
        return float(s)
    except ValueError:
        return None


LABELS = {
    "quality": [r"Qualidade do hist[óo]rico", r"History Quality", r"Qualidade"],
    "bars": [r"Barras", r"Bars"],
    "ticks": [r"^Ticks$", r"Ticks:"],
    "net": [r"Lucro L[íi]quido Total", r"Total Net Profit"],
    "gross_profit": [r"Lucro Bruto", r"Gross Profit"],
    "gross_loss": [r"Perda Bruta", r"Gross Loss"],
    "pf": [r"Fator de Lucro", r"Profit Factor"],
    "expected": [r"Retorno Esperado", r"Expected Payoff"],
    "dd_abs_bal": [r"Rebaixamento Absoluto do Saldo", r"Balance Drawdown Absolute"],
    "dd_max_bal": [r"Rebaixamento M[áa]ximo do Saldo", r"Balance Drawdown Maximal"],
    "dd_rel_bal": [r"Rebaixamento Relativo do Saldo", r"Balance Drawdown Relative"],
    "dd_abs_eq": [r"Rebaixamento Absoluto do Capital", r"Equity Drawdown Absolute"],
    "dd_max_eq": [r"Rebaixamento M[áa]ximo do Capital", r"Equity Drawdown Maximal"],
    "dd_rel_eq": [r"Rebaixamento Relativo do Capital", r"Equity Drawdown Relative"],
    "trades": [r"Total de Negocia[çc][õo]es", r"Total Trades"],
    "win_trades": [r"Negocia[çc][õo]es com Lucro", r"Profit Trades"],
    "loss_trades": [r"Negocia[çc][õo]es com Perda", r"Loss Trades"],
    "short_trades": [r"Posi[çc][õo]es Vendidas", r"Short Trades"],
    "long_trades": [r"Posi[çc][õo]es Compradas", r"Long Trades"],
    "deposit": [r"Dep[óo]sito Inicial", r"Initial Deposit"],
    "leverage": [r"Alavancagem", r"Leverage"],
    "period": [r"^Per[íi]odo", r"^Period"],
    "expert": [r"Expert Advisor", r"Rob[ôo]"],
    "symbol": [r"^Ativo", r"^Symbol"],
    "model": [r"^Modelo", r"^Model"],
    "spread": [r"^Spread"],
}


def _after(lines: list[str], patterns: list[str], limit: int = 4) -> str | None:
    cre = [re.compile(p, re.I) for p in patterns]
    for i, ln in enumerate(lines):
        if any(c.search(ln) for c in cre):
            # value may be same line after ':' or next non-label lines
            if ":" in ln:
                rhs = ln.split(":", 1)[1].strip()
                if rhs:
                    return rhs
            for j in range(1, limit + 1):
                if i + j < len(lines):
                    nxt = lines[i + j]
                    if nxt and not nxt.endswith(":") and len(nxt) < 80:
                        return nxt
    return None


def parse_deals(lines: list[str]) -> list[dict]:
    # Find last header "Comissão" / "Commission" preceded by Volume/Preço
    header_i = None
    for i, ln in enumerate(lines):
        if ln in {"Comissão", "Commission"} and i >= 4:
            window = lines[i - 6 : i + 3]
            if any(x in window for x in ("Volume", "Preço", "Price", "Swap", "Lucro", "Profit")):
                header_i = i
    if header_i is None:
        return []
    # rows start after Comentário/Comment
    start = header_i
    for j in range(header_i, min(header_i + 6, len(lines))):
        if lines[j] in {"Comentário", "Comment"}:
            start = j + 1
            break
    deals = []
    i = start
    date_re = re.compile(r"^\d{4}\.\d{2}\.\d{2}")
    while i < len(lines):
        if not date_re.match(lines[i]):
            # end of deals table (sometimes extra sections follow)
            if deals and (lines[i].endswith(":") or lines[i] in {"Ordens", "Orders", "Gráfico", "Graph"}):
                break
            i += 1
            continue
        # balance row: date, ticket, balance, comm?, swap?, profit, balance, comment?
        chunk = []
        i0 = i
        i += 1
        while i < len(lines) and not date_re.match(lines[i]):
            chunk.append(lines[i])
            # a complete deal has symbol + in/out or 'balance'
            if len(chunk) > 20:
                break
            i += 1
        # classify
        if "balance" in chunk or "Balance" in chunk:
            # skip deposit
            continue
        # typical: ticket, symbol, type, in/out, volume, price, order, comm, swap, profit, balance, comment
        try:
            # find in/out index
            io = None
            for k, v in enumerate(chunk):
                if v in {"in", "out", "in/out", "out by", "inout"}:
                    io = k
                    break
            if io is None or io < 2:
                continue
            typ = chunk[io - 1]
            symbol = chunk[io - 2]
            volume = _num(chunk[io + 1])
            price = _num(chunk[io + 2])
            # order may be int then commission
            comm = _num(chunk[io + 4]) if len(chunk) > io + 4 else None
            swap = _num(chunk[io + 5]) if len(chunk) > io + 5 else None
            profit = _num(chunk[io + 6]) if len(chunk) > io + 6 else None
            comment = chunk[io + 8] if len(chunk) > io + 8 else ""
            if typ not in {"buy", "sell", "buy limit", "sell limit"} and typ.lower() not in {"buy", "sell"}:
                # maybe typ is at io-1 still ok
                pass
            deals.append(
                {
                    "time": lines[i0],
                    "symbol": symbol,
                    "type": typ,
                    "entry": chunk[io],
                    "volume": volume,
                    "price": price,
                    "commission": comm,
                    "swap": swap,
                    "profit": profit,
                    "comment": comment,
                }
            )
        except Exception:
            continue
    return deals


def weekly(deals: list[dict]) -> list[dict]:
    groups: dict[str, dict] = {}
    for d in deals:
        try:
            t = datetime.strptime(d["time"][:19], "%Y.%m.%d %H:%M:%S")
        except Exception:
            try:
                t = datetime.strptime(d["time"][:10], "%Y.%m.%d")
            except Exception:
                continue
        # Monday-start ISO week
        monday = t - timedelta(days=t.weekday())
        key = monday.strftime("%Y-%m-%d")
        g = groups.setdefault(
            key,
            {"week_start": key, "trades": 0, "wins": 0, "losses": 0, "net": 0.0, "commission": 0.0, "profit": 0.0, "swap": 0.0},
        )
        comm = d.get("commission") or 0.0
        swap = d.get("swap") or 0.0
        pr = d.get("profit") or 0.0
        g["commission"] += comm
        g["swap"] += swap
        g["profit"] += pr
        g["net"] += pr + comm + swap
        if d.get("entry") in {"out", "out by", "inout"}:
            g["trades"] += 1
            net = pr + comm + swap
            # for out deals, entry commission is on the in deal; weekly net still sums all
            if net > 0:
                g["wins"] += 1
            elif net < 0:
                g["losses"] += 1
    return [groups[k] for k in sorted(groups)]


def parse(path: Path) -> dict:
    text = _decode(path.read_bytes())
    lines = _lines(text)
    info = {"file": str(path)}
    for key, pats in LABELS.items():
        info[key] = _after(lines, pats)
    # quality often is "100% de ticks reais"
    q = info.get("quality") or ""
    m = re.search(r"(\d+)\s*%", q)
    info["real_tick_pct"] = int(m.group(1)) if m else None
    info["quality_raw"] = q
    deals = parse_deals(lines)
    info["deal_count"] = len(deals)
    info["commission_sum"] = round(sum((d.get("commission") or 0.0) for d in deals), 6)
    info["swap_sum"] = round(sum((d.get("swap") or 0.0) for d in deals), 6)
    info["profit_sum"] = round(sum((d.get("profit") or 0.0) for d in deals), 6)
    # sample first trade commissions
    samples = [d for d in deals if d.get("commission") not in (None, 0, 0.0)][:6]
    info["commission_samples"] = samples
    info["weeks"] = weekly(deals)
    # numeric casts
    for k in ("net", "pf", "gross_profit", "gross_loss", "deposit"):
        if isinstance(info.get(k), str):
            # strip trailing annotation
            info[k + "_num"] = _num(re.split(r"\s{2,}|\(", info[k], maxsplit=1)[0])
    if isinstance(info.get("trades"), str):
        info["trades_num"] = _num(re.split(r"\s", info["trades"], maxsplit=1)[0])
    if isinstance(info.get("win_trades"), str):
        # "18 (27.69%)"
        m = re.search(r"([\d\s]+)\s*\(([\d.,]+)\s*%\)", info["win_trades"])
        if m:
            info["wins_num"] = _num(m.group(1))
            info["win_rate_pct"] = _num(m.group(2))
    if isinstance(info.get("dd_max_eq"), str):
        m = re.search(r"([\d\s.,]+)\s*\(([\d.,]+)\s*%\)", info["dd_max_eq"])
        if m:
            info["dd_max_eq_money"] = _num(m.group(1))
            info["dd_max_eq_pct"] = _num(m.group(2))
        else:
            info["dd_max_eq_money"] = _num(info["dd_max_eq"])
    if isinstance(info.get("dd_rel_eq"), str):
        m = re.search(r"([\d.,]+)\s*%\s*\(([\d\s.,]+)\)", info["dd_rel_eq"])
        if m:
            info["dd_rel_eq_pct"] = _num(m.group(1))
            info["dd_rel_eq_money"] = _num(m.group(2))
    return info


def main():
    if len(sys.argv) < 2:
        print("usage: parse_mt5_report.py <report.htm> [json-out]", file=sys.stderr)
        sys.exit(2)
    path = Path(sys.argv[1])
    info = parse(path)
    # compact print
    keys = [
        "file", "expert", "period", "deposit", "quality_raw", "real_tick_pct",
        "bars", "ticks", "net", "pf", "trades", "win_trades", "loss_trades",
        "dd_max_eq", "dd_rel_eq", "gross_profit", "gross_loss",
        "deal_count", "commission_sum", "swap_sum", "profit_sum",
        "wins_num", "win_rate_pct", "dd_max_eq_money", "dd_max_eq_pct",
    ]
    out = {k: info.get(k) for k in keys}
    out["weeks"] = info.get("weeks")
    out["commission_samples"] = info.get("commission_samples")
    text = json.dumps(out, indent=2, ensure_ascii=False)
    print(text)
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
