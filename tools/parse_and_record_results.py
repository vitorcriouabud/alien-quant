#!/usr/bin/env python3
"""
ALIEN LAB - Unified MT5 Strategy Tester Report Parser & Experiment Recorder
Robustly parses MT5 Strategy Tester HTML (.htm/.html) reports in UTF-16LE / UTF-8,
extracting key metrics in both Portuguese and English MT5 locales, computing
Average Risk:Reward (R:R), printing a formatted Markdown summary, and optionally
recording the results directly into EXPERIMENTOS.csv.
"""

import os
import sys
import re
import argparse
import json
import unicodedata
from datetime import datetime
from pathlib import Path


def strip_accents(s: str) -> str:
    """Normalize and remove diacritics/accents for robust key comparison."""
    if not s:
        return ""
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def clean_number(val_str: str) -> float:
    """
    Cleans and converts number strings from various locale formats:
    Handles '1 257.98', '1.257,98', '748.30', '748,30', '-509.68', '$10,000.00'.
    """
    if not val_str:
        return 0.0
    s = str(val_str).replace("\xa0", " ").replace("$", "").replace("%", "").strip()
    s = s.replace(" ", "")

    if "." in s and "," in s:
        if s.rfind(".") > s.rfind(","):
            # e.g., 1,257.98 -> comma is thousand separator
            s = s.replace(",", "")
        else:
            # e.g., 1.257,98 -> dot is thousand separator
            s = s.replace(".", "").replace(",", ".")
    elif "," in s:
        # e.g., 748,30 -> comma is decimal separator
        s = s.replace(",", ".")

    try:
        return float(s)
    except ValueError:
        # Try extracting the first valid float sequence
        m = re.search(r"[-+]?\d*\.?\d+", s)
        if m:
            try:
                return float(m.group(0))
            except ValueError:
                return 0.0
        return 0.0


def read_report_file(file_path: str) -> str:
    """Reads HTML report file trying UTF-16LE with BOM, UTF-16, UTF-8, and CP1252."""
    encodings = ["utf-16", "utf-16-le", "utf-8-sig", "utf-8", "cp1252", "latin-1"]
    content = None
    for enc in encodings:
        try:
            with open(file_path, "r", encoding=enc) as f:
                content = f.read()
            if content and ("<table" in content.lower() or "<html" in content.lower()):
                return content
        except (UnicodeError, OSError):
            continue

    if content is None:
        # Fallback reading with errors ignored
        with open(file_path, "r", encoding="utf-16", errors="ignore") as f:
            content = f.read()
    return content


def resolve_report_path(report_arg: str, base_dir: Path = None) -> Path:
    """
    Resolves report file path from an absolute path, relative path, or report/experiment name.
    """
    p = Path(report_arg)
    if p.is_file():
        return p.resolve()

    if base_dir is None:
        base_dir = Path(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB")

    candidates = [
        base_dir / report_arg,
        base_dir / "results" / report_arg / f"{report_arg}.htm",
        base_dir / "results" / report_arg / f"{report_arg}.html",
        base_dir / "results" / f"{report_arg}.htm",
        base_dir / "results" / f"{report_arg}.html",
        base_dir / "results" / report_arg,
        Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "5FFA568149E88FCD5B44D926DCFEAA79" / report_arg,
        Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "5FFA568149E88FCD5B44D926DCFEAA79" / f"{report_arg}.htm",
    ]

    # Also search subdirectories of results
    results_dir = base_dir / "results"
    if results_dir.is_dir():
        for sub in results_dir.iterdir():
            if sub.is_dir():
                candidates.append(sub / f"{report_arg}.htm")
                candidates.append(sub / f"{report_arg}.html")
                candidates.append(sub / report_arg)

    for cand in candidates:
        if cand.is_file():
            return cand.resolve()

    raise FileNotFoundError(f"Relatório MT5 não encontrado para o argumento: '{report_arg}'")


def parse_report_html(html_text: str) -> dict:
    """
    Parses table key-value pairs from MT5 Strategy Tester HTML report.
    Handles both Portuguese and English labels.
    """
    raw_pairs = {}
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", html_text, re.DOTALL | re.IGNORECASE)

    for r in rows:
        cols = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.DOTALL | re.IGNORECASE)
        # Clean html tags & entities
        cleaned = [re.sub(r"<[^>]+>", "", c).strip() for c in cols]
        cleaned = [c for c in cleaned if c != ""]

        i = 0
        while i < len(cleaned) - 1:
            c1 = cleaned[i]
            c2 = cleaned[i + 1]
            if c1.endswith(":"):
                norm_key = strip_accents(c1[:-1]).strip().lower()
                raw_pairs[norm_key] = c2
                i += 2
            else:
                i += 1

    return raw_pairs


