# Vertical Implementation Slices

**Document type:** Implementation roadmap detail
**Decision status:** Accepted by Prompt 8-A
**Integration status:** P1-S01 integrated at `db02198`; PR #48 rejected; corrected P1-S02-T01 plan owner-accepted via P0-W41 at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`; bounded T01 implementation authorized via P0-W42 and reissued via P0-W43 by `docs/authorizations/P1-S02-T01.authorization`; T01 implementation Not yet implemented; P1-S02-T02 and later remain unauthorized
**Implementation status:** P1-S01 — Durable single-Run foundation integrated and owner-accepted
**Order authority:** `docs/ROADMAP.md`
**Quality Compiler placement:** QC0/QC1 planned in P1-S02; QC2 planned with bounded delegation; QC3/QC4 evidence-gated later

## Purpose

This document defines the bounded vertical workflows that implement Kiln.

A slice must produce usable behavior. It must not complete a horizontal framework merely because later architecture describes it.

P1-S01 — Durable single-Run foundation is integrated at `db02198` via PR #46 and owner-accepted (P1-S01-V01 manifest `overall: pass`, owner-machine OD-02 pass). PR #48 was adjudicated and rejected without merge. PR #53 remained historical and unmerged. The corrected P1-S02-T01 plan was integrated through PR #56 at `e57678874a36de1700aa666413b51aae31ea9b12` and owner-accepted via P0-W41 against canonical `main` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; acceptance grants no implementation authority; every P1-S02 ticket and aggregate slice remain unauthorized.

The Quality Compiler is a cross-slice product spine rather than a separate pre-product subsystem. QC0 and QC1 must be delivered through the P1-S02 Single-Run change workflow. Child Runs and QC2 enter only after accepted Single-Run Alpha Evidence and Wave B planning and authorization. QC3 and QC4 remain later evidence-gated expansion.

The proposed design and contracts under `quality-compiler/` are subordinate planning inputs. They do not authorize implementation by themselves.

## Slice identifiers

```text
P1-S01       slice
P1-S01-T01   ticket
P1-S01-G01   aggregate gate item
P1-S01-D01   demo
P1-S01-V01   slice verification manifest
```

A slice verification manifest is an implementation Evidence record. It is not a product Receipt.

A product Receipt is sealed only after committed product completion under P0-W24.

Quality Compiler maturity identifiers are separate from slice identifiers:

```text
QC0 deterministic Gate execution
QC1 evidence-aware Elixir dogfooding
QC2 independent falsification
QC3 Repository quality memory
QC4 multi-language public Pack platform
```

A QC maturity label records demonstrated capability. It does not authorize the slice or ticket that would implement it.

## Cross-slice rules

Every authorized slice shall:

1. introduce only the contract subset required by its demo;
2. preserve Task, Run, provider invocation, Tool, Patch, Command, process, protocol, Pack, Gate, Finding, and Evidence distinctions;
3. use pure functions for static concepts and transformations;
4. create processes only for live Resources, concurrency, timing, cancellation, streaming, subscriptions, external communication, or fault isolation;
5. keep Git and the filesystem authoritative for Repository state;
6. record material work facts and external-effect boundaries durably before reporting them as durable;
7. bind mutation and verification to exact Repository state when those effects are authorized;
8. keep model Claims separate from deterministic Observations, Findings, and Evidence;
9. make permission, mutation, Assurance, acceptance, and delivery explicit;
10. keep large or sensitive content in Artifacts;
11. include deterministic tests that do not require a live provider or public network;
12. label optional live smoke tests separately;
13. create a bounded slice verification manifest from exact implementation Evidence;
14. preserve failures, warnings, exclusions, limitations, Guarantee classes, and unknowns;
15. leave unauthorized capabilities unreachable or absent;
16. keep Development Packs descriptive: Packs may detect, plan, classify, and parse, but Kiln owns Project Command execution, source mutation, authority, policy, Evidence sufficiency, and acceptance;
17. preserve raw analyzer and Command output behind normalized results;
18. treat requested Assurance, required Assurance, resource budget, and repair autonomy as separate facts;
19. refuse to describe a lower achieved Assurance as a higher requested Assurance;
20. deliver one coherent repair Patch, recapture exact state, and reevaluate before another repair cycle.

