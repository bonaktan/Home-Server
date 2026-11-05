import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import configure
import migrate


class FakeVault:
    def __init__(self, events, renewal_failure=False, issuance_failure=False):
        self.events = events
        self.renewal_failure = renewal_failure
        self.issuance_failure = issuance_failure
        self.token = ""

    def request(self, path, data=None):
        self.events.append((path, data))
        if path == "auth/approle/login":
            return {"auth": {"client_token": "service-token", "lease_duration": 2}}
        if path.startswith("database/creds/"):
            if self.issuance_failure:
                raise RuntimeError("Issuance failed")
            return {"lease_id": "lease-one", "lease_duration": 2,
                    "data": {"username": "leased-user", "password": "leased-password"}}
        if path == "sys/leases/renew":
            if self.renewal_failure:
                raise RuntimeError("Renewal failed")
            return {"lease_duration": 2}
        if path == "auth/token/renew-self":
            return {"auth": {"lease_duration": 2}}
        return {}


class FakeProcess:
    def __init__(self, code):
        self.returncode = code

    def poll(self):
        return self.returncode

    def terminate(self):
        self.returncode = -15

    def wait(self, timeout=None):
        return self.returncode


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        identity = self.root / "infra/vault/private/approle/postgresql-migration"
        identity.mkdir(parents=True)
        (identity / "role-id").write_text("migration-role-id\n")
        (identity / "secret-id").write_text("migration-secret-id\n")
        self.events = []
        self.environment = patch.dict(os.environ, {"COMPOSE_FILE": "compose.yaml:compose.staging.yaml", "VAULT_TOKEN": "operator-root-token"}, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.root_patch = patch.object(migrate, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def invoke(self, code, **options):
        process = FakeProcess(code)
        vault = FakeVault(self.events, **options)

        def cleanup(*args, **kwargs):
            self.events.append(("container-cleanup", None))
            return subprocess.CompletedProcess(args[0], 0)

        with patch.object(migrate.subprocess, "Popen", return_value=process) as popen, \
             patch.object(migrate.subprocess, "run", side_effect=cleanup), \
             contextlib.redirect_stderr(io.StringIO()):
            result = migrate.run(vault, "postgresql", "migrate")
        return result, popen

    def test_credentials_never_enter_arguments_and_token_is_revoked_after_job(self):
        result, popen = self.invoke(0)
        self.assertEqual(result, 0)
        arguments = popen.call_args.args[0]
        self.assertNotIn("leased-password", arguments)
        self.assertNotIn("leased-user", arguments)
        self.assertIn("postgresql_migration", arguments)
        self.assertIn(str(Path('compose.staging.yaml').resolve()), arguments)
        environment = popen.call_args.kwargs["env"]
        self.assertEqual(environment["FLYWAY_PASSWORD"], "leased-password")
        self.assertNotIn("VAULT_TOKEN", environment)
        self.assertEqual(self.events[0][1], {"role_id": "migration-role-id", "secret_id": "migration-secret-id"})
        paths = [event[0] for event in self.events]
        self.assertLess(paths.index("container-cleanup"), paths.index("auth/token/revoke-self"))

    def test_flyway_failure_is_preserved_and_not_retried(self):
        result, popen = self.invoke(17)
        self.assertEqual(result, 17)
        self.assertEqual(popen.call_count, 1)
        self.assertEqual(self.events[-1][0], "auth/token/revoke-self")

    def test_renewal_failure_stops_job_and_revokes_token(self):
        with self.assertRaisesRegex(RuntimeError, "renewal failed"):
            self.invoke(None, renewal_failure=True)
        paths = [event[0] for event in self.events]
        self.assertIn("sys/leases/renew", paths)
        self.assertLess(paths.index("container-cleanup"), paths.index("auth/token/revoke-self"))

    def test_issuance_failure_still_revokes_login_token(self):
        with self.assertRaisesRegex(RuntimeError, "Issuance failed"):
            self.invoke(0, issuance_failure=True)
        self.assertEqual(self.events[-1][0], "auth/token/revoke-self")

    def test_explicit_compose_selection_is_required(self):
        del os.environ["COMPOSE_FILE"]
        with self.assertRaisesRegex(ValueError, "COMPOSE_FILE"):
            migrate.run(FakeVault(self.events), "postgresql", "migrate")
        self.assertEqual(self.events, [])

    def test_anonymous_client_ignores_operator_token(self):
        self.assertEqual(configure.Vault(token="").token, "")

    def test_renewal_renews_both_lease_and_token(self):
        class Stop:
            calls = 0

            def wait(self, interval):
                self.calls += 1
                return self.calls > 1

        errors = []
        migrate.renew(FakeVault(self.events), "lease-one", 2, Stop(), errors)
        self.assertEqual([e[0] for e in self.events], ["sys/leases/renew", "auth/token/renew-self"])
        self.assertEqual(errors, [])

    def test_mariadb_catalog_is_quoted_and_other_catalogs_are_not_granted(self):
        sql = configure.database_roles("custom`catalog")["mariadb-migration"]["creation_statements"][0]
        self.assertIn("ON `custom``catalog`.*", sql)
        self.assertNotIn("ON *.*", sql)

    def test_existing_connections_keep_passwords_and_existing_allowed_roles(self):
        for directory in ("database", "policies"):
            (self.root / "infra/vault" / directory).symlink_to(
                configure.ROOT / "infra/vault" / directory, target_is_directory=True)

        def request(path, data=None, missing_ok=False):
            self.events.append((path, data))
            if path == "sys/mounts":
                return {"data": {"database/": {"type": "database"}}}
            if path == "sys/auth":
                return {"data": {"approle/": {"type": "approle"}}}
            if path.startswith("database/config/") and data is None:
                return {"data": {"plugin_name": "existing-plugin", "allowed_roles": ["custom-role"]}}
            if path.endswith("/role-id"):
                return {"data": {"role_id": "role"}}
            if path.endswith("/secret-id"):
                return {"data": {"secret_id": "secret"}}
            return {}

        with patch.object(configure, "ROOT", self.root), \
             patch.object(configure, "database_sql", side_effect=lambda db, sql: "custom_catalog\n" if sql == "SELECT DATABASE();" else "") as database_sql, \
             contextlib.redirect_stdout(io.StringIO()):
            configure.configure(Mock(request=request))
        updates = [data for path, data in self.events if path.startswith("database/config/") and data]
        self.assertEqual(len(updates), 2)
        for update in updates:
            self.assertEqual(set(update), {"plugin_name", "allowed_roles"})
            self.assertIn("custom-role", update["allowed_roles"])
        self.assertFalse(any("PASSWORD" in call.args[1] for call in database_sql.call_args_list))
        maria_role = next(data for path, data in self.events if path == "database/roles/mariadb-migration")
        self.assertIn("ON `custom_catalog`.*", maria_role["creation_statements"][0])


if __name__ == "__main__":
    unittest.main()
