# P0-W21: Root Run lifecycle and durable journal

**Document type:** Focused planning work package  
**Status:** Implemented and verified on branch  
**Branch:** `work/p0-w21-root-run-lifecycle-journal`  
**Depends on:** P0-W20 integrated through pull request 25  
**Scope:** Root work state, transition authority, durable journal, restart reconstruction, and external-effect boundaries only  
**Build authorization:** Not issued

## Objective

Define the exact first-month Root Run transition contract and the smallest SQLite journal that reconstructs durable work without asking implementation to invent state, recovery, or persistence semantics.

## Entry evidence

- Prompt 4 integrated at merge commit `45acc2ed575957c53a8c57195d99c82965e9d48e`.
- OD-01 integrated at merge commit `bdcfcc5d4f4c6f74838d885c74c2240720b3dce1` but did not constrain this round.
- The OD-01 merge was current `main` when W21 began.
- Production source contained no Session, Task, Run, journal, migration, projection, or restart behavior.
- Prompt 3 marked IU-02, IU-06, IU-07, and IU-13 planning-dependent.

## Accepted planning decisions

P0-W21 proposes these decisions for owner acceptance and integration:

1. Persist Session states `active`, `completed`, and `abandoned`.
2. Persist Task states `in_progress`, `satisfied`, and `abandoned`.
3. Persist Root Run states `ready`, `running`, `waiting_for_user`, `orphaned`, `completed`, `failed`, and `canceled`.
4. Keep workflow step, pending decision, external-operation state, and Evidence state separate from Run status.
5. Start Session, initial Task, and Root Run atomically in usable states rather than persisting an unobservable `created` state.
6. Keep `completed`, `failed`, and `canceled` terminal.
7. Allow `orphaned` to leave only through explicit reconciliation.
8. Require every state-changing action to use expected revision, action identity, idempotency key, and canonical request digest.
9. Use one immutable append-oriented journal and one rebuildable Session projection.
10. Use direct Exqlite with one supervised connection and one writer.
11. Use WAL, `synchronous=FULL`, foreign keys, a 2-second busy timeout, and immediate write transactions on a local filesystem.
12. Use Kiln-owned forward SQL migrations with stable checksums.
13. Record external-operation intent before dispatch and never repeat an uncertain effect automatically.
14. Require completion to atomically align Session, Task, Root Run, user acceptance, current state, and the proof reference later defined by P0-W24.

## Files changed

- `docs/ROOT-RUN-LIFECYCLE-AND-JOURNAL.md`
- `docs/decisions/0022-use-exqlite-for-the-first-state-store.md`
- `docs/decisions/README.md`
- `docs/PLANNING.md`
- `docs/work/P0-W21-root-run-lifecycle-journal.md`

Final review-head compare against `main` before this closeout update:

- five changed Markdown files;
- 1,268 additions and seven deletions;
- no source or test change;
- no dependency, lockfile, migration, or runtime configuration change;
- no JSON Schema change;
- no CI, script, preflight, Skill, prompt, or agent change;
- no executable scaffold or product gate.

## Acceptance criteria

| Criterion | Result | Evidence |
| --- | --- | --- |
| Every first-month Run state is named and defined | Pass | lifecycle specification sections 1 and 2 |
| Every valid transition is defined | Pass | transition table |
| Invalid, duplicate, stale, denied, and uncertain requests are defined | Pass | invalid-request and failure matrices |
| Transition authority and expected revision are explicit | Pass | transition and authority matrices |
| Session and Task terminal alignment is explicit | Pass | atomic failure, cancellation, and completion transactions |
| Workflow, decision, operation, and proof state do not duplicate Run state | Pass | state-separation section |
| Journal entry, idempotency, sequence, and causation are defined | Pass | journal envelope and action-commit contract |
| Atomic transaction groups are defined | Pass | Session start, operation, decision, reconciliation, and completion transactions |
| Projection rebuild and transcript separation are defined | Pass | projection and transcript sections |
| SQLite boundary is selected | Pass | ADR-0022 and SQLite section |
| Migration, corruption, busy, startup, and unsupported-version behavior are explicit | Pass | startup, migration, integrity, and failure matrices |
| Restart and unknown-effect behavior are explicit | Pass | restart matrix |
| No provider, Patch, Command, Evidence, CLI, Child, or implementation scope enters | Pass | authority, exclusions, and implementation boundary |
| Review-head Repository validation passes | Pass | CI run `30419722173` on head `7cc2a0f769e947353be287e486be4f0acebba6de` |
| Exact closeout-head Repository validation passes | Pending | final CI required after this record update |

## Verification

Review head `7cc2a0f769e947353be287e486be4f0acebba6de` passed GitHub CI run `30419722173`.

The run passed:

- Vale;
- current agent-preflight behavior tests;
- Project agent-asset validation;
- dependency installation;
- formatting;
- warnings-as-errors compilation;
- compile-connected cycle detection;
- ExUnit.

The current preflight result still proves the obsolete P0 mechanics only. It does not prove accepted P1 ticket compatibility.

The final closeout commit requires one additional exact-head CI run.

## Evidence index

| Evidence ID | Scope | Evidence |
| --- | --- | --- |
| P0-W21-E01 | Entry gate | PR #25 and PR #26 merge commits; starting `main` identity |
| P0-W21-E02 | State and transition authority | lifecycle specification sections 2 through 5 |
| P0-W21-E03 | Journal and projection | lifecycle specification sections 6 through 8 |
| P0-W21-E04 | SQLite choice | ADR-0022 and official Exqlite and SQLite sources |
| P0-W21-E05 | Failure and restart | startup, commit-uncertainty, restart, and failure matrices |
| P0-W21-E06 | Change boundary | GitHub compare against `main` |
| P0-W21-E07 | Review verification | CI `30419722173` |
| P0-W21-E08 | Final verification | pending closeout-head CI |

## W22 ownership handoff

P0-W22 can consume:

- Run and operation identity;
- the common operation states;
- intent-before-dispatch;
- terminal or unknown result recording;
- expected revision and idempotency principles;
- conservative restart and orphan rules.

P0-W22 cannot add or change:

- Session, Task, or Run states;
- transition authority;
- journal entry envelope or projection ownership;
- migrations or store startup;
- completion transaction semantics.

Merge P0-W21 before P0-W22. Then rebase or restack W22 onto the integrated W21 result and audit it for lifecycle or persistence overlap.

## Explicit exclusions

P0-W21 did not:

- implement source, tests, migrations, dependencies, Schemas, scripts, or scaffolding;
- define MiniMax, Context, Tools, Repository reads, or disclosure;
- define Patch representation or Approval;
- define registered Command or process-tree semantics;
- define criterion Evidence, Receipt aggregation, or CLI presentation;
- define Child Runs, Attention, TUI, worktrees, protocols, telemetry, remote execution, or attestations;
- issue build authorization.

## Gate verdict

P0-W21 passes on this branch after the exact closeout head passes CI.

Owner review, acceptance, integration, and merge remain required.

## Exact next action

After final-head CI passes, mark pull request 27 ready and merge it before P0-W22. Reconcile W22 onto the resulting `main` and run an exact ownership audit before W22 integration.
