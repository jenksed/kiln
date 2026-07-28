# Branching and Work Planning

**Document type:** Reference

Kiln uses branch names as execution coordinates. A branch name identifies the planned unit of work, its roadmap phase, and its purpose.

Kiln uses trunk-based development. `main` is the integrated project truth. Kiln MUST NOT use a permanent `develop` branch or long-lived phase branches.

## Work identifiers

Kiln uses these stable identifiers:

```text
P1          Phase 1
P1-W02      Phase 1 work package 2
P1-X01      Phase 1 experiment 1
ADR-0004    Architecture decision 4
```

A work-package identifier MUST remain the same in each related artifact.

```text
Plan:          docs/work/P1-W02-supervised-command.md
Branch:        work/p1-w02-supervised-command
Issue title:   [P1-W02] Supervised command execution
PR title:      [P1-W02] Add supervised command execution
Requirement:   P1-W02-R01
Criterion:     P1-W02-AC01
Evidence:      P1-W02-E01
```

The shared identifier connects intent, implementation, verification, and completion evidence without a separate planning taxonomy.

## Branch classes

### `work/`

Use `work/` for accepted roadmap work packages.

```text
work/p1-w02-supervised-command
work/p3-w04-evidence-freshness
```

A `work/` branch MAY contain code, tests, documentation, and configuration when they serve one objective.

### `fix/`

Use `fix/` for a defect in accepted behavior.

```text
fix/p1-w03-cancel-race
fix/session-replay-order
```

Use the originating work-package identifier when the defect maps to one work package.

### `spike/`

Use `spike/` for a time-bounded experiment that answers one technical unknown.

```text
spike/p1-x01-pty-options
spike/p5-x02-extension-framing
```

A spike MUST define:

- the question;
- the time or effort limit;
- the evidence to collect;
- the decision that the evidence will inform.

A spike MUST NOT merge experimental implementation into `main` unless the branch is converted into an accepted work package.

### `docs/`

Use `docs/` for isolated documentation corrections that do not change requirements, architecture, or planned behavior.

```text
docs/clarify-local-setup
```

A material planning or architecture change MUST use `work/` and the applicable identifier.

### `chore/`

Use `chore/` for repository maintenance that does not change product behavior.

```text
chore/update-ci-cache
chore/refresh-dev-runtime
```

### `release/`

Use `release/` only for a short-lived release preparation branch.

```text
release/v0.1.0
```

### `hotfix/`

Use `hotfix/` only for an urgent correction to a released version.

```text
hotfix/v0.1.1-session-corruption
```

## Naming grammar

Use this grammar:

```text
<class>/<work-id>-<purpose>
```

The `<purpose>` segment MUST:

- use lowercase kebab case;
- use concrete nouns or verbs;
- describe the work boundary;
- omit names of agents, models, or contributors;
- omit generic words such as `changes`, `updates`, `misc`, or `improvements`.

Examples:

```text
work/p1-w01-session-domain
work/p1-w02-event-journal
work/p1-w03-command-supervision
fix/p1-w03-descendant-cleanup
spike/p1-x01-process-group-control
```

## Branch purpose rules

Each branch MUST have one primary objective.

A branch SHOULD be mergeable after one to three focused development sessions. If a branch accumulates two independent objectives, split the branch.

A branch MUST NOT represent an entire roadmap phase.

A branch MUST NOT exist only to hold unreviewed work for an indefinite period.

A branch MAY depend on another open branch when the dependency is explicit. Prefer independent branches when the file and contract overlap is low.

## Required work-package plan

Each `work/` branch MUST add or update one plan in `docs/work/`.

The plan filename MUST start with the work-package identifier.

```text
docs/work/P1-W03-command-supervision.md
```

The plan MUST use `docs/templates/IMPLEMENTATION-PLAN.md` and contain:

1. objective;
2. observed current state and evidence;
3. assumptions and unknowns;
4. requirements;
5. proposed changes;
6. expected files or components;
7. acceptance criteria;
8. verification commands;
9. required completion evidence;
10. explicit exclusions.

The plan MUST identify dependencies on other work packages.

## Requirement and evidence identifiers

Requirements use this form:

```text
P1-W03-R01
```

Acceptance criteria use this form:

```text
P1-W03-AC01
```

Completion evidence uses this form:

```text
P1-W03-E01
```

A pull request MUST link each completion claim to an acceptance criterion and its evidence.

## Commit and pull-request rules

Commits SHOULD represent meaningful implementation states. Commits MUST NOT record every agent action.

A commit MAY use the work-package identifier:

```text
P1-W03: add command lifecycle types
P1-W03: supervise command cancellation
```

A pull-request title MUST use this form:

```text
[P1-W03] Add supervised command execution
```

A pull-request body MUST state:

- objective;
- observed starting state;
- changes;
- acceptance status;
- verification evidence;
- failures and warnings;
- unknowns and exclusions;
- dependencies.

## Merge rules

Before merge, the branch MUST:

1. contain one coherent work package;
2. satisfy its acceptance criteria;
3. execute its required verification;
4. record the verification result;
5. disclose failures, warnings, unknowns, and exclusions;
6. match the completion report;
7. include an ADR for each material architectural decision;
8. update roadmap status when the merge changes phase status.

Squash merge is the default for a work package. Preserve multiple commits only when the commit boundaries have lasting review or diagnostic value.

Delete the branch after merge.

## Parallel work

Parallel branches SHOULD have low file overlap and settled interface boundaries.

When two branches depend on an unsettled interface, complete the interface-defining work package first.

When stacked pull requests are necessary:

1. set the dependent pull request base to the prerequisite branch;
2. state the dependency in both plans;
3. do not report the dependent work as ready for `main` until the prerequisite merges;
4. change the dependent pull request base to `main` after the prerequisite merges.

## Phase 1 branch map

Phase 1 begins with these proposed work packages:

| ID | Branch | Purpose | Depends on |
| --- | --- | --- | --- |
| P1-W01 | `work/p1-w01-session-domain` | Define workspace, session, event, execution, fingerprint, and checkpoint types. | P0 |
| P1-W02 | `work/p1-w02-event-journal` | Persist append-oriented session events in SQLite and reconstruct a session. | P1-W01 |
| P1-W03 | `work/p1-w03-command-supervision` | Start, stream, time out, cancel, and record a command. | P1-W01, P1-W02 |
| P1-W04 | `work/p1-w04-git-observation` | Capture Git state and repository fingerprints before and after execution. | P1-W01, P1-W02 |
| P1-W05 | `work/p1-w05-cli-projection` | Expose session and execution state through the CLI. | P1-W02, P1-W03, P1-W04 |
| P1-W06 | `work/p1-w06-restart-recovery` | Reconstruct interrupted sessions and report the last known safe state. | P1-W02, P1-W03, P1-W04 |
| P1-W07 | `work/p1-w07-phase-proof` | Execute and record the Phase 1 acceptance scenario. | P1-W05, P1-W06 |

This map is proposed until each work-package plan is accepted.

## Bootstrap exception

`agent/bootstrap-project-foundation` predates this policy. It is a one-time exception. New planned branches MUST follow this document after P0-W02 merges.