import concurrent.futures
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/operations"))
spec = importlib.util.spec_from_file_location("backup_status_store", ROOT / "scripts/operations/backup_status_store.py")
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


class BackupStatusStoreTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.uid = os.geteuid()

    def observe(self, used, observed, now=1000, destination="r2"):
        return store.observe(str(self.path), destination,
                             {"budget_bytes": 1000, "used_bytes": used,
                              "observed_at": observed, "max_age_seconds": 60},
                             now, self.uid)

    def test_warning_survives_restart_stale_and_out_of_order_observations(self):
        self.assertEqual(self.observe(1000, 990)["state"], "exceeded")
        self.assertEqual(self.observe(1, 900)["last_known"], "exceeded")
        self.assertEqual(self.observe(1, 980)["state"], "stale")
        persisted = json.loads((self.path / "r2.json").read_text())
        self.assertEqual((persisted["state"], persisted["source_observed_at"]), ("stale", 980))
        self.assertEqual(self.observe(1, 990)["state"], "unknown")
        self.assertEqual(self.observe(750, 991)["state"], "warning")
        self.assertEqual(self.observe(749, 992)["state"], "ok")
        self.assertEqual(self.observe(800, 993, destination="second_server")["state"], "warning")
        self.assertEqual(json.loads((self.path / "r2.json").read_text())["last_known"], "ok")

    def test_failed_atomic_replace_preserves_previous_state(self):
        self.observe(1000, 990)
        with mock.patch.object(store.os, "replace", side_effect=OSError("simulated")):
            with self.assertRaises(OSError):
                self.observe(1, 991)
        self.assertEqual(json.loads((self.path / "r2.json").read_text())["last_known"], "exceeded")
        self.assertFalse(list(self.path.glob("*.tmp")))

    def test_concurrent_observations_keep_newest_source_time(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(self.observe, 1, 995), pool.submit(self.observe, 900, 999)]
            for future in futures:
                future.result()
        state = json.loads((self.path / "r2.json").read_text())
        self.assertEqual(state["observed_at"], 999)
        self.assertEqual(state["last_known"], "warning")

    def test_rejects_symlink_or_permissive_directory(self):
        outside = self.path / "outside"
        outside.write_text("preserve")
        (self.path / "r2.json").symlink_to(outside)
        with self.assertRaises(OSError):
            self.observe(1, 990)
        self.assertEqual(outside.read_text(), "preserve")
        os.chmod(self.path, 0o777)
        with self.assertRaises(ValueError):
            self.observe(1, 990, destination="second_server")
        os.chmod(self.path, 0o700)


if __name__ == "__main__":
    unittest.main()
