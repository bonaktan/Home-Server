# Flyway with dynamic Vault credentials

Use this for an existing production installation where both Flyway histories
already contain successful V1 and V2 migrations and the Vault database connections
work. These steps add two migration identities without replacing application
AppRoles or resetting Vault's management passwords.

The jobs use the original `flyway/flyway:10` image and host Python 3; no image
build is needed. The helper logs in with a dedicated AppRole, fetches credentials,
renews the token and database lease while Flyway runs, then revokes the token and
its leases. Credentials enter the container environment, not command arguments
or files. Docker administrators can inspect container environment variables.

## 1. Prepare the database permissions once

On the production Docker host, from the repository root:

```sh
export COMPOSE_FILE=compose.yaml:compose.production.yaml
docker compose exec -T postgresql sh -ec 'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < infra/vault/database/bootstrap-postgresql-migration.sql
docker compose exec -T mariadb sh -ec 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mariadb --protocol=socket -uroot --database="$MYSQL_DATABASE"' < infra/vault/database/bootstrap-mariadb-migration.sql
```

PostgreSQL uses the container's local socket, which the repository permits for
local administration; this bypasses the failing TCP password from the log. If
your production local authentication differs, run the SQL through an authorized
administrator session instead. MariaDB still requires its actual root password.
The commands do not change either administrator password or existing Flyway
migration checksums.

PostgreSQL gets a stable NOLOGIN owner, `vault_postgresql_migration`, with schema
creation permissions in `POSTGRES_DB` and ownership of its existing
`public.flyway_schema_history` table. MariaDB's manager gains grant authority on
`MARIADB_DB` so it can issue accounts limited to that catalog. Both scripts can
be rerun. V2 must already have created `vault_manager` in both databases.

## 2. Allow the new roles on the existing Vault connections

Log into the production Vault web UI with an administrator identity. Open
**database → Connections → postgresql**, edit **Allowed roles**, and append
`postgresql-migration`. Keep all existing allowed role names. Do the same for
the `mariadb` connection, appending `mariadb-migration`.

Do not replace the manager password with a remembered temporary password or an
empty value. Vault already owns that password. If the edit form requires one,
use the web UI's `>_` console to perform these partial updates instead, one
command at a time:

```text
vault write database/config/postgresql plugin_name=postgresql-database-plugin allowed_roles=itskolar-admin,itskolar-worker,skybridge-admin,skybridge-worker,postgresql-exporter,postgresql-migration
vault write database/config/mariadb plugin_name=mysql-database-plugin allowed_roles=pterodactyl,mariadb-exporter,mariadb-migration
```

