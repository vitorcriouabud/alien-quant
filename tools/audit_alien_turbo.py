#!/usr/bin/env python3
"""ALIEN TURBO Discovery ZIP auditor: primary MT5 tester deals vs M1 shadow approximations.

- Verifies SHA256 for each archived HTML/CSV/SET and compiled EX5+source
- Compares all 9 policies; counts raw M1 signal cohort independent of execution
- Counts M1 OHLC approximate outcomes separately, preserving BOTH-HIT ambiguity
- No claims of live Goat fills, robust out-of-sample edge, or risk compliance
"""
from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import io
import json
from pathlib import Path
from zipfile import ZipFile

VARIANTS=(
    "A_BASE","B_FREQUENCY","C_ALLDAY","D_MULTI5",
    "E_H1M15","F_M5SWEEP","G_M15FVG","H_RR3","I_RISKSIZED",
)
D=lambda x:Decimal(str(x))


def sha(data:bytes)->str:
    return hashlib.sha256(data).hexdigest().upper()


def parse_csv(payload:bytes)->list[dict]:
    content=payload.decode("utf-8-sig", errors="replace")
    return list(csv.DictReader(io.StringIO(content),delimiter=";"))


def one(z:ZipFile,needle:str,extension:str)->str:
    items=[n for n in z.namelist()
           if Path(n).name.startswith(needle) and
           n.lower().endswith(extension.lower())]
    if len(items)!=1:
        raise ValueError(f"Need exactly one {needle} {extension}; got {items}")
    return items[0]


def parse_decimal(value:str|None)->Decimal:
    if value is None or value=="":
        return D(0)
    try:
        return D(value)
    except InvalidOperation as e:
        raise ValueError(f"invalid numeric value: {value}") from e


