# P0-W43: Authorize migration-runner compound-statement support for P1-S02-T01

**Document type:** Implementation plan (governance)
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w43-authorize-migration-compound-statements`
**Depends on:** P0-W42 integrated at `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf` via PR #58; PR #59 integrated at `1243b8f27a594c9440638964a83b56c74774ba28`; explicit owner adjudication of the discovered migration-runner incompatibility

## Objective

Adjudicate a discovered incompatibility between the accepted P1-S02-T01 plan and the current migration runner, in favor of preserving the accepted Evidence contract. Amend the accepted T01 plan to authorize exactly one additional implementation path, `lib/kiln/store/migrations.ex`, for compound-statement support in `statements/1` only, and reissue `docs/authorizations/P1-S02-T01.authorization` against the amended plan digest and the current canonical base.

This package contains no runtime implementation. It changes no Elixir source, no migration, no schema, and no test.

## Observed current state

| Observation | Evidence | Result |
| --- | --- | --- |
| Canonical `main` after PR #59 | `1243b8f27a594c9440638964a83b56c74774ba28` | observed |
| Accepted T01 plan requires an aborting aggregate `evidence_warnings` limit | `docs/work/P1-S02-T01-artifact-evidence-substrate.md` migration contract | accepted authority |
| An aggregate-across-rows limit is not expressible as a row-local `CHECK` | SQLite semantics | observed |
| The migration runner splits SQL on `;` after stripping `--` comments | `lib/kiln/store/migrations.ex` `statements/1` | observed |
| Applying that split to a trigger body yields two fragments | reproduction against the runner's exact logic | observed |
| The first fragment fails in SQLite | `Error: in prepare, incomplete input` | observed |
| The accepted T01 file table excludes `lib/kiln/store/migrations.ex` | accepted plan `Expected files or components` | accepted authority |
| Prior T01 authorization binds the pre-amendment plan digest | `docs/authorizations/P1-S02-T01.authorization` | observed |
| T01 implementation branch | `work/p1-s02-t01-artifact-evidence-substrate-v2` at canonical `main`, zero unique commits | observed |
| Trusted owner registry | `docs/authorizations/TRUSTED-OWNERS` | `Joshua Jenks` |
| Runtime on canonical `main` | no P1-S02 implementation path present | unchanged |

## Owner decision

The owner adjudicated the discovered incompatibility at `2026-08-10T23:06:00-04:00`, against canonical `main` `1243b8f27a594c9440638964a83b56c74774ba28`, in favor of preserving the accepted Evidence contract and narrowly expanding the authorized implementation surface.

The decision preserves the requirement that migration `0004` enforce the 16,384-byte aggregate `evidence_warnings` limit as an aborting database constraint. It explicitly rejects application-only enforcement and rejects a denormalized aggregate column or equivalent schema workaround.

It authorizes exactly one additional implementation path, `lib/kiln/store/migrations.ex`, for compound-statement support in `statements/1` only.

It does **not**:

- authorize P1-S02-T02 or later tickets;
- permit any capability excluded by the accepted T01 plan;
- permit reuse, cherry-pick, restoration, or continuation of PR #48;
- permit implementation to begin before this package integrates on canonical `main`;
- permit any other change to the accepted T01 technical contract.

## Assumptions and unknowns

### Assumptions

- **P0-W43-A01:** Amending the accepted plan invalidates the previous `plan_sha256` binding, so the authorization record must be reissued in the same governance change or T01 becomes unrunnable under `scripts/agent-preflight`.
- **P0-W43-A02:** A single squash-merged commit carrying both the amended plan and the reissued record satisfies `find_authority_source/5`, which requires one trusted commit containing the exact blob pair.
- **P0-W43-A03:** Migration checksums hash the file bytes, not the split result, so a splitter change cannot alter the recorded checksum of an already-applied migration. The implementation ticket must still prove the executed statement sequence is unchanged.

### Unknowns

- **P0-W43-U01:** The exact compound-statement recognition strategy is an implementation choice reserved to P1-S02-T01 under P1-S02-T01-R16.
- **P0-W43-U02:** Whether any later migration requires additional compound forms beyond `CREATE TRIGGER ... BEGIN ... END;` is not decided here.

## Requirements

- **P0-W43-R01:** The accepted T01 plan shall authorize `lib/kiln/store/migrations.ex` for compound-statement support in `statements/1` only.
- **P0-W43-R02:** The amended plan shall bind that expansion to unchanged behavior, checksums, and executed statement sequence for migrations 0001 through 0003, and unchanged discovery, bookkeeping, transaction, rollback, and error semantics.
- **P0-W43-R03:** The amended plan shall require regression coverage for compound-statement splitting, trigger creation and firing, the 16,384 and 16,385 aggregate boundary pair, and a failed compound migration recording no checksum.
- **P0-W43-R04:** `docs/authorizations/P1-S02-T01.authorization` shall be reissued against the exact amended plan digest, base `1243b8f27a594c9440638964a83b56c74774ba28`, owner `Joshua Jenks`, and `authorized_at=2026-08-10T23:06:00-04:00`, in canonical key order.
- **P0-W43-R05:** The reissued scope line shall preserve the PR #48 prohibition and the P1-S02-T02-and-later exclusion.
- **P0-W43-R06:** Only governance documents that bind or reproduce the superseded digest, base, or authorization state shall change. A document that merely mentions T01 shall not be modified, and no historical `docs/work/` record shall be modified. The set of corrected documents shall equal the set named in this plan's file table.
- **P0-W43-R07:** This package shall change no Elixir source, migration, schema, or test, and shall not itself modify `lib/kiln/store/migrations.ex`.
- **P0-W43-R08:** Statements in this package shall distinguish the canonical decision base, the authority-source commit, the implementation commit, GitHub's merge-test commit, and the canonical integration commit produced by merging. No statement shall assert that the reissued authorization exists at the decision base, and no statement shall predict the canonical integration commit.

## Security boundary

Allowed:

- amend the accepted T01 plan's requirements, criteria, Evidence table, file table, proposed changes, security boundary, and completion record;
- reissue the T01 authorization record;
- update governance documents whose current text binds or reproduces the superseded digest, base, or authorization state.

Denied:

- any runtime, migration, schema, or test change;
- modification of `lib/kiln/store/migrations.ex` in this package;
- widening T01 beyond the single adjudicated path;
- weakening the accepted Evidence contract or its aggregate bound;
- authorizing P1-S02-T02 or later work;
- rehabilitating PR #48.

## Proposed changes

1. Amend `docs/work/P1-S02-T01-artifact-evidence-substrate.md` to add P1-S02-T01-R16, P1-S02-T01-AC15, Evidence row E15, the `lib/kiln/store/migrations.ex` file-table row, proposed-change item 9, and the security-boundary allowance.
2. Correct that plan's now-false authorization-state claims in its Status line, acceptance-status table, and required-next-action section.
3. Reissue `docs/authorizations/P1-S02-T01.authorization` against the amended digest and current canonical base.
4. Update `docs/IMPLEMENTATION-AUTHORIZATION.md`, `AGENTS.md`, `README.md`, `docs/PLANNING.md`, `docs/IMPLEMENTATION-SLICES.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, and `docs/RUN-MODEL.md` only where they bind or reproduce the superseded digest, base, or authorization state.
5. Correct two statements in `AGENTS.md` that were already false at canonical `main` and directly contradict the authorization this package reissues: "No P1-S02 ticket or aggregate slice is currently authorized", and the claim that no authorization record exists at canonical `main`. Both were left stale by P0-W42. They are corrected here because P0-W43 cannot achieve its objective while the operative authority document denies the authorization it reissues.
6. Correct the blanket "all P1-S02 work unauthorized" claims in `docs/ARCHITECTURE.md` and `docs/RUN-MODEL.md`, which reproduce current authorization state and are false because P1-S02-T01 is boundedly authorized.
7. Add a commit-role vocabulary to `docs/IMPLEMENTATION-AUTHORIZATION.md` distinguishing decision base, authority source, implementation commit, merge-test commit, and canonical integration commit, and correct every statement in this package that described the decision base as already containing the reissued record.

