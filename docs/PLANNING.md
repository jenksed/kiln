# Kiln Planning Control

**Document type:** Planning and authority index  
**Status:** Wave A adjudicated  
**Build authorization:** P1-S01 consumed by PR #46; P1-S02-T01 adjudication consumed by rejected PR #48; corrected T01 plan owner-accepted via P0-W41 at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`; bounded T01 implementation authorized via P0-W42 and reissued via P0-W43 by `docs/authorizations/P1-S02-T01.authorization`; T01 implementation Not yet implemented; P1-S02-T02 and later unauthorized; active records governed by `docs/IMPLEMENTATION-AUTHORIZATION.md`

## Integrated Wave A baseline

| Pass or decision | Integrated equivalent |
| --- | --- |
| Prompt 1 through Prompt 4 | PRs 22–25 |
| OD-01 | PR 26 |
| P0-W21 | PR 27 and closeout PR 28 |
| P0-W22 | PR 29 |
| P0-W23 | PR 30 |
| OD-02 | PR 31 |
| P0-W24 | PR 32 |
| P0-W25 | PR 33 |
| Prompt 6-A | PR 34, final head `7b9afe5552ca0d336d343d4bfbe17ce7d14cc955`, merge `57a5790d2266cf1ab59f107d0b429c31c618e0ae`, CI `30425270052` |
| Provider and SQLite evidence correction | PR 35, merge `d76402a30e178d577d363384750baffd062cf9ef` |
| Prompt 7-A | independent adversarial review completed |
| Prompt 8-A | merged at `118bcaa`; P1-S01 integrated at `db02198` via PR #46 |

## Current authority order

Use these files in order:

1. [Wave A Adjudication and Development Authorization](WAVE-A-ADJUDICATION-AND-AUTHORIZATION.md) — executable authorization and review disposition.
2. [Owner Decision Register](OWNER-DECISIONS.md) — accepted owner choices.
3. [Root Run Lifecycle and Durable Journal](ROOT-RUN-LIFECYCLE-AND-JOURNAL.md) — lifecycle, journal, migration, restart, orphan, and completion transaction.
4. [Model, Context, and Repository Boundary](MODEL-CONTEXT-AND-REPOSITORY-BOUNDARY.md) — MiniMax M3, sealed Context, four Tools, Repository reads, disclosure, and secrets.
5. [Patch, Approval, and Mutation](PATCH-APPROVAL-AND-MUTATION.md) — complete-text Patch, Approval, mutation, rollback, and uncertain effect.
6. [Command, Evidence, and Acceptance](COMMAND-EVIDENCE-AND-ACCEPTANCE.md) — registered Commands, Artifacts, criterion Evidence, acceptance, atomic completion input, post-completion Receipt, and delivery.
7. [CLI and Local Delivery Contract](CLI-AND-LOCAL-DELIVERY-CONTRACT.md) — complete product CLI and arm64 macOS delivery target.
8. [Roadmap](ROADMAP.md), [Implementation Slices](IMPLEMENTATION-SLICES.md), and [Slice Acceptance Gates](SLICE-ACCEPTANCE-GATES.md) — authorized order and gates.
9. [First-month Contract Index](contracts/README.md) — conformance support only.
10. Accepted ADRs and integrated work records.

`docs/IMPLEMENTATION-AUTHORIZATION.md` and a matching record under `docs/authorizations/` are additionally required before a ticket or slice implementation branch may proceed. Plan acceptance and implementation authorization are separate decisions.

## Focused specification status

P0-W21 through P0-W25 are accepted and integrated through PRs 27 through 33.

Some large focused specification files still contain branch-era header text such as `proposed`, the old work branch, or `owner acceptance required`. That metadata is stale and is superseded by:

- this planning index;
- the final Wave A adjudication;
- the ADR index;
- the integrated work records;
- the merge history.

The detailed decisions inside those focused specifications remain active unless Prompt 8-A explicitly changes them.

Do not copy stale branch-era metadata into implementation plans or source documentation.

## Active focused decisions

- **P0-W21:** Session `active|completed|abandoned`; Task `in_progress|satisfied|abandoned`; Run `ready|running|waiting_for_user|orphaned|completed|failed|canceled`; workflow and operation state separate; one append-oriented journal; deterministic replay; conservative unknown effects; P0-W21 atomic completion.
- **P0-W22:** MiniMax M3 only; deterministic fake for tests; no fallback; sealed Context; four Tool maximum; bounded active-Repository reads; disclosure and secret controls.
- **P0-W23:** complete-text `add|replace|delete` Patch; exact base and digest; local-user Approval; one mutation owner; rollback data; exact base, target, or unknown recovery.
- **P0-W24:** registered non-shell Commands; macOS process-group proof; immutable Artifacts; criterion-bound Evidence; user acceptance; atomic completion before product Receipt sealing.
- **P0-W25:** foreground CLI; text and structured results; no bypass; explicit recovery; arm64 macOS Mix-release target.
- **OD-02:** Apple Silicon macOS 15.0 or later, local APFS, one interactive local user, owner's M1 Pro validation host.

