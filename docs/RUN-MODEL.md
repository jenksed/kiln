# Run Model

**Document type:** Run subject summary  
**Decision status:** Accepted  
**Integration status:** Reconciled by Prompt 8-A  
**Implementation status:** P1-S01 integrated at `db02198` via PR #46  
**Focused lifecycle authority:** `docs/ROOT-RUN-LIFECYCLE-AND-JOURNAL.md`

## Definition

A Run is one durable, independently inspectable attempt or coordination boundary for one Task inside a Kiln Session.

A Run is Kiln's primary durable identity for:

- work coordination;
- observation;
- cancellation;
- Evidence association;
- recovery;
- bounded accounting when applicable.

A Run is not an Agent persona, model invocation, Tool call, Command, operating-system or BEAM process, branch, worktree, protocol session, conversation, or transcript.

This document summarizes the accepted model. P0-W21 controls exact first-month state, transitions, journal, restart, orphan, and completion semantics.

## First useful hierarchy

```text
Project
└── Session
    └── initial Task
        └── Root Run
```

The first useful Kiln has one active Project, one active Repository, one Session, one initial Task, and exactly one Root Run.

The initial design does not create a separate Root Task. The initial Task states the accepted desired outcome and criteria. The Root Run attempts or coordinates it.

## Task and Run

A Task states a desired outcome. A Run attempts or coordinates it.

A completed Run does not satisfy its Task through status alone. First-month satisfaction occurs only through the atomic completion transaction that binds:

- the accepted objective and criteria revision;
- exact current Repository state when applicable;
- current passing Evidence;
- no unresolved external operation or unknown effect;
- required user acceptance;
- the current aggregate proof reference.

## Identity

Kiln generates `run_id`.

Run identity must not use:

- role, Agent, model, or provider name;
- provider request ID;
- Tool, Command, Worker, process, Port, or Task runtime handle;
- branch, commit, worktree, or checkout path;
- client, protocol thread, or transcript position.

Run identity survives Worker, process, provider, client, adapter, and application restart.

## Root Run

Each first-month Session has exactly one Root Run.

The Root Run:

- has no Parent Run;
- references the initial Task;
- owns the primary work-control projection;
- can advance accepted deterministic workflow actions;
- can later investigate, propose, apply an authorized Patch, execute registered verification, and request final acceptance when those subsystems are authorized;
- remains subject to Project policy, explicit authority, user Approval, Evidence gates, and completion rules.

Root is a relationship role and invariant. It does not require a separate entity type, supervisor, or long-lived process.

## First-month persisted states

The first-month Root Run states are exactly:

```text
ready
running
waiting_for_user
orphaned
completed
failed
canceled
```

### `ready`

Kiln can accept the next valid application action. No external operation or unresolved pending decision blocks progress.

### `running`

Kiln is advancing one accepted action or owns one nonterminal external-operation intent.

This does not identify a process. A transient Worker can own the live Resource.

### `waiting_for_user`

One durable pending decision exists with an exact subject, revision, permitted responses, requested actor, and resume action.

### `orphaned`

Kiln cannot prove the terminal result or effect of a material external operation.

It cannot become complete through a summary, timeout, process death, or user assertion. Explicit reconciliation is required.

### Terminal states

`completed`, `failed`, and `canceled` are terminal for the first-month one-attempt Run.

- `completed` requires the atomic accepted completion transaction.
- `failed` requires known effects and no unresolved unknown.
- `canceled` requires authorized cancellation and known or reconciled effects.

## Separate state dimensions

Do not encode these as first-month Run states:

- workflow step;
- pending decision type;
- provider, Patch, or Command operation state;
- Tool activity;
- verification activity;
- Evidence freshness or contradiction;
- recovery action;
- Child activity.

Specifically, do not add `created`, `waiting_for_command`, `verifying`, `stale`, `reconciling`, `waiting_for_child`, or `waiting_for_permission` to the first-month Run status.

The accepted workflow steps are:

