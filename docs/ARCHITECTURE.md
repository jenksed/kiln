# Architecture

**Document type:** Reference  
**Status:** Foundational direction; implementation details remain provisional  
**Internal-domain authority:** `docs/INTERNAL-DOMAIN-MODEL.md`

## Architectural position

Kiln owns one protocol-neutral internal domain model.

The primary durable execution unit is a Run.

Interfaces, providers, language servers, tool servers, agent clients, terminals, and future protocols connect through domain commands, queries, events, projections, and adapters. They do not own Session or Run truth.

## System shape

```text
                           Developer
                               |
            +------------------+------------------+
            |                  |                  |
           CLI                TUI        Phoenix or headless client
            |                  |                  |
            +------------------+------------------+
                               |
                      Kiln domain API
                               |
     +-------------------------+-------------------------+
     |                         |                         |
 Workspace and Project    Session and Task        Run graph and Steward
     |                         |                         |
 Repository, Environment   Objective and criteria   Workers and executions
     |                         |                         |
     +-------------------------+-------------------------+
                               |
       Context | Capability policy | Evidence | Recovery
                               |
                  Append-oriented event journal
                               |
                            SQLite
                               |
             +-----------------+-----------------+
             |                 |                 |
        Native Tools      External processes   Repository and OS
```

External integrations enter through adapters:

```text
External protocol, provider, or mature tool
                    |
          Adapter-owned translation
                    |
              Kiln domain API
```

No external protocol object appears between the domain API and the internal model.

## Domain hierarchy

```text
Workspace
└── Project
    ├── Repositories
    ├── Environments
    ├── Repository trust policy
    ├── Privacy policy
    └── Session
        ├── Tasks
        └── Root Run
            ├── Child Run
            ├── Child Run
            └── Child Run
```

The hierarchy describes ownership and work lineage. It does not prescribe database tables or OTP supervision.

## Work boundaries

### Workspace

A Workspace is one host-local operating and trust boundary. It contains Projects and Environments.

### Project

A Project is one durable software product or body of work. It owns active instructions, Repository memberships, policies, and Sessions.

### Repository

A Repository is one Git-backed source tree. Git and the filesystem remain authoritative for source state.

A Project can classify a Repository as primary, secondary writable, dependency, reference-only, or denied.

### Environment

An Environment defines where Commands, Tools, and managed Resources execute. Availability does not grant authority.

### Session

A Session owns one accepted objective, completion contract, Task set, event sequence, Root Run, and Run graph.

### Task

A Task states one bounded desired outcome or decision. A Task can have several Runs.

### Run

A Run is the primary durable execution and coordination unit for one Task.

A Run owns or references:

- identity and lifecycle;
- Task, Session, Root Run, and Parent Run relationships;
- Context manifest;
- Agent binding;
- Capability grants and limits;
- Worker leases;
- model invocations;
- Tool calls, Commands, and Terminals;
- Artifacts and Change sets;
- Claims, Evidence, and Receipts;
- attention, interruption, Checkpoints, resource accounting, and result.

### Root Run and Project Steward

Each Session has exactly one Root Run. The Root Run carries Project Steward responsibility by default.

The Steward coordinates delivery. It does not own Repository truth, policy truth, Evidence truth, or user authority.

### Agent, Worker, and model invocation

An Agent is a versioned execution definition.

A Worker is a transient executor that holds a bounded lease to advance one Run.

A model invocation is one provider request and response stream owned by a Run.

A Worker or invocation can fail without changing Run identity.

## Execution layers

Kiln separates durable work from live execution.

```text
Task: desired outcome
        ↓
Run: durable execution unit
        ↓
Worker lease: live executor
        ↓
Model invocation | Tool call | Command | Terminal
        ↓
Artifact | Change set | Claim | Evidence
```

A Tool call remains a Tool call unless the work requires independent inspection, steering, interruption, measurement, Evidence, or recovery. In that case, Kiln creates a Child Run.

## Runtime ownership

A process should exist only when it owns:

- mutable concurrent state;
- a Resource lifetime;
- timing or timeout behavior;
- subscriptions or streaming;
- cancellation;
- external communication;
- failure isolation.

Data entities and derived projections do not require processes.

A candidate runtime shape is:

```text
Kiln.Application
├── Kiln.Store
├── Kiln.PolicyService
├── Kiln.AdapterSupervisor
├── Kiln.WorkspaceSupervisor
│   └── active Workspace coordinator when required
├── Kiln.SessionSupervisor
│   └── active Session coordinator
├── Kiln.RunSupervisor
│   ├── active Run process
│   ├── active Run process
│   └── active Run process
├── Kiln.ExecutionSupervisor
│   ├── Worker process
│   ├── model invocation process
│   ├── Command process
│   └── Terminal process
└── Kiln.ProjectionSupervisor
    ├── attention router
    ├── Evidence freshness projection
    └── interface event publisher
```

This shape is directional. Requirements can combine or split services.

A domain noun does not justify a process.

## Logical lineage is not supervision

The Run graph records logical work lineage:

```text
Root Run
├── Scout Run
├── Builder Run
└── Verifier Run
```

