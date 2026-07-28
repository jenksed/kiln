# P0-W06: Internal Domain Model

**Document type:** Reference  
**Status:** In progress  
**Branch:** `work/p0-w06-internal-domain-model`  
**Depends on:** P0-W05 through draft pull request 6

## Objective

Define Kiln's protocol-neutral internal domain model before Phase 1 implementation or external-protocol planning.

## Observed current state

| Observation | Evidence | Date or commit |
| --- | --- | --- |
| The planning baseline states that Kiln must own stable internal terms and avoid becoming a protocol catalog. | `docs/PLANNING-BASELINE.md` | 2026-07-28 |
| The existing model defines Workspace, Session, Run, Root Run, Child Run, attention, capability profiles, Artifacts, Evidence, and Client focus. | `docs/SESSION-MODEL.md`, `docs/RUN-MODEL.md`, `docs/SECURITY-MODEL.md` | 2026-07-28 |
| Project, Task, Agent, Worker, model invocation, Claim, Receipt, Repository trust policy, and Privacy policy do not have complete internal contracts. | Planning-baseline glossary and gaps | 2026-07-28 |
| The planning baseline identifies capability policy and context contracts as unresolved. | CF-012 and planning gaps | 2026-07-28 |
| ADR 0004 defines first-class Runs but does not fully separate Run from Task, Agent, Worker, or model invocation. | ADR 0004 | 2026-07-28 |
| ADR 0003 defines an external extension boundary but does not prohibit an external protocol from becoming the core semantic model. | ADR 0003 | 2026-07-28 |
| No production implementation exists for the planned domain entities. | `mix.exs`, `lib/`, `test/`, planning baseline | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W06-A01:** A Session remains the durable objective boundary.
- **P0-W06-A02:** A Run remains the primary durable execution unit.
- **P0-W06-A03:** A Task is desired work and can have several Runs.
- **P0-W06-A04:** An Agent is a versioned execution definition, not the durable work entity.
- **P0-W06-A05:** A Worker is a transient lease-holder that advances one Run.
- **P0-W06-A06:** Kiln can define schemas before it selects protocol adapters.
- **P0-W06-A07:** SQLite and the append-oriented event journal remain the initial persistence direction.
- **P0-W06-A08:** A Project can include active and reference Repositories with different trust roles.
- **P0-W06-A09:** Privacy policy must evaluate provider and adapter egress independently from capability permission.

### Unknowns

- **P0-W06-U01:** Unknown. The exact UUIDv7 implementation requires dependency or internal-generator review.
- **P0-W06-U02:** Unknown. The final SQL normalization and indexes require implementation evidence.
- **P0-W06-U03:** Unknown. The policy expression language is not selected.
- **P0-W06-U04:** Unknown. The initial event snapshot frequency is not selected.
- **P0-W06-U05:** Unknown. The exact Worker lease and orphan timeout requires dogfooding.
- **P0-W06-U06:** Unknown. The first supported multi-Repository Session scope requires product evidence.
- **P0-W06-U07:** Unknown. Receipt signatures and key ownership remain deferred.
- **P0-W06-U08:** Unknown. Exact context compaction algorithms remain deferred.
- **P0-W06-U09:** Unknown. Adapter packaging and process boundaries remain deferred.

## Requirements

- **P0-W06-R01:** Kiln shall own one protocol-neutral internal domain model.
- **P0-W06-R02:** External protocols shall connect through adapters and shall not define core identity, lifecycle, authority, persistence, or Evidence semantics.
- **P0-W06-R03:** The model shall define Workspace, Project, Repository, Environment, Session, Task, Run, Root Run, Parent Run, Child Run, Agent, Worker, and model invocation.
- **P0-W06-R04:** The model shall define Capability, Capability grant, Skill, Resource, Tool call, Command, Terminal, Approval, Attention request, and Interruption.
- **P0-W06-R05:** The model shall define Artifact, Change set, Claim, Evidence, Receipt, Trace, Checkpoint, Client, Client focus, Repository trust policy, and Privacy policy.
- **P0-W06-R06:** Each concept shall state purpose, identity, ownership, lifecycle, persistence, relationships, mutable state, immutable Evidence, security boundary, runtime form, and critical distinctions.
- **P0-W06-R07:** The primary unit of agent work shall be a Run.
- **P0-W06-R08:** A Run shall be independently identifiable, inspectable, interruptible, resumable when recovery is valid, measurable, permission-scoped, context-scoped, Evidence-producing, and cancellable.
- **P0-W06-R09:** The model shall separate Session from Task, Task from Run, Run from Agent, Agent from model invocation, and Agent from Worker.
- **P0-W06-R10:** The model shall separate Capability from Tool and Capability availability from permission.
- **P0-W06-R11:** The model shall separate Skill from Agent persona, Claim from Evidence, Evidence from Receipt, and Artifact from Context.
- **P0-W06-R12:** The model shall separate logical Run lineage from OTP supervision and Client focus from shared Session state.
- **P0-W06-R13:** The model shall separate active-Project instructions from retrieved reference-Project content.
- **P0-W06-R14:** The model shall define an entity and relationship diagram.
- **P0-W06-R15:** The model shall define durable, transient, immutable, and derived state.
- **P0-W06-R16:** The model shall define ownership and lifecycle responsibility.
- **P0-W06-R17:** The model shall define an initial SQLite persistence model without creating a table for every noun.
- **P0-W06-R18:** The model shall define domain invariants and forbidden states.
- **P0-W06-R19:** The model shall define the external-adapter boundary.
- **P0-W06-R20:** The model shall provide JSON Schema Draft 2020-12 contracts for important entities.
- **P0-W06-R21:** The model shall define a migration strategy for existing planning terminology.
- **P0-W06-R22:** An OTP process shall exist only for concurrent state, lifecycle, timing, subscriptions, external communication, or fault isolation.
- **P0-W06-R23:** The work package shall not implement production code or select an external protocol.

