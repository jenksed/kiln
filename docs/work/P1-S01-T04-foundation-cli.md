# P1-S01-T04: Implement the foundation CLI

**Document type:** Implementation plan  
**Status:** Accepted  
**Parent slice:** P1-S01  
**Branch:** `work/p1-s01-t04-foundation-cli`  
**Depends on:** P1-S01-T03 merged and accepted

## Slice contribution

P1-S01 enables a developer to create and inspect one durable Root Session before model or mutation complexity exists.

This ticket exposes only the implemented P1-S01 actions and queries through a minimal foreground CLI development entry point with equivalent text and structured results.

It contributes to P1-S01-G08 and G11 and enables the user-facing steps of P1-S01-D01.

After merge, the CLI does not expose provider, Context, Repository-source, Patch, Command, completion, Receipt, release, Child, or Wave B commands.

## Objective

Implement a minimal foreground CLI surface for Project selection metadata, Session start, status, inspect, supported cancellation, and restart-aware resume guidance without redefining domain or persistence semantics and without claiming the final packaged `kiln` release exists.

## Observed current state

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| T01 supplies domain actions and explicit errors | accepted ticket output | preceding ticket | merged state |
| T02 supplies the store and action transaction | accepted ticket output | preceding ticket | merged state |
| T03 supplies current projection queries and restart reconstruction | accepted ticket output | preceding ticket | merged state |
| P0-W25 defines the final CLI contract, but release packaging is not authorized in P1-S01 | focused CLI authority and Prompt 8-A | integrated planning | current authority |
| No user-facing CLI parser or renderer existed at Wave A authorization | Repository inspection | Prompt 8-A | baseline |

## Assumptions and unknowns

### Assumptions

- **P1-S01-T04-A01:** A project-scoped Mix task named `mix kiln` is the smallest development entry point and does not replace the later arm64 Mix-release launcher.
- **P1-S01-T04-A02:** A small explicit parser is sufficient for the authorized command set; no CLI framework dependency is required unless the implementation proves otherwise and returns to planning.
- **P1-S01-T04-A03:** One JSON document per non-streaming invocation is sufficient for structured output.

### Unknowns

- **P1-S01-T04-U01:** Terminal color and formatting details can remain minimal because product branding and packaged delivery are later work.
- **P1-S01-T04-U02:** Interactive confirmation wording can be refined in later product CLI work, but no bypass or fake success can enter now.

## Requirements

- **P1-S01-T04-R01:** The source-development CLI shall be invoked as `mix kiln` and shall identify itself as a development entry point, not the packaged product release.
- **P1-S01-T04-R02:** The CLI shall support only `start`, `status`, `inspect`, `cancel`, and `resume` guidance for implemented P1-S01 actions.
- **P1-S01-T04-R03:** `start` shall accept one Repository root, objective, and one or more criteria and shall map to the accepted atomic Session-start action.
- **P1-S01-T04-R04:** `status` shall query the current projection and shall not infer state from transcript text.
- **P1-S01-T04-R05:** `inspect` shall show exact Session, Task, Root Run, workflow, revision, decision, operation, warning, exclusion, and unknown facts available in P1-S01.
- **P1-S01-T04-R06:** `cancel` shall be accepted only when P0-W21 permits a known cancellation without an unresolved external effect.
- **P1-S01-T04-R07:** `resume` shall not perform hidden work; it shall report the current projection and valid next P1-S01 actions.
- **P1-S01-T04-R08:** Every invocation shall support text and `--format json` output with equivalent status, identifiers, revisions, warnings, errors, and next actions.
- **P1-S01-T04-R09:** Structured output shall use `kiln.cli.result/v1` and the accepted status and exit mappings.
- **P1-S01-T04-R10:** Unsupported future commands shall be absent or shall return explicit `unsupported` with exit 9. They shall not return fake success.
- **P1-S01-T04-R11:** Stale revision, blocked store, invalid input, known failure, and unknown or orphaned state shall map to the accepted distinct exits.
- **P1-S01-T04-R12:** CLI rendering shall not become domain or store authority.
- **P1-S01-T04-R13:** CLI logs and errors shall not include Repository source, secrets, complete transcript text, or hidden payloads.
- **P1-S01-T04-R14:** The ticket shall not create release, installer, Homebrew, daemon, TUI, or auto-update behavior.

