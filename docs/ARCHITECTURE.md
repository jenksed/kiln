# Integrated Architecture

**Document type:** Architecture summary  
**Decision status:** Accepted  
**Integration status:** Reconciled by Prompt 8-A; Quality Compiler placement added as later planned work  
**Implementation status:** P1-S01 integrated at `db02198`; PR #48 rejected; P1-S02-T01 boundedly authorized and not yet implemented; P1-S02-T02 and later unauthorized; P1-S02 is not authorized as an aggregate slice  
**Detailed subject authorities:** P0-W21 through P0-W25  
**Quality Compiler design package:** `quality-compiler/`, subordinate to Roadmap and later slice authorization

## Purpose

This document summarizes the minimum architecture for one durable, controlled, evidence-backed Repository change.

It does not redefine the focused authorities. When a detail conflicts with a focused specification, use these documents in order:

1. `docs/ROOT-RUN-LIFECYCLE-AND-JOURNAL.md`;
2. `docs/MODEL-CONTEXT-AND-REPOSITORY-BOUNDARY.md`;
3. `docs/PATCH-APPROVAL-AND-MUTATION.md`;
4. `docs/COMMAND-EVIDENCE-AND-ACCEPTANCE.md`;
5. `docs/CLI-AND-LOCAL-DELIVERY-CONTRACT.md`.

The Roadmap and final Wave A authorization control implementation order. This summary and the Quality Compiler design package cannot authorize work or add early scope.

## Product loop

```text
Intent
→ bounded investigation
→ explicit Patch proposal
→ user Approval
→ controlled application
→ Assurance and Evidence Plan
→ registered Gate execution
→ normalized Findings and criterion-bound Evidence
→ user acceptance
→ atomic completion
→ post-completion Receipt sealing and delivery
```

Kiln optimizes for completed trustworthy work. It does not optimize for Agent count, Run count, protocol count, process count, panes, indexes, Tool catalogs, analyzer count, or a numerical quality score.

## Non-negotiable rules

1. A Task states desired work. A Run attempts or coordinates it.
2. Run is the durable execution and observation identity.
3. A Run is not an Agent, model request, Tool call, Command, Gate, Finding, process, branch, worktree, protocol session, Development Pack, or transcript.
4. The first useful product has one Root Run and no Child Run requirement.
5. Logical Run lineage does not define OTP supervision.
6. A durable record does not require a permanent process.
7. Git and the filesystem remain Repository source truth.
8. SQLite records Kiln work and recovery facts. It does not replace Git or source files.
9. Model output is a proposal or Claim. It cannot grant authority, apply its own Patch, verify itself, or accept completion.
10. Capability availability, policy allowance, explicit grant, user Approval, requested Assurance, required Assurance, and achieved Assurance are separate facts.
11. Context selection cannot grant authority.
12. A successful Command or empty Finding list does not imply that a criterion passed.
13. Passing Evidence is current, complete, state-bound, non-contradicted, and sufficient for the required Guarantee and Assurance.
14. A product Receipt has no authority and is sealed only after committed completion.
15. Other repositories are disabled in the first product.
16. Large, sensitive, binary, or unbounded content remains outside the journal and normal model Context.
17. Development Packs may detect, plan, classify, and parse. They cannot execute Project Commands, mutate source, install dependencies, grant authority, change Project policy, or create acceptance.
18. Kiln owns Environment selection, registered Gate execution, cleanup classification, Finding validation, policy evaluation, Evidence sufficiency, and completion readiness.
19. Raw Command and analyzer output remains available behind normalized Findings and Evidence.
20. Missing tools, Pack failures, parser failures, truncation, stale state, or unknown cleanup cannot become an empty pass.
21. Resource budget and repair autonomy cannot silently lower the claimed Assurance.
22. The smallest reliable implementation wins. Speculative flexibility is deferred.

## First useful system

```text
Developer
   │
   ▼
foreground CLI
   │
   ▼
Single-Run workflow application
   ├── domain rules and current projections
   ├── effective-authority checks
   ├── sealed Context package builder
   ├── bounded active-Repository reads
   ├── one MiniMax provider adapter and deterministic fake
   ├── exact Patch and Approval path
   ├── registered Command execution
   ├── Quality Compilation coordinator
   │   ├── Assurance and risk planning
   │   ├── Gate graph and execution requests
   │   ├── Finding normalization and baseline policy
   │   └── criterion and Evidence consolidation
   ├── Artifact, Evidence, completion, and post-completion Receipt functions
   └── SQLite journal and projection store
           │
           ├── transient model and Command Workers
           └── supervised Development Pack process when QC1 is authorized
```

