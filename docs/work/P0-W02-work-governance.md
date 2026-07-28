# P0-W02: Work Governance

**Document type:** Reference  
**Status:** Complete  
**Branch:** `work/p0-w02-work-governance`  
**Depends on:** P0-W01 repository foundation

## Objective

Define a branch-linked planning and evidence system that reduces coordination cost and preserves work provenance.

## Observed current state

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| Kiln had a proof-ordered roadmap but no branch naming policy. | `docs/ROADMAP.md` at `5a05c22d11564689df183c90d4794a25a3693896` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln required ADRs for foundational changes but had no ADR template. | `AGENTS.md` lines 65-69 at `5a05c22d11564689df183c90d4794a25a3693896` | ChatGPT GitHub connector | 2026-07-28 |
| The bootstrap branch predates the branch naming policy. | Branch `agent/bootstrap-project-foundation` | ChatGPT GitHub connector | 2026-07-28 |
| CI checked Elixir formatting, compilation, and tests but did not check prose. | `.github/workflows/ci.yml` at `5a05c22d11564689df183c90d4794a25a3693896` | ChatGPT GitHub connector | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W02-A01:** A stable work-package identifier will reduce intent reconstruction across plans, branches, pull requests, and evidence.
- **P0-W02-A02:** Trunk-based development with short-lived branches is suitable for the current single-developer project.

### Unknowns

- **P0-W02-U01:** Unknown. The useful maximum branch size will be measured during Phase 1 work packages.
- **P0-W02-U02:** Unknown. The long-term Vale false-positive rate requires evidence from later documentation changes. Review each reported violation before expanding the rule set.

## Requirements

- **P0-W02-R01:** The repository shall define one branch naming grammar for planned work.
- **P0-W02-R02:** Each planned work branch shall include a stable work-package identifier.
- **P0-W02-R03:** Each work-package plan shall connect requirements, acceptance criteria, and completion evidence through the work-package identifier.
- **P0-W02-R04:** The repository shall define normative language, requirement, evidence, planning, ADR, and completion rules.
- **P0-W02-R05:** Documentation linting shall use repository-local deterministic rules.
- **P0-W02-R06:** The bootstrap branch shall remain an explicit one-time naming exception.

## Proposed changes

1. Add branch classes and a branch naming grammar.
2. Add work-package, requirement, acceptance, and evidence identifiers.
3. Map Phase 1 work packages to proposed branch names and dependencies.
4. Add normative engineering quality rules.
5. Add implementation-plan and ADR templates.
6. Add a pull-request template that requires evidence and unknowns.
7. Add Vale configuration and repository-local rules.
8. Add prose linting to continuous integration.
9. Link the new rules from contributor and project documentation.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `docs/BRANCHING-AND-WORK-PLANNING.md` | Add branch and work-package rules. | Added |
| `docs/ENGINEERING-QUALITY-RULES.md` | Add normative writing, requirements, evidence, and completion rules. | Added |
| `docs/templates/IMPLEMENTATION-PLAN.md` | Add work-package plan template. | Added |
| `docs/templates/ADR.md` | Add ADR template. | Added |
| `.github/pull_request_template.md` | Add evidence-centered pull-request template. | Added |
| `.vale.ini` | Configure prose linting. | Added |
| `styles/Kiln/` | Add repository-local Vale rules. | Added |
| `.github/workflows/ci.yml` | Run Vale in CI. | Updated |
| `AGENTS.md` | Require the work-package and quality rules. | Updated |
| `README.md` | Link the rules. | Updated |
| `docs/ROADMAP.md` | Add work identifiers and Phase 1 work-package map. | Updated |

## Acceptance criteria

- **P0-W02-AC01**
  - **Given** a planned Phase 1 work package
  - **When** a contributor creates its plan, branch, pull request, requirements, acceptance criteria, and evidence
  - **Then** each artifact can use one stable work-package identifier
  - **Evidence:** repository reference and template inspection

- **P0-W02-AC02**
  - **Given** a technical implementation plan
  - **When** a contributor uses the repository template
  - **Then** the plan contains all ten required planning sections
  - **Evidence:** `docs/templates/IMPLEMENTATION-PLAN.md`

- **P0-W02-AC03**
  - **Given** a documentation change that contains a repository-forbidden promotional term
  - **When** continuous integration runs Vale
  - **Then** the prose-linting check exits with a failure
  - **Evidence:** Vale command result in continuous integration

- **P0-W02-AC04**
  - **Given** the accepted Phase 1 roadmap
  - **When** a contributor selects the next work package
  - **Then** the roadmap identifies its proposed branch name and dependencies
  - **Evidence:** `docs/ROADMAP.md`

## Verification commands

```bash
vale .
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Each command must exit with status `0` on the final branch head.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W02-E01 | P0-W02-AC01 | Paths and identifier examples in the branch reference and templates. |
| P0-W02-E02 | P0-W02-AC02 | Inspection of the implementation-plan template. |
| P0-W02-E03 | P0-W02-AC03 | Passing Vale runs plus an isolated negative-rule run. |
| P0-W02-E04 | P0-W02-AC04 | Phase 1 work-package table in the roadmap. |

## Explicit exclusions

- GitHub label creation
- GitHub issue automation
- merge queue configuration
- branch protection configuration
- release automation
- a formal ASD-STE100 compliance claim
- semantic validation of requirement quality by Vale

## Completion record

**Result:** Complete

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| P0-W02-AC01 | Pass | P0-W02-E01 | `docs/BRANCHING-AND-WORK-PLANNING.md`, the plan template, and the pull-request template use one work-package identifier across artifacts. |
| P0-W02-AC02 | Pass | P0-W02-E02 | `docs/templates/IMPLEMENTATION-PLAN.md` contains the ten required planning sections and a completion record. |
| P0-W02-AC03 | Pass | P0-W02-E03 | CI run `30328831549` failed the `prose` job after the branch added only `docs/vale-negative-fixture.md`. CI run `30328877926` passed `prose` after the fixture was removed. |
| P0-W02-AC04 | Pass | P0-W02-E04 | `docs/ROADMAP.md` maps P1-W01 through P1-W07 to branch names and dependencies. |

### Verification executed

| Command or check | Exit status | Evidence location |
| --- | --- | --- |
| Vale positive path | 0 | GitHub Actions run `30328877926`, job `prose` |
| Vale negative path | Nonzero as required | GitHub Actions run `30328831549`, job `prose` |
| `mix format --check-formatted` | 0 | GitHub Actions run `30328877926`, job `test` |
| `mix compile --warnings-as-errors` | 0 | GitHub Actions run `30328877926`, job `test` |
| `mix test` | 0 | GitHub Actions run `30328877926`, job `test` |

### Failures and warnings

- CI run `30328831549` contains an intentional prose failure for the negative-rule test.
- The Vale job has `pull-requests: write` permission so the action can report pull-request annotations.

### Remaining unknowns and exclusions

- P0-W02-U01 and P0-W02-U02 remain open and do not block this work package.
- The explicit exclusions remain unchanged.

### Repository state

- Commit: current head of pull request 3
- Branch: `work/p0-w02-work-governance`
- Diff reviewed: Yes