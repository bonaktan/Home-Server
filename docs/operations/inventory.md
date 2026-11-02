# Infrastructure inventory

Status: **incomplete; not a production-change authorization**. Observations are dated and must be refreshed before use. The 2026-11-01 [host](../investigations/2026-11-01-debian-host-baseline.md) and [database](../investigations/2026-11-01-database-connectivity.md) investigations preserve the detailed evidence and limitations; this register does not turn unknown history into fact.

## Atom

Read-only SSH on 2026-11-02 identified `home-server` (alias `home-server-alt`), Debian 13.7, kernel `6.12.113+deb13-amd64`. Active management paths include Wi-Fi `wlp1s0` and Tailscale; an independent recovery route has not been tested. Infrastructure is under `/srv/Home-Server`. `networking` and `systemd-resolved` ownership, persisted wired configuration, boot/driver settings, APT integration and the Pi-hole path are documented in the host investigation. Effective privileged firewall rules, complete schedules, package/repository inventory, firmware and loaded driver settings remain unknown. Do not apply the repository's old network assumptions to the live host.

Running Compose projects observed: `home-server`, `itskolar-system`, `pearl-horizon-airlines`. The central project runs cloudflared, nginx, PostgreSQL, pgAdmin, MariaDB, Pi-hole, Pterodactyl panel/cache/Wings, registry/UI, Prometheus, node-exporter, cAdvisor, Loki, Promtail and Grafana. A Wings-managed workload also runs outside those project labels. Container presence does not establish readiness.

Named volumes observed include `home-server_database-data`, `home-server_mariadb-data`, `home-server_observ-grafana-data`, `home-server_panel-cache-data`, `home-server_postgresql-data`, `home-server_registry-data`, `home-server_static-website-data`, `itskolar-system_itskolardb`, `itskolar-system_itskolarresources`, `itskolar-system_itskolarsites`, `pearl-horizon-airlines_pearlfrontend`, `pearl-horizon-airlines_receipts`, `skybridge-airways_skybridge_nginx_logs`, and `skybridge-airways_skybridge_postgres_data`, plus anonymous volumes. No volume should be changed based on this list alone. Map all mounts, population, sizes and project labels before adoption; Docker's listing alone does not prove a volume is empty or disposable.

PostgreSQL and MariaDB are shared engines. The prior investigation identified ITskolar's authentication, CONNECT and schema gaps; MariaDB consumers and real application migrations still require inventory. Secret input interfaces must be recorded without values. Panel/egg versions, a relevant workload's supported delivery interface and its complete data/metadata dependencies remain unverified.

## Second server

Identity, OS, interfaces, independent workloads, services, mounts, backup storage, access and local collection are not yet verified. The [hardware snapshot](../../new_server_hardware.md) is planning context, not current-state evidence.

## Gate and outstanding evidence

No protected usable recovery set, independent recovery access, complete populated-volume map or actual backup size has been demonstrated. Privileged firewall rules, root schedules, certificate renewal, effective SSH settings, all external consumers and input interfaces remain to be inventoried. Retain running state; do not replace or delete volumes or change networking until the plan's gate is met. Record redacted observations only, never raw environments, credentials or secret-bearing command lines.
