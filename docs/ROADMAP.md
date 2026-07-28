# Roadmap

**Document type:** Reference

The roadmap is ordered by proof, not platform ambition.

P0-W05 establishes the planning-status baseline. The current Phase 1 and Phase 2 work-package boundaries require reconciliation after P0-W05. See `docs/PLANNING-BASELINE.md` and `docs/PLAN-RECONCILIATION.md`.

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
**Goal:** establish project identity, constraints, documentation, basic Elixir structure, CI, work governance, coding-agent controls, foundational execution concepts, and one reliable planning baseline.

### Work packages

| ID | Purpose | Branch | Status |
| --- | --- | --- | --- |
| P0-W01 | Establish the repository foundation. | `agent/bootstrap-project-foundation` | Integrated into `main` through pull request 1 |
| P0-W02 | Define branch-linked planning, evidence rules, templates, and prose linting. | `work/p0-w02-work-governance` | Merged into the P0-W01 branch; not integrated into `main` |
| P0-W03 | Add agent-friendly code rules, project invariants, skills, specialist reviewers, and deterministic development checks. | `work/p0-w03-agent-ready-development` | Merged into the P0-W02 branch; not integrated into `main` |
| P0-W04 | Define first-class runs, the navigable run graph, and Project Steward responsibility. | `work/p0-w04-run-graph-stewardship` | Draft pull request 5; implemented but unverified |
| P0-W05 | Audit planning authority, decisions, conflicts, implementation evidence, and document status. | `work/p0-w05-planning-baseline` | In progress; depends on P0-W04 |

**Exit:** a new coding session can identify the project purpose, non-goals, accepted decisions, integration state, invariants, session and run boundaries, Project Steward responsibility, next work package, mutation boundary, acceptance criteria, and required evidence. The session can run one preflight command and one complete quality command.

## Phase 1 — Local execution kernel

**ID:** P1  
**Goal:** prove durable supervised local work before adding an accepted LLM-driven development loop.

### Required behavior

- open one workspace;
- create one session and one root run;
- persist session and run events in SQLite;
- reconstruct session and run state after restart;
- execute one supervised command;
- stream bounded output;
- support timeout and cancellation;
- record termination accurately;
- capture Git state and a repository fingerprint;
- expose state through a basic command-line projection.

### Current proposed work packages

These work packages predate ADRs 0004 and 0005. They remain proposed until the reconciliation pass confirms or replaces them.

| ID | Purpose | Branch | Depends on | Status |
| --- | --- | --- | --- | --- |
| P1-W01 | Define workspace, session, event, execution, fingerprint, and checkpoint types. | `work/p1-w01-session-domain` | P0 | Reconciliation required |
| P1-W02 | Persist append-oriented session events in SQLite and reconstruct a session. | `work/p1-w02-event-journal` | P1-W01 | Reconciliation required |
| P1-W03 | Start, stream, time out, cancel, and record a command. | `work/p1-w03-command-supervision` | P1-W01, P1-W02 | Proposed |
| P1-W04 | Capture Git state and repository fingerprints before and after execution. | `work/p1-w04-git-observation` | P1-W01, P1-W02 | Proposed |
| P1-W05 | Expose session and execution state through the CLI. | `work/p1-w05-cli-projection` | P1-W02, P1-W03, P1-W04 | Reconciliation required |
| P1-W06 | Reconstruct interrupted sessions and report the last known safe state. | `work/p1-w06-restart-recovery` | P1-W02, P1-W03, P1-W04 | Reconciliation required |
| P1-W07 | Execute and record the Phase 1 acceptance scenario. | `work/p1-w07-phase-proof` | P1-W05, P1-W06 | Reconciliation required |

The reconciliation must decide where to prove:

- run identity and lineage;
- fake navigable child runs;
- client-local focus;
- attention routing;
- the first Project Steward projection;
- minimal evidence and acceptance state.

Each accepted work package requires a plan before implementation.

**Exit:** Kiln can create, execute, interrupt, restart, reconstruct, navigate, and accurately report a manual root-run and child-run scenario without a live model.

## Phase 2 — Provider and model loop

**ID:** P2

### Required behavior

- one provider-neutral request and streaming event contract;
- one direct OpenAI-compatible provider adapter;
- model capability discovery or explicit configuration;
- streamed neutral provider events;
- one provider-backed root run;
- read, search, patch or write, and command tools;
- persistent model and tool events;
- context-size accounting;
- cancellation;
- Project Steward control projection;
- completion summary.

The first direct provider target is MiniMax because the project owner has an active Token Plan.

Kimi and Codex require separate managed-client bridge evaluation because platform sign-in is owned by their official clients.

Provider transport experiments MAY begin before Phase 1 is complete on isolated `spike/` branches. Experimental transport code MUST NOT enter the accepted session loop or satisfy Phase 2 until Phase 1 exits.

The reconciliation must decide when the first real read-only child run and independent verifier become accepted behavior.

**Exit:** Kiln completes one small repository change through a provider-backed root Steward run, preserves the session after restart, and reports current evidence and unresolved work.

## Phase 3 — Evidence-backed completion

**ID:** P3

Required:

- observed mutation records;
- project verification commands;
- structured evidence;
- repository-state binding;
- evidence freshness;
- mutation reconciliation;
- unresolved-failure reporting;
- completion readiness;
- `what remains unproven?` inspection;
- independent verifier runs for material completion claims.

**Exit:** a passing test becomes stale after a relevant source change, and Kiln refuses to treat it as current.

## Phase 4 — Context and recovery

**ID:** P4

Required:

- orientation records and freshness;
- context-item provenance;
- deterministic inclusion rules;
- token estimates;
- per-run context manifests;
- checkpoints;
- interruption summaries;
- traceable compaction;
- session and run branching where accepted;
- recovery of the run graph, attention, and Steward projection.

## Phase 5 — Extension protocol

**ID:** P5

Required:

- supervised external processes;
- protocol negotiation;
- tool registration;
- progress and cancellation;
- capability declarations;
- crash isolation;
- one non-Elixir example extension.

## Phase 6 — Phoenix LiveView

**ID:** P6

Required:

- session and workspace views;
- run tree and run navigation;
- model and tool streams;
- global attention view;
- permission prompts;
- interruption;
- Git status and diff;
- verification and context views;
- reconnect without terminating the runtime;
- client-local focus.

## Phase 7 — TypeScript SDK

**ID:** P7

Required:

- typed tool registration;
- schemas;
- capabilities;
- cancellation;
- progress;
- compatibility checks;
- test helpers;
- example extensions.

## Pending roadmap reconciliation

P0-W04 and P0-W05 do not finalize the new proof order.

Before P1-W01 implementation begins, reconcile:

- session and run domain boundaries;
- event-journal scope;
- fake-run interface proof;
- attention and client-focus timing;
- Project Steward vertical slice;
- minimum evidence and acceptance state;
- MiniMax adapter acceptance timing;
- first read-only child run;
- independent verifier timing;
- writing-run isolation;
- version 0.1 completion scenario.

The current authorities, conflicts, gaps, and unknowns are recorded in `docs/PLANNING-BASELINE.md`. The candidate proof order remains in `docs/PLAN-RECONCILIATION.md`.

## Deferred

- Gleam modules;
- Rust sandbox helper;
- Model Context Protocol strategy;
- hosted collaboration;
- plugin registry;
- browser integrated development environment;
- remote execution;
- unlimited delegation depth;
- writing children before isolation;
- automatic Git publication.