Those lists cover this repository's roles. Include any additional roles you
have configured before executing them; if the connection already allows `*`,
no update is necessary. Vault 1.21 preserves omitted connection fields during
an update, including its stored password ([Vault implementation](https://github.com/hashicorp/vault/blob/v1.21.4/builtin/logical/database/path_config_connection.go#L437)).

## 3. Create the database roles in the web UI

Under **database → Roles → Create role**, choose **Dynamic**, set the default TTL
to **1h** and maximum TTL to **24h**. Supply creation statements explicitly;
an empty field produces `empty creation statements`. Leave custom renewal and
rollback statements blank.

For **postgresql-migration**, select connection **postgresql** and use:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}'
  VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION CONNECTION LIMIT 5 INHERIT;
GRANT "vault_postgresql_migration" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '30min';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE "{{name}}" SET role = 'vault_postgresql_migration';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

For **mariadb-migration**, select connection **mariadb** and use the following.
Replace `ACTUAL_MARIADB_DB` with the catalog selected by `MARIADB_DB` in Compose
(normally `mariadb`). Keep the Vault `{{...}}` placeholders unchanged.

```sql
CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'
  REQUIRE SSL WITH MAX_USER_CONNECTIONS 5;
GRANT ALL PRIVILEGES ON `ACTUAL_MARIADB_DB`.* TO '{{name}}'@'%';
```

Revocation statements:

```sql
DROP USER IF EXISTS '{{name}}'@'%';
```

## 4. Create two ACL policies

Go to **Policies → ACL Policies → Create ACL policy**. Create each policy using
the complete contents of its corresponding repository file:

| Policy name | File to paste |
| --- | --- |
| `postgresql-migration` | [postgresql-migration.hcl](../policies/postgresql-migration.hcl) |
| `mariadb-migration` | [mariadb-migration.hcl](../policies/mariadb-migration.hcl) |

Each can read only its own database credentials, renew those leases, and manage
its own token. These policies do not grant Vault administrative access.

## 5. Create two AppRoles and install their IDs

AppRole is already enabled at `approle/`. In the web UI's `>_` console, run these
commands individually. SecretIDs do not expire, as requested; database passwords
remain temporary.

```text
vault write auth/approle/role/postgresql-migration token_policies=postgresql-migration token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/mariadb-migration token_policies=mariadb-migration token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault read auth/approle/role/postgresql-migration/role-id
vault write -force auth/approle/role/postgresql-migration/secret-id
vault read auth/approle/role/mariadb-migration/role-id
vault write -force auth/approle/role/mariadb-migration/secret-id
```

On the production host, create the two directories:

```sh
mkdir -p infra/vault/private/approle/postgresql-migration infra/vault/private/approle/mariadb-migration
chmod 700 infra/vault/private infra/vault/private/approle/postgresql-migration infra/vault/private/approle/mariadb-migration
```

Use a local editor to save each role's `role_id` and `secret_id` values in these
files, with just the value on one line:

```text
infra/vault/private/approle/postgresql-migration/role-id
infra/vault/private/approle/postgresql-migration/secret-id
infra/vault/private/approle/mariadb-migration/role-id
infra/vault/private/approle/mariadb-migration/secret-id
```

Restrict the files to the operator running the helper:

```sh
chmod 600 infra/vault/private/approle/postgresql-migration/role-id infra/vault/private/approle/postgresql-migration/secret-id infra/vault/private/approle/mariadb-migration/role-id infra/vault/private/approle/mariadb-migration/secret-id
```

Do not commit these files or paste their contents into chat. If using automated
enrollment instead, `configure.py` performs all these steps, but also reconciles
all existing application roles and issues replacement SecretIDs for them.

## 6. Run migrations before deployment

Start the databases and ensure Vault is unsealed. Set the externally reachable
Vault HTTPS address, including its port if necessary:

```sh
export COMPOSE_FILE=compose.yaml:compose.production.yaml
export VAULT_ADDR=https://vault.internal.bonnybonnybonaktan.xyz
# For a private Vault CA, also set VAULT_CACERT to its CA file on this host.
docker compose up -d postgresql mariadb vault
python3 infra/vault/database/migrate.py postgresql
python3 infra/vault/database/migrate.py mariadb
docker compose up -d
```

Run each command only if the preceding command succeeds. The helper also accepts
`info` or `validate` after the database name. It uses dedicated AppRoles even if
your shell has an administrator `VAULT_TOKEN`. Flyway continues to validate the
unchanged V1/V2 checksums; it does not repair history automatically.

Normal `docker compose up` excludes migration jobs via Compose profiles. Run the
helper explicitly before deploying changes that require migrations. Direct
`docker compose run postgresql_migration` now fails early without injected
credentials. The database must already be running because the helper uses
`--no-deps`. Flyway has a maximum database lease lifetime of 24h; jobs still
running when renewal fails are stopped without automatically retrying SQL.

## Permissions and fresh installations

These identities perform schema migrations in the configured infrastructure
catalogs. They cannot provision new databases or users, and do not manage the
separate application catalogs (`itskolar_system`, `skybridge_airways`, `panel`).
PostgreSQL objects created by the helper belong to the stable migration role,
so revoking its leased login does not break ownership. To alter other existing
objects, an administrator must deliberately transfer the required ownership or
grant appropriate privileges. Do not reset the PostgreSQL role before DDL.
MariaDB routines/views that use `DEFINER` need an explicitly managed stable
definer; an expiring username must not become their lasting security identity.

V1/V2 contain privileged database/user provisioning and need an administrator
on a fresh installation. Run the explicit administrator jobs once before Vault
enrollment:

```sh
docker compose run --rm postgresql_bootstrap_migration
docker compose run --rm mariadb_bootstrap_migration
```

These jobs retain the emergency credentials from `.env`; they are excluded from
ordinary `up`. They still require the actual administrator password. Use them
only for provisioning migrations requiring administrator authority, after
reviewing the SQL. Do not grant superuser privileges to the dynamic migrator
to work around missing scope.
