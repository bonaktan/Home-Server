# Dynamic database credentials

This is a staged migration for PostgreSQL 18, MariaDB 11 and Vault 1.21. Nothing
here deploys to a server automatically. Back up both databases and Vault before
running the cutover. Use Docker Compose v2 with `!override` support, Python 3 and OpenSSL.

MariaDB V1 is preserved exactly as originally applied, with Flyway checksum
`-2027749246`. Later edits to its password clause caused checksum mismatches;
those edits have been reverted. An existing database recording `-2027749246`
can migrate without repairing its history. Never edit an applied migration to
change a password; use Vault or a new versioned migration.

An environment that already recorded an edited V1 (for example `-27116424`)
needs separate review before reconciling its history with `flyway repair`.
Repair updates migration metadata; it does not apply the SQL differences.
Do not repair a failed/partial migration blindly or disable checksum validation.

Vault gets a dedicated `vault_manager` account in each database, never the
database bootstrap/root account. V2 creates these accounts without usable
logins. Enrollment generates random passwords in memory, sends them through
the local database socket and Vault's verified HTTPS API, then immediately
rotates them through Vault. Reruns preserve Vault's stored management passwords.

PostgreSQL's manager has CREATEROLE and ADMIN OPTION on the five service
roles, without inheriting them. MariaDB's manager needs CREATE USER plus grant
authority for `panel.*` and exporter monitoring privileges. MariaDB's exporter
requires global SELECT; this identity can read application data and must be
treated as privileged. Neither application nor exporter gets GRANT OPTION.
Migration enrollment adds a sixth PostgreSQL group and MariaDB grant authority
on the configured infrastructure catalog, for the two dedicated Flyway identities.

## Policies and roles

Each policy in [../policies](../policies) allows reading exactly one credential
endpoint, renewing that role's leases, and managing the caller's own token.
It grants no database configuration, policy administration or other-service access.

| Policy / AppRole | Credential endpoint | Database privileges |
| --- | --- | --- |
| `itskolar-admin` | `database/creds/itskolar-admin` | Existing `ITskolar-System_Admin` role |
| `itskolar-worker` | `database/creds/itskolar-worker` | Existing `ITskolar-System_Worker` role |
| `skybridge-admin` | `database/creds/skybridge-admin` | Existing `Skybridge-Airways_Admin` role |
| `skybridge-worker` | `database/creds/skybridge-worker` | Existing `Skybridge-Airways_Worker` role |
| `postgresql-exporter` | `database/creds/postgresql-exporter` | `pg_monitor` |
| `pterodactyl` | `database/creds/pterodactyl` | All privileges on `panel.*` |
| `mariadb-exporter` | `database/creds/mariadb-exporter` | SELECT, PROCESS, REPLICATION CLIENT, SLAVE MONITOR; 3 connections |
| `postgresql-migration` | `database/creds/postgresql-migration` | Stable schema owner in `POSTGRES_DB`; 5 connections |
| `mariadb-migration` | `database/creds/mariadb-migration` | All privileges on `MARIADB_DB` only; 5 connections |

For an existing production deployment, follow [Flyway with dynamic credentials](DYNAMIC_MIGRATIONS.md)
to add the two identities through the Vault UI and run migrations. Ordinary
`docker compose up` excludes migration jobs; use `migrate.py` explicitly before
deploying changes that require them. No custom Flyway image is built.

The four application role names are retained to preserve existing grants and
object ownership. V2 grants CONNECT to their databases. It does not replay the
commented-out schema grants in V1: application migrations must already have
assigned the required schema/table privileges to those stable roles.
Admin logins automatically SET ROLE to the stable role so DDL does not leave
objects owned by an expiring username. Do not RESET ROLE before creating objects.
Workers cannot create objects unless the existing role's grants allow it.

## Bootstrap and verify


Run from the repository root. Keep the same `COMPOSE_FILE` selection for all
commands and future deployments:

`compose.yaml` contains the shared database TLS and Vault Agent configuration.
Production overrides the host certificate paths; staging adds published ports
and uses the local certificates in `infra/certs`. Both require the same bootstrap.
Staging publishes its development ports on loopback, puts Pi-hole on a bridge
network, and leaves Cloudflared disabled behind the `tunnel` profile. Its nginx
overrides allow local Docker bridge clients and trust the local Vault certificate.

