#!/usr/bin/env python3
"""Isolated Docker check: TLS, enrollment, issuance, ACL isolation and revocation."""
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time

SOURCE = Path(__file__).resolve().parents[1]
REPO = SOURCE.parents[2]
spec = importlib.util.spec_from_file_location("configure", SOURCE / "configure.py")
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


def run(*args, input=None, check=True):
    return subprocess.run(args, input=input, text=True, capture_output=True, check=check, timeout=120)


def main():
    prefix = "vault-db-test-" + secrets.token_hex(4)
    containers = []
    run("docker", "network", "create", prefix)
    try:
        with tempfile.TemporaryDirectory(prefix=prefix) as temporary:
            root = Path(temporary)
            subprocess.run(["sh", str(SOURCE / "generate-tls.sh")], cwd=root,
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            tls = root / "infra/vault/private/database-tls"
            policies = root / "infra/vault/policies"
            policies.symlink_to(REPO / "infra/vault/policies", target_is_directory=True)
            config.ROOT = root

            def start(service, image, *args):
                name = prefix + "-" + service
                containers.append(name)
                run("docker", "run", "-d", "--name", name, "--network", prefix,
                    "--network-alias", service, *args, image, *commands.get(service, []))
                return name

            commands = {
                "postgresql": ["/test-entrypoint.sh", "postgres", "-c", "ssl=on", "-c", "ssl_cert_file=/run/database-tls/server.pem",
                               "-c", "ssl_key_file=/run/database-tls/server-key.pem", "-c", "hba_file=/test-hba.conf"],
                "mariadb": ["/test-entrypoint.sh", "mariadbd", "--ssl-cert=/run/database-tls/server.pem", "--ssl-key=/run/database-tls/server-key.pem"],
                "vault": ["server", "-dev", "-dev-root-token-id=test-only", "-dev-listen-address=0.0.0.0:8200"],
            }
            names = {}
            for service, image, environment in [
                ("postgresql", "postgres:18-alpine", ["-e", "POSTGRES_PASSWORD=test-only", "-e", "POSTGRES_DB=postgres"]),
                ("mariadb", "mariadb:11", ["-e", "MYSQL_ROOT_PASSWORD=test-only"]),
            ]:
                names[service] = start(service, image, *environment,
                    "--tmpfs", "/var/lib/postgresql" if service == "postgresql" else "/var/lib/mysql",
                    "--tmpfs", "/run/database-tls", "-v", f"{tls / service}:/tls-source:ro",
                    "-v", f"{SOURCE / 'tls-entrypoint.sh'}:/test-entrypoint.sh:ro",
                    "-v", f"{SOURCE / 'postgresql-hba.conf'}:/test-hba.conf:ro",
                    "-v", f"{tls / 'ca.pem'}:/test-ca.pem:ro", "--entrypoint", "/bin/sh")

            names["vault"] = start("vault", "hashicorp/vault:1.21", "--cap-add", "IPC_LOCK", "--entrypoint", "/bin/vault", "-e", "VAULT_ADDR=http://127.0.0.1:8200",
                                   "-e", "VAULT_TOKEN=test-only", "-v", f"{tls / 'ca.pem'}:/vault/database-ca.pem:ro")

            def sql(database, statement):
                if database == "postgresql":
                    command = ["psql", "-XAtq", "-h", "127.0.0.1", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"]
                else:
                    command = ["mariadb", "-h127.0.0.1", "-uroot", "-ptest-only", "--batch", "--skip-column-names"]
                result = run("docker", "exec", "-i", "-e", "PGPASSWORD=test-only", names[database], *command, input=statement, check=False)
                if result.returncode:
                    raise AssertionError(f"{database}: {result.stderr}")
                return result.stdout

            config.database_sql = sql

            class DockerVault:
                def request(self, path, data=None, missing_ok=False, token="test-only"):
                    command = ["docker", "exec", "-i", "-e", f"VAULT_TOKEN={token}", names["vault"], "vault"]
                    command += ["read", "-format=json", path] if data is None else ["write", "-format=json", path, "-"]
                    result = run(*command, input=json.dumps(data) if data is not None else None, check=False)
                    if result.returncode:
                        if missing_ok and "No value found" in result.stderr:
                            return None
                        raise AssertionError(f"Vault {path} failed: {result.stderr}")
                    return json.loads(result.stdout) if result.stdout.strip() else {}

            vault = DockerVault()
            for service in ("postgresql", "mariadb", "vault"):
                for attempt in range(90):
                    try:
                        vault.request("sys/health") if service == "vault" else sql(service, "SELECT 1;")
                        break
                    except (subprocess.CalledProcessError, AssertionError):
                        time.sleep(1)
                else:
                    raise AssertionError(f"{service} failed to start")

            for database in ("postgresql", "mariadb"):
                for migration in sorted((REPO / "infra/migration" / database).glob("V*.sql")):
                    sql(database, migration.read_text())
            config.configure(vault)
            config.configure(vault)  # root rotation and identity files must survive reruns.
            sql("postgresql", (SOURCE / "postgresql-cutover.sql").read_text())
            sql("mariadb", (SOURCE / "mariadb-cutover.sql").read_text())

            for role, settings in config.database_roles().items():
                identity = root / "infra/vault/private/approle" / role
                login = vault.request("auth/approle/login", {
                    "role_id": (identity / "role-id").read_text().strip(),
                    "secret_id": (identity / "secret-id").read_text().strip(),
                })
                token = login["auth"]["client_token"]
                # A workload can get only its own role and cannot administer Vault.
                for path in ("database/config/postgresql", "database/creds/another-service", "sys/policies/acl/test"):
                    capabilities = vault.request("sys/capabilities", {"token": token, "paths": [path]})
                    assert capabilities["data"][path] == ["deny"], capabilities
                credentials = vault.request(f"database/creds/{role}", token=token)
                vault.request("sys/leases/renew", {"lease_id": credentials["lease_id"], "increment": 3600}, token=token)
                username = credentials["data"]["username"]
                password = credentials["data"]["password"]
                database = settings["db_name"]
                if database == "postgresql":
                    application_db = "itskolar_system" if role.startswith("itskolar") else "skybridge_airways" if role.startswith("skybridge") else "postgres"
                    connection = ["docker", "exec", "-e", f"PGPASSWORD={password}", names[database],
                                  "psql", "-XAtq", f"host=postgresql user={username} dbname={application_db} sslmode=verify-full sslrootcert=/test-ca.pem", "-c", "SELECT current_user;"]
                    assert run(*connection).stdout.strip() == (config.PG_ROLES[role][0] if role.endswith("-admin") else username)
                    assert sql(database, f"SELECT rolsuper OR rolcreaterole FROM pg_roles WHERE rolname='{username}';").strip() == "f"
                else:
                    connection = ["docker", "exec", "-e", f"MYSQL_PWD={password}", names[database],
                                  "mariadb", "-hmariadb", f"-u{username}", "--ssl-ca=/test-ca.pem", "--ssl-verify-server-cert", "-e", "SELECT 1;"]
                    run(*connection)
                    if role == "pterodactyl":
                        denied = run(*connection[:-2], "-e", "CREATE DATABASE forbidden;", check=False)
                        assert denied.returncode != 0
                vault.request("sys/leases/revoke", {"lease_id": credentials["lease_id"]})
                assert run(*connection, check=False).returncode != 0, f"{role} survived revocation"
                print(f"PASS: {role}: TLS login, ACL isolation, revocation")

            # Exercise the actual Agent templates, including renewal and restart
            # at max TTL. Only the supervised command and test Vault TLS differ.
            agent_names = []
            for role, variable in [("postgresql-exporter", "DATA_SOURCE_USER"),
                                   ("mariadb-exporter", "MYSQLD_USERNAME"),
                                   ("pterodactyl", "DB_USERNAME")]:
                settings = config.database_roles()[role]
                settings.update(default_ttl="5s", max_ttl="10s")
                vault.request(f"database/roles/{role}", settings)
                agent_config = (REPO / f"infra/vault/agent/{role}.hcl").read_text()
                agent_config = agent_config.split("exec {")[0]
                agent_config = agent_config.replace("https://vault.internal.bonnybonnybonaktan.xyz:8200", "http://vault:8200")
                agent_config = agent_config.replace('  ca_cert = "/etc/vault-agent/vault-ca.pem"\n', "")
                command = ["/bin/sh", "-ec", f'echo "${variable}" >> /tmp/observed; exec sleep 300']
                agent_config += "exec {\n command = " + json.dumps(command) + '\n restart_on_secret_changes = "always"\n}\n'
                config_file = root / f"{role}.hcl"
                config_file.write_text(agent_config)
                service = "agent-" + role
                commands[service] = ["agent", "-config=/test-agent.hcl"]
                agent_names.append(start(service, "hashicorp/vault:1.21",
                    "--cap-add", "IPC_LOCK", "--entrypoint", "/bin/vault",
                    "-v", f"{config_file}:/test-agent.hcl:ro",
                    "-v", f"{root / 'infra/vault/private/approle' / role}:/run/vault-auth:ro"))
            deadline = time.monotonic() + 120
            pending = set(agent_names)
            while pending and time.monotonic() < deadline:
                for agent in list(pending):
                    observed = run("docker", "exec", agent, "cat", "/tmp/observed", check=False).stdout.splitlines()
                    if len(set(observed)) >= 2:
                        pending.remove(agent)
                if pending:
                    time.sleep(1)
            for agent in pending:
                print(run("docker", "logs", "--tail", "30", agent, check=False).stderr)
            assert not pending, f"Agent failed to replace credentials/restart: {pending}"
            print("PASS: all three Agent configs renew leases and restart with new credentials")

            assert sql("postgresql", "SELECT count(*) FROM pg_roles WHERE rolname IN ('ITskolar-System_Admin','ITskolar-System_Worker','Skybridge-Airways_Admin','Skybridge-Airways_Worker') AND rolcanlogin;").strip() == "0"
            print("PASS: legacy PostgreSQL logins disabled; MariaDB account locked")
    finally:
        for container in reversed(containers):
            run("docker", "rm", "-f", "-v", container, check=False)
        run("docker", "network", "rm", prefix, check=False)


if __name__ == "__main__":
    os.umask(0o077)
    main()
