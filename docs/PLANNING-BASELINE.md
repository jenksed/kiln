# Planning Baseline

**Document type:** Reference  
**Status:** Authoritative planning-status map for this branch  
**Audit date:** 2026-07-28  
**Audited branch:** `work/p0-w04-run-graph-stewardship`  
**Audited commit:** `c5a919f32d422ccc1a5371afd955172a8a0a20c5`

## Purpose

This document defines the planning baseline before the next architecture or roadmap pass.

This document does not redesign Kiln. It records the current product, accepted decisions, proposed decisions, conflicts, unknowns, and implementation evidence.

This document uses these status terms:

- **Observed:** Repository evidence shows that the statement is true.
- **Accepted:** The project owner or an integrated architecture decision record establishes the decision.
- **Integrated:** The decision or artifact is on `main`.
- **Proposed:** A branch document or work package requests the decision, but the decision is not integrated.
- **Provisional:** The project uses the direction for planning, but implementation evidence can change it.
- **Exploratory:** The project is evaluating the direction.
- **Implemented:** Source or configuration exists in the repository.
- **Verified:** Current checks passed against the stated repository state.
- **Unknown:** Current evidence does not answer the question.
- **Superseded:** A later decision replaces the statement.

A statement can have more than one status. For example, a decision can be accepted by the owner but not integrated into `main`.

## Baseline verdict

Kiln has a strong product thesis and a coherent set of runtime principles. The repository does not yet have one integrated planning source of truth.

`main` contains the accepted project foundation from pull request 1. The active planning stack contains later governance, development-agent, run-graph, and Project Steward work. Pull requests 3 and 4 merged into intermediate branches. Pull request 5 is an open draft. These changes are not integrated into `main`.

The current planning stack also contains stale status statements. Some documents call decisions accepted while the pull request remains draft and unverified. The P0-W04 work plan still calls completed document changes pending. The current CI run failed before Elixir checks ran.

The next pass must reconcile status and roadmap order. It must not add more architecture until these conflicts are resolved.

## Current product definition

Kiln is a local-first runtime for AI-assisted software development.

Kiln hosts bounded model-driven and deterministic runs. It mediates capabilities. It supervises external execution. It assembles context. It records evidence against repository state. It coordinates one repository objective toward verified completion while it preserves user authority.

This definition describes intended product responsibilities. It does not claim that these capabilities exist in the current implementation.

Kiln uses work as the central abstraction. It does not use an artificial organization of agents as the central abstraction.

### Product-position evaluation

| Proposed position | Result | Evidence |
| --- | --- | --- |
| Local-first agent host | Supported with terminology limits. The repository uses `run` for an independently inspectable unit of work. It does not define `agent` as the durable domain object. | `docs/RUN-MODEL.md`; ADR 0004 |
| Capability broker | Supported as planned architecture. Explicit capability mediation is accepted. A broker implementation does not exist. | `docs/SECURITY-MODEL.md`; `docs/ARCHITECTURE.md`; `docs/PROJECT-INVARIANTS.md` |
| Execution supervisor | Supported as a required product responsibility. Command supervision is planned for Phase 1. It is not implemented. | `docs/ROADMAP.md`; `docs/ARCHITECTURE.md` |
| Context system | Supported as planned product scope. The repository does not yet define a complete context contract. | `docs/ARCHITECTURE.md`; Phase 4 in `docs/ROADMAP.md` |
| Evidence system | Accepted as a foundational principle. Evidence collection, freshness, and repository binding are not implemented. | ADR 0002; `KILN-INV-007`; Phase 3 in `docs/ROADMAP.md` |
| Build real software | Supported. The project centers repository objectives, mutations, verification, and completion. | `docs/PROJECT-PROVENANCE.md`; `docs/PROJECT-STEWARDSHIP.md` |

The phrase `agent host` can be used in external product language only when the glossary defines an agent as a model-backed run or worker. Internal architecture must continue to use `run`, `tool execution`, and `model request` as separate terms.