The first-month target has one active Project, one active Repository, one Session, one initial Task, and one Root Run.

It does not require:

- Child Runs;
- a TUI;
- background scheduling;
- a general Capability broker;
- a retrieval framework;
- managed worktrees;
- code intelligence;
- a general protocol ecosystem;
- telemetry export;
- local project intelligence;
- remote execution.

P1-S02 may introduce one bounded supervised Development Pack protocol because QC1 requires language-specific planning and parsing outside the Kiln authority core. That protocol is not permission to become a general plugin or interoperability platform.

## Core durable subset

### Project

One active Repository plus accepted instructions, disclosure policy, mutation policy, Assurance policy, registered verification configuration, and accepted Development Pack configuration when authorized.

### Session

One accepted objective and its complete Kiln work history.

First-month persisted states are:

```text
active
completed
abandoned
```

### Task

One accepted desired outcome with criteria, constraints, and exclusions.

First-month persisted states are:

```text
in_progress
satisfied
abandoned
```

### Root Run

One durable, independently inspectable attempt or coordination boundary.

First-month persisted states are exactly:

```text
ready
running
waiting_for_user
orphaned
completed
failed
canceled
```

Workflow step, pending user decision, external-operation state, Quality Compilation state, Assurance state, Finding state, and Evidence state are separate facts. Do not add `created`, `waiting_for_command`, `verifying`, `stale`, `under_assured`, or Child-oriented states to the first-month Run status.

## Quality Compiler primitives

When P1-S02 is authorized, the Quality Compiler introduces seven foundational concepts without replacing Task, Run, Command, Artifact, Evidence, or Receipt:

```text
Subject
Claim
Verification Obligation
Observation
Guarantee
Derived Fact
Decision
```

- A **Subject** identifies the exact immutable Repository, Patch, Artifact, Command result, or release state being evaluated.
- A **Claim** states something about that Subject.
- A **Verification Obligation** records what must be done to evaluate the Claim.
- An **Observation** records one analyzer or execution result.
- A **Guarantee** states what the Observation can legitimately establish and under which assumptions and bounds.
- A **Derived Fact** records a normalized result plus its producer and invalidation dependencies.
- A **Decision** is Kiln's deterministic policy conclusion.

A Finding is one Derived Fact produced from an Observation. A Finding is not criterion Evidence by itself.

## Assurance

The planned user-facing profiles are:

```text
Auto
1  Rapid
2  Standard
3  Thorough
4  Critical
5  Formal
```

Assurance controls required Evidence breadth and strength. It does not control whether Kiln reports truthfully.

Kiln computes required Assurance from Project policy, changed paths, risk, criteria, Pack requirements, and accepted waivers. Resource budget and repair autonomy remain separate controls.

A user may request more Assurance freely. A request below the required floor blocks or creates an explicit waiver decision that records omitted methods and residual risk. The final Receipt reports achieved Assurance.

## Durable state and operations

The Session journal records accepted work facts and material external-effect boundaries.

It supports:

- ordered sequence and revision;
- expected-revision checks;
- idempotency;
- deterministic replay;
- rebuildable current projections;
- forward migrations;
- restart reconstruction;
- conservative unknown-effect classification.

The first store uses direct Exqlite, one supervised connection, one writer, WAL, `synchronous=FULL`, foreign keys, a bounded busy timeout, and immediate write transactions. It does not depend on nested first-month transactions.

An external operation records durable intent before dispatch. If restart cannot prove a terminal result or effect, the operation is unknown and the Run is `orphaned`. Kiln does not repeat the effect automatically.

Quality Compilation records selected Pack identities, required Assurance, the Evidence Plan, Gate intents and observations, Finding batches, policy decisions, criterion evaluations, and achieved Assurance as bounded facts and immutable Artifact references. Large raw reports remain outside the journal.

## State ownership

### Git and filesystem

Own source content, commits, refs, branch and checkout state, dirty state, and source history.

### Kiln journal

Owns accepted objective and criteria revisions, Session, Task and Run transitions, user decisions, operation intents and observations, Assurance decisions, Quality Compilation state, Evidence state, recovery facts, and final completion.

### Immutable Artifacts

Own raw stdout and stderr, structured analyzer reports, normalized Finding batches, Evidence Plans, impact summaries, verifier reports, Counterexamples, and large or sensitive bounded content.

### Rebuildable projections

Provide current status, workflow step, pending decisions, operation state, Patch state, Assurance, Gate state, current Findings, criterion evaluations, warnings, unknowns, and readiness.

### Transcript

Preserves interaction history. It cannot change objective, criteria, authority, mutation, Assurance, Findings, Evidence, recovery, or completion state.

## External boundaries

