# Goldfish brainstorm: raw reviewer reports

Date: 2026-11-02. Mode: BRAINSTORM. No document-template standard was imposed.

Frozen target: `concepts_brief.md`, original lines 1–417, SHA256 `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`.

Mandatory immutable evidence: `docs/investigations/2026-11-01-database-connectivity.md` and `docs/investigations/2026-11-01-debian-host-baseline.md` (88 lines each).

The native collaboration tool launched each reviewer with `fork_turns="none"`, a general-purpose role, its exact installed persona, the same frozen target and evidence, and read-only constraints. Reviewers received no prior conversation, other reviewer findings, or proposed answers. Two reviewers run per wave because the root and synthesizer occupy the remaining two agent slots. A native completion and a complete mandatory-read manifest are required to count a review as completed. Reviewer conclusions below are raw findings, not owner decisions or implementation approval. The consolidated report records deduplication and any severity changes.

Reports are appended after actual native completion. All scope references in raw reports refer to the frozen target before the later synthesis section is appended.

## egm-codebase-details — completed

**Native task id:** `/root/goldfish_synthesis/operations_brainstormer`
**Role:** Observability-and-Debugging-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash. No retry.

### Raw report

The concept has **no demonstrated feasibility Blocker** from this lens. The brief distinguishes requirements from pending mechanisms well. The following are consequential unresolved operating choices; they do not require a completed implementation plan at intake.

All findings have dimension **Observability & Operational SRE Debuggability**.

1. **Major — Decide what visibility is required while central Grafana is unavailable.**
   **Scope:** `concepts_brief.md:26–28, 161–171, 254, 360`.
   **State:** Central Grafana and existing notification routing are owner requirements; alert placement and outage behavior are unresolved. Local telemetry continuing on the second server preserves evidence, but does not by itself notify anyone that the Atom, Grafana, or the inter-server query path failed. Similarly, a stopped log collector cannot reliably report its own failure solely through the log stream it has stopped delivering.
   **Consequence:** Recovery-point age, blocked secret publication, and failed updates can become invisible during the incident that makes them important. This is compatible with the accepted manual recovery model if the notification blackout is deliberate.
   **Next disposition — clarify requirement:** Explicitly accept that blackout, or establish a narrowly scoped independent detection route using the existing destinations and permitted deployment scope. During drafting, distinguish host failure, unreachable data source, empty query result, stale samples, and disabled alert evaluation. Do not silently add another Grafana or notification stack.

2. **Major — Update availability needs a current state as well as an event log.**
   **Scope:** `concepts_brief.md:147–159, 175–177, 309`.
   **State:** External/database-major log-and-alert behavior is required; reminder, resolution, and missing-telemetry behavior are already identified as pending.
   **Consequence:** A one-time “update available” log can age outside an alert query window while the update remains unapplied. Conversely, an old event can keep alerting after another deployment has resolved it. No event can mean “no update,” a failed registry query, or a stopped watcher.
   **Next disposition — research feasibility:** Select semantics for a pending update, successful scan heartbeat, failed scan, superseded candidate, and confirmed rollout. Correlate these with installed and candidate digests and deployment ownership. A periodically repeated safe status record is one simple option; a separate bespoke update dashboard or state service is not inherently necessary. Treat this as normal updater/alert design, not evidence that an unselected updater is infeasible.

3. **Major — Secret durability and consumer activation need separately observable states.**
   **Scope:** `concepts_brief.md:133–141, 215, 226, 258–260, 275–277, 294`.
   **State:** Off-site recoverability before acknowledgment and manual admin activation are owner requirements. The publication protocol remains open.
   **Consequence:** “Secret saved,” “R2 copy protected,” “database accepts the new credential,” “deployment inputs refreshed,” and “consumer recreated successfully” are different outcomes. A timeout after an off-site write can also leave an ambiguous result requiring safe retry or reconciliation. A single successful-backup message cannot explain whether a rotation is durable, active, or still pending.
   **Next disposition — research feasibility:** Require safe version and operation identifiers across publication, recovery copy, backend credential change, delivery, activation, and validation. Expose pending, blocked, failed, committed, and activated states without values. The chosen mechanism should make an interrupted operation diagnosable and resumable. This strengthens the already stated admin-visible pending-refresh requirement; it does not require application tracing or code changes.

4. **Major — Resolve whether sensitive command arguments may exist in restricted local raw records.**
   **Scope:** `concepts_brief.md:211, 215, 218–220, 228–239`.
   **State:** Safe command detail and omission are delegated working decisions; native capture and filtering are proposals awaiting verification.
   **Consequence:** The brief acknowledges that raw audit/authentication records can contain sensitive arguments, while other passages say never to record secret values and to redact or omit unsafe arguments. The acceptance test checks that a harmless secret marker is absent from **forwarded** records. These statements leave two interpretations: local raw sensitive arguments are temporarily permitted under restricted access, or credential-bearing arguments must never be recorded anywhere. Those have different feasible capture strategies.
   **Next disposition — clarify requirement:** State the privacy boundary for raw local records, spools, rotation, backups, and Loki. Then preflight the marker across every retained representation, not only the forwarded stream. Prefer safe metadata and mutation evidence where argument capture cannot meet the selected boundary. Preserve the explicit limitation that arbitrary scripts and shell syntax cannot be perfectly classified.

5. **Major — Keep service availability separate from usable application/database readiness.**
   **Scope:** `concepts_brief.md:69–84, 135–141, 175`; database investigation `:20–21, 30–38, 48–50, 65, 75–79`.
   **State:** The investigation confirms current ITskolar authentication, privilege, and schema blockers. It also confirms that the running bot has database features disabled; it does not establish a historical network failure.
   **Consequence:** Container uptime, a healthy database process, successful image recreation, and a populated consumer password can all coexist with an unusable application database. Generic connection errors make an incident harder to classify.
   **Next disposition — implementation preflight:** Carry the existing staged checks into deployment and secret-activation outcomes: effective consumer network/configuration, endpoint reachability, authentication, authorization, schema compatibility, and intended feature enablement. Retain the last attempted stage and result with safe context. Operator-run or deployment-side checks can provide this without adding an application SDK. Full distributed tracing would add scope before establishing a need.

