"""Regressões do watchdog e da publicação de falhas do executor ALIEN."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

import alien_data_catalog as catalog
import alien_quant_executor as executor

TASK = {
    "from": "2026.10.19",
    "to": "2026.10.21",
    "mode": "local",
    "symbol": "XAUUSD",
    "model": 4,
}


class DataSourceTests(unittest.TestCase):
    def test_source_selection_does_not_fall_back_to_another_broker(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.assertEqual(executor.source_path(root, {}, "roboforex-ecn"), root)
            self.assertIsNone(executor.source_path(root, {}, "metaquotes-demo"))
            executor.save(root / executor.MARKER, {"server": "RoboForex-ECN", "login": 1})
            with self.assertRaises(executor.SourceUnavailable):
                executor.check_terminal(root, "metaquotes-demo")
        with self.assertRaisesRegex(ValueError, "Fonte desconhecida"):
            executor.parse_job({**TASK, "source": "../untrusted"})

    def test_holdout_blocks_overlap_with_exclusive_end(self):
        for start, stop in [("2026.11.24", "2026.11.25"), ("2026.12.10", "2026.12.11")]:
            self.assertEqual(executor.parse_job({**TASK, "from": start, "to": stop})["to"], stop)
        for start, stop in [("2026.11.24", "2026.11.26"), ("2026.11.25", "2026.11.26"),
                            ("2026.12.09", "2026.12.10")]:
            with self.assertRaisesRegex(ValueError, "reservada"):
                executor.parse_job({**TASK, "from": start, "to": stop})

    def test_source_in_native_journal_must_match(self):
        meta = {"data_source": {"server": "MetaQuotes-Demo"}}
        for journal in ("no history", "XAUUSD,M1 (RoboForex-ECN): tested"):
            with self.assertRaises(executor.InvalidBacktestReport):
                executor.verify_report_source(journal, TASK, meta)
        executor.verify_report_source("XAUUSD,M1 (MetaQuotes-Demo): tested", TASK, meta)
        self.assertEqual(meta["data_source"]["observed_servers"], ["MetaQuotes-Demo"])

    def test_catalog_reserved_csv_reads_header_only(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "XAUUSD_20261125.csv"
            path.write_bytes(b"time_msc,bid,ask\n\xff")
            entry = catalog.csv_metadata({"path": path, "holdout": True})
            self.assertEqual(entry["columns"], ["time_msc", "bid", "ask"])
            self.assertTrue(entry["holdout"])
            self.assertFalse(entry["selectable"])
            self.assertFalse(entry["coverage_verified"])

    def test_catalog_does_not_infer_coverage_from_container_names(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / "RoboForex-ECN/ticks/XAUUSD/202611.tkc"
            path.parent.mkdir(parents=True)
            path.write_bytes(b"fixture")
            self.assertFalse(catalog.inventory(root, "fixture")[0]["coverage_verified"])


class ExecutionRecoveryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.run_dir = self.base / "task_recovery"
        self.run_dir.mkdir()

    def manifest(self):
        return executor.load(self.run_dir / "result.json")

    def test_git_timeout_retries_and_publishes_only_sanitized_evidence(self):
        def attempt(_, directory, meta):
            meta["stage"] = "git"
            if meta["attempt"] == 1:
                (directory / "journal-tester.log").write_text(
                    "12:01:02 account 1234567 Password=secret "
                    "preliminary downloading of history ticks cancelled",
                    encoding="utf-8",
                )
                raise subprocess.TimeoutExpired(["git", "Password=secret"], executor.GIT_TIMEOUT)
            (directory / "report.htm").write_text("result", encoding="utf-8")

        with patch.object(executor, "execute", side_effect=attempt) as native:
            with patch.object(executor.time, "sleep"):
                executor.run_job(self.base, self.run_dir, TASK)
        self.assertEqual(native.call_count, 2)
        self.assertEqual(self.manifest()["status"], "completed")
        bundle_dir = self.base / "bundles"
        bundle_dir.mkdir()
        executor.publish(self.run_dir, bundle_dir)
        with ZipFile(bundle_dir / "task_recovery.zip") as bundle:
            self.assertIn("report.htm", bundle.namelist())
            details = bundle.read("diagnostico-01.txt").decode()
            self.assertIn("Etapa: git", details)
            self.assertIn("90 s", details)
            self.assertIn("downloading of history ticks cancelled", details)
            self.assertNotIn("1234567", details)
            self.assertNotIn("secret", details)
            self.assertFalse(any(name.endswith(".log") for name in bundle.namelist()))

    def test_invalid_ticks_do_not_retry(self):
        invalid = executor.InvalidBacktestReport("O histórico tem ticks gerados.")
        with patch.object(executor, "execute", side_effect=invalid) as native:
            executor.run_job(self.base, self.run_dir, TASK)
        self.assertEqual(native.call_count, 1)
        self.assertEqual(self.manifest()["status"], "failed")

    def test_resume_does_not_repeat_an_attempt_already_completed(self):
        meta = {
            "id": self.run_dir.name,
            "status": "running",
            "started": executor.utc(),
            "task": TASK,
            "attempts": [{"attempt": 1, "status": "completed", "stage": "report"}],
        }
        (self.run_dir / "attempt-01").mkdir()
        with patch.object(executor, "execute") as native:
            executor.run_job(self.base, self.run_dir, TASK, meta)
        native.assert_not_called()
        self.assertEqual(self.manifest()["status"], "completed")

    def test_interrupted_attempt_uses_remaining_budget(self):
        meta = {
            "id": self.run_dir.name,
            "status": "running",
            "started": executor.utc(),
            "task": TASK,
            "attempts": [{"attempt": 1, "status": "running", "stage": "tester"}],
        }
        (self.run_dir / "attempt-01").mkdir()
        with patch.object(executor, "execute") as native:
            executor.run_job(self.base, self.run_dir, TASK, meta)
        native.assert_called_once()
        entries = self.manifest()["attempts"]
        self.assertEqual([entry["status"] for entry in entries], ["interrupted", "completed"])

    def test_history_and_simulation_have_separate_progress_limits(self):
        state = {"phase_changes": []}
        phase, progress = executor.observe_journal(
            "preliminary downloading of history ticks started\n", "initialization", state
        )
        self.assertTrue(progress)
        self.assertEqual(phase, "history")
        self.assertIsNone(executor.terminal_deadline(phase, 0, 1190, 1200))
        self.assertIn("histórico", executor.terminal_deadline(phase, 0, 0, 1200))
        phase, _ = executor.observe_journal("generating based on real ticks", phase, state)
        self.assertEqual(phase, "simulation")
        phase, _ = executor.observe_journal("history synchronization completed", phase, state)
        self.assertEqual(phase, "simulation")
        self.assertIsNone(executor.terminal_deadline(phase, 0, 1790, 1800))
        self.assertIn("limite total", executor.terminal_deadline(phase, 0, 21590, 21600))

    def test_late_tick_start_with_generated_ticks_is_fallback(self):
        state = {"phase_changes": []}
        executor.observe_journal(
            "real ticks begin from 2026.11.24 00:00:00, every tick generation used",
            "simulation", state,
        )
        self.assertTrue(state["tick_fallback_seen"])

    def test_bom_and_appended_utf16_history_events(self):
        log = self.base / "tester.log"
        log.write_text("preliminary downloading of history ticks started\n", encoding="utf-16")
        offsets = {}
        self.assertIn("started", executor.read_journal_updates(self.base, offsets))
        with log.open("ab") as stream:
            stream.write("preliminary downloading of history ticks completed\n".encode("utf-16-le"))
        self.assertIn("completed", executor.read_journal_updates(self.base, offsets))
        self.assertEqual(executor.read_journal_updates(self.base, offsets), "")


if __name__ == "__main__":
    unittest.main()