## Security boundary

Allowed:

- read accepted P1-S01 projection and metadata through application query functions;
- submit accepted P1-S01 domain actions through the application boundary;
- parse bounded UTF-8 arguments and local file paths for objective or criteria input;
- render text or one JSON result;
- return explicit unsupported results for excluded commands.

Denied:

- direct database access from renderer or parser;
- Repository source reads;
- provider or network access;
- credentials;
- source mutation;
- shell or external Commands;
- product completion, product Receipt, release packaging, Child, TUI, or Wave B behavior;
- `--yes`, auto-approval, auto-acceptance, or hidden action chaining.

## Proposed changes

1. Add a small CLI request parser for the authorized P1-S01 command set.
2. Add application command and query dispatch without bypassing domain actions.
3. Add text and JSON renderers with stable result and error mapping.
4. Add a source-development Mix task entry point.
5. Add golden and structural tests proving text and JSON describe equivalent state.
6. Add protected unsupported-command and no-fake-success fixtures.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `lib/kiln/cli.ex` | parse, dispatch, and result boundary | Proposed |
| `lib/kiln/cli/request.ex` | bounded command and option types | Proposed |
| `lib/kiln/cli/result.ex` | accepted result and error envelope | Proposed |
| `lib/kiln/cli/text_renderer.ex` | deterministic text rendering | Proposed |
| `lib/kiln/cli/json_renderer.ex` | canonical JSON-compatible result construction | Proposed |
| `lib/mix/tasks/kiln.ex` | source-development `mix kiln` entry point | Proposed |
| `test/kiln/cli/` | parser, dispatch, output, exit, and unsupported-command tests | Proposed |
| `test/fixtures/cli/` | exact projection and output fixtures | Proposed |

A JSON runtime dependency is not authorized automatically. If canonical JSON output cannot be implemented safely with the existing dependency boundary, pause and return to planning rather than adding an unreviewed general dependency.

## Acceptance criteria

- **P1-S01-T04-AC01**
  - **Given** an empty accepted state directory and bounded start input
  - **When** `mix kiln start` runs
  - **Then** it creates one durable Session, Task, and Root Run and returns exact identifiers and revision in text and structured forms
  - **Evidence:** CLI start integration tests
- **P1-S01-T04-AC02**
  - **Given** current or restarted P1-S01 state
  - **When** `status` and `inspect` run
  - **Then** text and JSON outputs describe equivalent authoritative facts and safe next actions
  - **Evidence:** golden and structural equivalence tests
- **P1-S01-T04-AC03**
  - **Given** a valid known cancellation state or an orphaned or blocked state
  - **When** `cancel` runs
  - **Then** valid cancellation records the accepted action and unsafe cancellation returns the correct explicit result without changing state
  - **Evidence:** cancellation and no-change fixtures
- **P1-S01-T04-AC04**
  - **Given** stale revision, invalid input, blocked store, known failure, unknown state, or unsupported command
  - **When** CLI dispatch runs
  - **Then** each result uses the accepted status and exit code and none returns success
  - **Evidence:** protected result matrix
- **P1-S01-T04-AC05**
  - **Given** the CLI source and tests
  - **When** reviewed
  - **Then** no renderer or parser accesses SQLite directly or performs an excluded effect
  - **Evidence:** boundary source inspection and tests
- **P1-S01-T04-AC06**
  - **Given** the exact branch head
  - **When** full validation runs
  - **Then** all checks pass and no excluded command is reachable
  - **Evidence:** exact-head CI and compare

## Deterministic verification

```bash
scripts/test-agent-preflight
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
scripts/validate-agent-assets
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test test/kiln/cli
mix test
```

Focused manual fixture commands may use temporary `$KILN_HOME` paths and must not require network access.

## Demo contribution