6. **Major — Capacity feasibility must include investigation and alert queries, not just local ingestion.**
   **Scope:** `concepts_brief.md:26–28, 44–45, 53, 239–243, 271–273, 349, 360`; Debian baseline `:24–26, 43`.
   **State:** The 4 GiB placement and 30 searchable audit days are constraints. Storage allocations, resource limits, and broader telemetry retention remain open. Existing measurements are snapshots.
   **Consequence:** Separate second-host storage removes its ingestion/storage load from the Atom, but central Grafana still performs dashboards and alert evaluation against both hosts. During an incident, broad historical queries, audit collection, backups, and normal services may compete. The second server’s telemetry and backup roles also share finite storage. Thirty days by retention setting alone does not establish thirty days of searchable evidence without loss.
   **Next disposition — research feasibility:** Establish a small measured event-volume and query-load budget, distinguish audit from general telemetry retention, and observe dropped records, ingestion delay, disk pressure, and query failures. Keep stable host/service identity; avoid making arbitrary command text or unique operation identifiers an unrestricted label vocabulary. If budgets are tight, reduce unrelated telemetry detail or query breadth before shortening the owner’s audit horizon or relocating prohibited infrastructure.

7. **Major — Define audit continuity across the collector and persistence migration.**
   **Scope:** `concepts_brief.md:53–54, 218–243, 413`; Debian baseline `:39–43`.
   **State:** A supported collector is required, while collector selection and current journal persistence remain unresolved. The evidence identifies live history truncation on login.
   **Consequence:** Replacing collection, adding persistent backend storage, or fixing the MOTD path can still introduce gaps or duplicates if the old source is retired before the replacement is verified. Previously absent audit events cannot be reconstructed merely by configuring a 30-day target.
   **Next disposition — implementation preflight:** Establish the effective start of the promised audit coverage, preserve available historical records, and explicitly record older gaps. Validate source permissions, resume/checkpoint behavior, duplicate handling, and loss reporting during the collector cutover. A short controlled overlap is an alternative to a single abrupt switch. This is a migration acceptance concern, not a reason to require retrospective history that was never captured.

Useful simplification: use a shared safe operation identifier for deployments, updates, migrations, secret activation, and recovery checks. Structured operation records plus host metrics can address this project’s primary debugging needs without introducing a distributed tracing platform, an application standby, or another notification product.

### Read manifest

Read completely:

