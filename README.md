# Kiln

Kiln is a local-first, evidence-driven coding harness built on Elixir and OTP for rapid, lucid AI-assisted software development.

Kiln is not an application scaffolder, an autonomous software company, an agent-management framework, or a catalog of protocol implementations. It is the durable runtime around model-driven repository work: execution, state, context, permissions, runs, interruption, recovery, and verification.

## Project thesis

A model supplies intelligence. The harness determines whether that intelligence becomes trustworthy software.

Kiln is designed to move work through:

> Intent → Orientation → Investigation → Change → Verification → Reconciliation → Completion

Kiln uses these foundational boundaries:

```text
Workspace: local operating and trust boundary
└── Project: durable software product or body of work
    └── Session: one accepted objective and work history
        ├── Tasks: bounded desired outcomes
        └── Run graph: durable execution and coordination attempts
            └── Root Run: Project Steward responsibility
```

The Session owns the objective. Tasks state desired work. Runs are the primary execution units. Agent definitions, Workers, model invocations, Tools, Commands, and external protocols operate within or beneath Runs.

Kiln supports bounded Child Runs without turning the product into an artificial organization of agents.

## Foundational direction

- **Runtime:** Elixir and OTP
- **Internal model:** Kiln-native and protocol-neutral
- **External integration:** adapters map protocols and mature tools to Kiln domain commands, events, and schemas
- **Capability selection:** use the simplest reliable integration that satisfies lifecycle, security, interoperability, isolation, and replaceability
- **Model-facing Tools:** small intent-level operations rather than protocol, server, vendor, or CLI catalogs
- **Objective boundary:** one durable Session
- **Desired-work boundary:** one bounded Task
- **Execution model:** one Root Run and a navigable Run graph
- **Primary execution unit:** Run, not Agent persona or model invocation
- **Delivery coordination:** Project Steward responsibility on the Root Run
- **Initial interface:** command-line interface
- **Durable state:** SQLite and an append-oriented event journal
- **Source truth:** Git and the filesystem
- **Authority:** explicit Capabilities, policy, and scoped grants
- **Evidence:** Claims remain separate from Evidence and Receipts
- **Web interface:** Phoenix LiveView, after the runtime is proven
- **Extensions:** language-neutral supervised subprocess protocol
- **First external software development kit:** TypeScript, after the protocol is proven
- **Gleam:** deferred until a concrete pure domain component earns it

No external protocol may become Kiln's internal domain model.

MCP is an optional protocol boundary, not Kiln's default integration layer and not a security sandbox.

## Capability integration

Kiln evaluates integrations in this order:

1. in-process function or library;
2. native Kiln adapter;
3. direct deterministic CLI;
4. local service API or Unix-domain socket;
5. local MCP server;
6. remote API or software development kit;
7. remote MCP server;
8. browser or user-interface automation.

Kiln selects the earliest practical option that satisfies the required contract.

Initial positions:

- Repository reads and writes are native.
- Git normally uses a native adapter backed by the Git CLI.
- Build, test, lint, format, compiler, package-manager, and static-analysis behavior uses existing CLIs.
- Raw LSP remains behind a native semantic adapter.
- Local MCP requires material lifecycle, state, sharing, replacement, discovery, or existing-implementation value.
- Remote MCP requires material interoperability and discovery value beyond a narrow API.
- Browser automation is a fallback unless browser behavior is under test.
- Mature tools are orchestrated rather than rebuilt.

The full Capability catalog remains outside model Context. A Run receives a small phase-relevant Tool projection such as `repo.read`, `code.inspect`, `command.run`, and `verify.run`.

See [Capability integration](docs/CAPABILITY-INTEGRATION.md).

## Project Steward

The Project Steward uses Kiln's Run graph, Tasks, specifications, Repository observations, Capability policy, Evidence, and completion gates to coordinate work.

The Steward can:

- decompose work into bounded Tasks and Runs;
- route attention;
- request independent verification;
- track requirements, mutations, Evidence, risks, and unknowns;
- reconcile Repository state against the accepted specification;
- recommend continuation, blocking, or completion.

The Steward cannot override user authority, policy, Repository truth, Evidence freshness, or completion gates.

## Current milestone

Phase 0 is defining the Repository and runtime foundation before implementation begins.

P0-W05 audits the integrated and stacked planning state. Read [Planning baseline](docs/PLANNING-BASELINE.md) before product, architecture, or roadmap work.

P0-W06 defines the [Internal domain model](docs/INTERNAL-DOMAIN-MODEL.md), JSON contracts, protocol-adapter boundary, and Run-centered execution semantics before Phase 1 implementation.

P0-W07 defines the [Capability integration](docs/CAPABILITY-INTEGRATION.md) hierarchy, deterministic broker, compact model-facing Tools, result normalization, duplicate policy, and initial non-MCP boundary.

The later roadmap reconciliation must align Phase 1 with:

- Workspace, Project, Repository, and Environment identity;
- Session, Task, Run, and event identity;
- minimum Context, Capability, Claim, Evidence, Receipt, and Checkpoint primitives;
- native Repository and Git behavior;
- Capability registration, availability, selection, permission, and normalization;
- fake navigable Child Runs;
- Client-local focus;
- attention routing;
- Project Steward projection;
- supervised execution;
- Repository observation and trust policy;
- provider-backed Root Runs;
- read-only Child Runs;
- independent verification.

See [Plan reconciliation](docs/PLAN-RECONCILIATION.md).

Provider and protocol experiments may run on isolated spike branches. They must not bypass the internal domain, integration hierarchy, execution-kernel, policy, privacy, output, Artifact, and Evidence gates.

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

Project-local Skills, prompts, and specialist agents support the coding agent that builds Kiln. They are development controls. They are not Kiln runtime Runs, Agent definitions, or Workers.

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

- [Planning baseline](docs/PLANNING-BASELINE.md)
- [Internal domain model](docs/INTERNAL-DOMAIN-MODEL.md)
- [Capability integration](docs/CAPABILITY-INTEGRATION.md)
- [Domain contracts](docs/contracts/README.md)
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

The repository intentionally begins with no third-party runtime dependencies. Use the project dependency-review skill before adding a library, executable, service, native implemented function (NIF), port program, development tool, or protocol client.

## Status

Kiln is pre-alpha. The architecture is being constrained before implementation and will be tested through dogfooding on real software projects.
