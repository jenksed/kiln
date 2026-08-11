# Roadmap

**Document type:** Implementation-order authority  
**Decision status:** Accepted by Prompt 8-A  
**Integration status:** P1-S01 integrated at `db02198` via PR #46 (closeout SHA `5792ffd`, evidence SHA `444c5a5`)  
**Implementation status:** P1-S01 durable single-Run foundation integrated and owner-accepted on the OD-02 acceptance machine  
**Authorization level:** P1-S02-T01 implementation authorized by P0-W42; T01 implementation Not yet implemented; P1-S02-T02 and later remain unauthorized
**Quality Compiler placement:** Planned across P1-S02, Wave B, and later evidence-gated expansion; not independently authorized

## Roadmap rule

Kiln is implemented through bounded vertical user workflows.

A slice must produce usable behavior, deterministic tests, an explicit security boundary, a demo, and a slice verification manifest. A product Receipt is different: it is sealed only after committed product completion under P0-W24.

A slice does not complete a subsystem merely because the long-term architecture describes it.

Prompt 8-A is the sole current build-authorization authority. Older roadmap prose, broad Schemas, planned ticket names, and the `quality-compiler/` design package do not independently authorize work.

The Quality Compiler is a cross-slice product spine. It must enter through the exact vertical workflow that needs its capabilities rather than through an isolated horizontal framework build.

## Owner schedule adjudication

The Single-Run Change Alpha remains an aggressive first-month execution target.

The owner accepts uncertainty in that estimate and rejects schedule pessimism as a reason to remove accepted safety, durability, recovery, Evidence, CLI, packaging, delivery, or Quality Compiler requirements.

Rules:

- implementation remains divided into bounded tickets with exact gates;
- a missed time target causes replanning;
- missed timing does not silently weaken behavior;
- no accepted feature is removed solely because a reviewer predicts a longer schedule;
- Quality Compiler depth may be staged by accepted Assurance and risk, but required controls cannot be silently skipped.

## Product sequence

```text
P1-S01 durable single-Run foundation
→ P1-S02 evidence-backed Single-Run Change Alpha plus QC0/QC1
→ accepted Single-Run and Elixir dogfood Evidence
→ P0-W26 interruption reconciliation planning
→ P0-W27 bounded delegation planning
→ Prompt 6-B
→ Prompt 7-B
→ Prompt 8-B
→ only the delegated work authorized by Prompt 8-B, including QC2 when accepted
→ QC3 Repository quality memory after accepted QC2 Evidence
→ QC4 multi-language Pack platform after Elixir and TypeScript portability proof
```

Later evidence-gated expansion can also add TUI projection, managed mutation isolation, code intelligence, interoperability, local project intelligence, telemetry, or remote execution.

## Quality Compiler placement

The Quality Compiler maturity sequence is:

```text
QC0 — deterministic Gate execution
QC1 — evidence-aware Elixir dogfooding
QC2 — independent falsification
QC3 — Repository quality memory
QC4 — multi-language public Development Pack platform
```

Placement rules:

1. **P1-S01 remains unchanged.** It establishes durable work identity, journal, replay, projections, restart, and the foundation CLI. No Quality Compiler runtime work is authorized there.
2. **P1-S02 owns QC0 and QC1 planning.** Registered Commands, Artifacts, criterion Evidence, aggregate evaluation, the Pack boundary, normalized Findings, Assurance planning, and the first Elixir dogfood proof belong inside the complete Single-Run change workflow.
3. **Wave B owns QC2 planning.** Independent falsification requires the accepted read-only Verifier Child and cannot be simulated by self-review inside the Root Run.
4. **QC3 follows accepted QC2 runtime Evidence.** Repository quality memory must be derived from real Finding, Gate, Evidence, and verifier history rather than speculative indexes.
5. **QC4 follows portability proof.** The public Pack protocol does not freeze until the Elixir reference Pack and a thin TypeScript Pack both fit without language-specific assumptions in the core.

The detailed proposed design, contracts, threat model, Assurance profiles, prior-art inheritance, and implementation sequence live under `quality-compiler/`. Those documents are planning inputs subordinate to this roadmap and later slice authorization.