# P1-S01 — Durable single-Run foundation

**Status:** Integrated at `db02198` via PR #46; owner-accepted. Manifest: `artifacts/p1-s01/slice-01-5792ffdd3af6c45f07e07b8334ce150ad642495b.json` (`overall: pass`, 18 components, owner-machine OD-02 pass)
**Milestone:** Durable work boundary
**Target:** aggressive first foundation sequence; timing does not weaken gates

## User-visible value

A developer can select one local Repository, record one objective and criteria, create one Session, initial Task, and Root Run, inspect current status through a minimal CLI, stop Kiln, restart it, and return to the same durable work state.

## Concepts introduced

- generated identifiers;
- one active Project and Repository observation boundary;
- Session;
- initial Task;
- Root Run;
- exact P0-W21 persisted lifecycle;
- append-oriented journal;
- expected revision and idempotency;
- current projections;
- transcript records separate from domain events;
- durable decisions and external-operation intent and observation records;
- minimal CLI request and result boundary;
- slice verification manifest.

## Authorized responsibilities

Exact module and file names are selected by the ticket that owns them. Responsibilities include:

```text
identifier generation and validation
Project observation metadata
Session, Task, and Root Run domain records
pure lifecycle and action validation
store startup, migrations, integrity, and transactions
journal append and replay
current projections
minimal foreground CLI
P1-S01 aggregate gate and verification manifest
```

No Session, Task, Run, decision, operation, event, projection, or verification-manifest record requires its own process.

## Security boundary

- one canonical selected Repository root;
- metadata observation only; no Repository source read;
- no source write;
- no provider or public network;
- no model-facing Tool;
- no secret access;
- no shell or external Command;
- no Quality Compilation, Development Pack, Gate execution, Finding, Assurance, baseline, or completion Evidence;
- no Child Run;
- no product completion or Receipt;
- CLI state is not domain authority;
- unknown or corrupt state blocks progress rather than returning success.

## Authorized tickets

| Order | Ticket | Deliverable |
| --- | --- | --- |
| 1 | P1-S01-T01 | identifiers, first-month state records, constructors, invariants, pure actions and transitions |
| 2 | P1-S01-T02 | direct Exqlite, store startup, migrations, integrity checks, journal append, revision and idempotency transactions |
| 3 | P1-S01-T03 | deterministic replay, rebuildable projections, restart, duplicate and out-of-order behavior |
| 4 | P1-S01-T06 | shared `Kiln.Workflow` application boundary; consumed by T04 |
| 5 | P1-S01-T04 | minimal foreground CLI start, status, inspect, cancel, resume, and structured output |
| 6 | P1-S01-T05 | aggregate gate, restart demo, corruption and migration fixtures, and P1-S01-V01 |

The accepted plans are under `docs/work/P1-S01-T01-*.md` through `T06`.

Each ticket begins only after its predecessor merges and its exact acceptance Evidence is accepted.

## Acceptance criteria

- one Session has one initial Task and exactly one Root Run;
- Session start creates `active`, `in_progress`, and `ready` atomically;
- no separate Root Task exists;
- Run identity is independent of process, provider, branch, worktree, transcript, Gate, or Development Pack;
- objective and criteria revisions are durable;
- the exact seven-state lifecycle rejects invalid transitions;
- expected revision rejects stale writes;
- idempotency prevents duplicate effects;
- transaction failure leaves no partial durable action;
- forward migrations and unsupported future versions behave deterministically;
- projections rebuild deterministically from zero;
- transcript records cannot alter authoritative state;
- restart reconstructs the same current work state;
- text and structured CLI outputs describe equivalent state;
- no unauthorized capability is reachable.

## Deterministic tests

