# Home server infrastructure refactor

* **Author:** Server owner, with Codex
* **Date:** 2026-11-01
* **Last updated:** 2026-11-02
* **Stage:** EGM brainstorm, owner confirmed readiness for independent Goldfish reviews on 2026-11-02. The overall design is not finalized. Formal drafting has not started.

## Overview

Restructure the Debian 13 home server configuration so application databases, GitHub Actions deployments, secrets, container updates, and telemetry from a second server can be operated with clear ownership and recoverable changes. Investigate the existing networking and bootstrap failures alongside that design.

The result must explain both what changes and why. It must cover the host operating system as well as Docker services, and provide a staged migration with checks and recovery steps. This request authorizes planning and documentation; it does not ask for a live migration.

### Anchored working hypothesis for review

Keep the central platform on the 4 GiB Atom, make Debian configuration and application database provisioning/migration ownership reproducible, and deliver secrets through existing application configuration with protected off-site recovery before acknowledging changes. Use isolated GitHub-hosted image builds and owner-authorized production deployments, while the second server keeps its own telemetry backends and serves as a backup target, with Grafana and its existing notification setup remaining central. Maintain Pi-hole's intended DNS/NTP/DHCP role and internal access boundaries, automatically apply compatible central image updates while alerting on external updates and database major upgrades, and prioritize recoverable data plus 30 days of meaningful change/command audit history over continuous availability.

The decisions below are the constraints for review. Database process topology, secrets/delivery products, the precise zero-loss publication protocol, deployment transport, update tooling, DHCP/network implementation, and resource/retention sizing still need design and verification. Reviewers should challenge feasibility and identify concrete trade-offs without treating these pending mechanisms as already implemented or owner-approved choices.

### Confirmed deployment scope

The owner confirmed that the central infrastructure stays on the current Atom server. The second server receives the observability portion, excluding Grafana, and is subsequently authorized as a recovery-copy storage target. It is not an additional deployment target for this project's databases, secrets manager, registry, CI runner/deployer, ingress, Pi-hole, or Pterodactyl infrastructure. Independently operated workloads on that server remain outside this infrastructure deployment. Backup storage does not make it an application standby or authorize replicating the full infrastructure stack.

The owner subsequently delegated build placement and permitted considering an isolated build environment on the second server as a possible exception. The selected working design uses GitHub-hosted builders, so no CI installation on the second server is selected. This optional build exception does not broaden deployment of the other central infrastructure.

Grafana stays on the current server and must provide visibility into both hosts. The owner explicitly requires the second server to run Prometheus, node-exporter, cAdvisor, Loki, and Promtail or a supported replacement. Each server has its own Prometheus and Loki instances so telemetry ingestion and storage for the second server do not add that load to the Atom. Collector selection remains open.

The design must provide Grafana access to both servers' telemetry backends. The query/connection mechanism, authentication, network path, retention, and alert placement still need agreement. Local collection and storage should continue when the inter-server connection or central Grafana is unavailable; validate this behavior in the formal plan. Duplicating all second-server telemetry into the Atom would defeat the stated reason for separate storage and is not an assumed requirement.

## Analysis

### Evidence boundaries

The initial pass inspected repository configuration. The owner subsequently authorized SSH inspection of `home-server-alt`. Bounded read-only investigations verified the current ITskolar database path/account blockers, application configuration, existing runner services, and selected Debian/Pi-hole runtime state. See the [database investigation](docs/investigations/2026-11-01-database-connectivity.md) and [Debian/Pi-hole baseline](docs/investigations/2026-11-01-debian-host-baseline.md) for evidence and limits. The second server has not been inspected remotely. The local workspace has not been treated as the target Debian host. Private key contents were not inspected, and secret values are deliberately omitted from these documents.

Structural exploration used the codebase-memory graph for project `mnt-Data-Projects-Infrastructure-Home-Server`, indexed on 2026-10-30, with Tier 2 verification. Coverage was checked for the files used below. The graph reports unusable parsing for the nginx main configuration and Pi-hole virtual host; both were read directly in full. Graph edges do not establish runtime connectivity.

On 2026-11-01 the owner confirmed the current hardware document and supplied the second server's hardware snapshot. Both hardware paths passed a further best-effort coverage check against the refreshed index and were read directly. The second snapshot describes its state when collected, not a live capacity measurement.

### Current configuration and implications

