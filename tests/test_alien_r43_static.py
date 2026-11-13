"""ALIEN R4.3: invariantes estáticas; NÃO substituem MetaEditor ou MT5."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/"MQL5/Experts/ALIEN_R43_EARLY_M1_SHADOW.mq5"
A=ROOT/"MQL5/Profiles/Tester/ALIEN_R43_A_DESLOCAMENTO.set"
B=ROOT/"MQL5/Profiles/Tester/ALIEN_R43_B_MICROBREAK.set"
RUN=ROOT/"tools/RODAR_R43_AB.ps1"

def parse(path):
    o={}
    for x in path.read_text(encoding="utf-8-sig").splitlines():
        if x.startswith(";") or not x.strip():continue
        k,v=x.split("=",1)
        if k in o:raise ValueError("duplicated input "+k)
        o[k]=v.split("||")[0]
    return o

class R43Checks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=EA.read_text(encoding="utf-8")
        cls.runner=RUN.read_text(encoding="utf-8")
        cls.a=parse(A);cls.b=parse(B)

    def test_single_hypothesis_change(self):
        self.assertEqual(set(self.a),set(self.b))
        diffs={k for k in self.a if self.a[k]!=self.b[k]}
        self.assertEqual(diffs,{"UseEarlyMicroBreak","CSVFileName","ShadowCSVFileName"})
        self.assertEqual(self.a["UseEarlyMicroBreak"],"false")
        self.assertEqual(self.b["UseEarlyMicroBreak"],"true")

    def test_all_source_inputs_in_preset(self):
        src=dict(re.findall(r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',self.s,re.MULTILINE))
        self.assertEqual(set(src),set(self.b))
        self.assertEqual(self.b["EnableDemoOrders"],"false")
        self.assertEqual(self.b["EnableShadowLab"],"true")
        for k,v in src.items():
            if k in ("CSVFileName","ShadowCSVFileName","UseEarlyMicroBreak"):
                continue
            self.assertEqual(self.b[k],v.strip().strip('"'),k)

    def test_protect_csv_strings(self):
        for file in (A,B):
            for row in file.read_text(encoding="utf-8").splitlines():
                if row.startswith(("CSVFileName=","ShadowCSVFileName=")):
                    self.assertNotIn("|",row)
                    self.assertTrue(row.endswith(".csv"))
        self.assertIn("if($_ -match \"^CSVFileName=\")",self.runner)

    def test_shadow_only_and_closed_bar(self):
        for t in (
          "if(MQLInfoInteger(MQL_TESTER)==0 || EnableDemoOrders",
          "CopyRates(_Symbol,tf,1,count,bars)",
          "if((datetime)q.time < signalBar.time+PeriodSeconds(PERIOD_M1)) return",
          "MicroBreakLookbackBars+1",
          "micro[1].high",
          "micro[1].low",
          'c.phase=(fromRetest?',
          'UseEarlyMicroBreak?"MICRO_DIRETO":"DESLOCAMENTO"',
          'UseEarlyMicroBreak?"MICRO_RETESTE":"RETESTE"',
        ):
            self.assertIn(t,self.s)

    def test_timeout_not_future_tick_and_session_logged(self):
        for t in (
          "exitPrice=c.lastQuote",
          '"GAP_TIMEOUT":"TIMEOUT"',
          'double liquidation=(c.direction==1?q.bid:q.ask);',
          'c.lastQuoteAt=(datetime)q.time;',
          "session_ok",
        ):
            self.assertIn(t,self.s)

    def test_single_executable_two_runs(self):
        for term in (
          'SkipCompile=($mode.micro -eq "true")',
          '$firstExe -ne $he',
          'ALIEN_R43_AB_',
          'ShadowCSVFileName=',
          'events_sha256=',
          'shadow_sha256=',
        ):
            self.assertIn(term,self.runner)

if __name__=="__main__":
    unittest.main()
