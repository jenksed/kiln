# Kiln

Kiln is a local-first coding execution ledger and control plane built with Elixir and OTP for one developer working on real software with AI.

A model can investigate and propose work. Kiln decides whether that proposal becomes an authorized change, a verified result, and a durable completion record.

Kiln moves one Repository objective through:

```text
Intent
→ Investigation
→ Implementation
→ Verification
→ Completion
```

## Product problem

Coding agents already provide model choice, terminal interfaces, file Tools, shell access, permissions, sessions, Skills, and subagents.

Kiln is useful only when it adds a stronger work boundary:

- one accepted objective and criteria;
- exact Repository state;
- bounded model Context and Tools;
- explicit mutation authority;
- controlled Patch and Command execution;
- current machine-readable Evidence;
- truthful failure and unknown-effect state;
- restart recovery without replaying uncertain effects.

Kiln keeps these facts separate from the conversation transcript and from model confidence.

## Primary user

The initial user is one developer working on one local active Repository at a time.

Kiln does not initially target teams, hosted collaboration, remote Workers, or autonomous engineering organizations.

## Smallest useful Kiln

The first useful product is a **single-Run, CLI-first, durable change loop**:

```text
select one Repository
→ record one objective and criteria
→ create one Session, Task, and Root Run
→ investigate through bounded Repository reads
→ produce one exact Patch proposal
→ require user approval for the Patch digest
→ apply the Patch to exact base state
→ run one registered verification Command
→ block completion on failed, blocked, stale, or unknown Evidence
→ seal a bounded Receipt after user acceptance
→ restore the work record after restart
```

The first useful version does not require Child Runs, a TUI, managed worktrees, a general Capability broker, Skills, LSP, Tree-sitter, protocols, telemetry, or cross-project intelligence.

## Core model

```text
Workspace: host-local maximum path and trust boundary
└── Project: one active Repository plus accepted instructions and policy
    └── Session: one accepted objective and complete Kiln work history
        └── Task: one desired outcome with criteria
            └── Root Run: one durable execution and coordination attempt
```

A Task states desired work. A Run attempts or coordinates it.

A Run is not:

- an Agent persona;
- a model request;
- a Tool call;
- a Command;
- a process;
- a branch or worktree;
- a protocol session;
- a transcript.

Conversation records can belong to a Run. They do not become the canonical objective, mutation, Evidence, or completion state.

## Minimum architecture

```text
CLI
  │
  ▼
Single-Run workflow application
  ├── pure domain and projection functions
  ├── explicit authority evaluator
  ├── explicit Context package builder
  ├── native Repository reader and exact Patch service
  ├── one provider adapter
  ├── one registered Command runner
  ├── Artifact, Evidence, and Receipt functions
  └── SQLite journal and current projections
          │
          └── transient model and Command Workers
```

Key rules:

- Git and the filesystem remain Repository truth.
- SQLite records Kiln work facts, decisions, and recovery state. It does not replace source truth.
- A model can propose a change. It cannot approve or apply its own Patch.
- A successful Command does not prove every criterion.
- Evidence must identify its subject, method, state binding, freshness, and completeness.
- A Receipt references Evidence and decisions. It cannot grant authority or create a passing result.
- No permanent process exists merely because a Run, Session, Task, Capability, Artifact, or Evidence record exists.
- Processes are reserved for live model streams, external process trees, database connections owned by the selected library, and later background scheduling or subscriptions.
- External protocols adapt to Kiln-native concepts.

See [Product Scope and Minimum Architecture](docs/PRODUCT-SCOPE-AND-MINIMUM-ARCHITECTURE.md) and [Integrated Architecture](docs/ARCHITECTURE.md).

## Child Runs

Child Runs are important next, not required for the first useful version.

Version 0.1 can add:

- one depth-one read-only Scout Child;
- one depth-one independent Verifier Child;
- at most one active Child per Session;
- Root-visible Attention for blocking Child work;
- CLI inspection and return-to-Root navigation.

