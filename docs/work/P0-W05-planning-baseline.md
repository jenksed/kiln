# P0-W05: Planning Baseline Audit

**Document type:** Reference  
**Status:** In progress  
**Branch:** `work/p0-w05-planning-baseline`  
**Depends on:** P0-W04 through draft pull request 5

## Objective

Audit the current Kiln planning stack and establish one planning-status baseline before roadmap reconciliation or production implementation.

## Observed current state

| Observation | Evidence | Date or commit |
| --- | --- | --- |
| `main` contains the repository foundation from pull request 1. | Merge commit `10089b00c2c944e1858d54d900fcba0faa055500` | 2026-07-28 |
| P0-W02 and P0-W03 merged into intermediate branches, not `main`. | Pull requests 3 and 4 | 2026-07-28 |
| P0-W04 is an open draft that changes product and architecture documents. | Pull request 5 | 2026-07-28 |
| The P0-W04 head is `c5a919f32d422ccc1a5371afd955172a8a0a20c5`. | Pull request 5 metadata | 2026-07-28 |
| P0-W04 CI failed at agent asset validation. Later Elixir checks were skipped. | Workflow run `30332448342`, job `90190297822` | 2026-07-28 |
| The source implements only a Mix project, empty supervisor, version function, and one version test. | `mix.exs`, `lib/`, `test/` | 2026-07-28 |
| Current documents use accepted, integrated, implemented, and verified inconsistently. | Roadmap, ADRs 0004 and 0005, P0-W04 plan, pull-request state | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W05-A01:** P0-W04 content must be audited because it is the active product and architecture candidate.
- **P0-W05-A02:** `main` remains integrated truth until stacked work merges.
- **P0-W05-A03:** Owner acceptance and repository integration are separate states.
- **P0-W05-A04:** This pass can define planning status without redesigning product architecture.

### Unknowns

- **P0-W05-U01:** Unknown. The final integration order and rebase plan for pull requests 3 through 5 is not recorded.
- **P0-W05-U02:** Unknown. The exact cause of the agent asset validation failure requires script-level diagnosis.
- **P0-W05-U03:** Unknown. The final Phase 1 and Phase 2 order requires a separate reconciliation pass.
- **P0-W05-U04:** Unknown. The project has no accepted rule for recording owner acceptance before branch integration.

## Requirements

- **P0-W05-R01:** The audit shall distinguish observed facts, accepted decisions, proposed decisions, assumptions, unknowns, conflicts, and superseded statements.
- **P0-W05-R02:** The audit shall not claim a capability exists without source, test, or executed verification evidence.
- **P0-W05-R03:** The audit shall identify the current product, architecture, roadmap, decision, security, and work-package authorities.
- **P0-W05-R04:** The audit shall define Kiln's current product position and compare it with repository evidence.
- **P0-W05-R05:** The audit shall provide a glossary for inconsistent product and architecture terms.
- **P0-W05-R06:** The audit shall provide accepted-decision, conflict, superseded-statement, unknown-question, and planning-gap registers.
- **P0-W05-R07:** The audit shall recommend which documents to retain, merge, replace, or archive.
- **P0-W05-R08:** The audit shall preserve accepted decisions and shall not redesign Kiln.
- **P0-W05-R09:** The repository start sequence shall link to the planning baseline.
- **P0-W05-R10:** The roadmap shall record this work package and its dependency on P0-W04.
- **P0-W05-R11:** The closeout shall identify files inspected, files changed, conflicts, authorities, superseded statements, unknowns, and evidence.

## Proposed changes

1. Add `docs/PLANNING-BASELINE.md`.
2. Add this work-package plan.
3. Link the baseline from the README.
4. Require coding sessions to read the baseline before broad planning or architecture work.
5. Add P0-W05 to the Phase 0 roadmap table.
6. Do not modify production source.

## Expected files or components

| Path | Expected change |
| --- | --- |
| `docs/PLANNING-BASELINE.md` | Add the complete audit and registers. |
| `docs/work/P0-W05-planning-baseline.md` | Add the work-package contract. |
| `README.md` | Add the planning-baseline link and status note. |
| `AGENTS.md` | Add the planning baseline to the required start sequence. |
| `docs/ROADMAP.md` | Add P0-W05 and state that reconciliation follows it. |

## Acceptance criteria

- **P0-W05-AC01**
  - **Given** the current integrated and stacked planning state
  - **When** a coding session reads the planning baseline
  - **Then** it can identify the product, architecture, roadmap, decision, and implementation authorities
  - **Evidence:** source-of-truth map in `docs/PLANNING-BASELINE.md`

