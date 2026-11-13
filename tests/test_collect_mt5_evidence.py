import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "collect_mt5_evidence.py"


class CollectorTests(unittest.TestCase):
    def test_zip_with_csv_and_html_and_manifest(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "mt5"
            source.mkdir()
            (source / "study.csv").write_text("date;result\n2026-11-12;1\n", encoding="utf-8")
            (source / "tester.htm").write_text("<html><table></table></html>", encoding="utf-8")
            (source / "private.log").write_text("not included", encoding="utf-8")
            dest = root / "out"
            cp = subprocess.run(
                [sys.executable, str(SCRIPT), "--source", str(source),
                 "--output", str(dest), "--days", "0"], capture_output=True, text=True
            )
            self.assertEqual(cp.returncode, 0, cp.stderr)
            archives = list(dest.glob("*.zip"))
            self.assertEqual(len(archives), 1)
            with zipfile.ZipFile(archives[0]) as z:
                names = z.namelist()
                self.assertEqual(z.testzip(), None)
                self.assertTrue(any(n.endswith("/study.csv") for n in names))
                self.assertTrue(any(n.endswith("/tester.htm") for n in names))
                self.assertFalse(any(n.endswith(".log") for n in names))
                manifest = json.loads(z.read("manifest.json"))
                self.assertEqual(len(manifest["files"]), 2)
                self.assertEqual(manifest["schema"], "alien-evidencia-v1")

    def test_no_data_is_a_failure_not_a_fake_report(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "empty"
            source.mkdir()
            cp = subprocess.run(
                [sys.executable, str(SCRIPT), "--source", str(source),
                 "--output", str(root / "out"), "--days", "0"],
                capture_output=True, text=True
            )
            self.assertEqual(cp.returncode, 2)
            self.assertFalse(list((root / "out").glob("*.zip")))


if __name__ == "__main__":
    unittest.main()