## Prompt 6-A status and disposition

Prompt 6-A is complete and integrated.

Retained or revised:

- accepted conformance constants and transitions;
- provider and Command-host temporary behaviour seams;
- first-month Schema;
- positive and protected negative fixtures;
- semantic validator;
- pinned Draft 2020-12 validator;
- current preflight;
- local and CI validation wiring.

Removed:

- product-like `scaffold_status/0`;
- the absent-future-module test that locked implementation namespaces.

No conformance scaffold performs a product effect or grants authority.

## Final authorization

Authorization level:

> **P1-S01 Vertical Slice Authorized (consumed)**

The P1-S01 authorization was activated at the `118bcaa` merge and consumed by PR #46, which integrated P1-S01 at `db02198`.

The executed ticket chain (in actual merge order) was:

```text
P1-S01-T01  work/p1-s01-t01-domain-foundation   → merged
P1-S01-T02  work/p1-s01-t02-durable-store        → merged
P1-S01-T03  work/p1-s01-t03-replay-projections   → merged
P1-S01-T06  work/p1-s01-t06-workflow-surface     → merged
P1-S01-T04  work/p1-s01-t04-foundation-cli       → merged
P1-S01-T05  work/p1-s01-t05-slice-gate           → merged (PR #46 at db02198)
```

See `docs/work/P1-S01-T01-domain-foundation.md` through `docs/work/P1-S01-T05-slice-gate.md` and `docs/work/P1-S01-T06-workflow-surface.md` for per-ticket plans and completion records, and `docs/work/P1-S01-slice-closeout.md` for the slice closeout.

## Prohibited scope

P1-S01 does not authorize:

- provider or fake-provider execution;
- Repository source read, search, or disclosure;
- Context packages or model-facing Tools;
- source mutation;
- Patch, Approval, application, or rollback;
- external registered Commands or native helper;
- criterion completion Evidence;
- user completion acceptance;
- product Receipt sealing;
- release packaging or installation;
- Child Runs, Scout, Verifier, Attention, or TUI;
- P0-W26, P0-W27, or Wave B;
- broad build implementation.

PR #48 was adjudicated and rejected; every P1-S02 ticket remains planned and unauthorized.

PR #48 candidate commit `60367874bfc3c0e6d8cbd736f58e1ae17938943b` was premature. Correctly authorized head `7ba158bddff76ade9aca79cb8501e675bd0cded9` passed CI but failed technical adjudication; the PR closed without merge.

## Owner schedule adjudication

The first-month Single-Run Alpha target remains aggressive.

Schedule uncertainty does not remove accepted product requirements. A missed target causes replanning, not silent weakening of safety, durability, recovery, Evidence, CLI, packaging, or delivery.

## Wave B gate

P0-W26 and P0-W27 remain blocked until the authorized Single-Run Alpha produces accepted runtime Evidence for:

- one real source change;
- durable restart;
- controlled Patch authority;
- registered verification;
- criterion-bound Evidence;
- a valid post-completion product Receipt;
- observed failure or interruption behavior.

Wave B then still requires Prompt 6-B, Prompt 7-B, and Prompt 8-B before delegated implementation.

## Exact next action

P1-S01 integration and authority enforcement are complete. PR #48 was rejected. P0-W38 proposed a corrected T01 Evidence/result, accepted binding and conformance projection, persistence, protected-classification, state-based freshness, identity, transaction, replay/currentness, numeric bounds, migration, and API contract; it integrated through PR #56 at `e57678874a36de1700aa666413b51aae31ea9b12`. PR #53 remained the historical unmerged predecessor. P0-W41 records the owner acceptance of the corrected T01 plan against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; that acceptance integrated through PR #57 at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`. P0-W42 authorizes the bounded T01 implementation by creating `docs/authorizations/P1-S02-T01.authorization` against canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`, binding the Accepted-state plan digest, the trusted owner, and the bounded T01-v2 scope. Authorization permits but does not start implementation; no P1-S02 runtime implementation exists yet. P0-W43 adjudicates a discovered migration-runner incompatibility, narrowly authorizes `lib/kiln/store/migrations.ex` for compound-statement support, and reissues the authorization record against the amended plan digest. The exact next legitimate action after P0-W43 integrates is to move `work/p1-s02-t01-artifact-evidence-substrate-v2` to the resulting canonical `main` and begin implementation. Do not start implementation before that governance change integrates on canonical `main`; do not restore PR #48; do not implement any P1-S02-T02 or later ticket.
