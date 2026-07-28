# Project Stewardship

**Document type:** Explanation  
**Status:** Foundational direction

The Project Steward is Kiln's session-level delivery responsibility.

The Project Steward uses the run graph, repository evidence, capability policy, accepted specifications, and completion gates to move one repository objective toward a working, verified result.

The Project Steward is not an artificial manager persona. It is a constrained control role attached to the root run.

## Purpose

The Project Steward exists to protect delivery integrity while increasing development leverage.

Delivery integrity means that Kiln can show:

- which intent and specifications govern the work;
- how the work was decomposed;
- which runs performed each task;
- which files and artifacts changed;
- which verification evaluated the current repository state;
- which risks, failures, and unknowns remain;
- why the session is or is not ready for completion.

The Steward should reduce:

- repeated repository orientation;
- duplicated investigation;
- untracked delegation;
- specification drift;
- stale verification;
- hidden blockers;
- persuasive but unsupported completion claims;
- user effort spent reconstructing session state.

## Relationship to the root run

Each session has one root run.

The root run carries Project Steward responsibility by default.

```text
Session objective
└── Root run: Project Steward responsibility
    ├── Scout run
    ├── Builder run
    ├── Research run
    └── Verifier run
```

The Steward responsibility can use one model, several bounded model runs, deterministic services, or direct user commands.

The role name describes responsibility. It does not require a fixed prompt persona or one permanent model.

## Steward authority

The Project Steward may:

- maintain the active intent and completion contract;
- trace requirements to planned and completed work;
- decompose work into bounded runs;
- choose foreground or background delegation;
- request capability grants for child runs;
- assign resource limits;
- pause or cancel runs;
- route attention;
- request independent verification;
- compare implementation state with the accepted specification;
- identify stale evidence;
- propose the next highest-value action;
- block a completion recommendation when evidence is missing;
- produce the final reconciliation report.

## Steward limits

The Project Steward must not:

- override the user's final authority;
- change accepted product intent without disclosure and approval;
- bypass capability policy;
- treat BEAM isolation as an operating-system sandbox;
- modify repository truth through an unrecorded path;
- mark stale evidence as current;
- hide failed verification;
- convert unknown state into a success state;
- allow concurrent writers in one checkout;
- create delegation only to simulate an organization;
- delegate responsibility for final reconciliation to an opaque child;
- report completion when the completion contract is not satisfied.

Deterministic systems remain authoritative for:

- repository fingerprints;
- current Git state;
- event ordering;
- capability decisions;
- evidence freshness;
- acceptance status;
- resource ceilings;
- recovery state.

The Steward can interpret these facts. It cannot rewrite them through narrative.

## Stewardship loop

The Steward follows this control loop:

```text
Understand objective
→ establish specification and completion contract
→ orient to current repository state
→ identify the next uncertainty or change
→ execute directly or delegate a bounded run
→ observe results and mutations
→ update risks, unknowns, and traceability
→ verify the current repository state
→ reconcile intent, changes, and evidence
→ continue, block, or recommend completion
```

### 1. Establish objective

The Steward records:

- the requested outcome;
- accepted constraints;
- explicit exclusions;
- applicable architecture decisions;
- applicable project invariants;
- completion criteria.

The Steward must identify a material specification gap as `Unknown` rather than inventing a requirement.

### 2. Orient

The Steward establishes the minimum current repository context required for the next action.

Orientation must include:

- repository identity;
- branch and commit;
- dirty state;
- governing instructions;
- relevant specifications and architecture decisions;
- available verification entry points;
- unresolved prior work.

Orientation facts must have freshness and invalidation rules.

### 3. Select work

The Steward selects work by expected contribution to the objective.

The Steward should prefer:

- the cheapest reliable test of an unknown;
- deterministic inspection before model speculation;
- one bounded change over broad unreviewed mutation;
- independent verification for material completion claims;
- direct execution when delegation adds no value.

### 4. Delegate when useful

The Steward creates a child run when a task benefits from:

- isolated context;
- concurrent read-only investigation;
- specialized model or tool capability;
- independent review;
- separate evidence;
- user steering;
- independent cancellation or recovery.

The Steward must provide each child with:

- one bounded task;
- required inputs;
- authority and capability limits;
- resource limits;
- expected result structure;
- completion or return condition.

A child run must not receive the full session transcript by default.

### 5. Maintain the delivery ledger

The Steward maintains traceability among:

```text
Intent
→ specification or requirement
→ run or deterministic operation
→ mutation or artifact
→ verification
→ evidence
→ completion status
```

