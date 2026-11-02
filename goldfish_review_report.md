# Goldfish Review Report

**Date:** 2026-11-02. **Mode:** BRAINSTORM. **Target:** `concepts_brief.md`, frozen lines 1–417, SHA256 `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`.

All six independent reviewers completed. They found **no demonstrated concept-feasibility Blocker**. Deduplication yields **12 Major risks and 1 Nit** from 41 raw findings (39 Major, 2 Nit). These are unresolved interpretation choices, mechanism-selection gates, and migration obligations. They do not mean an intake brief must already be an executable implementation plan. Several obligations are explicitly anticipated by the brief; the review makes their consequences and acceptance boundaries concrete.

The concept remains an EGM brainstorm. Completion of review is neither final agreement on the brief nor implementation approval. No document-template standard was imposed. No live host changes, credential changes, deployments, remote inspection, or notifications were performed by this review.

## Reviewer status and provenance

| Requested lens | Native task id | Role | Verified status | Raw severity counts |
| --- | --- | --- | --- | --- |
| egm-design | `/root/goldfish_synthesis/design_brainstormer` | Architecture-and-Economics-Brainstormer | completed | 5 Major, 1 Nit |
| egm-codebase-details | `/root/goldfish_synthesis/operations_brainstormer` | Observability-and-Debugging-Brainstormer | completed | 7 Major |
| egm-zoom-out | `/root/goldfish_synthesis/simplicity_brainstormer` | Simplicity-and-Reuse-Brainstormer | completed | 7 Major |
| egm-comprehension | `/root/goldfish_synthesis/ergonomics_brainstormer` | Operator-Ergonomics-Brainstormer | completed | 6 Major, 1 Nit |
| egm-implementation-readiness | `/root/goldfish_synthesis/migration_brainstormer` | Migration-and-Compatibility-Brainstormer | completed | 7 Major |
| egm-structural | `/root/goldfish_synthesis/maintenance_brainstormer` | Maintenance-and-Coupling-Brainstormer | completed | 7 Major |

Each native task returned an actual final report, its exact installed-persona read, complete reads of the frozen brief and both mandatory evidence reports, the matching brief hash, and no inaccessible mandatory reads. There were no failed/incomplete reviewers, no retries, and **0 not run**. Reviewers used `fork_turns="none"`, general-purpose roles, identical frozen target/evidence, and read-only constraints, in three independent pairs. Findings were not passed between reviewers. Native completion status was checked; launched tasks were not counted as reviews.

The [raw findings and read manifests](docs/reviews/2026-11-02-goldfish-raw-findings.md) preserve each report with its native task id and status. Raw numbering is retained below for traceability. All scope references in this report refer to the frozen original brief; the later synthesis is appended after line 417.

Mandatory evidence was read completely by the synthesizer and every reviewer:

- **DB evidence:** [2026-11-01-database-connectivity.md](docs/investigations/2026-11-01-database-connectivity.md), lines 1–88; SHA256 `36e0680d86169d9fcc9dff59f09cc192e3833f5bc1abbd2e7534a5b36fbd6663`.
- **Host evidence:** [2026-11-01-debian-host-baseline.md](docs/investigations/2026-11-01-debian-host-baseline.md), lines 1–88; SHA256 `50bddb14de3b0e7892d0b16ee97e561860eab7109f1002448749f128ec3bdc38`.

Both evidence files remained unchanged. Some reviewer coverage calls reported refreshed graph generation `2026-11-01T16:21:02Z` rather than the supplied `15:44:01Z`. Coverage metadata remains best effort. Relevant partially covered SQL lines were read directly; conclusions use direct bounded document/configuration evidence, with no new runtime or remote-graph claims. No reviewer consulted web documentation; this report makes no fresh product/API feasibility assertion.

## Prioritized findings

### Blockers

**None demonstrated.** Zero-loss publication and capacity require feasibility evidence before mechanism commitment. An unselected product or unfinished preflight is not proof that the concept is impossible. Actual deployment remains unauthorized regardless of the absence of concept blockers.

### M-01 — Demonstrate protected publication and no-code delivery before choosing the secret mechanism — Major