```text
intent
investigation
proposal
approval
application
verification
acceptance
reconciliation
```

The accepted external-operation states are:

```text
intent_recorded
started
succeeded
failed
canceled
unknown
```

## Durable Run record

A Root Run owns or references only the current facts required for work and recovery, including:

- Run, Session, and Task identity;
- status and workflow step;
- accepted objective and criteria revisions;
- pending user decision;
- external-operation records;
- policy and authority references;
- Context, provider, Tool, Patch, Command, Artifact, and Evidence references when those subsystems are authorized;
- warnings, unknowns, cancellation, and recovery state;
- final completion reference.

It does not own complete Artifact payloads, hidden model reasoning, provider-native prompt state, branch or worktree identity, or client-local UI state.

## Transcript relationship

Conversation messages are ordered interaction records associated with a Run.

They do not own objective, criteria, authority, mutation, Evidence, recovery, or completion state.

Kiln restores current truth from the journal, projections, and exact Repository observations. It does not ask a model to reconstruct state from a transcript summary.

## Runtime ownership

Run lineage and OTP supervision are separate.

A Run is durable data and does not receive a dedicated process merely because it is active.

A process is justified only when it owns a live Resource, concurrency, timing, cancellation, streaming, external communication, or fault isolation.

The first implementation can use pure domain modules plus the supervised store boundary. Later authorized work can add transient provider, mutation, and Command Workers.

There is no first-month `RunSupervisor`, permanent Root Run process, Session process, Task process, Capability broker process, Evidence process, Receipt process, or event-publisher process.

## Operations

### Model invocation

One provider request and response stream owned by a Run. It receives an immutable Context package and fixed Tool projection. It cannot complete a Run.

### Tool call

One bounded Kiln-native operation. A Tool call is not a Child Run.

### Patch application

One explicit external operation bound to exact Patch, Approval, base state, rollback data, and idempotency identity.

### Command

One registered external-process operation. A transient Worker and macOS helper can own its process group, timeout, cancellation, output capture, and cleanup.

None of these operation types redefine Run identity or status.

## Child Runs

Child Runs are not part of the authorized first-month implementation.

Wave B may later plan one depth-one read-only Scout and one independent Verifier, with maximum one active Child, no writing Child, no nested delegation, no peer communication, and no shared mutable Context.

Those limits are planning constraints only until P0-W26, P0-W27, Prompt 6-B, Prompt 7-B, and Prompt 8-B complete after accepted Single-Run runtime Evidence exists.

## Completion

A model result, successful Command, favorable summary, current Receipt, or Run status alone cannot create completion.

P0-W24 evaluates criterion Evidence and aggregate readiness. The user accepts the exact current evaluation. P0-W21 then atomically aligns Run, Task, Session, acceptance, and proof reference.

A product Receipt is sealed after that transaction and has no authority.

## Current authorization

P1-S01 was executed as T01 → T02 → T03 → T06 → T04 → T05 and integrated at `db02198` via PR #46. See `docs/work/P1-S01-T01-domain-foundation.md`, `docs/work/P1-S01-T02-durable-store.md`, `docs/work/P1-S01-T03-replay-projections.md`, `docs/work/P1-S01-T06-workflow-surface.md`, `docs/work/P1-S01-T04-foundation-cli.md`, `docs/work/P1-S01-T05-slice-gate.md`, and `docs/work/P1-S01-slice-closeout.md`.

Those tickets implemented domain identifiers and states, the durable store, deterministic replay and projections, the shared Workflow application boundary, the minimum foundation CLI, and the P1-S01 aggregate gate and slice verification manifest. PR #48 was rejected, closed, and unmerged. P1-S02-T01 is boundedly authorized and not yet implemented; P1-S02-T02 and later remain unauthorized, and P1-S02 is not authorized as an aggregate slice.

They may not implement MiniMax, Repository source reads, Patch mutation, external Commands, criterion completion Evidence, product Receipt sealing, release packaging, Child Runs, TUI, or Wave B work.
