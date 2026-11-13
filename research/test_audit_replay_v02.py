# -*- coding: utf-8 -*-
"""Testes sinteticos do auditor. Nao usam dados de trading nem MT5."""
import tempfile
import unittest
from pathlib import Path

from research.audit_replay_v02 import audit, parse_number


class ReplayAuditTests(unittest.TestCase):
    def check_csv(self, content, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / "trades.csv"
            file.write_text(content, encoding="utf-8")
            return audit(file, **kwargs)

    def test_pf_mean_and_drawdown(self):
        result = self.check_csv(
            "trade_id,entry_time,r_net\n"
            "a,2026-11-01 10:00:00,1\n"
            "b,2026-11-02 10:00:00,-2\n"
            "c,2026-11-03 10:00:00,0.5\n"
        )
        self.assertEqual(result["n_operacoes"], 3)
        self.assertEqual(result["soma_r"], -0.5)
        self.assertAlmostEqual(result["media_r"], -1 / 6, places=5)
        self.assertEqual(result["profit_factor_r"], 0.75)
        self.assertEqual(result["max_drawdown_r"], 2)
        self.assertEqual(result["status"], "TRIAGEM_HISTORICA_NAO_PROMOVER")

    def test_semicolon_and_decimal_comma(self):
        result = self.check_csv(
            "id;entry_time;r_liquido\n"
            "a;2026-11-01 10:00:00;1,25\n"
            "b;2026-11-02 10:00:00;-0,75\n"
        )
        self.assertEqual(result["soma_r"], 0.5)
        self.assertAlmostEqual(result["profit_factor_r"], 1.666667, places=5)

    def test_duplicate_trade_id_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "duplicado"):
            self.check_csv("id,r_net\na,1\na,-1\n")

    def test_missing_r_column_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "R LIQUIDO"):
            self.check_csv("id,pnl_dollars\na,1\n")

    def test_explicit_column_name(self):
        result = self.check_csv("id,Meu R\na,1.5\n", r_col="Meu R")
        self.assertEqual(result["soma_r"], 1.5)

    def test_reverse_chronology_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "cronologica"):
            self.check_csv(
                "id,entry_time,r_net\n"
                "a,2026-11-03 12:00:00,1\n"
                "b,2026-11-02 12:00:00,-1\n"
            )

    def test_nonfinite_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "nao finito"):
            self.check_csv("id,r_net\na,nan\n")

    def test_no_timestamp_flags_uncertainty(self):
        result = self.check_csv("id,r_net\na,1\nb,-2\n")
        self.assertIsNone(result["n_dias"])
        self.assertIsNone(result["ic95_media_r_bootstrap_dias"])
        self.assertTrue(any("Sem coluna temporal" in w for w in result["avisos"]))

    def test_bootstrap_is_deterministic_and_not_a_holdout(self):
        header = "id,entry_time,r_net\n"
        rows = "".join(
            "t%d,2026-10-%02d 10:00:00,%s\n" % (i, i, "1" if i % 2 else "-2")
            for i in range(1, 13)
        )
        a = self.check_csv(header + rows)
        b = self.check_csv(header + rows)
        self.assertEqual(a["ic95_media_r_bootstrap_dias"], b["ic95_media_r_bootstrap_dias"])
        self.assertEqual(a["n_dias"], 12)
        self.assertIn("NAO_PROMOVER", a["status"])

    def test_published_number_mismatch_is_reported(self):
        result = self.check_csv(
            "id,r_net\na,-1\nb,-1\n",
            expected={"n": 93, "mean": -0.364, "pf": 0.537},
        )
        self.assertFalse(result["checagem_relatorio"]["consistente_com_arredondamento"])
        self.assertEqual(len(result["checagem_relatorio"]["divergencias"]), 3)

    def test_concentration_without_best_three(self):
        result = self.check_csv("id,r_net\na,10\nb,-3\nc,-3\nd,-3\ne,-3\n")
        self.assertEqual(result["soma_r"], -2)
        self.assertEqual(result["soma_sem_3_maiores_r"], -12)

    def test_numeric_parser_rejects_ambiguous_locale(self):
        with self.assertRaisesRegex(ValueError, "ambiguos"):
            parse_number("1.234,56", 3)


if __name__ == "__main__":
    unittest.main()