- Persona: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/codebase_details.md` — lines 1–69.
- Frozen brief: `/mnt/Data/Projects/Infrastructure/Home-Server/concepts_brief.md` — lines 1–417.
- Evidence: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-database-connectivity.md` — lines 1–88.
- Evidence: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-debian-host-baseline.md` — lines 1–88.

Verified brief SHA256: `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c` — matches the expected hash.

Optional source/configuration reads: none. External documentation reads: none. Inaccessible or missing reads: none. No remote inspection, structural-code claims, edits, or notifications were performed.

## egm-design — completed

**Native task id:** `/root/goldfish_synthesis/design_brainstormer`
**Role:** Architecture-and-Economics-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash before and after review. No retry.

### Raw report

Architecture-and-Economics-Brainstormer, BRAINSTORM: **No demonstrated concept-feasibility blocker.** The placement and recovery-first approach are plausible. The material risks concern bounded resources, failure-policy interpretation, and proving that the eventual mechanisms preserve the stated guarantees. Pending product choices are not themselves defects.

Verified brief SHA256, before and after review: `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`.

1. **Major — Memory/resource economics: the Atom needs an explicit admission budget.**
   **Scope:** `concepts_brief.md:22–28,44,108,218–243`; Debian baseline `:24–26`; `compose.yaml:44–618` resource entries, especially Loki `:536,552` and Grafana `:617`.
   The existing long-running services’ configured memory ceilings total approximately **4,160M**, excluding the two migration jobs, the host, and independently deployed applications. The observed host has 3,839 MiB usable RAM. Ceilings are not measured consumption, so this does **not** prove the present stack cannot run; it demonstrates that the limits provide no aggregate safety margin. Loki’s `GOMEMLIMIT=580MiB` also exceeds its 256M container limit. Adding secret delivery and audit collection without measuring coincident peaks could make database recovery or routine updates trigger OOM failures.
   **Mitigation/disposition — research feasibility, then implementation preflight:** establish an aggregate budget covering steady state plus one maintenance operation, with explicit host/application reserve. Measure current workloads and proposed components before selecting heavyweight products. Useful simplifications include making pgAdmin an on-demand administration service and avoiding permanent auxiliary UIs or agents where an existing administrative workflow suffices. Hosted builds are a sound delegated working decision because they remove one substantial competing load.

2. **Major — Storage economics: 30 searchable audit days and two backup destinations compete with existing data.**
   **Scope:** `concepts_brief.md:243,250–256,270–273`; Debian baseline `:26`; `new_server_hardware.md:67–74`; `compose.yaml:452–453,539–541`; `infra/loki/loki-config.yml:27–35`.
   The Atom snapshot has approximately 31 GiB free. The second server’s root snapshot implies only approximately **41.7 GiB free**, rather than an unused 128 GB backup device. Current Prometheus settings retain seven days with a 200MB size cap; Loki specifies seven days. Extending audit retention, adding durable telemetry storage, retaining backup generations, and keeping images for recovery can therefore exhaust either host even though each feature independently looks small. The second server’s independent workloads also own part of that space.
   **Mitigation/disposition — research feasibility:** obtain bounded data-volume and daily-growth estimates before allocating storage. Budget audit retention separately from general logs, metrics, database/Pterodactyl copies, image retention, and backup temporary space. Preserve the owner’s 30-day audit target by reducing unrelated telemetry noise first. Consider streaming backups instead of requiring a full additional local staging copy where the selected tool permits it. No particular backup or collector product is ruled out by present evidence.

3. **Major — Recovery-policy boundary: an alert does not enforce a 24-hour maximum loss window.**
   **Scope:** `concepts_brief.md:249–264,277,285–292`.
   Secret changes explicitly pause when off-site durability is unavailable. Database and Pterodactyl writes have no corresponding stale-backup policy yet. If off-site backups remain unavailable for more than 24 hours while those workloads keep changing, subsequent loss of both home machines can exceed the off-site recovery-point target. A second copy at the same site does not resolve that case. The brief does not establish whether these combined failures are required coverage, so this is an **unresolved requirement boundary**, not a proven contradiction.
   **Mitigation/disposition — clarify requirement:** retain a choice between enforcing a degraded-operation boundary when no sufficiently recent required recovery point exists, or explicitly limiting which outage/failure combinations the 24-hour target covers. The owner’s acceptance of service shutdown makes stopping relevant writes a possible design response. Do not silently turn “maximum acceptable loss” into “normally achieved by a scheduled backup.”

4. **Major — Secret durability requires a feasibility demonstration across publication and activation.**
   **Scope:** `concepts_brief.md:127–141,258–260,275–277,294–296`.
   R2-before-acknowledgment is a necessary durability boundary, but publication, upstream credential changes, generated application configuration, manual recreation, and revocation remain separate operations. A crash can leave a protected new value that is not active, or an active backend credential whose recovery metadata still describes another version. A product’s ordinary “save succeeded” response could also bypass the required off-site acknowledgment boundary unless all permitted mutation paths are controlled. These are mechanism risks already acknowledged by the brief; they do not establish that zero-loss publication is infeasible.
   **Mitigation/disposition — research feasibility:** before committing to a product, demonstrate a small end-to-end update through the existing application input interface, including failure between publication and activation, retry, and recovery from protected versions. The independent recovery record must distinguish pending and active credentials and retain the previously usable version. Prefer a small admin-controlled publication/delivery workflow over a new custom management platform if it satisfies the requirement. No application/startup-code changes are needed merely to investigate this option.

5. **Major — Automatic updates need service-specific compatibility decisions, including recoverable state.**
   **Scope:** `concepts_brief.md:149–179,254–256,413`; Debian baseline `:78–80`.
   Excluding database major upgrades does not make other central images safely interchangeable. Grafana, the Pterodactyl panel, and other persistent services can change stored state; preserving an old image alone may not preserve a usable rollback. Updates also consume pull, extraction, backup, and temporary recovery space on the same constrained filesystem. This is an implementation-preflight risk, not an objection to the owner-authorized automatic-update policy.
   **Mitigation/disposition — implementation preflight:** classify central services by compatible release series and state-changing behavior, serialize changes with deployment and backup operations, and require a usable recovery point before updates that can irreversibly transform persistent data. Preserve existing Grafana state before its maintenance, as the brief already requires. An updater should defer an unclassified candidate and report it rather than interpreting a moving tag as proof of compatibility.

6. **Nit — Avoid paying for a topology replacement to repair provisioning defects.**
   **Scope:** `concepts_brief.md:69–84,371`; database investigation `:30–48,69–79`.
   The verified ITskolar incident demonstrates missing passwords, privileges, and schemas while DNS/TCP connectivity works. It supplies no evidence that shared database processes caused that failure. Per-application database processes could provide independent version/lifecycle boundaries, but they introduce additional memory, maintenance, backup, and migration costs on this Atom. Conversely, shared processes need explicit per-application ownership and access boundaries.
   **Mitigation/disposition — avoid extra scope:** retain shared-engine/per-application-database provisioning as the smallest baseline alternative, alongside a selectively isolated process where an actual compatibility or lifecycle requirement warrants it. Treat Skybridge’s transition as a separate coordinated integration, including its existing data and migrations; do not assume that account provisioning alone completes that move. This is an alternative-selection recommendation, not a demand to settle topology during intake.

### Read manifest

- Exact persona read completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/design_critic.md`.
- Mandatory documents read completely: `concepts_brief.md:1–417`; `docs/investigations/2026-11-01-database-connectivity.md:1–88`; `docs/investigations/2026-11-01-debian-host-baseline.md:1–88`.
- Optional files read completely: `Hardware_Info.md:1–62`, `new_server_hardware.md:1–145`, `infra/loki/loki-config.yml:1–55`, `infra/prometheus/prometheus.yml:1–15`.
- `compose.yaml` received bounded literal searches across the file for service names, image names, resource settings, relevant persistent-path declarations, retention settings, and `GOMEMLIMIT`; it was **not** read completely.
- Workflow instructions read: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`. Coverage checked for all eight relied-on project files. Initial optional-file checks reported generation `2026-11-01T15:44:01Z`; subsequent checks reported `2026-11-01T16:21:02Z`. All returned `no_recorded_issue`/`metadata_match`, a best-effort signal only. Findings above use direct document/configuration evidence, not graph-derived runtime claims.
- No web documentation, remote systems/accounts, ignored environment files, private keys, or additional source files were read. **Missing/inaccessible attempted reads: none.** All mandatory reads completed. No files changed.

## egm-comprehension — completed

**Native task id:** `/root/goldfish_synthesis/ergonomics_brainstormer`
**Role:** Operator-Ergonomics-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash. No retry.

### Raw report

Operator-Ergonomics-Brainstormer, BRAINSTORM mode. The concept is understandable and has no demonstrated feasibility Blocker. The following seven risks should shape drafting; they do not require a completed implementation plan at intake.

1. **Major — Secret “save,” durability, and activation need distinct operator meanings.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:123–141, 258–260, 275–277, 294`; database evidence `2026-11-01-database-connectivity.md:46–50`.
   **Friction/consequence:** The owner requires protected off-site recovery before acknowledging changes, while activation is manual and applications cannot change their secret-loading code. An admin can otherwise see “saved” in a chosen product while the protected version, backend credential, delivered configuration, and running consumer disagree. Retrying after a partial failure could make that ambiguity worse.
   **Ergonomic requirement:** Establish visible version states such as pending protection, protected, pending consumer activation, active, and failed, with safe retry/reconciliation behavior. Demonstrate one environment-only consumer and one representative Pterodactyl workload using allowed configuration controls before selecting a delivery design.
   **Disposition:** **Research feasibility.** This is a product/workflow feasibility gate, not evidence that the no-code constraint is impossible.

2. **Major — Automatic image recreation could accidentally activate a pending secret.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:133–139, 149–157, 175`.
   **Friction/consequence:** Secret activation is reserved for manual ops-admin action, but central image maintenance automatically recreates containers. If delivery overwrites an environment/configuration file before manual activation, an unrelated image update can load the pending secret. Merely assigning different policies to the two operations does not prevent their shared container lifecycle from combining them.
   **Ergonomic requirement:** Define an active configuration version separately from pending delivery. Automatic image maintenance must use the last activated inputs, or explicitly defer when a safe combination cannot be established. Serialize image replacement, deployment, and credential rotation around the affected service.
   **Disposition:** **Clarify requirement** through a combined-operation acceptance case. This is a policy interaction needing resolution before implementation.

3. **Major — Successful onboarding must have one recognizable result from the actual consumer.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:75–84, 94, 110, 141`; database evidence `2026-11-01-database-connectivity.md:19–21, 30–37, 50, 54–65`.
   **Friction/consequence:** The evidence shows why “container running,” “password supplied,” and “network attached” are insufficient individually. A generic connection error makes an admin repeat unrelated networking, account, and schema experiments. Separate tools without a coherent result would preserve the reported operating difficulty even after topology changes.
   **Ergonomic requirement:** Provide one supported onboarding/deployment path that identifies its Compose inputs and artifact, then reports safe, categorized results for endpoint reachability, authentication, authorization, schema readiness, and application-level use. Explicitly identify intentionally disabled database features. Include the next responsible owner/action when a stage fails. A thin wrapper or documented invocation around existing tools is sufficient.
   **Disposition:** **Implementation preflight.** This is the measurable operating outcome; changing database process topology is not itself the remedy.