### Confirmed non-goals

Kiln is not primarily:

- an agent-framework abstraction layer;
- an autonomous agent organization;
- a manager-agent hierarchy;
- a generic chatbot;
- an application scaffolder;
- a hosted collaboration service;
- a plugin marketplace;
- a browser integrated development environment;
- a replacement for Git.

Evidence: `docs/PROJECT-PROVENANCE.md`, `docs/PROJECT-INVARIANTS.md`, ADR 0004, and ADR 0005.

The repository does not yet state these non-goals with enough precision:

- Kiln is not a catalog of protocol implementations.
- Kiln does not replace language servers.
- Kiln does not replace build systems.
- Kiln does not replace mature command-line tools.

Add these statements during product-document reconciliation. Do not add protocol adapters only to increase protocol coverage.

## Source-of-truth map

### Repository integration truth

`main` is the integrated project truth. This rule comes from `docs/BRANCHING-AND-WORK-PLANNING.md`.

Observed integrated baseline:

- `main` includes pull request 1 at merge commit `10089b00c2c944e1858d54d900fcba0faa055500`.
- `main` does not include the complete P0-W02, P0-W03, or P0-W04 planning stack.

The active candidate baseline is the head of pull request 5 at `c5a919f32d422ccc1a5371afd955172a8a0a20c5`.

### Planning authority by subject

| Subject | Authoritative document | Status and limit |
| --- | --- | --- |
| Planning status and document relationships | `docs/PLANNING-BASELINE.md` | Authoritative on this branch. It does not replace product or architecture detail. |
| Product purpose and boundaries | `docs/PROJECT-PROVENANCE.md` | Product authority on the active planning branch. The corresponding `main` version remains integrated truth until the stack merges. |
| Architecture | `docs/ARCHITECTURE.md` plus accepted ADRs | Architecture authority. Diagrams and candidate processes remain provisional unless an ADR accepts them. |
| Implementation order | `docs/ROADMAP.md` | Roadmap authority, but Phase 1 and Phase 2 order is explicitly unresolved. |
| Session contract | `docs/SESSION-MODEL.md` | Foundational direction. No implementation exists. |
| Run contract | `docs/RUN-MODEL.md` | Owner-accepted direction in draft pull request 5. Not integrated. |
| Project Steward responsibility | `docs/PROJECT-STEWARDSHIP.md` | Owner-accepted direction in draft pull request 5. Not integrated. |
| Security and capabilities | `docs/SECURITY-MODEL.md` | Initial threat-model direction. It is not a sandbox claim. |
| Stable project constraints | `docs/PROJECT-INVARIANTS.md` | Constraint register for the active planning branch. Invariants 015 through 022 depend on draft ADRs 0004 and 0005. |
| Architecture decisions | `docs/decisions/` | Decision authority. Repository integration status must be recorded separately from ADR status. |
| Work-package execution contract | Matching file in `docs/work/` | Authority for one branch objective, acceptance criteria, and evidence. |
| Branch and merge policy | `docs/BRANCHING-AND-WORK-PLANNING.md` | Process authority. Its Phase 1 branch map is stale and must defer to the reconciled roadmap. |
| Actual product capability | Source, tests, executed checks, and current CI | Documentation cannot prove implementation. |
| Development-agent controls | `.agents/`, `.pi/`, scripts, and related docs | These assets help build Kiln. They are not Kiln runtime capabilities. |

### Current product, architecture, and roadmap documents

- **Product:** `docs/PROJECT-PROVENANCE.md`
- **Architecture:** `docs/ARCHITECTURE.md` and `docs/decisions/`
- **Roadmap:** `docs/ROADMAP.md`
- **Planning-status map:** `docs/PLANNING-BASELINE.md`

No other document may silently override these roles.

## Implementation reality

### Observed implementation

At the audited commit, Kiln has:

- one Elixir Mix project;
- application version `0.1.0-dev`;
- one empty OTP supervisor;
- one test for the version function;
- no third-party runtime dependencies;
- CI configuration;
- prose checks;
- development-agent preflight and asset-validation scripts;
- project-local development skills, prompts, and read-only specialist reviewers.

Evidence:

- `mix.exs`
- `lib/kiln.ex`
- `lib/kiln/application.ex`
- `test/kiln_test.exs`
- `.github/workflows/ci.yml`
- `scripts/agent-preflight`
- `scripts/validate-agent-assets`
- pull requests 1, 3, 4, and 5

### Capabilities that are not implemented

Repository evidence does not show an implementation for:

- workspace opening;
- durable sessions;
- SQLite storage;
- event reconstruction;
- root or child runs;
- Project Steward logic;
- command supervision;
- streaming command output;
- timeout or cancellation;
- Git observation or repository fingerprints;
- a product CLI or TUI;
- provider access;
- a capability broker;
- context assembly;
- evidence freshness;
- completion gates;
- an extension protocol;
- Phoenix LiveView;
- a TypeScript SDK;
- MCP, LSP, or ACP adapters.

Do not describe these items as existing Kiln features.

### Current verification state

GitHub Actions run `30332448342` evaluated pull request 5.

Observed result:

- prose job: passed;
- agent preflight test: passed;
- agent asset validation: failed;
- dependency install: skipped;
- Elixir format check: skipped;
- warnings-as-errors compilation: skipped;
- compile-connected cycle check: skipped;
- ExUnit tests: skipped.

The active P0-W04 branch is implemented but unverified. No completion claim is valid for that branch head.

## Glossary

### Agent

A model-backed worker that performs reasoning or generation. `Agent` is not the primary durable domain object. A model-backed worker operates within a run.

### Agent host

The product responsibility that starts, observes, interrupts, and recovers model-backed work. Internal documents should express this responsibility through runs, model requests, and execution processes.

### Capability

A named permission to read, write, execute, access a network host, use a secret, or perform another controlled action.

### Capability broker

The deterministic service that evaluates capability requests against policy. The term describes planned architecture. No broker implementation exists.

### Context

The selected information that a run can use. Context must have provenance, inclusion rules, size accounting, and freshness. The complete context contract is unknown.

### Evidence

A structured record that supports or rejects a claim. Evidence must identify the repository state, command or observation, result, and freshness.

### Execution

A supervised external action, such as a command, tool process, model request, or extension process. Execution is not the same as a run.

### Project Steward

The constrained delivery responsibility on the root run. It maintains traceability and recommends continuation, blocking, or completion. It does not own repository truth or evidence truth.

### Run

One independently inspectable unit of work in a session. A run has lineage, status, capabilities, context, artifacts, evidence, resource accounting, cancellation state, and attention state.

### Session

One durable attempt to move one repository objective toward verified completion. A session owns one root run and one run graph in the proposed P0-W04 model.

### Tool execution

One invocation of a deterministic or external tool. A tool execution can occur within a run. A tool execution is not automatically a child run.

### Transcript

A conversational projection. It is not the canonical session or run record.

### Verification

An evaluation of acceptance criteria against a stated repository state.

### Workspace

The local repository and its operating boundary.

## Accepted-decisions register

### Integrated accepted decisions

| ID | Decision | Evidence |
| --- | --- | --- |
| AD-001 | Elixir and OTP own the initial runtime. | ADR 0001 on `main` |
| AD-002 | Use processes only for state, resources, concurrency, cancellation, isolation, or external communication. | ADR 0001 |
| AD-003 | Use an append-oriented durable journal separate from transcript projections. | ADR 0002 on `main` |
| AD-004 | Use SQLite for the first durable journal. | ADR 0002 |
| AD-005 | Git and the filesystem remain source truth for repository state. | ADR 0002; project provenance |
| AD-006 | Use a versioned language-neutral protocol over supervised external processes for the primary public extension boundary. | ADR 0003 on `main` |
| AD-007 | The initial product serves one developer on local repositories. | Project provenance on `main` |
| AD-008 | The command-line interface is the initial interface and must remain usable without Phoenix. | README and project provenance on `main` |
| AD-009 | Evidence-backed completion is foundational. | Project provenance, session model, and AGENTS on `main` |
| AD-010 | Kiln does not use an agent-manager hierarchy as the central abstraction. | Project provenance and AGENTS on `main` |
| AD-011 | Version 0.1 remains one Mix project until evidence justifies an umbrella. | Architecture on `main` |

