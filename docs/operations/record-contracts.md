# Operation record contracts

Status: design for implementation and review, not evidence that any control is deployed. Records contain metadata and references only: never secret values, request bodies, unrestricted arguments, environments or credentials. The installed, root-owned catalog defines enrolled identifiers and canonical paths; request data cannot extend it or select shell commands, Compose files, mounts or privileged paths.

## Common operation

A durable operation binds a unique operation ID and kind, host and enrolled service, request origin and authorization evidence references, current host epoch where applicable, expected prior state, canonical configuration identity, selected image digest and platform, explicitly active secret references, and request, observation and result times. Fields that do not apply to a kind are explicitly absent rather than guessed. The verifier must reject malformed, oversized, out-of-scope or inconsistent records before privileged use. Identifiers, field lengths, allowed characters and the concrete serialization must be fixed and tested with each implementation, not accepted as arbitrary strings.

State transitions are `received → verified → prepared → applying → observed completion`, with `rejected`, `deferred`, `failed` and `uncertain` outcomes carrying safe reasons. Acceptance into a queue is not authorization or readiness. Record the intended mutation durably before applying it; record completion only after actual state and readiness have been observed. Repeated submission of the same identity must not repeat a completed mutation or silently supersede newer state. Conflicting expected prior state defers or rejects the operation.

A crash, lost response or released lock is not proof of success or failure. Reconciliation inspects durable intent and actual service/backend state before another mutation; ambiguous results remain uncertain until resolved. Incoming files are adopted without following links and checked for type, ownership, length and scope before privileged processing. Implement durable replacement with file and directory persistence appropriate to the filesystem, and test interruption and power loss at each boundary. Exact wire format, finite limits and retention must be reviewed before deployment; do not interpret this document as a finished parser.

## Deployment and maintenance

A deployment record additionally binds the enrolled repository, workflow, production ref, source revision, build run and attempt, artifact identity and digest/platform, initiator and authoritative approval evidence, target service and epoch. The home verifier retrieves authoritative evidence rather than trusting submitted owner fields. A collaborator rerun does not inherit an earlier owner's authorization. Explicit approval binds the source/build origin attempt, digest, target and current epoch. An unavailable or unverifiable authorization or registry input defers deployment.

After an older host state is restored, suspend automatic execution, reconcile actual deployments, then renew the admin-managed host epoch. Reject unconsumed requests and approvals from earlier epochs; completed records remain history. A prior build may be selected through a new authorization in the current epoch.

Maintenance records bind the observed current and candidate digests, discovery source and observation time, classification, policy and reason. Failed or stale scans cannot resolve a known pending update. Unknown compatibility defers. External and Pterodactyl applications and the backup-storage service remain alert/manual; second-host automatic maintenance is limited to enrolled observability services. Lifecycle operations use the same explicitly active inputs and expected prior state regardless of origin.

## Publication, activation and capture

A secret publication binds a stable operation ID and predecessor, encrypted complete candidate digest, both protected locations, staged serving reference and matching complete receipt dependencies. Verify retrieved candidate and receipts at both destinations and the staged serving copy before acknowledging a protected pending version. A successful local write or an ambiguous upload response does not satisfy this condition. Retry and reconcile under the same identity; do not infer absence from a transient negative read after an ambiguous upload.

Activation is a separate manual operation. Protect intent and compatible references before changing backend credentials or delivery; record observed consumer validation and protected active state before safe revocation. Pending is never implicitly active, including on image recreation. An interrupted activation remains explicit and reconciled; never revoke the only known working credential on an uncertain restart. Both destinations and the other publication prerequisites must be available for acknowledgment.

Capture shares the host lifecycle coordination boundary with deployments, schema/configuration and credential changes. Under the lock, capture consistent enrolled data and finalize a manifest binding the data point to roles/grants, migration history, image/configuration and active secret references. Apply supported database snapshots and workload quiescence: the lock alone cannot make live files consistent. Release coordination before transfer and verification. Track independently verified recoverable points and freshness per destination and data class; an upload or repository check alone is not a tested application restore.

## Retention and evidence

Retain operation and reconciliation history long enough for audit and recovery, including completed records across epoch renewal. Exact retention, rotation, disk reserves and storage location remain subject to the measured capacity and 30-day searchable audit gates. Preserve a last validated compatible recovery set and dependencies through downtime. Backup failure produces persistent degraded/freshness state while services continue running; it never waives the two-destination secret acknowledgment prerequisite. Advisory size observations retain source timestamps and stale/unknown state and do not enforce upload limits.

Implementation acceptance requires disposable fault-injection tests for input and authorization boundaries, replay and epoch invalidation, interrupted state transitions, active/pending isolation and capture coordination, plus inspection of every retained representation for harmless secret markers. See the [design](../designs/home-server-refactor.md) for the complete gates and accepted recovery exceptions.
