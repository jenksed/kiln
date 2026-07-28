# ADR 0007: Use Run as the primary execution unit

- **Status:** Accepted
- **Integration:** Proposed on P0-W06
- **Date:** 2026-07-28

## Context

Kiln must coordinate work that can use models, deterministic code, tools, commands, terminals, human input, and external adapters.

The current planning direction defines first-class Runs for independently inspectable delegated work. The internal model still needs precise boundaries among Session, Task, Run, Agent, Worker, and model invocation.

If the primary unit is an Agent persona, durable work state becomes coupled to a prompt role or model runtime. A persona cannot reliably define recovery, cancellation, capability scope, context scope, Evidence, or completion across several invocations and Workers.

If the primary unit is a model invocation or process, one restart, retry, tool wait, or model change fragments the work history.

## Decision drivers

- Work must survive model and process failure.
- The user must inspect, interrupt, resume, measure, and cancel work independently.
- Authority and context must be scoped to durable work.
- One unit must connect Task, execution, Artifacts, Claims, Evidence, and results.
- Deterministic and model-backed work must use the same execution model.
- Logical lineage must remain separate from OTP supervision.
- Agent personas must not become an organization chart.

## Considered options

### Use Agent as the primary unit

Rejected because Agent definitions describe execution strategy, not durable work identity or lifecycle.

### Use model invocation or process as the primary unit

Rejected because one Run can require several invocations, tool calls, commands, process replacements, and recovery attempts.

### Use Task as the primary execution unit

Rejected because a Task states desired work and can require several execution attempts. Task status and execution status need different semantics.

### Use Run as the primary unit

Accepted because a Run can preserve one bounded execution or coordination attempt across Workers, invocations, tools, interruption, recovery, and Evidence production.

## Decision

A Run shall be Kiln's primary durable execution unit.

Every Run shall:

- have one Kiln-generated identity;
- belong to one Session;
- reference exactly one Task;
- reference one Root Run;
- reference zero or one Parent Run;
- have an explicit lifecycle status;
- have an explicit context manifest;
- have a versioned Agent binding when model reasoning is used;
- have explicit capability grants and limits;
- record resource use;
- own or reference Tool calls, model invocations, Commands, Artifacts, Claims, Evidence, attention, interruptions, Checkpoints, and a structured result;
- remain identifiable after its Worker or process dies.

The Run shall be independently identifiable, inspectable, interruptible, resumable when recovery is valid, measurable, permission-scoped, context-scoped, Evidence-producing, and cancellable.

A Session shall own one accepted objective and its complete work history.

A Task shall state one bounded desired outcome or decision. One Task can have several Runs over time. A completed Run shall not automatically satisfy its Task.

An Agent shall be a versioned execution definition. It shall not own Run state or authority.

A Worker shall be a transient live executor that holds a bounded lease to advance one Run. A replacement Worker shall not create a new Run unless the work is a new execution attempt by product decision.

A model invocation shall be one provider request and response stream owned by a Run. One Run can contain zero, one, or many model invocations.

Root Run, Parent Run, and Child Run shall be Run roles and relationships. They shall not require separate tables, structs, or OTP process types.

Logical Run lineage shall not determine OTP supervision. Runtime process ownership shall follow lifecycle, concurrency, cancellation, subscriptions, external communication, and fault-isolation needs.

## Consequences

### Positive

- Work state survives model, Worker, process, and interface failure.
- Model-backed and deterministic work share one domain.
- Permission, context, measurement, and Evidence can be scoped to one unit.
- Child work can be navigated without an agent organization hierarchy.
- Task retries and alternative approaches remain explicit.
- Client views can inspect one shared Run graph.
- Recovery can mark uncertain execution as orphaned without losing the Run.

### Negative

- Task and Run lifecycles require separate projections.
- Worker leasing and orphan recovery require explicit rules.
- Run records can contain many related execution records.
- Small tool operations must not be promoted to Runs without a reason.
- Agent and Skill terminology must be migrated across existing planning text.

## Guardrails

- A Run shall not be identified by a PID, port, model request ID, protocol thread ID, or Agent name.
- A Run shall not inherit ambient capabilities from its Parent Run.
- A model invocation shall not mark a Run complete.
- Completing a Run shall not automatically satisfy a Task.
- A Child Run shall belong to the same Session as its Parent Run.
- The Run graph shall be acyclic.
- A logical Parent Run shall not become the OTP supervisor by default.
- A Tool call shall remain a Tool call unless it requires independent inspection, steering, interruption, measurement, Evidence, or recovery.
- A Worker lease shall expire or terminate before another Worker advances the same Run concurrently, unless the Run contract explicitly allows coordinated Workers.

## Evidence and assumptions

### Evidence

- ADR 0004 accepts first-class Runs for independently inspectable delegated work.
- The planning baseline defines Run as one independently inspectable unit and states that Agent is not the durable domain object.
- The Session and Project Steward models require durable state across model and process interruption.

### Assumptions

- One active Worker per Run is the initial default.
- A later Run can coordinate several internal deterministic services without turning each service into a Run.
- Task satisfaction can be derived from accepted criteria and current Evidence.

## Superseded decisions

This ADR refines earlier uses of `agent`, `worker`, `sub-agent`, and `model-driven worker` as broad execution terms.

It does not supersede ADR 0004. ADR 0004 establishes first-class Run lineage. This ADR establishes the Run as the primary execution unit and separates it from Task, Agent, Worker, and model invocation.
