---
name: kiln-elixir-otp
description: Guides Elixir and OTP implementation in Kiln. Use when adding or changing modules, processes, supervisors, tasks, ports, messages, cancellation, configuration, or ExUnit tests.
compatibility: Kiln targets Elixir 1.20 and Erlang/OTP 28.
---

# Kiln Elixir and OTP

Read `docs/ELIXIR-OTP-ENGINEERING.md` and `docs/AGENT-FRIENDLY-CODEBASE.md` before implementation.

## Design sequence

1. Define observable behavior.
2. Define data and invariants.
3. Implement pure rules first.
4. Identify state or resource ownership.
5. Select the smallest OTP abstraction that owns the required lifetime.
6. Define failure, cancellation, and restart behavior.
7. Define durable reconstruction separately.
8. Write narrow tests before expanding the boundary.

## Process decision

Use a process only when it owns:

- mutable state;
- a resource lifetime;
- concurrency;
- cancellation;
- failure isolation;
- external communication.

Do not create a process for a namespace or pure data transformation.

For each process, document:

```text
Domain identity:
State owned:
Accepted messages:
External resources:
Normal termination:
Abnormal termination:
Restart policy:
Durable reconstruction source:
Cleanup evidence:
```

## Implementation rules

- Keep the public domain API separate from GenServer callbacks.
- Use structs and `@type t` for stable public domain data.
- Do not persist process identifiers, references, ports, tasks, or functions.
- Do not create atoms from external input.
- Use tagged errors for expected failures.
- Let unexpected programmer errors fail at an observable process boundary.
- Do not use casts to hide required acknowledgements or backpressure.
- Do not use arbitrary sleeps in tests.
- Do not add a behaviour, protocol, macro, or callback without a current requirement.
- Do not call application configuration throughout domain code.

## Shared-boundary inspection

When changing a macro, struct, public entry module, or imported module, run the relevant commands:

```bash
mix xref callers Module
mix xref trace path/to/file.ex
mix xref graph --format cycles --label compile-connected --fail-above 0
```

## Test strategy

- Test pure functions without processes.
- Use `async: true` only for isolated tests.
- Use monitors or explicit messages for lifecycle tests.
- Use temporary directories for filesystem behavior.
- Use real subprocesses only when operating-system behavior is under test.
- Assert the event or durable state that records terminal outcomes.

## Review before completion

Check:

- Is every process necessary?
- Is state ownership singular and explicit?
- Can the state be reconstructed after restart?
- Is cancellation observable?
- Can failure of one operation corrupt another session?
- Are external handles excluded from durable state?
- Do tests evaluate the accepted behavior?
- Did the change introduce compile-connected cycles?

Then run:

```bash
scripts/check
```