## Phase 0 — Complete on Prompt 8-A merge

Integrated shaping:

- Prompts 1 through 4;
- OD-01;
- P0-W21 through P0-W25;
- OD-02;
- Prompt 6-A;
- independent Prompt 7-A review;
- Prompt 8-A adjudication and authorization.

Phase 0 complete on Prompt 8-A merge at `118bcaa`.

## Phase 1 — Change-loop-first slices

# P1-S01 — Durable single-Run foundation

**Status:** Integrated at `db02198` via PR #46; owner-accepted; P1-S01-V01 manifest `overall: pass`  
**Purpose:** establish the smallest durable Kiln work boundary before provider, Repository-source, mutation, Command, completion, or Quality Compiler complexity.

## User-visible outcome

A developer can select one Repository, record one objective and criteria, create one Session, initial Task, and Root Run, inspect status through a minimal CLI, stop Kiln, restart it, and return to the same durable work state.

## Authorized delivery

- accepted identifiers and first-month state types;
- one active Project and Repository observation boundary;
- Session, initial Task, and Root Run invariants;
- exact P0-W21 lifecycle transition validation;
- direct Exqlite state store;
- forward migrations and integrity checks;
- append-oriented journal;
- expected revision and idempotency behavior;
- rebuildable current projections;
- transcript records separate from domain events;
- deterministic restart reconstruction;
- durable user-decision and external-operation intent and terminal-or-unknown record shapes;
- minimal CLI start, status, inspect, cancel, resume, and structured result surface;
- aggregate deterministic gate, demo, and slice verification manifest.

## Authorized ticket sequence

| Order | Ticket | Branch | Outcome |
| --- | --- | --- | --- |
| 1 | P1-S01-T01 | `work/p1-s01-t01-domain-foundation` | identifiers, state types, constructors, invariants, pure lifecycle transitions |
| 2 | P1-S01-T02 | `work/p1-s01-t02-durable-store` | Exqlite, store startup, migrations, integrity, journal transaction, revision and idempotency boundary |
| 3 | P1-S01-T03 | `work/p1-s01-t03-replay-projections` | deterministic replay, projections, restart, duplicate and out-of-order handling |
| 4 | P1-S01-T06 | `work/p1-s01-t06-workflow-surface` | shared `Kiln.Workflow` application boundary; consumed by T04 |
| 5 | P1-S01-T04 | `work/p1-s01-t04-foundation-cli` | minimal foreground CLI and structured output over implemented P1-S01 actions |
| 6 | P1-S01-T05 | `work/p1-s01-t05-slice-gate` | aggregate gate, restart demo, corruption fixtures, and P1-S01-V01 verification manifest |

Each ticket begins only after its dependency merges and its exact gate is accepted.

## P1-S01 exclusions

P1-S01 does not authorize:

- real or fake provider execution;
- Repository source reads or disclosure;
- Context package construction;
- model-facing Tools;
- source mutation;
- Patch proposal, Approval, application, or rollback;
- external Command execution;
- native macOS helper execution;
- criterion completion Evidence;
- Quality Compilation, Development Packs, Findings, Assurance planning, or baselines;
- user completion acceptance;
- product Receipt sealing;
- release packaging or installation;
- Child Runs;
- TUI;
- worktrees;
- protocols;
- Wave B work.

The deterministic fake provider and Quality Compiler work remain planned for P1-S02 and are not required to prove P1-S01.

## P1-S01 exit

P1-S01 passes only when the exact integrated state proves:

- one Session starts atomically with one `in_progress` Task and one `ready` Root Run;
- invalid lifecycle transitions fail;
- expected revision and idempotency prevent false or duplicate state;
- journal transactions roll back atomically;
- migrations and integrity checks behave deterministically;
- projections rebuild from zero;
- transcript records cannot alter work state;
- restart reconstructs objective, criteria, Task, Run, decisions, operations, warnings, and revision;
- the minimal CLI's text and structured outputs describe the same state;
- no excluded capability is reachable;
- P1-S01-D01 and P1-S01-V01 bind the exact integrated commit and Evidence.

