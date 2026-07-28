# P0-W07: Capability Integration and Broker

**Document type:** Reference  
**Status:** In progress  
**Branch:** `work/p0-w07-capability-integration`  
**Depends on:** P0-W06 through draft pull request 7

## Objective

Define how Kiln selects and connects to capabilities without allowing MCP, LSP, APIs, CLIs, or browser interfaces to become the internal domain or model-facing abstraction.

Define a Capability broker that keeps integrations replaceable, permission-scoped, deterministic, bounded, traceable, and outside model Context except for a small intent-level Tool projection.

## Observed current state

| Observation | Evidence | Date or commit |
| --- | --- | --- |
| Kiln owns a protocol-neutral internal domain. | ADR 0006 and `docs/INTERNAL-DOMAIN-MODEL.md` | 2026-07-28 |
| Run is the primary durable execution unit. | ADR 0007 | 2026-07-28 |
| Capability availability, policy, grant, and effective authority are separate. | `docs/SECURITY-MODEL.md` | 2026-07-28 |
| Tools declare required Capabilities but do not grant them. | Internal domain and Security model | 2026-07-28 |
| The planning baseline identifies MCP, LSP, and capability-policy boundaries as unresolved. | `docs/PLANNING-BASELINE.md` | 2026-07-28 |
| No Capability broker, registration catalog, selection logic, or model-facing Tool implementation exists. | Source inventory and P0-W06 status | 2026-07-28 |
| Repository, Git, Command, Artifact, Evidence, and policy behavior remain unimplemented. | `docs/PLANNING-BASELINE.md` and source inventory | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P0-W07-A01:** Kiln can preserve one intent-level Tool contract across several implementations.
- **P0-W07-A02:** Repository operations are core enough to remain native.
- **P0-W07-A03:** Git CLI behavior is more mature and replaceable than rebuilding Git internals.
- **P0-W07-A04:** Existing build, test, lint, format, compiler, and analyzer CLIs remain authoritative.
- **P0-W07-A05:** Raw LSP can be translated into stable semantic operations.
- **P0-W07-A06:** Most initial core capabilities gain no material value from MCP.
- **P0-W07-A07:** A full integration catalog would waste model Context and increase Tool-selection errors.
- **P0-W07-A08:** Artifact-backed continuations can keep results bounded.

### Unknowns

- **P0-W07-U01:** Unknown. The exact Elixir module and process boundaries for the broker require implementation evidence.
- **P0-W07-U02:** Unknown. The final registration storage format and migration path require implementation evidence.
- **P0-W07-U03:** Unknown. Health-probe cadence and expiry rules require dogfooding.
- **P0-W07-U04:** Unknown. The semantic-fingerprint algorithm requires fixtures from real duplicate integrations.
- **P0-W07-U05:** Unknown. The initial LSP client library and server lifecycle strategy remain unselected.
- **P0-W07-U06:** Unknown. The first justified local MCP capability remains unselected.
- **P0-W07-U07:** Unknown. Remote authentication, rate limits, and cost inputs remain deferred.
- **P0-W07-U08:** Unknown. Stable pagination contracts require implementation evidence.
- **P0-W07-U09:** Unknown. Browser automation framework selection remains deferred.

## Applicable invariants and decisions

This work preserves:

- ADR 0001 through ADR 0007;
- `KILN-INV-001` through `KILN-INV-034`;
- protocol-neutral core identity;
- Run-centered work;
- explicit Capability grants;
- Repository trust and Privacy policy;
- Claim, Evidence, Receipt, Artifact, and Context separation;
- no process for every noun;
- external adapters outside the domain model.

This work adds ADR 0008 and ADR 0009 and extends the invariant register.

## Requirements