## Proposed changes

1. Add `docs/INTERNAL-DOMAIN-MODEL.md` as the internal terminology and relationship authority.
2. Add JSON Schema contracts under `docs/contracts/`.
3. Add ADR 0006 for the protocol-neutral internal model.
4. Add ADR 0007 for Run as the primary execution unit.
5. Add this work-package plan.
6. Update the architecture to place adapters outside the domain boundary.
7. Update Session and Run references with Task, Agent, Worker, and model-invocation distinctions.
8. Update security text with availability, policy, grant, effective authority, Repository trust, and Privacy policy.
9. Add internal-domain invariants to the project invariant register.
10. Link the model from README and coding-session instructions.
11. Add P0-W06 to the Phase 0 roadmap.
12. Do not modify production source.

## Expected files or components

| Path | Expected change |
| --- | --- |
| `docs/INTERNAL-DOMAIN-MODEL.md` | Add the complete protocol-neutral domain model. |
| `docs/contracts/README.md` | Define contract scope and validation rules. |
| `docs/contracts/kiln-core.schema.json` | Add core entity contracts. |
| `docs/contracts/kiln-execution.schema.json` | Add execution and authority contracts. |
| `docs/contracts/kiln-evidence.schema.json` | Add Artifact, Claim, Evidence, Receipt, Trace, and Checkpoint contracts. |
| `docs/decisions/0006-protocol-neutral-internal-domain.md` | Record the adapter-boundary decision. |
| `docs/decisions/0007-run-primary-execution-unit.md` | Record the Run-centered execution decision. |
| `docs/decisions/README.md` | Index ADRs and distinguish decision from integration state. |
| `docs/PROJECT-INVARIANTS.md` | Add protocol, Run, authority, Evidence, context, trust, and privacy invariants. |
| `docs/ARCHITECTURE.md` | Add the internal domain and adapter boundaries. |
| `docs/SESSION-MODEL.md` | Add Project, Task, and Run ownership distinctions. |
| `docs/RUN-MODEL.md` | Add Task, Agent, Worker, and invocation distinctions. |
| `docs/SECURITY-MODEL.md` | Add effective-authority, trust, and privacy rules. |
| `README.md` | Link the internal domain model. |
| `AGENTS.md` | Require the model for relevant planning and implementation. |
| `docs/ROADMAP.md` | Add P0-W06 and preserve no-production-code scope. |

## Acceptance criteria

- **P0-W06-AC01**
  - **Given** the required domain concept list
  - **When** the internal domain model is inspected
  - **Then** every required concept has all required definition fields
  - **Evidence:** concept specifications in `docs/INTERNAL-DOMAIN-MODEL.md`

- **P0-W06-AC02**
  - **Given** Session, Task, Run, Agent, Worker, and model invocation
  - **When** their relationships are inspected
  - **Then** Run is the primary execution unit and each other concept has a distinct purpose and lifecycle
  - **Evidence:** critical-distinction table and ADR 0007

- **P0-W06-AC03**
  - **Given** Capability, Tool, availability, policy, and grant
  - **When** effective authority is evaluated
  - **Then** availability alone cannot authorize an action
  - **Evidence:** effective-authority formula, security update, and schema contracts

- **P0-W06-AC04**
  - **Given** an external protocol or mature tool
  - **When** it connects to Kiln
  - **Then** an adapter maps it to Kiln-native commands, entities, and events without changing the core model
  - **Evidence:** ADR 0006 and external-adapter boundary

- **P0-W06-AC05**
  - **Given** a reference Repository
  - **When** its content enters a Run
  - **Then** it remains data without instruction authority and follows trust and privacy policy
  - **Evidence:** Repository trust policy, Context rules, and domain invariants

- **P0-W06-AC06**
  - **Given** Claim, Evidence, Receipt, Artifact, Context, Trace, and Checkpoint
  - **When** the evidence model is inspected
  - **Then** none of these terms silently substitutes for another
  - **Evidence:** concept specifications, invariants, forbidden states, and evidence schema

