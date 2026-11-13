#!/usr/bin/env python3
"""Prova estatica de invariantes. NAO substitui MetaEditor/testador."""
from pathlib import Path
import unittest
import re
SRC = Path(__file__).resolve().parents[1] / "MQL5/Experts/ALIEN_GENESIS_MTF_R4_DEMO.mq5"

def args_at(text, anchor):
    ix=text.index("FileWrite(g_csv",anchor)
    left=text.index("(",ix)
    depth=0; quote=False; escaped=False; begin=left+1; out=[]
    for i in range(left,len(text)):
        ch=text[i]
        if quote:
            if ch=='"' and not escaped: quote=False
            if ch=="\\" and not escaped: escaped=True
            else: escaped=False
            continue
        if ch=='"': quote=True;continue
        if ch=="(":depth+=1
        elif ch==")":
            depth-=1
            if depth==0:
                out.append(text[begin:i].strip())
                return out
        elif ch=="," and depth==1:
            out.append(text[begin:i].strip()); begin=i+1
    raise AssertionError("FileWrite sem fechamento")

class CheckR4(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=SRC.read_text(encoding="utf-8")
    def test_modules_active(self):
        for name in ("EnableDemoOrders","UseH1Context","RequireH1Alignment",
            "UseM15FVG","UseM15OrderBlock","UseM5LiquiditySweep",
            "UseM1Displacement","UseBollinger","UseATRFilter",
            "UseLiquidityRoomFilter","UseSessionFilter","EnableBreakEven",
            "EnableATRTrailing","EnableDailyGuard","EnableWeekendGuard",
            "EnablePanel","EnableCSV"):
            self.assertRegex(self.source,rf"input bool\s+{name}\s*=\s*true;")
    def test_demo_only_guard(self):
        self.assertIn("AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO",self.source)
        self.assertIn("if(!IsDemoOrTester())",self.source)
        self.assertIn("if(!EntryAllowed(dir))",self.source)
    def test_risk_constraints(self):
        for t in ("OrderCalcProfit(","OrderCalcMargin(","TRADE_RETCODE_DONE",
                  "trade.ResultDeal()>0","SYMBOL_TRADE_STOPS_LEVEL",
                  "MaximumStopPoints","RewardRiskMultiple*stopPoints",
                  "if(rounded+1e-9<minLot) return false"):
            self.assertIn(t,self.source)
    def test_temporal_alignment(self):
        for t in ("CopyRates(_Symbol,tf,1,count,bars)",
                  "b[j].time+PeriodSeconds(PERIOD_M15)>sweepOpen",
                  "bars[j].time+PeriodSeconds(PERIOD_H1)>sweepOpen",
                  "if(b[0].time<g_setup.armTime) return"):
            self.assertIn(t,self.source)
    def test_csv_schema(self):
        a=args_at(self.source,self.source.index("void LogEvent"))
        b=args_at(self.source,self.source.index("if(FileSize(g_csv)==0)"))
        self.assertEqual(len(a),len(b))
        self.assertEqual(len(a),23) # handle + 22 colunas
    def test_risk_defaults(self):
        self.assertRegex(self.source,r"RiskPercentEquity\s*=\s*0\.25;")
        self.assertRegex(self.source,r"RewardRiskMultiple\s*=\s*4\.0;")
        self.assertRegex(self.source,r"MaximumStopPoints\s*=\s*180\.0;")

if __name__=="__main__":
    unittest.main()