- **Lens attribution:** design #4; codebase-details #3; zoom-out #1, #7; comprehension #1; implementation-readiness #2; structural #1.
- **Scope/evidence:** brief lines 118–141, 249, 258–260, 270–298; DB evidence lines 20, 46–50.
- **Risk:** A local store's successful save or periodic export does not enforce R2-before-acknowledgment. Alternate UI/API write paths may bypass the boundary. Protected publication, backend credential acceptance, delivered configuration, consumer activation, and revocation can diverge after a crash or ambiguous timeout. ITskolar's input interface is established, while the unnamed consumer and relevant Pterodactyl controls remain unknown.
- **Recommendation:** Evaluate a bounded, controlled publication procedure before committing to a product. Show independently recoverable encrypted values and version/location/activation metadata in R2 before reporting completion. Retain the previous usable version and expose safe pending/protected/backend-active/consumer-active states, using fewer states where a demonstrated protocol permits it. Exercise timeout, interrupted update, retry, outage deferral, and recovery. Demonstrate delivery through one environment-only consumer and one actual Pterodactyl workload without application, entrypoint, startup, or egg-script changes. Verify every permitted mutation route respects the boundary. Compare supported native behavior with a small admin-operated encrypted publication workflow; a new management platform is not justified by default.
- **Disposition:** **Research feasibility.** This is a mechanism-selection gate already anticipated by P-01, not a newly discovered impossibility. Whether a second-server copy is also synchronous can be evaluated against D-11–D-13; mandatory protected off-site acknowledgment remains fixed.

### M-02 — Preserve the active configuration across every container lifecycle writer — Major

- **Lens attribution:** zoom-out #4; comprehension #2; implementation-readiness #4–5; structural #2.
- **Scope/evidence:** brief lines 88–110, 133–139, 149–157, 175–179; DB evidence lines 19–22, 54–65, 71.
- **Risk:** A lock prevents simultaneous replacements but cannot stop a later updater from loading a newly staged secret file. Image maintenance could therefore activate a pending credential. New hosted builds also leave competing production writers if existing runner/workflow paths remain usable. Implicit Compose inputs can lose current networks or persistent-resource associations.
- **Recommendation:** Give the host one controlled lifecycle path with explicit project/Compose/network/volume inputs and recorded active image/configuration generations. Keep pending secret inputs separate; image maintenance consumes the currently activated configuration or defers safely. Bind application authorization to the deployed artifact. Cut over and restrict/retire the old runner/workflow routes only after validating the new path, and retain an authorized rollback. Include a combined test: stage a secret, run an otherwise permitted image update, verify the active secret does not change, then perform admin activation.
- **Disposition:** **Implementation preflight.** Preserving the brief's admin-initiated activation working plan is a derived design constraint, not a reason to ask the owner to reconfirm manual activation. Exact owner-trigger/re-run semantics already remain explicit choices under D-04; this review does not decide them.

### M-03 — Select mechanisms against one joint capacity envelope — Major

- **Lens attribution:** design #1–2; codebase-details #6; zoom-out #2; structural #4.
- **Scope/evidence:** brief lines 22–28, 44–45, 53, 218–243, 264–273, 349; Host evidence lines 24–26, 43. Design's bounded configuration evidence: `compose.yaml:44–618` resource entries, `:452–453,536–552,617`; `new_server_hardware.md:67–74`; `infra/loki/loki-config.yml:27–35`.
- **Risk:** The Atom has approximately 3,839 MiB usable RAM, swap use, and 31 GiB free in one snapshot. Design's approximate sum of existing long-running service memory ceilings is 4,160M, excluding host/apps/jobs; ceilings are not actual simultaneous consumption. Loki's configured Go target exceeds its container limit. The second server's hardware snapshot implies approximately 41.7 GiB free, not an unused 128 GB backup disk. Databases, telemetry, audit, image retention/extraction, backup staging, and recovery all share those budgets. Central Grafana queries/evaluation still cost resources even with remote ingestion/storage.
- **Recommendation:** Measure representative event/data growth, steady usage, and one maintenance/restore peak before adding resident components. Set aggregate host/application reserve, storage and I/O allocations, bounded cache/scratch, persistence, and pressure/loss observability. Budget 30 searchable audit days separately from general metrics/logs and secret/backup retention. Reduce unrelated noise or query breadth first; consider on-demand pgAdmin and streamed backups where supported. Do not shorten the audit horizon or move prohibited central services as an unstated workaround.
- **Disposition:** **Research feasibility**, followed by **implementation preflight**. Neither a capacity failure nor adequate headroom is established by snapshots or configured limits.

