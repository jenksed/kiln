# ADR 0008: Select the simplest reliable capability integration

- **Decision status:** Accepted
- **Integration status:** Proposed on P0-W07
- **Date:** 2026-07-28

## Context

Kiln can connect to the same software-development capability through an in-process library, native adapter, command-line interface, local service, MCP server, remote API, or browser automation.

Selecting protocols by novelty or uniformity would add lifecycle, security, output, and replacement costs without guaranteeing better product behavior.

Kiln must preserve its protocol-neutral internal domain. Capability integration must satisfy the required lifecycle, authority, isolation, provenance, and output contract while remaining as simple and replaceable as practical.

## Decision drivers

- local-first operation;
- deterministic behavior;
- clear lifecycle and cancellation;
- least privilege;
- strong provenance;
- bounded output;
- mature-tool reuse;
- implementation replaceability;
- protocol neutrality;
- low operational burden;
- honest isolation guarantees.

## Decision

Kiln shall evaluate capability implementations in this default order:

1. in-process function or library;
2. native Kiln adapter;
3. direct deterministic command-line interface;
4. local service API or Unix-domain socket;
5. local MCP server;
6. remote API or software development kit;
7. remote MCP server;
8. browser or user-interface automation.

Kiln shall select the earliest option that satisfies all material requirements. An earlier option shall be rejected when it fails required lifecycle, cancellation, isolation, authority, provenance, output, compatibility, or replaceability behavior.

Kiln shall use these initial positions:

- Repository reads and writes are native Kiln operations.
- Git uses a native Kiln adapter normally backed by the Git CLI.
- Build, test, lint, formatting, compiler, package-manager, and static-analysis behavior uses mature existing CLIs.
- Raw LSP stays behind a native semantic adapter.
- MCP is not selected only because a capability can be wrapped in MCP.
- Local MCP requires material lifecycle, state, sharing, replaceability, discovery, or existing-implementation value.
- Remote MCP requires material interoperability and discovery value beyond a narrow API integration.
- Browser automation is a fallback unless browser behavior is under test.
- MCP is a protocol boundary, not a sandbox, permission model, trust policy, or privacy boundary.
- Kiln shall not rebuild mature tools merely to make them appear agent-native.

Every implementation, including MCP and browser integrations, shall use Kiln-native Capability, Tool call, Resource, policy, Artifact, Evidence, Trace, and Receipt paths.

## Initial non-MCP boundary

The initial system shall not use MCP for:

- Repository reads, writes, path handling, patching, or Change sets;
- Git operations;
- Command and Terminal lifecycle;
- build, test, lint, format, compiler, or package-manager commands;
- Artifact and event-journal access;
- Session, Task, Run, attention, Checkpoint, Claim, Evidence, Receipt, Trace, or completion state;
- Capability grants, Approvals, Repository trust, Privacy policy, or effective authority;
- raw LSP access exposed to the model.

## Consequences

### Positive

- core operations remain inspectable and local;
- mature tools retain their established behavior;
- protocol adoption must justify its cost;
- implementations can be replaced behind stable Kiln contracts;
- model-facing Tools remain independent from transport;
- permission and privacy enforcement remain centralized;
- local and deterministic options receive a consistent preference.

### Negative

- Kiln must maintain several native adapters rather than one universal protocol bridge;
- CLI compatibility and parsing require version-aware fixtures;
- implementation selection needs a catalog and broker;
- some integrations need dedicated lifecycle code;
- protocol-specific features may not map without semantic loss.

## Rejected alternatives

### Use MCP as the default integration layer

Rejected because MCP does not provide operating-system containment, Repository policy, Privacy policy, Capability grants, Evidence semantics, or deterministic implementation preference.

### Rebuild mature tools inside Kiln

Rejected because it increases scope and correctness risk without improving the Run, Context, Capability, Evidence, or recovery model.

### Always use in-process libraries

Rejected because a library can create tighter coupling, weaker compatibility, more ambient authority, or worse isolation than a mature CLI or service.

### Always use direct APIs for remote systems

Rejected because some broad changing systems gain material interoperability and discovery value from a strong remote MCP implementation.

## Evidence and assumptions

### Evidence

- ADR 0006 establishes a protocol-neutral internal domain.
- ADR 0007 establishes Run as the primary execution unit.
- The Security model separates availability, policy, grants, and effective authority.
- The internal domain model defines Tool calls and external adapters without selecting a protocol.

### Assumptions

- Kiln can preserve one model-facing operation across several implementations.
- Existing CLIs remain the authoritative interface for many development tools.
- Protocol selection can be evaluated per capability rather than globally.
- Initial MCP value is lower for Kiln core operations than native and CLI integrations.

## Superseded decisions

None.
