# P0-W44: Simplify implementation authorization boundaries

**Document type:** Implementation plan (governance)
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w44-simplify-authorization-boundaries`
**Depends on:** P0-W43 integrated at `2f88281527811b8c4be0243fb201ae4416730a13` via PR #60; explicit owner adjudication that Kiln's implementation-governance model has become over-constrained and must be simplified before P1-S02-T01 implementation resumes.

## Objective

Replace source-topology authorization with semantic / capability authorization so ordinary implementation decomposition, deterministic clerical reconciliation, and mutable project-status prose no longer require owner reauthorization. Establish clear owner-escalation boundaries. Separate normative authority from derived status prose. Reduce digest churn. Stop the governance spiral that has interrupted P1-S02-T01 implementation.

This package contains no runtime, test, migration, schema, or enforcement-script change. It amends governance doctrine and minimum governance text only.

## Observed current state

| Observation | Evidence | Result |
| --- | --- | --- |
| Canonical `main` after PR #60 | `2f88281527811b8c4be0243fb201ae4416730a13` | observed |
| Active T01 plan digest | `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e` | observed at canonical `main` |
| Active T01 authorization base | `1243b8f27a594c9440638964a83b56c74774ba28` (P0-W43 decision base) | observed |
| T01 implementation branch head | `05423aa2a8fdbe65952a41c80159d0f61204beeb` | observed |
| T01 implementation adds `lib/kiln/artifact/fs.ex` | implementation branch | observed |
| T01 plan file-table closes with "No other path is authorized" | `docs/work/P1-S02-T01-artifact-evidence-substrate.md` | observed governance prose |
| Prior P0-W44 attempt | branch `work/p0-w44-reconcile-t01-file-surface` at `3df25cc7eb0cb4e4c81070fb530b8e6f9682bfb9`, based on the implementation branch and pushing T01 implementation underneath a governance-only commit | observed package-topology defect |
| Authorization state manually propagated across many documents | `AGENTS.md`, `README.md`, `docs/PLANNING.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION-SLICES.md`, `docs/IMPLEMENTATION-AUTHORIZATION.md` | observed duplication |
| Preflight currently validates authorization record, plan digest, owner, base, branch/work-package alignment; does not validate package topology against the canonical base | `scripts/agent-preflight` | observed enforcement gap |
| Trusted owner registry | `docs/authorizations/TRUSTED-OWNERS` | `Joshua Jenks` |
| Runtime on canonical `main` | no P1-S02 runtime implementation is integrated on canonical main | observed |

## Owner decision

The owner adjudicated at `2026-08-11T13:00:00-04:00` against canonical `main` `2f88281527811b8c4be0243fb201ae4416730a13` that Kiln's implementation-governance model has become over-constrained, that ordinary implementation decomposition, deterministic clerical reconciliation, and mutable project-status prose must not become owner authorization events, and that this package must simplify the model while preserving the safety properties listed under "Required safety properties that must survive" below.

The decision states verbatim:

> Kiln's implementation-governance model has become over-constrained. It is turning ordinary implementation decomposition, deterministic clerical reconciliation, and mutable project-status prose into owner authorization events. This is generating repeated digest churn, reauthorization cycles, duplicated state propagation, branch mistakes, and multi-day interruptions without corresponding safety value.
>
> We are simplifying the model now.
>
> Authorization must protect behavior, capability, security/trust boundaries, persistence contracts, accepted technical semantics, and genuinely protected surfaces. It must NOT make ordinary source-file decomposition, helper modules, test organization, or mutable lifecycle prose into independent owner decisions.

The decision narrowly authorizes this single governance simplification package. It does not:

- modify or re-authorize any P1-S02-T01 runtime implementation;
- authorize P1-S02-T02 or later;
- rehabilitate PR #48;
- rewrite or discard the existing Layer 2 checkpoint at `05423aa`;
- introduce new governance machinery beyond what is strictly required by this package.

## Required safety properties that must survive

This simplification MUST preserve every one of these properties. They are not negotiable.

1. Explicit owner-controlled authorization for each implementation package.
2. Accepted technical contract that the implementation must satisfy.
3. Trusted canonical authority source for accepted plans and authorization records.
4. Plan / authorization integrity binding via SHA-256 digests.
5. PR #48 prohibition remains in force.
6. No P1-S02-T02 or later authorization.
7. No unauthorized capability expansion (network, Repository source access, provider, process execution, etc.).
8. No silent persistence-contract changes.
9. No security-boundary expansion.
10. Exact implementation ancestry / Evidence against the trusted authority source.
11. Deterministic verification (preflight, validators, format, compile, xref, tests, prose lints).
12. Completion requiring current Evidence.

## Assumptions and unknowns

### Assumptions

- **P0-W44-A01:** The plan body amendment changes the plan SHA-256. Plan / authorization integrity is a required safety property, so the authorization record must be re-bound to the post-amendment digest in the same governance change. The re-bind is a digest update, not a new authorization scope.
- **P0-W44-A02:** The new authorization model changes only the granularity at which owner adjudication is required. It does not modify any T01 technical contract.
- **P0-W44-A03:** Mutable downstream prose (README.md, PLANNING.md, ROADMAP.md, IMPLEMENTATION-SLICES.md) is corrected by deterministic governance reconciliation after this package integrates. It is not smuggled into this package.
- **P0-W44-A04:** The T01 implementation branch at `05423aa` is preserved unchanged. T01 implementation can resume immediately after this package integrates.
- **P0-W44-A05:** Two enforcement follow-ups (package-topology validation against `merge-base(canonical_base, HEAD)..HEAD`; plan-manifest machine-readable representation) are recorded but explicitly out of scope for this package. They do not block T01 implementation.

### Unknowns

- **P0-W44-U01:** The exact structural format for separating digest-bound technical contract from mutable lifecycle metadata in future plan revisions is not decided here. The doctrine is established; the structural migration is a bounded follow-up.
- **P0-W44-U02:** The preflight enforcement follow-ups may be addressed as a single follow-up governance ticket or as separate tickets; that is an implementation choice for the future ticket.

## New authorization model

Authorization binds **semantic scope**, not arbitrary source topology.

### A. Capabilities

What the implementation is allowed to do. Examples for T01:

- Artifact persistence
- Artifact filesystem publication
- Evidence persistence
- Evidence currentness evaluation
- Migration execution
- Bounded compound-SQL recognition

### B. Security and trust boundaries

What the implementation must not cross. Examples for T01:

- Repository source access
- Network access
- Process execution
- Caller-selected Artifact root
- Destructive cleanup
- Secret exposure

### C. Durable / external contracts

Persisted or externally observable promises that the implementation must not change silently:

- Persisted SQLite schema
- Artifact / Evidence canonical representations
- Accepted vocabularies
- Idempotency semantics
- Durability guarantees
- Transaction ownership
- Migration semantics
- Public API surface

### D. Ticket / product scope

Boundaries between tickets and forbidden later capabilities:

- T01 vs T02 scope
- Forbidden Gate / Command / Patch / Receipt work
- PR #48 prohibition

### E. Explicitly protected paths (exception)

A specific source path may still be marked protected when changing the path itself is security- or authority-sensitive. Examples: authorization records, trusted-owner registries, certain governance scripts. Protected paths must be **declared explicitly** in the plan; absence of declaration means the path is not protected.

## Expected files are advisory by default

The T01 plan's `Expected files or components` section is **review guidance**, not an authorization boundary, unless a specific row is marked protected.

An implementation agent MAY add, split, rename, or reorganize subordinate implementation files when ALL of the following remain true:

1. the work implements an already-authorized capability or contract;
2. no new capability is introduced;
3. no new external effect is introduced;
4. no accepted persistence or API contract changes;
5. no security / trust boundary expands;
6. no later ticket scope is entered;
7. no explicitly protected path rule is violated;
8. tests and verification continue to prove the accepted behavior.

Therefore `lib/kiln/artifact/fs.ex` does not require a special owner authorization. It falls naturally under the already-authorized T01 Artifact filesystem publication responsibility.

## OWNER-DECISION-REQUIRED categories

Implementation MUST stop and request owner adjudication when any one of these categories is encountered:

### 1. New capability

The implementation needs to do something not already permitted by the work package (network access, Repository source read, Command execution, automatic deletion, provider interaction, background processing, etc.).

### 2. Accepted contract change

The implementation cannot satisfy the accepted requirement without changing a technical contract (Evidence semantics, canonical record identity, schema shape, transaction semantics, idempotency semantics, durability guarantees, accepted vocabulary, externally observable API semantics).

### 3. Security / trust-boundary expansion

Broader filesystem authority, new credentials, new external system, new caller-controlled path, destructive behavior, or weakened integrity guarantee.

### 4. Ticket / scope expansion

T02 behavior required during T01, Gate work appearing during Evidence substrate implementation, or a later Wave capability becoming necessary.

### 5. Genuine discretionary owner choice

Two or more materially different valid strategies exist and choosing among them changes product architecture, risk, contract, cost, or future direction.

## DETERMINISTIC IMPLEMENTATION DISCRETION (no owner reauthorization required)

Agents may proceed without owner reauthorization for:

- adding a private or subordinate helper module;
- splitting a large module into focused modules;
- moving private implementation code between modules;
- introducing additional test files inside the authorized test subtree;
- adding fixtures inside the authorized work;
- renaming private functions;
- improving internal decomposition;
- choosing among equivalent private algorithms where contract / security behavior is unchanged;
- strengthening an implementation while remaining inside accepted semantics.

These actions still require tests and review. They do not require a new owner authorization cycle.

## DETERMINISTIC GOVERNANCE RECONCILIATION (no owner reauthorization required)

Agents may repair a governance projection without owner adjudication when:

- the correct state is uniquely determined by accepted authority;
- no capability or technical contract changes;
- no authorization scope expands;
- no discretionary policy choice exists.

Examples:

- replacing stale "T01 unauthorized" prose after T01 has been authorized;
- correcting "base commit" vs "integration commit" terminology when the repository contains the exact facts;
- updating derived indexes, links, and next-action sentences;
- correcting obvious clerical inconsistencies.

These corrections should ideally be generated or validated automatically. They must not interrupt implementation unless the stale representation itself creates an unsafe ambiguity for enforcement.

## Requirements

- **P0-W44-R01:** The T01 plan's `Expected files or components` table shall be advisory by default unless a specific row is explicitly marked protected. Ordinary implementation decomposition (for example, `lib/kiln/artifact/fs.ex`) shall require no additional authorization when it implements an already-authorized capability or contract, introduces no new capability, changes no accepted persistence or API contract, expands no security / trust boundary, enters no later ticket scope, and violates no explicitly protected path.
- **P0-W44-R02:** The amended T01 plan shall include the OWNER-DECISION-REQUIRED, DETERMINISTIC IMPLEMENTATION DISCRETION, and DETERMINISTIC GOVERNANCE RECONCILIATION categories exactly as named in this plan.
- **P0-W44-R03:** `AGENTS.md` shall gain a short new section describing the new authorization model, the OWNER-DECISION-REQUIRED list, the DETERMINISTIC categories, and the required safety properties.
- **P0-W44-R04:** `docs/IMPLEMENTATION-AUTHORIZATION.md` shall gain a short note distinguishing normative authority from derived status / index prose.
- **P0-W44-R05:** The authorization record `docs/authorizations/P1-S02-T01.authorization` shall be re-bound to the post-amendment plan SHA-256 because plan / authorization integrity is a required safety property and the plan body was amended. The re-bind is a digest update, not a new authorization. Every other field and the canonical key order shall remain unchanged.
- **P0-W44-R06:** README.md, PLANNING.md, ROADMAP.md, and IMPLEMENTATION-SLICES.md shall not be modified by this package. Their corrections are deferred to deterministic governance reconciliation after merge.
- **P0-W44-R07:** This package shall change no Elixir source, migration, schema, test, or preflight / enforcement script.
- **P0-W44-R08:** The T01 implementation branch `work/p1-s02-t01-artifact-evidence-substrate-v2` at `05423aa` and the rescue stash / rescue ref shall remain untouched.
- **P0-W44-R09:** Two enforcement follow-ups (package-topology validation against `merge-base(canonical_base, HEAD)..HEAD`; plan-manifest machine-readable representation) shall be recorded but explicitly out of scope for this package. They shall not block T01 implementation.

## Document roles

Normative authority vs derived status must be separated:

### Normative

These grant, deny, or constrain implementation:

- Accepted technical contract inside an Accepted plan
- Machine-readable authorization record (`docs/authorizations/*.authorization`)
- Trusted-owner authority (`docs/authorizations/TRUSTED-OWNERS`)
- Explicitly designated governance policy marked as normative

### Derived status / index

Summarize normative state but do not independently grant or revoke authority:

- Current status dashboards
- Implementation-slice summaries
- Roadmap status
- README current-state summaries
- AGENTS.md "Current authorization boundary" narrative

Preflight must consume **normative authority**, not infer authorization by reconciling every prose projection.

### Historical provenance

Describes what happened at a prior point. Do not rewrite merely because current state changed.

### Narrative / design documentation

Explains architecture and rationale. Does not independently authorize implementation unless explicitly designated normative.

## Digest churn reduction

Plan / authorization digests should protect stable technical authority, not mutable lifecycle metadata. Two bounded changes are introduced by this package:

1. The T01 plan retains its existing `plan_sha256` binding to the technical-contract body. Lifecycle metadata (Status, next action, integration SHA, current implementation checkpoint) is downstream prose and does not need to invalidate the digest when corrected.
2. Future plan amendments MAY separate "Digest-bound technical contract" (requirements, acceptance criteria, security boundary, durable contracts, capability declarations, explicit protected paths) from "Mutable lifecycle metadata" (Status, integration SHA, current implementation head, narrative history). This package does not require a full structural migration; it establishes the doctrine and identifies the bounded follow-up.

## Proposed changes

1. Amend `docs/work/P1-S02-T01-artifact-evidence-substrate.md`:
   - Replace the "No other path is authorized" closing sentence with the new doctrine: file table is advisory by default; protected paths must be declared explicitly; `lib/kiln/artifact/fs.ex` is acknowledged as a legitimate subordinate decomposition and requires no additional authorization.
   - Add the OWNER-DECISION-REQUIRED categories as authoritative escalation guidance for T01 implementation.
   - Add the DETERMINISTIC IMPLEMENTATION DISCRETION and DETERMINISTIC GOVERNANCE RECONCILIATION categories.
   - Note that this plan's `Expected files or components` table is review guidance, not authorization, unless a row is explicitly marked protected.
2. Add a short new section to `AGENTS.md` describing the new authorization model, the OWNER-DECISION-REQUIRED list, and the DETERMINISTIC IMPLEMENTATION DISCRETION / GOVERNANCE RECONCILIATION categories. Do NOT rewrite the existing authority-history narrative; it is historical provenance.
3. Add a short note to `docs/IMPLEMENTATION-AUTHORIZATION.md` distinguishing normative from derived document roles. Do not rewrite the existing authority-history narrative; it is historical provenance.
4. Do not modify README.md, PLANNING.md, ROADMAP.md, or IMPLEMENTATION-SLICES.md. They bind mutable lifecycle metadata and are not normative; they will be corrected by deterministic governance reconciliation after this package integrates, NOT in this package. Update the authorization record to bind the post-amendment plan digest because plan / authorization integrity is a required safety property and the plan body was amended by this package. The authorization-record update is a digest re-binding, not a new authorization.

This keeps the package small. It minimizes digest churn. It does not touch mutable downstream prose.

## Expected files or components

| Path | Expected change | Status |
| --- | --- | --- |
| `docs/work/P0-W44-simplify-authorization-boundaries.md` | this governance plan | Proposed |
| `docs/work/P1-S02-T01-artifact-evidence-substrate.md` | advisory-file-table doctrine, escalation categories, deterministic categories, `lib/kiln/artifact/fs.ex` adjudication | Proposed |
| `AGENTS.md` | short new section describing the new authorization model, OWNER-DECISION-REQUIRED list, and DETERMINISTIC categories | Proposed |
| `docs/IMPLEMENTATION-AUTHORIZATION.md` | short note distinguishing normative from derived document roles | Proposed |
| `docs/authorizations/P1-S02-T01.authorization` | digest re-binding to amended plan SHA-256 | Proposed |

No other path is changed by this package.

## Acceptance criteria

- **P0-W44-AC01 — Advisory file-table doctrine applied**
  - **Given** the amended T01 plan;
  - **When** its `Expected files or components` section is read;
  - **Then** the closing sentence no longer claims exhaustive authority, the table is described as review guidance, and `lib/kiln/artifact/fs.ex` is explicitly acknowledged as a subordinate decomposition requiring no additional authorization.
  - **Evidence:** plan text.
- **P0-W44-AC02 — Escalation and discretion categories present**
  - **Given** the amended T01 plan and the AGENTS.md update;
  - **When** the new authorization model sections are read;
  - **Then** the OWNER-DECISION-REQUIRED, DETERMINISTIC IMPLEMENTATION DISCRETION, and DETERMINISTIC GOVERNANCE RECONCILIATION categories appear and match the lists in this plan.
  - **Evidence:** plan text and AGENTS.md text.
- **P0-W44-AC03 — Package topology is governance-only**
  - **Given** the final branch diff against canonical `main` `2f88281`;
  - **When** it is inspected for scope leakage;
  - **Then** the diff is limited to the five files named in this plan's file table, contains no file under `lib/`, `test/`, `priv/`, `config/`, `mix.exs`, `mix.lock`, or any preflight / enforcement script, and contains no implementation branch ancestry.
  - **Evidence:** `git diff --name-only origin/main..HEAD`.
- **P0-W44-AC04 — Existing T01 plan amended only by named edits and authorization record digest re-bound**
  - **Given** the final plan and authorization record blobs;
  - **When** they are diffed against canonical `main`;
  - **Then** any change to the T01 plan is limited to the named `P0-W44-AC01` and `P0-W44-AC02` sections, and the authorization record's `plan_sha256` is updated to the post-amendment plan digest while every other field and the canonical key order remain unchanged.
  - **Evidence:** `git diff origin/main -- docs/work/P1-S02-T01-artifact-evidence-substrate.md` and `git diff origin/main -- docs/authorizations/P1-S02-T01.authorization`.
- **P0-W44-AC05 — Downstream mutable prose left alone in this package**
  - **Given** the final branch diff;
  - **When** it is inspected;
  - **Then** README.md, PLANNING.md, ROADMAP.md, and IMPLEMENTATION-SLICES.md are byte-identical to canonical `main`. Their corrections are deferred to deterministic governance reconciliation after merge, not smuggled into this package.
  - **Evidence:** `git diff origin/main -- README.md docs/PLANNING.md docs/ROADMAP.md docs/IMPLEMENTATION-SLICES.md` is empty.
- **P0-W44-AC06 — All local gates pass**
  - **Given** the branch head;
  - **When** the standard verification suite runs;
  - **Then** every command in the "Deterministic verification" section exits `0`.
  - **Evidence:** exit codes.
- **P0-W44-AC07 — Implementation branch is not disturbed**
  - **Given** the existing implementation branch `work/p1-s02-t01-artifact-evidence-substrate-v2` at `05423aa`;
  - **When** this package integrates;
  - **Then** that branch's HEAD is unchanged, no commits from this package are added to it, and the rescue stash / rescue ref created earlier are still present and untouched.
  - **Evidence:** `git rev-parse origin/work/p1-s02-t01-artifact-evidence-substrate-v2` still equals `05423aa`; `git stash list` still contains the rescue entry; `rescue/pre-verification-stash` still exists.

## Deterministic verification

```bash
git merge-base origin/main HEAD
git rev-list --count origin/main..HEAD
git diff --name-only origin/main..HEAD
git diff --check
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
```

Every command must exit `0`, except where a pre-existing environment-only failure is recorded with Evidence and shown to be unchanged by this package.

## High-priority enforcement follow-up (NOT contained in this package)

Two enforcement defects surfaced during this work. They are recorded here as bounded follow-ups and are NOT implemented in this package. They are the only follow-up governance work permitted before T01 implementation resumes, and both must be deferred until after T01 Layer 3 unless they directly prevent a concrete safety failure.

### Follow-up A — Package topology enforcement

Governance / package scope must be evaluated against the full package diff from its canonical base, not only `HEAD~1..HEAD`. The prior P0-W44 attempt demonstrated this failure: a governance-only commit sat on top of an unmerged implementation branch, so `HEAD~1..HEAD` was governance-clean while the package as a whole contained runtime ancestry.

The correct invariant: scope validation evaluates `merge-base(canonical_base, HEAD)..HEAD`, not only the last commit. For a governance-only package, runtime changes anywhere in that range must fail.

### Follow-up B — Plan-manifest machine-readable representation

Plans currently expose their authorized surface as a Markdown file table. Preflight has no machine-readable counterpart and therefore cannot mechanically enforce path rules. The plan-manifest contract should gain a `paths.json` sidecar with explicit exact-path and bounded-subtree entries, and preflight should consume it.

Both follow-ups are explicitly OUT OF SCOPE for this package. They are recorded here so they are not lost. They must not block T01 implementation.

## Exact next action after P0-W44 merges

1. Record the resulting canonical `main` SHA.
2. Move `work/p1-s02-t01-artifact-evidence-substrate-v2` to that exact commit, preserving the existing `05423aa` implementation ancestry.
3. Confirm the T01 plan and authorization record are byte-identical to trusted canonical `main`.
4. Run `scripts/agent-preflight` and `scripts/test-agent-preflight` on the moved implementation branch.
5. Re-run Layer 2 targeted and full gates.
6. **Begin Layer 3 / Evidence immediately.** Do not introduce another governance planning cycle between step 5 and step 6 unless a real OWNER-DECISION-REQUIRED condition is discovered.

## Project Arsenal feedback — governance spiral root cause

This package is the first governance simplification that names the failure mode directly. The Project Arsenal repository should encode the principle:

> **Escalate discretion. Automate determinism.**

For every proposed Arsenal improvement, identify:

- safety property preserved;
- ceremony removed;
- automation opportunity;
- owner responsibility remaining;
- expected reduction in interruptions.

### Failure 1 — Source topology became authorization

A helper module required owner reauthorization despite no behavioral scope expansion. The fix is to replace source-path authorization with capability + contract authorization, and to declare protected paths explicitly only when path identity is itself security- or authority-sensitive.

### Failure 2 — Cryptographic binding included mutable governance state

Minor plan / status changes cascaded into digest and authorization reissuance. The fix is to separate digest-bound technical contract (requirements, acceptance criteria, security boundary, durable contracts, capability declarations, explicit protected paths) from mutable lifecycle metadata (Status, integration SHA, current implementation head, narrative history). Plan amendments should reissue the digest only when the technical-contract body actually changes.

### Failure 3 — Duplicated state projections

Authorization state was manually repeated across many documents, creating contradiction opportunities. The fix is to separate normative authority (accepted plan, authorization record, trusted-owner registry) from derived status / index prose. Preflight must consume normative authority directly; it must not attempt to infer authorization by reconciling every prose projection.

### Failure 4 — Clerical errors escalated to owner decisions

Deterministically repairable inconsistencies repeatedly interrupted implementation. The fix is the DETERMINISTIC GOVERNANCE RECONCILIATION category, which permits agents to repair obvious clerical inconsistencies without owner reauthorization.

### Failure 5 — Package truth was confused with commit truth

A governance commit looked clean when inspected as `HEAD~1..HEAD`, while its actual branch contained runtime implementation ancestry. The fix is Follow-up A: scope validation against `merge-base(canonical_base, HEAD)..HEAD`.

### Failure 6 — Process optimized for avoiding procedural deviation instead of maximizing safe engineering progress

The fix is the temporary governance freeze recorded below.

### Top five changes Arsenal should make

1. Replace plan `Expected files or components` Markdown table with a machine-readable `paths.json` sidecar that distinguishes exact files from bounded subtrees, and update preflight to consume it. Removes Failure 1 and parts of Failure 3.
2. Split plan bodies into "Digest-bound technical contract" and "Mutable lifecycle metadata", with digest binding the former only. Removes Failure 2.
3. Add explicit OWNER-DECISION-REQUIRED, DETERMINISTIC IMPLEMENTATION DISCRETION, and DETERMINISTIC GOVERNANCE RECONCILIATION categories to plan templates and preflight documentation. Removes Failure 4.
4. Add package-topology validation against `merge-base(canonical_base, HEAD)..HEAD` to preflight. Removes Failure 5.
5. Mark README.md, ROADMAP.md, PLANNING.md, IMPLEMENTATION-SLICES.md, and the AGENTS.md authority-boundary narrative as "derived status / index" rather than normative authority, so preflight stops treating them as authority sources. Removes Failure 3.

### Temporary governance freeze

No new governance mechanism may be introduced before P1-S02-T01 completes unless it prevents a concrete security, trust, persistence-integrity, or authorization-boundary failure. Allowed governance maintenance during T01: fix a real enforcement bug; correct deterministic authority ambiguity; repair branch topology; repair an actual safety boundary. Not allowed: richer status indexes, new evidence-document bureaucracy, additional owner-approval stages, new prose synchronization requirements, module / path whitelisting, new digest-bound lifecycle metadata.

## Explicit exclusions

- No runtime, migration, schema, test, or enforcement-script change.
- No modification of `lib/`, `test/`, `priv/`, `config/`, `mix.exs`, `mix.lock`, or `scripts/agent-preflight`.
- No P1-S02-T01 implementation.
- No P1-S02-T02 or later authorization.
- No PR #48 reuse, cherry-pick, restoration, or rehabilitation.
- No modification of any historical `docs/work/` provenance record.
- No rewriting of mutable downstream prose (README.md, PLANNING.md, ROADMAP.md, IMPLEMENTATION-SLICES.md). Their corrections are deferred to deterministic governance reconciliation after merge.
- No reissuing of the authorization record with new authorization scope or new owner decision. The authorization record IS updated to bind the post-amendment plan digest because plan / authorization integrity is a required safety property and the plan body was amended by this package. The change is a digest re-binding, not a new authorization.
- No prediction or invention of the canonical integration commit produced by merging this package.

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P0-W44-E01 | P0-W44-AC01 | plan text proving the closing sentence no longer claims exhaustive authority, the table is described as review guidance, and `lib/kiln/artifact/fs.ex` is acknowledged as a subordinate decomposition |
| P0-W44-E02 | P0-W44-AC02 | plan text and AGENTS.md text proving OWNER-DECISION-REQUIRED, DETERMINISTIC IMPLEMENTATION DISCRETION, and DETERMINISTIC GOVERNANCE RECONCILIATION categories appear |
| P0-W44-E03 | P0-W44-AC03 | `git diff --name-only origin/main..HEAD` proving the diff is limited to the named files and contains no runtime branch ancestry |
| P0-W44-E04 | P0-W44-AC04 | `git diff origin/main -- docs/work/P1-S02-T01-artifact-evidence-substrate.md` and `git diff origin/main -- docs/authorizations/P1-S02-T01.authorization` |
| P0-W44-E05 | P0-W44-AC05 | `git diff origin/main -- README.md docs/PLANNING.md docs/ROADMAP.md docs/IMPLEMENTATION-SLICES.md` empty |
| P0-W44-E06 | P0-W44-AC06 | exit codes from the deterministic verification suite |
| P0-W44-E07 | P0-W44-AC07 | `git rev-parse origin/work/p1-s02-t01-artifact-evidence-substrate-v2` equals `05423aa`; `git stash list` still contains the rescue entry; `rescue/pre-verification-stash` still exists |

## Completion record

**Result:** Prepared for owner review. Not merged, not implemented, not verified.

| Stage | Status | Result |
| --- | --- | --- |
| Owner adjudication | Granted | recorded at `2026-08-11T13:00:00-04:00` against canonical `main` `2f88281527811b8c4be0243fb201ae4416730a13` |
| Governance change | Prepared | pending owner review and merge |
| T01 implementation | Checkpoint exists; execution paused | Layer 2 implementation checkpoint at `05423aa2a8fdbe65952a41c80159d0f61204beeb` exists on `work/p1-s02-t01-artifact-evidence-substrate-v2`; it is not integrated on canonical `main`; it remains untouched by P0-W44; execution may resume only after this package integrates and the implementation branch is moved / reconciled against the resulting canonical authority |
| Project Arsenal defect | Reported | two follow-ups recorded; both deferred until after T01 Layer 3 |
