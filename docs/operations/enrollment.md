# Enrollment and external scope

Status: **incomplete; do not modify or retire external paths based on this attachment alone**. Entries are observations, not authorization to execute them. Refresh them and complete the independent implementation-readiness/security review before production execution.

Read-only Atom inspection on 2026-11-02 found these paths:

| Scope | Observed files or units | Remaining evidence |
| --- | --- | --- |
| ITskolar | `/srv/ITskolar-System/.github/workflows/docker-image.yml`; `compose.yaml`, `compose.production.yaml`, `compose.staging.yaml` under that directory | Repository/workflow IDs, refs, owner ID, package access, production contract, migration history and any other deployment writers. |
| Skybridge | `/srv/Skybridge-Airways/.github/workflows/deploy.yml`; `/srv/Skybridge-Airways/compose.yaml` | Actual migration files/history, data ownership, repository IDs and deployment writers; preserve its local engine until verified transfer. |
| Runners | `actions.runner.PUP-ITskolar.bonny-server.service`; `actions.runner.RHES-Staff.bonny-server.service` | Registrations, all repositories/workflows using them and tested restricted replacement before suspension/retirement. |
| Certificates and DHCP | No exhaustive inventory yet. | Exact Certbot installation, root/user schedules, renewal hooks and credentials ownership; router configuration, leases and rollback access. |
| Provider | No provider-managed policy inventory yet. | Exact R2/KMS/GitHub policies, retention and independently administered recovery access. |

The GitHub private-repository plan, included hosted-runner allowance, spending controls, GHCR access and supported approval mechanism remain unverified. Enumerate all application repositories and legacy workflows, adopted root schedules/source files, migrations and provider policies before claiming the file-scope gate is complete. A filename alone does not establish the contents, current effect or safe replacement.