OTP supervision records process startup, restart, termination, and fault containment.

A Run's `parent_run_id` must not select its OTP supervisor.

A Child Run failure must not corrupt Parent Run state. A Parent Run restart must not erase useful Child Run work. Persisted events restore Run state. OTP restores process structure.

## Domain API

All Clients, Workers, Steward operations, and adapters must use explicit domain commands and queries.

Candidate commands include:

- register Workspace;
- register Project;
- register Repository;
- define Environment;
- start Session;
- accept objective or completion-contract revision;
- create Task;
- create Root Run;
- create Child Run;
- bind Agent definition;
- submit model invocation;
- request Tool call;
- request or revoke Capability grant;
- raise or resolve Attention request;
- interrupt Run or execution;
- create Artifact, Claim, Evidence, Receipt, or Checkpoint;
- request reconciliation;
- request completion.

Candidate queries include:

- Workspace and Project snapshot;
- Repository membership and trust;
- Environment availability;
- Session snapshot;
- Task graph;
- Run graph and Run projection;
- active Worker leases and executions;
- Capability availability, grants, and effective authority;
- Context manifest;
- unresolved attention;
- Artifact and Change-set inventory;
- Claim and Evidence status;
- Trace;
- completion readiness.

The exact API remains provisional. It must preserve the domain distinctions in `docs/INTERNAL-DOMAIN-MODEL.md`.

## Event and projection flow

```text
Domain command or observed external fact
                  ↓
          Authorization and validation
                  ↓
           Durable domain event
                  ↓
          Append-oriented journal
                  ↓
        Rebuildable projections and indexes
                  ↓
       CLI, TUI, web, headless, and adapters
```

Interfaces must not poll every process to reconstruct a Session.

Live output can use transient bounded deltas. Durable events and Artifacts must retain enough information for reconstruction and audit.

## Authority model

Capability availability, policy allowance, and Capability grant are separate.

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

A Parent Run, Agent, Skill, Tool, adapter, or Environment cannot grant ambient authority.

## Context and trust

A Run uses an immutable Context manifest.

Each Context item records provenance, digest, trust class, sensitivity, inclusion reason, size estimate, freshness, and transformation history.

Active-Project instructions can govern work.

Reference-only Repository or Project content remains untrusted data. It cannot change instructions, policy, product direction, or authority without an explicit user decision and recorded revision.

An Artifact does not enter Context automatically.

## Claims, Evidence, and Receipts

A Claim is an assertion.

Evidence is an immutable observation with method, producer, result, state binding, and freshness rule.

A Receipt is an immutable sealed manifest that references Evidence, state, failures, warnings, unknowns, and outcomes.

A Receipt cannot make stale or missing Evidence current.

Completion readiness is a deterministic projection. The Steward or an Agent can recommend completion but cannot set readiness through narrative.

## Client-local focus

The shared runtime owns Workspace, Project, Session, Task, Run, policy, Artifact, Claim, and Evidence state.

Each Client owns its current focus and viewport.

```text
Terminal A → Root Run
Terminal B → Verifier Run
Web Client → Scout Run
```

Changing focus must not change execution, authority, scheduling, the Root Run, or another Client.

## External-adapter boundary

An adapter owns:

- protocol parsing and validation;
- authentication specific to the external system;
- external identifier mappings;
- message and event translation;
- protocol metadata;
- representation-loss disclosures.

An adapter does not own:

- Kiln Session, Task, or Run identity;
- Capability grants;
- Repository trust or Privacy policy;
- Evidence freshness;
- completion readiness;
- canonical domain events.

ACP, MCP, LSP, A2A, AG-UI, AHP, provider APIs, and other protocols are examples of adapter concerns. Their inclusion here does not accept their implementation or roadmap position.

## Source authority

- Current user instruction and accepted Project instructions own desired behavior.
- Repository trust policy owns instruction and source trust classification.
- Privacy policy owns egress, retention, and redaction rules.
- SQLite owns durable Kiln events and rebuildable state projections.
- Git owns committed source history and branch identity.
- The filesystem owns current working Artifacts.
- Environment observations own current execution-environment facts.
- Capability policy and grants own authority.
- Evidence records and freshness rules own verification status.
- The transcript is a projection, not the canonical Session or Run record.
- Client focus is interface state, not shared truth.
- External protocol objects are adapter data, not core truth.

## Initial implementation rule

Version 0.1 remains one Mix project. An umbrella is deferred until actual dependency, release, or ownership boundaries justify it.

The first vertical slice should prove:

1. Workspace registration;
2. Project registration;
3. one primary Repository membership and trust policy;
4. one Environment definition;
5. one Session and accepted objective;
6. one root Task;
7. one Root Run;
8. append-oriented events;
9. one minimal Context manifest;
10. one scoped Capability grant;
11. one supervised Command Tool call;
12. one Artifact and Claim;
13. one Evidence record bound to Repository state;
14. one Checkpoint;
15. one command-line projection.

Do not start with a provider, Agent protocol, Child Run, TUI framework, or broad adapter surface.
