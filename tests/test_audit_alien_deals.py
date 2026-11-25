import importlib.util
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "audit_alien_deals.py"
SPEC = importlib.util.spec_from_file_location("audit_alien_deals", MODULE_PATH)
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
SPEC.loader.exec_module(audit)


class AuditAlienDealsTests(unittest.TestCase):
    def setUp(self):
        self.trades = audit.parse_csv_bytes(
            b"position_id;liquido_conta\n1001;1.42\n1002;-0.50\n",
            "trades.csv",
        )
        self.deals = audit.parse_csv_bytes(
            (
                "deal_ticket;position_id;symbol;magic;entry;profit;commission;swap;fee\n"
                "1;1001;XAUUSD;802092;DEAL_ENTRY_IN;0;-0.04;0;0\n"
                "2;1001;XAUUSD;0;DEAL_ENTRY_OUT;1.50;-0.04;0;0\n"
                "3;1002;XAUUSD;802092;DEAL_ENTRY_IN;0;-0.04;0;0\n"
                "4;1002;XAUUSD;802092;DEAL_ENTRY_OUT;-0.46;0;0;0\n"
                "5;1003;XAUUSD;802092;DEAL_ENTRY_IN;0;-0.04;0;0\n"
            ).encode("utf-8"),
            "deals.csv",
        )

    def test_locale_number_formats(self):
        self.assertAlmostEqual(audit.number("1.234,56"), 1234.56)
        self.assertAlmostEqual(audit.number("1,234.56"), 1234.56)
        self.assertAlmostEqual(audit.number("-0,04"), -0.04)

    def test_external_magic_close_is_included_by_position_id(self):
        result = audit.reconcile(self.trades, self.deals, None, "XAUUSD", 802092, 0.01)
        self.assertEqual(result["missing"], [])
        self.assertEqual(result["mismatches"], [])
        self.assertEqual(result["external_close_positions"], 1)
        self.assertEqual(result["orphan_target_ids"], ["1003"])
        self.assertEqual(len(result["matched"]), 2)

    def test_conflicting_duplicate_position_is_flagged(self):
        duplicated = audit.parse_csv_bytes(
            b"position_id;liquido_conta;nota\n1001;1.42;A\n1001;1.42;B\n",
            "duplicate.csv",
        )
        result = audit.reconcile(duplicated, self.deals, None, "XAUUSD", 802092, 0.01)
        self.assertEqual(result["conflicting_ids"], ["1001"])

    def test_zip_auto_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "bundle.zip"
            with zipfile.ZipFile(bundle, "w") as zf:
                zf.writestr("trades.csv", "position_id;liquido_conta\n1001;1.42\n")
                zf.writestr(
                    "deals.csv",
                    "position_id;symbol;magic;entry;profit;commission\n"
                    "1001;XAUUSD;802092;DEAL_ENTRY_IN;0;-0.04\n"
                    "1001;XAUUSD;0;DEAL_ENTRY_OUT;1.50;-0.04\n",
                )
                zf.writestr("events.csv", "event;details\nDEAL_EXIT;close\n")
            docs = audit.read_zip_members(bundle)
            trades = audit.choose_doc(docs, "trades")
            deals = audit.choose_doc(docs, "deals")
            events = audit.choose_doc(docs, "events")
            self.assertIsNotNone(trades)
            self.assertIsNotNone(deals)
            self.assertIsNotNone(events)
            result = audit.reconcile(trades, deals, events, "XAUUSD", 802092, 0.01)
            self.assertEqual(len(result["matched"]), 1)
            self.assertEqual(result["event_counts"]["DEAL_EXIT"], 1)


if __name__ == "__main__":
    unittest.main()
