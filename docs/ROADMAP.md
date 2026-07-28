# Roadmap

**Document type:** Reference

The roadmap is ordered by proof, not platform ambition.

P0-W05 establishes the planning-status baseline. P0-W06 establishes the protocol-neutral internal domain model. The current Phase 1 and Phase 2 work-package boundaries require reconciliation after P0-W06. See `docs/PLANNING-BASELINE.md`, `docs/INTERNAL-DOMAIN-MODEL.md`, and `docs/PLAN-RECONCILIATION.md`.

## Work identifiers

Kiln uses these identifiers:

```text
P1          Phase 1
P1-W02      Phase 1 work package 2
P1-X01      Phase 1 experiment 1
```

Each planned work package MUST follow `docs/BRANCHING-AND-WORK-PLANNING.md`.

## Phase 0 — Repository foundation

**ID:** P0  
**Goal:** establish project identity, constraints, documentation, basic Elixir structure, CI, work governance, coding-agent controls, foundational execution concepts, one reliable planning baseline, and one stable protocol-neutral internal domain model.

### Work packages

| ID | Purpose | Branch | Status |
| --- | --- | --- | --- |
| P0-W01 | Establish the Repository foundation. | `agent/bootstrap-project-foundation` | Integrated into `main` through pull request 1 |
| P0-W02 | Define branch-linked planning, Evidence rules, templates, and prose linting. | `work/p0-w02-work-governance` | Merged into the P0-W01 branch; not integrated into `main` |
| P0-W03 | Add agent-friendly code rules, project invariants, Skills, specialist reviewers, and deterministic development checks. | `work/p0-w03-agent-ready-development` | Merged into the P0-W02 branch; not integrated into `main` |
| P0-W04 | Define first-class Runs, the navigable Run graph, and Project Steward responsibility. | `work/p0-w04-run-graph-stewardship` | Draft pull request 5; implemented but unverified |
| P0-W05 | Audit planning authority, decisions, conflicts, implementation Evidence, and document status. | `work/p0-w05-planning-baseline` | Draft pull request 6; implemented but unverified |
| P0-W06 | Define the protocol-neutral internal domain, contracts, adapter boundary, and Run-centered execution unit. | `work/p0-w06-internal-domain-model` | In progress; depends on P0-W05 |

**Exit:** a new coding Session can identify the Project purpose, non-goals, accepted decisions, integration state, invariants, Workspace, Project, Repository, Environment, Session, Task, Run, Agent, Worker, model-invocation, Capability, Context, Evidence, and adapter boundaries. The Session can identify the next work package, mutation boundary, acceptance criteria, and required Evidence. It can run one preflight command and one complete quality command.

## Phase 1 — Local execution kernel

**ID:** P1  
**Goal:** prove durable supervised local work through the Kiln-native domain before adding an accepted model-driven loop.

### Required behavior

- register one Workspace;
- register one Project;
- bind one primary Repository and Repository trust policy;
- define one Environment;
- create one Session and accepted objective;
- create one root Task and one Root Run;
- persist Session, Task, Run, and execution events in SQLite;
- reconstruct Session, Task, Run, policy, and execution state after restart;
- create one minimal Context manifest;
- issue one scoped Capability grant;
- execute one supervised Command through a Tool call;
- stream bounded output;
- support timeout, interruption, and cancellation;
- record termination accurately;
- capture Git state and a Repository fingerprint;
- produce one Artifact and Claim;
- record one minimal Evidence item bound to Repository state;
- create one Checkpoint;
- expose state through a basic command-line projection.

### Current proposed work packages

These work packages predate ADRs 0004 through 0007. They remain proposed until the reconciliation pass confirms or replaces them.

| ID | Purpose | Branch | Depends on | Status |
| --- | --- | --- | --- | --- |
| P1-W01 | Define Workspace, Session, event, execution, fingerprint, and Checkpoint types. | `work/p1-w01-session-domain` | P0 | Replacement or major expansion required |
| P1-W02 | Persist append-oriented Session events in SQLite and reconstruct a Session. | `work/p1-w02-event-journal` | P1-W01 | Replacement or major expansion required |
| P1-W03 | Start, stream, time out, cancel, and record a Command. | `work/p1-w03-command-supervision` | P1-W01, P1-W02 | Domain and Capability reconciliation required |
| P1-W04 | Capture Git state and Repository fingerprints before and after execution. | `work/p1-w04-git-observation` | P1-W01, P1-W02 | Trust and Evidence reconciliation required |
| P1-W05 | Expose Session and execution state through the CLI. | `work/p1-w05-cli-projection` | P1-W02, P1-W03, P1-W04 | Task, Run, attention, and Client-focus reconciliation required |
| P1-W06 | Reconstruct interrupted Sessions and report the last known safe state. | `work/p1-w06-restart-recovery` | P1-W02, P1-W03, P1-W04 | Worker lease, orphan, policy, and Checkpoint reconciliation required |
| P1-W07 | Execute and record the Phase 1 acceptance scenario. | `work/p1-w07-phase-proof` | P1-W05, P1-W06 | Replacement scenario required |

The reconciliation must decide where to prove:

- Project and Repository membership;
- Task identity and satisfaction;
- Run identity and lineage;
- event and projection schemas;
- Capability availability, policy, grants, and effective authority;
- Context items and manifests;
- Claim, Evidence, Receipt, and Checkpoint minimums;
- fake navigable Child Runs;
- Client-local focus;
- attention routing;
- the first Project Steward projection.

