# Capability Integration

**Document type:** Reference  
**Decision status:** Owner-accepted direction  
**Integration status:** Proposed on P0-W07  
**Implementation status:** Not implemented  
**Contract version:** `kiln.capability/v0`

## Purpose

This document defines how Kiln discovers, selects, authorizes, invokes, and records software-development capabilities.

Kiln must use the simplest reliable integration that satisfies lifecycle, security, interoperability, isolation, and replaceability requirements.

Kiln must not use MCP or another protocol merely because a capability can be wrapped in that protocol.

The model-facing interface must express software-development intent. It must not expose transport selection, protocol envelopes, server identifiers, or provider mechanics.

## Default integration hierarchy

Kiln evaluates integrations in this order and selects the highest practical option:

1. in-process function or library;
2. native Kiln adapter;
3. direct deterministic command-line interface;
4. local service API or Unix-domain socket;
5. local MCP server;
6. remote API or software development kit;
7. remote MCP server;
8. browser or user-interface automation.

`Highest practical` means the earliest option that satisfies the required contract without creating unacceptable coupling, lifecycle risk, security exposure, output ambiguity, or replacement cost.

The hierarchy is a default, not a rule that in-process code always wins. Kiln must reject an earlier option when it fails a material requirement.

## Evaluation dimensions

Evaluate each candidate against:

- deterministic behavior;
- input and output contract quality;
- cancellation and timeout support;
- streaming and backpressure needs;
- lifecycle ownership;
- failure isolation;
- permission scope;
- secret handling;
- local-first operation;
- provenance quality;
- output size control;
- version compatibility;
- replaceability;
- installation and maintenance burden;
- interoperability value;
- availability detection;
- testability;
- recovery after interruption.

## Refined hierarchy

### 1. In-process function or library

Use when:

- the operation is deterministic or narrowly stateful;
- the library has a stable interface;
- the dependency can run inside Kiln's trust boundary;
- cancellation and fault isolation do not require a process boundary;
- the dependency does not introduce unsafe ambient authority;
- output can be normalized without parsing human-oriented text.

Prefer for:

- path and glob operations;
- text decoding and encoding;
- hashing and fingerprints;
- diff parsing;
- structured query planning;
- schema validation;
- deterministic filtering, ranking, truncation, and projection;
- repository reads and writes implemented through Kiln-owned file operations.

Do not use in-process solely to avoid spawning a mature CLI. A library that is harder to replace, less compatible, or less faithful than the established CLI is not the higher practical option.

### 2. Native Kiln adapter

A native adapter is Kiln-owned code that translates a mature native interface into Kiln domain operations.

Use when:

- Kiln needs stable semantic operations rather than raw transport access;
- the underlying capability has several implementations;
- Kiln must apply trust, privacy, output, and Evidence rules consistently;
- a direct library or CLI must be hidden behind a replaceable contract;
- the capability is central enough to justify a maintained Kiln abstraction.

Native adapters should own normalization, compatibility checks, availability probes, and implementation selection. They must not bypass the Capability broker.

Prefer native adapters for:

- Repository access;
- Git operations;
- semantic code inspection;
- command execution;
- verification orchestration;
- Artifact storage;
- model-provider access when accepted;
- local knowledge retrieval.

### 3. Direct deterministic CLI

Use when:

- the CLI is the mature authoritative interface;
- behavior is scriptable and non-interactive;
- arguments can be passed as an argument vector;
- exit status and machine-readable output are available;
- installation and version can be detected;
- Kiln can supervise, cancel, time out, and record the process;
- the CLI is easier to replace than a language-specific library.

Prefer existing CLIs for:

- Git;
- build systems;
- test runners;
- linters;
- formatters;
- compilers;
- package managers;
- static analyzers;
- project-specific maintenance commands.

Human-oriented text is acceptable only when no stable structured output exists and the parser is bounded, version-aware, and covered by fixtures.

### 4. Local service API or Unix-domain socket

Use when:

- the capability owns durable or expensive local state;
- several Runs or Clients need shared access;
- startup cost makes per-call processes wasteful;
- the capability needs subscriptions or long-lived streaming;
- a process boundary improves isolation;
- the service exposes a narrow stable API;
- local transport and authentication are simpler than a protocol framework.

Prefer a Unix-domain socket for one-host services when platform support and permissions are adequate. Prefer loopback HTTP only when tooling or portability justifies it.

### 5. Local MCP server

Local MCP is justified when one or more of these conditions are material:

- the capability is separately operated and has its own lifecycle;
- the capability is stateful across Kiln Sessions;
- the capability must remain independently replaceable;
- multiple clients need the same capability catalog;
- the capability already has a strong, maintained MCP implementation;
- MCP discovery and schema exchange remove meaningful integration work;
- the capability vendor or maintainer defines MCP as a primary supported interface.

Local MCP is not justified when:

- Kiln already has a simpler native or CLI path;
- the server only wraps local file reads, Git, shell commands, or a single API call;
- the wrapper adds no lifecycle, interoperability, or replacement value;
- the implementation weakens provenance or permission precision;
- the full server catalog would be copied into model context.

MCP is a protocol boundary. It is not a process sandbox, permission system, trust policy, or privacy boundary.

### 6. Remote API or software development kit

Use when:

- the capability is inherently remote;
- the provider has a narrow stable API;
- direct integration provides clearer authentication, errors, rate limits, and lifecycle semantics than MCP;
- Kiln benefits from precise request construction and normalized result handling;
- the integration can remain behind a native adapter.

Prefer a direct API over remote MCP when Kiln needs only a small stable portion of one service and discovery adds little value.

### 7. Remote MCP server

Remote MCP is justified when:

- interoperability across several clients is a primary requirement;
- dynamic discovery has real product value;
- the remote server exposes a broad changing capability set;
- the server has a strong security and operational posture;
- a narrow direct API would create substantial duplicate integration work;
- replacement among compatible servers is plausible and valuable.

Remote MCP should not be the default route to one narrow remote API. Remote transport increases trust, privacy, latency, availability, and supply-chain risk.

### 8. Browser or user-interface automation

Use only when:

- browser behavior is the capability under test;
- no supported library, CLI, service, API, or protocol interface exists;
- the user explicitly requires interaction with a human-only surface;
- the operation is bounded and its fragility is disclosed.

Browser automation is a fallback for capability integration. It is a first-class test mechanism when browser behavior itself is under test.

## Required positions

### Repository reads and writes

Repository reads and writes must be native in the initial system.

Kiln must own:

- path resolution;
- Workspace and Repository boundary enforcement;
- symlink policy;
- encoding detection;
- bounded reads;
- content digests;
- atomic replacement;
- patch application;
- mutation observation;
- Artifact and Change-set creation;
- Repository fingerprint binding.

Do not place core Repository access behind MCP in the initial system.

### Git

Git operations should normally use a native Kiln adapter backed by the Git CLI.

The adapter should expose Kiln-native operations such as status, diff, show, log, branch identity, worktree management, apply, commit preparation, and fingerprint observations. It should pass argument vectors, use stable output modes, normalize results, and preserve the exact Git command and version as provenance.

Do not rebuild Git object storage, index behavior, merge machinery, or worktree semantics inside Kiln.

### Build, test, lint, and format

Use the Project's existing CLIs through supervised Commands.

Kiln should discover and execute accepted verification entry points. It should not rebuild test runners, compilers, linters, formatters, or build systems merely to appear agent-native.

### Language servers

Raw LSP must remain behind a native semantic adapter.

The model-facing interface should ask for semantic intent such as:

- symbols at a location;
- definition and references;
- diagnostics;
- hover or type information;
- call hierarchy;
- rename feasibility;
- code actions.

The adapter owns LSP lifecycle, initialization, document synchronization, versioning, transport, server-specific compatibility, and conversion to Kiln-native results.

LSP messages and server object identities must not become Kiln domain entities.

### MCP

MCP must not be selected solely because a capability can be exposed through MCP.

Use local MCP only when separate operation, state, sharing, replacement, or an existing strong implementation creates material value.

Use remote MCP only when interoperability and discovery create more value than a narrow API integration.

