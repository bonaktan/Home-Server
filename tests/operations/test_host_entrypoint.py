import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class HostEntrypointTest(unittest.TestCase):
    def run_entry(self, script, *args):
        return subprocess.run(
            ["bash", str(ROOT / script), *args], capture_output=True, text=True
        )

    def test_default_is_read_only_inspection(self):
        result = self.run_entry("setup.sh")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Host:", result.stdout)
        self.assertIn("Inventory and readiness gates:", result.stdout)

    def test_unimplemented_phases_fail_closed(self):
        for action in ("plan", "apply", "verify"):
            with self.subTest(action=action):
                result = self.run_entry("setup.sh", action, "network")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("no changes made", result.stderr)

    def test_bad_input_is_rejected_and_legacy_delegates(self):
        self.assertEqual(self.run_entry("setup.sh", "apply", "../network").returncode, 2)
        result = self.run_entry("new_setup.sh", "inspect")
        self.assertEqual(result.returncode, 0)
        self.assertIn("deprecated", result.stderr)
        self.assertIn("Host:", result.stdout)


if __name__ == "__main__":
    unittest.main()