### M-04 — Resolve the 24-hour recovery policy during a prolonged off-site outage — Major

- **Lens attribution:** design #3.
- **Scope/evidence:** brief lines 249–264, 277, 285–292.
- **Risk:** Secret publication pauses without required off-site durability. Database/Pterodactyl writes have no equivalent stale-backup boundary yet. If off-site copies remain unavailable for more than 24 hours while writes continue, later loss of both home hosts can exceed the off-site recovery-point target. An alert alone does not enforce the maximum loss limit.
- **Recommendation:** Clarify whether this combined outage/loss case is required coverage. If it is, design a bounded degraded mode, potentially quiescing the affected workload before its required independent recovery point becomes too old. If it is outside scope, record that limit explicitly. Preserve the owner's stated loss limits and acceptance of shutdown; do not silently redefine them as a normal schedule success rate.
- **Disposition:** **Clarify requirement.** This is an owner interpretation choice, not a demonstrated contradiction in the current brief.

### M-05 — Restore compatible service recovery sets from an independent entry point — Major

- **Lens attribution:** comprehension #4; implementation-readiness #3; structural #7.
- **Scope/evidence:** brief lines 169, 189–191, 245–264, 285–298, 413; DB evidence lines 48, 78; Host evidence lines 30–36, 78, 86.
- **Risk:** A latest zero-loss secret may not match account state inside a database backup up to 24 hours old. Pterodactyl files, panel/Wings metadata, databases, images, and configuration may each be independently recoverable yet mutually incompatible. Finite retention or artifact disappearance during prolonged permitted downtime can remove the last usable combination. Recovery can also be circular if instructions, credentials, networking, or images require the failed Atom, registry, secret store, Pi-hole, or Grafana.
- **Recommendation:** Define a minimal recovery set per service: consistent data, account/schema/configuration state, compatible image identity and obtainable artifact, relevant secret versions/key material, and safe reconciliation to current credentials. Capture coordinated Pterodactyl state as needed; accepted downtime permits quiesced backup where simpler. Protect the last usable set until a replacement is independently recoverable. Test a clean operator/rebuild environment using separately accessible instructions and recovery material, including independent management networking.
- **Disposition:** **Implementation preflight.** Compatible recovery is a consequence of the existing recoverability requirement; exact capture and artifact-retention mechanisms are ordinary drafting work. No standby/failover deployment is requested.

### M-06 — Gate automatic stateful updates by compatibility and recovery — Major

- **Lens attribution:** design #5; implementation-readiness #4; structural #7.
- **Scope/evidence:** brief lines 149–179, 254–256, 413; Host evidence lines 78–80.
- **Risk:** Excluding database major releases does not establish reversibility for Grafana, Pterodactyl panel, or other state-migrating images. A failed health check followed by the old image can leave incompatible persistent state. Pull/extract/backup overhead also occurs on the constrained filesystem.
- **Recommendation:** Inventory service-specific compatible release series and persistent-state transitions, defer unclassified candidates, and require a usable compatible recovery point before irreversible changes. Serialize maintenance with deployment, credential activation, and relevant backup operations. Retain enough image/configuration/state history to explain and recover the actual update. Keep database-major discovery distinct from current-series digest watching, as the brief already requires.
- **Disposition:** **Implementation preflight** with targeted **research feasibility** for updater capabilities. Preserve D-08/D-09 automation policy; this is not a request for new owner approval on every compatible central image.

### M-07 — Adopt existing database state and make consumer readiness the operating result — Major

- **Lens attribution:** design #6; codebase-details #5; zoom-out #3; comprehension #3; implementation-readiness #1; structural #3.
- **Scope/evidence:** brief lines 61–84, 141, 371; DB evidence lines 7–9, 20–21, 30–50, 54–79.
- **Risk:** Edited creation SQL or a new topology will not automatically repair persisted passwords/grants/schema state. Lack of a history table at one location does not prove absent data/history elsewhere. Skybridge still has a separate database lifecycle and possible data source to reconcile. Process health can coexist with disabled database features or unusable credentials/schema.
- **Recommendation:** Inventory/adopt current accounts, ownership, grants, data, and schema/migration history before replay or retirement. Assign infrastructure provisioning and application-schema owners separately. Select the authoritative Skybridge source and rollback boundary before accepting destination writes. Provide one supported deployment/onboarding invocation that reports safe staged checks from the actual consumer: effective configuration/network, reachability, authentication, authorization including rejected cross-application access, schema compatibility, and intended feature use. Prefer shared-engine/per-application ownership as a least-change candidate where compatibility permits; add processes for demonstrated lifecycle/isolation needs.
- **Disposition:** **Implementation preflight** and **avoid extra scope**. Application-owner assignment and topology comparison belong in drafting/inventory; they do not require reopening the already accepted database-management goal. Design's topology-cost Nit is merged here because the same concern accompanies material migration obligations.