- **P0-W06-AC07**
  - **Given** the complete concept catalog
  - **When** OTP process requirements are inspected
  - **Then** a process is required only for concurrent state, lifecycle, timing, subscriptions, external communication, or fault isolation
  - **Evidence:** OTP process table and ADR 0007

- **P0-W06-AC08**
  - **Given** the initial persistence design
  - **When** it is inspected
  - **Then** durable identities and events are stored while runtime handles and derived projections remain absent or rebuildable
  - **Evidence:** persistence model and durable-versus-transient table

- **P0-W06-AC09**
  - **Given** the three JSON Schema files
  - **When** a JSON parser and Draft 2020-12 validator load them
  - **Then** they are syntactically valid and expose only Kiln-native fields
  - **Evidence:** parser output and schema inspection

- **P0-W06-AC10**
  - **Given** existing planning terminology
  - **When** a later work package uses it
  - **Then** the migration table identifies the canonical Kiln term or boundary
  - **Evidence:** terminology migration strategy

- **P0-W06-AC11**
  - **Given** this planning-only pass
  - **When** the final diff is inspected
  - **Then** no production source, test, dependency, workflow, or runtime configuration changes
  - **Evidence:** final changed-file list

## Verification commands

```bash
scripts/agent-preflight
scripts/validate-agent-assets
vale .
python -m json.tool docs/contracts/kiln-core.schema.json >/dev/null
python -m json.tool docs/contracts/kiln-execution.schema.json >/dev/null
python -m json.tool docs/contracts/kiln-evidence.schema.json >/dev/null
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

Each command must exit with status `0` before this work package is complete.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W06-E01 | P0-W06-AC01 | Complete concept catalog. |
| P0-W06-E02 | P0-W06-AC02 | Critical distinctions and ADR 0007. |
| P0-W06-E03 | P0-W06-AC03 | Effective-authority model and Capability contracts. |
| P0-W06-E04 | P0-W06-AC04 | Adapter-boundary text and ADR 0006. |
| P0-W06-E05 | P0-W06-AC05 | Trust and Privacy policy contracts. |
| P0-W06-E06 | P0-W06-AC06 | Evidence-domain definitions and schema. |
| P0-W06-E07 | P0-W06-AC07 | OTP process classification. |
| P0-W06-E08 | P0-W06-AC08 | Persistence and state tables. |
| P0-W06-E09 | P0-W06-AC09 | Passing JSON parser and schema checks. |
| P0-W06-E10 | P0-W06-AC10 | Migration mapping. |
| P0-W06-E11 | P0-W06-AC11 | Final changed-file list. |
| P0-W06-E12 | All | Passing CI for the final branch head. |

## Explicit exclusions

- production Elixir modules;
- Ecto or SQLite migrations;
- UUID implementation;
- an OTP supervision implementation;
- command execution implementation;
- provider integration;
- ACP, MCP, LSP, A2A, AG-UI, AHP, or other adapter implementation;
- TUI selection or implementation;
- policy expression-language selection;
- Receipt signing;
- context compaction algorithm;
- Phase 1 work-package reordering;
- P0-W04 or P0-W05 CI repair;
- integration of the stacked pull requests into `main`.

## Completion record

**Result:** Implemented but unverified

### Acceptance status

| Criterion | Status | Evidence ID |
| --- | --- | --- |
| P0-W06-AC01 | Implemented; verification pending | P0-W06-E01 |
| P0-W06-AC02 | Implemented; verification pending | P0-W06-E02 |
| P0-W06-AC03 | Implemented; verification pending | P0-W06-E03 |
| P0-W06-AC04 | Implemented; verification pending | P0-W06-E04 |
| P0-W06-AC05 | Implemented; verification pending | P0-W06-E05 |
| P0-W06-AC06 | Implemented; verification pending | P0-W06-E06 |
| P0-W06-AC07 | Implemented; verification pending | P0-W06-E07 |
| P0-W06-AC08 | Implemented; verification pending | P0-W06-E08 |
| P0-W06-AC09 | Implemented; verification pending | P0-W06-E09 |
| P0-W06-AC10 | Implemented; verification pending | P0-W06-E10 |
| P0-W06-AC11 | Verification pending | P0-W06-E11 |

### Verification executed

No complete verification has run for the final P0-W06 branch head.

### Failures and warnings

- The dependency stack has unresolved CI and integration state.
- JSON syntax and complete repository checks remain pending.

### Remaining unknowns and exclusions

- P0-W06-U01 through P0-W06-U09 remain open.
- All explicit exclusions remain outside this work package.

### Repository state

- Branch: `work/p0-w06-internal-domain-model`
- Base branch: `work/p0-w05-planning-baseline`
- Base commit: `def2c04766caefcea35285fbf550827d195910db`
- Final commit: Pending
- Diff reviewed: Pending