4. **Major — Recovery needs an entry point usable without the failed platform.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:189–191, 254–260, 285–290, 413`; baseline evidence `2026-11-01-debian-host-baseline.md:30–36, 78, 86`.
   **Friction/consequence:** Manual recovery with unlimited downtime still fails if the operator must first recover Pi-hole, the secret manager, Grafana, or an unavailable account to discover how to restore them. The observed active address differs from persisted intent, privileged firewall evidence was unavailable, and certificate automation remains unknown. These make a remembered “usual access path” unreliable during reconstruction.
   **Ergonomic requirement:** Select a separately accessible recovery entry point containing a recovery inventory, required identities/privileges, network/bootstrap instructions, protected recovery material, and the order for restoring dependencies. Test its usability from a clean operator environment under the accepted loss scenarios. Preserve a route to administer networking while Pi-hole is unavailable.
   **Disposition:** **Implementation preflight.** Do not add automatic failover or another application host.

5. **Major — Central alerting must distinguish action required, stale evidence, and deliberate downtime.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:26–28, 159, 163–171, 243, 264`.
   **Friction/consequence:** Update notices, backup-age violations, collector loss, and application failures have different actions. Repeated update notices without a responsible owner or resolution condition create noise. Central Grafana being unavailable also removes the normal notification path even while second-server collection continues; silence cannot establish health.
   **Ergonomic requirement:** Each actionable alert should identify host/service, responsible deployment owner, evidence age, required action, and resolution condition. Define deduplication/reminders and how planned downtime affects evaluation. Expose stale/missing data clearly when Grafana returns, and provide a direct recovery-status check outside its UI.
   **Disposition:** **Clarify requirement.** Continuous outage notification is an unresolved choice, not an implied requirement for another Grafana or notification stack.