- identifiers and constructor validation;
- Session, Task, and Root Run invariants;
- accepted action and transition table;
- journal append and rollback;
- expected-revision conflict;
- idempotent duplicate submission;
- migration forward and unsupported-version behavior;
- integrity and corruption fixtures;
- deterministic replay and projection rebuild;
- duplicate and out-of-order action handling;
- transcript separation;
- CLI result and exit mapping;
- restart from exact fixture state;
- absence or explicit unsupported result for every excluded action.

## Slice verification manifest

**P1-S01-V01 — Durable single-Run verification manifest**

It references:

- exact integrated commit;
- required ticket and PR commits;
- accepted objective and criteria fixture;
- Repository observation metadata;
- migration and SQLite versions;
- journal and projection fixture digests;
- gate command and structured result;
- restart demo output;
- owner-machine Evidence;
- warnings, exclusions, unsupported paths, and unknowns;
- manifest digest and creation time.

It cannot satisfy a Task, complete a Run, authorize Quality Compiler work, or act as a product Receipt.

## Demo

**P1-S01-D01 — Durable single-Run foundation**

1. Select one fixture Repository without reading source content.
2. Start one Session with objective and criteria.
3. Show the initial Task and Root Run.
4. Show current revision and durable state.
5. Record bounded transcript metadata without changing domain state.
6. Record one supported decision or cancellation action.
7. Stop Kiln.
8. Restart Kiln.
9. Show the reconstructed objective, criteria, Task, Run, decision, warnings, and revision.
10. Verify P1-S01-V01 against the exact integrated state.

## Exit

Kiln has a durable work foundation that survives restart without reconstructing truth from conversation text.

## Explicit exclusions

- provider behavior or fake-provider execution;
- Repository source reads or search;
- Context packages and model-facing Tools;
- Patch proposal, Approval, mutation, or rollback;
- external Commands or native helper;
- Quality Compilation, Development Packs, Findings, Assurance, or baselines;
- criterion completion Evidence;
- user completion acceptance;
- product Receipt sealing;
- release packaging or installation;
- Child Runs or Attention;
- TUI;
- managed worktrees;
- protocols;
- Wave B work.

# P1-S02 — Evidence-backed Single-Run Change Alpha plus QC0/QC1

**Status:** Planned; corrected T01 plan Accepted; bounded T01 implementation Authorized; T01 implementation Not yet implemented; T02 and later Unauthorized
**Entry gate:** P1-S01 aggregate gate, demo, verification manifest, owner-machine Evidence, and Prompt 8-A authorization conditions remain satisfied; the corrected T01 plan is owner-accepted via P0-W41; the bounded T01 implementation is authorized via P0-W42 by `docs/authorizations/P1-S02-T01.authorization` and reissued via P0-W43 against the amended plan digest and canonical decision base `1243b8f27a594c9440638964a83b56c74774ba28`; the reissued record becomes active authority only when P0-W43 integrates on canonical `main`; implementation begins only after that integration, by moving `work/p1-s02-t01-artifact-evidence-substrate-v2` to the observed canonical integration commit.

## User-visible value

A developer can ask MiniMax M3 to investigate the active Repository, inspect an exact Patch proposal, approve it, apply it, select or accept an Assurance level, run the Kiln-owned Evidence Plan through registered Gates, inspect normalized Findings and criterion-bound Evidence, and accept completion only when the current aggregate evaluation is ready.

## Planned concepts

### Complete change-loop concepts

- bounded Repository observation, read, and exact search;
- disclosure policy and sealed Context package;
- four phase-specific model-facing Tools;
- deterministic fake provider;
- one real MiniMax M3 adapter after live capability proof;
- model Claims separate from source observations;
- complete-text Patch and exact user Approval;
- one mutation owner, rollback data, and exact target or unknown observation;
- registered non-shell Commands and macOS process-group helper;
- user acceptance;
- P0-W21 atomic completion;
- post-completion product Receipt;
- remaining product CLI and local arm64 macOS delivery.

### QC0 concepts