## Expected files or components

| Path | Expected change | Status |
| --- | --- | --- |
| `docs/work/P0-W43-authorize-migration-compound-statements.md` | this governance plan | Proposed |
| `docs/work/P1-S02-T01-artifact-evidence-substrate.md` | R16, AC15, E15, file row, proposed change 9, security allowance, corrected authorization state | Proposed |
| `docs/authorizations/P1-S02-T01.authorization` | reissued against amended digest and current base | Proposed |
| `docs/IMPLEMENTATION-AUTHORIZATION.md` | current result and authority-result list rebound | Proposed |
| `AGENTS.md` | authorization boundary rebound; two pre-existing false statements corrected | Proposed |
| `README.md` | active-record digest and next-action rebound | Proposed |
| `docs/PLANNING.md` | build-authorization line and next-action rebound | Proposed |
| `docs/IMPLEMENTATION-SLICES.md` | integration status and P1-S02 entry gate rebound | Proposed |
| `docs/ARCHITECTURE.md` | implementation-status line reproduced a now-false blanket P1-S02 unauthorized state | Proposed |
| `docs/RUN-MODEL.md` | P1-S01 execution note reproduced a now-false blanket P1-S02 unauthorized state | Proposed |
| `docs/ROADMAP.md` | authorization narrative rebound | Proposed |