6. **Major — Audit usefulness needs a bounded operator contract.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:205–243, 403–405`; baseline evidence `2026-11-01-debian-host-baseline.md:39–43`.
   **Friction/consequence:** The brief correctly acknowledges that command names cannot reliably distinguish mutations and that unsafe arguments may be omitted. The remaining ergonomic risk is presenting a sparse execution record as an explanation of what changed. Unknown scripts, redacted arguments, and successful process launches can leave investigation inconclusive despite meeting the selected field list.
   **Ergonomic requirement:** Distinguish observed mutation, attempted execution, inferred association, and unknown outcome in the eventual presentation. Preserve explicit omission/loss indicators. Prefer a lightweight, documented managed-change route that links normal changes to their reason, revision, validation, and rollback, with native auditing covering out-of-band activity as far as verified. Keep noisy raw events out of the principal operator view.
   **Disposition:** **Research feasibility.** Do not promise semantic reconstruction of arbitrary shell activity or build a custom administration platform to obtain it.

7. **Nit — Historical Debian reconstruction needs a stopping rule.**
   **Dimension:** UX & Developer Ergonomics.
   **Scope:** `concepts_brief.md:318, 335–356`; baseline evidence `2026-11-01-debian-host-baseline.md:7–17, 27–29, 86`.
   **Friction/consequence:** Original installation choices and some setting rationales are unknown. If reproducing the original baseline becomes a prerequisite for every accepted improvement, investigation can expand indefinitely without making the target host more reproducible.
   **Ergonomic requirement:** Separate establishing the effective current state and reproducible target from bounded historical explanation. Record unavailable historical facts as unknown, preserve unexplained hardware settings deliberately, and resolve only the historical gaps that materially affect a proposed change or recovery.
   **Disposition:** **Avoid extra scope.** The owner’s request to explain deviations does not require inventing or completely reconstructing lost history.

### Decision interpretation

Owner requirements include the placement constraints, no application/startup-code changes for secrets, manual secret activation, automatic central image maintenance, owner-authorized application deployments, selected recovery destinations/loss limits, Pi-hole/access boundaries, and meaningful audit history. GitHub-hosted build placement and selected audit detail are delegated working decisions. Focused Linux Audit integration is a proposal. Secret publication/delivery, deployment transport, updater behavior, capture rules, and sizing remain unverified mechanisms. None of the findings treats an unselected product as infeasible.

### Read manifest

Read in full:

- Persona: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/comprehension.md`.
- Frozen brief: `/mnt/Data/Projects/Infrastructure/Home-Server/concepts_brief.md`, lines 1–417.
- Evidence: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-database-connectivity.md`, lines 1–88.
- Evidence: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-debian-host-baseline.md`, lines 1–88.
- Workflow reference: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`.

Verified brief SHA256 matches the expected value: `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`.

Coverage was checked for all three repository documents. The tool reported `no_recorded_issue` and `metadata_match`, with generation `2026-11-01T16:21:02Z`; this differs from the supplied generation. Conclusions rely on direct complete document reads, not structural graph completeness or new runtime observations.

Optional repository sources read: none. Web sources consulted: none. Inaccessible or missing attempted reads: none. Initial combined output truncation was resolved by bounded reads. No files were changed and no remote hosts/accounts were contacted.

## egm-zoom-out — completed

**Native task id:** `/root/goldfish_synthesis/simplicity_brainstormer`
**Role:** Simplicity-and-Reuse-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash. No retry.

### Raw report

The concept has no demonstrated feasibility Blocker. Its strongest simplifications are already accepted: hosted builds, manual recovery, manual secret activation, per-host telemetry storage, and reuse of Grafana notifications. The main risk is turning the remaining coordination problems into a new management platform.

All findings below use the Contrarian / YAGNI & Code Minimization dimension. They are concept risks and drafting priorities, not claims that an intake brief must already contain executable procedures.

1. **Major — Zero-loss secrets need a bounded publication mechanism.**
   Scope: `concepts_brief.md:247–298`, especially 258–260, 277, and 294. Zero loss before acknowledgment is an owner requirement; the storage product and enforcement mechanism remain unknown. Installing a local secret manager and periodically exporting it would not satisfy that requirement. Allowing another administrative write path could bypass an otherwise correct publisher.

   **Consequence:** The design could acquire a custom distributed transaction service, or promise durability its normal administrative interface cannot enforce.

   **Simplification and disposition — research feasibility:** Evaluate one protected, serialized publication procedure that produces an encrypted, independently recoverable version in R2 before reporting success. Distinguish published, pending activation, and active versions. Establish whether the second-server copy must also complete synchronously; mandatory R2 acknowledgment plus an asynchronous second copy is a simpler candidate, subject to the accepted recovery cases. Require a small failure demonstration before product commitment, rather than designing a general control platform.

2. **Major — Capacity is a feasibility gate; adding products is not a neutral choice.**
   Scope: `concepts_brief.md:22–28,44–45,243,264–273`; Debian baseline report `:24–26`; `compose.yaml:447–475,531–553`. The reported Atom snapshot has approximately 1.6 GiB available and existing swap use. Compose already includes both database engines, local telemetry, Grafana, registry services, and Pterodactyl infrastructure. Loki declares a Go memory target above its container limit; the inspected Prometheus/Loki volume sections mount configuration but no explicit data directory.

   **Consequence:** Independently reasonable additions could collectively exhaust RAM or eMMC, jeopardizing databases and recovery staging. The snapshot does not prove that the proposed system cannot fit.

   **Simplification and disposition — implementation preflight:** Establish one combined memory, disk, write-volume, and maintenance-peak budget before adding resident agents or stores. Reuse the existing service families, with host-specific configuration, and preserve local second-server telemetry storage. Keep 30-day audit retention separate from general metrics retention; do not quietly reduce the required audit horizon to make the budget fit.

3. **Major — Database topology changes could obscure the verified provisioning defect.**
   Scope: `concepts_brief.md:61–84,371`; database investigation `:7–9,30–48,69–79`; PostgreSQL provisioning SQL `:3–15,26–40,141–153,164–179`; MariaDB provisioning SQL `:1–3`. The evidence establishes missing passwords, missing connection privileges, absent expected schemas, and inconsistent deployment inputs. It does not establish that shared database processes caused the current failure.

   **Consequence:** Moving to per-application engines or inventing a universal migration framework could consume scarce resources while reproducing the same account and schema failures.

   **Simplification and disposition — clarify requirement / avoid extra scope:** Keep the current shared-instance arrangement as a least-change candidate, with explicit per-application identities and ownership. Reuse the existing SQL/Compose structure where useful, while separating repeatable account/database provisioning from each application's schema migrations. Shared versus separate processes remains an unresolved trade-off; choose it for demonstrated isolation, compatibility, or lifecycle needs. Skybridge integration remains a coordinated migration, not an endpoint substitution.

4. **Major — Serialized writers also need an explicit active configuration version.**
   Scope: `concepts_brief.md:94–110,133–137,149–157,175–179`; database investigation `:22,54–65`. Owner-authorized application deployments, automatic central image updates, and manual secret activation are three distinct authorities. A lock prevents simultaneous container replacement, but does not prevent an updater from recreating a container with newly staged secrets or unintended Compose inputs.

   **Consequence:** An automatic image update could activate a secret change intended for manual rollout. Existing runners or old deployment recipes could remain alternate production writers after hosted builds are introduced.

   **Simplification and disposition — clarify requirement / implementation preflight:** Use one host-controlled deployment path with explicit Compose inputs and recorded artifact/configuration versions. Automatic maintenance should consume the currently activated secret configuration; staging a secret should not implicitly activate it. Include retirement or restriction of the two existing runner paths in migration scope. A small deployment receiver and shared serialization boundary are candidates; a deployment platform is not yet justified. Exact transport and owner-event semantics remain open.

5. **Major — Command auditing must not become a universal shell-behavior classifier.**
   Scope: `concepts_brief.md:203–243,403–405`; Debian baseline `:38–43`; `new_setup.sh:68–103`. Required change/command evidence and the delegated safe fields are established. Linux Audit is a proposal whose coverage and cost remain unverified. The brief correctly recognizes that names such as `ls`, scripts, redirects, and API clients cannot reliably determine whether an operation mutates state.

   **Consequence:** A custom classifier could become the largest software component in the refactor, yet still lose important actions or retain credentials. Replacing native records with such a component would worsen reliability.

   **Simplification and disposition — research feasibility / avoid extra scope:** Reuse APT/dpkg, journal, service, and deployment records; preserve the installed package hook instead of retaining the competing custom APT consumer. Add focused mutation rules and safe administrative execution metadata, retaining unknown interpreter/script executions with explicit uncertainty. Use the listed harmless acceptance cases to establish useful coverage. Do not require perfect semantic classification or complete operation outcomes where the capture source cannot observe them.

6. **Major — The Pi-hole HTTP defect does not justify a network architecture replacement.**
   Scope: `concepts_brief.md:181–199`; Debian baseline `:30–35,54–67`; `new_setup.sh:169–199`. The evidence narrows the web failure to nginx's configured container-to-host path; host-origin HTTP works. Effective firewall rules were unavailable. The active Wi-Fi address differs from the persisted wired configuration, and DHCP is currently disabled.

   **Consequence:** Switching directly to bridge/macvlan networking to repair the UI could introduce DHCP broadcast problems, unsuitable Wi-Fi assumptions, and loss of the working management route.

   **Simplification and disposition — implementation preflight:** First investigate the existing host-network path and effective filtering, preserving internal access boundaries. Keep UI repair and controlled DHCP adoption as separate migration stages. Reusing host networking remains a candidate; any alternative must justify its broadcast and management-address behavior. Preserve the working Debian network manager and existing host deviations until their intended replacement is supported by evidence. Neither bootstrap script is an appropriate whole-host migration shortcut.

7. **Major — Delivery feasibility depends on consumer controls, not the secret-store brand.**
   Scope: `concepts_brief.md:118–141,201,308,392–393`; database investigation `:20,46–48`. No application/startup-code modification and manual admin activation are owner constraints. ITskolar's environment interface is established. The unnamed system's configuration inputs and Pterodactyl workloads' supported deployment controls are not.

   **Consequence:** Selecting a product around SDKs, injected entrypoints, dynamic credentials, or automatic restart agents could force prohibited application changes or an unnecessary delivery framework.

   **Simplification and disposition — research feasibility / avoid extra scope:** Start with each consumer's existing environment/configuration interface and an admin-operated delivery/recreation procedure. Reuse Compose `env_file` for the established ITskolar interface, with protected generated configuration and consumer-scoped access. Verify Pterodactyl configuration controls for the actual workloads before generalizing. Keep short-lived credentials, sidecars, polling agents, and automatic activation out unless a concrete consumer need justifies them. Unknown consumer interfaces are discovery items, not evidence that no compliant product exists.

### Read manifest

- Exact persona read in full: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/zoom_out.md`.
- Mandatory files read in full: `concepts_brief.md:1–417`; `docs/investigations/2026-11-01-database-connectivity.md:1–88`; `docs/investigations/2026-11-01-debian-host-baseline.md:1–88`.
- Verified brief SHA256: `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`, matching the supplied frozen hash.
- Optional source reads: selected service/image/storage/resource lines in `compose.yaml`, including full ranges 447–477 and 531–555; PostgreSQL SQL ranges 1–40 and 140–180; MariaDB SQL 1–3; targeted reporting/firewall searches and `new_setup.sh:60–108,160–205`. Credential details are omitted from this report.
- Workflow instructions read: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`. A bounded graph function search in `new_setup.sh` returned no matching symbols; no completeness or absence conclusion relies on it.
- Coverage checked for every relied-on repository file. The tool reported generation `2026-11-01T16:21:02Z`, newer than the supplied generation. PostgreSQL SQL has partial coverage at lines 15 and 153; MariaDB SQL at lines 1 and 3. All those ranges were read directly. Other checked paths reported no recorded issue, which remains a best-effort signal.
- Inaccessible/missing reads: **none**. No remote inspection, secret-file reads, edits, or external documentation reads were performed. Remote conclusions remain bounded by the two evidence reports.

## egm-implementation-readiness — completed

**Native task id:** `/root/goldfish_synthesis/migration_brainstormer`
**Role:** Migration-and-Compatibility-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash. No retry.

### Raw report

Review complete. No concept-level infeasibility is established. The accepted downtime and manual recovery policy makes staged migration practical; the principal risks are loss of compatibility across persistent state, credential activation, and deployment transitions. The following are **Major** risks to resolve through drafting and targeted preflight, rather than reasons to reject the concept. No Blocker or Nit finding.

All findings use the **Migration & Backward Compatibility** dimension.

1. **Major — Adopt existing database state before changing ownership or topology.**
   **Scope:** `concepts_brief.md:65–84`; database evidence `:33–48,67–79`.
   The confirmed problem includes existing roles/databases with incomplete grants and schemas. Skybridge separately still declares its own PostgreSQL volume and migration job. A new provisioner could encounter partially initialized objects, while a topology change could leave two databases treated as authoritative. Absence of a history table at one inspected location does not establish that all migration history or application data is absent.
   **Migration requirement:** Define adoption of existing accounts, ownership, grants, schema versions, and data before replaying provisioning or retiring any database. For Skybridge, establish whether data must move and select one authoritative source before endpoint cutover. Preserve an explicit rollback boundary before accepting writes at the destination.
   **Disposition:** **Implementation preflight** for actual state; **clarify requirement** for migration ownership. Topology remains an open mechanism. A useful simplification is to repair provisioning and deployment consistency first, retaining existing database processes unless separation has a demonstrated benefit.

2. **Major — Secret durability and credential activation need a recoverable intermediate state.**
   **Scope:** `concepts_brief.md:123–141,258–260,275–298`.
   Zero-loss storage, unchanged application inputs, and manual activation are owner requirements. The publication mechanism is unknown. A crash between saving a protected secret version, changing the database/API credential, recreating consumers, and recording completion can leave a durable value whose activation status is ambiguous. A consumer may also retain the old environment while a later operation assumes it has refreshed.
   **Migration requirement:** Distinguish prepared, durably recoverable, backend-active, consumer-active, and acknowledged state—or an equivalent simpler protocol. Preserve enough safe metadata to reconcile an interrupted rotation without exposing values. Do not revoke the working credential before the protected update prerequisites succeed; define recovery where the provider cannot accept overlapping credentials. Direct product/UI mutation paths must respect the same acknowledgment boundary.
   **Disposition:** **Research feasibility** of candidate delivery/publication mechanisms. This is a substantive feasibility gate, but an unselected product is not itself a blocker. An admin-driven protected procedure may suffice; a custom service is not yet justified.

3. **Major — Independently recoverable backups must also form a compatible recovery set.**
   **Scope:** `concepts_brief.md:169,245–264,285–299,413`; database evidence `:48,78`.
   The newest zero-loss secret version can differ from the credential state inside a restored database that is up to 24 hours old. Similarly, independently successful Pterodactyl database, workload-file, panel/Wings metadata, and image backups may describe different application versions or moments. Meeting each component’s age target alone does not establish a usable combined restore.
   **Migration requirement:** Associate recovery points with required configuration, image/schema versions, account state, and compatible secret versions; define reconciliation to current credentials after restoration. Establish which Pterodactyl components need coordinated capture. Preserve the last usable recovery set through downtime rather than letting independent expiration remove a required member.
   **Disposition:** **Implementation preflight** and **clarify recovery-set semantics**. The accepted outage policy permits a simpler quiesced backup or maintenance-window approach where online consistency would otherwise require substantial machinery.

4. **Major — Automatic maintenance can cross a persistent-state boundary or activate pending secrets.**
   **Scope:** `concepts_brief.md:133–139,149–179,394–395`.
   Database-major exclusion does not make every permitted central image update reversible. Another central service may migrate its persistent state. Moreover, recreation by the updater can consume newly generated deployment inputs before the ops admin has authorized secret activation, coupling two policies the brief deliberately separates.
   **Migration requirement:** Classify each stateful central service’s supported update/recovery boundary, preserve a compatible recovery point before irreversible changes, and coordinate all writers of service configuration. Specify whether pending secret inputs are isolated from the active deployment inputs so automatic image recreation cannot activate them prematurely. Failed health checks must not imply that restoring only the previous image restores the previous state.
   **Disposition:** **Research feasibility** for the updater and service compatibility; **clarify policy interaction** for secret activation. Prefer serialized updates and small maintenance groups over adding availability machinery.

5. **Major — The CI handoff must preserve the effective deployment while retiring the old path.**
   **Scope:** `concepts_brief.md:88–110,175`; database evidence `:19–22,54–65,71`.
   Hosted builders are a delegated working decision; production authorization is an owner requirement. Two existing Atom runners and an application workflow with implicit Compose inputs remain migration liabilities. A successful new image build does not show that the replacement deployment preserves the current production network attachment or targets the same persistent resources. Leaving the old workflow usable also leaves a competing deployment writer.
   **Migration requirement:** Establish an explicit production deployment identity/configuration, preserve required project/network/volume associations, and bind authorization to the artifact actually started. Validate a canary deployment’s effective database access before retiring the old path. Restrict or disable the previous runner/workflow route as part of cutover, with a rollback path that cannot bypass owner authorization.
   **Disposition:** **Implementation preflight**. Transport and approval tooling are ordinary design choices; preserving the production state and eliminating competing writers are migration requirements.

6. **Major — Host networking and DHCP need independent recovery checkpoints.**
   **Scope:** `concepts_brief.md:183–199,337–356`; Debian evidence `:27–36,54–67`.
   The active management route uses Wi-Fi at `.3`, persisted wired intent uses `.4`, effective firewall rules remain unreadable, and router DHCP is still authoritative. Combining firewall replacement, resolver changes, Pi-hole network-mode changes, and DHCP cutover could remove both application access and the route needed to reverse the change. Host-origin HTTP success does not validate the required client paths.
   **Migration requirement:** Preserve the working management route and recovery addressing, establish effective filtering before replacement, and validate DNS/NTP/browser access separately from DHCP. Retain router settings and define rollback effects on existing leases/reservations before changing LAN-wide authority. Avoid overlapping production DHCP pools.
   **Disposition:** **Implementation preflight** and **research feasibility** for the actual interface/router arrangement. Fixing the existing nginx-to-host path before a broader network-mode change is a useful low-scope option; DHCP remains a desired target.

7. **Major — Observability migration can destroy the history and notification state needed to validate the migration.**
   **Scope:** `concepts_brief.md:26–28,53–54,163–171,239–243`; Debian evidence `:41–43`.
   Per-host backends and 30 searchable audit days are requirements; collector selection and storage mechanics remain open. Existing Grafana routing is owner-reported but not exportable with the credentials tested. Recreating telemetry services or replacing Promtail without verifying existing storage and collection continuity could lose history, duplicate records, or leave a silent collection gap. Rebuilding Grafana could also remove the notification route intended to report failures.
   **Migration requirement:** Establish existing storage and protect Grafana’s effective database/configuration and encryption material before changes. Validate replacement collection on one bounded stream, including safe metadata filtering and observable loss, before retiring the previous collector. Explicitly distinguish newly established 30-day retention from historical records that were never retained. Confirm new data sources do not invalidate existing alert queries/routing.
   **Disposition:** **Implementation preflight**. **Avoid extra scope:** preserve existing notification infrastructure and add required integration; do not reconstruct an entire alerting stack solely because repository provisioning is incomplete.

### Read manifest

- Exact persona read completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/implementation_readiness.md`; applied its **BRAINSTORM** migration/compatibility mode.
- Frozen brief read completely: `/mnt/Data/Projects/Infrastructure/Home-Server/concepts_brief.md`, lines **1–417**.
- Verified SHA256: **`c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`**, matching the supplied value.
- Database evidence read completely: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-database-connectivity.md`, lines **1–88**.
- Debian evidence read completely: `/mnt/Data/Projects/Infrastructure/Home-Server/docs/investigations/2026-11-01-debian-host-baseline.md`, lines **1–88**.
- Additional instruction source read: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`.
- Coverage checked for all three repository documents: **no recorded issue**, best-effort metadata match, no omitted ranges or additional pages. Returned generation was **2026-11-01T16:21:02Z**, differing from the delegated `15:44:01Z`; findings rely on complete direct document reads, not structural graph assertions.
- Optional repository sources or external documentation read: **none**.
- Missing or inaccessible requested reads: **none**. No live/remote inspection, secret-file reads, changes, or notifications were performed.

