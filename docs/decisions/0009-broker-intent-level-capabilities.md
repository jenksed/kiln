# ADR 0009: Broker capabilities behind intent-level Tools

- **Decision status:** Accepted
- **Integration status:** Proposed on P0-W07
- **Date:** 2026-07-28

## Context

Kiln can support many native, CLI, service, API, MCP, and browser integrations. Exposing every implementation directly to a model would increase Context size, protocol coupling, duplicate Tools, permission confusion, and selection noise.

Kiln needs one deterministic component that keeps the full catalog outside model Context, selects implementations, applies policy, normalizes results, limits output, and preserves provenance.

## Decision drivers

- small model-facing interface;
- deterministic implementation preference;
- phase-specific Tool selection;
- least privilege;
- duplicate suppression;
- bounded output;
- Artifact-backed large results;
- replaceable implementations;
- availability changes;
- Trace and Receipt completeness;
- protocol-neutral Tool contracts.

## Decision

Kiln shall implement a Capability broker as a deterministic control-plane responsibility.

The broker shall:

- inventory implementation registrations;
- keep the complete catalog outside model Context;
- observe implementation availability and compatibility;
- filter candidates by Task phase and Run intent;
- rank implementations using ADR 0008;
- prefer deterministic implementations;
- detect duplicate semantic capabilities;
- evaluate effective authority before execution;
- route to the chosen implementation;
- normalize result and error envelopes;
- enforce output and privacy limits;
- store large results as Artifacts;
- preserve implementation and policy provenance;
- emit availability and invocation events;
- record material use in Traces and Receipts;
- re-evaluate authority before fallback.

The broker shall not grant authority, own Project intent, expose raw protocol catalogs, or turn an available integration into a permitted operation.

The initial model-facing Tool namespace shall be:

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

These Tool names express software-development intent. They do not identify protocols, servers, CLIs, vendors, or implementations.

The model-facing projection should normally contain fewer than twelve Tools and shall include only the operations relevant to the current Task phase, Run state, availability, and authority.

## Duplicate policy

Registrations that satisfy substantially the same operation and semantic result contract shall share a replacement group.

Kiln shall expose one intent-level Tool for the group and rank implementations outside model Context.

Kiln shall not invoke duplicate implementations together unless the Task explicitly requires comparison, corroboration, or independent verification.

A fallback shall receive a new authority evaluation and shall disclose implementation change and semantic loss.

## Result contract

Every capability invocation shall return a bounded Kiln-native envelope containing:

- status;
- summary;
- structured data;
- Artifact references;
- Claim and Evidence references when applicable;
- Attention reference when applicable;
- warnings and errors;
- truncation and continuation state;
- provenance;
- metrics.

Large, binary, or unbounded content shall be stored as Artifacts. The model receives bounded excerpts and stable references.

A Tool result shall not become Evidence automatically. An Evidence-producing operation must declare its method, producer, state binding, and freshness rule.

## Runtime ownership

Capability definitions, registrations, duplicate groups, selection rules, and result contracts are data.

A shared broker process is justified only when it owns live health subscriptions, availability state, concurrent routing, leases, or invalidation timers.

No process shall exist merely because `Capability broker` is a named architecture responsibility.

## Consequences

### Positive

- model Context stays small;
- models operate on development intent rather than protocol mechanics;
- duplicate integrations do not create duplicate model Tools;
- implementation replacement does not change the Tool contract;
- permission checks remain centralized;
- large results remain out of model Context;
- Traces and Receipts can identify exactly which implementation ran.

### Negative

- Kiln must define and maintain normalization contracts;
- selection and duplicate rules require fixtures;
- some protocol-specific features will be hidden or disclosed as semantic loss;
- availability probes and fallback create additional state;
- intent-level Tools can become too broad if contracts are not kept bounded.

## Rejected alternatives

### Expose the complete capability catalog to the model

Rejected because catalog size, duplicate Tools, and protocol details would consume Context and increase probabilistic selection errors.

### Use one generic execute Tool

Rejected because a universal execution primitive weakens intent contracts, permission precision, output limits, and Evidence semantics.

### Let each adapter enforce permissions independently

Rejected because authority, trust, Privacy policy, Approval, and fallback behavior must remain consistent across implementations.

### Treat Tool output as Evidence

Rejected because a successful invocation can produce incomplete, stale, transformed, or unverified output.

## Evidence and assumptions

### Evidence

- The internal domain model distinguishes Capability, Tool call, Artifact, Claim, Evidence, Receipt, Trace, and Context.
- The Security model requires effective-authority evaluation for every controlled operation.
- ADR 0008 defines implementation selection order.

### Assumptions

- A compact intent contract can represent the initial development operations.
- Large results can be stored and retrieved as Artifacts.
- Task phase and Run state are available to deterministic selection logic.
- Implementation-specific provenance can remain outside the model-facing Tool name.

## Superseded decisions

None.
