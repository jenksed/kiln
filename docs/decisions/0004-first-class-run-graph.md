# ADR 0004: Model delegated work as first-class runs

- **Status:** Accepted
- **Date:** 2026-07-28

## Context

Kiln must support investigation, implementation, research, verification, and background work without turning delegated tasks into opaque tool calls.

The existing project direction defined one durable session and one model-driven worker. That model does not provide enough structure for independently inspectable delegated work, concurrent read-only investigation, nested attention, client-local navigation, or recovery of child activity.

The project also prohibits agent-manager hierarchies. A run model must preserve work as the central abstraction.

## Decision drivers

- delegated work must be inspectable, steerable, cancellable, and recoverable;
- each delegated task needs separate context, capabilities, artifacts, evidence, and resource accounting;
- interfaces must navigate the same durable execution structure;
- nested requests for user attention must not disappear;
- logical work lineage must not dictate OTP fault-containment structure;
- the system must not become an artificial organization chart;
- concurrent writing must not corrupt one checkout.

## Considered options

### Represent delegated work as tool calls

Rejected because tool calls do not provide sufficient lineage, navigation, independent context, attention, cancellation, or recovery semantics.

### Represent each agent as an organizational role

Rejected because Kiln optimizes work state and delivery, not a hierarchy of artificial employees.

### Represent each independently inspectable unit of work as a run

Accepted because runs can support model work, deterministic work, background execution, verification, and future clients through one domain model.

## Decision

Each session shall contain one root run.

When Kiln delegates an independently inspectable task, Kiln shall create a child run.

Runs shall form a durable navigable graph through `session_id`, `root_run_id`, and `parent_run_id` relationships.

Each run shall own or reference:

- a bounded task;
- context;
- transcript projection;
- capability profile;
- tool executions;
- artifacts;
- evidence;
- resource accounting;
- cancellation state;
- attention state;
- completion result.

Logical run lineage shall remain separate from OTP supervision relationships.

Each client shall maintain its focused run independently from the session and from other clients.

Attention routing shall operate independently of run depth.

Kiln shall prohibit concurrent writing runs from modifying one checkout. Writing children require isolated worktrees or patch artifacts before they are enabled.

## Consequences

### Positive

- delegated work becomes inspectable and recoverable;
- terminal, web, and protocol clients can project one shared execution model;
- child work can fail without corrupting parent state;
- parent views can show live child projections without copying transcripts;
- resource and evidence accounting can be per run;
- nested attention can reach the user through one inbox;
- independent verification becomes a natural run type.

### Negative

- session persistence and projection become more complex;
- the event model must distinguish session and run events;
- client navigation requires explicit focus state;
- resource limits and orphan recovery require domain rules;
- writing concurrency requires worktree or patch boundaries;
- early implementation must prove a vertical run slice before broad delegation.

## Evidence and assumptions

### Evidence

- The project owner accepted navigable delegated runs as foundational direction on 2026-07-28.
- Existing Kiln documents did not define run lineage, client-local focus, or attention routing before this decision.
- The existing event-journal and interface-projection decisions provide compatible foundations.

### Assumptions

- A session remains the objective boundary.
- A run remains a bounded execution boundary.
- Initial delegation depth and concurrency will be limited.
- The first child runs will be read-only.

## Superseded decisions

This decision narrows the earlier single-worker framing in `docs/PROJECT-PROVENANCE.md`.

It does not supersede the rule that work is the central abstraction or the prohibition on agent-manager hierarchies.
