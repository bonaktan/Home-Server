# Goldfish annotated resolution report

**Status: resolved — document-level corrections and owner risk decisions applied.**

**Target:** [working design](../../../design_draft.md), full file, and the supporting policy documents listed below. **Input findings:** R-01–R-05 and N-01–N-05 in the [consolidated review](../../../consolidated_review_report.md), independently confirmed by the [dedicated security review](../2026-11-02-security-review-rerun/security_report.md). The frozen reviewed version and raw reports remain unchanged.

All ten findings are categorized **PROPOSE FIX** and applied under the owner's targeted instructions/delegation. R-02/R-04/R-05 are settled through explicit policy/risk acceptance, not technical removal of the risk. R-01/R-03 are corrected in the planned contracts. No finding severity was changed. No implementation or independent post-edit re-review is claimed.

## Major findings and resolutions

### R-01 — Proxy-header trust — Major — PROPOSE FIX

* **Original scope:** frozen lines 288–290 and 296; PSEC-01/SEC2-01.
* **Discrepancy/rationale:** broad replacement-address trust could let an untrusted reachable bridge peer assert a LAN identity and undermine internal address ACLs.
* **Owner instruction:** “R-01: yes, approved.”
* **Applied edit:** D-29 confines replacement-address handling to actual ingress peers/public virtual hosts, separates ingress from application peers, and makes internal authorization use the original TCP peer. Internal admin names must use the intended direct LAN path. The UI upstream repair remains separate.
* **Remaining proof:** inspect effective addressing/configuration and verify real LAN access, forged-header/container/tunnel rejection and IPv6. These checks are required before applying the eventual nginx/network configuration.

### R-02 — Both backup destinations fail while writes continue — Major — PROPOSE FIX

* **Original scope:** frozen 60–63, 304, 321–323; DES-01/SEC2-02.
* **Discrepancy/rationale:** the no-write assumption had no defined response when background/local writes continued, leaving the recovery-point requirement ambiguous.
* **Owner instruction:** fire a Grafana alert, keep services running, and make degraded protection visible.
* **Applied edit:** D-30 explicitly accepts exceeding the normal 24-hour database/Pterodactyl target during failed protection. Do not automatically stop writers solely because backups fail or age. Retain last usable sets, retry protection, persist per-destination/data-class degraded state and freshness, and alert/remind through existing Grafana routes. Clear only after fresh verified protection returns. Discretionary updates retain their own recovery prerequisites.
* **Accepted risk:** loss can exceed 24 hours if the active host fails before protection returns; alerts may be interrupted under D-20. This does not relax zero-loss acknowledgment of managed secrets.

### R-03 — Recovery capture coordination — Major — PROPOSE FIX

* **Original scope:** frozen 257–259, 304–306, 331; ZI-01/SEC2-03.
* **Discrepancy/rationale:** staggered scheduling did not serialize capture and matching input selection with deployments, schema/configuration or credential transitions.
* **Owner instruction:** “R-03: yes.”
* **Applied edit:** D-31 puts consistent local data capture plus matching account/image/configuration/active-secret references in the existing lifecycle coordination contract. Use supported native consistency/quiescence, finalize the local manifest, then release coordination before transfer/checks. No extra controller or lock scheme is added.
* **Remaining proof:** pause capture across a conflicting requested mutation and verify an interrupted/concurrent set restores using its recorded inputs. The lock alone is not a data snapshot.

### R-04 — Hostile backup intake and size/cost exposure — Major — PROPOSE FIX

* **Original scope:** frozen 233, 308–312, 319, 327–331; DES-02/SEC2-04.
* **Discrepancy/rationale:** growth monitoring does not independently contain a compromised writer's storage/operation consumption.
* **Owner instruction:** alert near a predetermined backup size. The follow-up explicitly contrasted independent intake limits with alerts-only acceptance of exhaustion/cost; the owner selected **“Alerts only; accept storage and cost exposure.”**
* **Applied edit:** D-32 defines advisory per-destination byte budgets and warning/exceeded/clear/stale state, routed through existing Grafana destinations. Starting ratios are warning at 80%, exceeded at 100%, and clear below 75%; actual GiB budgets follow dataset/churn/free-space evidence before enabling the rules. Observe shared-filesystem free space and available provider usage separately.
* **Accepted risk:** no automatic admission cutoff, spending cap, credential revocation, pruning or service shutdown follows from the advisory budget. A hostile writer can exhaust capacity or grow R2 costs. Natural destination failures remain possible and trigger D-30 degradation plus secret-publication deferral. Existing copy-deletion protection remains required.