MCP is not a security sandbox. Every MCP operation must pass through Kiln's Capability, Repository trust, Privacy, Approval, output, Artifact, Trace, and Receipt rules.

### Mature tools

Kiln should orchestrate mature tools rather than replace them. Agent-native behavior comes from Kiln's Run, Capability, Context, Evidence, and recovery model, not from reimplementing every tool.

## Decision tree

```text
Does Kiln already own the operation safely and deterministically?
├── Yes → use an in-process function or native Repository operation.
└── No
    ↓
Does Kiln need a stable semantic contract over one or more implementations?
├── Yes → use a native Kiln adapter.
└── No
    ↓
Does a mature deterministic CLI provide the required behavior?
├── Yes → supervise the CLI directly.
└── No
    ↓
Does the capability need a separately managed local lifecycle, shared state, or subscriptions?
├── Yes
│   ↓
│   Is a narrow local API or Unix socket sufficient?
│   ├── Yes → use the local API or socket.
│   └── No
│       ↓
│       Does a strong MCP implementation provide material discovery, sharing, or replacement value?
│       ├── Yes → use local MCP through an adapter.
│       └── No → build the narrowest local service contract.
└── No
    ↓
Is the capability inherently remote?
├── No → reassess requirements. Do not add a protocol wrapper without value.
└── Yes
    ↓
Does a narrow direct API satisfy the requirement?
├── Yes → use the API through a native adapter.
└── No
    ↓
Does remote MCP provide material interoperability or discovery value?
├── Yes → use remote MCP through an adapter.
└── No
    ↓
Is browser behavior itself under test or is no supported interface available?
├── Yes → use bounded browser automation.
└── No → capability is unsupported until a reliable integration exists.
```

## Capability broker

The Capability broker is Kiln's deterministic control plane for capability discovery, selection, authorization, execution routing, normalization, and audit.

It is not an Agent, model-facing catalog dump, protocol server, Tool implementation, or operating-system sandbox.

### Responsibilities

The broker must:

1. inventory native, CLI, local-service, API, MCP, and browser implementations;
2. maintain capability definitions and implementation registrations outside model context;
3. probe and update availability;
4. select candidate capabilities by Task phase and Run intent;
5. rank implementations by the hierarchy and deterministic preference;
6. detect duplicates and semantic overlap;
7. evaluate effective authority before use;
8. route requests to the selected implementation;
9. normalize result and error envelopes;
10. enforce output budgets and redaction;
11. store large or binary results as Artifacts;
12. preserve implementation, version, input digest, timing, policy, and Resource provenance;
13. emit lifecycle and availability events;
14. record use in Traces, Evidence when applicable, and Receipts;
15. support implementation withdrawal and replacement without changing model-facing Tool names.

### Non-responsibilities

The broker must not:

- decide Project intent;
- invent Capability grants;
- expose the complete catalog to the model;
- infer that availability means permission;
- promote an MCP Tool directly into the model-facing namespace;
- execute an operation before policy evaluation;
- treat normalized output as Evidence without an Evidence-producing method;
- bypass an adapter's lifecycle owner;
- hide representation loss or implementation fallback.

## Broker architecture

```text
Capability registrations and availability observations
                         ↓
                 Capability catalog
                         ↓
Task phase + Run intent + required result contract
                         ↓
               Candidate selector
                         ↓
Hierarchy rank + determinism + policy + health + cost
                         ↓
              Implementation decision
                         ↓
       Effective-authority and privacy evaluation
                         ↓
                  Execution router
                         ↓
       Result normalization and output limiting
                         ↓
 Artifact | Claim | Evidence | Trace | Receipt references
```

The catalog and selection logic are deterministic services. A shared broker process is justified only when it owns live availability subscriptions, health state, leases, or concurrent request routing. Capability definitions and registrations remain data.

## Task phases

The broker uses Task phase as one selection input. Initial phases are:

- orientation;
- investigation;
- change;
- verification;
- reconciliation;
- recovery.

A registration declares supported phases. The broker must not make a destructive change implementation available during orientation unless the Run explicitly requests change authority.

