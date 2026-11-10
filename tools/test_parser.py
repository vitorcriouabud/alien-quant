#!/usr/bin/env python3
"""
Unit and Integration Tests for tools/parse_and_record_results.py
Validates:
1. Benchmark report parsing (EXP_014_GOAT_10K.htm)
2. International number parsing (spaces, dots, commas, negative values)
3. Bilingual label handling (Portuguese and English)
4. Average Risk:Reward calculation & edge cases (zero losses, zero trades)
5. EXPERIMENTOS.csv formatting and idempotent updates
"""

import os
import sys
import unittest
import tempfile
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from parse_and_record_results import (
    clean_number,
    strip_accents,
    read_report_file,
    parse_report_html,
    extract_metrics,
    generate_markdown_summary,
    append_to_experiment_csv,
    resolve_report_path
)


class TestMT5ReportParser(unittest.TestCase):

    def setUp(self):
        self.benchmark_report = TOOLS_DIR.parent / "results" / "EXP_014_GOAT_10K" / "EXP_014_GOAT_10K.htm"
        self.zero_trade_report = TOOLS_DIR.parent / "results" / "ALIEN_V11_2_MESA_10K_OUTUBRO" / "ALIEN_V11_2_MESA_10K_OUTUBRO.htm"

    def test_clean_number_formats(self):
        """Test parsing of different locale number representations."""
        self.assertAlmostEqual(clean_number("748.30"), 748.30)
        self.assertAlmostEqual(clean_number("1 257.98"), 1257.98)
        self.assertAlmostEqual(clean_number("1.257,98"), 1257.98)
        self.assertAlmostEqual(clean_number("748,30"), 748.30)
        self.assertAlmostEqual(clean_number("-509.68"), -509.68)
        self.assertAlmostEqual(clean_number("-7.10"), -7.10)
        self.assertAlmostEqual(clean_number("0.83%"), 0.83)
        self.assertAlmostEqual(clean_number("$10,000.00"), 10000.00)
        self.assertAlmostEqual(clean_number(""), 0.0)
        self.assertAlmostEqual(clean_number(None), 0.0)

    def test_strip_accents(self):
        """Test diacritics removal for robust key comparison."""
        self.assertEqual(strip_accents("Lucro Líquido Total"), "Lucro Liquido Total")
        self.assertEqual(strip_accents("Rebaixamento Máximo do Capital Líquido"), "Rebaixamento Maximo do Capital Liquido")
        self.assertEqual(strip_accents("Total de Negociações"), "Total de Negociacoes")
        self.assertEqual(strip_accents("Média lucro da negociação"), "Media lucro da negociacao")

    def test_benchmark_exp014_metrics(self):
        """Verify extraction against EXP_014_GOAT_10K.htm benchmark."""
        self.assertTrue(self.benchmark_report.is_file(), f"Benchmark file not found: {self.benchmark_report}")
        html_text = read_report_file(str(self.benchmark_report))
        raw_pairs = parse_report_html(html_text)
        metrics = extract_metrics(raw_pairs, self.benchmark_report)

        # Confirm benchmark values
        self.assertAlmostEqual(metrics["net_profit"], 748.30, places=2)
        self.assertAlmostEqual(metrics["profit_factor"], 2.47, places=2)
        self.assertEqual(metrics["total_trades"], 140)
        self.assertEqual(metrics["win_count"], 83)
        self.assertEqual(metrics["loss_count"], 57)
        self.assertAlmostEqual(metrics["win_rate"], 59.29, places=2)
        self.assertAlmostEqual(metrics["max_dd_money"], 90.12, places=2)
        self.assertAlmostEqual(metrics["max_dd_pct"], 0.83, places=2)
        self.assertAlmostEqual(metrics["avg_win"], 15.16, places=2)
        self.assertAlmostEqual(metrics["avg_loss"], -7.10, places=2)

        # Average Risk:Reward = abs(AvgWin / AvgLoss) = abs(15.16 / -7.10) = 2.1352...
        expected_rr = abs(15.16 / -7.10)
        self.assertAlmostEqual(metrics["risk_reward"], expected_rr, places=2)
        self.assertAlmostEqual(metrics["risk_reward"], 2.14, places=2)

        # Meta properties
        self.assertEqual(metrics["symbol"], "XAUUSD")
        self.assertEqual(metrics["timeframe"], "M1")
        self.assertEqual(metrics["period"], "2026.10.05 - 2026.10.17")
        self.assertEqual(metrics["deposit"], 10000.0)

    def test_english_report_parsing(self):
        """Verify parsing when MT5 generates reports with English labels."""
        english_html = """
        <html>
        <table>
        <tr><td nowrap colspan="3">Expert Advisor:</td><td nowrap><b>ALIEN_V12_1_INSTITUTIONAL</b></td></tr>
        <tr><td nowrap colspan="3">Symbol:</td><td nowrap><b>XAUUSD</b></td></tr>
        <tr><td nowrap colspan="3">Period:</td><td nowrap><b>M1 (2026.10.21 - 2026.11.07)</b></td></tr>
        <tr><td nowrap colspan="3">Initial Deposit:</td><td nowrap><b>10 000.00</b></td></tr>
        <tr><td nowrap colspan="3">Leverage:</td><td nowrap><b>1:100</b></td></tr>
        <tr><td nowrap colspan="3">Total Net Profit:</td><td nowrap><b>850.50</b></td></tr>
        <tr><td nowrap colspan="3">Profit Factor:</td><td nowrap><b>2.65</b></td></tr>
        <tr><td nowrap colspan="3">Total Trades:</td><td nowrap><b>110</b></td></tr>
        <tr><td nowrap colspan="3">Profit Trades (% of total):</td><td nowrap><b>70 (63.64%)</b></td></tr>
        <tr><td nowrap colspan="3">Loss Trades (% of total):</td><td nowrap><b>40 (36.36%)</b></td></tr>
        <tr><td nowrap colspan="3">Equity Drawdown Maximal:</td><td nowrap><b>115.40 (1.12%)</b></td></tr>
        <tr><td nowrap colspan="3">Average profit trade:</td><td nowrap><b>18.20</b></td></tr>
        <tr><td nowrap colspan="3">Average loss trade:</td><td nowrap><b>-8.50</b></td></tr>
        </table>
        </html>
        """
        raw_pairs = parse_report_html(english_html)
        metrics = extract_metrics(raw_pairs, Path("dummy_english.htm"))

        self.assertAlmostEqual(metrics["net_profit"], 850.50)
        self.assertAlmostEqual(metrics["profit_factor"], 2.65)
        self.assertEqual(metrics["total_trades"], 110)
        self.assertEqual(metrics["win_count"], 70)
        self.assertAlmostEqual(metrics["win_rate"], 63.64, places=2)
        self.assertAlmostEqual(metrics["max_dd_money"], 115.40)
        self.assertAlmostEqual(metrics["max_dd_pct"], 1.12)
        self.assertAlmostEqual(metrics["avg_win"], 18.20)
        self.assertAlmostEqual(metrics["avg_loss"], -8.50)
        self.assertAlmostEqual(metrics["risk_reward"], abs(18.20 / -8.50), places=2)

    def test_zero_trades_edge_case(self):
        """Test graceful handling when an experiment executes 0 trades."""
        if self.zero_trade_report.is_file():
            html_text = read_report_file(str(self.zero_trade_report))
            raw_pairs = parse_report_html(html_text)
            metrics = extract_metrics(raw_pairs, self.zero_trade_report)

            self.assertEqual(metrics["total_trades"], 0)
            self.assertEqual(metrics["win_rate"], 0.0)
            self.assertEqual(metrics["risk_reward"], 0.0)
            self.assertEqual(metrics["net_profit"], 0.0)

    def test_zero_losses_risk_reward(self):
        """Test R:R calculation when there are zero losing trades."""
        html = """
        <tr><td nowrap>Total Net Profit:</td><td><b>100.00</b></td></tr>
        <tr><td nowrap>Total Trades:</td><td><b>5</b></td></tr>
        <tr><td nowrap>Average profit trade:</td><td><b>20.00</b></td></tr>
        <tr><td nowrap>Average loss trade:</td><td><b>0.00</b></td></tr>
        """
        raw_pairs = parse_report_html(html)
        metrics = extract_metrics(raw_pairs, Path("test.htm"))
        self.assertEqual(metrics["risk_reward"], float("inf"))

    def test_csv_append_and_idempotence(self):
        """Test appending and updating rows in EXPERIMENTOS.csv without creating duplicates."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            test_csv = Path(tmp_dir) / "TEST_EXPERIMENTOS.csv"

            row1 = {
                "ID": "EXP-999",
                "Data": "2026-11-09",
                "Estrategia": "ALIEN Test 1",
                "Timeframe": "M1",
                "Periodo": "2026.10.21 - 2026.11.07",
                "Ativo": "XAUUSD",
                "Modelo_Ticks": "Real Ticks (4)",
                "Banca_USD": 10000,
                "Lucro_USD": 500.00,
                "Fator_Lucro": 2.10,
                "Trades": 80,
                "WinRate_Pct": "60.0%",
                "Max_DD_USD": 85.00,
                "Semanas_Stop12_Violado": "Nao (DD $85.00 < $140)",
                "Conclusao": "Teste inicial",
            }

            # 1. First write creates file and header
            append_to_experiment_csv(test_csv, row1)
            lines = test_csv.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines), 2)
            self.assertTrue(lines[0].startswith("ID;Data;Estrategia"))
            self.assertTrue(lines[1].startswith("EXP-999;"))

            # 2. Second write with same ID updates row in place rather than duplicating
            row1_updated = dict(row1)
            row1_updated["Lucro_USD"] = 550.00
            row1_updated["Conclusao"] = "Teste atualizado"
            append_to_experiment_csv(test_csv, row1_updated)

            lines_after = test_csv.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines_after), 2, "Expected exactly 2 lines (header + 1 updated row)")
            self.assertIn("550.00", lines_after[1])
            self.assertIn("Teste atualizado", lines_after[1])

            # 3. Third write with different ID appends new row
            row2 = dict(row1)
            row2["ID"] = "EXP-1000"
            append_to_experiment_csv(test_csv, row2)
            lines_3 = test_csv.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines_3), 3)

    def test_run_backtest_ps1_defaults_and_integration(self):
        """Verify Run-Backtest.ps1 has required defaults and calls parse_and_record_results.py."""
        ps1_path = TOOLS_DIR / "Run-Backtest.ps1"
        self.assertTrue(ps1_path.is_file(), f"Run-Backtest.ps1 not found at {ps1_path}")
        content = ps1_path.read_text(encoding="utf-8", errors="ignore")

        # Required defaults
        self.assertRegex(content, r'\[string\]\$FromDate\s*=\s*"2026\.10\.21"')
        self.assertRegex(content, r'\[string\]\$ToDate\s*=\s*"2026\.11\.07"')
        self.assertRegex(content, r'\[int\]\$Model\s*=\s*4')
        self.assertRegex(content, r'\[int\]\$Deposit\s*=\s*10000')
        self.assertRegex(content, r'\[int\]\$Leverage\s*=\s*100')

        # Integration with parse_and_record_results.py
        self.assertIn("parse_and_record_results.py", content)
        self.assertIn("EXPERIMENTOS.csv", content)


if __name__ == "__main__":
    unittest.main()
