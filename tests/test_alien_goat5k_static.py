"""GOAT5K research harness: static invariants only, not MetaEditor compilation."""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/"MQL5/Experts/ALIEN_GOAT5K_RISK_SHADOW.mq5"
SET=ROOT/"MQL5/Profiles/Tester/ALIEN_GOAT5K_RISK_SHADOW.set"
RUNNER=ROOT/"tools/RODAR_GOAT5K_RISK_LAB.ps1"
SAMPLER=ROOT/"MQL5/Experts/GOAT_XAUUSD_SPREAD_READONLY.mq5"

class TestGoat5K(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ea=EA.read_text(encoding="utf-8")
        cls.preset=SET.read_text(encoding="utf-8")
        cls.runner=RUNNER.read_text(encoding="utf-8")
        cls.sampler=SAMPLER.read_text(encoding="utf-8")

    def test_input_defaults_match_preset_exactly(self):
        params=dict(re.findall(
            r'^\s*input\s+(?:bool|int|double|ulong|string)\s+(\w+)\s*=\s*([^;]+);',
            self.ea,re.MULTILINE))
        parsed={}
        for line in self.preset.splitlines():
            if not line or line.startswith(";"):continue
            key,value=line.split("=",1)
            self.assertNotIn(key,parsed,key)
            parsed[key]=value.split("||")[0]
        self.assertEqual(set(params),set(parsed))
        for k,v in params.items():
            self.assertEqual(parsed[k],v.strip().strip('"'),k)
        for k in ("CSVFileName","ShadowCSVFileName"):
            item=[x for x in self.preset.splitlines() if x.startswith(k+"=")][0]
            self.assertNotIn("|",item)

    def test_safe_model_defaults(self):
        s=self.preset
        for item in (
            "EnableDemoOrders=false",
            "GoatLiveTradingAuthorization=false",
            "GoatInitialCapitalUsd=5000.0",
            "GoatFloatingLimitPct=1.0",
            "GoatDailyDrawdownPct=4.0",
            "GoatStaticLossPct=10.0",
            "GoatFloatingSafetyBufferUsd=10.0",
            "RiskPercentEquity=0.25",
            "EstimatedRoundTurnPerLot=5.00",
            "UseEarlyMicroBreak=false",
            "EnableLocalStopPairing=true",
        ):
            self.assertIn(item,s)

    def test_no_live_or_demo_orders_even_if_inputs_modified(self):
        s=self.ea
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)==0 || EnableDemoOrders ||",s)
        self.assertIn("GoatLiveTradingAuthorization || !GoatAssumedFloatingVariant",s)
        self.assertIn("MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-GoatInitialCapitalUsd)>0.01",s)
        self.assertIn("MathAbs(GoatInitialCapitalUsd-5000.0)>0.01",s)
        self.assertIn("MathAbs(RiskPercentEquity-0.25)>0.000001",s)
        self.assertIn("if(!EnableDemoOrders) { LogEvent",s)

    def test_guard_calculation_conservative_and_account_wide(self):
        s=self.ea
        for text in (
            "GoatCombinedNegativeFloatingUsd()",
            "PositionGetTicket(i)",
            "PositionSelectByTicket(ticket)",
            "PositionGetDouble(POSITION_PROFIT)",
            "PositionGetDouble(POSITION_SWAP)",
            "c.goatExistingFloatingLossUsd+c.goatWorstLossUsd",
            "floatHard-GoatFloatingSafetyBufferUsd",
            "effectiveEquity-c.goatWorstLossUsd",
            "GoatDailyFloorAssumed()+GoatDailySafetyBufferUsd",
            "GoatStaticFloor()+GoatStaticSafetyBufferUsd",
            "EstimatedRoundTurnPerLot*c.lot",
            "GoatEvaluateRisk(c);",
            "GoatDailyResetReferenceUsd",
        ):
            self.assertIn(text,s)

    def test_candidate_risk_independent(self):
        s=self.ea
        self.assertIn('c.stopModel="STOP_M5"',s)
        self.assertIn('c.stopModel="STOP_M1_LOCAL"',s)
        self.assertIn("c.goatWorstLossUsd=0.0;",s)
        self.assertIn('ShadowWrite(c,"SEM_PIVO_LOCAL"',s)
        self.assertIn('"goat_all_gates_ok"',s)
        self.assertIn('"goat_floating_hard_usd"',s)
        self.assertIn('"goat_daily_floor_assumed_usd"',s)

    def test_runner_fixed_account_and_isolation(self):
        s=self.runner
        for text in (
            "[int]$Deposit=5000",
            'if($Deposit -ne 5000)',
            "ALIEN_TEST_MT5",
            "ALIEN_GOAT5K_RISK_SHADOW.mq5",
            "ALIEN_GOAT5K_RISK_SHADOW.set",
            "goat_hard_floating_usd=50",
            "goat_guard_floating_usd=40",
            "goat_static_floor_usd=4500",
            "goat_fee_assumption_per_lot",
            "goat_eligible_shadow_candidates",
            "Compress-Archive",
        ):
            self.assertIn(text,s)

    def test_goat_quote_collector_does_not_trade(self):
        s=self.sampler
        for text in (
            "ACCOUNT_TRADE_ALLOWED)==0",
            "AccountInfoString(ACCOUNT_SERVER)",
            'SymbolInfoTick(_Symbol,q)',
            "SYMBOL_TRADE_CONTRACT_SIZE",
            "SYMBOL_TRADE_TICK_VALUE",
            "spread_points",
            "EventSetTimer(1)",
        ):
            self.assertIn(text,s)
        for forbidden in ("OrderSend(", "trade.Buy(", "trade.Sell(", "#include <Trade/Trade.mqh>"):
            self.assertNotIn(forbidden,s)

if __name__=="__main__":
    unittest.main()
