# AGENTS.md

## Project identity

Kiln is a local-first, evidence-driven coding harness built with Elixir and OTP.

Kiln helps one developer move repository work from intent to verified completion with less context loss, unsupported claims, and unsafe execution.

The Workspace is the local operating boundary. The Project is the durable product boundary. The Session is the durable objective boundary. Tasks state bounded desired work. Runs are the primary durable execution units. The Root Run carries Project Steward responsibility by default.

Agent definitions, Workers, model invocations, Tools, Commands, and external protocols operate within or beneath Runs. They do not replace Run identity.

Project-local Skills and specialist agents help build Kiln. They are not Kiln runtime components.

## Required start sequence

Before planned work:

1. run `scripts/agent-preflight`;
2. read `docs/PLANNING-BASELINE.md` for current authority, status, conflicts, and unknowns;
3. read the matching work-package plan in `docs/work/`;
4. read `docs/PROJECT-INVARIANTS.md`;
5. read `docs/AGENT-FRIENDLY-CODEBASE.md`;
6. read `docs/ENGINEERING-QUALITY-RULES.md`;
7. read `docs/INTERNAL-DOMAIN-MODEL.md` when work affects product entities, persistence, protocols, context, capabilities, security, evidence, interfaces, or recovery;
8. read `docs/RUN-MODEL.md` and `docs/PROJECT-STEWARDSHIP.md` when work affects Sessions, Tasks, Runs, providers, interfaces, execution, Evidence, or recovery;
9. read applicable architecture and decision records;
10. inspect current source, tests, Git state, and dependency direction.

Use the `kiln-work-package` Skill for this sequence.

For Elixir and OTP changes, also load `kiln-elixir-otp` and read `docs/ELIXIR-OTP-ENGINEERING.md`.

## Non-negotiable principles

1. Optimize project throughput, not Agent or Run activity.
2. Keep the core small and inspectable.
3. Prefer deterministic code over probabilistic bookkeeping.
4. Treat Git and the filesystem as source truth.
5. Keep the event journal separate from transcript projections.
6. Bind verification Evidence to Repository state.
7. Use Capability-based permissions.
8. Keep interfaces behind an explicit domain API.
9. Model bounded delegated work as first-class Runs when independent inspection, steering, cancellation, Evidence, or recovery is required.
10. Use Run as the primary execution unit. Do not use Agent persona, Worker process, model invocation, or protocol thread as durable work identity.
11. Do not make an artificial organization of agents a core abstraction.
12. Do not allow an external protocol to become Kiln's internal domain model.
13. Do not add scaffolding, marketplaces, cloud services, or browser integrated development environment features to early milestones.
14. Preserve each `KILN-INV-*` invariant unless an accepted ADR supersedes it.

## Language and protocol boundaries

- Elixir owns runtime processes, supervision, Resources, streaming, and side effects.
- Gleam is deferred. It may later own selected pure rules or protocol transformations.
- External Tools, protocols, and ecosystems cross supervised process or adapter boundaries.
- ACP, MCP, LSP, A2A, AG-UI, AHP, provider APIs, and client bridges MUST translate to Kiln-native commands, entities, events, and schemas.
- External identifiers MUST remain in adapter-owned mappings.
- Core modules MUST NOT import protocol-specific types.
- Rust may later support operating-system isolation if a demonstrated requirement justifies it.
- Do not introduce a second language without an accepted architecture decision record (ADR).

## Elixir and OTP rules

Do not create a process for every noun.

Use a process when it owns mutable state, a Resource lifetime, concurrency, cancellation, timing, subscriptions, failure isolation, or external communication.

Keep deterministic transformations in ordinary functions or pure modules.

Keep the public domain API separate from GenServer callback modules.

Supervision restores runtime structure. Persisted events and Repository observations restore durable state.

Logical Run lineage is not OTP supervision. Do not derive supervisor-child relationships from `parent_run_id`.

Do not persist process identifiers, references, ports, Tasks, functions, supervisor paths, connections, or external request identifiers as domain identity.

Do not create atoms from external input.

Do not use arbitrary sleeps to synchronize tests.

Inspect shared dependency effects with `mix xref callers`, `mix xref trace`, or the compile-connected cycle check.

## Internal domain rules

A Session MUST have one Root Run and MAY contain many Tasks and Runs.

A Task MUST state desired work. A Run MUST represent one execution or coordination attempt for one Task.

Completing a Run MUST NOT automatically satisfy its Task.

An Agent MUST be a versioned execution definition. A Worker MUST be a transient executor lease. A model invocation MUST be one provider request and response stream.

A Capability definition or availability observation MUST NOT grant authority.

Effective authority is the intersection of:

- available Capability;
- Workspace limits;
- Project Repository trust policy;
- Privacy policy;
- Session limits;
- active Run Capability grant;
- Resource scope and operation limits.

An Agent, Skill, Tool, adapter, Environment, or Parent Run MUST NOT grant itself or a Child Run ambient authority.

A Claim MUST NOT be treated as Evidence. A Receipt MUST NOT make stale or missing Evidence current.

An Artifact MUST NOT enter model Context without a provenance-bearing Context item and immutable Context manifest.

