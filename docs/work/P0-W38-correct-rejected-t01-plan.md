# P0-W38: Correct the rejected P1-S02-T01 plan

**Document type:** Implementation plan
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w38-correct-rejected-t01-plan`
**Depends on:** P0-W37 merged at `f9b5a312ac31ee4015025a87bcd3cec199b12297`; PR #48 rejected and closed without merge at `7ba158bddff76ade9aca79cb8501e675bd0cded9`

## Objective

Replace the rejected P1-S02-T01 contract with one coherent proposed plan that resolves its Evidence-result, persistence, protected-classification, freshness-boundary, Artifact-API, accepted-authority reconciliation, currentness, and bounds defects while preserving PR #48 as rejected history, changing no Kiln runtime path, and granting no implementation authority.

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
- **P0-W38-R02:** Define one explicit Evidence result field and preserve P0-W24's subject, Repository, host/environment, Command-result, plural Artifact, freshness, completeness, and contradiction contract through an exact canonical record-plus-view representation.
- **P0-W38-R03:** Define the runtime owner and durable path for Artifact bytes, Artifact metadata, and Evidence records.
- **P0-W38-R04:** Define contradiction, stale, incomplete, and integrity semantics, persistence effects, atomic failure behavior, and deterministic acceptance tests.
- **P0-W38-R05:** Reconcile the rejected candidate's invalid TTL behavior by preserving P0-W24's four state-based freshness rules, forbidding `time_bound` and TTL persistence, and testing application and direct SQL rejection.
- **P0-W38-R06:** Resolve the Artifact public write API to exactly `Kiln.Artifact.Store.put/2` and define both arguments.
- **P0-W38-R07:** Reconcile identity, plural association, transaction ownership, idempotency, migrations, rollback, schemas, canonical bytes, P0-W24, the active conformance projection, and completion Evidence.
- **P0-W38-R08:** Preserve the distinction between proposed planning, owner acceptance, implementation authorization, implementation, verification, and acceptance.
- **P0-W38-R09:** Change no runtime source, test, migration, schema, dependency, or configuration path.
- **P0-W38-R10:** Separate persistent Evidence request identity and unseen-key admission from pure currentness re-evaluation, with exact replay ordering and an integrity-checked read API.
- **P0-W38-R11:** Fix numeric Artifact and metadata bounds, direct-persistence enforcement, and deterministic no-truncation overflow behavior.

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
2. Define exact Artifact and Evidence records, accepted binding projection, persistence ownership, byte placement, API signatures, transaction boundaries, replay ordering, pure currentness, and migration behavior.
3. Define protected outcomes and their durable effects so a false pass or dangling Evidence association cannot commit.
4. Fix Artifact and metadata limits plus exact overflow behavior at application and applicable database boundaries.
5. Synchronize current authority documents to say that the correction is proposed, owner acceptance is pending, and no implementation is authorized.
6. Record deterministic validation and an empty runtime-path diff in this plan's completion record.

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
  - **Then** Evidence has one explicit result vocabulary, a real owned persistence path, every accepted P0-W24 binding, and an exact record-plus-currentness projection into the active first-month Schema.
  - **Evidence:** T01 requirements, record shapes, APIs, and acceptance criteria.
- **P0-W38-AC02**
  - **Given** contradiction, stale, incomplete, and integrity cases;
  - **When** the corrected protected matrix is reviewed;
  - **Then** each case has exact semantics, persistence effects, failure behavior, and tests that prevent false or dangling durable Evidence.
  - **Evidence:** T01 protected-classification contract and AC08 through AC11.
- **P0-W38-AC03**
  - **Given** application and direct-SQL persistence paths;
  - **When** freshness and association constraints are reviewed;
  - **Then** only the four accepted state-based rules can commit, no TTL has a durable representation, and missing Artifact references cannot commit.
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
- **P0-W38-AC07**
  - **Given** an exact Evidence retry after Repository, host, Command, Artifact, or invalidation state changes;
  - **When** the persistence and currentness contracts are reviewed;
  - **Then** persistent identity replays before unseen-key admission and `Currentness.evaluate/2` reports the changed applicability without a write or idempotency conflict.
  - **Evidence:** T01 APIs, idempotency ordering, and AC07 through AC09.
- **P0-W38-AC08**
  - **Given** Artifact bytes and all security-relevant metadata at their limit and one unit over;
  - **When** the application and direct-persistence boundaries are reviewed;
  - **Then** every limit is numeric, byte-based where applicable, and paired with exact rejection or explicit upstream truncation behavior.
  - **Evidence:** T01 bounds table, migration contract, and AC13.
- **P0-W38-AC09**
  - **Given** P0-W24 and the active first-month conformance Schema;
  - **When** the corrected T01 representation is compared field by field;
  - **Then** T01 explicitly preserves and maps the accepted contract and does not silently supersede it.
  - **Evidence:** T01 canonical Evidence-view mapping and AC05.

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
| P0-W38-E03 | P0-W38-AC03 | accepted freshness vocabulary, absent TTL, plural foreign-key, and direct-SQL constraint compare |
| P0-W38-E04 | P0-W38-AC04 | exact `put/2` signature and argument contract |
| P0-W38-E05 | P0-W38-AC05 | authority scan, absent authorization record, and empty runtime-path diff |
| P0-W38-E06 | P0-W38-AC06 | full local validation and exact-head CI |
| P0-W38-E07 | P0-W38-AC07 | persistent-identity, replay-order, read, and pure-currentness contract compare |
| P0-W38-E08 | P0-W38-AC08 | numeric bounds, byte semantics, direct-persistence, and overflow contract compare |
| P0-W38-E09 | P0-W38-AC09 | P0-W24 and active conformance field-by-field reconciliation |

## Explicit exclusions

- No runtime implementation, test, migration, runtime JSON Schema, dependency, or configuration change.
- No owner acceptance of T01 and no implementation authorization record.
- No restoration, rebase, cherry-pick, or reuse of rejected PR #48 code.
- No T02 or later planning authorization.
- No merge of this pull request.

## Completion record

**Result:** Corrected T01 governance contract proposed and amended after blocking review. No T01 plan acceptance or P1-S02 implementation authorization was granted, PR #48 remains rejected, and no runtime path changed. Fresh exact-head CI is required for the amendment before PR readiness.

### Verified Repository state

- Base: `f9b5a312ac31ee4015025a87bcd3cec199b12297`.
- Branch: `work/p0-w38-correct-rejected-t01-plan`.
- Pull request: PR #53.
- Governance enforcement head: `53c6562fa4c4febd6f28fe8927352101e8a6832f`.
- Initial governance CI: runs `31311303234` and `31311421953`, success at the pre-review heads.
- Rejected PR #48 head: `7ba158bddff76ade9aca79cb8501e675bd0cded9`.
- Active T01 authorization record: absent.
- Corrected T01 lifecycle: Proposed, not Accepted.
- Runtime-path diff: empty.
- Review-correction commit: governance-only and must receive fresh full CI before a final closeout Evidence commit.

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| P0-W38-AC01 | Pass | P0-W38-E01 | result, accepted bindings, conformance projection, and owned durable persistence are explicit |
| P0-W38-AC02 | Pass | P0-W38-E02 | four protected classifications have exact semantics, effects, failures, and tests |
| P0-W38-AC03 | Pass | P0-W38-E03 | four accepted freshness rules, absent TTL, result/completeness, and plural Artifact association have application and SQLite boundaries |
| P0-W38-AC04 | Pass | P0-W38-E04 | public Artifact write API is exactly `put/2(ready_store, PutRequest)` |
| P0-W38-AC05 | Pass | P0-W38-E05 | eight changed files are governance-only; authorization absent; runtime compare empty |
| P0-W38-AC06 | Pending | P0-W38-E06 | fresh exact-head CI is required after the review correction |
| P0-W38-AC07 | Pass | P0-W38-E07 | persistent identity, unseen-key admission, read, replay ordering, and pure currentness are separate |
| P0-W38-AC08 | Pass | P0-W38-E08 | Artifact and metadata limits are numeric with exact overflow behavior |
| P0-W38-AC09 | Pass | P0-W38-E09 | P0-W24 and active first-month conformance fields are explicitly preserved and mapped |

### Completion Evidence

- **P0-W38-E01:** the corrected T01 plan requires `result: pass | fail | blocked | unknown`, assigns `Kiln.Evidence.Store.record/2` durable ownership, preserves Repository, host/environment, Command-result, plural Artifact, freshness, completeness, and contradiction bindings, and maps immutable storage plus pure currentness into the accepted Evidence item.
- **P0-W38-E02:** contradiction preserves all valid observations and is derived across current peers; stale admission rejects an unseen mismatched record while pure currentness reports an old record stale without mutation; truthful incomplete `blocked` or `unknown` may persist while incomplete `pass` or `fail` cannot; integrity rolls back the Evidence transaction.
- **P0-W38-E03:** the plan permits exactly P0-W24's four state-based freshness rules, has no TTL field or column, requires plural foreign-key and Artifact integrity checks, and defines direct-SQL negative fixtures and per-migration rollback.
- **P0-W38-E04:** the plan defines only `Kiln.Artifact.Store.put/2(ready_store, %Kiln.Artifact.PutRequest{})` for writing, adds read-only `fetch/2`, names a fresh replacement implementation branch, and forbids reuse of the rejected branch.
- **P0-W38-E05:** the compare from `f9b5a312…` contains `AGENTS.md`, README, six governance/planning documents, and no `lib/`, `test/`, `priv/`, `config/`, `mix.exs`, or `mix.lock` path. `docs/authorizations/P1-S02-T01.authorization` remains absent.
- **P0-W38-E06:** initial local and exact-head validation passed at the pre-review heads. The review correction must rerun the same local suite and receive fresh full CI before this Evidence returns to Pass.
- **P0-W38-E07:** Evidence persistent request identity excludes admission and later currentness contexts; exact replay is integrity-checked before unseen-key admission, and `fetch/2` plus pure `Currentness.evaluate/2` re-evaluate historical records without writes.
- **P0-W38-E08:** the T01 bounds table fixes a 16,777,216-byte Artifact maximum, 65,536-byte canonical requests, and explicit identifier, media-type, warning, rationale, association, and currentness limits. Overflow is rejected without silent T01 truncation.
- **P0-W38-E09:** the corrected plan states that it does not supersede P0-W24 or the active first-month Schema and defines exact canonical mappings for subject, Repository, host/environment, Command result, plural Artifacts, freshness, completeness, contradiction, invalidation, status, and record digest.

### Failures and warnings

- Local dependency-backed compile, xref, and test execution was unavailable because the environment denied the Hex network action. Exact-head CI supplied passing results for all three checks.
- `scripts/test-agent-preflight` has a historical final source-root assertion fixed to the W34 branch name. It passes in the CI-style detached checkout but cannot pass from a named W38 checkout. This governance-only package does not modify that development-tool path.

### Required next action

After this governance package merges, the owner must accept, revise, or reject the corrected proposed T01 plan. Only a later, separate governance action may mark it Accepted and issue a new exact authorization record for a fresh implementation package.