Examples:

- orientation prefers Repository inventory, Git status, Project instructions, and Environment inspection;
- investigation prefers search, read, semantic inspection, documentation lookup, and read-only runtime inspection;
- change permits bounded Repository mutation and accepted Commands;
- verification prefers Project-defined verification Commands and read-only inspection;
- reconciliation prefers diff, Evidence, Claim, Receipt, and completion-state queries;
- recovery prefers Checkpoint, execution status, process termination facts, Git state, and Artifact recovery.

## Capability registration model

Each implementation registration must contain:

```text
registration_id
capability_key
capability_version
implementation_id
implementation_kind
implementation_version
provider_or_owner
supported_operations
supported_task_phases
input_contract
result_contract
required_capabilities
resource_types
trust_class
privacy_class
locality
lifecycle_mode
isolation_mode
cancellation_mode
streaming_mode
output_profile
health_probe
availability_state
availability_observed_at
priority_adjustment
replacement_group
semantic_fingerprint
provenance
```

### Implementation kinds

Use these values:

- `in_process`;
- `native_adapter`;
- `cli`;
- `local_service`;
- `local_mcp`;
- `remote_api`;
- `remote_mcp`;
- `browser_automation`.

### Locality

Use:

- `in_process`;
- `host_local`;
- `workspace_local`;
- `network_local`;
- `remote`.

### Lifecycle mode

Use:

- `per_call`;
- `per_run`;
- `shared_managed`;
- `shared_external`.

### Availability

Availability states are:

- unknown;
- probing;
- available;
- degraded;
- unavailable;
- incompatible;
- disabled.

Availability observations are timestamped facts. They do not grant permission and do not remain valid indefinitely.

## Selection rules

The broker ranks candidates in this order:

1. satisfies the model-facing operation contract;
2. supports the current Task phase;
3. is available and version-compatible;
4. can operate within active trust and Privacy policy;
5. can satisfy required cancellation, streaming, isolation, and lifecycle semantics;
6. has active or requestable Capability authority;
7. follows the integration hierarchy;
8. is deterministic over probabilistic;
9. is local over remote when result quality is equivalent;
10. has structured output over human-oriented output;
11. has stronger provenance and Evidence production;
12. has lower output and Context cost;
13. has lower operational and replacement cost.

A selection decision must record all eligible candidates, exclusion reasons, chosen implementation, fallback policy, and semantic-loss disclosure.

The model can request a Capability by intent. It cannot choose a protocol or bypass ranking unless the user or accepted Project configuration explicitly pins an implementation.

## Permission integration

Capability registration answers `what can Kiln technically invoke?`

Permission evaluation answers `what may this Run invoke now?`

Before execution, the broker must resolve:

```text
registration is available
∩ operation maps to a defined Capability
∩ Workspace permits the Resource
∩ Repository trust policy permits the source and operation
∩ Privacy policy permits inputs, output, logging, and egress
∩ Session limits permit the operation
∩ Run has an active scoped Capability grant
∩ Approval exists when required
∩ implementation-specific required Capabilities are granted
= authorized invocation
```

The broker must bind the authorization decision to:

- registration and implementation version;
- Run;
- operation and normalized arguments digest;
- Resource scope;
- policy versions;
- grant identifiers;
- Approval identifiers;
- time and expiry;
- output and egress limits.

A fallback implementation requires a new authority evaluation. Permission for one implementation does not automatically authorize another implementation with broader egress, lifecycle, or Resource access.

## Result normalization

Every capability invocation returns one Kiln-native result envelope.

```text
status
summary
structured_data
artifact_refs
claim_refs
evidence_refs
attention_ref
warnings
errors
truncated
continuation
provenance
metrics
```

### Status

Use:

- completed;
- partial;
- failed;
- denied;
- canceled;
- timed_out;
- orphaned;
- unavailable;
- incompatible.

### Normalization rules

