import fcntl
import gzip
import os
import shutil
import subprocess
import tempfile
import termios
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ListchangesOutputTest(unittest.TestCase):
    def test_no_terminal_preserves_output_for_log(self):
        data = b"package (1.2) stable; urgency=low\n\n  * Change.\n"
        result = subprocess.run(
            ["setsid", str(ROOT / "scripts/host/listchanges-output.sh")],
            input=data, capture_output=True, check=True,
        )
        self.assertEqual(result.stdout, data)
        self.assertEqual(result.stderr, b"")

    @unittest.skipUnless(shutil.which("apt-listchanges") and shutil.which("dpkg-deb"),
                         "Debian packaging tools are required")
    def test_noninteractive_apt_listchanges_logs_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            pkg = base / "pkg"
            (pkg / "DEBIAN").mkdir(parents=True)
            doc = pkg / "usr/share/doc/example-home-server"
            doc.mkdir(parents=True)
            (pkg / "DEBIAN/control").write_text(
                "Package: example-home-server\nVersion: 1.0\nArchitecture: all\n"
                "Maintainer: Fixture <fixture@example.invalid>\nDescription: fixture\n"
            )
            with gzip.open(doc / "changelog.Debian.gz", "wb") as stream:
                stream.write(b"example-home-server (1.0) stable; urgency=low\n\n"
                             b"  * fixture changelog marker\n\n"
                             b" -- Fixture <fixture@example.invalid>  "
                             b"Mon, 02 Nov 2026 00:00:00 +0000\n")
            deb = base / "fixture.deb"
            subprocess.run(["dpkg-deb", "--build", str(pkg), str(deb)],
                           check=True, capture_output=True)
            parts = base / "parts"
            parts.mkdir()
            apt_config = base / "apt.conf"
            apt_config.write_text(
                f'Dir::Etc::parts "{parts}";\n'
                f'Dir::Etc::apt-listchanges-main "{ROOT / "infra/host/apt/listchanges.conf"}";\n'
                f'Dir::Etc::apt-listchanges-parts "{parts}";\n'
            )
            log = base / "listchanges.log"
            env = dict(os.environ, APT_CONFIG=str(apt_config), DEBIAN_FRONTEND="noninteractive")
            subprocess.run(
                ["setsid", "apt-listchanges", "--profile=apt", "--show-all", "--no-network",
                 f"--log={log}", f"--filter={ROOT / 'scripts/host/listchanges-output.sh'}", str(deb)],
                env=env, check=True, capture_output=True,
            )
            self.assertIn("fixture changelog marker", log.read_text())
            log.unlink()
            hook = base / "apt-hook"
            hook.write_text(f"VERSION 2\nAPT::Get::Assume-Yes=1\n\n"
                            f"example-home-server 0.9 < 1.0 {deb}\n")
            with hook.open("rb") as info:
                env["APT_HOOK_INFO_FD"] = str(info.fileno())
                subprocess.run(
                    ["setsid", "apt-listchanges", "--apt", "--show-all", "--no-network",
                     f"--log={log}", f"--filter={ROOT / 'scripts/host/listchanges-output.sh'}"],
                    env=env, pass_fds=(info.fileno(),), check=True, capture_output=True,
                )
            self.assertIn("fixture changelog marker", log.read_text())

    def test_terminal_receives_same_changelog_as_log(self):
        master, slave = os.openpty()
        data = b"package changelog marker\n"
        try:
            def attach_terminal():
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

            result = subprocess.run(
                [str(ROOT / "scripts/host/listchanges-output.sh")],
                input=data, capture_output=True, check=True,
                pass_fds=(slave,), preexec_fn=attach_terminal,
            )
            self.assertEqual(result.stdout, data)
            self.assertEqual(os.read(master, 1024).replace(b"\r\n", b"\n"), data)
        finally:
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
