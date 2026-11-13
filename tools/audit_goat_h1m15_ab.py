#!/usr/bin/env python3
"""ALIEN GOAT5K H1/M15 A/B — auditoria deterministica de ZIP MT5.

Requires only Python stdlib. Does NOT infer broker availability, real fills,
profitability, unseen tick data, or Goat Funded Trader compliance.
"""
from __future__ import annotations

import argparse
import csv
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import statistics
from zipfile import ZipFile

NAMES = ("A_BASE", "B_CONTEXT")


def D(value: str | int | float) -> Decimal:
    return Decimal(str(value))


def one_member(archive: ZipFile, label: str, suffix: str) -> str:
    found = [n for n in archive.namelist()
             if n.startswith(f"ALIEN_H1M15_{label}_")
             and n.lower().endswith(suffix.lower())]
    if len(found) != 1:
        raise ValueError(f"{label}: expected one {suffix}, got {len(found)}")
    return found[0]


def analyze(zip_path: Path) -> dict:
    with ZipFile(zip_path) as z:
        manifest_files = [n for n in z.namelist() if n.endswith("MANIFESTO.json")]
        if len(manifest_files) != 1:
            raise ValueError("exactly one MANIFESTO.json required")
        manifest = json.loads(z.read(manifest_files[0]))
        if manifest.get("schema") != "ALIEN_H1M15_EXECUTION_AB_V1":
            raise ValueError("unknown schema; refuse ambiguous ZIP")
        if manifest.get("deposit") != 5000 or manifest.get("model") != 4:
            raise ValueError("not a 5k real-ticks-requested tester package")
        experiments = {p["label"]:p for p in manifest["experiments"]}
        if set(experiments) != set(NAMES):
            raise ValueError("expected exactly A_BASE and B_CONTEXT")
        if experiments["A_BASE"]["required_context"] is not False:
            raise ValueError("A must have context OFF")
        if experiments["B_CONTEXT"]["required_context"] is not True:
            raise ValueError("B must have context ON")
        hashes = {p["ex5_sha256"] for p in experiments.values()}
        if len(hashes) != 1:
            raise ValueError("different compiled EX5 hash between A/B")

        results = {}
        for label in NAMES:
            p = experiments[label]
            csv_name = one_member(z, label, "_EVENTS.csv")
            preset_name = one_member(z, label, ".set")
            html_candidates = [n for n in z.namelist()
                               if n.startswith(f"ALIEN_H1M15_{label}_")
                               and n.lower().endswith((".htm",".html"))]
            if len(html_candidates)!=1:
                raise ValueError(f"{label}: missing/duplicate MT5 report")
            name_values = (
                (csv_name,"event_log_sha256"),
                (preset_name,"preset_sha256"),
                (html_candidates[0],"report_sha256"),
            )
            for member, key in name_values:
                actual = hashlib.sha256(z.read(member)).hexdigest().upper()
                if actual != str(p[key]).upper():
                    raise ValueError(f"SHA mismatch: {label} {key}")

            preset_text = z.read(preset_name).decode("ascii", errors="replace")
            mode = "true" if label == "B_CONTEXT" else "false"
            rows_preset = [x for x in preset_text.splitlines()
                           if x.startswith("RequireH1M15Context=")]
            if len(rows_preset)!=1 or not rows_preset[0].startswith(
                    "RequireH1M15Context="+mode+"||"):
                raise ValueError(f"{label}: wrong frozen .set mode")

            content = z.read(csv_name).decode("utf-8-sig", errors="replace")
            rows = list(csv.DictReader(io.StringIO(content), delimiter=";"))
            events = [x.get("event","") for x in rows]
            counts = {event:events.count(event) for event in set(events)}
            deal_rows=[x for x in rows if x.get("event") in ("DEAL_IN","DEAL_OUT")]
            opened=[x for x in rows if x.get("event")=="ORDER_FILLED"]
            closed=[x for x in rows if x.get("event")=="DEAL_OUT"]
            per_deal=[D(x["realized_net_usd"] or "0") for x in deal_rows]
            per_close=[D(x["realized_net_usd"] or "0") for x in closed]
            real_net=sum(per_deal, D(0))
            extra_fee=sum((D(x["volume"] or "0") for x in opened), D(0))*D(
                manifest.get("fee_usd_per_lot_roundtrip_assumption",5))
            profit=sum((max(D(0),n) for n in per_close),D(0))
            loss=sum((-min(D(0),n) for n in per_close),D(0))
            pf=None if loss==0 else float(profit/loss)
            logged_eq=[D(x["equity_usd"]) for x in rows
                       if x.get("equity_usd")]
            result={
                "report_file":html_candidates[0],
                "events":len(rows),
                "order_attempts":counts.get("ORDER_ATTEMPT",0),
                "order_filled":len(opened),
                "deal_in":counts.get("DEAL_IN",0),
                "deal_out":len(closed),
                "context_rejected":counts.get("VETO_CONTEXTO",0),
                "context_approved":counts.get("CONTEXTO_APROVADO",0),
                "stop_rejected":counts.get("VETO_STOP",0),
                "spread_rejected":counts.get("VETO_SPREAD",0),
                "sizing_rejected":counts.get("VETO_LOTE",0),
                "trade_win_rate_pct_from_exit_deals":(
                   100.0*sum(x>0 for x in per_close)/len(per_close)
                   if per_close else None),
                "net_usd_from_deal_rows":str(real_net),
                "net_usd_after_ADDITIONAL_fee_scenario":str(real_net-extra_fee),
                "cost_scenario_extra_usd":str(extra_fee),
                "profit_factor_on_exit_deals_before_entry_fees":pf,
                "min_equity_at_logged_events_only":(
                   str(min(logged_eq)) if logged_eq else None),
                "source":"MetaQuotes-Demo tester; not Goat live",
            }
            if len(opened)!=counts.get("DEAL_IN",0):
                result["WARNING"]="Filled orders differ from deal IN count; inspect partial fills"
            results[label]=result

        base=results["A_BASE"];ctx=results["B_CONTEXT"]
        baseline_count=base["order_filled"]
        return {
            "schema":"ALIEN_H1M15_AB_AUDIT_V1",
            "input_zip":zip_path.name,
            "manifest_validated":True,
            "sha256_verified_six_files":True,
            "identical_ex5_declared_hash":True,
            "baseline_96_fills_reference_count_match":baseline_count==96,
            "important_baseline_note":(
                "Matching 96 fills alone does not prove identical trade-by-trade reproduction."
            ),
            "same_period_but_NOT_independent_holdout":True,
            "trade_selection_policies_differ":True,
            "net_reported_trade_rows_not_full_dd":True,
            "assumed_fee_may_double_count_if_broker_charged_commission":True,
            "not_goat_server_data":True,
            "results":results,
            "delta_b_minus_a_deal_net_usd":str(
                D(ctx["net_usd_from_deal_rows"])-
                D(base["net_usd_from_deal_rows"])
            ),
        }


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip",type=Path,help="ZIP from RODAR_GOAT5K_H1M15_AB.ps1")
    parser.add_argument("--out",type=Path,default=None,help="Output JSON")
    args=parser.parse_args()
    result=analyze(args.zip)
    output=json.dumps(result,indent=2,ensure_ascii=False)
    if args.out is not None:
        args.out.parent.mkdir(parents=True,exist_ok=True)
        args.out.write_text(output+"\n",encoding="utf-8")
    print(output)


if __name__=="__main__":
    main()
