# Run Model

**Document type:** Reference  
**Status:** Foundational direction  
**Internal-domain authority:** `docs/INTERNAL-DOMAIN-MODEL.md`

A Run is one independently inspectable execution or coordination attempt for one Task inside a Kiln Session.

The Run is Kiln's primary durable execution unit.

## Required properties

A Run must be independently:

- identifiable;
- inspectable;
- interruptible;
- resumable when recovery is valid;
- measurable;
- permission-scoped;
- Context-scoped;
- Evidence-producing;
- cancellable.

A Run can be model-backed, deterministic, command-oriented, human-steered, verification-focused, or coordination-focused.

## Domain hierarchy

```text
Workspace
└── Project
    └── Session
        ├── Task
        │   ├── Run
        │   └── later Run attempt
        └── Root Task
            └── Root Run
                ├── Child Run
                ├── Child Run
                │   └── Child Run
                └── Child Run
```

This hierarchy represents ownership and work lineage. It does not represent an organization chart or OTP supervision tree.

## Task and Run

A Task states one bounded desired outcome or decision.

A Run is one execution or coordination attempt for that Task.

Every Run must reference exactly one Task.

One Task can have several Runs because:

- an earlier Run failed;
- Evidence became stale;
- a different approach is required;
- independent verification requires a separate Run;
- concurrent read-only investigation uses several bounded Runs.

A completed Run does not automatically satisfy the Task. Task satisfaction is derived from accepted criteria and current Evidence.

## Run identity

A Run has a Kiln-generated `run_id`.

Run identity must not use:

- Agent name;
- model name;
- provider request ID;
- protocol task, thread, or session ID;
- Worker identity;
- BEAM PID or reference;
- operating-system PID;
- Tool call ID;
- Command ID;
- Terminal ID.

A Run identity survives every Worker, process, model invocation, client, and adapter connection.

## Run roles

### Root Run

Each Session has exactly one Root Run.

The Root Run:

- references the Session root Task;
- has no Parent Run;
- references itself as `root_run_id`;
- is the main execution and control context;
- carries Project Steward responsibility by default.

Root is a Run role and invariant. It does not require a separate entity table, Elixir struct, or process type.

### Parent Run

A Parent Run is the existing Run referenced by a Child Run's `parent_run_id`.

The Parent Run:

- explains why the Child Run exists;
- receives the Child Run's structured result;
- exposes a Child projection;
- can request interruption or attention routing;
- does not automatically supervise the Child process;
- does not transfer ambient authority or Context.

Parent is a relationship role, not a separate entity.

### Child Run

A Child Run is a Run with a non-null `parent_run_id`.

Create a Child Run when delegated work requires independent:

- inspection;
- steering;
- interruption or cancellation;
- Context;
- Capability scope;
- measurement;
- Artifacts and Evidence;
- recovery.

Delegation that does not need these properties can remain a Tool call, deterministic function, or internal service operation.

A Child Run is not an organizational subordinate or hidden background Agent.

## Agent, Worker, and model invocation

### Agent

An Agent is a versioned execution definition.

An Agent can define:

- instruction Artifacts;
- model-selection policy;
- Skill bindings;
- expected result schema;
- reasoning and Tool-use strategy.

An Agent is data. It does not own Run state, Capability grants, policy, or completion readiness.

### Worker

A Worker is a transient live executor that holds a bounded lease to advance one Run.

A Worker can be:

- model-backed;
- deterministic;
- command-focused;
- a human bridge;
- an adapter bridge.

A Worker process can die and be replaced without changing Run identity.

Do not persist Worker runtime handles. Record lease, heartbeat, handoff, crash, and termination events when material.

The initial default is one active Worker lease per Run.

### Model invocation

A model invocation is one provider request and response stream owned by a Run.

A Run can contain zero, one, or many model invocations.

A model invocation:

- uses one immutable Context manifest;
- uses one Agent binding snapshot when present;
- can request Tool calls;
- records normalized events, usage, output, failure, cancellation, and provider mappings;
- cannot mark the Task, Run, or Session complete by itself.

## Required Run data

A Run must have or reference:

```elixir
%Kiln.Run{
  id: run_id,
  session_id: session_id,
  task_id: task_id,
  root_run_id: root_run_id,
  parent_run_id: parent_run_id,
  status: status,
  context_manifest_id: context_manifest_id,
  agent_binding: agent_binding,
  limits: limits,
  created_at: created_at,
  updated_at: updated_at
}
```

The exact Elixir type is provisional. The fields express required domain information.

Each Run must also own or reference:

- Task statement and criteria;
- Context manifest;
- Agent binding when present;
- Worker leases;
- model invocations;
- requested Capabilities and active Capability grants;
- Resources;
- Tool calls;
- Commands and Terminals;
- attention and interruption state;
- Artifacts and Change sets;
- Claims and Evidence;
- Receipts and Checkpoints;
- token, cost, time, and Resource accounting;
- failures, warnings, risks, unknowns, and exclusions;
- structured result.

## Run lifecycle

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

- Run identity;
- previous status;
- next status;
- reason;
- event time;
- recorded event sequence;
- actor or causation;
- relevant execution or Attention request.