```sh
export COMPOSE_FILE=compose.yaml:compose.production.yaml
# For staging instead:
# export COMPOSE_FILE=compose.yaml:compose.staging.yaml
# export VAULT_CACERT="$PWD/infra/certs/fullchain.pem"

sh infra/vault/database/generate-tls.sh
docker compose up -d postgresql mariadb vault
# Initialize/unseal Vault using the existing operations instructions if needed.
# Fresh databases only: V1/V2 require administrator provisioning permissions.
docker compose run --rm postgresql_bootstrap_migration
docker compose run --rm mariadb_bootstrap_migration

export VAULT_ADDR=https://vault.internal.bonnybonnybonaktan.xyz
python3 infra/vault/database/configure.py
python3 infra/vault/database/migrate.py postgresql
python3 infra/vault/database/migrate.py mariadb
docker compose up -d --build postgresql_exporter mariadb_exporter pterodactyl
```

For staging, enrollment can instead use the Vault CLI already in the container.
Initialize/unseal Vault and log in locally first; never send keys or tokens in chat:

```sh
export COMPOSE_FILE=compose.yaml:compose.staging.yaml
vault_stage() {
  docker compose exec \
    -e VAULT_ADDR=https://127.0.0.1:8200 \
    -e VAULT_CACERT=/vault/tls/fullchain.pem \
    -e VAULT_TLS_SERVER_NAME=vault.internal.bonnybonnybonaktan.xyz \
    vault vault "$@"
}
# Fresh Vault only: vault_stage operator init
# vault_stage operator unseal    # repeat with the required distinct keys
vault_stage login
python3 infra/vault/database/tests/staging.py bootstrap
```

Staging Wings uses `infra/vault/private/wings/config.yml`, exported from a node
created in the **staging** panel. Set its remote URL to `http://pterodactyl`, API
port to `8443`, and certificate/key paths to
`/etc/letsencrypt/live/bonnybonnybonaktan.xyz/{fullchain,privkey}.pem`.
The staging node hostname `homeservernode.bonnybonnybonaktan.xyz` resolves to
Wings internally; the panel trusts the staging certificate through the standard
system CA store. The existing node configuration under `infra/pterodactyl/etc`
is not used for staging Wings. Keep the generated node token private.

The script prompts privately for a Vault administrator token. It needs permission
to enable the database engine and AppRole auth, configure/rotate the two database
connections, and write the nine roles and policies. This token is never mounted
into a workload. Run enrollment on the Docker host where the repository and
Compose project live, with the same environment/project selection as deployment.
Only use this bootstrap on a `database/` mount owned by this repository; existing
connections with the same names are preserved rather than overwritten.

The CA key and server keys are under ignored `infra/vault/private/database-tls`.
Move the CA key to offline storage after issuing the server certificates. Public
CA certificates may be distributed to clients; never mount the CA private key or
database server keys into Vault or applications. Server certificates expire after
365 days: renew with the same CA and restart the databases. The generator refuses
to overwrite an existing CA. Vault and its agents verify database and Vault
certificates; no insecure TLS option is used. PostgreSQL rejects plaintext
management logins, and MariaDB management/dynamic accounts require SSL.

Confirm both exporters report successful scrapes and the panel can read and write
its database. Verify issuance and revocation for each external application too.
Do not bring up the exporters/panel before enrollment: Agent waits for Vault and
valid identity files. Vault must be unsealed to issue or renew credentials.

## External PostgreSQL applications

Their application code is not in this repository. Copy only the matching
`infra/vault/private/approle/SERVICE` directory to each deployment through your
secret-delivery mechanism. Keep the host `private/` parent mode 0700; the individual
mounted directories and files are readable by unprivileged container processes.
Never mount the entire `private/` tree into a service.

Use the exporter Agent configuration as the pattern: change the credential path,
environment variable names and supervised command for the application. Both
username and password templates must reference the same path. Connect to
`itskolar_system` or `skybridge_airways` with `sslmode=verify-full` and the database
CA. The generated certificates cover Docker names `postgresql` and `mariadb`;
issue certificates for additional DNS names if deployments connect differently.
Attach local clients to `vault_clients` and `shared_infra_database` as required;
do not attach applications to Vault's `vault_database` management network.

