# Project provenance

**Status:** Foundational  
**Project stage:** Greenfield  
**Primary user:** The project owner  
**Operating model:** Local-first, single-developer coding harness

## Why Kiln exists

Kiln exists to give one developer substantially more leverage when building real software with AI.

It is the durable runtime around model-driven repository work. Models supply reasoning and generation. Kiln supplies state, execution, permissions, context, interruption recovery, repository awareness, verification, provenance, and completion semantics.

The product should make model-driven development:

- faster without weakening control;
- lucid rather than transcript-bound;
- recoverable after interruption;
- inspectable at the level of runs, actions, artifacts, and evidence;
- provider-flexible;
- difficult to mark complete on stale evidence;
- able to use bounded parallel work without losing lineage.

## Product thesis

Most coding tools center the conversation loop:

> prompt → model → tool call → model → answer

Kiln centers the state of the development work:

> intent → orientation → investigation → change → verification → reconciliation → completion

These are harness states. They are not agent personas and not necessarily separate model prompts.

Kiln models three foundational work boundaries:

```text
Workspace
└── Session: one repository objective
    └── Run graph: independently inspectable units of work
        └── Root run: Project Steward responsibility
```

The session is the durable objective boundary.

The run graph is the durable execution model.

The Project Steward is the delivery-coordination responsibility attached to the root run.

The Steward uses Kiln's run graph, policy, repository observations, evidence, recovery, and interfaces to move the objective toward specification-conformant, verified completion.

Kiln does not model an artificial company. Bounded delegated runs exist to improve investigation, implementation, verification, research, or recovery. The work remains the central abstraction.

## Why first-class runs

Delegated work must not disappear into opaque background tool calls.

When a delegated task needs independent inspection, steering, cancellation, evidence, or recovery, Kiln creates a first-class run.

Each run has or references:

- a bounded task;
- separate model context;
- status;
- capabilities;
- transcript projection;
- artifacts;
- evidence;
- resource accounting;
- cancellation state;
- attention state;
- parent and root relationships.

Clients can enter a run, observe activity, provide input, inspect evidence, cancel it, and return to its parent.

Logical run lineage remains separate from OTP supervision. The interface tree must not determine fault-containment structure.

## Why Project Stewardship

A run graph provides execution structure. It does not by itself keep work aligned with the objective or accepted specification.

The Project Steward maintains delivery integrity by:

- preserving the active intent and completion contract;
- tracing specifications to runs, mutations, verification, and evidence;
- choosing direct execution or bounded delegation;
- routing attention;
- identifying blockers and unknowns;
- requesting independent verification;
- reconciling the final repository state;
- blocking a completion recommendation when evidence is missing or stale.

The Steward is not an autonomous manager persona.

The Steward cannot override:

- user authority;
- capability policy;
- Git or filesystem truth;
- event ordering;
- evidence freshness;
- acceptance status;
- completion gates.

The role may be performed by one model, several bounded runs, deterministic services, or direct user control.

## Why Elixir and OTP

Kiln coordinates independent, long-lived, and failure-prone activities:

- model streams;
- commands and tests;
- run processes;
- filesystem observation;
- permission requests;
- repository mutation tracking;
- evidence collection;
- attention routing;
- interface connections;
- external extension processes;
- user interruption and recovery.

Node can support these responsibilities through asynchronous input and output, subprocesses, worker threads, and lifecycle conventions. Kiln chooses the BEAM because lightweight processes, message passing, supervision, and isolated state ownership are the runtime's normal operating model.

The claim is deliberately narrow:

> For a local-first coding harness where durable sessions, first-class delegated runs, supervised execution, interruption recovery, concurrent tool activity, interface independence, and evidence-backed completion are primary requirements, Elixir and OTP provide a better default runtime architecture than a conventional in-process Node implementation.

This advantage only matters if it becomes observable product behavior.

OTP supervision does not provide durable recovery by itself. Supervisors restore running structure. Persisted events and repository observations restore known development state.

Logical run parents do not necessarily supervise child processes.

## Why not Gleam first

Gleam is attractive for protocols, state-transition rules, evidence states, capability policy, and other pure domain logic. It is deferred because the first risks are operational: ports, subprocesses, streaming, dynamic supervision, persistence coordination, Phoenix integration, and third-party BEAM libraries.

Kiln starts as a single-language Elixir system. Gleam may be introduced later when a specific pure component benefits enough from stronger compile-time guarantees to justify the boundary.

## Why not TypeScript as the trusted center

TypeScript remains strategically important for provider software development kits, abstract syntax tree tooling, browser automation, editor components, Model Context Protocol integrations, and extension distribution.

Kiln should consume those capabilities through explicit supervised process and protocol boundaries. Elixir owns runtime integrity. External ecosystems provide specialized capabilities.

## Why not C or Rust for the core

C optimizes for low-level control at the cost of safety and integration velocity. Rust is a stronger future candidate for a small sandbox or pseudo-terminal helper, but neither language is the best initial fit for a system dominated by lifecycle coordination, recoverable state, streaming, and live interfaces.

## Initial boundaries

Kiln begins with:

- Elixir and OTP for the runtime;
- a durable session and run graph;
- Project Steward responsibility on the root run;
- a permanent command-line interface;
- SQLite for harness state;
- Git and the filesystem as repository truth;
- Phoenix LiveView as a later web projection;
- language-neutral supervised subprocesses for external extensions;
- TypeScript as the likely first extension software development kit;
- read-only child runs before writing children;
- one writer per checkout until worktree or patch isolation exists.

## Explicit non-goals

The initial core does not include:

- application scaffolding;
- authentication or object-relational mapping generators;
- autonomous engineering organizations;
- manager-agent hierarchies;
- unlimited recursive delegation;
- concurrent child writes to one checkout;
- automatic product-direction changes;
- hosted collaboration;
- plugin marketplaces;
- an embedded browser integrated development environment;
- automatic commits, pushes, merges, or pull requests;
- a vector database by default;
- broad provider coverage before the execution model is trustworthy.

## Success standard

Kiln succeeds when the developer trusts it because the harness can show:

- what objective and specification govern the session;
- which runs performed the work;
- what changed;
- which attention items and risks remain;
- what was verified;
- what evidence became stale;
- why the Steward recommends continuation, blocking, or completion.

Trust must come from preserved state and current evidence, not from a persuasive completion message.
