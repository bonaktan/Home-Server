# Staging validation — 2026-11-04

All service runs used `compose.yaml` plus `compose.staging.yaml` on this machine.
Cloudflared remained stopped as requested. The validated stack is left running.

## Results

| Check | Result |
| --- | --- |
| Full Compose startup | 19 running services; no unhealthy containers |
| Flyway | Both databases at V2; repeated migration jobs exited 0 |
| Vault | Unsealed, authenticated operator CLI, verified TLS, healthy Docker healthcheck |
| Database management | Dedicated managers enrolled; passwords rotated through Vault, including again after services started |
| Seven AppRoles | Each can issue only its own credentials; other-role and database-management access denied |
| Renewal | Service tokens and their own database leases renew; another role's lease renewal is denied |
| Database authentication | All seven roles connect with verified TLS; wrong passwords and revoked credentials fail |
| Legacy-login cutover | Four PostgreSQL roles are NOLOGIN; original MariaDB panel account is locked |
| Real service rotation | Both exporters and the panel replace credentials at maximum TTL and recover working database access |
| Panel | Login page responds; dynamic credentials perform TLS database writes/reads using temporary tables |
| Panel supervision | PHP, nginx, queue worker and foreground cron run under supervisord |
| Panel queue | A temporary job dispatched through Redis ran in the real worker, queried the database with the worker's dynamic credentials, and wrote a completion marker; probe files and markers were removed |
| HTTPS routes | Vault, pgAdmin, Grafana, Prometheus, registry UI and panel return 200; Pi-hole redirects to its login UI |
| Wings | Local staging node authenticated to the panel; verified TLS system API accepts its token and rejects anonymous access; SFTP handshake succeeds |
| Registry | Anonymous access denied; authenticated HTTPS blob/manifest upload, fetch and manifest deletion succeed |
| Pi-hole / Redis | DNS resolution succeeds; Redis responds to PING |
| Monitoring | All six Prometheus targets up; `pg_up=1`, `mysql_up=1` |
| Logging | Promtail ready; Loki contains collected Vault container logs |
| Lease restoration | Panel and exporter roles restored to 1h initial / 24h maximum TTL |

Credential values, Vault initialization material and node tokens are omitted.
Generated TLS, AppRole and node files stay under the ignored `infra/vault/private/`.
Only the temporary registry manifest was deleted; the registry may retain its small
unreferenced test configuration blob until normal garbage collection.

## Runtime fixes found by these checks

- Removed Vault's unsupported `-sealed-code` healthcheck flag and enabled certificate verification.
- Corrected AppRole directory permissions so the unprivileged exporters can read their own identity files while the host parent directory remains private.
- Moved Laravel cache clearing after upstream environment/application-key setup.
- Kept cron under supervisord so queue, web and cron processes receive replacement credentials.
- Isolated staging Pi-hole from host networking and its port conflict with Wings.
- Corrected staging Wings API port/certificate mounts and supplied a separate local node configuration.
- Added staging nginx access, upstream and CA overrides; enabled verified panel-to-Wings HTTPS with internal DNS.
- Kept development ports on loopback and Cloudflared behind a disabled-by-default staging profile.

## Repeatable checks

After logging in to the staging Vault container CLI:

```sh
python3 infra/vault/database/tests/staging.py credentials
python3 infra/vault/database/tests/staging.py rotation
docker compose -f compose.yaml -f compose.staging.yaml ps -a
```

The rotation test interrupts the three supervised services and restores their
normal Vault role TTLs in its cleanup path. It verifies the actual service images,
not substitute child commands or a development-mode Vault instance.

## Limits

- No external PostgreSQL application deployment or its schema/table permissions was exercised; those application repositories are outside this stack.
- No game server was installed or run. Wings validation covers panel authentication, system API, Docker initialization and the SFTP listener, not a game workload or authenticated file transfer.
- The public tunnel, external nginx application upstreams and remote Grafana data sources were not exercised during this local-only validation.
- Flyway 10.22.0 warns that PostgreSQL 18.6 and MariaDB 11.8 are newer than its tested versions. Both fresh and repeated migrations succeeded here; this does not establish broader Flyway version support.
