# P3-W01: KIL-W3 Work Envelope Supervision v0

**Document type:** Implementation plan
**Status:** Accepted
**Parent slice:** KIL-W3 (Wave 3 work)
**Branch:** `work/p3-w01-kil-w3-work-envelope-supervision`
**Depends on:** P1-S02-T01 merged substrate at `ddaa176`; engineering-system coordination `6ee8d7c`

## Slice contribution

Builds the narrowest real application path that supervises one Repository
Recon Work Envelope through the merged P1-S02-T01 Artifact + Evidence
substrate. Adds the supervisor boundary; no broader Capability broker, no
P1-S02-T02 or later work.

## Objective

Accept an `engineering-system/work-envelope/v0` payload through a CLI
boundary (`mix kiln supervise --work-envelope <path>`), validate the
envelope through `Kiln.WorkEnvelope`, observe the target repository
through `Kiln.RepositoryObservation`, decide `git.read` authority through
`Kiln.Authority`, persist Artifact + Evidence through the merged
substrate, and produce an `engineering-system/run-result-envelope/v0`
that survives process death.

## Observed current state

| Observation | Evidence | Date |
| --- | --- | --- |
| P1-S02-T01 substrate merged at `ddaa176` | `git log` | current |
| `Kiln.Evidence` / `Evidence.Store` / `RecordRequest` available | `lib/kiln/evidence*` | current |
| `Kiln.Artifact.Store` available | `lib/kiln/artifact/store.ex` | current |
| `Kiln.Evidence.Currentness.evaluate/2` available | `lib/kiln/evidence/currentness.ex` | current |
| `Kiln.Evidence.View.from_evidence/2` and `to_first_month/1` available | `lib/kiln/evidence/view.ex` | current |
| Engineering-system coordination `WAVE-3-FIRST-REAL-RUN.md` exists | engineering-system repo | 2026-08-13 |

## Assumptions and unknowns

### Assumptions

- **P3-W01-A01:** The merged P1-S02-T01 substrate (Artifact + Evidence
  + Store) is the only substrate Kiln needs for the Wave 3 v0 path.
- **P3-W01-A02:** The Loadout producer supplies observation completion
  deterministically through the supervisor boundary.
- **P3-W01-A03:** The producer's `workspace_state_digest` and Kiln's
  `repository_state_digest` are independent and may differ; only the
  base_commit SHA is contractually equivalent.

### Unknowns

- **P3-W01-U01:** YAML parsing of Work Envelope payloads is delegated
  to JSON for the CLI v0; the engineering-system contract continues to
  publish YAML fixtures for readability.

## Requirements

- **P3-W01-R01:** The CLI exposes `supervise` and routes through
  `Kiln.Supervision`; it must not reach into `Evidence.Store`,
  `Artifact.Store`, or projection internals.
- **P3-W01-R02:** `Kiln.WorkEnvelope.new/1` validates schema identity,
  work_id, producer, goal, capability, project state, scope, constraints,
  proof obligations, and authority requests.
- **P3-W01-R03:** Work Envelope `work_id` is bound to a durable Run id
  through `supervision_runs (work_id, request_digest, run_id)` with
  `(work_id, request_digest)` unique. Replay of the same `(work_id,
  request_digest)` returns the same `run_id`; a different request digest
  for the same `work_id` returns an idempotency conflict.
- **P3-W01-R04:** The supervisor observes the target repository through
  `Kiln.RepositoryObservation`; producer `workspace_state_digest` and
  Kiln `repository_state_digest` are retained separately and never
  interchanged.
- **P3-W01-R05:** `Kiln.Authority.decide/1` accepts exactly `git.read`
  on the target repository; non-`git.read` capabilities are denied.
- **P3-W01-R06:** Observation completion is accepted through the same
  supervisor; procedure failure is recorded truthfully (no manufactured
  success).
- **P3-W01-R07:** The supervisor persists Artifact + Evidence through
  the merged substrate and produces a `kiln.evidence/v1` Evidence row
  binding the observation's `repository_state_digest`.
- **P3-W01-R08:** `Kiln.RunResultEnvelope.build/1` produces the
  engineering-system/run-result-envelope/v0 envelope with `status`,
  `authority`, `effects`, `evidence`, `proof_obligations`, `unknowns`,
  and `acceptance_readiness.ready = false`.