### Provider

MiniMax M3 is the only real initial provider. The deterministic fake is required for tests. There is no fallback.

Only the sealed Context package and required provider metadata may leave the machine under accepted Project disclosure policy.

### Repository reads

Reads and literal search remain inside one canonical selected checkout. Path escape, symlink traversal, special files, binary content, invalid encoding, stale digests, and mandatory secret paths are denied.

### Patch mutation

The authoritative Patch is a manifest of complete UTF-8 after-images for `add`, `replace`, and `delete`. Unified diff is review output only.

Only exact user Approval for the current Patch and base can permit one mutation operation. No fuzzy application, shell mutation, Git staging, commit, push, merge, publish, or deploy occurs.

### Command and Gate execution

Only registered absolute executables and validated argv can run. No shell string or arbitrary model or Pack Command is allowed.

A Gate refers to an accepted Command registration and evaluation purpose. It does not contain arbitrary runtime executable authority.

On the supported host, a dedicated process-group helper must prove cleanup. Missing proof is unknown, not a successful timeout or cancellation.

### Development Packs

The public Pack boundary is a supervised external process with a bounded framed protocol.

A Pack may:

- describe its identity and supported Project kinds;
- detect exact Project indicators;
- propose Gate and impact plans;
- parse bounded immutable output;
- provide policy metadata and verifier guidance;
- declare limitations and execution effects.

A Pack may not:

- run a Project Command;
- mutate source;
- install dependencies;
- read ambient secrets;
- widen a registration or grant;
- choose network or writable access;
- call a model;
- suppress a Finding under Project authority;
- create a passing criterion or completion Decision.

A Pack crash, timeout, protocol mismatch, malformed result, or parser failure remains explicit and cannot crash Kiln or produce a false pass.

### Evidence and completion

Exit zero, model confidence, a Finding count, a summary, or a Receipt cannot prove completion.

Every required criterion must have current, complete, non-contradicted Evidence sufficient for the required Assurance and Guarantee. User acceptance binds the current aggregate evaluation. P0-W21 owns the atomic Run, Task, Session, acceptance, and proof-reference completion transaction.

A product Receipt is sealed afterward from immutable references. Receipt failure blocks delivery, not the truth of already committed completion.

## Runtime ownership

Permanent processes are justified only for live Resource ownership.

The initial runtime can include:

- one supervised SQLite connection and writer;
- transient model invocation Workers;
- transient mutation Workers;
- transient Command Workers;
- the macOS Command-host helper process used by a registered Command;
- one supervised Development Pack host process only when QC1 is authorized and active.

There is no process per Session, Task, Run, Claim, Verification Obligation, Finding, Evidence item, Receipt, or static policy record.

## Supported host

The first supported profile is Apple Silicon macOS 15.0 or later, local APFS, and one interactive local user. Other hosts are unsupported until their complete workflow passes host conformance and review.

## Implementation order

Prompt 8-A authorizes only P1-S01-T01 through P1-S01-T05 in exact sequence.

That sequence establishes domain state, durable store, deterministic replay and projections, the minimum foundation CLI, and the P1-S01 aggregate gate and slice verification manifest.

It does not authorize MiniMax calls, Repository source disclosure, Patch mutation, external Commands, Quality Compilation, Development Packs, Findings, Assurance, product Evidence completion, product Receipt sealing, release packaging, Child Runs, TUI, or Wave B work.

After P1-S01 passes its aggregate gate and owner-machine Evidence, a later authorization pass may place QC0 and QC1 inside P1-S02 in this dependency order:

```text
Artifact and registered Command substrate
→ Pack protocol and deterministic fake Pack
→ Quality Compilation and Assurance Plan
→ Gate execution and raw result capture
→ Finding normalization, fingerprints, and baselines
→ Elixir reference Pack
→ one dogfooded Kiln source change
→ criterion and Evidence consolidation
→ aggregate Single-Run Alpha proof and delivery
```

That work must remain vertical: each ticket advances the complete source-change workflow and leaves unavailable later capabilities unreachable.

QC2 belongs only with the later accepted read-only Verifier Child after P0-W26, P0-W27, Prompt 6-B, Prompt 7-B, and Prompt 8-B.

QC3 Repository quality memory follows accepted QC2 runtime Evidence. QC4 follows Elixir and TypeScript portability proof and later public-platform authorization.

## Deferred expansion

After the authorized Single-Run Alpha and QC1 produce accepted runtime Evidence, later planning may address interruption refinement and bounded delegation with QC2.

QC3, QC4, managed worktrees, TUI, code intelligence, generalized interoperability, local project intelligence, telemetry, and remote execution remain evidence-gated later work.