def extract_metrics(raw_pairs: dict, report_path: Path) -> dict:
    """
    Extracts, normalizes, and computes all required backtest metrics:
    - Net Profit ($)
    - Profit Factor (PF)
    - Total Trades
    - Win Rate (%)
    - Maximal Equity Drawdown ($ and %)
    - Average Win ($)
    - Average Loss ($)
    - Average Risk:Reward (R:R) = abs(AvgWin / AvgLoss)
    """
    # 1. Net Profit
    profit_raw = (
        raw_pairs.get("lucro liquido total")
        or raw_pairs.get("total net profit")
        or "0.0"
    )
    net_profit = clean_number(profit_raw)

    # 2. Profit Factor
    pf_raw = (
        raw_pairs.get("fator de lucro")
        or raw_pairs.get("profit factor")
        or "0.0"
    )
    profit_factor = clean_number(pf_raw)

    # 3. Total Trades
    trades_raw = (
        raw_pairs.get("total de negociacoes")
        or raw_pairs.get("total de operacoes")
        or raw_pairs.get("total trades")
        or "0"
    )
    total_trades = int(clean_number(trades_raw.split()[0])) if trades_raw else 0

    # 4. Profit & Loss Trades (Win Rate)
    win_raw = (
        raw_pairs.get("negociacoes com lucro (% of total)")
        or raw_pairs.get("negociacoes com lucro")
        or raw_pairs.get("profit trades (% of total)")
        or raw_pairs.get("profit trades")
        or ""
    )
    loss_raw = (
        raw_pairs.get("negociacoes com perda (% of total)")
        or raw_pairs.get("negociacoes com perda")
        or raw_pairs.get("loss trades (% of total)")
        or raw_pairs.get("loss trades")
        or ""
    )

    win_count = 0
    win_rate = 0.0
    if win_raw:
        # e.g., '83 (59.29%)' or '83'
        m_win = re.search(r"(\d+)\s*\(([\d\.\,]+)%\)", win_raw)
        if m_win:
            win_count = int(m_win.group(1))
            win_rate = clean_number(m_win.group(2))
        else:
            win_count = int(clean_number(win_raw))
            if total_trades > 0:
                win_rate = (win_count / total_trades) * 100.0

    loss_count = 0
    loss_rate = 0.0
    if loss_raw:
        m_loss = re.search(r"(\d+)\s*\(([\d\.\,]+)%\)", loss_raw)
        if m_loss:
            loss_count = int(m_loss.group(1))
            loss_rate = clean_number(m_loss.group(2))
        else:
            loss_count = int(clean_number(loss_raw))
            if total_trades > 0:
                loss_rate = (loss_count / total_trades) * 100.0

    if win_rate == 0.0 and total_trades > 0 and win_count > 0:
        win_rate = (win_count / total_trades) * 100.0

    # 5. Maximal Equity Drawdown ($ and %)
    # Priority: Maximal Equity Drawdown > Maximal Balance Drawdown > Maximal Drawdown
    dd_raw = (
        raw_pairs.get("rebaixamento maximo do capital liquido")
        or raw_pairs.get("equity drawdown maximal")
        or raw_pairs.get("maximal equity drawdown")
        or raw_pairs.get("rebaixamento maximo do saldo")
        or raw_pairs.get("balance drawdown maximal")
        or raw_pairs.get("rebaixamento maximo")
        or raw_pairs.get("maximal drawdown")
        or "0.0 (0.0%)"
    )

    max_dd_money = 0.0
    max_dd_pct = 0.0
    # Format e.g., '90.12 (0.83%)' or '0.83% (90.12)' or '90.12'
    m_dd1 = re.search(r"([\d\.\,\s]+)\s*\(([\d\.\,]+)%\)", dd_raw)
    m_dd2 = re.search(r"([\d\.\,]+)%\s*\(([\d\.\,\s]+)\)", dd_raw)
    if m_dd1:
        max_dd_money = clean_number(m_dd1.group(1))
        max_dd_pct = clean_number(m_dd1.group(2))
    elif m_dd2:
        max_dd_pct = clean_number(m_dd2.group(1))
        max_dd_money = clean_number(m_dd2.group(2))
    else:
        max_dd_money = clean_number(dd_raw)

    # 6. Average Win ($) and Average Loss ($)
    avg_win_raw = (
        raw_pairs.get("media lucro da negociacao")
        or raw_pairs.get("media lucro por negociacao")
        or raw_pairs.get("average profit trade")
        or raw_pairs.get("average win trade")
        or "0.0"
    )
    avg_win = clean_number(avg_win_raw)

    avg_loss_raw = (
        raw_pairs.get("media perda na negociacao")
        or raw_pairs.get("media perda por negociacao")
        or raw_pairs.get("average loss trade")
        or "0.0"
    )
    avg_loss = clean_number(avg_loss_raw)
    if avg_loss > 0 and "-" in avg_loss_raw:
        avg_loss = -avg_loss

    # 7. Average Risk:Reward (R:R) = abs(AvgWin / AvgLoss)
    if abs(avg_loss) > 1e-6:
        risk_reward = abs(avg_win / avg_loss)
    elif avg_win > 0:
        risk_reward = float("inf")
    else:
        risk_reward = 0.0

    # 8. Auxiliary Metadata
    deposit_raw = (
        raw_pairs.get("deposito inicial")
        or raw_pairs.get("initial deposit")
        or "10000"
    )
    deposit = clean_number(deposit_raw)

    symbol = (
        raw_pairs.get("ativo")
        or raw_pairs.get("symbol")
        or "XAUUSD"
    )

    expert = (
        raw_pairs.get("expert advisor (robo)")
        or raw_pairs.get("expert advisor")
        or raw_pairs.get("robo")
        or raw_pairs.get("expert")
        or report_path.stem
    )

    period_raw = (
        raw_pairs.get("periodo")
        or raw_pairs.get("period")
        or ""
    )

    # Extract Timeframe & Date Range from Period string: e.g. "M1 (2026.10.05 - 2026.10.17)"
    timeframe = "M1"
    period_dates = period_raw
    m_per = re.search(r"([A-Za-z0-9]+)\s*\((.*?)\)", period_raw)
    if m_per:
        timeframe = m_per.group(1).strip()
        period_dates = m_per.group(2).strip()
    elif not period_dates:
        period_dates = "2026.10.21 - 2026.11.07"

    leverage_raw = raw_pairs.get("alavancagem") or raw_pairs.get("leverage") or "1:100"

    return {
        "report_file": str(report_path),
        "report_name": report_path.name,
        "strategy": expert,
        "symbol": symbol,
        "timeframe": timeframe,
        "period": period_dates,
        "deposit": deposit,
        "leverage": leverage_raw,
        "net_profit": net_profit,
        "profit_factor": profit_factor,
        "total_trades": total_trades,
        "win_count": win_count,
        "loss_count": loss_count,
        "win_rate": win_rate,
        "loss_rate": loss_rate,
        "max_dd_money": max_dd_money,
        "max_dd_pct": max_dd_pct,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
        "risk_reward": risk_reward,
    }


