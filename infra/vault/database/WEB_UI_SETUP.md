# Production Vault setup through the web UI

This is the manual alternative to running `configure.py`. It uses the current
repository's database roles and service policies. It does not run the enrollment
script or use the staging test script.

For the two dedicated Flyway identities, follow the additional
[dynamic migration setup](DYNAMIC_MIGRATIONS.md) after completing this guide.
That guide also covers adding them to an existing production Vault without
replacing application SecretIDs. Initial V1/V2 provisioning uses the explicit
`postgresql_bootstrap_migration` and `mariadb_bootstrap_migration` jobs.

The database preparation and final identity-file installation happen outside
Vault's web UI. Database connections, dynamic roles and ACL policies use the UI;
AppRole commands use its built-in browser console (`>_`). The browser console is
not an operating-system shell: run each command separately, without shell loops,
file redirection or environment-variable expansion.

## 1. Confirm the prerequisites

- Both production Flyway migrations have reached V2 successfully.
- Vault is initialized and unsealed.
- The production database TLS files exist under `infra/vault/private/database-tls`.
- Vault mounts the public database CA at `/vault/database-ca.pem`.
- Open `https://vault.internal.bonnybonnybonaktan.xyz/ui/` from your allowed LAN
  and log in with an administrator token. The initial root token can perform setup.

These instructions assume the two database connections have not already been
configured. If they exist, inspect them before making changes. Do not reset the
SQL management passwords behind an existing Vault connection.

## 2. Prepare the SQL management accounts — database administrator session

V2 creates PostgreSQL's `vault_manager` with NOLOGIN and MariaDB's account locked.
The UI cannot log in until you explicitly enroll these SQL accounts.

Generate two different temporary random passwords using a password manager.
Use a long hexadecimal value to avoid SQL quoting problems. Keep them private.

Run this as the PostgreSQL administrator, for example through pgAdmin:

```sql
ALTER ROLE vault_manager LOGIN PASSWORD 'REPLACE_WITH_POSTGRESQL_TEMPORARY_PASSWORD';
```

Run this as the MariaDB administrator:

```sql
ALTER USER 'vault_manager'@'%' IDENTIFIED BY 'REPLACE_WITH_MARIADB_TEMPORARY_PASSWORD' ACCOUNT UNLOCK;
```

These are database SQL statements, not commands for Vault's `>_` console.
Do not use the PostgreSQL superuser or MariaDB root account as Vault's connection
identity. The V2 migrations have already granted the manager permissions needed
for the roles below.

## 3. Enable the database engine — Vault UI

Choose **Secrets Engines → Enable new engine → Databases**. Use the mount path
`database` and enable it. If the mount already exists, open it instead.

## 4. Create the PostgreSQL connection — Vault UI

Under `database`, choose **Create connection** and enter:

| Field | Value |
| --- | --- |
| Connection name | `postgresql` |
| Database plugin | PostgreSQL / `postgresql-database-plugin` |
| Username | `vault_manager` |
| Password | Temporary PostgreSQL manager password from step 2 |
| Verify connection | Enabled |
| Username template, when exposed | `v_{{random 24}}` |
| Allowed roles | `itskolar-admin,itskolar-worker,skybridge-admin,skybridge-worker,postgresql-exporter` |

Connection URL:

```text
postgresql://{{username}}:{{password}}@postgresql:5432/POSTGRES_DB_VALUE?sslmode=verify-full&sslrootcert=/vault/database-ca.pem
```

Replace only `POSTGRES_DB_VALUE` with the actual `POSTGRES_DB` value from your
production `.env` (for example `postgres`). The UI does not expand shell variables.
Leave `{{username}}` and `{{password}}` exactly as shown. The CA path is inside the
Vault container. Do not set `sslmode=disable` or disable connection verification.

