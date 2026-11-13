"""ALIEN GOAT5K execution tester safety: static invariants, not MQL5 compilation."""
import re
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/"MQL5/Experts/ALIEN_GOAT5K_EXECUTION_TESTER.mq5"
SET=ROOT/"MQL5/Profiles/Tester/ALIEN_GOAT5K_EXECUTION_TESTER.set"
RUN=ROOT/"tools/RODAR_GOAT5K_EXECUTION_TESTER.ps1"

class ExecutionGates(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code=EA.read_text(encoding="utf-8")
        cls.preset=SET.read_text(encoding="utf-8")
        cls.runner=RUN.read_text(encoding="utf-8")

    def test_all_defaults_preserved(self):
        params=dict(re.findall(
            r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',
            self.code,re.M))
        got={}
        for row in self.preset.splitlines():
            if not row or row.startswith(";"):continue
            key,value=row.split("=",1)
            self.assertNotIn(key,got)
            got[key]=value.split("||")[0]
        self.assertEqual(set(params),set(got))
        for key,value in params.items():
            self.assertEqual(got[key],value.strip().strip('"'),key)
        self.assertNotIn("|",next(row for row in self.preset.splitlines() if row.startswith("CSVFileName=")))

    def test_orders_test_only_and_no_live_fail_open(self):
        s=self.code
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)==0 || !EnableTesterOrders ||",s)
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)==0) return;",s)
        self.assertIn("StringFind(symbol,\"XAU\")<0 || _Period!=PERIOD_M1",s)
        self.assertIn("MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-5000.0)>0.01",s)
        self.assertIn("RiskLimitPct>0.25",s)
        self.assertIn("RiskMaxUsd>12.50",s)
        self.assertIn("FloatingSafetyUsd>40.0",s)
        self.assertIn("DailyLossGuardPct>1.0",s)
        self.assertIn("TotalLossGuardPct>8.0",s)
        self.assertIn("MaxLot>0.02",s)
        self.assertIn("MaxDayTrades>6",s)
        self.assertIn("MaxStopPoints>180",s)
        self.assertIn("SpreadLimitPoints>45",s)
        self.assertIn("RewardRisk>2.0",s)
        self.assertIn("PositionsTotal()>0",s)

    def test_broker_execution_and_deal_reporting(self):
        s=self.code
        for required in (
            'trade.Buy(vol,_Symbol,0.0,sl,tp,"ALIEN_TESTER")',
            'trade.Sell(vol,_Symbol,0.0,sl,tp,"ALIEN_TESTER")',
            "trade.ResultDeal()>0",
            "TRADE_TRANSACTION_DEAL_ADD",
            "DEAL_PROFIT",
            "DEAL_COMMISSION",
            "DEAL_SWAP",
            "DEAL_FEE",
            'LogRow("ORDER_FILLED"',
            'LogRow("ORDER_REJECTED"',
            "ORDER_ATTEMPT",
            "DEAL_IN",
            "DEAL_OUT",
        ):
            self.assertIn(required,s)

    def test_risk_budget_and_broker_constraints(self):
        s=self.code
        for required in (
            "OrderCalcProfit(kind,_Symbol,1.0,inWorst,outWorst,oneLotPnL)",
            "OrderCalcMargin(kind,_Symbol,vol,entry,margin)",
            "AssumedCommissionPerLot",
            "SlipReservePoints",
            "NegativeFloating()",
            "FloatingSafetyUsd-NegativeFloating()-5.0",
            "g_dayReference*(1.0-DailyLossGuardPct/100.0)",
            "InitialDepositUsd*(1.0-TotalLossGuardPct/100.0)",
            "CloseOwn(\"TESTER risk lock\")",
            "CopyRates(_Symbol,PERIOD_M1,1,StopLookbackBars,b)",
        ):
            self.assertIn(required,s)

    def test_runner_isolated_terminal_and_report(self):
        s=self.runner
        for required in (
            "[int]$Deposit=5000",
            'if($Deposit -ne 5000)',
            "ALIEN_TEST_MT5",
            'Where-Object {$_.ExecutablePath -and $_.ExecutablePath -ieq $testExe}',
            "ALIEN_GOAT5K_EXECUTION_TESTER.mq5",
            "ALIEN_GOAT5K_EXECUTION_TESTER.set",
            "EnableTesterOrders=true",
            "Model=4",
            "Import-Csv",
            "ORDER_FILLED",
            "DEAL_OUT",
            "Compress-Archive",
            "event_log_sha256",
        ):
            self.assertIn(required,s)

    def test_no_incorrect_profit_claim(self):
        s=self.runner
        self.assertIn("NOT LIVE GOAT fills",s)
        self.assertIn("benchmark",s.lower())

if __name__=="__main__":
    unittest.main()