### M-08 — Converge one host target through independent network checkpoints — Major

- **Lens attribution:** zoom-out #6; implementation-readiness #6; structural #5.
- **Scope/evidence:** brief lines 49–51, 181–199, 335–356; Host evidence lines 27–43, 54–67.
- **Risk:** Two bootstrap paths, persisted wired `.4` intent, active Wi-Fi `.3`, and unverified privileged filtering are inconsistent authorities. Replaying a script or combining firewall/resolver/network-mode/DHCP changes can lose the route needed to undo them. Changing Pi-hole mode merely to repair HTTP can impair broadcast delivery or violate access boundaries.
- **Recommendation:** Choose an authoritative reproducible target and retire superseded mutation paths. Preserve unexplained hardware settings and the working network manager until supported changes are designed. Obtain effective filtering evidence, diagnose the existing nginx-to-host path, and separately validate LAN DNS/NTP/browser access, rejection policy, and DHCP. Establish fixed management/recovery addressing and saved router/lease/reservation rollback before controlled DHCP authority transfer. Limit second-host changes to its authorized roles.
- **Disposition:** **Implementation preflight**, with narrow **research feasibility** for the actual interface/router arrangement. The exact firewall cause remains unknown; no current bridge/macvlan replacement is selected.

### M-09 — State the privacy boundary for local raw command records — Major

- **Lens attribution:** codebase-details #4; structural #6.
- **Scope/evidence:** brief lines 211, 215, 218–220, 228–239.
- **Risk:** The brief acknowledges sensitive arguments in restricted raw audit/auth records, while other text says never to record secret values and specifies redaction/omission. The acceptance marker is presently checked only in forwarded records. Whether sensitive arguments may ever be retained locally changes feasible capture strategies and the risk carried into spools/rotation/backups.
- **Recommendation:** Clarify whether tightly restricted local raw argument capture is allowed or whether added capture must omit unsafe arguments before any persistence. State the boundary for local files, spools, rotation, backups, and Loki, and test the harmless marker across every retained representation. Prefer metadata/mutation sources where argument safety cannot meet the selected rule.
- **Disposition:** **Clarify requirement.** This is a genuine privacy interpretation choice; forwarding redaction alone cannot settle it. No general secret detector is promised.

### M-10 — Keep audit coverage bounded and migrate it without claiming retrospective completeness — Major

- **Lens attribution:** codebase-details #7; zoom-out #5; comprehension #6; implementation-readiness #7; structural #6.
- **Scope/evidence:** brief lines 53–54, 203–243, 403–405, 413; Host evidence lines 38–43.
- **Risk:** A universal shell-mutation classifier would be expensive and incomplete. Sparse launch records cannot always explain affected state, intent, or outcome. Collector replacement, persistence changes, and MOTD repair can still lose or duplicate history; records never captured cannot be recreated by setting 30-day retention.
- **Recommendation:** Reuse native package/journal/service/mutation/deployment evidence and selected safe administrative execution metadata. Document tested coverage, unknown/omitted fields, inferred associations, and actual loss; keep rationale in managed change records. Verify the brief's harmless cases and local/forwarded privacy boundary. Migrate one bounded stream with checkpoint/resume/duplicate/loss checks before retiring the old collector. Preserve available history and mark the effective start and earlier gaps of the new coverage. Maintain the installed APT integration and eliminate the competing hook through the staged host plan.
- **Disposition:** **Research feasibility**, then **implementation preflight**; **avoid extra scope** from a universal parser or custom administration platform. Additional limits on permitted administrative paths require owner agreement if native verified coverage cannot satisfy the existing requirement; this review does not impose such restrictions.

### M-11 — Deliberately accept or address the central-alerting blackout — Major