def generate_markdown_summary(metrics: dict, exp_id: str = None) -> str:
    """Formats metrics dictionary into a readable Markdown summary table."""
    id_str = exp_id if exp_id else metrics.get("report_name", "EXPERIMENT")
    rr_str = f"{metrics['risk_reward']:.2f}" if metrics['risk_reward'] != float("inf") else "inf"
    stop_eval = (
        f"Nao (DD ${metrics['max_dd_money']:.2f} < $140)"
        if metrics['max_dd_money'] < 140.0
        else f"Sim (DD ${metrics['max_dd_money']:.2f} >= $140)"
    )

    md = []
    md.append(f"### MT5 Backtest Summary: {id_str}")
    md.append("")
    md.append("| Metric | Value | Reference / Details |")
    md.append("|---|---|---|")
    md.append(f"| **Experiment ID** | `{id_str}` | Identificador |")
    md.append(f"| **Strategy (EA)** | `{metrics['strategy']}` | Expert Advisor |")
    md.append(f"| **Symbol / Timeframe** | `{metrics['symbol']}` / `{metrics['timeframe']}` | Ativo e Timeframe |")
    md.append(f"| **Period** | `{metrics['period']}` | Intervalo de Teste |")
    md.append(f"| **Initial Deposit** | `${metrics['deposit']:,.2f}` | Saldo Inicial |")
    md.append(f"| **Leverage** | `{metrics['leverage']}` | Alavancagem no Testador |")
    md.append(f"| **Total Net Profit** | **${metrics['net_profit']:+,.2f} USD** | Lucro Líquido Total |")
    md.append(f"| **Profit Factor (PF)** | **{metrics['profit_factor']:.2f}** | Fator de Lucro |")
    md.append(f"| **Total Trades** | **{metrics['total_trades']}** | Negociações Fechadas |")
    md.append(f"| **Win Rate** | **{metrics['win_rate']:.2f}%** | {metrics['win_count']} vitórias / {metrics['loss_count']} derrotas |")
    md.append(f"| **Maximal Equity Drawdown** | **${metrics['max_dd_money']:.2f} ({metrics['max_dd_pct']:.2f}%)** | Rebaixamento Máx Capital Líquido |")
    md.append(f"| **Average Win** | `${metrics['avg_win']:.2f}` | Média por trade vencedor |")
    md.append(f"| **Average Loss** | `${metrics['avg_loss']:.2f}` | Média por trade perdedor |")
    md.append(f"| **Average Risk:Reward (R:R)** | **{rr_str}** | abs(AvgWin / AvgLoss) |")
    md.append(f"| **Daily Stop Limit ($140)** | **{stop_eval}** | Goat 10K Disjuntor Diário |")
    md.append("")
    return "\n".join(md)


