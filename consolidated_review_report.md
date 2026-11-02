# Current-design Goldfish review

* **Date:** 2026-11-02
* **State:** Owner resolutions D-29–D-33 are applied to the working design. All five Major findings are settled at the document level through corrections or explicit risk acceptance, and all five Nits are corrected. Implementation gates remain; no post-edit independent re-review is claimed.
* **Target:** [Frozen design snapshot](docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md), lines 1–484, SHA-256 `927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907`.
* **Working draft:** [design_draft.md](design_draft.md), updated after review under the owner's targeted instructions. The frozen target and raw reviewer reports remain unchanged. [The original input manifest](docs/reviews/2026-11-02-design-goldfish/input_manifest.md) and [pre-resolution archive](docs/reviews/2026-11-02-design-resolution/before_manifest.md) preserve provenance.

The review identified five Majors and five Nits. Independent security review confirmed the five Majors and added no distinct finding. The owner then approved corrections for R-01/R-03, selected explicit operating risks for R-02/R-04/R-05, and delegated Nit fixes. **All ten document findings are settled; the corresponding implementation tests remain unpassed.** No completed reviewer demonstrated a concept/product-feasibility Blocker. Neither review completion nor accepted risk is a security clearance.

This review targets the concrete architecture and alternatives, including selected Vault/KMS, CI transport, operating tools and host split. The earlier [brainstorm review](goldfish_review_report.md) covered a different frozen brief and is preserved separately. Detailed Implementation has not been drafted; implementation-readiness was deliberately not run.

## Owner-directed resolution

| Item | Current disposition | Decision and remaining boundary |
| --- | --- | --- |
| R-01 | Document correction applied | D-29: internal authorization uses the original TCP peer; replacement-address trust is scoped to actual ingress peers/public virtual hosts. Source configuration is not changed yet; forged-header/LAN/IPv6 tests remain required. |
| R-02 | Settled by explicit risk acceptance | D-30: services keep running during degraded protection, including both-destination failure with continued writes. Persist state and alert through Grafana. The owner accepts exceeding the normal 24-hour database/Pterodactyl target; secret acknowledgment remains gated. |
| R-03 | Document correction applied | D-31: consistent local capture and matching references join existing lifecycle coordination; remote transfer follows after releasing it. Concurrency/interruption/restore checks remain. |
| R-04 | Settled by explicit risk acceptance | D-32: advisory size alerts only; the owner explicitly accepts storage exhaustion and R2 cost exposure. No hard upload cutoff or automatic pruning/revocation/shutdown is claimed. Actual byte budgets follow measurement. |
| R-05 | Settled by explicit trust acceptance | D-33: the main host has broader second-Loki backend API authority. CI/unrelated principals remain excluded; no query-only gateway is added. OS/backup-retention administration is not granted. |
| N-01–N-05 | Delegated corrections applied | Define deployment epoch/restore invalidation, fix stale stage wording, identify custom lifecycle glue, distinguish S3 backend from R2 compatibility, and simplify the product/license paragraph. |

See the [annotated resolution record](docs/reviews/2026-11-02-design-resolution/goldfish_review_report.md) for exact edits, categories, owner evidence and verification. Categories: 10 PROPOSE FIX applied, 0 CONTEST, 0 ESCALATE, 0 DECLINE; 0 unaddressed document findings. No severity was changed and no raw finding was erased.

## Historical review coverage and completion

| Stage/lens | Native task | Result | Retry or read completion |
| --- | --- | --- | --- |
| 5 — initial zoom out | /root/design_zoom_initial | Completed: 0 Blocker, 1 Major, 0 Nit | No retry |
| 6 — comprehension | /root/design_comprehension | Completed: 0 Blocker, 0 Major, 1 Nit | Initial usage-limit failure; retry 1 completed |
| 7 — design | /root/design_critic | Completed: 0 Blocker, 2 Majors, 0 Nit | No retry |
| 7 — structure | /root/design_structure | Completed: 0 Blocker, 0 Major, 0 Nit | Completed linked historical reads through follow-up before acceptance |
| 7 — style | /root/design_style | Completed: 0 Blocker, 0 Major, 4 Nits | Completed linked historical reads through follow-up before acceptance |
| 8 — intermediate zoom out | /root/design_zoom_final | Completed: 0 new findings; prior Major themes reaffirmed | No retry; tool-output privacy incident recorded below |
| Additional dedicated security — original run | /root/design_security | **Not run to completion; no final report** | Initial usage-limit failure; single retry failed at model capacity; retained as history |
| Dedicated security — owner-requested rerun | /root/security_review_rerun | **Completed: all 5 existing Majors confirmed; 0 distinct new findings** | New fresh-context run; no retry needed |
| 9 — implementation-readiness | None | **Not run** | Detailed Implementation is absent by design |

