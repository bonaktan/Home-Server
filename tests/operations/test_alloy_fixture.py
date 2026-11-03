import http.server
import os
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOY = os.environ.get("HOME_SERVER_ALLOY_TEST_BIN")


@unittest.skipUnless(ALLOY, "set HOME_SERVER_ALLOY_TEST_BIN to a reviewed Alloy binary")
class AlloyFixtureTest(unittest.TestCase):
    def test_audit_collection_and_positions_survive_restart(self):
        calls = []

        class Receiver(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                calls.append((self.path, self.rfile.read(int(self.headers["Content-Length"]))))
                self.send_response(204)
                self.end_headers()

            def log_message(self, *args):
                pass

        with tempfile.TemporaryDirectory() as directory, http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver) as server:
            root = Path(directory)
            source = root / "audit.log"
            source.write_text("fixture-safe-one\n")
            config = (ROOT / "infra/alloy/config.alloy").read_text()
            config = config.replace("/var/log/home-server/audit/*.log", str(root / "*.log"))
            config = config.replace("http://loki:3100", f"http://127.0.0.1:{server.server_port}")
            config_path = root / "config.alloy"
            config_path.write_text(config)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            processes = []
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                alloy_port = listener.getsockname()[1]
            logs = tempfile.TemporaryFile(mode="w+t")
            self.addCleanup(logs.close)

            def diagnostics():
                logs.flush()
                logs.seek(0)
                return logs.read()

            def start():
                process = subprocess.Popen(
                    [ALLOY, "run", "--disable-reporting", f"--server.http.listen-addr=127.0.0.1:{alloy_port}",
                     f"--storage.path={root / 'data'}", str(config_path)],
                    env=dict(os.environ, HOME_SERVER_HOST="fixture"),
                    stdout=logs, stderr=logs,
                )
                processes.append(process)
                return process

            def wait_for_count(count, process):
                deadline = time.monotonic() + 35
                while len(calls) < count and time.monotonic() < deadline:
                    self.assertIsNone(process.poll(), f"Alloy exited before forwarding the fixture: {diagnostics()}")
                    time.sleep(0.2)
                self.assertGreaterEqual(len(calls), count, "Alloy did not forward the fixture")

            try:
                first = start()
                wait_for_count(1, first)
                first.terminate()
                self.assertEqual(first.wait(timeout=15), 0)
                initial = len(calls)
                second = start()
                time.sleep(12)
                self.assertIsNone(second.poll(), f"Alloy exited on restart: {diagnostics()}")
                self.assertEqual(len(calls), initial, "restart re-sent the previous record")
                with source.open("a") as stream:
                    stream.write("fixture-safe-two\n")
                wait_for_count(initial + 1, second)
                self.assertTrue(all(path == "/loki/api/v1/push" and body for path, body in calls))
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=15)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                server.shutdown()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