1. Preserve the native exit status, error code, or protocol result in provenance.
2. Map errors to Kiln categories without deleting native details.
3. Do not place unbounded raw output in `summary` or `structured_data`.
4. Store large text, binary data, logs, diffs, traces, and result sets as Artifacts.
5. Return stable identifiers and bounded excerpts to the model.
6. Record whether output is complete, sampled, filtered, transformed, redacted, or truncated.
7. Preserve ordering when ordering is meaningful.
8. Preserve source location, Repository state, command, request digest, implementation version, and observation time.
9. Do not convert a Tool result into Evidence automatically. An Evidence-producing operation must declare its method and state binding.
10. Never hide a fallback implementation, semantic loss, stale availability observation, or representation mismatch.
11. Normalize secrets to references or redacted values.
12. Use continuation handles that reference stored Artifacts or broker-owned cursors. Do not require the model to replay the original broad request.

## Output limits

Each registration declares an output profile:

- maximum inline bytes;
- maximum item count;
- maximum line count;
- maximum excerpt size;
- whether streaming is supported;
- whether pagination is stable;
- Artifact storage policy;
- redaction policy;
- model-summary policy.

Broker defaults must be conservative. The model can request a narrower slice or Artifact continuation. Expanding output beyond Run limits requires a new bounded request and may require Approval.

## Provenance

Each invocation must record:

- `tool_call_id`;
- model-facing operation;
- Capability definition and version;
- selected registration and implementation;
- integration kind;
- implementation version;
- adapter version when present;
- normalized input digest;
- native command or request digest;
- Environment and Resource references;
- Repository fingerprint when relevant;
- policy, grant, and Approval references;
- start and end times;
- termination or response code;
- output Artifact digests;
- normalization and redaction steps;
- fallback and semantic-loss disclosures.

## Model-facing Tool design

The initial model-facing namespace should remain compact:

- `repo.search`;
- `repo.read`;
- `repo.change`;
- `code.inspect`;
- `docs.lookup`;
- `runtime.inspect`;
- `command.run`;
- `verify.run`;
- `artifact.read`;
- `knowledge.search`;
- `capability.request`.

These are intent contracts. They are not one-to-one mappings to implementations.

### `repo.search`

Search active or permitted reference Repositories with bounded results and provenance.

Possible implementations:

- native file index;
- `git grep`;
- `rg`;
- semantic index;
- trusted knowledge adapter.

### `repo.read`

Read bounded Repository content by path, symbol-derived location, or search result reference.

Initial implementation must be native.

### `repo.change`

Create a bounded Change set through patch, atomic replacement, or approved file operation.

Initial implementation must be native. It must not mean arbitrary shell execution.

### `code.inspect`

Request semantic code facts such as symbols, definitions, references, diagnostics, types, call relationships, or structural queries.

Possible implementations:

- native parser or tree query;
- native semantic adapter over LSP;
- compiler or analyzer CLI.

The model never sends raw LSP messages.

### `docs.lookup`

Retrieve version-matched documentation from accepted local or remote sources.

Possible implementations:

- local documentation files;
- package-manager or language documentation CLI;
- narrow documentation API;
- justified MCP server.

### `runtime.inspect`

Inspect current Environment, process, container, service, log, or application state without mutation.

Possible implementations:

- native observer;
- deterministic CLI;
- local service API;
- justified local MCP when the operational system already exposes it strongly.

### `command.run`

Run one supervised non-interactive Command with explicit executable, arguments, working directory, Environment, limits, and required authority.

The model does not choose shell evaluation by default.

### `verify.run`

Run accepted Project verification entry points and produce Evidence-bound results.

Possible implementations are normally existing build, test, lint, formatting, compiler, or static-analysis CLIs.

### `artifact.read`

Read a bounded section or metadata view of a stored Artifact.

Initial implementation must be native.

### `knowledge.search`

Search Project knowledge and permitted reference content while preserving trust classification and preventing instruction promotion.

Implementation can use local indexes, local services, or a justified MCP server. Reference content remains untrusted input.

### `capability.request`

Request discovery or authorization for an operation not currently exposed or permitted.

It returns candidates, required authority, availability, and an Attention request when user Approval is required. It does not let the model register arbitrary integrations or choose remote transport.

## Small-interface rules

