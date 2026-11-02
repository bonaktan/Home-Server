# Maintained host configuration and supporting tools

* **Date:** 2026-11-02
* **State:** D-28 selects B for the main server and A for the second server, retaining Compose and the common supporting-tool proposal for the Technical Plan. Installation and feasibility tests remain pending.
* **Context:** [Approved requirements and decisions](../../concepts_brief.md), [host evidence](../investigations/2026-11-01-debian-host-baseline.md), [lifecycle policy](maintenance-policy.md), and [Vault recovery profile](vault-operations.md).

## Selected host split and retained comparison

The repository's setup scripts write overlapping host settings. The live host also differs from those scripts, and some privileged firewall/scheduler evidence remains unavailable. Re-running a script cannot establish which differences are intentional. Choose one maintained configuration approach, adopt the live state deliberately, and retire competing writers after validation. Keep Docker Compose for the services under either approach.

D-28 selects modular shell scripts for the main server and workstation-run Ansible for the second server. Carry the common supporting tools into the Technical Plan. Resource fit and the listed compatibility tests are prerequisites, not assumed successes.

Each host has one configuration owner: Ansible application targets exclude the main server, and main-server shell modules do not configure the second host remotely. The second-host roles cover observability, authorized backup storage, and their necessary access/maintenance settings; they do not deploy central services or adopt unrelated applications. Share reviewed policy schemas, event fields, and lifecycle behavior while accepting the cost of maintaining two configuration methods. Neither may run a separate unrestricted Compose update or activate pending secrets.

| | A — Ansible and Compose | B — Modular shell scripts and Compose |
| --- | --- | --- |
| Mechanism | Run versioned Ansible roles/templates from the admin workstation over the user's SSH configuration. In the selected split, its application inventory targets only the second server's authorized roles. No Ansible server, AWX, or broad GitHub-to-host administration is added. | On the main server, refactor the existing setup approach into one phased, repeatable host entry point, small modules, and versioned templates. Separate inspection, proposed changes, and explicit application. Retire the old competing paths after adoption. |
| What it helps | Existing modules express packages, files, services, and host differences; repeat application and drift review share that model. | Keeps the operating approach close to the current repository and avoids a new workstation configuration framework. |
| Operating cost | Maintain the workstation environment, pinned collections, inventory, and role conventions. Understand module/check-mode behavior and protect secret-bearing output. | Maintain custom detection, idempotence, ordering, change previews, error handling, and drift checks. Ordinary shell scripts provide none of these automatically. |
| Failure conditions | A wrong inventory/template can affect the wrong host or interrupt management access. Check mode is advisory: unsupported tasks may provide no useful prediction, and tasks can explicitly override it. Diff/debug output can expose secrets unless controlled. | A partly completed script, hidden environment dependency, or inadequate guard can leave state half-applied or erase a live setting. A custom dry run can diverge from the actual operation. |
| Recovery and ownership | Back up the exact replaced files, validate access before closing the current session, apply in bounded stages, and use explicit rollback/recovery. Admin configuration must coordinate with the lifecycle lock. | The same staged adoption, access checks, backups, lifecycle coordination, and recovery requirements apply. |

Ansible's documented [check/diff limits](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html) and [debug/no_log limitation](https://docs.ansible.com/projects/ansible/latest/reference_appendices/faq.html) prevent treating a preview or output-suppression setting as proof of safety. Neither profile gives application CI the admin's SSH identity. Neither introduces a second independent Compose deployment path.

## Common supporting-tool proposal

### Local log collection: Grafana Alloy