## egm-structural — completed

**Native task id:** `/root/goldfish_synthesis/maintenance_brainstormer`
**Role:** Maintenance-and-Coupling-Brainstormer
**Completion evidence:** Native `FINAL_ANSWER` received; complete mandatory-read manifest and matching frozen hash before and after review. No retry.

### Raw report

Independent BRAINSTORM review complete. The concept has no demonstrated feasibility blocker. Its highest feasibility gates are enforcing off-site durability for every acknowledged secret change and fitting the combined operational workload within the fixed hardware budgets. Other findings concern maintenance boundaries that should guide drafting.

All findings use the **Long-Term Tech Debt & Maintainability** dimension.

1. **Major — Secret publication can become a custom distributed transaction.**
   **Scope:** `concepts_brief.md:127–141, 258–260, 275–298`; database investigation `:46–48`.
   Zero loss, immutable off-site history, backend credential changes, environment delivery, and manual activation span independent systems. A product that supports exporting secrets does not necessarily control every acknowledgment path. An administrator changing a managed secret through an uncoordinated UI could bypass the durability guarantee; publishing a recoverable secret also does not establish that its database account accepts it.
   **Maintainability requirement:** Select a supported, enforceable publication path for managed secret changes, with a crash-recoverable acknowledgment boundary and separate consumer-activation status. Ordinary administration must not bypass it. Verify interrupted publication/rotation and recovery without invalidating the previously working credential prematurely. Compare native product support with a simpler versioned encrypted publication workflow before accepting custom coordination code.
   **Disposition:** **Research feasibility.** The acknowledgment guarantee is an owner requirement; the workflow/product remains unknown. This is a mechanism-selection gate, not evidence that the requirement is impossible.

