# Container maintenance and lifecycle policy

* **Date:** 2026-11-02
* **State:** Central/external rules are confirmed. D-27 carries the owner's assent forward as automatic compatible updates for the second server's observability containers. Watcher tooling is not selected here.
* **Context:** [Approved brief](../../concepts_brief.md), [selected CI profile](ci-deployment.md), and [Vault publication/activation contract](secrets-publication.md).

## Workload classes

Classify services in an admin-controlled inventory. An image name, caller-supplied request field, or application-controlled container label alone must not grant update authority. Discovery of an unknown container can identify a missing inventory entry; it does not enroll that container for automatic changes.

| Workload class | Confirmed behavior |
| --- | --- |
| Enrolled central infrastructure on the Atom | Detect and automatically apply compatible image updates through the controlled lifecycle path, with data/configuration/recovery prerequisites and observed results. |
| PostgreSQL/MariaDB release changes requiring major/series migration | Detect and log/alert for admin action; do not automatically migrate. Define compatible release lines using each engine's upgrade rules, not a generic first-number test or moving tag alone. |
| External Compose applications | Detect image updates and emit actionable Loki state for existing Grafana notification routing. Their approved CI/admin deployment process controls rollout. |
| Pterodactyl-managed applications | Use the external log/alert policy. The infrastructure watcher never replaces Wings-managed application containers directly. Image monitoring does not establish that game/plugin/application files inside a volume are current. |
| Unrelated applications on the second server | Keep application ownership independent. Enrollment for update detection does not authorize rollout; use the external alert-only rule. |
| Second-server observability containers | Automatically apply compatible updates to enrolled Prometheus, node-exporter, cAdvisor, Loki, and log-collector containers under D-27. Preserve host-local collection/storage and apply the same lifecycle prerequisites. |
| Unknown containers or unclassifiable candidates | Report the inventory/classification issue and defer changes. Preserve the running deployment and last known scan state. |

Database major/series discovery needs its own supported release/tag source in addition to watching the currently allowed channel. A changed digest under a current-series tag alone cannot reveal every newly published major release. Define the observed running artifact, tracked update reference, and allowed release boundary independently; immutable deployed digests and mutable discovery references have different purposes.

## Shared lifecycle contract

The CI submitter, automatic updater, and manual secret activator are distinct request origins, with different authorization. They must use the same host-controlled rules for an enrolled service. Keep this as bounded operational tooling; no new orchestration platform, public administration API, or general command dispatcher is required.

1. **Validate origin and scope.** CI uses D-04/D-25/D-26's platform evidence. Central image maintenance uses D-08's service-specific permission and compatible channel. Manual secret activation uses the ops-admin operation and a protected published version. None of these authorities implicitly substitutes for the others.
2. **Serialize changes.** Use one host lifecycle lock across the controlled deployment/update/activation operations on that host, together with a durable operation record. This favors simple, explainable ordering on the Atom. A released lock after a crash does not establish a completed operation: reconcile the record before another mutation. Root actions outside this path remain an operational/audit limit, not something a file lock can prevent.
3. **Resolve intended inputs.** Fix the image digest, canonical configuration identity, and explicitly active secret/configuration version before replacing anything. Stage pending secret material separately. A new native KV version, newly rendered pending file, moving tag, or SSH reconnect must not change those choices silently.
4. **Check recovery and dependencies.** Establish service-specific compatibility and a usable recovery point/configuration set before applying an image that can change persistent state. For Vault, check required KMS/bootstrap access before an avoidable restart. For other services, define their own readiness and restoration checks. Defer on missing/failed prerequisites while preserving the current deployment.
5. **Apply through the intended manager.** Pull and recreate the enrolled Compose service with its existing data mounts and selected inputs. Pterodactyl application changes, when separately authorized by their application owner, use the panel/Wings lifecycle. Do not let a discovery tool become an independent second writer that bypasses these rules.
6. **Observe the actual outcome.** Record process/container startup, service readiness, and real consumer validation separately. A pull, successful command launch, SSH exit, or healthy database daemon alone does not prove application readiness. Keep a clear pending/failed/uncertain result if confirmation is unavailable.
7. **Recover deliberately.** Use compatible data/configuration/artifact state and an explicit recovery operation. Reverting an image alone does not reverse a data migration. Keep the previous usable recovery set and incomplete-operation evidence; avoid repeated automatic restart/rollback loops.