- **P3-W01-R09:** `Kiln.Supervision.inspect_run/2` reconstructs the
  envelope after process death from durable Artifact + Evidence + link
  tables.
- **P3-W01-R10:** `Currentness.evaluate/2` classifies stale Evidence
  when the current context's `repository_state_digest` differs from the
  recorded binding.

## Security boundary

Allowed:

- A CLI command `supervise` that routes through `Kiln.Supervision`.
- New modules `Kiln.WorkEnvelope`, `Kiln.WorkEnvelopeLoader`,
  `Kiln.RepositoryObservation`, `Kiln.Authority`, `Kiln.Supervision`,
  `Kiln.RunResultEnvelope`.
- New migration `0005_supervision_runs.sql` for the durable Run binding.
- New tests under `test/kiln/`.

Denied:

- General policy engine.
- Arbitrary Capabilities beyond `repository-recon`.
- Loadout ontology import.
- Mutations to the target repository.
- General agent runtime.
- P1-S02-T02 or later work.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `lib/kiln/work_envelope.ex` | Intake validation | Added |
| `lib/kiln/work_envelope_loader.ex` | CLI disk read | Added |
| `lib/kiln/repository_observation.ex` | Read-only repo observation | Added |
| `lib/kiln/authority.ex` | `git.read` decision | Added |
| `lib/kiln/run_result_envelope.ex` | Run Result Envelope v0 producer | Added |
| `lib/kiln/supervision.ex` | Orchestrating boundary | Added |
| `lib/kiln/cli.ex` | Dispatch `supervise` command | Modified |
| `lib/kiln/cli/request.ex` | Add `supervise` command + flag | Modified |
| `priv/store/migrations/0005_supervision_runs.sql` | Durable Run tables | Added |
| `test/kiln/work_envelope_test.exs` | Validation tests | Added |
| `test/kiln/repository_observation_test.exs` | Observation tests | Added |
| `test/kiln/authority_test.exs` | Authority tests | Added |
| `test/kiln/run_result_envelope_test.exs` | Envelope tests | Added |
| `test/kiln/supervision_test.exs` | Supervisor pipeline tests | Added |
| `docs/work/P3-W01-kil-w3-work-envelope-supervision.md` | This plan | Added |
| `docs/authorizations/P3-W01.authorization` | Authorization record | Added |
| `test/kiln/slices/p1_s01_test.exs` | Exclude Wave 3 modules | Modified |
| `test/kiln/store/migrations_test.exs` | Bump expected version | Modified |
| `test/kiln/store_test.exs` | Bump expected version | Modified |

## Proposed changes

1. Add `Kiln.WorkEnvelope` for payload validation.
2. Add `Kiln.WorkEnvelopeLoader` for disk reads.
3. Add `Kiln.RepositoryObservation` for read-only repo observation.
4. Add `Kiln.Authority` for `git.read` decision.
5. Add `Kiln.RunResultEnvelope` for envelope production.
6. Add `Kiln.Supervision` as the orchestrating boundary.
7. Extend `Kiln.CLI` to dispatch `supervise` through `Kiln.Supervision`.
8. Add `priv/store/migrations/0005_supervision_runs.sql` for the durable
   Run binding.

## Acceptance criteria

- **P3-W01-AC01:** Valid envelope binds to a durable Run id.
- **P3-W01-AC02:** Same work_id + same request returns the same Run.
- **P3-W01-AC03:** Same work_id + different request returns conflict.
- **P3-W01-AC04:** Authority denied for non-git.read capabilities.
- **P3-W01-AC05:** Restart preserves the durable facts.
- **P3-W01-AC06:** State change between observation and Evidence
  evaluation is classified stale, not silently current.

## Deterministic verification

```bash
scripts/agent-preflight
scripts/test-agent-preflight
scripts/validate-agent-assets
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
```

## Required completion Evidence

| Evidence ID | Acceptance criterion |
| --- | --- |
| P3-W01-E01 | AC01 |
| P3-W01-E02 | AC02 |
| P3-W01-E03 | AC03 |
| P3-W01-E04 | AC04 |
| P3-W01-E05 | AC05 |
| P3-W01-E06 | AC06 |

## Explicit exclusions

- General policy engine.
- Arbitrary Capabilities beyond `repository-recon`.
- Loadout ontology import.
- Mutations to the target repository.
- General agent runtime.
- P1-S02-T02 or later work.

## Completion record

**Result:** Authorized, implemented, and verified.