# P1-S02 — Evidence-backed Single-Run Change Alpha plus QC0/QC1

**Status:** Planned; corrected T01 plan Accepted; bounded T01 implementation Authorized; T01 implementation Not yet implemented; PR #48 rejected
**Entry gate:** P1-S01 must merge and pass its aggregate gate and owner-machine Evidence.

## Intended outcome

A developer can ask MiniMax M3 to investigate the active Repository, inspect one exact Patch, approve and apply it, compile an Assurance-appropriate verification plan, run registered verification Gates, inspect normalized Findings and criterion-bound Evidence, accept completion only when the current aggregate passes, and inspect a post-completion product Receipt.

## Planned subsystems

- bounded Repository reads and search;
- accepted disclosure policy and sealed Context;
- four-Tool maximum;
- deterministic fake provider and one real MiniMax M3 adapter;
- exact complete-text Patch and user Approval;
- one mutation owner with rollback and uncertain-effect handling;
- registered non-shell Commands and macOS process-group helper;
- immutable Artifacts and exact-state Command results;
- Quality Subject, Verification Obligation, Observation, Finding, Evidence Contribution, Guarantee, Derived Fact, and Decision boundaries;
- requested, required, and achieved Assurance with automatic risk escalation and explicit waiver handling;
- supervised external Development Pack protocol with a deterministic fake Pack;
- Gate planning and execution owned by Kiln rather than by a Pack;
- raw-output preservation and normalized, versioned Finding identity;
- audit, ratchet, and strict enforcement modes;
- criterion-to-Evidence consolidation and aggregate evaluation;
- `kiln-elixir` as the first reference Pack;
- one real Kiln source change completed through the Elixir Pack as the QC1 dogfood proof;
- user acceptance, atomic completion, and post-completion Receipt;
- remaining CLI commands;
- arm64 macOS local release and delivery.

## Planned dependency order

The later P1-S02 authorization pass must preserve this dependency order while dividing work into bounded vertical tickets:

```text
Artifact and registered Command substrate
→ Pack protocol and deterministic fake Pack
→ Quality Compilation plan and Gate execution
→ Findings, fingerprints, baselines, and Assurance
→ Elixir Pack
→ first dogfooded source change
→ criterion and Evidence consolidation
→ aggregate Single-Run Alpha proof and delivery
```

Repository investigation, provider, Patch, mutation, CLI, recovery, and completion work must be integrated into those vertical tickets. The sequence does not authorize an isolated horizontal framework build.

P1-S02 requires a later authorization confirmation after P1-S01 Evidence. Its current subsystem and Quality Compiler names are planning aids only.

## P1-S02 minimum Quality Compiler exit

P1-S02 may claim QC1 only when the exact integrated state proves:

- Packs describe, classify, and parse but cannot execute Project Commands, mutate source, install dependencies, grant authority, or create a passing Decision;
- Kiln owns Environment selection, Command execution, policy evaluation, Evidence sufficiency, and acceptance;
- every required Gate result binds the exact Repository and Patch state, Pack version, parser version, Command registration, toolchain, and Environment;
- raw output remains available behind every normalized result;
- missing tools, Pack failure, malformed output, truncation, stale state, and unknown cleanup cannot produce a pass;
- Findings distinguish introduced, preexisting, resolved, regressed, worsened, and ambiguous state;
- requested Assurance can be raised by Project policy, risk, criterion, or Pack requirements without silent downgrade;
- a lower resource budget blocks, narrows scope, or requires an explicit waiver rather than weakening the claimed Assurance;
- one real Kiln source change completes through `kiln-elixir` with criterion-bound Evidence and a durable product Receipt;
- the implementation does not claim independent falsification before QC2.

## First-month milestone

The owner retains this aggressive target:

```text
open Repository
→ record objective and criteria
→ investigate through bounded reads
→ propose exact Patch
→ approve Patch digest
→ apply Patch
→ compute required Assurance
→ compile the Evidence Plan
→ run registered Gates
→ inspect Findings and current Evidence
→ accept completion
→ seal and verify the product Receipt
→ restart and restore the record
```

