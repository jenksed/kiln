# AGENTS.md

## Project identity

Kiln is a local-first, evidence-driven coding harness built with Elixir and OTP.

The project helps one developer move repository work from intent to verified completion with less context loss, weaker claims, and unsafe execution.

## Required references

Before planned work, read:

- `docs/BRANCHING-AND-WORK-PLANNING.md`;
- `docs/ENGINEERING-QUALITY-RULES.md`;
- the applicable work-package plan in `docs/work/`;
- the relevant architecture and decision records in `docs/`.

## Non-negotiable principles

1. Optimize project throughput, not agent activity.
2. Keep the core small and inspectable.
3. Prefer deterministic code over probabilistic bookkeeping.
4. Treat Git and the filesystem as source truth.
5. Keep the session journal separate from the transcript.
6. Bind verification evidence to repository state.
7. Use capability-based permissions.
8. Keep interfaces behind an explicit domain API.
9. Do not make multi-agent management a core abstraction.
10. Do not add scaffolding, marketplaces, cloud services, or browser-IDE features to early milestones.

## Language boundaries

- Elixir owns runtime processes, supervision, resources, streaming, and side effects.
- Gleam is deferred. It may later own selected pure rules or protocol transformations.
- External tools should cross a supervised process or protocol boundary.
- Rust may later support operating-system isolation if a demonstrated requirement justifies it.
- Do not introduce a second language without an accepted architecture decision record (ADR).

## OTP guidance

Do not create a process for every noun.

Use a process when it owns mutable state, a resource lifetime, concurrency, cancellation, failure isolation, or external communication. Keep deterministic transformations as ordinary pure modules.

Supervision restores runtime structure. Persisted events and repository observations restore durable state.

## Work-package discipline

Planned work MUST use a work-package identifier and a branch that follows `docs/BRANCHING-AND-WORK-PLANNING.md`.

A `work/` branch MUST have one plan in `docs/work/`.

Use the same work-package identifier in:

- the plan filename;
- branch name;
- issue and pull-request titles when present;
- requirements;
- acceptance criteria;
- evidence identifiers;
- completion reports.

Each branch MUST have one primary objective. Split independent objectives into separate work packages.

## Change discipline

Before implementation:

- inspect current Git state;
- record the observed current state and evidence;
- state the objective and exclusions;
- identify assumptions and unknowns;
- define requirements and acceptance criteria;
- identify applicable architecture constraints;
- identify required verification and evidence.

During implementation:

- distinguish observed, inferred, proposed, assumed, and unknown information;
- update the work-package plan when material facts change;
- record an ADR for each material architecture decision;
- do not reverse an accepted ADR without a superseding ADR.

Before completion:

- run the narrowest meaningful checks;
- run the full available project checks;
- inspect the final diff;
- link acceptance criteria to evidence;
- report failures, warnings, unknowns, and exclusions;
- confirm that the repository state matches the completion report;
- never claim verification that did not run.

If required verification cannot run, report `implemented but unverified`. Do not report the work package as complete.

## Standard checks

```bash
vale .
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Documentation rules

- Follow `docs/ENGINEERING-QUALITY-RULES.md`.
- Give each document one primary purpose.
- Use Easy Approach to Requirements Syntax (EARS)-compatible requirements when applicable.
- Use Given-When-Then for behavioral acceptance criteria when applicable.
- Support material repository claims with current evidence.
- Do not claim formal ASD-STE100 compliance.
- Roadmap status must match implementation evidence.
- Distinguish accepted, provisional, and deferred decisions.
- Prefer omission over unsupported content.