- **P0-W07-R01:** Kiln shall evaluate capability integrations through the accepted hierarchy from in-process code to browser automation.
- **P0-W07-R02:** Kiln shall select the earliest hierarchy option that satisfies lifecycle, security, interoperability, isolation, output, and replaceability requirements.
- **P0-W07-R03:** Repository reads and writes shall remain native in the initial system.
- **P0-W07-R04:** Git shall normally use a native adapter backed by the Git CLI.
- **P0-W07-R05:** Build, test, lint, format, compiler, package-manager, and static-analysis capabilities shall normally use existing CLIs.
- **P0-W07-R06:** Raw LSP shall remain behind a native semantic adapter.
- **P0-W07-R07:** MCP shall not be selected solely because a capability can be wrapped in MCP.
- **P0-W07-R08:** Local MCP shall require material lifecycle, state, sharing, replacement, discovery, or existing-implementation value.
- **P0-W07-R09:** Remote MCP shall require material interoperability and discovery value beyond a narrow direct API.
- **P0-W07-R10:** Browser automation shall remain a fallback unless browser behavior is under test.
- **P0-W07-R11:** MCP shall not be represented as a security sandbox.
- **P0-W07-R12:** Kiln shall not rebuild mature tools merely to create agent-native interfaces.
- **P0-W07-R13:** The Capability broker shall inventory all supported implementation kinds outside model Context.
- **P0-W07-R14:** The broker shall select implementations by Task phase, Run intent, compatibility, availability, authority, hierarchy, determinism, locality, output, provenance, and replacement cost.
- **P0-W07-R15:** The broker shall re-evaluate effective authority before each invocation and before fallback.
- **P0-W07-R16:** The broker shall return one bounded normalized result envelope.
- **P0-W07-R17:** Large or binary results shall become Artifacts with bounded model-visible references.
- **P0-W07-R18:** The broker shall preserve selection, implementation, authority, Repository, output, fallback, and normalization provenance.
- **P0-W07-R19:** The broker shall record material Capability use in Traces and Receipts.
- **P0-W07-R20:** The model-facing interface shall use a compact intent-level Tool namespace.
- **P0-W07-R21:** The full catalog shall remain outside model Context.
- **P0-W07-R22:** Duplicate semantic capabilities shall collapse into one model-facing Tool and one replacement group.
- **P0-W07-R23:** Availability changes shall invalidate selection without changing model-facing Tool identity.
- **P0-W07-R24:** The initial system shall not use MCP for Kiln core Repository, Git, execution, Artifact, journal, Run, Evidence, policy, or authority responsibilities.
- **P0-W07-R25:** Capability definitions, registrations, selection rules, and result contracts shall remain data unless live concurrency or subscriptions justify a process.

## Proposed changes

1. Add `docs/CAPABILITY-INTEGRATION.md`.
2. Add ADR 0008 for the integration hierarchy.
3. Add ADR 0009 for the Capability broker and compact model-facing Tools.
4. Add `docs/contracts/kiln-capability.schema.json`.
5. Update the contract index.
6. Update architecture and security references.
7. Extend Project invariants.
8. Update README and AGENTS start rules.
9. Add P0-W07 and capability-proof requirements to the roadmap.
10. Add this work-package plan.
11. Do not implement production code.

## Expected files or components

| Path | Expected change |
| --- | --- |
| `docs/CAPABILITY-INTEGRATION.md` | Add the hierarchy, broker, Tools, normalization, duplicates, and acceptance criteria. |
| `docs/decisions/0008-simplest-reliable-capability-integration.md` | Record the default hierarchy and initial non-MCP boundary. |
| `docs/decisions/0009-broker-intent-level-capabilities.md` | Record the broker and compact Tool surface. |
| `docs/contracts/kiln-capability.schema.json` | Define registration, selection, Tool projection, and result contracts. |
| `docs/contracts/README.md` | Index the Capability contract. |
| `docs/ARCHITECTURE.md` | Add broker and integration hierarchy references. |
| `docs/SECURITY-MODEL.md` | Clarify broker permission and MCP boundaries. |
| `docs/PROJECT-INVARIANTS.md` | Add stable integration constraints. |
| `docs/decisions/README.md` | Index ADR 0008 and ADR 0009. |
| `README.md` | Link Capability Integration and summarize the position. |
| `AGENTS.md` | Require the capability hierarchy before integration work. |
| `docs/ROADMAP.md` | Add P0-W07 and the initial broker proof slice. |
| `docs/work/P0-W07-capability-integration.md` | Record this work package. |

## Acceptance criteria

- **P0-W07-AC01**
  - **Given** the possible implementation kinds
  - **When** a planning or implementation session chooses an integration
  - **Then** it applies the hierarchy and documents why earlier practical options were rejected
  - **Evidence:** `docs/CAPABILITY-INTEGRATION.md` and ADR 0008

- **P0-W07-AC02**
  - **Given** Repository, Git, verification, semantic inspection, MCP, API, and browser capability classes
  - **When** the integration position is inspected
  - **Then** the document states the required native, CLI, adapter, protocol, and fallback boundaries
  - **Evidence:** required-positions and initial non-MCP sections

- **P0-W07-AC03**
  - **Given** a catalog with native, CLI, API, MCP, and browser registrations
  - **When** the broker contract is inspected
  - **Then** it defines inventory, availability, phase selection, authority, normalization, output, provenance, Artifact, duplicate, Trace, and Receipt behavior
  - **Evidence:** Capability broker specification and ADR 0009

- **P0-W07-AC04**
  - **Given** an available Capability implementation
  - **When** the Run lacks effective authority
  - **Then** availability does not permit execution and fallback requires a new authority evaluation
  - **Evidence:** permission-integration rules and Security model

- **P0-W07-AC05**
  - **Given** a result larger than the inline budget
  - **When** normalization completes
  - **Then** the large content becomes an Artifact and the model receives bounded references and provenance
  - **Evidence:** result-normalization rules and Capability schema

- **P0-W07-AC06**
  - **Given** many implementation registrations
  - **When** one Run receives its model-facing Tool projection
  - **Then** the full catalog stays outside Context and the Run receives at most twelve phase-relevant intent Tools
  - **Evidence:** model-facing Tool design, ADR 0009, and schema

