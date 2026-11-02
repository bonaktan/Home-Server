# Stage 5 — Initial Zoom Out

Native task: `/root/design_zoom_initial`. Completion: actual native `FINAL_ANSWER` received. No retry. The full reviewer response follows unchanged.

---

Initial Zoom Out: **one Major architecture-contract gap; no Blocker or Nit.** The objective is clear and the architecture addresses the verified provisioning, deployment-consistency and recovery problems. I found no demonstrated YAGNI violation or existing equivalent utility that the proposal unnecessarily replaces. The two configuration methods, Vault/KMS, synchronous dual-destination secret protection and local telemetry backends are recorded owner constraints or selections.

**ZI-01 — Major — Include recovery capture in the lifecycle coordination boundary.**  
**Target scope:** lines 257–259, 304–306 and 331; related supporting contract: `docs/designs/maintenance-policy.md:28`.

The shared lifecycle operation explicitly serializes CI deployment, image maintenance and secret activation. Host configuration and certificate hooks also explicitly coordinate with it. Scheduled recovery-set capture is described separately through native consistent captures, quiescence and staggered scheduling, without stating how it participates in that same coordination boundary.

A permitted interleaving can therefore capture database account state, then allow credential activation or an application/schema update, then record newer active-secret/configuration/image references in the recovery manifest. Individually valid captures can produce an incompatible recovery set. Staggering timers reduces contention but does not prevent manual operations or delayed jobs from overlapping.

This is a **documented coordination omission**, not evidence that an implemented backup has failed. The draft already recognizes compatible recovery as a requirement; the missing connection is between that requirement and its selected lifecycle mechanism.

**Smallest useful correction:** include recovery capture as a participant in the existing lifecycle contract. Capture the consistent local data plus its matching roles/configuration/image/secret references while conflicting lifecycle mutations are excluded; release that boundary before remote transfer and repository verification. Avoid introducing another controller or independent lock scheme. Add a fixture that pauses capture while a credential activation or deployment is requested, then verifies the resulting set restores with its recorded inputs.

The acknowledged capacity, audit-privacy, Pterodactyl-delivery, provider-access and retention-compatibility gates remain material. They are explicitly identified as unproven and are not additional demonstrated defects from this review. Missing executable code or a complete implementation file list was not graded.

Read manifest:

- **Persona, read first:** `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/zoom_out.md`.
- **Standard:** `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/resources/document_standards/zoom-out-standard.md`.
- **Workflow instruction:** `/home/bonny/.codex/skills/codebase-memory/SKILL.md`.
- **Frozen target:** `docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md`, completely read, lines **1–484**. SHA-256 verified before and after: **`927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`**.
- **Manifest:** `docs/reviews/2026-11-02-design-goldfish/input_manifest.md`, completely read.
- **Required context read completely:** `README.md`; `System_Documentation.md`; `Hardware_Info.md`; `new_server_hardware.md`; `concepts_brief.md`; all eight requested `docs/designs/` documents: `database-boundaries.md`, `secrets-publication.md`, `vault-operations.md`, `ci-authorization.md`, `ci-deployment.md`, `maintenance-policy.md`, `operations-tooling.md`, `security-considerations.md`; both `docs/investigations/2026-11-01-database-connectivity.md` and `2026-11-01-debian-host-baseline.md`.
- **Historical provenance read completely:** `goldfish_review_report.md` and `docs/reviews/2026-11-02-goldfish-raw-findings.md`. Their findings were not substituted for current-target analysis.
- **Source verification:** complete structural reads of `setup.sh`, `new_setup.sh`, `compose.yaml`, both Compose overrides, Prometheus/Loki/Promtail configurations, nginx main/Pi-hole configurations and Grafana datasource provisioning. Sensitive-related lines and environment/command values were suppressed or reduced to safe structural facts. PostgreSQL SQL was read at lines 1–40 and 140–180, including both missed-coverage lines; all three MariaDB SQL lines were inspected through safe structural reporting. Additional bounded literal searches covered setup scripts and infrastructure YAML.
- **Graph verification:** Tier 2, project `mnt-Data-Projects-Infrastructure-Home-Server`; session status generation **2026-11-02T07:16:46Z**, newer than the delegated generation. Task-directed Function search returned `setup.log`; both-direction trace and exact snippet showed a logging helper, not equivalent operational orchestration. Resource search returned 13 database/telemetry resources; PostgreSQL topology traced both directions. All result pages completed. Exact coverage checked for every relied-on repository path, with root-scope diagnostics paginated. Relevant nginx unusable ranges and SQL missed lines were read directly. Other clean signals remain best effort; ignored paths and remote `/srv` prevent exhaustive absence claims.
- **Unreadable required files:** none. Initial output truncation was recovered through bounded rereads. No SSH, service probes, edits, implementation, external documentation retrieval or subagent delegation.
- **Finding counts:** **Blocker 0; Major 1; Nit 0.**