Replace Promtail with Alloy on both hosts. Keep each host's Prometheus, node-exporter, cAdvisor, and Loki; only the Atom runs Grafana. Preserve service labels, query/alert behavior, and collection positions where supported. Validate duplicates, gaps, and startup after interruption before retiring Promtail. Conversion is a starting point requiring review, not a reason to bypass conversion errors. [Grafana's migration guidance](https://grafana.com/docs/alloy/latest/set-up/migrate/from-promtail/) documents conversion and positions differences; [Promtail is past its March 2026 end of life](https://grafana.com/docs/loki/latest/send-data/promtail/).

Alloy does not solve the retention budget. Measure its combined load with both telemetry stores and existing applications. Do not copy all second-host telemetry to the Atom or add a second Grafana to compensate for a failing budget. Unacceptable resource use or migration gaps stop adoption for revision.

### Image discovery: regctl inside the controlled maintenance operation

Use a systemd timer and regctl to resolve candidate image manifest digests and list release tags from an admin-owned inventory. Track `linux/amd64`, the deployed artifact, discovery reference, and allowed release series explicitly. Do not compare Docker's local configuration ID with an OCI manifest digest. [regctl documents digest resolution](https://regclient.org/cli/regctl/image/digest/) and [tag listing](https://regclient.org/cli/regctl/tag/ls/).

The timer runs the bounded scanner; the lifecycle executor remains the only controlled replacement path. Preserve pending/resolved/deferred and stale/failed-scan state under the [maintenance policy](maintenance-policy.md). A changed digest is evidence of an image change, not proof of application or data compatibility. Unknown tags, authentication/rate errors, unproven upgrades, and unavailable recovery prerequisites defer rollout.

Keep central inventory/policy ownership on the Atom. For the second host, install a small local maintenance operation and timer restricted by its admin-owned enrollment to observability services. This lets maintenance and status collection work while the inter-host link is down, without adding a CI endpoint or remote Docker API there. Export its status through its local Loki for central Grafana queries. Unrelated applications and the backup-storage service retain their separate alert/manual policy.

Diun remains a possible alternative discovery component: its [file provider](https://crazymax.dev/diun/providers/file/) avoids requiring Docker discovery, and its [script notification](https://crazymax.dev/diun/notif/script/) can feed a controlled operation. This proposal uses regctl because discovery is already part of the required lifecycle/status operation; adding a separate notification service would still require that operation and reconciliation. This is a design judgment, not a measured resource comparison.

### Data backups: Restic, protected destinations, independent retention administration

Use Restic for encrypted, deduplicated database/Pterodactyl/configuration recovery sets. First produce consistent PostgreSQL/MariaDB backups with supported native tools and define Pterodactyl's workload-specific quiescence or native backup procedure. Copying live database directories or arbitrary changing game files is not a consistency guarantee. Accepted downtime permits stopping writers where needed.

Store independently usable repositories in R2 and on the second server. Restic documents [S3-compatible endpoints and encrypted repositories](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html); this establishes a supported client mechanism, not a completed R2 compatibility test. Test the actual endpoint, repository operations, checks, and restores before relying on it. Repository passwords and account recovery must be available independently of the failed Vault/Atom.

On the second server, run a dedicated rest-server endpoint as part of its already-authorized backup-storage role. Require private authenticated TLS access, a persistent storage path, repository separation, and append-only client access. Keep full deletion/retention credentials off the Atom. The official [rest-server documentation](https://github.com/restic/rest-server/blob/master/README.md) describes append-only operation, private repositories, TLS, and the unsafe temporary default storage path. This endpoint does not replicate any central application service and is not enrolled by D-27's observability update permission.

For R2, propose bucket locks on repository data, index, snapshot, key, and configuration prefixes, with mutable Restic lock files outside those protected prefixes. Hold protected objects indefinitely until controlled retention maintenance; ordinary age-based expiration of an old data pack could destroy a recent snapshot that still references it. Do not apply a blanket lock that prevents normal repository lock cleanup. R2 documents [prefix-based indefinite locks and rejection of changes to locked objects](https://developers.cloudflare.com/r2/buckets/bucket-locks/); its separate control-plane bucket locks are not interchangeable with AWS S3 Object Lock headers.

Retention maintenance runs from an independently secured admin environment with the Atom's write credential revoked/disabled and denial verified. Preserve a known usable recovery set, perform reviewed forget/prune/check work, restore and verify protection, then issue/resume the routine credential. The Atom must not hold authority to remove bucket locks. Do not let client-supplied snapshot timestamps/tags alone decide what survives; Restic documents [append-only retention hazards and separate maintenance](https://restic.readthedocs.io/en/stable/060_forget.html). A compromise must not turn routine backups into deletion of the retained usable set.

This protection design increases retention work and storage use. Prove R2 behavior, append-only behavior, size/cost limits, and safe interrupted maintenance on disposable repositories. If any prerequisite fails, return to the design rather than silently granting deletion rights or weakening the recovery requirement. Keep the last usable compatible set through prolonged service downtime. Final schedules and capacity limits belong in the Technical Plan after measurements; both destinations remain unconfigured.

### Vault recovery bundles: age and the supported object API

Use [age's recipient/identity file encryption](https://github.com/FiloSottile/age/blob/main/doc/age.1.ronn) for the independently encrypted managed-state exports required by D-24, with decryption material and account-recovery instructions outside both hosts and the original AWS KMS dependency. This is separate from periodic Restic backups. The complete candidate and matching publication receipt must be verified at both destinations before acknowledgment. The [Vault publication contract](secrets-publication.md) remains authoritative about retries, active/pending state, and no application/startup-code changes.

Use the AWS CLI's S3 API client against R2 for bounded bundle/receipt publication; keep the endpoint, bucket, and allowed object namespace admin-controlled. Its documented [conditional PutObject interface](https://docs.aws.amazon.com/cli/latest/reference/s3api/put-object.html) maps to R2's documented [atomic conditional writes](https://developers.cloudflare.com/r2/api/s3/api/). Exact retry, conflict, timeout, and read-back behavior still require the publication fixture. Do not use object overwrite or a missing response as evidence that publication committed. Use native Vault CLI/API operations for Vault administration; add no application SDK or custom unseal helper.

### Administrative audit: native sources with metadata-only command capture

Use auditd for bounded administrative process/file metadata, existing APT/dpkg and systemd sources for their own observed operations, and structured lifecycle/backup/certificate events for operations controlled by this design. Capture the safe fields agreed in D-18; omit unsafe/unreviewed arguments before any newly retained file, journal, spool, archive, or Loki stream. No terminal transcript, raw environment, or general raw command-line recorder is proposed.

Audit's [message-type exclusion mechanism](https://manpages.debian.org/trixie/auditd/auditctl.8.en.html) is a candidate for excluding argument-bearing records before auditd persistence. Its existence does not prove the required combined rules: a disposable Debian 13 fixture must inspect actual records, harmless sensitive markers, queued/failure paths, collector state, archives, and forwarding. Do not enable production capture until that boundary passes. Inspect existing sudo/journal/application argument exposure separately; forwarding existing raw logs through a later redactor does not meet the new-retention boundary.

An executed process, successful system call, completed operation, and successful application outcome are distinct evidence. Shell builtins need not create a new process; selected configuration mutation watches and controlled operation records improve coverage without pretending to identify every state-changing shell command. Exclude reviewed routine read-only noise, bound watched paths and event volume, and expose lost events/collection gaps. Preserve the requested 30 searchable audit days without watching high-volume database data files or inventing a universal command classifier.

## What the next section must make concrete

With D-28's split selected, add the full Technical Plan to [design_draft.md](../../design_draft.md): maintained Debian target and adoption order; database provisioning; protected Vault publication/delivery; authorized CI; common lifecycle inputs and locking; local telemetry; Pi-hole/firewall/DHCP; certificates; protected recovery sets; and combined capacity gates. Preserve every existing decision and report unproven constraints. File-by-file implementation and its validation/recovery sequence follow the Technical Plan's EGM approval.

No live package installation, configuration application, backup repository creation, secret export, or account change was performed to prepare this proposal.