- **P0-W07-AC07**
  - **Given** duplicate registrations
  - **When** the model-facing projection is built
  - **Then** Kiln exposes one intent Tool, ranks implementations deterministically, and records the selected implementation
  - **Evidence:** duplicate-capability policy and selection contract

- **P0-W07-AC08**
  - **Given** MCP availability
  - **When** the initial non-MCP boundary is inspected
  - **Then** Kiln core Repository, Git, execution, Artifact, journal, Run, Evidence, and policy capabilities remain outside MCP
  - **Evidence:** explicit initial non-MCP list

- **P0-W07-AC09**
  - **Given** the JSON contract
  - **When** a JSON parser and schema validator load it
  - **Then** it is valid Draft 2020-12 JSON Schema and contains registration, selection, Tool projection, and result definitions
  - **Evidence:** parser and validator output

- **P0-W07-AC10**
  - **Given** architecture, security, invariants, roadmap, README, and AGENTS
  - **When** terminology is inspected
  - **Then** they agree that the broker is deterministic, MCP is an adapter boundary, the model sees intent Tools, and mature capabilities remain native or CLI-based where practical
  - **Evidence:** cross-document inspection

- **P0-W07-AC11**
  - **Given** this planning-only work package
  - **When** the final diff is reviewed
  - **Then** no production source, tests, dependencies, workflows, scripts, or runtime configuration have changed
  - **Evidence:** changed-file inventory

## Verification commands

```bash
scripts/agent-preflight
scripts/validate-agent-assets
vale .
python -m json.tool docs/contracts/kiln-capability.schema.json
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

Each command must exit with status `0` before this work package is complete.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| P0-W07-E01 | P0-W07-AC01 | Hierarchy, decision tree, and ADR 0008. |
| P0-W07-E02 | P0-W07-AC02 | Required positions and initial non-MCP boundary. |
| P0-W07-E03 | P0-W07-AC03 | Broker responsibilities, architecture, and ADR 0009. |
| P0-W07-E04 | P0-W07-AC04 | Permission and fallback rules. |
| P0-W07-E05 | P0-W07-AC05 | Result-normalization and Artifact rules. |
| P0-W07-E06 | P0-W07-AC06 | Compact Tool projection and schema maximum. |
| P0-W07-E07 | P0-W07-AC07 | Duplicate policy and selection decision contract. |
| P0-W07-E08 | P0-W07-AC08 | Explicit capabilities that are not MCP initially. |
| P0-W07-E09 | P0-W07-AC09 | JSON parser and schema-validator output. |
| P0-W07-E10 | P0-W07-AC10 | Cross-document terminology review. |
| P0-W07-E11 | P0-W07-AC11 | Final changed-file list. |
| P0-W07-E12 | All | Passing complete CI against the final head. |

## Explicit exclusions

- production Elixir implementation;
- SQLite migrations;
- Tool implementations;
- Git adapter implementation;
- LSP client selection or implementation;
- MCP client or server implementation;
- remote API implementation;
- browser automation implementation;
- dynamic plugin marketplace;
- broad Capability catalogs;
- provider integration;
- final Phase 1 work-package reordering;
- repair of dependency-stack CI and integration state.

## Completion record

**Result:** Implemented but unverified

### Acceptance status

| Criterion | Status | Evidence ID |
| --- | --- | --- |
| P0-W07-AC01 | Implemented; verification pending | P0-W07-E01 |
| P0-W07-AC02 | Implemented; verification pending | P0-W07-E02 |
| P0-W07-AC03 | Implemented; verification pending | P0-W07-E03 |
| P0-W07-AC04 | Implemented; verification pending | P0-W07-E04 |
| P0-W07-AC05 | Implemented; verification pending | P0-W07-E05 |
| P0-W07-AC06 | Implemented; verification pending | P0-W07-E06 |
| P0-W07-AC07 | Implemented; verification pending | P0-W07-E07 |
| P0-W07-AC08 | Implemented; verification pending | P0-W07-E08 |
| P0-W07-AC09 | Implemented; parser verification pending | P0-W07-E09 |
| P0-W07-AC10 | In progress | P0-W07-E10 |
| P0-W07-AC11 | Verification pending | P0-W07-E11 |

### Verification executed

No complete verification has run for the final P0-W07 branch head.

### Failures and warnings

- The dependency stack has unresolved agent-asset validation and integration state.
- JSON parser and schema validation remain pending.
- Complete repository checks remain pending.

### Remaining unknowns and exclusions

- P0-W07-U01 through P0-W07-U09 remain open.
- All explicit exclusions remain outside this work package.

### Repository state

- Branch: `work/p0-w07-capability-integration`
- Base branch: `work/p0-w06-internal-domain-model`
- Base commit: `e59607430817a239ea125562380f6525439aba5c`
- Final commit: Pending
- Diff reviewed: Pending