Kiln must not use `busy` as the only execution state.

### Terminal states

`completed`, `failed`, and `canceled` are terminal for one Run attempt.

`orphaned` means Kiln does not know the current state of an external execution or Worker after recovery. It is not success.

`stale` means the Run result or its supporting Evidence no longer applies to the required current state. It does not erase history.

### Resume rules

A paused Run can resume.

An interrupted Run can resume when the event journal and external state establish a safe continuation.

A canceled Run does not resume. A new attempt requires a new Run.

An orphaned Run can resume only after explicit reconciliation establishes that duplicate external effects cannot occur.

## Run lineage and OTP supervision

Logical lineage and runtime supervision are separate relationships.

```text
Logical Run graph

Root Run
├── Scout Run
├── Builder Run
└── Verifier Run
```

```text
Possible runtime supervision

Kiln.RunSupervisor
├── active Root Run process
├── active Scout Run process
├── active Builder Run process
└── active Verifier Run process
```

A Run's `parent_run_id` defines:

- why the Run exists;
- where its structured result returns;
- how Clients navigate the graph;
- which Run can coordinate its Task relationship.

An OTP supervisor defines:

- process startup;
- restart policy;
- process termination;
- fault containment.

A logical Parent Run must not be assumed to supervise the Child process.

A Parent failure must not erase useful Child work. A Child failure must not corrupt Parent state.

The event journal restores durable Run state. OTP restores running process structure.

## Foreground and background Runs

Foreground and background are interaction hints. They do not change Run identity or authority.

### Foreground Run

A foreground Child Run is expected to receive immediate user attention.

Typical flow:

```text
Parent Run creates Child Task and Run
→ Child Run starts
→ Client opens the Child Run
→ Parent waits or continues by policy
→ Child Run returns a structured result
→ Client can return to the Parent Run
```

Use a foreground Run for:

- interactive debugging;
- design investigation;
- work likely to need user steering;
- permission-sensitive execution.

### Background Run

A background Child Run executes without changing Client focus.

Typical flow:

```text
Parent Run creates Child Task and Run
→ Child Run starts
→ Client remains on Parent Run
→ Parent projection shows Child activity
→ completion or attention is routed globally
```

Use a background Run for:

- Repository search;
- documentation lookup;
- slow verification;
- read-only analysis;
- independent review.

Kiln must not change Client focus automatically when a Child Run completes.

## Client-local focus

The shared Session stores the Run graph. Each connected Client stores its own focused Run.

```text
Terminal Client A → Root Run
Terminal Client B → Verifier Run
Web Client         → Scout Run
```

A focus change must not:

- pause a Run;
- change another Client's focus;
- change the Session Root Run;
- reassign authority;
- alter execution state;
- change scheduling.

Client focus is transient interface state unless the Client stores it as non-authoritative convenience data.

## Parent projection and Child result

A Parent Run must expose each Child Run through a live projection.

The projection should include:

- Task title and Run kind hint;
- status;
- elapsed time;
- token, cost, and Resource use;
- current activity summary;
- effective-authority summary;
- attention state;
- Artifact and Evidence counts;
- structured result when available.

The Parent projection must not copy the full Child transcript or Context into the Parent.

A Child result should contain:

- Task outcome;
- summary;
- observed facts and Evidence references;
- Claims and inferences;
- unknowns and unresolved risks;
- Artifact and Change-set references;
- failures and warnings;
- recommended next action when applicable.

## Context scope

Each Run has one current immutable Context manifest.

A later Context update creates a new manifest.

Each Context item must record:

- source;
- digest;
- trust class;
- sensitivity;
- inclusion reason;
- freshness;
- token estimate;
- transformation history.

An Artifact does not enter Context automatically.

A Child Run does not receive the Parent transcript or Context by default. It receives the minimum required Context items for its Task.

Reference-only Repository content remains untrusted data. It cannot issue instructions, change policy, or gain authority.

## Capabilities and authority

Each Run receives explicit Capability grants and limits.

Capability availability is not permission.

Effective authority is:

```text
available Capability
∩ Workspace limits
∩ Project Repository trust policy
∩ Privacy policy
∩ Session limits
∩ active Run Capability grant
∩ Resource scope and operation limits
```

A Child Run inherits no ambient authority from its Parent Run.

The Parent can request a new Child grant. Policy and the authorized actor decide it.

An Agent, Skill, Tool, adapter, or Environment cannot grant authority.

## Tools, Commands, and Terminals

A Tool call invokes one Kiln-native operation contract.

A Tool declares required Capabilities. Kiln validates effective authority before execution.

A Tool call can create a Command.

A Command is a supervised operating-system process specification and execution record.

A Terminal is an interactive process Resource owned by one Command and Run while open.

A Tool call does not automatically become a Child Run.

Use a Child Run only when the delegated operation needs independent Run properties.

## Attention and interruption

Any Run can raise an Attention request.

Attention types include:

- question;
- Approval;
- permission;
- conflict;
- failure;
- decision;
- priority.

Attention routing must not depend on Run depth.

An Interruption records a request to pause, cancel, detach, stop input, or terminate a Run or execution.

