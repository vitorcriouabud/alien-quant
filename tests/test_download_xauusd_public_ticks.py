import gzip
import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "tools" / "download_xauusd_public_ticks.py"
SPEC = importlib.util.spec_from_file_location("alien_ticks", MODULE)
alien_ticks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(alien_ticks)


class TickDownloadTests(unittest.TestCase):
    def test_verify_valid_gzip(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ticks.csv.gz"
            with gzip.open(path, "wt", encoding="utf-8", newline="") as stream:
                stream.write(alien_ticks.HEADER + "\n")
                stream.write("2026-01-01 00:00:00.001,2000.100,2000.000,0.1,0.2\n")
                stream.write("2026-01-01 00:00:00.002,2000.200,2000.100,0.2,0.3\n")
            result = alien_ticks.verify_gzip(path, 2)
            self.assertEqual(result["rows_verified"], 2)
            self.assertEqual(result["gzip_crc"], "OK")

    def test_rejects_ask_below_bid(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.csv.gz"
            with gzip.open(path, "wt", encoding="utf-8", newline="") as stream:
                stream.write(alien_ticks.HEADER + "\n")
                stream.write("2026-01-01 00:00:00.001,1999.9,2000.0,0.1,0.2\n")
            with self.assertRaises(ValueError):
                alien_ticks.verify_gzip(path, 1)

    def test_rejects_out_of_order_timestamps(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "order.csv.gz"
            with gzip.open(path, "wt", encoding="utf-8", newline="") as stream:
                stream.write(alien_ticks.HEADER + "\n")
                stream.write("2026-01-01 00:00:00.002,2000.1,2000.0,0.1,0.2\n")
                stream.write("2026-01-01 00:00:00.001,2000.2,2000.1,0.1,0.2\n")
            with self.assertRaises(ValueError):
                alien_ticks.verify_gzip(path, 2)


if __name__ == "__main__":
    unittest.main()