- **P0-W05-AC02**
  - **Given** planned but unimplemented Kiln capabilities
  - **When** the baseline describes implementation reality
  - **Then** it separates intended responsibilities from implemented and verified behavior
  - **Evidence:** implementation-reality section and source inventory

- **P0-W05-AC03**
  - **Given** ADRs and branch documents with different integration states
  - **When** the decision register classifies them
  - **Then** it distinguishes accepted, integrated, provisional, exploratory, and deferred states
  - **Evidence:** accepted-decisions register

- **P0-W05-AC04**
  - **Given** fragmented or contradictory planning text
  - **When** the audit completes
  - **Then** each material conflict has an identifier, impact, evidence, and required resolution
  - **Evidence:** CF-001 through CF-012

- **P0-W05-AC05**
  - **Given** future planning or architecture work
  - **When** a coding session starts that work
  - **Then** repository instructions direct it to the planning baseline before it changes the plan
  - **Evidence:** README and AGENTS links

- **P0-W05-AC06**
  - **Given** the Phase 0 roadmap
  - **When** P0-W05 is added
  - **Then** the roadmap states that implementation-order reconciliation follows the baseline audit
  - **Evidence:** Phase 0 table and pending-reconciliation text

- **P0-W05-AC07**
  - **Given** this documentation-only pass
  - **When** the final diff is reviewed
  - **Then** no production source file has changed
  - **Evidence:** changed-file list

## Verification commands

```bash
scripts/agent-preflight
scripts/validate-agent-assets
vale .
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

Each command must exit with status `0` before this work package is complete.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W05-E01 | P0-W05-AC01 | Planning authority table and current branch evidence. |
| P0-W05-E02 | P0-W05-AC02 | Source and test inventory with explicit non-implementation list. |
| P0-W05-E03 | P0-W05-AC03 | Decision-status register. |
| P0-W05-E04 | P0-W05-AC04 | Conflict register with required resolution. |
| P0-W05-E05 | P0-W05-AC05 | README and AGENTS links. |
| P0-W05-E06 | P0-W05-AC06 | Updated roadmap. |
| P0-W05-E07 | P0-W05-AC07 | Final changed-file list with no production source files. |
| P0-W05-E08 | All | Passing CI for the final branch head. |

## Explicit exclusions

- production code;
- roadmap reordering;
- new runtime architecture;
- provider implementation;
- capability-policy design;
- context-system design;
- TUI library selection;
- P0-W04 CI repair;
- pull-request stack integration;
- acceptance of new product capabilities.

## Completion record

**Result:** Implemented but unverified

### Acceptance status

| Criterion | Status | Evidence ID |
| --- | --- | --- |
| P0-W05-AC01 | Implemented; verification pending | P0-W05-E01 |
| P0-W05-AC02 | Implemented; verification pending | P0-W05-E02 |
| P0-W05-AC03 | Implemented; verification pending | P0-W05-E03 |
| P0-W05-AC04 | Implemented; verification pending | P0-W05-E04 |
| P0-W05-AC05 | Implemented; verification pending | P0-W05-E05 |
| P0-W05-AC06 | Implemented; verification pending | P0-W05-E06 |
| P0-W05-AC07 | Observed; verification pending | P0-W05-E07 |

### Verification executed

No complete verification has run for the final P0-W05 branch head.

The final diff was inspected through the GitHub commit comparison.

### Failures and warnings

- The dependency branch has a failing CI run.
- P0-W05 verification remains pending.
- Documentation changes can trigger the same asset-validation failure until the validation contract is reconciled.

### Remaining unknowns and exclusions

- P0-W05-U01 through P0-W05-U04 remain open.
- Roadmap reconciliation and production implementation remain excluded.

### Repository state

- Branch: `work/p0-w05-planning-baseline`
- Base branch: `work/p0-w04-run-graph-stewardship`
- Base commit: `c5a919f32d422ccc1a5371afd955172a8a0a20c5`
- Branch head before this closeout update: `b9d0fd65d54c61e11d284870533d33eb01069a8d`
- Changed files: `AGENTS.md`, `README.md`, `docs/PLANNING-BASELINE.md`, `docs/ROADMAP.md`, `docs/work/P0-W05-planning-baseline.md`
- Production source files changed: None
- Diff reviewed: Yes
- Complete verification: Pending