# Kiln Planning Control

**Document type:** Planning authority index  
**Status:** Active  
**Build authorization:** Not issued

## Integrated planning baseline

| Pass | Integrated equivalent |
| --- | --- |
| Prompt 1 | Pull request 22, merge commit `ef487c432a04de705e58ec79569abe5bb51e3d7a` |
| Prompt 2 | Pull request 23, merge commit `33da2a718d8d5305bf89035503ac372f07e80a6e` |
| Prompt 3 | Pull request 24, merge commit `0dba694f2a54ab517a2c43bbbd5c77f526a02e65` |
| Prompt 4 | Pull request 25, merge commit `45acc2ed575957c53a8c57195d99c82965e9d48e` |
| OD-01 | Pull request 26, merge commit `bdcfcc5d4f4c6f74838d885c74c2240720b3dce1` |

The Prompt 4 and OD-01 merges form the Wave A focused-planning baseline.

## Current authorities

Use these files in this order:

1. [Planning Completion Baseline](PLANNING-COMPLETION-BASELINE.md) — observed planning and implementation baseline from Prompt 1.
2. [Product Scope and Minimum Architecture](PRODUCT-SCOPE-AND-MINIMUM-ARCHITECTURE.md) — product, scope, delivery rationale, and minimum architecture from Prompt 2.
3. [Implementation Disposition Register](IMPLEMENTATION-DISPOSITION-REGISTER.md) — implementation-like asset status, blast radius, and disposition from Prompt 3.
4. [Planning Round Register](PLANNING-ROUND-REGISTER.md) — unresolved-domain classification, focused rounds, dependencies, Prompt 5 bundles, and readiness gates from Prompt 4.
5. [Owner Decision Register](OWNER-DECISIONS.md) — accepted and pending owner choices that focused rounds must consume.
6. [Planning Round Authoritative Inputs](PLANNING-ROUND-INPUTS.md) — exact Repository paths consumed by each Prompt 5 bundle.
7. [Roadmap](ROADMAP.md) — product slice and implementation-order authority.
8. [Implementation Slices](IMPLEMENTATION-SLICES.md) — slice outcomes, boundaries, tests, demos, and planned Receipts.
9. [Slice Acceptance Gates](SLICE-ACCEPTANCE-GATES.md) — aggregate proof required when each slice enters implementation.

The [Architecture](ARCHITECTURE.md), [Run Model](RUN-MODEL.md), [Session Model](SESSION-MODEL.md), accepted [ADRs](decisions/README.md), and focused specifications provide subject authority. They cannot broaden the current scope or reorder delivery without an accepted authority change.

## Focused-round authorities

- P0-W21 proposes `ROOT-RUN-LIFECYCLE-AND-JOURNAL.md` as the first-month lifecycle and durable-state authority. It must integrate first.
- P0-W22 proposes [Model, Context, and Repository Boundary](MODEL-CONTEXT-AND-REPOSITORY-BOUNDARY.md) as the provider, sealed Context, Tool, active-Repository read, disclosure, and secret-screening authority.
- ADR-0023 proposes the concrete MiniMax M2.7 OpenAI-compatible mapping under accepted ADR-0021.

P0-W22 must be reconciled onto integrated P0-W21 before acceptance. It can consume lifecycle and external-operation identifiers. It cannot add or revise Run states, transition authority, journal entries, projections, migrations, or restart semantics.

## Remaining planning process

```text
integrate P0-W21
→ rebase, audit, and integrate P0-W22
→ P0-W23
→ record OD-02 before P0-W24 and P0-W25 complete
→ P0-W24
→ P0-W25
→ Prompt 6-A justified first-month conformance
→ Prompt 7-A independent adversarial review
→ Prompt 8-A adjudication and possible bounded authorization
```

Prompt 7 remains immediately before Prompt 8. Prompt 8 is the only pass that may issue build authorization.

## Current owner decisions

- OD-01 is accepted through ADR-0021: MiniMax only, sealed Context only, Project-controlled source disclosure, and no fallback.
- OD-02 remains pending and must be accepted before P0-W24 and P0-W25 complete.

## Wave B gate

P0-W26 and P0-W27 do not run during Wave A. They require accepted runtime Evidence from an authorized Single-Run Alpha, including one real change, durable restart, controlled Patch authority, registered verification, criterion-bound Evidence, a valid Receipt, and observed failure or interruption behavior.

After that Evidence exists:

```text
P0-W26
→ P0-W27
→ Prompt 6-B
→ Prompt 7-B
→ Prompt 8-B
→ only the delegated implementation scope explicitly authorized by Prompt 8-B
```

## Current next action

Complete and integrate P0-W21 first. Continue P0-W22 design in parallel, but do not merge it independently. Reconcile P0-W22 onto the P0-W21 merge, run an ownership audit, validate the exact rebased head, and merge it second.