Failure to meet the calendar target causes replanning, not scope weakening.

# Wave B — Not authorized

P0-W26 and P0-W27 do not run until the authorized Single-Run Alpha and QC1 dogfood proof provide accepted runtime Evidence showing:

- one real source change;
- durable restart behavior;
- controlled Patch authority;
- registered verification;
- a recorded Assurance Plan;
- normalized Findings with raw Artifact references;
- criterion-bound Evidence;
- a valid post-completion Receipt;
- observed runtime failure or interruption behavior.

Only then can Wave B plan:

- one read-only Scout Child;
- one independent Verifier Child;
- maximum depth one;
- maximum one active Child;
- no writing Child;
- no peer communication;
- no shared mutable Context;
- no permission expansion;
- bounded result delivery and CLI navigation;
- QC2 independent falsification with reproducible Counterexample Artifacts and risk-based verifier requirements.

The Root implementation Agent cannot serve as the independent verifier. QC2 passes only when an accepted Verifier Child independently attempts to falsify material Claims.

No P1-S03, P1-S04, or P1-S05 implementation is authorized by Prompt 8-A.

# Phase 2 — Evidence-gated expansion

These items remain deferred until measured need and accepted planning exist:

- QC3 Repository quality memory derived from real Finding, Gate, Evidence, and verifier history;
- QC4 multi-language public Development Pack platform after a thin TypeScript portability proof;
- Pack SDK, conformance certification, signing, distribution, and organization policy;
- TUI projection;
- managed mutation isolation;
- delegated Patch proposal;
- code intelligence;
- Capability interoperability;
- local project intelligence;
- telemetry and attestations;
- remote execution.

QC3 must not begin as a speculative graph, vector, or analytics platform. QC4 must not freeze the public protocol before both Elixir and TypeScript prove portability.

## Pause and return-to-planning conditions

Development pauses when:

- an authorized ticket requires an excluded external effect;
- a focused authority conflict is discovered;
- store corruption or migration behavior cannot be classified safely;
- the selected Exqlite/SQLite line cannot meet the accepted durability baseline;
- implementation would require nested first-month transactions;
- revision, idempotency, replay, or restart invariants cannot be proved;
- a ticket would introduce provider, mutation, Command, completion, Quality Compiler, product Receipt, release, Child, TUI, or Wave B behavior early;
- a Development Pack can execute a Project Command, mutate source, install dependencies, grant authority, or assign acceptance;
- required Assurance is silently lowered because of budget, unavailable tooling, or implementation convenience;
- normalized Findings discard their raw source Artifact or lose producer and state binding;
- deterministic gates cannot reproduce the claimed result;
- the exact merge head is not green.

## Exact next action

P1-S01 is complete and accepted. PR #48 was adjudicated at exact head `7ba158bd`, passed CI, failed technical acceptance, and closed without merge. The corrected T01 plan integrated through PR #56 at `e57678874a36de1700aa666413b51aae31ea9b12`; PR #53 remained the historical unmerged predecessor. P0-W41 records the owner acceptance of the corrected T01 plan against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; that acceptance integrated through PR #57 at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`. P0-W42 authorizes the bounded T01 implementation by creating `docs/authorizations/P1-S02-T01.authorization` against canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`, binding the Accepted-state plan digest, the trusted owner, and the bounded T01-v2 scope. Authorization permits but does not start implementation; no P1-S02 runtime implementation exists yet. P0-W43 adjudicates a discovered migration-runner incompatibility, preserves the accepted aborting aggregate `evidence_warnings` constraint, narrowly authorizes `lib/kiln/store/migrations.ex` for compound-statement support in `statements/1` only, and reissues the authorization record against amended plan digest `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e` and canonical decision base `1243b8f27a594c9440638964a83b56c74774ba28`. The reissued record becomes active trusted authority only when P0-W43 integrates on canonical `main`. The exact next legitimate action after that integration is to observe the resulting canonical integration commit and move `work/p1-s02-t01-artifact-evidence-substrate-v2` to it. Plan acceptance and exact implementation authorization remain separate decisions.