Every counted Goldfish was launched with `fork_turns="none"`, its installed persona, explicit standard where applicable, and read-only instructions. Earlier stages did not receive current-run peer findings. Stage 8 intentionally receives earlier stage reports, as the EGM protocol requires. The security rerun explicitly received frozen prior reports as context and independently verified their claims. Seven reviewer tasks completed across the original review and requested rerun; the earlier failed task is not counted as completed. Complete final reports and actual read manifests are preserved below; launches and interim messages do not count as completed reviews.

The original six completed reviewers yielded **0 Blockers, 3 Majors, 5 Nits**; parent verification added **2 Majors**. The fresh security review independently confirmed **R-01–R-05**, adding **0 distinct new findings**. SEC2 IDs are verification references, not five additional defects. The historical unique count remains **0 Blockers, 5 Majors, 5 Nits**. Later owner resolutions settle those findings as documented above. No independent post-resolution re-review, clean round or convergence is claimed.

## Historical Major findings — frozen reviewed design

### R-01 — Restrict trusted proxy headers before claiming LAN-only administration

**Source:** parent PSEC-01, independently confirmed by SEC2-01. **Frozen scope:** 288–290, 296. **Priority:** Major.

The repository's [nginx configuration](infra/nginx/nginx.conf) trusts `172.16.0.0/12` to supply `CF-Connecting-IP`, while the Pi-hole and pgAdmin virtual hosts allow the LAN address range. nginx shares networks with application components. A reachable untrusted peer in the trusted source range can supply a false LAN client address and undermine the intended network ACL.

