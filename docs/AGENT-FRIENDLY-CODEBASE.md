# Agent-Friendly Codebase Rules

**Document type:** Reference

An agent-friendly codebase makes structure, behavior, constraints, and verification easy to discover from current repository evidence.

These rules support humans and coding agents. They do not make agents part of Kiln's runtime architecture.

## 1. Core properties

Kiln code SHOULD provide:

- predictable locations for responsibilities;
- explicit public boundaries;
- small mutation surfaces;
- named invariants;
- visible side effects;
- stable command entry points;
- tests that mirror behavior boundaries;
- errors that identify the failed operation;
- limited compile-time indirection;
- documentation that points to source truth instead of replacing it.

## 2. Repository structure

Each top-level source directory MUST have one primary responsibility.

Use this initial source map:

```text
lib/kiln/
├── sessions/
├── workspaces/
├── events/
├── execution/
├── store/
├── providers/
├── tools/
├── context/
├── policy/
└── evidence/
```

A module path SHOULD match its module name.

Example:

```text
lib/kiln/execution/command.ex
Kiln.Execution.Command
```

Use one primary module per file. A private helper MAY share a file when separation would hide a single cohesive behavior.

Create a nested `AGENTS.md` only when a directory has additional rules. Do not copy the root instructions into nested files.

## 3. Public boundaries

Each capability SHOULD expose one clear public entry module.

Examples:

```text
Kiln.Sessions
Kiln.Execution
Kiln.Workspaces
```

Callers MUST use the public entry module unless an accepted design exposes another module.

A GenServer callback module MUST NOT become the public domain API by default.

Use this separation where state ownership requires a process:

```text
Public domain API
  -> pure validation and transition functions
  -> process owner
  -> external side effect
```

The process owner controls state and resource lifetime. Pure modules define deterministic rules.

## 4. Process boundaries

Create a process only when the process owns at least one of:

- mutable state;
- a resource lifetime;
- concurrency;
- cancellation;
- failure isolation;
- external communication.

Do not create a process for a data type, namespace, or pure transformation.

Each long-lived process MUST document:

- the state it owns;
- the messages it accepts;
- the child or resource lifetime it controls;
- its restart expectation;
- the durable state used after restart.

A supervisor restart MUST NOT be described as data recovery.

## 5. Data and state

Use structs for stable domain data.

Public structs SHOULD have `@type t` definitions when callers construct or inspect them.

Use explicit identifiers instead of process identifiers as durable identities.

Do not persist process identifiers, references, ports, tasks, or anonymous functions.

Keep durable state separate from runtime handles.

External input MUST NOT create atoms dynamically.

Configuration MUST enter through a defined boundary. Do not scatter `Application.get_env/3` calls through domain modules.

## 6. Side effects

A function name and module location SHOULD make side effects visible.

Prefer:

```text
Kiln.Store.append_event/2
Kiln.Execution.start_command/2
```

Avoid names that hide mutation behind generic verbs such as `process`, `handle`, or `manage` when a concrete verb is available.

Side-effecting functions MUST return enough information to record the operation outcome.

Do not rescue broad exception classes to convert unknown failures into success-shaped values.

Use tagged results at expected failure boundaries:

```elixir
{:ok, value}
{:error, reason}
```

Let unexpected programmer errors fail at the process boundary where supervision and evidence can observe them.

## 7. Indirection

Use a behaviour when the project has a replaceable boundary with at least one current implementation and a credible second implementation.

Do not add a behaviour only to make an internal function mockable.

Use macros only when a function, data structure, or generated file cannot express the requirement with comparable clarity.

A macro MUST identify the compile-time behavior and its effect on cross-reference dependencies.

Avoid dynamic module lookup unless the boundary requires runtime registration.

## 8. Functions and modules

A module MUST have one primary responsibility.

A public function SHOULD perform one domain operation.

Prefer explicit data flow over hidden state or process-dictionary use.

Use pattern matching to validate known shapes. Return an explicit error for expected invalid external data.

Do not add speculative parameters, callback hooks, configuration keys, or extension points.

Do not preserve unused compatibility paths before a released contract exists.

## 9. Documentation

Each public entry module MUST have a `@moduledoc` that states:

- its responsibility;
- its public boundary;
- its important invariants;
- the subsystem it does not own when confusion is likely.

Public functions SHOULD use `@doc` when the name and types do not fully state the contract.

Use examples only when the example is executable or can be verified against current code.

Documentation MUST NOT promise planned behavior as current behavior.

Repository documents SHOULD link to source modules, tests, ADRs, or commands that establish the claim.

## 10. Tests

Test paths SHOULD mirror source paths.

Example:

```text
lib/kiln/execution/command.ex
test/kiln/execution/command_test.exs
```

Tests MUST assert observable behavior.

Do not assert private implementation details when a public result or event provides the evidence.

Use `async: true` only when the test does not share mutable state, global configuration, named processes, or external resources.

Do not use arbitrary sleeps as synchronization.

Use monitors, messages, explicit acknowledgements, or bounded polling against an observable state.

A process test MUST terminate processes that it starts or link them to the test process.

A regression test SHOULD identify the defect or work-package ID in the test name or module documentation.

## 11. Error messages and logs

Errors MUST state:

- the failed operation;
- the relevant workspace, session, execution, or event identity when available;
- the reason category;
- whether retry is safe when the system knows that fact.

Logs MUST NOT become the only evidence of a state transition.

Do not log secrets, complete model prompts, credentials, or unrestricted command environments.

## 12. Change locality

A work package SHOULD change the smallest coherent set of modules.

A new feature SHOULD add or extend one public boundary rather than requiring callers to coordinate several internal modules.

When a change crosses subsystem boundaries, the plan MUST state the dependency direction and the reason.

Do not rename unrelated modules or reformat unrelated files in an implementation branch.

## 13. Discovery workflow

Before editing code, the coding agent MUST:

1. run `scripts/agent-preflight`;
2. read the current work-package plan;
3. read the applicable ADRs and invariant identifiers;
4. inspect the public entry module and corresponding tests;
5. use `mix xref callers` or `mix xref trace` when changing a shared boundary;
6. state the expected mutation surface.

Before completion, the coding agent MUST:

1. inspect the final diff;
2. run the narrowest relevant tests;
3. run `scripts/check`;
4. request read-only specialist review when the change touches OTP, persistence, security, or project invariants;
5. record evidence against acceptance criteria.

## 14. Agent-specific limits

The main coding agent is the default writer.

Specialist agents SHOULD inspect and report. They SHOULD NOT edit files.

A reviewer MUST separate:

- blocking defects;
- material risks;
- optional improvements;
- unknowns.

The coding agent MUST NOT implement optional reviewer suggestions unless they support the current work-package objective.

The coding agent MUST NOT create new product abstractions to support the development-agent workflow.
