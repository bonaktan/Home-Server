# Stage 8 — Intermediate Zoom Out

Native task: `/root/design_zoom_final`. Actual final response received. No retry. Full final response follows; the parent separately records its disclosed tool-output privacy incident in review_progress.md.

---

**Stage 8 verdict: no new high-altitude findings; architectural closure remains open.** The unchanged design addresses the verified provisioning, deployment-consistency and recovery problems. Its selected components and accepted placement/availability choices do not demonstrate unnecessary platform complexity.

No ZF IDs are assigned. Earlier findings remain unresolved; no mitigation was applied between reviews. This is an architecture pass, not implementation readiness, convergence proof or a completed independent security review.

The main simplification is already present: retain Compose and shared database engines, reuse Grafana notifications, build remotely, recover manually, and keep orchestration bounded to known administrative operations. Publication and lifecycle coordination require custom security-sensitive glue, but the requirements justify that glue. They do not justify a general management service, universal command classifier, orchestration platform or standby deployment. STY-02’s clarification that the lifecycle operation is custom remains useful.

**Disposition of earlier Major themes**

| Earlier finding | Exact frozen scope | Architectural disposition and smallest correction |
| --- | --- | --- |
| **ZI-01 — recovery capture coordination** | 257–259, 304–306, 331 | Reaffirmed. Include consistent capture and its matching configuration/image/secret references in the existing lifecycle coordination boundary. Release that boundary before remote transfer. Reuse the selected operation and lock rather than create another controller or locking scheme. |
| **DES-01 — continued writes without either backup destination** | 60–63, 304, 321–323 | Reaffirmed. Define the response when the no-write assumption fails, including stop/resume conditions or an explicit extended-loss exception. D-19 does not already settle this case. The selected capture tools and accepted downtime can support a bounded policy; another recovery platform is not established as necessary. |
| **DES-02 — hostile append-only intake** | 233, 308–312, 319, 327–331 | Reaffirmed. Enforce aggregate second-host storage admission independently of the Atom, preserving host/telemetry/maintenance reserves. Rest-server’s repository-size option is a candidate control, not proof of an aggregate boundary across subrepositories and temporary uploads. R2 exposure and independent revocation still require an explicit policy. [Rest-server documentation](https://github.com/restic/rest-server/blob/master/README.md). |
| **PSEC-01 — proxy-header trust** | 288–290, 296 | Reaffirmed as limited parent security evidence. Correct the existing nginx trust boundary between ingress and application peers, then test forged headers and intended LAN restrictions. This fits the current nginx/network configuration; it does not require replacing the network architecture. nginx documents that trusted peers can supply replacement client addresses. [Real-IP module](https://nginx.org/en/docs/http/ngx_http_realip_module.html). |
| **PSEC-02 — telemetry query authority** | 274–276, 296 | Reaffirmed as limited parent security evidence. Explicitly choose broader main-host backend trust or a restricted query interface. If query-only authority is required, assess a small second-host access proxy using established nginx technology within the observability role. That component must be selected explicitly; it need not replicate central ingress. Allow permitted paths and methods deliberately: Loki documents separate authorization and a shutdown endpoint accepting GET. [Authentication](https://grafana.com/docs/loki/latest/operations/authentication/), [HTTP API](https://grafana.com/docs/loki/latest/reference/loki-http-api/). |

These corrections can largely extend the selected components and contracts. PSEC-02 may add a narrow access component, depending on the chosen trust policy. None of the evidence establishes a need for new platform machinery.

Capacity, pre-storage audit privacy, actual Pterodactyl delivery, provider permissions, protected-repository compatibility and isolated recovery remain material feasibility gates. Their acknowledged pending status is not an additional demonstrated product failure. CMP-01 and the four style Nits remain earlier findings, without reclassification here.

**Actual read and verification manifest**

- Persona read **first**, completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/zoom_out.md`, **1–74**. Mode **REVIEW**.
- Standard applied completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/resources/document_standards/zoom-out-standard.md`, **1–60**.
- Structural-search skill read completely: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`, **1–79**.
- Frozen target read completely, recovering truncated outputs through bounded rereads: `docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md`, **1–484**. FeatureRange **1–484**; DetailedRange **N/A, not drafted**. SHA-256 verified before and after: **`927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`**.
- Input manifest read completely: `docs/reviews/2026-11-02-design-goldfish/input_manifest.md`, **1–47**. All **30** listed original-file hashes and logical line counts matched.
- Baseline documents read completely: `README.md` **1–34**; `System_Documentation.md` **1–319**; `Hardware_Info.md` **1–62**; `new_server_hardware.md` **1–145**; `concepts_brief.md` **1–606**.
- Supporting designs read completely under `docs/designs/`: `database-boundaries.md` **1–62**; `secrets-publication.md` **1–111**; `vault-operations.md` **1–75**; `ci-authorization.md` **1–58**; `ci-deployment.md` **1–77**; `maintenance-policy.md` **1–66**; `operations-tooling.md` **1–75**; `security-considerations.md` **1–34**.
- Investigations read completely: `docs/investigations/2026-11-01-database-connectivity.md` and `2026-11-01-debian-host-baseline.md`, each **1–88**.
- Historical provenance read completely: `goldfish_review_report.md` **1–154**; `docs/reviews/2026-11-02-goldfish-raw-findings.md` **1–411**.
- Explicit current-run context read completely under the review directory: `zoom_out_report.md` **1–34**; `comprehension_report.md` **1–60**; `critic_report.md` **1–16**; `design_critic_report.md` **1–49**; `structural_report.md` **1–42**; `style_report.md` **1–46**; `parent_security_followup.md` **1–31**.
- Reuse verification: complete structural reads of `setup.sh` **1–212** and `new_setup.sh` **1–202**; safe structural projection of complete `compose.yaml`; complete nginx main/Pi-hole/pgAdmin, Loki, Prometheus, Promtail and Grafana datasource configurations. PostgreSQL SQL **1–40, 140–180** and MariaDB SQL **1–3** inspected. These existing bootstrap/migration paths do not supply an equivalent protected publisher or coordinated lifecycle utility.
- Graph: Tier 2, project `mnt-Data-Projects-Infrastructure-Home-Server`; status generation **09:11:59Z**, coverage generation **2026-11-02T09:14:22Z**. Function search, both-direction trace and exact snippet identified `setup.log` as a logging helper. Resource search and nginx topology trace completed without remaining pages. Exact coverage checked **38 relied repository paths**; all three relied unusable nginx files and every relied SQL missed range were read directly. Clean coverage remains best effort. Ignored paths and remote `/srv` preclude exhaustive absence claims.
- Web checks: official nginx Real-IP, Loki authentication/API and rest-server documentation. No live probes, SSH, builds, edits or subagents. A source-output redaction miss was reported separately to the parent; credential text is excluded from this report.
- **Missing required reads: none. New finding counts only: Blocker 0; Major 0; Nit 0.**