### Owner-accepted decisions that are not integrated

These decisions have explicit owner-acceptance evidence in P0-W04. They remain unintegrated because pull request 5 is draft.

| ID | Decision | Evidence and integration state |
| --- | --- | --- |
| AD-012 | A session has one root run and one durable run graph. | P0-W04 observation; ADR 0004; draft PR 5 |
| AD-013 | Independently inspectable delegated work becomes a child run. | ADR 0004; draft PR 5 |
| AD-014 | Logical run lineage is separate from OTP supervision. | ADR 0004; draft PR 5 |
| AD-015 | Client focus is local to each client. | ADR 0004; draft PR 5 |
| AD-016 | Attention routing is independent of run depth. | ADR 0004; draft PR 5 |
| AD-017 | Concurrent writing runs require worktree or patch isolation. | ADR 0004; draft PR 5 |
| AD-018 | The root run carries Project Steward responsibility by default. | P0-W04 observation; ADR 0005; draft PR 5 |
| AD-019 | The Project Steward cannot override user authority, policy, repository truth, evidence freshness, or completion gates. | ADR 0005; draft PR 5 |

### Provisional decisions

| ID | Direction | Reason it remains provisional |
| --- | --- | --- |
| PD-001 | The exact OTP supervision tree in `docs/ARCHITECTURE.md`. | The document calls the structure directional. No runtime implementation exists. |
| PD-002 | Candidate domain commands, queries, and event names. | No implemented domain API or persistence schema exists. |
| PD-003 | Initial child depth and concurrency limits. | The documents require dogfooding evidence. |
| PD-004 | Read-only child runs before writing child runs. | Accepted as proof order, but exact milestone is unresolved. |
| PD-005 | MiniMax as the first direct provider adapter. | The roadmap states the target, but no dedicated ADR or provider contract exists. |
| PD-006 | Kimi and Codex managed-client bridges. | Evaluation is pending. |
| PD-007 | Phoenix LiveView after the runtime is proven. | Planned interface, not implemented. |
| PD-008 | TypeScript as the first external SDK. | ADR 0003 defers the SDK until the protocol is proven. |
| PD-009 | Context engine structure and Phase 4 scope. | The context contract is incomplete. |
| PD-010 | The candidate proof order in `docs/PLAN-RECONCILIATION.md`. | The document states that the order is not accepted. |

### Exploratory or deferred decisions

- Gleam modules;
- Rust sandbox or pseudo-terminal helper;
- MCP strategy;
- LSP integration strategy;
- ACP client strategy beyond current references;
- hosted collaboration;
- plugin registry;
- browser integrated development environment;
- remote execution;
- unlimited delegation depth;
- automatic Git publication.

## Conflict register

### CF-001: `main` authority conflicts with the active planning stack

`docs/BRANCHING-AND-WORK-PLANNING.md` states that `main` is integrated project truth. P0-W02, P0-W03, and P0-W04 are not integrated into `main` as one stack.

**Impact:** A coding session can read different product and architecture definitions based on branch.

**Required resolution:** Merge or rebase the stack in dependency order. Update pull-request bases after each prerequisite merges.

### CF-002: ADR status does not show repository integration state

ADRs 0004 and 0005 say `Accepted`. Pull request 5 is a draft and is not integrated.

**Impact:** A reader can interpret accepted as integrated.

