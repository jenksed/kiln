# ADR 0005: Attach Project Steward responsibility to the root run

- **Status:** Accepted
- **Date:** 2026-07-28

## Context

Kiln is intended to produce quality, working, specification-conformant applications while giving one developer more leverage than a conventional coding-agent setup.

A durable run graph provides execution structure, but the graph does not by itself protect delivery integrity. The system needs one explicit responsibility for maintaining the objective, coordinating bounded runs, tracing work to specifications, routing attention, requesting verification, and reconciling the final repository state.

A generic manager-agent hierarchy would conflict with Kiln's work-centered architecture and would add probabilistic coordination overhead.

## Decision drivers

- one responsibility must maintain the session objective and completion contract;
- delegated runs must remain aligned with accepted specifications;
- the system must select work based on current risk, unknowns, and evidence;
- verification and completion claims must remain traceable;
- user authority and deterministic gates must remain binding;
- delegation must increase leverage rather than agent activity;
- recovery must restore control state after interface or model failure.

## Considered options

### Let the active Builder own all coordination

Rejected because implementation confidence, specification tracking, attention routing, and independent verification require a distinct control responsibility even when one model performs several responsibilities.

### Add a hierarchy of manager agents

Rejected because it introduces agent-management overhead and weakens work-centered traceability.

### Attach Project Steward responsibility to the root run

Accepted because one root control context can coordinate runs, deterministic services, user decisions, and completion reconciliation without creating an artificial organization.

## Decision

Each session root run shall carry Project Steward responsibility by default.

The Project Steward shall:

- maintain the accepted objective and completion contract;
- preserve traceability from specification to work, changes, verification, evidence, and completion status;
- select direct execution or bounded delegation based on expected value;
- create and constrain child runs;
- route attention;
- track failures, risks, unknowns, and exclusions;
- request independent verification for material completion claims;
- reconcile intent, repository state, and current evidence;
- recommend continuation, blocking, or completion.

The Project Steward shall not:

- override user authority;
- change accepted intent without disclosure and approval;
- bypass capability policy;
- alter deterministic repository or evidence facts through narrative;
- hide failed or stale verification;
- permit concurrent writers in one checkout;
- report completion when the completion contract is not satisfied;
- create delegation only to simulate an organization.

Deterministic services remain authoritative for repository state, event ordering, capability decisions, resource ceilings, evidence freshness, recovery state, and acceptance status.

The Steward responsibility may be performed by one model, several bounded runs, deterministic code, or direct user commands. It is not tied to one fixed persona.

## Consequences

### Positive

- session delivery has one explicit control responsibility;
- specifications, runs, mutations, and evidence can remain connected;
- delegation can be judged by contribution to the objective;
- independent verification can be requested before completion;
- unresolved attention and risk remain visible;
- recovery can reconstruct the last durable control state;
- the user can inspect and override coordination decisions.

### Negative

- stewardship state and projections must be modeled explicitly;
- the root run requires clear authority and capability separation;
- poor Steward prompts could create planning loops without deterministic controls;
- completion logic must not depend on Steward confidence;
- implementation must prevent duplicate delegation after restart;
- dogfooding must measure whether stewardship reduces time to verified completion.

## Evidence and assumptions

### Evidence

- The project owner required a Project Steward focused on delivering quality, working, specification-conformant applications on 2026-07-28.
- Kiln already defines evidence-backed completion, capability policy, durable sessions, and work-centered planning.
- ADR 0004 defines a compatible root-run and child-run execution model.

### Assumptions

- The root run is the main session control context.
- User acceptance remains final.
- Deterministic checks can expose stale evidence and unsatisfied criteria.
- Initial child delegation remains bounded and read-only by default.

## Superseded decisions

This decision refines the earlier statement that Kiln maintains one model-driven worker.

It does not supersede the prohibition on agent-manager hierarchies.
