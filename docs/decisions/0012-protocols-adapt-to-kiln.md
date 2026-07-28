# ADR 0012: Protocols adapt to Kiln

- **Decision status:** Accepted
- **Integration status:** Proposed on P0-W09
- **Date:** 2026-07-28

## Context

Kiln needs editor integration, external Capabilities, code intelligence, user interfaces, execution isolation, and Evidence exchange. Several open protocols address parts of this surface.

Adopting a protocol too early can allow its object model, lifecycle, transport, or security assumptions to define Kiln's product. Kiln already has stronger product constraints:

- Kiln owns durable Session and Run truth.
- Interfaces are projections.
- The event journal and Repository observations support recovery.
- Capabilities remain behind explicit policy mediation.
- Completion depends on current Evidence.

## Decision

Kiln uses protocols through replaceable adapters around Kiln-native domain concepts.

The internal event model, command API, query API, Capability broker, Artifact model, and Evidence model MUST exist independently of any external protocol.

The accepted protocol positions are:

1. ACP is the primary editor and coding-client interface after Kiln proves its internal event stream.
2. AG-UI projects the same internal Run events and state used by the command-line interface, terminal user interface, LiveView, and ACP adapter.
3. AHP is a design reference for authoritative, reconnectable, synchronized Sessions. Kiln does not depend on AHP while the protocol is unstable.
4. MCP client support has higher priority than MCP server support.
5. MCP catalogs, discovery, and invocation remain behind Kiln's Capability broker.
6. A2A is reserved for independent external agents. Local Child Runs use Kiln's native execution model.
7. OpenAPI is preferred over MCP when a narrow existing service already has a precise HTTP contract and does not need model-oriented discovery.
8. LSP is normalized into a narrow semantic interface. Raw LSP is not exposed directly to models.
9. Tree-sitter is internal structural infrastructure. It is not a primary model-facing Tool.
10. DAP is valuable after the first useful coding loop. It is not required for that loop.
11. Agent Skills-compatible `SKILL.md` packages are first-class and load lazily.
12. OpenTelemetry observes Kiln itself. OTLP export is optional and replaceable.
13. Structured Evidence formats are ingested into Kiln's Evidence model. They do not become the canonical Evidence model.
14. WASI and WIT remain plugin-boundary experiments until a concrete extension justifies them.
15. Protocol versions and raw external identifiers are recorded at adapter boundaries so adapters can be replaced without rewriting durable Kiln state.

The detailed ranking, mappings, boundaries, and acceptance criteria are defined in [Protocol capability map](../PROTOCOL-CAPABILITY-MAP.md).

## Consequences

- Kiln MUST define stable native concepts before it ships major adapters.
- Adapters translate external messages into Kiln commands, queries, events, Capabilities, Artifacts, and Evidence.
- Protocol-specific state is stored as versioned adapter metadata, not as the primary domain model.
- Protocol catalogs cannot grant authority.
- A protocol implementation can be removed without invalidating Sessions, Runs, Evidence Receipts, or Repository history.
- Kiln MAY support only a useful subset of a protocol.
- Conformance tests MUST cover translation, cancellation, reconnection, authorization, and compatibility failure.

## Rejected positions

- Using ACP as Kiln's internal event model.
- Allowing MCP servers to bypass Capability policy.
- Using A2A for local Child Run orchestration.
- Exposing raw Tree-sitter trees or complete LSP catalogs to every model invocation.
- Treating AG-UI shared state or a transcript as authoritative Session state.
- Making JUnit, SARIF, OpenTelemetry, in-toto, or SLSA the canonical Kiln Evidence representation.
- Requiring WASI or WIT for the first extension protocol.

## Review triggers

Review this decision when one of these conditions becomes true:

- ACP cannot represent a required Kiln editor interaction without persistent protocol-specific state.
- AHP reaches a stable version and demonstrates interoperable multi-client implementations.
- MCP server demand exceeds MCP client demand for real Kiln workflows.
- a supported language cannot provide useful normalized semantics through LSP or another stable source;
- a WASI component delivers materially stronger isolation or portability than supervised native subprocesses;
- Evidence export becomes a release or supply-chain requirement rather than a local completion requirement.