**Required resolution:** Keep decision status and repository integration as separate fields in the ADR index or planning baseline.

### CF-003: Phase 1 and Phase 2 plans predate the run and Steward decisions

The roadmap states that current work-package boundaries require reconciliation.

**Impact:** The roadmap cannot yet function as an executable implementation sequence.

**Required resolution:** Complete the planned roadmap reconciliation before P1-W01 begins.

### CF-004: P0-W04 work-plan status is stale

The P0-W04 plan says foundational documents are pending. The files exist in the branch. The plan also says no verification has run. CI did run and failed.

**Impact:** The work plan does not describe current branch state.

**Required resolution:** Update the P0-W04 completion record with the actual files, branch commit, CI run, failure, and skipped checks.

### CF-005: Phase 0 status labels are inconsistent

The roadmap calls P0-W02 complete on a stacked branch and calls P0-W03 in progress, although pull requests 3 and 4 are recorded as merged into intermediate branches. P0-W04 is in progress and unverified.

**Impact:** `Complete`, `merged`, `integrated`, and `verified` are used as if they mean the same state.

**Required resolution:** Use separate columns for implementation, verification, pull-request state, and `main` integration.

### CF-006: Product terminology is inconsistent

The repository uses `coding harness`, `durable runtime`, `agent host`, `run graph`, `model-driven worker`, `execution engine`, `execution supervisor`, `tool supervisor`, `capability broker`, and `permission broker`.

**Impact:** Components and responsibilities can appear to be separate products when they are synonyms or layers.

**Required resolution:** Use the glossary in this document. Select one term for each domain concept during document reconciliation.

### CF-007: Provisional architecture appears concrete

The architecture diagram names registries, engines, supervisors, brokers, and projections. The same document says implementation details remain provisional.

**Impact:** A coding agent can create components because they appear in the diagram, not because a requirement needs them.

**Required resolution:** Mark candidate components in diagrams and require a work-package requirement before implementation.

### CF-008: Evidence is foundational but full evidence work is late

Evidence-backed completion is a foundational decision. Full evidence freshness is in Phase 3. The Project Steward requires minimum evidence and acceptance state earlier.

**Impact:** The first provider-backed flow could claim completion before the evidence model exists.

**Required resolution:** Define a minimum evidence slice in Phase 1 or Phase 2. Keep advanced freshness and reconciliation in Phase 3.

### CF-009: Provider priority lacks a decision boundary

The roadmap names MiniMax as the first direct provider. The planning set also references Kimi and Codex bridges. No provider ADR defines the direct-provider contract or managed-client boundary.

**Impact:** Experimental provider work can become accepted architecture without a stable contract.

**Required resolution:** Record the provider contract and acceptance boundary before provider code enters the accepted loop.

### CF-010: The active branch is not verified

CI run `30332448342` failed at agent asset validation. The Elixir checks did not run.

**Impact:** The branch cannot report P0-W04 complete.

**Required resolution:** Fix or reconcile the asset validation failure, rerun all checks, and bind the result to the final branch commit.

### CF-011: Planning order is duplicated

The Phase 1 map exists in both `docs/ROADMAP.md` and `docs/BRANCHING-AND-WORK-PLANNING.md`.

**Impact:** The two maps can drift.

**Required resolution:** Keep roadmap order only in `docs/ROADMAP.md`. Keep naming examples and rules in the branching document.

### CF-012: Capability mediation has no accepted domain contract

Security, architecture, run, and Steward documents use capability profiles and a broker. No ADR defines capability identity, inheritance, grant lifetime, denial, revocation, or audit semantics.

**Impact:** Security-critical behavior can be designed ad hoc during implementation.

**Required resolution:** Add a capability-policy decision before capability enforcement implementation.

## Superseded-decision and document register

### Superseded statements