1. Do not expose one model-facing Tool for every CLI command, MCP Tool, API endpoint, or LSP method.
2. Do not include the full Capability catalog in model Context.
3. Select a small phase-relevant Tool subset for each Run.
4. Use schemas with intent-level fields and bounded options.
5. Keep transport, authentication, server identity, and version negotiation hidden from the model unless diagnosis requires them.
6. Return stable Kiln references rather than raw external object graphs.
7. Prefer explicit operations over a generic `execute_anything` Tool.
8. `command.run` is an escape hatch for accepted Commands, not an authorization bypass.

## Catalog projection into model Context

The broker maintains the full catalog outside model Context.

For one Run step, it can project:

- available intent-level Tool names;
- one-line purpose;
- bounded input schema;
- material authority requirement;
- important output limit;
- unavailability or Approval state when relevant.

The projection should normally contain fewer than twelve model-facing Tools. The broker can add or remove Tools when Task phase, Run state, availability, or authority changes.

## Duplicate-capability policy

Two registrations are duplicates when they satisfy substantially the same model-facing operation and semantic result contract over the same Resource class.

The broker computes or records a `semantic_fingerprint` from:

- operation contract;
- input and result schema versions;
- Resource types;
- mutation class;
- Evidence method;
- lifecycle and isolation semantics;
- trust and egress class.

### Duplicate groups

Registrations with the same or overlapping fingerprint belong to one replacement group.

The broker must:

- present one model-facing Tool;
- rank implementations deterministically;
- retain alternatives outside model Context;
- record the chosen implementation;
- re-evaluate authority before fallback;
- disclose semantic differences;
- avoid invoking multiple duplicates unless comparison or independent verification is the Task.

### Preference order inside a duplicate group

Prefer:

1. deterministic over probabilistic;
2. native and local over protocol and remote;
3. stronger state binding and Evidence production;
4. structured output;
5. narrower authority and egress;
6. healthy and version-compatible implementation;
7. lower operational cost;
8. Project-pinned implementation when accepted.

Do not silently merge results from duplicate implementations. Independent corroboration must produce separate provenance and Evidence.

## Availability changes

The broker must support capability availability changes without changing Tool identity.

Availability can change because of:

- executable installation or removal;
- version incompatibility;
- service startup or shutdown;
- MCP server connection state;
- authentication expiry;
- network loss;
- Environment change;
- Resource removal;
- policy disablement;
- adapter health.

The broker records availability observations and invalidates cached selection when relevant facts change.

An active operation follows its own lifecycle. Loss of future availability does not rewrite a completed result. Loss of a required live connection can fail, cancel, or orphan the active execution according to its contract.

## Receipts and Traces

Each material capability use must appear in the Run Trace.

A completion Receipt should reference capability use when it contributed to:

- Repository mutation;
- verification;
- Evidence;
- external egress;
- Approval;
- publication;
- recovery;
- a material decision.

The Receipt should identify the model-facing operation, selected implementation, authority decision, output Artifacts, Evidence, warnings, truncation, fallback, and unresolved uncertainty.

## Capabilities that must not use MCP initially

The initial system must not use MCP for:

- Repository path discovery;
- Repository file reads;
- Repository writes;
- patch or Change-set application;
- Git status, diff, log, show, branch, and worktree operations;
- process spawning and supervision;
- Command execution;
- Terminal lifecycle;
- project build commands;
- project test commands;
- lint commands;
- formatting commands;
- compiler invocation;
- Artifact storage and reads;
- SQLite event-journal access;
- Session, Task, Run, attention, Checkpoint, Trace, Claim, Evidence, Receipt, or completion queries;
- Capability grants, Approvals, trust policy, Privacy policy, or effective-authority evaluation;
- raw LSP transport exposed to the model.

These capabilities are Kiln core responsibilities, native adapters, or direct mature CLIs. Wrapping them in MCP would add protocol and lifecycle surface without enough interoperability value in the initial system.

## Initial MCP candidates

MCP can be evaluated later for:

- a separately operated local knowledge service shared by several clients;
- an existing mature documentation server with strong versioned retrieval;
- a stateful local application or data service that already has a maintained MCP interface;
- broad remote enterprise systems where dynamic discovery and cross-client interoperability are requirements;
- external research or knowledge systems whose protocol implementation is stronger than a narrow custom integration.

Each candidate still requires hierarchy evaluation, threat review, Privacy policy, Capability registration, duplicate detection, and an accepted work package.

## Acceptance criteria

### CAP-AC-001: Hierarchy selection

Given two implementations that satisfy the same result contract, when the earlier hierarchy option satisfies lifecycle, security, isolation, and replaceability requirements, then Kiln selects it unless an accepted Project rule records a material reason not to.

### CAP-AC-002: No MCP by convenience

Given a capability that has both a direct native or CLI implementation and an MCP wrapper, when MCP adds no material lifecycle, sharing, discovery, or replaceability value, then Kiln does not select MCP.

### CAP-AC-003: Repository operations remain native

Given a Repository read or mutation request, when Kiln executes the operation, then the initial implementation uses Kiln-native Repository operations and records boundary, digest, mutation, and fingerprint provenance.

### CAP-AC-004: Existing verification CLIs

Given an accepted build, test, lint, format, compiler, or static-analysis entry point, when Kiln verifies a Project, then Kiln supervises the mature CLI rather than rebuilding its behavior.

### CAP-AC-005: Raw LSP remains hidden

Given a semantic code-inspection request, when an LSP implementation is selected, then the model receives Kiln-native semantic results and never sends or receives raw LSP protocol messages.

### CAP-AC-006: Catalog stays outside Context

Given a catalog with more integrations than one Run needs, when Kiln builds the model-facing Tool projection, then it includes only the small phase-relevant intent interface and does not copy the full catalog into Context.

### CAP-AC-007: Permission remains separate

Given an available registration, when a Run lacks effective authority, then the broker denies execution or raises Attention for Approval and does not infer permission from availability.

### CAP-AC-008: Bounded normalized result

Given a capability result larger than the inline limit, when normalization completes, then Kiln stores the large result as an Artifact and returns a bounded summary, stable reference, completeness state, and provenance.

### CAP-AC-009: Duplicate collapse

Given native, CLI, API, or MCP registrations with the same semantic operation, when the model-facing projection is built, then Kiln exposes one intent Tool and ranks implementations outside Context.

### CAP-AC-010: Availability change

Given a selected implementation that becomes unavailable before invocation, when the broker re-evaluates the request, then it records the availability change, selects an authorized compatible fallback or returns unavailable, and does not silently broaden authority.

### CAP-AC-011: Trace and Receipt

Given a material Capability invocation, when it terminates, then its model-facing operation, selected implementation, authority, timing, result, Artifact, Evidence, warnings, and fallback state are available to the Run Trace and completion Receipt.

### CAP-AC-012: Browser fallback

Given a capability with a supported non-browser integration, when Kiln selects an implementation, then it does not use browser automation unless browser behavior itself is under test or an accepted exception records why the supported interface is insufficient.

## Initial implementation slice

Implement only enough broker behavior to prove:

1. registration of one native Repository implementation;
2. registration of one Git CLI adapter;
3. registration of one Project verification CLI;
4. availability probing;
5. phase filtering;
6. deterministic selection;
7. effective-authority evaluation;
8. bounded result normalization;
9. large-result Artifact storage;
10. Trace and Receipt references;
11. one duplicate group with deterministic preference;
12. one availability-loss fallback or explicit unavailable result.

Do not implement MCP, remote APIs, browser automation, dynamic protocol discovery, or a general plugin marketplace in the first slice.

## Deferred decisions

Implementation evidence must decide:

- exact broker module and process boundaries;
- registration storage format;
- health-probe cadence;
- semantic-fingerprint algorithm;
- selection scoring representation;
- stable pagination contracts;
- adapter packaging;
- MCP client library;
- remote authentication storage;
- cost and rate-limit inputs;
- browser automation framework;
- cross-client local MCP sharing requirements.

These decisions must not weaken the hierarchy, permission separation, compact model interface, or protocol-neutral internal domain.