| Area | Repository evidence | Implication for the design |
| --- | --- | --- |
| Current server hardware | The owner confirms [Hardware_Info.md](Hardware_Info.md): Atom x5-Z8300, 4 GiB RAM, approximately 64 GB eMMC, and USB Ethernet. | All central infrastructure must fit this machine. Budget memory, build concurrency, telemetry retention, disk writes, and backup space before adding services. The second server's resources do not expand this budget. |
| Second server hardware | [new_server_hardware.md](new_server_hardware.md) describes a Toshiba Satellite B552/H, x86-64 i5-3230M with two cores/four threads, 8 GiB RAM, and a 128 GB drive (119.24 GiB reported). The snapshot reports Debian 13, Wi-Fi up, wired Ethernet down, and a Tailscale interface. | Size the permitted observability components alongside its independent workloads. Establish actual cross-host reachability and a storage budget; the snapshot's reported memory/disk use is not a peak measurement. Do not move other central infrastructure here. |
| Database ownership | [compose.yaml](compose.yaml) runs PostgreSQL and MariaDB with shared database networking and central Flyway jobs. PostgreSQL migrations use the configured PostgreSQL account; MariaDB migrations use root. The owner reports difficult account management, intermittent reachability/authentication problems, and difficult onboarding/migrations, including Pterodactyl. | Separate database provisioning, application schema migrations, runtime access, and engine upgrades in the design. Read-only SSH checks establish current ITskolar password/privilege/schema blockers; they do not decide the future database process topology or diagnose every reported failure. |
| Network ownership | [compose.yaml](compose.yaml) combines ingress, home DNS, databases, Pterodactyl, registry, and monitoring. It requires an existing `pterodactyl_nw` network. | Explain startup dependencies and application attachment explicitly. A Docker bridge on one host is not a network between two hosts. |
| Pi-hole web UI | Pi-hole uses host networking. nginx publishes host ports 80/443. [pihole.conf](infra/nginx/conf.d/pihole.conf) forwards to `host.docker.internal:8080`. Runtime inspection confirms persisted Pi-hole port 8080, working host-origin HTTP requests, and a timeout from nginx to the configured upstream. The virtual host permits only `192.168.1.0/24`. | Investigate the container-to-host filtering/routing path and intended client access. A port mismatch is ruled out for the observed deployment, but effective firewall rules were unavailable. Do not claim a confirmed firewall cause or treat a host-origin request as a complete LAN/VPN browser test. See the linked baseline report. |
| Host setup | [setup.sh](setup.sh) writes an nftables ruleset; [new_setup.sh](new_setup.sh) flushes iptables chains and writes an IPv4 ruleset. The newer script permits UDP DNS but has no corresponding TCP 53 acceptance rule. It changes SSH configuration without an explicit validation/reload step. | The final host plan must identify which script ran, which firewall backend is active, how Docker and Tailscale rules coexist, and how to prevent remote lockout. IPv6 needs explicit treatment. Docker relies on its networking rules; see [Docker firewall documentation](https://docs.docker.com/engine/network/packet-filtering-firewalls/). |
| Package change reporting | `new_setup.sh` runs its initial full upgrade before installing/configuring apt-listchanges. It then invokes `apt-listchanges --apt` through `DPkg::Pre-Invoke` and suppresses failures. | The custom hook does not provide the package input expected by `--apt`. Inspect the installed package hook and effective APT configuration before designing the replacement. Use the package integration rather than a second competing consumer. See [apt.conf](https://manpages.debian.org/trixie/apt/apt.conf.5.en.html) and [apt-listchanges](https://manpages.debian.org/trixie/apt-listchanges/apt-listchanges.1.en.html). |
| Login change reporting | `new_setup.sh` removes the normal `/run/motd.dynamic` PAM entry and uses the script directory as `motd_dir`. Live PAM already uses `/run/motd.dynamic`, differing from that script, while the installed MOTD script still truncates a shared changes log on login. | Fix the repository script and remaining live history-loss behavior separately. Preserve the already configured generated-output path rather than assuming the live host still matches the script. See [Debian pam_motd](https://dyn.manpages.debian.org/trixie/libpam-runtime/pam_motd.8) and its [Debian implementation patch](https://sources.debian.org/src/pam/1.7.0-5/debian/patches/update-motd). |
| Secrets | Compose contains literal credentials/default passwords as well as values supplied through environment variables. | Inventory each consumer and its supported delivery method. Replacing configuration text does not rotate credentials already stored in applications or databases. Record migration and revocation separately; do not copy existing values into this brief. |
| Telemetry | [prometheus.yml](infra/prometheus/prometheus.yml) targets the current host and local cAdvisor. Compose gives Grafana an explicit data volume but no explicit persistent data mount for Prometheus or Loki. [Loki configuration](infra/loki/loki-config.yml) uses filesystem storage. Loki's configured Go memory target also exceeds its container memory limit. | Verify actual mounts and memory use. Define persistence, retention, per-host identity, secure transport, and behavior when either server or the link is down. Do not assume a recreate preserves telemetry. |
| Log collection | Compose deploys Promtail with [this configuration](infra/promtail/promtail-config.yml). | Promtail reached end of life on March 2, 2026 according to [Grafana](https://grafana.com/docs/loki/latest/send-data/promtail/). The design needs a supported collector; product selection remains open. |
| Updates and deployment | Multiple images use moving tags. [compose.staging.yaml](compose.staging.yaml) publishes several database/cache/admin ports without an explicit host address. | Establish the effective Compose invocation and intended exposure before proposing deployment automation. Distinguish detecting a new image, approving it, and replacing a running container. Avoid competing deployment writers. |
| Certificates | Base Compose mounts one certificate directory into several domain-specific locations; [compose.production.yaml](compose.production.yaml) instead mounts host Let's Encrypt directories. | Establish how certificates are issued, what names they cover, how renewal reaches nginx and Wings, and what survives recovery. Repository mounts alone do not prove renewal works. |
| Documentation | [System_Documentation.md](System_Documentation.md) describes older database names and a narrower service inventory than Compose. | Update the operational reference only after the target design is agreed. Keep accepted decisions and their reasons linked to the resulting configuration. |

### Owner-reported database workflow problems

The owner reports that managing accounts for PostgreSQL and MariaDB is difficult. Consumers sometimes cannot reach an instance or have their username/password rejected; consumer misconfiguration is a possible explanation the owner explicitly identifies. Adding a service and handling its migrations, including Pterodactyl, also make account management difficult.

The owner confirms PostgreSQL and MariaDB are the database engines in use, matching the checked-in Compose. Pterodactyl targets MariaDB. The remaining inventory work concerns consumers, endpoints, accounts, and migration ownership.

### Verified ITskolar failure and planned Skybridge dependency

The owner identified `/srv/ITskolar-System` on `home-server-alt` as the affected consumer and `/srv/Skybridge-Airways` as a planned consumer. SSH confirmed this alias reaches the current Atom server and that both project directories and `/srv/Home-Server` are on that host.

The [read-only investigation](docs/investigations/2026-11-01-database-connectivity.md) reproduced the ITskolar login failure from inside its bot container: DNS and TCP connectivity work, but the configured worker has no database password set. Both ITskolar roles also lack `CONNECT` to their database, and the expected `application` and `student` schemas are absent. `ENABLE_DB=False` in the running bot explains why its running status does not validate database use. The current shared-instance Skybridge roles have the same password/connection-privilege gaps; Skybridge's Compose still targets its own database and has not been integrated with the shared instance.

The ITskolar workflow uses bare Compose commands, while the running bot's database network attachment comes from its production override. Configuration rendering confirms the base file alone lacks that attachment. A complete running-job environment was not inspected, so this is a verified configuration discrepancy and a deployment risk rather than a proven explanation of historical connection loss. Two self-hosted Actions runner services already run on the Atom.

These observations confirm provisioning and deployment consistency as work the refactor must address. Database process topology remains undecided. No live fix was applied.

### Database operations to distinguish

The design discussion should distinguish these operations so one failure is not mistaken for another:

* **Reach the endpoint:** identify the consumer's location, resolve the intended hostname there, connect to the actual database TCP port, and establish any required TLS connection. ICMP ping failure alone does not establish whether a database connection is possible. Docker service names, host-local addresses, and remote addresses require different reachability checks.
* **Authenticate and authorize:** establish which application uses which identity, where its credential comes from, which database it authenticates against, and what it may access. Verify the actual persisted account state and the consumer's effective configuration without revealing credentials.
* **Provision a new service:** define who creates its database and accounts, grants and revokes access, records ownership, and updates consumers. A repeat run must have a defined outcome for an existing database/account.
* **Run application migrations:** identify the migration tool and owner for each application, required privileges, sequencing with deployments, failure behavior, and recovery. Do not assume a central Flyway job should own every third-party application's schema.

A useful onboarding acceptance check will exercise an authorized connection from the real consumer environment and a rejected connection to another application's data. Migration checks must establish that the supported application version can start and use its schema. Exact procedures and account boundaries remain to be agreed; the bounded ITskolar checks above do not replace validation of the final onboarding process.

### CI ownership and collaborator access

The owner has full oversight and control of both organizations served by the existing runners. Some collaborators can push code. The owner requires production deployment to have either explicit approval from the owner or a pipeline-triggering event initiated by the owner. Repository visibility, GitHub plan, branch protection, workflow-change restrictions, and runner assignment have not yet been established.

The design must define which collaborator changes may run builds and which may reach production. Source code, dependency installation, build scripts, and Dockerfiles can execute code during a build, so reviewing only changes to the workflow file would not establish the full build trust boundary. The observed workflows build and deploy on the application host. The owner delegated future build placement; the selected working design moves builds to GitHub-hosted VMs, with detailed job privileges and deployment transport still to be designed.

Organization ownership establishes who can set policy. It does not establish whether the intended approval rule is currently enforced. Record the policy separately from the mechanisms available on the repositories' GitHub plans. The second server remains outside the central CI rollout.

The agreed policy means a collaborator-triggered run must wait for the owner's approval before deployment, while an owner-triggered run may proceed without an additional approval step. Approval must authorize the revision/artifact actually deployed; the design needs to prevent a later `git pull` or moving image tag from substituting different code after approval. The approval mechanism and artifact identification remain design work.

Several cases still need explicit treatment during design:

* A trigger initiated by the owner may include collaborator commits. Whether that owner action authorizes the entire selected revision needs clarification before finalizing event rules.
* Re-runs have both an original actor and a re-run initiator. GitHub documents that re-runs retain the original actor's privileges and exposes `github.actor` separately from `github.triggering_actor`; checking the original actor alone would not express who requested a re-run. Define approval behavior for re-runs and chained workflows, and identify the owner using verified platform identity rather than commit author text. See [GitHub contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) and [re-running workflows](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).
* Build code with production-host control could act before a later deployment approval step. The chosen build/deploy arrangement must enforce the owner's policy at the point production control becomes available, not merely label the final step as deployment.
* The ability to edit a workflow must not provide an alternate route around the required authorization. Workflow/runner restrictions and where authorization is enforced remain to be designed.
* GitHub environment reviewer features vary by plan and repository visibility. Do not promise a built-in approval gate before checking applicability. See [deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

### Selected build placement under owner delegation

Use standard multi-core GitHub-hosted Linux VM runners for image builds and build-time checks, targeting `linux/amd64` for these servers. GitHub provisions these jobs on fresh VMs; its single-CPU `ubuntu-slim` runner is a different, container-based arrangement and is not the selected isolation mechanism. See [GitHub runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

This choice keeps build CPU, memory, temporary files, and build-cache writes off the Atom and avoids adding a local hypervisor and VM lifecycle management to the refactor. The second server retains its independently managed workloads, agreed observability deployment, and authorized backup-storage role. No local build benchmark has established spare VM capacity on either home server.

The intended flow is to build an image remotely, publish it, authorize a specific revision/artifact under D-04, and have the Atom pull and start that artifact using host-controlled deployment configuration. The build job must not receive the production Docker socket, runtime application secrets, or general access to the home network. Registry publishing permissions, production deployment transport, and the replacement or restriction of the current runner services remain design work. A fresh builder does not establish that the image it produces is safe to run; application privileges and artifact authorization remain necessary design boundaries.

Plan around free/included compute with no paid overages assumed. GitHub documents standard public-repository runner use as free, while private/internal builds draw from the repository owner's included compute; artifact/cache/registry storage has separate considerations. Confirm visibility, allowance, concurrency, build duration, image size, and spending controls before implementation. Do not assume a fixed quota based on an older minutes-only pricing table. See [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

The GitHub connector confirms `bonaktan/Skybridge-Airways` is public. Its request for `PUP-ITskolar/ITskolar-System` returned 404, which does not establish whether that repository is private, inaccessible to the connector, renamed, or absent. The two organizations' complete repository inventory, billing plans, and current usage remain unverified. No settings or billing changes were made.

### Confirmed secret consumers

The owner identifies ITskolar-System, a planned but undeployed system, and some services running in Pterodactyl as “external” secret consumers. Here the term describes applications outside the central infrastructure stack; their location, network reachability, and operator permissions must be established separately. The unnamed planned system must not be silently identified with Skybridge-Airways, which has already been discussed as a separate planned database integration.

| Consumer group | Established context | Integration work still to define |
| --- | --- | --- |
| Central infrastructure | The owner requests secrets management for internal services; Compose currently mixes environment-supplied and literal credentials. | Consumer inventory, supported secret-file/environment interfaces, bootstrap credentials, and startup dependencies. |
| ITskolar-System | Runs on the Atom outside the central Compose project. Its bot uses `.env-application` through Compose `env_file` and reads credentials from environment variables. No application or startup-code modification is allowed for secret integration; an ops-admin restart to apply changed values is acceptable. | Preserve the existing application interface; define identity, delivery through deployment configuration, the admin's recreation procedure, and outage behavior. |
| Unnamed undeployed system | Planned secret consumer, not yet deployed. The same no-code-change constraint applies to secret integration. | Its runtime, ownership, existing configuration interfaces, and deployment path. |
| Pterodactyl workloads | Some applications managed through Pterodactyl need secrets. This is distinct from the panel and Wings themselves consuming infrastructure credentials. | Which workloads and operators, control over images/eggs/startup commands, per-workload authentication and access, and refresh/restart behavior within Wings' lifecycle. |

The owner requires no code modification for secret integration. Treat this as a hard constraint covering application source and application startup code: do not require an SDK, application API calls, changed credential-loading logic, or a modified application startup script. Use supported deployment configuration and the application's existing environment-variable or configuration-file interface. Do not assume a new image entrypoint, wrapper script, or egg script change is allowed as a workaround.

This establishes a need for secret delivery outside the application process as well as central storage. The exact host/deployment agent, authentication, and delivery mechanism remain open. Inventory each consumer's supported input formats and the configuration controls available through Compose or Pterodactyl. A file mount alone does not make an environment-only consumer read that file: Compose secrets are files, and `_FILE` variables are an image-specific convention, not automatic behavior for every application. See [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/).

The design must avoid using one shared, broadly privileged machine credential for all unrelated workloads, and must define how the deployment/delivery component authenticates before fetching consumer secrets. Establish permissions, lifetime, and cleanup for any generated runtime configuration. The secret store's encryption and access controls do not eliminate the need to protect a consumer's delivered values.

The owner accepts restarting a service to apply changed secrets, with restarts performed manually by the ops admin. Use admin-initiated activation as the working plan; automatic restarts or application hot reload are not required. This applies to secret changes and does not decide the separate container-image update policy.

For ITskolar's environment-based delivery, a changed secret must reach a newly created container with the updated environment; `docker compose restart` does not apply environment configuration changes. The operational “restart” procedure must therefore deliver the new values and recreate the affected container while preserving its data. Pterodactyl's procedure must refresh the configured inputs through its supported lifecycle before the admin restarts the workload; support remains to be verified for each relevant service. See [Docker Compose restart](https://docs.docker.com/reference/cli/docker/compose/restart/).

Changing a stored secret and changing the credential accepted by a database/API are separate operations. Until the manual rollout, existing consumers may still hold the old value. The rotation procedure must coordinate backend credential changes, delivery, admin activation, validation, and old-credential revocation. Do not promise uninterrupted operation when a provider cannot support overlapping credentials. A short-lived credential must not expire ahead of a manual rollout without a verified renewal method compatible with existing application inputs.

Acceptable interruption duration, scheduling, and behavior when the store is unavailable remain unresolved. The design needs an admin-visible way to identify pending consumer refresh and verify successful application without exposing secret values.

For database credentials, delivery must be coordinated with the actual database account state. The ITskolar investigation demonstrates that a nonempty consumer password does not establish that the database account has a matching password or sufficient access.

### Container update policy

The owner requires different behavior for the two workload classes:

| Workload class | On detecting a newer image | Owner's intended outcome |
| --- | --- | --- |
| Central infrastructure | Automatically apply the image update and restart the affected service. | Central infrastructure stays current without waiting for a manual image rollout. |
| Database major-version upgrades | Emit an update-available log collected by Loki and alert the owner. Do not automatically apply the major upgrade. | The admin plans and performs the database migration separately. This overrides the general central automatic-update rule for these upgrades. |
| External applications | Emit an update-available log; Loki collects it and the alerting path notifies the owner. Do not apply the image update. | The owner learns about available updates while the application's own deployment process controls rollout. |

For an image update, “restart” means pulling the new image and recreating the affected container using the intended deployment configuration and existing data mounts. Restarting the old container alone does not switch it to the new image. A pull alone also does not start a new container. See [Compose pull](https://docs.docker.com/reference/cli/docker/compose/pull/) and [Compose up](https://docs.docker.com/reference/cli/docker/compose/up/).

This is explicit owner authorization for automatic central-infrastructure image maintenance. D-04 continues to govern CI-initiated application deployments and collaborator changes; an updater must not turn an external application's new image into an approved deployment. The automatic secret-refresh behavior remains separate: D-07 permits admin-initiated restarts for changed secrets.

The final design must identify central services explicitly and distinguish them from applications managed in separate Compose projects or through Wings. Unknown containers must not acquire automatic-update privileges merely by being visible to a watcher. A detected Pterodactyl application update must use the external log/alert path; the watcher must not recreate a Wings-managed application container directly. Whether the second server's observability services join the automatic central-service maintenance class still needs explicit treatment; the monitoring topology alone does not decide update authority there.

External update logs need enough safe context to act on: host, service, deployment owner, image, current digest/version, detected digest/version, event time, and update policy. Define collection and alert evaluation, routing, deduplication, reminder/resolution behavior, and missing-telemetry handling. Loki ingestion by itself does not deliver a notification; configure the required log-based rule in the existing Grafana alerting setup. See [Loki alerting](https://grafana.com/docs/loki/latest/alert/).

### Existing production alerting to preserve

The owner reports an existing production Grafana alerting setup with Discord webhooks and an additional webhook integration referred to as “nfty.” Reuse the existing contact points and notification policies for new update and operational alerts. Do not add a replacement notification stack or assume existing rules need to be recreated.

A bounded read-only SSH check established that Grafana is running and `/api/health` reports its database healthy. Its provisioning mount is `/srv/Home-Server/infra/grafana/provisioning`; the inspected directory contains only `datasources/datasources.yml`. The repository alone therefore does not capture the owner-reported alerting configuration.

Contact-point, notification-policy, alert-rule, and data-source API requests using the container's existing bootstrap admin credentials returned HTTP 401. Those credentials do not establish access to the current account. A targeted read-only database-metadata inspection through existing noninteractive sudo was also unavailable. No password reset, privilege workaround, webhook test, or alerting configuration change was attempted. Webhook URLs and tokens were not displayed or stored. Contact-point names/types, routing, rules, and delivery remain owner-reported rather than independently verified.

Before changing Grafana or its data storage, obtain an authenticated, protected export/inventory and a consistent backup of the effective configuration and database. Preserve existing identifiers, notification routing, and the encryption-key configuration needed for stored secrets. Keep webhook credentials outside committed exports. Verify restore behavior before relying on a rollback; Grafana documents both [backup requirements](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/) and [database encryption key handling](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-database-encryption/).

The formal validation plan must establish that a new update event reaches the intended existing contact points, that a resolved condition follows the intended routing, and that adding second-server data sources does not break existing rules. No notification was sent during this planning inspection. Behavior when central Grafana itself is unavailable remains a separate recovery/monitoring question.

### Update compatibility and recovery

Automatic central updates still need an allowed version range, cadence/window, serialized changes, compatible configuration, health checks, outcome logs, and recovery behavior. Coordinate this updater with the production deployer so they cannot concurrently replace the same service. Record the resolved image digest and retain enough deployment state to recover; repository intent and runtime image selection must remain explainable.

The owner explicitly requires database major-version upgrades to follow the external-service log-and-alert path. Automatic central database updates must remain within a defined compatible release series; classification must use the database engine's release/upgrade rules rather than trusting a floating image tag. If a candidate cannot be classified, report it for review rather than assume it is an allowed automatic update. Define version limits and alert-only major-release discovery as separate checks: observing a new digest for a pinned current-series tag does not by itself discover a newly published major-version tag.

PostgreSQL documents major upgrades as requiring an upgrade method such as dump/restore or `pg_upgrade`, while minor upgrades within a major release preserve the storage format. An image change alone is not a database migration strategy, and reverting an image does not necessarily reverse state migrations. See [PostgreSQL upgrades](https://www.postgresql.org/docs/18/upgrading.html). Other central updates that migrate persistent application state still need service-specific compatibility and recovery handling; the database-major exception does not establish that every other image change is reversible.

### Pi-hole's target role

The owner wants Pi-hole to provide DNS, NTP, and ideally DHCP for the home network. The current inspected configuration already enables DNS and NTP but has DHCP disabled. Treat DHCP as a desired part of the target design, with feasibility and cutover prerequisites to establish; do not silently drop it to simplify container networking.

The design must account for DHCP broadcast delivery when choosing Pi-hole's network mode. Moving the container onto an ordinary Docker bridge solely to avoid the HTTP upstream problem would require a working DHCP relay or another supported broadcast path. Pi-hole documents host networking, macvlan, and bridge-plus-relay arrangements in [its Docker DHCP guide](https://docs.pi-hole.net/docker/dhcp/). The active Wi-Fi interface and missing configured wired adapter must be considered before selecting a network arrangement; do not assume a separate container LAN address will work on the current connection.

The owner confirms the home router currently provides DHCP and plans to disable that function once Pi-hole DHCP is validated. The router remains the current authority until the controlled cutover. Establish its administrative controls and preserve its configuration for rollback.

The plan must define scoped validation of Pi-hole's DHCP behavior before changing LAN-wide authority, followed by a controlled switch from router DHCP to Pi-hole DHCP and a real-client lease/renewal test. Do not interpret “working before disabling the router” as permission to run two independent DHCP servers with overlapping production lease pools. Record the fixed management address, lease range, reservations, gateway/DNS/NTP options, lease behavior, IPv4/IPv6 responsibilities, and recovery access. Router model, actual ranges/reservations, and cutover controls remain to be inventoried. No router or DHCP setting was changed during inspection.

Keep the browser-access failure separate from the LAN protocol requirements: Pi-hole already serves HTTP 200 to host-origin requests on 8080, while nginx's configured host-gateway path times out. Fixing the web UI needs an effective filtering/routing review and an intended LAN/VPN access policy; it does not require discarding the host's DNS/DHCP/NTP role. Host and recovery networking must remain usable when Pi-hole is down, consistent with the owner's acceptance of service outages and manual restoration.

### Administration access policy

The owner requires the existing access split to remain: Pi-hole and databases/database administration stay internal, while Grafana may be externally reachable through the existing ingress. This is a requirement to preserve the access policy while fixing connectivity, not permission to publish database ports or bypass the internal UI restrictions.

The checked-in Pi-hole and pgAdmin virtual hosts allow `192.168.1.0/24` and deny other clients. The Grafana virtual host has no equivalent LAN-only filter. The observed infrastructure PostgreSQL/MariaDB containers have no host-published database ports. Keep internal names, ingress routes, host bindings, client-source handling, and effective firewall rules consistent with that policy; an `internal` hostname alone does not enforce access control.

“Follow the current solution” does not authorize expanding private access to additional VPN clients or networks. Verify actual source addresses and rules before any such change. The final preflight must test permitted LAN access, rejected public/other-source access, and authenticated external Grafana access separately. Existing Tailscale SSH connectivity does not establish browser access to every internal interface.

The secret manager's administrative access and any necessary machine-facing endpoint still need a product-specific design. The confirmed external secret consumers are separate application deployments, which does not by itself require a public secret-manager UI/API. No additional public administration endpoint is selected.

### Server change auditing

The owner specifically wants package installations, kernel/driver tweaks, and execution of nonstandard/state-changing shell commands recorded, while excluding ordinary commands such as `cd`/`ls` that do not change managed system state. The owner wants about one month of investigation history; use 30 days as the working searchable-audit retention target. Propose the following focused operational baseline for the overall design review:

| Change category | Events and evidence to retain |
| --- | --- |
| Packages and repositories | Install, upgrade, downgrade, removal, unattended-upgrade outcome, package versions, and repository/signing-configuration changes. Preserve APT/dpkg records independently of the login MOTD. |
| Kernel, boot, drivers, and host tuning | Kernel/package changes, bootloader command-line changes, driver/module configuration, sysctl configuration and supported runtime-change evidence, reboot, and the effective kernel/boot settings after restart. |
| Administrative command execution | Commands/scripts that change or attempt to change managed system state, with actor/session, execution identity, safe command details, affected resources, and result where observable. Suppress routine read-only navigation/listing noise without allowing that filter to hide mutations. |
| Networking and access | Interface/address/resolver changes, DHCP configuration/cutover, firewall changes, SSH/login outcomes, sudo/privileged actions, and account/group/key administration metadata. |
| Services and containers | systemd unit/drop-in changes, service lifecycle/failure, Docker/Compose configuration and lifecycle changes, image updates, and health/recovery outcomes. Correlate with the owning project and resolved image digest. |
| CI and deployment | Initiating platform identity, owner approval where required, source revision, artifact digest, Actions run/deployment reference, target services, success/failure, and rollback. |
| Secrets | Administrative create/update/delete, delivery/read authorization metadata where the selected product provides it, denied access, affected secret version/consumer, and activation outcome. Never record secret values. This does not promise visibility into every use of an environment variable inside an unchanged application. |
| Recovery and certificates | Backup/copy/verification/restore outcome, age of latest usable recovery point, retention/deletion actions, and certificate issuance/renewal/reload outcomes. |

The proposed mechanism is to reuse APT/dpkg logs, persistent service/authentication journal records, Docker/deployer events, and secret/backup/certificate operation metadata, adding focused Linux Audit rules for selected host configuration mutations and administrative actions. Debian's [auditd manual](https://manpages.debian.org/trixie/auditd/auditd.8.en.html) describes the kernel audit records, local storage, and persistent rule loading; [auditctl](https://manpages.debian.org/trixie/auditd/auditctl.8.en.html) documents rule filtering and lost/backlog counters. Installed audit support, rule feasibility, and resource cost still need verification. This is a proposal, not a claim that a complete audit system is already active.

Use bounded event selection and retention suitable for the Atom. The added command-execution requirement goes beyond noticing that a file changed, but it still excludes ordinary read-only activity and does not request a raw terminal transcript. Some raw audit/auth records can include command arguments or other sensitive context: restrict local access, define rotation/caps, and forward only approved fields after filtering. Do not stream process environments, file contents, webhook credentials, or secret-bearing command text into Loki. Verify filtering with a harmless marker before enabling broader collection. The owner delegates the useful command-record detail; the selected fields and omission policy follow below, while capture rules still need verification.

Command names alone do not establish whether an invocation changes state. A script/interpreter may read or write, shell builtins/redirection can mutate files without a separate executable for the apparent command, and a network/API call may change remote state without writing a local configuration file. A compound command beginning with `ls` must not be discarded as a whole if later parts mutate the system. GNU documents [shell redirection](https://www.gnu.org/software/bash/manual/html_node/Redirections.html) and [command execution](https://www.gnu.org/software/bash/manual/html_node/Command-Search-and-Execution.html); the final design must account for these cases rather than promise perfect classification from a name blacklist.

Combine command-attempt evidence with relevant mutation/lifecycle records and identify limits for shell builtins, scripts, editors, sudo, automation, and application/runtime activity. Failed administrative attempts should remain investigable where captured. A successful executable launch is not evidence that the command's operation completed successfully; record the completion result only when the chosen source actually provides it. Any classification that cannot safely determine behavior needs an explicit treatment, rather than silently dropping unknown commands.

Where available, retain timestamp, host, original login/service/platform actor, action, affected path/service/package, result, and a correlation identifier. An automatically started process may have no human login identity; preserve its unit or workflow origin rather than assigning it to the last SSH user. Audit events describe observable changes, while the rationale belongs in a Git commit or operations change record with the previous/target settings, reason, validation, and rollback.

Under the owner's delegation, use the following command-record fields:

| Field | Selected detail |
| --- | --- |
| Time and location | Timestamp with timezone, host identity, and working directory where the capture source supplies it. |
| Actor and origin | Original login identity, effective identity, SSH/sudo session or service/CI origin, and a correlation/event identifier. Preserve unavailable/unknown identity explicitly. |
| Operation | Resolved executable or script path, command category, and arguments only where they can be safely retained. For managed scripts/configuration, associate a repository revision or digest when available without hashing large files on every execution. |
| Sensitive-data handling | Redact credential-bearing arguments; if an argument vector cannot be safely represented, omit it and mark that omission. Never promise that a general shell parser can reliably detect every secret. No process-environment capture or added raw terminal/output transcript is selected. |
| Affected resource | Relevant configuration path, package, unit, container, image digest, or authorized remote operation, correlated from the source that observes it. Do not invent a resource from the command's name alone. |
| Result | Attempted/denied/completed status, exit result, and duration only when the capture source actually observes them. Keep executable-launch success distinct from operation completion. |

Unknown administrative scripts/interpreters should retain safe execution metadata rather than being silently treated as read-only. Basic navigation/listing can be filtered, but the classification must preserve mutation records for compound commands, redirection, aliases/functions, and actions that fail. Acceptance cases should include a privileged package operation, a file modification through shell redirection, an editor/script change, a denied action, a routine read-only command, and an argument containing a harmless secret marker. Verify usable attribution, absence of the marker from forwarded records, and observable collector/audit loss; do not claim complete coverage until those paths are tested.

Send the selected records through the supported collector to that host's Loki and include an independently protected audit archive in R2 if the chosen retention/cost policy calls for it. Logs remaining only on a compromised Atom cannot establish an independent audit trail. Remote copies and audit-loss/collector-health alerts improve evidence, but do not justify claiming a complete tamper-proof history after privileged compromise. An authorized root actor may affect event generation or forwarding; define this practical limit in the runbook.

The agreed investigation horizon is about one month, with 30 days of searchable audit history as the working target. Measure event volume and set per-host Loki storage, local spool/rotation, and audit-loss alerts to support that target. Do not silently shorten it to fit current defaults. Any longer encrypted archive, exact storage allocation, implementation of the selected metadata/redaction policy, and alert thresholds remain to be designed. Keep operational audit retention separate from general telemetry retention, database/Pterodactyl backups, and secret recovery/version history.

### Recovery requirements supplied by the owner

| Data class | Maximum acceptable loss after a server failure | Scope and consequence |
| --- | --- | --- |
| Secrets | Zero loss. | No loss of acknowledged secret changes under the six accepted failure scenarios below. A recoverable authoritative copy must survive loss of either or both home servers. The durability mechanism still needs selection and verification. |
| Databases | At most 24 hours. | Recovery must restore a consistent state no older than 24 hours before failure, including the accounts/permissions needed to use the data. Verify completed, independently recoverable backups rather than relying on a daily schedule alone. |
| Pterodactyl backups | At most 24 hours. | The backup policy must provide a recoverable Pterodactyl workload state within a 24-hour gap. Confirm which workload data, backup artifacts, and panel/Wings metadata are needed for a usable restoration. |
| Application uploads | Not applicable. | The owner processes no application uploads. Do not add a separate application-upload backup subsystem. Pterodactyl workload files remain covered by their own recovery requirement. |

These are recovery-point requirements: they limit how much recent state may be lost. The owner has no fixed restoration deadline: every service may be shut down, and a sysadmin may rebuild/restore when time permits, provided data remains recoverable within the agreed loss limits. No automatic failover, spare application host, continuous availability, or maximum downtime is required. The recovery procedure must still be repeatable, testable, and usable after prolonged downtime, including recovery credentials and required image/configuration versions.

The owner selects Cloudflare R2 and the second server as recovery-copy targets, both requiring setup from scratch. Capacity, retention, existing coverage, and restore-test frequency remain open. Grafana alerting state, certificate/renewal configuration, and other infrastructure state still need explicit coverage in the recovery plan; do not assume the secret-store requirement alone covers them. Define a finite retention/expiration policy deliberately; no fixed restore deadline does not establish infinite retention or justify deleting the last recoverable state while services are down.

For zero-loss secrets after loss of the Atom, the design needs an independent authoritative store or a durable recovery copy of each change before that change is treated as committed. Periodic snapshots or asynchronous copying retain a loss window, however short the schedule. A replication mechanism's acknowledgment and failure guarantees must be checked rather than inferred from a “backup successful” label. PostgreSQL's [synchronous/asynchronous replication explanation](https://www.postgresql.org/docs/18/high-availability.html) illustrates this distinction; this is not a decision to use PostgreSQL as the secret store or add database replicas.

The storage of secrets, metadata needed to locate/version them, and keys/credentials needed to decrypt or access their recovery copy must all survive the chosen failure scenario. Keep recovery material accessible without first requiring the failed secret manager to start. Preserve version history for unwanted changes/deletions; a synchronized current copy alone does not establish recovery from operator error or compromise.

The owner accepts coverage for disk/host loss, loss of both home machines, accidental changes/corruption, compromise of the Atom, lost recovery material/account access, and Internet/R2 outages, as described below. Do not claim absolute protection against every possible event or mark zero loss achieved before a mechanism is selected and verified. A backup directory on the Atom is not independent of losing that server, and an ordinary daily export cannot satisfy the zero-loss requirement for secret changes acknowledged between exports.

For the 24-hour database/Pterodactyl targets, choose a schedule with room for backup duration, transfer, and failures, and alert on the age of the latest usable independent recovery point. A job starting once every 24 hours can exceed the allowed gap if it runs slowly or fails. Restoration must be tested with an isolated target and verified application access; a stored file's existence is insufficient evidence of recoverability.

### Selected recovery destinations

| Target | Owner-confirmed availability | Design work |
| --- | --- | --- |
| Cloudflare R2 | Available as an off-site recovery target; not yet configured. | Private bucket/repository layout, client-side encryption, scoped credentials, compatible transfer/backup tools, version history/retention, deletion protection, cost/capacity, integrity verification, and a tested restore path. |
| Second server | Available as an independent-host recovery target; not yet configured. | Dedicated backup location and access identity, free-space budget alongside telemetry/workloads, encryption, retention, access restrictions, copy/restore validation, and independence from the Atom's credentials and storage. Its geographic/site independence remains unverified. |

Neither target has a verified usable backup, and no R2 resources, credentials, or second-server backup services were configured during planning. The second server's 128 GB drive is not an unlimited target; size actual database/Pterodactyl recovery data and telemetry retention before allocating storage. A copy there adds a storage role, not a second deployment of the central databases or secret manager.

R2 documents strongly consistent object operations, but this does not make an asynchronous export from a local secret manager a zero-loss transaction. The design must define where a secret change becomes authoritative and when it is acknowledged relative to the required independent copy. Check the selected tool against [R2's S3 API compatibility](https://developers.cloudflare.com/r2/api/s3/api/) rather than assuming all AWS S3 features are present. Use [R2's consistency documentation](https://developers.cloudflare.com/r2/reference/consistency/) to validate the actual write/read protocol.

The accepted scope includes loss of both home servers, so the latest acknowledged secret version must be independently recoverable off-site. The owner accepts deferring secret changes while a required recovery destination or update prerequisite is unavailable. Do not report a local-only change as committed or invalidate the existing credential before the protected update can complete. Define the exact acknowledgment and activation sequence in the design; current software/workflows have not been shown to enforce it.

### Accepted failure coverage

After reviewing the examples, the owner accepts all six scenarios below. These are required design/test cases, not claims that the current system already handles them. A failure mode is a concrete event that prevents normal operation or destroys usable state. Losing data, being temporarily unable to access data, and having data exposed to an attacker require different responses.

| Event | Example in this setup | Protection the plan should provide |
| --- | --- | --- |
| Loss of the Atom or its disk | eMMC fails or the machine stops working permanently. | Recover secret values/metadata from an independent copy and restore databases/Pterodactyl state within their 24-hour loss limit. Replacement hardware and rebuild time are separate concerns. |
| Loss of both home machines | Theft, fire, flood, or an electrical event affects both machines. | Recover from encrypted off-site copies in R2, including the keys/access material needed to use them. A second machine at the same site does not cover this event alone. Physical placement still needs confirmation. |
| Accidental edit, deletion, or corrupted state | An admin overwrites a working credential or a migration damages the store. | Retained known-good versions and tested restore procedures. Copying only the latest state can copy the mistake too. Define retention and what constitutes an authorized deletion. |
| Compromise of the Atom | An attacker with server access tries to destroy recovery copies. | Separate backup administration, credentials with limited scope, retained copies protected from the Atom's routine write/delete privileges, and a clean recovery procedure. Do not assume a replication target is safe when the compromised host can erase it. |
| Loss of recovery keys or account access | The only decryption/unseal key or Cloudflare recovery credential was stored on the failed Atom. | A separately secured recovery kit that can be used without starting the failed secret manager. Test that the kit can actually decrypt/access a recovery copy. |
| Internet or R2 outage | The network/provider is temporarily unreachable while both home machines remain intact. | Treat this primarily as an availability event. Existing services should continue with already-delivered valid credentials where their normal behavior permits. The owner accepts pausing secret changes until the required off-site durability step and update prerequisites can succeed. |

The accepted coverage is to survive the first five scenarios through independent copies, protected version history, recovery material, and restoration tests, and to tolerate the last by pausing changes instead of weakening durability. The owner states deferral will not affect operations and prefers waiting until an update can complete safely. Express this as explicit prerequisite checks and failure handling, not a promise that updates can never fail. No automatic failover or continuous service availability is implied.

For newly saved secrets to survive loss of both home machines, the required acknowledgment boundary is an independently recoverable encrypted version in R2 before the change is reported complete. Cloudflare documents that a successful R2 write is returned after persistence to disk, while distinguishing durability from availability and accidental-deletion protection. See [R2 durability](https://developers.cloudflare.com/r2/reference/durability/). Selecting a local secret manager and exporting later would not provide this end-to-end acknowledgment behavior; the eventual product/workflow must support or enforce it.

R2 bucket locks can prevent overwrites/deletes during configured retention, but administrators can remove lock rules. They are not a complete defense against compromise of the Cloudflare administrative account. Keep bucket-management credentials separate from routine host backup access and verify tool compatibility with locked objects before selecting a repository layout. See [R2 bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/).

Encrypted independent copies and restoration testing also follow [CISA's ransomware recovery guidance](https://www.cisa.gov/sites/default/files/2023-10/StopRansomware-Guide-508C-v3_1.pdf). Backups address recoverability; if secret values are exposed, revoking/rotating affected credentials is still necessary. Total destruction of every recovery copy and key, or simultaneous compromise of all administrative domains, cannot be presented as a zero-loss guarantee from the two selected targets.

### Questions to resolve through the EGM discussion

These are unresolved design topics, not an answer form or accepted requirements:

* Hardware and observability component placement are established. The remaining host questions concern network relationship, available capacity under load, telemetry access, retention, and alert behavior.
* The full workload inventory, including applications outside this repository, Pterodactyl panel/Wings, and containers created by Wings.
* The broader PostgreSQL/MariaDB consumer inventory and migration ownership. The current ITskolar consumer is on the same host as the shared database, with authentication/privilege/schema blockers verified; other reported or historical failures remain unverified.
* GitHub repository visibility/plan/allowance, enforcement of the agreed owner-approval-or-owner-trigger rule, treatment of the two existing self-hosted runners, exact event/re-run semantics, registry choice, and the allowed route into the server for deployments. GitHub-hosted VM builds are selected under owner delegation, with cost/compatibility checks outstanding. Building images and deploying them are distinct steps even when one workflow performs both. GitHub documents persistent compromise risks for self-hosted runners, particularly with untrusted contributions; see [GitHub's runner guidance](https://docs.github.com/en/enterprise-cloud%40latest/actions/reference/security/secure-use?learn=getting_started&learnProduct=actions).
* Supported configuration interfaces, deployment controls, operators, delivery authentication, credential-rotation ordering, and outage behavior for central services, ITskolar-System, the unnamed undeployed system, and Pterodactyl workloads. No application/startup-code changes are allowed, and manual ops-admin restarts to apply secret changes are acceptable; the external delivery mechanism is not yet selected.
* The central automatic-update / external log-and-alert split, database-major alert-only exception, and reuse of existing Grafana webhook routing are confirmed. Exact allowed release series, handling of other state-migrating updates, maintenance windows, interruption tolerance, recovery, verified contact-point/rule details, and second-server observability update authority remain open.
* Pi-hole's target DNS/NTP/DHCP role, replacement of router DHCP, and the internal Pi-hole/database versus external Grafana access split are established. Router controls, scoped validation/cutover, address/reservation plan, protocol exposure, IPv6 responsibilities, effective access tests, and any separately proposed VPN access change remain to be established.
* Backup capacity, implementation of the accepted six-scenario failure coverage and deferred-secret-change policy, existing coverage, retention/expiration, restore testing, alerting recovery, and telemetry/audit retention. Recovery is manual with no fixed deadline. R2 and the second server are selected targets but unconfigured. Maximum acceptable loss is established: zero for secrets and at most 24 hours for databases/Pterodactyl backups; there are no application uploads to cover.
* Package operations, kernel/driver changes, and nonstandard/state-changing command execution are required audit categories, with roughly one month of investigation history. Useful command fields and safe omission are selected under owner delegation; capture/classification, archive duration, volume/capacity, and attribution/compromise limits still need verification. Supplemental event categories are proposed for review; shell history alone is insufficient.

## Goals vs. Non-Goals

### In-scope goals supplied by the owner

1. Establish changes from the Debian 13 baseline, including relevant driver, kernel, and host settings.
2. Resolve database management across infrastructure and independently managed applications.
3. Support GitHub Actions builds and deployment to the current server.
4. Provide secrets management for internal, external, and Pterodactyl-managed workloads.
5. Centrally detect container updates and define how updates are applied.
6. Extend central observability to a second server with its own Prometheus, node-exporter, cAdvisor, Loki, and log collector. Keep Grafana on the current server and keep second-server telemetry ingestion/storage local to that second server to reduce Atom load.
7. Resolve host-network service access, primarily Pi-hole's web UI.
8. Correct package change reporting and bootstrap behavior.
9. Investigate certificate lifecycle, server action logging, and other dependencies uncovered during discovery.
10. Document the reasoning, migration sequence, validation, and recovery for accepted changes.

### Boundaries for this planning request

No live host changes, credential rotation, data movement, image upgrades, or deployment are included in this discussion. The request does not establish a need for a container orchestrator, database clustering, automatic failover, or a custom management platform. Add such work only if a concrete requirement justifies it.

The second server is outside the general central infrastructure rollout except for observability and the subsequently authorized backup-storage role. These integrations may require their own host access, storage, network rules, and service configuration; they do not authorize replicating the current server's full bootstrap or changing unrelated services. An isolated builder there remains an unselected contingency under the owner's separate delegation.

## Establishing the Debian 13 baseline

“Default Debian 13” needs a reproducible reference: architecture, installation image or source, installation date, installer tasks, package versions, and relevant hardware. Package defaults vary with versions and installer choices. Comparing only with today's package defaults would not explain all earlier changes.

The host inventory must distinguish four things: repository intent, effective running configuration, package/installer defaults, and proposed target configuration. Existing scripts show intent and possible mutations; they cannot reconstruct every manual change.

The [first live Debian/Pi-hole baseline](docs/investigations/2026-11-01-debian-host-baseline.md) now records package-conffile deviations, boot/driver settings, active versus persisted network configuration, resolver settings, installed APT hooks, live PAM behavior, and public certificate metadata. It also records permissions/coverage gaps. It does not replace the original-installation reference or complete privileged runtime inventory.

Collect a read-only, redacted inventory from the current server before finalizing host changes. On the second server, limit discovery and proposed changes to evidence needed for observability and backup-storage integration; do not expand this into a general host refactor:

| Evidence area | What to establish | Why it matters |
| --- | --- | --- |
| OS and packages | Debian release, architecture, repositories and signing keys, installed/held packages, package history, third-party packages, modified package conffiles, and locally added configuration. | Reconstruct package and configuration drift without equating every installed package with a customization. |
| Boot and hardware | Firmware/BIOS, boot mode and bootloader settings, active and installed kernels, kernel command line, loaded modules and overrides, device/driver/firmware bindings, microcode, and relevant boot errors. | Separate needed hardware fixes from copied tuning. No kernel flags or driver overrides should be prescribed without hardware evidence and a recovery path. |
| Resources and storage | CPU/RAM, swap/zram, filesystems and mount options, disk health where supported, free space/inodes, Docker storage driver/data root, service usage, and OOM events. | Set a measured budget for builds, databases, telemetry, and backups. |
| Networking | Effective network manager, addresses/routes, DNS ownership, listening sockets, IPv4/IPv6 forwarding and sysctls, firewall backend/rules, Docker networks, and Tailscale reachability/policy. | Diagnose Pi-hole and cross-host access using the effective traffic path. |
| Services and access | Enabled services, timers, cron, systemd overrides, SSH effective settings, PAM configuration, users/groups/sudo policy, Docker permissions, and recovery access. | Account for host-managed work that Compose does not describe. |
| Operations | Effective APT hooks, unattended-upgrade policy, journald/log rotation, certificate renewal and reload hooks, backups and restore evidence, deployment jobs, and monitoring targets. | Establish how changes are made, recorded, maintained, and recovered today. |

Collect targeted fields rather than unfiltered environment/configuration dumps. Keep tokens, private keys, passwords, sensitive process arguments, and application data out of Git. Where historical evidence is absent, mark the previous state as unknown rather than inventing a default.

For each accepted host deviation, the formal plan must record the baseline and evidence, current value, intended value, reason, affected services, apply/reboot requirements, validation, rollback, and how future drift will be detected. Do not apply either bootstrap script just to discover its effects.

## Alternatives Weighed

For second-server telemetry, the owner chose local Prometheus and Loki instances instead of sending all ingestion/storage work to the Atom. This reduces the Atom's ingestion and storage load and makes local retention possible when the connection is down, at the cost of maintaining two sets of telemetry backends and their storage budgets. Central Grafana still needs access to each backend, and its availability remains a separate concern.

The owner delegated build placement and expressed a preference for isolation, allowing the second server as a possible isolated-build fallback and bare metal if necessary. The selected working option and alternatives are:

| Build option | Mechanism and benefit | Cost, failure conditions, and disposition |
| --- | --- | --- |
| GitHub-hosted VM builds | Fresh standard Linux VM per job; the home servers receive deployable images. | Requires GitHub availability, sufficient included compute/spending controls, registry connectivity, and enough runner disk/build resources. Selected under owner delegation because it removes build pressure and build-host access from production without adding local VM infrastructure. |
| Isolated VM on the Atom | Build daemon and job workspace live in a separate guest with restricted networking and no production mounts. | Competes with all central services for 4 GiB RAM, CPU, eMMC space, and I/O. No measured spare capacity or VM support has been established. Not selected. |
| Isolated VM on the second server | Separate disposable guest and builder; no production Docker socket or secret mounts. | The owner permits considering this build-specific exception. Requires verified virtualization support, measured workload headroom, disk/network limits, cleanup, and a design for guest compromise. Contingency to evaluate if hosted builds prove unsuitable; no installation is selected. |
| Bare-metal or production-daemon builds | Reuses the present runner/Docker arrangement with little new infrastructure. | Provides weaker separation of build execution from the server's services and keeps resource contention. Docker daemon control can change host mounts/files; see [Docker security](https://docs.docker.com/engine/security/). Not selected while an isolated alternative is available; no automatic fallback on quota exhaustion. |

Database topology, secrets product/delivery, deployment transport, and updater product choices remain open. The updater's central-automatic/external-log policy is established. Preserve the mechanism, benefit, cost, failure conditions, and owner decision for each alternative discussed. In particular, do not equate a central source of configuration with a requirement to share every database process or every credential.

## Key Decisions & Staging for Next Steps

### Decision record

| ID | State | Decision or requirement | Reason |
| --- | --- | --- | --- |
| R-01 | Owner request | Cover Debian host configuration and central infrastructure together. | Several reported failures span host services, firewall rules, and containers. |
| R-02 | Owner request | Include CI deployment, secrets, updates, and a second telemetry source. | These are requirements that the original configuration does not adequately address. |
| R-03 | Owner request | Document the reasons behind the refactor using EGM. | The owner needs an explainable plan and invites detailed clarification. |
| R-04 | Owner-reported problem, 2026-11-01 | Make database account management, connectivity diagnosis, service onboarding, and migrations easier to operate. | The owner reports rejected credentials, difficulty reaching instances, and cumbersome onboarding/migrations, including Pterodactyl. Diagnose these independently before selecting a replacement topology. |
| C-01 | Owner-confirmed constraint | The owner controls both organizations using the runners; some collaborators can push code. | Define the desired build/deployment approval policy and execution privileges explicitly. Organization control alone does not describe the effective workflow policy. |
| R-05 | Owner-confirmed requirement | Serve secrets to central infrastructure, ITskolar-System, an unnamed planned system, and some Pterodactyl workloads. | Secrets must reach applications outside the central Compose project, including applications with a Pterodactyl-managed lifecycle. Delivery and per-workload authentication remain to be designed. |
| E-01 | Verified over SSH, 2026-11-01 | ITskolar currently reaches PostgreSQL over its Docker network but cannot authenticate; its roles also lack database connection privileges and expected schemas are absent. | Read-only connection and catalog checks establish separate onboarding blockers; details are preserved in the linked investigation. |
| E-02 | Verified over SSH, 2026-11-01 | Two Actions runners already run on the Atom; ITskolar's checked workflow does not explicitly select the production Compose override that supplies its database network. | CI must account for existing trust/access and use a consistent production configuration. Historical workflow causality remains unverified. |
| D-01 | Owner confirmed, 2026-11-01; backup-storage exception added by D-12 | Keep the central infrastructure on the Atom server; deploy observability components on the second server, excluding Grafana. | The owner limits the general infrastructure rollout. D-12 subsequently authorizes backup storage there; the second server must not become an assumed destination for other central services. |
| D-02 | Owner confirmed, 2026-11-01 | Use `Hardware_Info.md` for the current server and `new_server_hardware.md` for the second server. | The owner confirmed the first remains accurate and supplied the second as the hardware reference. |
| D-03 | Owner confirmed, 2026-11-01 | Run Prometheus, node-exporter, cAdvisor, Loki, and Promtail or a replacement on the second server; each server owns its Prometheus/Loki instance. | Store and ingest second-server telemetry on that machine to alleviate strain on the Atom. Grafana remains central. |
| D-04 | Owner confirmed | Permit CI-initiated production deployment after the owner's explicit approval or when the pipeline-triggering event was initiated by the owner. | Collaborators can push code, while the owner retains production authorization. Exact trigger/re-run semantics and enforcement remain design work. D-08 separately authorizes central image maintenance. |
| D-05 | Agent-selected working design under explicit owner delegation | Build images on standard GitHub-hosted Linux VMs; keep builds off the Atom and do not install a builder on the second server in the selected design. Use free/included compute with no paid overages assumed. | Avoid build contention on the Atom and local VM administration, and separate build execution from production host access. Verify repository allowance, build compatibility, and registry/deployment transport before implementation. An isolated second-server VM is a contingency, not an automatic fallback. |
| D-06 | Owner-confirmed hard constraint | Integrate secret delivery without modifying application or application startup code. | Preserve existing configuration inputs and perform delivery through supported deployment/host configuration. SDK integration, changed application credential-loading logic, and modified startup scripts are outside the allowed approach. |
| D-07 | Owner-confirmed operating requirement | Apply changed secrets by restarting the affected service; the ops admin may perform this manually. | No application hot-reload implementation or automatic lifecycle change is required. Runbooks must load fresh inputs before the restart/recreation and coordinate upstream credential changes with the manual rollout. |
| D-08 | Owner-confirmed operating requirement | Automatically apply detected central-infrastructure image updates and restart/recreate affected services; for external services emit an update log collected by Loki and alert the owner without changing the application. | Central maintenance is automatic while external rollout remains application-controlled. D-09 exempts database major-version upgrades. Notification routing and implementation details remain to be defined. |
| D-09 | Owner-confirmed exception | For database major-version upgrades, emit an update log collected by Loki and alert the owner without automatically upgrading the database. | The admin controls data migration and compatibility validation. The updater must enforce engine-specific release limits and discover new major releases without applying them. |
| D-10 | Owner-confirmed existing capability | Reuse production Grafana alerting, including existing Discord and the owner's “nfty” webhook destinations. | Existing notification infrastructure already meets the destination requirement. Add the required update rules while preserving current routing/state; authenticated inventory and delivery verification remain outstanding. |
| D-11 | Owner-confirmed recovery requirement | Allow zero secret loss and at most 24 hours of database/Pterodactyl-backup loss after a server failure. Application uploads are not processed and need no separate backup scope. | Size recovery around these limits. Independent secret durability, failure scope, recovery material, destinations, retention, and restore evidence still need design; no current guarantee has been established. |
| D-12 | Owner-selected recovery targets | Use Cloudflare R2 and the second server for recovery copies; both need setup from scratch. | Provide independent-host and off-site recovery targets. This adds a limited backup-storage role on the second server. No working backup, capacity allocation, or zero-loss mechanism is yet verified. |
| D-13 | Owner-confirmed coverage and availability trade-off | Account for all six failure scenarios; defer secret changes while R2 or required update prerequisites are unavailable. | The owner accepts waiting without operational impact. Preserve existing valid service inputs and require off-site recoverability before acknowledging a new secret version. Exact product/workflow enforcement and recovery testing remain outstanding. |
| D-14 | Owner-confirmed recovery-time requirement | All services may be taken down. Restore manually when the sysadmin has time, with no fixed restoration deadline, while preserving the agreed data-loss limits. | Prefer durable copies, recovery material, and tested rebuild/restore procedures. No automatic failover or extra application standby is required. Retention must still preserve an available recovery point through downtime. |
| D-15 | Owner-confirmed target role | Pi-hole should provide DNS, NTP, and ideally DHCP. | Preserve the desired DHCP role while selecting networking and fixing web access. Current Pi-hole DHCP is disabled; the router provides DHCP today and will be disabled after Pi-hole validation and controlled cutover. Establish broadcast delivery, fixed management addressing, lease/reservation settings, and rollback before enabling LAN-wide service. |
| D-16 | Owner-confirmed access policy | Preserve internal-only Pi-hole and database/database-administration access; Grafana may remain externally reachable through the current solution. | Connectivity fixes must retain the existing exposure boundary. Verify effective LAN restrictions and authenticated Grafana access. No expansion to additional VPN networks or public secret-manager endpoint is assumed. |
| R-06 | Owner-confirmed minimum audit requirement | Record package installations, kernel/driver tweaks, and nonstandard/state-changing shell command executions, excluding ordinary read-only commands such as `cd`/`ls`. Identify related useful events in the design. | The owner needs evidence of host changes and invites completion of the scope. D-18 selects useful command detail; reliable capture/classification, redaction implementation, and the detailed native auditing approach remain open. |
| D-17 | Owner-confirmed investigation horizon | Keep about one month of audit history; use 30 searchable days as the working retention target. | Size Loki and local collection accordingly and expose capacity/loss problems. This does not automatically set backup, secret-version, or all other telemetry retention. |
| D-18 | Agent-selected detail under explicit owner delegation | Record safe command/script identity and arguments, time/host/context, original/effective actor and origin, affected resources, and actual outcome where observed; omit unsafe arguments and identify missing information. | Reconstruct administrative changes without collecting credentials or misleadingly treating a launched process as a successful operation. Exact capture coverage and filtering need verification. |
| E-03 | Verified over SSH | Pi-hole serves HTTP 200 from the host on port 8080, while nginx's request to its configured host-gateway upstream times out. Live PAM already uses `/run/motd.dynamic`; the faulty custom APT hook remains installed beside the package hook. | Use the live baseline to narrow networking diagnosis and separate script fixes from changes still needed on the host. Privileged firewall access remains unavailable. |
| P-01 | Pending design/verification | Database boundaries, secrets product/publication/delivery, deployment authorization/transport, collector/updater products, network/certificate mechanics, audit capture, storage budgets, backup retention, and recovery implementation. | The working constraints are recorded. Select feasible mechanisms, resolve trade-offs, and verify preflight gaps through review and drafting rather than imply that owner requirements alone establish implementation guarantees. |

### EGM progression

Continue open-ended clarification one question at a time, updating this file with evidence and owner decisions. Once the problem and boundaries are established, present the working hypothesis for the owner's explicit readiness confirmation. Only then run fresh-context Goldfish reviews, preserve objections and responses, and finalize this brief.

After agreement on the brief, use EGM drafting to produce the formal design and migration plan. That plan must map each requirement to changes, prerequisites, reasoning, acceptance checks, and rollback. The migration must account for surviving a DNS, secret-store, registry, or telemetry outage and for database changes that cannot be undone by reverting a container image.

### Current discussion focus

The owner confirmed readiness for independent Goldfish reviews on 2026-11-02. Review the anchored working hypothesis in fresh contexts, retain objections and responses, and refine the brief before the formal design handoff. Product/implementation choices and preflight evidence gaps remain explicit review work; the review approval does not authorize production changes.

## Goldfish brainstorm synthesis — 2026-11-02

All six requested independent Goldfish lenses completed in fresh contexts: architecture/economics, operational debugging, simplicity/reuse, operator ergonomics, migration/compatibility, and long-term maintenance/coupling. Each read the full original 417-line brief and both immutable investigation reports and verified brief SHA256 `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`. No reviewer was counted from launch alone; none failed, required retry, or missed a mandatory read. See the [consolidated review](goldfish_review_report.md) and [raw reports/read manifests](docs/reviews/2026-11-02-goldfish-raw-findings.md).

The synthesis groups 41 raw findings into **0 demonstrated concept-feasibility Blockers, 12 Major risks, and 1 Nit**. Reviewers considered the recovery-first, fixed-placement approach plausible; this is not evidence that pending mechanisms already meet the requirements. Review completion does not finalize the brief, approve implementation, select products, or authorize production changes. Existing owner decisions, delegated working decisions, scope boundaries, and evidence limits above remain in force.

### Consequential risks and derived design constraints

* **Protected publication and existing-input delivery (M-01):** demonstrate one controlled, crash-recoverable secret publication path with protected R2 recovery before acknowledgment, safe retry/reconciliation, no bypass through another administrative interface, and separate durable/backend/consumer activation evidence. Test an environment-only consumer and an actual relevant Pterodactyl workload without application/startup changes before committing to a mechanism. A supported admin-operated workflow is a candidate; a custom management platform is not assumed.
* **Active configuration and authorized lifecycle (M-02, M-06):** staged secrets must not become active because an automatic image update recreates a container. Preserve explicit active inputs and artifact identity, serialize writers, and validate the combined operation. Carry the current admin-initiated activation working plan forward rather than asking the owner to repeat it. Retire/restrict old runner paths during CI cutover and classify stateful image updates by compatible release/recovery boundaries.
* **One measured capacity budget (M-03):** select secrets, audit, telemetry, backup, and updater mechanisms against combined memory/disk/I/O usage and maintenance peaks on both machines. Existing snapshots and configured limits establish neither adequate headroom nor infeasibility. Include Grafana queries, backup scratch, image retention, and independent second-host workloads. Preserve 30 searchable audit days; reduce unrelated telemetry noise before treating that horizon as negotiable.
* **Compatible recovery and adoption (M-05, M-07):** restored data, accounts/schema, secret versions, configuration, images, and Pterodactyl metadata/files must work together. Preserve the last usable recovery set through downtime, provide a recovery entry point independent of the failed platform, and test a clean restore. Adopt existing database state and establish actual consumer readiness before topology or endpoint changes; the verified provisioning defects do not require per-application database processes.
* **Bounded host and observability migration (M-08, M-10, M-12, N-01):** converge one host target without replaying obsolete bootstrap assumptions; separate Pi-hole UI repair from DHCP authority transfer and preserve recovery networking. Keep native audit sources and explicit uncertainty rather than invent a universal command classifier. Preserve available history, mark its effective coverage start/gaps, protect existing Grafana state/routing, and define update-pending/resolution/scan-health semantics. Bound historical reconstruction where original evidence is unavailable.

These are research and drafting obligations, including concerns already anticipated above. They do not require every script/task to be executable at brainstorm stage and do not select a new topology or product.

### Unresolved objections requiring interpretation

1. **Combined outage and recovery-point limit (M-04):** if required off-site backups remain unavailable for more than 24 hours while database/Pterodactyl writes continue, subsequent loss of both home hosts may exceed the stated loss limit. Clarify the covered failure combination and any degraded-write/shutdown boundary; an alert alone cannot enforce the limit. No requirement is relaxed by this observation.
2. **Local raw-command privacy (M-09):** the brief acknowledges sensitive arguments in restricted raw audit records but also requires safe omission/redaction. Clarify whether such arguments may persist locally at all. Test the selected boundary across raw records, spools, rotation, backups, and forwarded Loki fields, rather than checking forwarding alone.
3. **Central-alerting blackout (M-11):** second-host local collection does not guarantee notification when the Atom, Grafana, or their query path is down. Explicitly accept that blackout or define narrowly scoped independent detection within the existing destinations and authorized deployment scope. No additional Grafana or notification stack is selected.

The existing open D-04 trigger/re-run semantics, second-host observability update authority, and any separately proposed VPN-access expansion also remain unresolved. Product/delivery/publication, database ownership/topology, transport, collector/updater, compatible recovery sets/retention, capture rules, certificate/network evidence, and sizing still require bounded alternatives and validation. The review makes no new remote observations; both investigation reports remain unchanged. Resolve or explicitly carry these objections into the next EGM discussion before claiming final agreement on the brief or implementation readiness.

## Post-review clarification

### Backup fallback and connectivity assumption — M-04

The owner confirms that database/Pterodactyl backups can continue to the second server while R2 is unavailable. If both recovery destinations are unreachable, the owner considers loss of Internet connectivity likely and permits assuming no new externally arriving data in that situation. These are operating assumptions for the design, not evidence that either unconfigured target currently works.

| Condition | Working treatment | Remaining qualification |
| --- | --- | --- |
| R2 unavailable, second-server backup succeeds | Continue using the second server as a recoverable backup target for database/Pterodactyl state. Track each destination's successful recovery points separately and catch R2 up when it returns. | A fresh second-server copy protects against loss of the Atom, but not simultaneous loss of both home hosts before the remote copy is refreshed. |
| R2 and second-server backup destinations unavailable | Use the owner's assumption that no new data is arriving because connectivity is likely down. Preserve existing data and recovery points; avoid treating missing connectivity as a successful backup. | No incoming traffic does not establish that background jobs, game worlds, local users, queues, or scheduled work stop writing. Check actual workload behavior before relying on a no-write assumption. |

Secret publication remains governed by D-13: defer changes while the required off-site durability step is unavailable. The database/Pterodactyl fallback does not change zero-loss secret acknowledgment.

M-04 is partially clarified, not closed for every accepted failure combination. An extended R2 outage followed by loss of both home machines can still leave only an older off-site recovery point even if second-server backups succeeded throughout the outage. The owner's acceptance or rejection of this temporary whole-site exposure still needs confirmation; do not silently relax the 24-hour loss requirement or claim the second-server copy survives that event.

### Accepted temporary off-site exposure — M-04 / D-19

The owner explicitly accepts the combined case described above: while R2 is unavailable, database/Pterodactyl backups may rely on the second server, and subsequent loss of both home hosts may exceed the 24-hour data-loss target. This resolves the pending acceptance question in the preceding paragraph. It is a documented exception during the off-site outage, not a claim that a local backup survives loss of the site.

The normal database/Pterodactyl target remains a successful, recoverable point no older than 24 hours. Do not stop these services solely because R2 is unavailable while second-server protection remains healthy. Track destination freshness separately, expose degraded off-site protection, retain the last usable copies, and resume off-site protection when R2 returns. If both destinations are unavailable, retain the connectivity assumption and workload-write qualification above; neither an alert nor loss of incoming traffic establishes a successful backup. D-13 remains unchanged for secrets: require off-site protection before acknowledging a new secret version.

| ID | State | Decision | Reason |
| --- | --- | --- | --- |
| D-19 | Owner confirmed, 2026-11-02 | Accept temporary loss beyond 24 hours for databases/Pterodactyl if both home hosts are lost during an R2 outage; use the second server for backups during that outage. | The owner accepts this combined-failure exposure rather than requiring a second off-site destination or stopping otherwise protected services. |

### Command-audit privacy boundary — M-09 / D-18 refinement

Under the owner's delegation to select the most useful command details, use the stricter privacy boundary: retain safe metadata and explicitly reviewed argument fields only. Omit unreviewed or unsafe arguments before they enter any newly introduced retained record, including local raw records, spools, rotated archives, backups, and Loki. Do not introduce arbitrary raw command-line or terminal-transcript persistence and rely on redacting it only during forwarding.

This refines D-18; it does not promise a universal secret detector or perfect identification of every state-changing command. If a native source cannot meet this boundary, select metadata-only capture or another bounded source and document the resulting coverage gap. Existing logs and their argument exposure still need inventory; this decision neither erases them nor establishes their safety. Before enabling the selected collection path, use a harmless sensitive-value marker to check every retained form, including failure/spool paths. M-09's policy ambiguity is resolved by this delegated choice; feasibility and coverage remain implementation gates.

### Accepted central-alerting interruption — M-11 / D-20

The owner reports an existing healthchecks.io setup on both servers that notifies them when a server is down. Preserve those checks as the existing server-down notification path. Their configuration, delivery behavior, and exact failure coverage have not been inspected during this planning work.

The owner accepts interruption of the remaining Grafana-based alerts while the Atom, central Grafana, or its query path is unavailable. No additional independent notification service, second Grafana instance, or secondary alert-routing stack is required. Each host's telemetry collection/storage should still continue independently where that host remains operational, within the selected retention and resource budget. Recover current update-pending and collection-health state after service restoration; do not equate local data collection with uninterrupted notification delivery.

| ID | State | Decision | Reason |
| --- | --- | --- | --- |
| D-20 | Owner confirmed, 2026-11-02 | Accept interruption of Grafana alerts during central alerting outages; preserve the existing healthchecks.io server-down checks on both machines. | The owner already has server-down notification and considers the remaining alerts noncritical during that outage. |

## Review disposition and formal-design handoff

The three post-review policy ambiguities now have explicit dispositions: M-04 has the owner's accepted temporary off-site exposure in D-19; M-09 has the stricter pre-storage privacy boundary selected under D-18's delegation; M-11 has the accepted alerting interruption in D-20. These follow-up decisions supersede the corresponding pending questions in the frozen review material above. The original 417-line reviewed brief and both investigation reports remain unchanged so the review's evidence can be traced.

The remaining review findings are design and validation obligations, not closed implementation work:

| Finding | Disposition to carry into the formal design |
| --- | --- |
| M-01 — protected secrets and existing-input delivery | Compare bounded mechanisms and prove off-site recovery before acknowledgment, recovery after interruption, and delivery to real environment/file/Pterodactyl consumers without application or startup-code changes. Do not claim zero loss from an asynchronous export. |
| M-02 — one active configuration and lifecycle path | Define active versus pending inputs, artifact identity, serialization, manual secret activation, and retirement/restriction of old runner deployment paths. An automatic image recreation must not activate a pending secret. |
| M-03 — combined resource budget | Measure both hosts and budget steady use plus maintenance peaks, telemetry/audit retention, backup scratch, and image storage. Keep central infrastructure on the Atom and second-host ingestion/storage local. |
| M-04 — combined outage | Policy resolved by D-19. Implement per-destination recovery-point tracking and the documented fallback; validate background-write assumptions rather than infer them from lost connectivity. |
| M-05 — compatible recovery sets | Define the data, roles, secret versions, configuration, images, Pterodactyl state, independent recovery kit, and retention needed for a usable restore after prolonged downtime. Test isolated recovery. |
| M-06 — stateful updates | Define allowed release series, preconditions, consistent recovery points, and restore compatibility. Image reversion alone is insufficient for a changed on-disk format. |
| M-07 — database adoption and onboarding | Adopt existing state before changing endpoints; separate account/database provisioning from application schema migrations. Validate real consumer access and fix the evidenced password, CONNECT, and schema blockers. Compare process topology on its own merits. |
| M-08 — coherent host target | Map effective Debian settings to one maintained target with rationale, uncertainty, management access, validation, and rollback. Repair Pi-hole UI access separately from the router-to-Pi-hole DHCP cutover. |
| M-09 — audit privacy | Policy resolved by the D-18 refinement. Verify safe capture across all newly retained forms before enabling it and state the coverage limits. |
| M-10 — bounded audit coverage | Use native sources with explicit attribution, observed outcome, continuity/gap reporting, and 30 searchable audit days. Do not design a universal shell-command classifier. |
| M-11 — central-alerting interruption | Policy resolved by D-20. Preserve existing healthchecks.io checks and Grafana destinations; no new independent alerting stack is required. |
| M-12 — durable update status | Define pending, applied/resolved, scan failure, and stale-scan state so notification does not depend on one transient log entry. External applications remain alert-only. |
| N-01 — historical Debian reconstruction | Bound reconstruction using available package/installer/runtime evidence; identify unknown history rather than invent a complete clean-install comparison. |

The formal design must still settle consequential choices through bounded alternatives, including secrets publication/delivery, database ownership/process layout, CI authorization and transport, collector/updater tooling, network/certificate mechanics, and storage/retention. D-04's exact rerun/revision authorization semantics and the second server's observability update authority remain explicit design questions. Existing access boundaries remain in force; VPN access is not silently broadened. These questions may be addressed while drafting; the handoff does not imply that an unselected mechanism is approved or feasible.

**Current stage:** brainstorm refinement is ready for owner alignment and handoff to EGM drafting. Formal drafting and production changes have not begun. The requested next artifact is a design and migration plan covering the Debian baseline, target infrastructure, reasoning and alternatives, affected files, prerequisites, validation, and recovery. Preserve the existing evidence and raw review reports as historical records.

### Owner alignment and private-repository clarification — 2026-11-02

The owner confirms that ITskolar-System is private and approves this brief with that clarification. This resolves the earlier repository-visibility uncertainty for ITskolar-System; the connector's previous 404 remains an access observation, not evidence that the repository was absent. Other repositories' visibility, organization plans, Actions allowances/usage, approval-feature availability, and registry storage still require their own verification. Do not infer a paid plan or an available private-repository approval mechanism from this confirmation.

| ID | State | Decision or fact | Consequence |
| --- | --- | --- | --- |
| D-21 | Owner confirmed, 2026-11-02 | ITskolar-System is a private repository. | Design CI within the actual private-repository plan, allowance, and authorization capabilities; preserve source/image access restrictions. |

The brief is approved as the requirements input to formal EGM drafting. Continue in [design_draft.md](design_draft.md), beginning with Overview, Problem, Goals, and Non-Goals. This stage update supersedes the previous handoff-pending text; the frozen review input and historical findings remain unchanged. Approval of the brief does not close the technical choices or validation obligations above.

### Formal drafting progress — 2026-11-02

The owner approved Overview & Goals in [design_draft.md](design_draft.md). Continue with the Technical Plan, resolving the remaining consequential architecture choices rather than treating that section approval as selection of an unproven product or topology. [Database layout options](docs/designs/database-boundaries.md) provide the first decision input; no layout has been selected yet.

### Shared database engines selected — D-22

The owner selected shared engines for the Technical Plan. Keep one centrally operated PostgreSQL service and one MariaDB service, with application-specific databases/accounts, explicit provisioning ownership, and application-owned schema migrations through their supported tools. Address the verified onboarding defects and make production consumer configuration explicit. Do not migrate every application to a dedicated engine process to solve those defects. The [database comparison](docs/designs/database-boundaries.md) retains the benefits, shared failure/maintenance costs, and unselected dedicated-container alternative. Existing data adoption, least-privilege details, resource fit, and recovery still require validation.

| ID | State | Decision | Reasoning carried into the plan |
| --- | --- | --- | --- |
| D-22 | Owner confirmed, 2026-11-02 | Use shared PostgreSQL and MariaDB engines with application-specific database/account ownership. | Concentrate the refactor on repeatable provisioning, consumer configuration, migrations, and recovery while avoiding additional engine instances on the Atom. Engine-level administration and maintenance remain shared. |

Continue the Technical Plan with the [secrets publication/delivery comparison](docs/designs/secrets-publication.md). Product choice is still pending; zero-loss acknowledgment, no application/startup-code changes, manual activation, and the protected off-site requirement remain unchanged.

### Vault added to the pending secrets comparison

The owner asked why HashiCorp Vault was missing from the shortlist. It had no demonstrated requirement-based disqualifier; the comparison now includes SOPS/age, OpenBao, and Vault Community. Primary-source checks establish a current licensing difference, not an internal-use prohibition, and no comparative measurement establishes that OpenBao is lighter. Vault's local integrated-storage and possible S3/R2 variants have their own compatibility, resource, and retained-recovery requirements. The [comparison](docs/designs/secrets-publication.md) records those trade-offs. This clarification selects no product and changes none of the agreed durability/delivery constraints.

### Vault preferred, with prompt disclosure of problems — D-23

The owner prefers HashiCorp Vault and asks to be told immediately about problems it may introduce. Carry Vault Community forward as the preferred secrets-service direction; report verified problems, requirement conflicts, and unproven feasibility separately. Keep the shared-engine decision, no application/startup-code changes, protected off-site acknowledgment, manual consumer activation, and accepted outage policy intact. Do not switch to OpenBao/SOPS or weaken those constraints without the owner deciding the trade-off.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-23 | Owner preference, 2026-11-02 | Prefer Vault Community for the secrets service and promptly report problems. | Product direction is selected for further design; capacity, protected publication/recovery, installed-consumer compatibility, and operating profile remain to be validated. |

The [Vault operating considerations](docs/designs/vault-operations.md) record the known publication/ordinary-write gap, seal behavior after restart, resource/swap requirements, audit availability/privacy, shared-host exposure, and remaining consumer/upgrade validation. They distinguish native product behavior from unverified target-host feasibility. The pending profile choice makes the proposed local integrated storage and manual-versus-cloud-assisted unseal trade-off explicit; no KMS account, paid resource, live Vault instance, or host setting has been created or changed.

### AWS KMS unseal with independent recovery exports — D-24

The owner selected option 3 after reviewing the native seal-fallback limitation: run Vault Community with local integrated storage and native AWS KMS auto-unseal; keep independently encrypted exports on the second server and R2 so an admin can rebuild a fresh Vault if the original KMS key/access cannot be recovered. This is a rebuild/restore fallback, not a second mechanism that can unlock the existing KMS-sealed store. Do not add a Transit service, Enterprise Seal HA, or a custom Shamir-unseal helper to the selected design. The second server retains its observability and backup-storage roles.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-24 | Owner selected option 3, 2026-11-02 | Local Vault integrated storage with AWS KMS auto-unseal and independent encrypted recovery exports to the second server/R2. | Accept manual rebuild recovery when KMS is permanently unavailable. The old store/snapshot can still depend on the old KMS key; recovery keys alone cannot replace it. Preserve the zero-loss acknowledgment boundary and no fixed restoration deadline. |

The [selected recovery profile](docs/designs/vault-operations.md) defines the required exported scope, independent decryption/access route, and clean-rebuild test. To make the second-server fallback current under the zero-loss requirement, the proposed publication workflow will verify the complete encrypted candidate and matching receipt in both R2 and the second-server recovery location before acknowledging the managed change. This is a derived implementation precondition of the selected fallback, not a new owner statement about availability; D-13 already permits waiting for required update prerequisites. If either destination is unavailable, defer new secret changes and preserve active inputs. Database/Pterodactyl fallback and D-19's accepted exception remain separate.

### Owner actions authorize the complete selected revision — D-25

The owner confirms that an eligible production push or rerun initiated by them authorizes deployment of the complete selected revision, including commits written by collaborators. Bind that authorization to the actual source/build attempt and resolved artifact. Do not require another approval solely because some included work was collaborator-authored, and do not confuse a collaborator rerunning an originally owner-initiated run with a current owner action.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-25 | Owner confirmed, 2026-11-02 | An eligible owner-initiated production push/rerun authorizes the entire selected revision, including collaborator commits. | Completes D-04's revision interpretation. Actual initiator, intended target, successful checks, and exact artifact remain part of enforcement; author text and original-run privileges are insufficient. |

The [authorization document](docs/designs/ci-authorization.md) carries the confirmed rule into the proposed event matrix and validation cases. Continue with the [deployment transport comparison](docs/designs/ci-deployment.md). Its shared GHCR and owner-only approval-workflow components are proposals for the profile decision, not already-selected dependencies or live changes.

### Restricted OpenSSH deployment over Tailscale selected — D-26

The owner selected deployment profile B: hosted builds publish to GHCR, and a separate deployment job submits bounded requests over restricted OpenSSH/Tailscale to the Atom. This selects the profile's common private owner-controlled approval repository/workflow for collaborator-originated builds and production-side GitHub metadata verification. Owner-initiated eligible runs retain D-25's complete-revision authorization without a redundant approval action.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-26 | Owner selected B, 2026-11-02 | Use restricted OpenSSH submission over Tailscale, GHCR images by digest, a private owner-controlled approval workflow, and the Atom's independent authorization/execution boundary. | Allows direct request submission while keeping the SSH credential separate from deployment authority. Only a narrow CI-to-Atom submission path is added; no general private-network access, production Docker control, or CI installation on the second server is selected. |

The [selected deployment design](docs/designs/ci-deployment.md) retains the polling alternative and defines the submission/privileged-execution separation. Package permissions, GitHub App installations, trusted workflow/repository identities, Tailscale federation/tag rules, SSH forced commands and credentials, canonical configuration, operation state, and cutover of the old runners remain implementation/verification work. No repository, key, tailnet rule, or host service was created or changed during selection.

Continue with the [maintenance policy](docs/designs/maintenance-policy.md). CI deployment, central image maintenance, and manual secret activation must share controlled lifecycle behavior. The second server's observability-container update authority is still a distinct unresolved policy; D-26 does not grant CI control of that host or decide its image-maintenance behavior.

### Second-server observability maintenance — D-27

The owner's “yes please” is carried forward as assent to automatic compatible updates for the second server's observability containers. This interpretation was stated in chat. Enroll only that host's Prometheus, node-exporter, cAdvisor, Loki, and supported log collector, with the compatibility, recovery, active-input, and serialized lifecycle checks used for central infrastructure. Unrelated applications remain alert-only. This does not extend the Atom-only CI submission identity, authorize automatic OS upgrades, or enroll the separately authorized backup-storage service for automatic replacement.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-27 | Owner assent interpreted in context, 2026-11-02 | Automatically apply compatible image updates to the second server's enrolled observability containers. | Keep maintenance consistent with central observability while preserving local collection/storage, independent applications, and the restricted CI boundary. Missing prerequisites defer an update. |

The [maintenance policy](docs/designs/maintenance-policy.md) now records the selected scope and preserves the alert-only alternative. The next drafting decision is the maintained Debian configuration approach and its proposed supporting tools; no host packages, services, or credentials have been changed.

### Different configuration approaches for the two hosts — D-28

The owner selects approach B (modular shell scripts plus Compose) for the main Atom server and approach A (Ansible plus Compose) for the second server. This refines the offered profiles into a per-host split. The [tooling comparison](docs/designs/operations-tooling.md) carries the common Alloy, regctl, Restic/rest-server, age, supported object-client, and bounded native-audit proposal into the Technical Plan under that split. Resource fit, privacy, repository protection, delivery, and recovery remain validation gates.

| ID | State | Decision | Reason or limit |
| --- | --- | --- | --- |
| D-28 | Owner selected split, 2026-11-02 | Use modular shell scripts on the main server and workstation-run Ansible on the second server, retaining Compose and the shared operating-tool proposal. | Each host has one configuration owner. Maintain two configuration methods deliberately, with common policy/event/lifecycle formats; do not run both against the same managed host settings. |

Ansible's inventory must exclude the main server from application targets. Its second-host scope remains observability and authorized backup storage with necessary maintenance/access configuration, not central-service replication or wholesale adoption of independent applications. Main-server scripts must not configure the second server through an alternate remote path. Both methods enter controlled service lifecycle operations instead of bypassing authorization, active/pending inputs, or serialization. The formal Technical Plan is now being drafted for its section review; this decision authorizes documentation, not live installation.

**Current drafting stage:** [Technical Plan](design_draft.md#technical-plan-architecture) is written and awaiting owner section approval. It proposes the concrete integration, retained-data boundaries, maintained Debian target, staged adoption and feasibility gates under D-01–D-28. It has not been approved or implemented. Alternatives Considered and Detailed Implementation remain the next EGM sections; their approval gates are still required. The historical brainstorm-stage wording above remains part of the provenance record.

### Technical Plan approved; alternatives drafted — 2026-11-02

The owner explicitly approved the Technical Plan. Preserve its architecture and implementation acceptance gates; approval is not evidence that capacity, privacy, backup protection, real-consumer integration or recovery tests have passed. The approved Technical Plan body, between its heading and the next top-level section, has SHA-256 `86bd28ed587b6d5cf88f4fc20cf51739c5a892f122ef4d824d1116b8a1337eed` before insertion of the alternatives section.

**Current drafting stage:** [Alternatives Considered](design_draft.md#alternatives-considered) is drafted for owner section review. It records the original build-placement alternatives and subsequent database, secrets/seal, deployment, lifecycle, telemetry, recovery and host-configuration decisions without reopening them. Detailed Implementation remains next after that approval. No production configuration or live service was changed.
