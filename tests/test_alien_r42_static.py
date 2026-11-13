#!/usr/bin/env python3
"""R4.2 shadow: invariantes estaticos. Nao compilam .mq5 nem validam lucro."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"MQL5/Experts/ALIEN_R42_SHADOW_LAB.mq5"
SET=ROOT/"MQL5/Profiles/Tester/ALIEN_R42_SHADOW_LAB.set"
RUN=ROOT/"tools/RODAR_R42_SHADOW.ps1"

class R42Static(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code=SOURCE.read_text(encoding="utf-8")
        cls.preset=SET.read_text(encoding="utf-8")
        cls.runner=RUN.read_text(encoding="utf-8")

    def test_research_only_explicitly_locked(self):
        s=self.code
        self.assertRegex(s,r"input bool\s+EnableDemoOrders\s*=\s*false;")
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)==0 || EnableDemoOrders",s)
        self.assertIn("ShadowStart(fromRetest,confirmBar,q);",s)
        self.assertIn("ShadowUpdate(); // desfecho tick a tick antes dos novos sinais",s)
        self.assertLess(s.index("ShadowUpdate(); // desfecho tick a tick"),
                        s.index("TryEntryFromClosedM1();",s.index("void OnTick()")))

    def test_causal_labeling_and_cost_disclosure(self):
        s=self.code
        for phrase in (
          "if((long)q.time_msc<=c.tickMsc) continue",
          "liquidation=(c.direction==1?q.bid:q.ask)",
          "result=(reachedStop?\"SL\":(reachedTarget?\"TP\":\"TIMEOUT\"))",
          'ShadowWrite(g_shadow[i],"CENSURADO_FIM_DADOS",TimeCurrent())',
          "estimated_commission",
          "spread_over_stop",
          "ShadowReferenceVolume",
          "OrderCalcProfit(typ,_Symbol,c.lot,c.entry,liquidation,gross)",
          "g_setup.shadowDispSeen=true",
          "g_setup.shadowRetSeen=true",
        ):
            self.assertIn(phrase,s)

    def test_all_defaults_in_preset(self):
        params=dict(re.findall(r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',
                               self.code,re.MULTILINE))
        parsed={}
        for line in self.preset.splitlines():
            if not line or line.startswith(";"):continue
            key,rest=line.split("=",1)
            self.assertNotIn(key,parsed)
            parsed[key]=rest
        self.assertEqual(set(params),set(parsed))
        for key,val in params.items():
            val=val.strip().strip('"')
            self.assertEqual(parsed[key].split("||")[0],val,key)
            if key in ("CSVFileName","ShadowCSVFileName"):
                self.assertNotIn("|",parsed[key])
                self.assertTrue(parsed[key].endswith(".csv"))
        self.assertTrue(parsed["EnableDemoOrders"].startswith("false"))
        self.assertTrue(parsed["EnableShadowLab"].startswith("true"))

    def test_runner_uses_isolated_terminal_and_no_trades(self):
        self.assertIn('Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"',self.runner)
        self.assertIn('PresetPath=$setFile',self.runner)
        self.assertIn('ShadowCSVFileName=',self.runner)
        self.assertIn('Compress-Archive',self.runner)
        self.assertIn('events_sha256=',self.runner)
        self.assertIn('shadow_sha256=',self.runner)
        self.assertNotIn('C:\\Program Files\\RoboForex',self.runner)

if __name__=="__main__":
    unittest.main()