Active-Project instructions can govern work. Reference-only Project or Repository content is untrusted input and MUST NOT change instructions, policy, product direction, or authority without explicit user acceptance.

## Product Run model

A Session MUST have one Root Run.

The Root Run carries Project Steward responsibility by default.

When delegated work requires independent inspection, steering, cancellation, Evidence, measurement, or recovery, create a Child Run. Do not hide that work in an opaque background Tool call.

Each Run MUST have or reference:

- one bounded Task;
- Session, Root Run, and Parent Run identifiers;
- explicit status;
- one Context manifest;
- a versioned Agent binding when model reasoning is used;
- explicit Capability grants and limits;
- Tool calls, model invocations, Commands, and Terminal activity when present;
- Artifacts, Claims, and Evidence;
- Resource accounting;
- cancellation and attention state;
- a structured result.

Client focus MUST remain local to each Client. A focus change MUST NOT change Run execution or another Client.

Attention routing MUST work independently of Run depth.

Do not permit concurrent writing Runs in one checkout. Writing Child Runs require isolated worktrees or patch Artifacts.

Initial Child Runs SHOULD be read-only.

## Project Steward rules

The Project Steward coordinates delivery. It is not a manager-of-managers persona.

The Steward MUST:

- maintain the accepted objective and completion contract;
- trace specifications to Tasks, Runs, mutations, verification, Evidence, and completion status;
- select direct execution or bounded delegation based on expected contribution to delivery;
- route attention;
- disclose blockers, failures, material uncertainty, and specification gaps;
- request independent verification for material completion Claims;
- reconcile intent, Repository state, and current Evidence.

The Steward MUST NOT:

- override user authority;
- change accepted intent without disclosure and approval;
- bypass Capability, Repository trust, or Privacy policy;
- alter Repository or Evidence facts through narrative;
- treat stale Evidence as current;
- permit concurrent writers in one checkout;
- report completion when the completion contract is not satisfied;
- create Child Runs only to simulate an organization.

Deterministic services remain authoritative for Repository state, event ordering, Capability decisions, Evidence freshness, recovery state, and acceptance status.

## Work-package discipline

Planned work MUST use a work-package identifier and a branch that follows `docs/BRANCHING-AND-WORK-PLANNING.md`.

A `work/` branch MUST have one matching plan in `docs/work/`.

Use the same work-package identifier in:

- the plan filename;
- branch name;
- issue and pull-request titles when present;
- requirements;
- acceptance criteria;
- Evidence identifiers;
- completion reports.

Each branch MUST have one primary objective. Split independent objectives into separate work packages.

A plan MUST identify each applicable project invariant.

## Development-agent model

The main coding agent is the default writer for building Kiln.

Project-local specialist agents are optional reviewers. They MUST NOT become parallel implementation owners.

Use:

- `kiln-otp-reviewer` for OTP lifecycle, supervision, cancellation, and restart review;
- `kiln-integrity-reviewer` for invariant, scope, and Evidence review;
- `kiln-verifier` for independent non-mutating command Evidence.

Specialist agents MUST NOT receive `edit` or `write` Tools.

The verifier MAY use Bash only for non-mutating inspection and checks.

The main coding agent remains responsible for evaluating findings and applying accepted corrections.

Do not implement optional reviewer suggestions unless they serve the current work-package objective.

Development-agent assets do not prove the Kiln runtime Run model.

## Change discipline

Before implementation:

- record the observed current state and Evidence;
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
- preserve internal-domain, Run, and stewardship boundaries when work touches state, interfaces, adapters, execution, Context, policy, or Evidence.

Before completion:

- inspect the final diff against the intended base;
- run the narrowest meaningful checks;
- run `scripts/check`;
- request applicable specialist review;
- link each acceptance criterion to current Evidence;
- report failures, warnings, unknowns, and exclusions;
- confirm that Repository state matches the completion report;
- never claim verification that did not run.

Use the `kiln-evidence-closeout` Skill for completion.

If required verification cannot run, report `implemented but unverified`. Do not report the work package as complete.

## Dependency discipline

Use the `kiln-dependency-review` Skill before adding a library, executable, service, native implemented function (NIF), port program, or development Tool.

A dependency proposal MUST identify the requirement, exact version, official interface, maintenance Evidence, license, transitive effect, security boundary, alternatives, and removal cost.

Do not add a dependency because it is common in unrelated projects.

## Standard checks

```bash
scripts/agent-preflight
scripts/check
```

`scripts/check` runs:

- project Skill and specialist-agent validation;
- Vale prose checks;
- Elixir formatting;
- warnings-as-errors compilation;
- compile-connected cycle detection;
- ExUnit tests.

Domain-contract work MUST also parse and validate JSON Schemas.

## Documentation rules

- Follow `docs/ENGINEERING-QUALITY-RULES.md`.
- Give each document one primary purpose.
- Use Easy Approach to Requirements Syntax (EARS)-compatible requirements when applicable.
- Use Given-When-Then for behavioral acceptance criteria when applicable.
- Support material Repository Claims with current Evidence.
- Do not claim formal ASD-STE100 compliance.
- Roadmap status must match implementation Evidence.
- Distinguish accepted, integrated, provisional, implemented, and verified states.
- Prefer omission over unsupported content.