The lifecycle inputs are host-controlled; the request contains bounded identifiers. Protect runtime inputs and API/registry credentials from application/workflow write access. A manual secret activation coordinates upstream credential changes, container input recreation, validation, and later revocation; it does not become automatic because an image update happens between those steps.

The second server keeps its own local collection/storage when the link or central Grafana is unavailable. Scope its automatic maintenance to the enrolled observability services through a separately bounded maintenance identity/operation. D-26's CI identity remains limited to the Atom. No remote Docker TCP endpoint or general second-host deployment role follows from this policy. The backup-storage service is a separate role; its updates remain alert/manual unless separately authorized.

## Second-server observability decision and alternative

The affected services are that host's Prometheus, node-exporter, cAdvisor, Loki, and supported log collector. Grafana stays on the Atom. This choice does not cover unrelated applications, OS packages, or the Atom's central services.

| | Automatic compatible updates | Alert-only updates |
| --- | --- | --- |
| Mechanism | Enroll only those observability services in automatic maintenance, with the same compatibility/recovery/active-input checks used for central infrastructure. | Detect candidates, log persistent update state to that host's Loki, and let existing Grafana rules notify the owner; an admin performs rollout. |
| Benefit | Maintains this observability deployment under the same automatic policy as central infrastructure. | Keeps each second-host image change under direct admin control and requires no automatic remote replacement authority. |
| Cost | Define narrowly scoped maintenance execution, service-specific data recovery, and behavior when the controller/link is unavailable. The existing backup-storage role does not by itself grant Docker management. | More manual maintenance; available updates can remain pending until the admin acts. Preserve scan freshness and reminders so this does not disappear silently. |
| Failure treatment | Failed checks or unavailable control/link defer updates; they must not stop an otherwise functioning local telemetry stack or broaden execution to unrelated apps. | Missing/stale scans and pending updates remain explicit. Grafana notification interruptions remain accepted under D-20; healthchecks.io continues its existing server-down role. |

D-27 selects automatic compatible updates. Alert-only remains the unselected alternative, preserved to explain the operating trade-off. Service enrollment, execution permissions, and recovery must still be implemented and validated; selection is not proof of safe rollout.

## Update state and alert behavior

Detection must distinguish a pending update, successful application, explicit deferral, scan failure, and stale collection. Persist the latest verified observation and applied state; emit a safe state record on successful scans so an outstanding update does not vanish solely because a one-time log ages out of an alert window. A failed scan retains the previous known candidate/pending state and separately marks freshness failure.

Use stable host/service/project identifiers, current and candidate registry references/digests, policy, scan-completed time, event/operation identity, outcome, and a safe reason. Keep observation time separate from forwarding time so delayed/replayed logs cannot masquerade as a fresh successful scan. Do not put secret values, raw process environments, or arbitrary unvalidated request text into these records.

Grafana rules must evaluate current pending/resolved state and separate missing/stale scan health, route through existing Discord and the owner's additional webhook contact point, and define deduplication/reminders. A resolution event must actually clear the latest pending state rather than coexist indefinitely with an old update event. The existing authenticated alert inventory/export and restore remain preflight requirements; no account reset or replacement notification platform is selected.

The owner accepts Grafana-based alert interruptions and has existing healthchecks.io checks on both machines. Local telemetry and maintenance-state collection should continue where its host is operational; it does not imply uninterrupted notifications or an additional Grafana instance.

## Proof to carry into the formal plan

Test each workload class, an unknown service, and an unclassifiable update. Exercise concurrent CI/update/activation requests and interruption at each lifecycle boundary. Verify that an image update does not activate pending secrets, that a failed scan cannot falsely resolve a pending update, and that a completed operation cannot be replayed after restart. Test compatible stateful recovery rather than only old-image startup.

Measure steady and maintenance-peak RAM/disk/I/O, registry and metadata rate behavior, local audit/log persistence, and the 30-day audit budget. Retain per-host telemetry storage ownership and unrelated second-host workloads. These are design/validation obligations, not completed tests. Scanner/updater and collector products, exact release lines, schedules, files, and command interfaces remain for the formal Technical Plan; update authority is settled by D-08/D-09/D-27.
