import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("docker"), "Docker Compose is required")
class ObservabilityComposeTest(unittest.TestCase):
    def render(self, extra=None):
        env = dict(os.environ)
        for component in ("PROMETHEUS", "NODE_EXPORTER", "CADVISOR", "LOKI", "ALLOY"):
            env[f"SECOND_{component}_IMAGE"] = "example.invalid/fixture@sha256:" + "a" * 64
        env["SECOND_TAILSCALE_IP"] = "100.64.0.3"
        env["SECOND_OBSERVABILITY_GATEWAY"] = "172.31.0.1"
        if extra:
            env.update(extra)
        return subprocess.run(
            ["docker", "compose", "-f", str(ROOT / "compose.observability.yaml"),
             "config", "--format", "json"], env=env, capture_output=True, text=True,
        )

    def test_services_storage_and_private_bindings(self):
        result = self.render()
        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(result.stdout)
        services = config["services"]
        self.assertEqual(set(services), {"prometheus", "node_exporter", "cadvisor", "loki", "alloy"})
        for name, target in (("prometheus", "/prometheus"), ("loki", "/loki"),
                             ("alloy", "/var/lib/alloy")):
            self.assertTrue(any(v["type"] == "volume" and v["target"] == target
                                for v in services[name]["volumes"]))
        for name in ("prometheus", "loki"):
            self.assertEqual(services[name]["ports"][0]["host_ip"], "100.64.0.3")
        for name in ("node_exporter", "cadvisor", "alloy"):
            self.assertNotIn("ports", services[name])
        self.assertEqual(services["node_exporter"]["network_mode"], "host")

    def test_missing_address_or_image_fails_to_render(self):
        for field in ("SECOND_TAILSCALE_IP", "SECOND_OBSERVABILITY_GATEWAY", "SECOND_LOKI_IMAGE"):
            with self.subTest(field=field):
                self.assertNotEqual(self.render({field: ""}).returncode, 0)


if __name__ == "__main__":
    unittest.main()
