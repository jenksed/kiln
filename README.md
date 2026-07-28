# Kiln

Kiln is a local-first, evidence-driven coding harness built on Elixir and OTP for rapid, lucid AI-assisted software development.

Kiln is not an application scaffolder, an autonomous software company, or an agent-management framework. It is the durable runtime around model-driven repository work: execution, state, context, permissions, runs, interruption, recovery, and verification.

## Project thesis

A model supplies intelligence. The harness determines whether that intelligence becomes trustworthy software.

Kiln is designed to move work through:

> Intent → Orientation → Investigation → Change → Verification → Reconciliation → Completion

Kiln uses these foundational boundaries:

```text
Workspace
└── Session: one repository objective
    └── Run graph: inspectable units of work
        └── Root run: Project Steward responsibility
```

The session owns the objective. The run graph owns execution lineage. The Project Steward coordinates delivery toward specification-conformant, verified completion.

Kiln supports bounded delegated runs without turning the product into an artificial organization of agents.

## Foundational direction

- **Runtime:** Elixir and OTP
- **Objective boundary:** one durable session
- **Execution model:** one root run and a navigable run graph
- **Delivery coordination:** Project Steward responsibility on the root run
- **Initial interface:** command-line interface
- **Durable state:** SQLite
- **Source truth:** Git and the filesystem
- **Web interface:** Phoenix LiveView, after the runtime is proven
- **Extensions:** language-neutral supervised subprocess protocol
- **First external software development kit:** TypeScript, after the protocol is proven
- **Gleam:** deferred until a concrete pure domain component earns it

## Project Steward

The Project Steward uses Kiln's run graph, specifications, repository observations, capability policy, evidence, and completion gates to coordinate work.

The Steward can:

- decompose work into bounded runs;
- route attention;
- request independent verification;
- track requirements, mutations, evidence, risks, and unknowns;
- reconcile the repository against the accepted specification;
- recommend continuation, blocking, or completion.

The Steward cannot override user authority, policy, repository truth, evidence freshness, or completion gates.

## Current milestone

Phase 0 is defining the repository and runtime foundation before implementation begins.

The next planning pass must reconcile the current Phase 1 work packages with:

- session and run identity;
- durable run events;
- fake navigable child runs;
- client-local focus;
- attention routing;
- Project Steward projection;
- supervised execution;
- provider-backed root runs;
- read-only child runs;
- independent verification.

See [Plan reconciliation](docs/PLAN-RECONCILIATION.md).

Provider transport experiments may run on isolated spike branches. They must not bypass the accepted execution-kernel and evidence gates.

## Work planning

Kiln uses short-lived branches and stable work-package identifiers.

Example:

```text
Plan:      docs/work/P1-W03-command-supervision.md
Branch:    work/p1-w03-command-supervision
PR:        [P1-W03] Add supervised command execution
Criterion: P1-W03-AC01
Evidence:  P1-W03-E01
```

See [Branching and work planning](docs/BRANCHING-AND-WORK-PLANNING.md) before planned implementation.

## Agent-ready development

Project-local skills, prompts, and specialist agents support the coding agent that builds Kiln. They are development controls. They are not Kiln runtime runs.

The default workflow is:

```bash
scripts/agent-preflight
scripts/check
```

Project-local skills live under `.agents/skills/`:

- `kiln-work-package`
- `kiln-elixir-otp`
- `kiln-dependency-review`
- `kiln-integrity-review`
- `kiln-evidence-closeout`

Optional Pi specialist agents live under `.pi/agents/`. The OTP and integrity agents are read-only. The verifier may run non-mutating checks but may not edit files.

The main coding agent remains the default writer and owns final implementation decisions.

## Documentation

- [Project provenance](docs/PROJECT-PROVENANCE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Session model](docs/SESSION-MODEL.md)
- [Run model](docs/RUN-MODEL.md)
- [Project Stewardship](docs/PROJECT-STEWARDSHIP.md)
- [Security model](docs/SECURITY-MODEL.md)
- [Roadmap](docs/ROADMAP.md)
- [Plan reconciliation](docs/PLAN-RECONCILIATION.md)
- [Project invariants](docs/PROJECT-INVARIANTS.md)
- [Agent-friendly codebase rules](docs/AGENT-FRIENDLY-CODEBASE.md)
- [Elixir and OTP engineering guide](docs/ELIXIR-OTP-ENGINEERING.md)
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
scripts/agent-preflight
scripts/check
```

The repository intentionally begins with no third-party runtime dependencies. Use the project dependency-review skill before adding a library, executable, service, native implemented function (NIF), port program, or development tool.

## Status

Kiln is pre-alpha. The architecture is being constrained before implementation and will be tested through dogfooding on real software projects.
