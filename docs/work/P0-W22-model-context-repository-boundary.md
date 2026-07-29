# P0-W22: Provider, Context, Tools, Repository reads, and disclosure

**Document type:** Focused planning work package  
**Status:** In progress  
**Branch:** `work/p0-w22-model-context-repository-boundary`  
**Depends on:** P0-W20 and OD-01 integrated  
**Scope:** MiniMax provider boundary, sealed Context, bounded Repository reads, fixed Tools, disclosure, and secret screening only

## Objective

Define one reproducible MiniMax boundary, one explicit sealed Context package, four or fewer model-facing Tools, safe local Repository reads, and the only data that may leave the machine.

## Observed current state and evidence

- Prompt 4 is integrated at merge commit `45acc2ed575957c53a8c57195d99c82965e9d48e`.
- OD-01 is accepted through ADR-0021 and integrated at merge commit `bdcfcc5d4f4c6f74838d885c74c2240720b3dce1`.
- OD-01 selects MiniMax as the only initial real provider, requires one deterministic fake, permits only sealed Context disclosure under accepted Project policy, and forbids fallback.
- Prompt 3 marks IU-08, IU-09, IU-13, and IU-31 as planning-dependent or deferred.
- Current Context, Capability, execution, and core Schemas contain broader catalogs, retrieval, Agent, Skill, and provider assumptions than the first-month workflow accepts.
- Production source contains no provider, Context, Tool, Repository-read, disclosure, or secret-screening behavior.

## Assumptions and unknowns

### Assumptions

- MiniMax's current hosted text API can support one bounded coding workflow with streaming and function-style Tools.
- Direct HTTP and JSON mapping is smaller than adding a provider SDK or general OpenAI client abstraction.
- Basic deterministic Repository search and reads are sufficient before LSP, Tree-sitter, or an index.
- The initial user can accept a Project disclosure policy before source excerpts are sent.

### Unknowns

- Exact MiniMax endpoint, model identifier, request and response mapping, streaming, cancellation, timeout, and malformed-result behavior.
- Exact retry policy when provider receipt is uncertain.
- Exact Context fields, order, digest, token and byte limits, and retention.
- Exact path, file, symlink, binary, encoding, size, ignore, and fingerprint rules.
- Exact Tool request, result, continuation, output externalization, and failure contracts.
- Exact secret and sensitive-source screening behavior.

## Requirements

- Consume OD-01 without widening it.
- Define one MiniMax model and one direct API mapping.
- Define one deterministic fake provider contract.
- Define streaming, cancellation, timeout, malformed result, usage, and explicit retry behavior.
- Define an ordered sealed Context package and manifest.
- Define allowed, denied, transformed, and omitted Context item classes.
- Define exact token, byte, file, item, Tool-call, turn, and elapsed limits.
- Define Repository root, eligible file set, paths, ignores, symlinks, special files, binary and encoding behavior, reads, search, and fingerprints.
- Define at most four phase-specific Tools with fixed schemas.
- Define large-result externalization and bounded continuation.
- Define source disclosure, credentials, secrets, untrusted instructions, provider payload retention, and provider-side policy limits.
- Preserve P0-W21 ownership of lifecycle and journal semantics.

## Proposed changes

1. Create `docs/MODEL-CONTEXT-AND-REPOSITORY-BOUNDARY.md` as focused subject authority.
2. Create an ADR for the exact MiniMax API and model mapping if required.
3. Update planning control to link the focused authority and record OD-01 consumption.
4. Record the lifecycle and persistence assumptions that must be reconciled after P0-W21 integrates.
5. Complete this work record with final Evidence.

## Files or components expected to change

- `docs/MODEL-CONTEXT-AND-REPOSITORY-BOUNDARY.md`
- `docs/PLANNING.md`
- `docs/decisions/0023-use-minimax-m2-7-openai-compatible-api.md`
- `docs/decisions/README.md`
- `docs/work/P0-W22-model-context-repository-boundary.md`

No production source, test, Schema, dependency, configuration, CI, script, preflight, Skill, prompt, agent, or conformance scaffold changes in this round.

## Acceptance criteria

- One MiniMax endpoint, model, request, stream, Tool, result, usage, timeout, cancellation, malformed-result, and retry contract exists.
- One fake-provider contract covers success and required failures deterministically.
- One ordered Context package, manifest, digest, state binding, and inspection contract exists.
- Exact item, source, token, byte, file, result, turn, and time limits exist.
- Exact Repository path, ignore, symlink, binary, encoding, special-file, search, read, and fingerprint behavior exists.
- Exactly four or fewer phase Tools exist and unused catalogs are absent.
- Secret values, denied paths, reference repositories, runtime Skills, hidden reasoning, and unrelated files cannot enter provider Context.
- Provider payload and response retention are explicit.
- No fallback, router, broker, retrieval framework, LSP, Tree-sitter, protocol, Patch application, Command, or Evidence completion behavior enters scope.
- No P0-W21 lifecycle or persistence contract is defined.

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

Targeted checks must also prove OD-01 is integrated, four or fewer Tools are named, no fallback exists, all provider-bound items carry disclosure decisions, and no lifecycle or journal ownership appears in the focused authority.

## Required completion evidence

- P0-W22-E01: Prompt 4 and OD-01 merge Evidence.
- P0-W22-E02: current official MiniMax API, model, Tool, streaming, and privacy source review.
- P0-W22-E03: provider and fake contracts.
- P0-W22-E04: sealed Context and disclosure contract.
- P0-W22-E05: Repository-read and Tool matrices.
- P0-W22-E06: secret, path, malformed-result, timeout, cancel, and no-fallback examples.
- P0-W22-E07: exact pre-rebase planning-only diff and CI.
- P0-W22-E08: post-P0-W21 rebase authority audit and exact rebased-head CI.

## Explicit exclusions

P0-W22 does not:

- define or change Run, Session, or Task lifecycle;
- define journal, transaction, migration, replay, projection, or persistence semantics;
- define Patch representation, Approval, source mutation, or rollback;
- define registered Command, criterion Evidence, completion, Receipt, or CLI presentation;
- implement or scaffold any behavior;
- add provider fallback, routing, ensemble, Skills, retrieval framework, reference repositories, code intelligence, protocols, telemetry, remote execution, or attestations;
- issue build authorization.
