# CI authorization semantics for the Technical Plan

* **Date:** 2026-11-02
* **State:** D-04's authorization rule and D-25's whole-revision interpretation are owner-confirmed. D-26 selects restricted OpenSSH over Tailscale plus GHCR and the private approval workflow in the [deployment design](ci-deployment.md).
* **Context:** [Approved brief](../../concepts_brief.md), [design draft](../../design_draft.md), and [existing deployment evidence](../investigations/2026-11-01-database-connectivity.md).

## Confirmed boundary

Build images on standard GitHub-hosted VMs. Production deployment to the Atom requires either the owner's explicit approval or a triggering event initiated by the owner. Collaborators may push/build but must not obtain an alternate production-control path before authorization. Automatic compatible central-image maintenance remains separately authorized by D-08; it does not approve a new external application artifact.

The GitHub connector identifies its authenticated account as `bonaktan`, numeric ID `128207489`. This provides a candidate owner identity for the allowlist; it does not independently verify private-organization permissions, billing plan, repository IDs, protected refs, or current workflow controls. Preserve numeric platform identity rather than using commit-author text or a caller-supplied username as proof.

ITskolar-System is private, confirmed by the owner. GitHub documents required environment reviewers as public-repository-only on Free, Pro, and Team plans. Its actual plan remains unverified, so the design must not require that private-repository feature. Use an owner-initiated authorization action with independently verified platform metadata where native review is unavailable. See [GitHub deployment protection rules](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

## Owner-confirmed whole-revision authorization

An owner-initiated push or rerun can include commits written by collaborators. The owner confirms that their action authorizes the entire selected source revision and its build result for the intended production target, including collaborator-written commits. Authorization still binds to the exact source, build attempt, and resolved artifact that deployment uses.

This is D-25, confirmed on 2026-11-02. Do not infer authorization by inspecting commit authors: authorship and the owner's platform action are different evidence. A collaborator initiating a new attempt does not become the owner merely because the original attempt was owner-initiated.

## Proposed event treatment

The following matrix carries the confirmed interpretation into proposed enforcement rules; it is not a claim that the existing workflows enforce them. Every eligible row also requires an explicitly enrolled repository, production ref/target, successful required checks, and a bound artifact. Unknown origins or missing metadata remain ineligible.

| Event | Proposed production treatment |
| --- | --- |
| Owner initiates an eligible production push/run | Authorize the complete selected revision and its exact verified build output; no second approval is required solely because some included code was written by collaborators. |
| Collaborator initiates a run | Build/check in isolation if allowed, then wait for the owner's explicit authorization of the exact revision/build/artifact. |
| Owner initiates a rerun of a collaborator's run | Treat the owner's current rerun action as authorization under D-25, with current attempt/artifact binding and successful checks. |
| Collaborator reruns an originally owner-initiated run | Do not grant new production authorization from the original actor alone. Require owner authorization for the applicable attempt/artifact; do not reuse a consumed request to trigger another deployment or rollback. |
| Owner explicitly authorizes an already-built artifact | Bind that owner action to the referenced source/build tuple and digest. Do not rebuild different bytes or resolve a moving tag under the same approval. |
| Bot, scheduled, or chained workflow requests application deployment | Require a verified chain to an eligible owner action or exact explicit owner approval. A workflow/bot label or claimed upstream actor is insufficient. |
| Cancelled, expired, replayed, or identity/artifact-mismatched request | Reject or report the precise pending/unknown state. A retry may query/reconcile the same operation; it must not substitute a newer revision or repeat a completed mutation silently. |

GitHub distinguishes the initial `actor` from the actor initiating a rerun, and reruns retain the original actor's privileges. Therefore, a workflow condition checking the initial actor is insufficient for this owner policy. Verify platform run/attempt metadata outside caller-controlled payload fields. See [GitHub contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts), [rerun behavior](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs), and [workflow-run/attempt API](https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run-attempt).

## Binding and enforcement requirements

The production-side decision must retain repository and workflow identity, source revision, build run/attempt and successful job references, artifact identity/digest, production target, the owner-origin or explicit-approval record, request identity, current authorization generation and observed result. A partial rerun can reuse a prior build output: record the actual build origin separately from the current authorizing action instead of inventing a new build or accepting unbound outputs.

The authorization generation is an admin-managed per-host deployment epoch. Bind requests and explicit approvals to the current epoch. After restoring older host state, the ops admin reconciles actual deployment state and renews the epoch before resuming execution; unconsumed requests/approvals from older epochs are rejected, while completed records remain history. A prior build may be selected by a newly authorized current-epoch operation. Exact representation and interface follow in Detailed Implementation.

Retrieve and validate actual GitHub metadata through an identity with the required read access. A request body, image label, workflow environment variable, or commit message cannot prove its own authorization. Resolve/download the selected artifact once, verify its identity, and use that fixed digest; GHCR documents [pulling by digest](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#pull-by-digest). GHCR is selected in D-26; actual artifact binding and access remain to be tested.

The eventual transport must preserve the following boundaries:

* Build/dependency/Dockerfile code receives no production Docker socket, runtime secrets, or general home-network access. Publishing an application image is distinct from applying it.
* Production authority must not depend solely on a YAML conditional that a collaborator can change. Do not expose a broadly privileged deployment key as an application-repository secret and assume a later approval job prevents earlier use.
* Host-controlled, reviewed deployment configuration defines services, networks, mounts, privilege, and allowed operations. A deployment request supplies bounded identifiers, not arbitrary shell commands or a replacement privileged Compose file from an application build.
* Old production runner registrations and other competing deployment paths must be retired/restricted during cutover. A new secure path does not remove the old workflow's authority by itself.
* Application deployment, manual secret activation, the central updater and recovery capture share lifecycle coordination. Preserve active inputs and artifact identity, and capture matching data/references before remote transfer. An unavailable authorization API, registry or required input defers the operation while preserving the running deployment.
* Logs and GitHub feedback distinguish request publication, authorization, actual replacement, readiness, failure, and recovery. Do not report deployment success merely because an image/request was uploaded.

## Evidence to obtain before implementation

Inventory actual organization/repository IDs, plans/compute usage, production refs, workflow/edit permissions, existing runner assignment, image/package access, and the selected feedback/approval mechanism. The connector's prior private-repository 404 does not override the owner's visibility confirmation. The org plans have not been inferred from account identity.

Test owner/collaborator first runs and reruns, including the original-owner/current-collaborator case, a forged owner field, a chained workflow with missing origin, a substituted image tag/artifact, partial rerun output reuse, a replay after completion, and an unavailable verification API. Exercise permitted and denied requests before granting real production control. These are future acceptance cases; no deployment or permission change was made during this research.

Whole-revision authorization and the deployment profile are settled. D-26 selects restricted OpenSSH submission over Tailscale, with GHCR and the private owner-controlled approval workflow. Finalize its credentials, files, and validation in [the deployment design](ci-deployment.md) and formal Technical Plan. Do not add a second-server CI installation or paid build overages as an implicit fallback.