A Child receives independent Context and narrower explicit grants. It cannot create descendants, expand permissions, communicate with a sibling, or mutate source in version 0.1.

Do not create a Child to wrap one Tool call, add a persona, imitate an organization, or inflate activity.

## Delivery targets

### First month — Single-Run Change Alpha

Deliver one real change through the complete CLI workflow:

- one active Repository;
- one Session, Task, and Root Run;
- minimal SQLite journal and restart;
- one provider and deterministic fake provider;
- bounded read and search;
- explicit Context package;
- four or fewer model-facing Tools;
- exact Patch proposal and user-approved application;
- one registered non-shell verification Command;
- minimal Artifacts, Evidence, Receipt, and completion gate.

### Twelve weeks — Trustworthy Delegated CLI

Add:

- interruption and unknown-effect recovery;
- one read-only Scout Child;
- one independent Verifier Child;
- one active Child at a time;
- bounded Child result delivery;
- Root-visible Attention;
- CLI Run list, inspect, enter, cancel, and return-to-Root actions.

Still defer:

- TUI;
- nested or concurrent Child graphs;
- writing Children;
- managed worktrees;
- LSP, Tree-sitter, and persistent code indexes;
- runtime Skills;
- ACP, MCP, OpenAPI, AG-UI, AHP, and A2A;
- local project intelligence and embeddings;
- telemetry export;
- remote execution;
- automatic commit, push, merge, publication, or formal attestations.

See [Roadmap](docs/ROADMAP.md) and [Implementation Slices](docs/IMPLEMENTATION-SLICES.md).

## Integration policy

Kiln selects the smallest boundary that preserves semantics, cancellation, security, Evidence, testing, and replacement:

1. direct function;
2. library;
3. deterministic CLI;
4. direct API or software development kit;
5. local service or socket;
6. dedicated adapter;
7. protocol client;
8. protocol server;
9. MCP only when dynamic discovery or replacement provides measured value.

MCP is not a sandbox, permission system, Repository boundary, or reason to replace a simpler integration.

## Context and Tool policy

The first-month model package includes only the accepted objective, criteria, current state, approved instructions, selected source ranges, current failures and Evidence, output contract, limits, and no more than four Tool schemas.

Do not load by default:

- full conversation history;
- full Repository files when ranges suffice;
- complete Tool or Capability catalogs;
- all Skills;
- reference repositories;
- raw logs or reports;
- secrets or denied paths;
- stale requirements.

Large results remain Artifacts with bounded excerpts, digests, and completeness state.

## Security boundary

- One canonical approved Repository root.
- One selected writable checkout and one mutation owner.
- No concurrent writer in the first month.
- No model shell.
- No automatic dependency installation.
- No automatic commit, push, merge, publish, or deploy.
- Exact Patch approval and base-state validation before mutation.
- Minimal constructed Command environment.
- Provider disclosure includes only the sealed Context package.
- Reference repositories are disabled through version 0.1.
- Instructions found in files are untrusted data unless they belong to the accepted active Project instruction set.
- Delegation can narrow authority. It cannot expand it.

## Evidence and completion

Kiln keeps these facts separate:

```text
Proposed
Applied
Executed
Verified
Accepted
Delivered
```

A Task can complete only when:

- the accepted change is the observed Repository state;
- required criteria pass with current Evidence;
- no required execution is blocked or orphaned;
- no unknown effect remains;
- the user accepts the result.

Model confidence, a persuasive summary, exit zero, a Receipt, or a mergeable branch cannot imply completion.

## Product boundary

Kiln is not:

- an autonomous software company;
- an Agent-management hierarchy;
- a general multi-agent framework;
- a protocol catalog;
- a replacement for Git, language servers, build tools, package managers, or mature CLIs;
- a whole-machine index;
- a vector-database project;
- a generalized workflow engine;
- a universal developer-tool integration platform;
- a universal sandbox;
- an automatic code-harvesting system.

## Current implementation status

