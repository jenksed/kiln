# P0-W44: Reconcile P1-S02-T01 file surface with Artifact filesystem implementation decomposition

**Document type:** Implementation plan (governance)
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w44-reconcile-t01-file-surface`
**Depends on:** P0-W43 integrated at `2f88281527811b8c4be0243fb201ae4416730a13` via PR #60; explicit owner adjudication of the discovered implementation/file-table mismatch.

## Objective

Adjudicate a discovered mismatch between the accepted P1-S02-T01 plan's authoritative `Expected files or components` table and the actual implementation decomposition. The implementation branch `work/p1-s02-t01-artifact-evidence-substrate-v2` at `05423aa2a8fdbe65952a41c80159d0f61204beeb` adds one runtime path — `lib/kiln/artifact/fs.ex` — that is not named in the accepted table while the table closes with the exhaustive claim "No other path is authorized."

The owner has already adjudicated the substantive question. The owner decision is recorded verbatim in the "Owner decision" section below. This package contains no runtime implementation; it reconciles authority only.

## Observed current state

| Observation | Evidence | Result |
| --- | --- | --- |
| Canonical `main` after PR #60 | `2f88281527811b8c4be0243fb201ae4416730a13` | observed |
| Active T01 authorization base | `1243b8f27a594c9440638964a83b56c74774ba28` (P0-W43 decision base) | observed |
| Active T01 plan digest | `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e` | observed at canonical `main` |
| T01 implementation branch head | `05423aa2a8fdbe65952a41c80159d0f61204beeb` | observed |
| Accepted T01 plan file-table exhaustive claim | `docs/work/P1-S02-T01-artifact-evidence-substrate.md` line 413: "No other path is authorized." | accepted authority |
| Implementation adds unlisted runtime path | `lib/kiln/artifact/fs.ex` exists on the implementation branch but is absent from the file table | observed mismatch |
| `lib/kiln/artifact/fs.ex` module purpose | Artifact filesystem placement, staging, atomic-publication helpers, intermediate-component containment, final-leaf classification, content hashing/rehash verification, cleanup helpers, deterministic test seams | implementation inspection |
| `scripts/agent-preflight` current enforcement | accepts the branch despite the unlisted path because it does not compare the implementation diff against the authorized file table | observed |
| Trusted owner registry | `docs/authorizations/TRUSTED-OWNERS` | `Joshua Jenks` |
| Runtime on canonical `main` | no P1-S02 implementation path present | unchanged |

## Owner decision

The owner adjudicated the implementation/file-table mismatch at `2026-08-11T12:00:00-04:00`, against canonical `main` `2f88281527811b8c4be0243fb201ae4416730a13`, in favor of reconciling the accepted plan with the already-existing implementation decomposition rather than rolling back the implementation or rewriting the module back into `lib/kiln/artifact.ex`.

The decision states verbatim:

> `lib/kiln/artifact/fs.ex` is approved as the dedicated filesystem implementation module for the already-authorized P1-S02-T01 Artifact publication and integrity responsibilities. This does not widen T01 behavior or capability scope. It only reconciles the accepted file surface with the implementation decomposition already required to satisfy Artifact atomicity, containment, integrity, and replay requirements.

The decision narrowly authorizes one additional implementation path, `lib/kiln/artifact/fs.ex`, with the bounded responsibilities named in the requirements section below.

It does **not**:

- widen T01 behavior, contract, or capability surface;
- permit reuse, cherry-pick, restoration, or continuation of PR #48;
- permit implementation to begin before this package integrates on canonical `main`;
- authorize P1-S02-T02 or later tickets;
- modify the existing Layer 2 implementation at `05423aa`;
- authorize any path beyond `lib/kiln/artifact/fs.ex`.

## Assumptions and unknowns

### Assumptions

- **P0-W44-A01:** Amending the accepted plan's file table invalidates the previous `plan_sha256` binding, so the authorization record must be reissued in the same governance change or T01 becomes unrunnable under `scripts/agent-preflight`.
- **P0-W44-A02:** The bounded responsibility text recorded in this plan is the authoritative description of what `lib/kiln/artifact/fs.ex` is allowed to do. Anything outside that scope remains unauthorized and must be adjudicated separately.
- **P0-W44-A03:** The implementation branch's `05423aa` checkpoint already satisfies the bounded responsibilities enumerated in this plan, so the implementation branch does not require further edits before re-base onto the new canonical authority.
- **P0-W44-A04:** A separate governance ticket is required to repair `scripts/agent-preflight` so it mechanically enforces the accepted file table. That ticket is not contained in P0-W44.

### Unknowns

- **P0-W44-U01:** The exact mechanical enforcement shape for `scripts/agent-preflight` is an implementation choice reserved to the future P0 enforcement-defect ticket.
- **P0-W44-U02:** Whether any future Artifact work will require additional filesystem primitives beyond `lib/kiln/artifact/fs.ex` is not decided here.

## Requirements

- **P0-W44-R01:** The accepted T01 plan's `Expected files or components` table shall explicitly name `lib/kiln/artifact/fs.ex` with the bounded responsibilities named in this plan.
- **P0-W44-R02:** The amended plan shall describe `lib/kiln/artifact/fs.ex` as subordinate to the already-authorized Artifact publication contract. The module shall not gain independent domain authority and shall not acquire any of the denied capabilities listed below.
- **P0-W44-R03:** The amended plan shall add an acceptance criterion (P1-S02-T01-AC16) proving that the bounded responsibilities and denied capabilities remain accurate after integration.
- **P0-W44-R04:** The amended plan's "No other path is authorized" closing sentence shall remain in force for paths other than the ones added or already named by this plan.
- **P0-W44-R05:** `docs/authorizations/P1-S02-T01.authorization` shall be reissued against the exact amended plan digest, base `2f88281527811b8c4be0243fb201ae4416730a13`, owner `Joshua Jenks`, and `authorized_at=2026-08-11T12:00:00-04:00`, in canonical key order.
- **P0-W44-R06:** The reissued scope line shall preserve the PR #48 prohibition, the P1-S02-T02-and-later exclusion, and the "no denied capability surface" clause from P0-W42 / P0-W43.
- **P0-W44-R07:** This package shall change no Elixir source, migration, schema, or test, and shall not itself modify `lib/kiln/artifact/fs.ex`, `lib/kiln/artifact.ex`, `lib/kiln/artifact/store.ex`, `lib/kiln/artifact/put_request.ex`, or any test or migration under `test/` or `priv/`.
- **P0-W44-R08:** This package shall not modify `scripts/agent-preflight`. The preflight enforcement defect must be addressed by a separate P0 governance ticket.
- **P0-W44-R09:** Statements in this package shall distinguish the decision base, the authority-source commit, the implementation commit, the merge-test commit, and the canonical integration commit. No statement shall claim the new authorization exists at the decision base, and no statement shall predict the canonical integration commit.

## Security boundary

### `lib/kiln/artifact/fs.ex` allowed responsibilities

- Artifact filesystem placement under a caller-supplied Artifact root.
- Staging and atomic-publication helpers used by `Kiln.Artifact.Store.put/2`.
- Path containment and integrity checks for intermediate components and the final leaf.
- Content hashing and rehash verification, including classification of the final leaf via `File.lstat/1`.
- Cleanup helpers for leftover staging files.
- Filesystem-specific deterministic test seams (`:kiln, {:fs_fault, key}` injection points) used by T01 publication tests.

### `lib/kiln/artifact/fs.ex` denied capabilities

- Repository source access of any kind.
- Arbitrary caller-selected roots beyond the Artifact root supplied by `Kiln.Artifact.Store`.
- Deletion or garbage collection of any Artifact or non-Artifact path.
- Remote storage, network calls, or any non-filesystem I/O.
- Background processes, processes, supervision, or scheduling.
- Retries, recovery loops, or speculative re-execution.
- Provider, model, Context, Tool, Patch, Command, Gate, Receipt, or any later P1-S02 capability.
- Any independent domain authority distinct from `Kiln.Artifact.Store`.

Allowed (governance only):

- amend the accepted T01 plan's file table and add the corresponding acceptance criterion;
- reissue the T01 authorization record;
- update governance documents whose current text binds or reproduces the superseded digest, base, or authorization state;
- add a new `docs/work/P0-W44-reconcile-t01-file-surface.md` governance plan.

Denied:

- any runtime, migration, schema, or test change;
- modification of `lib/kiln/artifact/fs.ex` in this package;
- modification of `lib/kiln/artifact.ex`, `lib/kiln/artifact/store.ex`, `lib/kiln/artifact/put_request.ex`, migrations, or tests in this package;
- modification of `scripts/agent-preflight` or any other enforcement script in this package;
- widening T01 beyond the single adjudicated path;
- authorizing P1-S02-T02 or later work;
- rehabilitating PR #48;
- starting, re-implementing, or moving the T01 implementation branch.

## Proposed changes

1. Amend `docs/work/P1-S02-T01-artifact-evidence-substrate.md` to add a `lib/kiln/artifact/fs.ex` file-table row, a P1-S02-T01-AC16 acceptance criterion, an E16 Evidence row, and an updated security-boundary allowance that lists the bounded responsibilities and denied capabilities for `lib/kiln/artifact/fs.ex`.
2. Correct that plan's now-stale authorization-state claims in its acceptance-status table and required-next-action section to reflect the new digest and base.
3. Reissue `docs/authorizations/P1-S02-T01.authorization` against the amended digest and the current canonical base `2f88281527811b8c4be0243fb201ae4416730a13`.
4. Update `AGENTS.md`, `README.md`, `docs/IMPLEMENTATION-AUTHORIZATION.md`, `docs/IMPLEMENTATION-SLICES.md`, `docs/PLANNING.md`, and `docs/ROADMAP.md` only where they bind or reproduce the superseded digest, base, or authorization state.

## Expected files or components

| Path | Expected change | Status |
| --- | --- | --- |
| `docs/work/P0-W44-reconcile-t01-file-surface.md` | this governance plan | Proposed |
| `docs/work/P1-S02-T01-artifact-evidence-substrate.md` | file-table row, AC16, E16, security-boundary allowance, corrected authorization state | Proposed |
| `docs/authorizations/P1-S02-T01.authorization` | reissued against amended digest and current base `2f88281` | Proposed |
| `AGENTS.md` | authorization boundary rebound; reference to P0-W44 added | Proposed |
| `README.md` | active-record digest rebound; reference to P0-W44 added | Proposed |
| `docs/IMPLEMENTATION-AUTHORIZATION.md` | current result and authority-result list rebound | Proposed |
| `docs/IMPLEMENTATION-SLICES.md` | P1-S02 entry-gate text rebound | Proposed |
| `docs/PLANNING.md` | build-authorization line and next-action rebound | Proposed |
| `docs/ROADMAP.md` | authorization narrative rebound | Proposed |

No other path is authorized by this package.

## Acceptance criteria

- **P0-W44-AC01 — Amended plan authorizes exactly one additional path**
  - **Given** the amended T01 plan;
  - **When** its file table and security boundary are read;
  - **Then** `lib/kiln/artifact/fs.ex` is authorized for the bounded responsibilities named in this plan, and no other new path appears.
  - **Evidence:** final diff of the plan file.
- **P0-W44-AC02 — Bounded responsibilities and denied capabilities are recorded**
  - **Given** the amended T01 plan;
  - **When** the security boundary section is read;
  - **Then** the allowed responsibilities and denied capabilities listed above appear verbatim, the module is described as subordinate to `Kiln.Artifact.Store`, and AC16 references them.
  - **Evidence:** plan text.
- **P0-W44-AC03 — Authorization record binds the amended plan**
  - **Given** the reissued record;
  - **When** `scripts/agent-preflight` validates the T01 branch after integration;
  - **Then** `plan_sha256` equals the SHA-256 of the amended plan, `base_sha` is `2f88281527811b8c4be0243fb201ae4416730a13`, key order is canonical, the owner is registered, and `authorized_at` equals `2026-08-11T12:00:00-04:00`.
  - **Evidence:** digest comparison and preflight result.
- **P0-W44-AC04 — No runtime, test, migration, schema, or enforcement-script change**
  - **Given** the final diff;
  - **When** it is inspected for scope leakage;
  - **Then** no file under `lib/`, `test/`, `priv/`, `config/`, or `scripts/` (except governance and validator scripts that already bind the superseded digest) changed; `lib/kiln/artifact/fs.ex` is untouched; and `scripts/agent-preflight` is untouched.
  - **Evidence:** `git diff --name-only` against the base.
- **P0-W44-AC05 — Governance references are consistent, complete, and minimal**
  - **Given** the governance documents;
  - **When** each is checked against its existing contract;
  - **Then** every document that binds or reproduces the superseded digest, base, or authorization state is corrected; no document that merely mentions T01 is modified; no historical `docs/work/` record is modified; and the set of corrected documents equals the set named in this plan's file table.
  - **Evidence:** exhaustive search for superseded digests and bases; per-file justification; final diff.
- **P0-W44-AC06 — Commit roles are not conflated**
  - **Given** every statement added or changed by this package;
  - **When** each reference to a commit is read;
  - **Then** the decision base, the authority-source commit, the implementation commit, the merge-test commit, and the canonical integration commit are distinguished; no statement claims the reissued record exists at the decision base; and no statement predicts the canonical integration commit.
  - **Evidence:** commit-role vocabulary, added-line audit of the final diff, and absence of any invented post-merge SHA.
- **P0-W44-AC07 — Enforcement defect is reported, not silently patched**
  - **Given** the discovered gap in `scripts/agent-preflight`;
  - **When** the completion record is read;
  - **Then** a Project Arsenal / Kiln governance defect report exists describing the failure, the recommended deterministic enforcement shape, and the fact that the fix belongs in a separate P0 enforcement-defect ticket rather than in P0-W44.
  - **Evidence:** completion-record "Project Arsenal feedback" section.

## Deterministic verification

```bash
shasum -a 256 docs/work/P1-S02-T01-artifact-evidence-substrate.md
git diff --exit-code 2f88281527811b8c4be0243fb201ae4416730a13 -- docs/work/P1-S02-T01-artifact-evidence-substrate.md
scripts/agent-preflight
scripts/test-agent-preflight
scripts/validate-agent-assets
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
vale --glob='!{deps,_build,.claude/dependencies}/**' .
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
git diff --name-only 2f88281527811b8c4be0243fb201ae4416730a13 -- lib test priv config mix.exs mix.lock scripts/agent-preflight
git diff --check
```

Every command must exit `0`, except where a pre-existing environment-only failure is recorded with Evidence and shown to be unchanged by this package.

## Exact next action after P0-W44 merges

1. Record the resulting canonical `main` SHA.
2. Move `work/p1-s02-t01-artifact-evidence-substrate-v2` to that exact commit, preserving the existing `05423aa` implementation ancestry.
3. Confirm zero unique commits on the implementation branch beyond `05423aa`, no PR #48 ancestry, and that the amended T01 plan and reissued authorization record are byte-identical to trusted canonical `main`.
4. Run `scripts/agent-preflight` and `scripts/test-agent-preflight` from the moved implementation branch.
5. Re-run Layer 2 targeted and full gates.
6. Only then begin Layer 3 / Evidence implementation within the amended authorized surface.
7. Schedule a separate P0 governance ticket to repair `scripts/agent-preflight` so the exhaustive file table is enforced mechanically.

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P0-W44-E01 | AC01 | amended plan diff showing exactly one added path |
| P0-W44-E02 | AC02 | AC16 text and security-boundary text |
| P0-W44-E03 | AC03 | amended plan digest, record contents, and preflight result |
| P0-W44-E04 | AC04 | name-only diff proving no runtime/test/migration/schema/enforcement-script change |
| P0-W44-E05 | AC05 | per-file governance justification, exhaustive stale-reference search, and final diff |
| P0-W44-E06 | AC06 | commit-role vocabulary, added-line audit, and proof that no post-merge SHA is invented |
| P0-W44-E07 | AC07 | Project Arsenal / Kiln governance defect report in completion record |

## Explicit exclusions

- No runtime, migration, schema, test, or enforcement-script change.
- No modification of `lib/kiln/artifact/fs.ex` in this package.
- No modification of any other implementation path under `lib/`, `test/`, `priv/`, or `config/`.
- No modification of `scripts/agent-preflight` in this package.
- No P1-S02-T01 implementation.
- No P1-S02-T02 or later authorization.
- No PR #48 reuse, cherry-pick, restoration, or rehabilitation.
- No modification of any historical `docs/work/` provenance record.
- No prediction or invention of the canonical integration commit produced by merging this package.

## Completion record

**Result:** Prepared for owner review. Not merged, not implemented, not verified.

| Stage | Status | Result |
| --- | --- | --- |
| Owner adjudication | Granted | recorded at `2026-08-11T12:00:00-04:00` against canonical `main` `2f88281527811b8c4be0243fb201ae4416730a13` |
| Governance change | Prepared | pending owner review and merge |
| T01 implementation | Not started | permitted only after this package integrates |
| Project Arsenal defect | Reported | preflight enforcement gap recorded in this section; fix tracked as a separate P0 ticket |

### Project Arsenal feedback — authorized file surface gap

**Observed failure mode:** an implementation branch at `05423aa` adds `lib/kiln/artifact/fs.ex` while the accepted plan's `Expected files or components` table explicitly closes with "No other path is authorized." `scripts/agent-preflight` accepted the implementation branch without detecting the unlisted path. The mismatch was visible only to a human reading the file table and the diff in parallel.

**Why humans and agents missed it:** the accepted plan's file table sits in Markdown and is not consumed by any automated check. Reviewers reading the implementation diff do not always load the file table side by side. The implementation's decomposition (moving Artifact filesystem primitives into a dedicated module) is sensible and so the change was approved on technical grounds without ever comparing the new path list against the authorized surface.

**Why current preflight missed it:** `scripts/agent-preflight` validates the authorization record, the plan digest, the trusted owner, and the branch/work-package alignment. It does not enumerate the plan's authorized file surface, snapshot the implementation diff, or compare the two. The exhaustive-claim language in the plan is therefore advisory rather than enforced.

**Recommended structured representation for authorized paths:** move the file table out of Markdown prose into a machine-readable sidecar at `docs/work/<plan>.paths.json` (or equivalent), with explicit entries per authorized path, per authorized subtree, and per denied pattern. The exact-file vs subtree distinction must be explicit so that `test/kiln/artifact/` style subtree authorizations do not accidentally lock in module counts.

**Recommended diff-vs-authority check:** a deterministic script that:

1. Loads the plan's authorized-paths manifest.
2. Snapshots the implementation diff against the plan's decision base.
3. Rejects any added or modified path outside the manifest.
4. Honors subtree patterns explicitly and reports subtree expansion.

The check should run as part of `scripts/agent-preflight` so an out-of-surface implementation cannot pass preflight.

**Treatment of exact files vs subtree patterns:** exact files are listed verbatim; subtree patterns use a glob suffix (`test/kiln/artifact/**`) and are bounded so they cannot expand beyond the named subtree. Subtree patterns are not a license to add files anywhere; they are a license to add files inside the named subtree only.

**Expected reduction in review churn:** fewer round-trips where reviewers notice an unlisted path post-merge, fewer retrofits of file-table amendments after the fact, and a clearer audit trail between plan and diff.

**Risk of over-constraining legitimate refactors:** any implementation that moves code across files will need a corresponding plan amendment. That cost is the price of mechanical enforcement and is preferable to silent drift. The recommended mitigation is to allow the plan amendment and the implementation refactor to land in the same governance window when the refactor is purely cosmetic.

**How an agent should escalate when a new helper module becomes necessary:** stop, do not silently add the module, and open a governance ticket that proposes a plan amendment naming the new path, its bounded responsibilities, and its denied capabilities. Implementation of the helper module must not begin until the amended plan and reissued authorization record integrate on canonical `main`.

### Key lesson

> An exhaustive implementation surface is useful only if the tooling enforces it mechanically. Otherwise it creates ceremony without protection.

### Local verification results

_To be filled in by the implementing agent after running the gates listed under "Deterministic verification" above._

### Acceptance status

_To be filled in by the implementing agent after the local verification and any exact-head CI run._
