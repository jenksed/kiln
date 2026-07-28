# Run Model

**Document type:** Reference  
**Status:** Foundational direction

A run is one independently inspectable unit of work inside a Kiln session.

A session owns one repository objective. A run performs or coordinates a bounded part of that objective.

## Domain hierarchy

```text
Workspace
└── Session
    └── Root run
        ├── Child run
        ├── Child run
        │   └── Child run
        └── Child run
```

The hierarchy represents work lineage. It does not represent an organization chart.

## Definitions

### Workspace

A workspace identifies the local repository and its operating boundary.

### Session

A session is one durable attempt to move a repository objective toward verified completion.

The session owns:

- the accepted intent;
- the completion contract;
- the run graph;
- the event sequence;
- repository observations;
- session-level policy;
- final reconciliation.

### Run

A run is one bounded execution context within a session.

A run can perform:

- direct implementation;
- investigation;
- documentation research;
- command execution coordination;
- verification;
- review;
- planning;
- recovery analysis;
- Project Steward coordination.

### Root run

Each session has one root run.

The root run represents the main control context for the session. The root run carries Project Steward responsibility by default.

### Child run

A child run is created when a task must become independently inspectable, steerable, cancellable, or accountable.

Delegation that does not require those properties can remain an ordinary tool execution or pure function call.

## Required run data

A run must have or reference:

```elixir
%Kiln.Run{
  id: run_id,
  session_id: session_id,
  root_run_id: root_run_id,
  parent_run_id: parent_run_id,
  kind: :steward | :builder | :scout | :verifier | :research | :system,
  status: :running,
  capability_profile: capability_profile,
  provider_ref: provider_ref,
  execution_ref: execution_ref,
  created_at: created_at,
  updated_at: updated_at
}
```

The exact Elixir type is provisional. The fields express required domain information.

Each run must also own or reference:

- its task statement;
- its context manifest;
- its transcript projection;
- its tool executions;
- its artifacts;
- its evidence;
- its observed mutations;
- its token and cost accounting;
- its time and resource limits;
- its cancellation state;
- its attention state;
- its completion result.

## Run lineage and OTP supervision

Logical lineage and runtime supervision are separate relationships.

```text
Logical run graph

Root run
├── Scout run
├── Builder run
└── Verifier run
```

```text
Runtime supervision

Kiln.RunSupervisor
├── Root run process
├── Scout run process
├── Builder run process
└── Verifier run process
```

A run's `parent_run_id` defines:

- why the run exists;
- where its result returns;
- how clients navigate the graph;
- which run receives its structured completion result.

An OTP supervisor defines:

- process startup;
- restart policy;
- process termination;
- fault containment.

A logical parent must not be assumed to supervise the child process.

A parent failure must not automatically erase useful child work. A child failure must not corrupt the parent run.

The event journal restores durable run state. OTP restores running process structure.

## Run statuses

Kiln uses explicit statuses:

```text
created
queued
starting
running
waiting_for_tool
waiting_for_child
waiting_for_user
waiting_for_permission
paused
verifying
completed
failed
canceled
orphaned
stale
```

A status transition must include:

- run identifier;
- previous status;
- next status;
- reason;
- event time;
- sequence position.

Kiln must not use a generic `busy` status as the only execution state.

## Foreground and background runs

### Foreground run

A foreground child is expected to receive immediate user attention.

Typical flow:

```text
Parent delegates
→ child run starts
→ client opens the child
→ parent waits or continues by policy
→ child returns a structured result
→ client can return to the parent
```

Use a foreground run for:

- interactive debugging;
- design investigation;
- work that is likely to need user steering;
- permission-sensitive execution.

### Background run

A background child executes without changing client focus.

Typical flow:

```text
Parent delegates
→ child run starts
→ client remains on the parent
→ parent shows a live child projection
→ completion or attention is routed globally
```

Use a background run for:

- repository search;
- documentation lookup;
- slow verification;
- read-only analysis;
- independent review.

Kiln must not change client focus automatically when a child completes.

## Client-local focus

The shared session stores the run graph. Each connected client stores its own focused run.

```text
Terminal client A → root run
Terminal client B → verifier run
Web client         → scout run
```

A focus change must not:

- pause a run;
- change another client's focus;
- change the session's root run;
- reassign run authority;
- alter execution state.

A client focus record should contain:

- client identifier;
- session identifier;
- focused run identifier;
- selected child or artifact;
- viewport state;
- last observed event sequence.

Client focus is transient interface state unless a client chooses to persist it.

## Parent projection

A parent run must expose each child through a live projection.

The projection should include:

- run title and kind;
- status;
- elapsed time;
- resource use;
- current activity summary;
- attention state;
- artifact count;
- evidence count;
- completion result when available.

The parent projection must not copy the full child transcript into the parent transcript.

A child completion result should contain:

- summary;
- observed evidence;
- inferences;
- unknowns;
- unresolved risks;
- artifact references;
- recommended next action when applicable.

## Attention routing

Any run can require attention.

An attention item must include:

```elixir
%Kiln.Attention{
  id: attention_id,
  session_id: session_id,
  run_id: run_id,
  parent_run_id: parent_run_id,
  type: :question | :permission | :conflict | :failure | :decision,
  urgency: :blocking | :high | :normal,
  summary: summary,
  response_schema: response_schema,
  created_at: created_at
}
```

The exact Elixir type is provisional.

Attention routing must not depend on nesting depth.

A client must be able to:

- answer from a global attention view;
- open the requesting run;
- route the item to the parent run;
- approve or deny a permission request;
- cancel the requesting run;
- defer a non-blocking item.

A run in `waiting_for_user` or `waiting_for_permission` must identify the active attention item.

## Event model

The event journal should record at least:

```text
run.created
run.started
run.status_changed
run.output_appended
run.tool_started
run.tool_completed
run.child_created
run.attention_required
run.attention_resolved
run.artifact_created
run.evidence_recorded
run.mutation_observed
run.completed
run.failed
run.canceled
run.orphaned
```

Not every token must become a durable event.

Live output may use bounded deltas while the journal stores compact, reconstructable segments.

Interfaces consume projections from the event sequence. Interfaces must not poll every run process to reconstruct session state.

## Capabilities

Each run receives an explicit capability profile.

Examples:

```text
inspect
verify
write_patch
write_worktree
network_research
steward
```

A child run inherits no ambient authority from its parent.

The parent may request a capability grant for the child. The capability broker remains authoritative.

A run must not access secrets, paths, network hosts, or mutation operations that its profile does not allow.

## Writing isolation

Kiln must not allow multiple writing runs to mutate one checkout concurrently.

Before concurrent writing runs are enabled, Kiln must support at least one of:

1. one isolated Git worktree per writing run;
2. one patch artifact per writing run that a controlling run reviews and applies.

The initial default is:

- one active writer for the main checkout;
- read-only children by default;
- verifier runs without write access;
- no automatic merge;
- no child Git push.

A writing run must identify its mutation boundary before execution.

## Initial delegation limits

The data model may support deeper graphs, but the initial product should use conservative defaults:

```text
Maximum child depth:          2
Maximum concurrent children:  3
Default child capability:     read-only
Default child result:         structured summary and evidence
Default writing children:     disabled
```

These values are provisional until dogfooding produces evidence.

## Recovery

After restart, Kiln must reconstruct:

- the run graph;
- each run's last durable status;
- unresolved attention;
- artifacts and evidence;
- parent-child relationships;
- interrupted executions;
- orphaned runs;
- client-independent session state.

Recovery must not convert an interrupted run into a completed run.

A run with unknown external execution state must become `orphaned` or another explicit non-success state.

## Interface requirements

The command-line interface, terminal user interface, Phoenix interface, and future protocol clients must use the same run queries and commands.

Candidate commands include:

- create child run;
- steer run;
- pause run;
- resume run;
- cancel run;
- resolve attention;
- set client focus;
- return a child result;
- mark a run stale.

Candidate queries include:

- get run;
- list children;
- get ancestry;
- get descendants;
- get run projection;
- list attention;
- list artifacts;
- list evidence;
- get resource use.

## Non-goals

The run model does not require:

- unlimited recursive delegation;
- peer-to-peer child communication;
- agent-manager hierarchies;
- shared mutable model context;
- automatic product decisions;
- concurrent writes to one checkout;
- automatic patch application;
- automatic merging;
- a permanent visual dashboard.

## Foundational rule

A delegated model task must become a first-class run when the task needs independent inspection, steering, cancellation, evidence, or recovery.

Delegated work must not become an opaque background tool call.
