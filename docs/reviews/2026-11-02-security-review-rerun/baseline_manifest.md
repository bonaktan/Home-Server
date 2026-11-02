# Current-design Goldfish review: frozen input manifest

* Created: 2026-11-02T07:16:37.166025+00:00
* Original target: /mnt/Data/Projects/Infrastructure/Home-Server/design_draft.md
* Frozen snapshot: /mnt/Data/Projects/Infrastructure/Home-Server/docs/reviews/2026-11-02-design-goldfish/design_draft.reviewed.md
* Target SHA-256: 927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907
* FeatureRange: 1–484; DetailedRange: N/A (not drafted).
* Scope: initial zoom out, comprehension, design/structure/style critique, explicit security critique, intermediate zoom out. Read-only, one review pass; no automatic remediation or convergence claim. Implementation-readiness is not run.
* Resolve relative links in the frozen snapshot against the original repository root, not this snapshot directory. Read the target and referenced local documents; use external primary documentation to verify material current-product claims as needed.
* Fresh reviewers receive no conversation history or parent analysis. Historical linked review reports are provenance, not a review of this current target.

| Original repository path | Lines | SHA-256 |
| --- | --- | --- |
| design_draft.md | 484 | 927061d6f09cef1a94a8ab1bd79f3aa61f3f29cf1f09f9ea5a1cd210b9aff907 |
| concepts_brief.md | 606 | 8f887d6407d4b58cbf306c678ebc2959d7d12f978fd5b121800a2cbe926a40de |
| README.md | 34 | 1f34056925dfdf8ffef55a8f2ad98d3e385284f84983eec1c4966b1b4c416bca |
| System_Documentation.md | 319 | ced0f58470ff265cde70dda780b03b3f70140f888be00ab22139d79e8942cff7 |
| Hardware_Info.md | 62 | 822a92974fdfcf0b24c9053eeb42552e55ec7dfe0be1ea678499573ff62bb244 |
| new_server_hardware.md | 145 | 9ec0b0651d35b56accf26a9d6622d5799b1dc4d75426b62a5027357a17f4bdd5 |
| docs/designs/database-boundaries.md | 62 | c02af10750e8d8d82b6300932daec9aa13dbcc533b2e60033bae85b628df3ede |
| docs/designs/secrets-publication.md | 111 | 080e27d0e542c045394e0aa4be19a13432622a5baf260dd179c2c09d94f456ac |
| docs/designs/vault-operations.md | 75 | eb8122e3fd0c7b0f5a8739a6d2bd129eda98c79a96bcc64f11a6f4b185d02e54 |
| docs/designs/ci-authorization.md | 58 | 7432fb7fc56a1549ce974c465149eefe61a73d08d8ba7ce26c83fee26fc2df69 |
| docs/designs/ci-deployment.md | 77 | 23e5292e26bba9953bf6dc6b79c151d21f4b0b599a88ca9aaaf106c57931b8b4 |
| docs/designs/maintenance-policy.md | 66 | e110efa9259c7a78eaf2010e6f373fdff95b058e01f9f4756bc5cc4b4a1513ed |
| docs/designs/operations-tooling.md | 75 | 98cf44658e6fbac2e0d2dd2a01005158fc6bead6de1385cba6e087a22d7fc6e1 |
| docs/designs/security-considerations.md | 34 | ec3896f70889b49755faf390c979e1e408e37a57f6b7d2a150e5e3996ab0660b |
| docs/investigations/2026-11-01-database-connectivity.md | 88 | 36e0680d86169d9fcc9dff59f09cc192e3833f5bc1abbd2e7534a5b36fbd6663 |
| docs/investigations/2026-11-01-debian-host-baseline.md | 88 | 50bddb14de3b0e7892d0b16ee97e561860eab7109f1002448749f128ec3bdc38 |
| goldfish_review_report.md | 154 | ad0f37f1e5af5add3b03e51030bb739e9cdc8ffec7988d7b9b3b9d220554923b |
| docs/reviews/2026-11-02-goldfish-raw-findings.md | 411 | e2680530a0d8ab0d2bea8271f4d7b4302c717d37a96bc5ec673e47f9cf9a49ae |
| setup.sh | 212 | 89c0865136a73fd517e550efd5730ac2df95be48797d711ac0f6fdad577a9925 |
| new_setup.sh | 202 | a2d3317e853490fbcaca2b886e15721c9537ca6a468970226b7d2cfad88c02dc |
| compose.yaml | 619 | bc69d9edc9306e7bdc3b088a7f808b79b8366207b044f64751c2dd342f6f93b8 |
| compose.production.yaml | 13 | 37a231fb8f5c06e4fe2a82d5e3c37e543b9d2e9f0904e2c7f6815c5f7aa46451 |
| compose.staging.yaml | 28 | a7a99de15855e20213a999bbe5bc9e5c03dd166d8ed83a9cccd30d66a5202bfa |
| infra/prometheus/prometheus.yml | 15 | 78f0bb5288bff75d40360df71e26fa8ec352d8a3cd8dedf430150429e5306800 |
| infra/loki/loki-config.yml | 55 | 3690dfb3f994bd039bae8ab96e7c01f80bcbe824f856c58ed27f0ff9bf9d4411 |
| infra/promtail/promtail-config.yml | 30 | 21f1f382a347b29eeee786fc81eb111ae5ab28e2756e77829dd891973b0a0b33 |
| infra/nginx/conf.d/pihole.conf | 37 | e25e8c6164d6a8c3a623ad3434b543016f024649227ab87650c8cef6d6cc777c |
| infra/nginx/nginx.conf | 106 | 10284f68b021bfd82d3f5dde64d5956afcb4e361eac856a8b1c123258eeb5f36 |
| infra/migration/postgresql/V1__ITskolarSystem-Skybridge.sql | 437 | 67de19b4c1a57f13f8b8afa891c0f990681a563b38ba13fac5f784e0b948b5bb |
| infra/migration/mariadb/V1__Pterodactyl.sql | 3 | e1885654a573fe6aa6b1961006881ecf6fb279becfa33ad5d01fad3368785e7d |

## Graph verification context

Tier 2. Project mnt-Data-Projects-Infrastructure-Home-Server, ready at generation 2026-11-02T06:57:29Z. Exact-path coverage was checked for target, supporting designs/evidence/hardware, scripts, Compose and selected configs. No recorded issue is best effort, not completeness. Nginx parsing is unusable; read relevant source directly. PostgreSQL SQL coverage misses lines 15/153; MariaDB misses 1/3; direct bounded reads are required if relying on these paths. Other checked paths report metadata_match/no_recorded_issue. A bounded Function search returned setup.log, traced both ways to one setup caller and no callees; its snippet is only a logging helper. This is not exhaustive coverage of shell logic. Remote /srv and host runtime are outside the graph.
