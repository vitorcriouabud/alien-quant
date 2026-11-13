#!/usr/bin/env python3
"""R4.1: guardas estaticas e equivalencia dos presets. NAO compila MQL5."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"MQL5/Experts/ALIEN_GENESIS_MTF_R41_DEMO.mq5"
A=ROOT/"MQL5/Profiles/Tester/ALIEN_R41_A_BASELINE.set"
B=ROOT/"MQL5/Profiles/Tester/ALIEN_R41_B_RETESTE.set"

def parse_set(path):
    found={}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if not line or line.lstrip().startswith(";") or "=" not in line:
            continue
        key,values=line.split("=",1)
        assert key not in found, "Input duplicado: "+key
        found[key]=values.split("||")[0]
    return found

class R41StaticChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=SOURCE.read_text(encoding="utf-8")

    def test_baseline_diff_only_is_retest_and_csv_name(self):
        a,b=parse_set(A),parse_set(B)
        self.assertEqual(set(a),set(b))
        diffs={k for k in a if a[k]!=b[k]}
        self.assertEqual(diffs,{"EnableM1Retest","CSVFileName"})
        self.assertEqual(a["EnableM1Retest"],"false")
        self.assertEqual(b["EnableM1Retest"],"true")

    def test_defaults_match_frozen_input_sets(self):
        pattern=r'^\s*input\s+(bool|int|double|ulong|string)\s+([A-Za-z]\w*)\s*=\s*([^;]+);'
        source_inputs={name:val.strip().strip('"') for typ,name,val in re.findall(
            pattern,self.s,re.MULTILINE)}
        b=parse_set(B)
        self.assertEqual(set(b),set(source_inputs))
        self.assertEqual(source_inputs["EnableM1Retest"],"true")
        for key in source_inputs:
            self.assertEqual(b[key],source_inputs[key],key)

    def test_no_trade_on_real(self):
        self.assertIn("if(!IsDemoOrTester())",self.s)
        self.assertIn("if(!EntryAllowed(dir))",self.s)
        self.assertIn("AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO",self.s)
        self.assertIn("TRADE_TRANSACTION_DEAL_ADD",self.s)

    def test_stop_not_widened_for_retest(self):
        self.assertIn("if(stopPoints>MaximumStopPoints)",self.s)
        self.assertIn("ArmRetestFromDisplacement(",self.s)
        self.assertIn("g_setup.sweepExtreme-StopBufferPoints*_Point",self.s)
        self.assertIn("g_setup.sweepExtreme+(StopBufferPoints+spread)*_Point",self.s)
        self.assertIn("if(rounded+1e-9<minLot) return false",self.s)
        self.assertIn("RewardRiskMultiple*stopPoints*_Point",self.s)

    def test_retest_uses_closed_candles_only_after_confirmation(self):
        for phrase in (
           "CopyRates(_Symbol,tf,1,count,bars)",
           "if(bar.time<g_setup.retestAfter) return",
           "if(bar.time>=g_setup.retestExpires)",
           "bar.close>bar.open",
           "bar.close<bar.open",
           "g_setup.stage==2",
           "if(newM5Open<=g_setup.retestExpires) return",
           "RET_INVALIDADO",
           "RET_EXPIRADO",
           "RET_ORDEM_EXECUTADA",
        ):
            self.assertIn(phrase,self.s)

    def test_csv_fields_and_commission_buffer(self):
        self.assertIn('"setup_stage","retest_level","retest_eligible_after"',self.s)
        self.assertIn('"stop_points","direction"',self.s)
        self.assertIn('"TRADE_FECHADO"',self.s)
        self.assertRegex(self.s,r'EstimatedRoundTurnPerLot\s*=\s*8\.30;')
        self.assertRegex(self.s,r'RiskPercentEquity\s*=\s*0\.25;')
        self.assertRegex(self.s,r'RewardRiskMultiple\s*=\s*4\.0;')

    def test_runner_uses_override_preset(self):
        runner=(ROOT/"tools/Run-Backtest.ps1").read_text(encoding="utf-8")
        wrapper=(ROOT/"tools/RODAR_R41_AB.ps1").read_text(encoding="utf-8")
        self.assertIn('[string]$PresetPath',runner)
        self.assertIn('if ($PresetPath)',runner)
        self.assertIn("PresetPath=$workingSet",wrapper)
        self.assertIn('C:\\ALIEN_TEST_MT5\\terminal64.exe',wrapper)
        self.assertIn('NoCsv=$true',wrapper)

if __name__=="__main__":
    unittest.main()
