# Architecture decision records

**Document type:** Decision authority index

Architecture decision records preserve decisions that constrain future implementation.

Use `docs/templates/ADR.md` for new records. Follow `docs/ENGINEERING-QUALITY-RULES.md`.

## Decision status vocabulary

- **Proposed:** under review and not binding.
- **Accepted:** current Project constraint.
- **Superseded:** replaced by a later accepted ADR.
- **Rejected:** considered and deliberately not chosen.

## Integration status vocabulary

Decision status and Repository integration are separate facts.

- **Integrated:** present on `main`.
- **Proposed on branch:** present on an open branch or pull request but not on `main`.
- **Superseded on branch:** replaced before integration.

An accepted ADR must not be reversed without a superseding ADR. An accepted ADR that is not integrated must state its integration status.

## Records

| ADR | Decision status | Integration status |
| --- | --- | --- |
| [0001: Elixir and OTP own the initial runtime](0001-elixir-otp-core.md) | Accepted | Integrated |
| [0002: Persist a Session journal separate from the transcript](0002-durable-session-journal.md) | Accepted | Integrated |
| [0003: Use a language-neutral external extension boundary](0003-language-neutral-extensions.md) | Accepted | Integrated |
| [0004: Model delegated work as first-class Runs](0004-first-class-run-graph.md) | Accepted | Integrated |
| [0005: Attach Project Steward responsibility to the Root Run](0005-project-steward.md) | Accepted | Integrated |
| [0006: Own a protocol-neutral internal domain model](0006-protocol-neutral-internal-domain.md) | Accepted | Integrated |
| [0007: Use Run as the primary execution unit](0007-run-primary-execution-unit.md) | Accepted | Integrated |
| [0008: Select the simplest reliable Capability integration](0008-simplest-reliable-capability-integration.md) | Accepted | Integrated |
| [0009: Broker Capabilities behind intent-level Tools](0009-broker-intent-level-capabilities.md) | Accepted | Integrated |
| [0010: Compile the smallest sufficient Context](0010-compile-smallest-sufficient-context.md) | Accepted | Integrated |
| [0011: Resolve documentation by authority and version](0011-resolve-documentation-by-authority-and-version.md) | Accepted | Integrated |
| [0012: Protocols adapt to Kiln](0012-protocols-adapt-to-kiln.md) | Accepted | Integrated |
| [0013: Use protected trunk and exclusive writable worktrees](0013-protected-trunk-and-exclusive-worktrees.md) | Accepted | Integrated through pull request 14 |
| [0014: Delegate work through first-class Runs](0014-delegated-work-uses-first-class-runs.md) | Accepted | Integrated through pull request 15 |
| [0015: Use a Run-first event-projected terminal interface](0015-run-first-event-projected-terminal-interface.md) | Accepted | Integrated through pull request 16 |
| [0016: Use SQLite-first read-only local project intelligence](0016-use-sqlite-first-read-only-project-intelligence.md) | Accepted | Integrated through pull request 17 |
| [0017: Quarantine reference instructions and enforce read-only intelligence](0017-quarantine-reference-instructions-and-enforce-read-only-intelligence.md) | Accepted | Integrated through pull request 18 |
| [0018: Use tiered deterministic execution and Evidence](0018-use-tiered-deterministic-execution-and-evidence.md) | Accepted | Integrated through pull request 19 |
| [0019: Implement Kiln through vertical product slices](0019-implement-kiln-through-vertical-product-slices.md) | Partially superseded by ADR 0020 | Integrated through pull request 20 |
| [0020: Prove a single-Run change loop before delegated orchestration](0020-prove-single-run-change-loop-before-delegation.md) | Accepted | Integrated through pull request 23 |
| [0021: Use MiniMax as the only initial provider](0021-use-minimax-as-the-only-initial-provider.md) | Accepted | Integrated through pull request 26 |
| [0023: Use the MiniMax M2.7 OpenAI-compatible API](0023-use-minimax-m2-7-openai-compatible-api.md) | Accepted | Proposed on `work/p0-w22-model-context-repository-boundary` |
