"""GOAT5K virtual portfolio simulator: realistic synthetic failure scenarios."""
import io
import json
import sys
import tempfile
import unittest
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from goat_virtual_portfolio import (
    D, Settings, TwinSimulation, VirtualPortfolio, audit_shadow_zip, ts
)

T0 = "2026-11-13T17:00:00-05:00"


def at(time):
    return f"2026-11-13T{time}-05:00"


def quote(bid="4000.00", ask="4000.10", when=None):
    return {"type": "quote", "ts": when or T0, "symbol": "XAUUSD",
            "bid": bid, "ask": ask}


def reset(when=T0, assumed=True):
    return {"type": "reset", "ts": when, "assumed": assumed}


def signal(id, model="STOP_M5", side="BUY", stop="3990.00",
           approved=True, when=T0, volume="0.01"):
    return {
        "type": "signal", "ts": when, "model": model, "id": str(id),
        "symbol": "XAUUSD", "side": side, "stop": stop,
        "volume": volume, "contract_size": "100", "approved": approved,
    }


class GoatVirtualLedgerTests(unittest.TestCase):
    def prepared(self):
        x=TwinSimulation()
        x.feed(quote())
        x.feed(reset())
        return x

    def test_three_simultaneous_worst_stops_allow_fourth_rejected(self):
        x=self.prepared()
        for i in range(4):
            x.feed(signal(f"s{i}"))
        a=x.portfolios["STOP_M5"]
        self.assertEqual(a.opened, 3)
        self.assertEqual(a.max_positions, 3)
        self.assertLess(a.worst_combined(), D("40"))
        self.assertTrue(any(
            e["event"] == "reject_risk_combined_worst_stop_exposure"
            for e in a.audit
        ))
        self.assertEqual(x.portfolios["STOP_M1_LOCAL"].opened, 0)

    def test_large_gap_breaches_before_virtual_stop_execution(self):
        x=self.prepared()
        for i in range(3):
            x.feed(signal(f"g{i}"))
        x.feed(quote("3940.00","3940.10",at("17:01:00")))
        a=x.portfolios["STOP_M5"]
        self.assertIn("floating",a.hard_breaches)
        self.assertTrue(a.permanently_locked)
        self.assertEqual(a.closed,3)
        self.assertGreater(a.peak_negative_floating,D("50"))
        self.assertLess(a.balance,D("4900"))
        self.assertTrue(any(e["event"]=="hard_floating_breach" for e in a.audit))

    def test_profit_winner_cannot_offset_loser_in_floating_rule(self):
        x=self.prepared()
        x.feed(signal("long",side="BUY",stop="3990"))
        x.feed(signal("short",side="SELL",stop="4010"))
        x.feed(quote("3995.00","3995.10",at("17:01:00")))
        a=x.portfolios["STOP_M5"]
        self.assertEqual(a.opened,2)
        self.assertGreater(a.negative_floating(),D("0"))
        self.assertLess(a.negative_floating(),D("10"))
        self.assertAlmostEqual(float(a.equity()),4999.7,delta=1)

    def test_candidate_not_approved_is_never_opened(self):
        x=self.prepared()
        x.feed(signal("notApproved",approved=False))
        a=x.portfolios["STOP_M5"]
        self.assertEqual(a.opened,0)
        self.assertIn("reject_strategy",[e["event"] for e in a.audit])

    def test_missing_reset_must_reject_not_invent_daily_reference(self):
        x=TwinSimulation()
        x.feed(quote())
        x.feed(signal("s1"))
        a=x.portfolios["STOP_M5"]
        self.assertEqual(a.opened,0)
        self.assertIsNone(a.daily_reference)
        self.assertEqual(a.audit[-1]["event"],"reject_no_daily_reference")

    def test_wrong_reset_hour_rejected(self):
        x=TwinSimulation()
        x.feed(quote())
        with self.assertRaises(ValueError):
            x.feed(reset("2026-11-13T16:00:00-05:00"))

    def test_reset_reference_higher_of_balance_equity(self):
        x=TwinSimulation()
        x.feed(quote())
        x.feed(reset())
        x.feed(signal("a"))
        x.feed(quote("3998.00","3998.10",at("17:10:00")))
        # Next calendar day after 5pm NY, open position losing:
        x.feed(quote("3998.00","3998.10","2026-11-14T17:00:00-05:00"))
        x.feed(reset("2026-11-14T17:00:00-05:00",assumed=True))
        a=x.portfolios["STOP_M5"]
        self.assertEqual(a.daily_reference,a.balance)
        self.assertLess(a.equity(),a.balance)
        self.assertEqual(a.resets,2)
        self.assertEqual(a.assumed_resets,2)

    def test_independent_stop_models(self):
        x=self.prepared()
        x.feed(signal("one",model="STOP_M5"))
        x.feed(signal("one",model="STOP_M1_LOCAL",stop="3995"))
        a=x.portfolios["STOP_M5"]
        b=x.portfolios["STOP_M1_LOCAL"]
        self.assertEqual(a.opened,1)
        self.assertEqual(b.opened,1)
        self.assertNotEqual(a.positions["one"].initial_risk_usd,
                            b.positions["one"].initial_risk_usd)
        self.assertEqual(len(a.positions),len(b.positions))
        self.assertTrue(x.report()["portfolio_ledgers_are_independent"])

    def test_per_trade_limit_with_reserved_slippage_commission(self):
        x=self.prepared()
        x.feed(signal("tooMuch",stop="3980"))
        self.assertEqual(x.portfolios["STOP_M5"].opened,0)
        self.assertTrue(any(
            e["event"] == "reject_risk_risk_per_trade"
            for e in x.portfolios["STOP_M5"].audit
        ))
        self.assertEqual(x.portfolios["STOP_M5"].settings.trade_cap,D("12.5"))

    def test_quote_gap_telemetry_and_stale_quote_rejection(self):
        x=self.prepared()
        x.feed(signal("a"))
        x.feed(quote("3999","3999.1",at("17:10:00")))
        a=x.portfolios["STOP_M5"]
        self.assertGreaterEqual(a.max_quote_gap,600)
        self.assertTrue(any(e["event"] == "quote_gap" for e in a.audit))
        x.feed(signal("late",when=at("17:15:00")))
        self.assertEqual(a.audit[-1]["event"],"reject_stale_quote")

    def test_no_unspecified_tz(self):
        with self.assertRaises(ValueError):
            ts("2026-11-13T17:00:00")

    def test_invalid_stop_side(self):
        x=self.prepared()
        x.feed(signal("wrong",stop="4010"))
        self.assertEqual(x.portfolios["STOP_M5"].audit[-1]["event"],
                         "reject_stop_side")

    def test_audit_zip_cannot_pretend_to_have_tick_ledger(self):
        columns=["state","stop_model","all_filters_ok","goat_all_gates_ok"]
        rows=[
          ["OPEN","STOP_M5","0","0"],
          ["OPEN","STOP_M1_LOCAL","0","0"],
          ["SEM_PIVO_LOCAL","STOP_M1_LOCAL","0","0"],
          ["TP","STOP_M5","0","0"],
        ]
        with tempfile.TemporaryDirectory() as td:
            path=Path(td)/"fake.zip"
            out=io.StringIO()
            writer=__import__("csv").writer(out,delimiter=";")
            writer.writerow(columns); writer.writerows(rows)
            with ZipFile(path,"w") as z:
                z.writestr("TEST_OUTCOMES.csv",out.getvalue())
            audit=audit_shadow_zip(path)
        self.assertEqual(audit["open_shadow_rows"],2)
        self.assertEqual(audit["no_pivot_rows"],1)
        self.assertFalse(audit["independent_portfolio_simulation_executed"])
        self.assertFalse(audit["models"][0]["portfolio_time_series_computable_from_this_csv"])

    def test_no_live_trade_library_calls(self):
        src=(Path(__file__).resolve().parents[1]/"tools/goat_virtual_portfolio.py").read_text(encoding="utf-8")
        for forbidden in ["import MetaTrader5", "OrderSend(", "trade.Buy(", "trade.Sell("]:
            self.assertNotIn(forbidden,src)


if __name__ == "__main__":
    unittest.main()
