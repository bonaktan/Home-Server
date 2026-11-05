#!/usr/bin/env python3
"""Enroll database managers and reconcile Vault roles/policies. No third-party packages."""
import getpass
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
PG_ROLES = {
    "itskolar-admin": ("ITskolar-System_Admin", "5min", -1),
    "itskolar-worker": ("ITskolar-System_Worker", "30s", 20),
    "skybridge-admin": ("Skybridge-Airways_Admin", "5min", -1),
    "skybridge-worker": ("Skybridge-Airways_Worker", "30s", 20),
    "postgresql-exporter": ("vault_postgresql_exporter", "30s", 5),
    "postgresql-migration": ("vault_postgresql_migration", "30min", 5),
}


def database_roles(mariadb_database="mariadb"):
    roles = {}
    for name, (group, timeout, limit) in PG_ROLES.items():
        create = (
            'CREATE ROLE "{{name}}" WITH LOGIN PASSWORD \'{{password}}\' '
            "VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE "
            f'NOREPLICATION CONNECTION LIMIT {limit} INHERIT; '
            f'GRANT "{group}" TO "{{{{name}}}}"; '
            f'ALTER ROLE "{{{{name}}}}" SET statement_timeout = \'{timeout}\'; '
            'ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = \'60s\';'
        )
        if name.endswith("-admin") or name == "postgresql-migration":
            # DDL must be owned by the stable group, not a leased login.
            create += f' ALTER ROLE "{{{{name}}}}" SET role = \'{group}\';'
        roles[name] = {
            "db_name": "postgresql", "creation_statements": [create],
            "revocation_statements": ['DROP ROLE IF EXISTS "{{name}}";'],
            "default_ttl": "1h", "max_ttl": "24h",
        }
    for name, grants, limit in [
        ("pterodactyl", "GRANT ALL PRIVILEGES ON panel.* TO '{{name}}'@'%';", 30),
        ("mariadb-exporter", "GRANT SELECT, PROCESS, REPLICATION CLIENT, SLAVE MONITOR ON *.* TO '{{name}}'@'%';", 3),
        ("mariadb-migration", "GRANT ALL PRIVILEGES ON `" + mariadb_database.replace("`", "``") + "`.* TO '{{name}}'@'%';", 5),
    ]:
        roles[name] = {
            "db_name": "mariadb",
            "creation_statements": [
                "CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}' REQUIRE SSL "
                f"WITH MAX_USER_CONNECTIONS {limit}; " + grants
            ],
            "revocation_statements": ["DROP USER IF EXISTS '{{name}}'@'%';"],
            "default_ttl": "1h", "max_ttl": "24h",
        }
    return roles


