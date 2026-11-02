import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAYBOOK = ROOT / "ansible/playbooks/second-server.yml"


@unittest.skipUnless(shutil.which("ansible-playbook"), "ansible-core is required")
class AnsibleScopeTest(unittest.TestCase):
    def test_unenrolled_target_is_rejected_before_connection(self):
        with tempfile.TemporaryDirectory() as directory:
            inventory = Path(directory) / "hosts.ini"
            inventory.write_text("[second_server]\nhome-server-alt ansible_connection=local\n")
            env = dict(os.environ, ANSIBLE_LOCAL_TEMP=str(Path(directory) / "tmp"),
                       ANSIBLE_NOCOLOR="1")
            env.pop("ANSIBLE_CONFIG", None)
            result = subprocess.run(
                ["ansible-playbook", "-i", str(inventory), str(PLAYBOOK), "--check"],
                env=env, capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Only the enrolled second-server alias may be targeted", result.stdout)
            self.assertNotIn("Gather minimal host facts]", result.stdout)


if __name__ == "__main__":
    unittest.main()
