# Dedicated security architecture review — completed rerun

Native task `/root/security_review_rerun`, launched with `fork_turns="none"` after the owner's explicit request for a new security review. Actual complete native `FINAL_ANSWER` received; no retry was needed. The full reviewer response follows. This wrapper is parent metadata.

---

**COMPLETE — fresh security architecture review, Mode REVIEW.**

Reviewed the frozen draft, lines **1–484**; Detailed Implementation is outside scope.

**Distinct new findings: 0 Blockers, 0 Majors, 0 Nits. Confirmed existing findings: 5 Majors, R-01–R-05.** The SEC2 identifiers below provide this review’s independent verification and must not increase the consolidated defect count. No product-feasibility Blocker was demonstrated.

The specification addresses the supplied standard’s problem, goals, architecture, alternatives and risks. Five architecture contracts remain unresolved. Proposed controls have not been implemented or validated; this report supplies no security clearance.

| Existing ID | Independent result | This report | Principal consequence |
| --- | --- | --- | --- |
| R-01 | Confirmed, conditional on effective peer addressing/reachability | SEC2-01 | Confidentiality and integrity: loss of the LAN access boundary |
| R-02 | Confirmed | SEC2-02 | Recoverability: loss beyond the normal recovery-point limit |
| R-03 | Confirmed | SEC2-03 | Integrity and recoverability: incompatible recovery inputs |
| R-04 | Confirmed | SEC2-04 | Availability, recoverability and uncontrolled resource/cost consumption |
| R-05 | Confirmed as a proposed boundary gap | SEC2-05 | Integrity and availability of second-host telemetry |

**SEC2-01 — Major — Separate trusted ingress identity from application peers. Duplicate R-01.**

**Frozen scope:** 288–290, 296.

Safe source projection independently confirmed `set_real_ip_from 172.16.0.0/12` and `CF-Connecting-IP` at `infra/nginx/nginx.conf:68–69`; Pi-hole and pgAdmin permit `192.168.1.0/24` at their respective lines 17–18. Compose places nginx on application-accessible networks.

