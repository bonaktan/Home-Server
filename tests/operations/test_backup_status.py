import json
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/operations/backup-status.sh"


class BackupStatusTest(unittest.TestCase):
    def classify(self, **overrides):
        observation = dict(budget_bytes=1000, used_bytes=800, observed_at=990,
                           now=1000, max_age_seconds=60, last_known="ok")
        observation.update(overrides)
        return subprocess.run([str(SCRIPT)], input=json.dumps(observation),
                              capture_output=True, text=True)

    def test_thresholds_and_hysteresis(self):
        for used, prior, expected in [(799, "ok", "ok"), (800, "ok", "warning"),
                                      (1000, "warning", "exceeded"),
                                      (750, "exceeded", "warning"),
                                      (749, "warning", "ok")]:
            with self.subTest(used=used, prior=prior):
                result = self.classify(used_bytes=used, last_known=prior)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(json.loads(result.stdout),
                                 {"state": expected, "last_known": expected})

    def test_missing_stale_or_future_observation_cannot_clear_warning(self):
        for observed, used, expected in [(None, None, "unknown"), (900, 1, "stale"),
                                         (1001, 1, "unknown")]:
            with self.subTest(observed=observed):
                result = self.classify(observed_at=observed, used_bytes=used,
                                       last_known="warning")
                self.assertEqual(json.loads(result.stdout),
                                 {"state": expected, "last_known": "warning"})

    def test_invalid_input_does_not_emit_status(self):
        for invalid in ({"budget_bytes": 0}, {"used_bytes": True},
                        {"last_known": "arbitrary"}, {"unexpected": "marker"}):
            result = self.classify(**invalid)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertNotIn("marker", result.stderr)


    def test_duplicate_fields_and_oversized_input_are_rejected(self):
        for data in ('{"now":1,"now":2}', "x" * 4097):
            result = subprocess.run([str(SCRIPT)], input=data, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
