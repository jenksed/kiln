# Architecture decision records

**Document type:** Reference

Architecture decision records (ADRs) preserve decisions that constrain future implementation.

Use `docs/templates/ADR.md` for new records. Follow `docs/ENGINEERING-QUALITY-RULES.md`.

## Decision status vocabulary

- **Proposed:** under review and not yet binding.
- **Accepted:** current project constraint.
- **Superseded:** replaced by a later ADR.
- **Rejected:** considered and deliberately not chosen.

## Integration status vocabulary

Decision status and repository integration are separate facts.

- **Integrated:** present on `main`.
- **Proposed on branch:** present on an open branch or pull request but not on `main`.
- **Superseded on branch:** replaced before integration.

An accepted ADR MUST NOT be reversed without a superseding ADR. An accepted ADR that is not integrated MUST state its integration status in the record.

## Records

| ADR | Decision status | Integration status |
| --- | --- | --- |
| [0001: Elixir and OTP own the initial runtime](0001-elixir-otp-core.md) | Accepted | Integrated |
| [0002: Persist a session journal separate from the transcript](0002-durable-session-journal.md) | Accepted | Integrated |
| [0003: Use a language-neutral external extension boundary](0003-language-neutral-extensions.md) | Accepted | Integrated |
| [0004: Model delegated work as first-class runs](0004-first-class-run-graph.md) | Accepted | Proposed on P0-W04 stack |
| [0005: Attach Project Steward responsibility to the root run](0005-project-steward.md) | Accepted | Proposed on P0-W04 stack |
| [0006: Own a protocol-neutral internal domain model](0006-protocol-neutral-internal-domain.md) | Accepted | Proposed on P0-W06 |
| [0007: Use Run as the primary execution unit](0007-run-primary-execution-unit.md) | Accepted | Proposed on P0-W06 |
| [0008: Select the simplest reliable capability integration](0008-simplest-reliable-capability-integration.md) | Accepted | Proposed on P0-W07 |
| [0009: Broker capabilities behind intent-level Tools](0009-broker-intent-level-capabilities.md) | Accepted | Proposed on P0-W07 |