- immutable Artifact storage for raw and structured outputs;
- registered Command definitions with exact executable, argv, cwd, Environment, limits, and process ownership;
- Quality Subject bound to exact Repository and Patch state;
- Verification Obligations derived from accepted criteria;
- Gate definitions and a deterministic Gate graph;
- requested, required, and achieved Assurance;
- Kiln-owned Gate execution and exact terminal observations;
- Quality Observations and Guarantee classes;
- normalized Findings with raw Artifact references;
- deterministic aggregate Decisions that preserve `pass`, `fail`, `blocked`, `unknown`, `stale`, and `contradicted` distinctions.

### QC1 concepts

- supervised external Development Pack process boundary;
- deterministic fake Pack and protocol conformance fixtures;
- Pack detection, planning, parsing, impact hints, and policy metadata;
- no Pack-owned Project Command execution, source mutation, dependency installation, authority, or acceptance;
- stable Inspection, Finding, and Finding Occurrence identities;
- versioned exact, structural, candidate, and no-match fingerprint classifications;
- audit, ratchet, and strict enforcement;
- dependency-tracked Derived Facts and invalidation;
- Elixir project detection and the `kiln-elixir` reference Pack;
- Elixir format, compile, test, xref, and Repository aggregate Gates;
- one real Kiln source change completed through the Elixir Pack;
- criterion-to-Evidence consolidation that retains method, Guarantee, assumptions, scope, limitations, freshness, completeness, and contradiction.

## Planned security boundary

- one approved active Repository root;
- exact path, symlink, special-file, encoding, size, and secret controls;
- only sealed Context may leave the machine;
- no fallback provider;
- no direct model write Tool;
- exact Approval before mutation;
- no fuzzy Patch;
- no shell;
- no dependency installation, Git publication, deployment, or remote execution;
- no Pack access to ambient secrets, writable Repository paths, model calls, or arbitrary executables;
- a Pack cannot widen a Command registration or choose its Environment;
- unknown external effects block completion and are never retried automatically;
- parser, Pack, tool, or cleanup uncertainty cannot become an empty passing result.

## Planned implementation dependency order

The later authorization pass must divide work into bounded vertical tickets while preserving this dependency order:

```text
Artifact and registered Command substrate
→ Pack protocol and deterministic fake Pack
→ Quality Compilation and Assurance Plan
→ Gate execution and raw result capture
→ Finding normalization, fingerprints, and baselines
→ Elixir reference Pack
→ one dogfooded Kiln source change
→ criterion and Evidence consolidation
→ aggregate Single-Run Alpha demo, Receipt, restart, and delivery
```

This order is not permission to implement isolated horizontal layers without user-visible slice contribution. Each ticket must advance the same complete change workflow and keep unavailable later capabilities unreachable.

## Assurance behavior

The planned user-facing profiles are:

```text
Auto
1  Rapid
2  Standard
3  Thorough
4  Critical
5  Formal
```

Assurance controls the required Evidence breadth and strength. It does not permit dishonest acceptance.

The effective plan combines:

```text
requested Assurance
+ Project minimum
+ path and change risk
+ criterion requirements
+ Pack mandatory conditions
= required Assurance
```

Resource budget and repair autonomy remain separate. When required Assurance cannot be established under the available budget or controls, Kiln blocks, narrows the task, or requests an explicit waiver. It does not silently downgrade the result.

## P1-S02 Quality Compiler acceptance criteria

P1-S02 does not reach QC1 unless:

- every Gate is selected through an inspectable Evidence Plan;
- the plan states selected Gates, omitted Gates, fallback, known blind spots, and completeness;
- every result binds the exact Subject, Pack, parser, Command registration, toolchain, Environment, and time;
- raw stdout, stderr, and structured source results remain immutable Artifacts;
- normalized Findings preserve producer, rule, path, semantic anchor when available, fingerprint versions, and source Artifact;
- line movement or minor wording changes do not automatically create unrelated Finding identity;
- ambiguous Finding matches are not silently merged;
- audit, ratchet, and strict modes behave deterministically;
- a baseline is explicit debt, not an opaque count or ignore wildcard;
- missing tools, malformed Pack output, truncation, cancellation, process crash, and unknown cleanup cannot pass;
- `exit 0` does not automatically satisfy a criterion;
- Evidence retains its real Guarantee and limitations;
- no numerical quality score overrides a hard failure, contradiction, unknown effect, or missing required Evidence;
- the first Elixir Pack dogfood change produces a durable accepted Receipt;
- independent falsification is not claimed before QC2.

