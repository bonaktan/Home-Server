What this proposes

Keep central services and application deployments on the Atom, move builds to GitHub-hosted VMs, and give the second server local telemetry storage plus protected backup storage. Use Vault with AWS KMS for normal unseal, while independently encrypted exports support rebuilding without the original KMS key. Deployment, image maintenance and manual secret activation share controlled lifecycle operations; acknowledged secret changes require verified recovery copies at both destinations. Adopt existing host and application state gradually, with capacity, privacy, consumer compatibility and recovery tests gating implementation.

How the existing system works, per this document

The Atom runs central Docker infrastructure, separate application deployments and two production self-hosted Actions runners. ITskolar can reach PostgreSQL, but missing backend passwords, connection privileges and expected schemas prevent usable database access; its workflow also leaves production Compose selection implicit. Pi-hole responds locally on port 8080, while nginx’s configured upstream path fails, and repository setup assumptions differ from effective host configuration. Existing Grafana alerting must be preserved, while backup destinations, complete inventories and several operational mechanisms remain unverified.

**COMPLETE — 0 Blockers, 0 Majors, 1 Nit.** The architecture’s parts connect: placement, authorization, publication, activation, maintenance and recovery boundaries are understandable. Explicit feasibility gates are consistently distinguished from completed validation.

**CMP-01 — Nit — Undefined “authorization generation” after restoration**

**Frozen scope:** line 251, Technical Plan §7.

The document requires automatic submission execution to remain suspended after restoring older host state until reconciliation and renewal of its “authorization generation.” Neither the target nor the linked CI documents defines that term. Replay/supersession tracking explains ordinary retries, but the reader cannot tell what generation renewal changes or which earlier requests and approvals it invalidates.

**Minimal clarification:** Define what the generation identifies, who renews it, and how renewal affects previously issued requests or approvals. Its storage format and command interface can remain for Detailed Implementation.

**Actual read manifest**

Persona read first and completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/comprehension.md`, lines 1–69. Mode REVIEW. **No document standard applied.**

Frozen target read completely in bounded ranges:

- `docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md`, lines 1–484.
- SHA-256 verified: `927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`.
- FeatureRange 1–484; DetailedRange N/A, not drafted.
- `docs/reviews/2026-11-02-design-goldfish/input_manifest.md`, lines 1–47.

All **15 mandatory baseline documents** read completely:

- `README.md`, 1–34.
- `System_Documentation.md`, 1–319.
- `Hardware_Info.md`, 1–62.
- `new_server_hardware.md`, 1–145.
- `concepts_brief.md`, 1–606.
- `docs/designs/database-boundaries.md`, 1–62.
- `docs/designs/secrets-publication.md`, 1–111.
- `docs/designs/vault-operations.md`, 1–75.
- `docs/designs/ci-authorization.md`, 1–58.
- `docs/designs/ci-deployment.md`, 1–77.
- `docs/designs/maintenance-policy.md`, 1–66.
- `docs/designs/operations-tooling.md`, 1–75.
- `docs/designs/security-considerations.md`, 1–34.
- `docs/investigations/2026-11-01-database-connectivity.md`, 1–88.
- `docs/investigations/2026-11-01-debian-host-baseline.md`, 1–88.

Additional complete reads:

- Historical provenance only: `goldfish_review_report.md`, 1–154; `docs/reviews/2026-11-02-goldfish-raw-findings.md`, 1–411.
- Linked drafting reference: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/skills/egm-draft/SKILL.md`, 1–314, read as reference material.
- Coverage instructions: `/home/bonny/.codex/skills/codebase-memory/SKILL.md`, 1–79.

**Checks and limits:** 22 distinct files read completely, including 19 repository documents. All 18 document hashes listed in the input manifest matched. All 15 distinct local links in the frozen target resolve against the original repository root. Initial combined-output truncations were recovered through bounded reads; unreadable or incomplete files: **0**.

One Tier 2 coverage call checked all 19 repository paths: `metadata_match`/`no_recorded_issue`, no pagination or reported gaps, generation `2026-11-02T07:25:03Z`. This is best-effort coverage; conclusions rely on complete direct document reads. Targeted literal searches checked definitions across those documents. Structural/source-code queries: **0**; implementation source/configuration reads: **0**; web checks: **0**; live probes: **0**; writes: **0**. No parent conversation or current-run reviewer findings were retrieved.

---

Native completion record: `/root/design_comprehension` returned this complete final report on retry 1 after an initial usage-limit error. No document standard was applied. The complete reviewer result above is preserved; this footer is parent metadata.