P1-S01 — Durable single-Run foundation is integrated at `db02198` via PR #46 (closeout SHA `5792ffdd3af6c45f07e07b8334ce150ad642495b`, evidence SHA `444c5a5`, hardening SHA `c872c16`, slice closeout SHA `a4ea5f9`). The final P1-S01-V01 manifest was recorded at the ignored local path `artifacts/p1-s01/slice-01-5792ffdd3af6c45f07e07b8334ce150ad642495b.json` with `overall: pass` and 18 components passing on the accepted OD-02 owner-machine. Its documented digest preserves provenance, but the owner-machine file is not currently retrievable from a fresh checkout; see `artifacts/p1-s01/README.md`. PR #48 was adjudicated and rejected; PR #53 remained historical and unmerged; PR #56 integrated the corrected T01 plan at `e57678874a36de1700aa666413b51aae31ea9b12`; PR #57 recorded owner acceptance of the corrected T01 plan at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`. P0-W42 authorizes the bounded P1-S02-T01 implementation package against that same canonical base and creates `docs/authorizations/P1-S02-T01.authorization` binding the Accepted-state plan digest `b61f1c611d1a9df65b0334f7c71aa8c723e7d8c0dc4efe9fd5a053a78313e6e5`, the trusted owner `Joshua Jenks`, the bounded T01-v2 scope, and `authorized_at=2026-08-10T15:26:00-04:00`. Authorization permits but does not start implementation; no P1-S02 runtime implementation exists yet; P1-S02-T02 and later remain unauthorized. P0-W43 then adjudicated a discovered migration-runner incompatibility, amended the T01 plan to authorize `lib/kiln/store/migrations.ex` for compound-statement support only, and reissued the authorization record against amended plan digest `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e`, decision base `1243b8f27a594c9440638964a83b56c74774ba28`, and `authorized_at=2026-08-10T23:06:00-04:00`. The amended plan and reissued record become active trusted authority only when P0-W43 integrates on canonical `main`. The exact next action after that integration is to observe the resulting canonical integration commit and move `work/p1-s02-t01-artifact-evidence-substrate-v2` to it. See `docs/IMPLEMENTATION-AUTHORIZATION.md`.

## Development

Kiln targets Elixir 1.20 on Erlang/OTP 28.

```bash
mise install
mix deps.get
git submodule update --init --recursive
scripts/agent-preflight
scripts/check
```

The third-party `project-arsenal` development-agent dependency at
`.claude/dependencies/project-arsenal` is a pinned Git submodule. CI and
`scripts/validate-agent-assets` both expect the submodule to be initialized
and at the reviewed commit (`ecc8797d45447060b0c4aacd8efb6b1909e9e690`);
re-initialize it on every fresh checkout with
`git submodule update --init --recursive` before running the agent-asset
validator. The dependency is reference content only and is not a Kiln runtime
component.

Current development-agent conformance still requires reconciliation before Phase 1 tickets begin.

## Planning authority

1. [Product Scope and Minimum Architecture](docs/PRODUCT-SCOPE-AND-MINIMUM-ARCHITECTURE.md)
2. [Integrated Architecture](docs/ARCHITECTURE.md)
3. [Roadmap](docs/ROADMAP.md)
4. [Implementation Slices](docs/IMPLEMENTATION-SLICES.md)
5. [Slice Acceptance Gates](docs/SLICE-ACCEPTANCE-GATES.md)
6. accepted ADRs in [Architecture Decisions](docs/decisions/README.md)
7. subject specifications for detailed boundaries
8. JSON contracts as provisional conformance scaffolding

Build authorization for P1-S01 was issued by `docs/WAVE-A-ADJUDICATION-AND-AUTHORIZATION.md` and consumed by PR #46. The corrected P1-S02-T01 plan was owner-accepted via P0-W41 against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; no P1-S02 package is currently authorized. The next governance action is a separate T01 implementation-authorization package. See `docs/IMPLEMENTATION-AUTHORIZATION.md`.
