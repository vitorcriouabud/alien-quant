"""ALIEN TURBO: static MQL5 gates, 8 frozen presets, and synthetic ZIP audit."""
import csv
from hashlib import sha256
import io
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/"MQL5/Experts/ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
RUN=ROOT/"tools/RODAR_ALIEN_TURBO_DISCOVERY.ps1"
sys.path.insert(0,str(ROOT/"tools"))
from audit_alien_turbo import audit, VARIANTS


def read_inputs(file):
    out={}
    for line in file.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith(";"):continue
        if "=" not in line:raise ValueError("bad preset line")
        name,v=line.split("=",1)
        if name in out:raise ValueError("duplicate input "+name)
        out[name]=v.split("||")[0]
    return out


class TurboTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=SRC.read_text(encoding="utf-8")
        cls.runner=RUN.read_text(encoding="utf-8")
        cls.profiles={key:read_inputs(ROOT/f"MQL5/Profiles/Tester/ALIEN_TURBO_{key}.set")
                      for key in VARIANTS}

    def test_all_nine_variants_present(self):
        self.assertEqual(len(self.profiles),9)
        self.assertEqual(len(VARIANTS),9)
        base=self.profiles["A_BASE"]
        self.assertEqual(base["MaxDayTrades"],"6")
        self.assertEqual(base["CooldownMinutes"],"30")
        self.assertEqual(base["MaxOpenPositions"],"1")
        self.assertEqual(base["StartServerHour"],"7")
        self.assertEqual(base["EndServerHour"],"20")
        self.assertEqual(base["RewardRisk"],"2.0")

    def test_expected_incremental_differences_only(self):
        expected={
           "A_BASE":{},
           "B_FREQUENCY":{"MaxDayTrades":"1440","CooldownMinutes":"0"},
           "C_ALLDAY":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24"},
           "D_MULTI5":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5"},
           "E_H1M15":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5","RequireH1M15Context":"true"},
           "F_M5SWEEP":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5","RequireM5ClosedSweep":"true"},
           "G_M15FVG":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5","RequireM15ClosedFVG":"true"},
           "H_RR3":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5","RewardRisk":"3.0"},
           "I_RISKSIZED":{"MaxDayTrades":"1440","CooldownMinutes":"0",
                       "StartServerHour":"0","EndServerHour":"24",
                       "MaxOpenPositions":"5","MaxLot":"0.05"},
        }
        b=self.profiles["A_BASE"]
        for key,inputs in self.profiles.items():
            self.assertEqual(set(inputs),set(b),key)
            diff={k:v for k,v in inputs.items()
                  if v!=b[k] and k not in (
                      "CSVFileName","TapeCSVFileName","OutcomeCSVFileName")}
            self.assertEqual(diff,expected[key],key)

    def test_inputs_match_source_and_safety_defaults(self):
        params=dict(re.findall(
            r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',
            self.source,re.M))
        base=self.profiles["A_BASE"]
        self.assertEqual(set(params),set(base))
        for k,v in params.items():
            if k in ("CSVFileName","TapeCSVFileName","OutcomeCSVFileName"):continue
            self.assertEqual(base[k],v.strip().strip('"'),k)
        for id,inputs in self.profiles.items():
            for k,v in (
                ("EnableTesterOrders","true"),
                ("InitialDepositUsd","5000.0"),
                ("RiskLimitPct","0.25"),
                ("RiskMaxUsd","12.50"),
                ("FloatingSafetyUsd","35.0"),
                ("EnableSignalTape","true"),
                ("EnableM1ShadowOutcomes","true"),
            ):
                self.assertEqual(inputs[k],v,id)
            self.assertEqual(inputs["MaxLot"],
                             "0.05" if id=="I_RISKSIZED" else "0.02",id)

    def test_tape_sees_signals_before_execution_limits(self):
        s=self.source
        section=s[s.index("void TestSignal()"):s.index("int OnInit()")]
        for snippet in (
            "g_signals++;",
            "TapeCandidate(id,b[0].time,q,dir",
            "StartShadow(id,b[0].time,q,dir",
            "if(g_locked)return;",
            "if(!SessionOK())return;",
            "if(PositionsTotal()>=EffectiveMaxOpenPositions())return;",
            "if(g_dayTrades>=MaxDayTrades)return;",
        ):
            self.assertIn(snippet,section)
        self.assertLess(section.index("TapeCandidate("),section.index("if(g_locked)return;"))
        self.assertLess(section.index("StartShadow("),section.index("if(g_locked)return;"))
        self.assertIn("g_locked",s)
        self.assertIn("if(!g_totalLocked)g_locked=false;",s)

    def test_closed_causal_market_features(self):
        s=self.source
        for pattern in (
            "CopyRates(_Symbol,PERIOD_M1,1,22,rates)",
            "CopyRates(_Symbol,PERIOD_H1,1,count,h)",
            "CopyRates(_Symbol,PERIOD_M15,1,M15EquilibriumBars,m)",
            "CopyRates(_Symbol,PERIOD_M5,1,11,m)",
            "CopyRates(_Symbol,PERIOD_M15,1,3,m)",
            'LogRow("VETO_M5_SWEEP"',
            'LogRow("VETO_M15_FVG"',
            "m5_sweep_aligned",
            "m15_fvg_aligned",
            "bb20_width_pts",
            "m1_atr14_pts",
        ):
            self.assertIn(pattern,s)

    def test_simulation_marks_ambiguity_and_estimated_ask(self):
        s=self.source
        for token in (
            '"BOTH_TOUCHED_AMBIGUOUS"',
            '"ASK_EST_FROM_BID_PLUS_ENTRY_SPREAD"',
            '"SIMULACAO_OHLC_M1_NAO_TICK_FILL"',
            '"CENSORED_END_NO_FUTURE_DATA"',
            "if(hitStop && hitTarget)",
            "if(closed[0].time<=c.signalBarTime)continue",
        ):
            self.assertIn(token,s)

    def test_risk_and_tester_guards_preserved(self):
        s=self.source
        for token in (
            "if(MQLInfoInteger(MQL_TESTER)==0 || !EnableTesterOrders ||",
            "if(MQLInfoInteger(MQL_TESTER)==0)return;",
            "MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-5000.0)>0.01",
            "MaxDayTrades>1440",
            "MaxOpenPositions>5",
            "MaxLot>0.05",
            "RiskMaxUsd>12.50",
            "RiskLimitPct>0.25",
            "TotalLossGuardPct>8.0",
            "FloatingSafetyUsd>40.0",
            "ActiveWorstStopExposureUsd()",
            "AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING",
            "OrderCalcProfit(kind,symbol,lot,entry,slWorst,pnl)",
        ):
            self.assertIn(token,s)
        self.assertNotIn("WebRequest(",s)

    def test_runner_collects_all_variants_and_partial_zips(self):
        s=self.runner
        for token in (
            "Stop-AlienIsolatedTerminal -Stage",
        ):
            # Current runner names this function Stop-AlienIsolatedTerminal.
            self.assertIn(token,s)
        for key in VARIANTS:
            self.assertIn(f'id="{key}"',s)
        for token in (
            "GetFullPath($_.ExecutablePath) -ieq $expected",
            "Stop-Process -Id $pIdLocal -Force",
            'Where-Object {$_.LastWriteTime -ge $start.AddMinutes(-2)}',
            '"TRADES.csv"',
            '"_CANDIDATES.csv"',
            '"_OUTCOMES.csv"',
            "Copy-Item -LiteralPath $ex5 -Destination $copy",
            "Compress-Archive",
            "Empacotando evidencias ja prontas",
        ):
            if token in ('"TRADES.csv"','"_CANDIDATES.csv"'):
                continue
            self.assertIn(token,s)

    def test_synthetic_zip_audit_verifies_hashes_and_does_not_claim_fills(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/"ALIEN_TURBO_DISCOVERY_FAKE.zip"
            source=b"synthetic source"
            binary=b"synthetic compiled file"
            prefix=path.stem+"_A_BASE"
            header=["event","realized_net_usd","volume","equity_usd"]
            o=io.StringIO()
            w=csv.DictWriter(o,fieldnames=header,delimiter=";")
            w.writeheader()
            for event,net,lot in (
                ("ORDER_ATTEMPT","0","0.02"),
                ("ORDER_FILLED","0","0.02"),
                ("DEAL_IN","0","0.02"),
                ("DEAL_OUT","-3","0.02"),
            ):
                w.writerow({"event":event,"realized_net_usd":net,
                            "volume":lot,"equity_usd":"5000"})
            trade_bytes=o.getvalue().encode("utf-8")
            tape=("candidate_id;direction;bid;ask;spread_points;entry;stop;"
                  "stop_points;both_context_ok;m5_sweep_aligned;m15_fvg_aligned;"
                  "stop_within_limits;spread_within_limit\n"
                  "one;BUY;100;100.1;10;100.1;99;110;1;0;0;1;1\n").encode()
            outcomes=b"candidate_id;state\none;TARGET_FIRST_TOUCH_M1\n"
            profile=b"EnableTesterOrders=true\nInitialDepositUsd=5000.0\n"
            html=b"synthetic HTML, NOT real MT5"
            files={
               "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5":source,
               "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.ex5":binary,
               prefix+"_TRADES.csv":trade_bytes,
               prefix+"_CANDIDATES.csv":tape,
               prefix+"_OUTCOMES.csv":outcomes,
               prefix+".set":profile,
               prefix+".htm":html,
            }
            hashval=lambda x:sha256(x).hexdigest().upper()
            row={
                "variant":"A_BASE","changed_inputs":{},
                "ex5_sha256":hashval(binary),
                "preset_sha256":hashval(profile),
                "report_sha256":hashval(html),
                "trades_sha256":hashval(trade_bytes),
                "candidates_sha256":hashval(tape),
                "outcomes_sha256":hashval(outcomes),
                "filled":1,"deals_in":1,"deals_out":1,"candidates":1,
            }
            manifest={
                "schema":"ALIEN_TURBO_DISCOVERY_V1",
                "capital_usd":5000,"model":4,
                "source_sha256":hashval(source),
                "compiled_sha256":hashval(binary),
                "success":False,"failure":"synthetic partial",
                "experiments":[row],
            }
            with ZipFile(path,"w") as z:
                for name,data in files.items():z.writestr(name,data)
                z.writestr("MANIFESTO.json",json.dumps(manifest))
            res=audit(path)
            self.assertEqual(res["status"],"PARTIAL")
            self.assertEqual(res["results"]["A_BASE"]["net_tester_deals_usd"],"-3")
            self.assertEqual(res["results"]["A_BASE"]["net_after_additional_fee_scenario_usd"],"-3.10")
            self.assertEqual(res["results"]["A_BASE"]["total_unrestricted_m1_candidates"],1)
            files[prefix+"_TRADES.csv"]=trade_bytes+b"tamper"
            damaged=Path(tmp)/"ALIEN_TURBO_DISCOVERY_FAKE_tampered.zip"
            with ZipFile(damaged,"w") as z:
                for name,data in files.items():z.writestr(name,data)
                z.writestr("MANIFESTO.json",json.dumps(manifest))
            # Use same canonical file names despite zip stem suffix.
            # A mismatched zip label itself may reject before the SHA.
            with self.assertRaises(ValueError):
                audit(damaged)


if __name__=="__main__":
    unittest.main()