Save. When offered root-credential rotation, choose **Rotate and enable** (or
**Rotate root credentials** in the connection's actions). This rotates the
configured `vault_manager` password; "root" is the Vault operation's name, not
an instruction to use the PostgreSQL superuser.

After successful rotation, discard the temporary password. Vault now owns the
replacement password. Do not write the old password back into this connection.

## 5. Create the MariaDB connection — Vault UI

Create another connection:

| Field | Value |
| --- | --- |
| Connection name | `mariadb` |
| Database plugin | MySQL/MariaDB / `mysql-database-plugin` |
| Username | `vault_manager` |
| Password | Temporary MariaDB manager password from step 2 |
| Verify connection | Enabled |
| Username template, when exposed | `v_{{random 24}}` |
| Allowed roles | `pterodactyl,mariadb-exporter` |
| TLS CA | Full public PEM contents of `infra/vault/private/database-tls/ca.pem` |

Connection URL:

```text
{{username}}:{{password}}@tcp(mariadb:3306)/
```

Supply the **contents** of the public CA certificate in the TLS CA field, or use
its file-upload control. Do not enter a host filesystem path as the CA contents.
Do not upload `ca-key.pem`, `server-key.pem`, or any other private key. Leave
insecure TLS / skip-verification options disabled.

Save, rotate the configured management credential, and discard the temporary
password after rotation succeeds.

If your UI does not expose a listed advanced field, do not replace it with a
similarly named setting. A missing username-template field can keep the plugin's
safe default username format; the Agents accept the returned username. TLS CA
and connection verification must be configured before saving the MariaDB connection.

## 6. Create the dynamic database roles — Vault UI

Open **database → Roles → Create role** for each role below. Select **Dynamic**,
select its database connection, and set **Default TTL = 1h** and **Max TTL = 24h**.
Paste the SQL into the creation and revocation statement fields. Leave custom
renewal/rollback statements blank so the plugin uses its defaults.

Keep `{{name}}`, `{{password}}`, and `{{expiration}}` unchanged: Vault supplies
those values when issuing credentials. PostgreSQL roles inherit existing stable
application grants; this setup does not create missing application schemas or
grant missing schema/table permissions. Admin statements switch to the stable
owner role so objects are not owned by an expiring login.

### itskolar-admin

Database connection: `postgresql`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT -1 INHERIT;
GRANT "ITskolar-System_Admin" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '5min';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE "{{name}}" SET role = 'ITskolar-System_Admin';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

### itskolar-worker

Database connection: `postgresql`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 20 INHERIT;
GRANT "ITskolar-System_Worker" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '30s';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

### skybridge-admin

Database connection: `postgresql`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT -1 INHERIT;
GRANT "Skybridge-Airways_Admin" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '5min';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE "{{name}}" SET role = 'Skybridge-Airways_Admin';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

### skybridge-worker

Database connection: `postgresql`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 20 INHERIT;
GRANT "Skybridge-Airways_Worker" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '30s';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

### postgresql-exporter

Database connection: `postgresql`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 5 INHERIT;
GRANT "vault_postgresql_exporter" TO "{{name}}";
ALTER ROLE "{{name}}" SET statement_timeout = '30s';
ALTER ROLE "{{name}}" SET idle_in_transaction_session_timeout = '60s';
```

Revocation statements:

```sql
DROP ROLE IF EXISTS "{{name}}";
```

### pterodactyl

Database connection: `mariadb`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}' REQUIRE SSL WITH MAX_USER_CONNECTIONS 30;
GRANT ALL PRIVILEGES ON panel.* TO '{{name}}'@'%';
```

Revocation statements:

```sql
DROP USER IF EXISTS '{{name}}'@'%';
```

### mariadb-exporter

Database connection: `mariadb`. Default TTL: `1h`. Maximum TTL: `24h`.

Creation statements:

```sql
CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}' REQUIRE SSL WITH MAX_USER_CONNECTIONS 3;
GRANT SELECT, PROCESS, REPLICATION CLIENT, SLAVE MONITOR ON *.* TO '{{name}}'@'%';
```

Revocation statements:

```sql
DROP USER IF EXISTS '{{name}}'@'%';
```

Before continuing, confirm the saved role actually contains the SQL. In the
browser console, inspect the three local service roles:

```text
vault read database/roles/pterodactyl
vault read database/roles/mariadb-exporter
vault read database/roles/postgresql-exporter
```

Each must have a non-empty `creation_statements` value and the expected `db_name`.
If the form uses an Add control for a statement, commit the entry before saving.
SQL saved on a connection or left in an unsaved form does not configure a role.
An issuance error `empty creation statements` means this role needs correction;
it is separate from AppRole login authentication.

## 7. Install the ACL policies — Vault UI

Open **Policies → ACL Policies → Create ACL policy**. For each name below, paste
all of the corresponding HCL file's contents and save. Keep every policy's name
exactly as shown. The policies allow reading only the matching credential role,
renewing that role's leases, and managing the caller's own token.

| Policy name | Repository file |
| --- | --- |
| `itskolar-admin` | [policies/itskolar-admin.hcl](../policies/itskolar-admin.hcl) |
| `itskolar-worker` | [policies/itskolar-worker.hcl](../policies/itskolar-worker.hcl) |
| `skybridge-admin` | [policies/skybridge-admin.hcl](../policies/skybridge-admin.hcl) |
| `skybridge-worker` | [policies/skybridge-worker.hcl](../policies/skybridge-worker.hcl) |
| `postgresql-exporter` | [policies/postgresql-exporter.hcl](../policies/postgresql-exporter.hcl) |
| `pterodactyl` | [policies/pterodactyl.hcl](../policies/pterodactyl.hcl) |
| `mariadb-exporter` | [policies/mariadb-exporter.hcl](../policies/mariadb-exporter.hcl) |

## 8. Enable AppRole and create service identities — Vault UI and browser console

Open **Access → Auth Methods → Enable new method → AppRole**, using path `approle`.
Skip enabling it if it is already present.

Open the UI's **`>_` console**. Run each of these separately:

```text
vault write auth/approle/role/itskolar-admin token_policies=itskolar-admin token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/itskolar-worker token_policies=itskolar-worker token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/skybridge-admin token_policies=skybridge-admin token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/skybridge-worker token_policies=skybridge-worker token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/postgresql-exporter token_policies=postgresql-exporter token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/pterodactyl token_policies=pterodactyl token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
vault write auth/approle/role/mariadb-exporter token_policies=mariadb-exporter token_no_default_policy=true token_period=1h token_num_uses=0 secret_id_ttl=0 secret_id_num_uses=0
```

These use renewable 1h periodic tokens, non-expiring SecretIDs with unlimited
authentications, and exactly one service policy. No root/admin policy or default
policy is attached. The SecretID remains a long-lived credential that must be
protected and revoked/replaced if compromised.

Fetch each service's RoleID and generate its SecretID in the same browser console:

```text
vault read auth/approle/role/itskolar-admin/role-id
vault write -force auth/approle/role/itskolar-admin/secret-id
vault read auth/approle/role/itskolar-worker/role-id
vault write -force auth/approle/role/itskolar-worker/secret-id
vault read auth/approle/role/skybridge-admin/role-id
vault write -force auth/approle/role/skybridge-admin/secret-id
vault read auth/approle/role/skybridge-worker/role-id
vault write -force auth/approle/role/skybridge-worker/secret-id
vault read auth/approle/role/postgresql-exporter/role-id
vault write -force auth/approle/role/postgresql-exporter/secret-id
vault read auth/approle/role/pterodactyl/role-id
vault write -force auth/approle/role/pterodactyl/secret-id
vault read auth/approle/role/mariadb-exporter/role-id
vault write -force auth/approle/role/mariadb-exporter/secret-id
```

Keep only `role_id` and `secret_id` for delivery to the service. The
`secret_id_accessor` is an identifier for managing/revoking the SecretID; it is
not the service's login secret. Do not send these values in chat or commit them.

## 9. Install identity files — production Docker host

The UI cannot place files on the Docker host. For the three services in this
Compose stack, create their directories from the production repository root:

```sh
umask 077
mkdir -p infra/vault/private/approle
chmod 700 infra/vault/private
for service in postgresql-exporter mariadb-exporter pterodactyl; do
  mkdir -p "infra/vault/private/approle/$service"
  chmod 755 "infra/vault/private/approle/$service"
done
```

Use a local editor to create these two files in each service's directory:

| Filename | Contents |
| --- | --- |
| `role-id` | That service's returned `role_id` value, with no label or quotes |
| `secret-id` | That service's returned `secret_id` value, with no label or quotes |

Do not paste the SecretID into a shell command that will be saved in shell history.
After saving the files:

```sh
chmod 444 infra/vault/private/approle/postgresql-exporter/role-id infra/vault/private/approle/postgresql-exporter/secret-id
chmod 444 infra/vault/private/approle/mariadb-exporter/role-id infra/vault/private/approle/mariadb-exporter/secret-id
chmod 444 infra/vault/private/approle/pterodactyl/role-id infra/vault/private/approle/pterodactyl/secret-id
```

The private parent directory is host-owner-only. The individual mounted service
directories/files are readable by the exporters' unprivileged users. Never mount
the whole private directory into a service.

Deliver each external PostgreSQL application's own RoleID/SecretID to that
application's deployment through its secret-delivery mechanism. Do not give an
application another service's identity or a Vault administrator token.

## 10. Start and verify — production Docker host and Vault UI

From the production repository root:

```sh
export COMPOSE_FILE=compose.yaml:compose.production.yaml
docker compose up -d --build postgresql_exporter mariadb_exporter pterodactyl
docker compose ps
docker compose logs --tail=50 postgresql_exporter mariadb_exporter pterodactyl
```

The current implementation still builds three Agent-enabled images. The
original-image/sidecar alternative has not been implemented.

In Vault, open each database role and use **Generate credentials** to confirm
issuance works. Treat the displayed values as secrets; revoke temporary test
leases afterward through the UI's lease management. Confirm the panel can serve
requests and perform database operations, and both exporters report successful
scrapes (`pg_up=1` and `mysql_up=1`).

Keep legacy logins until every deployment has moved successfully. Use the separate
cutover SQL files only after verification, especially for the external PostgreSQL
applications. AppRole SecretIDs do not expire; revoke/replace them if compromised
or when retiring a deployment. Vault Agent continues renewing its tokens and
rotating the database credentials independently.

## Existing AppRoles: change to non-expiring SecretIDs

Use this section if you already created identities with the earlier 30-day setting.
Changing the role default affects newly issued SecretIDs; existing IDs retain their
original expiry. RoleIDs, ACL policies and database credential TTLs stay the same.

In the Vault UI's `>_` console, run the commands for each existing service role.
The dedicated property endpoint updates only the SecretID TTL:

```text
vault write auth/approle/role/itskolar-admin/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/itskolar-worker/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/skybridge-admin/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/skybridge-worker/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/postgresql-exporter/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/pterodactyl/secret-id-ttl secret_id_ttl=0
vault write auth/approle/role/mariadb-exporter/secret-id-ttl secret_id_ttl=0
```

For each role, generate a replacement SecretID. For example:

```text
vault write -force auth/approle/role/pterodactyl/secret-id
```

Verify the response has `secret_id_ttl = 0` and `secret_id_num_uses = 0`.
Install the returned `secret_id` in that service's existing `secret-id` file.
Do not replace its `role-id` file or paste the new SecretID into shell history.
For Pterodactyl, use the production host editor between these commands:

```sh
chmod 600 infra/vault/private/approle/pterodactyl/secret-id
# Edit the file to contain only the new secret_id value.
chmod 444 infra/vault/private/approle/pterodactyl/secret-id
```

Repeat for `postgresql-exporter` and `mariadb-exporter`, and deliver each external
application's replacement identity to its own deployment. Then verify new
logins by restarting the three local Agents during an acceptable interruption:

```sh
docker compose -f compose.yaml -f compose.production.yaml restart postgresql_exporter mariadb_exporter pterodactyl
```

Once replacement authentication succeeds, revoke the old SecretIDs through their
accessors if you retained them. Otherwise, the old 30-day IDs expire at their
original deadlines. New non-expiring IDs require explicit revocation if retired
or compromised; creating another ID does not automatically revoke them.

## Sources and limits

- [HashiCorp database UI walkthrough](https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets)
- [Database connection and role API](https://developer.hashicorp.com/vault/api-docs/secret/databases)
- [MySQL/MariaDB TLS parameters](https://developer.hashicorp.com/vault/api-docs/secret/databases/mysql-maria)
- [AppRole browser-console walkthrough](https://developer.hashicorp.com/vault/tutorials/auth-methods/approle)
- [AppRole API and SecretID TTL settings](https://developer.hashicorp.com/vault/api-docs/auth/approle)

Connection values, SQL and policy names come from this repository. The role SQL
in this guide was copied from `configure.py`'s role definitions. UI labels can
vary with version. This document configures production; only staging was exercised
in the earlier validation record. No production settings were changed by writing
this guide.