```text
P1-S01-D01 user-visible path: start a Session, show Task and Run status, inspect durable facts, stop the application, restart, and show the same projection through `mix kiln`.
```

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P1-S01-T04-E01 | P1-S01-T04-AC01 | start command text and structured results |
| P1-S01-T04-E02 | P1-S01-T04-AC02 | output-equivalence fixture results |
| P1-S01-T04-E03 | P1-S01-T04-AC03 | cancellation and blocked-state results |
| P1-S01-T04-E04 | P1-S01-T04-AC04 | complete exit and error matrix |
| P1-S01-T04-E05 | P1-S01-T04-AC05 | layer-boundary review |
| P1-S01-T04-E06 | P1-S01-T04-AC06 | exact compare and CI run |

### Slice gate contribution

| Slice gate or verification manifest | Contribution |
| --- | --- |
| P1-S01-G08 | equivalent text and structured output and exit mapping |
| P1-S01-G11 | excluded commands absent or unsupported |
| P1-S01-V01 | command inventory, result fixtures, warnings, and exclusions |

## Explicit exclusions

- No packaged `kiln` Mix release, installer, checksum, Homebrew formula, daemon, or auto-update.
- No provider or fake-provider execution.
- No Repository source reads.
- No Context, Tool, Patch, Approval, mutation, Command, helper, criterion completion Evidence, product Receipt, Child, TUI, or Wave B behavior.
- No direct store access from CLI rendering.
- No hidden multi-step workflow or fake success.

## Completion record

**Result:** Verified pending CI

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| P1-S01-T04-AC01 | passed | P1-S01-T04-E01 | passed |
| P1-S01-T04-AC02 | passed | P1-S01-T04-E02 | passed |
| P1-S01-T04-AC03 | passed | P1-S01-T04-E03 | passed |
| P1-S01-T04-AC04 | passed | P1-S01-T04-E04 | passed |
| P1-S01-T04-AC05 | passed | P1-S01-T04-E05 | passed |
| P1-S01-T04-AC06 | passed | P1-S01-T04-E06 | passed |

### Verification executed

| Command or check | Exit status | Evidence location |
| --- | --- | --- |
| `mix format --check-formatted` | 0 | command output; all files formatted |
| `mix compile --warnings-as-errors` | 0 | command output; no warnings or errors |
| `mix xref graph --format cycles --label compile-connected --fail-above 0` | 0 | command output; no cycles found |
| `mix test` | 0 | command output; 194 tests passed |
| `scripts/test-agent-preflight` | 0 | command output; obsolete preflight fixture passed |
| `python3 scripts/validate_first_month_contracts.py` | 0 | command output; 10 positive and 11 protected negative fixtures passed |
| `python3 scripts/validate_json_schema_contracts.py` before environment setup | 1 | command output; pinned `jsonschema` package was not importable |
| `python3 -m venv .venv && .venv/bin/pip install -r requirements/conformance.txt` | 0 | local virtual environment; `jsonschema==4.26.0` installed |
| `source .venv/bin/activate && python3 scripts/validate_json_schema_contracts.py` | 0 | command output; 10 positive, 8 Schema-rejected, and 3 semantic-only fixtures passed |
| `scripts/validate-agent-assets` | 0 | command output; 5 Skills, 3 specialist agents, and 3 prompt templates passed |
| `source .venv/bin/activate && scripts/check` | 0 | aggregate gate; Vale passed 125 files and 194 tests passed |

### Demo and slice status

- Ticket demo contribution: Demonstrated locally via `mix kiln --help`/`version` and protected fixtures
- Parent slice gate affected: P1-S01-G08 and G11
- Slice verification manifest updated: No
- Slice completion claimed: No

### Failures and warnings

- This is a source-development entry point, not the delivered release.

### Remaining unknowns and exclusions

- Aggregate proof and owner-machine demo are T05.

### Repository state

- Commit: `e82225836ac25ba0d9cd1da4614ec169f907e01a`
- Branch: `work/p1-s01-t04-foundation-cli` (confirmed)
- Diff reviewed: Yes
- Exact CI run: `30514255493`, success (`prose` and `test` checks green) on PR #40
- Parent slice status after merge: unchanged
