# Project Invariants

**Document type:** Reference

This register gives stable identifiers to Kiln constraints that coding agents and reviewers must preserve.

An invariant is not a complete architecture description. Each invariant links to the source that establishes its rationale.

A work package that changes an invariant MUST include a new or superseding architecture decision record (ADR).

## Invariant register

### KILN-INV-001: Work is the central abstraction

Kiln MUST model the state of repository work. Kiln MUST NOT use an artificial organization of agents as its core abstraction.

**Source:** `docs/PROJECT-PROVENANCE.md`, `docs/ARCHITECTURE.md`

### KILN-INV-002: The initial product serves one developer

Kiln MUST optimize the initial product for one developer working on local repositories.

Hosted collaboration and multi-user control planes remain deferred.

**Source:** `docs/PROJECT-PROVENANCE.md`, `docs/ROADMAP.md`

### KILN-INV-003: Elixir and OTP own runtime coordination

Elixir and OTP MUST own session lifecycle, supervision, cancellation, streaming, resources, and runtime side effects in the initial system.

A second implementation language requires an accepted ADR.

**Source:** `docs/decisions/0001-elixir-otp-core.md`

### KILN-INV-004: Supervision is not persistence

A supervisor restart MUST restore runtime structure only.

Kiln MUST reconstruct durable development state from persisted events and current repository observations.

**Source:** `docs/PROJECT-PROVENANCE.md`, `docs/SESSION-MODEL.md`

### KILN-INV-005: The session journal is not the transcript

Kiln MUST store durable session and run events separately from conversational transcript projections.

A transcript MAY be a projection of events and model content.

**Source:** `docs/decisions/0002-durable-session-journal.md`, `docs/RUN-MODEL.md`

### KILN-INV-006: Git and the filesystem remain source truth

Kiln MUST NOT replace Git as source-history authority.

Kiln MUST observe repository state and bind its evidence to that state.

**Source:** `docs/PROJECT-PROVENANCE.md`, `docs/ARCHITECTURE.md`

### KILN-INV-007: Completion requires current evidence

Kiln MUST distinguish model claims from observations.

Kiln MUST NOT treat stale evidence as proof of the current repository state.

**Source:** `docs/SESSION-MODEL.md`, `docs/PROJECT-STEWARDSHIP.md`

### KILN-INV-008: Permissions use explicit capabilities

Tools, extensions, and runs MUST request explicit capabilities.

BEAM process isolation MUST NOT be represented as operating-system containment.

**Source:** `docs/SECURITY-MODEL.md`, `docs/RUN-MODEL.md`

### KILN-INV-009: Interfaces do not own session truth

The command-line interface, Phoenix interface, and future clients MUST use an explicit domain API.

An interface MUST NOT become the authoritative owner of durable session or run state.

**Source:** `docs/ARCHITECTURE.md`

### KILN-INV-010: The command-line interface remains independent

Kiln MUST remain usable through the command-line interface without Phoenix or a browser.

**Source:** `docs/PROJECT-PROVENANCE.md`, `docs/ROADMAP.md`

### KILN-INV-011: Extensions cross a language-neutral boundary

The primary public extension boundary MUST use supervised external processes and a versioned language-neutral protocol.

Native Elixir extensions MAY exist. They MUST NOT become the only extension path.

**Source:** `docs/decisions/0003-language-neutral-extensions.md`

### KILN-INV-012: Scaffolding is outside the core

Application generators, web framework defaults, database selection, authentication scaffolds, and deployment generators MUST NOT enter the core runtime.

These features MAY exist later as external extensions or products.

**Source:** `docs/PROJECT-PROVENANCE.md`

### KILN-INV-013: Deterministic code owns bookkeeping

Kiln MUST use deterministic code for repository fingerprints, event recording, permission enforcement, evidence freshness, invalidation, cancellation, acceptance status, and state reconstruction when deterministic implementation is feasible.

**Source:** `docs/PROJECT-PROVENANCE.md`, `AGENTS.md`

### KILN-INV-014: Development agents are not product runs

Project-local skills, prompts, and specialist agents support the construction and review of Kiln.

They MUST NOT be described as Kiln runtime components or used as evidence that the Kiln run model is implemented.

**Source:** `docs/work/P0-W03-agent-ready-development.md`, `docs/RUN-MODEL.md`

### KILN-INV-015: Delegated work is a first-class run

When delegated work requires independent inspection, steering, cancellation, evidence, or recovery, Kiln MUST create a child run.

Kiln MUST NOT hide such work inside an opaque background tool call.

**Source:** `docs/decisions/0004-first-class-run-graph.md`, `docs/RUN-MODEL.md`

### KILN-INV-016: Run lineage is not OTP supervision

Kiln MUST store logical parent-child run relationships independently from OTP supervisor-child relationships.

A user-interface hierarchy MUST NOT dictate fault-containment structure.

**Source:** `docs/decisions/0004-first-class-run-graph.md`, `docs/ARCHITECTURE.md`

### KILN-INV-017: Run focus is client-local

Each client MUST own its focused run independently from the session and from other clients.

Changing client focus MUST NOT change run execution or another client's view.

**Source:** `docs/RUN-MODEL.md`, `docs/ARCHITECTURE.md`

### KILN-INV-018: Attention routing is depth-independent

A run that requires user input, permission, conflict resolution, or failure handling MUST emit a normalized attention item.

Attention delivery MUST NOT depend on the run's nesting depth.

**Source:** `docs/RUN-MODEL.md`, `docs/SESSION-MODEL.md`

### KILN-INV-019: Concurrent writers require isolation

Kiln MUST NOT allow multiple writing runs to modify one checkout concurrently.

A writing child requires an isolated Git worktree or a patch artifact that a controlling run reviews and applies.

**Source:** `docs/RUN-MODEL.md`, `docs/decisions/0004-first-class-run-graph.md`

### KILN-INV-020: The root run carries Project Steward responsibility

Each session root run MUST carry Project Steward responsibility by default.

The Steward MUST maintain delivery traceability and reconcile the objective, repository state, and current evidence.

**Source:** `docs/decisions/0005-project-steward.md`, `docs/PROJECT-STEWARDSHIP.md`

### KILN-INV-021: The Project Steward is constrained

The Project Steward MUST NOT override user authority, capability policy, repository truth, evidence freshness, acceptance status, or completion gates.

The Steward MUST disclose blocked work, failed verification, material uncertainty, and unresolved specification gaps.

**Source:** `docs/decisions/0005-project-steward.md`, `docs/PROJECT-STEWARDSHIP.md`

### KILN-INV-022: Delegation must serve delivery

The Project Steward SHOULD delegate only when a child run improves evidence, parallelism, specialization, independent review, steering, cancellation, or recovery.

Kiln MUST NOT optimize for the number of active runs.

**Source:** `docs/PROJECT-STEWARDSHIP.md`, `docs/PROJECT-PROVENANCE.md`

## Review use

A plan MUST list each invariant that constrains the work.

An integrity review MUST identify:

- preserved invariants;
- threatened invariants;
- invariant changes that require an ADR;
- unknown effects that need verification.