2. **Major — Automatic image recreation can accidentally activate pending secrets.**
   **Scope:** `concepts_brief.md:133–139, 149–157, 175–179, 390–395`.
   Image maintenance, CI deployment, and manual secret activation all recreate containers. If delivery renders pending secrets into the configuration an updater subsequently reads, an automatic image update could activate those secrets before the admin performs the intended rollout. Serializing operations alone does not prevent this. Likewise, an application deployment must retain its approved artifact identity while central maintenance proceeds independently.
   **Maintainability requirement:** Give each service one lifecycle authority and an explicit active image/configuration generation. Pending secret material must remain separate from active deployment inputs until admin activation; image maintenance should preserve the active secret generation. Reuse a minimal deployment record and existing tooling rather than introduce several competing reconcilers.
   **Disposition:** **Clarify requirement.** Resolve which configuration generation each operation is authorized to activate. Manual secret activation and automatic central image updates are owner decisions; their interaction is unresolved.

3. **Major — Database centralization can preserve the existing ownership coupling under new tooling.**
   **Scope:** `concepts_brief.md:46, 75–84, 177–179, 371`; database investigation `:40–48, 67–79`.
   The evidence establishes incomplete provisioning, while Skybridge still has its own database and migration lifecycle. A universal central migration job would couple unrelated application releases and third-party schemas. Conversely, per-application engines increase the fixed Atom resource and upgrade burden. Neither topology removes the need to reconcile existing persisted accounts, grants, data, and schema ownership.
   **Maintainability requirement:** Establish application migration owners and engine-compatibility groups before choosing process topology. Keep infrastructure provisioning separate from application schema evolution; define how existing catalog state is adopted or corrected rather than assuming edited creation SQL will repair it. Recovery must restore compatible data, account privileges, schema state, and application versions together.
   **Disposition:** **Clarify requirement / implementation preflight.** Prefer shared processes where compatibility permits; introduce additional processes only for a concrete isolation or release requirement. Topology remains an open choice, not an owner requirement.

