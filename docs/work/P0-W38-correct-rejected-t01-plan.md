# P0-W38: Correct the rejected P1-S02-T01 plan

**Document type:** Implementation plan
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w38-correct-rejected-t01-plan`
**Depends on:** P0-W37 merged at `f9b5a312ac31ee4015025a87bcd3cec199b12297`; PR #48 rejected and closed without merge at `7ba158bddff76ade9aca79cb8501e675bd0cded9`

## Objective

Replace the rejected P1-S02-T01 contract with one coherent proposed plan that resolves its Evidence-result, persistence, protected-classification, TTL, and Artifact-API defects while preserving PR #48 as rejected history, changing no Kiln runtime path, and granting no implementation authority.

## Observed current state

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| Canonical `main` | `f9b5a312ac31ee4015025a87bcd3cec199b12297` | `git ls-remote`, fresh clone | 2026-08-09 |
| Latest governance closeout | PR #52 merged as `f9b5a312ac31ee4015025a87bcd3cec199b12297` | GitHub PR metadata and Git history | 2026-08-09 |
| Rejected candidate | PR #48 closed, unmerged, at `7ba158bddff76ade9aca79cb8501e675bd0cded9` | GitHub PR metadata | 2026-08-09 |
| Rejected candidate CI | Run `31294035484` passed but did not satisfy the accepted criteria | PR #48 disposition | 2026-08-09 |
| Current implementation authority | No P1-S02 authorization record exists; every P1-S02 ticket and slice is unauthorized | `docs/IMPLEMENTATION-AUTHORIZATION.md`, `docs/authorizations/` | `f9b5a312` |
| Runtime on `main` | No PR #48 runtime file is integrated | compare and runtime-path inspection | `f9b5a312` |

## Assumptions and unknowns

### Assumptions

- **P0-W38-A01:** The owner's instruction authorizes this governance-only plan correction and publication, but not acceptance of the corrected T01 plan or implementation of it.
- **P0-W38-A02:** The same T01 plan path remains the governing path so a later authorization can bind one unambiguous plan digest.
- **P0-W38-A03:** Rejected PR #48 remains negative Evidence and is not a source of accepted implementation.

### Unknowns

- **P0-W38-U01:** Whether the owner will accept, revise, or reject the corrected T01 plan remains undecided.
- **P0-W38-U02:** The future authorization base, authorization time, implementation branch, and replacement implementation head do not exist yet.
- **P0-W38-U03:** Exact implementation performance and crash-window behavior remain unverified until a fresh authorized implementation supplies runtime Evidence.

## Requirements

- **P0-W38-R01:** Correct the T01 plan as a complete domain and persistence contract, not as five isolated sentence edits.
- **P0-W38-R02:** Define one explicit Evidence result field and bounded vocabulary consistent with first-month Evidence authority.
- **P0-W38-R03:** Define the runtime owner and durable path for Artifact bytes, Artifact metadata, and Evidence records.
- **P0-W38-R04:** Define contradiction, stale, incomplete, and integrity semantics, persistence effects, atomic failure behavior, and deterministic acceptance tests.
- **P0-W38-R05:** Enforce freshness TTL shape in application validation and SQLite constraints, including direct SQL writes.
- **P0-W38-R06:** Resolve the Artifact public write API to exactly `Kiln.Artifact.Store.put/2` and define both arguments.
- **P0-W38-R07:** Reconcile identity, association, transaction ownership, idempotency, migrations, rollback, schemas, canonical bytes, and completion Evidence.
- **P0-W38-R08:** Preserve the distinction between proposed planning, owner acceptance, implementation authorization, implementation, verification, and acceptance.
- **P0-W38-R09:** Change no runtime source, test, migration, schema, dependency, or configuration path.

## Security boundary

Allowed:

- governance and planning Markdown;
- correction of the rejected T01 plan at its existing path;
- synchronization of current governance status and exact-next-action text;
- deterministic Repository validation and read-only inspection of rejected PR #48.

Denied:

- `lib/`, `test/`, `priv/`, `config/`, `mix.exs`, or `mix.lock` changes;
- creation of an authorization record;
- acceptance of the corrected T01 plan;
- reuse, restoration, rebase, or modification of PR #48;
- Artifact, Evidence, migration, provider, Repository-read, Patch, Command, Gate, completion, Receipt, Child, TUI, or Wave B runtime work;
- merge of this pull request.

Authority inputs are canonical `origin/main`, the accepted authority order in `AGENTS.md`, PR #48's rejection record, and PR #52's governance closeout. This package performs no product network, secret, process, or filesystem effect beyond normal local Git and publication of the governance diff.

## Proposed changes

1. Rewrite the existing T01 plan as a proposed replacement contract while retaining the exact PR #48 rejection history.
2. Define exact Artifact and Evidence records, persistence ownership, byte placement, API signatures, transaction boundaries, idempotency, and migration behavior.
3. Define protected outcomes and their durable effects so a false pass or dangling Evidence association cannot commit.
4. Synchronize current authority documents to say that the correction is proposed, owner acceptance is pending, and no implementation is authorized.
5. Record deterministic validation and an empty runtime-path diff in this plan's completion record.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `docs/work/P0-W38-correct-rejected-t01-plan.md` | governance package and completion Evidence | Proposed |
| `docs/work/P1-S02-T01-artifact-evidence-substrate.md` | coherent corrected T01 contract, proposed only | Proposed |
| `AGENTS.md` | exact next authority state | Proposed |
| `README.md` | current implementation and planning status | Proposed |
| `docs/PLANNING.md` | exact next owner decision | Proposed |
| `docs/ROADMAP.md` | exact next action | Proposed |
| `docs/IMPLEMENTATION-AUTHORIZATION.md` | proposed-plan/no-authorization result | Proposed |
| `docs/IMPLEMENTATION-SLICES.md` | corrected-plan status without authorization | Proposed |

## Acceptance criteria

- **P0-W38-AC01**
  - **Given** PR #48's five blocking findings and accepted Evidence authority;
  - **When** the corrected T01 plan is reviewed;
  - **Then** Evidence has one explicit result vocabulary and a real owned persistence path.
  - **Evidence:** T01 requirements, record shapes, APIs, and acceptance criteria.
- **P0-W38-AC02**
  - **Given** contradiction, stale, incomplete, and integrity cases;
  - **When** the corrected protected matrix is reviewed;
  - **Then** each case has exact semantics, persistence effects, failure behavior, and tests that prevent false or dangling durable Evidence.
  - **Evidence:** T01 protected-classification contract and AC08 through AC11.
- **P0-W38-AC03**
  - **Given** application and direct-SQL persistence paths;
  - **When** TTL and association constraints are reviewed;
  - **Then** invalid rule/TTL pairs, negative or zero TTLs, and missing Artifact references cannot commit.
  - **Evidence:** T01 migration contract and AC06, AC09, and AC11.
- **P0-W38-AC04**
  - **Given** the corrected public API;
  - **When** Artifact persistence is planned;
  - **Then** the only public write function is `Kiln.Artifact.Store.put/2`, with a ready Store and one typed request as its exact arguments.
  - **Evidence:** T01 API contract and AC04.
- **P0-W38-AC05**
  - **Given** the final branch diff;
  - **When** authority language and paths are inspected;
  - **Then** no P1-S02 implementation is accepted or authorized and no runtime path changed.
  - **Evidence:** authority scans and empty runtime-path diff.
- **P0-W38-AC06**
  - **Given** the exact branch head;
  - **When** the complete governance validation suite runs;
  - **Then** every applicable deterministic check passes.
  - **Evidence:** command results and exact-head CI.

## Deterministic verification

```bash
scripts/agent-preflight
scripts/test-agent-preflight
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
scripts/validate-agent-assets
vale --glob='!{deps,_build}/**' .
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
test ! -e docs/authorizations/P1-S02-T01.authorization
git diff --name-only f9b5a312ac31ee4015025a87bcd3cec199b12297 -- lib test priv mix.exs mix.lock config
git diff --check f9b5a312ac31ee4015025a87bcd3cec199b12297
```

Every command must exit `0`. The runtime-path diff command must print no path.

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P0-W38-E01 | P0-W38-AC01 | corrected result and persistence contract compare |
| P0-W38-E02 | P0-W38-AC02 | protected-classification matrix compare |
| P0-W38-E03 | P0-W38-AC03 | TTL, foreign-key, and direct-SQL constraint contract compare |
| P0-W38-E04 | P0-W38-AC04 | exact `put/2` signature and argument contract |
| P0-W38-E05 | P0-W38-AC05 | authority scan, absent authorization record, and empty runtime-path diff |
| P0-W38-E06 | P0-W38-AC06 | full local validation and exact-head CI |

## Explicit exclusions

- No runtime implementation, test, migration, runtime JSON Schema, dependency, or configuration change.
- No owner acceptance of T01 and no implementation authorization record.
- No restoration, rebase, cherry-pick, or reuse of rejected PR #48 code.
- No T02 or later planning authorization.
- No merge of this pull request.

## Completion record

**Result:** Corrected T01 governance contract proposed and verified. No T01 plan acceptance or P1-S02 implementation authorization was granted, PR #48 remains rejected, and no runtime path changed.

### Verified Repository state

- Base: `f9b5a312ac31ee4015025a87bcd3cec199b12297`.
- Branch: `work/p0-w38-correct-rejected-t01-plan`.
- Pull request: PR #53.
- Governance enforcement head: `53c6562fa4c4febd6f28fe8927352101e8a6832f`.
- Exact-head CI: run `31311303234`, success.
- Rejected PR #48 head: `7ba158bddff76ade9aca79cb8501e675bd0cded9`.
- Active T01 authorization record: absent.
- Corrected T01 lifecycle: Proposed, not Accepted.
- Runtime-path diff: empty.
- Final closeout commit: documentation-only and must receive fresh full CI before integration.

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| P0-W38-AC01 | Pass | P0-W38-E01 | result and owned durable persistence contracts are explicit |
| P0-W38-AC02 | Pass | P0-W38-E02 | four protected classifications have exact semantics, effects, failures, and tests |
| P0-W38-AC03 | Pass | P0-W38-E03 | TTL, result/completeness, and Artifact association have application and SQLite boundaries |
| P0-W38-AC04 | Pass | P0-W38-E04 | public Artifact write API is exactly `put/2(ready_store, PutRequest)` |
| P0-W38-AC05 | Pass | P0-W38-E05 | eight changed files are governance-only; authorization absent; runtime compare empty |
| P0-W38-AC06 | Pass | P0-W38-E06 | local available checks and exact-head CI run `31311303234` passed |

### Completion Evidence

- **P0-W38-E01:** the corrected T01 plan requires `result: pass | fail | blocked | unknown`, assigns `Kiln.Evidence.Store.record/2` durable ownership, and separates immutable Evidence from later criterion evaluation.
- **P0-W38-E02:** contradiction preserves both valid observations; stale rejects a new mismatched binding without erasing history; truthful incomplete non-pass may persist while incomplete pass cannot; integrity rolls back the Evidence transaction.
- **P0-W38-E03:** the plan requires a strictly bounded time TTL, `NULL` for non-time rules, foreign-key and Artifact integrity checks, direct-SQL negative fixtures, and per-migration rollback.
- **P0-W38-E04:** the plan defines only `Kiln.Artifact.Store.put/2(ready_store, %Kiln.Artifact.PutRequest{})`; a fresh replacement implementation branch is named and the rejected branch cannot be reused.
- **P0-W38-E05:** the compare from `f9b5a312…` contains `AGENTS.md`, README, six governance/planning documents, and no `lib/`, `test/`, `priv/`, `config/`, `mix.exs`, or `mix.lock` path. `docs/authorizations/P1-S02-T01.authorization` remains absent.
- **P0-W38-E06:** local W38 preflight, detached preflight regression, semantic validator, pinned JSON Schema validator, agent assets, Vale 3.14.2, Mix formatting, diff check, and authority scans passed. CI run `31311303234` additionally passed dependency installation, warnings-as-errors compilation, compile-connected cycle checks, all tests, the P1-S01 aggregate gate, and prose validation.

### Failures and warnings

- Local dependency-backed compile, xref, and test execution was unavailable because the environment denied the Hex network action. Exact-head CI supplied passing results for all three checks.
- `scripts/test-agent-preflight` has a historical final source-root assertion fixed to the W34 branch name. It passes in the CI-style detached checkout but cannot pass from a named W38 checkout. This governance-only package does not modify that development-tool path.

### Required next action

After this governance package merges, the owner must accept, revise, or reject the corrected proposed T01 plan. Only a later, separate governance action may mark it Accepted and issue a new exact authorization record for a fresh implementation package.
