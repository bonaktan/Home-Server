# Dedicated security review rerun — input manifest

* Created: 2026-11-02T09:29:57.572866+00:00
* Authorization: owner explicitly requested the security review again after the earlier run failed. This is a new run; the earlier failed run is preserved.
* Target: design_draft.reviewed.md, lines 1–484, SHA-256 927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907.
* Scope: architecture security review; Detailed Implementation is not drafted. No production changes or live tests.
* Resolve relative links in both copied documents against original repository root /mnt/Data/Projects/Infrastructure/Home-Server.
* baseline_manifest.md preserves the previous manifest; all 30 original-file hashes still match at start.
* Parent codebase-memory Tier 2 project mnt-Data-Projects-Infrastructure-Home-Server is ready at 2026-11-02T09:21:49Z. Coverage checked for design, Compose, scripts, selected nginx/Loki/Grafana and security/CI/Vault/maintenance docs. Nginx main/Pi-hole/pgAdmin parsing is unusable; direct safe source projections are necessary. Clean coverage is best effort, not completeness. No new parent call-graph conclusions.
* Fresh native reviewer must read its installed persona/standard, all required target/context, report actual hashes/read coverage, and distinguish existing consolidated items from new findings. No conversation memory.
* Source-output rule: never dump SQL, shell or Compose/environment source lines. Use strict safe structural projections only. Do not print SQL authentication clauses at all, even redacted variants; do not read secret stores, private keys or raw environments. The earlier filters missed syntax variants.

| Original context path | Lines | SHA-256 |
| --- | --- | --- |
| consolidated_review_report.md | 110 | 9ecde63aba54cb3a8d080e8b72349f009c022bc03e74f714198e8d434e444020 |
| docs/reviews/2026-11-02-design-goldfish/parent_security_followup.md | 31 | 08a554a9c815c8f28bf1268476dfdd12f91fba1d42fedf388a7ace3430b4a94c |
| docs/reviews/2026-11-02-design-goldfish/security_review_status.md | 14 | 14af361aa578be4d4da2953f8592c9646d6d5af713f98afb5b4e5ef4d2e4c8d7 |
| docs/reviews/2026-11-02-design-goldfish/zoom_out_report.md | 34 | 28db663e6a5d4fe63b0a6a8dbf68fad7089de26cf3470694032dc19361b8b675 |
| docs/reviews/2026-11-02-design-goldfish/comprehension_report.md | 60 | 9afc2cb331a0475fcffd55766ff6ed85121110f49b5a729b9ac7d82735d3da84 |
| docs/reviews/2026-11-02-design-goldfish/critic_report.md | 16 | 2e74f9b7bfbb4c8055ba0c44d83639baef04713e46284b55b421a2295149ab60 |
| docs/reviews/2026-11-02-design-goldfish/design_critic_report.md | 49 | d21eb39584362c6c881ccfa4f2581b0d078a1be9ad93f2536e0d48ea774d23c9 |
| docs/reviews/2026-11-02-design-goldfish/structural_report.md | 42 | 96c7b3da4b588878fdc2a22aca682e61a7ea9b0c10fc29ff14e15565ef4f3c2c |
| docs/reviews/2026-11-02-design-goldfish/style_report.md | 46 | 94888500af91b31c658ad63339f172cdd48471465429331987dd74e04ecf9b2d |
| docs/reviews/2026-11-02-design-goldfish/intermediate_zoom_out_report.md | 42 | 5edd31412312a336efa42556cbf866bd6a89c1d84dd385ebceb65fdbbea0c611 |

The copied prior_consolidated_review.md has SHA-256 9ecde63aba54cb3a8d080e8b72349f009c022bc03e74f714198e8d434e444020. Reports and finding descriptions are context to verify independently, not proof of implemented controls.