- **Lens attribution:** codebase-details #1; comprehension #5; implementation-readiness #7; structural #7.
- **Scope/evidence:** brief lines 26–28, 161–171, 243, 254, 264, 360.
- **Risk:** Second-host local collection preserves evidence while central Grafana is unavailable, but not necessarily notifications. A failed collector cannot reliably report solely through its failed output. Silence during that period cannot establish that backup age, publication, or updates remain healthy. Existing Grafana routing is owner-reported and must be preserved through maintenance.
- **Recommendation:** Explicitly accept notification blackout during Atom/Grafana/link failure, or define a narrow independent detection route within authorized scope and existing notification destinations. Distinguish stale data, unreachable sources, stopped evaluation, and planned downtime. Preserve/export/test existing Grafana state and routing before changing it; do not invent a replacement notification stack or another Grafana deployment.
- **Disposition:** **Clarify requirement** for outage visibility; **implementation preflight** for existing routing preservation and verification. Continuous availability is not implied by the recovery requirements.

### M-12 — Make update notifications express pending state and scan health — Major

- **Lens attribution:** codebase-details #2; comprehension #5.
- **Scope/evidence:** brief lines 147–159, 175–177, 309.
- **Risk:** A one-time update event can leave the alert window before installation, while an old event can continue after resolution. No event can mean no candidate, a failed scan, or a stopped watcher. Without responsible owner, evidence age, action, and resolution semantics, alerts can be misleading or noisy.
- **Recommendation:** Define pending/superseded/resolved candidate state and successful/failed/missing scan evidence, correlated to installed/candidate digests and deployment ownership. Include clear action, deduplication/reminders, and resolution. Periodic safe status records are one candidate; no separate state service or dashboard is required by this finding. Verify delivery through existing contact points and policy as already required.
- **Disposition:** **Implementation preflight**, with **research feasibility** of the selected updater/log-rule semantics. The brief already lists this design work; it requires no new owner policy by itself.

### N-01 — Bound historical Debian reconstruction — Nit

- **Lens attribution:** comprehension #7; supported by zoom-out #6 and structural #5.
- **Scope/evidence:** brief lines 318, 335–356; Host evidence lines 7–17, 27–29, 86.
- **Risk/recommendation:** Lost installer history or undocumented hardware rationale can prolong investigation without improving the reproducible target. Record unavailable facts as unknown, preserve unexplained settings deliberately, and pursue historical gaps where they affect a proposed change or recovery. Establish current/target evidence without inventing an original default.
- **Disposition:** **Avoid extra scope.** This does not reduce the owner's request to explain known deviations.

## Triage and remaining decisions

**Owner interpretation choices to resolve:**

1. M-04: coverage/degraded-write policy when prolonged loss of required off-site backup is followed by loss of both home hosts.
2. M-09: whether sensitive arguments may exist in restricted local raw records, or added capture must prevent any such persistence.
3. M-11: whether central Grafana/Atom/link outages may create a notification blackout, or require narrowly scoped independent detection.

Existing explicit owner choices also remain open where the brief already records them: D-04 exact trigger/re-run authorization semantics and whether an owner trigger authorizes the whole selected revision; update authority for second-host observability; any proposed VPN-access expansion. This review supplies no implicit answers.

**Mechanism selection and evidence work:** publication/delivery and bootstrap authentication; whether second-host secret copying is synchronous; enforceable owner/artifact authorization and deployment transport; application migration owners, authoritative data sources and database compatibility groups; updater/collector selection; compatible recovery sets, retention and artifact availability; privacy-compatible audit capture; aggregate capacity and backpressure behavior; effective firewall/router/certificate/Grafana preflight. These are not all new owner questions. Research and drafting should propose concrete bounded alternatives before requesting decisions that cannot be delegated.

**Derived constraints to carry forward:** active and pending secret inputs must remain distinct during automatic recreation; locks must be combined with explicit deployment versions; restored components must be mutually usable; verified consumer readiness must replace process uptime as success; source/history gaps must remain visible. These preserve existing decisions and should be tested without asking the owner to restate them.

**Suggested next step:** refine the three interpretation choices and perform small publication/delivery and joint-capacity feasibility studies, then draft a staged design with a disposition for M-01–M-12/N-01. Preserve manual recovery and the selected deployment boundaries. Do not add clustering, a standby platform, another notification stack, a universal shell parser, or a general management service without a concrete demonstrated need. Formal drafting can elaborate mechanisms; production authorization and implementation readiness have not been established by this review.
