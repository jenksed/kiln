# Architecture

**Status:** Foundational direction; implementation details remain provisional.

## System shape

Kiln separates its durable runtime from its interfaces.

```text
                         Developer
                             |
             +---------------+----------------+
             |               |                |
            CLI       Phoenix LiveView   Headless API
             |               |                |
             +---------------+----------------+
                             |
                    Harness domain API
                             |
                       Workspace
                             |
                         Session
                             |
                    Durable run graph
                             |
                    Root run: Steward
             +---------------+----------------+
             |               |                |
         Child runs     Execution engine   Context engine
             |               |                |
      Run supervisor    Tool supervisor    Provider layer
             +---------------+----------------+
                             |
                    Event journal and SQLite
                             |
                     Capability broker
                             |
             +---------------+----------------+
             |               |                |
        Native tools    Extensions       External systems
```

The command-line interface, web interface, and future clients are projections. They do not own session or run truth.

## Work boundaries

### Workspace

A workspace identifies the local repository and its operating boundary.

### Session

A session owns one repository objective, completion contract, run graph, and final reconciliation.

### Run

A run owns or references one independently inspectable unit of work.

### Project Steward

The root run carries Project Steward responsibility by default.

The Steward coordinates delivery through explicit domain commands. The Steward does not bypass policy, repository truth, evidence freshness, or user authority.

## Runtime ownership

A process should exist only when it owns mutable state, a resource lifetime, concurrency, cancellation, failure isolation, or external communication.

A likely later supervision shape is:

```text
Kiln.Application
├── Kiln.Store
├── Kiln.ProviderRegistry
├── Kiln.ExtensionRegistry
├── Kiln.WorkspaceRegistry
├── Kiln.WorkspaceSupervisor
│   └── Kiln.WorkspaceSession
│       ├── session coordinator
│       ├── context projection
│       ├── permission broker
│       ├── evidence collector
│       ├── attention router
│       └── stewardship projection
└── Kiln.RunSupervisor
    ├── root run process
    ├── child run process
    ├── model request process
    └── tool execution process
```

This structure is directional. It is not a mandate to create a process for every module.

## Logical lineage is not supervision

The run graph records logical lineage:

```text
Root run
├── Scout run
├── Builder run
└── Verifier run
```

The OTP supervision tree records process lifecycle and fault containment.

A run's `parent_run_id` must not be used as an implicit OTP supervisor relationship.

This separation permits:

- a child failure without parent corruption;
- a parent restart without automatic child destruction;
- recovery of useful child artifacts;
- interface navigation that does not dictate process ownership.

The event journal restores durable run state. OTP restores process structure.

## Event flow

Interfaces consume projections from the event stream.

```text
Run and tool processes
        ↓
Durable event journal
        ↓
Projection builders
        ↓
PubSub or protocol event stream
        ↓
CLI, TUI, Phoenix, ACP, or other clients
```

An interface must not poll every run process to reconstruct the session.

Live output may use transient bounded deltas. Durable records must retain enough information for reconstruction.

## Client-local focus

Each client owns its currently viewed run.

```text
Terminal A → root run
Terminal B → verifier run
Web client → scout run
```

Changing focus must not change another client, pause execution, or redefine the session's active run.

The shared runtime owns the run graph. The client owns navigation state.

## Attention routing

Any run can emit a normalized attention item.

Attention types include:

- question;
- permission;
- conflict;
- failure;
- decision.

The attention router must deliver items independently of run depth.

A client can respond from a global attention view or enter the requesting run.

## Writing isolation

The active checkout permits one writer.

Concurrent writing runs require:

- isolated Git worktrees; or
- patch artifacts that a controlling run reviews and applies.

Read-only investigation and verification can run concurrently under explicit capability profiles.

## Stewardship architecture

The Project Steward uses these authoritative services:

```text
Accepted intent and specification
            ↓
Project Steward projection
            ↓
Run graph and attention router
            ↓
Execution, tools, providers, and verification
            ↓
Repository observations and evidence
            ↓
Reconciliation and completion readiness
```

The Steward interprets and coordinates state. The Steward does not own the underlying truth.

Authoritative sources remain:

- current user instruction and accepted specifications for desired behavior;
- Git and filesystem observations for repository state;
- the event journal for recorded session and run history;
- capability policy for authority;
- current evidence for verification status;
- deterministic acceptance logic for completion readiness.

## Domain API

All interfaces and stewardship operations must use explicit commands and queries.

Candidate session commands:

- start session;
- record intent;
- update completion contract;
- create checkpoint;
- resume session;
- request reconciliation;
- request completion.

Candidate run commands:

- create root run;
- create child run;
- steer run;
- pause run;
- resume run;
- cancel run;
- return child result;
- mark run stale.

Candidate attention commands:

- raise attention;
- resolve attention;
- route attention;
- approve or deny a capability.

Candidate queries:

- session snapshot;
- run graph;
- run projection;
- run ancestry and descendants;
- event history;
- workspace status;
- current context;
- active executions;
- unresolved attention;
- verification status;
- unresolved findings;
- delivery traceability;
- completion readiness.

Interfaces and models must not directly manipulate arbitrary GenServers or persistence records.

## Source authority

- SQLite owns durable session and run events and resumable harness state.
- Git owns committed source history and branch identity.
- The filesystem owns current working artifacts.
- The transcript is a projection, not the canonical session or run.
- Client focus is interface state, not session truth.
- The Project Steward is a control projection, not the source of repository or evidence facts.

## Initial implementation rule

Version 0.1 remains one Mix project. An umbrella is deferred until actual dependency, release, or ownership boundaries justify it.

The implementation should prove the model vertically before broad delegation:

1. session and root run domain;
2. durable run events;
3. fake child-run navigation and attention;
4. supervised execution;
5. one provider-backed root run;
6. one read-only child run;
7. independent verifier;
8. writing isolation before writing children.

The final work-package order remains subject to the planned reconciliation pass.