4. **Major — Several individually bounded features share one constrained capacity budget.**
   **Scope:** `concepts_brief.md:22–28, 44–45, 205–243, 264–273, 349`; Debian baseline `:24–26`.
   Local databases, telemetry, 30 searchable audit days, image/cache growth, secret delivery, backup staging, and update activity all compete on the Atom. The second server likewise combines telemetry, recovery copies, and independent workloads on its 128 GB drive. The measured Atom snapshot includes swap use and limited free storage, but establishes neither failure nor sufficient peak headroom.
   **Maintainability requirement:** Make a joint capacity envelope a selection gate, including concurrent backup, collection, and container recreation. Define bounded scratch/cache use and observable pressure/loss behavior without silently reducing the audit horizon or exceeding recovery-point limits. General telemetry retention and sampling can be smaller than audit retention; streamed backups and bounded image caches may avoid unnecessary staging.
   **Disposition:** **Research feasibility / implementation preflight.** Hardware placement and recovery/audit requirements are fixed. Component sizing and degradation policy remain unresolved. No capacity failure has been demonstrated.

5. **Major — Reproducibility needs one target authority, not continued replay of historical bootstrap assumptions.**
   **Scope:** `concepts_brief.md:49–51, 183–199, 335–356`; Debian baseline `:27–43, 65–67`.
   Repository scripts, persisted configuration, and runtime state already disagree. Reusing a bootstrap script as the convergence mechanism risks restoring obsolete networking/PAM assumptions or replacing Docker/Tailscale rules. Pi-hole becoming DHCP authority also makes a changing management address more consequential. Keeping two plausible setup paths would prolong the same diagnosis burden after the refactor.
   **Maintainability requirement:** Select one authoritative target configuration and retire or clearly disable superseded mutation paths. Reconcile existing hosts in small validated changes, preserving unexplained hardware settings until evidence supports changing them. Establish fixed management/recovery networking independent of Pi-hole availability before DHCP cutover. Keep second-server changes limited to its authorized roles.
   **Disposition:** **Implementation preflight.** This requires a coherent source of truth and migration boundary; it does not require adopting a configuration-management platform or replacing the current network manager.

6. **Major — Semantic command filtering can become a permanent custom-parser project.**
   **Scope:** `concepts_brief.md:205–243, 403–405`.
   The brief correctly identifies compound commands, interpreters, redirection, unknown scripts, and sensitive arguments. A growing classifier attempting to distinguish every read from every mutation would be brittle across shells and tools. Kernel launch evidence also cannot reliably supply operation completion, business intent, or a safely redacted argument vector. These limits affect both maintenance cost and what “meaningful history” can promise.
   **Maintainability requirement:** Define bounded supported administrative paths and observable event guarantees. Prefer native package, service, mutation, and deployment records; preserve safe metadata for unknown administrative execution. Keep rationale in change records. Treat raw local argument capture separately from forwarded-field redaction and verify both with the harmless marker.
   **Disposition:** **Clarify requirement / research feasibility.** Command categories and 30 days are owner requirements; native auditing is a proposal and exact capture remains unknown. The unresolved choice is the acceptable completeness boundary or constraints on administrative execution—not a demand for a universal parser.

7. **Major — Frequent image changes can outpace the recoverable application state.**
   **Scope:** `concepts_brief.md:169–179, 249–260, 264–298, 400, 413`; Debian baseline `:78–80`.
   Automatically updated services may migrate persistent state between daily recovery points. Restoring an old database or Grafana backup with whichever image is currently available can fail even when the backup decrypts correctly. Prolonged permitted downtime adds artifact availability, expiring recovery credentials, and retention hazards. A live central registry or Grafana instance cannot be a prerequisite for rebuilding the failed Atom.
   **Maintainability requirement:** Define a minimal recovery unit per stateful service: usable data, required configuration/key material, compatible image identity, and migration state. Preserve the last usable unit until a replacement is independently recoverable, including during extended downtime. Test a clean rebuild using the recovery kit without relying on the failed secret store, Pi-hole, registry, or Grafana. Central-alerting outage may remain an accepted availability limit; a second notification platform is unnecessary.
   **Disposition:** **Implementation preflight.** Manual recovery and no fixed restoration deadline are owner requirements. Artifact retention, restore compatibility, and recovery bootstrap mechanisms remain design choices.

### Read manifest

- Read the exact persona in full: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/structural.md`; applied its BRAINSTORM maintenance/coupling instructions.
- Read all of `/mnt/Data/Projects/Infrastructure/Home-Server/concepts_brief.md`, lines 1–417.
- Read both mandatory evidence reports in full: database connectivity, lines 1–88; Debian host baseline, lines 1–88.
- Verified the brief hash before and after reading: `c3da093055175db78af292557f4176a9607d22b528144fe6641bb1232050df5c`, matching the supplied frozen hash.
- Additional procedural read: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`. No optional repository source/configuration files or web documents were read.
- Called `check_index_coverage` for all three relied-on repository documents. All returned `no_recorded_issue`, `metadata_match`, and no continuation. The tool reported generation `2026-11-01T16:21:02Z`, newer than the supplied `15:44:01Z`; this is best-effort metadata, not proof of completeness. Conclusions rely on full direct document reads and bounded reported observations, not structural or runtime graph claims.
- **Inaccessible/missing reads: none.** Initial output truncation was recovered with complete bounded reads. No remote inspection, edits, secret-file reads, credential reproduction, or subagent delegation occurred.