Each accepted work package requires a plan before implementation.

**Exit:** Kiln can create, execute, interrupt, restart, reconstruct, navigate, and accurately report one manual Project, Session, Task, Root Run, Command, Artifact, Claim, Evidence, and Checkpoint scenario without a live model or external agent protocol.

## Phase 2 — Provider and model loop

**ID:** P2

### Required behavior

- one Kiln-native provider-neutral model-invocation contract;
- one direct provider adapter;
- model Capability discovery or explicit configuration;
- streamed normalized model-invocation events;
- one provider-backed Root Run;
- versioned Agent binding;
- read, search, patch or write, and Command Tools;
- persistent model and Tool events;
- Context-size accounting;
- Privacy-policy evaluation before egress;
- interruption and cancellation;
- Project Steward control projection;
- Claims and completion summary without unsupported completion.

The first direct provider target is MiniMax because the project owner has an active Token Plan.

Kimi and Codex require separate managed-client adapter evaluation because platform sign-in is owned by their official Clients.

Provider transport experiments MAY begin before Phase 1 is complete on isolated `spike/` branches. Experimental adapter code MUST NOT enter the accepted Session loop or satisfy Phase 2 until Phase 1 exits.

The reconciliation must decide when the first real read-only Child Run and independent Verifier become accepted behavior.

**Exit:** Kiln completes one small Repository change through a provider-backed Root Run, preserves the Session after restart, and reports current Evidence, Claims, failures, and unresolved work.

## Phase 3 — Evidence-backed completion

**ID:** P3

Required:

- observed mutation records;
- Change sets bound to Repository fingerprints;
- project verification Commands;
- structured Claims and Evidence;
- Repository-state binding;
- Evidence freshness;
- mutation reconciliation;
- deterministic Receipts;
- unresolved-failure reporting;
- completion readiness;
- `what remains unproven?` inspection;
- independent Verifier Runs for material completion Claims.

**Exit:** a passing test becomes stale after a relevant source change, and Kiln refuses to treat it as current. A final Receipt discloses the stale Evidence and cannot report the Claim as proven.

## Phase 4 — Context and recovery

**ID:** P4

Required:

- orientation records and freshness;
- Context-item provenance and trust class;
- deterministic inclusion rules;
- token estimates;
- per-Run immutable Context manifests;
- explicit Artifact-to-Context inclusion;
- Checkpoints;
- interruption summaries;
- traceable compaction;
- Session and Run branching where accepted;
- recovery of Tasks, Run graph, Worker leases, attention, policies, Claims, Evidence, and Steward projection.

## Phase 5 — Extension and adapter boundary

**ID:** P5

Required:

- supervised external processes;
- versioned language-neutral extension protocol;
- adapter-owned protocol negotiation and identifier mapping;
- Tool and Resource registration through Kiln-native contracts;
- progress and cancellation;
- Capability declarations without ambient grants;
- Privacy-policy evaluation;
- crash isolation;
- conformance tests that prove the adapter does not alter core semantics;
- one non-Elixir example extension or adapter.

## Phase 6 — Phoenix LiveView

**ID:** P6

Required:

- Project, Session, and Workspace views;
- Task and Run tree navigation;
- model and Tool streams;
- global attention view;
- Approval and permission prompts;
- interruption;
- Git status and diff;
- Claim, Evidence, Receipt, and Context views;
- reconnect without terminating the runtime;
- Client-local focus.

## Phase 7 — TypeScript SDK

**ID:** P7

Required:

- typed Kiln-native Tool and Resource registration;
- JSON Schema contracts;
- Capability declarations;
- cancellation;
- progress;
- compatibility checks;
- adapter mapping helpers;
- test helpers;
- example extensions and adapters.

## Pending roadmap reconciliation

P0-W04 through P0-W06 do not finalize the new proof order.

Before P1-W01 implementation begins, reconcile:

- Workspace, Project, Repository, and Environment boundaries;
- Session, Task, Run, Agent, Worker, and model-invocation boundaries;
- event-journal and projection scope;
- Capability-policy work-package boundaries;
- Repository trust and Privacy-policy timing;
- minimum Context manifest;
- minimum Claim, Evidence, Receipt, and Checkpoint state;
- fake-Run interface proof;
- attention and Client-focus timing;
- Project Steward vertical slice;
- MiniMax adapter acceptance timing;
- first read-only Child Run;
- independent Verifier timing;
- writing-Run isolation;
- version 0.1 completion scenario;
- adapter acceptance and conformance boundaries.

The current authorities, conflicts, gaps, and unknowns are recorded in `docs/PLANNING-BASELINE.md`. The internal terms and contracts are in `docs/INTERNAL-DOMAIN-MODEL.md`. The earlier candidate proof order remains in `docs/PLAN-RECONCILIATION.md` until it is replaced.

## Deferred

- Gleam modules;
- Rust sandbox helper;
- ACP adapter strategy;
- Model Context Protocol adapter strategy;
- Language Server Protocol adapter strategy;
- A2A, AG-UI, and AHP adapter strategies;
- hosted collaboration;
- plugin registry;
- browser integrated development environment;
- remote execution;
- unlimited delegation depth;
- writing Child Runs before isolation;
- automatic Git publication.
