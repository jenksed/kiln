# Session Model

**Document type:** Reference  
**Status:** Foundational direction  
**Internal-domain authority:** `docs/INTERNAL-DOMAIN-MODEL.md`

A Session is one durable attempt to move one accepted Project objective toward verified completion.

Each Session owns:

- one accepted objective and completion contract;
- one primary Repository and selected Environment snapshot;
- one set of Tasks;
- exactly one Root Run;
- one durable Run graph;
- one event sequence;
- one policy snapshot;
- final reconciliation and outcome.

## Session, Task, and Run

```text
Project
└── Session: one objective and complete work history
    ├── Task: bounded desired outcome
    │   ├── Run: first attempt
    │   └── Run: later attempt
    └── Root Task
        └── Root Run: main execution and Steward control context
```

The Session is the objective boundary.

A Task states what must be done.

A Run is one durable execution or coordination attempt for one Task.

A completed Run does not automatically satisfy its Task. Task satisfaction depends on accepted criteria and current Evidence.

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

These are work-state concepts. They are not separate Agent personas, mandatory model turns, or external protocol states.

## Session identity and ownership

A Session has a Kiln-generated `session_id`.

A provider conversation ID, client thread ID, terminal ID, external task ID, or protocol session ID must not become the Session identity.

The Project owns the Session.

The Session owns Tasks, Runs, attention, Checkpoints, and final reconciliation. It references Project-owned policies and Repository memberships through an immutable policy snapshot.

## Session state

A Session should eventually track:

- Project identity;
- user intent and accepted objective revision;
- completion-contract revisions;
- accepted specifications and exclusions;
- primary and secondary Repository identities;
- selected Environment identity and fingerprint;
- Repository trust and Privacy policy versions;
- Git branch, commit, dirty state, and Repository fingerprints;
- orientation facts and freshness;
- Task identities, dependencies, criteria, and satisfaction status;
- Root Run identity;
- Run graph and Run projections;
- Context manifests;
- Agent bindings and model invocations;
- Tool calls, Commands, and Terminals;
- Capability requests, Approvals, grants, revocations, and effective authority;
- Attention requests;
- observed file mutations and Change sets;
- Artifacts, Claims, Evidence, and Receipts;
- delivery traceability;
- failures, warnings, unresolved findings, risks, and unknowns;
- Checkpoints;
- interruption and recovery state;
- completion Claims, readiness, and final acceptance.

## Session lifecycle

The Session lifecycle is:

```text
created
→ active
→ interrupted | paused | reconciling
→ active | completed | abandoned
→ archived
```

A Session status is a durable event-derived projection.

A Session can be `completed` only after the completion contract is satisfied and the required final acceptance occurs.

A Session can be `abandoned` without deleting its history.

## Task model

A Task is one bounded desired outcome, investigation, decision, verification target, or reconciliation action.

A Task must record:

- `task_id`;
- Session identity;
- accepted statement revision;
- acceptance criteria;
- constraints and exclusions;
- dependencies;
- priority;
- status;
- related Runs;
- satisfaction or rejection reason.

Task status is:

```text
proposed
accepted
ready
blocked
in_progress
satisfied
rejected
abandoned
superseded
```

Task status is not Run status.

One Task can have:

- a failed Run followed by a later Run;
- competing read-only Runs;
- one implementation Run and one verification Run;
- no Run when deterministic inspection satisfies it directly and the action remains recorded.

When an action requires independent inspection, interruption, permission scope, Context, Evidence, measurement, or recovery, it must be represented by a Run.

## Root Task and Root Run

The Session should create one root Task that represents the accepted objective or its first executable contract.

The Session must contain exactly one Root Run.

The Root Run:

- references the root Task;
- has no Parent Run;
- references itself as `root_run_id`;
- carries Project Steward responsibility by default;
- maintains the main control context;
- can execute work directly;
- can create or coordinate bounded Child Runs;
- receives structured Child Run results;
- coordinates attention and reconciliation;
- remains subject to Session policy, Capability grants, and completion gates.

Replacing a failed Root Run process must not create a second Root Run identity.

## Run graph

A Session owns one durable acyclic Run graph.

```text
Root Run
├── Child Run
├── Child Run
│   └── Child Run
└── Child Run
```

Every Run in the graph must:

- belong to this Session;
- reference one Task in this Session;
- reference the Session Root Run;
- reference zero or one Parent Run;
- remain identifiable across Worker and process restart.

The graph records work lineage. It does not define OTP supervision.

## Project Steward projection

The Session maintains a Project Steward projection derived from current Session, Task, Run, policy, Repository, and Evidence events.

The projection should include:

- active objective and completion contract;
- governing requirements, decisions, and exclusions;
- Task graph and satisfaction status;
- active, queued, blocked, interrupted, and completed Runs;
- unresolved attention;
- current Capability and policy constraints;
- Context and active Project instruction revision;
- known mutations, Change sets, and Artifacts;
- Claims and Evidence status;
- stale Evidence;
- failures and warnings;
- unresolved risks and unknowns;
- recommended next action;
- completion readiness.

The Steward projection is not the source of Repository truth, policy truth, or Evidence truth.

## Event journal

The durable record is append-oriented.

Candidate Session events include:

```text
SessionCreated
ObjectiveRevisionAccepted
CompletionContractRevisionAccepted
RepositoryBound
EnvironmentSelected
PolicySnapshotRecorded
OrientationCaptured
RepositoryFingerprintCaptured
CheckpointCreated
SessionInterrupted
SessionPaused
SessionResumed
ReconciliationRequested
CompletionClaimed
CompletionAccepted
CompletionRejected
SessionAbandoned
SessionArchived
```

Candidate Task events include:

```text
TaskProposed
TaskAccepted
TaskDependencyAdded
TaskReady
TaskBlocked
TaskStarted
TaskSatisfied
TaskRejected
TaskAbandoned
TaskSuperseded
```

Candidate Run events are defined by `docs/RUN-MODEL.md` and the internal-domain contracts.

Not every streamed token requires a durable event. Event granularity must support reconstruction, causation, audit, and correct terminal state without meaningless volume.

## Attention

The Session owns a depth-independent attention index derived from Run and policy events.

An unresolved Attention request must identify:

- request identity;
- requesting Run or deterministic service;
- Parent Run when present;
- type;
- urgency;
- summary;
- required response schema;
- creation time;
- blocking status;
- actor authority required to resolve it.

The user must be able to resolve attention without manually navigating every Parent Run.

A pending Approval is an Attention request. The immutable Approval decision remains separate.

## Client state

A Client can focus any Run in the Session when it has read authority.

Client focus is not Session state.

Two Clients can view different Runs without changing execution or each other's focus.

A Client can persist navigation state as convenience data, but this state must remain separate from the canonical Session and Run journal.

## Context and instruction authority

The Session records the accepted active-Project instruction revision.

Each Run receives an immutable Context manifest.

A Context manifest can include content from active and reference Repositories. Each item must retain provenance, trust class, sensitivity, digest, inclusion reason, and transformation history.

Reference-only content cannot:

- issue instructions;
- change the Session objective;
- change policy;
- grant authority;
- alter product direction;
- become active instruction without explicit user acceptance.

## Recovery rule

OTP restores runtime structure. The event journal, policies, Artifacts, and current Repository and Environment observations restore known Session state.

Recovery must never transform an interrupted, orphaned, failed, or unknown operation into a successful one.

After restart, Kiln must reconstruct:

- Session identity and accepted revisions;
- policy snapshot;
- Task graph and last durable Task statuses;
- Root Run identity;
- Parent-Child Run relationships;
- last durable Run statuses;
- expired Worker leases and orphaned executions;
- unresolved attention and Approvals;
- Artifacts, Change sets, Claims, Evidence, and Receipts;
- Repository and Environment observations;
- the last durable Steward projection;
- the latest Checkpoint.

A replacement Worker or Steward process must not duplicate active Child work, repeat a mutation, or repeat an external effect without an idempotency decision.

## Completion rule

A model response is a Claim.

A Run result is not automatic Task satisfaction.

A Task is satisfied only when its accepted criteria and required Evidence are satisfied.

The Project Steward can recommend Session completion. It cannot make Evidence current through narrative.

Session completion requires:

- satisfied required Tasks and acceptance criteria;
- current required Evidence;
- disclosed failures and warnings;
- Repository state that matches the completion report;
- stated unknowns and exclusions;
- no unresolved blocking Attention request;
- a final Receipt that references the relevant Evidence and state;
- final user acceptance when required.
