#!/usr/bin/env python3
"""Validate the actual staging deployment; never selects production or runs docker run."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
COMPOSE = ["docker", "compose", "-f", str(ROOT / "compose.yaml"), "-f", str(ROOT / "compose.staging.yaml")]
spec = importlib.util.spec_from_file_location("configure", ROOT / "infra/vault/database/configure.py")
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)


def compose(*args, stdin=None, environment=None):
    return subprocess.run(COMPOSE + list(args), input=stdin, text=True, capture_output=True,
                          cwd=ROOT, env={**os.environ, **(environment or {})}, timeout=120)


class StagingVault:
    def request(self, path, data=None, missing_ok=False, token=None, denied=False):
        args = ["exec", "-T", "-e", "VAULT_ADDR=https://127.0.0.1:8200",
                "-e", "VAULT_CACERT=/vault/tls/fullchain.pem",
                "-e", "VAULT_TLS_SERVER_NAME=vault.internal.bonnybonnybonaktan.xyz"]
        if token:
            args += ["-e", "VAULT_TOKEN"]
        args += ["vault", "vault"]
        args += ["read", "-format=json", path] if data is None else ["write", "-format=json", path, "-"]
        result = compose(*args, stdin=json.dumps(data) if data is not None else None,
                         environment={"VAULT_TOKEN": token} if token else {})
        if denied:
            assert result.returncode and "Code: 403" in result.stderr, f"Expected denial: {path}"
            return
        if result.returncode:
            if missing_ok and "No value found" in result.stderr:
                return None
            raise RuntimeError(f"Staging Vault request failed: {path} (secrets withheld)")
        return json.loads(result.stdout) if result.stdout.strip() else {}


def sql(database, statement):
    commands = {
        "postgresql": 'exec psql -XAtq -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1',
        "mariadb": 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mariadb --protocol=socket -uroot --database="$MYSQL_DATABASE" --batch --skip-column-names',
    }
    result = compose("exec", "-T", database, "sh", "-ec", commands[database], stdin=statement)
    if result.returncode:
        raise RuntimeError(f"Staging {database} SQL failed (secrets withheld)")
    return result.stdout


def check_credentials(vault):
    for role, settings in configure.database_roles().items():
        identity = ROOT / "infra/vault/private/approle" / role
        login = vault.request("auth/approle/login", {
            "role_id": (identity / "role-id").read_text().strip(),
            "secret_id": (identity / "secret-id").read_text().strip(),
        })
        token = login["auth"]["client_token"]
        lease = None
        try:
            vault.request("auth/token/renew-self", {}, token=token)
            for forbidden in ("database/config/postgresql", "database/creds/another-service"):
                vault.request(forbidden, token=token, denied=True)
            credentials = vault.request(f"database/creds/{role}", token=token)
            lease = credentials["lease_id"]
            vault.request("sys/leases/renew", {"lease_id": lease, "increment": 3600}, token=token)
            vault.request("sys/leases/renew", {"lease_id": "database/creds/another-service/test"}, token=token, denied=True)
            username, password = credentials["data"]["username"], credentials["data"]["password"]
            if settings["db_name"] == "postgresql":
                database = "itskolar_system" if role.startswith("itskolar") else "skybridge_airways" if role.startswith("skybridge") else "postgres"
                # These identities use the configured infrastructure catalog.
                if role in ("postgresql-exporter", "postgresql-migration"):
                    database = sql("postgresql", "SELECT current_database();").strip()
                args = ["exec", "-T", "-e", "PGPASSWORD", "postgresql", "psql", "-XAtq",
                        f"host=postgresql dbname={database} user={username} sslmode=verify-full sslrootcert=/test-ca.pem",
                        "-c", "SELECT session_user;"]
                # The CA is already mounted in the manager TLS source's sibling
                # only on the host; copy the public CA into this container for tests.
                cp = compose("cp", str(ROOT / "infra/vault/private/database-tls/ca.pem"), "postgresql:/test-ca.pem")
                assert cp.returncode == 0, "Could not install public test CA"
                environment = {"PGPASSWORD": password}
                wrong = {"PGPASSWORD": "deliberately-invalid-staging-probe"}
            else:
                cp = compose("cp", str(ROOT / "infra/vault/private/database-tls/ca.pem"), "mariadb:/test-ca.pem")
                assert cp.returncode == 0, "Could not install public test CA"
                args = ["exec", "-T", "-e", "MYSQL_PWD", "mariadb", "mariadb", "-hmariadb", f"-u{username}",
                        "--ssl-ca=/test-ca.pem", "--ssl-verify-server-cert", "-e", "SELECT 1;"]
                environment = {"MYSQL_PWD": password}
                wrong = {"MYSQL_PWD": "deliberately-invalid-staging-probe"}
            assert compose(*args, environment=environment).returncode == 0, f"{role}: TLS login failed"
            assert compose(*args, environment=wrong).returncode != 0, f"{role}: incorrect password accepted"
            vault.request("sys/leases/revoke", {"lease_id": lease})
            lease = None
            assert compose(*args, environment=environment).returncode != 0, f"{role}: revoked login accepted"
            print(f"PASS {role}: scoped ACL, token/lease renewal, verified TLS, wrong password rejected, revocation", flush=True)
        finally:
            if lease:
                vault.request("sys/leases/revoke", {"lease_id": lease})
            vault.request("auth/token/revoke-self", {}, token=token)


PANEL_PROBE = r'''
<?php
$environment = [];
foreach (glob('/proc/[0-9]*/environ') as $file) {
    $raw = @file_get_contents($file);
    if ($raw === false || !str_contains($raw, 'DB_USERNAME=v_')) continue;
    foreach (explode("\0", $raw) as $pair) {
        $parts = explode('=', $pair, 2);
        if (count($parts) === 2) $environment[$parts[0]] = $parts[1];
    }
    break;
}
if (empty($environment['DB_USERNAME']) || empty($environment['DB_PASSWORD'])) exit(2);
try {
    $pdo = new PDO('mysql:host=mariadb;port=3306;dbname=panel', $environment['DB_USERNAME'], $environment['DB_PASSWORD'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::MYSQL_ATTR_SSL_CA => '/etc/vault-agent/database-ca.pem',
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true,
    ]);
    $pdo->exec('CREATE TEMPORARY TABLE vault_staging_probe (value INT)');
    $pdo->exec('INSERT INTO vault_staging_probe VALUES (42)');
    if ((int)$pdo->query('SELECT value FROM vault_staging_probe')->fetchColumn() !== 42) exit(3);
    echo $environment['DB_USERNAME'];
} catch (Throwable $error) { fwrite(STDERR, 'Panel TLS read/write probe failed'); exit(4); }
'''


def observe(service):
    if service == "pterodactyl":
        result = compose("exec", "-T", service, "php", stdin=PANEL_PROBE.lstrip())
        if result.returncode:
            return None
        web = compose("exec", "-T", service, "curl", "-fsS", "--max-time", "5", "-o", "/dev/null", "http://127.0.0.1/auth/login")
        if web.returncode:
            return None
        return result.stdout.strip()
    variable, port, metric = ("DATA_SOURCE_USER", 9187, "pg_up") if service == "postgresql_exporter" else ("MYSQLD_USERNAME", 9104, "mysql_up")
    metrics = compose("exec", "-T", service, "wget", "-qO-", f"http://127.0.0.1:{port}/metrics")
    if metrics.returncode or not re.search(r"^" + metric + r"(?:\{[^\n]*\})? 1$", metrics.stdout, re.M):
        return None
    command = f'''for file in /proc/[0-9]*/environ; do
        tr '\\0' '\\n' < "$file" 2>/dev/null | sed -n 's/^{variable}=//p'
    done'''
    result = compose("exec", "-T", service, "sh", "-c", command)
    names = {line.strip() for line in result.stdout.splitlines() if line.startswith("v_")}
    return next(iter(names)) if len(names) == 1 else None


def check_rotation(vault):
    services = {"postgresql_exporter": "postgresql-exporter", "mariadb_exporter": "mariadb-exporter", "pterodactyl": "pterodactyl"}
    originals = {role: vault.request(f"database/roles/{role}")["data"] for role in services.values()}
    try:
        for role, settings in originals.items():
            vault.request(f"database/roles/{role}", {**settings, "default_ttl": "60s", "max_ttl": "120s"})
        restarted = compose("restart", *services)
        assert restarted.returncode == 0, "Could not restart staging Agents"
        initial, rotated = {}, set()
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline and len(rotated) != len(services):
            for service in services:
                current = observe(service)
                if not current:
                    continue
                if service not in initial:
                    initial[service] = current
                    print(f"READY {service}: dynamic credential is serving database requests", flush=True)
                elif current != initial[service] and service not in rotated:
                    rotated.add(service)
                    print(f"PASS {service}: maximum-TTL credential replacement and working database access", flush=True)
            time.sleep(2)
        assert len(rotated) == len(services), f"Rotation not verified for {set(services) - rotated}"
    finally:
        for role, settings in originals.items():
            vault.request(f"database/roles/{role}", settings)
        result = compose("restart", *services)
        assert result.returncode == 0, "Could not restart Agents after restoring normal TTLs"
        print("Restored original database TTLs and restarted staging Agents", flush=True)


if __name__ == "__main__":
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("bootstrap", "credentials", "rotation"))
    action = parser.parse_args().action
    vault = StagingVault()
    if action == "bootstrap":
        configure.database_sql = sql
        configure.configure(vault)
    elif action == "credentials":
        check_credentials(vault)
    else:
        check_rotation(vault)
