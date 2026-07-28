# Kiln Domain Contracts

**Status:** Foundational contract direction; not implemented  
**Contract family:** `kiln.domain/v0`

These JSON Schemas express Kiln-native domain contracts.

They do not define external protocol messages. An adapter can translate ACP, MCP, LSP, A2A, AG-UI, AHP, provider, terminal, or client messages to these contracts.

## Files

- `kiln-core.schema.json`: Workspace, Project, Repository, Environment, Session, Task, Run, Client focus, Context, Repository trust policy, and Privacy policy.
- `kiln-execution.schema.json`: Agent, Worker lease, model invocation, Capability, Capability grant, Skill, Resource, Tool call, Command, Terminal, Approval, Attention request, and Interruption.
- `kiln-evidence.schema.json`: Artifact, Change set, Claim, Evidence, Receipt, Trace reference, and Checkpoint.

## Rules

1. Kiln generates all core identifiers.
2. External identifiers belong in adapter-owned mapping records.
3. Unknown external fields do not enter a core entity.
4. A schema definition does not require a database table or OTP process.
5. State transitions are durable events. Entity documents can be immutable records or rebuildable projections.
6. Contract version `v0` is allowed to change before implementation. A later incompatible contract requires a new version.
7. Capability availability, effective authority, Evidence freshness, Trace, completion readiness, and most Client state are derived projections.
8. Process identifiers and runtime handles must never appear in these schemas.

## Validation

The schemas use JSON Schema Draft 2020-12. Cross-file references use stable `urn:kiln:schema:*` identifiers. A validator must register all three schemas in one catalog before resolving cross-file references.
