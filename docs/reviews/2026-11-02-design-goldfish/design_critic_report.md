# Stage 7 — Design critique

Native task: `/root/design_critic`. Actual final report received. No retry. Full reviewer response follows.

---

The architecture addresses the feature-specification standard’s problem, boundaries, alternatives and major trade-offs. Two remaining policy gaps need resolution. Neither demonstrates product infeasibility.

**DES-01 — Major — No defined response when both backup destinations fail and writes continue.**

**Frozen scope:** lines 60–63, 304, 321–323.

The design requires a recoverable database/Pterodactyl point within 24 hours, but its both-destinations-unavailable treatment only says to verify background/local/game/queued writes before relying on the no-write assumption. It never defines the action when that verification finds writes.

For example, R2 becomes unavailable and the second destination rejects backups because of storage or authentication failure. Background writes continue for more than 24 hours, then the Atom fails. Neither checking connectivity nor reporting stale protection prevents loss beyond the stated limit. D-19 covers loss of both hosts during an R2 outage while second-server protection is healthy; it does not clearly authorize this case.

**Minimal correction:** define the loss-of-protection policy when the no-write test fails: establish alternate protection, enforce a bounded quiescence/final-capture procedure, or obtain an explicit extended-loss exception. Define which workloads stop and the condition for resuming writes. A fixture should cover background writes with both destinations unavailable and central notifications unavailable.

**Disposition:** architecture policy must be settled before accepting this failure contract. Exact commands and thresholds belong in Detailed Implementation. This finding does not reopen D-19’s accepted exception.

**DES-02 — Major — Append-only intake needs a resource boundary independent of the Atom.**

**Frozen scope:** lines 233, 308–312, 319, 327–331.

The design correctly acknowledges that a compromised Atom can upload garbage or consume quota, but its specified response is growth tracking and independent validation. The capacity ledger measures legitimate workloads; it does not bound a hostile writer.

An append-only credential can exhaust its available destination storage without deleting anything. On the second server, unrestricted intake can consume space needed by telemetry, independent applications and recovery maintenance. On R2, indefinitely protected uploads create storage and operation charges until independent intervention. R2 bills stored volume and operations; indefinite object protection does not provide spending control. [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/).

**Minimal correction:** require an aggregate, destination-enforced byte/inode allowance for the second-server backup identity, including repository creation and temporary-upload space, with protected host/telemetry/maintenance reserves. Rest-server documents a repository size limit, although the implementation must verify its scope and bypass resistance. Separately define R2 abuse detection, independent credential revocation and an accepted spending exposure or enforceable intake bound. [Rest-server documentation](https://github.com/restic/rest-server/blob/master/README.md).

Test these limits using routine credentials and direct hostile uploads, without relying on cooperation from the Atom. Reaching a limit must reject new intake while preserving existing recovery sets and following the secret-deferral and database protection policies.

**Disposition:** architectural containment requirement; numerical allocations and enforcement configuration can follow measurement. This does not establish that current storage is insufficient.

The existing capacity, pre-storage audit privacy, actual Pterodactyl delivery, protected-repository compatibility and isolated-restore gates remain necessary. Their acknowledged absence is not an additional defect at this architecture-review stage. Primary documentation supports the stated distinction between rebuilding Vault from independent exports and unsealing its old KMS-dependent store. R2 also documents atomic conditional creation and the ambiguity of negative reads while earlier writes remain in flight. [Vault seal behavior](https://developer.hashicorp.com/vault/docs/concepts/seal), [R2 consistency](https://developers.cloudflare.com/r2/reference/consistency/).

**Read manifest and limits**

- Persona read first and completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/agents/design_critic.md`, lines 1–63.
- Standard read completely: `/home/bonny/.codex/plugins/cache/egm/egm/0.1.0/resources/document_standards/feature-spec-standard.md`, lines 1–36.
- Frozen target read completely in bounded chunks, recovering truncated output: `docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md`, lines 1–484. DetailedRange: N/A. SHA-256 verified twice: `927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`.
- Input manifest read completely. Required baseline read completely: `README.md` 1–34; `System_Documentation.md` 1–319; `Hardware_Info.md` 1–62; `new_server_hardware.md` 1–145; `concepts_brief.md` 1–606.
- All eight required supporting designs read completely: database-boundaries 1–62; secrets-publication 1–111; vault-operations 1–75; ci-authorization 1–58; ci-deployment 1–77; maintenance-policy 1–66; operations-tooling 1–75; security-considerations 1–34.
- Both required investigations read completely, lines 1–88 each. Historical `goldfish_review_report.md` 1–154 and `docs/reviews/2026-11-02-goldfish-raw-findings.md` 1–411 read as provenance only.
- Codebase-memory skill read completely. Exact-path coverage checked for all 19 relied repository documentation paths. Returned generations were `2026-11-02T07:25:03Z` and `2026-11-02T09:05:10Z`; all reported `metadata_match/no_recorded_issue`, with no remaining pages. Coverage is best effort; conclusions rely on direct document reads. No source/configuration or structural call-graph claims were needed.
- Web verification: official Cloudflare R2 lock, consistency, S3 compatibility and pricing documentation; official Restic retention documentation and rest-server README; HashiCorp Vault seal documentation. Debian’s auditctl page timed out twice; no finding relies on its contents.
- Missing/unreadable mandatory files: **none**. No current-run peer reports, conversation history, live services, credentials or remote `/srv` files consulted. No edits or implementation performed.

**Counts:** 0 Blockers, 2 Majors, 0 Nits. One read-only architecture critique pass; implementation readiness and operational feasibility remain unproven.
