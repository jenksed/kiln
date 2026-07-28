# ADR 0006: Own a protocol-neutral internal domain model

- **Status:** Accepted
- **Integration:** Proposed on P0-W06
- **Date:** 2026-07-28

## Context

Kiln must connect to models, language servers, tool servers, agent clients, user interfaces, terminals, and other mature systems.

These systems use different concepts for sessions, tasks, agents, tools, resources, permissions, messages, events, and traces. Their lifecycles and security assumptions also differ.

If Kiln adopts one external protocol as its internal model, Kiln will inherit that protocol's omissions, naming, authority rules, and release cycle. Later integrations will require core changes or parallel internal models.

Kiln already requires durable Sessions, first-class Runs, capability mediation, Repository truth, evidence freshness, interruption recovery, and interface independence. No current external protocol defines all these requirements as Kiln needs them.

## Decision drivers

- Kiln must preserve stable product semantics across protocol changes.
- Security and Evidence rules must remain under Kiln control.
- External identifiers must not define durable Kiln identity.
- Protocol support must remain replaceable and optional.
- Core persistence must not store protocol envelopes as canonical events.
- Mature tools must connect without becoming the product architecture.
- The internal model must support native CLI, TUI, web, and headless clients.

## Considered options

### Adopt one agent or tool protocol as the internal model

Rejected because it gives an external specification authority over Kiln lifecycle, security, persistence, and Evidence semantics.

### Create one internal model per protocol

Rejected because it fragments Session and Run truth and makes cross-protocol work difficult to inspect and recover.

### Own one Kiln-native model and use adapters

Accepted because Kiln can preserve one domain while each adapter translates protocol-specific messages, identifiers, capabilities, and events.

## Decision

Kiln shall own a versioned, protocol-neutral internal domain model.

The core model shall use Kiln-native concepts and identifiers for:

- Workspace, Project, Repository, and Environment;
- Session, Task, Run, and Run lineage;
- Agent definition, Worker lease, and model invocation;
- Capability, Capability grant, Skill, Resource, Tool call, Command, and Terminal;
- Approval, Attention request, Interruption, Client, and Client focus;
- Artifact, Change set, Claim, Evidence, Receipt, Trace reference, and Checkpoint;
- Repository trust policy and Privacy policy.

An external protocol shall connect through an adapter.

An adapter shall:

- parse and validate external messages;
- map external identifiers to Kiln identifiers in adapter-owned data;
- translate external operations to Kiln domain commands and queries;
- translate Kiln events and projections to external responses;
- preserve protocol metadata outside canonical core entities;
- use the same policy, approval, interruption, and Evidence path as native clients.

A core entity, event, database table, command, or query shall not require a protocol-specific field.

ACP, MCP, LSP, A2A, AG-UI, AHP, provider APIs, terminal protocols, and client bridges are adapter concerns. This list does not establish an implementation roadmap for those protocols.

## Consequences

### Positive

- Kiln retains control of durable identity and lifecycle.
- Run, capability, trust, privacy, and Evidence semantics remain stable.
- Protocol adapters can change or be removed without migrating the core model.
- Several protocols can operate against one Session and Run graph.
- Native clients and adapters use one authorization path.
- External protocol support does not become a protocol catalog objective.

### Negative

- Every protocol requires explicit translation code.
- Some external features will not map without loss.
- Adapter conformance and mapping tests become required.
- Kiln must maintain its own schemas and versioning rules.
- The model must resist speculative fields added only for possible protocols.

## Guardrails

- External IDs shall not be core primary keys.
- Raw protocol envelopes shall not be canonical domain events.
- Adapter availability shall not create a Capability grant.
- Core modules shall not import protocol-specific types.
- Adapter metadata shall not alter Repository trust or Privacy policy.
- A protocol feature without a Kiln product requirement shall remain outside core.
- Compatibility aliases shall remain at adapter or migration boundaries.

## Evidence and assumptions

### Evidence

- The planning baseline identifies LSP, MCP, and ACP boundaries as unresolved and warns against becoming a protocol catalog.
- ADR 0003 already requires a language-neutral supervised extension boundary.
- The accepted Run model requires semantics that are independent of interface and provider protocols.

### Assumptions

- Kiln can define stable domain commands, queries, events, and schemas before implementing adapters.
- Adapter-owned identifier mappings are sufficient for interoperability.
- Some protocol semantics will require explicit loss or approximation disclosures.

## Superseded decisions

This ADR does not supersede ADR 0003. ADR 0003 defines the public extension process boundary. This ADR defines the internal semantic boundary that all extensions and adapters must use.
