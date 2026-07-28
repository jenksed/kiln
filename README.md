# Kiln

Kiln is a local-first, evidence-driven coding harness built on Elixir and OTP for rapid, lucid AI-assisted software development.

Kiln is not an application scaffolder, an autonomous software company, or an agent-management framework. It is the durable runtime around model-driven repository work: execution, state, context, permissions, interruption, recovery, and verification.

## Project thesis

A model supplies intelligence. The harness determines whether that intelligence becomes trustworthy software.

Kiln is designed to move work through:

> Intent → Orientation → Investigation → Change → Verification → Reconciliation → Completion

The first product is for one developer working on local repositories. Other interfaces, extensions, and products may eventually build on the runtime, but they are not allowed to bloat the initial core.

## Foundational direction

- **Runtime:** Elixir and OTP
- **Initial interface:** CLI
- **Durable state:** SQLite
- **Source truth:** Git and the filesystem
- **Web interface:** Phoenix LiveView, after the runtime is proven
- **Extensions:** language-neutral supervised subprocess protocol
- **First external SDK:** TypeScript, after the protocol is proven
- **Gleam:** deferred until a concrete pure domain component earns it

## Current milestone

The first milestone is a local execution kernel that can:

1. open a repository workspace;
2. create and persist a session;
3. supervise a command;
4. stream and record its output;
5. cancel it safely;
6. observe repository state before and after execution;
7. restart and reconstruct the session accurately.

LLM integration follows only after those semantics are trustworthy.

## Work planning

Kiln uses short-lived branches and stable work-package identifiers.

Example:

```text
Plan:    docs/work/P1-W03-command-supervision.md
Branch:  work/p1-w03-command-supervision
PR:      [P1-W03] Add supervised command execution
Criteria: P1-W03-AC01
Evidence: P1-W03-E01
```

See [Branching and work planning](docs/BRANCHING-AND-WORK-PLANNING.md) before planned implementation.

## Documentation

- [Project provenance](docs/PROJECT-PROVENANCE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Session model](docs/SESSION-MODEL.md)
- [Security model](docs/SECURITY-MODEL.md)
- [Roadmap](docs/ROADMAP.md)
- [Branching and work planning](docs/BRANCHING-AND-WORK-PLANNING.md)
- [Engineering quality rules](docs/ENGINEERING-QUALITY-RULES.md)
- [Architecture decisions](docs/decisions/README.md)
- [Implementation plan template](docs/templates/IMPLEMENTATION-PLAN.md)
- [ADR template](docs/templates/ADR.md)

## Development

Kiln targets Elixir 1.20 on Erlang/OTP 28.

```bash
mise install
mix deps.get
vale .
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The repository intentionally begins with no third-party runtime dependencies. Dependencies should be introduced only when an accepted milestone requires them.

## Status

Kiln is pre-alpha. The architecture is intentionally narrow and will be validated by dogfooding on real software projects.