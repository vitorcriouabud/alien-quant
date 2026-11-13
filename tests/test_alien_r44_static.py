"""R4.4 stop-pair shadow, static invariants; not MQL5 compilation."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/"MQL5/Experts/ALIEN_R44_LOCAL_STOP_SHADOW.mq5"
P=ROOT/"MQL5/Profiles/Tester/ALIEN_R44_SHADOW_PAIR.set"
RUN=ROOT/"tools/RODAR_R44_PAIR.ps1"

class R44Guards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ea=EA.read_text(encoding="utf-8")
        cls.ps=P.read_text(encoding="utf-8")
        cls.run=RUN.read_text(encoding="utf-8")

    def test_default_inputs_frozen(self):
        params=re.findall(r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',self.ea,re.M)
        src={k:v.strip().strip('"') for k,v in params}
        preset={}
        for line in self.ps.splitlines():
            if not line or line.startswith(";"):continue
            k,val=line.split("=",1)
            self.assertNotIn(k,preset)
            preset[k]=val.split("||")[0]
        self.assertEqual(set(src),set(preset))
        for k,v in src.items():
            self.assertEqual(preset[k],v,k)
        self.assertEqual(preset["EnableDemoOrders"],"false")
        self.assertEqual(preset["EnableLocalStopPairing"],"true")
        self.assertEqual(preset["UseEarlyMicroBreak"],"false")
        for k in ("CSVFileName","ShadowCSVFileName"):
            line=[x for x in self.ps.splitlines() if x.startswith(k+"=")][0]
            self.assertNotIn("|",line)

    def test_same_entry_same_tick(self):
        s=self.ea
        p=s.index("void ShadowStart(")
        q=s.index("void ShadowUpdate(",p)
        code=s[p:q]
        self.assertIn("c.entry=(c.direction==1?q.ask:q.bid)",code)
        self.assertIn('c.stopModel="STOP_M5"',code)
        self.assertIn('c.stopModel="STOP_M1_LOCAL"',code)
        self.assertIn("RecordShadowVariant(c);",code)
        self.assertEqual(code.count("RecordShadowVariant(c);"),2)
        self.assertIn('ShadowWrite(c,"SEM_PIVO_LOCAL",c.startedAt)',code)
        self.assertNotIn("c.startedAt=",code[code.index('c.stopModel="STOP_M1_LOCAL"'):])
        self.assertNotIn("c.entry=",code[code.index('c.stopModel="STOP_M1_LOCAL"'):])

    def test_causal_confirmed_pivot(self):
        s=self.ea
        p=s.index("bool ConfirmedLocalPivot(")
        q=s.index("void ShadowStart(",p)
        pivot=s[p:q]
        for token in (
          "ClosedBars(PERIOD_M1,required,bars)",
          "if(bars[0].time!=signalBar.time) return false;",
          "for(int j=1;j<=LocalPivotLookbackBars;j++)",
          "if(bars[j].time<g_setup.armTime) break;",
          "bars[j].low<bars[j-1].low",
          "bars[j].low<bars[j+1].low",
          "bars[j].high>bars[j-1].high",
          "bars[j].high>bars[j+1].high",
          "c.stopPts>=MinimumStopPoints && c.stopPts<=MaximumStopPoints",
          "c.spreadPts<=MaximumSpreadPoints",
          "RewardRiskMultiple*c.stopPts*_Point",
        ):
            self.assertIn(token,pivot)

    def test_no_real_trades_and_no_micro_break(self):
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)==0 || EnableDemoOrders || !EnableShadowLab ||",self.ea)
        self.assertIn("!EnableLocalStopPairing || UseEarlyMicroBreak",self.ea)
        self.assertIn('if(!EnableDemoOrders) { LogEvent("SINAL_SEM_ORDEM"',self.ea)
        self.assertIn('if((datetime)q.time < signalBar.time+PeriodSeconds(PERIOD_M1)) return;',self.ea)

    def test_shadow_csv_schema_and_zip(self):
        for token in ("stop_model","pivot_at","pivot_price","setup_arm_at","all_filters_ok"):
            self.assertIn('"'+token+'"',self.ea)
        for token in (
          'ALIEN_R44_LOCAL_STOP_SHADOW.mq5',
          'ALIEN_R44_SHADOW_PAIR.set',
          '"ALIEN_TEST_MT5"',
          "shadow_local_no_pivot",
          "shadow_m5_open",
          "events_sha256=",
          "shadow_sha256=",
          "Compress-Archive",
          "CSVFileName=",
          "ShadowCSVFileName=",
        ):
            self.assertIn(token,self.run)

if __name__=="__main__":
    unittest.main()
