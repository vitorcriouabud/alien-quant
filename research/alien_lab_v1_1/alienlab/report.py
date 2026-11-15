"""Relatório HTML sóbrio. Não promove hipótese a estratégia lucrativa."""

from __future__ import annotations

import html
from pathlib import Path

import pandas as pd


def _table(df: pd.DataFrame, max_rows: int = 400) -> str:
    if df is None or df.empty:
        return "<p>Sem linhas.</p>"
    view = df.head(max_rows)
    cols = "".join(f"<th>{html.escape(str(c))}</th>" for c in view.columns)
    body = []
    for rec in view.itertuples(index=False):
        tds = []
        for value in rec:
            text = "" if value is None else str(value)
            if isinstance(value, float):
                text = f"{value:.4f}"
            tds.append(f"<td>{html.escape(text)}</td>")
        body.append("<tr>" + "".join(tds) + "</tr>")
    extra = ""
    if len(df) > max_rows:
        extra = f"<p>Mostrando {max_rows} de {len(df)} linhas. O CSV tem o restante.</p>"
    return extra + "<table><thead><tr>" + cols + "</tr></thead><tbody>" + "".join(body) + "</tbody></table>"


def write_html(
    path: Path,
    *,
    audit: dict,
    metrics: pd.DataFrame,
    paired: pd.DataFrame,
    errors: list[str],
) -> None:
    focus = metrics[
        (metrics["horizon_min"] == 15)
        & (metrics["cost_mode"] == "penalize_zero")
        & (metrics["slippage_points"] == metrics["slippage_points"].min())
    ] if len(metrics) else metrics
    cols = [
        "hypothesis_id",
        "n_filled",
        "mean_net_points",
        "mean_without_best",
        "win_rate",
        "profit_factor",
        "months_positive_frac",
        "screen",
    ]
    show = focus[cols] if len(focus) else focus
    rejected = int((metrics["screen"] == "REJECT").sum()) if len(metrics) else 0
    fragile = int((metrics["screen"] == "FRAGILE").sum()) if len(metrics) else 0
    screen = int((metrics["screen"] == "SURVIVES_SCREEN").sum()) if len(metrics) else 0
    inc = int((metrics["screen"] == "INCONCLUSIVE").sum()) if len(metrics) else 0
    err_html = "<br>".join(html.escape(e) for e in errors) or "nenhum"
    claim = html.escape(str(audit.get("claim_level", "exploratory")))
    body = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>ALIEN LAB V1 — triagem</title>
<style>
body {{ font-family: Georgia, serif; margin: 2rem; color: #1c1915; background: #f6f3ec; }}
h1,h2 {{ font-weight: 500; }}
table {{ border-collapse: collapse; width: 100%; background: white; font-family: ui-monospace, monospace; font-size: 12px; }}
th, td {{ border: 1px solid #d9d2c5; padding: 4px 6px; text-align: left; }}
th {{ background: #ece6da; }}
.note {{ background: #fff8e8; border: 1px solid #e2d2a8; padding: 0.8rem 1rem; }}
</style>
</head>
<body>
<h1>ALIEN LAB V1 — motor quantitativo</h1>
<div class="note">
<p>Isto é triagem em OHLC. Não é prova de lucro, não usa ticks reais e não autoriza operação.</p>
<p>Nível da amostra: <strong>{claim}</strong>. Hash das definições: <code>{html.escape(str(audit.get("definitions_sha256", "")))}</code></p>
<p>Grades: REJECT {rejected} · FRAGILE {fragile} · INCONCLUSIVE {inc} · SURVIVES_SCREEN {screen}.
SURVIVES_SCREEN só quer dizer que a média líquida, a média sem o melhor trade e a maioria dos meses ficaram positivas nesta amostra. Não é validação.</p>
</div>
<h2>Horizonte 15 min, spread zero penalizado, menor slippage da grade</h2>
{_table(show, 80)}
<h2>Pares núcleo versus confluência ou controle</h2>
{_table(paired, 200)}
<h2>Erros</h2>
<p>{err_html}</p>
</body>
</html>
"""
    path.write_text(body, encoding="utf-8")
