# ITskolar database connectivity investigation

Date: 2026-11-01. Scope: read-only inspection of `home-server-alt`, primarily `/srv/ITskolar-System`, with infrastructure and planned Skybridge dependencies. This is evidence for the EGM refactor, not a deployed fix.

## Findings

The current ITskolar connection failure is reproducible and has a confirmed authentication blocker. Its PostgreSQL worker role has no password set. A separate permission check confirms that the worker also lacks `CONNECT` on its database, so setting a password alone would leave another blocker. The expected application schemas are absent as well.

Networking from the current bot container to PostgreSQL works. A separate discrepancy between the deployment workflow and production Compose networking could explain losing connectivity after a future deployment, but no historical deployment was replayed and that is not a proven cause of an earlier outage.

## Observed deployment

The SSH alias resolves to the current Atom server, which identifies itself as `home-server` and runs Debian 13. Infrastructure is under `/srv/Home-Server`. The affected bot is under `/srv/ITskolar-System`; `/srv/Skybridge-Airways` is a planned shared-PostgreSQL consumer.

| Component | Observed state |
| --- | --- |
| Infrastructure PostgreSQL | Running as `infra-postgresql`, image `postgres:18-alpine`, attached to `home-server_shared_infra_database`. Port 5432 is not published to the host. |
| Infrastructure MariaDB | Running as `infra-mariadb`, image `mariadb:11`, attached to the shared database network. Port 3306 is not published to the host. MariaDB authentication was not tested in this investigation. |
| ITskolar bot | Running as `itskolarbot-discord`, attached to its frontend/backend networks and `home-server_shared_infra_database`. Docker labels identify both base and production Compose files as its configuration. |
| Bot database endpoint | `infra-postgresql:5432`, database `itskolar_system`, role `ITskolar-System_Worker`. The consumer has a nonempty password value, which was not displayed. |
| Bot feature setting | Its running environment has `ENV=PRODUCTION` and `ENABLE_DB=False`. Relevant source checks use the exact string `True` to enable database features. A running container therefore does not establish database readiness. |
| Existing CI | Two GitHub Actions runner systemd services are active, associated with PUP-ITskolar and RHES-Staff. CI is already part of the running host. |

## Checks and results

The connection probe ran inside the existing bot container using its existing environment. It did not import the application's `Database` wrapper or change its feature flag. The PostgreSQL connection requested a read-only session, a five-second connection timeout, and a five-second statement timeout. Password values and password hashes were not printed or saved in this report.