**Attack-path inference:** a reachable untrusted peer within the trusted range can submit a forged LAN address. nginx’s documented replacement-address mechanism then undermines the network ACL. Application authentication remains a separate control; this finding does not establish its bypass or a live exploit. [nginx Real-IP documentation](https://nginx.org/en/docs/http/ngx_http_realip_module.html)

**Minimum correction:** explicitly distinguish trusted ingress peers from application peers and select the connection identity used for internal authorization. This trust decision belongs in the architecture. Later tests must reject forged headers from untrusted containers while preserving actual LAN access, including IPv6.

**SEC2-02 — Major — Define the response when both destinations fail and writes continue. Duplicate R-02.**

**Frozen scope:** 60–63, 304, 321–323.

The draft requires verification of background/local/game/queued writes, but specifies no action when that verification finds continuing writes. An extended failure of both destinations followed by Atom loss can therefore exceed the normal 24-hour database/Pterodactyl recovery-point requirement.

D-19 accepts a specific whole-site-loss exposure during an R2 outage with healthy second-server protection; it does not clearly settle loss of both protection paths.

**Minimum correction:** select alternate protection, bounded quiescence/final capture, or an explicit extended-loss exception, with workload and resume boundaries. This is an architecture policy decision. Exact timing and commands follow later. Test continuing background writes with both destinations and central notifications unavailable.

**SEC2-03 — Major — Coordinate recovery capture with conflicting lifecycle mutations. Duplicate R-03.**

**Frozen scope:** 257–259, 304–306, 331.

The lifecycle lock covers deployment, maintenance and activation. Recovery capture instead relies on consistent native captures and staggered scheduling. Neither establishes that captured accounts/data and recorded image/configuration/secret references describe the same state.

A permitted interleaving captures database credentials, activates a replacement credential or schema, then records newer references. Each component can be valid while the assembled restore fails.

**Minimum correction:** include capture and matching reference selection within the existing coordination contract, excluding conflicting mutations. Release coordination before remote transfer. This architecture contract should precede implementation details. A concurrent/interrupted capture fixture must restore successfully using its recorded inputs.

**SEC2-04 — Major — Bound hostile intake independently of the Atom. Duplicate R-04.**

**Frozen scope:** 233, 308–312, 319, 327–331.

The draft recognizes malicious uploads but responds with growth tracking and validation. Those detect abuse without containing a compromised routine writer.

Append-only traffic can exhaust second-host storage needed by telemetry, independent workloads and recovery maintenance. R2 locks permit new object creation, while storage and operations remain chargeable. These mechanisms do not themselves impose an admission or spending bound. [R2 bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/), [R2 pricing](https://developers.cloudflare.com/r2/pricing/)

**Minimum correction:** require destination-enforced aggregate byte/inode allowances covering repositories and temporary uploads, with protected reserves. Rest-server’s documented repository-size option is a candidate; its aggregate scope and subrepository behavior require verification. Separately select independent R2 abuse detection/revocation and an enforceable boundary or explicitly accepted spending exposure. [rest-server documentation](https://github.com/restic/rest-server/blob/master/README.md)

Containment belongs in the architecture; numerical allocation follows measurement. Hostile-credential tests must preserve existing recovery sets when intake is rejected and invoke the selected protection/secret-deferral policy.

**SEC2-05 — Major — Decide the authority granted through the second Loki interface. Duplicate R-05.**

**Frozen scope:** 274–276, 296.

Allowing the main host to connect to a Loki port does not establish query-only authority. The documented API exposes ingestion and control operations; `/ingester/shutdown` accepts GET and POST and terminates the process by default. Loki has no included authentication layer, and enabling tenant identification does not create read-only authorization. [Loki HTTP API](https://grafana.com/docs/loki/latest/reference/loki-http-api/), [Loki authentication](https://grafana.com/docs/loki/latest/operations/authentication/)

A compromised permitted main-host principal could consequently inject records or interrupt second-host ingestion if granted the unrestricted backend surface. This is conditional architecture analysis; no second-host deployment or exposure was tested.

**Minimum correction:** explicitly accept broader backend authority or select a restricted query interface. Enforce permitted paths and methods; GET alone is insufficient. The authority/component decision belongs before file-level planning. Validate successful queries and rejected ingestion/control calls against the selected release and principal.

The following remain **explicit later proof gates**, rather than additional findings:

- **CI integrity:** authoritative repository/workflow/ref/current-initiator evidence, exact build-origin/attempt/artifact binding, restricted submission, host-owned configuration and durable replay state are already required. GitHub documents attempt-specific metadata access using an appropriately permitted App identity. Actual private access and the verifier’s binding remain untested. Existing N-01 should define authorization-generation renewal and invalidation after restore. [GitHub workflow-attempt API](https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run-attempt)
- **Privileged host and credential confidentiality:** safe projections confirmed Wings’ Docker socket, privileged cAdvisor with host mounts, Promtail’s socket and node-exporter’s read-only host-root mount. These are concrete privileged surfaces requiring the already-recorded effective-permission review. They do not establish an additional isolation guarantee. Docker authority can confer host-root control; a read-only socket bind does not provide API authorization. [Docker socket guidance](https://docs.docker.com/engine/security/protect-access/)
- **Vault recoverability:** synchronous candidate/receipt protection, protected recovery-critical configuration, manual activation and independent bootstrap material are specified. Rebuild exports correctly remain separate from old-store unsealing: recovery shares cannot replace an unavailable auto-unseal key. Complete managed-scope recovery, write-path restrictions, no-swap enforcement and actual Pterodactyl delivery still require proof. [Vault seal behavior](https://developer.hashicorp.com/vault/docs/concepts/seal)
- **Recovery integrity:** the selected independent maintenance procedure addresses hostile snapshot timestamps and preserves a known usable set. Its implementation, interrupted relocking and isolated restores remain gates. R2’s negative reads do not resolve an earlier in-flight write; the draft already accounts for this. [Restic append-only considerations](https://restic.readthedocs.io/en/stable/060_forget.html#security-considerations-in-append-only-mode), [R2 consistency](https://developers.cloudflare.com/r2/reference/consistency/)
- **Audit confidentiality and availability:** pre-storage omission, marker tests across native records/spools/archives, explicit capture gaps, loss monitoring and measured 30-day capacity are required. Native hashing or forwarding-time filtering is insufficient evidence. Accepted shared-host placement, manual recovery, alert interruptions and downtime remain constraints.

**Actual read manifest**

Persona read **first**, completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/design_critic.md`, **1–63**. Applied its REVIEW mode and `resources/document_standards/feature-spec-standard.md`, **1–36**, from the same EGM installation. Read `/home/bonny/.codex/skills/codebase-memory/SKILL.md`, **1–79**.

Frozen review-directory documents:

- `design_draft.reviewed.md`, **1–484**, read in bounded chunks; SHA-256 verified before and after: `927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`.
- `prior_consolidated_review.md`, **1–110**, independently checked against evidence; SHA-256 verified before and after: `9ecde63aba54cb3a8d080e8b72349f009c022bc03e74f714198e8d434e444020`.
- `input_manifest.md`, **1–26**, and `baseline_manifest.md`, **1–47**, completely read. All **30 baseline** and **10 prior-context** hash and logical-line-count comparisons matched their manifest entries.

Mandatory repository documents, all completely read:

- `README.md` **1–34**; `System_Documentation.md` **1–319**; `Hardware_Info.md` **1–62**; `new_server_hardware.md` **1–145**; `concepts_brief.md` **1–606**.
- Under `docs/designs/`: `database-boundaries.md` **1–62**; `secrets-publication.md` **1–111**; `vault-operations.md` **1–75**; `ci-authorization.md` **1–58**; `ci-deployment.md` **1–77**; `maintenance-policy.md` **1–66**; `operations-tooling.md` **1–75**; `security-considerations.md` **1–34**.
- Under `docs/investigations/`: `2026-11-01-database-connectivity.md` and `2026-11-01-debian-host-baseline.md`, each **1–88**.
- Historical provenance: `goldfish_review_report.md` **1–154** and `docs/reviews/2026-11-02-goldfish-raw-findings.md` **1–411**.

Additional prior reports completely read under `docs/reviews/2026-11-02-design-goldfish/`: `parent_security_followup.md` **1–31**; `security_review_status.md` **1–14**; `zoom_out_report.md` **1–34**; `comprehension_report.md` **1–60**; `critic_report.md` **1–16**; `design_critic_report.md` **1–49**; `structural_report.md` **1–42**; `style_report.md` **1–46**; `intermediate_zoom_out_report.md` **1–42**. No inaccessible conversation was retrieved.

Safe source projections parsed complete files **in-process**, emitting approved structural fields only:

- Compose **1–619**, production override **1–13**, staging override **1–28**.
- nginx main **1–106**; Pi-hole **1–37**; pgAdmin **1–37**; Grafana **1–35**; Prometheus **1–32**; Pterodactyl **1–72**.
- Loki **1–55**; Prometheus configuration **1–15**; Promtail configuration **1–30**; Grafana datasource provisioning **1–23**. Some projections supplied only counts.
- SQL missed ranges—PostgreSQL **15, 153**, MariaDB **1, 3**—received count-only projections. No semantic SQL conclusion relies on those projections. Scripts received hash verification only.

Codebase-memory: Tier 2, project `mnt-Data-Projects-Infrastructure-Home-Server`, observed generation **2026-11-02T09:30:02Z**. Bounded Resource search returned **14 results**, no remaining pages. Exact-path coverage checked **49 paths**, no remaining pages. Unusable nginx ranges received direct safe projections; partial SQL coverage remains qualified above. Other results reported metadata match/no recorded issue, which is best effort, not completeness. No call-graph or runtime-reachability claim was inferred.

Primary documentation sections consulted are linked above. The Loki authentication fetch initially failed, then succeeded. **Unreadable mandatory files: none.** Initial output truncation was recovered by bounded rereads. Source projections are not complete raw-code security inspection. Remote `/srv`, privileged runtime and ignored credential stores were not inspected. No writes, builds, SSH/live probes, mutations, credential changes, notifications or subagents were used.