def audit(path:Path)->dict:
    with ZipFile(path) as z:
        manifest_name=one(z,"MANIFESTO",".json")
        manifest=json.loads(z.read(manifest_name).decode("utf-8-sig"))
        if manifest.get("schema")!="ALIEN_TURBO_DISCOVERY_V1":
            raise ValueError("invalid manifest schema")
        if manifest.get("capital_usd")!=5000 or manifest.get("model")!=4:
            raise ValueError("expected MT5 $5k real ticks requested")
        src=one(z,"ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER",".mq5")
        if sha(z.read(src))!=str(manifest["source_sha256"]).upper():
            raise ValueError("SHA source mismatch")
        if manifest.get("compiled_sha256"):
            compiled=one(z,"ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER",".ex5")
            if sha(z.read(compiled))!=str(manifest["compiled_sha256"]).upper():
                raise ValueError("SHA EX5 mismatch")
        variants={}
        candidate_cohorts={}
        compiled_hashes=set()
        for row in manifest["experiments"]:
            label=row["variant"]
            if label not in VARIANTS or label in variants:
                raise ValueError("unknown/duplicate variant "+label)
            experiment_name=Path(path).stem+"_"+label
            ext={
                "preset_sha256":one(z,experiment_name,".set"),
                "trades_sha256":one(z,experiment_name+"_TRADES",".csv"),
                "candidates_sha256":one(z,experiment_name+"_CANDIDATES",".csv"),
                "outcomes_sha256":one(z,experiment_name+"_OUTCOMES",".csv"),
            }
            htmls=[n for n in z.namelist()
                   if Path(n).name.startswith(experiment_name) and
                   n.lower().endswith((".htm",".html"))]
            if len(htmls)!=1:raise ValueError("missing/duplicate HTML for "+label)
            ext["report_sha256"]=htmls[0]
            for hash_key,filename in ext.items():
                actual=sha(z.read(filename))
                if actual!=str(row[hash_key]).upper():
                    raise ValueError(f"{label}: SHA mismatch {hash_key}")
            compiled_hashes.add(str(row["ex5_sha256"]).upper())
            if (manifest.get("compiled_sha256") and
                str(row["ex5_sha256"]).upper()!=str(manifest["compiled_sha256"]).upper()):
                raise ValueError("compiled source differs between variants")
            ptext=z.read(ext["preset_sha256"]).decode("ascii",errors="replace")
            conf={}
            for line in ptext.splitlines():
                if not line or line.startswith(";"):continue
                if "=" not in line:continue
                name,val=line.split("=",1)
                if name in conf:raise ValueError(f"{label}: duplicate preset input {name}")
                conf[name]=val.split("||")[0]
            for k,v in row["changed_inputs"].items():
                if conf.get(k)!=str(v):
                    raise ValueError(f"{label}: expected {k}={v} got {conf.get(k)}")
            if conf.get("EnableTesterOrders")!="true" or conf.get("InitialDepositUsd")!="5000.0":
                raise ValueError(f"{label}: unsafe profile")
            trades=parse_csv(z.read(ext["trades_sha256"]))
            cand=parse_csv(z.read(ext["candidates_sha256"]))
            out=parse_csv(z.read(ext["outcomes_sha256"]))
            ids={}
            for c in cand:
                key=c.get("candidate_id")
                if not key or key in ids:raise ValueError(f"{label}: duplicate candidate {key}")
                ids[key]=c
            candidate_cohorts[label]=ids
            fills=[t for t in trades if t.get("event")=="ORDER_FILLED"]
            ins=[t for t in trades if t.get("event")=="DEAL_IN"]
            exits=[t for t in trades if t.get("event")=="DEAL_OUT"]
            deal_rows=[t for t in trades if t.get("event") in ("DEAL_IN","DEAL_OUT")]
            true_net=sum((parse_decimal(t.get("realized_net_usd")) for t in deal_rows),D(0))
            fill_volume=sum((parse_decimal(t.get("volume")) for t in fills),D(0))
            fee=fill_volume*D(5)
            wins=sum(parse_decimal(t.get("realized_net_usd"))>0 for t in exits)
            exits_pnl=[parse_decimal(t.get("realized_net_usd")) for t in exits]
            gross_wins=sum((max(D(0),p) for p in exits_pnl),D(0))
            gross_losses=sum((-min(D(0),p) for p in exits_pnl),D(0))
            estimated_pf=(str(gross_wins/gross_losses) if gross_losses>0 else None)
            events={}
            for t in trades:events[t.get("event","")]=events.get(t.get("event",""),0)+1
            o_states={}
            for o in out:o_states[o.get("state","")]=o_states.get(o.get("state",""),0)+1
            if len(fills)!=row["filled"] or len(ins)!=row["deals_in"] or len(exits)!=row["deals_out"]:
                raise ValueError(f"{label}: summary vs CSV mismatch")
            if len(cand)!=row["candidates"]:
                raise ValueError(f"{label}: tape rows vs manifest mismatch")
            variants[label]={
                "filled_tester_orders":len(fills),
                "closed_tester_deals":len(exits),
                "win_rate_pct":round(100*wins/len(exits),2) if exits else None,
                "net_tester_deals_usd":str(true_net),
                "extra_assumed_fee_usd":str(fee),
                "net_after_additional_fee_scenario_usd":str(true_net-fee),
                "profit_factor_exit_only":estimated_pf,
                "observed_event_min_equity_usd":(
                    str(min(parse_decimal(t["equity_usd"])
                            for t in trades if t.get("equity_usd")))
                    if any(t.get("equity_usd") for t in trades) else None),
                "total_unrestricted_m1_candidates":len(cand),
                "stop_and_spread_feasible":sum(
                    c.get("stop_within_limits")=="1" and
                    c.get("spread_within_limit")=="1" for c in cand),
                "both_context_aligned":sum(c.get("both_context_ok")=="1" for c in cand),
                "m5_sweep_aligned":sum(c.get("m5_sweep_aligned")=="1" for c in cand),
                "m15_fvg_aligned":sum(c.get("m15_fvg_aligned")=="1" for c in cand),
                "events":{k:v for k,v in sorted(events.items()) if
                    k.startswith(("VETO_","ORDER_","DEAL_","LOCK_"))},
                "m1_approx_outcomes":o_states,
                "input_changes":row["changed_inputs"],
            }
        if len(compiled_hashes)!=1:raise ValueError("EX5 differs across runs")
        alignment={}
        if "A_BASE" in candidate_cohorts:
            base=candidate_cohorts["A_BASE"]
            for label,cohort in candidate_cohorts.items():
                common=set(base)&set(cohort)
                align=0
                for k in common:
                    # The target may differ for 3R; entry/stop and raw
                    # market features must be identical for same candidate ID.
                    keys=("direction","bid","ask","spread_points","entry",
                          "stop","stop_points","both_context_ok",
                          "m5_sweep_aligned","m15_fvg_aligned")
                    if all(base[k].get(col)==cohort[k].get(col) for col in keys):
                        align+=1
                alignment[label]={
                    "shared_candidate_ids":len(common),
                    "base_only":len(set(base)-set(cohort)),
                    "variant_only":len(set(cohort)-set(base)),
                    "identical_market_features_on_shared":align,
                    "coverage_100pct":len(common)==len(base)==len(cohort) and align==len(common),
                }
        return {
            "schema":"ALIEN_TURBO_DISCOVERY_AUDIT_V1",
            "status":"COMPLETE" if manifest.get("success") and len(variants)==9 else "PARTIAL",
            "failure_if_partial":manifest.get("failure",""),
            "verified_primary_file_hashes":True,
            "same_compiled_ex5_hash":True,
            "results":variants,
            "shared_signal_cohort_alignment":alignment,
            "warnings":[
                "These are MT5 tester fills, not live Goat orders.",
                "M1 shadow outcomes use bid-OHLC; short exits assume constant entry spread. Both-touched bars are ambiguous.",
                "Additional $5/lot scenario can double count fees if broker already charged commissions.",
                "Drawdown must be read from primary HTML MT5 report, not sparse event equity.",
                "Multiple variants tested on same development sample: winner selection is in-sample, not proof of edge.",
                "Position cap 5 is conditional on MT5 hedging account; netting supports one symbol position.",
            ]
        }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip",type=Path)
    parser.add_argument("--out",type=Path,default=None)
    args=parser.parse_args()
    result=audit(args.zip)
    report=json.dumps(result,ensure_ascii=False,indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True,exist_ok=True)
        args.out.write_text(report+"\n",encoding="utf-8")
    print(report)


if __name__=="__main__":
    main()