class Vault:
    def __init__(self, token=None):
        self.address = os.environ.get("VAULT_ADDR", "https://vault.internal.bonnybonnybonaktan.xyz").rstrip("/")
        if not self.address.startswith("https://"):
            raise ValueError("VAULT_ADDR must use HTTPS")
        self.context = ssl.create_default_context(cafile=os.environ.get("VAULT_CACERT"))
        self.token = token if token is not None else os.environ.get("VAULT_TOKEN") or getpass.getpass("Vault administrator token: ")

    def request(self, path, data=None, missing_ok=False):
        request = urllib.request.Request(
            f"{self.address}/v1/{path}",
            data=json.dumps(data).encode() if data is not None else None,
            headers={"X-Vault-Token": self.token, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, context=self.context, timeout=60) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as error:
            if missing_ok and error.code == 404:
                return None
            # Do not echo API responses which can contain enrollment secrets.
            raise RuntimeError(f"Vault request {path} failed (HTTP {error.code})") from None


def database_sql(database, sql):
    commands = {
        "postgresql": 'exec psql -X -A -t -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1',
        "mariadb": 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mariadb --protocol=socket -uroot --database="$MYSQL_DATABASE" --batch --skip-column-names',
    }
    result = subprocess.run(
        ["docker", "compose", "exec", "-T", database, "sh", "-ec", commands[database]],
        input=sql, text=True, capture_output=True, cwd=ROOT,
    )
    if result.returncode:
        raise RuntimeError(f"{database} local enrollment failed; verify migrations and administrator access")
    return result.stdout


def configure(vault):
    for database in ("postgresql", "mariadb"):
        database_sql(database, (ROOT / f"infra/vault/database/bootstrap-{database}-migration.sql").read_text())
    mariadb_database = database_sql("mariadb", "SELECT DATABASE();").strip()
    if not mariadb_database or mariadb_database == "NULL":
        raise ValueError("Select MARIADB_DB before enrolling migration credentials")
    roles = database_roles(mariadb_database)
    mounts = vault.request("sys/mounts")["data"]
    if "database/" not in mounts:
        vault.request("sys/mounts/database", {"type": "database"})
    elif mounts["database/"]["type"] != "database":
        raise RuntimeError("database/ is occupied by another secrets engine")

    for database in ("postgresql", "mariadb"):
        config_path = f"database/config/{database}"
        existing = vault.request(config_path, missing_ok=True)
        if existing is None:
            password = secrets.token_hex(32)
            if database == "postgresql":
                database_sql(database, f"ALTER ROLE vault_manager LOGIN PASSWORD '{password}';")
                database_name = database_sql(database, "SELECT current_database();").strip()
                # Database names are URI components, never SQL or shell fragments.
                from urllib.parse import quote
                config = {
                    "plugin_name": "postgresql-database-plugin",
                    "connection_url": "postgresql://{{username}}:{{password}}@postgresql:5432/"
                    + quote(database_name, safe="")
                    + "?sslmode=verify-full&sslrootcert=/vault/database-ca.pem",
                }
            else:
                database_sql(database, f"ALTER USER 'vault_manager'@'%' IDENTIFIED BY '{password}' ACCOUNT UNLOCK;")
                config = {
                    "plugin_name": "mysql-database-plugin",
                    "connection_url": "{{username}}:{{password}}@tcp(mariadb:3306)/",
                    "tls_ca": (ROOT / "infra/vault/private/database-tls/ca.pem").read_text(),
                }
            config.update({
                "username": "vault_manager", "password": password,
                "allowed_roles": [name for name, role in roles.items() if role["db_name"] == database],
                "username_template": 'v_{{random 24}}', "verify_connection": True,
            })
            vault.request(config_path, config)
        else:
            allowed = existing["data"]["allowed_roles"]
            desired = [name for name, role in roles.items() if role["db_name"] == database]
            if "*" not in allowed and not set(desired).issubset(allowed):
                # A partial update retains the management password already owned by Vault.
                vault.request(config_path, {
                    "plugin_name": existing["data"]["plugin_name"],
                    "allowed_roles": sorted(set(allowed) | set(desired)),
                })
        # Safe on reruns: never overwrite the password Vault already owns.
        vault.request(f"database/rotate-root/{database}", {})

    auth = vault.request("sys/auth")["data"]
    if "approle/" not in auth:
        vault.request("sys/auth/approle", {"type": "approle"})
    elif auth["approle/"]["type"] != "approle":
        raise RuntimeError("approle/ is occupied by another auth method")

    private_root = ROOT / "infra/vault/private"
    private_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    private_root.chmod(0o700)
    private = private_root / "approle"
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name, role in roles.items():
        vault.request(f"database/roles/{name}", role)
        policy = (ROOT / f"infra/vault/policies/{name}.hcl").read_text()
        vault.request(f"sys/policies/acl/{name}", {"policy": policy})
        vault.request(f"auth/approle/role/{name}", {
            "token_policies": [name], "token_no_default_policy": True,
            "token_period": "1h", "token_num_uses": 0,
            "secret_id_ttl": 0, "secret_id_num_uses": 0,
        })
        directory = private / name
        directory.mkdir(exist_ok=True, mode=0o755)
        directory.chmod(0o755)
        role_id = vault.request(f"auth/approle/role/{name}/role-id")["data"]["role_id"]
        secret_id = vault.request(f"auth/approle/role/{name}/secret-id", {})["data"]["secret_id"]
        # Only these per-service directories are bind-mounted into containers.
        # The parent private/ directory remains host-owner-only.
        for filename, value in (("role-id", role_id), ("secret-id", secret_id)):
            path = directory / filename
            temporary = path.with_suffix(".new")
            temporary.write_text(value + "\n")
            temporary.chmod(0o444)
            temporary.replace(path)
        print(f"Configured {name}")


if __name__ == "__main__":
    os.umask(0o077)
    try:
        configure(Vault())
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