| Check | Result | Meaning |
| --- | --- | --- |
| Resolve `infra-postgresql` from the bot | Resolved to the PostgreSQL container's current address on the shared database network. | Current service discovery works. The observed address is ephemeral and must not become configuration. |
| Open TCP connection to port 5432 | Successful. | The current consumer-to-database transport path works. |
| Authenticate with the bot's configured credentials | Failed with password authentication failure. | The current failure is beyond DNS and TCP connectivity. |
| Inspect account metadata, without reading out hashes | Both ITskolar admin/worker roles have login enabled but no password set. | Password authentication cannot succeed for these roles. PostgreSQL explicitly documents this behavior in [CREATE ROLE](https://www.postgresql.org/docs/18/sql-createrole.html). |
| Check database privilege with `has_database_privilege` | Both ITskolar roles lack `CONNECT` to `itskolar_system`. | Once authentication is repaired, database access remains blocked. `CONNECT` is checked separately at startup; see [PostgreSQL privileges](https://www.postgresql.org/docs/18/ddl-priv.html). |
| Inspect database ownership/ACL | `itskolar_system` is owned by `postgres`; its explicit ACL grants privileges only to `postgres`. | Intended application permissions are not provisioned. |
| Check named application schemas | `application` and `student` do not exist in `itskolar_system`. | Re-enabling database features needs an application schema readiness check as well as a login check. No application table contents were read. |
| Check `public.flyway_schema_history` in the application database | Absent. | This database has no history table at that specific default location. This does not prove that Flyway never ran elsewhere or that no other migration mechanism exists. |
| Compare connection module on disk with the image | The file hashes match. | The inspected database connection wrapper matches that module in the running bot image. This is not a whole-image source verification. |

The expected Skybridge admin/worker roles already exist in the shared instance. Both also lack passwords and `CONNECT` to `skybridge_airways`; that database is owned by `postgres`. This is a confirmed provisioning gap for the planned integration, not an observed failure of a running Skybridge shared-database connection.

## Configuration evidence

### Provisioning and migrations

`/srv/Home-Server/infra/migration/postgresql/V1__ITskolarSystem-Skybridge.sql` creates both applications' admin/worker roles without assigning passwords. It creates the databases and revokes database access from `PUBLIC`, while the application access grants and schema/table statements are commented out. The catalog observations are consistent with those active statements; the inspection does not establish the complete history of changes to the database.

The refactor needs to define a repeatable way to create databases, establish ownership and privileges, set or rotate credentials, deliver them to consumers, and validate a real login. Application schema migration must have its own owner and supported procedure. Merely moving the consumer password into a secret manager would not set the database role's password or grant its permissions.

The bot connection wrapper at `/srv/ITskolar-System/ITskolarBot/src/bot/features/database.py:25` calls `psycopg2.connect` using the environment. Its broad exception handler raises the generic message `Cannot connect to the database.` The design should preserve actionable failure categories and safe context in logging. Python may retain exception context; whether existing logging displays it was not established, so this report does not claim that the original exception is irretrievable.

### Deployment configuration mismatch

The ITskolar workflow at `/srv/ITskolar-System/.github/workflows/docker-image.yml` runs `docker compose build` and `docker compose up -d` from the application directory without explicit Compose file arguments.

Rendering the configurations without starting anything shows:

| Compose inputs | Bot's configured networks |
| --- | --- |
| `compose.yaml` | Application frontend and backend only. |
| `compose.yaml` plus `compose.production.yaml` | Application frontend, backend, and the external shared database network. |

The running bot has the production configuration. The application root `.env` contains no `COMPOSE_FILE` setting, and neither inspected runner `.env` contains one. The workflow has no explicit override. The complete environment inherited by a running job was not inspected, so an override supplied elsewhere remains possible.

This is a deployment risk: the workflow's default configuration lacks the shared database attachment. It is not proof that a particular past workflow removed that attachment. The refactor needs one explicit, reviewable production deployment invocation and a post-deployment database check. Docker documents external networks and service discovery in [Compose networking](https://docs.docker.com/compose/how-tos/networking/).

### Skybridge integration is still pending

`/srv/Skybridge-Airways/compose.yaml` still declares its own PostgreSQL service, application database volume, and Flyway job. The backend and migration job depend on that local service; the file does not attach them to the infrastructure's shared database network. Switching to the shared instance will require coordinated endpoint, networking, role/credential, migration, and data handling decisions.

Its workflow still names `/srv/Flight-Management-System` as the working directory. This differs from the supplied project location and must be resolved before treating it as a working deployment recipe.

## Consequences for the EGM design

* Treat reachability, authentication, privileges, and schema readiness as separate onboarding checks.
* Establish a repeatable provisioning and credential-delivery process. The choice of shared versus per-application database processes remains open; this incident establishes incomplete provisioning, not a requirement to change topology.
* Preserve the intentional rejection of cross-application access while granting each application the access it needs. Do not solve onboarding by giving runtime consumers the shared database superuser.
* Give each application an explicit migration owner and deployment sequence. Account/database provisioning and application schema evolution need different permissions and recovery procedures.
* Make the production Compose inputs explicit in CI and validate the consumer's effective network attachment after deployment.
* Account for existing self-hosted runners, build load, and workflow authors' access in the CI design.

## Limits and actions left for implementation

No passwords, grants, schemas, feature flags, Compose files, workflows, or running services were changed. No migrations, builds, or deployment workflows were run. Catalog metadata was read; application records were not queried. The observed auth/permission/schema blockers remain present.

This was not a complete PostgreSQL/MariaDB audit, migration-history reconstruction, host OS drift inventory, or Actions security review. A bounded scan of recent bot log lines was not sufficient to attribute historical timeout messages to PostgreSQL, and no such attribution is made.

The local codebase-memory project does not index these remote application trees. Coverage checks reported the remote paths outside the project; the cited configurations and connection module were inspected directly over SSH, and relevant feature-flag literals were searched directly. The local counterpart of the provisioning SQL has partial graph coverage at its two `REVOKE` lines; both affected source ranges were read directly. No complete remote code structure or call-graph claim is made.
