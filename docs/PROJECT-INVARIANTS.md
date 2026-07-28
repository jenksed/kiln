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

### KILN-INV-023: Kiln owns the internal domain

No external protocol MAY define Kiln's core entities, identifiers, lifecycle, authority, persistence, or Evidence semantics.

External protocols MUST connect through adapters that use Kiln domain commands, queries, events, and schemas.

**Source:** `docs/decisions/0006-protocol-neutral-internal-domain.md`, `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-024: Run is the primary execution unit

Every independently inspectable unit of model-backed or deterministic work MUST be a Run.

An Agent persona, Worker process, model invocation, Tool call, protocol thread, or operating-system process MUST NOT replace Run identity.

**Source:** `docs/decisions/0007-run-primary-execution-unit.md`, `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-025: Task and Run remain separate

A Task MUST state desired work. A Run MUST represent one execution or coordination attempt for that Task.

Every Run MUST reference one Task. Completing a Run MUST NOT automatically satisfy the Task.

**Source:** `docs/decisions/0007-run-primary-execution-unit.md`, `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-026: Agent, Worker, and invocation remain separate

An Agent MUST be a versioned execution definition. A Worker MUST be a transient executor lease. A model invocation MUST be one provider request and response stream.

None of these concepts MAY own the durable work identity that belongs to the Run.

**Source:** `docs/decisions/0007-run-primary-execution-unit.md`, `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-027: Availability is not permission

Kiln MUST distinguish Capability availability, policy allowance, Capability grant, and effective authority.

A Tool, Skill, Agent, adapter, or Environment MUST NOT grant itself authority.

**Source:** `docs/SECURITY-MODEL.md`, `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-028: Child runs inherit no ambient authority

A Child Run MUST receive explicit Capability grants, Resource scope, Context, and limits.

A Parent Run MUST NOT transfer ambient path, network, secret, write, or publication authority.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`, ADR 0007

### KILN-INV-029: Claims are not evidence

A model statement, Agent conclusion, user assertion, Tool result summary, or completion narrative MUST be a Claim until Evidence supports or refutes it.

Kiln MUST NOT use confidence as proof.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-030: Evidence and receipts remain distinct

Evidence MUST be an immutable observation with method, producer, result, state binding, and freshness rule.

A Receipt MUST be an immutable sealed manifest that references Evidence. A Receipt MUST NOT make stale or missing Evidence current.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-031: Artifact inclusion is explicit

An Artifact MUST NOT enter model Context without a provenance-bearing Context item and immutable Context manifest.

Artifact existence MUST NOT imply instruction authority, Evidence status, or model visibility.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-032: Active project instructions outrank reference content

Content from a reference-only Repository or Project MUST remain untrusted input.

Reference content MUST NOT change active Project instructions, policy, product direction, or write authority unless the user explicitly accepts and records the change.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`

### KILN-INV-033: Privacy policy gates egress

Kiln MUST evaluate Privacy policy before Context, Artifacts, traces, Evidence, or secret-derived values leave their allowed boundary.

Capability to call a provider or adapter MUST NOT authorize all data to leave the local system.

**Source:** `docs/INTERNAL-DOMAIN-MODEL.md`, `docs/SECURITY-MODEL.md`

### KILN-INV-034: Process identity is not domain identity

Kiln MUST NOT persist a PID, port, monitor reference, BEAM Task, function, supervisor path, connection, or external request identifier as core domain identity.

A process MUST exist only when it owns concurrent state, lifecycle, timing, subscriptions, external communication, or fault isolation.

**Source:** ADR 0001, ADR 0007, `docs/INTERNAL-DOMAIN-MODEL.md`

## Review use

A plan MUST list each invariant that constrains the work.

An integrity review MUST identify:

- preserved invariants;
- threatened invariants;
- invariant changes that require an ADR;
- unknown effects that need verification.