## Product Receipt

P1-S02 can seal the first product Receipt only after:

1. every required criterion has current sufficient Evidence under the achieved Assurance;
2. no contradiction, blocking decision, unknown operation, expired baseline, or required new Finding remains;
3. the user accepts the current aggregate evaluation;
4. P0-W21 atomically completes the Run, Task, and Session.

The Receipt aggregates immutable references afterward and has no authority.

## Demo

**P1-S02-D01 — Evidence-backed Elixir change**

1. Open the Kiln Repository at one exact state.
2. Record an objective, criteria, and requested Assurance.
3. Investigate through bounded Repository reads.
4. Produce and approve one exact Patch.
5. Apply it through the single mutation owner.
6. Detect the Elixir Project through `kiln-elixir`.
7. Compile the required Assurance and Evidence Plan.
8. Run the selected registered Gates through Kiln.
9. Preserve raw output and inspect normalized Findings.
10. Repair one deliberately introduced defect through one coherent recapture cycle.
11. Run the completion plan.
12. Inspect criterion-to-Evidence coverage, limitations, and aggregate readiness.
13. Accept completion and seal the product Receipt.
14. Restart and inspect the durable record.

## Exit

One real Elixir source change moves from accepted intent to user-accepted verified completion through QC1. Failed, blocked, stale, contradictory, incomplete, orphaned, under-Assured, or unknown proof prevents completion.

# Wave B — Planned only after runtime Evidence

P0-W26 and P0-W27 remain blocked until the Single-Run Alpha and QC1 provide accepted runtime Evidence for a real change, restart, Patch authority, registered Gate execution, normalized Findings, criterion Evidence, achieved Assurance, a valid product Receipt, and observed interruption behavior.

No Child, Scout, Verifier, Attention, QC2, or P1-S03 through P1-S05 implementation is authorized.

## QC2 placement

When Prompt 8-B later authorizes bounded delegation, QC2 belongs with one depth-one read-only Verifier Child.

The Verifier:

- receives independent Context;
- cannot mutate source or widen authority;
- receives the objective, criteria, exact Patch and state, Evidence Plan, raw authorized Artifacts, Findings, Guarantees, and known risks;
- does not receive the implementation Agent's persuasive summary or hidden reasoning by default;
- independently attempts to falsify material Claims;
- produces concrete Counterexample Artifacts where possible;
- returns `pass`, `fail`, `blocked`, or `unknown` with explicit scope and limitations.

The Root implementation Agent cannot satisfy QC2 by reviewing itself.

# Later evidence-gated slices

The following remain deferred:

## QC3 — Repository quality memory

QC3 may retain rebuildable history for:

- logical Finding recurrence and regression;
- flaky test observations;
- Gate duration and reliability;
- baseline burn-down;
- impact-analysis false negatives;
- verifier discoveries;
- modules with broad dependency impact;
- repair effectiveness.

QC3 does not begin as a graph database, embedding system, or unexplained model memory. It starts from accepted journal facts, immutable Artifacts, and rebuildable projections after QC2 provides real data.

## QC4 — Multi-language public Pack platform

QC4 may add:

- a thin TypeScript Pack as the portability proof;
- Pack SDKs only after the wire protocol is proven;
- negative and seeded-defect conformance certification;
- Pack signing, distribution, and trust policy;
- framework Pack composition;
- organization policy distribution.

The public protocol does not freeze before both Elixir and TypeScript fit without language-specific fields in the core.

## Other deferred slices

- TUI projection;
- managed mutation isolation;
- delegated Patch proposal;
- code intelligence;
- interoperability;
- local project intelligence;
- telemetry and attestations;
- remote execution.