def append_to_experiment_csv(csv_path: Path, row_dict: dict) -> None:
    """
    Appends or updates a structured row in EXPERIMENTOS.csv using the project format:
    ID;Data;Estrategia;Timeframe;Periodo;Ativo;Modelo_Ticks;Banca_USD;Lucro_USD;Fator_Lucro;Trades;WinRate_Pct;Max_DD_USD;Semanas_Stop12_Violado;Conclusao
    """
    header = (
        "ID;Data;Estrategia;Timeframe;Periodo;Ativo;Modelo_Ticks;"
        "Banca_USD;Lucro_USD;Fator_Lucro;Trades;WinRate_Pct;Max_DD_USD;"
        "Semanas_Stop12_Violado;Conclusao\n"
    )

    formatted_row = (
        f"{row_dict['ID']};"
        f"{row_dict['Data']};"
        f"{row_dict['Estrategia']};"
        f"{row_dict['Timeframe']};"
        f"{row_dict['Periodo']};"
        f"{row_dict['Ativo']};"
        f"{row_dict['Modelo_Ticks']};"
        f"{row_dict['Banca_USD']};"
        f"{row_dict['Lucro_USD']:.2f};"
        f"{row_dict['Fator_Lucro']:.2f};"
        f"{row_dict['Trades']};"
        f"{row_dict['WinRate_Pct']};"
        f"{row_dict['Max_DD_USD']:.2f};"
        f"{row_dict['Semanas_Stop12_Violado']};"
        f"{row_dict['Conclusao']}\n"
    )

    if not csv_path.exists():
        with open(csv_path, "w", encoding="utf-8") as f:
            f.write(header)
            f.write(formatted_row)
        return

    # Check existing lines to update existing ID or append new
    with open(csv_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    id_target = row_dict["ID"]
    updated = False
    new_lines = []
    for line in lines:
        parts = line.split(";")
        if parts and parts[0].strip().upper() == id_target.strip().upper():
            new_lines.append(formatted_row)
            updated = True
        else:
            new_lines.append(line)

    if not updated:
        new_lines.append(formatted_row)

    with open(csv_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Unified MT5 Strategy Tester Report Parser and EXPERIMENTOS.csv Recorder"
    )
    parser.add_argument(
        "--report", "-r", required=True,
        help="Path or name of the MT5 HTML report (.htm / .html)"
    )
    parser.add_argument(
        "--exp-id", default=None,
        help="Experiment identifier (e.g., EXP-014, EXP-015)"
    )
    parser.add_argument(
        "--strategy", default=None,
        help="Strategy name (e.g., 'ALIEN V12.1 INSTITUTIONAL')"
    )
    parser.add_argument(
        "--csv", default=None,
        help="Optional path to EXPERIMENTOS.csv to append/update the record"
    )
    parser.add_argument(
        "--timeframe", default=None,
        help="Timeframe override (e.g., M1)"
    )
    parser.add_argument(
        "--period", default=None,
        help="Period override (e.g., '2026.10.21 - 2026.11.07')"
    )
    parser.add_argument(
        "--symbol", default=None,
        help="Asset symbol override (e.g., XAUUSD)"
    )
    parser.add_argument(
        "--deposit", type=float, default=None,
        help="Deposit override (e.g., 10000)"
    )
    parser.add_argument(
        "--model", default="Real Ticks (4)",
        help="Tick model name (default: 'Real Ticks (4)')"
    )
    parser.add_argument(
        "--stop-violated", default=None,
        help="Value for Semanas_Stop12_Violado column"
    )
    parser.add_argument(
        "--conclusion", default=None,
        help="Custom conclusion string for EXPERIMENTOS.csv"
    )
    parser.add_argument(
        "--date", default=None,
        help="Date string YYYY-MM-DD (default: current date)"
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Output JSON representation to stdout"
    )
    parser.add_argument(
        "--quiet", action="store_true",
        help="Suppress Markdown table output"
    )

    args = parser.parse_args()

    # 1. Resolve file path
    try:
        report_path = resolve_report_path(args.report)
    except FileNotFoundError as e:
        sys.stderr.write(f"ERRO: {e}\n")
        sys.exit(1)

    # 2. Read and parse report HTML
    html_text = read_report_file(str(report_path))
    raw_pairs = parse_report_html(html_text)
    metrics = extract_metrics(raw_pairs, report_path)

    # Overrides from CLI
    if args.strategy:
        metrics["strategy"] = args.strategy
    if args.symbol:
        metrics["symbol"] = args.symbol
    if args.timeframe:
        metrics["timeframe"] = args.timeframe
    if args.period:
        metrics["period"] = args.period
    if args.deposit is not None:
        metrics["deposit"] = args.deposit

    exp_id = args.exp_id or report_path.stem

    # 3. Print JSON or Markdown
    if args.json:
        out_dict = dict(metrics)
        out_dict["exp_id"] = exp_id
        print(json.dumps(out_dict, indent=2))
    elif not args.quiet:
        md_table = generate_markdown_summary(metrics, exp_id)
        print(md_table)

    # 4. Append to CSV if requested
    if args.csv:
        csv_file = Path(args.csv).resolve()
        date_str = args.date or datetime.now().strftime("%Y-%m-%d")

        # Stop rule evaluation
        if args.stop_violated:
            stop_viol = args.stop_violated
        else:
            if metrics["max_dd_money"] < 140.0:
                stop_viol = f"Nao (DD ${metrics['max_dd_money']:.2f} < $140)"
            else:
                stop_viol = f"Sim (DD ${metrics['max_dd_money']:.2f} >= $140)"

        # Conclusion string
        if args.conclusion:
            concl = args.conclusion
        else:
            rr_str = f"{metrics['risk_reward']:.2f}" if metrics['risk_reward'] != float("inf") else "inf"
            concl = (
                f"Lucro +${metrics['net_profit']:.2f}, PF {metrics['profit_factor']:.2f}, "
                f"WR {metrics['win_rate']:.1f}%, Max DD ${metrics['max_dd_money']:.2f}, "
                f"R:R {rr_str} ({metrics['total_trades']} trades)."
            )

        row_dict = {
            "ID": exp_id,
            "Data": date_str,
            "Estrategia": metrics["strategy"],
            "Timeframe": metrics["timeframe"],
            "Periodo": metrics["period"],
            "Ativo": metrics["symbol"],
            "Modelo_Ticks": args.model,
            "Banca_USD": int(metrics["deposit"]),
            "Lucro_USD": metrics["net_profit"],
            "Fator_Lucro": metrics["profit_factor"],
            "Trades": metrics["total_trades"],
            "WinRate_Pct": f"{metrics['win_rate']:.1f}%",
            "Max_DD_USD": metrics["max_dd_money"],
            "Semanas_Stop12_Violado": stop_viol,
            "Conclusao": concl,
        }

        append_to_experiment_csv(csv_file, row_dict)
        if not args.quiet:
            print(f"Registro gravado com sucesso em: {csv_file}")


if __name__ == "__main__":
    main()