The delivery ledger may be a materialized projection of session and run events.

The ledger should identify:

- unassigned requirements;
- work in progress;
- changes without a requirement or approved reason;
- requirements without current evidence;
- failed or stale verification;
- unresolved attention;
- accepted exclusions.

### 6. Control quality

The Steward protects quality through mechanisms, not adjectives.

Quality controls include:

- narrow mutation boundaries;
- explicit requirements;
- Given-When-Then acceptance criteria when applicable;
- tests that evaluate the required behavior;
- warnings-as-errors compilation;
- repository-specific static checks;
- independent verification for material changes;
- final diff inspection;
- evidence bound to the current repository fingerprint;
- disclosure of failures and unknowns.

The Steward must distinguish:

- implemented behavior;
- verified behavior;
- inferred behavior;
- proposed behavior;
- unknown behavior.

### 7. Reconcile

Before completion, the Steward compares:

- the current user instruction;
- accepted specifications;
- accepted architecture decisions;
- completed runs;
- repository mutations;
- current verification evidence;
- failures and warnings;
- unresolved unknowns;
- exclusions.

The Steward must explain any divergence.

### 8. Recommend completion

The Steward may recommend completion only when:

- acceptance criteria are satisfied;
- required verification has run;
- evidence remains current;
- material warnings and failures are disclosed;
- repository state matches the report;
- remaining unknowns and exclusions are stated;
- no blocking attention item remains unresolved.

The user retains final acceptance authority.

## Delegated run types

Run kinds describe bounded responsibilities, not employees.

### Scout

A Scout investigates repository facts and returns evidence, inferences, and unknowns.

Default capability: read-only.

### Builder

A Builder proposes or applies one bounded implementation change.

Default capability: one writer in the active checkout or an isolated worktree.

### Research

A Research run inspects version-matched external documentation or project knowledge.

Default capability: approved network hosts and no repository writes.

### Verifier

A Verifier evaluates acceptance criteria against the current repository state.

The Verifier should receive requirements, diff, and verification entry points. It should not receive the Builder's confidence narrative as evidence.

Default capability: read and non-mutating execution.

### Steward

A Steward run coordinates delivery, maintains traceability, routes attention, and performs reconciliation.

Default capability: control-plane commands. Repository write capability is separate.

## Competitive leverage

The Project Steward is intended to create advantage through concrete operating properties:

- several read-only investigations can run concurrently without losing lineage;
- the user can enter any delegated run and steer it;
- each run has separate context and resource accounting;
- repository facts survive interface closure;
- independent verification is easy to request and inspect;
- attention reaches the user regardless of run depth;
- the next action is selected from current objective, risk, and evidence state;
- the system can resume without reconstructing the entire project from a transcript;
- completion is tied to specifications and current evidence.

Kiln should measure whether these properties reduce time to verified completion. Kiln should not use the number of agents or child runs as a success metric.

## User interaction

The user must be able to:

- inspect the Steward's current objective and plan;
- see active and queued runs;
- enter any run;
- steer or cancel a run;
- answer attention items;
- change priority;
- restrict or expand capability grants;
- reject a proposed completion;
- take direct control of implementation;
- request a new reconciliation.

The Steward must explain material control decisions in concise operational terms.

## Failure behavior

If the Steward run fails, Kiln must preserve:

- the session objective;
- the run graph;
- active child state;
- unresolved attention;
- repository observations;
- evidence;
- the last durable stewardship projection.

A replacement Steward run may reconstruct control state from the event journal and repository truth.

A Steward restart must not duplicate an active child or repeat a mutation without an idempotency decision.

## Initial limits

The initial Steward should operate under conservative defaults:

```text
One root Steward responsibility per session
Maximum child depth: 2
Maximum concurrent children: 3
Read-only delegation by default
One active writer per checkout
Independent verifier required for material completion claims
No automatic commit, push, merge, or product-direction change
```

These limits are provisional until dogfooding produces evidence.

## Non-goals

Project Stewardship does not mean:

- an autonomous engineering manager;
- a replacement for user judgment;
- a hierarchy of manager agents;
- unlimited background work;
- delegation for every task;
- automatic architecture changes;
- automatic acceptance of model output;
- hidden modification of specifications;
- automatic publication to Git.

## Foundational rule

The Project Steward must use Kiln's state, run graph, policy, evidence, recovery, and interface capabilities to drive one repository objective toward specification-conformant, verified completion.

The Steward must increase leverage without weakening user control or evidence requirements.
