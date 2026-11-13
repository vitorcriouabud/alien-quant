"""Static and synthetic checks for ALIEN H1/M15 execution A/B (no MT5 compiler)."""
from __future__ import annotations

import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/"MQL5/Experts/ALIEN_GOAT5K_H1M15_AB_TESTER.mq5"
A=ROOT/"MQL5/Profiles/Tester/ALIEN_GOAT5K_H1M15_A_BASE.set"
B=ROOT/"MQL5/Profiles/Tester/ALIEN_GOAT5K_H1M15_B_CONTEXT.set"
RUNNER=ROOT/"tools/RODAR_GOAT5K_H1M15_AB.ps1"
sys.path.insert(0,str(ROOT/"tools"))
from audit_goat_h1m15_ab import analyze


def load_preset(path):
    out={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith(";"):continue
        k,v=line.split("=",1)
        if k in out:raise ValueError(f"duplicate input {k}")
        out[k]=v.split("||")[0]
    return out


class ABEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=EA.read_text(encoding="utf-8")
        cls.a=load_preset(A)
        cls.b=load_preset(B)
        cls.runner=RUNNER.read_text(encoding="utf-8")

    def test_one_experimental_dimension(self):
        self.assertEqual(set(self.a),set(self.b))
        differences={key for key in self.a if self.a[key]!=self.b[key]}
        self.assertEqual(differences,{"RequireH1M15Context","CSVFileName"})
        self.assertEqual(self.a["RequireH1M15Context"],"false")
        self.assertEqual(self.b["RequireH1M15Context"],"true")
        self.assertEqual(self.a["RewardRisk"],"2.0")
        self.assertEqual(self.b["SpreadLimitPoints"],"45.0")
        self.assertEqual(self.a["MaxStopPoints"],"180.0")

    def test_runner_compares_inputs_not_preset_comments(self):
        runner = self.runner
        # Regression: A and B preset headings differ but are not inputs.
        self.assertIn(
            '$_ -match "^[A-Za-z][A-Za-z0-9_]*="', runner)
        self.assertIn(
            '$_ -notmatch "^(RequireH1M15Context|CSVFileName)="', runner)
        self.assertIn('Sort-Object)', runner)
        self.assertIn('-CaseSensitive)', runner)
        lines_a = A.read_text(encoding="utf-8").splitlines()
        lines_b = B.read_text(encoding="utf-8").splitlines()
        def normalize(lines):
            return sorted(line.strip() for line in lines
                          if re.match(r'^[A-Za-z][A-Za-z0-9_]*=', line)
                          and not re.match(r'^(RequireH1M15Context|CSVFileName)=', line))
        self.assertEqual(normalize(lines_a), normalize(lines_b))
        self.assertNotEqual(lines_a[0], lines_b[0])

    def test_source_defaults_are_frozen(self):
        src=dict(re.findall(
            r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',
            self.source,re.MULTILINE))
        self.assertEqual(set(src),set(self.a))
        self.assertEqual(set(src),set(self.b))
        for key,val in src.items():
            if key in ("RequireH1M15Context","CSVFileName"):continue
            val=val.strip().strip('"')
            self.assertEqual(self.a[key],val,key)
            self.assertEqual(self.b[key],val,key)
        self.assertFalse(any("|" in line for path in (A,B)
            for line in path.read_text(encoding="utf-8").splitlines()
            if line.startswith("CSVFileName=")))

    def test_no_lookahead(self):
        s=self.source
        for item in (
          "CopyRates(_Symbol,PERIOD_H1,1,h1Required,h1)",
          "CopyRates(_Symbol,PERIOD_M15,1,M15EquilibriumBars,m15)",
          "CopyRates(_Symbol,PERIOD_M1,1,StopLookbackBars,b)",
          'if(!RequireH1M15Context) return true;',
          'LogRow("VETO_CONTEXTO",contextReason,dir,q.bid,q.ask);',
          'LogRow("CONTEXTO_APROVADO",contextReason,dir,q.bid,q.ask);',
          "h1Now>h1Prev",
          "h1[0].close>h1Now",
          "m15[0].close>middle",
          "H1TrendLookback!=20 || M15EquilibriumBars!=12",
        ):
            self.assertIn(item,s)

    def test_tester_only_risk_limits(self):
        s=self.source
        for item in (
          "if(MQLInfoInteger(MQL_TESTER)==0 || !EnableTesterOrders ||",
          "if(MQLInfoInteger(MQL_TESTER)==0) return;",
          "MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-5000.0)>0.01",
          "RiskLimitPct>0.25",
          "RiskMaxUsd>12.50",
          "FloatingSafetyUsd>40.0",
          "MaxLot>0.02",
          "PositionsTotal()>0",
          'trade.Buy(vol,_Symbol,0.0,sl,tp,"ALIEN_TESTER")',
          "TRADE_TRANSACTION_DEAL_ADD",
        ):
            self.assertIn(item,s)

    def test_ab_runner_isolated_and_evidence(self):
        s=self.runner
        for item in (
          "ALIEN_TEST_MT5",
          'Where-Object {$_.ExecutablePath -and $_.ExecutablePath -ieq $terminal}',
          "SkipCompile=($plan.label -eq \"B_CONTEXT\")",
          "Compare-Object -ReferenceObject $baseNormalized",
          "EX5 mudou entre A e B",
          "[int]$Deposit=5000",
          "Model=4",
          "event_log_sha256",
          "report_sha256",
          "CONTEXT",
          "Compress-Archive",
        ):
            if item=="CONTEXT":
                self.assertIn("VETO_CONTEXTO",s)
            else:
                self.assertIn(item,s)

    def test_synthetic_zip_audit(self):
        entries={"A_BASE":False,"B_CONTEXT":True}
        zipdata={}
        experiments=[]
        for label,on in entries.items():
            prefix=f"ALIEN_H1M15_{label}_FAKE"
            preset=f"RequireH1M15Context={'true' if on else 'false'}||x||0||x||N\n"
            out=io.StringIO()
            w=csv.DictWriter(out,fieldnames=[
                "event","realized_net_usd","volume","equity_usd"],delimiter=";")
            w.writeheader()
            for e,net,vol,eq in [
                ("ORDER_ATTEMPT",0,"0.02",5000),
                ("ORDER_FILLED",0,"0.02",5000),
                ("DEAL_IN",0,"0.02",5000),
                ("DEAL_OUT",-3 if not on else 6,"0.02",4997 if not on else 5006),
            ]:
                w.writerow({"event":e,"realized_net_usd":net,"volume":vol,"equity_usd":eq})
            html=b"valid synthetic MT5 report placeholder"
            csvdata=out.getvalue().encode("utf-8")
            pdata=preset.encode("ascii")
            files={
                prefix+"_EVENTS.csv":csvdata,
                prefix+".set":pdata,
                prefix+".htm":html,
            }
            zipdata.update(files)
            h=lambda x:hashlib.sha256(x).hexdigest().upper()
            experiments.append({
                "label":label,
                "required_context":on,
                "ex5_sha256":"ONE_IDENTICAL_SHA",
                "event_log_sha256":h(csvdata),
                "preset_sha256":h(pdata),
                "report_sha256":h(html),
            })
        manifest={
            "schema":"ALIEN_H1M15_EXECUTION_AB_V1",
            "deposit":5000,"model":4,
            "fee_usd_per_lot_roundtrip_assumption":5,
            "experiments":experiments,
        }
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"artificial.zip"
            with ZipFile(path,"w") as z:
                for fname,payload in zipdata.items():z.writestr(fname,payload)
                z.writestr("MANIFESTO.json",json.dumps(manifest))
            result=analyze(path)
            self.assertTrue(result["sha256_verified_six_files"])
            self.assertEqual(result["delta_b_minus_a_deal_net_usd"],"9")
            self.assertEqual(result["results"]["A_BASE"]["order_filled"],1)
            self.assertEqual(result["results"]["A_BASE"]["net_usd_after_ADDITIONAL_fee_scenario"],"-3.10")
            # Tamper: SHA must reject.
            corrupted=Path(folder)/"tampered.zip"
            with ZipFile(corrupted,"w") as z:
                for fname,payload in zipdata.items():
                    if fname.endswith("A_BASE_FAKE_EVENTS.csv"):payload+=b"tamper"
                    z.writestr(fname,payload)
                z.writestr("MANIFESTO.json",json.dumps(manifest))
            with self.assertRaisesRegex(ValueError,"SHA mismatch"):
                analyze(corrupted)


if __name__=="__main__":
    unittest.main()
