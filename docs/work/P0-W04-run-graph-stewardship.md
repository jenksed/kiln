# P0-W04: Run Graph and Project Stewardship

**Document type:** Reference  
**Status:** In progress  
**Branch:** `work/p0-w04-run-graph-stewardship`  
**Depends on:** P0-W03 agent-ready development controls

## Objective

Define the run graph and Project Steward as foundational Kiln concepts before implementation planning is reconciled.

## Observed current state

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| Kiln currently defines a session as one durable repository objective. | `docs/SESSION-MODEL.md` on `work/p0-w03-agent-ready-development` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln currently centers one model-driven worker and defers bounded review or verification workers. | `docs/PROJECT-PROVENANCE.md` on `work/p0-w03-agent-ready-development` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln does not currently define a first-class run, run graph, client-local run focus, or depth-independent attention routing. | `docs/ARCHITECTURE.md` and `docs/SESSION-MODEL.md` on `work/p0-w03-agent-ready-development` | ChatGPT GitHub connector | 2026-07-28 |
| The project owner has accepted navigable delegated runs as a foundational interaction and execution model. | User-provided run-graph direction | Project owner | 2026-07-28 |
| The project owner requires a Project Steward that coordinates work toward quality, working, specification-conformant applications. | Current user instruction | Project owner | 2026-07-28 |
| Kiln already prohibits agent-manager hierarchies and treats work as the central abstraction. | `docs/PROJECT-INVARIANTS.md`, `KILN-INV-001` | ChatGPT GitHub connector | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W04-A01:** A session remains the durable boundary for one repository objective.
- **P0-W04-A02:** A run is the durable boundary for one independently inspectable unit of work within a session.
- **P0-W04-A03:** Each session has one root run.
- **P0-W04-A04:** The root run carries Project Steward responsibility by default.
- **P0-W04-A05:** The Project Steward is a delivery responsibility, not an artificial employee persona.
- **P0-W04-A06:** Logical run lineage and OTP supervision require separate models.
- **P0-W04-A07:** Deterministic services retain authority for policy, evidence freshness, repository state, and completion gates.

### Unknowns

- **P0-W04-U01:** Unknown. The exact Phase 1 and Phase 2 work-package order must be reconciled after these decisions are accepted. Verify with a roadmap dependency review.
- **P0-W04-U02:** Unknown. The first terminal user interface library remains unselected. Verify with a bounded headless-navigation spike.
- **P0-W04-U03:** Unknown. The exact durable event granularity for streamed output requires implementation evidence.
- **P0-W04-U04:** Unknown. The first release that enables a real child run depends on execution-kernel and provider evidence.
- **P0-W04-U05:** Unknown. The initial default limits for depth, concurrency, token budget, and elapsed time require dogfooding evidence.

## Requirements

- **P0-W04-R01:** Each session shall contain one root run.
- **P0-W04-R02:** When Kiln delegates an independently inspectable task, Kiln shall create a child run.
- **P0-W04-R03:** Each run shall have an identifier, session identifier, root run identifier, optional parent run identifier, status, capability profile, execution reference, and creation time.
- **P0-W04-R04:** Kiln shall store logical run lineage independently from OTP supervision relationships.
- **P0-W04-R05:** Each run shall own or reference its context, transcript projection, artifacts, evidence, resource accounting, cancellation state, and attention state.
- **P0-W04-R06:** Each client shall store its focused run independently from the session and other clients.
- **P0-W04-R07:** When any run requires user input, permission, conflict resolution, or failure handling, Kiln shall emit a normalized attention event.
- **P0-W04-R08:** Delegated work shall remain inspectable from its parent and through direct run queries.
- **P0-W04-R09:** Kiln shall not represent the run graph as an organization chart or a hierarchy of manager agents.
- **P0-W04-R10:** The root run shall carry Project Steward responsibility unless the user selects another supported control mode.
- **P0-W04-R11:** The Project Steward shall maintain traceability from intent and accepted specifications to runs, changes, verification, evidence, unresolved risks, and completion readiness.
- **P0-W04-R12:** The Project Steward shall use bounded delegation only when delegation improves evidence, parallelism, specialization, or independent review.
- **P0-W04-R13:** The Project Steward shall not override user authority, capability policy, repository truth, evidence freshness, or completion gates.
- **P0-W04-R14:** The Project Steward shall disclose blocked work, material uncertainty, failed verification, and unresolved specification gaps.
- **P0-W04-R15:** Kiln shall not allow concurrent writing runs to modify one checkout.
- **P0-W04-R16:** Before writing child runs are enabled, Kiln shall provide isolated Git worktrees or patch artifacts that a controlling run applies.
- **P0-W04-R17:** The event journal shall record run creation, status changes, child creation, attention, artifacts, completion, failure, cancellation, and stewardship decisions that affect delivery.
- **P0-W04-R18:** The roadmap shall place run-graph and stewardship proof before broad delegation, extension, or interface expansion.

## Proposed changes