This is source-confirmed unsafe trust configuration, conditional on actual peer addressing and reachability; no live bypass was attempted. The replacement-address behavior is documented by [nginx](https://nginx.org/en/docs/http/ngx_http_realip_module.html).

**Required correction:** distinguish trusted ingress peers from application peers; define the effective identity used for internal access decisions. Test denial of forged LAN headers from an untrusted container/source, alongside permitted real LAN access and IPv6 behavior. Repairing the nginx-to-Pi-hole upstream alone does not close this issue. Exact networking/configuration choices need to be explicit.

### R-02 — Decide what happens when both backup destinations fail and writes continue

**Source:** DES-01, independently confirmed by SEC2-02. **Frozen scope:** 60–63, 304, 321–323. **Priority:** Major.

The design says to verify background/local/game/queued writes before relying on the owner's no-new-data assumption. It does not define what to do when that verification finds writes. Continued writes beyond the last usable 24-hour recovery point, followed by Atom loss, can exceed the normal target. D-19's accepted R2-outage/dual-host-loss exception does not already settle this different case.

**Required decision:** establish alternate protection, define bounded quiescence/final-capture and resume conditions, or obtain a specific extended-loss exception. Identify the affected workloads. Exact commands and timing margins follow in Detailed Implementation. Test background writes with both destinations and central notifications unavailable. Do not silently turn an alert or lost Internet connection into successful protection.

### R-03 — Include recovery capture in lifecycle coordination

**Source:** ZI-01, independently confirmed by SEC2-03. **Frozen scope:** 257–259, 304–306, 331. **Priority:** Major.

CI replacement, automatic maintenance, secret activation, host configuration and certificate hooks coordinate with the lifecycle operation. Backup capture is described through native consistency/quiescence and staggered timers without joining that boundary. A credential/schema/configuration transition can therefore occur between data capture and recording its supposedly matching references.

**Required correction:** capture consistent local data and its matching roles, image/configuration and secret references while conflicting lifecycle mutations are excluded. Use the existing coordination mechanism; release it before remote transfer/checking. Add an interrupted/concurrent capture test proving that the resulting set restores using its recorded inputs. Staggering schedules alone does not enforce this contract.

### R-04 — Bound hostile backup intake independently of the Atom

**Source:** DES-02, independently confirmed by SEC2-04. **Frozen scope:** 233, 308–312, 319, 327–331. **Priority:** Major.

Append-only clients can fill storage without deleting a retained object. Growth monitoring and a capacity ledger for legitimate traffic do not independently constrain a compromised writer. This can crowd out second-host telemetry/independent applications and create R2 storage/operation exposure. [R2 pricing](https://developers.cloudflare.com/r2/pricing/) and [bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/) describe charges and retention, not a complete admission bound.

**Required correction/decision:** enforce aggregate second-destination byte/inode allowances, including repository creation and temporary uploads, while reserving space for the host, telemetry and recovery maintenance. Verify the scope/bypass resistance of any [rest-server size control](https://github.com/restic/rest-server/blob/master/README.md). Separately define independent R2 abuse detection/revocation and either an enforceable intake boundary or explicitly accepted spending exposure. Numerical allocations need measurement. Test with hostile routine credentials; full destinations reject new intake, preserve existing sets and invoke the protection/secret-deferral policy.

### R-05 — Define whether the second Loki interface grants queries or broader authority

**Source:** parent PSEC-02, independently confirmed by SEC2-05. **Frozen scope:** 274–276, 296. **Priority:** Major.

A main-host-to-Loki port grant restricts who connects, not which API it can call. A monolithic backend can expose ingestion and control operations alongside queries. The [Loki API](https://grafana.com/docs/loki/latest/reference/loki-http-api/) documents a shutdown endpoint accepting GET and POST. Its [authentication guide](https://grafana.com/docs/loki/latest/operations/authentication/) also distinguishes tenant selection from authentication.

This is a proposed trust-boundary gap, not proof of a live second-host exposure. **Required decision:** either explicitly accept the main host's broader backend authority or define a restricted query interface separating it from ingestion/administration. A blanket GET allowance is insufficient. Validate the exact allowed principal, paths and methods with successful queries and rejected writes/control operations. Do not silently add a central ingress replica to the second server as the remedy.

## Historical Nits — corrections now applied

| ID | Raw source | Frozen line | Correction |
| --- | --- | --- | --- |
| N-01 | CMP-01 | 251 | Define authorization generation: what it identifies, who renews it after restore, and what prior requests/approvals become invalid. Storage/CLI details may wait. |
| N-02 | STY-01 | 21 | Replace the stale statement that treats the now-approved Technical Plan as future work. |
| N-03 | STY-02 | 257 | Remove or explain “native” for the custom bounded lifecycle operation. |
| N-04 | STY-03 | 388 | Distinguish Vault's documented S3 backend from unverified deployment of that backend against R2. |
| N-05 | STY-04 | 376 | Simplify the licensing paragraph without expanding its bounded conclusion or dropping capacity/privacy/delivery gates. |

## Traceability and raw reports

| Raw source | Consolidated item | Severity | Provenance |
| --- | --- | --- | --- |
| ZI-01 | R-03 | Major | [Initial zoom out](docs/reviews/2026-11-02-design-goldfish/zoom_out_report.md) |
| CMP-01 | N-01 | Nit | [Complete comprehension paraphrase and findings](docs/reviews/2026-11-02-design-goldfish/comprehension_report.md) |
| DES-01 | R-02 | Major | [Design critique](docs/reviews/2026-11-02-design-goldfish/design_critic_report.md) |
| DES-02 | R-04 | Major | [Design critique](docs/reviews/2026-11-02-design-goldfish/design_critic_report.md) |
| STY-01 | N-02 | Nit | [Style critique](docs/reviews/2026-11-02-design-goldfish/style_report.md) |
| STY-02 | N-03 | Nit | [Style critique](docs/reviews/2026-11-02-design-goldfish/style_report.md) |
| STY-03 | N-04 | Nit | [Style critique](docs/reviews/2026-11-02-design-goldfish/style_report.md) |
| STY-04 | N-05 | Nit | [Style critique](docs/reviews/2026-11-02-design-goldfish/style_report.md) |
| PSEC-01 | R-01 | Major, parent finding | [Parent source/primary-document verification](docs/reviews/2026-11-02-design-goldfish/parent_security_followup.md) |
| PSEC-02 | R-05 | Major, parent finding | [Parent source/primary-document verification](docs/reviews/2026-11-02-design-goldfish/parent_security_followup.md) |
| SEC2-01 | R-01 | Major, independent confirmation | [Dedicated security rerun](docs/reviews/2026-11-02-security-review-rerun/security_report.md) |
| SEC2-02 | R-02 | Major, independent confirmation | [Dedicated security rerun](docs/reviews/2026-11-02-security-review-rerun/security_report.md) |
| SEC2-03 | R-03 | Major, independent confirmation | [Dedicated security rerun](docs/reviews/2026-11-02-security-review-rerun/security_report.md) |
| SEC2-04 | R-04 | Major, independent confirmation | [Dedicated security rerun](docs/reviews/2026-11-02-security-review-rerun/security_report.md) |
| SEC2-05 | R-05 | Major, independent confirmation | [Dedicated security rerun](docs/reviews/2026-11-02-security-review-rerun/security_report.md) |

The [structural report](docs/reviews/2026-11-02-design-goldfish/structural_report.md) has no findings. The [final zoom-out report](docs/reviews/2026-11-02-design-goldfish/intermediate_zoom_out_report.md) adds no new IDs and reaffirms R-01–R-05 as open. Its corrections largely reuse the selected contracts/components; a restricted second-host query interface may need an explicitly selected access component. Neither another management platform nor a broad infrastructure replica was established as necessary.

The [Stage 7 aggregation](docs/reviews/2026-11-02-design-goldfish/critic_report.md), [original review progress](docs/reviews/2026-11-02-design-goldfish/review_progress.md), and [original dedicated security failure record](docs/reviews/2026-11-02-design-goldfish/security_review_status.md) preserve their separate scopes. The [completed security report](docs/reviews/2026-11-02-security-review-rerun/security_report.md), [rerun input manifest](docs/reviews/2026-11-02-security-review-rerun/input_manifest.md), and [rerun progress](docs/reviews/2026-11-02-security-review-rerun/review_progress.md) establish the later independent result. Its [frozen prior consolidated report](docs/reviews/2026-11-02-security-review-rerun/prior_consolidated_review.md) preserves the pre-rerun findings and coverage gap.

## What this review does not settle

The selected central placement, shared engines, owner-controlled CI authorization, Vault/KMS with independent rebuild exports, synchronous secret protection, local telemetry backends and split configuration methods were not demonstrated infeasible. Their accepted trade-offs are not new defects merely because another architecture is possible.

Capacity, pre-storage audit privacy, actual Pterodactyl delivery without startup changes, provider/plan permissions, protected Restic/R2 compatibility and isolated restore remain unpassed acceptance gates. The review does not supply runtime measurements, grant privileges, run backups, test recovery or implement controls. Acknowledging a gate does not establish success, but its absence was not mechanically counted as a product failure at this architecture stage.

Authorized documentation fixes and policy decisions were applied after the reviews; no production changes were made. The dedicated security architecture review covered the frozen pre-resolution design. A post-edit independent review is not claimed, and complete implementation-readiness review belongs after Detailed Implementation exists. The security rerun used safe source projections and reported no new source-output privacy incident. This does not erase earlier disclosures or prove future audit collection safe.

Two review-tool privacy incidents were disclosed: parent and final zoom-out source filters missed an authentication-clause variant and printed checked-in credential text. Further credential-bearing source output was stopped; values are omitted from reports and no credential was rotated. The [progress record](docs/reviews/2026-11-02-design-goldfish/review_progress.md) preserves this limitation. Review output must not be described as perfectly secret-free.
