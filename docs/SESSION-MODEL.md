# Session model

**Document type:** Reference  
**Status:** Foundational direction

A session is one durable attempt to move a repository objective toward verified completion.

Each session owns one root run and one durable run graph.

## Conceptual phases

```text
Intent
  → Orientation
  → Investigation
  → Change
  → Verification
  → Reconciliation
  → Completion
```

These are runtime concepts. They are not separate agents or mandatory model turns.

## Session and run relationship

```text
Session
├── objective and completion contract
├── repository and policy state
├── event sequence
└── run graph
    └── root run: Project Steward responsibility
        ├── child run
        └── child run
```

The session is the objective boundary.

The run is the independently inspectable execution boundary.

The root run is the main control context and carries Project Steward responsibility by default.

## Session state

A session should eventually track:

- user intent and completion contract;
- accepted specifications and exclusions;
- workspace path and repository identity;
- Git branch, commit, and dirty state;
- repository fingerprints;
- orientation facts and freshness;
- root run identifier;
- run graph and run projections;
- provider and model requests;
- tool requests and executions;
- capability decisions;
- attention items;
- observed file mutations;
- verification evidence;
- delivery traceability;
- unresolved findings and risks;
- checkpoints;
- interruption and recovery state;
- completion claims and acceptance.

## Root run

A session must contain exactly one root run.

The root run:

- receives the session objective;
- maintains the active control context;
- carries Project Steward responsibility;
- can execute work directly;
- can create bounded child runs;
- receives structured child results;
- coordinates attention and reconciliation;
- remains subject to session policy and completion gates.

Replacing a failed root-run process must not create a second root-run identity.

## Child runs

A session may contain child runs when work requires independent inspection, steering, cancellation, evidence, or recovery.

A child run must identify:

- its parent run;
- its root run;
- its bounded task;
- its capability profile;
- its resource limits;
- its expected result structure;
- its completion or return condition.

The child relationship records work lineage. It does not imply OTP supervision.

## Project Steward projection

The session should maintain a Project Steward projection derived from current session and run events.

The projection should include:

- active objective;
- current completion contract;
- governing requirements and decisions;
- active, queued, blocked, and completed runs;
- unresolved attention;
- known mutations and artifacts;
- verification status;
- stale evidence;
- failures and warnings;
- unresolved unknowns;
- recommended next action;
- completion readiness.

The projection is not the source of repository or evidence truth.

## Event journal

The durable record should be append-oriented.

### Session events

Candidate session events include:

- `SessionStarted`
- `IntentRecorded`
- `CompletionContractRecorded`
- `WorkspaceOpened`
- `OrientationCaptured`
- `RepositoryFingerprintCaptured`
- `CheckpointCreated`
- `SessionInterrupted`
- `SessionResumed`
- `ReconciliationRequested`
- `CompletionClaimed`
- `CompletionAccepted`
- `CompletionRejected`
- `SessionClosed`

### Run events

Candidate run events include:

- `RunCreated`
- `RunStarted`
- `RunStatusChanged`
- `RunOutputAppended`
- `ChildRunCreated`
- `ModelRequestStarted`
- `ToolRequested`
- `CapabilityGranted`
- `ToolExecutionStarted`
- `ToolExecutionCompleted`
- `AttentionRequired`
- `AttentionResolved`
- `ArtifactCreated`
- `FileMutationObserved`
- `VerificationCompleted`
- `EvidenceRecorded`
- `EvidenceInvalidated`
- `RunCompleted`
- `RunFailed`
- `RunCanceled`
- `RunOrphaned`

Not every streamed token needs its own durable event. Event granularity must support reconstruction without producing meaningless volume.

## Attention

The session owns a depth-independent attention index derived from run events.

An unresolved attention item must identify:

- the requesting run;
- its parent run when present;
- type;
- urgency;
- summary;
- required response shape;
- creation time;
- blocking status.

The user must be able to resolve an attention item without manually navigating every parent in the run graph.

## Client state

A client can focus any run in the session.

Client focus is not session-wide state.

Two clients may view different runs without changing execution or each other's focus.

A client may persist its own navigation state, but that state must remain separate from the canonical session and run journal.

## Recovery rule

OTP restores runtime structure. The event journal and repository observations restore known session and run state.

Recovery must never transform an interrupted, orphaned, or unknown operation into a successful one.

After restart, Kiln must reconstruct:

- the root run identity;
- parent-child run relationships;
- last durable run statuses;
- unresolved attention;
- artifacts and evidence;
- interrupted executions;
- the last durable Project Steward projection.

A replacement Steward run must not duplicate active child work without an explicit idempotency decision.

## Completion rule

A model response is a claim.

The Project Steward can recommend completion. The Steward cannot define evidence as current through narrative.

Completion requires:

- satisfied acceptance criteria;
- current required evidence;
- disclosed failures and warnings;
- repository state that matches the completion report;
- stated unknowns and exclusions;
- no unresolved blocking attention item;
- final user acceptance when required.