1. Revise project provenance to define the session, run graph, and Project Steward.
2. Add a run-model reference.
3. Add a Project Steward reference.
4. Revise architecture diagrams and runtime ownership rules.
5. Revise the session model to contain a root run and durable run graph.
6. Record separate architecture decisions for the run graph and Project Steward.
7. Add project invariants for inspectable delegated runs, lineage separation, client-local focus, attention routing, stewardship authority, and write isolation.
8. Update agent instructions so future implementation preserves these concepts.
9. Update the roadmap with P0-W04 and a pending reconciliation section.
10. Add a plan-reconciliation document for the next planning pass.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `docs/work/P0-W04-run-graph-stewardship.md` | Record this work package. | Added |
| `docs/RUN-MODEL.md` | Define runs, lineage, status, events, focus, attention, and isolation. | Proposed |
| `docs/PROJECT-STEWARDSHIP.md` | Define Project Steward responsibility, authority, workflow, and limits. | Proposed |
| `docs/PROJECT-PROVENANCE.md` | Replace single-worker framing with session, runs, and stewardship. | Proposed |
| `docs/ARCHITECTURE.md` | Add the run graph and separate it from OTP supervision. | Proposed |
| `docs/SESSION-MODEL.md` | Define the root run and session ownership of the run graph. | Proposed |
| `docs/decisions/0004-first-class-run-graph.md` | Record the run-graph decision. | Proposed |
| `docs/decisions/0005-project-steward.md` | Record the stewardship decision. | Proposed |
| `docs/decisions/README.md` | Index ADRs 0004 and 0005. | Proposed |
| `docs/PROJECT-INVARIANTS.md` | Add run and stewardship invariants. | Proposed |
| `docs/ROADMAP.md` | Add P0-W04 and pending reconciliation constraints. | Proposed |
| `docs/PLAN-RECONCILIATION.md` | Record required roadmap decisions. | Proposed |
| `AGENTS.md` | Add run-model and stewardship implementation rules. | Proposed |

## Acceptance criteria

- **P0-W04-AC01**
  - **Given** the foundational project documents
  - **When** a coding session explains workspace, session, root run, child run, and Project Steward
  - **Then** the explanation identifies the session as the objective boundary, the run graph as the execution model, and the Steward as the delivery coordinator
  - **Evidence:** matching definitions across provenance, architecture, session, run, and stewardship documents

- **P0-W04-AC02**
  - **Given** a child run with a logical parent
  - **When** the architecture describes runtime supervision
  - **Then** the architecture does not require the logical parent to supervise the child process
  - **Evidence:** ADR 0004 and architecture inspection

- **P0-W04-AC03**
  - **Given** two clients attached to one session
  - **When** each client focuses a different run
  - **Then** neither focus change alters the other client or session execution
  - **Evidence:** run-model focus rules

- **P0-W04-AC04**
  - **Given** a nested run that requires input
  - **When** the run emits attention
  - **Then** Kiln routes the attention independently of nesting depth and supports direct response or navigation
  - **Evidence:** run-model attention contract

- **P0-W04-AC05**
  - **Given** a proposed writing child
  - **When** the child would share an active checkout with another writer
  - **Then** project rules prohibit execution until a worktree or patch-artifact boundary exists
  - **Evidence:** run-model and invariant inspection

- **P0-W04-AC06**
  - **Given** an active Project Steward
  - **When** acceptance criteria lack current evidence or material specification gaps remain
  - **Then** the Steward cannot report the project objective as complete and must disclose the gap
  - **Evidence:** stewardship contract and ADR 0005

- **P0-W04-AC07**
  - **Given** the current roadmap
  - **When** the next planning pass begins
  - **Then** the roadmap identifies the run graph and Project Steward as foundational and lists unresolved sequencing decisions
  - **Evidence:** roadmap and plan-reconciliation document

## Verification commands

```bash
scripts/agent-preflight
scripts/validate-agent-assets
vale .
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

Each command must exit with status `0`.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W04-E01 | P0-W04-AC01 | Matching definitions across five foundational documents. |
| P0-W04-E02 | P0-W04-AC02 | ADR and architecture text that separates lineage from supervision. |
| P0-W04-E03 | P0-W04-AC03 | Client-local focus rules. |
| P0-W04-E04 | P0-W04-AC04 | Normalized attention contract and events. |
| P0-W04-E05 | P0-W04-AC05 | Writing-run isolation rule and invariant. |
| P0-W04-E06 | P0-W04-AC06 | Steward authority and completion limits. |
| P0-W04-E07 | P0-W04-AC07 | Roadmap reconciliation section. |
| P0-W04-E08 | All | Passing CI for the final branch head. |

## Explicit exclusions

- run-process implementation;
- SQLite run tables or migrations;
- terminal user interface implementation;
- provider integration;
- actual child execution;
- unlimited delegation depth;
- concurrent child writes to one checkout;
- automatic merging;
- selecting the final terminal user interface library;
- final roadmap reordering before reconciliation.

## Completion record

**Result:** Implemented but unverified

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| P0-W04-AC01 | In progress | P0-W04-E01 | Foundational documents pending. |
| P0-W04-AC02 | In progress | P0-W04-E02 | ADR and architecture update pending. |
| P0-W04-AC03 | In progress | P0-W04-E03 | Run-model focus rules pending. |
| P0-W04-AC04 | In progress | P0-W04-E04 | Attention contract pending. |
| P0-W04-AC05 | In progress | P0-W04-E05 | Isolation rule pending. |
| P0-W04-AC06 | In progress | P0-W04-E06 | Stewardship contract pending. |
| P0-W04-AC07 | In progress | P0-W04-E07 | Reconciliation record pending. |

### Verification executed

No verification has run for the current branch head.

### Failures and warnings

- None observed through execution because verification has not run.

### Remaining unknowns and exclusions

- P0-W04-U01 through P0-W04-U05 remain open.
- Implementation and final roadmap reordering remain excluded.

### Repository state

- Commit: Unknown until the work package is complete.
- Branch: `work/p0-w04-run-graph-stewardship`
- Diff reviewed: No