### R-05 — Second-host Loki authority — Major — PROPOSE FIX

* **Original scope:** frozen 274–276, 296; PSEC-02/SEC2-05.
* **Discrepancy/rationale:** a port grant did not establish query-only API authority.
* **Owner instruction:** the main server has backend authority.
* **Applied edit:** D-33 explicitly permits the main host's broader supported second-Loki ingestion/control APIs in addition to Grafana queries. CI and unrelated principals remain excluded. This grants no second-host OS or backup-retention administration; no query-only gateway or central ingress replica is selected.
* **Accepted risk/proof:** an authorized or compromised main-host principal can alter or interrupt second-host telemetry. Validate permitted API behavior in disposable fixtures and verify rejected unrelated principals; no production shutdown probe was performed.

## Delegated Nits — all PROPOSE FIX

| Item | Original scope | Applied correction |
| --- | --- | --- |
| N-01 / CMP-01 | Frozen 251 | Define the admin-managed per-host deployment epoch, request/approval binding, ops-admin renewal after restore/reconciliation, rejection of older unconsumed authority and retained completed history. A previous build may be selected through a newly authorized current-epoch operation. |
| N-02 / STY-01 | Frozen 21 | Describe Technical Plan choices as present, and exact files/procedures/allocations as Detailed Implementation work; synchronize current stage descriptions. |
| N-03 / STY-02 | Frozen 257 | Describe the bounded lifecycle operation as custom operational glue. |
| N-04 / STY-03 | Frozen 388 | Distinguish Vault's documented PostgreSQL/S3 backends from unverified R2 deployment compatibility. |
| N-05 / STY-04 | Frozen 376 | Replace the double-negative licensing discussion with the owner's selection after the documented comparison, retaining acceptance gates and sources. |

The owner delegated these wording choices. The CI supporting documents also carry the epoch definition, current GHCR selection and recovery-capture coordination so the main draft and its references agree.

## Files changed and rationale

| Working document | Reason |
| --- | --- |
| [concepts_brief.md](../../../concepts_brief.md) | Append D-29–D-33 and delegated-Nit decisions after the frozen original brief; preserve historical requirements and explicit later exceptions. |
| [design_draft.md](../../../design_draft.md) | Apply the approved contracts, accepted risks and Nits to goals/recovery policy, architecture, alternatives and evidence references. |
| [maintenance-policy.md](../../designs/maintenance-policy.md) | Coordinate local capture and lifecycle changes; distinguish continued service operation from deferred discretionary updates and secret protection. |
| [operations-tooling.md](../../designs/operations-tooling.md) | Carry capture ordering, advisory size alerting and accepted resource/cost exposure into the selected tools. |
| [ci-authorization.md](../../designs/ci-authorization.md) | Define epoch/invalidation semantics and bind them to authorization evidence; synchronize lifecycle participation and selected registry wording. |
| [ci-deployment.md](../../designs/ci-deployment.md) | Define restore/replay generation without changing the restricted submission boundary. |
| [security-considerations.md](../../designs/security-considerations.md) | Update review provenance and distinguish corrected contracts, accepted risks and unpassed tests. |
| [secrets-publication.md](../../designs/secrets-publication.md) | Explicitly preserve required dual-destination secret acknowledgment despite the new data-backup/size exceptions. |
| [consolidated_review_report.md](../../../consolidated_review_report.md) | Keep historical findings/severity and mark their current authorized document dispositions. |

The [pre-edit manifest and archive](before_manifest.md) preserve the nine original documents. The [post-edit manifest](after_manifest.md) records the resulting hashes. All archived copy references retain their original source context; raw reviewer reports and reviewed snapshots are not edited.

## Verification and handoff

Checks cover Markdown links/fences/tables and unintended whitespace, matching current policy across documents, the first 417 brief lines, immutable investigation reports, frozen reviewed snapshots and raw review artifacts, and the pre/post document manifests. No runtime, credential, package, firewall, database or service change is part of this resolution. No application or startup code is modified.

Counts: **10 accepted PROPOSE FIX edits; 0 CONTEST; 0 ESCALATE; 0 DECLINE; 0 unaddressed document findings.** R-02/R-04/R-05 remain accepted operating risks. R-01/R-03 and the other planned controls still require implementation acceptance checks; all capacity, privacy, actual-consumer and isolated-restore gates remain.

Revised Alternatives Considered awaits its EGM section approval before Detailed Implementation. This resolution does not claim another independent review, implementation readiness or a converged review loop.