Pause can be resumable. Cancel is terminal for that Run or execution attempt.

The target process handles live signaling. The Interruption record remains durable data.

## Artifacts, Claims, Evidence, and Receipts

A Run can produce Artifacts and Change sets.

An Artifact is immutable content or a durable reference. It is not automatically Context or Evidence.

A Change set is an Artifact with Repository mutation semantics and a base fingerprint.

A Claim is an assertion. It can be supported, disputed, refuted, superseded, or withdrawn.

Evidence is an immutable observation with method, producer, result, Repository or Environment state binding, and freshness rule.

A Receipt is an immutable sealed manifest that references Evidence, state, failures, warnings, unknowns, and outcomes.

A Receipt cannot turn a Claim into Evidence or make stale Evidence current.

## Event model

The event journal should record at least:

```text
RunCreated
RunQueued
RunStarted
RunStatusChanged
WorkerLeaseGranted
WorkerHeartbeatRecorded
WorkerLeaseExpired
AgentBound
ContextManifestSelected
CapabilityRequested
CapabilityGranted
CapabilityDenied
CapabilityRevoked
ModelInvocationStarted
ModelInvocationCompleted
ModelInvocationFailed
ToolCallRequested
ToolCallStarted
ToolCallCompleted
ToolCallFailed
CommandStarted
CommandTerminated
TerminalOpened
TerminalClosed
ChildRunCreated
AttentionRequired
AttentionResolved
InterruptionRequested
InterruptionApplied
ArtifactCreated
ChangeSetCreated
ClaimRecorded
EvidenceRecorded
EvidenceInvalidated
ReceiptSealed
CheckpointCreated
RunCompleted
RunFailed
RunCanceled
RunOrphaned
RunMarkedStale
```

Not every token must become a durable event.

Live output can use bounded transient deltas while the journal stores compact, reconstructable segments and Artifact references.

Interfaces consume projections from the event sequence. They must not poll every Run process to reconstruct Session state.

## Writing isolation

Kiln must not allow multiple writing Runs to mutate one checkout concurrently.

Before concurrent writing Runs are enabled, Kiln must support at least one of:

1. one isolated Git worktree per writing Run;
2. one patch Artifact per writing Run that a controlling Run reviews and applies.

The initial default is:

- one active writer for the primary checkout;
- read-only Child Runs by default;
- Verifier Runs without write access;
- no automatic patch application;
- no automatic merge;
- no Child Git push.

A writing Run must identify its Repository and path mutation boundary before execution.

A Change set must record its base Repository fingerprint.

## Initial delegation limits

The data model can support deeper graphs, but the initial product should use conservative defaults:

```text
Maximum Child depth:          2
Maximum concurrent Children:  3
Default Child authority:      read-only grants
Default Child result:         structured result with Claims and Evidence
Default writing Children:     disabled
Default active Workers:       1 per Run
```

These values are provisional until dogfooding produces Evidence.

## Recovery

After restart, Kiln must reconstruct:

- Run graph;
- Task relationships;
- each Run's last durable status;
- Agent binding and Context manifest;
- Worker lease expiry and orphan status;
- unresolved attention;
- active Capability grants and revocations;
- Artifacts, Change sets, Claims, Evidence, Receipts, and Checkpoints;
- Parent-Child relationships;
- interrupted executions;
- Client-independent Session state.

Recovery must not convert an interrupted or orphaned Run into a completed Run.

A Run with unknown external execution state must remain `orphaned` or another explicit non-success state until reconciliation.

A replacement Worker must not repeat a mutation or external effect without an idempotency decision.

## Interface requirements

CLI, TUI, Phoenix, headless, and adapter Clients must use the same Run queries and commands.

Candidate commands include:

- create Task and Run;
- create Child Task and Child Run;
- bind Agent;
- select Context manifest;
- request Capability grant;
- start model invocation;
- request Tool call;
- steer, pause, resume, or cancel Run;
- resolve Attention request;
- set Client focus;
- return Child result;
- record Artifact, Claim, Evidence, Receipt, or Checkpoint;
- mark Run stale.

Candidate queries include:

- get Run;
- get Task;
- list Child Runs;
- get ancestry and descendants;
- get Run projection;
- get Context manifest;
- list Worker leases and executions;
- list effective authority and grants;
- list attention;
- list Artifacts and Change sets;
- list Claims and Evidence;
- get Resource use;
- get Trace;
- get Task satisfaction and completion readiness.

External protocol messages must translate to these or later accepted Kiln-native operations.

## Non-goals

The Run model does not require:

- unlimited recursive delegation;
- peer-to-peer Child communication;
- Agent-manager hierarchies;
- shared mutable model Context;
- automatic product decisions;
- concurrent writes to one checkout;
- automatic patch application;
- automatic merging;
- a permanent visual dashboard;
- a process for every Run-related noun;
- a database table for every schema definition;
- adoption of an external Agent or Tool protocol as the internal model.

## Foundational rule

A Task that needs independent execution properties must use a Run.

The Run remains the durable work identity across Agents, Workers, model invocations, Tools, Commands, processes, Clients, adapters, interruption, recovery, and Evidence production.
