# Roadmap

**Document type:** Reference

The roadmap is ordered by proof, not platform ambition.

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
**Goal:** establish project identity, constraints, documentation, basic Elixir structure, CI, work governance, and coding-agent controls.

### Work packages

| ID | Purpose | Branch | Status |
| --- | --- | --- | --- |
| P0-W01 | Establish the repository foundation. | `agent/bootstrap-project-foundation` | Draft PR; bootstrap exception |
| P0-W02 | Define branch-linked planning, evidence rules, templates, and prose linting. | `work/p0-w02-work-governance` | Complete on stacked branch; draft PR |
| P0-W03 | Add agent-friendly code rules, project invariants, skills, specialist reviewers, and deterministic development checks. | `work/p0-w03-agent-ready-development` | In progress |

**Exit:** a new coding session can identify the purpose, non-goals, accepted decisions, project invariants, next work package, mutation boundary, acceptance criteria, and required evidence. The session can run one preflight command and one complete quality command.

## Phase 1 — Local execution kernel

**ID:** P1  
**Goal:** prove durable supervised local work before adding an LLM to the development loop.

### Required behavior

- open one workspace;
- create one session;
- persist events in SQLite;
- reconstruct a session after restart;
- execute one supervised command;
- stream bounded output;
- support timeout and cancellation;
- record termination accurately;
- capture Git state and a repository fingerprint;
- expose state through a basic CLI.

### Proposed work packages

| ID | Purpose | Branch | Depends on | Status |
| --- | --- | --- | --- | --- |
| P1-W01 | Define workspace, session, event, execution, fingerprint, and checkpoint types. | `work/p1-w01-session-domain` | P0 | Proposed |
| P1-W02 | Persist append-oriented session events in SQLite and reconstruct a session. | `work/p1-w02-event-journal` | P1-W01 | Proposed |
| P1-W03 | Start, stream, time out, cancel, and record a command. | `work/p1-w03-command-supervision` | P1-W01, P1-W02 | Proposed |
| P1-W04 | Capture Git state and repository fingerprints before and after execution. | `work/p1-w04-git-observation` | P1-W01, P1-W02 | Proposed |
| P1-W05 | Expose session and execution state through the CLI. | `work/p1-w05-cli-projection` | P1-W02, P1-W03, P1-W04 | Proposed |
| P1-W06 | Reconstruct interrupted sessions and report the last known safe state. | `work/p1-w06-restart-recovery` | P1-W02, P1-W03, P1-W04 | Proposed |
| P1-W07 | Execute and record the Phase 1 acceptance scenario. | `work/p1-w07-phase-proof` | P1-W05, P1-W06 | Proposed |

Each proposed work package requires an accepted plan before implementation.

**Exit:** Kiln can execute, interrupt, restart, reconstruct, and accurately report a manual development action.

## Phase 2 — Provider and model loop

**ID:** P2

### Required behavior

- one provider-neutral request and streaming event contract;
- one direct OpenAI-compatible provider adapter;
- model capability discovery or explicit configuration;
- streamed neutral provider events;
- read, search, patch or write, and command tools;
- one model request at a time;
- persistent model and tool events;
- context-size accounting;
- cancellation;
- completion summary.

The first direct provider target is MiniMax because the project owner has an active Token Plan. Kimi and Codex require separate managed-client bridge evaluation because platform sign-in is owned by their official clients.

Provider transport experiments MAY begin before Phase 1 is complete on isolated `spike/` branches. Experimental transport code MUST NOT enter the main session loop or satisfy Phase 2 until Phase 1 exits.

**Exit:** Kiln completes one small repository change through the accepted provider contract and resumes after restart.

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
- `what remains unproven?` inspection.

**Exit:** a passing test becomes stale after a relevant source change, and Kiln refuses to treat it as current.

## Phase 4 — Context and recovery

**ID:** P4

Required:

- orientation records and freshness;
- context-item provenance;
- deterministic inclusion rules;
- token estimates;
- checkpoints;
- interruption summaries;
- traceable compaction;
- session branching.

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
- model and tool streams;
- permission prompts;
- interruption;
- Git status and diff;
- verification and context views;
- reconnect without terminating the runtime.

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

## Deferred

- Gleam modules;
- Rust sandbox helper;
- MCP strategy;
- hosted collaboration;
- plugin registry;
- browser IDE;
- remote execution;
- multi-worker delegation;
- automated Git publication.