No other path is authorized by this package.

## Acceptance criteria

- **P0-W43-AC01 — Amended plan authorizes exactly one additional path**
  - **Given** the amended T01 plan;
  - **When** its file table and security boundary are read;
  - **Then** `lib/kiln/store/migrations.ex` is authorized for compound-statement support in `statements/1` only, and no other new path appears.
  - **Evidence:** final diff of the plan file.
- **P0-W43-AC02 — Expansion is bound by preservation requirements**
  - **Given** P1-S02-T01-R16 and P1-S02-T01-AC15;
  - **When** they are read;
  - **Then** they require unchanged 0001-0003 checksums and statement sequence, unchanged runner semantics, splitter regression coverage, trigger creation and firing, the 16,384 and 16,385 boundary pair, and no checksum on a failed compound migration.
  - **Evidence:** plan text.
- **P0-W43-AC03 — Authorization record binds the amended plan**
  - **Given** the reissued record;
  - **When** `scripts/agent-preflight` validates the T01 branch after integration;
  - **Then** `plan_sha256` equals the SHA-256 of the amended plan, `base_sha` is ancestral, key order is canonical, and the owner is registered.
  - **Evidence:** digest comparison and preflight result.
- **P0-W43-AC04 — No runtime change**
  - **Given** the final diff;
  - **When** it is inspected for scope leakage;
  - **Then** no file under `lib/`, `test/`, `priv/`, or `config/` changed, and `lib/kiln/store/migrations.ex` is untouched.
  - **Evidence:** `git diff --name-only` against the base.
- **P0-W43-AC05 — Governance references are consistent, complete, and minimal**
  - **Given** the governance documents;
  - **When** each is checked against its existing contract;
  - **Then** every document that binds or reproduces the superseded digest, base, or authorization state is corrected, including `docs/ARCHITECTURE.md` and `docs/RUN-MODEL.md`; no document that merely mentions T01 is modified; no historical `docs/work/` record is modified; and the set of corrected documents equals the set named in this plan's file table.
  - **Evidence:** exhaustive search for superseded digests, bases, and blanket unauthorized claims; per-file justification; final diff.
- **P0-W43-AC06 — Commit roles are not conflated**
  - **Given** every statement added or changed by this package;
  - **When** each reference to a commit is read;
  - **Then** the decision base, authority source, implementation commit, merge-test commit, and canonical integration commit are distinguished; no statement claims the reissued record exists at the decision base; and no statement predicts the canonical integration commit.
  - **Evidence:** commit-role vocabulary section, added-line audit of the final diff, and absence of any invented post-merge SHA.

## Deterministic verification

```bash
scripts/agent-preflight
scripts/test-agent-preflight
scripts/validate-agent-assets
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
vale --glob='!{deps,_build}/**' .
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

Every command must exit `0`, except where a pre-existing environment-only failure is recorded with Evidence and shown to be unchanged by this package.

## Exact next action after P0-W43 merges

Record the resulting canonical `main` SHA. Move `work/p1-s02-t01-artifact-evidence-substrate-v2` to that exact commit, confirm zero unique commits and no PR #48 ancestry, verify the amended plan and reissued record are byte-identical to canonical `main`, run `scripts/agent-preflight` and `scripts/test-agent-preflight`, then begin P1-S02-T01 implementation within the amended authorized surface.

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P0-W43-E01 | AC01 | amended plan diff showing exactly one added path |
| P0-W43-E02 | AC02 | R16 and AC15 text |
| P0-W43-E03 | AC03 | amended plan digest, record contents, and preflight result |
| P0-W43-E04 | AC04 | name-only diff proving no runtime change |
| P0-W43-E05 | AC05 | per-file governance justification, exhaustive stale-reference search, and final diff |
| P0-W43-E06 | AC06 | commit-role vocabulary, added-line audit, and proof that no post-merge SHA is invented |

## Explicit exclusions

- No runtime, migration, schema, or test change.
- No modification of `lib/kiln/store/migrations.ex` in this package.
- No P1-S02-T01 implementation.
- No P1-S02-T02 or later authorization.
- No PR #48 reuse, cherry-pick, restoration, or rehabilitation.
- No change to the accepted Evidence contract, its vocabularies, or its bounds.
- No modification of any historical `docs/work/` provenance record.
- No prediction or invention of the canonical integration commit produced by merging this package.

## Completion record

**Result:** Prepared for owner review. Not merged, not implemented, not verified.

| Stage | Status | Result |
| --- | --- | --- |
| Owner adjudication | Granted | recorded at `2026-08-10T23:06:00-04:00` against canonical `main` `1243b8f27a594c9440638964a83b56c74774ba28` |
| Governance change | Prepared | pending owner review and merge |
| T01 implementation | Not started | permitted only after this package integrates |
