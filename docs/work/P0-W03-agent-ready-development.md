# P0-W03: Agent-Ready Development

**Document type:** Reference  
**Status:** In progress  
**Branch:** `work/p0-w03-agent-ready-development`  
**Depends on:** P0-W02 work governance

## Objective

Prepare Kiln for implementation by giving the coding agent clear repository boundaries, Elixir and OTP workflows, read-only specialist review, deterministic checks, and explicit project invariants.

The development agents and skills in this work package support the construction of Kiln. They are not runtime features of Kiln.

## Observed current state and evidence

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| Kiln has project rules, work-package planning, and evidence requirements. | `AGENTS.md`, `docs/BRANCHING-AND-WORK-PLANNING.md`, and `docs/ENGINEERING-QUALITY-RULES.md` at `c34a7740ba67b007f47f4a73f2e93a75fb874d65` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln has no project-local coding-agent skills. | `.agents/skills/` is absent at `c34a7740ba67b007f47f4a73f2e93a75fb874d65` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln has no project-local specialist agent definitions. | `.pi/agents/` is absent at `c34a7740ba67b007f47f4a73f2e93a75fb874d65` | ChatGPT GitHub connector | 2026-07-28 |
| Kiln has no explicit codebase rules for discoverability, process boundaries, or mutation surfaces. | Repository documentation inspection at `c34a7740ba67b007f47f4a73f2e93a75fb874d65` | ChatGPT GitHub connector | 2026-07-28 |
| The existing `mix check` alias does not run Vale or cross-reference cycle checks. | `mix.exs` lines 26-33 at `c34a7740ba67b007f47f4a73f2e93a75fb874d65` | ChatGPT GitHub connector | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W03-A01:** A small set of project-local skills will reduce repeated orientation and Elixir-specific mistakes.
- **P0-W03-A02:** A single writer with read-only specialist reviewers will preserve accountability better than parallel implementation agents.
- **P0-W03-A03:** Stable repository invariants will reduce architectural drift across model and session changes.

### Unknowns

- **P0-W03-U01:** Unknown. The frequency with which the coding agent will load each skill must be measured during Phase 1.
- **P0-W03-U02:** Unknown. The project-local Pi subagent extension is not installed by this repository. Verify specialist agents only in an environment where a reviewed subagent extension is available.
- **P0-W03-U03:** Unknown. The useful threshold for compile-connected dependencies must be measured as Kiln gains modules.

## Requirements

- **P0-W03-R01:** The repository shall define observable properties of an agent-friendly Kiln codebase.
- **P0-W03-R02:** The repository shall record stable project invariants with unique identifiers.
- **P0-W03-R03:** Project-local skills shall support work-package execution, Elixir and OTP implementation, dependency review, integrity review, and evidence closeout.
- **P0-W03-R04:** Project-local specialist agents shall be read-only except for a verifier that may execute non-mutating checks.
- **P0-W03-R05:** The main coding agent shall remain the only default source-code writer.
- **P0-W03-R06:** The repository shall provide one deterministic preflight command and one deterministic full-check command.
- **P0-W03-R07:** The full-check command shall run prose, formatting, compilation, cross-reference, and test checks.
- **P0-W03-R08:** Development-agent configuration shall not change Kiln's product architecture or introduce runtime multi-agent abstractions.

## Proposed changes

1. Add agent-friendly codebase rules.
2. Add a project invariant register.
3. Add an Elixir and OTP engineering guide.
4. Add project-local skills under `.agents/skills/`.
5. Add read-only project agent definitions under `.pi/agents/`.
6. Add explicit Pi prompt templates for start, review, and closeout workflows.
7. Add `scripts/agent-preflight`.
8. Add `scripts/check`.
9. Update `AGENTS.md`, `README.md`, and the roadmap.

## Files or components expected to change

| Path or component | Expected change | Status |
| --- | --- | --- |
| `docs/AGENT-FRIENDLY-CODEBASE.md` | Define discoverability and implementation rules. | Proposed |
| `docs/PROJECT-INVARIANTS.md` | Record protected architectural invariants. | Proposed |
| `docs/ELIXIR-OTP-ENGINEERING.md` | Define project-specific Elixir and OTP practices. | Proposed |
| `.agents/skills/` | Add project-local coding skills. | Proposed |
| `.pi/agents/` | Add optional specialist agent definitions. | Proposed |
| `.pi/prompts/` | Add explicit workflow prompts. | Proposed |
| `scripts/agent-preflight` | Check branch and plan readiness. | Proposed |
| `scripts/check` | Run the full deterministic quality gate. | Proposed |
| `AGENTS.md` | Require agent-friendly and invariant rules. | Proposed |
| `README.md` | Document development controls. | Proposed |
| `docs/ROADMAP.md` | Record P0-W03 and Phase 0 exit readiness. | Proposed |

## Acceptance criteria

- **P0-W03-AC01**
  - **Given** a coding agent starts a planned work branch
  - **When** the agent reads the repository context
  - **Then** the repository identifies the plan, project invariants, code rules, and required checks
  - **Evidence:** repository paths and preflight output

- **P0-W03-AC02**
  - **Given** an Elixir or OTP implementation task
  - **When** the coding agent loads project skills
  - **Then** one skill provides process-boundary, error, test, and verification rules specific to Kiln
  - **Evidence:** skill inspection and Pi skill validation

- **P0-W03-AC03**
  - **Given** a completed implementation diff
  - **When** specialist review runs
  - **Then** the OTP and integrity reviewers can inspect the diff without write tools
  - **Evidence:** agent frontmatter inspection

- **P0-W03-AC04**
  - **Given** a prepared work branch
  - **When** `scripts/check` runs
  - **Then** Vale, formatter, compiler, compile-connected cycle, and test checks execute
  - **Evidence:** command output and exit status

- **P0-W03-AC05**
  - **Given** an invalid branch or a `work/` branch without a matching plan
  - **When** `scripts/agent-preflight` runs
  - **Then** the command exits with a nonzero status and states the failed condition
  - **Evidence:** isolated negative tests

- **P0-W03-AC06**
  - **Given** the project-local skills and agents
  - **When** a reviewer inspects their scope
  - **Then** no file describes the development agents as Kiln runtime architecture
  - **Evidence:** repository search and review

## Verification commands

```bash
scripts/agent-preflight
scripts/check
```

Isolated negative tests MUST use a temporary branch name or temporary fixture that is removed before completion.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W03-E01 | P0-W03-AC01 | Context paths and successful preflight output. |
| P0-W03-E02 | P0-W03-AC02 | Skill files and validation output. |
| P0-W03-E03 | P0-W03-AC03 | Agent frontmatter with read-only tool lists. |
| P0-W03-E04 | P0-W03-AC04 | Successful `scripts/check` output. |
| P0-W03-E05 | P0-W03-AC05 | Negative preflight output and nonzero exit status. |
| P0-W03-E06 | P0-W03-AC06 | Search result and review statement. |

## Explicit exclusions

- a subagent extension implementation;
- automatic multi-agent orchestration;
- parallel code-writing agents;
- model selection policy;
- runtime agents inside Kiln;
- Credo, Dialyzer, ExCoveralls, or other dependencies before implementation evidence justifies them;
- automatic commits, pushes, or pull requests;
- branch protection administration.

## Completion record

**Result:** In progress

### Verification executed

No verification has run for the current branch.

### Remaining unknowns and exclusions

P0-W03-U01 through P0-W03-U03 remain open.