| Item | Superseded by | Status |
| --- | --- | --- |
| The earlier framing of one model-driven worker as the complete execution model. | ADR 0004 and ADR 0005 on the P0-W04 branch. | Owner-accepted, not integrated |
| Phase 1 types that omit run, attention, client-focus, and Steward state. | P0-W04 requirements and `docs/PLAN-RECONCILIATION.md`. | Requires roadmap replacement |
| The P0-W04 expected-file table that marks existing files as proposed or pending. | The observed branch contents. | Stale planning text |
| The claim that no P0-W04 verification has run. | GitHub Actions run `30332448342`. | Superseded by failed CI evidence |

### Documents to retain

Retain these documents with one clear purpose:

- `README.md` as the entry point;
- `AGENTS.md` as coding-session instructions;
- `docs/PROJECT-PROVENANCE.md` as product authority;
- `docs/ARCHITECTURE.md` as architecture authority;
- `docs/SESSION-MODEL.md` as session reference;
- `docs/RUN-MODEL.md` as run reference;
- `docs/PROJECT-STEWARDSHIP.md` as Steward explanation and constraints;
- `docs/SECURITY-MODEL.md` as threat-model direction;
- `docs/PROJECT-INVARIANTS.md` as stable constraint register;
- `docs/ROADMAP.md` as the only implementation-order authority;
- `docs/decisions/` as the decision record;
- `docs/work/` as work-package evidence;
- `docs/ENGINEERING-QUALITY-RULES.md` as writing and evidence rules;
- `docs/BRANCHING-AND-WORK-PLANNING.md` as branch and work-package policy.

### Documents or sections to merge

- Move repeated product-definition text from `README.md` and `AGENTS.md` into concise references to `docs/PROJECT-PROVENANCE.md`.
- Keep the accepted-decision summary in the ADR index. Do not repeat full decision content in the roadmap.
- Remove the Phase 1 schedule from the branching document after the roadmap reconciliation. Link to the roadmap.
- Merge provider-priority statements into one provider decision and one roadmap section.

### Documents or sections to replace

- Replace the current Phase 1 and Phase 2 work-package map after the reconciliation pass.
- Replace `docs/PLAN-RECONCILIATION.md` with the reconciled roadmap and a short historical completion note after the pass completes.
- Replace stale completion records in P0-W03 and P0-W04 with current evidence.

### Documents to archive

Do not archive a current source document during this pass.

After the planning stack integrates, preserve completed work-package plans as historical evidence. Do not treat them as current product or architecture authority.

## Unresolved architectural questions

1. What is the minimum version 0.1 completion scenario?
2. Which session, run, event, attention, and client identifiers exist in the first schema?
3. Does the initial journal use one event table or separate session and run streams?
4. Which event ordering and idempotency rules are mandatory?
5. What is the minimum evidence model that must exist before the first provider-backed completion claim?
6. What is the first terminal interface: line-oriented CLI, TUI, or both?
7. Which TUI library, if any, meets navigation and streaming needs?
8. What deterministic service creates the Project Steward projection?
9. Which Steward actions are model decisions and which are deterministic transitions?
10. What is the capability-policy contract?
11. How do capability grants inherit, expire, revoke, and audit?
12. What is the provider-neutral request and event contract?
13. What distinguishes direct provider adapters from managed-client bridges?
14. When does MiniMax move from experiment to accepted product code?
15. What is the first real child-run acceptance scenario?
16. When is independent verification mandatory?
17. What evidence justifies writing child runs?
18. Which worktree or patch-isolation mechanism is selected?
19. What is the context-item contract for provenance, freshness, inclusion, and compaction?
20. How will Kiln use LSP, MCP, and ACP without becoming a protocol catalog?
21. Which mature tools must Kiln invoke rather than replace?
22. What repository fingerprint invalidates each evidence type?
23. What recovery state applies to an external process with unknown termination state?
24. How does the project record owner acceptance before branch integration?

## Planning gaps

