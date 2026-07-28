## Objective

<One work-package objective>

## Work package

- ID: `<WORK-ID>`
- Plan: `docs/work/<WORK-ID>-<purpose>.md`
- Dependencies: None | `<WORK-ID list>`

## Observed starting state

- <Observed fact and repository, command, test, runtime, or official-documentation evidence>

## Changes

- <Change>

## Acceptance status

| Criterion | Status | Evidence ID | Evidence |
| --- | --- | --- | --- |
| `<WORK-ID>-AC01` | Pass | `<WORK-ID>-E01` | <path, command result, artifact, or runtime observation> |

## Verification

| Command or check | Exit status | Result or artifact |
| --- | --- | --- |
| `mix format --check-formatted` | `<status>` | <result> |
| `mix compile --warnings-as-errors` | `<status>` | <result> |
| `mix test` | `<status>` | <result> |
| `vale .` | `<status>` | <result> |

## Failures and warnings

- None observed. | <failure or warning>

## Unknowns and exclusions

- <Unknown, cheapest reliable verification method, or explicit exclusion>

## Architecture decisions

- None. | `ADR-<NNNN>`

## Completion statement

Complete | Implemented but unverified | Blocked

State why the selected result is accurate. Do not use `complete` when required verification did not run.