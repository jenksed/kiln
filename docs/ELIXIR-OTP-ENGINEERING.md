# Elixir and OTP Engineering Guide

**Document type:** Reference

This guide defines Elixir and OTP practices for coding agents that build Kiln.

Use official Elixir, Erlang, and library documentation that matches the project version. Do not infer an external interface from model memory.

## 1. Design order

Use this order before selecting an OTP abstraction:

1. Define the observable behavior.
2. Define the data and invariants.
3. Implement deterministic transformations as functions.
4. Identify resource ownership and concurrency.
5. Add a process only when ownership or lifetime requires it.
6. Add supervision only after the child failure and restart behavior are known.
7. Add persistence separately from process restart.

Do not begin with a GenServer because the subsystem contains state nouns.

## 2. Process selection

Use an ordinary function when the operation:

- is deterministic;
- completes within the caller operation;
- does not own mutable state;
- does not own a resource;
- does not require independent cancellation or failure isolation.

Use `Task` or `Task.Supervisor` for bounded concurrent work that has a result or terminal outcome.

Use `GenServer` when one process must own mutable state or serialize access to a resource.

Use `DynamicSupervisor` when child identities and lifetimes are created at runtime.

Use `Registry` only when callers require stable lookup by a domain identity. Do not use process identifiers as durable identities.

Use a `Supervisor` to encode child lifecycle policy. Do not use a supervisor to hide an undefined recovery policy.

## 3. State ownership

Each state-owning process MUST document:

- the state shape;
- the domain identity;
- the accepted calls, casts, and messages;
- the reply and timeout behavior;
- the restart strategy;
- the state reconstructed after restart;
- the child or external resource cleanup behavior.

Prefer a small process state that contains runtime handles and a durable identity.

Do not keep the complete durable session record only in process memory.

## 4. Calls, casts, and messages

Use a synchronous call when the caller requires an accepted result before continuing.

Use a cast only when the caller does not require delivery confirmation or an immediate result.

Do not use a cast to hide backpressure or error handling.

Use messages for external process events, monitors, ports, and explicit asynchronous protocols.

Message payloads SHOULD use tagged tuples or structs with stable meaning.

A process MUST reject unknown or invalid domain commands with an observable result. It MAY crash on programmer errors that violate internal assumptions.

## 5. Supervision

Define the expected child termination categories before choosing a restart setting.

Use:

- `:permanent` when the child must remain available after any exit;
- `:transient` when abnormal exit requires restart but normal completion does not;
- `:temporary` when the supervisor must not restart the child.

A process that represents one command execution will likely use a bounded task or temporary child. The implementation plan must verify the choice.

Keep supervision trees shallow enough to explain.

A supervisor child order MUST reflect startup dependencies. Avoid hidden dependencies between siblings.

## 6. Cancellation and cleanup

Cancellation MUST have an observable lifecycle.

A cancellation design MUST state:

- who requests cancellation;
- which process owns termination;
- which operating-system process or port receives the signal;
- the grace period;
- the escalation action;
- how descendant processes are handled;
- which event records the outcome.

Do not equate `Task.shutdown/2`, closing a port, or killing one operating-system process with confirmed descendant cleanup.

Use monitors to observe termination when the caller needs proof.

## 7. Errors

Use tagged errors for expected domain and boundary failures.

Examples:

```elixir
{:error, :workspace_not_found}
{:error, {:command_exit, status}}
{:error, {:provider, reason}}
```

Do not return free-form error strings as the only machine-readable error.

Preserve external error details as evidence, but normalize the category used by domain code.

Do not rescue all exceptions around a subsystem. Rescue only errors that the boundary can classify and handle.

Use exceptions for programmer errors and invalid internal assumptions.

## 8. Structs, types, and protocols

Use structs for stable domain records.

Add `@type t` to public domain structs.

Use `@enforce_keys` only when construction without a field is always invalid. Runtime validation remains necessary for external input.

Use a behaviour for provider, store, or external boundary implementations when replacement is a current requirement.

Use a protocol when dispatch depends on the data type and the set of supported data types is intentionally open.

Do not introduce behaviours and protocols only to increase abstraction count.

## 9. Compile-time dependencies

Avoid macros for ordinary code reuse.

Avoid invoking project functions in module bodies unless compile-time evaluation is required.

Before changing a shared macro, struct, or imported module, inspect dependency effects with:

```bash
mix xref callers Module
mix xref trace path/to/file.ex
mix xref graph --format cycles --label compile-connected --fail-above 0
```

Compile-connected cycles are a failed quality gate.

## 10. Configuration

Read application configuration at a defined runtime or application boundary.

Pass configuration into domain modules as data.

Use `config/runtime.exs` only for values that require runtime evaluation.

Do not read environment variables throughout the codebase.

Do not put secrets in application environment logs or evidence records.

## 11. Testing

Use ExUnit as the default test framework.

A test SHOULD use `async: true` only when it has no shared mutable state or named external resource.

Test pure transition and validation modules without starting an application process when possible.

Test process boundaries with observable messages, monitors, and state queries.

Do not synchronize with arbitrary sleeps.

Use temporary directories for filesystem tests.

Do not depend on the developer's global Git configuration, credentials, home-directory files, or network access in unit tests.

Use real subprocesses only in integration tests that need operating-system behavior.

A cancellation test MUST prove the recorded terminal state. A cleanup test SHOULD prove that the expected operating-system process is no longer alive.

## 12. Documentation

Public domain entry modules MUST explain their responsibility and boundary with `@moduledoc`.

Use `@doc` for contracts that are not obvious from the function name and type.

Use doctests only for deterministic examples that improve the API explanation.

Do not use doctests as the primary evidence for process lifecycle behavior.

Elixir stores documentation in compiled module documentation chunks. Documentation remains inspectable through official tooling and `Code.fetch_docs/1`.

## 13. Performance

Do not optimize process count, message shape, copying, or binary handling without observed evidence.

Use bounded output collection for commands and provider streams.

Avoid converting large binaries to lists.

Do not retain full command output or model streams in process state when the journal or artifact store owns the durable content.

Measure mailbox growth for processes that receive unbounded external streams.

## 14. Dependency policy

Before adding a dependency, the coding agent MUST use the dependency-review skill.

Prefer the standard library when it meets the accepted requirement with clear code.

A dependency proposal MUST record:

- the requirement it satisfies;
- the exact version considered;
- the official documentation inspected;
- release and maintenance evidence;
- license;
- transitive runtime effect;
- alternatives;
- removal cost;
- security and native-code implications.

Do not add a dependency because it is common in unrelated Elixir applications.

Potential development tools such as Credo, Dialyzer, code coverage, property testing, and dependency audit tools remain proposals until a work package defines their value and acceptance cost.

## 15. Required checks

Run the narrowest relevant test during implementation.

Run the complete gate before completion:

```bash
scripts/check
```

The complete gate includes:

- Vale prose checks;
- Elixir formatting;
- warnings-as-errors compilation;
- compile-connected cycle detection;
- ExUnit tests.

A passing gate does not prove untested runtime behavior. The completion report must identify the behavior evaluated by each check.

## Official references

- Elixir documentation: https://hexdocs.pm/elixir/
- Mix documentation: https://hexdocs.pm/mix/
- ExUnit documentation: https://hexdocs.pm/ex_unit/
- Erlang/OTP documentation: https://www.erlang.org/doc/