- No integrated planning baseline exists on `main`.
- No canonical glossary existed before this document.
- No version 0.1 completion contract exists.
- The roadmap does not yet map every product responsibility to a work package.
- The Phase 1 and Phase 2 dependency graph is unresolved.
- The context system lacks a domain contract.
- Capability policy lacks an ADR.
- Provider boundaries lack an ADR.
- Minimum evidence primitives are not scheduled early enough.
- LSP, MCP, and ACP boundaries are not defined.
- The product non-goals do not explicitly protect mature language servers, build systems, and command-line tools from replacement work.
- Documentation status does not consistently separate accepted, integrated, implemented, and verified.
- Work-package completion records are not synchronized with CI.
- The active planning stack has no current integration sequence to `main`.
- The current implementation inventory is not a maintained planning artifact.
- Candidate architecture components are not consistently labeled as candidate.

## Required next planning pass

The next pass must reconcile the roadmap. It must use this order:

1. correct P0-W03 and P0-W04 status and verification records;
2. integrate or rebase the planning stack in dependency order;
3. define the version 0.1 completion scenario;
4. map product responsibilities to work packages;
5. move the minimum evidence and acceptance slice before provider-backed completion;
6. define capability-policy and provider-boundary decisions;
7. revise Phase 1 and Phase 2 dependencies;
8. remove duplicate schedule maps;
9. update the authoritative product, architecture, and roadmap documents;
10. run complete verification against the final commit.

Do not add production code during that reconciliation pass.

## Audit closeout

### Files inspected

Integrated and active-branch product and planning files:

- `README.md`
- `AGENTS.md`
- `docs/PROJECT-PROVENANCE.md`
- `docs/ARCHITECTURE.md`
- `docs/SESSION-MODEL.md`
- `docs/SECURITY-MODEL.md`
- `docs/ROADMAP.md`
- `docs/RUN-MODEL.md`
- `docs/PROJECT-STEWARDSHIP.md`
- `docs/PLAN-RECONCILIATION.md`
- `docs/PROJECT-INVARIANTS.md`
- `docs/BRANCHING-AND-WORK-PLANNING.md`
- `docs/decisions/README.md`
- `docs/decisions/0001-elixir-otp-core.md`
- `docs/decisions/0002-durable-session-journal.md`
- `docs/decisions/0003-language-neutral-extensions.md`
- `docs/decisions/0004-first-class-run-graph.md`
- `docs/decisions/0005-project-steward.md`
- `docs/work/P0-W04-run-graph-stewardship.md`

Implementation and verification evidence:

- `mix.exs`
- `lib/kiln.ex`
- `lib/kiln/application.ex`
- `test/kiln_test.exs`
- pull requests 1, 2, 3, 4, and 5
- GitHub Actions run `30332448342`
- job `90190297822`

File inventories from pull requests 3, 4, and 5 were also inspected. These inventories cover governance, quality, agent-development, scripts, prompts, skills, run, and Steward artifacts.

### Files changed by this work package

- `docs/PLANNING-BASELINE.md`
- `docs/work/P0-W05-planning-baseline.md`
- `README.md`
- `AGENTS.md`
- `docs/ROADMAP.md`

### Existing decisions preserved

This pass preserves ADRs 0001 through 0005. It preserves the local-first, one-developer, work-centered, evidence-backed, capability-mediated, run-graph, and Project Steward directions.

This pass does not accept candidate implementation structures.

### Conflicts found

Twelve conflict classes are recorded as CF-001 through CF-012.

### Documents made authoritative

- `docs/PLANNING-BASELINE.md` for planning status and document relationships on this branch.
- Existing subject authorities remain unchanged: project provenance, architecture plus ADRs, roadmap, security model, invariant register, and work-package plans.

### Documents superseded

No complete source document is superseded during this pass.

Specific statements and duplicate schedule sections are marked for replacement.

### Unknowns

Twenty-four unresolved architecture questions remain. They are listed in this document.

### Evidence rule

Each conclusion in this baseline names its repository file, pull request, commit, work package, ADR, CI run, or job evidence. A later pass must update this baseline when the repository state changes.