Credentials have a 1h initial TTL and 24h maximum TTL. Vault Agent renews leases
and obtains replacements at maximum TTL, restarting the supervised process when
credentials change. This closes old connections and refreshes connection pools.
An application using Vault directly must implement the equivalent behavior;
reading credentials once at startup is insufficient. Restarts can briefly interrupt
requests. Database revocation prevents new logins; it does not terminate already
authenticated sessions. Drain/restart all consumers when revoking a compromised lease.

AppRole tokens are renewable with a 1h period and have no default policy. Secret
IDs do not expire and permit unlimited authentications, including after a process
or container restart. They are long-lived bootstrap credentials: protect their
files and revoke/replace them if compromised or when retiring a deployment.
Issuing a new SecretID does not revoke older IDs. Use AppRole's secret-id-accessor
API to revoke IDs that are no longer needed.

Changing an AppRole's default TTL does not remove the expiry from existing IDs.
For roles created with the previous 30-day setting, follow the
[web UI migration instructions](WEB_UI_SETUP.md#existing-approles-change-to-non-expiring-secretids)
to change the default, issue replacement IDs and install them. The RoleIDs stay
the same. Database credentials remain dynamic with their original 1h/24h TTLs.

## Disable the old logins

After every deployment has been tested, apply the explicit cutover files:

```sh
docker compose exec -T postgresql sh -ec 'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < infra/vault/database/postgresql-cutover.sql
docker compose exec -T mariadb sh -ec 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mariadb -uroot' < infra/vault/database/mariadb-cutover.sql
```

Restart/drain old sessions, remove legacy application passwords from deployment
secrets and the panel's persisted `.env`, and ensure no cached Laravel database
configuration remains. The panel wrapper clears its config cache before starting.
Do not delete its APP_KEY or other application settings.

Database initialization and the explicit `*_bootstrap_migration` jobs retain the
emergency administrator credentials from `.env`. Regular Flyway jobs use dedicated
Vault leases through `migrate.py`; privileged provisioning SQL still needs a
reviewed administrator operation. Remove `.env` access from application containers. CloudBeaver is an interactive
tool: users obtain their own scoped credentials rather than a shared superuser login.
Services without database access need no database ACL policy.

Rollback before disabling legacy logins: stop consumers and restore the previous
base and environment Compose configuration from version control. After disabling them, a database administrator must deliberately
restore LOGIN/passwords (PostgreSQL) or unlock/reset the old MariaDB account before
using the old deployment. Keep the databases' TLS configuration and Vault leases
until all dynamic sessions have drained. Never drop the stable PostgreSQL roles.

## Validation

```sh
docker compose -f compose.yaml -f compose.production.yaml config --quiet
docker compose -f compose.yaml -f compose.staging.yaml config --quiet
python3 infra/vault/database/tests/integration.py
python3 -m unittest discover -s infra/vault/database/tests -p test_migrate.py -v
```

The integration check creates disposable containers/network, loads both Flyway
SQL sets, enrolls and rotates managers twice, then tests every service's TLS login,
ACL isolation and lease revocation. It applies the cutover to the disposable data
and removes its containers/network on exit. It does not use production volumes.

To validate the **actual staging deployment**, use:

```sh
python3 infra/vault/database/tests/staging.py credentials
python3 infra/vault/database/tests/staging.py rotation
docker compose -f compose.yaml -f compose.staging.yaml ps -a
```

These commands pin `compose.yaml` and `compose.staging.yaml`. Credential checks
exercise all nine real AppRoles after enrollment, token/lease renewal, ACL denial, verified TLS,
incorrect-password rejection, and revocation. Rotation temporarily sets the panel
and exporters to 60s initial / 120s maximum leases and restarts them, verifies
replacement usernames with successful exporter scrapes and panel HTTP/database
read-write probes, then restores the original TTLs and restarts the Agents.
Run this only when interruptions to the local staging services are acceptable.
The latest results are in [the staging validation record](tests/STAGING_VALIDATION.md).

References: [database engine](https://developer.hashicorp.com/vault/docs/secrets/databases),
[Agent process supervision](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/process-supervisor),
[AppRole auto-auth](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle).
