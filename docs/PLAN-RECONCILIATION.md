# Plan Reconciliation

**Document type:** Reference  
**Status:** Pending  
**Trigger:** Complete P0-W04 and reconcile before P1-W01 implementation begins.

This document records accepted foundational inputs that require a new roadmap dependency pass.

It does not reorder the roadmap. The next planning pass must produce that change with explicit evidence and exclusions.

## Accepted inputs

The reconciliation must preserve:

1. Elixir and OTP own runtime coordination.
2. A session is the durable boundary for one repository objective.
3. Each session contains one root run.
4. The run graph is the durable execution model for independently inspectable work.
5. The root run carries Project Steward responsibility by default.
6. Logical run lineage is separate from OTP supervision.
7. Each client owns its focused run.
8. Attention routing is independent of run depth.
9. Read-only child runs precede writing child runs.
10. Concurrent writers require worktree or patch isolation.
11. Evidence-backed completion and repository-state binding remain foundational.
12. The first direct provider target is MiniMax.
13. Kimi and Codex platform sign-in require managed-client bridge evaluation.
14. The command-line interface remains independent from Phoenix.
15. Development-agent skills and prompts are not Kiln runtime runs.

## Current conflicts

### Session domain scope

The current P1-W01 work package defines session-domain types but does not include:

- root runs;
- child-run lineage;
- run status;
- attention;
- client focus;
- Project Steward projection.

The next plan must decide whether P1-W01 expands or splits into session-domain and run-domain packages.

### Event-journal scope

The current P1-W02 work package persists session events.

The next plan must decide whether the initial schema persists session and run events together or adds a separate run-event work package.

### Interface proof order

The accepted direction values navigable runs early.

The current roadmap places the first substantial interface after persistence, command supervision, and Git observation.

The next plan must decide whether a fake-run terminal projection should occur before provider integration to prove:

- run tree;
- breadcrumbs;
- parent and child navigation;
- child projections;
- client-local focus;
- global attention.

### Provider proof order

The current Phase 2 plan adds one provider-backed model loop after the execution kernel.

The provider-access spike can proceed in isolation, but the next plan must decide:

- when the first direct MiniMax adapter becomes accepted product code;
- whether the first provider-backed loop creates only the root run;
- when the first real read-only child run becomes available;
- when Kimi ACP and Codex app-server bridges enter the roadmap.

### Steward proof order

The Project Steward requires:

- accepted intent and completion contract;
- run graph;
- repository observations;
- evidence and acceptance projections;
- attention routing;
- deterministic completion constraints.

The next plan must define the smallest vertical Steward slice that can be tested before all later subsystems exist.

### Evidence timing

The current roadmap places full evidence freshness in Phase 3.

The Steward cannot protect completion integrity without at least a minimal acceptance and evidence projection.

The next plan must decide which evidence primitives move earlier without pulling the complete Phase 3 scope into the kernel.

## Required decisions

The reconciliation must decide:

1. the revised Phase 1 work-package boundaries;
2. the first schema for session, run, attention, and event identifiers;
3. the point at which fake navigable runs become executable acceptance criteria;
4. the first terminal interface scope;
5. the first Project Steward vertical slice;
6. the first provider-backed root-run slice;
7. the first real child-run slice;
8. the timing of independent verification;
9. the timing and mechanism of writing-run isolation;
10. the role of MiniMax, Kimi, and Codex in the accepted provider plan;
11. the revised version 0.1 completion scenario;
12. the migration from current work-package identifiers if identifiers change.

## Candidate proof order

This order is proposed for evaluation. It is not accepted roadmap order.

```text
Repository and agent controls
→ workspace, session, run, and event identity
→ append-oriented session and run journal
→ fake navigable root and child runs
→ attention and client-local focus
→ supervised command execution
→ Git observation and repository fingerprints
→ restart recovery
→ direct MiniMax root run
→ Project Steward delivery projection
→ one real read-only Scout child
→ independent Verifier child
→ evidence freshness and completion reconciliation
→ writing-run isolation
→ writing child runs
→ Phoenix projection and additional provider bridges
```

## Reconciliation acceptance criteria

The revised plan should:

- preserve stable work-package identifiers where the purpose remains unchanged;
- introduce new identifiers when one package gains an independent objective;
- identify dependencies explicitly;
- define one observable exit condition for each phase;
- place provider experiments outside accepted product code until their contract is proven;
- keep initial delegation limits explicit;
- include required verification and completion evidence for each work package;
- identify what is deferred from version 0.1;
- explain each change from the current roadmap.

## Required output

The reconciliation pass must update:

- `docs/ROADMAP.md`;
- the Phase 1 work-package map;
- the Phase 2 provider and run plan;
- the version 0.1 definition;
- work-package plan filenames and branches when required;
- architecture diagrams only if the accepted architecture changes;
- ADRs only if the accepted decisions change.
