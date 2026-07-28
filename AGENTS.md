# AGENTS.md

## Project identity

Kiln is a local-first, evidence-driven coding harness built with Elixir and OTP.

Kiln helps one developer move repository work from intent to verified completion with less context loss, unsupported claims, and unsafe execution.

The session is the durable objective boundary. The run graph is the durable execution model. The root run carries Project Steward responsibility by default.

Project-local skills and specialist agents help build Kiln. They are not Kiln runtime components.

## Required start sequence

Before planned work:

1. run `scripts/agent-preflight`;
2. read `docs/PLANNING-BASELINE.md` for current authority, status, conflicts, and unknowns;
3. read the matching work-package plan in `docs/work/`;
4. read `docs/PROJECT-INVARIANTS.md`;
5. read `docs/AGENT-FRIENDLY-CODEBASE.md`;
6. read `docs/ENGINEERING-QUALITY-RULES.md`;
7. read `docs/RUN-MODEL.md` and `docs/PROJECT-STEWARDSHIP.md` when the work affects sessions, runs, providers, interfaces, execution, evidence, or recovery;
8. read applicable architecture and decision records;
9. inspect current source, tests, Git state, and dependency direction.

Use the `kiln-work-package` skill for this sequence.

For Elixir and OTP changes, also load `kiln-elixir-otp` and read `docs/ELIXIR-OTP-ENGINEERING.md`.

## Non-negotiable principles

1. Optimize project throughput, not agent or run activity.
2. Keep the core small and inspectable.
3. Prefer deterministic code over probabilistic bookkeeping.
4. Treat Git and the filesystem as source truth.
5. Keep the event journal separate from transcript projections.
6. Bind verification evidence to repository state.
7. Use capability-based permissions.
8. Keep interfaces behind an explicit domain API.
9. Model bounded delegated work as first-class runs when independent inspection, steering, cancellation, evidence, or recovery is required.
10. Do not make an artificial organization of agents a core abstraction.
11. Do not add scaffolding, marketplaces, cloud services, or browser integrated development environment features to early milestones.
12. Preserve each `KILN-INV-*` invariant unless an accepted ADR supersedes it.

## Language boundaries

- Elixir owns runtime processes, supervision, resources, streaming, and side effects.
- Gleam is deferred. It may later own selected pure rules or protocol transformations.
- External tools should cross a supervised process or protocol boundary.
- Rust may later support operating-system isolation if a demonstrated requirement justifies it.
- Do not introduce a second language without an accepted architecture decision record (ADR).

## Elixir and OTP rules

Do not create a process for every noun.

Use a process when it owns mutable state, a resource lifetime, concurrency, cancellation, failure isolation, or external communication.

Keep deterministic transformations in ordinary functions or pure modules.

Keep the public domain API separate from GenServer callback modules.

Supervision restores runtime structure. Persisted events and repository observations restore durable state.

Logical run lineage is not OTP supervision. Do not derive supervisor-child relationships from `parent_run_id`.

Do not persist process identifiers, references, ports, tasks, or functions.

Do not create atoms from external input.

Do not use arbitrary sleeps to synchronize tests.

Inspect shared dependency effects with `mix xref callers`, `mix xref trace`, or the compile-connected cycle check.

## Product run model

A session MUST have one root run.

The root run carries Project Steward responsibility by default.

When delegated work requires independent inspection, steering, cancellation, evidence, or recovery, create a child run. Do not hide that work in an opaque background tool call.

Each run MUST have or reference:

- one bounded task;
- session, root, and parent identifiers;
- explicit status;
- a capability profile;
- context and transcript projections;
- artifacts and evidence;
- resource accounting;
- cancellation and attention state;
- a structured result.

Client focus MUST remain local to each client. A focus change MUST NOT change run execution or another client.

Attention routing MUST work independently of run depth.

Do not permit concurrent writing runs in one checkout. Writing children require isolated worktrees or patch artifacts.

Initial child runs SHOULD be read-only.

## Project Steward rules

The Project Steward coordinates delivery. It is not a manager-of-managers persona.

The Steward MUST:

- maintain the accepted objective and completion contract;
- trace specifications to runs, mutations, verification, evidence, and completion status;
- select direct execution or bounded delegation based on expected contribution to delivery;
- route attention;
- disclose blockers, failures, material uncertainty, and specification gaps;
- request independent verification for material completion claims;
- reconcile intent, repository state, and current evidence.

The Steward MUST NOT:

- override user authority;
- change accepted intent without disclosure and approval;
- bypass capability policy;
- alter repository or evidence facts through narrative;
- treat stale evidence as current;
- permit concurrent writers in one checkout;
- report completion when the completion contract is not satisfied;
- create child runs only to simulate an organization.

Deterministic services remain authoritative for repository state, event ordering, capability decisions, evidence freshness, recovery state, and acceptance status.

## Work-package discipline

Planned work MUST use a work-package identifier and a branch that follows `docs/BRANCHING-AND-WORK-PLANNING.md`.

A `work/` branch MUST have one matching plan in `docs/work/`.

Use the same work-package identifier in:

- the plan filename;
- branch name;
- issue and pull-request titles when present;
- requirements;
- acceptance criteria;
- evidence identifiers;
- completion reports.

Each branch MUST have one primary objective. Split independent objectives into separate work packages.

A plan MUST identify each applicable project invariant.

## Development-agent model

The main coding agent is the default writer for building Kiln.

Project-local specialist agents are optional reviewers. They MUST NOT become parallel implementation owners.

Use:

- `kiln-otp-reviewer` for OTP lifecycle, supervision, cancellation, and restart review;
- `kiln-integrity-reviewer` for invariant, scope, and evidence review;
- `kiln-verifier` for independent non-mutating command evidence.

Specialist agents MUST NOT receive `edit` or `write` tools.

The verifier MAY use Bash only for non-mutating inspection and checks.

The main coding agent remains responsible for evaluating findings and applying accepted corrections.

Do not implement optional reviewer suggestions unless they serve the current work-package objective.

Development-agent assets do not prove the Kiln runtime run model.

## Change discipline

Before implementation:

- record the observed current state and evidence;
- state the objective and exclusions;
- identify assumptions and unknowns;
- identify applicable invariant IDs and ADRs;
- define requirements and acceptance criteria;
- state the expected mutation surface;
- identify narrow and complete verification.

During implementation:

- distinguish observed, inferred, proposed, assumed, and unknown information;
- update the work-package plan when material facts change;
- record an ADR for each material architecture decision;
- do not reverse an accepted ADR without a superseding ADR;
- do not add speculative extension points or compatibility paths;
- do not include unrelated cleanup;
- preserve run and stewardship boundaries when work touches session state or interfaces.

Before completion:

- inspect the final diff against the intended base;
- run the narrowest meaningful checks;
- run `scripts/check`;
- request applicable specialist review;
- link each acceptance criterion to current evidence;
- report failures, warnings, unknowns, and exclusions;
- confirm that repository state matches the completion report;
- never claim verification that did not run.

Use the `kiln-evidence-closeout` skill for completion.

If required verification cannot run, report `implemented but unverified`. Do not report the work package as complete.

## Dependency discipline

Use the `kiln-dependency-review` skill before adding a library, executable, service, native implemented function (NIF), port program, or development tool.

A dependency proposal MUST identify the requirement, exact version, official interface, maintenance evidence, license, transitive effect, security boundary, alternatives, and removal cost.

Do not add a dependency because it is common in unrelated projects.

## Standard checks

```bash
scripts/agent-preflight
scripts/check
```

`scripts/check` runs:

- project skill and specialist-agent validation;
- Vale prose checks;
- Elixir formatting;
- warnings-as-errors compilation;
- compile-connected cycle detection;
- ExUnit tests.

## Documentation rules

- Follow `docs/ENGINEERING-QUALITY-RULES.md`.
- Use `docs/PLANNING-BASELINE.md` for current document authority and planning status.
- Give each document one primary purpose.
- Use Easy Approach to Requirements Syntax (EARS)-compatible requirements when applicable.
- Use Given-When-Then for behavioral acceptance criteria when applicable.
- Support material repository claims with current evidence.
- Do not claim formal ASD-STE100 compliance.
- Roadmap status must match implementation evidence.
- Distinguish accepted, integrated, implemented, verified, provisional, and deferred states.
- Prefer omission over unsupported content.